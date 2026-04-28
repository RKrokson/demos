---
name: "rest-api-from-design"
description: "When implementing a REST call cited in a design doc or vendor docs, copy the method and URL verbatim. No substitution. No inference."
domain: "api-implementation, error-handling, terraform"
confidence: "medium"
source: "observed — second recurrence confirmed (Fabric-private/workspace-policy.tf)"
---

## Context

Any time you are implementing an HTTP call that was specified in a design doc, vendor docs, or a
`.squad/decisions.md` entry, the cited method and URL are a **contract**, not a suggestion.

Applies to: Terraform `local-exec` PowerShell/bash blocks, GitHub Actions scripts, Azure CLI
fallback shells, and anywhere you hand-roll an HTTP call against an external API.

---

## The Rule

**Copy the cited method and URL verbatim. No substitution.**

REST conventions ("update existing resource → PATCH", "collection at /resource → /resource/{id}")
do not override a cited spec. The person who wrote the design doc already resolved the method and
path. Your job is to reproduce it exactly.

Two failure modes to avoid:

| Temptation | Why it's wrong |
|---|---|
| "The operation modifies existing state, so PATCH is more idiomatic than PUT." | The API author decides. If the spec says PUT, use PUT. |
| "The resource is `communicationPolicy`, so the path must be `/communicationPolicy`." | Path segments are not inferrable. A missing `/networking/` prefix is a different endpoint or 404. |

---

## Verification Step

Before writing the code, copy the cited URL and method as a comment above the call.
This makes the contract visible to reviewers and your future self.

**Terraform local-exec (PowerShell):**
```powershell
# Per Microsoft docs: PUT https://api.fabric.microsoft.com/v1/workspaces/{id}/networking/communicationPolicy
# Source: https://learn.microsoft.com/en-us/fabric/security/security-workspace-level-private-links-set-up
Invoke-RestMethod -Method PUT -Uri "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId/networking/communicationPolicy" ...
```

**GitHub Actions / bash:**
```bash
# Per design doc (decisions.md §11 Q2): PATCH {resource_id}/privateEndpointConnections/{conn_name}
curl -X PATCH "$resource_id/privateEndpointConnections/$conn_name" ...
```

If you cannot find the source URL to cite, **stop and ask**. Do not infer.

---

## Loud Failure Default

`on_failure = continue` (or any equivalent silent-fail flag) **MUST NOT** be used on
state-mutating REST calls (POST / PUT / PATCH / DELETE).

Use `on_failure = fail` (Terraform), `set -e` (bash), or `$ErrorActionPreference = 'Stop'`
(PowerShell) for any call that changes state.

> Silent failure is worse than a loud failure. If the call silently no-ops, Terraform reports
> success and the resource is in the wrong state — the operator only discovers this in the portal.

Only read-only diagnostic calls (GET-only, idempotent reads) may suppress failures, and even then
prefer logging to discarding the error.

---

## Post-Apply Validation

Where feasible, add a read-back after the state-mutating call to confirm the desired state landed.

```powershell
# After PUT: read back and assert
$result = Invoke-RestMethod -Method GET -Uri $uri -Headers $headers
if ($result.inbound.publicAccessRules.defaultAction -ne 'Deny') {
  throw "communicationPolicy write succeeded (HTTP 200) but state did not apply. Expected Deny, got $($result.inbound.publicAccessRules.defaultAction)."
}
```

This catches cases where the API returns 200 but the change did not persist (Fabric has been
observed doing this on first-apply when the workspace PE is not yet live).

---

## Anti-Patterns

- ❌ Substituting PATCH for PUT (or vice versa) based on REST instinct
- ❌ Shortening a URL path because it "looks redundant" (e.g., dropping `/networking/`)
- ❌ `on_failure = continue` on a PUT/PATCH/POST/DELETE
- ❌ No read-back when the consequence of silent failure is "workspace stays public"
- ❌ Implementing the URL from memory without checking the design doc or source link

---

## Prior Failure — Concrete Reference

**Bug:** `Fabric-private/workspace-policy.tf` (commit `4171dc3`, first deploy 2026-04-28).

Design doc cited:
```
PUT https://api.fabric.microsoft.com/v1/workspaces/{workspaceID}/networking/communicationPolicy
```
Source: `.squad/decisions/decisions.md` §5 item 5, citing Microsoft Learn
"Set up and use workspace-level private links" Step 8.

Code written:
```powershell
Invoke-RestMethod -Uri ".../v1/workspaces/$id/communicationPolicy" -Method PATCH ...
```
with `on_failure = continue`.

**Two errors, both masked:**
1. Method `PATCH` → should be `PUT`.
2. Path `/communicationPolicy` → should be `/networking/communicationPolicy`.

Terraform reported success. Portal showed "Allow all connections" (public access still open).
Ryan caught it during portal review — not from any apply-time signal.

Fixed in commit `0471d6a`. The fix changed method to `PUT`, restored the `/networking/` segment,
and set `on_failure = fail` on the create-time provisioner.
