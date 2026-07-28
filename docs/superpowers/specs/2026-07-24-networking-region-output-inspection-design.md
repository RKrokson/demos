# Networking region output inspection design

## Goal

Add a short PowerShell example to `Networking/README.md` so operators can inspect both entries from the `alz_regions` output without editing variables or reading the raw Terraform state.

## Placement

Add an `Inspect a deployed region` subsection directly after the explanation of `alz_regions.region0` and `alz_regions.region1` in the platform-to-ALZ contract section.

The text must state that the command runs from `Networking/`, where Terraform can read the configured state backend.

## README command contract

The README keeps the working-directory requirement in its surrounding text rather than changing directories inside the command. The operator starts in `Networking/`, and the copied command begins by reading `alz_regions`.

The command reads the Terraform output once, loops over `region0` and `region1`, and prints a heading for each region. Each iteration displays the full regional contract, then expands the nested Private DNS zone map instead of leaving it as a compact PowerShell object.

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
