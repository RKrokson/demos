terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0, < 5.0"
    }
    random = {
      source = "hashicorp/random"
      version = "~>3.5"
    }
    azapi = {
      source  = "azure/azapi"
      version = ">= 2.0, < 3.0"
    }
  }
}
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = false
      purge_soft_deleted_secrets_on_destroy = true
      recover_soft_deleted_secrets          = false
    }
  }
}
