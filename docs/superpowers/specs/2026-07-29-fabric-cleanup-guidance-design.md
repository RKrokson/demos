# Fabric cleanup guidance design

## Goal

Document a reliable cleanup sequence for all three `Fabric-private` network modes. The guidance must explain the two observed failure modes without presenting either one as a Terraform state problem.

## Observed behavior

- `inbound_only` apply and destroy can complete normally when Terraform can reach the restricted workspace.
- A destroy started outside the workspace private network can fail during provider refresh with `RequestDeniedByInboundPolicy`. Terraform reaches this refresh before the best-effort destroy provisioner can restore public access.
- `outbound_only` apply completes, but Fabric can return a generic `UnknownError` during outbound cleanup. Repeated destroy attempts can make partial progress and eventually complete.
- `inbound_and_outbound` contains both paths, so its cleanup guidance must include both the inbound preparation and the outbound retry procedure.

## Chosen documentation structure

Replace the current generic destroy procedure in `Fabric-private/README.md` with one mode-aware workflow.

### 1. Prepare the deployment

Keep the Fabric capacity active.

For `inbound_only` and `inbound_and_outbound`, proactively restore workspace public access before running Terraform:

1. Connect from the workspace private network through Bastion, VPN, ExpressRoute, or another connected host.
2. Make sure that connected host can still reach `app.fabric.microsoft.com` and `api.fabric.microsoft.com` over their public endpoints while it is on the workspace private network. The workspace-specific private FQDN helps with workspace access, but it cannot be used to change the communication policy.
3. In the Fabric workspace, open **Workspace settings** > **Inbound networking** > **Workspace connection settings** > **Allow connections from all networks** > **Apply**.
4. Wait for the policy change to propagate. Microsoft notes that workspace communication-policy changes can take up to 30 minutes.

This temporary access change prevents the Fabric provider refresh from failing before Terraform can delete the workspace. If cleanup is abandoned, manually restore `Deny` because Terraform does not detect portal changes to the communication policy.

`outbound_only` does not need this preparation because it does not deploy the inbound restriction.

### 2. Create and apply a reviewed destroy plan

Use a saved destroy plan instead of the interactive `terraform destroy` shortcut:

```powershell
$repoRoot = git rev-parse --show-toplevel
Set-Location (Join-Path $repoRoot 'Fabric-private')

terraform plan -destroy -out fabric-destroy.tfplan
terraform show fabric-destroy.tfplan
terraform apply fabric-destroy.tfplan
```

The operator must inspect the plan before applying it.

### 3. Recover from partial cleanup

If a destroy fails, do not remove resources from Terraform state and do not manually delete Fabric resources as the first response.

- `RequestDeniedByInboundPolicy`: confirm the portal control is still set to **Allow connections from all networks**, wait for propagation, then create and apply a new destroy plan.
- `UnknownError` during an outbound cleanup: keep the request ID, wait a few minutes, then create and apply a new destroy plan. Each failed attempt can remove some resources, so the previous saved plan is stale.
- `inbound_and_outbound`: complete the inbound policy preparation first, then use the outbound retry procedure if Fabric returns `UnknownError`.

If `UnknownError` continues after bounded retries or an extended wait, capture the complete `with <resource-address>` line and Fabric request ID for Microsoft support or a Fabric provider issue.

## Non-goals

- Adding fixed sleeps or automatic retry loops to Terraform.
- Changing provider versions or Fabric resource dependencies.
- Using `terraform state rm` to hide undeleted resources.
- Automating the communication-policy change in this documentation update.
- Claiming that every generic `UnknownError` comes from a specific Fabric resource without the full Terraform error context.

## Validation

- Confirm the README has distinct guidance for `inbound_only`, `outbound_only`, and `inbound_and_outbound`.
- Confirm the combined mode includes both cleanup paths in the correct order.
- Confirm every retry regenerates and reviews a destroy plan.
- Confirm the guidance preserves state plus the complete `with <resource-address>` line and Fabric request ID for escalation.
- Run `git diff --check` and the Superpowers privacy scan.
