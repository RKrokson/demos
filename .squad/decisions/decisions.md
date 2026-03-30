# Project Decisions

## Gitignore Audit (2025-01-17, finalized 2026-03-27)

**Owner:** Carl (Lead/Architect)  
**Status:** APPROVED & IMPLEMENTED

### Summary

The `.gitignore` file is well-aligned with Terraform best practices for a demo/lab environment using local state. Three root modules (Networking, Foundry-byoVnet, Foundry-managedVnet) are properly protected from accidental commits of state, locks, and sensitive variables.

### Findings

**Correct Patterns:**
- `*.tfstate` / `*.tfstate.*` — state files properly excluded
- `*.tfvars` — secrets excluded while `.example` and `.advanced.example` are tracked (best practice)
- `.terraform/` directories excluded
- `.terraform.tfstate.lock.info` excluded (transient)
- `override.tf*` patterns excluded
- `.terraformrc` / `terraform.rc` excluded
- Squad runtime excluded (`.squad/log/`, `.squad/decisions/inbox/`, `.squad/sessions/`)

**Design Choice:** `.terraform.lock.hcl` IS Tracked  
This is intentional and correct. Terraform recommends committing lock files for reproducible builds in shared repos.

### Approved Updates

Donut appended preventive patterns to `.gitignore`:

```
# IDE and editor configuration
.vscode/
.idea/
*.swp
*.swo

# Environment files
.env
.env.local
.env.*.local

# OS artifacts
Thumbs.db
.DS_Store
```

**Rationale:** Prevents accidental commits of local IDE config, environment variables, and OS artifacts while maintaining Terraform and Squad patterns.

### Next Steps

1. ✅ Update .gitignore with recommended patterns
2. ✅ Verify patterns with team validation
3. ✅ Commit and document decision

---

## Copilot Directive: Humanizer Skill (2026-03-30T02:34:00Z)

**Owner:** Ryan Krokson (via Copilot)  
**Status:** ACTIVE GUIDELINE

All README and documentation updates must be run through the humanizer skill before finalizing, to remove signs of AI-generated writing. This ensures consistent, natural technical voice across all documentation.

---

## VPN Removal and Output Contract (2026-03-29, finalized 2026-03-30)

**Owner:** Donut (Infra Dev)  
**Status:** APPROVED & IMPLEMENTED

### Summary

VPN infrastructure fully removed from Networking module. Networking output contract established with 10+ DNS zone IDs, vHub IDs, LAW ID, Key Vault ID/name, and region 1 subnet IDs exported for downstream module consumption.

### What Changed

1. **VPN fully removed.** All 8 VPN gateway resource blocks, 16 VPN variables, and tfvars references eliminated across both regions. The VPN naming bug (s2s_conn01 vs s2s_conn00) is now moot.

2. **Networking output contract established.** 10 private DNS zone IDs, vHub IDs, LAW ID, Key Vault ID/name, and region 1 subnet IDs are now exported. Foundry modules consume these directly instead of constructing ARM paths via string interpolation.

3. **Count guard bugs fixed.** `fw01_logs` and `ai_vnet01_dns` now properly require `create_vhub01`.

4. **Default tags added.** All 3 provider configurations now include `default_tags` block for consistent resource tagging.

5. **Provider constraints added.** Networking/config.tf: `required_version >= 1.8.3`. Foundry-byoVnet/config.tf: `random` provider declaration added.

### Impact

- Any future module that needs DNS zone IDs or subnet IDs should consume Networking outputs, not construct ARM paths.
- The `add_s2s_VPN00` and `add_s2s_VPN01` toggles no longer exist. Remove from any external documentation or automation.
- Default tags reduce boilerplate and improve consistency across all resources.
- Networking is now the single source of truth for DNS zone IDs and hub identifiers.

### Cross-Team Updates

- **Mordecai:** Removed all VPN references from documentation (READMEs, copilot-instructions.md).
