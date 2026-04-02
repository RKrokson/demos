# SystemAI — History

## Core Context

- **Project:** Azure IaC demo/lab environments (Terraform)
- **Owner:** Ryan Krokson
- **Stack:** Terraform (azurerm >= 4.0, azapi >= 2.0), PowerShell, Azure CLI
- **Structure:** Three root modules — Networking (Platform LZ), Foundry-byoVnet (App LZ), Foundry-managedVnet (App LZ, preview)
- **Key security context:** This is a lab/demo repo. Some intentionally permissive settings exist (e.g., firewall allow-all rules) and are documented. Distinguish between lab-acceptable and genuinely risky configurations.
- **Known security decisions:** disableLocalAuth=false on Foundry (required for agent proxy), networkAcls.defaultAction="Allow" with publicNetworkAccess="Disabled" (PG-validated combo), VM passwords via random_password + Key Vault.
- **Agent pronouns:** Carl he/him, Donut she/her (female cat), Mordecai he/him, Katia she/her.

## Learnings

### 2025-07-25 — Full Security Assessment

Completed full review of all 4 modules (Networking, region-hub child, Foundry-byoVnet, Foundry-managedVnet). Key findings:

- **No critical issues.** No exposed secrets, no public endpoints on AI services, no hardcoded credentials.
- **3 medium findings:** (1) Key Vault uses legacy access policies instead of RBAC authorization, (2) Key Vault has no purge protection (intentional for lab but undocumented), (3) No NSGs on shared/app subnets in the Networking child module — VMs only protected by OS firewall when Azure Firewall is disabled.
- **6 low findings:** All accepted risks or lab-appropriate tradeoffs. Firewall allow-all (documented), disableLocalAuth=false on BYO Foundry (PG-required), predictable VM username (mitigated by Bastion), no encryption-at-host (platform SSE sufficient), local state (gitignored properly).
- **Strong positive patterns:** Private endpoints on all AI services, Entra ID auth everywhere possible, ABAC conditions on Storage Blob Data Owner, managed identity throughout, proper .gitignore, TLS 1.2 minimum on storage, default-deny storage network rules.
- Assessment filed to `.squad/decisions/inbox/systemai-security-assessment.md`.
- Security skill written to `.squad/skills/azure-security/SKILL.md`.
