output "resource_group_id" {
  description = "The ID of the Container Apps resource group"
  value       = azurerm_resource_group.rg_aca00.id
}

output "aca_environment_id" {
  description = "The ID of the Container Apps Environment"
  value       = azurerm_container_app_environment.aca_env.id
}

output "aca_environment_default_domain" {
  description = "The default domain of the Container Apps Environment"
  value       = azurerm_container_app_environment.aca_env.default_domain
}

output "aca_environment_static_ip" {
  description = "The static IP address of the Container Apps Environment internal load balancer"
  value       = azurerm_container_app_environment.aca_env.static_ip_address
}

output "acr_id" {
  description = "The ID of the Azure Container Registry"
  value       = azurerm_container_registry.acr.id
}

output "acr_login_server" {
  description = "The login server URL of the Azure Container Registry"
  value       = azurerm_container_registry.acr.login_server
}

output "aca_identity_id" {
  description = "The ID of the user-assigned managed identity for ACA"
  value       = azurerm_user_assigned_identity.aca_identity.id
}

output "sample_app_id" {
  description = "The ID of the sample hello-world container app"
  value       = azurerm_container_app.hello_world.id
}

output "aca_vnet_id" {
  description = "The ID of the ACA spoke VNet"
  value       = azurerm_virtual_network.aca_vnet.id
}
