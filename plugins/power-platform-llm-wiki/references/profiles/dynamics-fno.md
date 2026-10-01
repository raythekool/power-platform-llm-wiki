# Profile: Dynamics 365 Finance & Operations

Load this profile when `project.profiles` contains `dynamics-fno`.

## Sources

| Source                          | How to collect                                                                                                                 | Dump                                                     |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------- |
| X++ metadata and code (Ax* XML) | Local clone of the Azure Repos / TFVC-migrated Git repo, or a copy of `PackagesLocalDirectory/<Package>` for the custom models | `raw/fno/<repo>-<date>.json` via `Get-CodeInventory.ps1` |
| Model descriptors               | `<Package>/Descriptor/<Model>.xml` (found by the inventory)                                                                    | same JSON (`fno.models`)                                 |
| Build / release pipelines       | `azure-pipelines*.yml` in the repo                                                                                             | same JSON (`components.pipelines`)                       |
| Work items                      | Azure DevOps MCP                                                                                                               | `raw/devops/`                                            |

Configure `fno.metadata_paths` in `wiki.config.yml` with the folders that contain **custom** packages only. Never inventory standard Microsoft packages (ApplicationSuite, ApplicationPlatform, ...): they are huge and not project knowledge.

```powershell
pwsh llm-wiki/.engine/scripts/Get-CodeInventory.ps1 -Path <clone>/Metadata -OutFile llm-wiki/raw/fno/<repo>-<date>.json
```

The inventory gives, per object type (`AxTable`, `AxTableExtension`, `AxClass`, `AxForm`, `AxFormExtension`, `AxDataEntityView`, `AxEnum`, `AxEdt*`, `AxSecurityPrivilege/Duty/Role`, `AxMenuItem*`, ...): names, fields, relations, indexes, method names, `extensionOf` targets and whether a method calls `next` (Chain of Command). Open the XML of an object only when its page needs source-level detail (method bodies are in `<Source>` CDATA).

Live environment data (LCS / PPAC, data entities over OData, batch job history) is out of scope for the automatic sync: document it from exports placed in `raw/specs/` or `raw/analysis/`.

## `wiki/code/` pages

| Page               | Content                                                                                             | Mandatory diagram                    |
| ------------------ | --------------------------------------------------------------------------------------------------- | ------------------------------------ |
| `index.md`         | Models (name, layer, publisher, references), object counts per type, last commit                    | `flowchart` of models and references |
| `architecture.md`  | Models / packages, integrations, environments, ISV dependencies                                     | `flowchart`                          |
| `datamodel.md`     | New tables and table extensions: fields (EDT / enum), relations, indexes                            | `erDiagram`                          |
| `extensions.md`    | Chain of Command and event-handler extensions: target object, method, `next` call, business purpose | `classDiagram` / `sequenceDiagram`   |
| `classes.md`       | New classes: services, controllers / contracts (SysOperation), batch jobs                           | `classDiagram`                       |
| `forms.md`         | New forms and form extensions, data sources, menu items                                             | optional                             |
| `data-entities.md` | Data entities: public name / collection, staging, data sources, mapped fields, DMF / OData usage    | `flowchart`                          |
| `security.md`      | Privileges -> duties -> roles with entry points (menu items)                                        | `flowchart`                          |
| `integrations.md`  | Custom services, OData / DMF packages, Business Events, recurring integrations                      | `sequenceDiagram`                    |
| `alm.md`           | Models, build pipeline, deployable packages, release process (LCS / PPAC)                           | `flowchart LR`                       |

## Conventions

- Reference objects as `` `<AxType>:<Name>` `` (e.g. `` `AxClass:SalesFormLetter_Contoso_Extension` ``).
- Extensions: always state the **standard object being extended**, the method, and whether standard logic still runs (`next` called).
- Separate new objects from extensions of standard objects in every page.
- Fill `implements:` with requirement IDs and a `Traceability` table; flag `⚠️ Drift` when the FDD describes behaviour that the code does not implement.
