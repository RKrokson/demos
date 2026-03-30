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

## Data imports
##

data "terraform_remote_state" "networking" {
  backend = "local"
  config = {
    path = "../Networking/terraform.tfstate"
  }
}

data "azurerm_client_config" "current" {}

## Create a resource group for Foundry resources
##
resource "azurerm_resource_group" "rg-ai01" {
  name     = "${var.resource_group_name_ai01}-${data.terraform_remote_state.networking.outputs.azure_region_0_abbr}-${random_string.unique.result}"
  location = data.terraform_remote_state.networking.outputs.rg_net00_location
  tags     = local.common_tags
}
