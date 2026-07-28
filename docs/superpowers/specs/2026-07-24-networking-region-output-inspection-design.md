# Networking region output inspection design

## Goal

Add a short PowerShell example to `Networking/README.md` so operators can inspect both entries from the `alz_regions` output without editing variables or reading the raw Terraform state.

## Placement

Add an `Inspect a deployed region` subsection directly after the explanation of `alz_regions.region0` and `alz_regions.region1` in the platform-to-ALZ contract section.

The text must state that the command runs from `Networking/`, where Terraform can read the configured state backend.

## Example

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

The fixed loop makes the example a single copy-and-paste command for the complete regional status. Each iteration displays the region's resource group, vHub, Firewall, and DNS fields, then expands the nested Private DNS zone map instead of leaving it as a compact PowerShell object.

## Behavior and limits

- The example reads outputs only. It does not change Terraform configuration or state.
- The example always displays `region0` followed by `region1`; the operator does not select or edit a region variable.
- A disabled region 1 remains useful to inspect because the output shows `enabled = false` and null resource-derived values.
- The example does not display the separate VM credential outputs.
- Terraform should surface missing state or missing output errors directly; the README does not need a wrapper function or custom error handling.

## Validation

- Confirm the snippet runs from `Networking/` after a deployment.
- Confirm one execution displays region 0 followed by region 1 without editing the snippet.
- Confirm the top-level fields are readable and `private_dns_zone_ids` expands into individual zone names and values.
- Run the Superpowers document privacy scan before committing.
