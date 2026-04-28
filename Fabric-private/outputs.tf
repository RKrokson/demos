output "resource_group_id" {
  description = "The ID of the Fabric resource group"
  value       = azurerm_resource_group.rg_fabric00.id
}

output "fabric_capacity_id" {
  description = "The ID of the Fabric capacity"
  value       = azurerm_fabric_capacity.fabric_capacity.id
}

output "fabric_workspace_id" {
  description = "The ID of the Fabric workspace"
  value       = fabric_workspace.workspace.id
}

output "storage_account_id" {
  description = "The ID of the lab storage account"
  value       = azurerm_storage_account.lab_storage.id
}

output "sql_server_id" {
  description = "The ID of the lab SQL server"
  value       = azurerm_mssql_server.lab_sql.id
}

output "sql_database_id" {
  description = "The ID of the lab SQL database"
  value       = azurerm_mssql_database.lab_db.id
}

output "mpe_storage_id" {
  description = "The ID of the Storage blob MPE"
  value       = fabric_workspace_managed_private_endpoint.mpe_storage.id
}

output "mpe_sql_id" {
  description = "The ID of the SQL Server MPE"
  value       = fabric_workspace_managed_private_endpoint.mpe_sql.id
}

output "key_vault_id" {
  description = "The ID of the LZ-local Fabric Key Vault"
  value       = azurerm_key_vault.fabric_kv.id
}

output "mpe_keyvault_id" {
  description = "The ID of the Key Vault MPE"
  value       = fabric_workspace_managed_private_endpoint.mpe_keyvault.id
}

output "workspace_private_link_service_id" {
  description = "The ARM resource ID of the Fabric workspace private link service"
  value       = azapi_resource.fabric_private_link_service.id
}

output "workspace_private_endpoint_id" {
  description = "The resource ID of the Fabric workspace private endpoint"
  value       = azurerm_private_endpoint.pe_fabric_workspace.id
}

output "workspace_private_endpoint_ip" {
  description = "The private IP address assigned to the Fabric workspace private endpoint"
  value       = azurerm_private_endpoint.pe_fabric_workspace.private_service_connection[0].private_ip_address
}
