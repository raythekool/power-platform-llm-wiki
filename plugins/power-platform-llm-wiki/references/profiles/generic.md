# Profile: Generic code (integrations, Azure, .NET, web)

Load this profile when `project.profiles` contains `generic`, or for repositories that are neither Power Platform nor F&O (Azure Functions, Logic Apps, APIs, middleware).

## Sources

Local clone + `Get-CodeInventory.ps1` (languages, .NET projects, pipelines). Then read entry points (`Program.cs`, `host.json`, function folders, `*.bicep` / `*.tf`, OpenAPI specs) for the pages below.

## `wiki/code/` pages

| Page              | Content                                                                                      | Mandatory diagram |
| ----------------- | -------------------------------------------------------------------------------------------- | ----------------- |
| `index.md`        | Repositories, projects, runtimes, last commit                                                | `flowchart`       |
| `architecture.md` | Components, hosting, data stores, external systems                                           | `flowchart` / C4  |
| `<component>.md`  | One page per deployable component: responsibility, interfaces, configuration, error handling | `sequenceDiagram` |
| `integrations.md` | Contracts (OpenAPI / message schemas), auth, retry, monitoring                               | `sequenceDiagram` |
| `alm.md`          | Build and release pipelines, infrastructure as code, environments                            | `flowchart LR`    |

Fill `implements:` and a `Traceability` table as for the other profiles.
