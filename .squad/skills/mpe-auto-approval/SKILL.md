---
name: "mpe-auto-approval"
description: "Terraform pattern for auto-approving Fabric Managed Private Endpoint connections on Azure target resources"
domain: "private-endpoints, terraform, azapi"
confidence: "high"
source: "earned — implemented in Fabric-byoVnet module (April 2026)"
---

## Context

When Microsoft Fabric creates a Managed Private Endpoint (MPE), the PE connection on the target Azure resource (Storage, SQL, Key Vault) always lands in `Pending` state. Azure has no platform auto-approval for Fabric MPEs. Terraform must approve each one explicitly after creation.

This pattern applies to any Fabric workspace with MPE outbound connectivity to Azure PaaS services.

## Patterns

### 1. Create the MPE

```hcl
resource "fabric_workspace_managed_private_endpoint" "mpe_storage" {
  workspace_id                    = fabric_workspace.workspace.id
  name                            = "mpe-storage-blob-${random_string.unique.result}"
  target_private_link_resource_id = azurerm_storage_account.lab_storage.id
  target_subresource_type         = "blob"
  request_message                 = "Auto-created by Terraform module"
}
```

### 2. List PE connections on the target (reads after MPE creation)

```hcl
data "azapi_resource_list" "storage_pe_connections" {
  type       = "Microsoft.Storage/storageAccounts/privateEndpointConnections@2023-05-01"
  parent_id  = azurerm_storage_account.lab_storage.id
  depends_on = [fabric_workspace_managed_private_endpoint.mpe_storage]
}
```

`depends_on` forces the data source to read during apply (after the MPE exists), not during plan.

### 3. Filter by PE resource ID (not name, not state)

```hcl
locals {
  storage_pe_conn_name = one([
    for conn in try(data.azapi_resource_list.storage_pe_connections.output.value, []) :
    conn.name
    if lower(try(conn.properties.privateEndpoint.id, "")) == lower(fabric_workspace_managed_private_endpoint.mpe_storage.id)
  ])
}
```

Critical: use `lower()` for case-insensitive ARM ID comparison. Use `try()` with default `""` to handle connections that lack a PE reference. Use `one()` to fail explicitly if no match (or multiple matches) found.

### 4. PATCH to Approved

```hcl
resource "azapi_resource_action" "approve_mpe_storage" {
  type        = "Microsoft.Storage/storageAccounts/privateEndpointConnections@2023-05-01"
  resource_id = "${azurerm_storage_account.lab_storage.id}/privateEndpointConnections/${local.storage_pe_conn_name}"
  method      = "PUT"
  body = {
    properties = {
      privateLinkServiceConnectionState = {
        status      = "Approved"
        description = "Auto-approved by Terraform module"
      }
    }
  }
}
```

### 5. Post-apply assertion

```hcl
check "mpe_storage_approved" {
  data "azapi_resource" "mpe_storage_conn" {
    type                   = "Microsoft.Storage/storageAccounts/privateEndpointConnections@2023-05-01"
    resource_id            = "${azurerm_storage_account.lab_storage.id}/privateEndpointConnections/${local.storage_pe_conn_name}"
    response_export_values = ["properties.privateLinkServiceConnectionState.status"]
  }
  assert {
    condition     = data.azapi_resource.mpe_storage_conn.output.properties.privateLinkServiceConnectionState.status == "Approved"
    error_message = "MPE to Storage is not Approved. Manual intervention required."
  }
}
```

### Target-specific API versions

| Target | API type path | Version |
|--------|--------------|---------|
| Storage Account | `Microsoft.Storage/storageAccounts/privateEndpointConnections` | `2023-05-01` |
| SQL Server | `Microsoft.Sql/servers/privateEndpointConnections` | `2023-08-01-preview` |
| Key Vault | `Microsoft.KeyVault/vaults/privateEndpointConnections` | `2023-07-01` |

## Anti-Patterns

- **Filter by "first Pending"** — on shared resources (e.g., Networking Key Vault), other modules or prior failed deploys may leave Pending connections. Approving the wrong one is a security risk.
- **Filter by name pattern** — Fabric-generated PE connection names are not deterministic and may change across provider versions.
- **Filter by state alone** — multiple connections can be in Pending state simultaneously.
- **Skip the check block** — silent Pending is the primary failure mode. The workspace silently loses private connectivity with no apply-time error. Always assert Approved.
- **Forget destroy cleanup** — `azapi_resource_action` has no destroy semantics. Orphaned Approved PE connections accumulate on shared resources (especially KV with its 25-connection limit).

## Fabric Provider Schema Notes (v1.9.x)

```
fabric_workspace_role_assignment:
  principal = { id = "...", type = "User|Group|ServicePrincipal|ServicePrincipalProfile" }
  role = "Admin|Member|Contributor|Viewer"

fabric_workspace_managed_private_endpoint:
  target_private_link_resource_id  (NOT target_private_link_service_id)
  request_message                  (required, free-text justification)
  target_subresource_type          (e.g., "blob", "sqlServer", "vault")
```
