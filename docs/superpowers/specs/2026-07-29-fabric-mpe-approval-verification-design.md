# Fabric MPE approval verification design

## Goal

Remove the false `Invalid Resource ID` warnings from `inbound_only` plans while preserving exact managed private endpoint matching and making outbound approval verification authoritative.

## Current problem

The three MPE approval checks contain nested `azapi_resource` data sources. These data sources always run because nested data sources inside Terraform `check` blocks cannot use `count` or `for_each`.

In `inbound_only`, no outbound targets or MPEs exist. The current code gives each nested data source the placeholder ID `placeholder-not-deployed`. AzAPI rejects that value, and Terraform converts the provider errors into warnings because they occurred inside `check` blocks. The plan and apply continue, but the warnings look like deployment failures.

The same check blocks are also non-blocking in outbound modes. If the approval read-back fails or returns a status other than `Approved`, Terraform warns and exits successfully. That can leave an outbound deployment looking successful even though Fabric cannot use one of its private data paths.

## Chosen design

Replace the three warning-only check-scoped reads with counted top-level data sources:

- `data.azapi_resource.mpe_storage_conn`
- `data.azapi_resource.mpe_sql_conn`
- `data.azapi_resource.mpe_kv_conn`

Each data source uses `count = local.deploy_outbound ? 1 : 0`.

When `network_mode = "inbound_only"`, Terraform creates no instances of these data sources. It sends no approval read-back requests and does not construct placeholder resource IDs.

When outbound networking is enabled, each data source:

1. Builds its `resource_id` from the real target resource ID and the connection name selected by the existing exact suffix match.
2. Depends on the corresponding `azapi_resource_action` approval PUT.
3. Exports `properties.privateLinkServiceConnectionState.status`.
4. Uses a `lifecycle.postcondition` requiring the returned status to equal `Approved`.

The exact connection-matching logic remains unchanged. Terraform must continue matching the target connection whose private endpoint ID ends with `{workspace_id}.{mpe_name}`. It must never approve the first pending connection by position, name pattern, or state alone.

## Failure behavior

### Inbound-only

An inbound-only plan or apply performs no outbound approval reads. The three invalid-resource-ID warnings disappear. All other inbound behavior remains unchanged.

### Outbound modes

An outbound apply creates the MPE, finds the exact target connection, sends the approval PUT, and reads the connection back.

The apply exits nonzero if:

- AzAPI cannot read the real private endpoint connection.
- The read-back status is not `Approved`.
- The existing exact-match lookup returns multiple connections.

Terraform does not roll back resources created before a failure. Those resources remain in state. After resolving the Azure or approval issue, the operator reruns `terraform apply`.

No fixed delay or retry is part of this change. The current flow orders the approval PUT after MPE creation and one target connection-list read; it does not poll for the connection to appear. Add a delay only if a real outbound apply demonstrates a repeatable stale-read problem.

## Documentation

Update `Fabric-private/README.md` to explain that outbound applies verify each MPE approval with a read-back and stop if Terraform cannot confirm `Approved`.

The README must also state that a failed verification does not roll back resources already created and that rerunning `terraform apply` retries the remaining work after the underlying issue is resolved.

## Validation

Run the module's existing formatting and validation checks.

Run plans for all three `network_mode` values:

- `inbound_only`: no invalid-resource-ID warnings, no MPE approval data reads, and no outbound resources.
- `outbound_only`: no inbound resources; all three MPE approval read-backs are deferred until apply.
- `inbound_and_outbound`: both inbound resources and all three outbound approval read-backs are present.

Review the saved plan JSON to verify the mode-specific resource split. A real outbound apply is required to prove Azure returns `Approved` to the blocking postconditions.

## Non-goals

- Changing the `network_mode` default.
- Changing MPE resource identities or target connection matching.
- Adding arbitrary sleeps or retry loops.
- Changing Fabric provider preview behavior or its preview warnings.
