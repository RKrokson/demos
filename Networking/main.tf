## Region 0 permanent resources
resource "azurerm_resource_group" "rg-net00" {
  name     = "${var.resource_group_name_net00}-${var.azure_region_0_abbr}-${local.suffix}"
  location = var.azure_region_0_name
  tags     = local.common_tags
}
resource "azurerm_log_analytics_workspace" "law00" {
  name                = "${var.log_analytics_workspace_name}-${var.azure_region_0_abbr}"
  resource_group_name = local.rg00_name
  location            = local.rg00_location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}
resource "azurerm_virtual_network" "shared_vnet00" {
  name                = "${var.shared_vnet_name00}-${var.azure_region_0_abbr}"
  address_space       = var.shared_vnet_address_space00
  location            = local.rg00_location
  resource_group_name = local.rg00_name
  tags                = local.common_tags
}
resource "azurerm_subnet" "shared_subnet00" {
  name                 = "${var.shared_subnet_name00}-${var.shared_vnet_name00}-${var.azure_region_0_abbr}"
  resource_group_name  = local.rg00_name
  virtual_network_name = azurerm_virtual_network.shared_vnet00.name
  address_prefixes     = var.shared_subnet_address00
}
resource "azurerm_subnet" "app_subnet00" {
  name                 = "${var.app_subnet_name00}-${var.shared_vnet_name00}-${var.azure_region_0_abbr}"
  resource_group_name  = local.rg00_name
  virtual_network_name = azurerm_virtual_network.shared_vnet00.name
  address_prefixes     = var.app_subnet_address00
}
resource "azurerm_subnet" "bastion_subnet00" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = local.rg00_name
  virtual_network_name = azurerm_virtual_network.shared_vnet00.name
  address_prefixes     = var.bastion_subnet_address00
}
resource "azurerm_virtual_hub_connection" "vhub_connection00" {
  name                      = "${var.azurerm_virtual_hub_connection_vhub00_to_shared00}-${var.azure_region_0_abbr}"
  virtual_hub_id            = azurerm_virtual_hub.vhub00.id
  remote_virtual_network_id = azurerm_virtual_network.shared_vnet00.id
  internet_security_enabled = var.add_firewall00
}
# Optional vHub 01 resources
resource "azurerm_resource_group" "rg-net01" {
  count    = var.create_vhub01 ? 1 : 0
  name     = "${var.resource_group_name_net01}-${var.azure_region_1_abbr}-${local.suffix}"
  location = var.azure_region_1_name
  tags     = local.common_tags
}
resource "azurerm_virtual_network" "shared_vnet01" {
  count               = var.create_vhub01 ? 1 : 0
  name                = "${var.shared_vnet_name01}-${var.azure_region_1_abbr}"
  address_space       = var.shared_vnet_address_space01
  location            = azurerm_resource_group.rg-net01[0].location
  resource_group_name = azurerm_resource_group.rg-net01[0].name
  tags                = local.common_tags
}
resource "azurerm_subnet" "shared_subnet01" {
  count                = var.create_vhub01 ? 1 : 0
  name                 = "${var.shared_subnet_name01}-${var.shared_vnet_name01}-${var.azure_region_1_abbr}"
  resource_group_name  = azurerm_resource_group.rg-net01[0].name
  virtual_network_name = azurerm_virtual_network.shared_vnet01[0].name
  address_prefixes     = var.shared_subnet_address01
}
resource "azurerm_subnet" "app_subnet01" {
  count                = var.create_vhub01 ? 1 : 0
  name                 = "${var.app_subnet_name01}-${var.shared_vnet_name01}-${var.azure_region_1_abbr}"
  resource_group_name  = azurerm_resource_group.rg-net01[0].name
  virtual_network_name = azurerm_virtual_network.shared_vnet01[0].name
  address_prefixes     = var.app_subnet_address01
}
resource "azurerm_subnet" "bastion_subnet01" {
  count                = var.create_vhub01 ? 1 : 0
  name                 = var.bastion_subnet_name01
  resource_group_name  = azurerm_resource_group.rg-net01[0].name
  virtual_network_name = azurerm_virtual_network.shared_vnet01[0].name
  address_prefixes     = var.bastion_subnet_address01
}
resource "azurerm_virtual_hub_connection" "vhub_connection01" {
  count                     = var.create_vhub01 ? 1 : 0
  name                      = var.azurerm_virtual_hub_connection_vhub01_to_shared01
  virtual_hub_id            = azurerm_virtual_hub.vhub01[0].id
  remote_virtual_network_id = azurerm_virtual_network.shared_vnet01[0].id
  internet_security_enabled = var.add_firewall01
}

