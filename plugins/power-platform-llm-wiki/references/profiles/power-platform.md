# Profile: Dynamics 365 CE / Power Platform

Load this profile when `project.profiles` contains `power-platform`.

## Sources

| Source                                                                   | How to collect                        | Dump                               |
| ------------------------------------------------------------------------ | ------------------------------------- | ---------------------------------- |
| Source code (plugins, PCF, web resources, unpacked solutions, pipelines) | Local clone + `Get-CodeInventory.ps1` | `raw/code/<repo>-<date>.json`      |
| Dataverse metadata (live environment)                                    | `pacx` (preferred) / `pac`            | `raw/dataverse/<solution>-<date>/` |
| Work items                                                               | Azure DevOps MCP                      | `raw/devops/`                      |

### Dataverse commands

Run `pacx auth ping` first; ask the user to select a profile if it fails. For each configured solution:

```powershell
pac solution export --name <Solution> --path llm-wiki/raw/dataverse/<Solution>-<date>.zip --managed false
pacx script solution --solution <Solution> --output llm-wiki/raw/dataverse/<Solution>-<date>/ --includeStateFields
pacx table print --solution <Solution>          # ER diagram source
pacx plugin list --solution <Solution>
pacx table exportMetadata --table <logicalname>  # per table, only for tables of interest
```

When counting custom tables from `pacx script` logs, isolate the entity section: the relationship section uses the same line format and inflates counts.

## `wiki/code/` pages

| Page               | Content                                                                                                | Mandatory diagram     |
| ------------------ | ------------------------------------------------------------------------------------------------------ | --------------------- |
| `index.md`         | Component catalog, repositories, solutions, last sync (commit / date)                                  | component `flowchart` |
| `architecture.md`  | Solutions and dependencies, integrations, environments                                                 | `flowchart` / C4      |
| `datamodel.md`     | Custom tables, key columns, relationships, choices, alternate keys                                     | `erDiagram`           |
| `plugins.md`       | Plugin / Custom API matrix: class, table, message, stage, mode, order, images; business logic per step | `sequenceDiagram`     |
| `pcf.md`           | PCF controls: purpose, bound properties, host forms/views                                              | `flowchart`           |
| `web-resources.md` | Form scripts: events (OnLoad/OnChange/OnSave), ribbon commands                                         | `sequenceDiagram`     |
| `flows.md`         | Cloud flows: trigger, main actions, connection references, error handling                              | `flowchart`           |
| `forms-views.md`   | Main forms (tabs, key fields, scripts) and system views                                                | optional              |
| `security.md`      | Security roles x tables x privileges, field security, teams                                            | optional              |
| `integrations.md`  | Inbound/outbound interfaces, auth, frequency, error handling                                           | `sequenceDiagram`     |
| `alm.md`           | Solution layering, pipelines, environment variables, deployment steps                                  | `flowchart LR`        |

Split a page per component (e.g. `code/plugins/credit-check.md`) when it exceeds ~300 lines.

## Conventions

- Reference tables as `dv:<logicalname>`; show display name and logical name the first time.
- Plugin rows: `Class | Table | Message | Stage (PreValidation/PreOperation/PostOperation) | Mode (Sync/Async) | Order | Filtering attributes | Images`.
- Describe behaviour in business terms first, then technical detail; cite `<repo>@<sha>:<path>`.
- Fill `implements:` with the requirement IDs a component realises; add a `Traceability` table.
