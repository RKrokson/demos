# Donut — Infra Developer (she/her, female cat) — SUMMARIZED

- **Owner:** Ryan Krokson
- **Project:** Azure IaC demo/lab environments — Terraform modules for Azure vWAN, AI Foundry, networking
- **Stack:** Terraform (azurerm >= 4.0, azapi >= 2.0, random ~> 3.5), PowerShell, Azure CLI
- **Structure:** Three root modules — Networking (foundation), Foundry-byoVnet/Fabric-private, Foundry-managedVnet linked via terraform_remote_state
- **Created:** 2026-03-27

---

## Summary

Donut is the infrastructure developer driving module implementation and live deployment. Started with Networking platform (vWAN, firewall, DNS, 3 Foundry ALZs). Shipped full Fabric-private ALZ (April–July 2026). **Major recent achievement:** Deployed workspace-level private endpoint for Fabric (2026-07-17), correcting the wrong prior decision that claimed it doesn't exist. Specialized in Azure provider quirks (azapi auth, fabric capacity UUID mapping, MPE filtering), Terraform patterns (multi-module coordination), and operational troubleshooting (transient errors, state reconciliation).

---

## Most Recent Work (2026-07-17 workspace-pe-deploy)

- **Fabric Workspace-Level PE:** Implemented per Carl's ADR design. Added `azapi_resource.fabric_private_link_service` (Microsoft.Fabric/privateLinkServicesForFabric@2024-06-01) and `azurerm_private_endpoint.pe_fabric_workspace`. Updated `workspace-policy.tf` depends_on to PE (not bare workspace). Added 3 outputs. Result: workspace PE IP 172.20.80.5, deny-public-access policy queued (30-min propagation). Files changed: fabric.tf, workspace-policy.tf, outputs.tf, README.md.

## Cross-Agent Coordination (2026-07-17)

**Partner:** Carl (Architect). Workspace-level PE fix deployed successfully. Key validation: `Microsoft.Fabric/privateLinkServicesForFabric` IS valid (workspace-scoped). azapi + azurerm cross-provider works. `schema_validation_enabled = false` required for bundled schema gap. Tenant-level PE out of scope per Ryan.

---

## Key Learnings — Recent Sessions

### Fabric PE Pattern (2026-07-17)
- **Microsoft.Fabric/privateLinkServicesForFabric IS valid:** The prior "not a real resource" note (line 52 of full history) was WRONG. This is the workspace-level PE anchor type (API 2024-06-01, global). Distinct from `Microsoft.PowerBI/privateLinkServicesForPowerBI` (tenant-level).
- **azapi schema_validation_enabled = false:** Bundled schema doesn't yet include this resource type. Without the flag, azapi rejects with "can't be found" error. Flag bypasses validation, lets ARM handle it directly. Workaround for any new ARM resource type not in bundled schema.
- **azurerm PE → azapi PLS cross-provider:** `private_connection_resource_id = azapi_resource.fabric_private_link_service.id` works — azapi resource ID is ARM path format.
- **Workspace PE private IP 172.20.80.5:** First IP in /24 pe_subnet. Creation took 56s. Normal timing.

### Full Deploy Patterns (2026-07-17 first-deploy, abridged)
- **Cross-tenant azapi auth:** azapi 2.x uses DEFAULT az CLI account's tenant. If CLI default is corporate and target sub is in personal tenant → 403 on all GETs. Fix: `az account set --subscription {target}` before Terraform. Setting `ARM_TENANT_ID` alone doesn't work (corporate account not registered in personal tenant).
- **Fabric capacity UUID:** `azurerm_fabric_capacity.id` is ARM format. `fabric_workspace.capacity_id` needs Fabric UUID. ARM API doesn't expose UUID. Fix: `data "fabric_capacity" { display_name = azurerm_fabric_capacity.name }`.
- **MPE PE connection filter:** Fabric UUID ≠ ARM PE path. Use `endswith(lower(conn.id), lower("{workspace_id}.{mpe_name}"))` for matching.
- **Fabric workspace creator auto-Admin:** Don't create explicit role assignment — creator already has Admin.

### Fabric SSMS Connection Strings (2026-07-18 LATEST)
- **SSMS Fabric-aware connection bug:** When SSMS connects to Lakehouse SQL endpoint, it makes a pre-TDS metadata call via `FabricWorkspaceApi.GetAsync`. With regular connection string (e.g., `{id}.datawarehouse.fabric.microsoft.com`), SSMS calls public `api.fabric.microsoft.com` → gets blocked by workspace deny-public policy. Solution: Use workspace-level private-link format with z{xy} prefix.
- **z{xy} format:** Insert `.z${first_2_chars_of_workspace_id_without_dashes}.` before `.datawarehouse.`. Example workspace ID `9627b1aa-...` → `z96`. So `{id}.datawarehouse.fabric.microsoft.com` becomes `{id}.z96.datawarehouse.fabric.microsoft.com`. SSMS recognizes prefix, routes metadata call through workspace PE FQDN (`{id-no-dashes}.z96.w.api.fabric.microsoft.com`), which resolves to PE private IP (172.20.80.5) via private DNS zone. Succeeds.
- **DNS gap by design:** `.z96.datawarehouse.fabric.microsoft.com` has NO private DNS A record. Fabric routing recognizes z96 prefix and transparently routes TDS traffic to workspace PE. Expected behavior, not misconfiguration.
- **Terraform outputs added:** New outputs `lakehouse_sql_connection_string` (public, for reference) and `lakehouse_sql_connection_string_private_link` (z{xy} format, for SSMS). IaC formula: `replace(..., ".datawarehouse.", ".z${substr(replace(workspace_id, "-", ""), 0, 2)}.datawarehouse.")`
- **Rule:** For any workspace with deny-public inbound policy, always use z{xy} format for client tool connection strings. Regular format will always fail from private networks if tool makes control-plane metadata call before SQL connection.

### Fabric Deploy Findings (2026-04-29)
- **Lakehouse display_name hyphen bug:** display_name rejects hyphens (letters/numbers/underscores only). Changed `lakehouse-${random_string}` → `Lakehouse_${random_string}`.
- **workspace_communication_policy race condition:** Terraform scheduled workspace PE, lakehouse, and MPEs in parallel. PE completed first → deny-public fired early → item creation calls blocked. Fixed by adding lakehouse + MPEs to depends_on of `terraform_data.workspace_communication_policy`. Deny-public now fires only after all items created.
- **Terraform import gap:** No import support for fabric resources. Recovery: REST delete orphans, taint communication_policy, destroy PE+PLS+policy, re-apply.


- **modtm refresh is the long pole:** 181 modtm_module_source data sources → ~30 min of GitHub calls. Total Networking destroy: 44 min (30 min refresh + 14 min Azure).
- **vHub destroy:** 10m45s — normal.
- **Foundry-byoVnet partial state:** If never applied past random_string/remote_state, destroy is instant — no Azure cleanup needed.

### Fabric Admin API (2026-07-15)
- **LIST-only read:** No per-setting GET. API has 161 total settingName values. Script must LIST once, cache, look up desired settings.
- **POST /update (not PATCH):** Verb+path is POST to `/v1/admin/tenantsettings/{settingName}/update`. PATCH doesn't exist.
- **Setting name corrections:** EnableFabric → removed (not in API). UsersCanCreateFabricItems → FabricGAWorkloads. WorkspaceLevelPrivateEndpointSettings → WorkspaceBlockInboundAccess. ServicePrincipalsCanCallFabricPublicAPIs → ServicePrincipalAccessGlobalAPIs.
- **Entra role + tenant provisioning gates:** Two independent prerequisites for any Fabric admin script.

---

## Architectural Patterns Established

- **Multi-region naming:** {resource}-{region_abbr}-{random_suffix} (e.g., kv00-sece-8357)
- **Per-LZ soft-delete + 7-day retention:** Lab-friendly KV lifecycle (purge protection off)
- **MPE auto-approval:** azapi_resource_list + strict ID filter + azapi_resource_action PUT + check {}
- **Workspace-local KV:** Eliminates orphaned PE on destroy; RBAC-only security
- **DNS resolver policy VNet link retry:** Transient InternalServerError — safe to retry

### Full lab teardown — Fabric-private + Networking (2026-07-17)
- **MPE UnknownError on destroy:** `fabric_workspace_managed_private_endpoint` resources (mpe_keyvault, mpe_storage) fail with `UnknownError` during `terraform destroy` if the workspace PE has already been removed (likely a Fabric API timing issue). Workaround: `terraform state rm` to drop them from state, then delete them manually via the Fabric REST API before deleting the workspace.
- **WorkspaceContainsManagedEndpoints:** Fabric refuses to delete a workspace if managed private endpoints still exist, even if they're no longer tracked in Terraform state. Must DELETE each MPE first: `GET /v1/workspaces/{id}/managedPrivateEndpoints` to list, then `DELETE /v1/workspaces/{id}/managedPrivateEndpoints/{mpeId}` for each. Only after that will `fabric_workspace` destroy succeed.
- **RequestDeniedByInboundPolicy on refresh:** Once workspace deny-public is active, any `terraform destroy` without `-refresh=false` will fail immediately — the Fabric provider can't refresh `fabric_workspace`. Always use `-refresh=false` for any destroy when workspace deny-public is in effect.
- **KV with PE already removed → 10+ min soft-delete wait:** `azurerm_key_vault` with `public_network_access_enabled = false` takes ~10 minutes to soft-delete when its private endpoint was already destroyed earlier in the same run. Appears to poll an async ARM operation. Normal; just wait.
- **Networking destroy with `-refresh=false`:** Skips the 30-min modtm GitHub refresh. Total time with `-refresh=false`: ~15 min for Azure operations (vHub destroyed in ~10 min, vWAN + RG ~1 min). Acceptable for teardown when state is known good.
- **Orphan soft-deleted KVs:** Two KVs (`kv00-sece-0473`, `kv00-sece-1850`) were left over from prior teardowns (March 2026). Purged during this session. KV purge takes 5–10 min each — sequential, no batching.
- **Outcome:** Full teardown successful. Fabric-private: 4 final resources destroyed after manual MPE cleanup. Networking: 579 resources destroyed. All RGs gone, no soft-deleted resources remaining.

### Full lab teardown — Fabric-private + Networking (2026-07-19, second full cycle)
- **communicationPolicy GET ≠ enforcement reality:** After flipping inbound policy to Allow via `PUT /networking/communicationPolicy`, the policy GET immediately returns `Allow` — but data-plane enforcement continues for 5–8 min. The MPE list/delete endpoint and the workspace DELETE endpoint are data-plane and remain blocked until propagation finishes. Do not trust the policy GET as confirmation; poll the actual data-plane endpoint with retries.
- **Inbound policy flapping during propagation window:** During the ~5–8 min propagation, the same endpoint can return 200 on one call and 403 `RequestDeniedByInboundPolicy` on the next. Retry loops with short sleeps (15–30s) are required for all MPE REST calls during this window.
- **MPE DELETE returns 200 but resource reappears:** One of the SQL MPE deletions returned HTTP 200 yet the MPE was still visible on the next GET. The DELETE is async on Fabric's side; issue it, then poll until the resource is absent rather than trusting the 200.
- **`fabric_workspace` DELETE is data-plane, not management-plane:** Unlike `/networking/communicationPolicy` (which stays publicly reachable even with Deny active), the workspace DELETE API is subject to the inbound policy. Even after the policy GET shows Allow, a Terraform destroy can still get `RequestDeniedByInboundPolicy` on `fabric_workspace` deletion if enforcement hasn't fully propagated. Workaround: manually `DELETE /v1/workspaces/{id}` via REST (polling until accessible), then `terraform state rm fabric_workspace.workspace`, then re-run `terraform destroy -refresh=false` for the remaining capacity + RG.
- **Proven two-phase destroy pattern for Fabric-private:** Phase 1: flip Allow → poll MPE endpoint until accessible → delete all MPEs with retries → state rm MPEs and approve actions → `terraform destroy -refresh=false` (destroys everything except workspace when workspace delete hits the policy). Phase 2: poll until workspace DELETE is accessible → DELETE workspace via REST → state rm workspace → `terraform destroy -refresh=false` (cleans up capacity + RG). Total Fabric-private time: ~20 min.
- **Networking destroy (2026-07-19):** 579 resources, `-refresh=false`, clean. vHub: 10m6s. vWAN: 14s. RG: 15s. Total: ~42 min (plan display is the long pole with 944 state resources).
- **Outcome:** Full teardown clean. All RGs gone, no soft-deleted resources, both state files empty.

### Fabric workspace-policy REST fix (2026-07-17 post-PE-deploy)
- **Bug:** `workspace-policy.tf` had two errors in both provisioners: wrong HTTP method (`PATCH` instead of `PUT`) and missing `/networking/` segment in the URL path (`/v1/workspaces/{id}/communicationPolicy` instead of `/v1/workspaces/{id}/networking/communicationPolicy`). Both errors were present on create-time and destroy-time provisioners.
- **Docs reference:** Microsoft Learn — "Set up and use workspace-level private links", Step 8. Confirmed: `PUT https://api.fabric.microsoft.com/v1/workspaces/{workspaceID}/networking/communicationPolicy`.
- **Fix:** Changed `Method PATCH` → `Method PUT`, added `/networking/` to both URL paths. Tightened create-time `on_failure = continue` → `on_failure = fail`.
- **Silent-failure lesson:** `on_failure = continue` on a critical state-change provisioner is dangerous — it lets Terraform mark the resource as created while the actual API call silently failed. The portal showed "Allow all connections" even though Terraform reported success. **Rule: only use `on_failure = continue` on destroy-time best-effort reverts, never on create/update state-change calls.**
- **Apply outcome:** Targeted apply with `-refresh=false` (full plan blocked because workspace deny-public was already in effect from Ryan's manual flip, causing the Fabric provider to get `RequestDeniedByInboundPolicy` on refresh). `Write-Host` confirmation appeared: `Fabric workspace 574ffc99-6b22-4e19-ba7f-f1f3715c1cf4 inbound public access set to Deny (private-only via workspace PE).` REST call returned 200/204.

### Fabric workspace-policy GET verification (2026-07-17 fix #3)
- **Pattern added:** After the PUT, the create-time provisioner now issues a GET against the same URI and asserts `inbound.publicAccessRules.defaultAction == "Deny"`. A mismatch throws and fails the apply — no silent success.
- **Reachability finding (important):** Feared the GET would be blocked by the very deny-public policy we just set. It was NOT. Microsoft's own docs confirm: "Workspace-level network settings don't restrict the workspaces network communication policy API. This API remains accessible from public networks, even if public access to the workspace is blocked." (See the table in Step 8 of the private links setup article.) The management plane endpoint stays callable from anywhere; only the workspace data-plane paths are restricted.
- **Apply outcome:** Both lines printed — PUT confirmation and `✅ Verified: workspace 574ffc99-6b22-4e19-ba7f-f1f3715c1cf4 inbound defaultAction is Deny.` No errors. Assertion passed. No decision-inbox entry needed (no network-reachability escalation required).

---

## See Also

- **decisions.md** — Architecture decisions, API contracts, design gates
- **history-archive.md** — Detailed early work (March 2026)
- Carl, Mordecai histories for parallel efforts



---

## Cross-Agent Notice: REST API from Design Skill (2026-07-18)

**All agents:** A new skill .squad/skills/rest-api-from-design/SKILL.md has been created to prevent recurring REST implementation errors. This affects anyone writing REST calls in Terraform, GitHub Actions, or shell scripts.

**Trigger:** Apply when implementing a REST call whose method + URL appears in a design doc or vendor docs. Key rule: use on_failure = fail on all state-mutating calls (POST/PUT/PATCH/DELETE); never substitute your own HTTP conventions.

---

## Learnings: Fabric SSMS z{xy} Connection String (2026-07-18)

### SSMS Requires z{xy} Private Link Format — Not an IaC Bug

**What we found:** SSMS failing with `RequestDeniedByInboundPolicy` from `FabricWorkspaceApi.GetAsync` is NOT caused by a wrong communicationPolicy body. The policy (`{"inbound":{"publicAccessRules":{"defaultAction":"Deny"}}}`) is correct and confirmed live via GET. The workspace PE and DNS zone are correctly provisioned (confirmed: five A records in `privatelink.fabric.microsoft.com` pointing to 172.20.80.5).

**Root cause:** SSMS's Fabric-aware pre-flight call to `api.fabric.microsoft.com` (generic public endpoint) goes via public internet even from the private VNet. The deny-public policy blocks it. Workspace PE DNS does NOT cover `api.fabric.microsoft.com` — only workspace-specific FQDNs like `{wsid-no-dashes}.z96.w.api.fabric.microsoft.com`.

**Fix:** Use the private link format of the SQL endpoint connection string in SSMS. Add `.z{xy}.` before `.datawarehouse.` (where xy = first two chars of workspace GUID without dashes). SSMS then routes its metadata call through the workspace-specific FQDN, which resolves to the PE private IP.

**Rule:** For any Fabric workspace with deny-public inbound: `terraform output lakehouse_sql_connection_string_private_link` is the SSMS server name. Never use the regular connection string.

### DNS Zone Architecture (workspace-level PE)

The `privatelink.fabric.microsoft.com` zone gets five A records per workspace PE:
- `{wsid}.z{xy}.w.api` — control plane REST API ✅ (SSMS metadata uses this)
- `{wsid}.z{xy}.blob`, `.c`, `.dfs`, `.onelake` — data plane endpoints ✅
- `.datawarehouse` — **NOT in zone by design.** Fabric's public routing handles `z{xy}.datawarehouse` TDS traffic transparently via PE. No private DNS record needed for SQL/TDS to work.

### Two-Tier Fabric API Architecture

Fabric has two API tiers for workspace-level PE:
1. **Workspace-specific FQDNs** (`{wsid}.z{xy}.*.fabric.microsoft.com`) → private IP via PE. These are covered by private DNS zone. Data and control-plane calls using these FQDNs route privately.
2. **Generic control plane** (`api.fabric.microsoft.com`) → public IP. NOT covered by workspace PE. Always goes via public internet. The deny-public policy blocks calls from public-internet sources. The communicationPolicy management API (GET/PUT `/networking/communicationPolicy`) is deliberately exempt from the deny-public rule, but generic workspace API calls (GET `/v1/workspaces/{id}`) are NOT exempt.

### IaC Changes (2026-07-18)

- **outputs.tf:** Added `lakehouse_sql_connection_string` (public) and `lakehouse_sql_connection_string_private_link` (z{xy} format) outputs for Lakehouse items.
- **README.md:** Added "Connecting via SSMS (inbound modes)" section.
- **fabric-workspace-private-link/SKILL.md:** Added Step 4 documenting z{xy} SSMS requirement.
- **.squad/decisions/inbox/donut-fabric-ssms-z96-connection-string.md:** Full incident writeup.

**Named prior failure:** Fabric workspace-policy.tf bug (commit 4171dc3) — used PATCH instead of PUT, wrong URL path, on_failure=continue masked the error.

For details, see .squad/skills/rest-api-from-design/SKILL.md.

---

## Learnings (2026-07-25 — network_mode + Lakehouse + workspace identity)

### Workspace Identity — native provider support
- **`identity` block on `fabric_workspace` is GA in microsoft/fabric ~> 1.9.** The provider handles `POST /v1/workspaces/{id}/provisionIdentity` internally. No `terraform_data` + REST workaround needed. Exposes `identity.application_id` and `identity.service_principal_id` as computed attributes.
- **Always-on is the right default.** The identity block can't be conditionally included without a `dynamic` block, and the identity itself is free. Option A (always provision) is cleaner than Option B (dynamic block gated on condition). Applied here.
- **provider version matters:** `identity` block requires `~> 1.9`. Pinning to `~> 1.0` would silently skip the attribute on older versions without validation error. Always pin to the minimum version that exposes the feature you're using.

### time_sleep + principal_type = "ServicePrincipal" — Entra propagation pattern
- **New service principal propagation delay is real:** Workspace identity provisioning creates an Entra SP. ARM RBAC can return "PrincipalNotFound" for up to ~60 seconds after creation if the role assignment fires immediately.
- **`time_sleep` (60s) + `principal_type = "ServicePrincipal"` is the correct pattern.** `time_sleep` gates the role assignment. `principal_type = "ServicePrincipal"` tells ARM to skip the Graph lookup that fails during the propagation window and assign directly by object ID. Both are required; neither alone is sufficient.
- **Captured as a reusable skill:** `.squad/skills/aad-identity-propagation/SKILL.md`

### network_mode enum gating pattern
- **`count = local.deploy_X ? 1 : 0` on every conditional resource.** Resources in the same conditional group can safely reference each other with `[0]` indexing — Terraform only evaluates the body when count > 0.
- **`one(resource[*].attribute)` is the safe null-coalescing pattern for locals and check blocks.** Never use `[0]` in unconditionally-evaluated expressions (locals, check blocks, outputs). `one([])` returns `null`; `try(null.attribute, fallback)` catches the null dereference.
- **check blocks can't be gated by count.** The workaround: assertion `condition = !local.deploy_X || <actual check>` short-circuits to `true` in non-applicable modes. Data source inside check block uses null-safe locals for resource_id; if it's a placeholder, the lookup fails gracefully (warning, not error) and the assertion still passes.
- **Networking never gates.** Spoke VNet, subnets, NSG, vHub connection, DNS always deploy. The PE subnet exists but is empty in outbound_only mode — this is harmless.

### ADLS Gen 2 + MPE blob endpoint
- **`is_hns_enabled = true` on `StorageV2` enables hierarchical namespace.** This is a `ForceNew` attribute — can't be added to an existing storage account. Clean-slate lab means no migration needed.
- **MPE `target_subresource_type` stays `"blob"`.** Fabric accesses ADLS Gen 2 via the blob endpoint internally. The `"dfs"` subresource is NOT needed for the MPE. This is validated in Carl's design doc.
- **`is_hns_enabled` is cosmetically breaking for existing state.** Always check for existing deployed resources before adding this. For this lab (torn-down, clean-slate), it's trivial.

### storage.tf refactor pattern
- **Moving resources to a dedicated file for mode clarity is worth doing.** All outbound-gated resources in `storage.tf` make it immediately obvious which resources live or die with `deploy_outbound`. `fabric.tf` becomes readable as "Fabric items only." This pattern should be applied whenever a file grows to host two distinct lifecycle concerns.

---

## Fabric Next Round: Implementation Complete (2026-04-29)

**Partner:** Carl (Architecture Lead)  
**Branch:** squad/fabric-alz-impl  
**Commit:** 82274ff (not yet pushed)  
**Status:** ✅ All 6 design asks delivered

### Implementation Summary

**All changes per Carl's approved design:**

1. ✅ Lakehouse — `fabric_lakehouse` resource gated on `workspace_content_mode == "lakehouse"`
2. ✅ network_mode enum — Three-way conditional (`inbound_only`, `outbound_only`, `inbound_and_outbound`)
3. ✅ Workspace identity — Always-on `identity { type = "SystemAssigned" }` block
4. ✅ ADLS Gen 2 upgrade — `is_hns_enabled = true` on storage account (gated on `deploy_outbound`)
5. ✅ Identity propagation delay — `time_sleep` (60s) + `principal_type = "ServicePrincipal"` pattern
6. ✅ Provider bumps — `microsoft/fabric ~> 1.9`, `hashicorp/time ~> 0.12`

### Files Changed

| File | Action | Key Changes |
|---|---|---|
| `config.tf` | Modified | Provider bumps (fabric, time) |
| `variables.tf` | Modified | Added `network_mode`, removed `restrict_workspace_public_access`, updated `workspace_content_mode` validation |
| `locals.tf` | Modified | Added `deploy_inbound`, `deploy_outbound` |
| `fabric.tf` | Modified | Added identity block, lakehouse resource, gated PE resources on `deploy_inbound` |
| `storage.tf` | **Created** | All outbound resources (KV, KV PE, storage, SQL, role assignment, time_sleep) |
| `mpe.tf` | Modified | Count gates on all MPE resources, safe null-access patterns, conditional check blocks |
| `workspace-policy.tf` | Modified | Gating via `deploy_inbound`, triggers_replace uses `var.network_mode` |
| `outputs.tf` | Modified | All conditional outputs guarded; added identity outputs |
| `README.md` | Modified | New Variables/Outputs tables, Network Mode section, workspace identity docs |
| `terraform.tfvars.example` | Modified | Added `network_mode` example |

### Key Implementation Patterns

1. **Safe null-access in locals & check blocks:** `one(resource[*].attribute)` + `try()` for count=0 resources
2. **Check block assertions:** `condition = !local.deploy_X || <actual_check>` short-circuit pattern
3. **[0] indexing inside co-conditioned resources:** Safe when both referencing and referenced resources have same `count` condition
4. **Pre-existing staged changes:** `main.tf` comment rename and stale check block removal included (related to module evolution)

### Notes

- **purge-soft-deleted.ps1 TODO:** Script doesn't exist in module; TODO placed in fabric.tf as a comment instead
- **depends_on list syntax:** Used list reference (`[azurerm_private_endpoint.pe_fabric_workspace]` not `[0]`) — valid Terraform, auto-null when count=0
- **Ready for merge:** All infrastructure tests should pass; feature gates tested locally

### Cross-Agent Learning Shared

- Safe patterns for conditional resources when count gates are involved
- Identity propagation timing critical for RBAC assignments on freshly-provisioned service principals

---

## End-to-End Deploy: Networking LZ + Fabric-private ALZ (2026-04-29)

**Branch:** squad/fabric-alz-impl  
**Mode:** network_mode=inbound_and_outbound, workspace_content_mode=lakehouse  
**Suffix:** 2679  
**Outcome:** ✅ Full deploy succeeded after two code bugs found and fixed in-flight

### Deploy Summary

| Phase | Resources | Time | Notes |
|---|---|---|---|
| Networking LZ | 944 in state | ~15 min Azure ops | dns_policy_dns_vnet_link tainted once (transient ISE) — re-apply fixed |
| Fabric-private | 28 managed | ~8 min total | Two bugs hit; multiple re-apply cycles needed |

**Key outputs:**
- Networking RG: `rg-net00-sece-3051`, Firewall IP: `172.30.0.132`, DNS inbound: `172.20.16.4`
- Fabric RG: `rg-fabric00-sece-2679`, Workspace ID: `9627b1aa-93c7-4d3d-8a17-7d00182c2dce`
- Workspace PE IP: `172.20.80.5`, Lakehouse: `Lakehouse_2679` (ID: `aa2f9be8`)
- All 3 MPEs Approved/Succeeded. Workspace PE Succeeded. RBAC confirmed.

### Bug 1: Fabric Lakehouse display_name rejects hyphens — FIXED

**Symptom:** `fabric_lakehouse` apply fails with `InvalidInput` — "DisplayName is Invalid for ArtifactType."  
**Root cause:** Fabric item display_name only allows letters, numbers, underscores. Hyphens are valid for workspace names (looser rules) but NOT for Fabric items (lakehouses, etc.).  
**Fix:** `fabric.tf` line ~51 — changed `"lakehouse-${random_string.unique.result}"` → `"Lakehouse_${random_string.unique.result}"`.  
**Rule going forward:** Fabric item display names: use letters/numbers/underscores only. Workspace names: hyphens OK.

### Bug 2: workspace_communication_policy race condition — FIXED

**Symptom:** After first partial apply, re-apply of remaining resources (`fabric_lakehouse`, `mpe_keyvault`) fails with `RequestDeniedByInboundPolicy`. Even after manually setting communicationPolicy to Allow via REST, re-apply still fails — Fabric auto-reverts to Deny within ~5–10 seconds once the workspace PE is Connected.  
**Root cause:** `workspace_communication_policy` had `depends_on = [azurerm_private_endpoint.pe_fabric_workspace]` only. In a parallel apply, workspace PE can complete before lakehouse/MPEs → Terraform fires the deny-public policy while those resources are still being created → all subsequent Fabric API calls blocked from public internet.  
**Fix:** `workspace-policy.tf` — added `fabric_lakehouse.lab_lakehouse`, `fabric_workspace_managed_private_endpoint.mpe_storage`, `mpe_sql`, `mpe_keyvault` to `depends_on` of `terraform_data.workspace_communication_policy`. Deny-public now fires only AFTER all Fabric items are successfully created.  
**Platform behavior (important):** Once a workspace PE is Connected/Approved, the Fabric platform auto-enforces deny-public for workspace management APIs regardless of the communicationPolicy setting. Manual Allow via REST reverts to Deny within ~5 seconds. This is by-design platform enforcement — no workaround from public internet; the ordering fix is the only solution.

### Recovery Procedure (for future reference when stuck in deny-public state)

1. Delete orphaned Fabric items via REST (`DELETE /v1/workspaces/{id}/items/{itemId}`, `DELETE /v1/workspaces/{id}/managedPrivateEndpoints/{mpeId}`)
2. Taint `terraform_data.workspace_communication_policy[0]` in state
3. Targeted destroy: `azurerm_private_endpoint.pe_fabric_workspace[0]`, `azapi_resource.fabric_private_link_service[0]`, `terraform_data.workspace_communication_policy[0]`
4. Apply with fixed `depends_on` — Fabric items + PE all create in parallel; communication_policy runs last

### Provider Gaps — No Import Support

- `fabric_workspace_managed_private_endpoint`: `terraform import` returns "Resource Import Not Implemented." Recovery: delete via REST + re-create.
- `fabric_lakehouse`: Import blocked when workspace deny-public is active (`RequestDeniedByInboundPolicy`). Even with brief Allow window, import initialization (>10s) exceeds the ~5s revert window. Recovery: delete via REST + re-create.

### Timing Reference (inbound_and_outbound + lakehouse, Sweden Central)

| Resource | Time |
|---|---|
| `azapi_resource.fabric_private_link_service` | ~17s |
| `azurerm_private_endpoint.pe_fabric_workspace` | ~1m13s |
| `fabric_lakehouse.lab_lakehouse` | ~1m22s |
| `fabric_workspace_managed_private_endpoint.mpe_keyvault` | ~4–5 min |
| Full Fabric-private apply (clean) | ~8 min |

---

## Fabric-private + Networking Full Teardown (2026-04-29, live validation)

### communicationPolicy GET Behavior — Critical Finding

After flipping inbound policy from Deny to Allow via `PUT /v1/workspaces/{id}/networking/communicationPolicy`:
- **Management-plane GET returns Allow immediately:** The policy GET shows `{"inbound":{"publicAccessRules":{"defaultAction":"Allow"}}}` within seconds
- **Data-plane enforcement lags 5–8 minutes:** MPE list endpoint, workspace DELETE endpoint, and other data-plane paths remain blocked by `RequestDeniedByInboundPolicy` for 5–8 minutes after the Allow flip
- **Consequence:** Do NOT use policy GET as a gate to proceed with MPE operations. Poll the actual data-plane endpoint (e.g., GET on an MPE URL) with retries until it succeeds. The policy GET creates a false sense of readiness.

### Inbound Policy Flapping During Propagation Window

During the 5–8 minute propagation after Allow flip:
- Same MPE endpoint can return HTTP 200 on one call and 403 `RequestDeniedByInboundPolicy` on the next
- Observed: Sequential GET calls returning inconsistent results within 30 seconds
- **Solution:** Implement retry loops with 15–30s sleeps on all REST calls (GET, DELETE) to MPE endpoints and workspace endpoints during this window

### MPE DELETE Returns 200 but Resource Persists

One SQL Managed Private Endpoint deletion:
- `DELETE /v1/workspaces/{id}/managedPrivateEndpoints/{mpeId}` returned HTTP 200
- Immediate subsequent GET still showed the MPE in the list
- After ~60s polling, the MPE finally disappeared
- **Pattern:** Fabric MPE DELETE is asynchronous. HTTP 200 means the request was accepted, not that deletion is complete. Always poll until the resource is absent before proceeding to workspace deletion.

### fabric_workspace DELETE is Data-Plane (Separate from Policy Management-Plane)

Key discovery:
- `/networking/communicationPolicy` is management-plane and remains callable from public networks even with deny-public active (Microsoft's deliberate exception for configuration)
- `DELETE /v1/workspaces/{id}` for workspace deletion is **data-plane** and is subject to the inbound policy restrictions
- Even after policy GET shows Allow and MPEs are deleted, workspace DELETE can still return `RequestDeniedByInboundPolicy` if enforcement propagation hasn't fully completed (~15 min possible)
- **Workaround:** If `terraform destroy` fails with `RequestDeniedByInboundPolicy` on workspace, manually issue `DELETE /v1/workspaces/{id}` via PowerShell/curl with retry loop (test reachability first), delete via REST when accessible, then `terraform state rm fabric_workspace.workspace`, then re-run `terraform destroy -refresh=false` for capacity + RG

### Two-Phase Destroy Pattern (Proven)

**Phase 1 — MPE and pre-workspace cleanup:**
1. Flip inbound policy Allow → `PUT /v1/workspaces/{id}/networking/communicationPolicy` with `{"inbound":{"publicAccessRules":{"defaultAction":"Allow"}}}`
2. Poll MPE GET endpoint with 15–30s retry sleep until HTTP 200 (5–8 min typical)
3. LIST and DELETE all MPEs with retry loops (`terraform destroy` will fail if MPEs remain)
4. `terraform state rm` for the MPE resources
5. `terraform destroy -refresh=false` (destroys all resources except workspace; workspace will fail if it hasn't been deleted yet)

**Phase 2 — Workspace cleanup:**
1. Poll workspace DELETE endpoint (`DELETE /v1/workspaces/{id}`) until successful (test with GET first; workspace may take additional 5–15 min beyond MPE propagation)
2. When DELETE returns 200, `terraform state rm fabric_workspace.workspace`
3. `terraform destroy -refresh=false` (destroys capacity + RG)

**Total time:** ~20–30 minutes for Fabric-private + Networking full teardown (vs. ~8 min apply).

### Networking Destroy Patterns

- **Fabric-private 579 Azure resources:** vHub ~10 min, vWAN ~15s, RG ~15s. Total: ~42 min with `-refresh=false`. (Long pole is plan display, not Azure operations.)
- **No orphans after full two-phase teardown:** All RGs deleted, no soft-deleted KVs remaining. State files clean.

---

