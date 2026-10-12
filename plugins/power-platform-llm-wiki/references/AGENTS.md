# LLM Wiki - Operating Manual

> Managed file: installed and refreshed by the LLM Wiki plugin (`init` / `config --refresh-engine`). Do not edit it in the project; put project-specific rules in `llm-wiki/wiki.config.yml` under `conventions:`.

The LLM Wiki is a persistent, code-first project knowledge base. The agent writes and maintains `wiki/`; people curate sources, review and certify pages, and ask questions.

## Layout

```text
llm-wiki/
├── AGENTS.md            # this manual (managed)
├── wiki.config.yml      # project configuration (owned by the team)
├── .engine/             # managed copy of skills, scripts, templates, profiles (do not edit)
├── .state/              # raw-manifest.json: hashes of processed sources (commit it)
├── templates/           # optional project overrides of .engine/templates/
├── raw/                 # sources (immutable for the agent, except dumps and conversions)
│   ├── meetings/  analysis/  specs/  adrs/  assets/
│   └── devops/  code/  dataverse/  fno/  github/     # dumps written by `update --source ...`
├── wiki/                # knowledge base (agent-maintained)
└── dist/                # publish output (git-ignored)
```

### `wiki/` structure

| Folder          | Content                                                              | Typical source              |
| --------------- | -------------------------------------------------------------------- | --------------------------- |
| `index.md`      | Catalog: one line per page, grouped by folder. Read it first.        | all                         |
| `overview.md`   | Big-picture synthesis of the project                                 | all                         |
| `log.md`        | Append-only operation log                                            | all                         |
| `requirements/` | One page per functional requirement (`REQ-...`)                      | FDD, BBP, workshops         |
| `design/`       | Technical design (to-be)                                             | TDD, ADR, workshops         |
| `code/`         | As-built documentation derived from code and metadata                | code, Dataverse, F&O        |
| `features/`     | Work items (Feature/Epic) with their stories                         | Azure DevOps                |
| `projects/`     | One page per repository                                              | code, GitHub/Azure Repos    |
| `delivery/`     | Backlog overview, environments, sprint snapshots, release notes      | Azure DevOps                |
| `meetings/`     | Meeting syntheses (never transcripts)                                | Teams minutes / transcripts |
| `reference/`    | `decisions/` (ADR), `concepts/`, `entities/`, `sources/`, `queries/` | all                         |

The pages under `code/` depend on the configured profiles (`project.profiles` in `wiki.config.yml`). Read `.engine/profiles/<profile>.md` for each active profile before touching `code/`.

## Page format

Every page starts with YAML front matter:

```yaml
---
type: requirement | design | code | feature | project | delivery | meeting | decision | concept | entity | source | query | index | overview | log
status: draft | reviewed | certified | superseded | deprecated   # content lifecycle (not needed for index/overview/log)
owner: Functional team             # accountable person or team
updated: 2026-10-01                # last substantive change
sources: [raw/analysis/fdd.md, ado:US-123, crm-repo@a1b2c3d]   # provenance
tags: [sales]
# relations not expressed by a link (knowledge graph, confidence INFERRED): page paths or entity ids
related: [../design/integration.md, AxClass:SalesFormLetter_Contoso_Extension]
depends_on: [REQ-SAL-001]
# lifecycle
reviewed_by: Name
certified_by: Name
certified_at: 2026-10-01
# type-specific
req_id: REQ-SAL-001                # requirement
implemented_by: [../code/plugins.md]   # requirement (optional; lint also uses `implements`)
implements: [REQ-SAL-001]          # code / design
devops_id: "US-1234"               # feature / requirement
state: Active                      # work-item or decision state (never in `status`)
date: 2026-09-30                   # meeting / event date
participants: [Name, Name]         # meeting
---
```

Body: one `#` title, a `>` TL;DR paragraph, then sections. The TL;DR is mandatory (lint `AI001`): one or two plain sentences that stand on their own, because the knowledge graph, `llms.txt` and AI search use it as the page summary. Use the templates in `llm-wiki/templates/` (if present) or `.engine/templates/`, translating headings to `project.language`.

### Links

- Internal links are **relative Markdown links with the `.md` extension**: `[REQ-SAL-001](../requirements/REQ-SAL-001-credit-check.md)`. Anchors are allowed (`page.md#section`).
- Never use `[[wiki links]]`: the publish step converts links to the target format (Azure DevOps or GitHub Wiki).
- Do not put emoji in link text. Emoji are fine in headings and markers.
- Reference `raw/` sources as inline code paths (`` `raw/meetings/file.md` ``), not as links: they are not published.

### Inline markers

```text
> ⚠️ **Contradiction:** <page A> says X, <page B> says Y. Unresolved.
> ⚠️ **Drift:** the FDD says X, the code does Y (<repo>@<rev>:<path>).
> 🕐 **Stale:** last verified YYYY-MM-DD.
- 🎯 **Action:** @Owner - what by YYYY-MM-DD.        (mark done with ✅)
> 🚫 **Blocked:** waiting for <page>.
```

### Diagrams

Use fenced ```` ```mermaid ```` blocks (supported by Azure DevOps Wiki and GitHub). Every `code/` page needs at least one diagram. Prefer `flowchart`, `sequenceDiagram`, `erDiagram`, `classDiagram`, `stateDiagram-v2`; keep each diagram focused.

## Content governance

1. The agent creates and updates pages as `status: draft`. It never sets `reviewed` or `certified` on its own: only when a person explicitly asks, recording `reviewed_by` / `certified_by` / `certified_at` with the name they give.
2. **Certified pages are not rewritten.** When new information affects a certified page, append a `## 🔄 Pending updates` section with the proposed change, the source, and a `> ⚠️` marker; a human decides.
3. Never overwrite human-curated content silently: flag contradictions and drift instead.
4. Every claim must be traceable: fill `sources` and the `Source references` section.
5. **No secrets** in the wiki (passwords, keys, connection strings, tokens). **Personal data**: when `governance.pii_redaction` is true, keep only names and roles of project participants; never copy customer personal data, e-mail addresses or phone numbers from sources.
6. Code is the primary source for as-built behaviour; FDD/TDD describe intent. When they disagree, document both and flag `⚠️ Drift`.

## Grounding

Answer project questions only from wiki pages, citing them with relative links. If the wiki does not contain the answer, say "Not documented yet" and propose the ingest or update that would add it.

## Special files

- `index.md`: `- [Title](folder/page.md) - one-line summary`, grouped by folder. Every page must be listed.
- `overview.md`: update only when the big picture changes.
- `log.md`: append only, newest at the bottom, one entry per operation: `## [YYYY-MM-DD] <operation> | <subject>` followed by bullets (sources, pages created/updated, counts, `pendingKB`).

## Cross-reference conventions

| What            | Pattern                     | Example                                                                                                              |
| --------------- | --------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| Wiki page       | relative Markdown link      | `[ADR-001](../reference/decisions/ADR-001-wiki.md)`                                                                  |
| Requirement     | `REQ-<AREA>-<NNN>`          | `REQ-SAL-001`                                                                                                        |
| Work item       | `` `<Type>-<ID>` ``         | `US-128`, `Bug-77`                                                                                                   |
| Commit / file   | `` `<repo>@<rev>:<path>` `` | `crm@a1b2c3d:src/Plugins/Credit.cs`, `fno@C1234:Metadata/...` (TFVC changeset), `copy@2026-10-01:...` (plain folder) |
| F&O object      | `` `<AxType>:<Name>` ``     | `AxClass:SalesFormLetter_Contoso_Extension`                                                                          |
| Dataverse table | `` `dv:<logicalname>` ``    | `dv:salesorder`                                                                                                      |
| Sprint          | `` `YYYY-SNN` ``            | `2026-S08`                                                                                                           |

Write entity ids in inline code exactly as above: the knowledge graph recognises them (and the names of components in the code inventory, e.g. `` `CreditCheckPlugin` ``) and links the page to them.

## Knowledge graph

`Get-WikiGraph.ps1` turns the wiki into a typed graph (0 tokens): pages, the entities they cite and the custom objects of the code inventories, with relations `links_to`, `implements`, `implemented_by`, `cites`, `mentions`, `drift`, `contradiction` (extracted), `related_to`, `depends_on` (inferred, from `related:` / `depends_on:`), and `extends`, `extension_of`, `relates_to`, `uses_table`, `grants`, `opens` (from the inventory). It groups nodes into areas (seeded by requirement areas), and lists hubs, cross-area connections and gaps.

- **Use it before opening pages**: `-Query <ids or words>` returns the neighbourhood and `pagesToRead`; `-Impact <id>` what depends on an object; `-From <a> -To <b>` how two things are connected.
- **Feed it**: link pages, write entity ids in inline code, and add `related:` / `depends_on:` only for relations that no link or `implements` already expresses.
- `wiki/reference/knowledge-map.md` is generated (`generated: true`): never edit it by hand; it is rebuilt at every lint.

## Deterministic scripts (prefer them to reading files by hand)

All scripts are in `llm-wiki/.engine/scripts/` (PowerShell 7, `pwsh`), emit JSON, and cost no tokens to run.

| Script                                                                                        | Use                                                                                                                                                                                                                                                    |
| --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Get-RawDelta.ps1 -RawPath llm-wiki/raw`                                                      | New / changed / to-convert sources. After a successful ingest: `-MarkProcessed <paths>`. Adopt an existing wiki: `-Baseline`.                                                                                                                          |
| `Get-CodeInventory.ps1 -Path <clone> -OutFile llm-wiki/raw/code/<repo>-<date>.json`           | Inventory of plugins, PCF, web resources, solutions, flows, pipelines, F&O models and Ax objects. Git, TFVC or plain folder; without git add `-Revision` and `-StatePath llm-wiki/.state/code-<repo>.json` for the changed files, then `-AcceptState`. |
| `Test-WikiLint.ps1 -WikiPath llm-wiki/wiki`                                                   | Front matter, lifecycle, links, orphans, index coverage, overdue actions, stale pages, Mermaid, traceability, secrets, TL;DR and page size (`AI001`, `AI002`).                                                                                         |
| `Get-WikiGraph.ps1 -WikiPath llm-wiki/wiki [-Query <terms>\|-Impact <id>\|-From <a> -To <b>]` | Knowledge graph summary or a focused subgraph with `pagesToRead`. Outputs: `-ReportPath` (knowledge map), `-AiExportPath` (`graph.json`, `llms.txt`, `llms-full.txt`, `graph.html`), `-OutFile`, `-HtmlPath`.                                          |
| `Export-Wiki.ps1 -WikiPath llm-wiki/wiki -OutPath <dir> -Target azure-devops\|github`         | Converts the wiki for publishing.                                                                                                                                                                                                                      |

## Cost control

- Process only what changed (`Get-RawDelta.ps1`, code inventory diff by commit, TFVC changeset or file-hash snapshot); never re-read unchanged sources.
- Read inventories and summaries before opening source files; open only the files a page needs.
- To answer or update, ask the knowledge graph which pages matter (`Get-WikiGraph.ps1 -Query`) instead of reading `index.md` and following links by hand.
- Let scripts do mechanical work (lint, link checks, publish conversion).
- Record `pendingKB` (from `Get-RawDelta.ps1`) and the number of files read in each `log.md` entry so consumption can be tracked over time.

## Headless mode

When no human is in the loop (scheduled GitHub Action assigned to the Copilot coding agent): skip questions, take every value from `wiki.config.yml`, never change page lifecycle status beyond `draft`, never publish unless `publish.headless: true`, run lint at the end, and deliver the result as a pull request with the message `docs(wiki): auto-update [YYYY-MM-DD] - N pages updated`.
