# Application Landing Zone — Microsoft Fabric (Fabric-private)

This is an optional application landing zone. It deploys a Microsoft Fabric capacity and workspace with private inbound connectivity (workspace-level PE) and private outbound connectivity (3 Managed Private Endpoints to Storage, SQL, and a workspace-local Key Vault) into its own spoke VNet.

The module creates the VNet, subnets, and hub connection. You do not need to deploy this to use the Networking module on its own.

## What It Deploys

| Resource                    | Purpose                                                                           |
| --------------------------- | --------------------------------------------------------------------------------- |
| Fabric Capacity (F2)        | Compute capacity for the workspace                                                |
| Fabric Workspace            | Container for Fabric items                                                        |
| Workspace PE                | Private inbound path to the workspace                                             |
| Lab Storage Account         | Blob storage target for Fabric MPE                                                |
| Lab Azure SQL Server + DB   | SQL target for Fabric MPE                                                         |
| Workspace-Local Key Vault   | Secrets storage for the Fabric workspace (reached via MPE)                        |
| 3 Managed Private Endpoints | Outbound private paths from Fabric to Storage (blob), SQL, and workspace-local KV |
| Spoke VNet (Block 5)        | `172.20.80.0/20` with PE subnet                                                   |
| NSG                         | Explicit allow rules on PE subnet (443, 1433)                                     |
| vHub connection             | Connects spoke to platform Virtual WAN hub                                        |
| DNS resolver policy link    | Private DNS resolution via platform DNS                                           |
| Diagnostic settings         | Capacity logs/metrics to platform LAW                                             |

## Prerequisites

- All [platform landing zone prerequisites](../README.md#prerequisites)
- Platform Landing Zone (`Networking/`) applied first with `add_private_dns00 = true`
- **One-time tenant configuration** — complete the gate sequence below before first deploy

### Tenant Configuration Gates (One-Time)

Fabric Admin Portal and tenant-settings REST API are only accessible after two gates. Follow this sequence:

#### Gate 1: Entra Directory Role

Azure RBAC roles (Subscription Owner, Contributor, etc.) grant **zero** Fabric admin authority. You must hold one of these Microsoft Entra directory roles:

- **Global Administrator**, OR
- **Power Platform Administrator**, OR
- **Fabric Administrator** (formerly Power BI Administrator)

Have an Entra admin assign you one of these roles in the [Entra admin center](https://entra.microsoft.com) (Roles and administrators → search for the role). Allow 5–15 minutes for the role to propagate after assignment.

#### Gate 2: Fabric Tenant Provisioning

Even with the Entra role, the Fabric Admin Portal and tenant-settings API return nothing until Fabric is provisioned on your tenant. Choose one:

- **Fastest:** Sign up for [Microsoft Fabric Free](https://app.fabric.microsoft.com) — click "Start trial" or the free tier signup button
- **Trial:** Start a Fabric Trial
- **Capacity:** Have an F-SKU capacity provisioned

After provisioning, verify access: navigate to [https://app.fabric.microsoft.com/admin-portal](https://app.fabric.microsoft.com/admin-portal). If you see the admin portal, both gates are open.

#### Gate 3: Enable Tenant Settings

Now that you have the Entra role and Fabric is provisioned, enable these tenant settings:

1. **Users can create Fabric items** (`FabricGAWorkloads`) — the "Microsoft Fabric" admin switch. Enable for the tenant or a security group. *(Note: "Microsoft Fabric" is a section header in the admin portal, not a separate API setting — this single toggle controls it.)*
2. **Configure workspace-level inbound network rules** (`WorkspaceBlockInboundAccess`) — enables workspace admins to restrict inbound public access (required for workspace-level private endpoints). Re-register `Microsoft.Fabric` provider afterward.
3. **Service principals can call Fabric public APIs** (`ServicePrincipalAccessGlobalAPIs`) — enable if running Terraform as a service principal.

Run the helper script to automate this:

```powershell
./configure-fabric-tenant-settings.ps1
```

Or configure manually via the Fabric Admin Portal (Admin portal → Tenant settings).

After toggling workspace-level inbound network rules, re-register the Fabric provider:

```sh
az provider register --namespace Microsoft.Fabric
```

## Quick Start

```sh
cd Fabric-private
cp terraform.tfvars.example terraform.tfvars   # edit if needed
terraform init
terraform plan
terraform apply
```

## Variables

| Variable                           | Default              | Purpose                                                           |
| ---------------------------------- | -------------------- | ----------------------------------------------------------------- |
| `resource_group_name`              | `"rg-fabric00"`      | Resource group name prefix                                        |
| `fabric_vnet_address_space`        | `["172.20.80.0/20"]` | VNet address range (Block 5)                                      |
| `pe_subnet_address`                | `["172.20.80.0/24"]` | PE subnet CIDR                                                    |
| `fabric_capacity_sku`              | `"F2"`               | Fabric capacity SKU                                               |
| `capacity_admin_upn_list`          | `[]`                 | UPNs for capacity admins (or use group OID)                       |
| `capacity_admin_group_object_id`   | `null`               | Entra group OID for capacity admins (recommended for shared labs) |
| `workspace_content_mode`           | `"none"`             | Only `none` supported; `lakehouse` reserved for future            |
| `restrict_workspace_public_access` | `true`               | Private-only by default — set to `false` to allow public access alongside the workspace PE |

For shared lab deployments, set `capacity_admin_group_object_id` to a security group containing all operators. The zero-config default uses the current `az` signed-in user.

## Outputs

| Output                              | Purpose                                   |
| ----------------------------------- | ----------------------------------------- |
| `resource_group_id`                 | Resource group ID                         |
| `fabric_capacity_id`                | Fabric capacity ID                        |
| `fabric_workspace_id`               | Fabric workspace ID                       |
| `storage_account_id`                | Lab storage account ID                    |
| `sql_server_id`                     | Lab SQL server ID                         |
| `key_vault_id`                      | Workspace-local Key Vault ID              |
| `mpe_storage_id`                    | Storage blob MPE ID                       |
| `mpe_sql_id`                        | SQL Server MPE ID                         |
| `mpe_keyvault_id`                   | Key Vault MPE ID                          |
| `workspace_private_link_service_id` | Fabric private link service ARM ID        |
| `workspace_private_endpoint_id`     | Fabric workspace private endpoint ID      |
| `workspace_private_endpoint_ip`     | Private IP assigned to the workspace PE   |

## Security Posture

### Private Connectivity

The workspace has two connectivity paths:

- **Inbound:** The workspace-level private endpoint in your spoke VNet allows client connections via the private network. By default, the workspace is **private-only** — public access is blocked. Set `restrict_workspace_public_access = false` to allow public access alongside the private endpoint.
- **Outbound:** The workspace runs in a Microsoft-managed VNet with no direct access to your network. It reaches shared lab resources (Storage, SQL) via 3 Managed Private Endpoints. The workspace reaches its own Key Vault (deployed in this resource group) via a dedicated MPE and DNS resolution.

The workspace-local Key Vault is used for workspace secrets. The workspace managed identity accesses it exclusively via the MPE; there is no dependency on or access to the shared Networking Key Vault.

### Private-Only Access (Default)

By default (`restrict_workspace_public_access = true`), the workspace blocks all public internet access. Users must connect via the private endpoint (Bastion, VPN, ExpressRoute, or any network with DNS resolution to the PE subnet). The Fabric portal shell (`app.fabric.microsoft.com`) still loads over the public internet, but workspace API calls are blocked unless the caller is on a network with the private endpoint. This is workspace-scoped and independent of any tenant-level settings.

Prerequisites: The workspace private endpoint must be deployed and DNS (`privatelink.fabric.microsoft.com`) must resolve to the PE's private IP.

> **⏱ Propagation delay:** After `terraform apply`, the workspace communication policy (`defaultAction: Deny`) can take **up to 30 minutes** to take full effect per [Microsoft docs](https://learn.microsoft.com/en-us/fabric/security/security-workspace-level-private-links-set-up). The workspace may still be reachable from the public internet briefly after apply completes — this is expected behavior, not a bug.

To allow public access alongside the private endpoint (the old default), set `restrict_workspace_public_access = false` in your tfvars.

### Tenant-Level Private Link — Out of Scope

Tenant-level private link (`BlockPublicNetworkAccess`) is not configured by this module. That is a tenant-admin setting with implications beyond a single workspace. See [Private links for Fabric tenants](https://learn.microsoft.com/fabric/security/security-private-links-overview) for details. Workspace-level private-only mode (above) is sufficient for lab isolation without tenant-wide blast radius.

## Destroy Procedure

### Step 1: Destroy the module

```sh
cd Fabric-private
terraform destroy
```

### Step 2: Capacity and workspace cleanup

- Do NOT pause the capacity before destroy — destroy from `Active` state. If already paused, resume first: `az fabric capacity resume --resource-group <rg> --capacity-name <name>`
- Fabric workspaces enter soft-delete for ~90 days. The workspace name uses a random suffix, so name collisions on re-deploy are unlikely.
- SQL server names are reserved for ~7 days post-delete. Same random suffix mitigates.
- The workspace-local Key Vault has soft-delete enabled with **7-day retention** (Azure mandatory; minimum set for fast lab redeploys) and purge protection disabled. Re-deploy is unblocked — no extended wait. If a same-named KV exists in soft-deleted state (e.g., suffix collision), purge it first: `az keyvault purge --name <kv-name>`

### Important

Do NOT toggle the "Configure workspace-level inbound network rules" tenant setting during a deploy lifecycle. If toggled, re-register `Microsoft.Fabric` afterward.
