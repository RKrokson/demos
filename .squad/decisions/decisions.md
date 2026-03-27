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
