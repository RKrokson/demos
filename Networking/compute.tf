resource "azurerm_public_ip" "bastion_pip00" {
  name                = "${var.bastion_pip_name00}-${var.azure_region_0_abbr}"
  location            = local.rg00_location
  resource_group_name = local.rg00_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}
resource "azurerm_bastion_host" "bastion_host00" {
  name                = "${var.bastion_host_name00}-${var.azure_region_0_abbr}"
  location            = local.rg00_location
  resource_group_name = local.rg00_name
  sku                 = var.bastion_host_sku00
  tags                = local.common_tags
  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion_subnet00.id
    public_ip_address_id = azurerm_public_ip.bastion_pip00.id
  }
}
resource "azurerm_network_interface" "vm00_nic" {
  name                = "${var.vm00_nic_name}-${var.azure_region_0_abbr}"
  location            = local.rg00_location
  resource_group_name = local.rg00_name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.shared_subnet00.id
    private_ip_address_allocation = "Dynamic"
  }
}
resource "azurerm_windows_virtual_machine" "vm00" {
  name                = "${var.vm00_name}-${var.azure_region_0_abbr}"
  location            = local.rg00_location
  resource_group_name = local.rg00_name
  size                = var.vm00_size
  admin_username      = "${local.suffix}${var.vm_admin_username}"
  network_interface_ids = [
    azurerm_network_interface.vm00_nic.id,
  ]
  admin_password                                         = data.azurerm_key_vault_secret.vm_password.value
  patch_mode                                             = "AutomaticByPlatform"
  bypass_platform_safety_checks_on_user_schedule_enabled = true
  tags                                                   = local.common_tags
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-datacenter-azure-edition"
    version   = "latest"
  }
}
# Region 1 compute resources
resource "azurerm_public_ip" "bastion_pip01" {
  count               = var.create_vhub01 ? 1 : 0
  name                = "${var.bastion_pip_name01}-${var.azure_region_1_abbr}"
  location            = azurerm_resource_group.rg-net01[0].location
  resource_group_name = azurerm_resource_group.rg-net01[0].name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}
resource "azurerm_bastion_host" "bastion_host01" {
  count               = var.create_vhub01 ? 1 : 0
  name                = "${var.bastion_host_name01}-${var.azure_region_1_abbr}"
  location            = azurerm_resource_group.rg-net01[0].location
  resource_group_name = azurerm_resource_group.rg-net01[0].name
  sku                 = var.bastion_host_sku01
  tags                = local.common_tags
  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion_subnet01[0].id
    public_ip_address_id = azurerm_public_ip.bastion_pip01[0].id
  }
}
resource "azurerm_network_interface" "vm01_nic" {
  count               = var.create_vhub01 ? 1 : 0
  name                = "${var.vm01_nic_name}-${var.azure_region_1_abbr}"
  location            = azurerm_resource_group.rg-net01[0].location
  resource_group_name = azurerm_resource_group.rg-net01[0].name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.shared_subnet01[0].id
    private_ip_address_allocation = "Dynamic"
  }
}
resource "azurerm_windows_virtual_machine" "vm01" {
  count               = var.create_vhub01 ? 1 : 0
  name                = "${var.vm01_name}-${var.azure_region_1_abbr}"
  location            = azurerm_resource_group.rg-net01[0].location
  resource_group_name = azurerm_resource_group.rg-net01[0].name
  size                = var.vm01_size
  admin_username      = "${local.suffix}${var.vm_admin_username}"
  network_interface_ids = [
    azurerm_network_interface.vm01_nic[0].id,
  ]
  admin_password                                         = data.azurerm_key_vault_secret.vm_password.value
  patch_mode                                             = "AutomaticByPlatform"
  bypass_platform_safety_checks_on_user_schedule_enabled = true
  tags                                                   = local.common_tags
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-datacenter-azure-edition"
    version   = "latest"
  }
}
