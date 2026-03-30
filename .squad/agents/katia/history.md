# Project Context

- **Owner:** Ryan Krokson
- **Project:** Azure IaC demo/lab environments — Terraform modules for Azure vWAN, AI Foundry, networking
- **Stack:** Terraform (azurerm >= 4.0, azapi >= 2.0, random ~> 3.5), PowerShell, Azure CLI
- **Structure:** Three root modules — Networking (foundation), Foundry-byoVnet, Foundry-managedVnet linked via terraform_remote_state
- **Created:** 2026-03-27

## Learnings

- **Gitignore Status:** Well-configured; .terraform.lock.hcl files ARE correctly committed (best practice for reproducible provider builds). All *.tfvars files properly ignored except *.example templates which ARE tracked.
- **Sensitive Files:** No credential files, secrets, or state files tracked in git. Repository is clean from a security perspective.
- **IDE Configs:** .vscode, .idea not tracked; no IDE-specific configuration leakage.
- **Squad Integration:** Squad runtime state properly ignored (.squad/orchestration-log/, .squad/log/, .squad/decisions/inbox/, .squad/sessions/) and workstream activation file excluded.
- **Terraform Patterns:** Crash logs, plan files (*.tfplan), override files, and CLI config files all correctly ignored per HCL best practices.
- **Example Files Pattern:** terraform.tfvars.example and terraform.tfvars.advanced.example are tracked in Networking/ as templates for users (correct approach).
- **2026-03-27 (gitignore-audit finalized):** Validated security posture with Carl (lead) and Donut (infra dev). No security gaps found. Approved pattern enhancements for IDE/env/OS artifacts.
- **2026-07-14 (full-terraform-review):** Comprehensive review of all three modules. Key findings:
  - `terraform validate` passes all modules (Foundry-managedVnet has warning about redundant `ignore_changes` on `output`).
  - `terraform fmt -check` fails across ALL modules — formatting drift in every .tf file.
  - **Critical bug:** Networking/main.tf line 505 uses `var.s2s_conn01_name` for VPN00 connection (should be `s2s_conn00_name`).
  - **Critical bug:** `fw01_logs` (line 900) count only checks `add_firewall01`, not `create_vhub01` — crashes if firewall01 enabled without hub01.
  - **Critical bug:** `s2s_VPN01` (line 970) count only checks `add_s2s_VPN01`, not `create_vhub01` — crashes referencing non-existent rg-net01[0].
  - **Critical bug:** `ai_vnet01_dns` (line 851) count checks `add_privateDNS01 && create_AiLZ` but not `create_vhub01` — crashes referencing non-existent ai_vnet01[0].
  - No validation blocks exist on any boolean toggle variables — invalid combos silently fail at apply time.
  - Firewall rules are allow-all (`*`/`*`/`*`) — acceptable for lab but should be flagged.
  - Foundry-byoVnet networkAcls.defaultAction = "Allow" contradicts publicNetworkAccess = "Disabled".
  - Foundry-byoVnet uses `time_sleep` but doesn't declare hashicorp/time provider (works via implicit provider but not pinned).
  - Private DNS zone IDs are hardcoded by string interpolation in Foundry modules — fragile, breaks if DNS zones aren't created by Networking.
  - `vm_admin_username` output is not marked sensitive, exposing admin usernames in state.
- **2026-03-29 (repo-revamp-plan):** Full team review completed. Four critical count-guard and naming bugs formally documented with reproduction scenarios. Team consensus on implementation backlog. All security findings merged into squad decisions.md. **Key coordination:** Worked with Carl (architect), Donut (code review), Mordecai (docs) to triangulate validation strategy.
- **2026-03-30 (phase1-validation):** Full validation of Phase 1 changes (Donut code + Mordecai docs). **BLOCKING FAILURE:** `default_tags` block added to all 3 provider configs but azurerm provider does NOT support this feature (it's an AWS provider feature). `terraform validate` fails in all 3 modules. Provider schema confirms only `features` block is valid. **Passed checks:** `terraform fmt -check` clean (all 3 modules), VPN fully removed from .tf/.tfvars (zero matches), count guards correct (fw01_logs checks `create_vhub01 && add_firewall01`, ai_vnet01_dns checks `create_vhub01 && add_privateDNS01 && create_AiLZ`), Networking outputs exports DNS zone IDs/subnets/LAW/KV, Foundry modules use output references (no string interpolation), `required_version` added to Networking, `random` provider declared in byoVnet, root README restructured as nav hub, LZ framing in all READMEs, prerequisites in all modules, "destory" typo fixed. **Observation:** 6 diagram filenames in Networking/README.md still contain "vpn" in the filename (e.g., `1reg-hub-dns-vpn-v1.1.png`). DNS zone outputs in Networking use ARM path interpolation rather than resource references (consequence of AVM module pattern — acceptable for now). **Verdict:** REJECT — must remove `default_tags` blocks from all 3 configs before merge. Assign to a different agent (not Donut) per validator protocol.
- **2026-03-30 (tags-fix-revalidation):** Re-validated Carl's fix for the `default_tags` rejection. **All 5 checks PASS:** (1) `default_tags` completely removed from all 3 config.tf files — clean provider blocks. (2) `locals.tf` exists in all 3 modules with correct `common_tags` map (environment=non-prod, managed_by=terraform, project=azure-infra-poc). (3) `terraform validate` succeeds in all 3 modules (Foundry-managedVnet still has pre-existing `ignore_changes` warning — not tags-related). (4) Spot-checked resource groups, VNets, firewalls, storage accounts, private endpoints, azapi resources across all modules — all have `tags = local.common_tags`. (5) Full resource inventory: 59 resources tagged across all modules (Networking=36, byoVnet=10, managedVnet=13). All untagged resources confirmed non-taggable: subnets, hub connections, role assignments, key vault secrets, diagnostic settings, forwarding rules, routing intents, cognitive deployments, azapi child resources (connections, outbound rules, managed networks, capability hosts, VNet links). **Verdict:** PASS — tags implementation is correct and complete. Carl's approach (locals.tf with explicit `tags = local.common_tags` on each resource) is the proper azurerm pattern.
