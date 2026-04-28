# Teardown Summary — 2026-07-16
**Author:** Donut (Infra Dev)
**Requested by:** Ryan Krokson
**Purpose:** Full environment teardown for clean Fabric testing slate

---

## Environment State Before Teardown

| Module | Resources in State | Status |
|---|---|---|
| Foundry-byoVnet | 2 (terraform_remote_state + random_string) | Destroyed |
| Foundry-managedVnet | 0 | Skipped |
| Fabric-private | No state file | Skipped |
| ContainerApps-byoVnet | 0 | Skipped |
| Networking | 944 | Destroyed |

## Operations Performed

1. **Foundry-byoVnet destroy** — 1 resource removed (random_string). No Azure resources were deployed. Instant.
2. **Soft-delete check** — `az cognitiveservices account list-deleted` returned empty. No purge needed.
3. **Networking destroy** — 579 resources destroyed in 44.3 minutes total (30 min modtm refresh + 14 min Azure destroy).

## Timing Breakdown (Networking)

- State refresh phase: ~30 min (181 modtm_module_source outbound GitHub calls)
- Azure resource deletion: ~14 min
- vHub destruction: 10m45s (normal)
- vWAN destruction: 12s
- Resource group deletion: 11s
- Total: 44.3 minutes

## Post-Teardown Azure State

**All project resource groups deleted.** Remaining RGs are pre-existing and NOT from this project:

| RG Name | Location | Owner |
|---|---|---|
| Default-ActivityLogAlerts | eastus | Azure platform |
| NetworkWatcherRG | eastus | Azure platform |
| rg-shared00-krok | centralus | Pre-existing (not our naming pattern) |
| rg-arc00-krok | centralus | Pre-existing (not our naming pattern) |
| McapsGovernance | westus2 | Azure governance |

**Environment is clean.** Ready for Fabric testing.

## Key Findings

- No SAL/legionservicelink cleanup needed — Foundry-byoVnet was never deployed to Azure this cycle
- modtm state refresh is the dominant time cost (~30 min), not the Azure destroy (~14 min)
- vHub InternalServerError did NOT occur this cycle
- Subscription: b6b5dea5-81d3-4e4a-85f3-b05266fc6f89 (ME-rykrokso-01)


---

# Decision: Enable Bastion IP-Connect and Native Client by Default

**Author:** Donut (Infra Dev)
**Date:** 2026-07-22
**Status:** Implemented

## Context

Azure Bastion Standard SKU supports two opt-in features that are useful for lab environments:
- ip_connect_enabled — connect to VMs by private IP address (not just resource ID). Enables cross-VNet Bastion scenarios.
- 	unneling_enabled — enables native client support via z network bastion tunnel, z network bastion rdp, and z network bastion ssh CLI commands.

Both features require Standard SKU (not available on Basic or Developer). Our default SKU is already Standard.

## Decision

Set both ip_connect_enabled = true and 	unneling_enabled = true unconditionally on the zurerm_bastion_host.bastion resource in Networking/modules/region-hub/main.tf. A comment notes the Standard SKU requirement.

No conditional gating on the SKU variable — these are lab environments, and the default is Standard. If someone overrides to Basic or Developer, Terraform will surface a clear Azure API error at apply time.

## Impact

- Backward compatible for existing deployments (Terraform will update the Bastion host in-place on next apply).
- Enables Ryan's cross-VNet and native client testing scenarios per Decision #18 (Bastion + vWAN routing intent validation).
- No new variables or outputs needed.

## Files Changed

- Networking/modules/region-hub/main.tf — added ip_connect_enabled and 	unneling_enabled to bastion resource


---


# Decision: Disable Purge Protection on Fabric-private Key Vault

**Date:** 2026-07-14  
**Author:** Donut  
**Requested by:** Ryan  
**Module:** Fabric-private/

## Decision

Set purge_protection_enabled = false on zurerm_key_vault.fabric_kv in Fabric-private/fabric.tf.

## Rationale

This is a lab module that Ryan deploys and tears down repeatedly. Purge protection on a Key Vault enforces a minimum 7-day wait (or requires z keyvault purge) between destroy and re-deploy of the same-named resource. That friction has no benefit in a non-production lab environment.

Soft delete is retained (soft_delete_retention_days = 7) as it is an Azure-enforced minimum and provides a recovery window for accidental deletion during a session.

## Trade-offs

- **Accepted risk:** Deleted secrets are recoverable for 7 days via soft-delete but can be immediately purged by any authorized operator. Acceptable for a lab with no production data.
- **Naming collision:** The KV name includes a andom_string suffix, so collisions across destroy/redeploy cycles are unlikely but not possible. README updated to note z keyvault purge as a targeted fix if a collision occurs.

## Alternatives Considered

- Keep purge protection, document z keyvault purge as mandatory step — rejected as unnecessary friction for a lab lifecycle.
- Import soft-deleted KV on redeploy — rejected as operationally complex for no benefit.

---

# Decision: Fabric Admin Tenant-Settings API Contract

**Author:** Donut (Infrastructure Dev)  
**Date:** 2026-07-15  
**Scope:** Fabric-private/configure-fabric-tenant-settings.ps1 and any future Fabric admin tooling

## Context

configure-fabric-tenant-settings.ps1 was returning rrorCode: "UnknownError" on every API call. Investigation against the Microsoft Learn Fabric Admin REST API confirmed two wrong assumptions baked in from initial authorship. This decision records the corrected contract so future infra work doesn't repeat the same mistakes.

## Corrected API Contract

### Read — LIST endpoint (only option)

`
GET https://api.fabric.microsoft.com/v1/admin/tenantsettings
`

- Returns an object with a 	enantSettings array; each element has settingName, nabled, and related fields.
- **No per-setting GET exists.** Calls to GET .../tenantsettings/{settingName} return an error (UnknownError / 404). The script was doing this per-setting GET in a loop — that was the read bug.
- **Pattern:** Call LIST once, cache into a hashtable keyed by settingName, look up each desired setting in the cache. This is also more efficient (one API call instead of N).

### Write — POST /update (not PATCH)

`
POST https://api.fabric.microsoft.com/v1/admin/tenantsettings/{settingName}/update
Body: { "enabled": true }
`

- The script was issuing PATCH .../tenantsettings/{settingName} (no /update suffix). That verb+path combination does not exist and silently returns UnknownError.
- Body shape is preserved — { "enabled": <bool> } is correct; only the verb and URL suffix changed.

### Required permissions

- Caller must be assigned the **Fabric Administrator** role in the tenant.
- OAuth scope: Tenant.ReadWrite.All (Fabric Admin API audience: https://api.fabric.microsoft.com).
- The existing z account get-access-token --resource https://api.fabric.microsoft.com auth flow is correct — do not change it.

## Setting-Name Validation Pattern

Hardcoded setting names in admin scripts must be validated against the LIST response before attempting any write. If a name is absent from the API's 	enantSettings array, the script must:

1. Emit a warning showing the **expected name** (what the script assumed).
2. Emit a warning showing the **full list of names** the API actually returned.
3. **Skip** rather than attempting a write that will fail silently.

This guards against API-side renames without requiring manual investigation to diagnose failures.

## Error Message Standard

Every catch block that wraps a Fabric Admin API call must surface all three of:

- HTTP status code: $_.Exception.Response.StatusCode.value__
- Response body: $_.ErrorDetails.Message
- URL that was called (log the variable, not a templated string)

The old Write-Warning "Failed to enable : " pattern produced opaque System.Net.WebException strings with no actionable signal.

## Files Changed

- Fabric-private/configure-fabric-tenant-settings.ps1 — all four issues fixed; auth flow unchanged; setting list unchanged; script invocation unchanged.

## Do Not

- Do not add a per-setting GET before or after the LIST call — it will fail.
- Do not use PATCH against /v1/admin/tenantsettings/{name} — use POST to .../update.
- Do not change the token acquisition (z account get-access-token) — it is correct.

---

# Decision Drop: Fabric Admin Access Model & Prerequisites Restructure

**Author:** Mordecai  
**Date:** 2026-07-15  
**Status:** Implemented  
**Scope:** Fabric-private README — Prerequisites section  

## Problem Statement

Ryan discovered two silent-failure gates that must be met BEFORE any Fabric tenant configuration (script or manual) will work:

1. Azure RBAC roles (Subscription Owner, Contributor, etc.) grant **zero** Fabric admin authority
2. Even with the correct Entra directory role, tenant-settings API returns nothing until Fabric is provisioned on the tenant

These gates were undocumented in the README, leading users to troubleshoot phantom API failures or hang on script execution without clear guidance.

## Decision: Gate-Based Prerequisites Structure

Restructured Fabric-private README Prerequisites section to document the gate order explicitly:

### Gate 1: Entra Directory Role
- User must hold one of: Global Administrator, Power Platform Administrator, or Fabric Administrator (Entra directory role, not Azure RBAC)
- Document this clearly: Azure RBAC is insufficient
- Link to Entra admin center for role assignment
- Allow 5–15 minutes for role propagation

### Gate 2: Fabric Tenant Provisioning
- Tenant must have Fabric provisioned (Free signup, trial, or F-SKU capacity)
- Provide three options with guidance (Free is fastest)
- Verification step: user can navigate to https://app.fabric.microsoft.com/admin-portal

### Gate 3: Enable Tenant Settings
- Four tenant-level settings (existing content preserved)
- Run script or configure manually via portal
- Re-register Microsoft.Fabric provider after toggling inbound network rules

## Rationale

- **Silent failure mode:** Errors returned are empty/null, not explicit about missing gates
- **Two independent prerequisites:** Role assignment and tenant provisioning are unrelated; both must be true
- **User experience:** Clear gate order + verification step (can access admin portal?) prevents troubleshooting dead-ends
- **Future-proof:** Any Fabric infrastructure automation must document this gate order

## Implementation

- Updated Fabric-private README lines ~24–51
- Kept existing four tenant settings; re-framed under Gate 3
- Added links to Entra admin center and Free signup
- Preserved tone (concise, lab-oriented, no marketing)
- No other README sections modified per scope

## Impact

- All future Fabric ALZ documentation and scripts must reference this gate order in prerequisites
- Any troubleshooting guide or FAQ should address the silent-failure modes (empty API response, script hangs)



# Decision: Fabric Admin API — Verified Tenant Setting Name Mappings

**Author:** Donut (Infra Dev)
**Date:** 2026-07-15
**Status:** Resolved — script updated, SKILL.md updated

---

## Context

configure-fabric-tenant-settings.ps1 was fixed last round to use the correct LIST + POST pattern against the Fabric Admin REST API. However, all four hardcoded settingName values were wrong — none matched the 161 names the API actually returns. The script ran cleanly but did nothing useful (all four skipped with "name not found" warnings).

---

## Research Method

1. Retrieved all 161 settingName values from live API response (via script run by Ryan).
2. Cross-referenced against Microsoft Learn: learn.microsoft.com/fabric/admin/tenant-settings-index, service-admin-portal-developer, service-admin-portal-microsoft-fabric-tenant-settings, service-admin-portal-advanced-networking, and the Fabric Admin REST API reference (/rest/api/fabric/admin/tenants/list-tenant-settings).

---

## Verified Intent → API Name Mappings

| Intent (README / script) | Wrong name (was) | Correct settingName | Portal path |
|---|---|---|---|
| "Users can create Fabric items" (the Microsoft Fabric admin switch) | UsersCanCreateFabricItems | **FabricGAWorkloads** | Tenant settings → Microsoft Fabric |
| "Configure workspace-level inbound network rules" | WorkspaceLevelPrivateEndpointSettings | **WorkspaceBlockInboundAccess** | Tenant settings → Advanced networking |
| "Service principals can call Fabric public APIs" | ServicePrincipalsCanCallFabricPublicAPIs | **ServicePrincipalAccessGlobalAPIs** | Tenant settings → Developer settings |

---

## Intents With No API Equivalent

| Intent | Status | Explanation |
|---|---|---|
| "Microsoft Fabric" (master toggle — was EnableFabric) | ❌ Removed from script | "Microsoft Fabric" is a **section header** in the admin portal, not a distinct API setting. Its only toggle is "Users can create Fabric items" (FabricGAWorkloads). There is no EnableFabric settingName in the Fabric Admin API. The script now has one entry (FabricGAWorkloads) that covers both original intents 1 and 3. |

---

## Key Insight: "Microsoft Fabric" = "Users can create Fabric items"

From learn.microsoft.com/fabric/admin/fabric-switch:
> "When you enable Microsoft Fabric using the tenant setting, users can create Fabric items."
> "In your tenant, you can enable Microsoft Fabric... navigate to the tenant settings and in *Microsoft Fabric*, expand **Users can create Fabric items**."

The admin portal UI has:
- **Section:** "Microsoft Fabric"
- **Toggle:** "Users can create Fabric items"

These are one single setting. The API settingName is FabricGAWorkloads. The original script had two entries (EnableFabric and UsersCanCreateFabricItems) that both tried to manage the same underlying setting — but both with wrong names.

---

## Files Changed

- Fabric-private/configure-fabric-tenant-settings.ps1 — corrected all three remaining settings, removed duplicate EnableFabric entry, added comments
- Fabric-private/README.md — updated Gate 3 to use API names alongside portal names; clarified "Microsoft Fabric" is a section header
- .squad/skills/fabric-admin-api/SKILL.md — added verified mappings table, wrong-names table, and corrected canonical example

---

### 2026-04-28: User correction — Fabric workspace-level private link IS supported (SUPERSEDED)
**By:** Ryan Krokson (via Copilot)
**Status:** SUPERSEDED by 2026-07-16 fix deployment
**Original claim:** "Fabric private links are tenant-scoped only."
**Correction:** During the 2026-04-28 Fabric-private deploy, Donut removed the workspace-level PE concluding this. This is incorrect. Microsoft documents a supported workspace-level private link flow: https://learn.microsoft.com/en-us/fabric/security/security-workspace-level-private-links-set-up — including a "deny public access" step that secures the workspace. The current deployment was reachable from the public internet because this configuration was missing.
**Resolution:** Workspace-level PE now correctly deployed 2026-07-16 using `Microsoft.Fabric/privateLinkServicesForFabric` + `azurerm_private_endpoint` with deny-public-access policy (see carl-fabric-workspace-pe-fix & donut-fabric-workspace-pe-deployed entries below).

---

### 2026-07-16: Scope directive — Fabric private link is workspace-level ONLY
**By:** Ryan Krokson (via Copilot)
**What:** Tenant-level Fabric private link is explicitly out of scope. The Fabric-private LZ enables and configures workspace-level private link only. Any future design or implementation work must NOT introduce tenant-level PE configuration, tenant admin private link toggles, or `Microsoft.PowerBI/privateLinkServicesForPowerBI` resources.
**Why:** User-confirmed scope decision — reinforces the workspace-level fix design without expanding into tenant-level territory.

---

# ADR: Fabric Workspace-Level Private Endpoint — Fix Design

**Author:** Carl (Lead/Architect)
**Date:** 2026-07-16
**Status:** Approved & Deployed
**Reverses:** Incorrect decision from 2026-04-28 ("Fabric private links are tenant-scoped only")
**Corrected by:** Ryan Krokson via `copilot-directive-fabric-workspace-pe-correction.md`

## 1. Doc-Grounded Summary: Workspace-Level Private Link Model

Microsoft Fabric supports private links at **two scopes**: tenant-level and workspace-level. The workspace-level flow allows per-workspace network isolation without affecting the entire tenant.

### How it works (from docs)

**Source:** [Set up and use workspace-level private links](https://learn.microsoft.com/en-us/fabric/security/security-workspace-level-private-links-set-up)

1. **Tenant prerequisite:** A Fabric administrator must enable the tenant setting **"Configure workspace-level inbound network rules"** (Step 0 in the docs — listed under Prerequisites). Without this, the feature is unavailable. This is a tenant admin portal toggle, not an ARM resource.

2. **Resource provider registration:** The `Microsoft.Fabric` resource provider must be re-registered in the Azure subscription that will host the private link service and private endpoint. This is a one-time step per subscription.

3. **Private Link Service (ARM resource):** Deploy an ARM resource of type `Microsoft.Fabric/privateLinkServicesForFabric` (API version `2024-06-01`). This is a **global** resource (location: `global`) that binds a tenant ID + workspace ID pair. It acts as the "anchor" that the private endpoint targets.
   - ARM template from docs:
     ```json
     {
       "type": "Microsoft.Fabric/privateLinkServicesForFabric",
       "apiVersion": "2024-06-01",
       "name": "<resource-name>",
       "location": "global",
       "properties": {
         "tenantId": "<tenant-id>",
         "workspaceId": "<workspace-id>"
       }
     }
     ```

4. **Private Endpoint:** Create a standard Azure private endpoint targeting the above resource. Key parameters:
   - **Resource type:** `Microsoft.Fabric/privateLinkServicesForFabric`
   - **Target sub-resource (group_id):** `workspace`
   - **DNS zone:** `privatelink.fabric.microsoft.com`
   - The docs note that **at least 10 IP addresses** should be reserved per workspace PE (currently 5 IPs are allocated per PE).

5. **Deny public access (optional but required for our use case):** Set the workspace communication policy via the Fabric data-plane REST API:
   ```
   PUT https://api.fabric.microsoft.com/v1/workspaces/{workspaceID}/networking/communicationPolicy
   Body: {"inbound":{"publicAccessRules":{"defaultAction":"Deny"}}}
   ```
   This takes up to **30 minutes** to take effect per Microsoft docs.

**Source:** [Private links for Fabric tenants (overview)](https://learn.microsoft.com/en-us/fabric/security/security-private-links-overview) — provides context on tenant-level vs workspace-level scoping and limitations.

### Critical distinction: This is NOT the same as tenant-level private link

Tenant-level private link uses `Microsoft.PowerBI/privateLinkServicesForPowerBI` and affects **all** workspaces. Workspace-level uses `Microsoft.Fabric/privateLinkServicesForFabric` and targets a **single workspace**. These are completely different ARM resource types. Donut's original error was conflating these two.

## 2. Terraform Implementation Plan

### Provider strategy

| Component | Provider | Resource type | Why |
|---|---|---|---|
| Private Link Service (anchor) | **azapi** | `Microsoft.Fabric/privateLinkServicesForFabric@2024-06-01` | No `azurerm` resource exists for this type. `azapi` is the only declarative option. |
| Private Endpoint | **azurerm** | `azurerm_private_endpoint` | Standard PE pattern, consistent with `pe_fabric_kv` already in `fabric.tf`. `group_id` = `workspace`. |
| DNS zone group on PE | **azurerm** (inline) | `private_dns_zone_group` block on the PE | Links to Networking's `privatelink.fabric.microsoft.com` zone. |
| Deny public access | **terraform_data + local-exec** | Fabric REST API | Already implemented in `workspace-policy.tf`. No changes needed — just needs the PE to exist first. |

### Where the PE lands

The private endpoint goes into the **existing `pe_subnet`** in the Fabric spoke VNet (`azurerm_subnet.pe_subnet`). This is the same subnet hosting the KV PE. The /24 subnet (256 IPs) has plenty of room for the 5 IPs the workspace PE allocates.

### DNS zone

Zone: `privatelink.fabric.microsoft.com`
- Already created by the **Networking** module (centralized DNS pattern).
- Already exposed as `dns_zone_fabric_id` output.
- Already validated by `check "fabric_dns_zone_present"` in `main.tf`.
- **No new DNS zone needed.** The PE's `private_dns_zone_group` will reference `data.terraform_remote_state.networking.outputs.dns_zone_fabric_id`.

### Dependency chain

```
azurerm_fabric_capacity → fabric_workspace → azapi_resource (PL service) → azurerm_private_endpoint (workspace PE) → terraform_data (deny public access)
```

The existing `workspace-policy.tf` already has `depends_on = [fabric_workspace.workspace]`. Donut must update this to depend on the **workspace PE** instead, ensuring the private path is live before public access is denied.

## 3. Touch List (files Donut will modify or create, in order)

| # | File | Action | What changes |
|---|---|---|---|
| 1 | `fabric.tf` | **Modify** | Remove the incorrect comment block. Add: (a) `azapi_resource` for `Microsoft.Fabric/privateLinkServicesForFabric@2024-06-01` — global resource, binds tenant_id + workspace_id; (b) `azurerm_private_endpoint` targeting the PL service with `subresource_names = ["workspace"]`, landing in `pe_subnet`, with `private_dns_zone_group` referencing `dns_zone_fabric_id`. |
| 2 | `workspace-policy.tf` | **Modify** | Update `depends_on` from `fabric_workspace.workspace` to the new workspace PE resource. This ensures the private inbound path is live before public deny takes effect. |
| 3 | `variables.tf` | **No change expected** | `restrict_workspace_public_access` already defaults to `true`. No new variables needed. |
| 4 | `outputs.tf` | **Modify** | Add outputs: `workspace_private_link_service_id`, `workspace_private_endpoint_id`, `workspace_private_endpoint_ip`. |
| 5 | `main.tf` | **No change expected** | `check "fabric_dns_zone_present"` already validates the DNS zone. |
| 6 | `README.md` | **Modify** | Document the workspace PE, tenant prerequisite, and the "deny public access" flow. |

## 4. Recommended Approach

Deploy the workspace-level private endpoint as a two-resource addition to `fabric.tf`: an `azapi_resource` for the `Microsoft.Fabric/privateLinkServicesForFabric` anchor (global, ARM-managed) and a standard `azurerm_private_endpoint` with `group_id = "workspace"` landing in the existing PE subnet, DNS-linked to the Networking module's `privatelink.fabric.microsoft.com` zone. Then update `workspace-policy.tf`'s `depends_on` to target the PE (not the bare workspace), ensuring the private path is live before public access is denied. This is a surgical, additive fix.

---

# Decision: Fabric Workspace-Level Private Endpoint — Deployed

**Author:** Donut (Infra Dev)
**Date:** 2026-07-17
**Branch:** squad/fabric-alz-impl
**Status:** Deployed and verified

## What Was Deployed

Workspace-level private endpoint for the Fabric-private ALZ, as designed in the ADR above and approved per scope directives.

### Resources added to `Fabric-private/`

| Resource | Name | Notes |
|---|---|---|
| `azapi_resource.fabric_private_link_service` | `fabric-pls-3886` | `Microsoft.Fabric/privateLinkServicesForFabric@2024-06-01`, location: global, binds tenant + workspace |
| `azurerm_private_endpoint.pe_fabric_workspace` | `fabric-workspace-pe-3886` | Lands in `pe_subnet`, DNS: `privatelink.fabric.microsoft.com`, subresource: `workspace` |

**PE Private IP:** `172.20.80.5`

### Files changed

| File | Change |
|---|---|
| `Fabric-private/fabric.tf` | Removed wrong comment block. Added `azapi_resource.fabric_private_link_service` + `azurerm_private_endpoint.pe_fabric_workspace`. Added `schema_validation_enabled = false` to azapi resource. |
| `Fabric-private/workspace-policy.tf` | Updated `depends_on` from `fabric_workspace.workspace` → `azurerm_private_endpoint.pe_fabric_workspace`. |
| `Fabric-private/outputs.tf` | Added `workspace_private_link_service_id`, `workspace_private_endpoint_id`, `workspace_private_endpoint_ip`. |
| `Fabric-private/README.md` | Added 30-min propagation callout. Updated Outputs table. |

### Terraform plan summary

- **3 added:** `fabric_private_link_service`, `pe_fabric_workspace`, `approve_mpe_storage` (drift)
- **1 changed:** `azurerm_storage_account.lab_storage` (drift)
- **1 destroyed:** `approve_mpe_storage` replacement (drift)
- **No workspace replacement.** `fabric_workspace.workspace` unchanged.

### Apply outcome

Success. Resources created cleanly:
- `azapi_resource.fabric_private_link_service`: created in 24s
- `azurerm_private_endpoint.pe_fabric_workspace`: created in 56s

## Verification

- `workspace_private_endpoint_ip = 172.20.80.5`
- DNS zone `privatelink.fabric.microsoft.com` linked via `private_dns_zone_group`
- `workspace-policy.tf` `depends_on` updated
- Propagation of `defaultAction: Deny` can take up to 30 min per Microsoft docs

## Key Fix: Wrong Decision Reversed

The 2026-04-28 deployment incorrectly concluded "Fabric private links are tenant-scoped only." This fix corrects the record. `Microsoft.Fabric/privateLinkServicesForFabric` is a real, workspace-scoped ARM resource type.

**azapi quirk documented:** `schema_validation_enabled = false` required because this resource type is not yet in the azapi bundled schema. See `.squad/skills/fabric-workspace-private-link/SKILL.md` for the pattern.


---

### 2026-04-28T23:53Z: Fabric next-round scope clarifications

**By:** Ryan (via Copilot)

**Context:** Pre-design brief for Carl's next design pass on Fabric-private. Scope confirmed before teardown completes.

**Decisions:**

1. **Lakehouse:** Add a **native Fabric Lakehouse** (OneLake-backed, `fabric_lakehouse` resource) inside the deployed workspace. NOT a shortcut to external ADLS Gen 2.

2. **Network mode conditional:** Three-way enum `network_mode`:
   - `inbound_only` — **default.** Workspace PE + communicationPolicy (deny public). No MPEs.
   - `outbound_only` — MPEs to storage/etc. only. No workspace PE. Workspace remains publicly reachable. **Niche / demo-only** scenario: customer is OK with public Fabric but needs to reach a private Azure resource.
   - `inbound_and_outbound` — both directions.
   - README must document `outbound_only` use case so future-self knows why it exists.

3. **Storage account upgrades for outbound (MPE) path:**
   - Storage account becomes ADLS Gen 2 (`is_hns_enabled = true`).
   - Enable Fabric **Workspace Identity** on the workspace.
   - Assign **Storage Blob Data Contributor** to the workspace identity SP on the storage account.
   - Shortcut creation is **out of scope** — Ryan will set up the shortcut manually. We're just enabling the prerequisites.

**Sequencing:** Carl designs first → Donut implements → Ryan validates. Hold until teardown completes.

