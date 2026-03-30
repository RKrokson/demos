# Azure Demo Lab — Infrastructure as Code

Terraform modules for deploying Azure networking and AI Foundry lab environments. This repo is for demos and testing, not production.

## Landing Zone Model

This repo follows a two-tier landing zone pattern:

```
┌─────────────────────────────────────────────────────┐
│          Application Landing Zones                  │
│                                                     │
│  ┌─────────────────┐    ┌───────────────────────┐   │
│  │ Foundry-byoVnet │    │ Foundry-managedVnet   │   │
│  └────────┬────────┘    └───────────┬───────────┘   │
│           │                        │                │
│           │  terraform_remote_state                 │
│           │  (../Networking/terraform.tfstate)       │
│           │                        │                │
├───────────┼────────────────────────┼────────────────┤
│           ▼                        ▼                │
│            Platform Landing Zone                    │
│                                                     │
│  ┌────────────────────────────────────────────────┐  │
│  │ Networking/                                    │  │
│  │ vWAN · Hubs · VNets · Firewall · DNS           │  │
│  └────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

**Platform Landing Zone** — Shared networking foundation that all workloads depend on.

| Folder | Layer | Description | Docs |
|---|---|---|---|
| `Networking/` | Platform | Azure Virtual WAN, hubs, spoke VNets, optional Firewall and Private DNS | [README](./Networking/README.md) |

**Application Landing Zones** — Optional workloads that plug into the platform. Pick one approach or neither. Do not deploy both Foundry modules at the same time.

| Folder | Layer | Description | Docs |
|---|---|---|---|
| `Foundry-byoVnet/` | Application | AI Foundry with private endpoints in a BYO VNet | [README](./Foundry-byoVnet/README.md) |
| `Foundry-managedVnet/` | Application | AI Foundry with private endpoints in a Microsoft-managed VNet | [README](./Foundry-managedVnet/README.md) |

Future modules will follow the same application landing zone pattern. See the [Adding a New Application Landing Zone](./docs/adding-application-landing-zone.md) guide.

## Prerequisites

- Azure CLI installed and authenticated (`az login`)
- Terraform >= 1.8.3
- `ARM_SUBSCRIPTION_ID` environment variable set (see `setSubscription.ps1`)
- Git

## Getting Started

1. Clone the repo and cd into it.

2. Set your subscription:
   ```powershell
   .\setSubscription.ps1
   ```

3. Deploy the platform landing zone:
   ```sh
   cd Networking
   terraform init
   terraform plan
   terraform apply
   ```

4. (Optional) Deploy an application landing zone. Each Foundry module creates its own spoke VNet. If you need private DNS resolution, set `add_private_dns00 = true` in your Networking tfvars and re-apply before deploying a Foundry module.
   ```sh
   cd ../Foundry-byoVnet   # or Foundry-managedVnet
   terraform init
   terraform plan
   terraform apply
   ```

See each module's README for configuration details and tfvars examples.

## Destroy Order

Tear down in reverse order. Destroy application landing zones first, then the platform.

1. Destroy the Foundry module:
   ```sh
   cd Foundry-byoVnet   # or Foundry-managedVnet
   terraform destroy
   ```
2. Purge the soft-deleted AI Foundry resource. The subnet service association link blocks Networking deletion until this is done. Wait about 10 minutes after purge.
   - [Purge a deleted resource](https://learn.microsoft.com/en-us/azure/ai-services/recover-purge-resources?tabs=azure-cli#purge-a-deleted-resource)
3. Destroy the platform:
   ```sh
   cd ../Networking
   terraform destroy
   ```

See each module's README for detailed cleanup steps and troubleshooting.

## Cost Estimates

This is for demos and labs. Deploy and delete as needed. Don't leave resources running long-term. You can power off VMs and Azure Firewall to save costs when not in use. Use the [Azure Calculator](https://azure.microsoft.com/en-us/pricing/calculator/) for your own estimate.

Rough estimate using Central US, single region:

| Resource | Daily (24h) | Monthly (730h) |
|---|---|---|
| Azure vWAN | $6 | $182.50 |
| Azure Firewall Premium | $42 | $1,277.50 |
| VM (Standard_B2s w/ Windows) | $1.19 | $36.21 |

## Disclaimer

The attached diagrams and code are provided AS IS without warranty of any kind and should not be interpreted as an offer or commitment on the part of Microsoft, and Microsoft cannot guarantee the accuracy of any information presented. MICROSOFT MAKES NO WARRANTIES, EXPRESS OR IMPLIED, IN THIS DIAGRAM(s) CODE SAMPLE(s).
