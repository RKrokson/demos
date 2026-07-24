---
applyTo: "docs/superpowers/**/*.md"
---

# Superpowers document hygiene

- Use repository-relative file paths in prose.
- PowerShell examples must derive the repository root with `git rev-parse --show-toplevel`.
- Do not include absolute local paths, usernames, home directories, personal email addresses, session IDs, task IDs, subscription IDs, tenant IDs, state contents, credentials, or other environment-specific identifiers.
- Do not hardcode `Copilot-Session` values in plans. The executing agent adds required commit trailers using its current session metadata.
- Before committing a Superpowers document, run the privacy scan below and review every match:

```powershell
rg '(?i)([A-Z]:\\|/Users/|/home/|C:/Users|Copilot-Session|session-state|[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,})' docs/superpowers
```

The expected result is no machine-, user-, or session-specific content.
