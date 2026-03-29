# Project Context

- **Owner:** Ryan Krokson
- **Project:** Azure IaC demo/lab environments — Terraform modules for Azure vWAN, AI Foundry, networking
- **Stack:** Terraform (azurerm >= 4.0, azapi >= 2.0, random ~> 3.5), PowerShell, Azure CLI
- **Structure:** Three root modules — Networking (foundation), Foundry-byoVnet, Foundry-managedVnet linked via terraform_remote_state
- **Created:** 2026-03-27

## Learnings

<!-- Append new learnings below. Each entry is something lasting about the project. -->
- Ryan wants "platform landing zone" / "application landing zone" framing across all READMEs
- Root README currently serves double duty as both landing page and content (monolithic). Needs restructuring into a navigation hub.
- Diagram path casing inconsistency: root README uses `./Diagrams/` (capital D), Networking README uses `./diagrams/` (lowercase). Both folders exist with different content. Windows hides this but Git on Linux will break.
- Root `Diagrams/` folder has only 4 images; Networking `diagrams/` folder has 16 images — the Networking examples reference the local subfolder.
- Foundry-byoVnet README has no `./diagrams/` subfolder — references `../Diagrams/` (root level).
- Foundry-managedVnet has a `diagrams/` subfolder with 1 image — references `../Diagrams/` (root level).
- The advanced tfvars example includes `create_AiLZ` vars but no AI subnet address overrides — worth documenting.
- copilot-instructions.md already exists at `.github/copilot-instructions.md` with solid content. Needs landing zone framing update.
- Networking `config.tf` has no `required_version` constraint, unlike both Foundry modules (>= 1.8.3).
- Neither Foundry README documents its Terraform variables or outputs.
- Cleanup/destroy sequencing is scattered — byoVnet and managedVnet each have partial cleanup steps; no unified destroy guide exists.
- **2026-03-29 (repo-revamp-plan):** Full team documentation review completed. 19 recommendations delivered covering README structure, landing zone framing, diagram normalization, and documentation completeness. Team consensus: README restructuring is primary doc work. All recommendations merged into squad decisions.md. **Key coordination:** Worked with Carl (architecture), Donut (code), Katia (validation) to align documentation with technical decisions. **Typo found:** `.tfvars.advance.example` should be `.tfvars.advanced.example`.
