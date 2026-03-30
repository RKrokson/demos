resource "azurerm_virtual_wan" "vwan" {
  name                = "${var.azurerm_virtual_wan_name}-${local.suffix}"
  resource_group_name = local.rg00_name
  location            = local.rg00_location
  tags                = local.common_tags
}
resource "azurerm_virtual_hub" "vhub00" {
  name                   = "${var.azurerm_virtual_hub00_name}-${var.azure_region_0_abbr}"
  resource_group_name    = local.rg00_name
  location               = local.rg00_location
  virtual_wan_id         = azurerm_virtual_wan.vwan.id
  address_prefix         = var.azurerm_vhub00_address_prefix
  hub_routing_preference = var.azurerm_vhub00_route_pref
  tags                   = local.common_tags

  timeouts {
    create = "60m"
    delete = "60m"
  }
}
resource "azurerm_virtual_hub_routing_intent" "vhub_routing_intent00" {
  count          = var.add_firewall00 ? 1 : 0
  name           = "routing-policy-${var.azurerm_virtual_hub00_name}-${var.azure_region_0_abbr}"
  virtual_hub_id = azurerm_virtual_hub.vhub00.id
  routing_policy {
    name         = "InternetTrafficPolicy"
    destinations = ["Internet"]
    next_hop     = azurerm_firewall.fw00[0].id
  }
  routing_policy {
    name         = "PrivateTrafficPolicy"
    destinations = ["PrivateTraffic"]
    next_hop     = azurerm_firewall.fw00[0].id
  }
}
# Optional vHub 01
resource "azurerm_virtual_hub" "vhub01" {
  count                  = var.create_vhub01 ? 1 : 0
  name                   = "${var.azurerm_virtual_hub01_name}-${var.azure_region_1_abbr}"
  resource_group_name    = azurerm_resource_group.rg-net01[0].name
  location               = azurerm_resource_group.rg-net01[0].location
  virtual_wan_id         = azurerm_virtual_wan.vwan.id
  address_prefix         = var.azurerm_vhub01_address_prefix
  hub_routing_preference = var.azurerm_vhub01_route_pref
  tags                   = local.common_tags

  timeouts {
    create = "60m"
    delete = "60m"
  }
}
resource "azurerm_virtual_hub_routing_intent" "vhub_routing_intent01" {
  count          = var.create_vhub01 ? (var.add_firewall01 ? 1 : 0) : 0
  name           = "routing-policy-${var.azurerm_virtual_hub01_name}-${var.azure_region_1_abbr}"
  virtual_hub_id = azurerm_virtual_hub.vhub01[0].id
  routing_policy {
    name         = "InternetTrafficPolicy"
    destinations = ["Internet"]
    next_hop     = azurerm_firewall.fw01[0].id
  }
  routing_policy {
    name         = "PrivateTrafficPolicy"
    destinations = ["PrivateTraffic"]
    next_hop     = azurerm_firewall.fw01[0].id
  }
}
