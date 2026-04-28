# Donut — Infra Developer (she/her, female cat)

- **Owner:** Ryan Krokson
- **Project:** Azure IaC demo/lab environments — Terraform modules for Azure vWAN, AI Foundry, networking
- **Stack:** Terraform (azurerm >= 4.0, azapi >= 2.0, random ~> 3.5), PowerShell, Azure CLI
- **Structure:** Three root modules — Networking (foundation), Foundry-byoVnet/Fabric-private, Foundry-managedVnet linked via terraform_remote_state
- **Created:** 2026-03-27

## Most Recent Work (2026-07-17 workspace-pe-deploy)

- **2026-07-17 (fabric-workspace-pe-deploy):** Implemented workspace-level private endpoint for Fabric-private ALZ. Reversed incorrect prior decision that workspace-level PE was not a valid ARM type. Added `azapi_resource.fabric_private_link_service` (Microsoft.Fabric/privateLinkServicesForFabric@2024-06-01, location: global) and `azurerm_private_endpoint.pe_fabric_workspace` (subresource: workspace, subnet: pe_subnet, DNS: privatelink.fabric.microsoft.com). Updated `workspace-policy.tf` depends_on from `fabric_workspace.workspace` → `azurerm_private_endpoint.pe_fabric_workspace`. Added 3 outputs: workspace_private_link_service_id, workspace_private_endpoint_id, workspace_private_endpoint_ip. Files changed: fabric.tf, workspace-policy.tf, outputs.tf, README.md. Plan: 3 added (PLS + PE + approve_mpe_storage replacement), 1 changed (storage account pre-existing drift), 1 destroyed (pre-existing drift). Apply: success. workspace_private_endpoint_ip = 172.20.80.5. Communication policy propagation can take up to 30 min — expected.

## Cross-Agent Coordination (2026-07-17)

**Partner:** Carl (Architect)  
**Session:** Fabric workspace-level PE fix deploy  
**Outcome:** ✅ ADR design validated; deployment successful

Carl designed the workspace-level PE fix (ADR in `.squad/decisions/inbox/carl-fabric-workspace-pe-fix.md`). Key insights from design:
- `Microsoft.Fabric/privateLinkServicesForFabric` IS valid (workspace-scoped PE anchor)
- azapi + azurerm cross-provider reference works (PE → PLS resource ID)
- azapi requires `schema_validation_enabled = false` for bundled schema gap
- Workspace PE depends on `workspace-policy.tf` now firing deny-public-access AFTER private path is live (not before)
- Tenant-level PE is OUT OF SCOPE per Ryan directive

All inbox files merged into decisions.md; superseded 2026-04-28 entry marked with full resolution context. Note: The prior learning "Workspace-level Fabric PE is not a real resource" (line 37 below) is now SUPERSEDED — it was based on the wrong ARM resource type. The workspace-level PE pattern is real and deployed.

## Learnings (2026-07-17 workspace-pe-deploy)

- **Microsoft.Fabric/privateLinkServicesForFabric IS a valid ARM resource type:** The prior decision was wrong. This is the workspace-level PE anchor type (API 2024-06-01, location: global). It is completely distinct from tenant-level `Microsoft.PowerBI/privateLinkServicesForPowerBI`. CORRECTION: update all history and code reflecting the old "not a valid ARM type" note.

- **azapi `schema_validation_enabled = false` required for Microsoft.Fabric/privateLinkServicesForFabric:** The azapi provider's bundled schema does not yet include this resource type. Without `schema_validation_enabled = false`, azapi rejects the resource with `resource type Microsoft.Fabric/privateLinkServicesForFabric can't be found`. Adding the flag bypasses local schema validation and lets ARM handle it directly. This is the correct workaround for any new ARM resource type not yet in the azapi schema bundle.

- **azurerm PE → azapi PLS cross-provider reference works correctly:** `private_connection_resource_id = azapi_resource.fabric_private_link_service.id` in `azurerm_private_endpoint` is accepted by the azurerm provider without issue. The azapi resource ID is an ARM resource path — the same format azurerm expects.

- **Workspace PE private IP (172.20.80.5):** First IP in the /24 pe_subnet. PE creation took 56s. Normal timing.

- **Pre-existing drift (approve_mpe_storage):** Storage account had a `private_link_access` block (Microsoft.Security/datascanners/StorageDataScanner) added by Azure Defender that wasn't in Terraform config. This caused `approve_mpe_storage` to replace as a side effect. Not caused by PE changes — pre-existing drift. Safe to let Terraform reconcile on apply.



- **2026-07-17 (fabric-private-first-deploy):** Full live deployment of Networking + Fabric-private ALZ from scratch. Networking: 579 resources, Sweden Central, firewall + private DNS enabled — two-phase apply (first run created 402 resources then hit azapi 403s; root cause was cross-tenant auth; fix = `az account set --subscription b6b5dea5-...` → switches to ryan@krokson.xyz in personal tenant). Total: 579 resources. Fabric-private: caught and fixed 5 code bugs during live apply (see Learnings below). Final state: 26 resources deployed, all 3 MPEs approved (storage/SQL/KV), workspace communication policy set. Fabric workspace ID: `574ffc99-6b22-4e19-ba7f-f1f3715c1cf4`, suffix `3886`.

## Learnings (2026-07-17 first deploy)

- **Cross-tenant azapi auth (CRITICAL):** `ME-rykrokso-01` (ID: `b6b5dea5-...`) is in Ryan's personal tenant (`16248402-...`, `ryan@krokson.xyz`). The azapi 2.x provider uses the DEFAULT az CLI account's tenant for token acquisition. If the CLI default is `rykrokso@microsoft.com` (corporate, tenant `72f988bf-...`), azapi acquires a corporate token → 403 on all GET operations in the personal tenant. Fix: **always run `az account set --subscription b6b5dea5-81d3-4e4a-85f3-b05266fc6f89` before any Terraform commands** to switch the default CLI account to `ryan@krokson.xyz`. Setting `ARM_TENANT_ID` alone does NOT work (corporate account not registered in personal tenant → AADSTS90072). The azurerm provider is more lenient and creates resources without GET-first checks, which is why some resources succeeded and others failed in the partial apply.

- **Fabric capacity UUID vs ARM ID:** `azurerm_fabric_capacity.id` returns ARM format (`/subscriptions/.../Microsoft.Fabric/capacities/{name}`). `fabric_workspace.capacity_id` requires the Fabric-side UUID (`xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`). The ARM API does NOT expose this UUID. Fix: use `data "fabric_capacity" "this" { display_name = azurerm_fabric_capacity.fabric_capacity.name }` — the display_name in the Fabric API matches the ARM resource name exactly.

- **Diagnostic settings not supported for Fabric capacities:** `azurerm_monitor_diagnostic_setting` targeting `microsoft.fabric/capacities` returns 400 `ResourceTypeNotSupported`. Remove this resource entirely — no workaround exists.

- **Workspace-level Fabric PE is not a real resource:** `Microsoft.Fabric/privateLinkServicesForFabric/{workspace-uuid}` is NOT a valid ARM resource type. Azure returns `InvalidResourceId`. Fabric Private Links are **tenant-scoped** only via `Microsoft.PowerBI/privateLinkServicesForPowerBI` (configured in Fabric Admin portal, not Terraform). Remove any workspace-level PE targeting that path. Inbound access control is done via `workspace_communication_policy`, not a PE.

- **MPE PE connection filter must use endswith, not == Fabric UUID:** `fabric_workspace_managed_private_endpoint.id` is a Fabric UUID (e.g., `2958f6a9-...`). `conn.properties.privateEndpoint.id` from the ARM PE connections list is an ARM resource path in Fabric's managed subscription (e.g., `.../Microsoft.Network/privateEndpoints/{workspace_id}.{mpe_name}`). These can NEVER be equal. Correct filter: `endswith(lower(conn.properties.privateEndpoint.id), lower("${workspace_id}.${mpe_name}"))`.

- **Fabric workspace creator auto-assigned Admin:** When `fabric_workspace` is created, the creating user is automatically assigned the Admin role. `fabric_workspace_role_assignment` for the same principal will fail with `PrincipalAlreadyHasWorkspaceRolePermissions`. Remove the explicit role assignment — the creator already has Admin.

- **workspace_communication_policy requires tenant-level Fabric Private Links:** `PATCH /v1/workspaces/{id}/communicationPolicy` returns `EntityNotFound` unless Fabric Private Links are enabled at the tenant level in the Fabric Admin portal. For lab environments without that configuration, add `on_failure = continue` to the provisioner so it degrades gracefully rather than failing the apply.

- **MPE creation is slow:** Each `fabric_workspace_managed_private_endpoint` takes 2–3 min to create. With 3 MPEs, total MPE creation time is ~9 min. Normal; do not assume failure if no output for 3 min.

- **Fabric MPE UnknownError is transient:** The Fabric API sometimes returns `UnknownError` for MPE creation. This is a transient server-side error — retry the apply. MPEs that previously failed with UnknownError succeed on retry with no other changes needed.

## Most Recent Work (2026-07-16)

- **2026-07-16 (full-env-teardown-pre-fabric):** Full environment teardown for clean Fabric testing slate. State discovery: Foundry-byoVnet had 2 resources (terraform_remote_state + random_string only — no Azure resources ever deployed), Foundry-managedVnet 0 resources, Fabric-private no state file, ContainerApps-byoVnet 0 resources, Networking 944 resources. Executed `terraform destroy -auto-approve` on Foundry-byoVnet (1 resource destroyed, instant), checked for soft-deleted AI Foundry resources (none found), then destroyed Networking (579 resources destroyed, 44.3 min). vHub took 10m45s. State refresh phase alone took ~30 min due to 181 modtm_module_source outbound calls to GitHub — normal for this module pattern, just slow. Post-destroy: no orphan resource groups matching our naming pattern. 5 pre-existing RGs remain (Default-ActivityLogAlerts, NetworkWatcherRG, rg-shared00-krok, rg-arc00-krok, McapsGovernance). Environment is clean. **Key timing insight:** modtm refresh phase = ~30 min of the 44 min total. Actual Azure destroy phase ≈ 14 min.

## Learnings (2026-07-16 teardown)

- **modtm state refresh is the long pole:** 181 modtm_module_source data sources each make outbound GitHub API calls during plan/refresh. With 181 of them, this takes ~30 min before any Azure resource deletion starts. Terraform process shows >100 CPU during this phase — it IS working, just not producing visible output. Do not kill the process.
- **Networking total time:** 44 min (30 min modtm refresh + 14 min Azure destroy). Previous session recorded ~80 min cycles; 44 min is the bare destroy time with one region and firewall enabled.
- **Foundry-byoVnet partial state:** If Foundry was never applied past the random_string/remote_state init, `terraform destroy` only removes those 2 local resources — instant and safe. No SAL/PE cleanup needed.
- **vHub destroy:** 10m45s — normal. No InternalServerError this cycle.
- **No soft-deleted Cognitive Services:** Environment was clean going in (Foundry was never deployed to Azure this cycle).
- **Orphan RG check:** Use `az group list --query "[?starts_with(name, 'rg-')].name" -o tsv`. Our pattern is `rg-{type}-{region_abbr}-{suffix}`. Pre-existing `rg-shared00-krok` and `rg-arc00-krok` (no region abbr/suffix) are not ours — do not delete.

## Most Recent Work (2026-07-15)

- **2026-07-15 (fabric-setting-name-mapping):** Identified and corrected all four wrong `settingName` values in configure-fabric-tenant-settings.ps1. Research method: cross-referenced live API's 161-name response against Microsoft Learn (tenant-settings-index, service-admin-portal-developer, service-admin-portal-advanced-networking, fabric-switch). Findings: (1) `EnableFabric` → does not exist; "Microsoft Fabric" is a portal section header, not an API setting — removed from script. (2) `UsersCanCreateFabricItems` → `FabricGAWorkloads` (the actual "Users can create Fabric items" toggle = the Fabric admin switch). (3) `WorkspaceLevelPrivateEndpointSettings` → `WorkspaceBlockInboundAccess` (confirmed by Advanced Networking docs). (4) `ServicePrincipalsCanCallFabricPublicAPIs` → `ServicePrincipalAccessGlobalAPIs` (confirmed by Developer settings docs). Script now has 3 entries (not 4 — "Microsoft Fabric" and "Users can create Fabric items" were duplicates of the same API setting). Updated SKILL.md with verified mappings + wrong-name history. Decision drop written.

- **2026-07-15 (fabric-script-api-fix):** Fixed critical bug in configure-fabric-tenant-settings.ps1. Root causes: (1) Script called per-setting GET in loop — API has only LIST endpoint. (2) Script issued PATCH, correct verb is POST + /update suffix. (3) No setting-name validation. (4) Error messages opaque (no status code/body). Fixed all four issues: replaced with single LIST + cache pattern, corrected verb/URL, added validation with clear warnings, improved error output (status, body, URL). Decision documented: Fabric Admin Tenant-Settings API Contract. Skill created: .squad/skills/fabric-admin-api/SKILL.md. Script uncommitted per workflow.

## Career Summary

**Infra Module Development (March–April 2026):** Built Networking platform LZ foundation (vWAN, vHubs, firewall, DNS resolver). Implemented two Foundry ALZs (byoVnet, managedVnet). Deployed + teardown validation (630 resources, ~80 min cycles). Discovered and documented Azure transient errors (InternalServerError on DNS policy, vHub provisioning), workarounds (retry, state rm + REST DELETE).

**ContainerApps ALZ (April 2026):** Designed + built ContainerApps-byoVnet (11 files, three app modes: none/hello-world/mcp-toolbox). Fixed external_enabled bug, consolidated LAW for cost savings.

**Fabric ALZ Milestone (April–July 2026):** Designed Fabric-byoVnet as simplified ALZ (single PE subnet, workspace-local KV, MPE auto-approval pattern). Implemented module (13 files, M1–M4 security mitigations). Coordinated 3-gate design review (Block Public Internet Access, MPE ID filtering, PE NSG rules). Renamed folder Fabric-byoVnet → Fabric-private (git mv + bulk string update). Documented API contract fix for admin tenant-settings PowerShell script. **First live deployment completed 2026-07-17** (26 resources, 3 MPEs approved).

## Architectural Patterns Established

- **Multi-region naming:** {resource}-{region_abbr}-{random_suffix} (e.g., kv00-sece-8357)
- **Per-LZ soft-delete + 7-day retention:** Lab-friendly KV lifecycle (purge protection off)
- **MPE auto-approval:** azapi_resource_list + `endswith` PE ID filter + azapi_resource_action PUT + check {} (filter uses `endswith(lower(pe.id), lower("{workspace_id}.{mpe_name}"))` — NOT equality with Fabric UUID)
- **Workspace-local KV:** Eliminates orphaned PE on destroy; RBAC-only security
- **DNS resolver policy VNet link retry:** Transient InternalServerError — safe to retry
- **Fabric capacity UUID lookup:** `data "fabric_capacity" { display_name = arm_resource.name }` — ARM API doesn't expose Fabric UUID; Fabric API does

## Key Learnings

- Fabric Admin API: LIST-only read (no per-setting GET), POST /update for writes, Entra role + tenant provisioning gates mandatory
- azapi cross-tenant auth: azapi 2.x uses DEFAULT az CLI account's tenant — always `az account set --subscription {target-sub}` before terraform commands when target sub is in a different tenant than your corporate account
- Fabric capacity: use `data "fabric_capacity"` data source to get UUID, never use azurerm_fabric_capacity.id (ARM format, incompatible)
- Fabric capacities don't support diagnostic settings: remove azurerm_monitor_diagnostic_setting
- Workspace-level Fabric PE doesn't exist: tenant-only via PowerBI PLS; remove any pe targeting Microsoft.Fabric/privateLinkServicesForFabric
- Fabric workspace creator auto-Admin: don't create explicit role assignment for the creating user
- workspace_communication_policy: needs tenant-level Private Links; use on_failure = continue
- vHub InternalServerError: terraform state rm + REST DELETE + re-apply
- legionservicelink SAL: 5–10 min hold post-purge; always wait + sync RG delete
- PE NSG: Explicit allow (443/1433 from VirtualNetwork) + explicit deny-all

## See Also

- **decisions.md** — Architecture decisions, API contracts, design gates
- **history-archive.md** — Detailed early work (March 2026)
- Mordecai, Carl, Katia, SystemAI histories for parallel efforts


- **2026-07-16 (full-env-teardown-pre-fabric):** Full environment teardown for clean Fabric testing slate. State discovery: Foundry-byoVnet had 2 resources (terraform_remote_state + random_string only — no Azure resources ever deployed), Foundry-managedVnet 0 resources, Fabric-private no state file, ContainerApps-byoVnet 0 resources, Networking 944 resources. Executed `terraform destroy -auto-approve` on Foundry-byoVnet (1 resource destroyed, instant), checked for soft-deleted AI Foundry resources (none found), then destroyed Networking (579 resources destroyed, 44.3 min). vHub took 10m45s. State refresh phase alone took ~30 min due to 181 modtm_module_source outbound calls to GitHub — normal for this module pattern, just slow. Post-destroy: no orphan resource groups matching our naming pattern. 5 pre-existing RGs remain (Default-ActivityLogAlerts, NetworkWatcherRG, rg-shared00-krok, rg-arc00-krok, McapsGovernance). Environment is clean. **Key timing insight:** modtm refresh phase = ~30 min of the 44 min total. Actual Azure destroy phase ≈ 14 min.

## Learnings (2026-07-16 teardown)

- **modtm state refresh is the long pole:** 181 modtm_module_source data sources each make outbound GitHub API calls during plan/refresh. With 181 of them, this takes ~30 min before any Azure resource deletion starts. Terraform process shows >100 CPU during this phase — it IS working, just not producing visible output. Do not kill the process.
- **Networking total time:** 44 min (30 min modtm refresh + 14 min Azure destroy). Previous session recorded ~80 min cycles; 44 min is the bare destroy time with one region and firewall enabled.
- **Foundry-byoVnet partial state:** If Foundry was never applied past the random_string/remote_state init, `terraform destroy` only removes those 2 local resources — instant and safe. No SAL/PE cleanup needed.
- **vHub destroy:** 10m45s — normal. No InternalServerError this cycle.
- **No soft-deleted Cognitive Services:** Environment was clean going in (Foundry was never deployed to Azure this cycle).
- **Orphan RG check:** Use `az group list --query "[?starts_with(name, 'rg-')].name" -o tsv`. Our pattern is `rg-{type}-{region_abbr}-{suffix}`. Pre-existing `rg-shared00-krok` and `rg-arc00-krok` (no region abbr/suffix) are not ours — do not delete.

## Most Recent Work (2026-07-15)

- **2026-07-15 (fabric-setting-name-mapping):** Identified and corrected all four wrong `settingName` values in configure-fabric-tenant-settings.ps1. Research method: cross-referenced live API's 161-name response against Microsoft Learn (tenant-settings-index, service-admin-portal-developer, service-admin-portal-advanced-networking, fabric-switch). Findings: (1) `EnableFabric` → does not exist; "Microsoft Fabric" is a portal section header, not an API setting — removed from script. (2) `UsersCanCreateFabricItems` → `FabricGAWorkloads` (the actual "Users can create Fabric items" toggle = the Fabric admin switch). (3) `WorkspaceLevelPrivateEndpointSettings` → `WorkspaceBlockInboundAccess` (confirmed by Advanced Networking docs). (4) `ServicePrincipalsCanCallFabricPublicAPIs` → `ServicePrincipalAccessGlobalAPIs` (confirmed by Developer settings docs). Script now has 3 entries (not 4 — "Microsoft Fabric" and "Users can create Fabric items" were duplicates of the same API setting). Updated SKILL.md with verified mappings + wrong-name history. Decision drop written.

- **2026-07-15 (fabric-script-api-fix):** Fixed critical bug in configure-fabric-tenant-settings.ps1. Root causes: (1) Script called per-setting GET in loop — API has only LIST endpoint. (2) Script issued PATCH, correct verb is POST + /update suffix. (3) No setting-name validation. (4) Error messages opaque (no status code/body). Fixed all four issues: replaced with single LIST + cache pattern, corrected verb/URL, added validation with clear warnings, improved error output (status, body, URL). Decision documented: Fabric Admin Tenant-Settings API Contract. Skill created: .squad/skills/fabric-admin-api/SKILL.md. Script uncommitted per workflow.

## Career Summary

**Infra Module Development (March–April 2026):** Built Networking platform LZ foundation (vWAN, vHubs, firewall, DNS resolver). Implemented two Foundry ALZs (byoVnet, managedVnet). Deployed + teardown validation (630 resources, ~80 min cycles). Discovered and documented Azure transient errors (InternalServerError on DNS policy, vHub provisioning), workarounds (retry, state rm + REST DELETE).

**ContainerApps ALZ (April 2026):** Designed + built ContainerApps-byoVnet (11 files, three app modes: none/hello-world/mcp-toolbox). Fixed external_enabled bug, consolidated LAW for cost savings.

**Fabric ALZ Milestone (April–July 2026):** Designed Fabric-byoVnet as simplified ALZ (single PE subnet, workspace-local KV, MPE auto-approval pattern). Implemented module (13 files, M1–M4 security mitigations). Coordinated 3-gate design review (Block Public Internet Access, MPE ID filtering, PE NSG rules). Renamed folder Fabric-byoVnet → Fabric-private (git mv + bulk string update). Documented API contract fix for admin tenant-settings PowerShell script.

## Architectural Patterns Established

- **Multi-region naming:** {resource}-{region_abbr}-{random_suffix} (e.g., kv00-sece-8357)
- **Per-LZ soft-delete + 7-day retention:** Lab-friendly KV lifecycle (purge protection off)
- **MPE auto-approval:** azapi_resource_list + strict ID filter + azapi_resource_action PATCH + check {}
- **Workspace-local KV:** Eliminates orphaned PE on destroy; RBAC-only security
- **DNS resolver policy VNet link retry:** Transient InternalServerError — safe to retry

## Key Learnings

- Fabric Admin API: LIST-only read (no per-setting GET), POST /update for writes, Entra role + tenant provisioning gates mandatory
- vHub InternalServerError: terraform state rm + REST DELETE + re-apply
- legionservicelink SAL: 5–10 min hold post-purge; always wait + sync RG delete
- PE NSG: Explicit allow (443/1433 from VirtualNetwork) + explicit deny-all

## See Also

- **decisions.md** — Architecture decisions, API contracts, design gates
- **history-archive.md** — Detailed early work (March 2026)
- Mordecai, Carl, Katia, SystemAI histories for parallel efforts
