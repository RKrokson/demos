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

## See Also

- `.squad/decisions.md` — All team decisions and approvals
- `.squad/agents/donut/history.md`, `.squad/agents/mordecai/history.md` — Parallel implementation work
