# Carl — Architecture Lead (Architect)

**Project:** Azure IaC demo/lab (Networking platform LZ + AI Foundry + Container Apps + Fabric ALZ modules)  
**Stack:** Terraform (azurerm, azapi, random), PowerShell, Azure CLI  
**Created:** 2026-03-27

## Summary

Architected platform/application landing zone model for multi-module deployment framework. Designed 4 ALZ modules (Foundry-byoVnet, Foundry-managedVnet, ContainerApps-byoVnet, Fabric-private). Resolved 8+ critical design gates (Bastion+vWAN compatibility, MPE auto-approval, workspace-local KV separation, workspace public access toggle, tenant-level PL deferral, naming convention, DNS zone configuration). Led team through security reviews, cross-module coordination, and decision documentation. Latest work: completed ADR on Fabric-private README review items 2/3/5/6 (2026-07-15).

## Key Decisions (Recent)

- **Bastion + vWAN Routing Intent:** Works despite Microsoft FAQ saying otherwise. Bastion data plane uses public IP directly, doesn't follow spoke's default route. Validated across 8 evidence categories.
- **Fabric ALZ KV separation-of-duties:** Move workspace-local KV from shared Networking RG to Fabric LZ RG. Preserves MPE requirement, eliminates cross-RG orphaned PE problem and 25-connection limit gotcha.
- **Workspace-level private access:** Fabric PE is additive by default (public access remains open). Use `terraform_data` + `local-exec` calling Fabric REST API to set communication policy `inbound.publicAccessRules.defaultAction = "Deny"`. Gives private-only workspace without tenant-wide blast radius.
- **Fabric-private naming:** Renamed from `Fabric-byoVnet` to accurately describe private-connectivity pattern (not VNet injection). Foundry-byoVnet uses VNet injection; Fabric uses managed VNet + spoke PEs.
- **Tenant-level Private Link:** Deferred (out of scope for module). Two-setting combo affecting entire tenant. ARM resources are Terraform-manageable, but settings require Fabric Admin REST API (not ARM). Recommended as manual post-deploy step with tenant-wide impact warning.

## Key Patterns

- Platform/ALZ model: Networking = shared foundation; Foundry/ContainerApps/Fabric = pluggable workloads
- azurerm tagging: `local.common_tags` + explicit per-resource (never `default_tags`)
- Child module pattern (modules/region-hub/) for region-scoped resources — eliminates boolean toggle bugs
- IP addressing: /20 blocks per module, non-overlapping
- DNS: centralized in Networking, spokes link via conditional `enable_dns_link`

## Cross-Team Coordination

- Worked with Donut (code), Mordecai (docs), Katia (validation), SystemAI (security)
- Led decision documentation flow: research → ADR → inbox → decisions.md
- Managed design gates and security review conditions

## Fabric Provider Gotchas (2026-04-28)

During first live deploy of Fabric-private on squad/fabric-alz-impl, Donut identified 5 provider-specific issues. These are architecture-neutral workarounds:

1. **azapi workspace PE** requires `preview = true` for resource type `microsoft.fabric/capacities/workspaces/privateEndpoints`
2. **fabric provider capacity** reference needs explicit UUID lookup (`data.azurerm_resource` with filtering, not direct resource ID)
3. **azurerm diagnostic_setting** removal leaves dangling state unless `enabled_log` blocks are explicitly declared (avoid silent failures)
4. **azapi workspace PE removal** requires careful ordering — destroy PE subnet links before MPE resources
5. **azapi_resource_action** for MPE approval: connection name is non-deterministic; use `endswith()` pattern with `on_failure = "continue"` for graceful handling

**Impact:** No design changes needed. Recommend documenting these in provider version notes if issues persist in future releases. Fixes validated on squad/fabric-alz-impl deployment.

## Learnings

### Fabric workspace-level PE model (2026-07-16)

Fabric supports private links at **two distinct scopes** — tenant-level (`Microsoft.PowerBI/privateLinkServicesForPowerBI`) and workspace-level (`Microsoft.Fabric/privateLinkServicesForFabric`). These are completely different ARM resource types. The workspace-level flow:

1. Fabric admin enables tenant setting "Configure workspace-level inbound network rules" (portal-only, not ARM).
2. Deploy ARM resource `Microsoft.Fabric/privateLinkServicesForFabric@2024-06-01` (location: `global`, binds tenantId + workspaceId).
3. Create standard `azurerm_private_endpoint` targeting that PL service with `subresource_names = ["workspace"]`.
4. DNS zone: `privatelink.fabric.microsoft.com` (already centralized in our Networking module).
5. Optionally deny public access via Fabric REST API `communicationPolicy` endpoint.

**What Donut got wrong on 2026-04-28:** Concluded "Fabric private links are tenant-scoped only" and removed the workspace PE. This conflated the tenant-level PL service (`Microsoft.PowerBI/...`) with the workspace-level PL service (`Microsoft.Fabric/...`). The incorrect comment was left in `fabric.tf` lines 123-127. The workspace was left publicly reachable as a result.

**Fix designed:** ADR `carl-fabric-workspace-pe-fix.md` — additive two-resource fix (azapi PL service + azurerm PE), no existing resources destroyed. Pending Ryan approval.

## Cross-Agent Update — Fabric Workspace-Level PE Fix Deployed (2026-07-17)

**Partner:** Donut (Infrastructure Dev)  
**Branch:** squad/fabric-alz-impl  
**Outcome:** ✅ Workspace PE deployed and verified (IP 172.20.80.5)

Donut successfully implemented the workspace-level PE fix design per the ADR. The corrected pattern is confirmed:
- **Resource type:** `Microsoft.Fabric/privateLinkServicesForFabric@2024-06-01` (azapi provider, location: global)
- **azapi quirk:** `schema_validation_enabled = false` required (bundled schema outdated)
- **PE dependency:** workspace-policy.tf now depends on PE (not bare workspace), ensuring private path is live before deny-public-access fires
- **Scope guardrail:** Tenant-level PE remains out of scope per Ryan directive

All inbox files merged into decisions.md; superseded 2026-04-28 entry marked with full resolution context.

### REST API method/URL drift — recurrence pattern (2026-07-18)

This has happened at minimum twice: an implementer reads a design doc that cites a specific HTTP
method + URL, then writes code using a different method or a slightly different path based on REST
convention intuition. The cited spec is overridden silently.

**Confirmed instance:** `Fabric-private/workspace-policy.tf` (commit `4171dc3`). Design cited
`PUT /v1/workspaces/{id}/networking/communicationPolicy`. Code wrote `PATCH /v1/workspaces/{id}/communicationPolicy`.
Two errors — wrong method, missing `/networking/` path segment. `on_failure = continue` masked
both. Ryan caught it from the portal. Fixed in `0471d6a`.

**Root cause:** Implementers pattern-match REST conventions instead of treating the cited
method+URL as a verbatim contract.

**Remediation:** Created `.squad/skills/rest-api-from-design/SKILL.md` — codifies the rule
(copy verbatim, cite source as a comment, `on_failure = fail` on mutating calls, read-back
validation) and preserves this instance as a concrete prior failure example. Skill confidence:
`medium` (second observation).

## See Also

- `.squad/decisions.md` — All team decisions and approvals
- `.squad/agents/donut/history.md`, `.squad/agents/mordecai/history.md` — Parallel implementation work
- `.squad/skills/rest-api-from-design/SKILL.md` — REST API from design doc enforcement skill


---

## Cross-Agent Notice: REST API from Design Skill (2026-07-18)

**All agents:** A new skill .squad/skills/rest-api-from-design/SKILL.md has been created to prevent recurring REST implementation errors. This affects anyone writing REST calls in Terraform, GitHub Actions, or shell scripts.

**Trigger:** Apply when implementing a REST call whose method + URL appears in a design doc or vendor docs. Key rule: use on_failure = fail on all state-mutating calls (POST/PUT/PATCH/DELETE); never substitute your own HTTP conventions.

**Named prior failure:** Fabric workspace-policy.tf bug (commit 4171dc3) — used PATCH instead of PUT, wrong URL path, on_failure=continue masked the error.

For details, see .squad/skills/rest-api-from-design/SKILL.md.

---

## Next Design Pass Queued


Fabric next design pass ready to spawn. Scope locked in decisions.md: native Lakehouse, three-way network_mode enum (inbound_only / outbound_only / inbound_and_outbound), and storage account upgrades (ADLS Gen 2 + Workspace Identity + Storage Blob Data Contributor) for outbound MPE path. Teardown complete; environment clean. See orchestration-log and session-log for context.

## Learnings

### fabric_workspace identity block — native provider support (2026-07-25)

The `microsoft/fabric` Terraform provider supports workspace identity natively via an `identity` block on `fabric_workspace`:

```hcl
identity = {
  type = "SystemAssigned"
}
```

Read-only outputs: `identity.application_id`, `identity.service_principal_id`. This calls the Fabric REST API `POST /v1/workspaces/{id}/provisionIdentity` internally. No `azapi_resource_action` or `terraform_data` + `local-exec` fallback needed.

Available since provider ~v1.9.x. PR #932 on the provider repo ("Allow workspace identity without capacity_id") confirms active maintenance.

**Implication:** The rest-api-from-design skill is NOT needed for workspace identity provisioning. The provider handles it declaratively.

### fabric_lakehouse — first-class provider resource (2026-07-25)

`fabric_lakehouse` is GA in the `microsoft/fabric` provider. Required: `display_name`, `workspace_id`. Optional: `description`, `configuration.enable_schemas`, `definition` (for bootstrapping metadata). OneLake-backed by default — no external storage configuration needed for a basic lakehouse.

### Entra SP propagation timing for RBAC (2026-07-25)

When a Fabric workspace identity is provisioned, the service principal takes 30-60s to propagate in Entra ID. `azurerm_role_assignment` will fail with "principal not found" if it fires immediately. Mitigation: `time_sleep` (60s) + `principal_type = "ServicePrincipal"` on the role assignment (skips ARM Graph lookup). This pattern applies to any Terraform scenario where a freshly-created SP needs an immediate RBAC assignment.

### network_mode three-way conditional pattern (2026-07-25)

For modules with independent inbound and outbound private connectivity, a three-way enum (`inbound_only`, `outbound_only`, `inbound_and_outbound`) is cleaner than two separate booleans. Separate bools create an invalid fourth state (both false = nothing deployed) that requires a validation block to reject. A single enum with validation avoids invalid combos and reads clearly in tfvars. Derived locals (`deploy_inbound`, `deploy_outbound`) keep the `count` expressions DRY across files.

---

## Fabric Next Round: Design Pass & Implementation Complete (2026-04-29)

**Status:** ✅ Design approved by Ryan; implementation delivered by Donut on squad/fabric-alz-impl (commit 82274ff, not yet pushed).

### Design Decisions Approved

1. **Lakehouse (native provider):** `fabric_lakehouse` resource (GA, first-class in microsoft/fabric provider). Default content_mode remains "none" — lakehouse is opt-in.
2. **network_mode three-way enum:** Replaces `restrict_workspace_public_access` boolean. Values: `inbound_only` (default), `outbound_only`, `inbound_and_outbound`. Gated locals: `deploy_inbound`, `deploy_outbound`.
3. **Workspace identity — always-on:** `identity { type = "SystemAssigned" }` block on `fabric_workspace`. Idempotent, no side effects. Provider handles via native API (no REST fallback).
4. **ADLS Gen 2 upgrade:** `is_hns_enabled = true` on storage account (outbound-only, gated on `deploy_outbound`).
5. **Identity propagation delay:** `time_sleep` (60s) + `principal_type = "ServicePrincipal"` on RBAC assignment to handle Entra ID propagation window.
6. **Provider bumps:** `microsoft/fabric ~> 1.9`, `hashicorp/time ~> 0.12`.

### Implementation Highlights (Donut)

- **Files changed:** config.tf, variables.tf, locals.tf, fabric.tf, storage.tf (new), mpe.tf, workspace-policy.tf, outputs.tf, README.md, terraform.tfvars.example.
- **Safe null-access pattern:** Used `one(resource[*].attribute)` + `try()` for count=0 resources in check blocks and locals.
- **Pre-existing staged changes included:** main.tf comment rename, removed stale check block (related to module evolution).
- **Edge case handling:** depends_on list reference (no [0] indexing); short-circuit assertions in check blocks.
- **Status:** All 6 design asks delivered; ready for code review and merge.

### Cross-Agent Learnings Shared

- Donut confirmed safe patterns for conditional resources with count gating and check blocks.
- Identity propagation timing now documented for future reference.

