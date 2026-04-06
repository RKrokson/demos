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

### 9. Default Outbound Access Strategy — No NAT Gateway (Ryan Krokson)

**Status:** Approved  
**Date:** 2026-04-02

**Context:** Ryan requested simpler outbound internet path for lab/POC scenarios without relying on NAT Gateway.

**Decision:** 
- When Azure Firewall is NOT deployed: set `default_outbound_access_enabled = true` on shared and app subnets only (not DNS, Bastion, or delegated subnets)
- When firewall IS deployed: leave it `false` (firewall handles egress control)

**Rationale:** Simplifies non-production lab networking without requiring NAT Gateway infrastructure.

**Impact:** Replaces NAT Gateway design for POC/demo environments.

---

### 10. Team Pronouns & Identity (Ryan Krokson)

**Status:** Approved  
**Date:** 2026-04-02

**Decision:** Team members from Dungeon Crawler Carl series use the following pronouns:
- Carl — he/him (Lead/Architect)
- Donut — she/her (female cat, Infra Dev)
- Mordecai — he/him (Donut's manager)
- Katia — she/her (Validator)

All agents use correct pronouns when referring to team members.

**Impact:** Team communication clarity.

---

### 11. Foundry BYO VNet — Configuration Gaps & 403 Root Cause (Katia)

**Status:** Analysis Complete, Actionable Findings  
**Date:** 2026-07-15

**Problem:** Post-deployment, the Agents blade returns 403 from Cosmos DB. Investigation compares our module against Microsoft's official reference template ([15b](https://github.com/microsoft-foundry/foundry-samples/tree/main/infrastructure/infrastructure-setup-terraform/15b-private-network-standard-agent-setup-byovnet)).

**Key Findings:**

1. **Gap 1 (HIGH — PRIMARY SUSPECT):** `networkAcls.defaultAction`
   - Reference: `"Allow"`
   - Our module: `"Deny"`
   - Root cause: `"Deny"` blocks the agent proxy's internal control-plane communication, forcing fallback to public IP (rejected by Cosmos)

2. **Gap 2 (MEDIUM):** `disableLocalAuth` on Foundry resource
   - Reference: `false`
   - Our module: `true`
   - Issue: May force proxy into unsupported auth flow

3. **Gap 3 (VERIFY):** DNS resolution configuration (conditional via `enable_dns_link`)
   - Must confirm private DNS zones resolve correctly from VNet

**Recommended Fixes (in order):**
1. Change `networkAcls.defaultAction` from `"Deny"` to `"Allow"` in `Foundry-byoVnet/foundry.tf`
2. Change `disableLocalAuth` from `true` to `false` on Foundry resource (if #1 doesn't fully resolve)
3. Verify DNS link configuration with `nslookup <cosmos>.documents.azure.com` from within VNet

**Documentation Note:** Public endpoints are NOT required for BYO VNet — the architecture supports fully private, end-to-end isolation per Microsoft docs.

**Workarounds NOT recommended:** Do NOT set `public_network_access_enabled = true` or add `network_acl_bypass` — these weaken security and don't appear in reference templates.

---

### 12. Security Assessment — Networking + Foundry Modules (SystemAI)

**Status:** Complete, No Critical Findings  
**Date:** 2025-07-25

**Assessment Scope:** All three modules (Networking platform LZ, Foundry-byoVnet, Foundry-managedVnet) as reference architecture for public deployment.

**Summary:** Codebase demonstrates solid security fundamentals (private endpoints, Entra ID auth, Key Vault, Bastion, no hardcoded secrets). **3 medium findings** and **5 low findings** worth addressing; no critical issues or exposed secrets.

**Medium Severity (Recommend Addressing):**

| ID | Module | Finding | Recommendation |
|----|--------|---------|-----------------|
| M-1 | Networking | Key Vault uses legacy access policies (not RBAC) | Switch to `enable_rbac_authorization = true` + `azurerm_role_assignment` resources |
| M-2 | Networking | Key Vault has no purge protection | Document intentional choice for lab cleanup, or add toggle `enable_purge_protection` |
| M-3 | Networking | No NSGs on shared/app subnets (only Bastion/PE have NSGs) | Add default-deny NSGs with explicit allow rules for Bastion inbound |

**Low Severity (Accepted Risks — Document):**

| ID | Module | Finding | Status |
|----|--------|---------|--------|
| L-1 | Networking | Firewall allow-all rules | Accepted (backlog item #8 tracks hardening) |
| L-2 | Foundry-byoVnet | `disableLocalAuth=false` | Accepted (PG-required for agent proxy) |
| L-3 | Foundry-byoVnet | `networkAcls.defaultAction="Allow"` | Accepted (PG-validated for BYO VNet) |
| L-4 | Networking | VM admin username predictable | Low risk (Bastion eliminates public SSH/RDP exposure) |
| L-5 | Networking | No encryption at host on VMs | Platform SSE sufficient for lab |
| L-6 | All | Local Terraform state | Appropriate for single-operator demos |

**Positive Patterns (Preserve):**
- Private endpoints on all AI services, DNS zone integration
- Entra ID auth preferred; local auth disabled where possible
- Least-privilege RBAC with specific roles
- No hardcoded secrets; random generation + Key Vault storage
- Proper `.gitignore` (tfstate, tfvars, .env excluded)
- Bastion for VM access (no public IPs)
- Storage hardening (TLS 1.2 minimum, shared keys disabled)
- Conditional firewall/outbound handling

**Priority:** Donut should address M-3 (NSGs) as part of next infrastructure sprint. M-1 and M-2 are good-to-fix improvements aligned with Azure best practices.

---

### 13. PG 15b Reference Comparison — Foundry-byoVnet Delta Analysis (Carl)

**Status:** Complete — High-Confidence Findings  
**Date:** 2025-07-27

**Context:** Post-Phase 1/2/3 revamp deployment of Foundry-byoVnet results in 403 (Cosmos rejects Foundry agent proxy's public IP). Full delta comparison against official Microsoft PG template.

**Critical Deltas (403 Risk):**

| Property | PG Reference | Our Code | Changed in Revamp | Risk |
|----------|---|---|---|---|
| Foundry `networkAcls.defaultAction` | `"Allow"` | `"Deny"` | YES (hardening) | **HIGH** |
| Foundry `disableLocalAuth` | `false` | `true` | YES | **MEDIUM** |
| AI Search `disableLocalAuth` | `false` | `true` | YES | Low (not Cosmos) |
| Cosmos connection `category` | `"CosmosDb"` | `"CosmosDB"` | Unknown | **POSSIBLE** |

**Root Cause Assessment:**

The `networkAcls.defaultAction = "Deny"` change breaks the agent proxy's internal control-plane communication with the Foundry service. The PG template intentionally uses `"Allow"` (with `publicNetworkAccess = "Disabled"`) to permit first-party Azure service access while blocking external public endpoints. Our `"Deny"` blocks this internal path, forcing the proxy to use its public outbound IP → Cosmos DB rejects it (403).

**High-Confidence Fix:**
1. Change `networkAcls.defaultAction` to `"Allow"` in `foundry.tf` (highest confidence — matches PG exactly)
2. If still failing, also change `disableLocalAuth` to `false` on Foundry resource
3. Fix CosmosDB connection category casing to `"CosmosDb"`

**Do NOT change:** Cosmos DB, Storage network_rules, private endpoints, RBAC, capability host — these match PG reference and are not the issue.

**Identical Sections (Verified):** All RBAC roles, subnet delegation, networkInjections, Cosmos properties, private endpoint configs.

---

### 14. ACA ALZ Design Decisions — Ryan Interview (Ryan Krokson)

**Status:** Approved  
**Date:** 2026-04-06

**Context:** Pre-implementation review with Ryan resolved ambiguities in Carl and SystemAI's ACA architecture proposals.

**Decisions:**

1. **Module name:** `ContainerApps-byoVnet` — follows Foundry naming pattern for consistency
2. **Sample app:** Yes — include hello-world container app to verify environment post-deploy
3. **ACR:** Yes — Premium Azure Container Registry with private endpoint required
4. **Workload profiles:** Consumption always-on + optional D4 dedicated via boolean toggle (Carl's proposal accepted)
5. **Key Vault:** Reuse Networking module's Key Vault (no new KV in this module) — requires new Networking output for KV ID/URI
6. **Firewall rules:** Do NOT add rules to Networking module. Document in README that lab assumes any/any firewall rules. List specific ACA FQDN requirements (MCR, AKS dependencies) for users who lock down firewall.
7. **Intended workloads:** MCP servers, AI agents, AI-related demos — informs container sizing and profile defaults

**Impact:** Clarifies ACA architecture; Donut proceeds with implementation.

---

### 15. ContainerApps-byoVnet Implementation Decisions (Donut — Infra Dev)

**Status:** Implemented  
**Date:** 2026-04-06

**Context:** Donut completed ContainerApps-byoVnet module (11 files). Module follows Foundry-byoVnet pattern, deploys to IP Block 4 (172.20.64.0/20).

**Key Implementation Decisions:**

1. **ACR DNS zone ownership:** `privatelink.azurecr.io` is created in ACA module (not Networking). Networking only manages DNS zones used by its own resources. Single-owner cleaner; if future module needs ACR, centralize then.
2. **Workload profiles mode:** Consumption profile explicitly declared in ACA environment to enable workload profiles mode. Required for optional D4 dedicated profile via `add_dedicated_workload_profile` toggle.
3. **Sample app uses MCR image:** Hello-world pulls from MCR (not ACR) to avoid chicken-egg: need images before environment exists. ACR + managed identity infrastructure fully provisioned for user workloads.
4. **New Networking output:** Added `dns_vnet00_id` to expose DNS VNet ID for cross-module DNS zone linking. Enables app LZs to link their private DNS zones to centralized DNS VNet for resolver integration.
5. **No firewall rules:** Per Ryan's directive, no firewall rules added. ACA FQDN requirements documented in module README (when created).

**Impact:**
- New module fully independent — deploy/destroy without touching Networking or Foundry modules
- IP addressing doc updated with Block 4 allocation
- Networking output contract expanded (backward compatible — new output only)
- Handoff to Carl for code review and production readiness

---

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
- Team directives from Ryan (via Copilot) are recorded when they affect workflow/communication
