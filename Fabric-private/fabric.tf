########## Fabric Capacity & Workspace
##########

resource "azurerm_fabric_capacity" "fabric_capacity" {
  name                = "fabriccap${random_string.unique.result}"
  resource_group_name = azurerm_resource_group.rg_fabric00.name
  location            = azurerm_resource_group.rg_fabric00.location

  sku {
    name = var.fabric_capacity_sku
    tier = "Fabric"
  }

  administration_members = local.capacity_admins
  tags                   = local.common_tags
}

resource "fabric_workspace" "workspace" {
  display_name = "fabric-workspace-${random_string.unique.result}"
  capacity_id  = azurerm_fabric_capacity.fabric_capacity.id
  description  = "Fabric workspace for BYO VNet lab deployment"
}

resource "fabric_workspace_role_assignment" "operator_admin" {
  workspace_id = fabric_workspace.workspace.id
  role         = "Admin"

  principal = {
    id   = data.azurerm_client_config.current.object_id
    type = "User"
  }
}

########## Lab Storage Account (MPE target — no conventional Azure PE)
##########

resource "azurerm_storage_account" "lab_storage" {
  name                = "fabstor${random_string.unique.result}"
  resource_group_name = azurerm_resource_group.rg_fabric00.name
  location            = azurerm_resource_group.rg_fabric00.location

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  shared_access_key_enabled       = false
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false
  tags                            = local.common_tags

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
}

########## Lab Azure SQL Server & Database (MPE target — Entra-only auth)
##########

resource "azurerm_mssql_server" "lab_sql" {
  name                          = "fabsql${random_string.unique.result}"
  resource_group_name           = azurerm_resource_group.rg_fabric00.name
  location                      = azurerm_resource_group.rg_fabric00.location
  version                       = "12.0"
  public_network_access_enabled = false
  minimum_tls_version           = "1.2"
  tags                          = local.common_tags

  azuread_administrator {
    login_username              = local.capacity_admins[0]
    object_id                   = data.azurerm_client_config.current.object_id
    azuread_authentication_only = true
  }
}

resource "azurerm_mssql_database" "lab_db" {
  name      = "fabdb${random_string.unique.result}"
  server_id = azurerm_mssql_server.lab_sql.id
  sku_name  = "Basic"
  tags      = local.common_tags
}

########## Workspace Private Endpoint + DNS Zone Group
##########

# VERIFY at first deploy: the PLS resource ID format for workspace-level PE.
# The target is Microsoft.Fabric/privateLinkServicesForFabric/{workspace-guid}.
# If fabric_workspace.workspace.id includes a path prefix, adjust the construction below.
resource "azurerm_private_endpoint" "pe_workspace" {
  name                = "fabric-workspace-pe-${random_string.unique.result}"
  resource_group_name = azurerm_resource_group.rg_fabric00.name
  location            = azurerm_resource_group.rg_fabric00.location
  subnet_id           = azurerm_subnet.pe_subnet.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "fabric-workspace-pls-connection"
    private_connection_resource_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Fabric/privateLinkServicesForFabric/${fabric_workspace.workspace.id}"
    subresource_names              = ["workspace"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "fabric-workspace-dns-config"
    private_dns_zone_ids = [
      data.terraform_remote_state.networking.outputs.dns_zone_fabric_id
    ]
  }

  depends_on = [fabric_workspace.workspace]
}

########## Diagnostic Settings — send capacity logs to platform LAW
##########

resource "azurerm_monitor_diagnostic_setting" "fabric_capacity_diag" {
  name                       = "fabric-capacity-diag-${random_string.unique.result}"
  target_resource_id         = azurerm_fabric_capacity.fabric_capacity.id
  log_analytics_workspace_id = data.terraform_remote_state.networking.outputs.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "AllMetrics"
  }
}
