# Application Landing Zone — Microsoft Fabric (BYO VNet)

This is an optional application landing zone. It deploys a Microsoft Fabric capacity and workspace with private inbound connectivity (workspace-level PE) and private outbound connectivity (3 Managed Private Endpoints to shared Storage, SQL, and Key Vault) into its own spoke VNet.

The module creates the VNet, subnets, and hub connection. You do not need to deploy this to use the Networking module on its own.

## What It Deploys

| Resource | Purpose |
|----------|---------|
| Fabric Capacity (F2) | Compute capacity for the workspace |
| Fabric Workspace | Container for Fabric items |
| Workspace PE | Private inbound path to the workspace |
| Lab Storage Account | Blob storage target for Fabric MPE |
| Lab Azure SQL Server + DB | SQL target for Fabric MPE |
| 3 Managed Private Endpoints | Outbound private paths from Fabric to Storage (blob), SQL, and shared Networking KV |
| Spoke VNet (Block 5) | `172.20.80.0/20` with PE subnet |
| NSG | Explicit allow rules on PE subnet (443, 1433) |
| vHub connection | Connects spoke to platform Virtual WAN hub |
| DNS resolver policy link | Private DNS resolution via platform DNS |
| Diagnostic settings | Capacity logs/metrics to platform LAW |

## Prerequisites

- All [platform landing zone prerequisites](../README.md#prerequisites)
- Platform Landing Zone (`Networking/`) applied first with `add_private_dns00 = true`
- DNS zone outputs available: `dns_zone_fabric_id`, `dns_zone_sql_id`, `dns_zone_blob_id`, `dns_zone_vaultcore_id`
- **One-time tenant configuration** — run `configure-fabric-tenant-settings.ps1` before first deploy (see below)

### Tenant Setup (One-Time)

Before your first deploy, a Fabric Administrator must enable these tenant settings:

1. **Microsoft Fabric** — enable for the tenant or a security group
2. **Configure workspace-level inbound network rules** — enable (then re-register `Microsoft.Fabric` provider)
3. **Users can create Fabric items** — enable
4. **Service principals can call Fabric public APIs** — enable if running Terraform as a service principal

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
cd Fabric-byoVnet
cp terraform.tfvars.example terraform.tfvars   # edit if needed
terraform init
terraform plan
terraform apply
```

## Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `resource_group_name` | `"rg-fabric00"` | Resource group name prefix |
| `fabric_vnet_address_space` | `["172.20.80.0/20"]` | VNet address range (Block 5) |
| `pe_subnet_address` | `["172.20.80.0/24"]` | PE subnet CIDR |
| `fabric_capacity_sku` | `"F2"` | Fabric capacity SKU |
| `capacity_admin_upn_list` | `[]` | UPNs for capacity admins (or use group OID) |
| `capacity_admin_group_object_id` | `null` | Entra group OID for capacity admins (recommended for shared labs) |
| `workspace_content_mode` | `"none"` | Only `none` supported; `lakehouse` reserved for future |

For shared lab deployments, set `capacity_admin_group_object_id` to a security group containing all operators. The zero-config default uses the current `az` signed-in user.

## Outputs

| Output | Purpose |
|--------|---------|
| `resource_group_id` | Resource group ID |
| `fabric_capacity_id` | Fabric capacity ID |
| `fabric_workspace_id` | Fabric workspace ID |
| `storage_account_id` | Lab storage account ID |
| `sql_server_id` | Lab SQL server ID |
| `mpe_storage_id` | Storage blob MPE ID |
| `mpe_sql_id` | SQL Server MPE ID |
| `mpe_keyvault_id` | Key Vault MPE ID |

## Security Posture

> ⚠️ **Security posture note (M1 — resolved by Ryan):** This lab does **NOT** enable the tenant-wide **"Block Public Internet Access"** (`BlockPublicNetworkAccess`) setting.
>
> **Rationale:** Lab participants access the workspace via browser over the public internet. Enabling this setting would require all users to be inside the private network — breaking access for the vast majority of lab/POC audiences.
>
> **What this means:** The workspace PE deploys a private *additional* path — it does **not** enforce a private *only* path. The public endpoints (`app.fabric.microsoft.com` and all public Fabric APIs) remain fully reachable. Notebook outbound traffic to the public internet is also unrestricted.
>
> **Acceptable risk:** This is a lab/POC environment with synthetic data. This posture is acceptable under those conditions. **Do NOT load production or sensitive data without revisiting this decision** — if you do, enable `BlockPublicNetworkAccess` and ensure all participants have private network access.

The KV MPE creates a network path only — the workspace has no data-plane access to the Networking KV. Do not grant the workspace managed identity Key Vault access roles on the shared Networking KV. If notebooks need secrets, deploy a separate KV in the Fabric RG.

Data residency: Sweden Central — all Fabric compute and OneLake storage is EU-bound. Appropriate for GDPR-in-scope POC scenarios. Do not load real production data without confirming data classification requirements.

## Destroy Procedure

### Step 1: Destroy the module

```sh
cd Fabric-byoVnet
terraform destroy
```

### Step 2 (Required): Clean up orphaned KV PE connections

After `terraform destroy`, the `azapi_resource_action` approval steps have no destroy semantics. The `privateEndpointConnections` entry on the shared Networking Key Vault remains in `Approved` state even though the Fabric workspace and its MPE no longer exist.

**Why this matters:** Azure Key Vault has a maximum of **25 private endpoint connections** per instance. Orphaned connections accumulate across deploy/destroy cycles. After enough cycles, the KV can no longer accept new PE connections — affecting all modules that depend on it (Foundry-byoVnet, future modules, this module on next deploy).

**Cleanup steps:**

1. List orphaned connections on the Networking KV:

   ```sh
   az network private-endpoint-connection list \
     --id $(terraform -chdir=../Networking output -raw key_vault_id) \
     --query "[?properties.privateLinkServiceConnectionState.status=='Approved' && properties.privateEndpoint.id==null].{name:name, status:properties.privateLinkServiceConnectionState.status}" \
     -o table
   ```

2. Delete each orphaned connection:

   ```sh
   az network private-endpoint-connection delete \
     --id "<full-connection-resource-id>" \
     --yes
   ```

   Replace `<full-connection-resource-id>` with the full ID from the list output. If the PE's target resource no longer exists, the connection is safe to remove.

3. Verify the cleanup:

   ```sh
   az network private-endpoint-connection list \
     --id $(terraform -chdir=../Networking output -raw key_vault_id) \
     -o table
   ```

**If destroy fails on KV PE removal:** The KV PE connection may be in a stuck state. Use `az keyvault network-rule remove` or delete the connection directly via the Azure portal (Key Vault → Networking → Private endpoint connections).

### Step 3: Capacity and workspace cleanup

- Do NOT pause the capacity before destroy — destroy from `Active` state. If already paused, resume first: `az fabric capacity resume --resource-group <rg> --capacity-name <name>`
- Fabric workspaces enter soft-delete for ~90 days. The workspace name uses a random suffix, so name collisions on re-deploy are unlikely.
- SQL server names are reserved for ~7 days post-delete. Same random suffix mitigates.

### Important

Do NOT toggle the "Configure workspace-level inbound network rules" tenant setting during a deploy lifecycle. If toggled, re-register `Microsoft.Fabric` afterward.
