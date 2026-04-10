# Carl — Architecture Lead (Archive)

Archived historical research and design work.

## July 2025 Research Phase

- **2025-07-25 (output-contract-review):** Reviewed Donut's output contract (Networking → Foundry modules). Approved — complete, well-described, consistent naming. Flagged Foundry output naming inconsistency (filed as decision).

- **2025-07-25 (tagging-fix):** Fixed `default_tags` implementation (AWS concept, unsupported by azurerm). Replaced with `local.common_tags`. All three modules pass validation.

- **2025-07-26 (local-auth-research):** Researched `disableLocalAuth` across Foundry services. AI Search hardening is optional; Foundry CognitiveServices inconsistency between BYO/managedVnet noted.

- **2025-07-26 (alz-vnet-migration-design):** Produced design for moving AI Landing Zone VNet from Networking into Foundry modules. 6 resource types per region, 3 new Networking outputs, 8 new Foundry variables.

- **2025-07-26 (alz-ip-address-design):** IP address space analysis. BYO=Block 2 (172.20.32.0/20), Managed=Block 3 (172.20.48.0/20). Non-overlapping design for simultaneous deployment.

- **2025-07-27 (15b-comparison):** Line-by-line PG 15b reference comparison. Root cause of Cosmos 403: `networkAcls.defaultAction = "Deny"` breaks agent proxy control-plane. Fix: change to `"Allow"`.

- **2025-07-27 (nat-gateway-design):** NAT Gateway design as firewall alternative. Firewall/NAT mutually exclusive by design (routing intent). 5 resources per region in child module.

- **2025-07-27 (pre-push-architecture-review):** Comprehensive code review before public push. HIGH: DNS policy null-reference guards needed. MEDIUM: stale comments, API version drift, Key Vault RBAC, NSGs. CLEAN: child module tight contract.

## March 2026 Implementation Phase

- **2026-03-27 (gitignore-audit finalized):** Architecture audit as team lead. Validated with Katia, updated by Donut with IDE/env patterns. Decision approved.

- **2026-03-29 (repo-revamp-plan):** Full team review. Consensus on landing zone architecture, priorities, decision framework. Approved platform/application LZ model.

- **2026-03-30 (tagging-pattern-lock):** Tagged 59 resources with `local.common_tags`. Established azurerm tagging pattern (locals + explicit, never default_tags).

- **2026-03-30 (region-hub-module-design):** Design for `modules/region-hub/` child module. 31 per-region resources, count guards eliminate boolean bugs. Zero user-facing changes.

- **2026-03-30 (phase3-wrap):** Phase 3 complete — 22 work items, 59 resources tagged, output contract finalized, security hardened, ALZ ownership refactored.

- **2026-04-03 (readme-accuracy-review):** README audit. Found non-existent variables in Foundry docs (Decision #7 not yet implemented). Fixed variable tables. Other content accurate.

- **2026-04-06 (aca-alz-architecture):** Designed Azure Container Apps ALZ. IP Block 4 (172.20.64.0/20), /27 delegated subnet, centralized DNS pattern, no NSG on delegated subnet.
