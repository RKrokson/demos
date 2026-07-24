# ── Hub ─────────────────────────────────────────────────────────

output "hub_id" {
  description = "Virtual Hub ID"
  value       = azurerm_virtual_hub.hub.id
}

output "hub_name" {
  description = "Virtual Hub name"
  value       = azurerm_virtual_hub.hub.name
}

# ── Shared VNet ─────────────────────────────────────────────────

output "shared_vnet_id" {
  description = "Shared spoke VNet ID"
  value       = azurerm_virtual_network.shared_vnet.id
}

output "shared_vnet_name" {
  description = "Shared spoke VNet name"
  value       = azurerm_virtual_network.shared_vnet.name
}

output "shared_subnet_id" {
  description = "Shared subnet ID"
  value       = azurerm_subnet.shared_subnet.id
}

output "app_subnet_id" {
  description = "App subnet ID"
  value       = azurerm_subnet.app_subnet.id
}

output "bastion_subnet_id" {
  description = "Bastion subnet ID"
  value       = azurerm_subnet.bastion_subnet.id
}

# ── Firewall ────────────────────────────────────────────────────

output "firewall_id" {
  description = "Azure Firewall ID (null if not deployed)"
  value       = var.add_firewall ? azurerm_firewall.fw[0].id : null
}

output "firewall_private_ip" {
  description = "Azure Firewall private IP (null if not deployed)"
  value       = var.add_firewall ? azurerm_firewall.fw[0].virtual_hub[0].private_ip_address : null
}

# ── DNS ─────────────────────────────────────────────────────────

output "dns_resolver_policy_id" {
  description = "DNS resolver policy ID (null if Private DNS not deployed)"
  value       = var.add_private_dns ? azapi_resource.dns_security_policy[0].id : null
}

output "dns_inbound_endpoint_ip" {
  description = "DNS resolver inbound endpoint IP (null if Private DNS not deployed)"
  value       = var.add_private_dns ? var.resolver_inbound_endpoint_address : null
}

output "dns_vnet_id" {
  description = "DNS VNet ID (null if Private DNS not deployed)"
  value       = var.add_private_dns ? azurerm_virtual_network.dns_vnet[0].id : null
}

# ── Compute ─────────────────────────────────────────────────────

output "vm_id" {
  description = "Windows VM ID"
  value       = azurerm_windows_virtual_machine.vm.id
}

output "vm_admin_username" {
  description = "Constructed VM admin username"
  value       = azurerm_windows_virtual_machine.vm.admin_username
  sensitive   = true
}

output "bastion_host_id" {
  description = "Bastion Host ID"
  value       = azurerm_bastion_host.bastion.id
}

# ── Private DNS Zone IDs ─────────────────────────────────────────

output "private_dns_zone_ids" {
  description = "Private DNS Zone IDs for application landing zones; values are null when Private DNS is disabled"
  value = {
    blob              = var.add_private_dns ? "${var.resource_group_id}/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net" : null
    file              = var.add_private_dns ? "${var.resource_group_id}/providers/Microsoft.Network/privateDnsZones/privatelink.file.core.windows.net" : null
    table             = var.add_private_dns ? "${var.resource_group_id}/providers/Microsoft.Network/privateDnsZones/privatelink.table.core.windows.net" : null
    queue             = var.add_private_dns ? "${var.resource_group_id}/providers/Microsoft.Network/privateDnsZones/privatelink.queue.core.windows.net" : null
    vaultcore         = var.add_private_dns ? "${var.resource_group_id}/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net" : null
    cognitiveservices = var.add_private_dns ? "${var.resource_group_id}/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com" : null
    openai            = var.add_private_dns ? "${var.resource_group_id}/providers/Microsoft.Network/privateDnsZones/privatelink.openai.azure.com" : null
    services_ai       = var.add_private_dns ? "${var.resource_group_id}/providers/Microsoft.Network/privateDnsZones/privatelink.services.ai.azure.com" : null
    search            = var.add_private_dns ? "${var.resource_group_id}/providers/Microsoft.Network/privateDnsZones/privatelink.search.windows.net" : null
    documents         = var.add_private_dns ? "${var.resource_group_id}/providers/Microsoft.Network/privateDnsZones/privatelink.documents.azure.com" : null
    acr               = var.add_private_dns ? "${var.resource_group_id}/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io" : null
    fabric            = var.add_private_dns ? "${var.resource_group_id}/providers/Microsoft.Network/privateDnsZones/privatelink.fabric.microsoft.com" : null
    sql               = var.add_private_dns ? "${var.resource_group_id}/providers/Microsoft.Network/privateDnsZones/privatelink.database.windows.net" : null
  }
}
