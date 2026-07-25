# Networking region output inspection implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a copy-and-paste PowerShell example that displays one deployed `alz_regions` entry and its Private DNS zone IDs.

**Architecture:** Extend the existing platform-to-ALZ contract section in `Networking/README.md`. The example reads the configured Terraform state through `terraform output`, selects `region0` or `region1`, and formats the top-level contract and nested DNS zone map separately.

**Tech Stack:** Markdown, PowerShell, Terraform CLI

## Global Constraints

- Modify only `Networking/README.md`.
- Place the new subsection immediately after the paragraph that explains `alz_regions.region0` and `alz_regions.region1`.
- State that the command runs from `Networking/`.
- Keep the example read-only; it must not change Terraform configuration or state.
- Use a reusable `$regionName` variable that accepts `region0` or `region1`.
- Display the selected region with `Format-List *`.
- Display `private_dns_zone_ids` separately with `Format-List *`.
- Do not display the separate VM credential outputs.
- Keep Superpowers documents portable and free of machine-specific paths, usernames, home directories, email addresses, or session identifiers.

---

## File map

- Modify `Networking/README.md`: document how to inspect one regional platform contract from Terraform state.

---

### Task 1: Add regional output inspection guidance

**Files:**
- Modify: `Networking/README.md:58-60`

**Interfaces:**
- Consumes: Terraform output `alz_regions` with `region0`, `region1`, and nested `private_dns_zone_ids`.
- Produces: A read-only PowerShell example for operators.

- [ ] **Step 1: Confirm the inspection subsection is absent**

Run from the repository root:

```powershell
rg '^### Inspect a deployed region$' Networking\README.md
```

Expected: no matches.

- [ ] **Step 2: Add the README subsection**

Insert the following immediately after the paragraph ending with "must not assume that Networking region 1 automatically enables a second workload region.":

````markdown
### Inspect a deployed region

Run this example from `Networking/` after Terraform has created or refreshed the configured state. Set `$regionName` to the region you want to inspect:

```powershell
$regionName = 'region0' # or 'region1'
$alz = terraform output -json alz_regions | ConvertFrom-Json
$region = $alz.$regionName

$region | Format-List *
$region.private_dns_zone_ids | Format-List *
```

The first list shows the selected region's resource group, vHub, Firewall, and DNS fields. The second list expands the Private DNS zone names and values. A disabled region 1 remains visible with `enabled = false` and null resource-derived values.
````

- [ ] **Step 3: Review the documentation change**

Run:

```powershell
git diff --check
git diff -- Networking\README.md
```

Expected: no whitespace errors; the diff contains only the new subsection in the platform-to-ALZ output section.

- [ ] **Step 4: Verify the documented commands when state is available**

From `Networking/`, run:

```powershell
$regionName = 'region0'
$alz = terraform output -json alz_regions | ConvertFrom-Json
$region = $alz.$regionName

$region | Format-List *
$region.private_dns_zone_ids | Format-List *
```

Repeat with:

```powershell
$regionName = 'region1'
```

Expected: each selection displays the regional contract. If region 1 is disabled, it displays `enabled = false` with null resource-derived values.

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
git commit -m "docs(networking): add regional output inspection"
```

The executing agent adds the required commit trailers using its current session metadata.
