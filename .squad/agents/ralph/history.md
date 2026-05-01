# Project Context

- **Owner:** Ryan Krokson
- **Project:** Azure IaC demo/lab environments — Terraform modules for Azure vWAN, AI Foundry, networking
- **Stack:** Terraform (azurerm >= 4.0, azapi >= 2.0, random ~> 3.5), PowerShell, Azure CLI
- **Created:** 2026-03-27

## Core Context

Agent Ralph initialized and ready for work.

## Recent Updates

📌 Team initialized on 2026-03-27
📌 Team cast from Dungeon Crawler Carl universe: Carl (Lead), Donut (Infra Dev), Mordecai (Docs), Katia (Validator)

## Learnings

Initial setup complete.


---

## Cross-Agent Notice: REST API from Design Skill (2026-07-18)

**All agents:** A new skill .squad/skills/rest-api-from-design/SKILL.md has been created to prevent recurring REST implementation errors. This affects anyone writing REST calls in Terraform, GitHub Actions, or shell scripts.

**Trigger:** Apply when implementing a REST call whose method + URL appears in a design doc or vendor docs. Key rule: use on_failure = fail on all state-mutating calls (POST/PUT/PATCH/DELETE); never substitute your own HTTP conventions.

**Named prior failure:** Fabric workspace-policy.tf bug (commit 4171dc3) — used PATCH instead of PUT, wrong URL path, on_failure=continue masked the error.

For details, see .squad/skills/rest-api-from-design/SKILL.md.
