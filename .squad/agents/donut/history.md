# Donut — Infra Developer (she/her, female cat) — SUMMARIZED (2026-04-29)

- **Owner:** Ryan Krokson
- **Project:** Azure IaC demo/lab environments — Terraform modules for Azure vWAN, AI Foundry, networking
- **Stack:** Terraform (azurerm >= 4.0, azapi >= 2.0, random ~> 3.5), PowerShell, Azure CLI
- **Structure:** Three root modules — Networking (foundation), Foundry-byoVnet/Fabric-private, Foundry-managedVnet linked via terraform_remote_state
- **Created:** 2026-03-27

---

## Summary

Donut is the infrastructure developer driving module implementation and live deployment. Started with Networking platform (vWAN, firewall, DNS). Shipped full Fabric-private ALZ (July 2026). **Major achievements:** (1) Deployed workspace-level private endpoint for Fabric (correcting prior wrong decision), (2) Mastered Fabric API nuances (UUID mapping, MPE async operations, data-plane propagation timing), (3) Established operational teardown pattern for deny-public-access cleanup. Specialized in Azure provider quirks (azapi auth, MSI provisioning), Terraform patterns (multi-module coordination), and operational troubleshooting (transient errors, async API polling).

---

## Most Recent Work (2026-04-30 Fabric-private + Networking Teardown — Background Agent donut-10)

- **Task:** Full teardown of Fabric-private (deny-public active) + Networking (firewall + DNS, two regions)
- **Duration:** ~3.2 hours wall clock (~70 min Azure-side work)
- **Mode:** Background agent (claude-sonnet-4.6)
- **Outcome:** SUCCESS. Zero orphans. All RGs deleted. Both state files at 0 resources. Lab fully destroyed.
- **Status:** Agent manually stopped post-disconnect/reconnect to allow Scribe post-run documentation + commit.
- **Key Incident:** During Networking destroy (~45 min mark, 944 → 46 resources), transient client-side DNS resolution failure (`dial tcp: lookup management.azure.com: no such host`). Root cause: network connectivity blip (client-side only). Azure had already accepted delete operations. Resolution: verified connectivity, re-ran `terraform destroy -refresh=false -auto-approve`. Terraform resumed from 46 resources, destroyed all remaining (exit code 0).
- **Fabric notes:** Two-phase pattern executed cleanly. SQL MPE needed 3 DELETE attempts (expected). Workspace DELETE was immediately successful on Phase 2 (policy had fully propagated during the 10-min KV soft-delete in Phase 1). Policy propagation: ~4:40 (14×20s polls).
- **Pattern established:** Any `dial tcp: lookup ... no such host` during destroy = client connectivity issue. Do not perform manual state surgery. Verify connectivity and re-run.

## Most Recent Work Archive: 2026-04-29 Fabric-private + Networking Teardown

- **Task:** Full teardown of Fabric-private + Networking with deny-public-access inbound policy active
- **Duration:** ~20–30 min (two-phase pattern with manual MPE/workspace REST deletions)
- **Outcome:** Zero orphans. All RGs deleted, no soft-deleted resources. Both state files clean.
- **Key Discovery:** communicationPolicy GET lags data-plane enforcement by 5–8 min; established two-phase destroy pattern with retry loops.

---

## Key Learnings — Recent Sessions

### Networking Destroy — Client DNS Blip (2026-07-25)
- **Symptom:** `terraform destroy` exits with code 1 mid-run with `dial tcp: lookup management.azure.com: no such host` on Private DNS zone async-delete status polls. Resources partially destroyed (e.g. 944 → 46 in state).
- **Cause:** Transient client-side DNS/network connectivity loss during long-running destroy. Has nothing to do with Azure state.
- **Fix:** Verify `management.azure.com` is reachable, then immediately re-run `terraform destroy -refresh=false -auto-approve`. Terraform picks up from remaining state — no manual state surgery needed.
- **Key check:** After connectivity restored, count state resources before retrying so you know what to expect.

### Fabric Two-Phase Destroy — Workspace DELETE timing observation (2026-07-25)
- The KV soft-delete (10+ min) in Phase 1 doubles as an inadvertent wait for workspace data-plane propagation. By the time Phase 1 finishes, the workspace DELETE call in Phase 2 succeeds on the first attempt. No separate polling loop needed for workspace DELETE when Phase 1 runs in full.

### Fabric PE Pattern (2026-07-17)
- **Microsoft.Fabric/privateLinkServicesForFabric IS valid:** Workspace-level PE anchor type (API 2024-06-01, global). Distinct from tenant-level `Microsoft.PowerBI/privateLinkServicesForPowerBI`.
- **azapi schema_validation_enabled = false:** Required workaround for new ARM types not in bundled schema. Lets ARM handle it directly.
- **azurerm PE → azapi PLS cross-provider:** Works seamlessly. azapi resource ID is ARM path format.

### Fabric SSMS z{xy} Connection Strings (2026-07-18)
- **SSMS metadata routing:** SSMS pre-TDS call to public `api.fabric.microsoft.com` gets blocked by deny-public policy. Solution: insert `.z{xy}.` before `.datawarehouse.` in connection string (where xy = first 2 chars of workspace GUID without dashes). SSMS recognizes prefix, routes through PE FQDN, resolves to PE private IP 172.20.80.5.
- **DNS gap by design:** No private DNS A record for `.z{xy}.datawarehouse`. Fabric routing recognizes z{xy} prefix and transparently routes TDS via PE. Expected.
- **Rule:** For any workspace with deny-public inbound, always use z{xy} format for client connections. Regular format fails from private networks.

### Workspace Identity — Native Provider Support (2026-07-25)
- **`identity` block on `fabric_workspace` is GA in microsoft/fabric ~> 1.9.** Provider handles `POST /v1/workspaces/{id}/provisionIdentity` internally. Always-on is the right default.
- **Entra SP propagation delay:** New service principal creation can trigger "PrincipalNotFound" on RBAC for ~60s. Use `time_sleep` + retry before assigning roles.

### Fabric workspace-policy REST fix (2026-07-17)
- **Bug:** Wrong HTTP method (`PATCH` instead of `PUT`) and missing `/networking/` segment in URL. Both provisioners affected.
- **Lesson:** Never use `on_failure = continue` on state-changing calls; only reserve for destroy-time best-effort. It masks API errors.
- **Pattern:** After PUT, issue GET and assert desired state was applied.

---

## Architectural Patterns Established

- **Multi-region naming:** `{resource}-{region_abbr}-{random_suffix}` (e.g., kv00-sece-8357)
- **Per-LZ soft-delete + 7-day retention:** Lab-friendly KV lifecycle (purge protection off)
- **MPE auto-approval:** azapi_resource_list + strict ID filter + azapi_resource_action PUT
- **Workspace-local KV:** Eliminates orphaned PE on destroy
- **DNS resolver policy VNet link retry:** Transient InternalServerError — safe to retry

---

## Full Lab Teardown Patterns

### Two-Phase Destroy for Fabric-private (2026-04-29, proven)

**Phase 1 — MPE cleanup:**
1. Flip inbound policy Allow via `PUT /networking/communicationPolicy`
2. Poll MPE GET endpoint with 15–30s retry sleep until 200 (5–8 min typical)
3. LIST and DELETE all MPEs with retry loops
4. `terraform state rm` for MPE resources
5. `terraform destroy -refresh=false` (workspace will fail; expected)

**Phase 2 — Workspace cleanup:**
1. Poll `DELETE /v1/workspaces/{id}` until accessible
2. When 200, `terraform state rm fabric_workspace.workspace`
3. `terraform destroy -refresh=false` (capacity + RG)

**Total time:** ~20–30 min.

### Critical Findings (2026-04-29 teardown, live validation)

**communicationPolicy GET Behavior:**
- Management-plane GET returns Allow immediately after flip
- Data-plane enforcement lags 5–8 minutes (MPE endpoints, workspace DELETE remain blocked)
- **Do not use policy GET as gate.** Poll actual data-plane endpoint with retries.

**Inbound Policy Flapping:**
- Same endpoint can return 200 then 403 on consecutive calls during propagation window
- Retry loops with 15–30s sleeps required for all REST calls (GET, DELETE) during window

**MPE DELETE Returns 200 but Resource Persists:**
- HTTP 200 means accepted, not complete. DELETE is async on Fabric side.
- Poll until resource absent before proceeding to workspace deletion.

**`fabric_workspace` DELETE is Data-Plane (Separate from Policy):**
- Unlike `/networking/communicationPolicy` (callable from public), workspace DELETE is subject to inbound policy
- Can remain blocked up to ~15 min after Allow flip
- Workaround: manually DELETE via REST (polling), `terraform state rm`, re-run `terraform destroy -refresh=false`

### Networking Destroy (579 resources, `-refresh=false`)
- vHub: ~10 min (10m6s observed)
- vWAN + RG: ~30s
- Total: ~42 min (plan display is the long pole with 944 state resources)
- No orphans, all RGs deleted.

---

## Networking Quirks

- **modtm refresh is the long pole:** 181 modtm_module_source data sources → ~30 min GitHub calls. Use `-refresh=false` for teardown.
- **Transient InternalServerError on DNS policy VNet link:** Safe to retry (did retry, worked).
- **Orphan soft-deleted KVs:** Purge takes 5–10 min each (sequential, no batching).

---

## See Also

- **decisions.md** — Architecture decisions, API contracts, two-phase destroy pattern, comment fixes
- **lz-teardown skill** — Detailed runbook with code examples (`.squad/skills/lz-teardown/SKILL.md`)
- **history-archive-2026-07-17.md** — Earlier work (March–July 2026 foundation builds)
- Carl, Mordecai, Systemai histories for parallel efforts

---

## Archived Sections (full details in history-archive-2026-07-17.md)

- Fabric Admin API (LIST-only, POST /update, setting name corrections)
- Early deploy patterns (azapi auth, Fabric capacity UUID, MPE filtering)
- Detailed 2026-07-17 workspace-policy GET verification

---

**Last updated:** 2026-04-29 — Full teardown + gotchas captured
