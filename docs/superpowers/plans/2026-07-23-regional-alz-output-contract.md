# Regional ALZ output contract implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Networking's region-specific scalar outputs with one regional `alz_regions` contract and migrate every existing application landing zone to consume its region-0 values.

**Architecture:** The `Networking/modules/region-hub` child module will publish a stable map of regional Private DNS zone IDs. The Networking root will combine each child module's resource, vHub, Firewall, DNS, and zone data into `alz_regions.region0` and `alz_regions.region1`. Existing ALZs will use a local `platform_region0` alias so package 1 changes only the data contract; regional resource composition remains in later roadmap packages.

**Tech Stack:** Terraform >= 1.11, AzureRM, AzAPI, local `terraform_remote_state`, PowerShell, Azure Virtual WAN, Azure Private DNS Resolver

## Global constraints

- Run Terraform from the module directory being changed, never from the repository root.
- Preserve each module's existing provider constraints.
- Keep `log_analytics_workspace_id` as a shared top-level Networking output.
- Move regional Private DNS zone IDs into `alz_regions`.
- Do not retain the old regional scalar outputs after all consumers are migrated.
- Do not add Terraform `moved` blocks; this lab uses destroy-and-redeploy upgrades.
- Do not add `.tftest.hcl`, TFLint, CI, or other test tooling.
- Do not commit state, `.tfvars`, plan files, or `.terraform/`.
- Preserve unrelated working-tree changes, especially `.github/copilot-instructions.md` and `Foundry-managedVnet/storage.tf`.
- Execute this plan in an isolated worktree created with the `using-git-worktrees` skill; the current root worktree contains unrelated changes.
- Every commit must include the required Copilot trailers.

---

## File map

### Networking contract

- Modify `Networking/modules/region-hub/outputs.tf`: publish `private_dns_zone_ids`.
- Modify `Networking/outputs.tf`: add `alz_regions`, temporarily retain old outputs until all consumers are migrated, then remove them in Task 6.
- Modify `Networking/README.md`: document the final contract.

### Foundry BYO VNet consumer

- Modify `Foundry-byoVnet/locals.tf`: add `local.platform_region0`.
- Modify `Foundry-byoVnet/main.tf`: migrate checks, naming, and location.
- Modify `Foundry-byoVnet/networking.tf`: migrate vHub, Firewall, DNS, and naming references.
- Modify `Foundry-byoVnet/aisearch.tf`: migrate Search Private DNS zone.
- Modify `Foundry-byoVnet/cosmosdb.tf`: migrate Cosmos DB Private DNS zone.
- Modify `Foundry-byoVnet/storage.tf`: migrate Blob Private DNS zone.
- Modify `Foundry-byoVnet/foundry.tf`: migrate Foundry Private DNS zones.

### Foundry managed VNet consumer

- Modify `Foundry-managedVnet/locals.tf`: add `local.platform_region0`.
- Modify `Foundry-managedVnet/main.tf`: migrate checks, naming, and location.
- Modify `Foundry-managedVnet/networking.tf`: migrate vHub, Firewall, DNS, and naming references.
- Modify `Foundry-managedVnet/aisearch.tf`: migrate Search Private DNS zone.
- Modify `Foundry-managedVnet/cosmosdb.tf`: migrate Cosmos DB Private DNS zone.
- Modify `Foundry-managedVnet/storage.tf`: migrate Blob, File, Table, and Queue Private DNS zones.
- Modify `Foundry-managedVnet/foundry.tf`: migrate Foundry Private DNS zones.

### Container Apps consumer

- Modify `ContainerApps-byoVnet/locals.tf`: add `local.platform_region0`.
- Modify `ContainerApps-byoVnet/main.tf`: migrate checks, naming, and location.
- Modify `ContainerApps-byoVnet/networking.tf`: migrate vHub, Firewall, DNS, and naming references.
- Modify `ContainerApps-byoVnet/aca.tf`: migrate regional naming.
- Modify `ContainerApps-byoVnet/acr.tf`: migrate regional naming and ACR Private DNS.
- Modify `ContainerApps-byoVnet/app.tf`: migrate application naming.
- Modify `ContainerApps-byoVnet/dns.tf`: migrate the platform DNS VNet ID.

### Fabric consumer

- Modify `Fabric-private/locals.tf`: add `local.platform_region0`.
- Modify `Fabric-private/main.tf`: migrate checks, naming, and location.
- Modify `Fabric-private/networking.tf`: migrate vHub, Firewall, DNS, and naming references.
- Modify `Fabric-private/fabric.tf`: migrate Fabric Private DNS.
- Modify `Fabric-private/storage.tf`: migrate regional naming and Key Vault Private DNS.

### Contributor documentation

- Modify `docs/adding-application-landing-zone.md`: teach `alz_regions`.
- Modify `.github/copilot-instructions.md`: replace the old scalar-output convention without disturbing unrelated edits.

## Interface produced by Task 1

Networking will expose this shape:

```hcl
data.terraform_remote_state.networking.outputs.alz_regions = {
  region0 = {
    enabled                = bool
    region_name            = string
    region_abbr            = string
    resource_group_id      = string
    resource_group_name    = string
    resource_group_location = string
    vhub_id                = string
    firewall_enabled       = bool
    dns_server_ip          = string
    dns_resolver_policy_id = string
    dns_vnet_id            = string
    private_dns_zone_ids = {
      blob                 = string
      file                 = string
      table                = string
      queue                = string
      vaultcore            = string
      cognitiveservices    = string
      openai               = string
      services_ai          = string
      search               = string
      documents            = string
      acr                  = string
      fabric               = string
      sql                  = string
    }
  }
  region1 = {
    # Same attributes. Resource-derived values are null when enabled = false.
  }
}
```

Application modules consume region 0 through:

```hcl
locals {
  platform_region0 = data.terraform_remote_state.networking.outputs.alz_regions.region0
}
```

---

### Task 1: Add the regional Networking contract

**Files:**
- Modify: `Networking/modules/region-hub/outputs.tf:87-97`
- Modify: `Networking/outputs.tf:1-121`

**Interfaces:**
- Consumes: `module.region0`, optional `module.region1[0]`, regional resource groups, and Networking feature variables.
- Produces: `output.alz_regions` and `module.region-hub.private_dns_zone_ids`.

- [ ] **Step 1: Record the baseline contract**

Run:

```powershell
Set-Location C:\github\anp
rg 'output "(rg_net00_|azure_region_0_abbr|vhub0[01]_id|dns_zone_|add_firewall00|dns_resolver_policy00_id|dns_inbound_endpoint00_ip|firewall_private_ip00|dns_vnet00_id|dns_server_ip00)' Networking\outputs.tf
rg 'output "private_dns_zone_ids"' Networking\modules\region-hub\outputs.tf
```

Expected:

- The first command finds the current scalar outputs.
- The second command returns no matches.

- [ ] **Step 2: Replace the child module's two Fabric-specific DNS outputs with one complete map**

Replace `private_dns_zone_fabric_id` and `private_dns_zone_sql_id` in `Networking/modules/region-hub/outputs.tf` with:

```hcl
# ── Private DNS Zone IDs ─────────────────────────────────────────

output "private_dns_zone_ids" {
  description = "Private DNS Zone IDs for application landing zones; values are null when Private DNS is disabled"
  value = {
    blob              = var.add_private_dns ? "${var.resource_group_id}/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net" : null
    file              = var.add_private_dns ? "${var.resource_group_id}/providers/Microsoft.Network/privateDnsZones/privatelink.file.core.windows.net" : null
    table             = var.add_private_dns ? "${var.resource_group_id}/providers/Microsoft.Network/privateDnsZones/privatelink.table.core.windows.net" : null
    queue             = var.add_private_dns ? "${var.resource_group_id}/providers/Microsoft.Network/privateDnsZones/privatelink.queue.core.windows.net" : null
    vaultcore         = var.add_private_dns ? "${var.resource_group_id}/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net" : null
    cognitiveservices = var.add_private_dns ? "${var.resource_group_id}/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com" : null
    openai            = var.add_private_dns ? "${var.resource_group_id}/providers/Microsoft.Network/privateDnsZones/privatelink.openai.azure.com" : null
    services_ai       = var.add_private_dns ? "${var.resource_group_id}/providers/Microsoft.Network/privateDnsZones/privatelink.services.ai.azure.com" : null
    search            = var.add_private_dns ? "${var.resource_group_id}/providers/Microsoft.Network/privateDnsZones/privatelink.search.windows.net" : null
    documents         = var.add_private_dns ? "${var.resource_group_id}/providers/Microsoft.Network/privateDnsZones/privatelink.documents.azure.com" : null
    acr               = var.add_private_dns ? "${var.resource_group_id}/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io" : null
    fabric            = var.add_private_dns ? "${var.resource_group_id}/providers/Microsoft.Network/privateDnsZones/privatelink.fabric.microsoft.com" : null
    sql               = var.add_private_dns ? "${var.resource_group_id}/providers/Microsoft.Network/privateDnsZones/privatelink.database.windows.net" : null
  }
}
```

- [ ] **Step 3: Append `alz_regions` while temporarily retaining the scalar outputs**

Add this block to `Networking/outputs.tf` after `log_analytics_workspace_id`:

```hcl
output "alz_regions" {
  description = "Regional platform contract consumed by application landing zones"
  value = {
    region0 = {
      enabled                 = true
      region_name             = var.azure_region_0_name
      region_abbr             = var.azure_region_0_abbr
      resource_group_id       = azurerm_resource_group.rg-net00.id
      resource_group_name     = azurerm_resource_group.rg-net00.name
      resource_group_location = azurerm_resource_group.rg-net00.location
      vhub_id                 = module.region0.hub_id
      firewall_enabled        = var.add_firewall00
      dns_server_ip = var.add_private_dns00 ? (
        var.add_firewall00 ? module.region0.firewall_private_ip : module.region0.dns_inbound_endpoint_ip
      ) : null
      dns_resolver_policy_id = module.region0.dns_resolver_policy_id
      dns_vnet_id            = module.region0.dns_vnet_id
      private_dns_zone_ids   = module.region0.private_dns_zone_ids
    }
    region1 = {
      enabled                 = var.create_vhub01
      region_name             = var.azure_region_1_name
      region_abbr             = var.azure_region_1_abbr
      resource_group_id       = try(azurerm_resource_group.rg-net01[0].id, null)
      resource_group_name     = try(azurerm_resource_group.rg-net01[0].name, null)
      resource_group_location = try(azurerm_resource_group.rg-net01[0].location, null)
      vhub_id                 = try(module.region1[0].hub_id, null)
      firewall_enabled        = var.create_vhub01 && var.add_firewall01
      dns_server_ip = var.create_vhub01 && var.add_private_dns01 ? (
        var.add_firewall01 ? module.region1[0].firewall_private_ip : module.region1[0].dns_inbound_endpoint_ip
      ) : null
      dns_resolver_policy_id = try(module.region1[0].dns_resolver_policy_id, null)
      dns_vnet_id            = try(module.region1[0].dns_vnet_id, null)
      private_dns_zone_ids = var.create_vhub01 ? module.region1[0].private_dns_zone_ids : {
        for key in keys(module.region0.private_dns_zone_ids) : key => null
      }
    }
  }
}
```

Do not remove the existing scalar outputs yet. They keep intermediate commits usable while Tasks 2-5 migrate consumers. They are removed before package completion.

- [ ] **Step 4: Format and validate Networking**

Run:

```powershell
Set-Location C:\github\anp\Networking
terraform init -backend=false
terraform fmt
terraform fmt -check
terraform validate
```

Expected: initialization succeeds, formatting is clean, and validation reports `Success! The configuration is valid.`

- [ ] **Step 5: Commit the contract**

```powershell
git -C C:\github\anp add Networking\modules\region-hub\outputs.tf Networking\outputs.tf
@'
feat(networking): add regional ALZ output contract

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
Copilot-Session: a8b61622-73a7-4118-a0e4-03989f28d424
'@ | git -C C:\github\anp commit -F -
```

---

### Task 2: Migrate Foundry BYO VNet to `alz_regions`

**Files:**
- Modify: `Foundry-byoVnet/locals.tf`
- Modify: `Foundry-byoVnet/main.tf`
- Modify: `Foundry-byoVnet/networking.tf`
- Modify: `Foundry-byoVnet/aisearch.tf`
- Modify: `Foundry-byoVnet/cosmosdb.tf`
- Modify: `Foundry-byoVnet/storage.tf`
- Modify: `Foundry-byoVnet/foundry.tf`

**Interfaces:**
- Consumes: `data.terraform_remote_state.networking.outputs.alz_regions.region0`.
- Produces: No new outputs; preserves the current region-0 deployment behavior.

- [ ] **Step 1: Confirm the module still uses scalar outputs**

Run:

```powershell
Set-Location C:\github\anp
rg 'terraform_remote_state\.networking\.outputs\.(rg_net00_location|azure_region_0_abbr|vhub00_id|add_firewall00|dns_server_ip00|dns_resolver_policy00_id|dns_zone_)' Foundry-byoVnet -g '*.tf'
```

Expected: matches in `main.tf`, `networking.tf`, `aisearch.tf`, `cosmosdb.tf`, `storage.tf`, and `foundry.tf`.

- [ ] **Step 2: Add the regional alias**

Add this entry at the start of the existing `locals` block in `Foundry-byoVnet/locals.tf`:

```hcl
  platform_region0 = data.terraform_remote_state.networking.outputs.alz_regions.region0
```

- [ ] **Step 3: Replace every regional scalar reference**

Apply these exact replacements:

| Old expression | New expression |
|---|---|
| `data.terraform_remote_state.networking.outputs.azure_region_0_abbr` | `local.platform_region0.region_abbr` |
| `data.terraform_remote_state.networking.outputs.rg_net00_location` | `local.platform_region0.resource_group_location` |
| `data.terraform_remote_state.networking.outputs.vhub00_id` | `local.platform_region0.vhub_id` |
| `data.terraform_remote_state.networking.outputs.add_firewall00` | `local.platform_region0.firewall_enabled` |
| `data.terraform_remote_state.networking.outputs.dns_server_ip00` | `local.platform_region0.dns_server_ip` |
| `data.terraform_remote_state.networking.outputs.dns_resolver_policy00_id` | `local.platform_region0.dns_resolver_policy_id` |
| `data.terraform_remote_state.networking.outputs.dns_zone_blob_id` | `local.platform_region0.private_dns_zone_ids.blob` |
| `data.terraform_remote_state.networking.outputs.dns_zone_search_id` | `local.platform_region0.private_dns_zone_ids.search` |
| `data.terraform_remote_state.networking.outputs.dns_zone_documents_id` | `local.platform_region0.private_dns_zone_ids.documents` |
| `data.terraform_remote_state.networking.outputs.dns_zone_cognitiveservices_id` | `local.platform_region0.private_dns_zone_ids.cognitiveservices` |
| `data.terraform_remote_state.networking.outputs.dns_zone_services_ai_id` | `local.platform_region0.private_dns_zone_ids.services_ai` |
| `data.terraform_remote_state.networking.outputs.dns_zone_openai_id` | `local.platform_region0.private_dns_zone_ids.openai` |

Leave `data.terraform_remote_state.networking.outputs.log_analytics_workspace_id` unchanged.

- [ ] **Step 4: Prove the scalar references are gone and validate**

Run:

```powershell
Set-Location C:\github\anp
rg 'terraform_remote_state\.networking\.outputs\.(rg_net00_location|azure_region_0_abbr|vhub00_id|add_firewall00|dns_server_ip00|dns_resolver_policy00_id|dns_zone_)' Foundry-byoVnet -g '*.tf'
Set-Location C:\github\anp\Foundry-byoVnet
terraform init -backend=false
terraform fmt
terraform fmt -check
terraform validate
```

Expected: `rg` returns no matches; Terraform validation succeeds.

- [ ] **Step 5: Commit the Foundry BYO migration**

```powershell
git -C C:\github\anp add Foundry-byoVnet\locals.tf Foundry-byoVnet\main.tf Foundry-byoVnet\networking.tf Foundry-byoVnet\aisearch.tf Foundry-byoVnet\cosmosdb.tf Foundry-byoVnet\storage.tf Foundry-byoVnet\foundry.tf
@'
refactor(foundry): consume regional platform contract

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
Copilot-Session: a8b61622-73a7-4118-a0e4-03989f28d424
'@ | git -C C:\github\anp commit -F -
```

---

### Task 3: Migrate Foundry managed VNet to `alz_regions`

**Files:**
- Modify: `Foundry-managedVnet/locals.tf`
- Modify: `Foundry-managedVnet/main.tf`
- Modify: `Foundry-managedVnet/networking.tf`
- Modify: `Foundry-managedVnet/aisearch.tf`
- Modify: `Foundry-managedVnet/cosmosdb.tf`
- Modify: `Foundry-managedVnet/storage.tf`
- Modify: `Foundry-managedVnet/foundry.tf`

**Interfaces:**
- Consumes: `data.terraform_remote_state.networking.outputs.alz_regions.region0`.
- Produces: No new outputs; preserves the current region-0 deployment behavior.

- [ ] **Step 1: Confirm the module still uses scalar outputs**

Run:

```powershell
Set-Location C:\github\anp
rg 'terraform_remote_state\.networking\.outputs\.(rg_net00_location|azure_region_0_abbr|vhub00_id|add_firewall00|dns_server_ip00|dns_resolver_policy00_id|dns_zone_)' Foundry-managedVnet -g '*.tf'
```

Expected: matches in the managed-VNet module.

- [ ] **Step 2: Add the regional alias without disturbing existing managed-network locals**

Add this entry at the start of the existing `locals` block in `Foundry-managedVnet/locals.tf`:

```hcl
  platform_region0 = data.terraform_remote_state.networking.outputs.alz_regions.region0
```

- [ ] **Step 3: Replace every regional scalar reference**

Apply these exact replacements:

| Old expression | New expression |
|---|---|
| `data.terraform_remote_state.networking.outputs.azure_region_0_abbr` | `local.platform_region0.region_abbr` |
| `data.terraform_remote_state.networking.outputs.rg_net00_location` | `local.platform_region0.resource_group_location` |
| `data.terraform_remote_state.networking.outputs.vhub00_id` | `local.platform_region0.vhub_id` |
| `data.terraform_remote_state.networking.outputs.add_firewall00` | `local.platform_region0.firewall_enabled` |
| `data.terraform_remote_state.networking.outputs.dns_server_ip00` | `local.platform_region0.dns_server_ip` |
| `data.terraform_remote_state.networking.outputs.dns_resolver_policy00_id` | `local.platform_region0.dns_resolver_policy_id` |
| `data.terraform_remote_state.networking.outputs.dns_zone_blob_id` | `local.platform_region0.private_dns_zone_ids.blob` |
| `data.terraform_remote_state.networking.outputs.dns_zone_file_id` | `local.platform_region0.private_dns_zone_ids.file` |
| `data.terraform_remote_state.networking.outputs.dns_zone_table_id` | `local.platform_region0.private_dns_zone_ids.table` |
| `data.terraform_remote_state.networking.outputs.dns_zone_queue_id` | `local.platform_region0.private_dns_zone_ids.queue` |
| `data.terraform_remote_state.networking.outputs.dns_zone_search_id` | `local.platform_region0.private_dns_zone_ids.search` |
| `data.terraform_remote_state.networking.outputs.dns_zone_documents_id` | `local.platform_region0.private_dns_zone_ids.documents` |
| `data.terraform_remote_state.networking.outputs.dns_zone_cognitiveservices_id` | `local.platform_region0.private_dns_zone_ids.cognitiveservices` |
| `data.terraform_remote_state.networking.outputs.dns_zone_services_ai_id` | `local.platform_region0.private_dns_zone_ids.services_ai` |
| `data.terraform_remote_state.networking.outputs.dns_zone_openai_id` | `local.platform_region0.private_dns_zone_ids.openai` |

Leave `log_analytics_workspace_id` references unchanged. Before editing `Foundry-managedVnet/storage.tf`, inspect the current file and preserve any unrelated work already present.

- [ ] **Step 4: Prove the scalar references are gone and validate**

Run:

```powershell
Set-Location C:\github\anp
rg 'terraform_remote_state\.networking\.outputs\.(rg_net00_location|azure_region_0_abbr|vhub00_id|add_firewall00|dns_server_ip00|dns_resolver_policy00_id|dns_zone_)' Foundry-managedVnet -g '*.tf'
Set-Location C:\github\anp\Foundry-managedVnet
terraform init -backend=false
terraform fmt
terraform fmt -check
terraform validate
```

Expected: `rg` returns no matches; Terraform validation succeeds.

- [ ] **Step 5: Commit the Foundry managed-VNet migration**

Stage only the listed files, not unrelated changes:

```powershell
git -C C:\github\anp add Foundry-managedVnet\locals.tf Foundry-managedVnet\main.tf Foundry-managedVnet\networking.tf Foundry-managedVnet\aisearch.tf Foundry-managedVnet\cosmosdb.tf Foundry-managedVnet\storage.tf Foundry-managedVnet\foundry.tf
@'
refactor(foundry): migrate managed VNet platform contract

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
Copilot-Session: a8b61622-73a7-4118-a0e4-03989f28d424
'@ | git -C C:\github\anp commit -F -
```

---

### Task 4: Migrate Container Apps to `alz_regions`

**Files:**
- Modify: `ContainerApps-byoVnet/locals.tf`
- Modify: `ContainerApps-byoVnet/main.tf`
- Modify: `ContainerApps-byoVnet/networking.tf`
- Modify: `ContainerApps-byoVnet/aca.tf`
- Modify: `ContainerApps-byoVnet/acr.tf`
- Modify: `ContainerApps-byoVnet/app.tf`
- Modify: `ContainerApps-byoVnet/dns.tf`

**Interfaces:**
- Consumes: `data.terraform_remote_state.networking.outputs.alz_regions.region0`.
- Produces: No new outputs; preserves all three existing `app_mode` values.

- [ ] **Step 1: Confirm the module still uses scalar outputs**

Run:

```powershell
Set-Location C:\github\anp
rg 'terraform_remote_state\.networking\.outputs\.(rg_net00_location|azure_region_0_abbr|vhub00_id|add_firewall00|dns_server_ip00|dns_resolver_policy00_id|dns_vnet00_id|dns_zone_)' ContainerApps-byoVnet -g '*.tf'
```

Expected: matches in the listed Container Apps files.

- [ ] **Step 2: Add the regional alias**

Add this entry at the start of `ContainerApps-byoVnet/locals.tf`:

```hcl
  platform_region0 = data.terraform_remote_state.networking.outputs.alz_regions.region0
```

- [ ] **Step 3: Replace every regional scalar reference**

Apply these exact replacements:

| Old expression | New expression |
|---|---|
| `data.terraform_remote_state.networking.outputs.azure_region_0_abbr` | `local.platform_region0.region_abbr` |
| `data.terraform_remote_state.networking.outputs.rg_net00_location` | `local.platform_region0.resource_group_location` |
| `data.terraform_remote_state.networking.outputs.vhub00_id` | `local.platform_region0.vhub_id` |
| `data.terraform_remote_state.networking.outputs.add_firewall00` | `local.platform_region0.firewall_enabled` |
| `data.terraform_remote_state.networking.outputs.dns_server_ip00` | `local.platform_region0.dns_server_ip` |
| `data.terraform_remote_state.networking.outputs.dns_resolver_policy00_id` | `local.platform_region0.dns_resolver_policy_id` |
| `data.terraform_remote_state.networking.outputs.dns_vnet00_id` | `local.platform_region0.dns_vnet_id` |
| `data.terraform_remote_state.networking.outputs.dns_zone_acr_id` | `local.platform_region0.private_dns_zone_ids.acr` |

Leave all `log_analytics_workspace_id` references unchanged.

- [ ] **Step 4: Prove the scalar references are gone and validate**

Run:

```powershell
Set-Location C:\github\anp
rg 'terraform_remote_state\.networking\.outputs\.(rg_net00_location|azure_region_0_abbr|vhub00_id|add_firewall00|dns_server_ip00|dns_resolver_policy00_id|dns_vnet00_id|dns_zone_)' ContainerApps-byoVnet -g '*.tf'
Set-Location C:\github\anp\ContainerApps-byoVnet
terraform init -backend=false
terraform fmt
terraform fmt -check
terraform validate
```

Expected: `rg` returns no matches; Terraform validation succeeds.

- [ ] **Step 5: Commit the Container Apps migration**

```powershell
git -C C:\github\anp add ContainerApps-byoVnet\locals.tf ContainerApps-byoVnet\main.tf ContainerApps-byoVnet\networking.tf ContainerApps-byoVnet\aca.tf ContainerApps-byoVnet\acr.tf ContainerApps-byoVnet\app.tf ContainerApps-byoVnet\dns.tf
@'
refactor(container-apps): consume regional platform contract

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
Copilot-Session: a8b61622-73a7-4118-a0e4-03989f28d424
'@ | git -C C:\github\anp commit -F -
```

---

### Task 5: Migrate Fabric to `alz_regions`

**Files:**
- Modify: `Fabric-private/locals.tf`
- Modify: `Fabric-private/main.tf`
- Modify: `Fabric-private/networking.tf`
- Modify: `Fabric-private/fabric.tf`
- Modify: `Fabric-private/storage.tf`

**Interfaces:**
- Consumes: `data.terraform_remote_state.networking.outputs.alz_regions.region0`.
- Produces: No new outputs; preserves the current `network_mode` behavior.

- [ ] **Step 1: Confirm the module still uses scalar outputs**

Run:

```powershell
Set-Location C:\github\anp
rg 'terraform_remote_state\.networking\.outputs\.(rg_net00_location|azure_region_0_abbr|vhub00_id|add_firewall00|dns_server_ip00|dns_resolver_policy00_id|dns_zone_)' Fabric-private -g '*.tf'
```

Expected: matches in the listed Fabric files.

- [ ] **Step 2: Add the regional alias**

Add this entry at the start of `Fabric-private/locals.tf`:

```hcl
  platform_region0 = data.terraform_remote_state.networking.outputs.alz_regions.region0
```

- [ ] **Step 3: Replace every regional scalar reference**

Apply these exact replacements:

| Old expression | New expression |
|---|---|
| `data.terraform_remote_state.networking.outputs.azure_region_0_abbr` | `local.platform_region0.region_abbr` |
| `data.terraform_remote_state.networking.outputs.rg_net00_location` | `local.platform_region0.resource_group_location` |
| `data.terraform_remote_state.networking.outputs.vhub00_id` | `local.platform_region0.vhub_id` |
| `data.terraform_remote_state.networking.outputs.add_firewall00` | `local.platform_region0.firewall_enabled` |
| `data.terraform_remote_state.networking.outputs.dns_server_ip00` | `local.platform_region0.dns_server_ip` |
| `data.terraform_remote_state.networking.outputs.dns_resolver_policy00_id` | `local.platform_region0.dns_resolver_policy_id` |
| `data.terraform_remote_state.networking.outputs.dns_zone_vaultcore_id` | `local.platform_region0.private_dns_zone_ids.vaultcore` |
| `data.terraform_remote_state.networking.outputs.dns_zone_fabric_id` | `local.platform_region0.private_dns_zone_ids.fabric` |
| `data.terraform_remote_state.networking.outputs.dns_zone_sql_id` | `local.platform_region0.private_dns_zone_ids.sql` |

Leave `log_analytics_workspace_id` references unchanged.

- [ ] **Step 4: Prove the scalar references are gone and validate**

Run:

```powershell
Set-Location C:\github\anp
rg 'terraform_remote_state\.networking\.outputs\.(rg_net00_location|azure_region_0_abbr|vhub00_id|add_firewall00|dns_server_ip00|dns_resolver_policy00_id|dns_zone_)' Fabric-private -g '*.tf'
Set-Location C:\github\anp\Fabric-private
terraform init -backend=false
terraform fmt
terraform fmt -check
terraform validate
```

Expected: `rg` returns no matches; Terraform validation succeeds.

- [ ] **Step 5: Commit the Fabric migration**

```powershell
git -C C:\github\anp add Fabric-private\locals.tf Fabric-private\main.tf Fabric-private\networking.tf Fabric-private\fabric.tf Fabric-private\storage.tf
@'
refactor(fabric): consume regional platform contract

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
Copilot-Session: a8b61622-73a7-4118-a0e4-03989f28d424
'@ | git -C C:\github\anp commit -F -
```

---

### Task 6: Remove the scalar contract, update docs, and verify the package

**Files:**
- Modify: `Networking/outputs.tf`
- Modify: `Networking/README.md`
- Modify: `docs/adding-application-landing-zone.md`
- Modify: `.github/copilot-instructions.md`

**Interfaces:**
- Consumes: All four existing ALZs migrated in Tasks 2-5.
- Produces: Final `alz_regions`-only regional contract and updated contributor guidance.

- [ ] **Step 1: Verify no Terraform consumer needs the scalar outputs**

Run:

```powershell
Set-Location C:\github\anp
rg 'terraform_remote_state\.networking\.outputs\.(rg_net00_id|rg_net00_name|rg_net00_location|azure_region_0_abbr|vhub00_id|vhub01_id|add_firewall00|dns_resolver_policy00_id|dns_inbound_endpoint00_ip|firewall_private_ip00|dns_vnet00_id|dns_server_ip00|dns_zone_)' -g '*.tf'
```

Expected: no matches.

- [ ] **Step 2: Reduce `Networking/outputs.tf` to shared outputs and `alz_regions`**

Remove these output blocks:

```text
rg_net00_id
rg_net00_location
azure_region_0_abbr
vhub00_id
vhub01_id
dns_zone_blob_id
dns_zone_file_id
dns_zone_table_id
dns_zone_queue_id
dns_zone_vaultcore_id
dns_zone_cognitiveservices_id
dns_zone_openai_id
dns_zone_services_ai_id
dns_zone_search_id
dns_zone_documents_id
dns_zone_acr_id
dns_zone_fabric_id
dns_zone_sql_id
rg_net00_name
add_firewall00
dns_resolver_policy00_id
dns_inbound_endpoint00_ip
firewall_private_ip00
dns_vnet00_id
dns_server_ip00
```

Keep exactly:

- `vm_admin_username`
- `vm_admin_password`
- `log_analytics_workspace_id`
- `alz_regions`

- [ ] **Step 3: Replace the Networking output documentation**

In `Networking/README.md`, replace the current scalar output table with:

```markdown
| Output | Purpose |
|---|---|
| `alz_regions` | Region 0 and optional region 1 resource group, vHub, Firewall, DNS, and Private DNS zone contract |
| `log_analytics_workspace_id` | Shared Log Analytics workspace used by application diagnostics |
| `vm_admin_username`, `vm_admin_password` | Credentials for the platform test VMs |

`alz_regions.region0` is always enabled. `alz_regions.region1.enabled` matches `create_vhub01`; its resource-derived values are null when region 1 is disabled. Application landing zones select their own deployment regions and must not assume that Networking region 1 automatically enables a second workload region.
```

Update the downstream-dependencies paragraph to list all current ALZs and say they consume `alz_regions.region0`.

- [ ] **Step 4: Update the ALZ authoring guide**

In `docs/adding-application-landing-zone.md`, add this local after the remote-state block:

```hcl
locals {
  platform_region0 = data.terraform_remote_state.networking.outputs.alz_regions.region0
}
```

Replace the example resource group with:

```hcl
resource "azurerm_resource_group" "rg" {
  name     = "rg-myworkload-${local.platform_region0.region_abbr}-${random_string.unique.result}"
  location = local.platform_region0.resource_group_location
  tags     = local.common_tags
}
```

Replace the key-output list with:

```markdown
- `alz_regions.<region>.resource_group_*` and `region_abbr` for location and naming
- `alz_regions.<region>.vhub_id` for the spoke connection
- `alz_regions.<region>.firewall_enabled` for `internet_security_enabled`
- `alz_regions.<region>.dns_server_ip`, `dns_resolver_policy_id`, and `dns_vnet_id` for DNS integration
- `alz_regions.<region>.private_dns_zone_ids` for private endpoint zone groups
- `log_analytics_workspace_id` for shared diagnostics
```

Update the naming section to reference `local.platform_region0.region_abbr`.

- [ ] **Step 5: Update repository instructions without overwriting unrelated edits**

In `.github/copilot-instructions.md`, preserve all current user changes and replace only these conventions:

```markdown
- Application resources generally use `{base-name}-{local.platform_region0.region_abbr}-{random_string.unique.result}`. The platform uses `local.suffix = random_string.unique.id`.
- Application spokes use `local.platform_region0` from the `alz_regions` output: vHub connections use `vhub_id`, `internet_security_enabled` follows `firewall_enabled`, private-endpoint subnets use its inverse for `default_outbound_access_enabled`, VNet DNS uses `dns_server_ip`, resolver policy links use `dns_resolver_policy_id`, and private endpoint zone groups use `private_dns_zone_ids`.
- Networking's `alz_regions` entries are null-safe for optional DNS, Firewall, and region-1 resources. Application modules validate required values with `check` blocks before creating dependent resources.
```

- [ ] **Step 6: Run the complete offline verification**

Run:

```powershell
Set-Location C:\github\anp
terraform fmt -check -recursive

Set-Location C:\github\anp\Networking
terraform init -backend=false
terraform validate

Set-Location C:\github\anp\Foundry-byoVnet
terraform init -backend=false
terraform validate

Set-Location C:\github\anp\Foundry-managedVnet
terraform init -backend=false
terraform validate

Set-Location C:\github\anp\ContainerApps-byoVnet
terraform init -backend=false
terraform validate

Set-Location C:\github\anp\Fabric-private
terraform init -backend=false
terraform validate
```

Expected: the recursive format check and all five validations succeed.

- [ ] **Step 7: Run the final contract search**

Run:

```powershell
Set-Location C:\github\anp
rg 'terraform_remote_state\.networking\.outputs\.(rg_net00_id|rg_net00_name|rg_net00_location|azure_region_0_abbr|vhub00_id|vhub01_id|add_firewall00|dns_resolver_policy00_id|dns_inbound_endpoint00_ip|firewall_private_ip00|dns_vnet00_id|dns_server_ip00|dns_zone_)' -g '*.tf' -g '*.md' -g '!docs/superpowers/**'
rg 'output "(rg_net00_|azure_region_0_abbr|vhub0[01]_id|dns_zone_|add_firewall00|dns_resolver_policy00_id|dns_inbound_endpoint00_ip|firewall_private_ip00|dns_vnet00_id|dns_server_ip00)' Networking\outputs.tf
rg '\b(rg_net00_id|rg_net00_name|rg_net00_location|azure_region_0_abbr|vhub00_id|vhub01_id|dns_resolver_policy00_id|dns_inbound_endpoint00_ip|firewall_private_ip00|dns_vnet00_id|dns_server_ip00|dns_zone_[a-z0-9_]+)\b' Networking\README.md docs\adding-application-landing-zone.md .github\copilot-instructions.md
```

Expected: all three commands return no matches.

- [ ] **Step 8: Review authenticated plans when lab state is available**

First review and apply the Networking output-only plan so downstream remote state contains `alz_regions`:

```powershell
Set-Location C:\github\anp\Networking
terraform plan -out=regional-contract.tfplan
terraform show -no-color regional-contract.tfplan
```

Expected: no Networking resources are replaced or destroyed; only output changes appear. Apply the saved plan only after explicit approval:

```powershell
terraform apply regional-contract.tfplan
terraform output -json alz_regions
Remove-Item .\regional-contract.tfplan
```

If the saved plan is not approved for apply, remove it without applying:

```powershell
Remove-Item .\regional-contract.tfplan
```

Then run each ALZ plan:

```powershell
Set-Location C:\github\anp\Foundry-byoVnet
terraform plan

Set-Location C:\github\anp\Foundry-managedVnet
terraform plan

Set-Location C:\github\anp\ContainerApps-byoVnet
terraform plan

Set-Location C:\github\anp\Fabric-private
terraform plan
```

Expected: changing the remote-state access path does not change existing region-0 resource arguments. Any unrelated drift must be reviewed separately rather than attributed to this package.

- [ ] **Step 9: Commit the final contract cleanup**

Stage only package files:

```powershell
git -C C:\github\anp add Networking\outputs.tf Networking\README.md docs\adding-application-landing-zone.md .github\copilot-instructions.md
@'
docs(networking): finalize regional ALZ contract

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
Copilot-Session: a8b61622-73a7-4118-a0e4-03989f28d424
'@ | git -C C:\github\anp commit -F -
```
