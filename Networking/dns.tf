resource "azurerm_virtual_network" "dns_vnet00" {
  count               = var.add_private_dns00 ? 1 : 0
  name                = "${var.dns_vnet_name00}-${var.azure_region_0_abbr}"
  address_space       = var.dns_vnet_address_space00
  location            = local.rg00_location
  resource_group_name = local.rg00_name
  tags                = local.common_tags
}
resource "azurerm_subnet" "resolver_inbound_subnet00" {
  count                = var.add_private_dns00 ? 1 : 0
  name                 = "${var.resolver_inbound_subnet_name00}-${var.dns_vnet_name00}-${var.azure_region_0_abbr}"
  resource_group_name  = local.rg00_name
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
  count                = var.add_private_dns00 ? 1 : 0
  name                 = "${var.resolver_outbound_subnet_name00}-${var.dns_vnet_name00}-${var.azure_region_0_abbr}"
  resource_group_name  = local.rg00_name
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
  count     = var.add_private_dns00 ? 1 : 0
  source    = "Azure/avm-ptn-network-private-link-private-dns-zones/azurerm"
  version   = "0.23.0"
  location  = local.rg00_location
  parent_id = azurerm_resource_group.rg-net00.id
  virtual_network_link_default_virtual_networks = {
    "dns_vnet00" = {
      virtual_network_resource_id = azurerm_virtual_network.dns_vnet00[0].id
      resolution_policy           = "NxDomainRedirect"
    }
  }
}
resource "azurerm_virtual_hub_connection" "vhub_connection00-to-dns" {
  count                     = var.add_private_dns00 ? 1 : 0
  name                      = "${var.azurerm_virtual_hub_connection_vhub00_to_dns00}-${var.azure_region_0_abbr}"
  virtual_hub_id            = azurerm_virtual_hub.vhub00.id
  remote_virtual_network_id = azurerm_virtual_network.dns_vnet00[0].id
  internet_security_enabled = var.add_firewall00
}
resource "azurerm_private_dns_resolver" "private_resolver00" {
  count               = var.add_private_dns00 ? 1 : 0
  name                = "${var.private_resolver_name00}-${var.azure_region_0_abbr}"
  resource_group_name = local.rg00_name
  location            = local.rg00_location
  virtual_network_id  = azurerm_virtual_network.dns_vnet00[0].id
  tags                = local.common_tags
}
resource "azurerm_private_dns_resolver_inbound_endpoint" "private_resolver00_inbound00" {
  count                   = var.add_private_dns00 ? 1 : 0
  name                    = "${var.private_resolver_name00}-inbound00-${var.azure_region_0_abbr}"
  private_dns_resolver_id = azurerm_private_dns_resolver.private_resolver00[0].id
  location                = local.rg00_location
  tags                    = local.common_tags
  depends_on = [
    azurerm_subnet.resolver_inbound_subnet00[0],
  ]
  ip_configurations {
    private_ip_allocation_method = "Static"
    subnet_id                    = azurerm_subnet.resolver_inbound_subnet00[0].id
    private_ip_address           = var.resolver_inbound_endpoint_address00
  }
}
resource "azurerm_virtual_network_dns_servers" "shared_vnet00_dns" {
  count              = var.add_private_dns00 ? 1 : 0
  virtual_network_id = azurerm_virtual_network.shared_vnet00.id
  dns_servers        = var.shared_vnet00_dns

  depends_on = [
    azurerm_subnet.resolver_inbound_subnet00[0],
    azurerm_subnet.resolver_outbound_subnet00[0]
  ]
}
resource "azurerm_private_dns_resolver_outbound_endpoint" "private_resolver00_outbound00" {
  count                   = var.add_private_dns00 ? 1 : 0
  name                    = "${var.private_resolver_name00}-outbound00-${var.azure_region_0_abbr}"
  private_dns_resolver_id = azurerm_private_dns_resolver.private_resolver00[0].id
  location                = local.rg00_location
  subnet_id               = azurerm_subnet.resolver_outbound_subnet00[0].id
  tags                    = local.common_tags
}
resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" "private_resolver00_forwarding_ruleset00" {
  count                                      = var.add_private_dns00 ? 1 : 0
  name                                       = "${var.private_resolver_name00}-ruleset00-${var.azure_region_0_abbr}"
  resource_group_name                        = local.rg00_name
  location                                   = local.rg00_location
  private_dns_resolver_outbound_endpoint_ids = [azurerm_private_dns_resolver_outbound_endpoint.private_resolver00_outbound00[0].id]
  tags                                       = local.common_tags
}

resource "azurerm_private_dns_resolver_forwarding_rule" "private_resolver00_forwarding_rule00" {
  count                     = var.add_private_dns00 ? 1 : 0
  name                      = "${var.private_resolver_name00}-rule00-${var.azure_region_0_abbr}"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.private_resolver00_forwarding_ruleset00[0].id
  domain_name               = "."
  enabled                   = true
  target_dns_servers {
    ip_address = "8.8.8.8"
    port       = 53
  }
}
resource "azurerm_private_dns_resolver_virtual_network_link" "private_resolver00_dnsvnet00link" {
  count                     = var.add_private_dns00 ? 1 : 0
  name                      = "${var.private_resolver_name00}-dnsvnetlink00-${var.azure_region_0_abbr}"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.private_resolver00_forwarding_ruleset00[0].id
  virtual_network_id        = azurerm_virtual_network.dns_vnet00[0].id
}
resource "azapi_resource" "dns_security_policy00" {
  count     = var.add_private_dns00 ? 1 : 0
  type      = "Microsoft.Network/dnsResolverPolicies@2023-07-01-preview"
  name      = "myDnsSecurityPolicy00-${var.azure_region_0_abbr}"
  parent_id = azurerm_resource_group.rg-net00.id
  location  = local.rg00_location
  tags      = local.common_tags

  body = {
    properties = {
      # DNS resolver policy properties - basic policy for now
    }
  }
}
resource "azapi_resource" "dns_security_policy_shared_vnet00_link" {
  count     = var.add_private_dns00 ? 1 : 0
  type      = "Microsoft.Network/dnsResolverPolicies/virtualNetworkLinks@2023-07-01-preview"
  name      = "vnet-link-to-dns-policy-shared-vnet00"
  parent_id = azapi_resource.dns_security_policy00[0].id
  location  = local.rg00_location

  body = {
    properties = {
      virtualNetwork = {
        id = azurerm_virtual_network.shared_vnet00.id
      }
    }
  }
}
resource "azapi_resource" "dns_security_policy_dns_vnet00_link" {
  count     = var.add_private_dns00 ? 1 : 0
  type      = "Microsoft.Network/dnsResolverPolicies/virtualNetworkLinks@2023-07-01-preview"
  name      = "vnet-link-to-dns-policy-dns-vnet00"
  parent_id = azapi_resource.dns_security_policy00[0].id
  location  = local.rg00_location

  body = {
    properties = {
      virtualNetwork = {
        id = azurerm_virtual_network.dns_vnet00[0].id
      }
    }
  }
}
resource "azurerm_monitor_diagnostic_setting" "dns_policy00_logs" {
  count              = var.add_private_dns00 ? 1 : 0
  name               = "dns-policy-logs-${var.azure_region_0_abbr}"
  target_resource_id = azapi_resource.dns_security_policy00[0].id

  log_analytics_workspace_id = azurerm_log_analytics_workspace.law00.id

  enabled_log {
    category = "DnsResponse"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
# Region 1 DNS resources
resource "azurerm_virtual_network" "dns_vnet01" {
  count               = var.create_vhub01 ? (var.add_private_dns01 ? 1 : 0) : 0
  name                = "${var.dns_vnet_name01}-${var.azure_region_1_abbr}"
  address_space       = var.dns_vnet_address_space01
  location            = azurerm_resource_group.rg-net01[0].location
  resource_group_name = azurerm_resource_group.rg-net01[0].name
  tags                = local.common_tags
}
resource "azurerm_subnet" "resolver_inbound_subnet01" {
  count                = var.create_vhub01 ? (var.add_private_dns01 ? 1 : 0) : 0
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
  count                = var.create_vhub01 ? (var.add_private_dns01 ? 1 : 0) : 0
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
  count                     = var.create_vhub01 && var.add_private_dns01 ? 1 : 0
  name                      = "${var.azurerm_virtual_hub_connection_vhub01_to_dns01}-${var.azure_region_1_abbr}"
  virtual_hub_id            = azurerm_virtual_hub.vhub01[0].id
  remote_virtual_network_id = azurerm_virtual_network.dns_vnet01[0].id
  internet_security_enabled = var.add_firewall01
}
module "private_dns01" {
  count     = var.create_vhub01 ? (var.add_private_dns01 ? 1 : 0) : 0
  source    = "Azure/avm-ptn-network-private-link-private-dns-zones/azurerm"
  version   = "0.23.0"
  location  = azurerm_resource_group.rg-net01[0].location
  parent_id = azurerm_resource_group.rg-net01[0].id
  virtual_network_link_default_virtual_networks = {
    "dns_vnet01" = {
      virtual_network_resource_id = azurerm_virtual_network.dns_vnet01[0].id
      resolution_policy           = "NxDomainRedirect"
    }
  }
}
resource "azurerm_private_dns_resolver" "private_resolver01" {
  count               = var.create_vhub01 ? (var.add_private_dns01 ? 1 : 0) : 0
  name                = "${var.private_resolver_name01}-${var.azure_region_1_abbr}"
  resource_group_name = azurerm_resource_group.rg-net01[0].name
  location            = azurerm_resource_group.rg-net01[0].location
  virtual_network_id  = azurerm_virtual_network.dns_vnet01[0].id
  tags                = local.common_tags
}
resource "azurerm_private_dns_resolver_inbound_endpoint" "private_resolver01_inbound00" {
  count                   = var.create_vhub01 ? (var.add_private_dns01 ? 1 : 0) : 0
  name                    = "${var.private_resolver_name01}-inbound00-${var.azure_region_1_abbr}"
  private_dns_resolver_id = azurerm_private_dns_resolver.private_resolver01[0].id
  location                = azurerm_resource_group.rg-net01[0].location
  tags                    = local.common_tags
  depends_on = [
    azurerm_subnet.resolver_inbound_subnet01[0],
  ]
  ip_configurations {
    private_ip_allocation_method = "Static"
    subnet_id                    = azurerm_subnet.resolver_inbound_subnet01[0].id
    private_ip_address           = var.resolver_inbound_endpoint_address01
  }
}
resource "azurerm_private_dns_resolver_outbound_endpoint" "private_resolver01_outbound00" {
  count                   = var.create_vhub01 ? (var.add_private_dns01 ? 1 : 0) : 0
  name                    = "${var.private_resolver_name01}-outbound00-${var.azure_region_1_abbr}"
  private_dns_resolver_id = azurerm_private_dns_resolver.private_resolver01[0].id
  location                = azurerm_resource_group.rg-net01[0].location
  subnet_id               = azurerm_subnet.resolver_outbound_subnet01[0].id
  tags                    = local.common_tags
}
resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" "private_resolver01_forwarding_ruleset00" {
  count                                      = var.create_vhub01 ? (var.add_private_dns01 ? 1 : 0) : 0
  name                                       = "${var.private_resolver_name01}-ruleset00-${var.azure_region_1_abbr}"
  resource_group_name                        = azurerm_resource_group.rg-net01[0].name
  location                                   = azurerm_resource_group.rg-net01[0].location
  private_dns_resolver_outbound_endpoint_ids = [azurerm_private_dns_resolver_outbound_endpoint.private_resolver01_outbound00[0].id]
  tags                                       = local.common_tags
}

resource "azurerm_private_dns_resolver_forwarding_rule" "private_resolver01_forwarding_rule00" {
  count                     = var.create_vhub01 ? (var.add_private_dns01 ? 1 : 0) : 0
  name                      = "${var.private_resolver_name01}-rule00-${var.azure_region_1_abbr}"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.private_resolver01_forwarding_ruleset00[0].id
  domain_name               = "."
  enabled                   = true
  target_dns_servers {
    ip_address = "8.8.8.8"
    port       = 53
  }
}
resource "azurerm_private_dns_resolver_virtual_network_link" "private_resolver01_dnsvnet01link" {
  count                     = var.create_vhub01 ? (var.add_private_dns01 ? 1 : 0) : 0
  name                      = "${var.private_resolver_name01}-dnsvnetlink01-${var.azure_region_1_abbr}"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.private_resolver01_forwarding_ruleset00[0].id
  virtual_network_id        = azurerm_virtual_network.dns_vnet01[0].id
}
resource "azurerm_virtual_network_dns_servers" "shared_vnet01_dns" {
  count              = var.create_vhub01 ? (var.add_private_dns01 ? 1 : 0) : 0
  virtual_network_id = azurerm_virtual_network.shared_vnet01[0].id
  dns_servers        = var.shared_vnet01_dns

  depends_on = [
    azurerm_subnet.resolver_inbound_subnet01[0],
    azurerm_subnet.resolver_outbound_subnet01[0]
  ]
}
resource "azapi_resource" "dns_security_policy01" {
  count     = var.create_vhub01 ? (var.add_private_dns01 ? 1 : 0) : 0
  type      = "Microsoft.Network/dnsResolverPolicies@2023-07-01-preview"
  name      = "myDnsSecurityPolicy01-${var.azure_region_1_abbr}"
  parent_id = azurerm_resource_group.rg-net01[0].id
  location  = azurerm_resource_group.rg-net01[0].location
  tags      = local.common_tags

  body = {
    properties = {
      # DNS resolver policy properties - basic policy for now
    }
  }
}
resource "azapi_resource" "dns_security_policy_shared_vnet01_link" {
  count     = var.create_vhub01 ? (var.add_private_dns01 ? 1 : 0) : 0
  type      = "Microsoft.Network/dnsResolverPolicies/virtualNetworkLinks@2023-07-01-preview"
  name      = "vnet-link-to-dns-policy-shared-vnet01"
  parent_id = azapi_resource.dns_security_policy01[0].id
  location  = azurerm_resource_group.rg-net01[0].location

  body = {
    properties = {
      virtualNetwork = {
        id = azurerm_virtual_network.shared_vnet01[0].id
      }
    }
  }
}
resource "azapi_resource" "dns_security_policy_dns_vnet01_link" {
  count     = var.create_vhub01 ? (var.add_private_dns01 ? 1 : 0) : 0
  type      = "Microsoft.Network/dnsResolverPolicies/virtualNetworkLinks@2023-07-01-preview"
  name      = "vnet-link-to-dns-policy-dns-vnet01"
  parent_id = azapi_resource.dns_security_policy01[0].id
  location  = azurerm_resource_group.rg-net01[0].location

  body = {
    properties = {
      virtualNetwork = {
        id = azurerm_virtual_network.dns_vnet01[0].id
      }
    }
  }
}
resource "azurerm_monitor_diagnostic_setting" "dns_policy01_logs" {
  count              = var.create_vhub01 ? (var.add_private_dns01 ? 1 : 0) : 0
  name               = "dns-policy-logs-${var.azure_region_1_abbr}"
  target_resource_id = azapi_resource.dns_security_policy01[0].id

  log_analytics_workspace_id = azurerm_log_analytics_workspace.law00.id

  enabled_log {
    category = "DnsResponse"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
