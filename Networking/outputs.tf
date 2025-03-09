output "vm_admin_username" {
  description = "Virtual Machine Admin Username"
  value = azurerm_linux_virtual_machine.vm00.admin_username
}