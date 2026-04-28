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

## See Also

- `.squad/decisions.md` — All team decisions and approvals
- `.squad/agents/donut/history.md`, `.squad/agents/mordecai/history.md` — Parallel implementation work
