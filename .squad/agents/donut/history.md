# Project Context

- **Owner:** Ryan Krokson
- **Project:** Azure IaC demo/lab environments — Terraform modules for Azure vWAN, AI Foundry, networking
- **Stack:** Terraform (azurerm >= 4.0, azapi >= 2.0, random ~> 3.5), PowerShell, Azure CLI
- **Structure:** Three root modules — Networking (foundation), Foundry-byoVnet, Foundry-managedVnet linked via terraform_remote_state
- **Created:** 2026-03-27

## Learnings

<!-- Append new learnings below. Each entry is something lasting about the project. -->
- **2026-03-27 (gitignore-audit):** Appended preventive .gitignore patterns for IDE configs (`.vscode/`, `.idea/`, swap files), environment files (`.env`, `.env.local`, `.env.*.local`), and OS artifacts (`Thumbs.db`, `.DS_Store`). Existing Terraform and Squad patterns left untouched. Coordinated with Carl (lead audit) and Katia (security validation).
