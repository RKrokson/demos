########## Create infrastructure resources
##########

## Create a random string
##
resource "random_string" "unique" {
  length      = 4
  min_numeric = 4
  numeric     = true
  special     = false
  lower       = true
  upper       = false
}

## Data imports from Networking
##

data "terraform_remote_state" "networking" {
  backend = "local"
  config = {
    path = "../Networking/terraform.tfstate"
  }
}

# Precondition: Private DNS must be deployed in the Networking module
# The ACA ALZ requires DNS server IP, resolver policy, and DNS VNet for private endpoint resolution
check "dns_prerequisite" {
  assert {
    condition     = local.platform_region0.dns_server_ip != null
    error_message = "Private DNS must be enabled in the Networking module (add_private_dns00 = true) before deploying this landing zone. DNS zones and resolver are required for private endpoint resolution."
  }
  assert {
    condition     = local.platform_region0.dns_resolver_policy_id != null
    error_message = "DNS resolver policy must exist in the Networking module. Ensure add_private_dns00 = true."
  }
  assert {
    condition     = local.platform_region0.dns_vnet_id != null
    error_message = "DNS VNet must exist in the Networking module. Ensure add_private_dns00 = true."
  }
}

## Create a resource group for Container Apps resources
##
resource "azurerm_resource_group" "rg_aca00" {
  name     = "${var.resource_group_name}-${local.platform_region0.region_abbr}-${random_string.unique.result}"
  location = local.platform_region0.resource_group_location
  tags     = local.common_tags
}
