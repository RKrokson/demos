# Squad Decisions Archive

Old decisions moved from decisions.md to keep active file focused.

### 5. Foundry Module Output Naming Standardization (Carl — Lead/Architect)

**Status:** Approved  
**Date:** 2025-07-25

The two Foundry module output files use inconsistent naming for equivalent resources:

| Concept | Foundry-byoVnet | Foundry-managedVnet |
|---|---|---|
| Foundry account | `ai_foundry_id` | `foundry_id` |
| Foundry project | `ai_foundry_project_id` | `foundry_project_id` |

**Decision:** Standardize on `ai_foundry_` prefix across both modules.

**Rationale:**
1. Matches the product name (Azure AI Foundry)
2. BYO module already uses it consistently
3. Avoids ambiguity — `foundry_id` alone is vague

**Implementation:** Rename internal resources in `Foundry-managedVnet/main.tf` and update its `outputs.tf`. No external consumers exist yet, so this is a zero-cost rename.

**Priority:** Medium — must be done before any downstream automation consumes these outputs.


### 6. Tagging Strategy — locals + explicit per-resource tags (Carl — Lead/Architect)

**Status:** Approved  
**Date:** 2025-07-25

**Context:** Donut's initial implementation used `default_tags` in the provider block. Katia's validation correctly identified this as invalid — `default_tags` is an AWS Terraform provider concept, not supported by azurerm.

**Decision:** Use `local.common_tags` defined in `locals.tf` and apply `tags = local.common_tags` explicitly on every taggable resource.

**Tagging Rules:**

1. **azurerm resources** — add `tags = local.common_tags` to all resources that support the `tags` argument (resource groups, VNets, VMs, NICs, firewalls, bastions, Key Vault, Log Analytics, etc.). Skip resources that don't support tags (subnets, hub connections, diagnostic settings, role assignments, etc.).
2. **azapi_resource** — add `tags = local.common_tags` as a top-level argument on tracked resources only (those with a `location`). Skip child/proxy resources (connections, capabilityHosts, virtualNetworkLinks, outbound rules, managed networks).
3. **Standard tag set:** `environment = "non-prod"`, `managed_by = "terraform"`, `project = "azure-infra-poc"`.

**Impact:**
- Backlog item #6 ("Adopt default_tags strategy") is now resolved with the correct approach.
- Carl (Fix tags implementation) tagged 59 resources across all three modules on 2026-03-30.
- All modules pass `terraform validate`.

**Key Learning:** azurerm provider does not support `default_tags` — always use locals + explicit per-resource tagging.


### 12. Security Assessment — Networking + Foundry Modules (SystemAI)

**Status:** Complete, No Critical Findings  
**Date:** 2025-07-25

**Assessment Scope:** All three modules (Networking platform LZ, Foundry-byoVnet, Foundry-managedVnet) as reference architecture for public deployment.

**Summary:** Codebase demonstrates solid security fundamentals (private endpoints, Entra ID auth, Key Vault, Bastion, no hardcoded secrets). **3 medium findings** and **5 low findings** worth addressing; no critical issues or exposed secrets.

**Medium Severity (Recommend Addressing):**

| ID | Module | Finding | Recommendation |
|----|--------|---------|-----------------|
| M-1 | Networking | Key Vault uses legacy access policies (not RBAC) | Switch to `enable_rbac_authorization = true` + `azurerm_role_assignment` resources |
| M-2 | Networking | Key Vault has no purge protection | Document intentional choice for lab cleanup, or add toggle `enable_purge_protection` |
| M-3 | Networking | No NSGs on shared/app subnets (only Bastion/PE have NSGs) | Add default-deny NSGs with explicit allow rules for Bastion inbound |

**Low Severity (Accepted Risks — Document):**

| ID | Module | Finding | Status |
|----|--------|---------|--------|
| L-1 | Networking | Firewall allow-all rules | Accepted (backlog item #8 tracks hardening) |
| L-2 | Foundry-byoVnet | `disableLocalAuth=false` | Accepted (PG-required for agent proxy) |
| L-3 | Foundry-byoVnet | `networkAcls.defaultAction="Allow"` | Accepted (PG-validated for BYO VNet) |
| L-4 | Networking | VM admin username predictable | Low risk (Bastion eliminates public SSH/RDP exposure) |
| L-5 | Networking | No encryption at host on VMs | Platform SSE sufficient for lab |
| L-6 | All | Local Terraform state | Appropriate for single-operator demos |

**Positive Patterns (Preserve):**
- Private endpoints on all AI services, DNS zone integration
- Entra ID auth preferred; local auth disabled where possible
- Least-privilege RBAC with specific roles
- No hardcoded secrets; random generation + Key Vault storage
- Proper `.gitignore` (tfstate, tfvars, .env excluded)
- Bastion for VM access (no public IPs)
- Storage hardening (TLS 1.2 minimum, shared keys disabled)
- Conditional firewall/outbound handling

**Priority:** Donut should address M-3 (NSGs) as part of next infrastructure sprint. M-1 and M-2 are good-to-fix improvements aligned with Azure best practices.

### 13. PG 15b Reference Comparison — Foundry-byoVnet Delta Analysis (Carl)

**Status:** Complete — High-Confidence Findings  
**Date:** 2025-07-27

**Context:** Post-Phase 1/2/3 revamp deployment of Foundry-byoVnet results in 403 (Cosmos rejects Foundry agent proxy's public IP). Full delta comparison against official Microsoft PG template.

**Critical Deltas (403 Risk):**

| Property | PG Reference | Our Code | Changed in Revamp | Risk |
|----------|---|---|---|---|
| Foundry `networkAcls.defaultAction` | `"Allow"` | `"Deny"` | YES (hardening) | **HIGH** |
| Foundry `disableLocalAuth` | `false` | `true` | YES | **MEDIUM** |
| AI Search `disableLocalAuth` | `false` | `true` | YES | Low (not Cosmos) |
| Cosmos connection `category` | `"CosmosDb"` | `"CosmosDB"` | Unknown | **POSSIBLE** |

**Root Cause Assessment:**

The `networkAcls.defaultAction = "Deny"` change breaks the agent proxy's internal control-plane communication with the Foundry service. The PG template intentionally uses `"Allow"` (with `publicNetworkAccess = "Disabled"`) to permit first-party Azure service access while blocking external public endpoints. Our `"Deny"` blocks this internal path, forcing the proxy to use its public outbound IP → Cosmos DB rejects it (403).

**High-Confidence Fix:**
1. Change `networkAcls.defaultAction` to `"Allow"` in `foundry.tf` (highest confidence — matches PG exactly)
2. If still failing, also change `disableLocalAuth` to `false` on Foundry resource
3. Fix CosmosDB connection category casing to `"CosmosDb"`

**Do NOT change:** Cosmos DB, Storage network_rules, private endpoints, RBAC, capability host — these match PG reference and are not the issue.

**Identical Sections (Verified):** All RBAC roles, subnet delegation, networkInjections, Cosmos properties, private endpoint configs.

