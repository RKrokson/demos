# Decision: Enable Bastion IP-Connect and Native Client by Default

**Author:** Donut (Infra Dev)
**Date:** 2026-07-22
**Status:** Implemented

## Context

Azure Bastion Standard SKU supports two opt-in features that are useful for lab environments:
- `ip_connect_enabled` — connect to VMs by private IP address (not just resource ID). Enables cross-VNet Bastion scenarios.
- `tunneling_enabled` — enables native client support via `az network bastion tunnel`, `az network bastion rdp`, and `az network bastion ssh` CLI commands.

Both features require Standard SKU (not available on Basic or Developer). Our default SKU is already Standard.

## Decision

Set both `ip_connect_enabled = true` and `tunneling_enabled = true` unconditionally on the `azurerm_bastion_host.bastion` resource in `Networking/modules/region-hub/main.tf`. A comment notes the Standard SKU requirement.

No conditional gating on the SKU variable — these are lab environments, and the default is Standard. If someone overrides to Basic or Developer, Terraform will surface a clear Azure API error at apply time.

## Impact

- Backward compatible for existing deployments (Terraform will update the Bastion host in-place on next apply).
- Enables Ryan's cross-VNet and native client testing scenarios per Decision #18 (Bastion + vWAN routing intent validation).
- No new variables or outputs needed.

## Files Changed

- `Networking/modules/region-hub/main.tf` — added `ip_connect_enabled` and `tunneling_enabled` to bastion resource


---




---

# Deploy Decision: Full Platform + Foundry-byoVnet (2026-04-24)

**Author:** Donut (Infra Dev)
**Requested by:** Ryan Krokson

## Decisions Made

### 1. Reused existing terraform.tfvars (no changes needed)
Ryan's existing Networking tfvars already had `add_firewall00 = true` and `add_private_dns00 = true` with single region (`create_vhub01 = false`). No modifications required.

### 2. DNS policy circuit breaker — retry, not workaround
The DNS resolver policy VNet link hit the known InternalServerError circuit breaker during initial apply. Chose simple retry (re-plan + re-apply) rather than any workaround. This is now the 3rd occurrence of this transient — it always resolves on retry within seconds.

### 3. Foundry-byoVnet tfvars unchanged
Used existing tfvars with Block 2 addressing (172.20.32.0/20) and GPT-5.4 model. No modifications needed for this deploy.

## Deployment Summary

| Module | Resources | Suffix | Wall Time |
|--------|-----------|--------|-----------|
| Networking | 579 | 8357 | ~35 min |
| Foundry-byoVnet | 32 | 0918 | ~22 min |
| **Total** | **611** | — | **~57 min** |

## Key Endpoints

- Firewall IP: 172.30.0.132
- DNS Resolver: 172.20.16.4
- Key Vault: kv00-sece-8357
- AI Foundry: aifoundry0918
- Project: project0918

---

# Teardown Note: 2026-04-24 — Foundry + Networking Teardown #11

**Author:** Donut
**Date:** 2026-04-24

## Summary

Tore down Foundry-byoVnet (suffix 0918, 33 resources) and Networking (suffix 8357, 579 resources). Total ~611 resources destroyed in ~80 min.

## Notable: Async RG Delete Silently Fails During SAL Hold

During the Foundry teardown, the `legionservicelink` SAL blocked subnet deletion as expected. After purging the soft-deleted Cognitive Services account and waiting 5 minutes, I used `az group delete --no-wait` to delete the RG. The command returned success, but 2 minutes later the RG was still in "Deleting" state, and after 5 minutes it reverted to "Succeeded" — the delete failed silently because the SAL was still active.

The reliable approach after SAL release: delete the VNet directly with `az network vnet delete`, then delete the empty RG synchronously with `az group delete --yes` (no `--no-wait`). This avoids the silent failure.

## Updated Workaround Sequence

1. `terraform destroy` — let it fail on SAL
2. Purge soft-deleted Cognitive Services: `az cognitiveservices account purge`
3. Wait 8-10 minutes for SAL release (5 min was not enough this time)
4. Delete VNet directly: `az network vnet delete`
5. Delete empty RG synchronously: `az group delete --yes`
6. Verify: `az group show` returns `ResourceGroupNotFound`
7. Clean state: `terraform state rm` for RG, subnet, VNet

## Verification

All target RGs (`rg-ai00-sece-0918`, `rg-net00-sece-8357`, `rg-kv00-sece-8357`) confirmed deleted. No soft-deleted accounts remain. Both Terraform states emptied.

---

# Decision: Remove ip_connect_enabled from Bastion Host

**Author:** Donut (Infra Dev)  
**Date:** 2026-04-25  
**Status:** Implemented  
**Branch:** `fix/bastion-remove-ip-connect`  

## Context

During team validation of Azure Bastion in a vWAN spoke with routing intent enabled (Decision #18), it was confirmed that Bastion itself works correctly — RDP and SSH connections succeed. However, the `ip_connect_enabled` feature (IP-based connection / connect-by-IP) does **not** work when vWAN routing intent is active.

## Root Cause

`ip_connect_enabled = true` enables Bastion's IP-based connection mode, which allows connecting to arbitrary target IPs (cross-VNet). This feature relies on a data path that conflicts with vWAN routing intent's forced `0.0.0.0/0` route propagation injected into spoke VNet connections. The route interception causes IP-connect traffic to be misrouted through the firewall in a way Bastion cannot complete.

Bastion's standard RDP/SSH flow (connecting to VMs by resource ID) does NOT use this path and works correctly.

## Decision

Remove `ip_connect_enabled` from `azurerm_bastion_host.bastion` in `Networking/modules/region-hub/main.tf`. By omitting the argument, the azurerm provider applies its default (`false`), disabling IP-connect without requiring an explicit `false` value in source.

`tunneling_enabled` is retained — it enables native client support (`az network bastion tunnel/rdp/ssh`) and is not affected by vWAN routing intent.

## Files Changed

- `Networking/modules/region-hub/main.tf` — removed `ip_connect_enabled = true` line, updated inline comment

## Impact

- Bastion Standard SKU continues to work in vWAN spoke with routing intent enabled
- IP-connect feature (`az network bastion connect --target-ip-address`) will not function in this topology — this is expected and correct
- `tunneling_enabled` and all standard Bastion flows unaffected
- No variable changes — `ip_connect_enabled` was hardcoded, not exposed as a module variable
- Backward compatible in-place update on next `terraform apply`

## Related

- Decision #18: Bastion Works with vWAN Routing Intent (secured hub)
- Donut history entry: `2026-04-16 (bastion-config-update)` (original addition)
- Donut history learning: `Bastion IP-connect incompatible with vWAN routing intent`

---

# Bastion Documentation Update — IP-Connect Removal

**Agent:** Mordecai (Docs)  
**Date:** 2026-04-25  
**Branch:** `fix/bastion-remove-ip-connect`  
**Commit:** Update Bastion docs — remove IP-connect, switch examples to resource-id

## Summary

Updated Networking README Notes section to align with Donut's code changes (Decision #20):
1. **Bastion section** — Removed `ip_connect_enabled` since it conflicts with vWAN routing intent. Native client RDP/SSH still works via resource ID.
2. **VM DNS gotcha section** — Deleted entirely. DNS renewal is solved in code via `vm_post_deploy` extension (runs `ipconfig /renew` after DNS servers configured). No longer a gotcha worth documenting.

## Changes

### Bastion section (lines 88–109)

1. **Intro paragraph (line 88):**
   - Removed: "IP-based connections (`ip_connect_enabled`) and native client support (`tunneling_enabled`) both enabled"
   - Added: Clear statement that only `tunneling_enabled` is active; explained IP-connect removal reason

2. **RDP example (line 95):**
   - Changed: `--target-ip-address <vm-private-ip>`
   - To: `--target-resource-id <vm-resource-id>`
   - Added: Example resource ID format for clarity

3. **SSH example (line 105):**
   - Changed: `--target-ip-address <vm-private-ip>`
   - To: `--target-resource-id <vm-resource-id>`

4. **Cross-VNet paragraph (line 107):**
   - Removed: Entire paragraph describing IP-connect cross-VNet access
   - Added: "Cross-VNet Bastion access is not supported in this vWAN topology."

### VM DNS gotcha section (line 113)

1. **Deleted entirely:**
   - Old: Paragraph explaining DHCP lease behavior and suggesting manual fixes
   - Why: DNS renewal is auto-handled by platform's `vm_post_deploy` extension. No longer a gotcha worth documenting as a Note.

## Rationale

### Bastion removal
- Donut's code change removed `ip_connect_enabled` because it forces the vWAN routing intent's 0.0.0.0/0 route into the spoke, which misroutes IP-connect data through the firewall.
- Resource-ID-based access remains functional and unaffected.
- Cross-VNet Bastion (which relied on IP-connect) is no longer a feature in this topology.
- Documentation must reflect current infrastructure state.

### VM DNS gotcha removal
- Previously documented as a "gotcha" requiring manual intervention.
- Platform's `vm_post_deploy` (CustomScriptExtension) already solves it: runs `ipconfig /renew` after DNS servers are configured (via `depends_on` ordering in region-hub/main.tf line 438).
- VMs now come up with correct DNS automatically — no longer a gotcha for documentation.

## Verification

- README Bastion section now matches actual module capabilities
- Examples use correct flag (`--target-resource-id`) that works with vWAN
- No CLI commands reference removed feature
- VM DNS paragraph removed — issue solved in code, no longer documentation concern
- Tone matches team style: concise, engineer-focused, no AI vocabulary

---

# Decision: Disable Purge Protection on Fabric-private Key Vault

**Date:** 2026-07-14  
**Author:** Donut  
**Requested by:** Ryan  
**Module:** `Fabric-private/`

## Decision

Set `purge_protection_enabled = false` on `azurerm_key_vault.fabric_kv` in `Fabric-private/fabric.tf`.

## Rationale

This is a lab module that Ryan deploys and tears down repeatedly. Purge protection on a Key Vault enforces a minimum 7-day wait (or requires `az keyvault purge`) between destroy and re-deploy of the same-named resource. That friction has no benefit in a non-production lab environment.

Soft delete is retained (`soft_delete_retention_days = 7`) as it is an Azure-enforced minimum and provides a recovery window for accidental deletion during a session.

## Trade-offs

- **Accepted risk:** Deleted secrets are recoverable for 7 days via soft-delete but can be immediately purged by any authorized operator. Acceptable for a lab with no production data.
- **Naming collision:** The KV name includes a `random_string` suffix, so collisions across destroy/redeploy cycles are unlikely but not impossible. README updated to note `az keyvault purge` as a targeted fix if a collision occurs.

## Alternatives Considered

- Keep purge protection, document `az keyvault purge` as mandatory step — rejected as unnecessary friction for a lab lifecycle.
- Import soft-deleted KV on redeploy — rejected as operationally complex for no benefit.

---

# User Directive: Lab KV Protection Minimums

**Date:** 2026-04-27  
**By:** Ryan (via Copilot)  
**Scope:** All Key Vaults in this repository

## Directive

Minimize Key Vault protections in this lab environment:
- Disable purge protection everywhere
- Set soft-delete retention to the Azure-mandated minimum (7 days; soft delete itself cannot be disabled)

## Rationale

The friction of `az keyvault purge` and 90-day waits is not justified in a lab environment. This directive prioritizes rapid destroy/redeploy cycles over recovery protection.

---

# User Directive: Fabric Workspace Private-Only by Default

**Date:** 2026-04-27  
**By:** Ryan (via Copilot)  
**Module:** `Fabric-private/`

## Directive

Flip the default for `restrict_workspace_public_access` from `false` to `true` in Fabric-private variables.

## Rationale

The lab's purpose is private connectivity — public-by-default contradicts the module's design intent (workspace PE is always deployed). Making private-only the default reduces configuration friction and aligns infrastructure with purpose.

