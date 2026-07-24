########## Application Landing Zone — Spoke VNet & Connectivity
##########

# AI spoke VNet for this Foundry module
resource "azurerm_virtual_network" "ai_vnet" {
  name                = "${var.ai_vnet_name}-${local.platform_region0.region_abbr}-${random_string.unique.result}"
  address_space       = var.ai_vnet_address_space
  location            = azurerm_resource_group.rg-ai01.location
  resource_group_name = azurerm_resource_group.rg-ai01.name
  tags                = local.common_tags
}

# Private endpoint subnet
resource "azurerm_subnet" "private_endpoint_subnet" {
  name                            = "${var.private_endpoint_subnet_name}-${local.platform_region0.region_abbr}"
  resource_group_name             = azurerm_resource_group.rg-ai01.name
  virtual_network_name            = azurerm_virtual_network.ai_vnet.name
  address_prefixes                = var.private_endpoint_subnet_address
  default_outbound_access_enabled = !local.platform_region0.firewall_enabled
}

# NSG for private endpoint subnet (default-deny inbound)
resource "azurerm_network_security_group" "pe_subnet_nsg" {
  name                = "${var.private_endpoint_subnet_name}-nsg-${local.platform_region0.region_abbr}-${random_string.unique.result}"
  location            = azurerm_resource_group.rg-ai01.location
  resource_group_name = azurerm_resource_group.rg-ai01.name
  tags                = local.common_tags
}

resource "azurerm_subnet_network_security_group_association" "pe_subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.private_endpoint_subnet.id
  network_security_group_id = azurerm_network_security_group.pe_subnet_nsg.id
}

# Connect AI spoke VNet to vHub
resource "azurerm_virtual_hub_connection" "vhub_connection_to_ai" {
  name                      = "vhub00-to-${var.ai_vnet_name}-${random_string.unique.result}"
  virtual_hub_id            = local.platform_region0.vhub_id
  remote_virtual_network_id = azurerm_virtual_network.ai_vnet.id
  internet_security_enabled = local.platform_region0.firewall_enabled
}

# Custom DNS servers on VNet — platform decides the IP (firewall or resolver)
resource "azurerm_virtual_network_dns_servers" "ai_vnet_dns" {
  virtual_network_id = azurerm_virtual_network.ai_vnet.id
  dns_servers        = [local.platform_region0.dns_server_ip]
}

# Link VNet to DNS resolver policy
resource "azapi_resource" "dns_security_policy_ai_vnet_link" {
  type      = "Microsoft.Network/dnsResolverPolicies/virtualNetworkLinks@2023-07-01-preview"
  name      = "vnet-link-to-dns-policy-${var.ai_vnet_name}-${random_string.unique.result}"
  parent_id = local.platform_region0.dns_resolver_policy_id
  location  = azurerm_resource_group.rg-ai01.location

  body = {
    properties = {
      virtualNetwork = {
        id = azurerm_virtual_network.ai_vnet.id
      }
    }
  }
}