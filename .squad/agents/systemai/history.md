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

### 2025-07-27 → 2026-04-06 — ACA Application Landing Zone Security Requirements Assessment

Completed proactive security requirements assessment for a new Azure Container Apps (ACA) ALZ before implementation. Key findings and patterns:

- **ACA workload profiles (dedicated) + internal-only + BYO VNet** is the most secure ACA deployment model. Fully compatible with existing vWAN spoke pattern.
- **NSG rules are ACA-specific:** Must allow ports 31080/31443 (edge proxy) and 30000-32767 (LB probes) in addition to 80/443. This is different from standard web workload NSGs.
- **MCR access is mandatory:** Even with private ACR, ACA pulls system containers from mcr.microsoft.com. Firewall rules must always allow MCR + AzureFrontDoor.FirstParty.
- **AKS dependency FQDNs:** ACA runs on AKS under the hood — `packages.aks.azure.com` and `acs-mirror.azureedge.net` must be allowed through firewall.
- **Azure DNS (168.63.129.16) must never be blocked outbound.** Exception: dedicated workload profiles can block `AzurePlatformDNS` service tag if custom DNS fully handles resolution.
- **Subnet delegation:** ACA requires `Microsoft.App/environments` delegation (same delegation already used by Foundry-byoVnet's workload subnet). Subnet must be exclusively dedicated to one ACA environment.
- **Private DNS for internal ACA:** Requires a private DNS zone matching the environment's default domain (`<UNIQUE>.<REGION>.azurecontainerapps.io`) with wildcard A record pointing to the static internal LB IP.
- **ACR requires Premium SKU** for private endpoint support. Use `admin_enabled = false` + managed identity with `AcrPull` role.
- **New DNS zone needed in Networking:** `privatelink.azurecr.io` not currently deployed. Should be added to the platform's private DNS zone set.
- **IP addressing:** Recommended Block 4 (172.20.64.0/20) for ACA ALZ to avoid overlap with Foundry modules.
- **5 critical, 5 medium, 4 low findings.** No blocking concerns — design is architecturally sound.
- **Comprehensive 441-line security requirements assessment** filed to `.squad/decisions/inbox/systemai-aca-security-requirements.md` (archived in orchestration-log).
- Concurrent work with Carl's architecture design; both merged into `decisions.md` Decision #11 (ACA ALZ Architecture).
- **Status:** APPROVED FOR IMPLEMENTATION — Security assessment complete, no blocking findings.

### 2025-07-27 — ACA ContainerApps-byoVnet Code Review

Completed security code review of Donut's ContainerApps-byoVnet implementation (11 .tf files) against original ACA security requirements.

- **Verdict: APPROVE** — No critical or medium findings. Zero drift from security requirements.
- **All 24 security controls verified:** Internal-only LB, user-assigned MI + AcrPull, no NSG on delegated subnet, NSG on PE subnet, ACR admin disabled, ACR public access disabled, private endpoint with correct subresource, DNS zones with dual VNet links, wildcard A record, vHub internet_security tracking firewall state, custom DNS, DNS resolver policy link, no hardcoded secrets, no public IPs.
- **1 low finding:** 5 DNS helper resources (4 VNet links, 1 A record) missing `tags = local.common_tags`. Governance hygiene only, no security impact.
- **Strong patterns:** Zero public attack surface, conditional firewall integration, DNS prerequisite check block, clean module separation.
- Review filed to `.squad/decisions/inbox/systemai-aca-code-review.md`.

### 2026-07-18 — ACA Post-Change Security Recheck

Re-reviewed ContainerApps-byoVnet after three changes: ingress `external_enabled` flip, LAW consolidation, and ACR DNS zone consolidation.

- **Verdict: APPROVE** — No critical findings. All three changes are security-neutral or positive. Zero public endpoints introduced.
- **Key insight on `external_enabled = true`:** In an internal ACA environment, this does NOT create internet exposure. It makes the app reachable from the broader private network (any connected spoke, on-prem via vHub) — not just the local VNet. This is the intended behavior for lab demos.
- **LAW consolidation:** Acceptable for lab. Shared workspace means platform RBAC governs app log visibility — fine when operators are the same team.
- **ACR DNS zone consolidation:** Correct pattern. PE auto-registers into centralized zone. General DNS prerequisites are checked via `check` block, though the ACR zone itself is not explicitly validated (acceptable risk given AVM module deploys all standard privatelink zones).
- **Existing accepted risks unchanged:** Empty PE subnet NSG (default Azure rules allow VNet inbound), allow-all firewall rules (lab-accepted, backlog item #8), AcrPull identity provisioned but not wired to sample app (infrastructure ready for user workloads).
- Recheck filed to `.squad/decisions/inbox/systemai-aca-recheck.md`.
