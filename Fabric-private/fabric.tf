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

# The fabric_workspace resource requires the Fabric-side capacity UUID, not the ARM resource ID.
# This data source looks up the UUID by display_name (which matches the ARM resource name).
data "fabric_capacity" "this" {
  display_name = azurerm_fabric_capacity.fabric_capacity.name
  depends_on   = [azurerm_fabric_capacity.fabric_capacity]
}

resource "fabric_workspace" "workspace" {
  display_name = "fabric-workspace-${random_string.unique.result}"
  capacity_id  = data.fabric_capacity.this.id
  description  = "Fabric workspace for Private lab deployment"
}

########## Local Key Vault (LZ-scoped, MPE target)
##########
# Lives in the Fabric LZ resource group so destroy doesn't leave orphaned PE
# connections on the shared Networking KV. Workspace reaches it via MPE 3.

resource "azurerm_key_vault" "fabric_kv" {
  name                = "kv-fabric-${data.terraform_remote_state.networking.outputs.azure_region_0_abbr}-${random_string.unique.result}"
  resource_group_name = azurerm_resource_group.rg_fabric00.name
  location            = azurerm_resource_group.rg_fabric00.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  enable_rbac_authorization     = true
  public_network_access_enabled = false
  purge_protection_enabled      = false
  soft_delete_retention_days    = 7

  tags = local.common_tags
}

resource "azurerm_private_endpoint" "pe_fabric_kv" {
  name                = "fabric-kv-pe-${random_string.unique.result}"
  resource_group_name = azurerm_resource_group.rg_fabric00.name
  location            = azurerm_resource_group.rg_fabric00.location
  subnet_id           = azurerm_subnet.pe_subnet.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "fabric-kv-pe-connection"
    private_connection_resource_id = azurerm_key_vault.fabric_kv.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "fabric-kv-dns-config"
    private_dns_zone_ids = [
      data.terraform_remote_state.networking.outputs.dns_zone_vaultcore_id
    ]
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

########## Workspace-Level Private Endpoint
##########
# Microsoft.Fabric/privateLinkServicesForFabric is a real ARM type (API 2024-06-01).
# It is workspace-scoped — completely distinct from the tenant-level
# Microsoft.PowerBI/privateLinkServicesForPowerBI type.
# Prerequisites (manual, out-of-band):
#   1. Fabric tenant setting "Configure workspace-level inbound network rules" enabled.
#   2. Microsoft.Fabric resource provider registered in the subscription.

resource "azapi_resource" "fabric_private_link_service" {
  type      = "Microsoft.Fabric/privateLinkServicesForFabric@2024-06-01"
  name      = "fabric-pls-${random_string.unique.result}"
  location  = "global"
  parent_id = azurerm_resource_group.rg_fabric00.id

  # Microsoft.Fabric/privateLinkServicesForFabric is not yet in the azapi provider's
  # bundled schema; disable local validation so azapi passes the request to ARM directly.
  schema_validation_enabled = false

  body = {
    properties = {
      tenantId    = data.azurerm_client_config.current.tenant_id
      workspaceId = fabric_workspace.workspace.id
    }
  }

  depends_on = [fabric_workspace.workspace]
}

resource "azurerm_private_endpoint" "pe_fabric_workspace" {
  name                = "fabric-workspace-pe-${random_string.unique.result}"
  resource_group_name = azurerm_resource_group.rg_fabric00.name
  location            = azurerm_resource_group.rg_fabric00.location
  subnet_id           = azurerm_subnet.pe_subnet.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "fabric-workspace-pe-connection"
    private_connection_resource_id = azapi_resource.fabric_private_link_service.id
    subresource_names              = ["workspace"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "fabric-workspace-dns-config"
    private_dns_zone_ids = [
      data.terraform_remote_state.networking.outputs.dns_zone_fabric_id
    ]
  }
}
