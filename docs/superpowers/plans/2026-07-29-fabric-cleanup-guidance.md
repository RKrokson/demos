# Fabric cleanup guidance implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the generic `Fabric-private` destroy instructions with a mode-aware cleanup procedure for inbound restrictions, transient outbound deletion errors, and the combined mode.

**Architecture:** Keep the change documentation-only. The README will use one shared reviewed-plan workflow, with proactive preparation for inbound modes and bounded manual retries for transient outbound `UnknownError` responses during outbound cleanup.

**Tech Stack:** Markdown, PowerShell, Terraform CLI

## Global Constraints

- For `inbound_only` and `inbound_and_outbound`, restore workspace public access to `Allow` from a host connected to the workspace private network before running Terraform.
- For `inbound_only` and `inbound_and_outbound`, the connected host must still reach `app.fabric.microsoft.com` and `api.fabric.microsoft.com` over their public endpoints while it is on the workspace private network; the workspace-specific private FQDN cannot be used to change the communication policy.
- Allow up to 30 minutes for the inbound communication-policy change to propagate.
- `outbound_only` does not require the inbound policy preparation.
- Every destroy attempt and retry must create and review a new `terraform plan -destroy` artifact.
- Do not add fixed sleeps or automatic retry loops to Terraform.
- Do not recommend `terraform state rm` or manual Fabric resource deletion as the first response.
- Preserve the complete `with <resource-address>` line and Fabric request ID when escalating persistent `UnknownError` failures.
- `inbound_and_outbound` must apply the inbound preparation first and the outbound retry guidance second.

---

### Task 1: Document mode-aware Fabric cleanup

**Files:**
- Modify: `Fabric-private/README.md:231-249`

**Interfaces:**
- Consumes: `network_mode` values `inbound_only`, `outbound_only`, and `inbound_and_outbound`.
- Produces: A single destroy procedure that covers preparation, reviewed destroy plans, partial cleanup, and escalation.

- [ ] **Step 1: Confirm the current destroy section lacks mode-aware guidance**

Run:

```powershell
$repoRoot = git rev-parse --show-toplevel
Set-Location $repoRoot

$readme = Get-Content Fabric-private\README.md -Raw
if ($readme -match 'RequestDeniedByInboundPolicy' -or
    $readme -match 'UnknownError' -or
    $readme -match 'terraform plan -destroy') {
  throw 'Expected the current destroy section to lack the new mode-aware cleanup guidance.'
}
```

Expected: the command exits successfully because the current procedure only runs `terraform destroy`.

- [ ] **Step 2: Replace the destroy procedure**

Replace `Fabric-private/README.md` from `## Destroy Procedure` through the end of the file with:

````markdown
## Destroy Procedure

### Step 1: Prepare for destroy

Keep the Fabric capacity in the `Active` state. If it is paused, resume it first:

```powershell
az fabric capacity resume --resource-group <rg> --capacity-name <name>
```

For `inbound_only` and `inbound_and_outbound`, restore workspace public access before running Terraform:

1. Connect from the workspace private network through Bastion, VPN, ExpressRoute, or another connected host.
2. Make sure that connected host can still reach `app.fabric.microsoft.com` and `api.fabric.microsoft.com` over their public endpoints while it is on the workspace private network. The workspace-specific private FQDN helps with workspace access, but it cannot be used to change the communication policy.
3. In the Fabric workspace, open **Workspace settings** > **Inbound networking** > **Workspace connection settings** > **Allow connections from all networks** > **Apply**.
4. Wait for the policy change to propagate. Microsoft notes that workspace communication-policy changes can take up to 30 minutes.

This step prevents the Fabric provider refresh from failing with `RequestDeniedByInboundPolicy` before Terraform can delete the workspace. If cleanup is abandoned, manually restore `Deny` because Terraform does not detect portal changes to the communication policy.

`outbound_only` does not deploy the inbound restriction and does not need this preparation.

### Step 2: Create and apply a destroy plan

```powershell
$repoRoot = git rev-parse --show-toplevel
Set-Location (Join-Path $repoRoot 'Fabric-private')

terraform plan -destroy -out fabric-destroy.tfplan
terraform show fabric-destroy.tfplan
terraform apply fabric-destroy.tfplan
```

Review every resource in the saved plan before applying it.

### Step 3: Retry partial cleanup

Terraform records resources removed by a partial destroy. Do not remove the remaining resources from state, and do not manually delete Fabric resources as the first response.

- `RequestDeniedByInboundPolicy`: confirm the portal control is still set to **Allow connections from all networks**, wait for propagation, then create and apply a new destroy plan.
- `UnknownError` during `outbound_only`: Fabric can return a generic delete error during outbound cleanup. Keep the request ID, wait a few minutes, then create and apply a new destroy plan.
- `inbound_and_outbound`: complete the inbound policy preparation first. If Fabric later returns `UnknownError`, follow the outbound retry procedure.

Each failed attempt can delete some resources, so never reuse the previous destroy plan. If `UnknownError` continues after bounded retries or an extended wait, capture the complete `with <resource-address>` line and Fabric request ID for Microsoft support or a [Fabric provider issue](https://github.com/microsoft/terraform-provider-fabric/issues).

### Step 4: Account for soft-delete retention

- Fabric workspaces enter soft-delete for about 90 days. The random suffix prevents name collisions on redeploy.
- SQL server names are reserved for about seven days after deletion. The random suffix mitigates collisions.
- The workspace-local Key Vault has soft-delete enabled with seven-day retention and purge protection disabled. If the same name remains soft-deleted, purge it with `az keyvault purge --name <kv-name>`.

### Important

Do not toggle the **Configure workspace-level inbound network rules** tenant setting during a deployment lifecycle. If it is toggled, re-register `Microsoft.Fabric` afterward.
````

- [ ] **Step 3: Verify all mode-specific guidance**

Run:

```powershell
$repoRoot = git rev-parse --show-toplevel
Set-Location $repoRoot

$readme = Get-Content Fabric-private\README.md -Raw
$required = @(
  'inbound_only',
  'outbound_only',
  'inbound_and_outbound',
  'RequestDeniedByInboundPolicy',
  'UnknownError',
  'terraform plan -destroy -out fabric-destroy.tfplan',
  'never reuse the previous destroy plan',
  'Do not remove the remaining resources from state',
  'app.fabric.microsoft.com',
  'api.fabric.microsoft.com',
  'Workspace settings** > **Inbound networking** > **Workspace connection settings** > **Allow connections from all networks** > **Apply**'
)

foreach ($text in $required) {
  if (-not $readme.Contains($text)) {
    throw "Missing required cleanup guidance: $text"
  }
}

$inboundIndex = $readme.IndexOf('restore workspace public access before running Terraform')
$combinedRetryIndex = $readme.IndexOf('complete the inbound policy preparation first')
if ($inboundIndex -lt 0 -or $combinedRetryIndex -le $inboundIndex) {
  throw 'Combined-mode cleanup does not place inbound preparation before outbound recovery.'
}

```

Expected: the command exits successfully.

- [ ] **Step 4: Review documentation quality**

Run:

```powershell
$repoRoot = git rev-parse --show-toplevel
Set-Location $repoRoot

git diff --check
git diff -- Fabric-private\README.md
git status --short
```

Expected: only `Fabric-private/README.md` is changed, and there are no whitespace errors.

- [ ] **Step 5: Commit the README update**

Run:

```powershell
$repoRoot = git rev-parse --show-toplevel
Set-Location $repoRoot

git add Fabric-private\README.md
git commit -m "docs(fabric): document mode-aware cleanup"
```

Expected: one commit containing only the Fabric cleanup documentation. The executing agent adds the required commit trailers using the current session metadata.
