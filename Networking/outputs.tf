output "vm_admin_username" {
  description = "Virtual Machine Admin Username"
  value = azurerm_linux_virtual_machine.vm00.admin_username
}
output "rg_net00_id" {
  description = "The ID of the Networking Resource Group."
  value = azurerm_resource_group.rg-net00.id
}
output "rg_net00_location" {
  description = "The location of the Networking Resource Group."
  value = azurerm_resource_group.rg-net00.location
}
output "azure_region_0_abbr" {
  description = "The abbreviation of the Azure 0 region."
  value = var.azure_region_0_abbr
}
output "private_endpoint_subnet00_id" {
  value = azurerm_subnet.private_endpoint_subnet00[0].id
  description = "The ID of the AI Foundry private endpoint subnet."
}
output "ai_foundry_subnet00_id" {
  value = azurerm_subnet.ai_foundry_subnet00[0].id
  description = "The ID of the AI Foundry subnet."
}