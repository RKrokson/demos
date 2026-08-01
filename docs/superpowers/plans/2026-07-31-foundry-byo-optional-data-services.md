# Foundry BYO optional data services implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `deploy_agent_data_services` variable to `Foundry-byoVnet/` that makes the Storage, Cosmos DB, and AI Search bundle optional.

**Architecture:** Every affected resource stays in its current file and gains `count = var.deploy_agent_data_services ? 1 : 0`. References to those resources become indexed. The project capability host is created in both modes and drops its three connection properties when the data services are absent. No child modules are introduced.

**Tech Stack:** Terraform 1.11 or later, AzureRM 4.x, AzAPI ~> 2.4.

**Design:** `docs/superpowers/specs/2026-07-31-foundry-byo-optional-data-services-design.md`

## Global constraints

- Only `Foundry-byoVnet/` changes. Do not modify `Networking/`, `Foundry-managedVnet/`, `ContainerApps-byoVnet/`, or `Fabric-private/`.
- The variable is named `deploy_agent_data_services`, type `bool`, default `true`.
- At the default, the plan output must be identical to the current module.
- The Foundry account keeps `networkInjections` with `scenario = "agent"` and `useMicrosoftManagedNetwork = false` in both modes.
- Never declare an account level capability host. Azure creates it.
- Do not add Terraform `moved` blocks or state migration.
- Do not add README notes about existing deployments or upgrades.
- Do not add cost commentary to the README.
- This repository has no `terraform test`, TFLint, or CI. Do not invent them.
- Commit messages follow the existing convention, for example `feat(foundry-byovnet): ...`. The executing agent adds its own commit trailers.

## Verification commands

Every task ends with these. Run from the module folder:

```powershell
Set-Location (Join-Path (git rev-parse --show-toplevel) 'Foundry-byoVnet')
terraform fmt -check
terraform validate
```

Expected: `terraform fmt -check` prints nothing and exits 0. `terraform validate` prints `Success! The configuration is valid.`

If `terraform validate` reports the module is not initialized, run `terraform init -backend=false` once first.

`terraform validate` evaluates every expression regardless of the `count` value, so an indexing mistake in either branch fails the command. That is the safety net for this plan.

---

### Task 1: Add the variable and example config

**Files:**
- Modify: `Foundry-byoVnet/variables.tf`
- Modify: `Foundry-byoVnet/terraform.tfvars.example`

**Interfaces:**
- Consumes: nothing.
- Produces: `var.deploy_agent_data_services`, a `bool` defaulting to `true`. Every later task gates resources with `count = var.deploy_agent_data_services ? 1 : 0`.

- [ ] **Step 1: Add the variable**

Append to the end of `Foundry-byoVnet/variables.tf`, after the `foundry_sku` variable:

```hcl

## Agent data services
variable "deploy_agent_data_services" {
  description = "Deploy BYO agent data services (Storage, Cosmos DB, AI Search) with their private endpoints, project connections, role assignments, and diagnostics. When false, Foundry Agent Service uses Microsoft-managed storage for agent data."
  type        = bool
  default     = true
}
```

- [ ] **Step 2: Add the example entry**

Append to the end of `Foundry-byoVnet/terraform.tfvars.example`:

```hcl
# ── Agent data services ──────────────────────
# Set to false to omit Storage, Cosmos DB, and AI Search and let
# Foundry Agent Service use Microsoft-managed storage instead.
# deploy_agent_data_services = true
```

- [ ] **Step 3: Verify**

```powershell
Set-Location (Join-Path (git rev-parse --show-toplevel) 'Foundry-byoVnet')
terraform fmt -check
terraform validate
```

Expected: `fmt -check` exits 0 with no output. `validate` prints `Success! The configuration is valid.`

The variable is unused at this point, which is fine. Terraform does not warn about unused variables.

- [ ] **Step 4: Commit**

```bash
git add Foundry-byoVnet/variables.tf Foundry-byoVnet/terraform.tfvars.example
git commit -m "feat(foundry-byovnet): add deploy_agent_data_services variable"
```

---

### Task 2: Gate the dependent resources

Gate the resources that *reference* the data services but are not themselves data services. They still point at un-counted resources here, so no indexing is needed yet and the module stays valid.

**Files:**
- Modify: `Foundry-byoVnet/project.tf`
- Modify: `Foundry-byoVnet/rbac.tf`
- Modify: `Foundry-byoVnet/diagnostics.tf`

**Interfaces:**
- Consumes: `var.deploy_agent_data_services` from Task 1.
- Produces: 17 counted resources, which is 4 in `project.tf`, 6 in `rbac.tf`, and 7 in `diagnostics.tf`. Their addresses become indexed: `azapi_resource.conn_cosmosdb[0]`, `azapi_resource.conn_storage[0]`, `azapi_resource.conn_aisearch[0]`, `time_sleep.wait_rbac[0]`, the six role assignments, and the seven diagnostic settings. Task 3 gates the remaining 6 resources, for 23 in total.

- [ ] **Step 1: Gate the three project connections and the RBAC timer**

In `Foundry-byoVnet/project.tf`, add a `count` line as the first argument of each of these four resources.

`azapi_resource.conn_cosmosdb`:

```hcl
resource "azapi_resource" "conn_cosmosdb" {
  count = var.deploy_agent_data_services ? 1 : 0

  type                      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"
```

`azapi_resource.conn_storage`:

```hcl
resource "azapi_resource" "conn_storage" {
  count = var.deploy_agent_data_services ? 1 : 0

  type                      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"
```

`azapi_resource.conn_aisearch`:

```hcl
resource "azapi_resource" "conn_aisearch" {
  count = var.deploy_agent_data_services ? 1 : 0

  type                      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"
```

`time_sleep.wait_rbac`:

```hcl
resource "time_sleep" "wait_rbac" {
  count = var.deploy_agent_data_services ? 1 : 0

  depends_on = [
    azurerm_role_assignment.cosmosdb_operator_foundry_project,
    azurerm_role_assignment.storage_blob_data_contributor_foundry_project,
    azurerm_role_assignment.search_index_data_contributor_foundry_project,
    azurerm_role_assignment.search_service_contributor_foundry_project
  ]
  create_duration = "60s"
}
```

Do not change `azapi_resource.conn_appinsights`. Application Insights is not part of this bundle.

Do not change the `depends_on` list on `azapi_resource.foundry_project_capability_host`. Terraform accepts whole-resource references to counted resources in `depends_on`, and the list resolves to empty when the count is zero.

- [ ] **Step 2: Gate all six role assignments**

In `Foundry-byoVnet/rbac.tf`, add the same `count` line as the first argument of every resource in the file. There are six: `cosmosdb_operator_foundry_project`, `storage_blob_data_contributor_foundry_project`, `search_index_data_contributor_foundry_project`, `search_service_contributor_foundry_project`, `cosmosdb_db_sql_role_aifp`, and `storage_blob_data_owner_foundry_project`.

The pattern for each, shown on the first one:

```hcl
resource "azurerm_role_assignment" "cosmosdb_operator_foundry_project" {
  count = var.deploy_agent_data_services ? 1 : 0

  depends_on = [
    resource.time_sleep.wait_project_identities
  ]
```

Leave every other argument in the file untouched, including the `condition` heredoc on `storage_blob_data_owner_foundry_project` and its use of `local.project_id_guid`. That local reads from `azapi_resource.foundry_project`, which is never gated.

- [ ] **Step 3: Gate the seven data-service diagnostic settings**

In `Foundry-byoVnet/diagnostics.tf`, add the same `count` line as the first argument of these seven resources:

- `azurerm_monitor_diagnostic_setting.diag_aisearch`
- `azurerm_monitor_diagnostic_setting.diag_cosmosdb`
- `azurerm_monitor_diagnostic_setting.diag_storage_blob`
- `azurerm_monitor_diagnostic_setting.diag_storage_file`
- `azurerm_monitor_diagnostic_setting.diag_storage_queue`
- `azurerm_monitor_diagnostic_setting.diag_storage_table`
- `azurerm_monitor_diagnostic_setting.diag_storage_account`

The pattern, shown on the first one:

```hcl
resource "azurerm_monitor_diagnostic_setting" "diag_aisearch" {
  count = var.deploy_agent_data_services ? 1 : 0

  name               = "diag-aisearch-${random_string.unique.result}"
  target_resource_id = azapi_resource.ai_search.id
```

Do not gate `diag_foundry`, `diag_foundry_project`, or `diag_nsg_foundry`. Those three targets are always deployed.

- [ ] **Step 4: Verify**

```powershell
Set-Location (Join-Path (git rev-parse --show-toplevel) 'Foundry-byoVnet')
terraform fmt -check
terraform validate
```

Expected: `fmt -check` exits 0. `validate` prints `Success! The configuration is valid.`

If `validate` reports an error like `Missing resource instance key`, a reference to one of the newly counted resources was missed. Read the error's file and line, and index that reference.

- [ ] **Step 5: Commit**

```bash
git add Foundry-byoVnet/project.tf Foundry-byoVnet/rbac.tf Foundry-byoVnet/diagnostics.tf
git commit -m "feat(foundry-byovnet): gate agent data service dependents"
```

---

### Task 3: Gate the data services and index every reference

This is the atomic core of the change. Adding `count` to the three accounts invalidates every reference to them at once, so the accounts, their private endpoints, all references, the capability host body, and the outputs move together.

**Files:**
- Modify: `Foundry-byoVnet/storage.tf`
- Modify: `Foundry-byoVnet/cosmosdb.tf`
- Modify: `Foundry-byoVnet/aisearch.tf`
- Modify: `Foundry-byoVnet/project.tf`
- Modify: `Foundry-byoVnet/rbac.tf`
- Modify: `Foundry-byoVnet/diagnostics.tf`
- Modify: `Foundry-byoVnet/outputs.tf`

**Interfaces:**
- Consumes: `var.deploy_agent_data_services` from Task 1, and the counted resources from Task 2.
- Produces: the complete feature. Addresses become `azurerm_storage_account.storage_account[0]`, `azurerm_cosmosdb_account.cosmosdb[0]`, `azapi_resource.ai_search[0]`, and the three private endpoints `azurerm_private_endpoint.pe-storage[0]`, `pe-cosmosdb[0]`, `pe-aisearch[0]`. Outputs `storage_account_id`, `cosmosdb_account_id`, and `ai_search_id` return `null` when disabled.

**Files deliberately left alone:** `Foundry-byoVnet/foundry.tf`, `main.tf`, `networking.tf`, `locals.tf`, and `config.tf` need no edits.

Two `depends_on` lists point at the private endpoints being counted in this task, and both are correct as written. `azurerm_private_endpoint.pe-aifoundry` in `foundry.tf` depends on `azurerm_private_endpoint.pe-aisearch`, and `azapi_resource.foundry_project` in `project.tf` depends on all four private endpoints. These are whole-resource references, which stay valid against a counted resource and resolve to an empty list when the count is zero. Do not index them, and do not gate either resource.

- [ ] **Step 1: Gate Cosmos DB and its private endpoint**

Replace the whole of `Foundry-byoVnet/cosmosdb.tf` with:

```hcl
## Create the Cosmos DB account to store agent threads
##
resource "azurerm_cosmosdb_account" "cosmosdb" {
  count = var.deploy_agent_data_services ? 1 : 0

  name                = "aifoundry${random_string.unique.result}cosmosdb"
  resource_group_name = azurerm_resource_group.rg-ai00.name
  location            = azurerm_resource_group.rg-ai00.location

  # General settings
  offer_type        = "Standard"
  kind              = "GlobalDocumentDB"
  free_tier_enabled = false

  # Set security-related settings
  local_authentication_disabled = true
  public_network_access_enabled = false

  # Set high availability and failover settings
  automatic_failover_enabled       = false
  multiple_write_locations_enabled = false
  tags                             = local.common_tags

  # Configure consistency settings
  consistency_policy {
    consistency_level = "Session"
  }

  # Configure single location with no zone redundancy to reduce costs
  geo_location {
    location          = azurerm_resource_group.rg-ai00.location
    failover_priority = 0
    zone_redundant    = false
  }
}

## Create Private Endpoint for Cosmos DB
##
resource "azurerm_private_endpoint" "pe-cosmosdb" {
  count = var.deploy_agent_data_services ? 1 : 0

  name                = "${azurerm_cosmosdb_account.cosmosdb[0].name}-private-endpoint"
  resource_group_name = azurerm_resource_group.rg-ai00.name
  location            = azurerm_resource_group.rg-ai00.location
  subnet_id           = azurerm_subnet.private_endpoint_subnet.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "${azurerm_cosmosdb_account.cosmosdb[0].name}-private-link-service-connection"
    private_connection_resource_id = azurerm_cosmosdb_account.cosmosdb[0].id
    subresource_names = [
      "Sql"
    ]
    is_manual_connection = false
  }

  private_dns_zone_group {
    name = "${azurerm_cosmosdb_account.cosmosdb[0].name}-dns-config"
    private_dns_zone_ids = [
      local.platform_region0.private_dns_zone_ids.documents
    ]
  }
}
```

- [ ] **Step 2: Gate Storage and its private endpoint**

Replace the whole of `Foundry-byoVnet/storage.tf` with:

```hcl
########## Create resources required to for agent data storage
##########

## Create a storage account for agent data
##
resource "azurerm_storage_account" "storage_account" {
  count = var.deploy_agent_data_services ? 1 : 0

  name                = "aifoundry${random_string.unique.result}storage00"
  resource_group_name = azurerm_resource_group.rg-ai00.name
  location            = azurerm_resource_group.rg-ai00.location

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  ## Identity configuration
  shared_access_key_enabled = false

  ## Network access configuration
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = local.common_tags
  network_rules {
    default_action = "Deny"
    bypass = [
      "AzureServices"
    ]
  }
}

## Create Private Endpoint for storage
##
resource "azurerm_private_endpoint" "pe-storage" {
  count = var.deploy_agent_data_services ? 1 : 0

  # Sequential PE creation required — parallel creation causes subnet update races
  # and account provisioning timing issues on fresh deploys. PG-validated pattern.
  depends_on = [azurerm_private_endpoint.pe-cosmosdb]

  name                = "${azurerm_storage_account.storage_account[0].name}-private-endpoint"
  resource_group_name = azurerm_resource_group.rg-ai00.name
  location            = azurerm_resource_group.rg-ai00.location
  subnet_id           = azurerm_subnet.private_endpoint_subnet.id
  tags                = local.common_tags
  private_service_connection {
    name                           = "${azurerm_storage_account.storage_account[0].name}-private-link-service-connection"
    private_connection_resource_id = azurerm_storage_account.storage_account[0].id
    subresource_names = [
      "blob"
    ]
    is_manual_connection = false
  }

  private_dns_zone_group {
    name = "${azurerm_storage_account.storage_account[0].name}-dns-config"
    private_dns_zone_ids = [
      local.platform_region0.private_dns_zone_ids.blob
    ]
  }
}
```

- [ ] **Step 3: Gate AI Search and its private endpoint**

Replace the whole of `Foundry-byoVnet/aisearch.tf` with:

```hcl
## Create an AI Search instance that will be used to store vector embeddings
##
resource "azapi_resource" "ai_search" {
  count = var.deploy_agent_data_services ? 1 : 0

  type                      = "Microsoft.Search/searchServices@2024-06-01-preview"
  name                      = "aifoundry${random_string.unique.result}search"
  parent_id                 = azurerm_resource_group.rg-ai00.id
  location                  = azurerm_resource_group.rg-ai00.location
  schema_validation_enabled = true
  tags                      = local.common_tags

  body = {
    sku = {
      name = var.ai_search_sku
    }

    identity = {
      type = "SystemAssigned"
    }

    properties = {

      # Search-specific properties
      replicaCount   = 1
      partitionCount = 1
      hostingMode    = "default"
      semanticSearch = "disabled"

      # Identity-related controls
      disableLocalAuth = true

      # Networking-related controls
      publicNetworkAccess = "disabled"
      networkRuleSet = {
        bypass = "None"
      }
    }
  }
}

## Create Private Endpoint for AI Search
##
resource "azurerm_private_endpoint" "pe-aisearch" {
  count = var.deploy_agent_data_services ? 1 : 0

  depends_on = [azurerm_private_endpoint.pe-storage]

  name                = "${azapi_resource.ai_search[0].name}-private-endpoint"
  resource_group_name = azurerm_resource_group.rg-ai00.name
  location            = azurerm_resource_group.rg-ai00.location
  subnet_id           = azurerm_subnet.private_endpoint_subnet.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "${azapi_resource.ai_search[0].name}-private-link-service-connection"
    private_connection_resource_id = azapi_resource.ai_search[0].id
    subresource_names = [
      "searchService"
    ]
    is_manual_connection = false
  }

  private_dns_zone_group {
    name = "${azapi_resource.ai_search[0].name}-dns-config"
    private_dns_zone_ids = [
      local.platform_region0.private_dns_zone_ids.search
    ]
  }
}
```

- [ ] **Step 4: Index the three project connections**

In `Foundry-byoVnet/project.tf`, update the bodies of the three connections gated in Task 2.

`azapi_resource.conn_cosmosdb` becomes:

```hcl
resource "azapi_resource" "conn_cosmosdb" {
  count = var.deploy_agent_data_services ? 1 : 0

  type                      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"
  name                      = azurerm_cosmosdb_account.cosmosdb[0].name
  parent_id                 = azapi_resource.foundry_project.id
  schema_validation_enabled = false

  body = {
    name = azurerm_cosmosdb_account.cosmosdb[0].name
    properties = {
      category = "CosmosDB"
      target   = azurerm_cosmosdb_account.cosmosdb[0].endpoint
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ResourceId = azurerm_cosmosdb_account.cosmosdb[0].id
        location   = azurerm_resource_group.rg-ai00.location
      }
    }
  }
}
```

`azapi_resource.conn_storage` becomes:

```hcl
resource "azapi_resource" "conn_storage" {
  count = var.deploy_agent_data_services ? 1 : 0

  type                      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"
  name                      = azurerm_storage_account.storage_account[0].name
  parent_id                 = azapi_resource.foundry_project.id
  schema_validation_enabled = false

  body = {
    name = azurerm_storage_account.storage_account[0].name
    properties = {
      category = "AzureStorageAccount"
      target   = azurerm_storage_account.storage_account[0].primary_blob_endpoint
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ResourceId = azurerm_storage_account.storage_account[0].id
        location   = azurerm_resource_group.rg-ai00.location
      }
    }
  }

  response_export_values = [
    "identity.principalId"
  ]
}
```

`azapi_resource.conn_aisearch` becomes:

```hcl
resource "azapi_resource" "conn_aisearch" {
  count = var.deploy_agent_data_services ? 1 : 0

  type                      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"
  name                      = azapi_resource.ai_search[0].name
  parent_id                 = azapi_resource.foundry_project.id
  schema_validation_enabled = false

  body = {
    name = azapi_resource.ai_search[0].name
    properties = {
      category = "CognitiveSearch"
      target   = "https://${azapi_resource.ai_search[0].name}.search.windows.net"
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ApiVersion = "2025-05-01-preview"
        ResourceId = azapi_resource.ai_search[0].id
        location   = azurerm_resource_group.rg-ai00.location
      }
    }
  }

  response_export_values = [
    "identity.principalId"
  ]
}
```

- [ ] **Step 5: Make the capability host body conditional**

In `Foundry-byoVnet/project.tf`, replace the `body` block of `azapi_resource.foundry_project_capability_host` so the resource reads:

```hcl
resource "azapi_resource" "foundry_project_capability_host" {
  depends_on = [
    azapi_resource.conn_aisearch,
    azapi_resource.conn_cosmosdb,
    azapi_resource.conn_storage,
    azapi_resource.conn_appinsights,
    time_sleep.wait_rbac
  ]
  type                      = "Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-04-01-preview"
  name                      = "caphostproj"
  parent_id                 = azapi_resource.foundry_project.id
  schema_validation_enabled = false

  body = {
    properties = merge(
      {
        capabilityHostKind = "Agents"
      },
      var.deploy_agent_data_services ? {
        vectorStoreConnections = [
          azapi_resource.ai_search[0].name
        ]
        storageConnections = [
          azurerm_storage_account.storage_account[0].name
        ]
        threadStorageConnections = [
          azurerm_cosmosdb_account.cosmosdb[0].name
        ]
      } : {}
    )
  }
}
```

The resource itself is not gated. It is created in both modes.

The `depends_on` list is unchanged. Whole-resource references to counted resources are valid and resolve to empty lists when the count is zero.

Two behaviors this relies on, both confirmed against Terraform 1.11:

1. The conditional short-circuits, so `azapi_resource.ai_search[0].name` is never evaluated when the variable is false. It does not raise an index error.
2. Both branches unify to `map(list(string))`, because all three values are lists of strings and `{}` converts to an empty map. `merge` then produces `{ capabilityHostKind = "Agents" }` alone when disabled.

- [ ] **Step 6: Index the role assignment scopes and names**

In `Foundry-byoVnet/rbac.tf`, index every reference to the three data services. `azurerm_role_assignment.cosmosdb_operator_foundry_project` needs only its `scope` changed, because its `name` does not reference a data service:

```hcl
  scope = azurerm_cosmosdb_account.cosmosdb[0].id
```

`azurerm_role_assignment.storage_blob_data_contributor_foundry_project`:

```hcl
  name                 = uuidv5("dns", "${azapi_resource.foundry_project.name}${azapi_resource.foundry_project.output.identity.principalId}${azurerm_storage_account.storage_account[0].name}storageblobdatacontributor")
  scope                = azurerm_storage_account.storage_account[0].id
```

`azurerm_role_assignment.search_index_data_contributor_foundry_project`:

```hcl
  name                 = uuidv5("dns", "${azapi_resource.foundry_project.name}${azapi_resource.foundry_project.output.identity.principalId}${azapi_resource.ai_search[0].name}searchindexdatacontributor")
  scope                = azapi_resource.ai_search[0].id
```

`azurerm_role_assignment.search_service_contributor_foundry_project`:

```hcl
  name                 = uuidv5("dns", "${azapi_resource.foundry_project.name}${azapi_resource.foundry_project.output.identity.principalId}${azapi_resource.ai_search[0].name}searchservicecontributor")
  scope                = azapi_resource.ai_search[0].id
```

`azurerm_cosmosdb_sql_role_assignment.cosmosdb_db_sql_role_aifp`:

```hcl
  account_name       = azurerm_cosmosdb_account.cosmosdb[0].name
  scope              = azurerm_cosmosdb_account.cosmosdb[0].id
  role_definition_id = "${azurerm_cosmosdb_account.cosmosdb[0].id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
```

`azurerm_role_assignment.storage_blob_data_owner_foundry_project`:

```hcl
  name                 = uuidv5("dns", "${azapi_resource.foundry_project.name}${azapi_resource.foundry_project.output.identity.principalId}${azurerm_storage_account.storage_account[0].name}storageblobdataowner")
  scope                = azurerm_storage_account.storage_account[0].id
```

Leave the `condition` heredoc and `condition_version` on that last resource unchanged.

- [ ] **Step 7: Index the diagnostic setting targets**

In `Foundry-byoVnet/diagnostics.tf`, update the `target_resource_id` of the seven gated settings:

```hcl
# diag_aisearch
  target_resource_id = azapi_resource.ai_search[0].id

# diag_cosmosdb
  target_resource_id = azurerm_cosmosdb_account.cosmosdb[0].id

# diag_storage_blob
  target_resource_id = "${azurerm_storage_account.storage_account[0].id}/blobServices/default"

# diag_storage_file
  target_resource_id = "${azurerm_storage_account.storage_account[0].id}/fileServices/default"

# diag_storage_queue
  target_resource_id = "${azurerm_storage_account.storage_account[0].id}/queueServices/default"

# diag_storage_table
  target_resource_id = "${azurerm_storage_account.storage_account[0].id}/tableServices/default"

# diag_storage_account
  target_resource_id = azurerm_storage_account.storage_account[0].id
```

Do not add those `# diag_*` comment lines to the file. They identify which resource each line belongs to.

- [ ] **Step 8: Make the three outputs null-safe**

In `Foundry-byoVnet/outputs.tf`, replace the last three outputs:

```hcl
output "storage_account_id" {
  description = "The ID of the Storage Account, or null when agent data services are disabled"
  value       = one(azurerm_storage_account.storage_account[*].id)
}

output "cosmosdb_account_id" {
  description = "The ID of the Cosmos DB account, or null when agent data services are disabled"
  value       = one(azurerm_cosmosdb_account.cosmosdb[*].id)
}

output "ai_search_id" {
  description = "The ID of the AI Search service, or null when agent data services are disabled"
  value       = one(azapi_resource.ai_search[*].id)
}
```

Leave `resource_group_id`, `ai_foundry_id`, and `ai_foundry_project_id` unchanged.

- [ ] **Step 9: Verify**

```powershell
Set-Location (Join-Path (git rev-parse --show-toplevel) 'Foundry-byoVnet')
terraform fmt -check
terraform validate
```

Expected: `fmt -check` exits 0. `validate` prints `Success! The configuration is valid.`

If `validate` fails with `Missing resource instance key`, an un-indexed reference remains. The error names the file and line.

If `fmt -check` lists a file, run `terraform fmt` and re-run the check.

- [ ] **Step 10: Confirm no reference was missed**

Search the module for un-indexed references to the three gated accounts:

```powershell
Set-Location (Join-Path (git rev-parse --show-toplevel) 'Foundry-byoVnet')
Select-String -Path *.tf -Pattern 'storage_account\.storage_account(?!\[)|cosmosdb_account\.cosmosdb(?!\[)|azapi_resource\.ai_search(?!\[)'
```

Expected: no output.

Matches are only acceptable on `depends_on` lines, which reference whole resources deliberately. There should be none of those for these three accounts, since the private endpoints reference them through interpolation instead.

- [ ] **Step 11: Verify formatting across the repository**

```powershell
Set-Location (git rev-parse --show-toplevel)
terraform fmt -check -recursive
```

Expected: exits 0 with no output.

- [ ] **Step 12: Commit**

```bash
git add Foundry-byoVnet/storage.tf Foundry-byoVnet/cosmosdb.tf Foundry-byoVnet/aisearch.tf Foundry-byoVnet/project.tf Foundry-byoVnet/rbac.tf Foundry-byoVnet/diagnostics.tf Foundry-byoVnet/outputs.tf
git commit -m "feat(foundry-byovnet): make agent data services optional"
```

---

### Task 4: Document the variable

**Files:**
- Modify: `Foundry-byoVnet/README.md`

**Interfaces:**
- Consumes: the completed feature from Task 3.
- Produces: no code. Documentation only.

- [ ] **Step 1: Add the variable to the variables table**

In `Foundry-byoVnet/README.md`, add a row to the end of the existing variables table:

```markdown
| `deploy_agent_data_services` | `true`               | Deploy BYO agent data services |
```

- [ ] **Step 2: Describe the disabled mode**

Immediately after the variables table, before the line beginning `For GPT deployment names`, insert:

```markdown
### Agent data services

By default the module deploys its own Azure Storage, Cosmos DB, and AI Search, and the project capability host points agent data at them.

Set `deploy_agent_data_services = false` to omit all three, along with their private endpoints, project connections, role assignments, and diagnostic settings. Foundry Agent Service then uses Microsoft-managed storage for conversation history, file uploads, and vector data.

The module remains a bring-your-own virtual network deployment in both modes. The Foundry account, its network injection, the project, the model deployment, and the private endpoint are unchanged.

Capability hosts cannot be updated in place, so pick a value before you deploy. Changing it on a live deployment requires `terraform destroy` first.
```

Do not add notes about upgrading existing deployments, and do not mention cost.

- [ ] **Step 3: Update the outputs table**

In the outputs table of the same file, replace the three data-service rows:

```markdown
| `storage_account_id`    | Storage account ID, null when data services are disabled |
| `cosmosdb_account_id`   | Cosmos DB account ID, null when data services are disabled |
| `ai_search_id`          | AI Search service ID, null when data services are disabled |
```

- [ ] **Step 4: Verify**

Confirm the file renders as valid Markdown and the tables are intact:

```powershell
Set-Location (Join-Path (git rev-parse --show-toplevel) 'Foundry-byoVnet')
Get-Content README.md | Select-String -Pattern 'deploy_agent_data_services'
```

Expected: two matches, one in the variables table and one in the new section.

- [ ] **Step 5: Commit**

```bash
git add Foundry-byoVnet/README.md
git commit -m "docs(foundry-byovnet): document deploy_agent_data_services"
```

---

### Task 5: Authenticated validation and completion gate

This task requires Azure authentication, an active subscription context, and the `Networking/` module already applied with `add_private_dns00 = true`. It is run by the repository owner, not by an automated worker.

**Files:** none.

**Interfaces:**
- Consumes: the completed feature from Tasks 1 through 4.
- Produces: the pass or fail signal that closes this package.

- [ ] **Step 1: Confirm the default mode is unchanged**

```powershell
Set-Location (Join-Path (git rev-parse --show-toplevel) 'Foundry-byoVnet')
terraform plan -var deploy_agent_data_services=true
```

Expected: the same resource set the module produced before this change. Note the total count in the `Plan:` line.

- [ ] **Step 2: Confirm the disabled mode drops 23 resources**

```powershell
terraform plan -var deploy_agent_data_services=false
```

Expected: the `Plan:` line shows exactly 23 fewer resources to add than Step 1.

Confirm the plan contains no `azurerm_storage_account`, `azurerm_cosmosdb_account`, or `azapi_resource.ai_search`, and that `azapi_resource.foundry_project_capability_host` is still present with `capabilityHostKind` as the only property under `body.properties`.

- [ ] **Step 3: Apply with data services disabled**

```powershell
terraform apply -var deploy_agent_data_services=false
```

- [ ] **Step 4: Verify the deployed result**

Check all four conditions:

1. The resource group holds the Foundry account, project, model deployment, and private endpoint, and holds no Storage, Cosmos DB, or AI Search resource.
2. `caphostproj` reached a succeeded provisioning state.
3. An agent can be created in the project and can run a conversation through the private endpoint.
4. A control apply with `deploy_agent_data_services=true` reproduces the original behavior.

- [ ] **Step 5: Record the outcome**

If all four pass, this package is complete.

If the apply fails, stop and return to the design. The spec deliberately defines no fallback configuration.

---

## Cleanup

After testing, destroy the application landing zone before `Networking/`. Purge the soft-deleted Foundry resource before the delegated subnet can be removed, as described in `Foundry-byoVnet/README.md`.
