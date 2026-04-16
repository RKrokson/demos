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



