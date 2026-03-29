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
- **2025-07-25 (repo-revamp-architecture-review):** Completed comprehensive review of all .tf files across Networking/, Foundry-byoVnet/, Foundry-managedVnet/ for repo revamp planning. Key findings:
  - Networking main.tf is 1020+ lines monolith; variables.tf has 100+ flat variables with copy-paste per region
  - Zero resource tags anywhere; no outputs from Foundry modules; no outputs.tf in Foundry dirs
  - Cross-module naming inconsistency: `ai_foundry` vs `foundry`, `myrandom` vs `unique`, mixed case in variable names (`firewall_SkuName00`)
  - Provider version drift: Networking uses `>= 4.0, < 5.0`, Foundry modules pin `~> 4.26.0`; Networking missing `required_version`
  - API version drift across azapi resources between Foundry modules
  - Remote state dependency is fragile (hardcoded `../Networking/terraform.tfstate` path); DNS zone IDs constructed as strings from rg_net00_id
  - Region 0/1 code is nearly identical — prime candidate for child module extraction
  - Security gaps: allow-all firewall rules, Key Vault using access policies instead of RBAC, no NSGs, `disableLocalAuth = false` on AI Search
  - Config divergence between Foundry modules: ZRS vs LRS, AzureServices bypass vs no bypass, identity block style differences
  - User preference: Networking = platform landing zone, Foundry modules = optional application landing zones
- **2026-03-29 (repo-revamp-plan):** Full team review completed. Consensus reached on landing zone architecture, implementation priorities, and decision framework. All recommendations merged into squad decisions.md. Next: implementation backlog execution. **Key decision:** Adopt platform/application landing zone model (Networking = platform LZ, Foundry modules = app LZs). Cross-module naming consistency, security hardening, and documentation restructuring are team priorities.
