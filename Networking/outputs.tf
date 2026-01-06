output "vm_admin_username" {
  description = "Virtual Machine Admin Username"
  value = azurerm_windows_virtual_machine.vm00.admin_username
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