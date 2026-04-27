########## Managed Private Endpoints — Fabric workspace → shared resources
##########
# Fabric MPEs always land in "Pending" on the target resource.
# No platform auto-approval exists — Terraform must approve each one.
# Pattern: create MPE → list target PE connections → filter by PE resource ID → PATCH to Approved.

# ─────────────────────────────────────────────
# MPE 1: Fabric → Lab Storage Account (blob)
# ─────────────────────────────────────────────

resource "fabric_workspace_managed_private_endpoint" "mpe_storage" {
  workspace_id                    = fabric_workspace.workspace.id
  name                            = "mpe-storage-blob-${random_string.unique.result}"
  target_private_link_resource_id = azurerm_storage_account.lab_storage.id
  target_subresource_type         = "blob"
  request_message                 = "Auto-created by Fabric-byoVnet Terraform module"
}

data "azapi_resource_list" "storage_pe_connections" {
  type       = "Microsoft.Storage/storageAccounts/privateEndpointConnections@2023-05-01"
  parent_id  = azurerm_storage_account.lab_storage.id
  depends_on = [fabric_workspace_managed_private_endpoint.mpe_storage]
}

resource "azapi_resource_action" "approve_mpe_storage" {
  type        = "Microsoft.Storage/storageAccounts/privateEndpointConnections@2023-05-01"
  resource_id = "${azurerm_storage_account.lab_storage.id}/privateEndpointConnections/${local.storage_pe_conn_name}"
  method      = "PUT"

  body = {
    properties = {
      privateLinkServiceConnectionState = {
        status      = "Approved"
        description = "Auto-approved by Fabric-byoVnet Terraform module"
      }
    }
  }
}

# ─────────────────────────────────────────────
# MPE 2: Fabric → Lab SQL Server
# ─────────────────────────────────────────────

resource "fabric_workspace_managed_private_endpoint" "mpe_sql" {
  workspace_id                    = fabric_workspace.workspace.id
  name                            = "mpe-sql-${random_string.unique.result}"
  target_private_link_resource_id = azurerm_mssql_server.lab_sql.id
  target_subresource_type         = "sqlServer"
  request_message                 = "Auto-created by Fabric-byoVnet Terraform module"
}

data "azapi_resource_list" "sql_pe_connections" {
  type       = "Microsoft.Sql/servers/privateEndpointConnections@2023-08-01-preview"
  parent_id  = azurerm_mssql_server.lab_sql.id
  depends_on = [fabric_workspace_managed_private_endpoint.mpe_sql]
}

resource "azapi_resource_action" "approve_mpe_sql" {
  type        = "Microsoft.Sql/servers/privateEndpointConnections@2023-08-01-preview"
  resource_id = "${azurerm_mssql_server.lab_sql.id}/privateEndpointConnections/${local.sql_pe_conn_name}"
  method      = "PUT"

  body = {
    properties = {
      privateLinkServiceConnectionState = {
        status      = "Approved"
        description = "Auto-approved by Fabric-byoVnet Terraform module"
      }
    }
  }
}

# ─────────────────────────────────────────────
# MPE 3: Fabric → Networking Key Vault (shared resource)
# The KV is shared across all ALZs — the lookup MUST tolerate
# other existing PE connections from prior deploys or other modules.
# ─────────────────────────────────────────────

resource "fabric_workspace_managed_private_endpoint" "mpe_keyvault" {
  workspace_id                    = fabric_workspace.workspace.id
  name                            = "mpe-keyvault-${random_string.unique.result}"
  target_private_link_resource_id = data.terraform_remote_state.networking.outputs.key_vault_id
  target_subresource_type         = "vault"
  request_message                 = "Auto-created by Fabric-byoVnet Terraform module"
}

data "azapi_resource_list" "kv_pe_connections" {
  type       = "Microsoft.KeyVault/vaults/privateEndpointConnections@2023-07-01"
  parent_id  = data.terraform_remote_state.networking.outputs.key_vault_id
  depends_on = [fabric_workspace_managed_private_endpoint.mpe_keyvault]
}

resource "azapi_resource_action" "approve_mpe_keyvault" {
  type        = "Microsoft.KeyVault/vaults/privateEndpointConnections@2023-07-01"
  resource_id = "${data.terraform_remote_state.networking.outputs.key_vault_id}/privateEndpointConnections/${local.kv_pe_conn_name}"
  method      = "PUT"

  body = {
    properties = {
      privateLinkServiceConnectionState = {
        status      = "Approved"
        description = "Auto-approved by Fabric-byoVnet Terraform module"
      }
    }
  }
}

# ─────────────────────────────────────────────
# PE connection name lookup — filter by MPE resource ID (M2 requirement)
# NEVER filter by "first Pending", name pattern, or state alone.
# ─────────────────────────────────────────────

locals {
  storage_pe_conn_name = one([
    for conn in try(data.azapi_resource_list.storage_pe_connections.output.value, []) :
    conn.name
    if lower(try(conn.properties.privateEndpoint.id, "")) == lower(fabric_workspace_managed_private_endpoint.mpe_storage.id)
  ])

  sql_pe_conn_name = one([
    for conn in try(data.azapi_resource_list.sql_pe_connections.output.value, []) :
    conn.name
    if lower(try(conn.properties.privateEndpoint.id, "")) == lower(fabric_workspace_managed_private_endpoint.mpe_sql.id)
  ])

  # KV lookup tolerates other existing connections — strict filter by this MPE's resource ID only
  kv_pe_conn_name = one([
    for conn in try(data.azapi_resource_list.kv_pe_connections.output.value, []) :
    conn.name
    if lower(try(conn.properties.privateEndpoint.id, "")) == lower(fabric_workspace_managed_private_endpoint.mpe_keyvault.id)
  ])
}

# ─────────────────────────────────────────────
# Post-apply assertions — verify each MPE reached Approved state
# check {} blocks re-evaluate at end of apply; silent Pending is the failure mode.
# ─────────────────────────────────────────────

check "mpe_storage_approved" {
  data "azapi_resource" "mpe_storage_conn" {
    type                   = "Microsoft.Storage/storageAccounts/privateEndpointConnections@2023-05-01"
    resource_id            = "${azurerm_storage_account.lab_storage.id}/privateEndpointConnections/${local.storage_pe_conn_name}"
    response_export_values = ["properties.privateLinkServiceConnectionState.status"]
  }
  assert {
    condition     = data.azapi_resource.mpe_storage_conn.output.properties.privateLinkServiceConnectionState.status == "Approved"
    error_message = "MPE to Storage (blob) is not Approved after auto-approval. Run: az network private-endpoint-connection approve"
  }
}

check "mpe_sql_approved" {
  data "azapi_resource" "mpe_sql_conn" {
    type                   = "Microsoft.Sql/servers/privateEndpointConnections@2023-08-01-preview"
    resource_id            = "${azurerm_mssql_server.lab_sql.id}/privateEndpointConnections/${local.sql_pe_conn_name}"
    response_export_values = ["properties.privateLinkServiceConnectionState.status"]
  }
  assert {
    condition     = data.azapi_resource.mpe_sql_conn.output.properties.privateLinkServiceConnectionState.status == "Approved"
    error_message = "MPE to SQL Server is not Approved after auto-approval. Run: az network private-endpoint-connection approve"
  }
}

check "mpe_keyvault_approved" {
  data "azapi_resource" "mpe_kv_conn" {
    type                   = "Microsoft.KeyVault/vaults/privateEndpointConnections@2023-07-01"
    resource_id            = "${data.terraform_remote_state.networking.outputs.key_vault_id}/privateEndpointConnections/${local.kv_pe_conn_name}"
    response_export_values = ["properties.privateLinkServiceConnectionState.status"]
  }
  assert {
    condition     = data.azapi_resource.mpe_kv_conn.output.properties.privateLinkServiceConnectionState.status == "Approved"
    error_message = "MPE to Key Vault is not Approved. The shared Networking KV may have stale PE connections — see README destroy procedure for cleanup."
  }
}
