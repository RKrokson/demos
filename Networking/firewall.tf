resource "azurerm_firewall" "fw00" {
  count               = var.add_firewall00 ? 1 : 0
  name                = "${var.firewall_name00}-${var.azure_region_0_abbr}"
  location            = local.rg00_location
  resource_group_name = local.rg00_name
  sku_name            = var.firewall_sku_name00
  sku_tier            = var.firewall_sku_tier00
  zones               = ["1", "2", "3"]
  tags                = local.common_tags
  virtual_hub {
    virtual_hub_id = azurerm_virtual_hub.vhub00.id
  }

  firewall_policy_id = azurerm_firewall_policy.fw00_policy[0].id

  timeouts {
    create = "60m"
    delete = "60m"
  }
}
resource "azurerm_firewall_policy" "fw00_policy" {
  count               = var.add_firewall00 ? 1 : 0
  name                = "${var.firewall_policy_name00}-${var.azure_region_0_abbr}"
  location            = local.rg00_location
  resource_group_name = local.rg00_name
  sku                 = var.firewall_sku_tier00
  tags                = local.common_tags
}
# WARNING: Allow-all rule for non-production lab use only.
# In production, restrict source/destination to known address spaces.
resource "azurerm_firewall_policy_rule_collection_group" "fw00_policy_rcg" {
  count              = var.add_firewall00 ? 1 : 0
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
  count              = var.add_firewall00 ? 1 : 0
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
  enabled_metric {
    category = "AllMetrics"
  }
}
resource "azurerm_firewall" "fw01" {
  count               = var.create_vhub01 ? (var.add_firewall01 ? 1 : 0) : 0
  name                = "${var.firewall_name01}-${var.azure_region_1_abbr}"
  location            = azurerm_resource_group.rg-net01[0].location
  resource_group_name = azurerm_resource_group.rg-net01[0].name
  sku_name            = var.firewall_sku_name01
  sku_tier            = var.firewall_sku_tier01
  zones               = ["1", "2", "3"]
  tags                = local.common_tags
  virtual_hub {
    virtual_hub_id = azurerm_virtual_hub.vhub01[0].id
  }

  firewall_policy_id = azurerm_firewall_policy.fw01_policy[0].id

  timeouts {
    create = "60m"
    delete = "60m"
  }
}
resource "azurerm_firewall_policy" "fw01_policy" {
  count               = var.create_vhub01 ? (var.add_firewall01 ? 1 : 0) : 0
  name                = "${var.firewall_policy_name01}-${var.azure_region_1_abbr}"
  location            = azurerm_resource_group.rg-net01[0].location
  resource_group_name = azurerm_resource_group.rg-net01[0].name
  sku                 = var.firewall_sku_tier01
  tags                = local.common_tags
}
# WARNING: Allow-all rule for non-production lab use only.
# In production, restrict source/destination to known address spaces.
resource "azurerm_firewall_policy_rule_collection_group" "fw01_policy_rcg" {
  count              = var.create_vhub01 ? (var.add_firewall01 ? 1 : 0) : 0
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
  count              = var.create_vhub01 && var.add_firewall01 ? 1 : 0
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
  enabled_metric {
    category = "AllMetrics"
  }
}
