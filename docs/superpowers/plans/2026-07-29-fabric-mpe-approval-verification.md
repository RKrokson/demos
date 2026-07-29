# Fabric MPE approval verification implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove false inbound-only MPE warnings and make outbound approval read-back a blocking deployment guarantee.

**Architecture:** Replace the three data sources nested inside warning-only `check` blocks with normal top-level data sources gated by `local.deploy_outbound`. Each outbound read depends on its approval PUT and uses a data-source postcondition to require `Approved`.

**Tech Stack:** Terraform 1.11+, AzureRM 4.26.0, AzAPI 2.3.0, Microsoft Fabric provider 1.10.0, PowerShell

## Global Constraints

- Preserve `network_mode = "inbound_only"` as the default.
- Preserve the existing exact MPE connection match using the `{workspace_id}.{mpe_name}` suffix.
- Never approve a connection by list position, name pattern, pending state, or any criterion other than the exact MPE resource identity.
- Do not change MPE, target resource, or approval-action resource addresses.
- Do not add fixed sleeps or retry loops.
- Inbound-only plans and applies must perform no outbound approval reads and must not construct placeholder resource IDs.
- Outbound approval reads must run after their matching approval PUT.
- An outbound apply must stop when a real connection cannot be read back as `Approved`.
- Terraform does not roll back resources already created before a verification failure; document that operators should resolve the issue and rerun `terraform apply`.
- Keep provider constraints unchanged.
- Do not modify Terraform state, `.tfvars`, or `.terraform/`.

---

## File map

- Modify `Fabric-private/mpe.tf`: replace warning-only nested check data sources with counted top-level read-backs and blocking postconditions.
- Modify `Fabric-private/README.md`: document strict outbound approval verification and partial-apply recovery.

---

### Task 1: Enforce outbound MPE approval read-back

**Files:**
- Modify: `Fabric-private/mpe.tf:170-225`
- Modify: `Fabric-private/README.md:133-141`

**Interfaces:**
- Consumes: `local.deploy_outbound`, `local.storage_pe_conn_name`, `local.sql_pe_conn_name`, `local.kv_pe_conn_name`, and the three `azapi_resource_action.approve_mpe_*` resources.
- Produces: Counted `data.azapi_resource.mpe_storage_conn`, `data.azapi_resource.mpe_sql_conn`, and `data.azapi_resource.mpe_kv_conn` read-backs whose postconditions require `Approved`.

- [ ] **Step 1: Confirm the placeholder warning path exists**

Run:

```powershell
Set-Location (git rev-parse --show-toplevel)
$matches = Select-String -Path Fabric-private\mpe.tf -SimpleMatch '"placeholder-not-deployed"'
if ($matches.Count -ne 3) {
  throw "Expected three placeholder MPE read-back IDs, found $($matches.Count)."
}
```

Expected: the command exits successfully after finding the three placeholder IDs used by the nested check data sources.

- [ ] **Step 2: Replace the nested checks with counted blocking read-backs**

In `Fabric-private/mpe.tf`, delete the `_lab_storage_id`, `_lab_sql_id`, and `_lab_kv_id` locals and replace the entire `Post-apply assertions` section with:

```hcl
# ─────────────────────────────────────────────
# Post-apply verification — read each approved MPE connection back.
# Top-level data sources can share the outbound count gate, so inbound_only
# performs no placeholder reads. Postconditions make failed verification blocking.
# ─────────────────────────────────────────────

data "azapi_resource" "mpe_storage_conn" {
  count       = local.deploy_outbound ? 1 : 0
  type        = "Microsoft.Storage/storageAccounts/privateEndpointConnections@2023-05-01"
  resource_id = "${azurerm_storage_account.lab_storage[0].id}/privateEndpointConnections/${local.storage_pe_conn_name}"

  response_export_values = ["properties.privateLinkServiceConnectionState.status"]
  depends_on             = [azapi_resource_action.approve_mpe_storage]

  lifecycle {
    postcondition {
      condition     = self.output.properties.privateLinkServiceConnectionState.status == "Approved"
      error_message = "Storage MPE approval could not be confirmed. Resolve the private endpoint connection status, then rerun terraform apply."
    }
  }
}

data "azapi_resource" "mpe_sql_conn" {
  count       = local.deploy_outbound ? 1 : 0
  type        = "Microsoft.Sql/servers/privateEndpointConnections@2023-08-01-preview"
  resource_id = "${azurerm_mssql_server.lab_sql[0].id}/privateEndpointConnections/${local.sql_pe_conn_name}"

  response_export_values = ["properties.privateLinkServiceConnectionState.status"]
  depends_on             = [azapi_resource_action.approve_mpe_sql]

  lifecycle {
    postcondition {
      condition     = self.output.properties.privateLinkServiceConnectionState.status == "Approved"
      error_message = "SQL MPE approval could not be confirmed. Resolve the private endpoint connection status, then rerun terraform apply."
    }
  }
}

data "azapi_resource" "mpe_kv_conn" {
  count       = local.deploy_outbound ? 1 : 0
  type        = "Microsoft.KeyVault/vaults/privateEndpointConnections@2023-07-01"
  resource_id = "${azurerm_key_vault.fabric_kv[0].id}/privateEndpointConnections/${local.kv_pe_conn_name}"

  response_export_values = ["properties.privateLinkServiceConnectionState.status"]
  depends_on             = [azapi_resource_action.approve_mpe_keyvault]

  lifecycle {
    postcondition {
      condition     = self.output.properties.privateLinkServiceConnectionState.status == "Approved"
      error_message = "Key Vault MPE approval could not be confirmed. Resolve the private endpoint connection status, then rerun terraform apply."
    }
  }
}
```

- [ ] **Step 3: Format and validate the Terraform module**

Run:

```powershell
Set-Location (Join-Path (git rev-parse --show-toplevel) 'Fabric-private')
terraform.exe fmt mpe.tf
terraform.exe fmt -check
terraform.exe validate -no-color
```

Expected: formatting is clean and validation reports `Success! The configuration is valid.`

- [ ] **Step 4: Verify all network-mode plans**

Run:

```powershell
Set-Location (Join-Path (git rev-parse --show-toplevel) 'Fabric-private')

$modes = @(
  @{ Mode = 'inbound_only';         Slug = 'inbound' },
  @{ Mode = 'outbound_only';        Slug = 'outbound' },
  @{ Mode = 'inbound_and_outbound'; Slug = 'both' }
)

foreach ($item in $modes) {
  $planPath = ".\fabric-$($item.Slug)-strict.tfplan"
  $logPath = Join-Path $env:TEMP "fabric-$($item.Slug)-strict-plan.log"

  terraform.exe plan `
    -input=false `
    -no-color `
    -lock-timeout=60s `
    -var "network_mode=$($item.Mode)" `
    -out $planPath 2>&1 |
    Tee-Object -FilePath $logPath

  if ($LASTEXITCODE -ne 0) {
    throw "Plan failed for network_mode=$($item.Mode)."
  }

  if (Select-String -Path $logPath -SimpleMatch 'Invalid Resource ID') {
    throw "Invalid Resource ID warning remains for network_mode=$($item.Mode)."
  }

  $plan = terraform.exe show -json $planPath | ConvertFrom-Json
  $readBacks = @(
    $plan.resource_changes |
      Where-Object address -Match '^data\.azapi_resource\.mpe_(storage|sql|kv)_conn'
  )
  $inboundResources = @(
    $plan.resource_changes |
      Where-Object address -Match 'fabric_private_link_service|pe_fabric_workspace|workspace_communication_policy'
  )

  $expectedReadBackCount = if ($item.Mode -eq 'inbound_only') { 0 } else { 3 }
  $expectedInboundCount = if ($item.Mode -eq 'outbound_only') { 0 } else { 3 }
  if ($readBacks.Count -ne $expectedReadBackCount) {
    throw "Expected $expectedReadBackCount MPE read-backs for $($item.Mode), found $($readBacks.Count)."
  }
  if ($inboundResources.Count -ne $expectedInboundCount) {
    throw "Expected $expectedInboundCount inbound resources for $($item.Mode), found $($inboundResources.Count)."
  }
}
```

Expected:

- `inbound_only` completes without `Invalid Resource ID` warnings and contains zero MPE approval read-backs.
- `outbound_only` contains exactly three MPE approval read-backs and no inbound resources.
- `inbound_and_outbound` contains exactly three MPE approval read-backs plus the inbound resources.
- Outbound read-backs are deferred until apply because they depend on the approval actions.

- [ ] **Step 5: Document strict outbound verification**

Add this paragraph after the `outbound_only` and `inbound_and_outbound` descriptions in `Fabric-private/README.md`:

```markdown
For either outbound mode, Terraform approves each managed private endpoint and then reads the target connection back. The apply stops if Terraform cannot confirm an `Approved` status. Resources created earlier in the apply remain in state; resolve the Azure approval or propagation issue, then rerun `terraform apply`.
```

- [ ] **Step 6: Review the final change**

Run:

```powershell
Set-Location (git rev-parse --show-toplevel)
git diff --check
git diff -- Fabric-private\mpe.tf Fabric-private\README.md
git status --short
```

Expected: only `Fabric-private/mpe.tf` and `Fabric-private/README.md` are changed, with no whitespace errors.

- [ ] **Step 7: Run the Superpowers privacy scan**

Run:

```powershell
Set-Location (git rev-parse --show-toplevel)
$scanCommand = (
  Get-Content .github\instructions\superpowers-plan-hygiene.instructions.md |
    Select-String "^\s*rg '\(\?i\)" |
    Select-Object -First 1
).Line.Trim()

Invoke-Expression $scanCommand
if ($LASTEXITCODE -eq 0) {
  throw 'Superpowers privacy scan found content that requires review.'
}
if ($LASTEXITCODE -ne 1) {
  exit $LASTEXITCODE
}
```

Expected: no machine-, user-, or session-specific content.

- [ ] **Step 8: Commit the implementation**

Run:

```powershell
Set-Location (git rev-parse --show-toplevel)
git add Fabric-private\mpe.tf Fabric-private\README.md
git commit -m "fix(fabric): enforce MPE approval readback"
```

Expected: one commit containing only the Terraform behavior change and its README documentation. The executing agent adds the required commit trailers using the current session metadata.
