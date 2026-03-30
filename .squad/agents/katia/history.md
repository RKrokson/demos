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
- **2026-03-30 (phase2-batch2-coordination):** Phase 2 Batch 2 orchestration logged and completed. Scribe merged 4 inbox decisions into main decisions file (resource-label-standardization, variable-naming-conventions, storage-account-configuration-pattern, ai-lz-directive). Updated Donut and Katia history with cross-team coordination notes. Indexed as non-blocking observation: AI vHub connections in Foundry modules missing `internet_security_enabled` toggle — flagged for future review but does not block merge.
- **2026-03-30 (phase2-batch2-validation):** Full validation of Donut's Phase 2 Batch 2 changes. **All 8 checks PASS.**
  - (1) `terraform fmt -check`: PASS all 3 modules — zero formatting drift.
  - (2) `terraform validate`: PASS all 3 modules — managedVnet still has pre-existing `ignore_changes` warning (not Batch 2 related).
  - (3) locals.tf: PASS — exists in Networking with `suffix`, `rg00_name`, `rg00_location`. `random_string.unique.id` and `azurerm_resource_group.rg-net00.name/.location` only appear in locals.tf definition. `local.suffix` used 7 times, `local.rg00_name`/`local.rg00_location` used ~40 times across all domain files. No stale inline references.
  - (4) PascalCase variables: PASS — no `SkuName`, `SkuTier`, `create_AiLZ`, `add_privateDNS`, `resource_group_name_KV` in any .tf file. All 8 variables confirmed renamed to snake_case.
  - (5) Validation blocks: PASS — 6 blocks on correct variables: CIDR validation on `azurerm_vhub00/01_address_prefix`, bastion SKU on `bastion_host_sku00/01` (Basic/Standard/Developer), firewall tier on `firewall_sku_tier00/01` (Standard/Premium).
  - (6) Resource labels: PASS — `random_string "unique"` in keyvault.tf (no `myrandom`). `azapi_resource "foundry"` in byoVnet foundry.tf (no `ai_foundry` resource label). `ai_foundry` string in output names and subnet refs is intentional naming, not resource labels.
  - (7) Storage replication: PASS — `account_replication_type = "LRS"` in both byoVnet/storage.tf:13 and managedVnet/storage.tf:13. managedVnet also has `bypass = ["AzureServices"]` in network_rules.
  - (8) tfvars: PASS — all 3 files (`terraform.tfvars`, `.example`, `.advanced.example`) use snake_case names (`create_ai_lz`, `add_private_dns00/01`, `add_firewall00/01`). No stale PascalCase variable names.
  - **OBSERVATION (non-blocking):** Documentation files still reference old PascalCase variable names (`create_AiLZ`, `add_privateDNS00`) in: root README, Networking/README, both Foundry READMEs, copilot-instructions.md, adding-application-landing-zone.md. Users following README instructions would use stale variable names and get "variable not declared" errors. Mordecai should update docs to match renamed variables.
  - **Verdict:** PASS — Phase 2 Batch 2 code changes are correct and complete. Doc update needed for variable name consistency (assign to Mordecai).
- **2026-03-30 (scribe-coordination):** Scribe wrote orchestration log entry for Phase 2 Batch 2 validation work. Decision #7 (ALZ VNet migration) and #8 (firewall control) merged into decisions.md. Ready for git commit. Non-blocking documentation sync issue flagged for Mordecai.
