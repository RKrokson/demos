# Pre-reqs and/or foundational resources
resource "random_string" "myrandom" {
  length = 3
  upper = false 
  special = false
  numeric = false   
}
data "azurerm_client_config" "current" {
}
# Random password generator
resource "random_password" "vm_password" {
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric  = true
}
resource "azurerm_resource_group" "rg-kv00" {
  name = "${var.resource_group_name_KV}-${var.azure_region_0_abbr}-${random_string.myrandom.id}"
  location = var.azure_region_0_name
}
resource "azurerm_key_vault" "kv00" {
  name                = "${var.kv_name}-${var.azure_region_0_abbr}"
  location            = azurerm_resource_group.rg-kv00.location
  resource_group_name = azurerm_resource_group.rg-kv00.name
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current.tenant_id
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = ["Get", "Set", "List", "Delete", "Purge"]
  }
}
resource "azurerm_key_vault_secret" "vm_password" {
  name         = var.kv_secret_name
  value        = random_password.vm_password.result
  key_vault_id = azurerm_key_vault.kv00.id
}
data "azurerm_key_vault_secret" "vm_password" {
  key_vault_id = azurerm_key_vault.kv00.id
  name         = var.kv_secret_name
  depends_on = [ azurerm_key_vault_secret.vm_password ]
}
# Region 0 permanent resources
resource "azurerm_resource_group" "rg-net00" {
  name = "${var.resource_group_name_net00}-${var.azure_region_0_abbr}-${random_string.myrandom.id}"
  location = var.azure_region_0_name
}
resource "azurerm_log_analytics_workspace" "law00" {
  name                = "${var.log_analytics_workspace_name}-${var.azure_region_0_abbr}"
  resource_group_name = azurerm_resource_group.rg-net00.name
  location            = azurerm_resource_group.rg-net00.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}
resource "azurerm_virtual_wan" "vwan" {
  name                = "${var.azurerm_virtual_wan_name}-${random_string.myrandom.id}"
  resource_group_name = azurerm_resource_group.rg-net00.name
  location            = azurerm_resource_group.rg-net00.location
}
resource "azurerm_virtual_hub" "vhub00" {
  name                = "${var.azurerm_virtual_hub00_name}-${var.azure_region_0_abbr}"
  resource_group_name = azurerm_resource_group.rg-net00.name
  location            = azurerm_resource_group.rg-net00.location
  virtual_wan_id      = azurerm_virtual_wan.vwan.id
  address_prefix      = var.azurerm_vhub00_address_prefix
  hub_routing_preference = var.azurerm_vhub00_route_pref
}
resource "azurerm_virtual_network" "shared_vnet00" {
  name                = "${var.shared_vnet_name00}-${var.azure_region_0_abbr}"
  address_space       = var.shared_vnet_address_space00
  location            = azurerm_resource_group.rg-net00.location
  resource_group_name = azurerm_resource_group.rg-net00.name
}
resource "azurerm_subnet" "shared_subnet00" {
  name                 = "${var.shared_subnet_name00}-${var.shared_vnet_name00}-${var.azure_region_0_abbr}"
  resource_group_name  = azurerm_resource_group.rg-net00.name
  virtual_network_name = azurerm_virtual_network.shared_vnet00.name
  address_prefixes     = var.shared_subnet_address00
}
resource "azurerm_subnet" "app_subnet00" {
  name                 = "${var.app_subnet_name00}-${var.shared_vnet_name00}-${var.azure_region_0_abbr}"
  resource_group_name  = azurerm_resource_group.rg-net00.name
  virtual_network_name = azurerm_virtual_network.shared_vnet00.name
  address_prefixes     = var.app_subnet_address00
}
resource "azurerm_subnet" "bastion_subnet00" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg-net00.name
  virtual_network_name = azurerm_virtual_network.shared_vnet00.name
  address_prefixes     = var.bastion_subnet_address00
}
resource "azurerm_public_ip" "bastion_pip00" {
  name                = "${var.bastion_pip_name00}-${var.azure_region_0_abbr}"
  location            = azurerm_resource_group.rg-net00.location
  resource_group_name = azurerm_resource_group.rg-net00.name
  allocation_method   = "Static"
  sku                 = "Standard"
}
resource "azurerm_bastion_host" "bastion_host00" {
  name                = "${var.bastion_host_name00}-${var.azure_region_0_abbr}"
  location            = azurerm_resource_group.rg-net00.location
  resource_group_name = azurerm_resource_group.rg-net00.name
  sku = var.bastion_host_sku00
  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion_subnet00.id
    public_ip_address_id = azurerm_public_ip.bastion_pip00.id
  }
}
resource "azurerm_virtual_hub_connection" "vhub_connection00" {
  name                      = "${var.azurerm_virtual_hub_connection_vhub00_to_shared00}-${var.azure_region_0_abbr}"
  virtual_hub_id            = azurerm_virtual_hub.vhub00.id
  remote_virtual_network_id = azurerm_virtual_network.shared_vnet00.id
}
resource "azurerm_virtual_network" "dns_vnet00" {
  count               = var.add_privateDNS00 ? 1 : 0
  name                = "${var.dns_vnet_name00}-${var.azure_region_0_abbr}"
  address_space       = var.dns_vnet_address_space00
  location            = azurerm_resource_group.rg-net00.location
  resource_group_name = azurerm_resource_group.rg-net00.name
}
resource "azurerm_subnet" "resolver_inbound_subnet00" {
  count               = var.add_privateDNS00 ? 1 : 0
  name                 = "${var.resolver_inbound_subnet_name00}-${var.dns_vnet_name00}-${var.azure_region_0_abbr}"
  resource_group_name  = azurerm_resource_group.rg-net00.name
  virtual_network_name = azurerm_virtual_network.dns_vnet00[0].name
  address_prefixes     = var.resolver_inbound_subnet_address00

  delegation {
    name = "Microsoft.Network.dnsResolvers"
    service_delegation {
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      name    = "Microsoft.Network/dnsResolvers"
    }
  }
}
resource "azurerm_subnet" "resolver_outbound_subnet00" {
  count               = var.add_privateDNS00 ? 1 : 0
  name                 = "${var.resolver_outbound_subnet_name00}-${var.dns_vnet_name00}-${var.azure_region_0_abbr}"
  resource_group_name  = azurerm_resource_group.rg-net00.name
  virtual_network_name = azurerm_virtual_network.dns_vnet00[0].name
  address_prefixes     = var.resolver_outbound_subnet_address00

  delegation {
    name = "Microsoft.Network.dnsResolvers"
    service_delegation {
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      name    = "Microsoft.Network/dnsResolvers"
    }
  }
}
module "private_dns00" {
  count               = var.add_privateDNS00 ? 1 : 0
  source = "Azure/avm-ptn-network-private-link-private-dns-zones/azurerm"
  location = azurerm_resource_group.rg-net00.location
  resource_group_name = azurerm_resource_group.rg-net00.name
  resource_group_creation_enabled = false
  virtual_network_resource_ids_to_link_to = {
    "dns_vnet00" = {
      vnet_resource_id = azurerm_virtual_network.dns_vnet00[0].id
    }
  }
}
resource "azurerm_virtual_hub_connection" "vhub_connection00-to-dns" {
  count               = var.add_privateDNS00 ? 1 : 0
  name                      = "${var.azurerm_virtual_hub_connection_vhub00_to_dns00}-${var.azure_region_0_abbr}"
  virtual_hub_id            = azurerm_virtual_hub.vhub00.id
  remote_virtual_network_id = azurerm_virtual_network.dns_vnet00[0].id
}
resource "azurerm_private_dns_resolver" "private_resolver00" {
  count               = var.add_privateDNS00 ? 1 : 0
  name                = "${var.private_resolver_name00}-${var.azure_region_0_abbr}"
  resource_group_name = azurerm_resource_group.rg-net00.name
  location            = azurerm_resource_group.rg-net00.location
  virtual_network_id  = azurerm_virtual_network.dns_vnet00[0].id
}
resource "azurerm_private_dns_resolver_inbound_endpoint" "private_resolver00_inbound00" {
  count               = var.add_privateDNS00 ? 1 : 0
  name                    = "${var.private_resolver_name00}-inbound00-${var.azure_region_0_abbr}"
  private_dns_resolver_id = azurerm_private_dns_resolver.private_resolver00[0].id
  location                = azurerm_resource_group.rg-net00.location
  depends_on = [
    azurerm_subnet.resolver_inbound_subnet00[0],
  ]
  ip_configurations {
    private_ip_allocation_method = "Static"
    subnet_id                    = azurerm_subnet.resolver_inbound_subnet00[0].id
    private_ip_address = var.resolver_inbound_endpoint_address00
  }
}
resource "azurerm_virtual_network_dns_servers" "shared_vnet00_dns" {
  count               = var.add_privateDNS00 ? 1 : 0
  virtual_network_id = azurerm_virtual_network.shared_vnet00.id
  dns_servers        = var.shared_vnet00_dns

  depends_on = [
    azurerm_subnet.resolver_inbound_subnet00[0],
    azurerm_subnet.resolver_outbound_subnet00[0]
  ]
}
resource "azurerm_private_dns_resolver_outbound_endpoint" "private_resolver00_outbound00" {
  count               = var.add_privateDNS00 ? 1 : 0
  name                    = "${var.private_resolver_name00}-outbound00-${var.azure_region_0_abbr}"
  private_dns_resolver_id = azurerm_private_dns_resolver.private_resolver00[0].id
  location                = azurerm_resource_group.rg-net00.location
  subnet_id               = azurerm_subnet.resolver_outbound_subnet00[0].id
}
resource "azurerm_firewall" "fw00" {
  count               = var.add_firewall00 ? 1 : 0
  name                = "${var.firewall_name00}-${var.azure_region_0_abbr}"
  location            = azurerm_resource_group.rg-net00.location
  resource_group_name = azurerm_resource_group.rg-net00.name
  sku_name            = var.firewall_SkuName00
  sku_tier            = var.firewall_SkuTier00
  zones               = ["1", "2", "3"]
  virtual_hub {
    virtual_hub_id      = azurerm_virtual_hub.vhub00.id
  }

  firewall_policy_id = azurerm_firewall_policy.fw00_policy[0].id
}
resource "azurerm_firewall_policy" "fw00_policy" {
  count               = var.add_firewall00 ? 1 : 0
  name                = "${var.firewall_policy_name00}-${var.azure_region_0_abbr}"
  location            = azurerm_resource_group.rg-net00.location
  resource_group_name = azurerm_resource_group.rg-net00.name
  sku = var.firewall_SkuTier00
}
resource "azurerm_firewall_policy_rule_collection_group" "fw00_policy_rcg" {
  count               = var.add_firewall00 ? 1 : 0
  name               = "${var.firewall_policy_rcg_name00}-${var.azure_region_0_abbr}"
  firewall_policy_id = azurerm_firewall_policy.fw00_policy[0].id
  priority           = 500
  network_rule_collection {
    name     = "network_rule_collection0"
    priority = 400
    action   = "Allow"
    rule {
      name                  = "network_rule_collection0_rule1"
      protocols             = ["TCP", "UDP", "ICMP"]
      source_addresses      = ["*"]
      destination_addresses = ["*"]
      destination_ports     = ["*"]
    }
  }
}
resource "azurerm_monitor_diagnostic_setting" "fw00_logs" {
  count               = var.add_firewall00 ? 1 : 0
  name               = "${var.firewall_logs_name00}-${var.azure_region_0_abbr}"
  target_resource_id = azurerm_firewall.fw00[0].id

  log_analytics_workspace_id = azurerm_log_analytics_workspace.law00.id
  enabled_log {
    category = "AzureFirewallApplicationRule"
  }
  enabled_log {
    category = "AzureFirewallNetworkRule"
  }
  enabled_log {
    category = "AzureFirewallDnsProxy"
  }
  metric {
    category = "AllMetrics"
  }
}
resource "azurerm_virtual_hub_routing_intent" "vhub_routing_intent00" {
  count               = var.add_firewall00 ? 1 : 0
  name                = "routing-policy-${var.azurerm_virtual_hub00_name}-${var.azure_region_0_abbr}"
  virtual_hub_id      = azurerm_virtual_hub.vhub00.id
  routing_policy {
    name = "InternetTrafficPolicy"
    destinations = ["Internet"]
    next_hop = azurerm_firewall.fw00[0].id
  }
    routing_policy {
    name = "PrivateTrafficPolicy"
    destinations = ["PrivateTraffic"]
    next_hop = azurerm_firewall.fw00[0].id
  }
}
resource "azurerm_network_interface" "vm00_nic" {
  name                = "${var.vm01_nic_name}-${var.azure_region_0_abbr}"
  location            = azurerm_resource_group.rg-net00.location
  resource_group_name = azurerm_resource_group.rg-net00.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.shared_subnet00.id
    private_ip_address_allocation = "Dynamic"
  }
}
resource "azurerm_linux_virtual_machine" "vm00" {
  name                = "${var.vm01_name}-${var.azure_region_0_abbr}"
  location            = azurerm_resource_group.rg-net00.location
  resource_group_name = azurerm_resource_group.rg-net00.name
  size                = "Standard_B2s"
  admin_username      = "${random_string.myrandom.id}${var.vm_admin_username}"
  network_interface_ids = [
    azurerm_network_interface.vm00_nic.id,
  ]
  admin_password = data.azurerm_key_vault_secret.vm_password.value
  disable_password_authentication = false
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
resource "azurerm_vpn_gateway" "s2s_VPN00" {
  count               = var.add_s2s_VPN00 ? 1 : 0
  name                = "${var.s2s_VPN00_name}-${var.azure_region_0_abbr}"
  location            = azurerm_resource_group.rg-net00.location
  resource_group_name = azurerm_resource_group.rg-net00.name
  virtual_hub_id      = azurerm_virtual_hub.vhub00.id
}
resource "azurerm_vpn_site" "s2s_site00" {
  count               = var.add_s2s_VPN00 ? 1 : 0
  name                = var.s2s_site00_name
  location            = azurerm_resource_group.rg-net00.location
  resource_group_name = azurerm_resource_group.rg-net00.name
  virtual_wan_id      = azurerm_virtual_wan.vwan.id
  address_cidrs = var.s2s_site00_addresscidr
  link {
    name       = "Site00-Link00"
    ip_address = var.s2s_site00_ipaddress
    speed_in_mbps = var.s2s_site00_speed
  }
}
resource "azurerm_vpn_gateway_connection" "s2s_VPN00_conn00" {
  count               = var.add_s2s_VPN00 ? 1 : 0
  name               = "${var.s2s_conn01_name}-${var.azure_region_0_abbr}"
  vpn_gateway_id     = azurerm_vpn_gateway.s2s_VPN00[0].id
  remote_vpn_site_id = azurerm_vpn_site.s2s_site00[0].id
  vpn_link {
    name             = "site00_link00"
    vpn_site_link_id = azurerm_vpn_site.s2s_site00[0].link[0].id
  }
}
resource "azurerm_monitor_diagnostic_setting" "s2s_VPN00_logs" {
  count               = var.add_s2s_VPN00 ? 1 : 0
  name               = "${var.s2s_VPN00_logs_name}-${var.azure_region_0_abbr}"
  target_resource_id = azurerm_vpn_gateway.s2s_VPN00[0].id

  log_analytics_workspace_id = azurerm_log_analytics_workspace.law00.id
  enabled_log {
    category = "GatewayDiagnosticLog"
  }
  enabled_log {
    category = "TunnelDiagnosticLog"
  }
  enabled_log {
    category = "RouteDiagnosticLog"
  }
    enabled_log {
    category = "IKEDiagnosticLog"
  }
  metric {
    category = "AllMetrics"
  }
}
# Optional vHub 01 resources
resource "azurerm_resource_group" "rg-net01" {
  count               = var.create_vhub01 ? 1 : 0
  name = "${var.resource_group_name_net01}-${var.azure_region_1_abbr}-${random_string.myrandom.id}"
  location = var.azure_region_1_name
}
resource "azurerm_virtual_hub" "vhub01" {
  count               = var.create_vhub01 ? 1 : 0
  name                = "${var.azurerm_virtual_hub01_name}-${var.azure_region_1_abbr}"
  resource_group_name = azurerm_resource_group.rg-net01[0].name
  location            = azurerm_resource_group.rg-net01[0].location
  virtual_wan_id      = azurerm_virtual_wan.vwan.id
  address_prefix      = var.azurerm_vhub01_address_prefix
  hub_routing_preference = var.azurerm_vhub01_route_pref
}
resource "azurerm_virtual_network" "shared_vnet01" {
  count               = var.create_vhub01 ? 1 : 0
  name                = "${var.shared_vnet_name01}-${var.azure_region_1_abbr}"
  address_space       = var.shared_vnet_address_space01
  location            = azurerm_resource_group.rg-net01[0].location
  resource_group_name = azurerm_resource_group.rg-net01[0].name
}
resource "azurerm_subnet" "shared_subnet01" {
  count               = var.create_vhub01 ? 1 : 0
  name                 = "${var.shared_subnet_name01}-${var.shared_vnet_name01}-${var.azure_region_1_abbr}"
  resource_group_name  = azurerm_resource_group.rg-net01[0].name
  virtual_network_name = azurerm_virtual_network.shared_vnet01[0].name
  address_prefixes     = var.shared_subnet_address01
}
resource "azurerm_subnet" "app_subnet01" {
  count               = var.create_vhub01 ? 1 : 0
  name                 = "${var.app_subnet_name01}-${var.shared_vnet_name01}-${var.azure_region_1_abbr}"
  resource_group_name  = azurerm_resource_group.rg-net01[0].name
  virtual_network_name = azurerm_virtual_network.shared_vnet01[0].name
  address_prefixes     = var.app_subnet_address01
}
resource "azurerm_subnet" "bastion_subnet01" {
  count               = var.create_vhub01 ? 1 : 0
  name                 = var.bastion_subnet_name01
  resource_group_name  = azurerm_resource_group.rg-net01[0].name
  virtual_network_name = azurerm_virtual_network.shared_vnet01[0].name
  address_prefixes     = var.bastion_subnet_address01
}
resource "azurerm_public_ip" "bastion_pip01" {
  count               = var.create_vhub01 ? 1 : 0
  name                = "${var.bastion_pip_name01}-${var.azure_region_1_abbr}"
  location            = azurerm_resource_group.rg-net01[0].location
  resource_group_name = azurerm_resource_group.rg-net01[0].name
  allocation_method   = "Static"
  sku                 = "Standard"
}
resource "azurerm_bastion_host" "bastion_host01" {
  count               = var.create_vhub01 ? 1 : 0
  name                = "${var.bastion_host_name01}-${var.azure_region_1_abbr}"
  location            = azurerm_resource_group.rg-net01[0].location
  resource_group_name = azurerm_resource_group.rg-net01[0].name
  sku = var.bastion_host_sku01
  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion_subnet01[0].id
    public_ip_address_id = azurerm_public_ip.bastion_pip01[0].id
  }
}
resource "azurerm_virtual_hub_connection" "vhub_connection01" {
  count               = var.create_vhub01 ? 1 : 0
  name                      = var.azurerm_virtual_hub_connection_vhub01_to_shared01
  virtual_hub_id            = azurerm_virtual_hub.vhub01[0].id
  remote_virtual_network_id = azurerm_virtual_network.shared_vnet01[0].id
}
resource "azurerm_virtual_network" "dns_vnet01" {
  count               = var.create_vhub01 ? (var.add_privateDNS01 ? 1 : 0) : 0
  name                = "${var.dns_vnet_name01}-${var.azure_region_1_abbr}"
  address_space       = var.dns_vnet_address_space01
  location            = azurerm_resource_group.rg-net01[0].location
  resource_group_name = azurerm_resource_group.rg-net01[0].name
}
resource "azurerm_subnet" "resolver_inbound_subnet01" {
  count               = var.create_vhub01 ? (var.add_privateDNS01 ? 1 : 0) : 0
  name                 = "${var.resolver_inbound_subnet_name01}-${var.dns_vnet_name01}-${var.azure_region_1_abbr}"
  resource_group_name  = azurerm_resource_group.rg-net01[0].name
  virtual_network_name = azurerm_virtual_network.dns_vnet01[0].name
  address_prefixes     = var.resolver_inbound_subnet_address01

  delegation {
    name = "Microsoft.Network.dnsResolvers"
    service_delegation {
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      name    = "Microsoft.Network/dnsResolvers"
    }
  }
}
resource "azurerm_subnet" "resolver_outbound_subnet01" {
  count               = var.create_vhub01 ? (var.add_privateDNS01 ? 1 : 0) : 0
  name                 = "${var.resolver_outbound_subnet_name01}-${var.dns_vnet_name01}-${var.azure_region_1_abbr}"
  resource_group_name  = azurerm_resource_group.rg-net01[0].name
  virtual_network_name = azurerm_virtual_network.dns_vnet01[0].name
  address_prefixes     = var.resolver_outbound_subnet_address01

  delegation {
    name = "Microsoft.Network.dnsResolvers"
    service_delegation {
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      name    = "Microsoft.Network/dnsResolvers"
    }
  }
}
resource "azurerm_virtual_hub_connection" "vhub_connection01-to-dns" {
  count               = var.create_vhub01 ? (var.add_privateDNS01 ? 1 : 0) : 0
  name                      = "${var.azurerm_virtual_hub_connection_vhub01_to_dns01}-${var.azure_region_1_abbr}"
  virtual_hub_id            = azurerm_virtual_hub.vhub01[0].id
  remote_virtual_network_id = azurerm_virtual_network.dns_vnet01[0].id
}
module "private_dns01" {
  count               = var.create_vhub01 ? (var.add_privateDNS01 ? 1 : 0) : 0
  source = "Azure/avm-ptn-network-private-link-private-dns-zones/azurerm"
  location = azurerm_resource_group.rg-net01[0].location
  resource_group_name = azurerm_resource_group.rg-net01[0].name
  resource_group_creation_enabled = false
  virtual_network_resource_ids_to_link_to = {
    "dns_vnet01" = {
      vnet_resource_id = azurerm_virtual_network.dns_vnet01[0].id
    }
  }
}
resource "azurerm_private_dns_resolver" "private_resolver01" {
  count               = var.create_vhub01 ? (var.add_privateDNS01 ? 1 : 0) : 0
  name                = "${var.private_resolver_name01}-${var.azure_region_1_abbr}"
  resource_group_name = azurerm_resource_group.rg-net01[0].name
  location            = azurerm_resource_group.rg-net01[0].location
  virtual_network_id  = azurerm_virtual_network.dns_vnet01[0].id
}
resource "azurerm_private_dns_resolver_inbound_endpoint" "private_resolver01_inbound00" {
  count               = var.create_vhub01 ? (var.add_privateDNS01 ? 1 : 0) : 0
  name                    = "${var.private_resolver_name01}-inbound00-${var.azure_region_1_abbr}"
  private_dns_resolver_id = azurerm_private_dns_resolver.private_resolver01[0].id
  location                = azurerm_resource_group.rg-net01[0].location
  depends_on = [
    azurerm_subnet.resolver_inbound_subnet01[0],
  ]
  ip_configurations {
    private_ip_allocation_method = "Static"
    subnet_id                    = azurerm_subnet.resolver_inbound_subnet01[0].id
    private_ip_address = var.resolver_inbound_endpoint_address01
  }
}
resource "azurerm_private_dns_resolver_outbound_endpoint" "private_resolver01_outbound00" {
  count               = var.create_vhub01 ? (var.add_privateDNS01 ? 1 : 0) : 0
  name                    = "${var.private_resolver_name01}-outbound00-${var.azure_region_1_abbr}"
  private_dns_resolver_id = azurerm_private_dns_resolver.private_resolver01[0].id
  location                = azurerm_resource_group.rg-net01[0].location
  subnet_id               = azurerm_subnet.resolver_outbound_subnet01[0].id
}
resource "azurerm_virtual_network_dns_servers" "shared_vnet01_dns" {
  count               = var.create_vhub01 ? (var.add_privateDNS01 ? 1 : 0) : 0
  virtual_network_id = azurerm_virtual_network.shared_vnet01[0].id
  dns_servers        = var.shared_vnet01_dns

  depends_on = [
    azurerm_subnet.resolver_inbound_subnet01[0],
    azurerm_subnet.resolver_outbound_subnet01[0]
  ]
}
resource "azurerm_firewall" "fw01" {
  count               = var.create_vhub01 ? (var.add_firewall01 ? 1 : 0) : 0
  name                = "${var.firewall_name01}-${var.azure_region_1_abbr}"
  location            = azurerm_resource_group.rg-net01[0].location
  resource_group_name = azurerm_resource_group.rg-net01[0].name
  sku_name            = var.firewall_SkuName01
  sku_tier            = var.firewall_SkuTier01
  zones               = ["1", "2", "3"]
  virtual_hub {
    virtual_hub_id      = azurerm_virtual_hub.vhub01[0].id
  }

  firewall_policy_id = azurerm_firewall_policy.fw01_policy[0].id
}
resource "azurerm_firewall_policy" "fw01_policy" {
  count               = var.create_vhub01 ? (var.add_firewall01 ? 1 : 0) : 0
  name                = "${var.firewall_policy_name01}-${var.azure_region_1_abbr}"
  location            = azurerm_resource_group.rg-net01[0].location
  resource_group_name = azurerm_resource_group.rg-net01[0].name
  sku = var.firewall_SkuTier01
}
resource "azurerm_firewall_policy_rule_collection_group" "fw01_policy_rcg" {
  count               = var.create_vhub01 ? (var.add_firewall01 ? 1 : 0) : 0
  name               = "${var.firewall_policy_rcg_name01}-${var.azure_region_1_abbr}"
  firewall_policy_id = azurerm_firewall_policy.fw01_policy[0].id
  priority           = 500
  network_rule_collection {
    name     = "network_rule_collection1"
    priority = 400
    action   = "Allow"
    rule {
      name                  = "network_rule_collection1_rule1"
      protocols             = ["TCP", "UDP", "ICMP"]
      source_addresses      = ["*"]
      destination_addresses = ["*"]
      destination_ports     = ["*"]
    }
  }
}
resource "azurerm_monitor_diagnostic_setting" "fw01_logs" {
  count               = var.add_firewall01 ? 1 : 0
  name               = "${var.firewall_logs_name01}-${var.azure_region_1_abbr}"
  target_resource_id = azurerm_firewall.fw01[0].id

  log_analytics_workspace_id = azurerm_log_analytics_workspace.law00.id
  enabled_log {
    category = "AzureFirewallApplicationRule"
  }
  enabled_log {
    category = "AzureFirewallNetworkRule"
  }
  enabled_log {
    category = "AzureFirewallDnsProxy"
  }
  metric {
    category = "AllMetrics"
  }
}
resource "azurerm_virtual_hub_routing_intent" "vhub_routing_intent01" {
  count               = var.create_vhub01 ? (var.add_firewall01 ? 1 : 0) : 0
  name                = "routing-policy-${var.azurerm_virtual_hub01_name}-${var.azure_region_1_abbr}"
  virtual_hub_id      = azurerm_virtual_hub.vhub01[0].id
  routing_policy {
    name = "InternetTrafficPolicy"
    destinations = ["Internet"]
    next_hop = azurerm_firewall.fw01[0].id
  }
    routing_policy {
    name = "PrivateTrafficPolicy"
    destinations = ["PrivateTraffic"]
    next_hop = azurerm_firewall.fw01[0].id
  }
}
resource "azurerm_network_interface" "vm01_nic" {
  count               = var.create_vhub01 ? 1 : 0
  name                = "${var.vm01_nic_name}-${var.azure_region_1_abbr}"
  location            = azurerm_resource_group.rg-net01[0].location
  resource_group_name = azurerm_resource_group.rg-net01[0].name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.shared_subnet01[0].id
    private_ip_address_allocation = "Dynamic"
  }
}
resource "azurerm_linux_virtual_machine" "vm01" {
  count               = var.create_vhub01 ? 1 : 0
  name                = "${var.vm01_name}-${var.azure_region_1_abbr}"
  location            = azurerm_resource_group.rg-net01[0].location
  resource_group_name = azurerm_resource_group.rg-net01[0].name
  size                = "Standard_B2s"
  admin_username      = "${random_string.myrandom.id}${var.vm_admin_username}"
  network_interface_ids = [
    azurerm_network_interface.vm01_nic[0].id,
  ]
  admin_password = data.azurerm_key_vault_secret.vm_password.value
  disable_password_authentication = false
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
resource "azurerm_vpn_gateway" "s2s_VPN01" {
  count               = var.add_s2s_VPN01 ? 1 : 0
  name                = "${var.s2s_VPN01_name}-${var.azure_region_1_abbr}"
  location            = azurerm_resource_group.rg-net01[0].location
  resource_group_name = azurerm_resource_group.rg-net01[0].name
  virtual_hub_id      = azurerm_virtual_hub.vhub01[0].id
}
resource "azurerm_vpn_site" "s2s_site01" {
  count               = var.add_s2s_VPN01 ? 1 : 0
  name                = "${var.s2s_site01_name}-${var.azure_region_1_abbr}"
  location            = azurerm_resource_group.rg-net01[0].location
  resource_group_name = azurerm_resource_group.rg-net01[0].name
  virtual_wan_id      = azurerm_virtual_wan.vwan.id
  address_cidrs = var.s2s_site01_addresscidr
  link {
    name       = "Site01-Link01"
    ip_address = var.s2s_site01_ipaddress
    speed_in_mbps = var.s2s_site01_speed
  }
}
resource "azurerm_vpn_gateway_connection" "s2s_VPN01_conn01" {
  count               = var.add_s2s_VPN01 ? 1 : 0
  name               = "${var.s2s_conn01_name}-${var.azure_region_1_abbr}"
  vpn_gateway_id     = azurerm_vpn_gateway.s2s_VPN01[0].id
  remote_vpn_site_id = azurerm_vpn_site.s2s_site01[0].id
  vpn_link {
    name             = "site01_link01"
    vpn_site_link_id = azurerm_vpn_site.s2s_site01[0].link[0].id
  }
}
resource "azurerm_monitor_diagnostic_setting" "s2s_VPN01_logs" {
  count               = var.add_s2s_VPN01 ? 1 : 0
  name               = "${var.s2s_VPN01_logs_name}-${var.azure_region_1_abbr}"
  target_resource_id = azurerm_vpn_gateway.s2s_VPN01[0].id

  log_analytics_workspace_id = azurerm_log_analytics_workspace.law00.id
  enabled_log {
    category = "GatewayDiagnosticLog"
  }
  enabled_log {
    category = "TunnelDiagnosticLog"
  }
  enabled_log {
    category = "RouteDiagnosticLog"
  }
    enabled_log {
    category = "IKEDiagnosticLog"
  }
  metric {
    category = "AllMetrics"
  }
}