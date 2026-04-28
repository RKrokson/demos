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

# NOTE: Workspace-level private endpoints (Microsoft.Fabric/privateLinkServicesForFabric)
# are NOT a valid ARM resource type. Fabric private connectivity is tenant-scoped
# via Microsoft.PowerBI/privateLinkServicesForPowerBI — not per-workspace.
# Inbound traffic restriction is enforced via workspace_communication_policy below.
