variable "resource_group_name_ai01" {
  description = "Resource Group Name"
  type        = string
  default     = "rg-ai01"
}

## Spoke VNet variables
## WARNING: Default address spaces use Block 3 (172.20.48.0/20). Block 2 is reserved for Foundry-byoVnet.
## See docs/ip-addressing.md for the full allocation table.
variable "ai_vnet_name" {
  description = "AI spoke VNet name"
  type        = string
  default     = "ai-vnet"
}
variable "ai_vnet_address_space" {
  description = "AI spoke VNet address space (Block 3 — 172.20.48.0/20)"
  type        = list(string)
  default     = ["172.20.48.0/20"]
}
variable "ai_foundry_subnet_name" {
  description = "Foundry workload subnet name (Microsoft.App delegation)"
  type        = string
  default     = "ai-foundry-subnet"
}
variable "ai_foundry_subnet_address" {
  description = "Foundry workload subnet address prefix"
  type        = list(string)
  default     = ["172.20.48.0/26"]
}
variable "private_endpoint_subnet_name" {
  description = "Private endpoint subnet name"
  type        = string
  default     = "private-endpoint-subnet"
}
variable "private_endpoint_subnet_address" {
  description = "Private endpoint subnet address prefix"
  type        = list(string)
  default     = ["172.20.49.0/24"]
}
variable "connect_to_vhub" {
  description = "Whether to connect the AI spoke VNet to the platform vHub"
  type        = bool
  default     = true
}
variable "enable_dns_link" {
  description = "Whether to link the AI spoke VNet to the platform DNS resolver policy (requires Private DNS deployed in Networking)"
  type        = bool
  default     = false
}