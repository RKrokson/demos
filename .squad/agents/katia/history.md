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
