# Foundry BYO optional data services

**Date:** 2026-07-31  
**Status:** Approved design, pending implementation plan

## Purpose

This is package 2 of the feature roadmap. It adds one variable to `Foundry-byoVnet/` that controls whether the module deploys its own agent data services.

Today the module always deploys Azure Storage, Cosmos DB, and Azure AI Search, together with their private endpoints, project connections, role assignments, and diagnostic settings. This design makes that whole set optional, so the module can also run with Microsoft-managed agent data storage.

The roadmap places this work before the multi-region Foundry packages so that regional composition does not have to assume the data services exist.

## Scope

Only `Foundry-byoVnet/` changes. No other landing zone, platform output, or shared document is affected.

## Variable

`deploy_agent_data_services` is a bool with a default of `true`. At the default, the deployed resources and their behavior are identical to the current module.

The value is chosen at deploy time. Capability hosts cannot be updated in place, so changing the value on a live deployment is not supported. Destroy the deployment first, then redeploy.

## Gated resources

When the variable is false, 23 resources are not created. Each one carries `count = var.deploy_agent_data_services ? 1 : 0`, and references to them are indexed.

| File | Resources |
|---|---|
| `Foundry-byoVnet/storage.tf` | Storage account and its private endpoint |
| `Foundry-byoVnet/cosmosdb.tf` | Cosmos DB account and its private endpoint |
| `Foundry-byoVnet/aisearch.tf` | AI Search service and its private endpoint |
| `Foundry-byoVnet/project.tf` | `conn_cosmosdb`, `conn_storage`, `conn_aisearch`, `wait_rbac` |
| `Foundry-byoVnet/rbac.tf` | All six role assignments, including the two data plane assignments |
| `Foundry-byoVnet/diagnostics.tf` | The seven Cosmos DB, AI Search, and Storage diagnostic settings |

The `depends_on` chains need no edits. Terraform accepts references to resources whose count is zero, so the sequential private endpoint chain and the capability host dependency list resolve to empty lists.

## Unchanged resources

These are deployed in both modes:

- The Foundry account, including `networkInjections` with `scenario = "agent"` and `useMicrosoftManagedNetwork = false`
- The model deployment
- The Foundry private endpoint
- The Foundry project and `wait_project_identities`
- Application Insights and its project connection
- Diagnostic settings for the Foundry account, the project, and the NSG
- The spoke VNet, both subnets, the NSG, and the virtual hub connection

The module stays a bring-your-own virtual network deployment in both modes.

## Capability host

`caphostproj` is created in both modes. Only its request body changes.

With data services enabled, the body is unchanged from today. With them disabled, the body carries `capabilityHostKind` and nothing else:

```hcl
body = {
  properties = merge(
    { capabilityHostKind = "Agents" },
    var.deploy_agent_data_services ? {
      vectorStoreConnections   = [azapi_resource.ai_search[0].name]
      storageConnections       = [azurerm_storage_account.storage_account[0].name]
      threadStorageConnections = [azurerm_cosmosdb_account.cosmosdb[0].name]
    } : {}
  )
}
```

The three connection properties are omitted rather than set to empty arrays. Agent conversation history, file uploads, and vector data are then held in Microsoft-managed storage.

No account level capability host is declared. Azure creates that resource, and this module must not manage it.

## Outputs

`storage_account_id`, `cosmosdb_account_id`, and `ai_search_id` return null when the data services are disabled:

```hcl
output "storage_account_id" {
  description = "The ID of the Storage Account, or null when agent data services are disabled"
  value       = one(azurerm_storage_account.storage_account[*].id)
}
```

`resource_group_id`, `ai_foundry_id`, and `ai_foundry_project_id` do not change.

## Documentation

`Foundry-byoVnet/README.md` gains the variable in its variables table, plus a short description of what the disabled mode deploys.

`Foundry-byoVnet/terraform.tfvars.example` gains a commented entry for the variable.

The root `README.md`, `docs/ip-addressing.md`, and `docs/adding-application-landing-zone.md` do not change. The landing zone table, deploy and destroy order, address allocations, and the Foundry soft delete purge step are all unaffected.

## Validation

Run static validation from the module folder:

```powershell
Set-Location (Join-Path (git rev-parse --show-toplevel) 'Foundry-byoVnet')
terraform init -backend=false
terraform fmt -check
terraform validate
```

`terraform validate` checks every expression regardless of the count value, so indexing mistakes in either branch are caught.

Check formatting across the repository from the root:

```powershell
Set-Location (git rev-parse --show-toplevel)
terraform fmt -check -recursive
```

An authenticated `terraform plan` in each mode confirms the resource counts. The plan with the variable disabled contains 23 fewer resources than the plan with it enabled.

## Completion gate

This package is not complete until an authenticated apply with `deploy_agent_data_services = false` succeeds and all of the following are confirmed:

- The resource group holds the Foundry account, project, model deployment, and private endpoint, and holds no Storage, Cosmos DB, or AI Search resources
- `caphostproj` reaches a succeeded provisioning state
- An agent can be created in the project and can run a conversation through the private endpoint
- A control apply with the variable set to true reproduces current behavior

If the apply fails, the design returns for revision rather than falling back to a predefined alternative.

## Out of scope

- Independent toggles for Storage, Cosmos DB, or AI Search
- Refactoring the module into child modules, which belongs to the multi-region package
- Terraform `moved` blocks or state migration
- Any change to `Foundry-managedVnet/`

## References

- [Capability hosts](https://learn.microsoft.com/azure/foundry/agents/concepts/capability-hosts)
- [Set up private networking for Foundry Agent Service](https://learn.microsoft.com/azure/ai-foundry/agents/how-to/virtual-networks)
- `docs/superpowers/specs/2026-07-23-feature-roadmap-design.md`
