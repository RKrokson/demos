output "vm_admin_username" {
  description = "Virtual Machine Admin Username"
  value       = module.region0.vm_admin_username
  sensitive   = true
}
output "vm_admin_password" {
  description = "Shared virtual machine administrator password for Bastion access"
  value       = random_password.vm_password.result
  sensitive   = true
}

# Log Analytics Workspace
output "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.law00.id
}

output "alz_regions" {
  description = "Regional platform contract consumed by application landing zones"
  value = {
    region0 = {
      enabled                 = true
      region_name             = var.azure_region_0_name
      region_abbr             = var.azure_region_0_abbr
      resource_group_id       = azurerm_resource_group.rg-net00.id
      resource_group_name     = azurerm_resource_group.rg-net00.name
      resource_group_location = azurerm_resource_group.rg-net00.location
      vhub_id                 = module.region0.hub_id
      firewall_enabled        = var.add_firewall00
      dns_server_ip = var.add_private_dns00 ? (
        var.add_firewall00 ? module.region0.firewall_private_ip : module.region0.dns_inbound_endpoint_ip
      ) : null
      dns_resolver_policy_id = module.region0.dns_resolver_policy_id
      dns_vnet_id            = module.region0.dns_vnet_id
      private_dns_zone_ids   = module.region0.private_dns_zone_ids
    }
    region1 = {
      enabled                 = var.create_vhub01
      region_name             = var.azure_region_1_name
      region_abbr             = var.azure_region_1_abbr
      resource_group_id       = try(azurerm_resource_group.rg-net01[0].id, null)
      resource_group_name     = try(azurerm_resource_group.rg-net01[0].name, null)
      resource_group_location = try(azurerm_resource_group.rg-net01[0].location, null)
      vhub_id                 = try(module.region1[0].hub_id, null)
      firewall_enabled        = var.create_vhub01 && var.add_firewall01
      dns_server_ip = var.create_vhub01 && var.add_private_dns01 ? (
        var.add_firewall01 ? module.region1[0].firewall_private_ip : module.region1[0].dns_inbound_endpoint_ip
      ) : null
      dns_resolver_policy_id = try(module.region1[0].dns_resolver_policy_id, null)
      dns_vnet_id            = try(module.region1[0].dns_vnet_id, null)
      private_dns_zone_ids = var.create_vhub01 ? module.region1[0].private_dns_zone_ids : {
        for key in keys(module.region0.private_dns_zone_ids) : key => null
      }
    }
  }
}
