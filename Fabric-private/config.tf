# Configure providers for Fabric BYO VNet module
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.26.0"
    }

    azapi = {
      source  = "azure/azapi"
      version = "~> 2.3.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }

    fabric = {
      source  = "microsoft/fabric"
      version = "~> 1.0"
    }
  }
  required_version = ">= 1.8.3"
  # Uncomment to store state in Azure Storage
  # backend "azurerm" {}
}

provider "azurerm" {
  features {
    resource_group {
      # Disabled to allow clean terraform destroy in this non-production environment.
      prevent_deletion_if_contains_resources = false
    }
  }
  storage_use_azuread = true
}
