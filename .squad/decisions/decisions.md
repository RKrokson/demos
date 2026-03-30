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

---

## Resource Label Standardization (2026-03-30T18:00:00Z)

**Owner:** Donut (Infra Dev)  
**Status:** APPROVED & IMPLEMENTED

### Summary

Standardized internal Terraform resource labels for the Foundry account across both modules to reduce cognitive load and eliminate inconsistencies.

### What Changed

| Resource | Foundry-byoVnet (was) | Foundry-byoVnet (now) | Foundry-managedVnet |
|---|---|---|---|
| Foundry account | `ai_foundry` | `foundry` | `foundry` |
| Foundry project | `ai_foundry_project` | `foundry_project` | `foundry_project` |
| Capability host | `ai_foundry_project_capability_host` | `foundry_project_capability_host` | `foundry_project_capability_host` |

**Output names** still use `ai_foundry_` prefix in both modules per Decision #5 (Foundry Output Naming).

In Networking, `random_string.myrandom` was renamed to `random_string.unique` to match both Foundry modules' convention.

### Impact

- **State migration required** for existing byoVnet deployments. Use `terraform state mv` for all three resource labels (`ai_foundry` → `foundry`, `ai_foundry_project` → `foundry_project`, `ai_foundry_project_capability_host` → `foundry_project_capability_host`).
- Networking `random_string.myrandom` → `random_string.unique` also requires `terraform state mv` for existing deployments.
- No impact on Foundry-managedVnet (labels were already correct).
- **Benefit:** Single consistent naming convention across all modules reduces confusion during troubleshooting and documentation.

---

## Variable Naming Conventions (2026-03-30T18:00:00Z)

**Owner:** Donut (Infra Dev)  
**Status:** APPROVED & IMPLEMENTED

### Summary

Renamed 8 PascalCase and mixed-case variables to snake_case to align with Terraform community conventions and improve code consistency.

### Variables Renamed

| Old Name | New Name | Type | Impact |
|---|---|---|---|
| `firewall_SkuName00` | `firewall_sku_name00` | string | 3 references in firewall.tf |
| `firewall_SkuName01` | `firewall_sku_name01` | string | 3 references in firewall.tf |
| `firewall_SkuTier00` | `firewall_sku_tier00` | string | 3 references in firewall.tf, 1 validation |
| `firewall_SkuTier01` | `firewall_sku_tier01` | string | 3 references in firewall.tf, 1 validation |
| `resource_group_name_KV` | `resource_group_name_kv` | string | 3 references in keyvault.tf |
| `create_AiLZ` | `create_ai_lz` | bool | 15+ references across all modules |
| `add_privateDNS00` | `add_private_dns00` | bool | 7 references in dns.tf |
| `add_privateDNS01` | `add_private_dns01` | bool | 7 references in dns.tf |

### Validation Blocks Added

- `firewall_sku_name00`, `firewall_sku_name01` — validates `Standard`, `Premium`
- `firewall_sku_tier00`, `firewall_sku_tier01` — validates `Basic`, `Standard`, `Premium`
- CIDR variables — validates IPv4 CIDR format
- Bastion SKU variables — validates `Basic`, `Standard`

### Description Improvements

Fixed 18 variable descriptions to be unique and descriptive:
- VNet names now indicate region and purpose
- Firewall names specify which region and component
- DNS resolver names clarify region and setup
- Bastion names differentiate by region

### Impact

- **All tfvars files updated** (terraform.tfvars.example and terraform.tfvars.advanced.example in Networking, plus any existing deployments must update variable references).
- **Validation blocks prevent invalid combinations at plan time** rather than failing at apply.
- **Code consistency:** All variables now follow snake_case convention matching Terraform best practices.

---

## Storage Account Configuration Pattern (2026-03-30T18:00:00Z)

**Owner:** Donut (Infra Dev)  
**Status:** APPROVED & IMPLEMENTED

### Summary

Refined storage account configurations across Foundry modules to optimize for redundancy and security.

### Changes

**Foundry-byoVnet (storage.tf):**  
- Changed account replication from `ZRS` (Zone-Redundant Storage) to `LRS` (Locally-Redundant Storage)
- Rationale: Lab/demo environment does not require cross-zone redundancy; LRS reduces cost and complexity

**Foundry-managedVnet (storage.tf):**  
- Added `["AzureServices"]` to `network_rules.bypass` list
- Enables Azure services (Cognitive Search, AI Services, etc.) to authenticate via managed identity without being blocked by the Deny-by-default network policy
- Preserves security: Only Microsoft services can bypass, not arbitrary clients

### Impact

- **Cost reduction** in byoVnet (ZRS → LRS)
- **Enhanced interoperability** in managedVnet (AzureServices bypass allows seamless service integration)
- Both changes align with decision #6 (Local Auth Security Hardening) — services use RBAC and managed identity, not shared keys

### Cross-Module Consistency

Both modules now follow a consistent pattern: LRS/local redundancy for lab environments, explicit bypass rules for managed identity scenarios.

---

## ALZ VNet Refactor — IP Address Allocation & Module Ownership (2026-07-26)

**Owner:** Donut (Infra Dev)  
**Status:** APPROVED & IMPLEMENTED

### Summary

Each Foundry application landing zone module owns its own spoke VNet, subnets, hub connection, and DNS links. The platform Networking module no longer creates or manages AI LZ networking resources. The `create_ai_lz` conditional has been fully removed.

### IP Address Allocation

Non-overlapping `/20` blocks assigned per module:

| Block # | CIDR (Region 0) | Assigned To |
|---------|-----------------|-------------|
| 2 | `172.20.32.0/20` | Foundry-byoVnet |
| 3 | `172.20.48.0/20` | Foundry-managedVnet |

Both modules can be deployed simultaneously against the same vHub without CIDR collision. The allocation table is documented in `docs/ip-addressing.md`.

### Platform-to-App Interface

New Networking outputs consumed by Foundry modules:
- `rg_net00_name` — resource group name
- `add_firewall00` — firewall toggle (drives `internet_security_enabled`)
- `dns_resolver_policy00_id` — DNS policy ID for VNet links
- `dns_inbound_endpoint00_ip` — DNS resolver IP for custom DNS servers

### Impact

- Katia's count-guard bug #3 (`ai_vnet01_dns`) is resolved by resource removal
- Future app LZs can onboard without modifying the Networking module
- Both Foundry modules are fully independent and self-contained for networking
