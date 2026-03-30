# Adding a New Application Landing Zone

This guide walks through creating a new Terraform module that plugs into the platform landing zone (Networking).

## Folder Structure

Create a new folder at the repo root. Name it after your workload. Each ALZ module needs these files:

```
My-Workload/
├── config.tf       # Provider and backend configuration
├── locals.tf       # Common tags and computed values
├── main.tf         # Resources
├── outputs.tf      # Module outputs
├── variables.tf    # Input variables
└── README.md       # Module documentation
```

## Remote State Setup

Your module reads platform outputs from the Networking module's local state file. Add this data source to `main.tf`:

```hcl
data "terraform_remote_state" "networking" {
  backend = "local"
  config = {
    path = "../Networking/terraform.tfstate"
  }
}
```

Then reference platform outputs like this:

```hcl
resource "azurerm_resource_group" "rg" {
  name     = "rg-myworkload-${data.terraform_remote_state.networking.outputs.azure_region_0_abbr}-${random_string.unique.result}"
  location = data.terraform_remote_state.networking.outputs.rg_net00_location
  tags     = local.common_tags
}
```

## Available Platform Outputs

The Networking module exposes resource group info, subnet IDs, hub IDs, Key Vault, Log Analytics, and private DNS zone IDs. See the full list in the [Networking README outputs table](../Networking/README.md#outputs--platform-to-alz-contract).

Key outputs you will likely need:

- `rg_net00_location` and `azure_region_0_abbr` for region and naming
- `ai_foundry_subnet00_id` and `private_endpoint_subnet00_id` for subnet placement
- `dns_zone_*` outputs for private endpoint DNS integration
- `key_vault_id` and `log_analytics_workspace_id` for shared services

Most outputs are conditional. Subnet and DNS zone outputs return `null` when their toggle variable is `false` in the Networking module.

## Naming Conventions

Follow the existing pattern: `{name}-{region_abbr}-{random_suffix}`

```hcl
resource "random_string" "unique" {
  length  = 4
  special = false
  upper   = false
  numeric = true
  lower   = true
}
```

Use the region abbreviation from platform outputs (`data.terraform_remote_state.networking.outputs.azure_region_0_abbr`) and append the random string to avoid collisions.

## Provider Configuration

Match the version constraints and features block from the existing Foundry modules:

```hcl
# config.tf
terraform {
  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.3.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.26.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
  required_version = ">= 1.8.3"
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  storage_use_azuread = true
}
```

Notes:
- `prevent_deletion_if_contains_resources = false` is for demo/lab use only. Set to `true` in production.
- `storage_use_azuread = true` enables Entra ID auth for storage operations.
- Only add `azapi` if you need it. Some workloads only need `azurerm`.

## Tags

Define common tags in `locals.tf` and apply them to every taggable resource:

```hcl
# locals.tf
locals {
  common_tags = {
    environment = "non-prod"
    managed_by  = "terraform"
    project     = "azure-infra-poc"
  }
}
```

Then on each resource:

```hcl
tags = local.common_tags
```

Not all resources support tags. Skip subnets, hub connections, diagnostic settings, and role assignments. If using `azapi_resource`, only add tags to tracked resources that have a `location` property.

## Prerequisites for the Platform

Before your ALZ module can run, the Networking module must be applied with the right toggles. At minimum you need `create_ai_lz = true` to get the AI spoke VNet. If your workload needs private DNS resolution, also set `add_private_dns00 = true`.

Document these requirements in your module's README under Prerequisites.

## README Template

Your module README should have these sections:

```markdown
# Application Landing Zone — [Workload Name]

One paragraph: what this module deploys and why.

## Prerequisites

- All [platform landing zone prerequisites](../README.md#prerequisites)
- Platform Landing Zone (`Networking/`) must be applied first with `create_ai_lz = true`
- [Any additional requirements specific to your workload]

## Quick Start

\```sh
cd My-Workload
terraform init
terraform plan
terraform apply
\```

## Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| ... | ... | ... | ... |

## Outputs

| Output Name | Description |
|---|---|
| ... | ... |

## Cleanup Steps

[Steps to destroy cleanly, including any soft-delete purge requirements]

## Troubleshooting

[Common errors and fixes]
```

## Checklist

Before submitting your new ALZ module:

- [ ] `terraform validate` passes
- [ ] `terraform fmt -check` passes
- [ ] Remote state data source reads from `../Networking/terraform.tfstate`
- [ ] All taggable resources use `local.common_tags`
- [ ] Naming follows `{name}-{region_abbr}-{random_suffix}` pattern
- [ ] README follows the template above
- [ ] Root README updated with your module in the Application Landing Zones table
