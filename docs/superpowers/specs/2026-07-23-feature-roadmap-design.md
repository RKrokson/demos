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
| 7 | Copilot Studio private networking | High strategic value, but requires a feasibility spike |
| 8 | Azure Databricks private networking | Strong demo value with more networking and cleanup complexity |
| 9 | AKS application landing zone | Useful and well-supported, but currently the lowest business priority |

Packages 1 and 2 are independent and can be implemented in parallel. Fabric can begin after package 1, but AI Gateway remains ahead of it because demand is stronger.

Each package receives its own feature design and implementation plan. This roadmap is not an implementation plan for all nine packages.

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

Region 0 is always enabled. Region 1 remains in the map but reports `enabled = false` and null resource values when `create_vhub01 = false`.

Existing scalar outputs remain available for backward compatibility. Shared outputs such as the Log Analytics workspace and private DNS zone IDs remain top-level outputs.

Application landing zones consume this contract through `terraform_remote_state`. Networking does not deploy or own workload resources.

## Workload module pattern

Existing application landing zones remain independent root modules:

- `Foundry-byoVnet/`
- `Foundry-managedVnet/`
- `Fabric-private/`

Each root module derives its enabled regions from `alz_regions` and composes region-scoped resources internally. Region 0 is always deployed. Region 1 follows the Networking state.

Refactoring existing resources into child modules is allowed to be a breaking upgrade. The README for each affected module will tell users to destroy an existing deployment before adopting the refactored version.

New workloads remain root-level application landing zones with their own state, README, variables, outputs, and cleanup instructions.

## Package definitions

### 1. Networking region-1 contract

Add the `alz_regions` output and document it in `Networking/README.md`. The output must be null-safe when region 1, Firewall, or Private DNS is disabled.

This package does not change existing Networking resources or application landing zones.

### 2. Foundry BYO optional data services

Add a boolean variable named `deploy_agent_data_services`, defaulting to `true`.

When enabled, behavior remains unchanged. The module deploys Azure Storage, Cosmos DB, Azure AI Search, private endpoints, diagnostics, role assignments, project connections, and capability-host references.

When disabled, all three data services and every dependent resource or reference are omitted as one bundle. Independent service toggles are out of scope.

Public Microsoft documentation may lag this Foundry behavior, so the final implementation requires an authenticated Azure deployment test with the variable disabled.

### 3. Foundry BYO VNet multi-region

Deploy one independent Foundry stack for each enabled region. Both stacks use the same model and project configuration in the first milestone.

Each region owns its resource group, spoke VNet, delegated subnet, private-endpoint subnet, Foundry resource, project, model deployment, private endpoints, and regional diagnostics.

Cross-region agent state, synchronized projects, automatic failover, and traffic routing are out of scope.

### 4. Foundry managed-VNet multi-region

Apply the same regional composition pattern to `Foundry-managedVnet/`.

Each region has an independent Foundry resource, project, Microsoft-managed agent network, private-endpoint spoke, and model deployment. Shared configuration does not imply shared state or automatic failover.

### 5. Private AI Gateway

Create a separate `AI-Gateway/` application landing zone.

The module deploys one Azure API Management Standard v2 instance in region 0. APIM uses an inbound private endpoint and outbound VNet integration. Public gateway access is disabled after the private endpoint is ready.

AI Gateway consumes a uniform `foundry_regions` output from either Foundry module:

- With one enabled Foundry region, APIM configures one backend.
- With two enabled Foundry regions, APIM configures a priority-ranked backend pool with circuit breakers.

The region-0 gateway spoke connects to `vhub00`. APIM reaches both Foundry private endpoints through the platform's vWAN routing and Private DNS.

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

Deploy a separate Fabric capacity, workspace, spoke VNet, private endpoint, and optional outbound resources in each enabled region.

The default remains an F2 capacity. Region 1 creates a second F2 capacity only when Networking region 1 is enabled.

The two Fabric estates are independent. Workspace replication, cross-region shortcuts, shared workspaces, and disaster recovery are out of scope.

### 7. Copilot Studio private networking

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

### 8. Azure Databricks private networking

Create an application landing zone for a private Databricks workspace used in Foundry and Databricks integration tests.

The first milestone uses the minimum transit-VNet and workspace-VNet pattern required for private UI/API access and VNet-injected compute. Serverless Network Connectivity Configurations and broader data-platform scenarios are added only when the target demo requires them.

Cleanup documentation must cover private endpoints, browser-authentication dependencies, and workspace deletion order.

### 9. AKS application landing zone

Create a cost-controlled private AKS cluster in a dedicated spoke.

The first milestone includes basic observability and an optional sample agent workload. Production baseline features such as WAF, complex ingress, multi-region orchestration, and large node pools remain out of scope.

## Cross-stack data flow

Networking publishes `alz_regions` and shared platform outputs.

Both Foundry modules publish the same `foundry_regions` structure. Each enabled region includes:

- Foundry resource ID
- Foundry project ID
- Foundry endpoint
- Model deployment names
- Azure region name and abbreviation

AI Gateway reads the selected Foundry state and Networking state. It validates that every enabled Foundry region exists and is enabled in Networking before configuring backends.

Fabric and future application landing zones read Networking state directly. They do not consume or modify Foundry resources unless a later integration feature explicitly requires it.

## Safeguards and error handling

Terraform `check` blocks will fail with specific messages when:

- Region 1 is requested by a workload but is unavailable in Networking
- Required vHub, DNS server, resolver policy, or private DNS outputs are null
- Foundry reports a region that does not match Networking
- AI Gateway receives zero Foundry backends
- An unsupported variable combination would leave dangling resources
- A feature-specific tenant or subscription prerequisite can be checked but is missing

Invalid configurations must fail during planning when Terraform has enough information. Provisioners and scripts must preserve exit codes, dependency ordering, and read-back checks. Errors must not be converted into successful Terraform runs.

## Cost controls

- Networking region 1 remains disabled by default
- Foundry uses existing low-capacity model defaults unless a package design changes them
- Foundry data services remain enabled by default for compatibility, but can be removed as one bundle
- AI Gateway deploys one APIM instance, not one per Foundry region
- Fabric region 1 creates a second capacity only when the platform and Fabric region are enabled
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
| New landing zones | Private connectivity, cleanup, and documented prerequisite checks |

For AI Gateway, deployment testing must prove:

- A private client can reach APIM
- APIM can reach every enabled private Foundry endpoint
- Private DNS resolves every enabled endpoint from the APIM integration path
- Managed identity authenticates to both Foundry resources
- A failed or throttled primary backend routes to the secondary backend

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
