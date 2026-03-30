# Platform Landing Zone — Networking

This is the shared networking foundation that all application landing zones in this repo depend on. It deploys an Azure Virtual WAN environment for demos and labs (not production).

## What Gets Deployed

The base deployment creates a Virtual WAN, a virtual hub, a spoke VNet, and a test VM. Boolean variables toggle optional components. All default to `false`.

### Conditional Variables

| Variable | Default | What It Enables |
|---|---|---|
| `create_vhub01` | `false` | Second region (hub, VNets, VMs) |
| `add_firewall00` | `false` | Azure Firewall in region 0 |
| `add_firewall01` | `false` | Azure Firewall in region 1 (requires `create_vhub01`) |
| `add_private_dns00` | `false` | Private DNS Resolver in region 0 |
| `add_private_dns01` | `false` | Private DNS Resolver in region 1 (requires `create_vhub01`) |

## Quick Start

```sh
cd Networking
terraform init
terraform plan
terraform apply
```

Create a `terraform.tfvars` file to enable optional components (see [Using the Conditionals](#using-the-conditionals) below).

## Prerequisites

- Azure CLI installed and authenticated (`az login`)
- Terraform >= 1.8.3
- `ARM_SUBSCRIPTION_ID` environment variable set (see `setSubscription.ps1` in the repo root)
- Sufficient Azure quota in your target region(s)

## Downstream Dependencies

Application landing zone modules (`Foundry-byoVnet/`, `Foundry-managedVnet/`) consume this module's outputs via `terraform_remote_state` (local backend, reads `./terraform.tfstate`). Each Foundry module creates its own spoke VNet and subnets — no Networking toggle is required. If you need private DNS resolution for Foundry, set `add_private_dns00 = true`.

## Outputs — Platform-to-ALZ Contract

Application landing zones consume these outputs via `terraform_remote_state`. This is the interface between the platform and ALZ layers.

| Output Name | Description |
|---|---|
| `vm_admin_username` | Virtual Machine Admin Username |
| `rg_net00_id` | The ID of the Networking Resource Group |
| `rg_net00_name` | The name of the Networking Resource Group |
| `rg_net00_location` | The location of the Networking Resource Group |
| `azure_region_0_abbr` | The abbreviation of the Azure 0 region |
| `add_firewall00` | Whether Azure Firewall is deployed in region 0 |
| `vhub00_id` | The ID of Virtual Hub 00 |
| `vhub01_id` | The ID of Virtual Hub 01 (null if `create_vhub01 = false`) |
| `log_analytics_workspace_id` | The ID of the Log Analytics Workspace |
| `key_vault_id` | The ID of Key Vault |
| `key_vault_name` | The name of Key Vault |
| `dns_resolver_policy00_id` | The DNS resolver policy ID (null if `add_private_dns00 = false`) |
| `dns_inbound_endpoint00_ip` | The DNS resolver inbound endpoint IP (null if `add_private_dns00 = false`) |
| `dns_zone_blob_id` | Private DNS Zone ID for `privatelink.blob.core.windows.net` |
| `dns_zone_file_id` | Private DNS Zone ID for `privatelink.file.core.windows.net` |
| `dns_zone_table_id` | Private DNS Zone ID for `privatelink.table.core.windows.net` |
| `dns_zone_queue_id` | Private DNS Zone ID for `privatelink.queue.core.windows.net` |
| `dns_zone_vaultcore_id` | Private DNS Zone ID for `privatelink.vaultcore.azure.net` |
| `dns_zone_cognitiveservices_id` | Private DNS Zone ID for `privatelink.cognitiveservices.azure.com` |
| `dns_zone_openai_id` | Private DNS Zone ID for `privatelink.openai.azure.com` |
| `dns_zone_services_ai_id` | Private DNS Zone ID for `privatelink.services.ai.azure.com` |
| `dns_zone_search_id` | Private DNS Zone ID for `privatelink.search.windows.net` |
| `dns_zone_documents_id` | Private DNS Zone ID for `privatelink.documents.azure.com` |

DNS zone outputs are null when `add_private_dns00 = false`.

## Notes

Azure Firewall is deployed with Routing Intent enabled for both Private and Internet traffic. The firewall policy allows any/any by default. Update firewall rules as needed for your tests.

Azure DNS Private Zones are deployed using the Azure Verified Module "Private Link Private DNS Zones" under Pattern Modules. This deploys every available privatelink zone with a few exceptions. The most important exception is `privatelink.{dnsPrefix}.database.windows.net`. You'll have to manually create this zone if you need it.

- [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/indexes/terraform/tf-pattern-modules/)
- [Exceptions list](https://github.com/Azure/terraform-azurerm-avm-ptn-network-private-link-private-dns-zones?tab=readme-ov-file#-private_link_private_dns_zones)

## Regions

The default primary region (region 0) is Sweden Central. The default secondary region (region 1) is Central US. Change these in the variables file — update both the full region name and abbreviation.

![Regions](./diagrams/region-vars-v1.1.png)

## VM Sizing

The default VM size is Standard_B2s. If you hit capacity constraints, override it in your tfvars.

![VM Size Variable](./diagrams/vm-size-vars.png)

## Using the Conditionals

All conditionals default to `false`. To enable them, create a `terraform.tfvars` file. Two examples are included:

- `terraform.tfvars.example` — Simple, conditionals only.
- `terraform.tfvars.advanced.example` — Conditionals plus custom IP address ranges.

Rename either file to `terraform.tfvars`, set the values you want to `true`, then run `terraform plan` and `terraform apply`.

## Examples

Below are examples of various configurations you can build with different tfvars combinations.

### 1 Region, vHub, w/ DNS

![Diagram](./diagrams/1reg-hub-dns-vpn-v1.1.png)
![tfvars](./diagrams/1reg-hub-dns-vpn-vars-v1.1.png)

### 1 Region, vHub (default deployment, no tfvars)

![Diagram](./diagrams/1reg-hub-ndns-nvpn-v1.1.png)
![tfvars](./diagrams/1reg-hub-ndns-nvpn-vars-v1.1.png)

### 1 Region, Secure Hub, w/ DNS

![Diagram](./diagrams/1reg-shub-dns-vpn-v1.1.png)
![tfvars](./diagrams/1reg-shub-dns-vpn-vars-v1.1.png)

### 1 Region, Secure Hub

![Diagram](./diagrams/1reg-shub-ndns-nvpn-v1.1.png)
![tfvars](./diagrams/1reg-shub-ndns-nvpn-vars-v1.1.png)

### 2 Regions, vHub, w/ DNS

![Diagram](./diagrams/2reg-hub-dns-vpn-v1.1.png)
![tfvars](./diagrams/2reg-hub-dns-vpn-vars-v1.1.png)

### 2 Regions, Secure vHub, w/ DNS

![Diagram](./diagrams/2reg-shub-dns-vpn-v1.1.png)
![tfvars](./diagrams/2reg-shub-dns-vpn-vars-v1.1.png)

### Add-on — AI Foundry (deploy a Foundry module separately)

Each Foundry module creates its own spoke VNet. See the [Foundry-byoVnet](../Foundry-byoVnet/README.md) or [Foundry-managedVnet](../Foundry-managedVnet/README.md) README for details.
