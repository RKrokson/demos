# Squad Decisions

## Active Decisions

### 1. Landing Zone Architecture Framing (Carl — Lead/Architect)

**Status:** Approved  
**Date:** 2026-03-29

Adopt the platform/application landing zone model:
- **Platform Landing Zone:** Networking module (vWAN, hubs, DNS, shared connectivity)
- **Application Landing Zones:** Foundry-byoVnet, Foundry-managedVnet (workload-specific resources)
- Future app LZs must be onboardable without modifying platform module
- Platform-to-app interface must be a well-defined output contract

**Impact:** Architectural direction set for all future changes. All READMEs, variables, and outputs must align with this model.

---

### 2. Documentation Revamp — Landing Zone Framing & Structure (Mordecai — Docs)

**Status:** Approved  
**Date:** 2026-03-29

Key decisions:
1. Root README becomes navigation hub (not content dump); each module gets self-contained docs
2. Landing zone terminology adopted consistently
3. Cleanup/destroy sequencing consolidated into single guide or root-level section
4. copilot-instructions.md updated to reflect landing zone framing
5. Diagram folder casing normalized (decide: git mv or content update?)

**Impact:** All READMEs will be restructured. Diagram path casing must be fixed (Windows hides case differences; Linux breaks on mismatch).

---

### 3. Terraform Best Practices & Code Quality (Donut — Infra Dev)

**Status:** Proposed (requires team consensus on implementation order)  
**Date:** 2026-03-29

Five key questions for implementation:

1. **Adopt `default_tags` in provider block?** Zero resources are tagged today. This is a team-wide convention choice.
   - **Recommendation:** Yes — improves cost tracking and governance.

2. **Split Networking/main.tf into per-concern files?** 1020 lines is unwieldy.
   - **Proposed split:** `vwan.tf`, `firewall.tf`, `dns.tf`, `vpn.tf`, `compute.tf`, `ai-spoke.tf`
   - **Recommendation:** Yes — improves maintainability.

3. **Add `required_version` to Networking/config.tf?** Both Foundry modules pin >= 1.8.3 but Networking does not.
   - **Recommendation:** Yes — consistency and safety.

4. **Tighten firewall rules from allow-all?** Current rules allow `*` source/destination/port.
   - **Recommendation:** Yes — even for demos, this is a security risk if connected to production networks.

5. **Adopt remote state backend for all modules?** Local state is fine for single-operator demos, but fragile.
   - **Recommendation:** No immediate action — local is acceptable for single-operator; document in README.

**High-Priority Bugs (implement first):**
- Line 505 VPN naming bug (s2s_conn01 → s2s_conn00)
- fw01_logs count missing create_vhub01 guard
- s2s_VPN01 count missing create_vhub01 guard
- ai_vnet01_dns count missing create_vhub01 guard

---

### 4. Boolean Toggle Validation & Count Guards (Katia — Validator)

**Status:** Approved  
**Date:** 2026-03-29

**Problem:** 7 boolean toggles in Networking module interact without validation. Invalid combinations cause cryptic Terraform crashes.

**Specific crashes found:**
1. `add_firewall01 = true` + `create_vhub01 = false` → fw01_logs crashes
2. `add_s2s_VPN01 = true` + `create_vhub01 = false` → VPN01 crashes
3. `add_privateDNS01 = true` + `create_AiLZ = true` + `create_vhub01 = false` → ai_vnet01_dns crashes

**Proposal:** Add `validation {}` blocks to region-1 conditional variables that depend on `create_vhub01`, OR fix count expressions to include guard. Validation blocks give clearer error messages.

**Impact:** Users with invalid toggle combinations will get clear guidance instead of cryptic failures. This is a UX and reliability improvement.

---

### 5. Foundry Module Output Naming Standardization (Carl — Lead/Architect)

**Status:** Approved  
**Date:** 2025-07-25

The two Foundry module output files use inconsistent naming for equivalent resources:

| Concept | Foundry-byoVnet | Foundry-managedVnet |
|---|---|---|
| Foundry account | `ai_foundry_id` | `foundry_id` |
| Foundry project | `ai_foundry_project_id` | `foundry_project_id` |

**Decision:** Standardize on `ai_foundry_` prefix across both modules.

**Rationale:**
1. Matches the product name (Azure AI Foundry)
2. BYO module already uses it consistently
3. Avoids ambiguity — `foundry_id` alone is vague

**Implementation:** Rename internal resources in `Foundry-managedVnet/main.tf` and update its `outputs.tf`. No external consumers exist yet, so this is a zero-cost rename.

**Priority:** Medium — must be done before any downstream automation consumes these outputs.

---

### 6. Tagging Strategy — locals + explicit per-resource tags (Carl — Lead/Architect)

**Status:** Approved  
**Date:** 2025-07-25

**Context:** Donut's initial implementation used `default_tags` in the provider block. Katia's validation correctly identified this as invalid — `default_tags` is an AWS Terraform provider concept, not supported by azurerm.

**Decision:** Use `local.common_tags` defined in `locals.tf` and apply `tags = local.common_tags` explicitly on every taggable resource.

**Tagging Rules:**

1. **azurerm resources** — add `tags = local.common_tags` to all resources that support the `tags` argument (resource groups, VNets, VMs, NICs, firewalls, bastions, Key Vault, Log Analytics, etc.). Skip resources that don't support tags (subnets, hub connections, diagnostic settings, role assignments, etc.).
2. **azapi_resource** — add `tags = local.common_tags` as a top-level argument on tracked resources only (those with a `location`). Skip child/proxy resources (connections, capabilityHosts, virtualNetworkLinks, outbound rules, managed networks).
3. **Standard tag set:** `environment = "non-prod"`, `managed_by = "terraform"`, `project = "azure-infra-poc"`.

**Impact:**
- Backlog item #6 ("Adopt default_tags strategy") is now resolved with the correct approach.
- Carl (Fix tags implementation) tagged 59 resources across all three modules on 2026-03-30.
- All modules pass `terraform validate`.

**Key Learning:** azurerm provider does not support `default_tags` — always use locals + explicit per-resource tagging.

---

## Implementation Backlog (Prioritized)

1. **CRITICAL:** Fix 4 count-guard bugs (Katia's findings)
2. **CRITICAL:** Fix VPN naming bug (line 505)
3. **HIGH:** Add validation blocks for boolean toggles
4. **HIGH:** Split Networking/main.tf into per-concern files
5. **HIGH:** Normalize diagram folder casing
6. **HIGH:** Adopt default_tags strategy
7. **MEDIUM:** Add required_version to Networking/config.tf
8. **MEDIUM:** Tighten firewall rules
9. **MEDIUM:** Mark sensitive outputs
10. **LOW:** Fix formatting drift (terraform fmt)

---

### 7. AI Landing Zone VNet Migration (Carl — Lead/Architect)

**Status:** Approved  
**Date:** 2026-03-30

**Context:** AI Landing Zone resources (VNet, subnets, hub connection, DNS configs) currently live in Networking module but logically belong to each application landing zone.

**Decision:** Move AI LZ VNet creation from Networking module into each Foundry module (Foundry-byoVnet, Foundry-managedVnet). Networking retains vHub, shared spokes, DNS zones, and firewall.

**Scope:** 6 resource types move per region:
- `azurerm_virtual_network` (ai_vnet00)
- `azurerm_subnet` (ai_foundry_subnet00, private_endpoint_subnet00)
- `azurerm_virtual_hub_connection` (vhub_connection00-to-ai)
- `azurerm_virtual_network_dns_servers` (ai_vnet00_dns)
- `azapi_resource` (dns_security_policy_ai_vnet00_link)

**New Networking Outputs:**
- `rg_net00_name` — Resource group name for VNet placement
- `dns_resolver_policy00_id` — DNS resolver policy ID (if Private DNS enabled)
- `dns_inbound_endpoint00_ip` — Inbound endpoint IP for custom DNS

**New Variables per Foundry Module:** 8 variables for VNet/subnet config, plus `connect_to_vhub` and `enable_dns_link` toggles.

**IP Addressing:** Non-overlapping defaults assigned:
- **Foundry-byoVnet:** Block 2 (172.20.32.0/20) — keeps current Networking default
- **Foundry-managedVnet:** Block 3 (172.20.48.0/20) — enables future co-deployment

**Impact:**
- Aligns with Decision #1 (Landing Zone Architecture)
- Enables future simultaneous deployment of both Foundry modules without IP collision
- Resolves Katia's count-guard bug #3 by removing conditional resources
- Implementation assigned to Donut (Phase 3+)

---

### 8. Foundry AI Spoke Firewall Control (Donut — Infra Dev)

**Status:** Implemented  
**Date:** 2026-03-30

**Decision:** Add `internet_security_enabled = var.add_firewallXX` toggle to AI spoke vHub connections in both Foundry modules.

**Rationale:** Enables conditional control over whether Foundry workloads route through Azure Firewall or bypass inspection when firewall is deployed. Aligns with Phase 2 security hardening pattern (merged secure/unsecure connection pairs).

**Implementation:**
- Foundry-byoVnet/networking.tf: Added toggle to AI spoke connection
- Foundry-managedVnet/networking.tf: Added toggle to AI spoke connection

**Impact:** Backward compatible; no state changes required.

---

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
