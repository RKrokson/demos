# Azure Security Patterns — Terraform Reference

Reusable security checklist for Azure IaC in this repo. Derived from the 2025-07-25 security assessment.

## Identity & Access

- Use `enable_rbac_authorization = true` on Key Vault (prefer RBAC over access policies).
- Set `shared_access_key_enabled = false` on Storage Accounts to force Entra ID auth.
- Set `local_authentication_disabled = true` on Cosmos DB unless a service requires local auth.
- Set `disableLocalAuth = true` on AI Search.
- Use `authType = "AAD"` on all Foundry project connections.
- Use SystemAssigned managed identity on all AI/Foundry resources.
- Apply least-privilege RBAC roles (Cosmos DB Operator, Storage Blob Data Contributor, Search Index Data Contributor) rather than broad Owner/Contributor.
- Use ABAC conditions to scope Storage Blob Data Owner to specific containers when possible.

## Networking

- Deploy private endpoints for all PaaS services. Never rely on public endpoints for AI services.
- Attach NSGs to all subnets that host resources (shared, app, PE subnets). Use default-deny inbound.
- Set `default_outbound_access_enabled = false` when Azure Firewall handles egress.
- Set `internet_security_enabled` on vHub connections to match firewall deployment state.
- Use Private DNS Resolver with firewall DNS proxy chaining for private endpoint name resolution.
- Set `publicNetworkAccess = "Disabled"` on Cognitive Services, AI Search, Cosmos DB, and Storage.
- Storage network rules: `default_action = "Deny"`, `bypass = ["AzureServices"]`.

## Secrets & Encryption

- Never hardcode credentials in `.tf` files. Use `random_password` + Key Vault.
- Ensure `.gitignore` excludes `*.tfstate`, `*.tfvars`, `.env`.
- Mark sensitive outputs with `sensitive = true` (VM passwords, admin usernames).
- Storage: enforce `min_tls_version = "TLS1_2"` and `allow_nested_items_to_be_public = false`.

## Key Vault

- For labs: purge protection can be disabled for clean destroy cycles, but document the tradeoff.
- For production forks: enable `purge_protection_enabled = true`.
- Provider features `purge_soft_delete_on_destroy = true` is lab-only; disable in production.

## Known Accepted Risks (Lab Context)

These are intentional for this demo repo and documented:
- Firewall rules allow `*` source/destination/ports (backlog item #8 tracks tightening).
- `disableLocalAuth = false` on BYO VNet Foundry (PG-required for agent proxy).
- `networkAcls.defaultAction = "Allow"` with `publicNetworkAccess = "Disabled"` on BYO Foundry (PG-validated combo).
- `prevent_deletion_if_contains_resources = false` on resource groups (clean destroy cycles).
