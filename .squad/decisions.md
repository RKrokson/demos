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

**Status:** Implemented & Approved  
**Date:** 2026-04-06

**Context:** Donut completed ContainerApps-byoVnet module (11 files). Module follows Foundry-byoVnet pattern, deploys to IP Block 4 (172.20.64.0/20).

**Key Implementation Decisions:**

1. **ACR DNS zone ownership:** `privatelink.azurecr.io` is created in Networking module (centralized pattern). Application LZs link to this zone, simplifying multi-module scenarios and avoiding duplication. Single-owner pattern from Networking's AVM private DNS.
2. **Workload profiles mode:** Consumption profile explicitly declared in ACA environment to enable workload profiles mode. Required for optional D4 dedicated profile via `add_dedicated_workload_profile` toggle.
3. **Sample app uses MCR image:** Hello-world pulls from MCR (not ACR) to avoid chicken-egg: need images before environment exists. ACR + managed identity infrastructure fully provisioned for user workloads.
4. **New Networking outputs:** Added `dns_vnet00_id` and `dns_zone_acr_id` to expose DNS VNet ID and centralized ACR DNS zone. Enables app LZs to link their resources to centralized DNS infrastructure.
5. **No firewall rules:** Per Ryan's directive, no firewall rules added. ACA FQDN requirements documented in module README.
6. **Ingress `external_enabled = true`:** Permits VNet-scoped reachability (not public internet exposure). Internal load balancer blocks public traffic; flag enables communication from peered spokes and on-premises networks. Verified safe for lab/internal workloads.
7. **Log Analytics consolidation:** ACA environment sends logs to platform Networking module's LAW (not module-local). Single pane of glass; acceptable for lab context.

**Impact:**
- New module fully independent — deploy/destroy without touching Networking or Foundry modules
- IP addressing doc updated with Block 4 allocation
- Networking output contract expanded (backward compatible — new outputs only)
- Centralized DNS pattern enables multi-module ACA deployment scenarios
- Verified secure by SystemAI; validated by Katia (14 checks pass)

**Sub-Decisions:**

- **16a. ACA Revalidation (Katia)** — 2026-07-16  
  All three fixes post-review are correct: `external_enabled = true` is private-network reachability; LAW consolidation reduces sprawl; ACR DNS zone centralization follows correct pattern. 14 validation checks pass.

- **16b. Security Recheck (SystemAI)** — 2026-07-18  
  All changes security-neutral or positive. `external_enabled = true` confirmed safe (no public endpoints); LAW consolidation acceptable for lab; DNS zone centralization is correct pattern. Approved for production.

---

### 16. Three-Mode Container App Deployment Pattern (Donut — Infra Dev)

**Status:** Implemented  
**Date:** 2026-04-08

**Context:** ContainerApps-byoVnet module previously hardcoded a single hello-world sample app. Ryan requested a flexible deployment pattern supporting three modes: no app, a quickstart verification app, and a real MCP Toolkit server.

**Decision:** Introduced `app_mode` variable with three values:
- **`none`** — ACA environment + ACR deployed, no container app. Useful when you only need the platform infrastructure.
- **`hello-world`** (default) — MCR quickstart image on port 80. Quick smoke test, no ACR pull needed.
- **`mcp-toolbox`** — MCP Toolkit server cloned from GitHub, built via `az acr build`, pushed to ACR, deployed on port 8080 with managed identity.

**Implementation Details:**
1. Two separate container app resources (not one with dynamic blocks) — hello-world and mcp-toolbox differ significantly in port, identity, registry config.
2. `terraform_data` with local-exec provisioner handles git clone + `az acr build` workflow. Cloud build means no local Docker Desktop required.
3. ACR `public_network_access_enabled` is conditional — `true` only in mcp-toolbox mode (required for `az acr build`), `false` otherwise.
4. Outputs renamed from `sample_app_id` to `container_app_id` and `container_app_fqdn`, both conditional with `try()`.

**Rationale:**
- Two resources is cleaner than heavy conditional logic when modes are materially different.
- `az acr build` is ideal for labs — no Docker Desktop dependency, builds run server-side in Azure.
- ACR public access tradeoff is acceptable for a lab; in production, use ACR Tasks with dedicated agent pools instead.

**Impact:**
- `sample_app_name` and `sample_app_image` variables removed (breaking change for existing tfvars files).
- `sample_app_id` output renamed to `container_app_id` (breaking output change).
- Pattern is reusable for future app modes (add new values to validation, add new container app resource with count guard).

---

### 17. Squad & Development Tooling Disclosure (Ryan Krokson)

**Status:** Approved  
**Date:** 2026-04-07T18:12Z

**Context:** User directive to clarify Squad's role in repo development.

**Decision:** Add a mention of Squad to the root README explaining that it's used for development of the repo but is not required to deploy the environments. Link to Brady's Squad website: https://bradygaster.github.io/squad/.

**Rationale:**
1. People may question the `.squad/` folder
2. Promotion for Brady and the Squad project

**Impact:** README will include Squad disclosure section.

---

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
- Team directives from Ryan (via Copilot) are recorded when they affect workflow/communication
