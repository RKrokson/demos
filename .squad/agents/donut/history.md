# Donut — Infra Developer (she/her, female cat)

- **Owner:** Ryan Krokson
- **Project:** Azure IaC demo/lab environments — Terraform modules for Azure vWAN, AI Foundry, networking
- **Stack:** Terraform (azurerm >= 4.0, azapi >= 2.0, random ~> 3.5), PowerShell, Azure CLI
- **Structure:** Three root modules — Networking (foundation), Foundry-byoVnet, Foundry-managedVnet linked via terraform_remote_state
- **Created:** 2026-03-27

## Recent Work (2026-04-06 onwards)

- **2026-04-06 (containerapps-byovnet-module):** Built new `ContainerApps-byoVnet/` application landing zone module (11 files). Follows Foundry-byoVnet pattern: spoke VNet (Block 4 — 172.20.64.0/20), ACA delegated subnet (/27, no NSG), PE subnet (with NSG), vHub connection, DNS resolver policy link. Key resources: ACA Environment (internal LB, Consumption + optional D4 workload profile), Premium ACR with private endpoint, hello-world sample app, private DNS zone for ACA environment.

- **2026-04-06 (containerapps-bugfix):** Fixed two bugs. (1) Changed `external_enabled = false` to `true` in app.tf — for internal ACA environments, `external_enabled` controls VNet reachability, not public internet. (2) Removed duplicate LAW — use platform's LAW via `log_analytics_workspace_id` output instead. App LZs consolidate shared resources from platform layer.

- **2026-04-07 (full-environment-teardown-3):** Tore down all three deployed environments cleanly. ACA teardown is fast (~16 min). Foundry legionservicelink on subnets is the consistent pain point — workaround: RG-delete + state cleanup. Networking destroys cleanly in ~45 min. Total wall time: ~75 min.

- **2026-04-08 (three-mode-app-deployment):** Implemented three-mode `app_mode` variable for ContainerApps-byoVnet. Modes: `none` (environment only), `hello-world` (MCR quickstart), `mcp-toolbox` (MCP Toolkit server from GitHub via cloud build). Two separate container app resources (cleaner than dynamic blocks for different configs). ACR `public_network_access_enabled` conditional (true for mcp-toolbox for `az acr build`). Docker build completes in 37-43 seconds via cloud build.

- **2026-04-08 (full-environment-deploy-4):** Fresh deploy of all three modules — clean state, zero errors. 630 resources in ~63 min wall time. **Networking:** 578 resources (suffix 6913). **Foundry-byoVnet:** 32 resources (suffix 7916). **ContainerApps-byoVnet:** 20 resources (suffix 5740). Cleanest deploy to date.

- **2026-04-08 (full-environment-teardown-4):** Tore down all three modules (suffixes 3514, 7916, 6913). ACA destroys cleanly in 16 min. Foundry hit expected legionservicelink issue — RG-delete + state cleanup needed. Networking 578 resources in 40 min. Total: ~627 resources destroyed in ~75 min wall time.

- **2026-04-08 (networking-only-deploy-5):** Deployed Networking LZ only (suffix 3784). Hit transient Azure DNS resolver policy circuit breaker on first apply (1 failure). Retry succeeded — all 578 resources created cleanly. DNS policy link failures are transient; simple retry resolves.

- **2026-04-10 (donut-networking-deploy):** Deployed Networking platform LZ successfully — 579 resources in Sweden Central, suffix 6786. Azure Firewall at 172.30.0.132, DNS resolver at 172.20.16.4. Zero errors. azurerm bumped to 4.68.0. Region 1 off. Ready for Foundry + ContainerApps modules.

- **2026-04-10 (networking-destroy-redeploy-7):** Destroy + redeploy cycle to test VM extension `depends_on` fix for `ipconfig /renew` ordering. **Destroy:** First attempt destroyed 571/579 — 2 vHub connections (`vhub00-to-shared00-sece`, `vhub00-to-dns00-sece`) timed out after 60 min (nil HTTP response / context deadline exceeded). Retry destroyed remaining 8 cleanly. **Redeploy:** 579 resources created, suffix `2883`, zero errors. RG `rg-net00-sece-2883`, Firewall IP `172.30.0.132`, Key Vault `kv00-sece-2883`. Total cycle: ~110 min. **New learning:** vHub connection deletes can hit 60-min timeout — connections are already deleted server-side, simple retry resolves.

- **2026-04-14 (networking-foundry-deploy-8):** Sequential deploy of Networking + Foundry-byoVnet. **Networking:** 579 resources, suffix `8575`, region swedencentral. Hit vHub InternalServerError during initial apply — Azure created the resource but polling failed. Imported the vHub but it was in Failed/None routing state. Had to delete via REST API and let Terraform recreate cleanly. Total Networking wall time: ~50 min (including recovery). Firewall IP `172.30.0.132`, DNS resolver `172.20.16.4`, KV `kv00-sece-8575`. **Foundry-byoVnet:** 32 resources, suffix `8999`, zero errors, ~25 min. AI Foundry `aifoundry8999`, project `project8999`, Cosmos DB + AI Search + Storage all deployed. **New learning:** When vHub creation polling fails with InternalServerError, don't import — the resource is in a Failed provisioning state. Delete it from Azure (REST API DELETE) and let Terraform recreate it fresh.

- **2026-04-14 (full-environment-teardown-9):** Sequential teardown of Foundry-byoVnet then Networking (suffixes 8999, 8575). **Foundry-byoVnet:** Hit expected legionservicelink SAL on `ai-foundry-subnet-sece`. Terraform destroyed 28/32 resources; VNet/subnet/RG stuck. Purged soft-deleted Cognitive Services account `aifoundry8999`. SAL took ~10 min to release after purge. VNet delete via `az network vnet delete` succeeded after waiting. State cleaned with `terraform state rm`. Total Foundry teardown: ~30 min. **Networking:** 579 resources destroyed cleanly, zero errors, ~45 min. vHub delete took 10 min, vWAN 11s. Total wall time: ~75 min. **Confirmed:** legionservicelink SAL release timing is consistently 5-10 min after Cognitive Services purge.

- **2026-04-14 (team-update-orchestration):** Parallel agent orchestration session. Deployed Networking LZ (579 resources, suffix 8575) + Foundry-byoVnet (32 resources, suffix 8999) with one vHub transient recovery. Carl completed Bastion + routing intent validation checklist for Microsoft PG (8 categories, 60+ CLI commands). Orchestration logs written. Team decisions merged (Decision #18: Bastion works with vWAN routing intent despite docs). Status: Both modules stable for downstream operations. Foundry environment ready for Bastion validation testing.

- **2026-04-15 (donut-destroy):** Executed planned destruction of Foundry-byoVnet (32 resources, suffix 8999) then Networking LZ (579 resources, suffix 8575). Foundry teardown encountered expected legionservicelink SAL blocking issue on AI Foundry subnet — resolved via Cognitive Services soft-delete purge + ~10 min SAL wait. Networking destroyed cleanly in ~45 min. Both Terraform states emptied. Subscription returned to clean state. Orchestration and session logs recorded.

- **2026-04-16 (bastion-config-update):** Implemented Decision #19 — added `ip_connect_enabled = true` and `tunneling_enabled = true` to `azurerm_bastion_host.bastion` resource in Networking/modules/region-hub/main.tf. Inline comment documents Standard SKU requirement. Terraform validate and fmt both pass clean. Changes are backward compatible (in-place Bastion update on next apply). Enables cross-VNet and native client testing scenarios per Decision #18 (routing intent validation). Coordinated with Mordecai (docs). Orchestration log written.

- **2026-04-26 (fabric-alz-design-approved):** [TEAM UPDATE] Carl completed Microsoft Fabric Application Landing Zone architecture design (Decision #19 in decisions.md). Module name: `Fabric-byoVnet` (IP Block 5: 172.20.80.0/20). 21 resources (azurerm + azapi + microsoft/fabric + null/external). Key design points: workspace-level PE, 3 Managed Private Endpoints with Terraform auto-approval, 2 new DNS zones (fabric.microsoft.com, database.windows.net) to be added to Networking, hybrid admin pattern (group OID > UPN list > current user fallback), 3-layer prereq validation. All 8 open design questions resolved. Design is locked and approved by Ryan — ready for your implementation. Next steps: (1) Networking precursor PR (add 2 DNS zones + 2 outputs), (2) Fabric-byoVnet module PR (all files per Decision #19 §1), (3) docs/ip-addressing.md update (Block 5 claim).

  - **2026-04-25 (fabric-alz-systemai-security-review):** SystemAI completed pre-implementation security review (Verdict: APPROVE WITH CONDITIONS). No critical findings. 4 medium findings (M1, M2, M3, M4) and 6 low/informational findings (L1–L6). **YOUR IMPL GATES (no blockers, implement in PR):** M3 = mark KV PE connection cleanup mandatory (not optional) in destroy docs; M4 = define explicit NSG rules for PE subnet (inbound on ports 443, 1433 from VirtualNetwork, reference Foundry-byoVnet as template). **Carl's design gates (he must resolve before handoff):** M1 = decide "Block Public Internet Access" (document omission OR add optional flag), M2 = specify MPE connection lookup strategy (filter by resource ID, not state). L1–L6 are advisory. Review merged into decisions.md with full content and summary table.

  - **2026-04-25 (fabric-alz-m1m2-gates-resolved):** Carl completed design gate resolutions. **M1 — Block Public Internet Access:** Documented intentional omission in §4 (lab context requires browser access; public path coexists with optional private PE). Ryan's call honored. **M2 — MPE Connection Lookup:** Specified filter strategy in §11 Q2: azapi_resource_action must filter privateEndpointConnections by `properties.privateEndpoint.id == MPE_resource_id`, never "first Pending" or name pattern. Added post-apply `check {}` block asserting `connection_status == "Approved"`. Silent Pending is the failure mode; explicit filter + assertion mitigates lookup collision on shared KV. Design fully approved and locked. Ready for your implementation. Orchestration and session logs recorded.

## Key Learnings

- **vHub InternalServerError recovery:** When vHub creation fails with InternalServerError and the polling times out, the resource exists in Azure but in a Failed/None routing state. Importing it into state doesn't help — the router never provisions. Correct fix: remove from state (`terraform state rm`), delete from Azure via REST API, then re-apply. The fresh creation succeeds and the router provisions correctly.

- **Foundry teardown gotchas:**legionservicelink on AI Foundry subnets can persist after destroy. Reliable workaround: RG-delete via CLI + state cleanup with `terraform state rm`. Purging soft-deleted Cognitive Services accounts doesn't always release the link immediately.

- **ACA teardown:** Clean and predictable (~16 min), no soft-delete concerns, no legionservicelink issues. ACA infrastructure is well-behaved.

- **ACR cloud build:** `az acr build` is ideal for labs — builds server-side in Azure, no Docker Desktop needed. Requires ACR public network access (acceptable for lab/non-prod).

- **App LZ pattern:** App landing zones should reference shared platform resources (LAW, DNS zones, KV) instead of creating duplicates. Consolidation avoids drift and simplifies teardown.

- **DNS zone ownership:** `privatelink.azurecr.io` is created by Networking's AVM module. App LZs should reference it via new `dns_zone_acr_id` output instead of creating their own zone.

- **ACA subnet delegation:** `Microsoft.App/environments` — requires explicit subnet delegation. ACA manages internal networking; no NSG needed on delegated subnet.

- **Firewall DNS proxy:** vHub firewall private IP is at `virtual_hub[0].private_ip_address`, not `ip_configuration[0]` (that's VNet-mode). DNS routing decision lives in platform layer — app LZs consume platform's `dns_server_ip00` output.

- **Bastion Standard SKU features:** `ip_connect_enabled` and `tunneling_enabled` require Standard SKU. They enable cross-VNet connect-by-IP and native client support (`az network bastion tunnel/rdp/ssh`). Set unconditionally since default SKU is Standard and these are lab environments.

## See Also

- **decisions.md** — Team approval decisions and architecture direction
- **history-archive.md** — Detailed early implementation work (March-August 2026)
- Carl, Katia, Mordecai, SystemAI histories for parallel work
