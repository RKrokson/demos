# Project Context

- **Owner:** Ryan Krokson
- **Project:** Azure IaC demo/lab environments — Terraform modules for Azure vWAN, AI Foundry, networking
- **Stack:** Terraform (azurerm >= 4.0, azapi >= 2.0, random ~> 3.5), PowerShell, Azure CLI
- **Structure:** Three root modules — Networking (foundation), Foundry-byoVnet, Foundry-managedVnet linked via terraform_remote_state
- **Created:** 2026-03-27

## Learnings

<!-- Append new learnings below. Each entry is something lasting about the project. -->
- **2026-03-27 (gitignore-audit):** Appended preventive .gitignore patterns for IDE configs (`.vscode/`, `.idea/`, swap files), environment files (`.env`, `.env.local`, `.env.*.local`), and OS artifacts (`Thumbs.db`, `.DS_Store`). Existing Terraform and Squad patterns left untouched. Coordinated with Carl (lead audit) and Katia (security validation).
- **2026-03-27 (terraform-best-practices-audit):** Comprehensive review of all 12 .tf files across 3 root modules. Key patterns: Networking/main.tf is 1020 lines (monolith), ~120 variables in Networking with heavy region duplication (region 0/1 copy-paste). Foundry modules use azapi extensively for AI Foundry resources not yet in azurerm. No tags on any resources. No `required_version` in Networking/config.tf. Local state backend used everywhere. Firewall rules are allow-all wildcards. Private DNS zone IDs are constructed via string interpolation rather than data sources. Variables lack validation blocks. `vm_admin_username` output exposes potentially sensitive info. `random_password` not marked sensitive. `s2s_site00_speed` typed as string but should be number.
- **2026-03-29 (repo-revamp-plan):** Full team review finalized. Four high-priority bugs identified (VPN naming, three count-guard crashes). Comprehensive recommendations delivered across code quality, security hardening, and documentation. Team consensus: implement critical bugs first, then architectural changes. All findings merged into squad decisions.md. **Key output:** 40+ prioritized findings with implementation sequence. **Cross-team coordination:** Worked with Carl (lead), Katia (validator), Mordecai (docs) on integrated review.
