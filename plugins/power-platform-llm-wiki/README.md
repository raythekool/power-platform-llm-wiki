# LLM Wiki - plugin

Code-first project knowledge base for Dynamics 365 delivery. See the [repository README](../../README.md) for the full description.

## Components

| Component        | Path                       | Purpose                                                                                                |
| ---------------- | -------------------------- | ------------------------------------------------------------------------------------------------------ |
| Agent            | `agents/llm-wiki.agent.md` | **LLM Wiki** agent: bootstrap, routing to skills, core rules                                           |
| Skill `init`     | `skills/init/`             | Wizard, scaffolding, engine installation, host integration (assets in `skills/init/assets/`)           |
| Skill `config`   | `skills/config/`           | Change settings, `--refresh-engine`, `--migrate` (v2 -> v3)                                            |
| Skill `update`   | `skills/update/`           | Sources (code, devops, dataverse, fno, github), `--full`, `--lint`, `--publish`, `--sprint`, lifecycle |
| Skill `ingest`   | `skills/ingest/`           | Meetings, FDD, TDD, ADR, generic documents                                                             |
| Skill `query`    | `skills/query/`            | Grounded answers with citations                                                                        |
| Operating manual | `references/AGENTS.md`     | Installed as `llm-wiki/AGENTS.md`                                                                      |
| Profiles         | `references/profiles/`     | `power-platform`, `dynamics-fno`, `generic`                                                            |
| Publishing       | `references/publishing.md` | Azure DevOps Wiki / GitHub Wiki procedure                                                              |
| Templates        | `templates/`               | meeting, requirement, design, adr, code-component, source                                              |
| MCP              | `.mcp.json`                | GitHub MCP (Azure DevOps MCP is configured per project by `init`)                                      |

## Scripts (PowerShell 7, JSON output)

| Script                  | Purpose                                                                                        |
| ----------------------- | ---------------------------------------------------------------------------------------------- |
| `Install-Engine.ps1`    | Copies AGENTS.md, scripts, templates, profiles and headless skill copies into `llm-wiki/`      |
| `Get-RawDelta.ps1`      | Incremental detection of new / changed / to-convert sources (SHA-256 manifest)                 |
| `Get-CodeInventory.ps1` | Inventory of CE / Power Platform components and F&O Ax* metadata                               |
| `Test-WikiLint.ps1`     | Front matter, lifecycle, links, orphans, index, actions, stale, Mermaid, traceability, secrets |
| `Export-Wiki.ps1`       | Conversion for Azure DevOps Wiki (`.order`, `%2D`, absolute links, attachments) or GitHub Wiki |
| `LlmWiki.Common.ps1`    | Shared helpers (UTF-8 I/O, front matter, links)                                                |
