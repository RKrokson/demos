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

### Teardown (2026-07-16)
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

**Named prior failure:** Fabric workspace-policy.tf bug (commit 4171dc3) — used PATCH instead of PUT, wrong URL path, on_failure=continue masked the error.

For details, see .squad/skills/rest-api-from-design/SKILL.md.
