# Project Context

- **Owner:** Ryan Krokson
- **Project:** Azure IaC demo/lab environments — Terraform modules for Azure vWAN, AI Foundry, networking
- **Stack:** Terraform (azurerm >= 4.0, azapi >= 2.0, random ~> 3.5), PowerShell, Azure CLI
- **Structure:** Three root modules — Networking (foundation), Foundry-byoVnet, Foundry-managedVnet linked via terraform_remote_state
- **Created:** 2026-03-27

## Learnings

- **.gitignore audit (2025-01-17):** .gitignore is well-designed for a Terraform demo/lab repo with local state. `.terraform.lock.hcl` files are intentionally tracked (not in .gitignore) — this is correct for reproducible builds in shared repos. Core gap: `.squad/`, `.github/`, and `.copilot/` directories are untracked and should be explicitly ignored. Three Terraform root modules (Networking → Foundry-byoVnet / Foundry-managedVnet) use local backends with state files properly excluded.
- **tfvars pattern:** `.tfvars.example` and `.tfvars.advanced.example` are tracked; actual `.tfvars` are ignored. Pattern correct: `*.tfvars` catches all secrets. No `.example` files are being ignored, which is the right trade-off for IaC docs.
- **2026-03-27 (gitignore-audit finalized):** Completed architecture audit as team lead. Validated with Katia (security), updated by Donut with IDE/env/OS patterns. Decision approved and implemented.
