# Networking region output inspection implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a zero-edit PowerShell example that displays both deployed `alz_regions` entries and their Private DNS zone IDs.

**Architecture:** Revise the existing platform-to-ALZ contract example in `Networking/README.md`. The example reads the configured Terraform state once, loops over `region0` and `region1`, and formats each top-level contract and nested DNS zone map separately.

**Tech Stack:** Markdown, PowerShell, Terraform CLI

## Global Constraints

- Modify only `Networking/README.md`.
- Place the new subsection immediately after the paragraph that explains `alz_regions.region0` and `alz_regions.region1`.
- State that the command runs from `Networking/`.
- Keep the example read-only; it must not change Terraform configuration or state.
- Use one fixed loop over `region0` and `region1`; the operator must not edit a region selector.
- Display a heading and the full region contract with `Format-List *` for each region.
- Display each region's `private_dns_zone_ids` separately with `Format-List *`.
- Do not display the separate VM credential outputs.
- Keep Superpowers documents portable and free of machine-specific paths, usernames, home directories, email addresses, or session identifiers.

---

## File map

- Modify `Networking/README.md`: document how to inspect one regional platform contract from Terraform state.

---

### Task 1: Show both regional outputs without editing

**Files:**
- Modify: `Networking/README.md:58-60`

**Interfaces:**
- Consumes: Terraform output `alz_regions` with `region0`, `region1`, and nested `private_dns_zone_ids`.
- Produces: A read-only PowerShell example that reports both regions in one execution.

- [ ] **Step 1: Confirm the example requires manual region selection**

Run from the repository root:

```powershell
Select-String -Path Networking\README.md -SimpleMatch "`$regionName = 'region0' # or 'region1'"
```

Expected: one match in the existing inspection example.

- [ ] **Step 2: Replace the inspection subsection**

Replace the existing `Inspect a deployed region` subsection with:

````markdown
### Inspect a deployed region

Run this example from `Networking/` after applying the current Networking configuration so the configured state contains the `alz_regions` output. It displays both regions without requiring any edits:

```powershell
$alz = terraform output -json alz_regions | ConvertFrom-Json

foreach ($regionName in 'region0', 'region1') {
  $region = $alz.$regionName
  $regionLabel = $regionName -replace 'region', 'Region '

  Write-Host "`n=== $regionLabel ==="
  $region | Format-List *

  Write-Host "--- Private DNS zone IDs ---"
  $region.private_dns_zone_ids | Format-List *
}
```

For each region, the first list shows its resource group, vHub, Firewall, and DNS fields. The second list expands its Private DNS zone names and values. A disabled region 1 remains visible with `enabled = false` and null resource-derived values.
````

- [ ] **Step 3: Review the documentation change**

Run:

```powershell
git diff --check
git diff -- Networking\README.md
```

Expected: no whitespace errors; the diff changes only the existing inspection subsection.

- [ ] **Step 4: Verify the documented commands when state is available**

Run:

```powershell
Set-Location (Join-Path (git rev-parse --show-toplevel) 'Networking')
$alz = terraform output -json alz_regions | ConvertFrom-Json

foreach ($regionName in 'region0', 'region1') {
  $region = $alz.$regionName
  $regionLabel = $regionName -replace 'region', 'Region '

  Write-Host "`n=== $regionLabel ==="
  $region | Format-List *

  Write-Host "--- Private DNS zone IDs ---"
  $region.private_dns_zone_ids | Format-List *
}
```

Expected: one execution displays Region 0 followed by Region 1. If region 1 is disabled, it displays `enabled = false` with null resource-derived values.

- [ ] **Step 5: Run the documentation privacy scan**

Run:

```powershell
Set-Location (git rev-parse --show-toplevel)
$scanCommand = (
  Get-Content .github\instructions\superpowers-plan-hygiene.instructions.md |
    Select-String "^\s*rg '\(\?i\)" |
    Select-Object -First 1
).Line.Trim()
Invoke-Expression $scanCommand
```

Expected: no matches.

- [ ] **Step 6: Commit the README change**

Stage only the README:

```powershell
git add Networking\README.md
git commit -m "docs(networking): show both regional outputs"
```

The executing agent adds the required commit trailers using its current session metadata.
