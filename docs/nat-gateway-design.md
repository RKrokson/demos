# NAT Gateway Design — Outbound Internet Without Firewall

**Author:** Carl (Lead / Architect)
**Date:** 2025-07-27
**Status:** Proposed

## Problem Statement

When Azure Firewall is toggled off (`add_firewall = false`), spoke VNets connected to the vWAN hub have no controlled outbound internet path. VMs and workloads fall back to Azure's default SNAT behavior, which provides no static IP, no logging, and no governance over egress traffic. The DNS Private Resolver's outbound endpoint also needs internet access to forward queries to external resolvers (e.g., 8.8.8.8).

Ryan wants a NAT Gateway deployed automatically when the firewall is absent, giving spokes a deterministic, static outbound IP without the cost of Azure Firewall.

## Design Decision: Implicit Toggle

NAT Gateway deploys automatically when firewall is off. No new user-facing variable.

**Logic:** `deploy_nat_gateway = !add_firewall` (per region, inside the child module).

```hcl
locals {
  deploy_nat_gateway = !var.add_firewall
}
```

**Rationale:**
- The two features are mutually exclusive for outbound internet. When firewall is on, it owns SNAT via routing intent. When firewall is off, NAT Gateway fills the gap.
- Adding a separate `add_nat_gateway` variable creates an invalid state (`add_firewall = true` + `add_nat_gateway = true`) that would require validation blocks to prevent. Implicit toggle eliminates this.
- Keeps the user interface simple: one boolean per region controls the outbound strategy.

| `add_firewall` | NAT Gateway | Routing Intent | Outbound Path |
|---|---|---|---|
| `true` | Not deployed | Active (Internet + Private) | Firewall SNAT |
| `false` | Deployed | Not active | NAT Gateway SNAT |

## vWAN + NAT Gateway Compatibility (Critical Research)

**Finding: NAT Gateway works on spoke VNets in a vWAN architecture, with conditions.**

Key constraints confirmed via Microsoft documentation:

1. **NAT Gateway cannot be placed in the vHub itself.** It must be associated directly with spoke VNet subnets.

2. **Routing intent overrides NAT Gateway.** When `internet_security_enabled = true` on the hub connection, the vHub's routing intent forces all internet-bound traffic from the spoke through the firewall. The firewall performs SNAT, and the spoke's NAT Gateway is bypassed. This is why firewall ON = NAT Gateway OFF.

3. **Without routing intent, NAT Gateway works.** When `internet_security_enabled = false` (our no-firewall case), the spoke VNet handles its own internet egress. Azure's default system route (0.0.0.0/0 -> Internet) remains active, and NAT Gateway takes over SNAT for associated subnets.

4. **No custom route tables needed.** In the no-firewall scenario, the default system routes are sufficient. NAT Gateway intercepts outbound traffic on associated subnets without requiring UDR configuration.

**Sources:**
- [Integrate NAT Gateway with Azure Firewall in Hub and Spoke](https://learn.microsoft.com/en-us/azure/nat-gateway/tutorial-hub-spoke-nat-firewall)
- [Securing Internet access with routing intent](https://learn.microsoft.com/en-us/azure/virtual-wan/about-internet-routing)
- [About Virtual Hub Routing](https://learn.microsoft.com/en-us/azure/virtual-wan/about-virtual-hub-routing)

## Resources to Add

All resources go in `modules/region-hub/` (the child module). Both regions get identical resources, gated by `local.deploy_nat_gateway`.

### New file: `modules/region-hub/nat-gateway.tf`

```hcl
locals {
  deploy_nat_gateway = !var.add_firewall
}

# ── NAT Gateway (conditional — deployed when firewall is OFF) ──

resource "azurerm_public_ip" "nat_gateway_pip" {
  count               = local.deploy_nat_gateway ? 1 : 0
  name                = "nat-gw-pip-${var.region_abbr}-${var.suffix}"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.common_tags
}

resource "azurerm_nat_gateway" "nat_gateway" {
  count                   = local.deploy_nat_gateway ? 1 : 0
  name                    = "nat-gw-${var.region_abbr}-${var.suffix}"
  location                = var.resource_group_location
  resource_group_name     = var.resource_group_name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 4
  tags                    = var.common_tags
}

resource "azurerm_nat_gateway_public_ip_association" "nat_gateway_pip_assoc" {
  count                = local.deploy_nat_gateway ? 1 : 0
  nat_gateway_id       = azurerm_nat_gateway.nat_gateway[0].id
  public_ip_address_id = azurerm_public_ip.nat_gateway_pip[0].id
}

# ── Subnet Associations (shared VNet) ──────────────────────────

resource "azurerm_subnet_nat_gateway_association" "shared_subnet" {
  count          = local.deploy_nat_gateway ? 1 : 0
  subnet_id      = azurerm_subnet.shared_subnet.id
  nat_gateway_id = azurerm_nat_gateway.nat_gateway[0].id
}

resource "azurerm_subnet_nat_gateway_association" "app_subnet" {
  count          = local.deploy_nat_gateway ? 1 : 0
  subnet_id      = azurerm_subnet.app_subnet.id
  nat_gateway_id = azurerm_nat_gateway.nat_gateway[0].id
}

# NOTE: AzureBastionSubnet is NOT associated — Bastion uses its own PIP.
# NOTE: DNS resolver subnets are NOT associated — see "DNS Subnet Analysis" below.
```

### Resource count per region: 5

| Resource | Count expression | Purpose |
|---|---|---|
| `azurerm_public_ip` | `!var.add_firewall ? 1 : 0` | Static PIP for NAT Gateway |
| `azurerm_nat_gateway` | `!var.add_firewall ? 1 : 0` | NAT Gateway instance |
| `azurerm_nat_gateway_public_ip_association` | `!var.add_firewall ? 1 : 0` | Attach PIP to NAT GW |
| `azurerm_subnet_nat_gateway_association` (shared) | `!var.add_firewall ? 1 : 0` | Shared subnet outbound |
| `azurerm_subnet_nat_gateway_association` (app) | `!var.add_firewall ? 1 : 0` | App subnet outbound |

## Subnet Association Analysis

### Shared VNet subnets

| Subnet | Associate with NAT GW? | Reasoning |
|---|---|---|
| `shared_subnet` | Yes | VMs live here; need outbound internet |
| `app_subnet` | Yes | Application workloads; need outbound internet |
| `AzureBastionSubnet` | No | Bastion has its own PIP; NAT Gateway association is not supported on Bastion subnets |

### DNS VNet subnets

| Subnet | Associate with NAT GW? | Reasoning |
|---|---|---|
| `resolver_inbound_subnet` | No | Delegated to `Microsoft.Network/dnsResolvers`. Inbound endpoint receives queries — no outbound internet needed |
| `resolver_outbound_subnet` | No | Delegated to `Microsoft.Network/dnsResolvers`. The outbound endpoint sends DNS queries to external forwarders (8.8.8.8), but this traffic uses Azure's DNS forwarding infrastructure, not the subnet's own internet route. The delegation may also block NAT Gateway association. |

**DNS forwarding to 8.8.8.8 does not require NAT Gateway.** The DNS Private Resolver's outbound endpoint uses Azure's internal DNS forwarding plane, which handles its own connectivity. The forwarding traffic does not traverse the subnet's data path in the way a VM's traffic would. This is confirmed by the fact that DNS forwarding works today without a firewall and without explicit internet routing.

### ALZ (Foundry) VNet subnets

| Subnet | Associate with NAT GW? | Reasoning |
|---|---|---|
| `ai-foundry-subnet` | Needs investigation | Delegated to `Microsoft.App/environments`. Private endpoint traffic is intra-VNet. Agent proxy outbound may need internet. See ALZ Integration section. |
| `private-endpoint-subnet` | No | Private endpoints are inbound-only. No outbound internet needed. |

## DNS Impact

**No changes required.** The existing DNS logic already handles the no-firewall case correctly.

Current behavior in `modules/region-hub/main.tf`:

```hcl
resource "azurerm_virtual_network_dns_servers" "shared_vnet_dns" {
  count              = var.add_private_dns ? 1 : 0
  virtual_network_id = azurerm_virtual_network.shared_vnet.id
  dns_servers        = var.add_firewall ? [azurerm_firewall.fw[0].virtual_hub[0].private_ip_address] : [var.resolver_inbound_endpoint_address]
}
```

When `add_firewall = false`:
- DNS servers point to the resolver inbound endpoint IP directly
- No DNS proxy is needed (firewall DNS proxy only exists when firewall exists)
- The resolver handles private DNS zone resolution and forwards public queries to 8.8.8.8

The root-level `dns_server_ip00` output also handles this correctly:

```hcl
output "dns_server_ip00" {
  value = var.add_firewall00 ? module.region0.firewall_private_ip : module.region0.dns_inbound_endpoint_ip
}
```

**Conclusion:** DNS path is firewall IP when firewall is on, resolver IP when firewall is off. NAT Gateway does not affect DNS resolution.

## IP Addressing

**One static PIP per region.** This is sufficient for a demo/lab environment.

| Region | NAT Gateway PIP | Notes |
|---|---|---|
| Region 0 | `nat-gw-pip-{abbr}-{suffix}` | Standard SKU, Static allocation |
| Region 1 | `nat-gw-pip-{abbr}-{suffix}` | Same pattern, different region |

**Why static?** NAT Gateway requires Standard SKU PIPs, and Standard SKU PIPs are always static. There's no choice here — Azure enforces this.

**Why one PIP?** A single PIP provides 64,512 SNAT ports. For a demo/lab with a handful of VMs, this is more than adequate. Production scenarios might need multiple PIPs (up to 16 per NAT Gateway) for SNAT port exhaustion, but that's out of scope.

**Cost:** NAT Gateway costs ~$32/month (idle) + $0.045/GB processed. Significantly cheaper than Azure Firewall (~$912/month for Premium).

## Output Contract Changes

### New outputs from child module (`modules/region-hub/outputs.tf`)

```hcl
output "nat_gateway_id" {
  description = "NAT Gateway ID (null if firewall is deployed)"
  value       = local.deploy_nat_gateway ? azurerm_nat_gateway.nat_gateway[0].id : null
}

output "nat_gateway_pip" {
  description = "NAT Gateway public IP address (null if firewall is deployed)"
  value       = local.deploy_nat_gateway ? azurerm_public_ip.nat_gateway_pip[0].ip_address : null
}
```

### New outputs from root module (`Networking/outputs.tf`)

```hcl
output "nat_gateway00_id" {
  description = "NAT Gateway ID for region 0 (null if firewall is deployed)"
  value       = module.region0.nat_gateway_id
}

output "nat_gateway00_pip" {
  description = "NAT Gateway public IP for region 0 (null if firewall is deployed)"
  value       = module.region0.nat_gateway_pip
}
```

**Why expose the NAT Gateway ID?** ALZ modules may need it for subnet associations on their own VNets (see next section).

## ALZ Integration

This is the most nuanced part of the design. The Foundry modules create their own spoke VNets with subnets, and those spokes connect to the same vHub.

### Current ALZ architecture

```
Foundry VNet (ai-vnet)
├── ai-foundry-subnet    (delegated: Microsoft.App/environments)
├── private-endpoint-subnet
└── vHub connection (internet_security_enabled = add_firewall00)
```

### Two options for ALZ outbound

**Option A: ALZ modules deploy their own NAT Gateway (Recommended)**

Each Foundry module creates its own NAT Gateway in its own VNet when `add_firewall00 = false`. The Foundry module already consumes `add_firewall00` from the Networking remote state.

Pros:
- Self-contained — each ALZ owns its outbound path
- No cross-module resource sharing
- Different ALZs can have different outbound PIPs (useful for allowlisting)
- Aligns with Decision #1 (Landing Zone Architecture): app LZs are self-sufficient

Cons:
- Each ALZ pays for its own NAT Gateway ($32/month each)
- More PIPs to manage

**Option B: ALZ modules share the platform NAT Gateway**

NAT Gateway is a VNet-level resource — it cannot be shared across VNets. A NAT Gateway in the shared VNet cannot serve the Foundry VNet's subnets. This option is architecturally impossible without VNet peering and custom routing, which conflicts with the vWAN model.

**Decision: Option A is the only viable approach.**

### ALZ implementation sketch

In each Foundry module's `networking.tf`, add:

```hcl
locals {
  deploy_nat_gateway = !data.terraform_remote_state.networking.outputs.add_firewall00
}

resource "azurerm_public_ip" "nat_gateway_pip" {
  count               = local.deploy_nat_gateway ? 1 : 0
  name                = "nat-gw-pip-${local.region_abbr}-${random_string.unique.result}"
  location            = local.rg_location
  resource_group_name = azurerm_resource_group.rg_ai.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_nat_gateway" "nat_gateway" {
  count               = local.deploy_nat_gateway ? 1 : 0
  name                = "nat-gw-${local.region_abbr}-${random_string.unique.result}"
  location            = local.rg_location
  resource_group_name = azurerm_resource_group.rg_ai.name
  sku_name            = "Standard"
  tags                = local.common_tags
}

resource "azurerm_nat_gateway_public_ip_association" "nat_gateway_pip_assoc" {
  count                = local.deploy_nat_gateway ? 1 : 0
  nat_gateway_id       = azurerm_nat_gateway.nat_gateway[0].id
  public_ip_address_id = azurerm_public_ip.nat_gateway_pip[0].id
}

resource "azurerm_subnet_nat_gateway_association" "private_endpoint_subnet" {
  count          = local.deploy_nat_gateway ? 1 : 0
  subnet_id      = azurerm_subnet.private_endpoint_subnet.id
  nat_gateway_id = azurerm_nat_gateway.nat_gateway[0].id
}

# ai-foundry-subnet: delegated to Microsoft.App — test association compatibility
# before adding. If delegation blocks NAT Gateway, this subnet may need to rely
# on the managed network's own outbound rules (Foundry-managedVnet) or VNet-level
# default SNAT (Foundry-byoVnet).
```

### ALZ output contract impact

No new outputs needed from Networking for ALZ NAT Gateway. Each ALZ module already has `add_firewall00` from remote state — that's all it needs to derive `deploy_nat_gateway`.

The `nat_gateway00_id` and `nat_gateway00_pip` outputs from Networking are informational (useful for diagnostics/allowlisting) but not consumed by ALZ modules.

## vHub Routing Interaction Summary

This table captures the complete routing behavior matrix:

| Component | Firewall ON | Firewall OFF + NAT GW |
|---|---|---|
| **vHub routing intent** | Active (Internet + Private traffic policies) | Not deployed |
| **`internet_security_enabled`** | `true` on all hub connections | `false` on all hub connections |
| **Outbound internet path** | Spoke → vHub → Firewall SNAT | Spoke → NAT Gateway SNAT |
| **DNS resolution** | VNet DNS → Firewall DNS proxy → Resolver | VNet DNS → Resolver directly |
| **Private traffic routing** | Spoke → vHub → Firewall → destination spoke | Spoke → vHub → destination spoke (no inspection) |
| **NAT Gateway on spoke** | Bypassed (routing intent overrides) | Active on associated subnets |

## Risk Assessment

### Risk 1: Delegated subnet + NAT Gateway compatibility (Medium)

**Risk:** The `ai-foundry-subnet` (delegated to `Microsoft.App/environments`) and DNS resolver subnets (delegated to `Microsoft.Network/dnsResolvers`) may reject NAT Gateway association.

**Mitigation:** Do not associate NAT Gateway with delegated subnets initially. Test in a dev environment before adding associations. The shared and app subnets (non-delegated) are confirmed compatible.

### Risk 2: Foundry agent proxy outbound (Medium)

**Risk:** In the BYO VNet model, the Foundry agent proxy runs in the `ai-foundry-subnet`. Without firewall or NAT Gateway on that subnet, the proxy may lack outbound internet for its control-plane communication (e.g., reaching Cosmos DB, storage endpoints).

**Mitigation:** This is already handled by private endpoints — the proxy communicates with Azure services via private endpoints, not the public internet. The private-endpoint-subnet has direct private connectivity to Cosmos DB, Storage, AI Search. No internet outbound is needed for data-plane operations.

### Risk 3: Switching from firewall to NAT Gateway (Low)

**Risk:** Toggling `add_firewall` from `true` to `false` in an existing deployment will destroy the firewall + routing intent and create the NAT Gateway + subnet associations in a single apply. The ordering could cause transient connectivity loss.

**Mitigation:** This is a lab/demo repo. Transient loss during apply is acceptable. For production, a blue-green approach would be needed. Document the expected behavior in the tfvars example comments.

### Risk 4: No egress filtering (Low — accepted for demo/lab)

**Risk:** NAT Gateway provides SNAT but zero traffic inspection. All outbound traffic flows unfiltered.

**Mitigation:** This is the explicit trade-off for cost savings in a demo/lab. The firewall option remains available for users who need egress filtering. Document this trade-off in README and tfvars examples.

### Risk 5: AzureBastionSubnet association (None — avoided)

**Risk:** NAT Gateway cannot be associated with AzureBastionSubnet.

**Mitigation:** The design explicitly excludes Bastion subnets. Bastion uses its own PIP for outbound.

## Implementation Plan

### Phase 1: Platform Landing Zone (Networking module)

1. Create `modules/region-hub/nat-gateway.tf` with NAT Gateway resources and shared/app subnet associations
2. Add `nat_gateway_id` and `nat_gateway_pip` outputs to `modules/region-hub/outputs.tf`
3. Add `nat_gateway00_id` and `nat_gateway00_pip` outputs to `Networking/outputs.tf`
4. Update `terraform.tfvars.example` and `terraform.tfvars.advanced.example` with comments explaining the NAT Gateway behavior
5. Run `terraform validate` and `terraform fmt -check`
6. Test: deploy with `add_firewall00 = false`, verify NAT Gateway is created and VM has outbound internet via the NAT PIP

### Phase 2: Application Landing Zones (Foundry modules)

1. Add NAT Gateway resources to `Foundry-byoVnet/networking.tf`
2. Add NAT Gateway resources to `Foundry-managedVnet/networking.tf`
3. Associate `private-endpoint-subnet` with NAT Gateway
4. Test `ai-foundry-subnet` (delegated) association in dev — add if compatible, skip if not
5. Run `terraform validate` and `terraform fmt -check`
6. Test end-to-end: deploy Networking (no firewall) → deploy Foundry → verify agent works

### Phase 3: Documentation

1. Update Networking README with NAT Gateway behavior
2. Update `docs/ip-addressing.md` if new addressing considerations arise
3. Add architecture diagram showing the no-firewall topology

## Files Modified

| File | Change |
|---|---|
| `modules/region-hub/nat-gateway.tf` | **New file** — NAT Gateway resources |
| `modules/region-hub/outputs.tf` | Add `nat_gateway_id`, `nat_gateway_pip` |
| `Networking/outputs.tf` | Add `nat_gateway00_id`, `nat_gateway00_pip` |
| `Networking/terraform.tfvars.example` | Add NAT Gateway behavior comments |
| `Networking/terraform.tfvars.advanced.example` | Add NAT Gateway behavior comments |
| `Foundry-byoVnet/networking.tf` | Add NAT Gateway resources (Phase 2) |
| `Foundry-managedVnet/networking.tf` | Add NAT Gateway resources (Phase 2) |
| `Networking/README.md` | Document NAT Gateway feature (Phase 3) |

## Open Questions

1. **Foundry-managedVnet:** Does the managed network handle its own outbound? If so, NAT Gateway may be unnecessary for this module entirely — the Microsoft-managed network has its own outbound rules. Need to verify whether the managed VNet subnets even participate in spoke-level routing.

2. **Multiple PIPs:** Should we parameterize the PIP count for future production use? Current design hardcodes 1 PIP. Adding a variable (`nat_gateway_pip_count`) is low-effort but premature for a demo repo.

3. **Idle timeout:** Default is 4 minutes. Should this be configurable? Probably not for a demo repo, but noting it for completeness.

4. **Region 1 outputs:** The current root outputs only expose region 0 NAT Gateway info. Should we add region 1 outputs (`nat_gateway01_id`, `nat_gateway01_pip`)? Follow the same pattern as `vhub01_id` — expose conditionally when `create_vhub01 = true`.
