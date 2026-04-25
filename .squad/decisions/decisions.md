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
- AI Foundry: ifoundry0918
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

