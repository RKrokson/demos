########## Create infrastructure resources
##########

## Create a random string
## 
resource "random_string" "unique" {
  length      = 4
  min_numeric = 4
  numeric     = true
  special     = false
  lower       = true
  upper       = false
}

## Data imports
##

data "terraform_remote_state" "networking" {
  backend = "local"
  config = {
    path = "../Networking/terraform.tfstate"
  }
}

data "azurerm_client_config" "current" {}

## Create a resource group for Foundry resources
##
resource "azurerm_resource_group" "rg-ai01" {
  name = "${var.resource_group_name_ai01}-${data.terraform_remote_state.networking.outputs.azure_region_0_abbr}-${random_string.unique.result}"
  location = data.terraform_remote_state.networking.outputs.rg_net00_location
}

########## Create resources required to for agent data storage
##########

## Create a storage account for agent data
##
resource "azurerm_storage_account" "storage_account" {
  name                = "foundry${random_string.unique.result}storage01"
  resource_group_name = azurerm_resource_group.rg-ai01.name
  location            = azurerm_resource_group.rg-ai01.location

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  ## Identity configuration
  shared_access_key_enabled = false

  # Ignore changes to queue/blob/file/table properties to avoid validation issues
  lifecycle {
    ignore_changes = [
      queue_properties,
      blob_properties,
      share_properties
    ]
  }

  ## Network access configuration
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  network_rules {
    default_action = "Deny"
    bypass = []
  }
}

# Private Endpoint for Blob
resource "azurerm_private_endpoint" "pe-storage-blob" {
  depends_on = [
    azurerm_storage_account.storage_account
  ]

  name                = "${azurerm_storage_account.storage_account.name}-pe-blob"
  resource_group_name = azurerm_resource_group.rg-ai01.name
  location            = azurerm_resource_group.rg-ai01.location
  subnet_id           = data.terraform_remote_state.networking.outputs.private_endpoint_subnet00_id
  private_service_connection {
    name                           = "${azurerm_storage_account.storage_account.name}-pe-blob-connection"
    private_connection_resource_id = azurerm_storage_account.storage_account.id
    subresource_names = [
      "blob"
    ]
    is_manual_connection = false
  }

  private_dns_zone_group {
    name = "${azurerm_storage_account.storage_account.name}-blob-dns-group"
    private_dns_zone_ids = [
      "${data.terraform_remote_state.networking.outputs.rg_net00_id}/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
    ]
  }
}

# Private Endpoint for File
resource "azurerm_private_endpoint" "pe-storage_file" {
  depends_on = [
    azurerm_storage_account.storage_account
  ]
  name                = "${azurerm_storage_account.storage_account.name}-pe-file"
  resource_group_name = azurerm_resource_group.rg-ai01.name
  location            = azurerm_resource_group.rg-ai01.location
  subnet_id           = data.terraform_remote_state.networking.outputs.private_endpoint_subnet00_id

  private_service_connection {
    name                           = "${azurerm_storage_account.storage_account.name}-pe-file-connection"
    private_connection_resource_id = azurerm_storage_account.storage_account.id
    is_manual_connection           = false
    subresource_names              = ["file"]
  }

  private_dns_zone_group {
    name = "${azurerm_storage_account.storage_account.name}-file-dns-group"
    private_dns_zone_ids = [
      "${data.terraform_remote_state.networking.outputs.rg_net00_id}/providers/Microsoft.Network/privateDnsZones/privatelink.file.core.windows.net"
    ]
  }
}

# Private Endpoint for Table
resource "azurerm_private_endpoint" "pe-storage_table" {
  name                = "${azurerm_storage_account.storage_account.name}-pe-table"
  resource_group_name = azurerm_resource_group.rg-ai01.name
  location            = azurerm_resource_group.rg-ai01.location
  subnet_id           = data.terraform_remote_state.networking.outputs.private_endpoint_subnet00_id

  private_service_connection {
    name                           = "${azurerm_storage_account.storage_account.name}-pe-table-connection"
    private_connection_resource_id = azurerm_storage_account.storage_account.id
    is_manual_connection           = false
    subresource_names              = ["table"]
  }

  private_dns_zone_group {
    name                 = "${azurerm_storage_account.storage_account.name}-table-dns-group"
    private_dns_zone_ids = [
      "${data.terraform_remote_state.networking.outputs.rg_net00_id}/providers/Microsoft.Network/privateDnsZones/privatelink.table.core.windows.net"
    ]
  }
}

# Private Endpoint for Queue
resource "azurerm_private_endpoint" "pe-storage_queue" {
  name                = "${azurerm_storage_account.storage_account.name}-pe-queue"
  resource_group_name = azurerm_resource_group.rg-ai01.name
  location            = azurerm_resource_group.rg-ai01.location
  subnet_id           = data.terraform_remote_state.networking.outputs.private_endpoint_subnet00_id

  private_service_connection {
    name                           = "${azurerm_storage_account.storage_account.name}-pe-queue-connection"
    private_connection_resource_id = azurerm_storage_account.storage_account.id
    is_manual_connection           = false
    subresource_names              = ["queue"]
  }

  private_dns_zone_group {
    name                 = "${azurerm_storage_account.storage_account.name}-queue-dns-group"
    private_dns_zone_ids = [
      "${data.terraform_remote_state.networking.outputs.rg_net00_id}/providers/Microsoft.Network/privateDnsZones/privatelink.queue.core.windows.net"
    ]
  }
}

# Role Assignment: Current user needs Storage Blob Data Contributor for Terraform to manage storage
resource "azurerm_role_assignment" "current_user_storage_blob" {
  scope                = azurerm_storage_account.storage_account.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Role Assignment: Current user needs Storage Queue Data Contributor
resource "azurerm_role_assignment" "current_user_storage_queue" {
  scope                = azurerm_storage_account.storage_account.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Role Assignment: Current user needs Storage File Data SMB Share Contributor
resource "azurerm_role_assignment" "current_user_storage_file" {
  scope                = azurerm_storage_account.storage_account.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Role Assignment: Current user needs Storage Table Data Contributor
resource "azurerm_role_assignment" "current_user_storage_table" {
  scope                = azurerm_storage_account.storage_account.id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Wait for Storage Account to be fully created before creating outbound rule
resource "time_sleep" "wait_storage" {
  create_duration = "10m"

  depends_on = [
    azurerm_storage_account.storage_account,
    azurerm_private_endpoint.pe-storage-blob,
    azurerm_private_endpoint.pe-storage_file,
    azurerm_private_endpoint.pe-storage_table,
    azurerm_private_endpoint.pe-storage_queue
  ]
}

# Managed Network Outbound Rule for Storage Account
resource "azapi_resource" "storage_outbound_rule" {
  type      = "Microsoft.CognitiveServices/accounts/managedNetworks/outboundRules@2025-10-01-preview"
  name      = "storage-blob-rule"
  parent_id = azapi_resource.managed_network.id

  schema_validation_enabled = false

  body = {
    properties = {
      type = "PrivateEndpoint"
      destination = {
        serviceResourceId = azurerm_storage_account.storage_account.id
        subresourceTarget = "blob"
      }
      category = "UserDefined"
    }
  }

  depends_on = [
    time_sleep.wait_storage,
    azurerm_role_assignment.foundry_network_connection_approver,
    azurerm_role_assignment.foundry_storage_blob,
    azurerm_role_assignment.foundry_storage_contributor
  ]
}

## Create the Cosmos DB account to store agent threads
##
resource "azurerm_cosmosdb_account" "cosmosdb" {
  name                = "foundry${random_string.unique.result}cosmosdb"
  resource_group_name = azurerm_resource_group.rg-ai01.name
  location            = azurerm_resource_group.rg-ai01.location

  # General settings
  offer_type        = "Standard"
  kind              = "GlobalDocumentDB"
  free_tier_enabled = false

  # Set security-related settings
  local_authentication_disabled = true
  public_network_access_enabled = false
  network_acl_bypass_for_azure_services = false

  # Set high availability and failover settings
  automatic_failover_enabled       = false
  multiple_write_locations_enabled = false

  # Configure consistency settings
  consistency_policy {
    consistency_level = "Session"
    max_interval_in_seconds = 5
    max_staleness_prefix    = 100
  }

  # Configure single location with no zone redundancy to reduce costs
  geo_location {
    location          = azurerm_resource_group.rg-ai01.location
    failover_priority = 0
    zone_redundant    = false
  }
}

resource "azurerm_private_endpoint" "pe-cosmosdb" {
  name                = "${azurerm_cosmosdb_account.cosmosdb.name}-private-endpoint"
  resource_group_name = azurerm_resource_group.rg-ai01.name
  location            = azurerm_resource_group.rg-ai01.location
  subnet_id           = data.terraform_remote_state.networking.outputs.private_endpoint_subnet00_id

  private_service_connection {
    name                           = "${azurerm_cosmosdb_account.cosmosdb.name}-pe-connection"
    private_connection_resource_id = azurerm_cosmosdb_account.cosmosdb.id
    subresource_names = [
      "Sql"
    ]
    is_manual_connection = false
  }

  private_dns_zone_group {
    name = "${azurerm_cosmosdb_account.cosmosdb.name}-dns-group"
    private_dns_zone_ids = [
      "${data.terraform_remote_state.networking.outputs.rg_net00_id}/providers/Microsoft.Network/privateDnsZones/privatelink.documents.azure.com"
    ]
  }
}

# Role Assignment: AI Foundry Account Identity - Contributor on Cosmos DB
resource "azurerm_role_assignment" "foundry_cosmos_contributor" {
  scope                = azurerm_cosmosdb_account.cosmosdb.id
  role_definition_name = "Contributor"
  principal_id         = azapi_resource.foundry.output.identity.principalId
}

# Wait for Cosmos DB to be fully created before creating outbound rule
resource "time_sleep" "wait_cosmos" {
  create_duration = "10m"

  depends_on = [
    azurerm_cosmosdb_account.cosmosdb,
    azurerm_private_endpoint.pe-cosmosdb
  ]
}

# Managed Network Outbound Rule for Cosmos DB Account
resource "azapi_resource" "cosmos_outbound_rule" {
  type      = "Microsoft.CognitiveServices/accounts/managedNetworks/outboundRules@2025-10-01-preview"
  name      = "cosmos-sql-rule"
  parent_id = azapi_resource.managed_network.id

  schema_validation_enabled = false

  body = {
    properties = {
      type = "PrivateEndpoint"
      destination = {
        serviceResourceId = azurerm_cosmosdb_account.cosmosdb.id
        subresourceTarget = "Sql"
      }
      category = "UserDefined"
    }
  }

  depends_on = [
    time_sleep.wait_cosmos,
    azurerm_role_assignment.foundry_network_connection_approver,
    azurerm_role_assignment.foundry_cosmos_contributor,
    azurerm_role_assignment.cosmosdb_reader_foundry_project,
    azurerm_role_assignment.cosmosdb_operator_foundry_project
  ]
}

# Role Assignment: Current user needs Cosmos DB Built-in Data Contributor
resource "azurerm_cosmosdb_sql_role_assignment" "current_user" {
  resource_group_name = azurerm_resource_group.rg-ai01.name
  account_name        = azurerm_cosmosdb_account.cosmosdb.name
  role_definition_id  = "${azurerm_cosmosdb_account.cosmosdb.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = data.azurerm_client_config.current.object_id
  scope               = azurerm_cosmosdb_account.cosmosdb.id
}

## Create an AI Search instance that will be used to store vector embeddings
##
resource "azapi_resource" "ai_search" {
  type                      = "Microsoft.Search/searchServices@2025-02-01-preview"
  name                      = "foundry${random_string.unique.result}search"
  parent_id                 = azurerm_resource_group.rg-ai01.id
  location                  = azurerm_resource_group.rg-ai01.location
  schema_validation_enabled = true

  body = {
    sku = {
      name = "standard"
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
      disableLocalAuth = false
      authOptions = {
        aadOrApiKey = {
          aadAuthFailureMode = "http401WithBearerChallenge"
        }
      }
      # Networking-related controls
      publicNetworkAccess = "disabled"
      networkRuleSet = {
        bypass = "None"
      }
    }
  }
}

resource "azurerm_private_endpoint" "pe-aisearch" {
  name                = "${azapi_resource.ai_search.name}-private-endpoint"
  resource_group_name = azurerm_resource_group.rg-ai01.name
  location            = azurerm_resource_group.rg-ai01.location
  subnet_id           = data.terraform_remote_state.networking.outputs.private_endpoint_subnet00_id

  private_service_connection {
    name                           = "${azapi_resource.ai_search.name}-private-link-service-connection"
    private_connection_resource_id = azapi_resource.ai_search.id
    subresource_names = [
      "searchService"
    ]
    is_manual_connection = false
  }

  private_dns_zone_group {
    name = "${azapi_resource.ai_search.name}-dns-config"
    private_dns_zone_ids = [
      "${data.terraform_remote_state.networking.outputs.rg_net00_id}/providers/Microsoft.Network/privateDnsZones/privatelink.search.windows.net"
    ]
  }
}

# Wait for AI Search to be fully created before creating outbound rule
resource "time_sleep" "wait_aisearch" {
  create_duration = "10m"

  depends_on = [
    azapi_resource.ai_search,
    azurerm_private_endpoint.pe-aisearch
  ]
}

# Managed Network Outbound Rule for AI Search Service
resource "azapi_resource" "aisearch_outbound_rule" {
  type      = "Microsoft.CognitiveServices/accounts/managedNetworks/outboundRules@2025-10-01-preview"
  name      = "aisearch-rule"
  parent_id = azapi_resource.managed_network.id

  schema_validation_enabled = false

  body = {
    properties = {
      type = "PrivateEndpoint"
      destination = {
        serviceResourceId = azapi_resource.ai_search.id
        subresourceTarget = "searchService"
      }
      category = "UserDefined"
    }
  }

  depends_on = [
    time_sleep.wait_aisearch,
    azurerm_role_assignment.foundry_network_connection_approver,
    azurerm_role_assignment.search_index_data_contributor_foundry_project,
    azurerm_role_assignment.search_service_contributor_foundry_project
  ]
}

# Role Assignment: Current user needs Search Service Contributor
resource "azurerm_role_assignment" "current_user_search_contributor" {
  scope                = azapi_resource.ai_search.id
  role_definition_name = "Search Service Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Role Assignment: Current user needs Search Index Data Contributor
resource "azurerm_role_assignment" "current_user_search_index" {
  scope                = azapi_resource.ai_search.id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

########## Create Foundry resource
##########

## Create the Foundry resource
##
resource "azapi_resource" "foundry" {
  type                      = "Microsoft.CognitiveServices/accounts@2025-10-01-preview"
  name                      = "foundry${random_string.unique.result}"
  parent_id                 = azurerm_resource_group.rg-ai01.id
  location                  = azurerm_resource_group.rg-ai01.location

  schema_validation_enabled = false

  response_export_values = [
    "identity.principalId"
  ]

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind = "AIServices",
    sku = {
      name = "S0"
    }
    properties = {

      # Support Entra ID and disable API Key authentication for underlining Cognitive Services account
      disableLocalAuth = true

      # Specifies that this is a Foundry resource
      allowProjectManagement = true

      # Set custom subdomain name for DNS names created for this Foundry resource
      customSubDomainName    = "foundry${random_string.unique.result}"

      # Network-related controls
      # Disable public access but allow Trusted Azure Services exception
      publicNetworkAccess = "Disabled"
      networkAcls = {
        defaultAction         = "Deny"
        virtualNetworkRules   = []
        ipRules               = []
      }

      # Enable VNet injection for Standard Agents
      networkInjections = [
        {
          scenario                   = "agent"
          subnetArmId                = ""
          useMicrosoftManagedNetwork = true
        }
      ]
      userOwnedStorage = [
        {
          resourceId = azurerm_storage_account.storage_account.id
        }
      ]
      userOwnedCosmosDB = [
        {
          resourceId = azurerm_cosmosdb_account.cosmosdb.id
        }
      ]
      userOwnedSearch = [
        {
          resourceId = azapi_resource.ai_search.id
        }
      ]
    }
  }

  lifecycle {
    ignore_changes = [
      body["properties"]["restore"],
      output
    ]
  }

  depends_on = [
    azurerm_storage_account.storage_account,
    azurerm_cosmosdb_account.cosmosdb,
    azapi_resource.ai_search
  ]
}

# Create Private Endpoints for foundry

resource "azurerm_private_endpoint" "pe-foundry" {
  depends_on = [
    azurerm_private_endpoint.pe-aisearch,
    azapi_resource.foundry
  ]

  name                = "${azapi_resource.foundry.name}-private-endpoint"
  resource_group_name = azurerm_resource_group.rg-ai01.name
  location            = azurerm_resource_group.rg-ai01.location
  subnet_id           = data.terraform_remote_state.networking.outputs.private_endpoint_subnet00_id


  private_service_connection {
    name                           = "${azapi_resource.foundry.name}-private-link-service-connection"
    private_connection_resource_id = azapi_resource.foundry.id
    subresource_names = [
      "account"
    ]
    is_manual_connection = false
  }

  private_dns_zone_group {
    name = "${azapi_resource.foundry.name}-dns-config"
    private_dns_zone_ids = [
      "${data.terraform_remote_state.networking.outputs.rg_net00_id}/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com",
      "${data.terraform_remote_state.networking.outputs.rg_net00_id}/providers/Microsoft.Network/privateDnsZones/privatelink.services.ai.azure.com",
      "${data.terraform_remote_state.networking.outputs.rg_net00_id}/providers/Microsoft.Network/privateDnsZones/privatelink.openai.azure.com"
    ]
  }
}

# Managed Network Configuration
resource "azapi_resource" "managed_network" {
  type      = "Microsoft.CognitiveServices/accounts/managedNetworks@2025-10-01-preview"
  name      = "default"
  parent_id = azapi_resource.foundry.id

  schema_validation_enabled = false

  body = {
    properties = {
      managedNetwork = {
        isolationMode      = "AllowInternetOutbound"
        managedNetworkKind = "V2"
        provisionNetworkNow = true
      }
    }
  }
  depends_on = [
    azapi_resource.foundry,
    azurerm_role_assignment.foundry_network_connection_approver
  ]
}

# Role Assignment: Network Connection Approver for Foundry Account Identity
# This role is required for the Foundry account to approve managed network private endpoint connections
resource "azurerm_role_assignment" "foundry_network_connection_approver" {
  scope                = azurerm_resource_group.rg-ai01.id
  role_definition_name = "Azure AI Enterprise Network Connection Approver"
  principal_id         = azapi_resource.foundry.output.identity.principalId
}

# Role Assignment: Storage Blob Data Contributor
resource "azurerm_role_assignment" "foundry_storage_blob" {
  scope                = azurerm_storage_account.storage_account.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azapi_resource.foundry.output.identity.principalId
}

# Role Assignment: Contributor on Storage Account
resource "azurerm_role_assignment" "foundry_storage_contributor" {
  scope                = azurerm_storage_account.storage_account.id
  role_definition_name = "Contributor"
  principal_id         = azapi_resource.foundry.output.identity.principalId
}

## Create a deployment for OpenAI's GPT-4o in the Foundry resource
##
resource "azurerm_cognitive_deployment" "foundry_deployment_gpt_4o" {
  depends_on = [
    azapi_resource.foundry
  ]

  name                 = "gpt-4o"
  cognitive_account_id = azapi_resource.foundry.id

  sku {
    name     = "GlobalStandard"
    capacity = 1
  }

  model {
    format  = "OpenAI"
    name    = "gpt-4o"
    version = "2024-11-20"
  }
}

########## Create the Foundry project, project connections, role assignments, and project-level capability host
##########

## Create Foundry project
##
resource "azapi_resource" "foundry_project" {
  depends_on = [
    azapi_resource.foundry,
    azurerm_private_endpoint.pe-storage-blob,
    azurerm_private_endpoint.pe-cosmosdb,
    azurerm_private_endpoint.pe-aisearch,
    azurerm_private_endpoint.pe-foundry
  ]

  type                      = "Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview"
  name                      = "project${random_string.unique.result}"
  parent_id                 = azapi_resource.foundry.id
  location                  = azurerm_resource_group.rg-ai01.location

  schema_validation_enabled = false

  identity {
    type = "SystemAssigned"
  }

  body = {
    properties = {
      displayName = "project"
      description = "A project for the Foundry account with network secured deployed Agent"
    }
  }

  response_export_values = [
    "identity.principalId",
    "properties.internalId"
  ]
}

## Wait 10 seconds for the Foundry project system-assigned managed identity to be created and to replicate
## through Entra ID
resource "time_sleep" "wait_project_identities" {
  depends_on = [
    azapi_resource.foundry_project
  ]
  create_duration = "60s"
}

## Create Foundry project connections
##
resource "azapi_resource" "conn_cosmosdb" {
  type                      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-10-01-preview"
  name                      = azurerm_cosmosdb_account.cosmosdb.name
  parent_id                 = azapi_resource.foundry_project.id

  schema_validation_enabled = false

  body = {
    properties = {
      category = "CosmosDB"
      target   = azurerm_cosmosdb_account.cosmosdb.endpoint
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ResourceId = azurerm_cosmosdb_account.cosmosdb.id
        location   = azurerm_resource_group.rg-ai01.location
      }
    }
  }
}

## Create the Foundry project connection to Azure Storage Account
##
resource "azapi_resource" "conn_storage" {
  type                      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-10-01-preview"
  name                      = azurerm_storage_account.storage_account.name
  parent_id                 = azapi_resource.foundry_project.id

  schema_validation_enabled = false

  body = {
    properties = {
      category = "AzureStorageAccount"
      target   = azurerm_storage_account.storage_account.primary_blob_endpoint
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ResourceId = azurerm_storage_account.storage_account.id
        location   = azurerm_resource_group.rg-ai01.location
      }
    }
  }
}

## Create the Foundry project connection to AI Search
##
resource "azapi_resource" "conn_aisearch" {
  type                      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-10-01-preview"
  name                      = azapi_resource.ai_search.name
  parent_id                 = azapi_resource.foundry_project.id

  schema_validation_enabled = false

  body = {
    properties = {
      category = "CognitiveSearch"
      target   = "https://${azapi_resource.ai_search.name}.search.windows.net"
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ApiVersion = "2025-05-01-preview"
        ResourceId = azapi_resource.ai_search.id
        location   = azurerm_resource_group.rg-ai01.location
      }
    }
  }
}

## Create the necessary role assignments for the Foundry project over the resources used to store agent data
##
resource "azurerm_role_assignment" "cosmosdb_operator_foundry_project" {
  depends_on = [
    resource.time_sleep.wait_project_identities
  ]
  name                 = uuidv5("dns", "${azapi_resource.foundry_project.name}${azapi_resource.foundry_project.output.identity.principalId}${azurerm_resource_group.rg-ai01.name}cosmosdboperator")
  scope                = azurerm_cosmosdb_account.cosmosdb.id
  role_definition_name = "Cosmos DB Operator"
  principal_id         = azapi_resource.foundry_project.output.identity.principalId
}

resource "azurerm_role_assignment" "cosmosdb_reader_foundry_project" {
  depends_on = [
    resource.time_sleep.wait_project_identities
  ]
  name                 = uuidv5("dns", "${azapi_resource.foundry_project.name}${azapi_resource.foundry_project.output.identity.principalId}${azurerm_resource_group.rg-ai01.name}cosmosdbreader")
  scope                = azurerm_cosmosdb_account.cosmosdb.id
  role_definition_name = "Cosmos DB Account Reader Role"
  principal_id         = azapi_resource.foundry_project.output.identity.principalId
}

resource "azurerm_role_assignment" "storage_blob_data_contributor_foundry_project" {
  depends_on = [
    resource.time_sleep.wait_project_identities
  ]
  name                 = uuidv5("dns", "${azapi_resource.foundry_project.name}${azapi_resource.foundry_project.output.identity.principalId}${azurerm_storage_account.storage_account.name}storageblobdatacontributor")
  scope                = azurerm_storage_account.storage_account.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azapi_resource.foundry_project.output.identity.principalId
}

resource "azurerm_role_assignment" "search_index_data_contributor_foundry_project" {
  depends_on = [
    resource.time_sleep.wait_project_identities
  ]
  name                 = uuidv5("dns", "${azapi_resource.foundry_project.name}${azapi_resource.foundry_project.output.identity.principalId}${azapi_resource.ai_search.name}searchindexdatacontributor")
  scope                = azapi_resource.ai_search.id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = azapi_resource.foundry_project.output.identity.principalId
}

resource "azurerm_role_assignment" "search_service_contributor_foundry_project" {
  depends_on = [
    resource.time_sleep.wait_project_identities
  ]
  name                 = uuidv5("dns", "${azapi_resource.foundry_project.name}${azapi_resource.foundry_project.output.identity.principalId}${azapi_resource.ai_search.name}searchservicecontributor")
  scope                = azapi_resource.ai_search.id
  role_definition_name = "Search Service Contributor"
  principal_id         = azapi_resource.foundry_project.output.identity.principalId
}

## Pause 60 seconds to allow for role assignments to propagate
##
resource "time_sleep" "wait_rbac" {
  depends_on = [
    azurerm_role_assignment.cosmosdb_operator_foundry_project,
    azurerm_role_assignment.cosmosdb_reader_foundry_project,
    azurerm_role_assignment.storage_blob_data_contributor_foundry_project,
    azurerm_role_assignment.search_index_data_contributor_foundry_project,
    azurerm_role_assignment.search_service_contributor_foundry_project
  ]
  create_duration = "90s"
}

# Wait for managed network outbound rules to fully provision
# Outbound rules need additional time beyond creation to be in Succeeded state
# Azure managed network provisioning can take several minutes
resource "time_sleep" "wait_outbound_rules" {
  create_duration = "600s"

  depends_on = [
    azapi_resource.storage_outbound_rule,
    azapi_resource.cosmos_outbound_rule,
    azapi_resource.aisearch_outbound_rule
  ]
}

## Create the Foundry project capability host
##
resource "azapi_resource" "foundry_project_capability_host" {
  type                      = "Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-04-01-preview"
  name                      = "caphostproj"
  parent_id                 = azapi_resource.foundry_project.id

  schema_validation_enabled = false

  body = {
    properties = {
      capabilityHostKind = "Agents"
      vectorStoreConnections = [
        azapi_resource.ai_search.name
      ]
      storageConnections = [
        azurerm_storage_account.storage_account.name
      ]
      threadStorageConnections = [
        azurerm_cosmosdb_account.cosmosdb.name
      ]
    }
  }
  depends_on = [
    azapi_resource.foundry_project,
    azapi_resource.conn_aisearch,
    azapi_resource.conn_cosmosdb,
    azapi_resource.conn_storage,
      # Project role assignments must be complete (matching Bicep dependencies)
    azurerm_role_assignment.cosmosdb_operator_foundry_project,
    azurerm_role_assignment.cosmosdb_reader_foundry_project,
    azurerm_role_assignment.storage_blob_data_contributor_foundry_project,
    azurerm_role_assignment.search_index_data_contributor_foundry_project,
    azurerm_role_assignment.search_service_contributor_foundry_project,
    # Wait for RBAC propagation
    time_sleep.wait_rbac,
    # CRITICAL: All outbound rules must be created AND provisioned before capability host
    # The capability host validates that outbound rules exist and are in Succeeded state
    azapi_resource.storage_outbound_rule,
    azapi_resource.cosmos_outbound_rule,
    azapi_resource.aisearch_outbound_rule,
    time_sleep.wait_outbound_rules
  ]
}

## Create the necessary data plane role assignments to the CosmosDb databases created by the Foundry Project
##
resource "azurerm_cosmosdb_sql_role_assignment" "cosmosdb_db_sql_role_aifp_user_thread_message_store" {
  depends_on = [
    azapi_resource.foundry_project_capability_host
  ]
  name                = uuidv5("dns", "${azapi_resource.foundry_project.name}${azapi_resource.foundry_project.output.identity.principalId}userthreadmessage_dbsqlrole")
  resource_group_name = azurerm_resource_group.rg-ai01.name
  account_name        = azurerm_cosmosdb_account.cosmosdb.name
  scope               = "${azurerm_cosmosdb_account.cosmosdb.id}/dbs/enterprise_memory/colls/${local.project_id_guid}-thread-message-store"
  role_definition_id  = "${azurerm_cosmosdb_account.cosmosdb.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = azapi_resource.foundry_project.output.identity.principalId
}

resource "azurerm_cosmosdb_sql_role_assignment" "cosmosdb_db_sql_role_aifp_system_thread_name" {
  depends_on = [
    azurerm_cosmosdb_sql_role_assignment.cosmosdb_db_sql_role_aifp_user_thread_message_store
  ]
  name                = uuidv5("dns", "${azapi_resource.foundry_project.name}${azapi_resource.foundry_project.output.identity.principalId}systemthread_dbsqlrole")
  resource_group_name = azurerm_resource_group.rg-ai01.name
  account_name        = azurerm_cosmosdb_account.cosmosdb.name
  scope               = "${azurerm_cosmosdb_account.cosmosdb.id}/dbs/enterprise_memory/colls/${local.project_id_guid}-system-thread-message-store"
  role_definition_id  = "${azurerm_cosmosdb_account.cosmosdb.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = azapi_resource.foundry_project.output.identity.principalId
}

resource "azurerm_cosmosdb_sql_role_assignment" "cosmosdb_db_sql_role_aifp_entity_store_name" {
  depends_on = [
    azurerm_cosmosdb_sql_role_assignment.cosmosdb_db_sql_role_aifp_system_thread_name
  ]
  name                = uuidv5("dns", "${azapi_resource.foundry_project.name}${azapi_resource.foundry_project.output.identity.principalId}entitystore_dbsqlrole")
  resource_group_name = azurerm_resource_group.rg-ai01.name
  account_name        = azurerm_cosmosdb_account.cosmosdb.name
  scope               = "${azurerm_cosmosdb_account.cosmosdb.id}/dbs/enterprise_memory/colls/${local.project_id_guid}-agent-entity-store"
  role_definition_id  = "${azurerm_cosmosdb_account.cosmosdb.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = azapi_resource.foundry_project.output.identity.principalId
}

## Create the necessary data plane role assignments to the Azure Storage Account containers created by the Foundry Project
##
resource "azurerm_role_assignment" "storage_blob_data_owner_foundry_project" {
  depends_on = [
    azapi_resource.foundry_project_capability_host
  ]
  name                 = uuidv5("dns", "${azapi_resource.foundry_project.name}${azapi_resource.foundry_project.output.identity.principalId}${azurerm_storage_account.storage_account.name}storageblobdataowner")
  scope                = azurerm_storage_account.storage_account.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azapi_resource.foundry_project.output.identity.principalId
  condition_version    = "2.0"
  condition            = <<-EOT
  (
    (
      !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags/read'})  
      AND  !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/filter/action'}) 
      AND  !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags/write'}) 
    ) 
    OR 
    (@Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringStartsWithIgnoreCase '${local.project_id_guid}' 
    AND @Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringLikeIgnoreCase '*-azureml-agent')
  )
  EOT
}

# Role Assignment: Cosmos DB Built-in Data Contributor
# This must be assigned AFTER the capability host is created
resource "azurerm_cosmosdb_sql_role_assignment" "project_cosmos_builtin_contributor" {
  resource_group_name = azurerm_resource_group.rg-ai01.name
  account_name        = azurerm_cosmosdb_account.cosmosdb.name
  
  # Cosmos DB Built-in Data Contributor role
  role_definition_id = "${azurerm_cosmosdb_account.cosmosdb.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  
  principal_id = azapi_resource.foundry_project.output.identity.principalId
  scope        = azurerm_cosmosdb_account.cosmosdb.id

  depends_on = [
    azapi_resource.foundry_project_capability_host
  ]
}