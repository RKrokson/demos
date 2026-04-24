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
Ryan's existing Networking tfvars already had dd_firewall00 = true and dd_private_dns00 = true with single region (create_vhub01 = false). No modifications required.

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

