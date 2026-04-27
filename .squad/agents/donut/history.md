# Donut — Infra Developer (she/her, female cat)

- **Owner:** Ryan Krokson
- **Project:** Azure IaC demo/lab environments — Terraform modules for Azure vWAN, AI Foundry, networking
- **Stack:** Terraform (azurerm >= 4.0, azapi >= 2.0, random ~> 3.5), PowerShell, Azure CLI
- **Structure:** Three root modules — Networking (foundation), Foundry-byoVnet, Foundry-managedVnet linked via terraform_remote_state
- **Created:** 2026-03-27

## Recent Work (2026-04-27)

- **2026-04-27 (kv-softdelete-and-workspace-default):** (1) Set `soft_delete_retention_days = 7` on Networking/keyvault.tf kv00 (was defaulting to 90 days). Fabric-private already at 7 days — no change. (2) Flipped `restrict_workspace_public_access` default in Fabric-private/variables.tf: `false` → `true` (private-by-default aligns with module's PE-always design). (3) Updated Fabric-private/README.md variables table, Security Posture section, and destroy procedure; updated root README.md with KV soft-delete callout. Terraform fmt + validate clean in both modules. (4) Processed two user directives from Ryan (lab KV minimums, workspace private default) and merged into decisions.md. Orchestration and session logs written. Decision documented.

- **2026-04-27 (fabric-kv-purge-protection):** Disabled purge_protection_enabled on azurerm_key_vault.fabric_kv in Fabric-private/fabric.tf (true → false). Updated README destroy procedure. terraform fmt + validate clean. Rationale: Lab module (Fabric-private) is redeployed often; purge protection enforces 7-day waits between destroy/redeploy, adding friction without benefit in non-prod environment. Soft delete retained for accidental deletion recovery. Decision documented.

- **2026-04-27 (networking-deploy):** Deployed Networking platform LZ to Azure from branch squad/fabric-alz-impl. Config: Region 0 only (swedencentral/sece), firewall00=true, private_dns00=true, vhub01=false. Plan: 579 resources to create. First apply completed 578/579 in ~36 min but hit Azure InternalServerError on dns_policy_dns_vnet_link (circuit breaker — "exceeded maximum processing count"). Re-plan showed 1 add/1 destroy; re-apply succeeded in ~15s. Total wall clock ~37 min. No vHub errors this run. New Fabric ALZ outputs confirmed: `dns_zone_fabric_id` = privatelink.fabric.microsoft.com, `dns_zone_sql_id` = privatelink.database.windows.net. RG: rg-net00-sece-7768, suffix: 7768.

- **2026-04-26 (fabric-alz-step2-module):** Built complete Fabric-byoVnet/ application landing zone module (13 files). Follows Foundry-byoVnet pattern: spoke VNet (Block 5 — 172.20.80.0/20), single PE subnet (/24) with explicit NSG (M4 compliance), vHub connection, DNS resolver policy link. Key resources: Fabric Capacity (F2), Workspace, workspace-level PE, lab Storage + SQL Server, diagnostic settings to platform LAW. **MPE auto-approval pattern (M2):** Three azapi_resource_action resources filter PE connections by lower(properties.privateEndpoint.id) matching MPE ID (strict filtering for shared KV), with post-apply check {} assertions. NSG rules: explicit inbound 443 (VirtualNetwork) for Fabric PLS/Storage/KV, inbound 1433 for SQL, explicit deny-all. All security mitigations (M1–M4) integrated. Committed on branch squad/fabric-alz-impl.

- **2026-04-26 (fabric-alz-parallel-steps-2-3-complete):** [ORCHESTRATION] Steps 2+3 complete on squad/fabric-alz-impl. Mordecai handled docs (Block 5 claim + README refresh) in parallel. Full design → implementation → documentation. Orchestration and session logs recorded. Ready for Ryan review and merge.

## Work Archive (2026-04-06 to 2026-04-25)

**ContainerApps-byoVnet ALZ (April 6–8):** Implemented 11-file module, fixed bugs (external_enabled, LAW consolidation), added three-mode deployment (none/hello-world/mcp-toolbox).

**Deploy/Destroy Cycles (April 8–15):** 4 full environment tests: 630 resources (~63 min deploy), confirmed ACA clean teardown (~16 min), identified legionservicelink SAL release timing (5-10 min post-purge), vHub connection delete timeout workaround (retry after 60 min), vHub InternalServerError recovery (REST API delete + re-create).

**Infrastructure Updates (April 16–25):** Added Bastion IP-Connect/tunneling features. Documented Decision #18 (Bastion works with routing intent). Coordinated design gates M1–M2 with Carl (Block Public Internet Access trade-off, MPE lookup spec). SystemAI security review: 4 medium findings (M1–M4), 6 advisory. Created branch squad/fabric-alz-impl, added Networking DNS zone outputs for Fabric ALZ. Ready for module implementation.

## Key Learnings

- **vHub InternalServerError:** Resource exists in Failed provisioning state. Correct fix: 	erraform state rm, REST API DELETE from Azure, then re-apply.
- **Foundry teardown:** legionservicelink SAL persists 5-10 min after Cognitive Services soft-delete purge. RG-delete + 	erraform state rm resolves.
- **ACA:** Clean and predictable teardown (~16 min), no soft-delete issues.
- **ACR cloud build:** Ideal for labs — builds server-side, no Docker Desktop needed.
- **App LZ pattern:** Consolidate shared platform resources (LAW, DNS zones, KV) instead of duplicating.
- **Fabric MPEs:** Always land in Pending. Use zapi_resource_list + strict ID filter + zapi_resource_action PATCH + check {} assertion.
- **Fabric provider schema:** principal = { id, type } (nested block, not separate args), 	arget_private_link_resource_id (not ..._service_id). Always verify with 	erraform providers schema -json.
- **PE subnet NSG:** Explicit allow rules (443 for HTTPS, 1433 for SQL) from VirtualNetwork + explicit deny-all. No NSG on Fabric delegation subnets (capacity is tenant-managed).
- **DNS resolver policy VNet link:** Can hit Azure InternalServerError with circuit breaker ("exceeded maximum processing count") during initial deploy. Transient — re-apply resolves it (destroy + recreate).

## See Also

- **decisions.md** — Architecture decisions and team direction
- **history-archive.md** — Detailed early work (March 2026)
- Carl, Mordecai, Katia, SystemAI histories for parallel work

- **Fabric-private rename (2026-07-14):** `git mv Fabric-byoVnet Fabric-private` preserves history. Internal `Fabric-byoVnet` strings in mpe.tf/config.tf/main.tf/fabric.tf/configure-fabric-tenant-settings.ps1 are independent of the folder rename — bulk-replace via PowerShell.
- **LZ-local KV pattern:** Put workspace-target KV in the LZ RG (RBAC-only, public access off, purge-protected, 7-day soft delete) + conventional `azurerm_private_endpoint` on pe_subnet using Networking's `dns_zone_vaultcore_id`. Repoint MPE 3 (target_private_link_resource_id, azapi_resource_list parent_id, azapi_resource_action resource_id, check resource_id) to `azurerm_key_vault.fabric_kv.id`. Eliminates orphaned PE connections on the shared Networking KV at destroy. Drop the `key_vault_present` check.
- **Workspace communication policy via local-exec:** Fabric data-plane `PATCH /v1/workspaces/{id}/communicationPolicy` cannot be reached via azapi (not ARM). Use `terraform_data` + `local-exec pwsh` with `az account get-access-token --resource https://api.fabric.microsoft.com`. Gate with feature flag (default off), `triggers_replace = [workspace.id, flag]`, destroy-time best-effort revert to Allow (`on_failure = continue`), depends_on workspace PE. Drift invisible to TF.
- **MPE repoint mechanics:** Auto-approval pattern is target-agnostic — only swap target_private_link_resource_id, azapi_resource_list parent_id, azapi_resource_action resource_id prefix, and check block resource_id. Strict ID-filter local (`lower(properties.privateEndpoint.id) == lower(mpe.id)`) is unchanged.
