# Networking region output inspection design

## Goal

Add a short PowerShell example to `Networking/README.md` so operators can inspect one deployed entry from the `alz_regions` output without reading the raw Terraform state.

## Placement

Add an `Inspect a deployed region` subsection directly after the explanation of `alz_regions.region0` and `alz_regions.region1` in the platform-to-ALZ contract section.

The text must state that the command runs from `Networking/`, where Terraform can read the configured state backend.

## Example

```powershell
$regionName = 'region0' # or 'region1'
$alz = terraform output -json alz_regions | ConvertFrom-Json
$region = $alz.$regionName

$region | Format-List *
$region.private_dns_zone_ids | Format-List *
```

The selected-region variable keeps the example reusable. The first command displays the region's resource group, vHub, Firewall, and DNS fields. The second expands the nested Private DNS zone map instead of leaving it as a compact PowerShell object.

## Behavior and limits

- The example reads outputs only. It does not change Terraform configuration or state.
- Valid region names are `region0` and `region1`.
- A disabled region 1 remains useful to inspect because the output shows `enabled = false` and null resource-derived values.
- The example does not display the separate VM credential outputs.
- Terraform should surface missing state or missing output errors directly; the README does not need a wrapper function or custom error handling.

## Validation

- Confirm the snippet runs from `Networking/` after a deployment.
- Test both `region0` and `region1`.
- Confirm the top-level fields are readable and `private_dns_zone_ids` expands into individual zone names and values.
- Run the Superpowers document privacy scan before committing.
