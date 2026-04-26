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

### 18. Bastion Works with vWAN Routing Intent (Secured Hub) (Carl — Lead/Architect)

**Status:** Evidence Collection In Progress  
**Date:** 2026-07-21  
**Requested by:** Ryan Krokson

**Context:** Microsoft documentation (Bastion FAQ) states that when Azure Virtual WAN hub is integrated with Azure Firewall as a Secured Virtual Hub, the AzureBastionSubnet must reside within a Virtual Network where the default 0.0.0.0/0 route propagation is disabled at the virtual network connection level.

Our deployed environment contradicts this. We have:
- Azure Firewall in vWAN hub (Sweden Central)
- Routing intent enabled (both `InternetTrafficPolicy` and `PrivateTrafficPolicy` → firewall)
- Bastion deployed in `shared_vnet` (spoke VNet)
- Hub connection has `internet_security_enabled = true` (0.0.0.0/0 route IS propagated)
- Bastion **works** — RDP/SSH connections to VMs succeed, VMs have internet access

**Hypothesis:** Bastion likely works because its data plane uses the **public IP directly** for WebSocket tunneling, not the spoke's default route. The 0.0.0.0/0 route injected by routing intent applies to traffic sourced from VM NICs in the subnet, but Bastion's own control/data plane communication uses a separate path (its public IP ↔ Azure backbone).

**Validation checklist developed for Microsoft PG** with 8 categories:
1. Connectivity evidence (RDP, SSH, file transfer, outbound internet)
2. Routing evidence (effective routes on VM NIC, hub connection configuration)
3. Firewall evidence (diagnostic logs, traffic flow analysis)
4. Network topology evidence (vWAN topology, routing intent configuration)
5. Configuration evidence (Terraform files, portal screenshots)
6. Edge cases (cross-VNet Bastion, shareable links, DNS resolution)
7. Negative tests (control cases establishing what would break)
8. Evidence packaging (compilation format for PG submission)

**Impact:** No Terraform code changes needed. May result in updated guidance for our module README. Validates current architecture pattern as correct.

---


### Microsoft Fabric Application Landing Zone — Architecture & Design (Carl — Lead)

**Status:** Approved — ready for Donut implementation
**Date:** 2026-04-09 (proposed) / 2026-04-09 (approved by Ryan after Q&A walkthrough)
**Module name:** `Fabric-byoVnet` (recommended — matches existing `Foundry-byoVnet`, `ContainerApps-byoVnet` naming. The "byoVnet" suffix is accurate: we provide the spoke VNet and use a workspace-level PE for inbound, so the ingress side genuinely is BYO. Outbound uses Managed Private Endpoints, but that is a workspace property, not a network mode.)

**Locked parameters (per Ryan, not re-litigated):** F2 default · swedencentral default · spin-up/teardown lifecycle · single-user-per-tenant · workspace-level PE only · 3 MPEs (lab Storage, lab Azure SQL, existing Networking PLZ Key Vault) · README + helpers + Terraform pre-flight (all three layers) · fail_fast pre-flight · hybrid admin pattern (UPN list OR security group OID, default current_user_upn) · `microsoft/fabric` provider preferred over azapi.

---

## 1. Module Structure

Directory: `Fabric-byoVnet/` at repo root, alongside `Foundry-byoVnet/`, `Foundry-managedVnet/`, `ContainerApps-byoVnet/`. File split mirrors `Foundry-byoVnet`:

| File | Contents |
|------|----------|
| `config.tf` | `terraform { required_version, required_providers }` block, provider configurations (`azurerm`, `azapi`, `random`, `fabric`). Backend stub commented out. |
| `main.tf` | `random_string.unique`, `data.terraform_remote_state.networking`, `data.azurerm_client_config.current`, the resource group `rg-fabric00`, `check {}` blocks for prereqs (DNS, Networking outputs). |
| `locals.tf` | `common_tags`, capacity admin resolution (hybrid pattern logic — see §7), name prefixes, computed `fabric_workspace_name`. |
| `variables.tf` | All inputs (see §7 for the non-obvious ones). |
| `networking.tf` | Spoke VNet, PE subnet, NSG, vHub connection, custom DNS servers binding, DNS resolver policy VNet link (azapi). |
| `capacity.tf` | `azurerm_fabric_capacity` (the Microsoft.Fabric/capacities ARM resource — capacity admins, SKU, region). |
| `workspace.tf` | `fabric_workspace` (microsoft/fabric provider), capacity assignment, workspace identity, workspace-level inbound network rule (workspace-level PE bind), `fabric_workspace_role_assignment` (operator gets Admin). |
| `workspace_pe.tf` | `azurerm_private_endpoint` for `Microsoft.Fabric/privateLinkServicesForFabric`/`workspace` subresource, DNS zone group binding to `privatelink.fabric.microsoft.com`. |
| `storage.tf` | Lab `azurerm_storage_account` (StorageV2, public network access disabled, no Azure PE — MPE handles ingress from Fabric only). |
| `sql.tf` | Lab `azurerm_mssql_server` + `azurerm_mssql_database` (auth: Entra-only, public network access disabled, AAD admin = current user). |
| `mpe.tf` | Three `fabric_workspace_managed_private_endpoint` resources (Storage blob, SQL Server, KV from remote_state) **plus three `azapi_resource_action` auto-approval steps** (one per target). Fabric MPEs always land in `Pending` on the target resource — no platform auto-approval exists; Terraform must approve. See §3 #12-#14b. |
| `outputs.tf` | Workspace ID, capacity ID, FQDN(s), storage/SQL IDs, MPE IDs+state. |
| `README.md` | Module-specific docs: prereqs, deploy/destroy steps, gotchas, FAQ (mirrors Foundry-byoVnet/README.md style). |
| `terraform.tfvars.example` | Minimal happy-path tfvars. |
| `scripts/` | Helper PowerShell + bash scripts (see §5). |

---

## 2. Network Architecture

**IP Block:** Block 5 in Region 0 — `172.20.80.0/20` (next free per `docs/ip-addressing.md`). Region 1 reserved at `172.21.80.0/20`. **Donut: update `docs/ip-addressing.md` as part of the implementation PR.**

**Subnets:**

| Subnet | CIDR | Purpose | Notes |
|--------|------|---------|-------|
| `private-endpoint-subnet` | `172.20.80.0/24` | Hosts the workspace-level PE | NSG attached, default-deny inbound. `default_outbound_access_enabled = !add_firewall00`. |
| (reserved/unused) | `172.20.81.0/24` – `172.20.95.0/20` | Future Fabric workloads (Spark VNet integration, Data Gateway VM, etc.) | Not provisioned now. |

No "fabric workload subnet" is needed: Fabric capacity is a tenant-bound managed service — no subnet delegation, no VNet injection (unlike Foundry's `Microsoft.App/environments`). MPEs live in the **Fabric-managed network**, not our VNet — there is no consumer-side subnet for outbound MPEs.

**vHub connection:** Same pattern as Foundry-byoVnet — `azurerm_virtual_hub_connection` with `internet_security_enabled = data.terraform_remote_state.networking.outputs.add_firewall00`.

**Custom DNS:** `azurerm_virtual_network_dns_servers` set to `data.terraform_remote_state.networking.outputs.dns_server_ip00` (firewall IP when firewall deployed, otherwise resolver inbound endpoint).

**DNS resolver policy link:** `azapi_resource` of type `Microsoft.Network/dnsResolverPolicies/virtualNetworkLinks@2023-07-01-preview`, pattern copy-pasted from Foundry-byoVnet/networking.tf.

**Private DNS zones required:**

| Zone | Used for | Where it must live |
|------|----------|-------------------|
| `privatelink.fabric.microsoft.com` | Workspace PE FQDNs (`{wsid}.z{xy}.w.api.fabric.microsoft.com`, `.c.`, `.dfs.`, `.blob.`, `.onelake.`, `.datawarehouse.`) | **NEW — must be added to Networking** |
| `privatelink.blob.core.windows.net` | Lab storage (consumed via Networking output) | Already in Networking |
| `privatelink.database.windows.net` | Lab Azure SQL | **NEW — must be added to Networking** (per Networking/README.md line 111, AVM module's exceptions list omits it) |
| `privatelink.vaultcore.azure.net` | Existing Networking KV | Already in Networking |

> **Decision (centralized DNS pattern):** Both new zones are added to the Networking module, following the centralized DNS pattern set by ContainerApps-byoVnet (Decision #15a, item 1). New Networking outputs: `dns_zone_fabric_id`, `dns_zone_sql_id`. Donut should bundle these Networking changes in the same PR (or a precursor PR) so `Fabric-byoVnet` can be deployed without manual zone creation. **Both zones are gated on `add_private_dns00 = true`.**
>
> **Why centralized:** matches the established pattern, avoids zone duplication when this module is deployed alongside others, and the Networking AVM private DNS module already accepts a custom `private_link_private_dns_zones` map for additions.

**A-record handling for the workspace PE:** the workspace FQDN is `{workspaceid}.z{xy}.w.api.fabric.microsoft.com` (and `.c.`, `.dfs.`, `.blob.`, `.onelake.` variants). The DNS zone group on the PE writes A records automatically based on the PE's IP plan — but the records use the `{wsid}.z{xy}` prefix, which is workspace-specific. Verify on first deploy that the DNS zone group correctly registers all five FQDN variants. (Microsoft Learn confirms the zone is correct; only one `privatelink.fabric.microsoft.com` zone is needed.)

---

## 3. Resource Inventory

| # | Resource | Provider | Notes |
|---|----------|----------|-------|
| 1 | `random_string.unique` | hashicorp/random | 4-char suffix. |
| 2 | `azurerm_resource_group.rg_fabric00` | hashicorp/azurerm | `rg-fabric00-{abbr}-{suffix}`. |
| 3 | `azurerm_virtual_network.fabric_vnet` | azurerm | Block 5. |
| 4 | `azurerm_subnet.private_endpoint_subnet` | azurerm | `/24`, NSG attached. |
| 5 | `azurerm_network_security_group.pe_subnet_nsg` + association | azurerm | Default-deny inbound. |
| 6 | `azurerm_virtual_hub_connection.vhub_connection_to_fabric` | azurerm | `internet_security_enabled` = `add_firewall00`. |
| 7 | `azurerm_virtual_network_dns_servers.fabric_vnet_dns` | azurerm | Points at platform DNS. |
| 8 | `azapi_resource.dns_security_policy_fabric_vnet_link` | azure/azapi | DNS resolver policy VNet link. |
| 9 | `azurerm_fabric_capacity.fabric_capacity` | azurerm | `sku.name = "F2"`, `administration_members = local.capacity_admins` (UPN list — see §7). |
| 10 | `fabric_workspace.workspace` | microsoft/fabric | Display name + capacity_id. |
| 11 | `fabric_workspace_role_assignment.operator_admin` | microsoft/fabric | Grants current user (or override) `Admin` on the workspace. |
| 12a | `fabric_workspace_managed_private_endpoint.mpe_storage` | microsoft/fabric | Target = lab storage (subresource `blob`). Lands in `Pending` on the target. |
| 12b | `azapi_resource_action.approve_mpe_storage` | azure/azapi | PATCH `{storage_id}/privateEndpointConnections/{conn_name}` with `properties.privateLinkServiceConnectionState.status = "Approved"`. `depends_on = [mpe_storage]`. |
| 13a | `fabric_workspace_managed_private_endpoint.mpe_sql` | microsoft/fabric | Target = lab SQL server (subresource `sqlServer`). Lands in `Pending`. |
| 13b | `azapi_resource_action.approve_mpe_sql` | azure/azapi | PATCH SQL server PE connection to `Approved`. `depends_on = [mpe_sql]`. |
| 14a | `fabric_workspace_managed_private_endpoint.mpe_keyvault` | microsoft/fabric | Target = remote_state KV ID (subresource `vault`). Lands in `Pending`. |
| 14b | `azapi_resource_action.approve_mpe_keyvault` | azure/azapi | PATCH KV PE connection to `Approved`. `depends_on = [mpe_keyvault]`. Operator already has Owner-equivalent rights on Networking's KV in the single-user lab pattern — no role assignment needed. |
| 15 | `azurerm_private_endpoint.pe_workspace` | azurerm | `subresource_names = ["workspace"]`, `private_connection_resource_id = "/subscriptions/{sub}/providers/Microsoft.Fabric/privateLinkServicesForFabric/{tenant-or-workspace-pls}"`. **VERIFY the parent PLS resource ID format** — for workspace-level PL, the connection target may need to be the workspace's `privateLinkServicesForFabric` resource (created implicitly when workspace inbound rules are configured). Donut: confirm via `microsoft/fabric` provider docs at implementation time. **Provider note:** controlled by `var.use_azapi_for_workspace_pe` (default `true`) — see §11 Q1 resolution. |
| 16 | `azurerm_storage_account.lab_storage` | azurerm | StorageV2, LRS, `public_network_access_enabled = false`, `shared_access_key_enabled = false`, `min_tls_version = "TLS1_2"`. No conventional Azure PE — MPE only. |
| 17 | `azurerm_mssql_server.lab_sql` | azurerm | `public_network_access_enabled = false`, Entra-only auth, `azuread_administrator { ... = current user }`. No SQL admin password. |
| 18 | `azurerm_mssql_database.lab_db` | azurerm | Basic SKU (cheapest — lab only). |
| 19 | `azurerm_monitor_diagnostic_setting.fabric_capacity_diag` | azurerm | Sends Fabric capacity diagnostic logs + metrics to Networking's LAW (`log_analytics_workspace_id` from remote_state). Mirrors ContainerApps LAW-consolidation pattern (Decision #15a item 7). |
| 20 | `null_resource.preflight_*` (or external data sources) | hashicorp/null + hashicorp/external | Pre-flight checks — see §6. |

Resources that are **NOT** in this module:
- No tenant-level Power BI/Fabric private link resource (`Microsoft.PowerBI/privateLinkServicesForPowerBI`) — workspace-level only.
- No Networking-side DNS zones (centralized in Networking — see §9).
- No conventional `azurerm_private_endpoint` for storage/SQL — MPEs handle Fabric→service ingress; no other consumers need private access in this lab.
- **No `azurerm_role_assignment` for the KV MPE.** Single-user lab pattern means the operator already has Owner on the subscription and therefore PE-approval rights on Networking's KV. Earlier draft proposed a self-bootstrap `Key Vault Reader` assignment — removed per Ryan (Q2). The MPE approval flow is the only thing that needed automation, and that's covered by the azapi_resource_action steps above.

---

## 4. Tenant Prerequisite Doc

> **Important correction to brief:** Some tenant settings labelled "portal-only" in the brief are actually manageable via the **Fabric Admin REST API** (`PATCH /admin/tenantsettings/{tenantSettingName}` per `learn.microsoft.com/rest/api/fabric/admin/tenants/update-tenant-setting`). The caller still needs the **Fabric Administrator** role and an admin-consented token. We treat them as "manual / one-time / portal-or-API" — README documents portal path (most accessible), helper script offers API automation for users who want repeatable setup, pre-flight checks detect the resulting state.

| Prereq | Scope | Frequency | How to set | Pre-flight detection |
|--------|-------|-----------|------------|----------------------|
| `Microsoft.Fabric` resource provider registered | Subscription | One-time per subscription | `az provider register --namespace Microsoft.Fabric` | `data.azurerm_client_config` + `azurerm` API call to `/subscriptions/{sub}/providers/Microsoft.Fabric` via external data source; assert `registrationState == "Registered"`. |
| **Microsoft Fabric enabled for the tenant** (or for the operator's security group) | Tenant | One-time per tenant | Portal: Admin portal → Tenant settings → "Microsoft Fabric" → Enabled. API: `update-tenant-setting` with name `EnableFabric` (verify exact identifier at impl time). | Cannot reliably detect via Terraform without admin token. **Indirect detection:** attempt to create the workspace; if it fails with a specific error code, surface a clear remediation. We document this and fail at apply time with a tagged error message. |
| **Service principals can use Fabric APIs** | Tenant | One-time per tenant | Portal: Tenant settings → Developer settings → "Service principals can call Fabric public APIs" → Enabled, scoped to a security group containing the SPN. API: `update-tenant-setting`. | **Only required when Terraform runs as SPN.** Pre-flight detects auth mode via `data.azurerm_client_config.current.client_id` vs. user UPN; if SPN and the SPN can't list workspaces (test API call), fail with a remediation message. |
| **Configure workspace-level inbound network rules** | Tenant | One-time per tenant | Portal: Tenant settings → "Configure workspace-level inbound network rules" → Enabled. API: `update-tenant-setting` (setting name to be verified — likely `WorkspaceLevelPrivateEndpointSettings` or similar). | Same as "Fabric enabled" — indirect detection via API attempt. **Tenant setting toggle requires re-registering Microsoft.Fabric** in the subscription afterward. Document this clearly. |
| **Users can create Fabric items** | Tenant | One-time per tenant | Portal: Tenant settings → "Users can create Fabric items" → Enabled. API: `update-tenant-setting`. | Indirect — workspace creation will fail otherwise. |
| Operator UPN has F SKU available in tenant region | Tenant + Region | Per-deploy verifies | N/A — implicit in capacity creation. | `data.azurerm_locations` filtered for Fabric capacity offers; cross-check `var.azure_region_name` is in supported list. (Sweden Central confirmed in "All workloads".) |
| Operator has rights to assign Fabric Capacity admins | Subscription / RG | Per-deploy | Operator must be RG Owner or Contributor + User Access Administrator. | Pre-flight: attempt `azurerm_role_assignment` dry-run via `data` source; rely on Terraform's apply-time error otherwise. |

**Per-deploy implicit prereqs (handled by module, not user):**
- DNS prerequisite (Private DNS deployed in Networking) — already enforced by the existing `check "dns_prerequisite"` pattern from Foundry-byoVnet/main.tf.
- Networking outputs `dns_zone_fabric_id` and `dns_zone_sql_id` populated — `check {}` block.
- vHub deployed (`vhub00_id != null`) — `check {}` block.
- Key Vault output present (`key_vault_id != null`) — `check {}` block.

---

## 5. Helper Script Outline (Donut produces)

Path: `Fabric-byoVnet/scripts/`

| Script | Purpose | What it does |
|--------|---------|--------------|
| `check-tenant-prereqs.ps1` | Read-only pre-flight reporter — run before `terraform plan` | (1) `az account show` → confirm tenant, sub, signed-in user. (2) `az provider show -n Microsoft.Fabric` → registration state. (3) `Invoke-RestMethod` against Fabric Admin REST API `/admin/tenantsettings` with delegated admin token → list tenant setting states for the four required settings. (4) Print a pass/fail table and exit non-zero if any required setting is off or unknown. (5) For unknown (no admin token), print the portal URL and a manual checklist. Bash equivalent: `check-tenant-prereqs.sh`. |
| `configure-fabric-tenant-settings.ps1` | Optional bootstrap for a fresh tenant | Calls Fabric Admin REST API `update-tenant-setting` for each of: Enable Fabric, SPN can use Fabric APIs (with security group OID parameter), workspace-level inbound rules, Users can create Fabric items. Requires Fabric Administrator role. After the workspace-inbound-rules toggle, runs `az provider register --namespace Microsoft.Fabric` to refresh the provider as documented. Idempotent (re-checks state before patching). Bash equivalent. |
| `register-fabric-provider.ps1` | Subscription-level provider registration | `az provider register --namespace Microsoft.Fabric --wait`. Idempotent. Run before first deploy and after any workspace-inbound-rules toggle. Bash equivalent. |
| `purge-soft-deleted.ps1` | Post-destroy cleanup | After `terraform destroy`, purges any soft-deleted Fabric/Power BI workspaces (Fabric soft-delete behavior — see §8) and the SQL server (mssql soft-delete). Mirrors Foundry-byoVnet's purge guidance. Bash equivalent. |
| `approve-mpe.ps1` | Diagnostic / break-glass MPE approval helper (Terraform handles approval automatically — this script is for failure recovery only) | If a Terraform-driven approval (azapi_resource_action) failed mid-apply and left an MPE in `Pending`, this script approves via `az network private-endpoint-connection approve`. Bash equivalent. **Not part of the happy-path workflow** — Ryan: Q2 resolution puts approval in Terraform. |

All scripts: **PowerShell + bash variants** (matches repo precedent of `setSubscription.ps1` plus newly cross-platform helpers). Scripts emit structured output (one line per check) so Terraform's `external` data source can consume them in pre-flight blocks.

---

## 6. Pre-flight Check Spec

Three layers — all `fail_fast` with actionable error messages.

**Layer A — `check {}` blocks (warnings, soft validation, non-blocking but visible):**

```hcl
# Existing pattern from Foundry-byoVnet/main.tf — replicate per condition:
check "dns_prerequisite" { ... }
check "fabric_dns_zone_present" { ... }   # asserts dns_zone_fabric_id != null
check "sql_dns_zone_present" { ... }      # asserts dns_zone_sql_id != null
check "vhub_present" { ... }              # asserts vhub00_id != null
check "key_vault_present" { ... }         # asserts key_vault_id != null
```

**Layer B — variable `validation {}` blocks (hard, fail at parse time):**
- `var.fabric_capacity_sku`: must match `^F(2|4|8|16|32|64|128|256|512|1024|2048)$`. Default `F2`.
- `var.azure_region_name`: must be in the Fabric "All workloads" supported list (hardcoded list — Sweden Central, North Europe, West US 2, etc.). Default `swedencentral`.
- Hybrid admin pattern: see §7 for the exact validation logic — `(length(capacity_admin_upn_list) > 0) || (capacity_admin_group_object_id != null)` AND not both.

**Layer C — `data "external"` pre-flight scripts (hard, fail at plan time with rich error messages):**

| Check | What it runs | Fail-fast message |
|-------|--------------|-------------------|
| `preflight_provider_registered` | `az provider show -n Microsoft.Fabric --query registrationState -o tsv` | "Microsoft.Fabric resource provider is not registered in subscription `{sub_id}`. Run `./scripts/register-fabric-provider.ps1` and re-run terraform plan." |
| `preflight_capacity_quota` | `az fabric capacity list-skus --subscription {sub} --query "[?name=='F2']"` (or equivalent ARM call) | "F2 capacity SKU is not available in `{region}` for this subscription. Try a different region or check with your subscription admin." |
| `preflight_admin_principal_resolves` | When `capacity_admin_upn_list` set: `az ad user show --id {upn}` for each. When `capacity_admin_group_object_id` set: `az ad group show --group {oid}`. | "Capacity admin `{upn or oid}` does not resolve in tenant `{tenant_id}`. Verify the value or your sign-in tenant." |
| `preflight_tenant_settings` (best-effort, warning-only when admin token unavailable) | `Invoke-RestMethod /admin/tenantsettings/{name}` for the four required settings | "Fabric tenant setting `{name}` is `{Disabled\|NotConfigured}`. Required for this module. To enable: portal → Admin portal → Tenant settings → `{path}`, OR run `./scripts/configure-fabric-tenant-settings.ps1`. Note: if `WorkspaceLevelPrivateEndpointSettings` was just toggled, you must also re-register Microsoft.Fabric." |
| `preflight_dns_zones_in_networking_state` | Inspect terraform_remote_state outputs | "`dns_zone_fabric_id` is null in Networking remote state. Add `privatelink.fabric.microsoft.com` to Networking's private DNS zones (this likely means the Networking module needs an update — see Fabric-byoVnet/README.md prereqs)." |

**Pattern:** Each `data "external"` returns `{ok = "true"|"false", message = "..."}`. A downstream `null_resource` with a `lifecycle { precondition { ... } }` enforces it. Apply halts with the structured message at plan time, which matches the spec's "fail fast with clear remediation messages."

---

## 7. Hybrid Admin Identity Pattern

**Variable shape:**

```hcl
variable "capacity_admin_upn_list" {
  description = "List of UPNs to assign as Fabric Capacity admins. Either this OR capacity_admin_group_object_id must be set. Defaults to the current Azure CLI signed-in user (zero-config first run)."
  type        = list(string)
  default     = []   # locals fallback fills in current user UPN if both this and the group OID are unset
}

variable "capacity_admin_group_object_id" {
  description = "Object ID of an Entra security group whose members should be Fabric Capacity admins. Takes precedence over capacity_admin_upn_list when set. Recommended for production / shared environments."
  type        = string
  default     = null
}
```

**Locals + validation:**

```hcl
data "azurerm_client_config" "current" {}

# Resolve current user UPN via az cli when neither input is set (zero-config first run)
data "external" "current_user_upn" {
  count = (length(var.capacity_admin_upn_list) == 0 && var.capacity_admin_group_object_id == null) ? 1 : 0
  program = ["pwsh", "-NoProfile", "-Command",
    "az ad signed-in-user show --query '{upn:userPrincipalName}' -o json"
  ]
}

locals {
  # Precedence: explicit group OID > explicit UPN list > current user fallback
  capacity_admins_resolved = var.capacity_admin_group_object_id != null ? [var.capacity_admin_group_object_id] : (
    length(var.capacity_admin_upn_list) > 0 ? var.capacity_admin_upn_list : [data.external.current_user_upn[0].result.upn]
  )
  capacity_admin_mode = var.capacity_admin_group_object_id != null ? "group" : "users"
}
```

**`azurerm_fabric_capacity` body** receives `administration_members = local.capacity_admins_resolved`. The provider accepts UPNs and group object IDs in the same array; `capacity_admin_mode` is informational for outputs/logs.

**Validation (top-level):**

```hcl
# Cross-variable validation — implemented via a check{} block since
# Terraform doesn't support multi-variable validation in one place yet.
check "exactly_one_admin_source" {
  assert {
    condition = !(length(var.capacity_admin_upn_list) > 0 && var.capacity_admin_group_object_id != null)
    error_message = "Set either capacity_admin_upn_list OR capacity_admin_group_object_id, not both."
  }
}
```

The "default = current_user_upn" requirement is met by the `data.external` fallback in locals — this gives genuinely zero-config first-run behavior without making `data.azurerm_client_config.current.user_principal_name` (which doesn't reliably populate UPN) the source of truth.

---

## 8. Teardown Gotchas (predictions + workarounds)

Drawing on the Foundry-byoVnet `serviceassociationlink` lesson, these are the predictable destroy-time issues:

| # | Risk | Prediction | Workaround |
|---|------|------------|-----------|
| 1 | **MPE approval-state cleanup on destroy** | Fabric MPEs always land in `Pending` on the target until approved. The module Terraform-approves all 3 MPEs at apply time (azapi_resource_action). On destroy, the `fabric_workspace_managed_private_endpoint` removal *should* cascade-delete the corresponding `privateEndpointConnections/{name}` on the target resource, but the azapi_resource_action approval has no destroy semantics (actions aren't lifecycle-bound). Risk: orphaned `Approved` PE connection on Networking's KV after `terraform destroy` of Fabric module, blocking later KV operations. | **Mitigation:** `purge-soft-deleted.ps1` includes an explicit cleanup pass that lists and removes any orphaned `privateEndpointConnections` on Networking's KV, lab Storage, and lab SQL whose origin matches our workspace. Document in README destroy section. Verify on first destroy whether the cascade actually works — if the Fabric provider's destroy cleanly removes the target-side connection, this becomes a no-op. |
| 2 | **Fabric Capacity in `Paused` state** | If a user pauses the capacity to save cost between sessions, `azurerm_fabric_capacity` destroy may fail to find the resource in the expected `Active` state. | README guidance: do NOT pause for teardown — destroy from `Active`. If already paused, resume first (`az fabric capacity resume`) before destroy. |
| 3 | **Workspace soft-delete / Power BI recycle bin** | Fabric workspaces enter a soft-delete / recycle-bin state for ~90 days after deletion. They retain a name lock — re-deploying with the same workspace name fails until purge. | Workspace name uses `random_string.unique` suffix already, so name collision unlikely on next deploy. Add purge to `purge-soft-deleted.ps1` for users who want to reclaim quota. |
| 4 | **Capacity admin chicken-and-egg on first deploy** | The signed-in user must be a Fabric Admin to set `administration_members` on the capacity. If neither UPN nor group is set and the `data.external` fallback fails (e.g., no `az` cli on PATH), capacity creation fails opaquely. | `preflight_admin_principal_resolves` (§6) catches this. README documents `az login` as a hard prereq. |
| 5 | **Workspace PE → workspace deletion ordering** | Deleting the Fabric workspace before the Azure-side `azurerm_private_endpoint` may leave the PE in a `Disconnected` state but still consuming a PE-subnet IP. | Explicit `depends_on` chain: `fabric_workspace` → `azurerm_private_endpoint.pe_workspace` (PE depends on workspace), so destroy goes PE-first → workspace-second naturally via Terraform graph reversal. |
| 6 | **Storage soft-delete blob containers** | Storage account destroy may fail if blob soft-delete retains containers. | `azurerm_storage_account` block includes `blob_properties { delete_retention_policy { days = 1 } }` (minimum) for lab — or disable soft-delete entirely for non-prod. |
| 7 | **SQL Server soft-delete** | `azurerm_mssql_server` destroy works cleanly, but the server name is reserved for ~7 days post-delete. | Same suffix-randomization mitigates. Document in README. |
| 8 | **Tenant setting "workspace-level inbound network rules" toggling** | If a user disables this tenant setting after deploy and re-enables, the existing workspace's inbound rule may need to be reconfigured. Microsoft Learn explicitly says re-register `Microsoft.Fabric` after toggling. | README destroy section: do not toggle during a deploy lifecycle. |

---

## 9. Integration Points with Networking PLZ

**Existing outputs consumed (no Networking changes required for these):**

| Output | Used for |
|--------|----------|
| `rg_net00_location` | Resource group location |
| `azure_region_0_abbr` | Naming suffix |
| `vhub00_id` | `azurerm_virtual_hub_connection` |
| `add_firewall00` | `internet_security_enabled` toggle |
| `dns_resolver_policy00_id` | DNS resolver policy VNet link |
| `dns_server_ip00` | Custom DNS servers on the VNet |
| `dns_inbound_endpoint00_ip` | Optional — only if directly referencing |
| `key_vault_id` | MPE target (KV) |
| `key_vault_name` | Output / diagnostics |
| `dns_zone_blob_id` | Reused if storage MPE needs Azure-side DNS resolution from VNet (optional — MPE is workspace-side; VNet-side resolution only if a VM in the spoke needs to resolve the storage account) |
| `dns_zone_vaultcore_id` | Same — for VNet-side KV resolution if needed |

**New outputs required from Networking (Donut adds these in same PR or precursor):**

| New output | Source | Purpose |
|------------|--------|---------|
| `dns_zone_fabric_id` | `privatelink.fabric.microsoft.com` (added to AVM zones map) | Workspace PE DNS zone group |
| `dns_zone_sql_id` | `privatelink.database.windows.net` (added to AVM zones map — currently excluded per README line 111) | SQL VNet-side resolution if needed |

**Networking module changes summary:**
1. Add two zones to the AVM private DNS zones module's input map.
2. Add two `output {}` blocks (mirror existing `dns_zone_*_id` pattern).
3. No other Networking changes required.

---

## 10. Provider Versions

| Provider | Source | Version constraint | Rationale |
|----------|--------|-------------------|-----------|
| `azurerm` | `hashicorp/azurerm` | `~> 4.26.0` | Match Foundry-byoVnet/config.tf. `azurerm_fabric_capacity` has been GA in 4.x — confirm exact min version supports F2 SKU at impl time (was added around 4.12 IIRC; pin floor accordingly). |
| `azapi` | `azure/azapi` | `~> 2.3.0` | Match repo. Used for DNS resolver VNet link only (and as escape hatch if any property surfaces are missing on `microsoft/fabric` provider). |
| `fabric` | `microsoft/fabric` | `~> 1.0` | Pin to first GA major. Per Microsoft Learn (July 2025 "Terraform Provider for Microsoft Fabric tutorial"), the provider covers `fabric_workspace`, `fabric_workspace_role_assignment`, `fabric_workspace_managed_private_endpoint`. **Donut: verify exact resource names/schema at impl time** — the provider is young and resource names may have shifted. |
| `random` | `hashicorp/random` | `~> 3.5` | Match repo. |
| `null` | `hashicorp/null` | `~> 3.2` | For pre-flight `null_resource` precondition pattern. |
| `external` | `hashicorp/external` | `~> 2.3` | For pre-flight `data "external"` script invocations. |

Provider configuration: `azurerm` features block matches Foundry-byoVnet (`prevent_deletion_if_contains_resources = false`, `storage_use_azuread = true`). `microsoft/fabric` provider auth uses the same `az` CLI / Azure-managed credential chain — no separate `provider "fabric" {}` configuration needed beyond the standard.

---

## 11. Resolved Decisions (Ryan walkthrough — locked)

The eight open questions from the proposal have been walked through with Ryan. All decisions below are locked; Donut implements against these.

### Q1 — `microsoft/fabric` provider coverage for workspace-level PE binding → **azapi fallback under feature flag**

Ship today with azapi as the implementation for workspace-PE binding (it's the safer bet given provider maturity). Expose a Terraform variable so users can flip to the native provider once parity is verified — no code rewrite needed for the migration.

```hcl
variable "use_azapi_for_workspace_pe" {
  description = "Use azapi_resource for workspace-level PE binding (current default). Set to false once microsoft/fabric provider parity is verified — module will use the native fabric_workspace_inbound_network_rule resource instead. Migration path: re-run terraform plan; the resource type changes but state can be moved with terraform state mv."
  type        = bool
  default     = true
}
```

**Migration path documented in README:**
1. Verify `microsoft/fabric` provider exposes the workspace-PE binding resource at the version pinned in `config.tf`.
2. Set `use_azapi_for_workspace_pe = false` in `terraform.tfvars`.
3. `terraform plan` will show a destroy/create on the binding resource. To preserve state without recreating the PE, run `terraform state mv azapi_resource.workspace_pe_binding fabric_workspace_inbound_network_rule.binding` (resource names finalized at impl).
4. `terraform apply` — should be a no-op if state move was clean.

### Q2 — KV RBAC self-bootstrap → **REVISED: no role assignment, but Terraform-drive MPE approval for all 3 targets**

Ryan and the brief flagged a hole in my original reasoning. **Verified against Microsoft Learn (`learn.microsoft.com/fabric/security/security-managed-private-endpoints-create`):** Fabric MPEs are *never* auto-approved by the platform — they always land in `Pending` and require admin action on the target resource.

**Implications for the single-user lab pattern:**
- The operator runs `terraform apply` for both Networking and Fabric-byoVnet, holds Owner on the subscription, and therefore already has approval rights on KV (Networking RG), lab Storage (Fabric RG), and lab SQL (Fabric RG). **No Key Vault Reader role assignment is needed** — the original §11 Q2 proposal was wrong; perms exist by default.
- What's needed instead: a Terraform-driven approval step that runs after each MPE creation. This applies to **all three** MPEs, not just KV.

**Pattern (per MPE):**
1. `fabric_workspace_managed_private_endpoint.{name}` creates the pending request on the target.
2. `azapi_resource_action.approve_{name}` PATCHes `{target_id}/privateEndpointConnections/{conn_name}` with `properties.privateLinkServiceConnectionState.status = "Approved"` and a fixed business justification (`"Auto-approved by Fabric-byoVnet Terraform module"`).
3. `depends_on = [fabric_workspace_managed_private_endpoint.{name}]` to enforce ordering.
4. The connection name on the target is generated by Fabric — the azapi action needs to *list* connections first (data source) and pick the right one (the one whose `properties.privateEndpoint.id` matches our MPE), or rely on a deterministic name pattern. **Donut: figure out the lookup pattern at impl time.**

**Reflected in the doc:**
- §1 file split: `mpe.tf` description updated to mention auto-approval pairs.
- §3 resource inventory: 12 → 12a/12b, 13 → 13a/13b, 14 → 14a/14b. Added 19 (diagnostic settings — Q7) and renumbered tail.
- §3 "NOT in this module": added explicit "no role assignment for KV MPE" note.
- §5 helper script `approve-mpe.ps1` reclassified as diagnostic / break-glass only.
- §8 teardown gotcha #1 rewritten — risk shifts from "manual approval orphan" to "orphaned `Approved` PE connections after destroy because azapi_resource_action has no destroy semantics."

### Q3 — Tenant setting names in Fabric Admin REST API → **Donut verifies at impl time**

No design change. Existing notes in §4 and §5 stand. Donut's `configure-fabric-tenant-settings.ps1` and `check-tenant-prereqs.ps1` get final tenant setting identifiers (`EnableFabric`, `WorkspaceLevelPrivateEndpointSettings`, `UsersCanCreateFabricItems`, `ServicePrincipalsCanCallFabricPublicAPIs` — exact strings TBD) from the Fabric Admin REST API reference at implementation time. Update the helper script and pre-flight messages accordingly.

### Q4 — Sample workspace content → **`workspace_content_mode = "none"` MVP, `lakehouse` as future work**

Ship MVP with no sample item in the workspace. Add a new variable for forward-compatibility:

```hcl
variable "workspace_content_mode" {
  description = "Sample content to deploy in the workspace. 'none' (default) ships an empty workspace. 'lakehouse' (FUTURE — not yet implemented) will deploy a sample Lakehouse for end-to-end verification."
  type        = string
  default     = "none"
  validation {
    condition     = contains(["none"], var.workspace_content_mode)
    error_message = "Only 'none' is supported in this release. 'lakehouse' is reserved for a future release."
  }
}
```

Mirrors ContainerApps' `app_mode` pattern (Decision #16) — the variable exists from day one with a single valid value, future modes added by relaxing the validation list and adding the corresponding resource block.

**Future work note:** When `lakehouse` is added, the resource will be `fabric_lakehouse` (microsoft/fabric provider). No change to capacity, networking, or MPE design.

### Q5 — Capacity pause/resume → **destroy-only**

Locked spin-up/teardown lifecycle stands. README destroy section explicitly says: *do not pause to "save" between sessions — always `terraform destroy` and re-create on next session.* §8 teardown gotcha #2 retained as the failure mode for users who try to destroy from a paused state.

### Q6 — Region 1 / multi-region → **defer**

Single region this round. `docs/ip-addressing.md` reserves `172.21.80.0/20` for future Region 1. No multi-region toggle in `Fabric-byoVnet` variables — when added, follow the existing pattern (region-1 variables gated on `data.terraform_remote_state.networking.outputs.vhub01_id != null`).

### Q7 — Diagnostic settings → **YES, send to Networking's LAW**

Mirrors ContainerApps decision (Decision #15a item 7). Added as resource #19 in §3:

```
azurerm_monitor_diagnostic_setting.fabric_capacity_diag
  target_resource_id        = azurerm_fabric_capacity.fabric_capacity.id
  log_analytics_workspace_id = data.terraform_remote_state.networking.outputs.log_analytics_workspace_id
  enabled_log { category_group = "allLogs" }
  metric { category = "AllMetrics" }
```

Networking's `log_analytics_workspace_id` output is already exposed (verified in `Networking/outputs.tf` line 30) — no new Networking output needed for Q7.

### Q8 — `internet_security_enabled` vs MPE outbound → **Donut verifies at impl time**

No design change. Expectation: MPEs originate from Fabric's managed network, not our spoke, so the spoke's 0.0.0.0/0 firewall route should not affect MPE traffic. Donut confirms by checking firewall logs for MPE-origin traffic during a `add_firewall00 = true` test deploy. If unexpected interaction shows up, raise a fresh decision item.

---

## TL;DR for Ryan (post-approval)

- New module `Fabric-byoVnet` at IP block 5 (`172.20.80.0/20`), F2 capacity in swedencentral, single-PE-subnet spoke.
- 21 resources (was 19) across azurerm + azapi + microsoft/fabric + null/external — added 3 azapi MPE auto-approval actions and 1 diagnostic settings resource per Q2/Q7.
- Two new private DNS zones added to Networking (`fabric.microsoft.com`, `database.windows.net`) — minimal Networking change, centralized DNS pattern preserved.
- Three-layer prereq strategy: README + helper PS/bash scripts (`scripts/`) + Terraform `check{}`/`validation{}`/`data "external"` pre-flight.
- Hybrid admin pattern: explicit group OID > explicit UPN list > `data.external` fallback to `az ad signed-in-user show`.
- Workspace-PE binding ships behind `use_azapi_for_workspace_pe = true` feature flag (Q1) — flip to `microsoft/fabric` provider when parity verified.
- All 8 open questions resolved (§11). Three are deferred verifications for Donut at impl time (Q3, Q8, the workspace-PE PLS resource ID format), five are locked design choices, none block implementation.

**Next step:** Donut starts implementation. Likely PR sequence:
1. Networking: add `privatelink.fabric.microsoft.com` and `privatelink.database.windows.net` to AVM zones map; add `dns_zone_fabric_id` and `dns_zone_sql_id` outputs.
2. `Fabric-byoVnet` module (all files per §1).
3. `docs/ip-addressing.md` Block 5 claim + root README entry.


## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
- Team directives from Ryan (via Copilot) are recorded when they affect workflow/communication

