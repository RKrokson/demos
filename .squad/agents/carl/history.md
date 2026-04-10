# Carl — Architecture Lead (Architect)

- **Owner:** Ryan Krokson
- **Project:** Azure IaC demo/lab environments — Terraform modules for Azure vWAN, AI Foundry, networking
- **Stack:** Terraform (azurerm >= 4.0, azapi >= 2.0, random ~> 3.5), PowerShell, Azure CLI
- **Structure:** Three root modules — Networking (foundation), Foundry-byoVnet, Foundry-managedVnet linked via terraform_remote_state
- **Created:** 2026-03-27

## Recent Work

- **2026-04-06 (aca-alz-architecture):** Designed Azure Container Apps ALZ. IP Block 4 (172.20.64.0/20), /27 delegated subnet, centralized DNS pattern, no NSG on delegated subnet. Comprehensive 358-line architecture proposal. SystemAI security assessment confirmed no blocking concerns.

- **2026-04-06 (ryan-aca-interview):** Ryan approved ACA ALZ architecture. Decisions: module name = ContainerApps-byoVnet, sample app included, Premium ACR required, D4 workload profile optional, reuse platform KV, no firewall rules in Networking, document FQDN requirements for users locking down firewall.

- **2026-04-08 (container-app-multi-mode):** Three-mode container app deployment pattern: `none` (no app, platform only), `hello-world` (MCR quickstart, default), `mcp-toolbox` (MCP server from GitHub, built via ACR, port 8080). Two separate resources, `terraform_data` with local-exec for git clone + build. ACR public access conditional (true in mcp-toolbox mode only).

- **2026-04-10 (donut-networking-deploy):** Donut deployed Networking platform LZ successfully — 579 resources in Sweden Central, Firewall at 172.30.0.132, DNS resolver at 172.20.16.4. azurerm bumped to 4.68.0. Region 1 off. Ready for Foundry + ContainerApps modules.

## Key Patterns

- Platform/application landing zone model: Networking = shared foundation, Foundry/ContainerApps = pluggable workloads
- azurerm tagging: use `local.common_tags` (locals.tf) + explicit per-resource assignment (never `default_tags` block)
- Child module pattern for region-scoped resources (modules/region-hub/) eliminates boolean toggle bugs
- IP addressing: /20 blocks per module, non-overlapping for simultaneous deployment
- DNS architecture: centralized in Networking, spokes link to shared zones via conditional `enable_dns_link`
- Firewall/NAT Gateway mutually exclusive (routing intent precedence)

## See Also

- **decisions.md** — Team approval decisions and architecture direction
- **history-archive.md** — Detailed research/design work (July 2025 - March 2026)
- Donut, Katia, Mordecai, SystemAI histories for parallel work
