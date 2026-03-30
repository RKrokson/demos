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
- **Phase 1 docs delivered (3 tasks):**
  - **1-readme-hub:** Root README rewritten as navigation hub. Removed duplicated module content. Added Landing Zone Model section with module index tables, Getting Started sequence, Destroy Order, and consolidated prereqs. Cost table kept (removed VPN line items). Removed all VPN references per Donut's code removal.
  - **1-lz-framing:** All module READMEs renamed with landing zone titles. Networking = "Platform Landing Zone — Networking" with Downstream Dependencies section. Both Foundry modules = "Application Landing Zone" with optional framing. copilot-instructions.md updated with platform/app LZ terminology and "future modules follow the same pattern" note. VPN references removed from copilot-instructions conditional deployments table.
  - **1-readme-prereqs:** Each module README now has its own Prerequisites section. Foundry modules link back to root prereqs and list additional requirements (create_AiLZ, add_privateDNS00, AI Foundry region support).
  - Fixed "destory" → "destroy" typo in Foundry-managedVnet/README.md.
  - Fixed "Cleanup step" → "Cleanup Steps" heading consistency across both Foundry READMEs.
  - Referenced PG-validated sample repos in both Foundry READMEs with inline links.
- Ryan mandated humanizer rules: no AI vocabulary, no promotional language, no rule of three, no em dashes overuse. Write like a senior engineer, not a marketing team.
- **2026-03-30 (phase1-coordination):** Coordinated Phase 1 implementation with Donut (code). All VPN references removed from documentation (READMEs, copilot-instructions.md) per Donut's code removal. Decision inbox merged. All changes ready for git commit with message "squad: phase 1 implementation — VPN removal, bug fixes, tags, outputs, LZ framing".
- **Targeted fixes batch:** Three doc corrections per Ryan: (1) Root README now says "pick one, not both" for Foundry modules instead of "deploy one, both, or neither." (2) Removed `terraform state rm azapi_resource.managed_network` step from Foundry-managedVnet cleanup and root destroy order -- no longer needed. (3) Removed ghost/stale DNS resolver REST API cleanup section from Foundry-byoVnet -- issue resolved upstream.
