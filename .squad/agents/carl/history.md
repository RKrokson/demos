# Carl — Architecture Lead (Architect)

- **Owner:** Ryan Krokson
- **Project:** Azure IaC demo/lab environments — Terraform modules for Azure vWAN, AI Foundry, networking
- **Stack:** Terraform (azurerm >= 4.0, azapi >= 2.0, random ~> 3.5), PowerShell, Azure CLI
- **Structure:** Three root modules — Networking (foundation), Foundry-byoVnet, Foundry-managedVnet linked via terraform_remote_state
- **Created:** 2026-03-27

## Recent Work

- **2026-04-06 (aca-alz-architecture):** Designed Azure Container Apps ALZ. IP Block 4 (172.20.64.0/20), /27 delegated subnet, centralized DNS pattern, no NSG on delegated subnet. Comprehensive 358-line architecture proposal. SystemAI security assessment confirmed no blocking concerns.

- **2026-04-06 (ryan-aca-interview):** Ryan approved ACA ALZ architecture. Decisions: module name = ContainerApps-byoVnet, sample app included, Premium ACR required, D4 workload profile optional, reuse platform KV, no firewall rules in Networking, document FQDN requirements for users locking down firewall.

- **2026-04-08 (container-app-multi-mode):** Three-mode container app deployment pattern: `none` (no app, platform only), `hello-world` (MCR quickstart, default), `mcp-toolbox` (MCP server from GitHub, built via ACR, port 8080). Two separate resources, `terraform_data` with local-exec for git clone + build. ACR public access conditional (true in mcp-toolbox mode only).

- **2026-04-10 (donut-networking-deploy):** Donut deployed Networking platform LZ successfully — 579 resources in Sweden Central, Firewall at 172.30.0.132, DNS resolver at 172.20.16.4. azurerm bumped to 4.68.0. Region 1 off. Ready for Foundry + ContainerApps modules.

- **2026-04-14 (bastion-routing-intent-validation):** Created comprehensive validation checklist for Ryan to prove Bastion works with vWAN routing intent (secured hub). Microsoft docs say AzureBastionSubnet requires 0.0.0.0/0 propagation disabled, but our deployment works with `internet_security_enabled = true`. Checklist covers 8 evidence categories: connectivity, routing, firewall logs, topology, config, edge cases, negative tests, and PG packaging. Hypothesis: Bastion data plane uses its public IP directly, not the spoke's default route — the injected 0.0.0.0/0 from routing intent doesn't affect Bastion's own traffic. Decision filed to `decisions/inbox/carl-bastion-routing-intent.md`.

- **2026-04-14 (team-update-orchestration):** Parallel agent orchestration session. Deployed Networking LZ (579 resources, suffix 8575) + Foundry-byoVnet (32 resources, suffix 8999) with one vHub transient recovery. Bastion validation checklist completed and decision merged into team decisions (Decision #18). Orchestration logs written. Both modules stable for downstream operations. Foundry environment ready for Bastion validation testing and Microsoft PG evidence collection.

## Learnings

- **Bastion + vWAN Routing Intent:** Azure Bastion deployed in a spoke VNet with `internet_security_enabled = true` (routing intent active, 0.0.0.0/0 propagated) works despite Microsoft Bastion FAQ saying it shouldn't. Bastion's data plane likely uses its public IP directly and doesn't follow the spoke's default route. Key evidence points: effective routes on VM NIC (same VNet), firewall logs showing whether Bastion traffic transits the FW, and the `internetSecurity` flag on the hub connection. This contradicts the Bastion FAQ docs as of July 2026.

## Key Patterns

- Platform/application landing zone model: Networking = shared foundation, Foundry/ContainerApps = pluggable workloads
- azurerm tagging: use `local.common_tags` (locals.tf) + explicit per-resource assignment (never `default_tags` block)
- Child module pattern for region-scoped resources (modules/region-hub/) eliminates boolean toggle bugs
- IP addressing: /20 blocks per module, non-overlapping for simultaneous deployment
- DNS architecture: centralized in Networking, spokes link to shared zones via conditional `enable_dns_link`
- Firewall/NAT Gateway mutually exclusive (routing intent precedence)


- **2026-04-24 (donut-platform-foundry-deploy):** Donut deployed Networking LZ (firewall + DNS) + Foundry-byoVnet to Sweden Central. SUCCESS: 611 total resources (Networking 579 suffix 8357, Foundry-byoVnet 32 suffix 0918) in ~57 min. Firewall 172.30.0.132, DNS Resolver 172.20.16.4, Foundry aifoundry0918/project0918 with GPT-5.4 model. One transient DNS resolver policy VNet link InternalServerError resolved by retry (3rd documented occurrence of this transient).
## See Also

- **decisions.md** — Team approval decisions and architecture direction
- **history-archive.md** — Detailed research/design work (July 2025 - March 2026)
- Donut, Katia, Mordecai, SystemAI histories for parallel work

## Learnings — 2026-04-09 — Fabric ALZ design

- New module proposed: `Fabric-byoVnet` at IP block 5 (`172.20.80.0/20`). F2 / swedencentral. Design dropped at `.squad/decisions/inbox/carl-fabric-alz-design.md` for Ryan review.
- **DNS zone for Fabric workspace PE is single zone:** `privatelink.fabric.microsoft.com` (resource `Microsoft.Fabric/privateLinkServicesForFabric`, subresource `workspace`). Verified via Microsoft Learn "Azure Private Endpoint private DNS zone values" doc. Tenant-level Power BI uses a different zone set (`analysis.windows.net`, `pbidedicated.windows.net`, `prod.powerquery.microsoft.com`) — NOT needed for workspace-level pattern.
- **Networking AVM private DNS zones module excludes `privatelink.database.windows.net`** (per Networking/README.md line 111). Fabric ALZ needs SQL — both `fabric.microsoft.com` and `database.windows.net` zones must be added to Networking. Centralized DNS pattern continues (matches Decision #15a item 1).
- **Fabric tenant settings ARE API-manageable** via Fabric Admin REST API `update-tenant-setting` (not portal-only as the brief assumed). Caller needs Fabric Admin role. Toggling "workspace-level inbound network rules" requires re-registering `Microsoft.Fabric` provider afterward.
- **F SKU + MPE + workspace-level PL all supported on F2** (verified via Fabric features parity doc — F SKU column shows MPE ✅ and Workspace-level private links ✅; trial supports MPE only via footnote ^1).
- Hybrid admin pattern resolution order: explicit group OID > explicit UPN list > `data.external` fallback to `az ad signed-in-user show`. `data.azurerm_client_config.current.user_principal_name` is unreliable so use az cli external data source for the zero-config first run.
- Predictable teardown gotchas: MPE approval-state leftover on KV cross-RG, capacity-paused-state destroy failure, workspace soft-delete (90d), workspace-PE ordering. Mitigated via `purge-soft-deleted.ps1` and explicit `depends_on`.
- Provider strategy: `microsoft/fabric` for workspace + MPEs + role assignments. `azurerm_fabric_capacity` for the capacity. `azapi` retained as escape hatch for any workspace-PE binding gap (open question #1 for Ryan).
- New Networking outputs needed: `dns_zone_fabric_id`, `dns_zone_sql_id`. Update `docs/ip-addressing.md` to claim Block 5.

## Learnings — 2026-04-25 — Fabric ALZ DNS zones correction (Ryan review)

- **Always verify AVM module defaults against the live source (`variables.tf`), not just the README.** The AVM `private_link_private_dns_zones` default list (~75 zones) includes `azure_fabric` → `privatelink.fabric.microsoft.com` and `azure_sql_server` → `privatelink.database.windows.net`. Both were already being created by Networking's AVM invocation — no zone additions were ever needed in Networking.
- **The AVM invocation in `Networking/modules/region-hub/main.tf:206-218` passes NO `private_link_excluded_zones`**, so all AVM-default zones are created. Always check for the zone key in the AVM `variables.tf` source before claiming a zone is missing.
- **`Networking/README.md` line 111 is misleading.** It says the AVM module excludes `privatelink.{dnsPrefix}.database.windows.net` — that's the SQL Managed Instance variant (requires a caller-constructed custom dnsPrefix), NOT the standard `privatelink.database.windows.net` SQL Server zone. Flag for future README cleanup to avoid repeating this mistake.
- **Fabric workspace PE only needs one zone:** `privatelink.fabric.microsoft.com`. Subdomains like `.dfs.fabric.microsoft.com`, `.onelake.fabric.microsoft.com`, etc. resolve under the same zone — no separate zones required. Verified via Microsoft Learn "Azure Private Endpoint private DNS zone values".

## Learnings — 2026-04-25 — Fabric ALZ M1/M2 from SystemAI security review

- **M1 trade-off documented (lab-friendly public access by design):** "Block Public Internet Access" is intentionally NOT enforced in this lab — workspace PE adds a private *additional* path, not a private-*only* path. Public endpoints remain open so browser-based lab participants can reach the workspace. Acceptable for lab/POC with synthetic data; must be revisited if production data is ever loaded. Ryan made the call: option (a) — document the omission, add optional `--enforce-private-only` flag to the helper script as deferred work.
- **M2 MPE lookup spec'd (filter by PE resource ID, not state):** The azapi_resource_action auto-approval MUST filter `privateEndpointConnections` by `properties.privateEndpoint.id == MPE resource ID`. Never use "first Pending" or name-pattern matching — the shared Networking KV can have connections from other modules, concurrent deploys, or failed teardowns. Also: add a post-apply `check {}` assertion that each MPE's `connection_status == "Approved"` — silent Pending is the key failure mode.

## Learnings — 2026-04-09 — Fabric ALZ design (Ryan walkthrough)

- All 8 open questions resolved. Design status: Approved — ready for Donut implementation.
- **CORRECTION to my Q2 reasoning:** Fabric MPEs are NEVER auto-approved by the platform — they always land in `Pending` on the target. Verified Microsoft Learn: `learn.microsoft.com/fabric/security/security-managed-private-endpoints-create`. My original "auto-approve = true (same-tenant, same-sub)" assumption for storage/SQL was wrong; same-tenant only affects whether approval rights exist, not whether the platform auto-approves. Always pending.
- Right pattern: `azapi_resource_action` PATCH on `{target_id}/privateEndpointConnections/{name}` setting `properties.privateLinkServiceConnectionState.status = "Approved"` with `depends_on = [mpe_resource]`. Apply per MPE (3 actions for our 3 MPEs).
- Single-user lab pattern means operator already has Owner on subscription → has approval rights on KV cross-RG without any module-side role assignment. The role assignment I originally proposed was unnecessary.
- `azapi_resource_action` has no destroy semantics. New teardown risk: orphaned `Approved` PE connections on target after Fabric MPE destroy. Mitigation moved into `purge-soft-deleted.ps1`.
- Q1 resolution: ship workspace-PE binding via azapi behind `var.use_azapi_for_workspace_pe = true` feature flag. Migration path documented (terraform state mv + flip variable).
- Q4: `var.workspace_content_mode = "none"` MVP only. `lakehouse` reserved for future via validation list (mirrors ContainerApps app_mode pattern).
- Q7: Add `azurerm_monitor_diagnostic_setting` for Fabric capacity → Networking LAW. `log_analytics_workspace_id` already in Networking outputs (line 30). No Networking change needed for this.
- Resource count went 19 → 21 (added 3 azapi auto-approval actions, 1 diagnostic setting; merged some numbering as 12a/12b/13a/13b/14a/14b).

## Learnings — 2026-04-25 — Fabric ALZ SystemAI Security Review (APPROVE WITH CONDITIONS)

- **Design gates — YOU MUST RESOLVE BEFORE DONUT STARTS IMPL:**
  - **M1 — "Block Public Internet Access" decision:** The design omits this tenant setting (probably intentionally for multi-browser POC access). Decide: either document the intentional omission with a README note, OR add it as an optional flag in `configure-fabric-tenant-settings.ps1`. Either choice is acceptable — the gap is that the design doesn't state which you chose. Add this to §4 (Tenant Prereqs) and README.
  - **M2 — MPE connection name lookup specification:** Your §11 Q2 defers the connection lookup to Donut with "figure out the lookup pattern at impl time." SystemAI flagged: lookup MUST filter by `properties.privateEndpoint.id` (not just "first Pending"), especially on the shared KV where multiple PE connections may exist from concurrent deploys. Specify the lookup strategy in §11 Q2, or explicitly delegate to Donut with this acceptance criterion.
- **Implementation gates (Donut addresses in PR, no blocking):**
  - **M3:** Mark KV PE connection cleanup as mandatory (not optional) in destroy README docs. Reference purge-soft-deleted.ps1.
  - **M4:** Define PE subnet NSG rules explicitly (inbound on ports 443, 1433 from VirtualNetwork, default-deny). Reference Foundry-byoVnet NSG as template.
- **L1–L6 (advisory):** Low findings for Donut's opportunistic incorporation — no gate.
- **13 positive patterns confirmed** — workspace-level PE (not tenant), Entra-only auth, public access disabled, hybrid admin pattern, etc. Design is architecturally sound. Zero critical findings.

- **2026-04-26 (fabric-alz-steps-1-3-complete-branch-ready):** [ORCHESTRATION LOG — FINAL] All three steps of Fabric ALZ implementation complete on squad/fabric-alz-impl:
   - **Step 1 (Carl, 2026-04-26):** DNS zones added to Networking outputs (dns_zone_fabric_id, dns_zone_sql_id) — branch created from main at fae6bee.
   - **Step 2 (Donut, 2026-04-26):** Full Fabric-byoVnet/ module implementation (13 files, commit c884193). All M1–M4 security mitigations integrated. MPE auto-approval skill documented.
   - **Step 3 (Mordecai, 2026-04-26):** Documentation synchronized (docs/ip-addressing.md Block 5 + root README, commit 09dfcd7).
   - **Status:** Design → implementation → documentation chain complete. Branch ready for Ryan review and merge to main. Orchestration logs and session logs recorded. Full history cross-annotations complete.
