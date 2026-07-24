########## Fabric private — Core resources & preconditions
##########

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

data "azurerm_client_config" "current" {}

# Resolve current user UPN when neither admin input is set (zero-config first run)
data "external" "current_user_upn" {
  count   = (length(var.capacity_admin_upn_list) == 0 && var.capacity_admin_group_object_id == null) ? 1 : 0
  program = ["pwsh", "-NoProfile", "-Command", "az ad signed-in-user show --query '{upn:userPrincipalName}' -o json"]
}

## Resource group
##

resource "azurerm_resource_group" "rg_fabric00" {
  name     = "${var.resource_group_name}-${local.platform_region0.region_abbr}-${random_string.unique.result}"
  location = local.platform_region0.resource_group_location
  tags     = local.common_tags
}

## Precondition checks
##

check "dns_prerequisite" {
  assert {
    condition     = local.platform_region0.dns_server_ip != null
    error_message = "Private DNS must be enabled in the Networking module (add_private_dns00 = true) before deploying this landing zone."
  }
}

check "fabric_dns_zone_present" {
  assert {
    condition     = local.platform_region0.private_dns_zone_ids.fabric != null
    error_message = "alz_regions.region0.private_dns_zone_ids.fabric is null in Networking remote state. Ensure the Networking module exposes privatelink.fabric.microsoft.com zone output."
  }
}

check "sql_dns_zone_present" {
  assert {
    condition     = local.platform_region0.private_dns_zone_ids.sql != null
    error_message = "alz_regions.region0.private_dns_zone_ids.sql is null in Networking remote state. Ensure the Networking module exposes privatelink.database.windows.net zone output."
  }
}

check "vhub_present" {
  assert {
    condition     = local.platform_region0.vhub_id != null
    error_message = "alz_regions.region0.vhub_id is null — Virtual Hub must be deployed in the Networking module."
  }
}

check "exactly_one_admin_source" {
  assert {
    condition     = !(length(var.capacity_admin_upn_list) > 0 && var.capacity_admin_group_object_id != null)
    error_message = "Set either capacity_admin_upn_list OR capacity_admin_group_object_id, not both."
  }
}
