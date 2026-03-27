# Copilot Instructions

## Project Overview

This repo contains Azure infrastructure-as-code (Terraform) for demo/lab environments. It is organized as three independent Terraform root modules with a dependency chain:

1. **`Networking/`** — Foundation layer. Deploys Azure Virtual WAN, virtual hubs, spoke VNets, and optional components (Azure Firewall, Private DNS, VPN Gateway, AI Landing Zone VNet). Must be applied first.
2. **`Foundry-byoVnet/`** — Deploys Azure AI Foundry with private endpoints into a BYO VNet created by the Networking layer.
3. **`Foundry-managedVnet/`** — Deploys Azure AI Foundry with private endpoints in a Microsoft-managed VNet.

The Foundry modules depend on `Networking/` via `terraform_remote_state` (local backend, reads `../Networking/terraform.tfstate`). The Networking module must be applied with `create_AiLZ = true` before either Foundry module can be applied.

## Terraform Commands

Each module is a standalone root module — run commands from within its directory:

```sh
cd Networking       # or Foundry-byoVnet, Foundry-managedVnet
terraform init
terraform plan
terraform apply
terraform destroy
```

Target a single resource:

```sh
terraform plan -target=azurerm_virtual_network.shared_vnet00
terraform apply -target=azurerm_virtual_network.shared_vnet00
```

Validate syntax without deploying:

```sh
terraform validate
terraform fmt -check
```

## Architecture Patterns

### Conditional deployments

The Networking module uses boolean variables to toggle optional components. Defaults are all `false`. Override via a `terraform.tfvars` file (gitignored — see `.example` files for templates):

| Variable | Controls |
|---|---|
| `create_vhub01` | Second region (hub, VNets, VMs) |
| `create_AiLZ` | AI Landing Zone spoke VNet (required before Foundry modules) |
| `add_firewall00` / `add_firewall01` | Azure Firewall per region |
| `add_privateDNS00` / `add_privateDNS01` | Private DNS Resolver per region |
| `add_s2s_VPN00` / `add_s2s_VPN01` | Site-to-Site VPN Gateway per region |

### Multi-region naming convention

Resources use a `{name}-{region_abbr}-{random_suffix}` pattern. Region abbreviations (e.g., `sece` for Sweden Central, `cus` for Central US) are defined in `variables.tf`. A 4-digit random numeric suffix is appended to avoid naming collisions.

### Provider versions

- `Networking/`: `azurerm >= 4.0, < 5.0`, `azapi >= 2.0, < 3.0`, `random ~> 3.5`
- `Foundry-*`: `azurerm ~> 4.26.0`, `azapi ~> 2.3.0` (pinned more tightly)

### Secrets handling

VM passwords are auto-generated via `random_password` and stored in Azure Key Vault. Never hardcode credentials in `.tf` files.

## Cleanup Gotchas

- After `terraform destroy` on a Foundry module, the AI Foundry resource enters soft-delete. You must purge it before destroying the Networking layer, or the subnet service association link will block deletion.
- For the managed VNet Foundry module, remove the managed network from state first: `terraform state rm azapi_resource.managed_network`
- Ghost DNS resolver resources may require a manual REST API delete (see `Foundry-byoVnet/README.md` for the example).

## Prerequisites

- Azure CLI (`az`) authenticated and subscription set (see `setSubscription.ps1`)
- Terraform >= 1.8.3
- `ARM_SUBSCRIPTION_ID` environment variable set for the azurerm provider
