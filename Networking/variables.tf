/* Define variables for region 0 and region 1 using the region map. Here are common region pairs.
"centralus" = "cus"
"eastus2" = "eus2"
"westus" = "wus"
"eastus" = "eus"
"northcentralus" = "ncus"
"southcentralus" = "scus"
"westcentralus" = "wcus"
"westus2" = "wus2"
"westus3" = "wus3"
"westeurope" = "weu"
"northeurope" = "neu"
"swedencentral" = "sece"
*/
variable "azure_region_0_abbr" {
  description = "Azure Region 0 Abbreviation"
  type = string
  default = "sece"
}
variable "azure_region_0_name" {
  description = "Azure Region 0 Name"
  type = string
  default = "swedencentral"
}
variable "azure_region_1_abbr" {
  description = "Azure Region 1 Abbreviation"
  type = string
  default = "cus"
}
variable "azure_region_1_name" {
  description = "Azure Region 1 Name"
  type = string
  default = "centralus"
}
# KV variables
variable "kv_name" {
  description = "Key Vault Name"
  type = string
  default = "kv00"
}
variable "resource_group_name_KV" {
  description = "Resource Group Name"
  type = string
  default = "rg-kv00"  
}
variable "kv_secret_name" {
  description = "Secret Name"
  type = string
  default = "kvsecret-vmpassword"  
}
# Region 0 permanent resources
variable "resource_group_name_net00" {
  description = "Resource Group Name"
  type = string
  default = "rg-net00"  
}
variable "azurerm_virtual_wan_name" {
  description = "Virtual WAN Name"
  type = string
  default = "vwan"
}
variable "azurerm_virtual_hub00_name" {
  description = "Virtual Hub 00 Name"
  type = string
  default = "vhub00"
}
variable "azurerm_vhub00_address_prefix" {
  description = "value of the address prefix for the virtual hub"
  type = string
  default = "172.30.0.0/23"
}
variable "azurerm_vhub00_route_pref" {
  description = "value of the route preference for the virtual hub"
  type = string
  default = "ExpressRoute"
}
variable "log_analytics_workspace_name" {
  description = "Log Analytics Workspace Name"
  type = string
  default = "law00"
}
variable "shared_vnet_name00" {
  description = "Virtual Network name"
  type = string
  default = "shared-vnet00"
}
variable "shared_vnet_address_space00" {
  description = "Virtual Network address_space"
  type = list(string)
  default = ["172.20.0.0/20"]
}
variable "azurerm_virtual_hub_connection_vhub00_to_shared00" {
  description = "Virtual Hub Connection from vhub00 to shared vnet00"
  type = string
  default = "vhub00-to-shared00"
}
variable "shared_vnet00_dns" {
  description = "Virtual Network DNS Servers"
  type = list(string)
  default = ["172.20.16.4"]
}
variable "shared_subnet_name00" {
  description = "Virtual Network Shared Subnet Name"
  type = string
  default = "shared-subnet00"
}
variable "shared_subnet_address00" {
  description = "Virtual Network Shared Subnet Address Spaces"
  type = list(string)
  default = ["172.20.5.0/24"]
}
variable "app_subnet_name00" {
  description = "Virtual Network App Subnet Name"
  type = string
  default = "app-subnet00"
}
variable "app_subnet_address00" {
  description = "Virtual Network App Subnet Address Spaces"
  type = list(string)
  default = ["172.20.6.0/24"]
}
variable "dns_vnet_name00" {
  description = "Virtual Network name"
  type = string
  default = "dns-vnet00"
}
variable "dns_vnet_address_space00" {
  description = "Virtual Network address_space"
  type = list(string)
  default = ["172.20.16.0/20"]
}
variable "azurerm_virtual_hub_connection_vhub00_to_dns00" {
  description = "Virtual Hub Connection from vhub00 to dns vnet00"
  type = string
  default = "vhub00-to-dns00"
}
variable "resolver_inbound_subnet_name00" {
  description = "Virtual Network Private Resolver Inbound Subnet Name"
  type = string
  default = "resolver-inbound-subnet00"
}
variable "resolver_inbound_subnet_address00" {
  description = "Virtual Network Private Resolver Inbound Subnet Address Spaces"
  type = list(string)
  default = ["172.20.16.0/28"]
}
variable "resolver_inbound_endpoint_address00" {
  description = "Virtual Network Private Resolver Inbound Endpoint Address"
  type = string
  default = "172.20.16.4"
}
variable "resolver_outbound_subnet_name00" {
  description = "Virtual Network Private Resolver Outbound Subnet Name"
  type = string
  default = "resolver-outbound-subnet00"
}
variable "resolver_outbound_subnet_address00" {
  description = "Virtual Network Private Resolver Outbound Subnet Address Spaces"
  type = list(string)
  default = ["172.20.16.16/28"]
}
variable "bastion_pip_name00" {
  description = "Bastion Public IP Name"
  type = string
  default = "bastion-pip00"
}
variable "bastion_host_name00" {
  description = "Bastion Host Name"
  type = string
  default = "bastion-host00"
}
variable "bastion_host_sku00" {
  description = "Bastion Host SKU"
  type = string
  default = "Standard"
}
variable "bastion_subnet_address00" {
  description = "Virtual Network Bastion Subnet Address Spaces"
  type = list(string)
  default = ["172.20.0.0/24"]
}
variable "vm00_nic_name" {
  description = "Virtual Machine 01 NIC Name"
  type = string
  default = "vm00-nic"
}
variable "vm00_name" {
  description = "Virtual Machine 01 Name"
  type = string
  default = "vm00"
}
variable "vm00_size" {
  description = "Virtual Machine Size"
  type = string
  default = "Standard_B2s"
}
variable "vm001_nic_name" {
  description = "Virtual Machine 01 NIC Name"
  type = string
  default = "vm001-nic"
}
variable "vm001_name" {
  description = "Virtual Machine 01 Name"
  type = string
  default = "vm001"
}
variable "vm001_size" {
  description = "Virtual Machine Size"
  type = string
  default = "Standard_B2s"
}
variable "vm_admin_username" {
  description = "Virtual Machine Admin Username"
  type = string
  default = "adminuser"
}
# Region 0 conditional resources
## AI LZ Conditional Variables for region 0
variable "create_AiLZ" {
  description = "Create the AI Landing Zone spoke VNet in each region"
  type        = bool
  default     = false
}
variable "ai_vnet_name00" {
  description = "AI spoke VNet name for region 0"
  type        = string
  default     = "ai-vnet00"
}
variable "ai_vnet_address_space00" {
  description = "AI spoke VNet address space for region 0"
  type        = list(string)
  default     = ["172.20.32.0/20"]
}
variable "azurerm_virtual_hub_connection_vhub00_to_ai00" {
  description = "vHub00 to AI VNet00 connection name"
  type        = string
  default     = "vhub00-to-ai00"
}
variable "ai_foundry_subnet_name00" {
  description = "Virtual Network AI Foundry Subnet Name"
  type = string
  default = "ai-foundry-subnet00"
}
variable "ai_foundry_subnet_address00" {
  description = "AI foundry subnet address prefix for region 0"
  type        = list(string)
  default     = ["172.20.32.0/24"]
}
variable "private_endpoint_subnet_name00" {
  description = "Virtual Network Private Endpoint Subnet Name"
  type = string
  default = "private-endpoint-subnet00"
}
variable "private_endpoint_subnet_address00" {
  description = "Private endpoint subnet address prefix for region 0"
  type        = list(string)
  default     = ["172.20.33.0/24"]
}
## Firewall variables for region 0
variable "add_firewall00" {
  description = "Add Firewall 00"
  type = bool
  default = false
}
variable "firewall_name00" {
  description = "Firewall Name"
  type = string
  default = "firewall00"
}
variable "firewall_SkuName00" {
  description = "Firewall SKU Name"
  type = string
  default = "AZFW_Hub"
}
variable "firewall_SkuTier00" {
  description = "Firewall SKU Tier"
  type = string
  default = "Premium"
}
variable "firewall_policy_name00" {
  description = "Name of the Firewall Policy"
  type = string
  default = "firewall00-policy"
}
variable "firewall_policy_rcg_name00" {
  description = "Name of the Firewall Policy Rule Collection Group"
  type = string
  default = "policy00-firewall00-rcg"
}
variable "firewall_logs_name00" {
  description = "Name of the Firewall Logs"
  type = string
  default = "firewall00-logs"
}
variable "add_privateDNS00" {
  description = "Add Private DNS 00"
  type = bool
  default = false
}
variable "private_resolver_name00" {
  description = "Private Resolver Name"
  type = string
  default = "resolver00"
}
variable "add_s2s_VPN00" {
  description = "Add s2s VPN00"
  type = bool
  default = false
}
variable "s2s_VPN00_name" {
  description = "s2s VPN00 name"
  type = string
  default = "s2s-vpn00"
}
variable "s2s_site00_name" {
  description = "s2s site00 name"
  type = string
  default = "s2s-site00"
}
variable "s2s_VPN00_logs_name" {
  description = "Name of the s2s VPN Logs"
  type = string
  default = "s2sVPN00-logs"
}
variable "s2s_conn00_name" {
  description = "s2s connection00 name"
  type = string
  default = "s2s-conn00"
}
variable "s2s_site00_addresscidr" {
  description = "s2s site00 address cidr"
  type = list(string)
  default = ["10.100.0.0/24"]
}
variable "s2s_site00_ipaddress" {
  description = "s2s site00 ip address"
  type = string
  default = "10.1.0.0"
}
variable "s2s_site00_speed" {
  description = "s2s site00 speed in mbps"
  type = string
  default = "20"
}
# Region 1 conditional resources
variable "create_vhub01" {
  description = "Create Virtual Hub 01"
  type = bool
  default = false
}
variable "resource_group_name_net01" {
  description = "Resource Group Name"
  type = string
  default = "rg-net01"  
}
variable "resource_group_location01" {
  description = "Region in which Azure Resources to be created"
  type = string
  default = "eastus2"  
}
variable "azurerm_virtual_hub01_name" {
  description = "Virtual Hub 01 Name"
  type = string
  default = "vhub01"
}
variable "azurerm_vhub01_address_prefix" {
  description = "value of the address prefix for the virtual hub"
  type = string
  default = "172.30.2.0/23"
}
variable "azurerm_vhub01_route_pref" {
  description = "value of the route preference for the virtual hub"
  type = string
  default = "ExpressRoute"
}
variable "shared_vnet_name01" {
  description = "Virtual Network name"
  type = string
  default = "shared-vnet01"
}
variable "dns_vnet_name01" {
  description = "Virtual Network name"
  type = string
  default = "dns-vnet01"
}
variable "shared_vnet_address_space01" {
  description = "Virtual Network address_space"
  type = list(string)
  default = ["172.21.0.0/20"]
}
variable "dns_vnet_address_space01" {
  description = "Virtual Network address_space"
  type = list(string)
  default = ["172.21.16.0/20"]
}
variable "shared_vnet01_dns" {
  description = "Virtual Network DNS Servers"
  type = list(string)
  default = ["172.21.16.4"]
}
variable "shared_subnet_name01" {
  description = "Virtual Network Shared Subnet Name"
  type = string
  default = "shared-subnet01"
}
variable "shared_subnet_address01" {
  description = "Virtual Network Shared Subnet Address Spaces"
  type = list(string)
  default = ["172.21.5.0/24"]
}
variable "app_subnet_name01" {
  description = "Virtual Network App Subnet Name"
  type = string
  default = "app-subnet01"
}
variable "app_subnet_address01" {
  description = "Virtual Network App Subnet Address Spaces"
  type = list(string)
  default = ["172.21.6.0/24"]
}
variable "azurerm_virtual_hub_connection_vhub01_to_shared01" {
  description = "Virtual Hub Connection from vhub01 to shared vnet01"
  type = string
  default = "vhub01-to-shared01"
}
variable "azurerm_virtual_hub_connection_vhub01_to_dns01" {
  description = "Virtual Hub Connection from vhub01 to dns vnet01"
  type = string
  default = "vhub01-to-dns01"
}
## AI LZ Conditional Variables for region 1
variable "ai_vnet_name01" {
  description = "AI spoke VNet name for region 1"
  type        = string
  default     = "ai-vnet01"
}
variable "ai_vnet_address_space01" {
  description = "AI spoke VNet address space for region 1"
  type        = list(string)
  default     = ["172.21.32.0/20"]
}
variable "azurerm_virtual_hub_connection_vhub01_to_ai01" {
  description = "vHub01 to AI VNet01 connection name"
  type        = string
  default     = "vhub01-to-ai01"
}
variable "ai_foundry_subnet_name01" {
  description = "Virtual Network AI Foundry Subnet Name"
  type = string
  default = "ai-foundry-subnet01"
}
variable "ai_foundry_subnet_address01" {
  description = "AI foundry subnet address prefix for region 1"
  type        = list(string)
  default     = ["172.21.32.0/24"]
}
variable "private_endpoint_subnet_name01" {
  description = "Virtual Network Private Endpoint Subnet Name"
  type = string
  default = "private-endpoint-subnet01"
}
variable "private_endpoint_subnet_address01" {
  description = "Private endpoint subnet address prefix for region 1"
  type        = list(string)
  default     = ["172.21.33.0/24"]
}
## DNS conditional variables for region 1
variable "resolver_inbound_subnet_name01" {
  description = "Virtual Network Private Resolver Inbound Subnet Name"
  type = string
  default = "resolver-inbound-subnet01"
}
variable "resolver_inbound_subnet_address01" {
  description = "Virtual Network Private Resolver Inbound Subnet Address Spaces"
  type = list(string)
  default = ["172.21.16.0/28"]
}
variable "resolver_inbound_endpoint_address01" {
  description = "Virtual Network Private Resolver Inbound Endpoint Address"
  type = string
  default = "172.21.16.4"
}
variable "resolver_outbound_subnet_name01" {
  description = "Virtual Network Private Resolver Outbound Subnet Name"
  type = string
  default = "resolver-outbound-subnet01"
}
variable "resolver_outbound_subnet_address01" {
  description = "Virtual Network Private Resolver Outbound Subnet Address Spaces"
  type = list(string)
  default = ["172.21.16.16/28"]
}
## Bastion conditional variables for region 1
variable "bastion_subnet_name01" {
  description = "Virtual Network Bastion Subnet Name"
  type = string
  default = "AzureBastionSubnet"
}
variable "bastion_pip_name01" {
  description = "Bastion Public IP Name"
  type = string
  default = "bastion-pip01"
}
variable "bastion_host_name01" {
  description = "Bastion Host Name"
  type = string
  default = "bastion-host01"
}
variable "bastion_host_sku01" {
  description = "Bastion Host SKU"
  type = string
  default = "Standard"
}
variable "bastion_subnet_address01" {
  description = "Virtual Network Bastion Subnet Address Spaces"
  type = list(string)
  default = ["172.21.0.0/24"]
}
variable "add_firewall01" {
  description = "Add Firewall 01"
  type = bool
  default = false
}
variable "firewall_name01" {
  description = "Firewall Name"
  type = string
  default = "firewall01"
}
variable "firewall_SkuName01" {
  description = "Firewall SKU Name"
  type = string
  default = "AZFW_Hub"
}
variable "firewall_SkuTier01" {
  description = "Firewall SKU Tier"
  type = string
  default = "Premium"
}
variable "firewall_policy_name01" {
  description = "Name of the Firewall Policy"
  type = string
  default = "firewall01-policy"
}
variable "firewall_logs_name01" {
  description = "Name of the Firewall Logs"
  type = string
  default = "firewall01-logs"
}
variable "firewall_policy_rcg_name01" {
  description = "Name of the Firewall Policy Rule Collection Group"
  type = string
  default = "firewall01-policy-rcg"
}
variable "add_privateDNS01" {
  description = "Add Private DNS 01"
  type = bool
  default = false
}
variable "private_resolver_name01" {
  description = "Private Resolver Name"
  type = string
  default = "resolver01"
}
variable "vm01_nic_name" {
  description = "Virtual Machine 01 NIC Name"
  type = string
  default = "vm01-nic"
}
variable "vm01_name" {
  description = "Virtual Machine 01 Name"
  type = string
  default = "vm01"
}
variable "vm01_size" {
  description = "Virtual Machine Size"
  type = string
  default = "Standard_B2s"
}
# Site-to-Site VPN variables for region 1
variable "add_s2s_VPN01" {
  description = "Add s2s VPN01"
  type = bool
  default = false
}
variable "s2s_VPN01_name" {
  description = "s2s VPN01 name"
  type = string
  default = "s2s-vpn01"
}
variable "s2s_VPN01_logs_name" {
  description = "Name of the s2s VPN Logs"
  type = string
  default = "s2s-vpn01-logs"
}
variable "s2s_site01_name" {
  description = "s2s site01 name"
  type = string
  default = "s2s-site01"
}
variable "s2s_conn01_name" {
  description = "s2s connection01 name"
  type = string
  default = "s2s-conn01"
}
variable "s2s_site01_addresscidr" {
  description = "s2s site01 address cidr"
  type = list(string)
  default = ["10.100.0.0/24"]
}
variable "s2s_site01_ipaddress" {
  description = "s2s site01 ip address"
  type = string
  default = "10.2.0.0"
}
variable "s2s_site01_speed" {
  description = "s2s site01 speed in mbps"
  type = string
  default = "20"
}