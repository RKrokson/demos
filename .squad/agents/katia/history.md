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
