# Feature roadmap design

**Date:** 2026-07-23  
**Status:** Approved design, pending final document review

## Purpose

This roadmap prioritizes the next set of features for the Azure Network Platform lab repository. The order favors reusable regional foundations first, followed by the strongest customer and pre-sales scenarios.

The repository remains a collection of independent Terraform root modules. Networking continues to own the platform landing zone, while Foundry, Fabric, AI Gateway, Copilot Studio, Databricks, and AKS remain separate application landing zones with separate state and lifecycles.

## Assumptions and constraints

- Terraform 1.11 or later
- Existing module-specific provider constraints remain unchanged
- Local Terraform state remains the default
- Deployments are short-lived demos, labs, and proofs of concept
- Region 0 is always present; region 1 is conditional
- Networking is deployed before application landing zones
- Private DNS is required for private application landing zones
- Costly resources remain optional or conditional
- Structural refactors may require destroy and redeploy
- State migration and Terraform `moved` blocks are out of scope

The main risks are identity churn, regional blast radius, preview API drift, recurring cost, and limited plan-only coverage. Identity churn is accepted because deployments are routinely destroyed and recreated.

## Prioritization

| Order | Package | Reason |
|---:|---|---|
| 1 | Networking region-1 application landing-zone contract | Small, low-risk prerequisite for every regional workload |
| 2 | Foundry BYO optional data-service bundle | Removes mandatory data-service assumptions before regional refactoring |
| 3 | Foundry BYO VNet multi-region | Highest-value regional workload and the base for AI Gateway |
| 4 | Foundry managed-VNet multi-region | Applies the regional pattern to the second Foundry architecture |
| 5 | Private AI Gateway | Strongest current customer and pre-sales demand |
| 6 | Fabric multi-region | Reuses the regional pattern for independent Fabric estates |
| 7 | Container Apps multi-region | Completes regional support across the existing application landing zones |
| 8 | Copilot Studio private networking | High strategic value, but requires a feasibility spike |
| 9 | Azure Databricks private networking | Strong demo value with more networking and cleanup complexity |
| 10 | AKS application landing zone | Useful and well-supported, but currently the lowest business priority |

Package 1 must complete before the Foundry changes because it replaces the platform-to-ALZ contract used by the current modules. Fabric can begin after package 1, but AI Gateway remains ahead of it because demand is stronger.

Each package receives its own feature design and implementation plan. This roadmap is not an implementation plan for all ten packages.

## Regional platform contract

Networking will add an `alz_regions` output map keyed by `region0` and `region1`.

Each entry will provide:

- `enabled`
- Azure region name and abbreviation
- Networking resource group ID, name, and location
- Virtual hub ID
- Firewall-enabled status
- DNS server IP
- DNS resolver policy ID
- Regional private DNS zone IDs required by application private endpoints

Region 0 is always enabled. Region 1 remains in the map but reports `enabled = false` and null resource values when `create_vhub01 = false`.

The regional scalar outputs will be replaced by `alz_regions`. Package 1 migrates every existing application landing zone to the new map and removes the obsolete region-specific outputs in the same change. The lab does not retain a permanent compatibility layer.

Truly shared outputs, such as the Log Analytics workspace, remain top-level. Private DNS zone IDs move into each regional entry because Networking creates regional Private DNS resources and application private endpoints must use the selected region's zones.

Application landing zones consume this contract through `terraform_remote_state`. Networking does not deploy or own workload resources.

## Workload module pattern

Existing application landing zones remain independent root modules:

- `Foundry-byoVnet/`
- `Foundry-managedVnet/`
- `ContainerApps-byoVnet/`
- `Fabric-private/`

Every application landing zone exposes a `deploy_region1` boolean that defaults to `false`. Region 0 is always deployed. Region 1 deploys only when `deploy_region1 = true` and `alz_regions.region1.enabled = true`.

Networking region 1 being available does not automatically create a second workload region. If an application landing zone sets `deploy_region1 = true` while Networking region 1 is unavailable, a Terraform check fails with a specific prerequisite error.

Each root module derives its selected regions from `alz_regions` and its own `deploy_region1` variable, then composes region-scoped resources internally.

Refactoring existing resources into child modules is allowed to be a breaking upgrade. The README for each affected module will tell users to destroy an existing deployment before adopting the refactored version.

New workloads remain root-level application landing zones with their own state, README, variables, outputs, and cleanup instructions.

## Package definitions

### 1. Networking region-1 contract

Add the `alz_regions` output and document it in `Networking/README.md`. The output must be null-safe when region 1, Firewall, or Private DNS is disabled.

Migrate Foundry BYO VNet, Foundry managed VNet, Container Apps, and Fabric to read their region-0 platform and Private DNS values from `alz_regions`. Remove the superseded region-specific scalar outputs after all current consumers are updated.

This package changes the platform-to-ALZ data contract but does not change deployed workload resource behavior.

### 2. Foundry BYO optional data services

Add a boolean variable named `deploy_agent_data_services`, defaulting to `true`.

When enabled, behavior remains unchanged. The module deploys Azure Storage, Cosmos DB, Azure AI Search, private endpoints, diagnostics, role assignments, project connections, and capability-host references.

When disabled, all three data services and every dependent resource or reference are omitted as one bundle. Independent service toggles are out of scope.

Public Microsoft documentation may lag this Foundry behavior, so the final implementation requires an authenticated Azure deployment test with the variable disabled.

### 3. Foundry BYO VNet multi-region

Deploy one independent Foundry stack in region 0. When `deploy_region1 = true`, deploy a second stack only if Networking region 1 is available. Both stacks use the same model and project configuration in the first milestone.

Each region owns its resource group, spoke VNet, delegated subnet, private-endpoint subnet, Foundry resource, project, model deployment, private endpoints, and regional diagnostics.

Cross-region agent state, synchronized projects, automatic failover, and traffic routing are out of scope.

### 4. Foundry managed-VNet multi-region

Apply the same `deploy_region1` regional composition pattern to `Foundry-managedVnet/`.

Each region has an independent Foundry resource, project, Microsoft-managed agent network, private-endpoint spoke, and model deployment. Shared configuration does not imply shared state or automatic failover.

### 5. Private AI Gateway

Create a separate `AI-Gateway/` application landing zone.

The module deploys one Azure API Management Standard v2 instance in region 0. APIM uses an inbound private endpoint and outbound VNet integration. Public gateway access is disabled after the private endpoint is ready.

AI Gateway exposes `deploy_region1 = false` and consumes a uniform `foundry_regions` output from either Foundry module:

- With `deploy_region1 = false`, APIM configures only the region-0 backend.
- With `deploy_region1 = true`, APIM configures a priority-ranked backend pool with circuit breakers and requires the selected Foundry state to contain region 1.

The region-0 gateway spoke connects to the region-0 vHub. APIM reaches every selected Foundry private endpoint through the platform's vWAN routing and Private DNS.

The first milestone includes:

- Managed-identity authentication to Foundry
- Token and request limits
- Backend health and circuit-breaker behavior
- Application Insights and Log Analytics diagnostics
- Outputs for the private gateway endpoint

One centralized APIM provides a single governed endpoint and keeps lab cost below a two-instance design. It demonstrates Foundry backend failover, not gateway regional high availability.

A second APIM instance, global private routing, semantic cache, API Center, MCP governance, and advanced policy packs are later enhancements.

The design borrows the centralized gateway and multi-region backend pattern from [enterprise-ai-gateway](https://github.com/nicksangeorge/enterprise-ai-gateway), but not its public-network configuration.

### 6. Fabric multi-region

Deploy a Fabric capacity, workspace, spoke VNet, private endpoint, and optional outbound resources in region 0.

The default remains an F2 capacity. A second independent Fabric estate is created only when `deploy_region1 = true` and Networking region 1 is available.

The two Fabric estates are independent. Workspace replication, cross-region shortcuts, shared workspaces, and disaster recovery are out of scope.

### 7. Container Apps multi-region

Apply the same `deploy_region1` regional composition pattern to `ContainerApps-byoVnet/`.

Region 0 retains the existing Container Apps environment, Azure Container Registry, spoke VNet, private endpoints, and selected `app_mode`. When region 1 is enabled for the ALZ, deploy an independent regional stack with the same application mode.

Cross-region application routing, shared registries, and application-level failover are out of scope.

### 8. Copilot Studio private networking

Start with a bounded feasibility and design package that produces a go/no-go recommendation before any deployment code is written.

The package must establish:

- Licensing and tenant prerequisites
- Managed Environment requirements
- Supported Power Platform geography and Azure region pairs
- Enterprise-policy ownership
- Delegated subnet requirements
- Terraform, ARM, and PowerShell automation boundaries
- Deployment and cleanup behavior

Implementation begins only after the spike proves that the design can be repeated reliably in this lab repository.

Any new Copilot Studio landing zone must expose `deploy_region1`, defaulting to `false`. Its feasibility package must determine how the ALZ variable maps to the Power Platform geography and enterprise-policy requirement for one or two Azure regions.

### 9. Azure Databricks private networking

Create an application landing zone for a private Databricks workspace used in Foundry and Databricks integration tests.

The first milestone uses the minimum transit-VNet and workspace-VNet pattern required for private UI/API access and VNet-injected compute. It exposes `deploy_region1`, defaulting to `false`, and creates a second independent workspace stack only when explicitly enabled. Serverless Network Connectivity Configurations and broader data-platform scenarios are added only when the target demo requires them.

Cleanup documentation must cover private endpoints, browser-authentication dependencies, and workspace deletion order.

### 10. AKS application landing zone

Create a cost-controlled private AKS cluster in a dedicated spoke.

The first milestone includes basic observability, an optional sample agent workload, and `deploy_region1 = false`. Enabling region 1 creates a second independent cluster rather than a multi-cluster orchestration layer. Production baseline features such as WAF, complex ingress, multi-region orchestration, and large node pools remain out of scope.

## Cross-stack data flow

Networking publishes `alz_regions` and shared platform outputs.

Both Foundry modules publish the same `foundry_regions` structure. Each enabled region includes:

- Foundry resource ID
- Foundry project ID
- Foundry endpoint
- Model deployment names
- Azure region name and abbreviation

Each application landing zone selects region 0 plus optional region 1 from `alz_regions`. Networking advertises availability; the ALZ's `deploy_region1` variable decides whether the workload uses that availability.

AI Gateway reads the selected Foundry state and Networking state. It validates that every requested Foundry backend exists and that its region is enabled in Networking before configuring APIM.

Fabric and future application landing zones read Networking state directly. They do not consume or modify Foundry resources unless a later integration feature explicitly requires it.

## Safeguards and error handling

Terraform `check` blocks will fail with specific messages when:

- `deploy_region1 = true` but Networking region 1 is unavailable
- AI Gateway requests region 1 but the selected Foundry deployment does not include it
- Required vHub, DNS server, resolver policy, or private DNS outputs are null
- Foundry reports a region that does not match Networking
- AI Gateway receives zero Foundry backends
- An unsupported variable combination would leave dangling resources
- A feature-specific tenant or subscription prerequisite can be checked but is missing

Invalid configurations must fail during planning when Terraform has enough information. Provisioners and scripts must preserve exit codes, dependency ordering, and read-back checks. Errors must not be converted into successful Terraform runs.

## Cost controls

- Networking region 1 remains disabled by default
- Every application landing zone defaults `deploy_region1` to `false`
- Foundry uses existing low-capacity model defaults unless a package design changes them
- Foundry data services remain enabled by default to preserve the current deployment behavior, but can be removed as one bundle
- AI Gateway deploys one APIM instance, not one per Foundry region
- Fabric region 1 creates a second capacity only when both Networking and the Fabric ALZ enable it
- New landing zones use the smallest practical lab SKUs and document recurring cost drivers

## Validation

Run validation from the module being changed:

```powershell
terraform init -backend=false
terraform fmt -check
terraform validate
```

Use authenticated `terraform plan` only when Azure authentication, subscription context, and prerequisite state are available.

Deployment validation must cover:

| Capability | Required cases |
|---|---|
| Foundry BYO | One and two regions with data services, plus one and two regions without data services |
| Foundry managed | One region and two regions |
| AI Gateway | One private backend, two private backends, and forced primary-backend failure |
| Fabric | One independent estate and two independent estates |
| Container Apps | One regional stack and two independent regional stacks for each supported `app_mode` |
| New landing zones | Private connectivity, cleanup, and documented prerequisite checks |

Every multi-region application landing zone must also prove these control cases:

- Networking has two regions and `deploy_region1 = false`: only region 0 is planned.
- Networking has two regions and `deploy_region1 = true`: both workload regions are planned.
- Networking has one region and `deploy_region1 = true`: planning fails with the expected prerequisite message.

For AI Gateway, deployment testing must prove:

- A private client can reach APIM
- APIM can reach every enabled private Foundry endpoint
- Private DNS resolves every enabled endpoint from the APIM integration path
- Managed identity authenticates to every configured Foundry resource
- When `deploy_region1 = true`, a failed or throttled primary backend routes to the secondary backend

This repository has no Terraform test files, TFLint configuration, or CI workflow. Those tools are not added as part of this roadmap.

## Rollback and cleanup

Rollback is destroy and redeploy from the prior configuration. No state migration or `moved` blocks are planned.

Each package must document:

- Application-before-platform destroy order
- Soft-delete purge steps
- Service-specific cleanup dependencies
- Any delay required before Networking can be removed
- How to disable optional cost-bearing resources

## Documentation updates

Each implementation package updates the documentation it owns:

- Root `README.md` for the landing-zone table and deploy/destroy order
- `Networking/README.md` for the platform output contract
- `docs/ip-addressing.md` for new address allocations
- `docs/adding-application-landing-zone.md` if the common template changes
- Module README files for prerequisites, variables, outputs, cost notes, and cleanup

## References

- [Foundry high availability and resiliency](https://learn.microsoft.com/en-us/azure/foundry/how-to/high-availability-resiliency)
- [Foundry Agent Service regions and limits](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/limits-quotas-regions)
- [APIM outbound VNet integration](https://learn.microsoft.com/azure/api-management/integrate-vnet-outbound)
- [APIM inbound private endpoint](https://learn.microsoft.com/azure/api-management/private-endpoint)
- [APIM backends and pools](https://learn.microsoft.com/en-us/azure/api-management/backends)
- [Fabric region availability](https://learn.microsoft.com/en-us/fabric/admin/region-availability)
- [Fabric workspace-level private links](https://learn.microsoft.com/en-us/fabric/security/security-workspace-level-private-links-overview)
- [Copilot Studio network isolation](https://learn.microsoft.com/en-us/microsoft-copilot-studio/admin-network-isolation-vnet)
- [Azure Databricks Private Link](https://learn.microsoft.com/en-us/azure/databricks/security/network/concepts/private-link)
- [Private AKS clusters](https://learn.microsoft.com/en-us/azure/aks/private-clusters)
- [Peer enterprise AI Gateway pattern](https://github.com/nicksangeorge/enterprise-ai-gateway)
