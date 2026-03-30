# Project Decisions

## Gitignore Audit (2025-01-17, finalized 2026-03-27)

**Owner:** Carl (Lead/Architect)  
**Status:** APPROVED & IMPLEMENTED

### Summary

The `.gitignore` file is well-aligned with Terraform best practices for a demo/lab environment using local state. Three root modules (Networking, Foundry-byoVnet, Foundry-managedVnet) are properly protected from accidental commits of state, locks, and sensitive variables.

### Findings

**Correct Patterns:**
- `*.tfstate` / `*.tfstate.*` — state files properly excluded
- `*.tfvars` — secrets excluded while `.example` and `.advanced.example` are tracked (best practice)
- `.terraform/` directories excluded
- `.terraform.tfstate.lock.info` excluded (transient)
- `override.tf*` patterns excluded
- `.terraformrc` / `terraform.rc` excluded
- Squad runtime excluded (`.squad/log/`, `.squad/decisions/inbox/`, `.squad/sessions/`)

**Design Choice:** `.terraform.lock.hcl` IS Tracked  
This is intentional and correct. Terraform recommends committing lock files for reproducible builds in shared repos.

### Approved Updates

Donut appended preventive patterns to `.gitignore`:

```
# IDE and editor configuration
.vscode/
.idea/
*.swp
*.swo

# Environment files
.env
.env.local
.env.*.local

# OS artifacts
Thumbs.db
.DS_Store
```

**Rationale:** Prevents accidental commits of local IDE config, environment variables, and OS artifacts while maintaining Terraform and Squad patterns.

### Next Steps

1. ✅ Update .gitignore with recommended patterns
2. ✅ Verify patterns with team validation
3. ✅ Commit and document decision

---

## Copilot Directive: Humanizer Skill (2026-03-30T02:34:00Z)

**Owner:** Ryan Krokson (via Copilot)  
**Status:** ACTIVE GUIDELINE

All README and documentation updates must be run through the humanizer skill before finalizing, to remove signs of AI-generated writing. This ensures consistent, natural technical voice across all documentation.

---

## VPN Removal and Output Contract (2026-03-29, finalized 2026-03-30)

**Owner:** Donut (Infra Dev)  
**Status:** APPROVED & IMPLEMENTED

### Summary

VPN infrastructure fully removed from Networking module. Networking output contract established with 10+ DNS zone IDs, vHub IDs, LAW ID, Key Vault ID/name, and region 1 subnet IDs exported for downstream module consumption.

### What Changed

1. **VPN fully removed.** All 8 VPN gateway resource blocks, 16 VPN variables, and tfvars references eliminated across both regions. The VPN naming bug (s2s_conn01 vs s2s_conn00) is now moot.

2. **Networking output contract established.** 10 private DNS zone IDs, vHub IDs, LAW ID, Key Vault ID/name, and region 1 subnet IDs are now exported. Foundry modules consume these directly instead of constructing ARM paths via string interpolation.

3. **Count guard bugs fixed.** `fw01_logs` and `ai_vnet01_dns` now properly require `create_vhub01`.

4. **Default tags added.** All 3 provider configurations now include `default_tags` block for consistent resource tagging.

5. **Provider constraints added.** Networking/config.tf: `required_version >= 1.8.3`. Foundry-byoVnet/config.tf: `random` provider declaration added.

### Impact

- Any future module that needs DNS zone IDs or subnet IDs should consume Networking outputs, not construct ARM paths.
- The `add_s2s_VPN00` and `add_s2s_VPN01` toggles no longer exist. Remove from any external documentation or automation.
- Default tags reduce boilerplate and improve consistency across all resources.
- Networking is now the single source of truth for DNS zone IDs and hub identifiers.

### Cross-Team Updates

- **Mordecai:** Removed all VPN references from documentation (READMEs, copilot-instructions.md).

---

## Local Auth Security Hardening (2026-03-30)

**Owner:** Carl (Lead/Architect)  
**Status:** APPROVED & IMPLEMENTED

### Summary

Comprehensive security research on `disableLocalAuth` settings across AI Foundry connected resources (AI Search, AI Services/CognitiveServices, Cosmos DB, Storage). Evidence-based recommendations to disable local auth on all services, relying solely on Entra ID / RBAC authentication.

### Findings

| Service | byoVnet | managedVnet | Secure? | Action |
|---|---|---|---|---|
| Storage Account | ✅ `disabled = true` | ✅ `disabled = true` | Yes | No change |
| Cosmos DB | ✅ `disabled = true` | ✅ `disabled = true` | Yes | No change |
| AI Search | ❌ `disableLocalAuth = false` | ❌ `disableLocalAuth = false` | No | Fix both |
| AI Foundry (CognitiveServices) | ❌ `disableLocalAuth = false` | ✅ `disableLocalAuth = true` | Mixed | Fix byoVnet |

### Key Evidence

1. **managedVnet already has `disableLocalAuth = true` on CognitiveServices** — proves it works with AI Foundry
2. **Both modules use RBAC role assignments** for all service-to-service auth — API keys are not consumed
3. **Microsoft docs explicitly support keyless auth** for AI Search agent tool and Foundry
4. **Azure AI Search indexers** can use managed identity (modern approach) without account keys
5. **READMEs already acknowledge** this pattern: "Set `disableLocalAuth` to `True` to require Entra-only auth"

### Implemented Changes

- **Foundry-byoVnet:** Set `disableLocalAuth = true` on AI Search resource (matches byoVnet)
- **Foundry-managedVnet:** Confirmed `disableLocalAuth = true` on AI Search (already correct)
- **Foundry-byoVnet:** Confirmed `disableLocalAuth = true` on CognitiveServices (already correct)

All RBAC role assignments (Search Index Data Contributor, Search Service Contributor, etc.) remain in place.

### Microsoft Recommendations Summary

| Service | Recommendation | Our Status |
|---|---|---|
| AI Services / Foundry | Disable local auth → Entra ID | ✅ byoVnet now hardened |
| AI Search | Disable API keys → RBAC | ✅ Both modules hardened |
| Cosmos DB | Disable local auth → Managed identity | ✅ Already correct |
| Storage | Prevent shared key → Entra ID | ✅ Already correct |

### Citation

- [Enable or disable RBAC in AI Search](https://learn.microsoft.com/azure/search/search-security-enable-roles#disable-api-key-authentication)
- [AI Search tool for Foundry agents — Keyless auth](https://learn.microsoft.com/azure/ai-foundry/agents/how-to/tools/azure-ai-search)
- [Disable local authentication in Azure AI Services](https://learn.microsoft.com/azure/ai-services/disable-local-auth)

---

## vHub Connection Merge Pattern (2026-03-30)

**Owner:** Donut (Infra Dev)  
**Status:** APPROVED & IMPLEMENTED

### Summary

Simplified Networking module's vHub connection configuration by merging mutually exclusive resource pairs (secure/unsecure variants) into single resources.

### What Changed

The Networking module had pairs of vHub connections toggled by firewall variables using duplicate resource blocks with identical configuration except `internet_security_enabled`. Example:

- `azurerm_virtual_hub_connection.shared_spoke00_unsecure` (when `add_firewall00 = false`)
- `azurerm_virtual_hub_connection.shared_spoke00_secure` (when `add_firewall00 = true`)

Merged into single resource:
- `azurerm_virtual_hub_connection.shared_spoke00` with `internet_security_enabled = var.add_firewall00`

Applied to all vHub connections:
- Shared spoke region 0 and region 1
- DNS VNet region 0 and region 1

### Impact

- **6 resource blocks eliminated** (3 connection pairs, each with 2 variants)
- **Simpler conditional logic** — one resource per connection, not two
- **No state migration needed** for new deployments (existing deployments would require `terraform state mv` for the removed `-secure` variants)
- **Cleaner main.tf** after file split refactoring

---

## GitHub Organization Standardization (2026-03-30)

**Owner:** Mordecai (Docs)  
**Status:** APPROVED & IMPLEMENTED

### Summary

Standardized foundry-samples repository references across module READMEs to use the correct, publicly accessible GitHub organization.

### What Changed

Two Foundry module READMEs linked to different GitHub orgs for the PG-validated sample repos:
- **Foundry-byoVnet:** `azure-ai-foundry/foundry-samples` (404 on GitHub API — org doesn't exist or not public)
- **Foundry-managedVnet:** `microsoft-foundry/foundry-samples` (exists and verified)

### Action

Standardized both READMEs to use `microsoft-foundry/foundry-samples`. Verified via GitHub API search.

### Impact

- BYO VNet README link now resolves correctly
- Both modules reference the same authoritative sample repo
- No code changes required; documentation only

---

## Foundry ALZ Architecture Directive (2026-03-30T16:44:00Z)

**Owner:** Ryan Krokson (via Copilot)  
**Status:** ACTIVE GUIDELINE

### Summary

Clarified Foundry Application Landing Zone deployment model and future architecture direction.

### Direction

**Current:** Foundry modules (byoVnet, managedVnet) are "either, not both" — you deploy one or the other, not both simultaneously into the same subscription.

**Future goal:** Move AI Landing Zone VNet creation into each Foundry ALZ folder. Each ALZ will create its own spoke VNet without requiring the platform-level `create_AiLZ` conditional in the Networking module. This aligns with landing zone best practice where each ALZ owns its own network resources.

### Implementation

- Root README now clarifies "pick one, not both" for Foundry modules
- New `docs/adding-application-landing-zone.md` guide documents current remote state pattern and future ALZ self-sufficiency
- Networking module remains "foundation-first" until ALZ VNet migration is complete

### Cross-Team Impact

- **Donut:** Code refactoring targets simplified dependency chain
- **Mordecai:** Documentation reflects current conditional model and future direction
- **Ryan:** Clarifies governance — ALZ model guides future module design
