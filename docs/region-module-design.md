# Design: `modules/region-hub/` Child Module

> ✅ **Implemented** — see `Networking/modules/region-hub/`. The design below was built as specified.

> **Author:** Carl (Lead / Architect)  
> **Date:** 2025-07-27  
> **Status:** Implemented  
> **Constraint:** Ryan-approved — flat per-region variables preserved; `create_vhub01` boolean toggle retained; NO region map variable.

---

## 1. Module Boundary

The `region-hub` child module encapsulates **all per-region resources** that are duplicated between region 0 and region 1. The root module calls it once unconditionally (region 0) and once conditionally (region 1, gated by `create_vhub01`).

### Resources moving INTO `modules/region-hub/`

**Hub (from vwan.tf):**

| # | Resource Type | Current Name (region 0 / 1) | Child Module Name |
|---|---|---|---|
| 1 | `azurerm_virtual_hub` | `vhub00` / `vhub01` | `hub` |
| 2 | `azurerm_virtual_hub_routing_intent` | `vhub_routing_intent00` / `01` | `routing_intent` |

**Shared VNet & Subnets (from main.tf):**

| # | Resource Type | Current Name (region 0 / 1) | Child Module Name |
|---|---|---|---|
| 3 | `azurerm_virtual_network` | `shared_vnet00` / `01` | `shared_vnet` |
| 4 | `azurerm_subnet` | `shared_subnet00` / `01` | `shared_subnet` |
| 5 | `azurerm_subnet` | `app_subnet00` / `01` | `app_subnet` |
| 6 | `azurerm_subnet` | `bastion_subnet00` / `01` | `bastion_subnet` |
| 7 | `azurerm_virtual_hub_connection` | `vhub_connection00` / `01` | `hub_connection_shared` |

**Firewall (from firewall.tf) — conditional on `add_firewall`:**

| # | Resource Type | Current Name (region 0 / 1) | Child Module Name |
|---|---|---|---|
| 8 | `azurerm_firewall` | `fw00` / `fw01` | `fw` |
| 9 | `azurerm_firewall_policy` | `fw00_policy` / `fw01_policy` | `fw_policy` |
| 10 | `azurerm_firewall_policy_rule_collection_group` | `fw00_policy_rcg` / `fw01_policy_rcg` | `fw_policy_rcg` |
| 11 | `azurerm_monitor_diagnostic_setting` | `fw00_logs` / `fw01_logs` | `fw_logs` |

**DNS (from dns.tf) — conditional on `add_private_dns`:**

| # | Resource Type | Current Name (region 0 / 1) | Child Module Name |
|---|---|---|---|
| 12 | `azurerm_virtual_network` | `dns_vnet00` / `01` | `dns_vnet` |
| 13 | `azurerm_subnet` | `resolver_inbound_subnet00` / `01` | `resolver_inbound_subnet` |
| 14 | `azurerm_subnet` | `resolver_outbound_subnet00` / `01` | `resolver_outbound_subnet` |
| 15 | `module` (AVM) | `private_dns00` / `01` | `private_dns` |
| 16 | `azurerm_virtual_hub_connection` | `vhub_connection00-to-dns` / `01` | `hub_connection_dns` |
| 17 | `azurerm_private_dns_resolver` | `private_resolver00` / `01` | `resolver` |
| 18 | `azurerm_private_dns_resolver_inbound_endpoint` | `private_resolver00_inbound00` / `01` | `resolver_inbound` |
| 19 | `azurerm_virtual_network_dns_servers` | `shared_vnet00_dns` / `01` | `shared_vnet_dns` |
| 20 | `azurerm_private_dns_resolver_outbound_endpoint` | `private_resolver00_outbound00` / `01` | `resolver_outbound` |
| 21 | `azurerm_private_dns_resolver_dns_forwarding_ruleset` | `private_resolver00_forwarding_ruleset00` / `01` | `forwarding_ruleset` |
| 22 | `azurerm_private_dns_resolver_forwarding_rule` | `private_resolver00_forwarding_rule00` / `01` | `forwarding_rule` |
| 23 | `azurerm_private_dns_resolver_virtual_network_link` | `private_resolver00_dnsvnet00link` / `01` | `forwarding_ruleset_dns_vnet_link` |
| 24 | `azapi_resource` | `dns_security_policy00` / `01` | `dns_security_policy` |
| 25 | `azapi_resource` | `dns_security_policy_shared_vnet00_link` / `01` | `dns_policy_shared_vnet_link` |
| 26 | `azapi_resource` | `dns_security_policy_dns_vnet00_link` / `01` | `dns_policy_dns_vnet_link` |
| 27 | `azurerm_monitor_diagnostic_setting` | `dns_policy00_logs` / `01` | `dns_policy_logs` |

**Compute (from compute.tf):**

| # | Resource Type | Current Name (region 0 / 1) | Child Module Name |
|---|---|---|---|
| 28 | `azurerm_public_ip` | `bastion_pip00` / `01` | `bastion_pip` |
| 29 | `azurerm_bastion_host` | `bastion_host00` / `01` | `bastion` |
| 30 | `azurerm_network_interface` | `vm00_nic` / `01` | `vm_nic` |
| 31 | `azurerm_windows_virtual_machine` | `vm00` / `01` | `vm` |

**Total: 31 resource instances per region (16 always-on, 4 firewall-conditional, 11 DNS-conditional + 1 AVM module call)**

---

## 2. Module Inputs

### 2.1 Child Module Variables (`modules/region-hub/variables.tf`)

All names are generic — no region numbers.

```hcl
# ── Context (passed from root) ─────────────────────────────────

variable "resource_group_name" {
  description = "Name of the pre-existing resource group for this region"
  type        = string
}

variable "resource_group_location" {
  description = "Location of the resource group"
  type        = string
}

variable "resource_group_id" {
  description = "Full resource ID of the resource group (used as parent_id for AVM/azapi)"
  type        = string
}

variable "region_abbr" {
  description = "Short region abbreviation for naming (e.g. sece, cus)"
  type        = string
}

variable "suffix" {
  description = "Random numeric suffix for globally unique names"
  type        = string
}

variable "common_tags" {
  description = "Tags applied to all taggable resources"
  type        = map(string)
}

variable "virtual_wan_id" {
  description = "ID of the parent Virtual WAN"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace for diagnostic settings"
  type        = string
}

variable "vm_admin_username" {
  description = "VM admin username (suffix is prepended inside the module)"
  type        = string
}

variable "vm_admin_password" {
  description = "VM admin password (from Key Vault)"
  type        = string
  sensitive   = true
}

# ── Hub ─────────────────────────────────────────────────────────

variable "hub_name" {
  description = "Virtual Hub name (region_abbr appended automatically)"
  type        = string
}

variable "hub_address_prefix" {
  description = "CIDR address prefix for the Virtual Hub"
  type        = string

  validation {
    condition     = can(cidrhost(var.hub_address_prefix, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "hub_route_pref" {
  description = "Hub routing preference (ExpressRoute, ASPath, VpnGateway)"
  type        = string
  default     = "ExpressRoute"
}

# ── Shared VNet ─────────────────────────────────────────────────

variable "shared_vnet_name" {
  description = "Shared spoke VNet name"
  type        = string
}

variable "shared_vnet_address_space" {
  description = "Shared spoke VNet address space"
  type        = list(string)
}

variable "shared_subnet_name" {
  description = "Shared subnet name"
  type        = string
}

variable "shared_subnet_address" {
  description = "Shared subnet address prefixes"
  type        = list(string)
}

variable "app_subnet_name" {
  description = "App subnet name"
  type        = string
}

variable "app_subnet_address" {
  description = "App subnet address prefixes"
  type        = list(string)
}

variable "bastion_subnet_address" {
  description = "Bastion subnet address prefixes"
  type        = list(string)
}

variable "hub_to_shared_connection_name" {
  description = "Name for the hub-to-shared-VNet connection"
  type        = string
}

# ── Firewall (conditional) ──────────────────────────────────────

variable "add_firewall" {
  description = "Deploy Azure Firewall in this region's hub"
  type        = bool
  default     = false
}

variable "firewall_name" {
  description = "Firewall name"
  type        = string
  default     = "firewall"
}

variable "firewall_sku_name" {
  description = "Firewall SKU name"
  type        = string
  default     = "AZFW_Hub"
}

variable "firewall_sku_tier" {
  description = "Firewall SKU tier"
  type        = string
  default     = "Premium"

  validation {
    condition     = contains(["Standard", "Premium"], var.firewall_sku_tier)
    error_message = "Firewall SKU tier must be one of: Standard, Premium."
  }
}

variable "firewall_policy_name" {
  description = "Firewall policy name"
  type        = string
  default     = "firewall-policy"
}

variable "firewall_policy_rcg_name" {
  description = "Firewall policy rule collection group name"
  type        = string
  default     = "firewall-policy-rcg"
}

variable "firewall_logs_name" {
  description = "Firewall diagnostic setting name"
  type        = string
  default     = "firewall-logs"
}

# ── DNS (conditional) ───────────────────────────────────────────

variable "add_private_dns" {
  description = "Deploy Private DNS Resolver in this region"
  type        = bool
  default     = false
}

variable "dns_vnet_name" {
  description = "DNS resolver VNet name"
  type        = string
  default     = "dns-vnet"
}

variable "dns_vnet_address_space" {
  description = "DNS resolver VNet address space"
  type        = list(string)
}

variable "hub_to_dns_connection_name" {
  description = "Name for the hub-to-DNS-VNet connection"
  type        = string
}

variable "resolver_inbound_subnet_name" {
  description = "Inbound resolver subnet name"
  type        = string
  default     = "resolver-inbound-subnet"
}

variable "resolver_inbound_subnet_address" {
  description = "Inbound resolver subnet address prefixes"
  type        = list(string)
}

variable "resolver_inbound_endpoint_address" {
  description = "Static IP for the resolver inbound endpoint"
  type        = string
}

variable "resolver_outbound_subnet_name" {
  description = "Outbound resolver subnet name"
  type        = string
  default     = "resolver-outbound-subnet"
}

variable "resolver_outbound_subnet_address" {
  description = "Outbound resolver subnet address prefixes"
  type        = list(string)
}

variable "private_resolver_name" {
  description = "Private DNS Resolver resource name"
  type        = string
  default     = "resolver"
}

variable "shared_vnet_dns_servers" {
  description = "Custom DNS server IPs to set on the shared VNet (typically the resolver inbound IP)"
  type        = list(string)
}

# ── Compute ─────────────────────────────────────────────────────

variable "bastion_pip_name" {
  description = "Bastion public IP name"
  type        = string
  default     = "bastion-pip"
}

variable "bastion_host_name" {
  description = "Bastion Host name"
  type        = string
  default     = "bastion-host"
}

variable "bastion_host_sku" {
  description = "Bastion Host SKU"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Basic", "Standard", "Developer"], var.bastion_host_sku)
    error_message = "Bastion SKU must be one of: Basic, Standard, Developer."
  }
}

variable "vm_nic_name" {
  description = "VM NIC name"
  type        = string
  default     = "vm-nic"
}

variable "vm_name" {
  description = "VM name"
  type        = string
  default     = "vm"
}

variable "vm_size" {
  description = "VM size"
  type        = string
  default     = "Standard_B2s"
}
```

### 2.2 How Root Maps Flat Variables to Module Inputs

The root module's existing flat variables (`*00`, `*01`) are mapped directly. **No user-facing variables change.**

```hcl
module "region0" {
  source = "./modules/region-hub"

  # Context
  resource_group_name        = azurerm_resource_group.rg-net00.name
  resource_group_location    = azurerm_resource_group.rg-net00.location
  resource_group_id          = azurerm_resource_group.rg-net00.id
  region_abbr                = var.azure_region_0_abbr
  suffix                     = local.suffix
  common_tags                = local.common_tags
  virtual_wan_id             = azurerm_virtual_wan.vwan.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law00.id
  vm_admin_username          = var.vm_admin_username
  vm_admin_password          = data.azurerm_key_vault_secret.vm_password.value

  # Hub
  hub_name           = var.azurerm_virtual_hub00_name
  hub_address_prefix = var.azurerm_vhub00_address_prefix
  hub_route_pref     = var.azurerm_vhub00_route_pref

  # Shared VNet
  shared_vnet_name              = var.shared_vnet_name00
  shared_vnet_address_space     = var.shared_vnet_address_space00
  shared_subnet_name            = var.shared_subnet_name00
  shared_subnet_address         = var.shared_subnet_address00
  app_subnet_name               = var.app_subnet_name00
  app_subnet_address            = var.app_subnet_address00
  bastion_subnet_address        = var.bastion_subnet_address00
  hub_to_shared_connection_name = var.azurerm_virtual_hub_connection_vhub00_to_shared00

  # Firewall
  add_firewall             = var.add_firewall00
  firewall_name            = var.firewall_name00
  firewall_sku_name        = var.firewall_sku_name00
  firewall_sku_tier        = var.firewall_sku_tier00
  firewall_policy_name     = var.firewall_policy_name00
  firewall_policy_rcg_name = var.firewall_policy_rcg_name00
  firewall_logs_name       = var.firewall_logs_name00

  # DNS
  add_private_dns                   = var.add_private_dns00
  dns_vnet_name                     = var.dns_vnet_name00
  dns_vnet_address_space            = var.dns_vnet_address_space00
  hub_to_dns_connection_name        = var.azurerm_virtual_hub_connection_vhub00_to_dns00
  resolver_inbound_subnet_name      = var.resolver_inbound_subnet_name00
  resolver_inbound_subnet_address   = var.resolver_inbound_subnet_address00
  resolver_inbound_endpoint_address = var.resolver_inbound_endpoint_address00
  resolver_outbound_subnet_name     = var.resolver_outbound_subnet_name00
  resolver_outbound_subnet_address  = var.resolver_outbound_subnet_address00
  private_resolver_name             = var.private_resolver_name00
  shared_vnet_dns_servers           = var.shared_vnet00_dns

  # Compute
  bastion_pip_name  = var.bastion_pip_name00
  bastion_host_name = var.bastion_host_name00
  bastion_host_sku  = var.bastion_host_sku00
  vm_nic_name       = var.vm00_nic_name
  vm_name           = var.vm00_name
  vm_size           = var.vm00_size
}

module "region1" {
  count  = var.create_vhub01 ? 1 : 0
  source = "./modules/region-hub"

  # Context
  resource_group_name        = azurerm_resource_group.rg-net01[0].name
  resource_group_location    = azurerm_resource_group.rg-net01[0].location
  resource_group_id          = azurerm_resource_group.rg-net01[0].id
  region_abbr                = var.azure_region_1_abbr
  suffix                     = local.suffix
  common_tags                = local.common_tags
  virtual_wan_id             = azurerm_virtual_wan.vwan.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law00.id
  vm_admin_username          = var.vm_admin_username
  vm_admin_password          = data.azurerm_key_vault_secret.vm_password.value

  # Hub
  hub_name           = var.azurerm_virtual_hub01_name
  hub_address_prefix = var.azurerm_vhub01_address_prefix
  hub_route_pref     = var.azurerm_vhub01_route_pref

  # Shared VNet
  shared_vnet_name              = var.shared_vnet_name01
  shared_vnet_address_space     = var.shared_vnet_address_space01
  shared_subnet_name            = var.shared_subnet_name01
  shared_subnet_address         = var.shared_subnet_address01
  app_subnet_name               = var.app_subnet_name01
  app_subnet_address            = var.app_subnet_address01
  bastion_subnet_address        = var.bastion_subnet_address01
  hub_to_shared_connection_name = var.azurerm_virtual_hub_connection_vhub01_to_shared01

  # Firewall
  add_firewall             = var.add_firewall01
  firewall_name            = var.firewall_name01
  firewall_sku_name        = var.firewall_sku_name01
  firewall_sku_tier        = var.firewall_sku_tier01
  firewall_policy_name     = var.firewall_policy_name01
  firewall_policy_rcg_name = var.firewall_policy_rcg_name01
  firewall_logs_name       = var.firewall_logs_name01

  # DNS
  add_private_dns                   = var.add_private_dns01
  dns_vnet_name                     = var.dns_vnet_name01
  dns_vnet_address_space            = var.dns_vnet_address_space01
  hub_to_dns_connection_name        = var.azurerm_virtual_hub_connection_vhub01_to_dns01
  resolver_inbound_subnet_name      = var.resolver_inbound_subnet_name01
  resolver_inbound_subnet_address   = var.resolver_inbound_subnet_address01
  resolver_inbound_endpoint_address = var.resolver_inbound_endpoint_address01
  resolver_outbound_subnet_name     = var.resolver_outbound_subnet_name01
  resolver_outbound_subnet_address  = var.resolver_outbound_subnet_address01
  private_resolver_name             = var.private_resolver_name01
  shared_vnet_dns_servers           = var.shared_vnet01_dns

  # Compute
  bastion_pip_name  = var.bastion_pip_name01
  bastion_host_name = var.bastion_host_name01
  bastion_host_sku  = var.bastion_host_sku01
  vm_nic_name       = var.vm01_nic_name
  vm_name           = var.vm01_name
  vm_size           = var.vm01_size
}
```

**Key design point:** Region 1's `count = var.create_vhub01 ? 1 : 0` is the ONLY conditional guard needed. Inside the module, firewall and DNS resources use their own `count = var.add_firewall ? 1 : 0` and `count = var.add_private_dns ? 1 : 0` without needing the nested `var.create_vhub01 ? (...) : 0` pattern. This eliminates the count-guard bugs Katia identified (Decision #4) — the module boundary enforces the region-exists precondition structurally.

---

## 3. Module Outputs

### `modules/region-hub/outputs.tf`

```hcl
# ── Hub ─────────────────────────────────────────────────────────

output "hub_id" {
  description = "Virtual Hub ID"
  value       = azurerm_virtual_hub.hub.id
}

output "hub_name" {
  description = "Virtual Hub name"
  value       = azurerm_virtual_hub.hub.name
}

# ── Shared VNet ─────────────────────────────────────────────────

output "shared_vnet_id" {
  description = "Shared spoke VNet ID"
  value       = azurerm_virtual_network.shared_vnet.id
}

output "shared_vnet_name" {
  description = "Shared spoke VNet name"
  value       = azurerm_virtual_network.shared_vnet.name
}

output "shared_subnet_id" {
  description = "Shared subnet ID"
  value       = azurerm_subnet.shared_subnet.id
}

output "app_subnet_id" {
  description = "App subnet ID"
  value       = azurerm_subnet.app_subnet.id
}

output "bastion_subnet_id" {
  description = "Bastion subnet ID"
  value       = azurerm_subnet.bastion_subnet.id
}

# ── Firewall ────────────────────────────────────────────────────

output "firewall_id" {
  description = "Azure Firewall ID (null if not deployed)"
  value       = var.add_firewall ? azurerm_firewall.fw[0].id : null
}

output "firewall_private_ip" {
  description = "Azure Firewall private IP (null if not deployed)"
  value       = var.add_firewall ? azurerm_firewall.fw[0].virtual_hub[0].private_ip_address : null
}

# ── DNS ─────────────────────────────────────────────────────────

output "dns_resolver_policy_id" {
  description = "DNS resolver policy ID (null if Private DNS not deployed)"
  value       = var.add_private_dns ? azapi_resource.dns_security_policy[0].id : null
}

output "dns_inbound_endpoint_ip" {
  description = "DNS resolver inbound endpoint IP (null if Private DNS not deployed)"
  value       = var.add_private_dns ? var.resolver_inbound_endpoint_address : null
}

output "dns_vnet_id" {
  description = "DNS VNet ID (null if Private DNS not deployed)"
  value       = var.add_private_dns ? azurerm_virtual_network.dns_vnet[0].id : null
}

# ── Compute ─────────────────────────────────────────────────────

output "vm_id" {
  description = "Windows VM ID"
  value       = azurerm_windows_virtual_machine.vm.id
}

output "vm_admin_username" {
  description = "Constructed VM admin username"
  value       = azurerm_windows_virtual_machine.vm.admin_username
  sensitive   = true
}

output "bastion_host_id" {
  description = "Bastion Host ID"
  value       = azurerm_bastion_host.bastion.id
}
```

---

## 4. Root Module Calls

See Section 2.2 for the full `module "region0"` and `module "region1"` blocks.

**Summary:**
- `module.region0` — always instantiated, no `count`
- `module.region1` — `count = var.create_vhub01 ? 1 : 0`
- Both share the same `source = "./modules/region-hub"`
- Root maps its flat `*00` / `*01` variables to the module's generic inputs

---

## 5. What Stays in Root

These resources are **global singletons** — NOT per-region, NOT duplicated:

| File | Resource | Reason |
|---|---|---|
| `keyvault.tf` | `random_string.unique` | Single random suffix shared by all resources |
| `keyvault.tf` | `data.azurerm_client_config.current` | Tenant/object ID lookup |
| `keyvault.tf` | `random_password.vm_password` | Single password for all VMs |
| `keyvault.tf` | `azurerm_resource_group.rg-kv00` | Key Vault RG |
| `keyvault.tf` | `azurerm_key_vault.kv00` | Central Key Vault |
| `keyvault.tf` | `azurerm_key_vault_secret.vm_password` | Password storage |
| `keyvault.tf` | `data.azurerm_key_vault_secret.vm_password` | Password retrieval |
| `main.tf` | `azurerm_resource_group.rg-net00` | Region 0 networking RG (also hosts vWAN, LAW) |
| `main.tf` | `azurerm_resource_group.rg-net01` | Region 1 networking RG (conditional) |
| `main.tf` | `azurerm_log_analytics_workspace.law00` | Central Log Analytics (both regions send here) |
| `vwan.tf` | `azurerm_virtual_wan.vwan` | Single vWAN — hubs attach to it |
| `locals.tf` | `local.suffix`, `local.rg00_name`, etc. | Shared naming helpers |
| `config.tf` | Provider + backend config | Global Terraform config |
| `variables.tf` | All existing variables | Flat per-region vars preserved (user-facing contract) |
| `outputs.tf` | All existing outputs | Updated to reference module outputs (see §6) |

**After refactoring, root-level .tf files shrink significantly:**
- `vwan.tf` → only `azurerm_virtual_wan.vwan` (2 resources become 1)
- `firewall.tf` → **deleted** (all content moves into child module)
- `dns.tf` → **deleted** (all content moves into child module)
- `compute.tf` → **deleted** (all content moves into child module)
- `main.tf` → RGs, LAW, and the two `module` blocks
- `keyvault.tf` → unchanged
- `locals.tf` → unchanged
- `config.tf` → unchanged
- `variables.tf` → unchanged (all flat vars retained for UX compatibility)
- `outputs.tf` → references updated (see §6)

---

## 6. Output Updates

The existing `outputs.tf` references change from direct resource addresses to module output references. The output **names, types, and descriptions remain identical** — downstream consumers (Foundry modules via `terraform_remote_state`) see no change.

```hcl
# ── Unchanged outputs (reference root-level resources) ──────────

output "rg_net00_id" {
  description = "The ID of the Networking Resource Group."
  value       = azurerm_resource_group.rg-net00.id
}

output "rg_net00_name" {
  description = "The name of the Networking Resource Group for region 0"
  value       = azurerm_resource_group.rg-net00.name
}

output "rg_net00_location" {
  description = "The location of the Networking Resource Group."
  value       = azurerm_resource_group.rg-net00.location
}

output "azure_region_0_abbr" {
  description = "The abbreviation of the Azure 0 region."
  value       = var.azure_region_0_abbr
}

output "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.law00.id
}

output "key_vault_id" {
  description = "The ID of Key Vault"
  value       = azurerm_key_vault.kv00.id
}

output "key_vault_name" {
  description = "The name of Key Vault"
  value       = azurerm_key_vault.kv00.name
}

output "add_firewall00" {
  description = "Whether Azure Firewall is deployed in region 0"
  value       = var.add_firewall00
}

# DNS zone ID outputs — unchanged; they construct IDs from the
# root-level RG ID which still lives in root.
output "dns_zone_blob_id" { ... }   # no change
output "dns_zone_file_id" { ... }   # no change
# ... (all 10 dns_zone_* outputs unchanged)

# ── Updated outputs (now reference module) ──────────────────────

output "vm_admin_username" {
  description = "Virtual Machine Admin Username"
  value       = module.region0.vm_admin_username
  sensitive   = true
}

output "vhub00_id" {
  description = "The ID of Virtual Hub 00"
  value       = module.region0.hub_id
}

output "vhub01_id" {
  description = "The ID of Virtual Hub 01"
  value       = var.create_vhub01 ? module.region1[0].hub_id : null
}

output "dns_resolver_policy00_id" {
  description = "The ID of the DNS resolver policy for region 0"
  value       = module.region0.dns_resolver_policy_id
}

output "dns_inbound_endpoint00_ip" {
  description = "The IP address of the DNS resolver inbound endpoint for region 0"
  value       = module.region0.dns_inbound_endpoint_ip
}
```

**Net effect:** 5 outputs change their `value` expression. 0 outputs are added or removed. Downstream consumers see no behavioral change.

---

## 7. State Migration Notes

> **Current status:** This is a lab/demo repo with no persistent live environments. State migration is **not required** for this repo. These commands are documented for anyone who has deployed the Networking module and wants to adopt the child module without destroying and recreating resources.

### Strategy

Use `terraform state mv` to move resources from root addresses to module addresses. Run all commands from within `Networking/`.

### Region 0 Commands

Region 0 resources have no `[0]` index (they don't use `count`). The child module's always-on resources also have no index.

```bash
# Hub
terraform state mv 'azurerm_virtual_hub.vhub00' \
  'module.region0.azurerm_virtual_hub.hub'

# Routing intent (conditional — only exists if firewall was deployed)
terraform state mv 'azurerm_virtual_hub_routing_intent.vhub_routing_intent00[0]' \
  'module.region0.azurerm_virtual_hub_routing_intent.routing_intent[0]'

# Shared VNet & subnets
terraform state mv 'azurerm_virtual_network.shared_vnet00' \
  'module.region0.azurerm_virtual_network.shared_vnet'
terraform state mv 'azurerm_subnet.shared_subnet00' \
  'module.region0.azurerm_subnet.shared_subnet'
terraform state mv 'azurerm_subnet.app_subnet00' \
  'module.region0.azurerm_subnet.app_subnet'
terraform state mv 'azurerm_subnet.bastion_subnet00' \
  'module.region0.azurerm_subnet.bastion_subnet'
terraform state mv 'azurerm_virtual_hub_connection.vhub_connection00' \
  'module.region0.azurerm_virtual_hub_connection.hub_connection_shared'

# Firewall (conditional — only if add_firewall00 was true)
terraform state mv 'azurerm_firewall.fw00[0]' \
  'module.region0.azurerm_firewall.fw[0]'
terraform state mv 'azurerm_firewall_policy.fw00_policy[0]' \
  'module.region0.azurerm_firewall_policy.fw_policy[0]'
terraform state mv 'azurerm_firewall_policy_rule_collection_group.fw00_policy_rcg[0]' \
  'module.region0.azurerm_firewall_policy_rule_collection_group.fw_policy_rcg[0]'
terraform state mv 'azurerm_monitor_diagnostic_setting.fw00_logs[0]' \
  'module.region0.azurerm_monitor_diagnostic_setting.fw_logs[0]'

# DNS (conditional — only if add_private_dns00 was true)
terraform state mv 'azurerm_virtual_network.dns_vnet00[0]' \
  'module.region0.azurerm_virtual_network.dns_vnet[0]'
terraform state mv 'azurerm_subnet.resolver_inbound_subnet00[0]' \
  'module.region0.azurerm_subnet.resolver_inbound_subnet[0]'
terraform state mv 'azurerm_subnet.resolver_outbound_subnet00[0]' \
  'module.region0.azurerm_subnet.resolver_outbound_subnet[0]'
terraform state mv 'module.private_dns00[0]' \
  'module.region0.module.private_dns[0]'
terraform state mv 'azurerm_virtual_hub_connection.vhub_connection00-to-dns[0]' \
  'module.region0.azurerm_virtual_hub_connection.hub_connection_dns[0]'
terraform state mv 'azurerm_private_dns_resolver.private_resolver00[0]' \
  'module.region0.azurerm_private_dns_resolver.resolver[0]'
terraform state mv 'azurerm_private_dns_resolver_inbound_endpoint.private_resolver00_inbound00[0]' \
  'module.region0.azurerm_private_dns_resolver_inbound_endpoint.resolver_inbound[0]'
terraform state mv 'azurerm_virtual_network_dns_servers.shared_vnet00_dns[0]' \
  'module.region0.azurerm_virtual_network_dns_servers.shared_vnet_dns[0]'
terraform state mv 'azurerm_private_dns_resolver_outbound_endpoint.private_resolver00_outbound00[0]' \
  'module.region0.azurerm_private_dns_resolver_outbound_endpoint.resolver_outbound[0]'
terraform state mv 'azurerm_private_dns_resolver_dns_forwarding_ruleset.private_resolver00_forwarding_ruleset00[0]' \
  'module.region0.azurerm_private_dns_resolver_dns_forwarding_ruleset.forwarding_ruleset[0]'
terraform state mv 'azurerm_private_dns_resolver_forwarding_rule.private_resolver00_forwarding_rule00[0]' \
  'module.region0.azurerm_private_dns_resolver_forwarding_rule.forwarding_rule[0]'
terraform state mv 'azurerm_private_dns_resolver_virtual_network_link.private_resolver00_dnsvnet00link[0]' \
  'module.region0.azurerm_private_dns_resolver_virtual_network_link.forwarding_ruleset_dns_vnet_link[0]'
terraform state mv 'azapi_resource.dns_security_policy00[0]' \
  'module.region0.azapi_resource.dns_security_policy[0]'
terraform state mv 'azapi_resource.dns_security_policy_shared_vnet00_link[0]' \
  'module.region0.azapi_resource.dns_policy_shared_vnet_link[0]'
terraform state mv 'azapi_resource.dns_security_policy_dns_vnet00_link[0]' \
  'module.region0.azapi_resource.dns_policy_dns_vnet_link[0]'
terraform state mv 'azurerm_monitor_diagnostic_setting.dns_policy00_logs[0]' \
  'module.region0.azurerm_monitor_diagnostic_setting.dns_policy_logs[0]'

# Compute
terraform state mv 'azurerm_public_ip.bastion_pip00' \
  'module.region0.azurerm_public_ip.bastion_pip'
terraform state mv 'azurerm_bastion_host.bastion_host00' \
  'module.region0.azurerm_bastion_host.bastion'
terraform state mv 'azurerm_network_interface.vm00_nic' \
  'module.region0.azurerm_network_interface.vm_nic'
terraform state mv 'azurerm_windows_virtual_machine.vm00' \
  'module.region0.azurerm_windows_virtual_machine.vm'
```

### Region 1 Commands

Region 1 resources currently use `[0]` index (from `count`). The module itself uses `count = 1`, so the target is `module.region1[0].resource_name`. Conditional resources inside the module also have `[0]`.

```bash
# Hub
terraform state mv 'azurerm_virtual_hub.vhub01[0]' \
  'module.region1[0].azurerm_virtual_hub.hub'
terraform state mv 'azurerm_virtual_hub_routing_intent.vhub_routing_intent01[0]' \
  'module.region1[0].azurerm_virtual_hub_routing_intent.routing_intent[0]'

# Shared VNet & subnets
terraform state mv 'azurerm_virtual_network.shared_vnet01[0]' \
  'module.region1[0].azurerm_virtual_network.shared_vnet'
terraform state mv 'azurerm_subnet.shared_subnet01[0]' \
  'module.region1[0].azurerm_subnet.shared_subnet'
terraform state mv 'azurerm_subnet.app_subnet01[0]' \
  'module.region1[0].azurerm_subnet.app_subnet'
terraform state mv 'azurerm_subnet.bastion_subnet01[0]' \
  'module.region1[0].azurerm_subnet.bastion_subnet'
terraform state mv 'azurerm_virtual_hub_connection.vhub_connection01[0]' \
  'module.region1[0].azurerm_virtual_hub_connection.hub_connection_shared'

# Firewall (conditional)
terraform state mv 'azurerm_firewall.fw01[0]' \
  'module.region1[0].azurerm_firewall.fw[0]'
terraform state mv 'azurerm_firewall_policy.fw01_policy[0]' \
  'module.region1[0].azurerm_firewall_policy.fw_policy[0]'
terraform state mv 'azurerm_firewall_policy_rule_collection_group.fw01_policy_rcg[0]' \
  'module.region1[0].azurerm_firewall_policy_rule_collection_group.fw_policy_rcg[0]'
terraform state mv 'azurerm_monitor_diagnostic_setting.fw01_logs[0]' \
  'module.region1[0].azurerm_monitor_diagnostic_setting.fw_logs[0]'

# DNS (conditional)
terraform state mv 'azurerm_virtual_network.dns_vnet01[0]' \
  'module.region1[0].azurerm_virtual_network.dns_vnet[0]'
terraform state mv 'azurerm_subnet.resolver_inbound_subnet01[0]' \
  'module.region1[0].azurerm_subnet.resolver_inbound_subnet[0]'
terraform state mv 'azurerm_subnet.resolver_outbound_subnet01[0]' \
  'module.region1[0].azurerm_subnet.resolver_outbound_subnet[0]'
terraform state mv 'module.private_dns01[0]' \
  'module.region1[0].module.private_dns[0]'
terraform state mv 'azurerm_virtual_hub_connection.vhub_connection01-to-dns[0]' \
  'module.region1[0].azurerm_virtual_hub_connection.hub_connection_dns[0]'
terraform state mv 'azurerm_private_dns_resolver.private_resolver01[0]' \
  'module.region1[0].azurerm_private_dns_resolver.resolver[0]'
terraform state mv 'azurerm_private_dns_resolver_inbound_endpoint.private_resolver01_inbound00[0]' \
  'module.region1[0].azurerm_private_dns_resolver_inbound_endpoint.resolver_inbound[0]'
terraform state mv 'azurerm_virtual_network_dns_servers.shared_vnet01_dns[0]' \
  'module.region1[0].azurerm_virtual_network_dns_servers.shared_vnet_dns[0]'
terraform state mv 'azurerm_private_dns_resolver_outbound_endpoint.private_resolver01_outbound00[0]' \
  'module.region1[0].azurerm_private_dns_resolver_outbound_endpoint.resolver_outbound[0]'
terraform state mv 'azurerm_private_dns_resolver_dns_forwarding_ruleset.private_resolver01_forwarding_ruleset00[0]' \
  'module.region1[0].azurerm_private_dns_resolver_dns_forwarding_ruleset.forwarding_ruleset[0]'
terraform state mv 'azurerm_private_dns_resolver_forwarding_rule.private_resolver01_forwarding_rule00[0]' \
  'module.region1[0].azurerm_private_dns_resolver_forwarding_rule.forwarding_rule[0]'
terraform state mv 'azurerm_private_dns_resolver_virtual_network_link.private_resolver01_dnsvnet01link[0]' \
  'module.region1[0].azurerm_private_dns_resolver_virtual_network_link.forwarding_ruleset_dns_vnet_link[0]'
terraform state mv 'azapi_resource.dns_security_policy01[0]' \
  'module.region1[0].azapi_resource.dns_security_policy[0]'
terraform state mv 'azapi_resource.dns_security_policy_shared_vnet01_link[0]' \
  'module.region1[0].azapi_resource.dns_policy_shared_vnet_link[0]'
terraform state mv 'azapi_resource.dns_security_policy_dns_vnet01_link[0]' \
  'module.region1[0].azapi_resource.dns_policy_dns_vnet_link[0]'
terraform state mv 'azurerm_monitor_diagnostic_setting.dns_policy01_logs[0]' \
  'module.region1[0].azurerm_monitor_diagnostic_setting.dns_policy_logs[0]'

# Compute
terraform state mv 'azurerm_public_ip.bastion_pip01[0]' \
  'module.region1[0].azurerm_public_ip.bastion_pip'
terraform state mv 'azurerm_bastion_host.bastion_host01[0]' \
  'module.region1[0].azurerm_bastion_host.bastion'
terraform state mv 'azurerm_network_interface.vm01_nic[0]' \
  'module.region1[0].azurerm_network_interface.vm_nic'
terraform state mv 'azurerm_windows_virtual_machine.vm01[0]' \
  'module.region1[0].azurerm_windows_virtual_machine.vm'
```

### Validation

After running all `state mv` commands:

```bash
terraform plan
```

A successful migration produces a plan with **0 additions, 0 changes, 0 destructions**.

---

## 8. File Structure

### Before

```
Networking/
  config.tf
  locals.tf
  variables.tf
  outputs.tf
  main.tf           # RGs, LAW, shared VNets, subnets, hub connections
  vwan.tf           # vWAN, vHubs, routing intents
  firewall.tf       # Firewalls, policies, RCGs, diagnostic settings
  dns.tf            # DNS VNets, resolvers, forwarding, security policies
  compute.tf        # Bastion, VMs, NICs, PIPs
  keyvault.tf       # Key Vault, secrets, random resources
```

### After

```
Networking/
  config.tf                          # unchanged
  locals.tf                          # unchanged
  variables.tf                       # unchanged (all flat vars retained)
  outputs.tf                         # value expressions updated (§6)
  main.tf                            # RGs, LAW, module blocks (simplified)
  vwan.tf                            # vWAN only (hubs move to child)
  keyvault.tf                        # unchanged
  modules/
    region-hub/
      main.tf                        # hub, shared VNet, subnets, connections,
                                     #   firewall, DNS, compute — all per-region
      variables.tf                   # generic inputs (§2.1)
      outputs.tf                     # module exports (§3)
```

### Implementation Note

The child module uses a single `main.tf` for simplicity. If it grows large, Donut may split it into `hub.tf`, `firewall.tf`, `dns.tf`, `compute.tf` following the same pattern as the original root module. That's an implementation detail, not an architectural decision.

### Provider Configuration

The child module **inherits** provider configuration from the root — no `provider` block needed inside `modules/region-hub/`. The `required_providers` block in the child module should declare the same providers (azurerm, azapi) without version constraints, deferring version pinning to the root.

---

## Design Rationale

1. **Why not `for_each` with a region map?** Ryan tried it, hit issues, and explicitly prefers the simple boolean toggle UX. The flat-variable approach is the approved contract.

2. **Why keep RGs in root?** The vWAN and Log Analytics Workspace live in region 0's RG. Moving the RG into the child module would create a circular dependency (vWAN needs the RG, the module needs vWAN ID). Cleaner to create RGs in root and pass them in.

3. **Why a single child module?** All 31 per-region resources share the same lifecycle and dependency graph. Splitting into sub-sub-modules (hub, firewall, DNS, compute) adds indirection without benefit at this scale.

4. **Why does this fix count-guard bugs?** The nested `var.create_vhub01 ? (var.add_firewall01 ? 1 : 0) : 0` pattern disappears. Region 1's entire module is gated by `count`, so firewall/DNS resources inside it only need `count = var.add_firewall ? 1 : 0`. The precondition is structural, not coded.

5. **Bastion subnet naming:** The child module hardcodes `name = "AzureBastionSubnet"` — this is an Azure platform requirement, not configurable. No variable exposed.
