# LLM Wiki — Power Platform Edition

> ⚠️ **This is a reference document.** It describes the pattern and rationale behind the LLM Wiki specialized for Power Platform / Dynamics 365 projects. To generate a working wiki repo from this document, share it with your LLM agent (Copilot, Claude, etc.) and ask: *"Generate an llm-wiki repository from this document."*

A portable, LLM-maintained project wiki for **Power Platform and Dynamics 365** delivery projects.

This document extends the original [LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) and specializes it for the Power Platform ecosystem: Dataverse solutions, Model-Driven Apps, plugins (C#), PCF controls (React/TypeScript), JavaScript web resources, Power Automate flows, and the Azure DevOps-based delivery lifecycle typical of D365 projects.

---

## The core idea

Power Platform projects generate documentation across too many tools: meeting notes in Teams/OneNote, specs in SharePoint, work items in Azure DevOps, code in GitHub, solution configs in Dataverse, architectural decisions in someone's head. When someone asks "why did we add that plugin?" or "what was decided about the data model?", the answer requires digging through three systems and asking two people.

The LLM Wiki solves this by making an LLM agent responsible for **building and maintaining a persistent, cross-referenced knowledge base** from all these sources. When you add a meeting transcript, the LLM doesn't just file it — it extracts decisions, links them to the relevant Dataverse tables, updates the feature pages in Azure DevOps, and flags where new information contradicts the original BBP. The wiki is a compounding artifact: every source you add makes it richer.

You never write the wiki yourself. The LLM writes and maintains all of it. You curate sources (paste meeting minutes, drop specs into `raw/`) and ask questions. Most data flows in automatically via **MCP server integrations** (Azure DevOps, GitHub) and via **scheduled Copilot Coding Agent** runs.

---

## Power Platform project context

### What it tracks

| Source               | How it arrives             | What gets extracted                                                                            |
| -------------------- | -------------------------- | ---------------------------------------------------------------------------------------------- |
| **Azure DevOps**     | MCP server 🔌 (live)        | Features, User Stories, Tasks, Bugs, Sprint status, WIQL queries                               |
| **GitHub repos**     | MCP server 🔌 + `gh` CLI    | Solutions, plugins (C#), PCF controls, JS web resources, Power Automate flows, CI/CD pipelines |
| **SharePoint**       | MCP server 🔌 (optional)    | BBP docs, analysis docs, technical specs, test plans                                           |
| **Meeting minutes**  | Manual 📋 → `raw/meetings/` | Decisions, action items, blockers, design choices                                              |
| **Analysis / specs** | Manual 📋 or SharePoint 🔌   | Functional requirements, data model specs, integration specs                                   |
| **ADRs**             | Manual 📋 → `raw/adrs/`     | Architectural decisions and their rationale                                                    |

### Power Platform–specific code components

The wiki includes a `wiki/code/` section that provides **functional analysis** of the codebase — not just file listings but descriptions of what each component does, how it integrates with Dataverse, and the business logic it implements.

| Component type                       | Typical location in repo                  | Wiki page                       |
| ------------------------------------ | ----------------------------------------- | ------------------------------- |
| **Dataverse plugins** (C#)           | `plugin/` or `Plugins/`                   | `wiki/code/plugin.md`           |
| **Custom APIs** (C#)                 | Same as plugins or separate project       | `wiki/code/plugin.md` (section) |
| **PCF controls** (React/TS)          | `pcf/` or `controls/`                     | `wiki/code/pcf.md`              |
| **JavaScript web resources**         | `WebResources/`                           | `wiki/code/web-resources.md`    |
| **Power Automate flows**             | Exported in solution `.zip`               | `wiki/code/flows.md`            |
| **Console apps / batch jobs** (.NET) | `batch/` or `jobs/`                       | `wiki/code/batch.md`            |
| **Solution metadata**                | `solution/` (exported via `pac`)          | `wiki/code/infrastructure.md`   |
| **Data model**                       | `datamodel/` scripts (PACX)               | `wiki/code/datamodel.md`        |
| **Build/deploy pipelines**           | `.github/workflows/`, `.azure-pipelines/` | `wiki/code/infrastructure.md`   |

### How they connect

```
┌──────────────────────────────────────────────────────────────┐
│                    MCP Servers (live)                         │
│                                                              │
│  🔌 Azure DevOps MCP    🔌 GitHub MCP    🔌 SharePoint MCP  │
│  Features, US, Tasks    Repos, PRs,      BBPs, Specs        │
│  Sprints, WIQL          Branches, Code   (optional)          │
└──────────────┬───────────────┬───────────────┬───────────────┘
               │               │               │
               ▼               ▼               ▼
┌──────────────────────────────────────────────────────────────┐
│                      LLM Wiki Agent                          │
│                                                              │
│  VS Code Copilot (interactive)                               │
│  Copilot Coding Agent (scheduled, headless)                  │
│  Reads MCP + raw/ → writes wiki/                             │
└────────────┬──────────────────────────────┬──────────────────┘
             │                              │
     ┌───────▼───────┐            ┌─────────▼─────────┐
     │    raw/       │            │      wiki/         │
     │  (manual)     │            │   (LLM-owned)      │
     │  meetings/    │            │  projects/          │
     │  analysis/    │            │  features/          │
     │  specs/       │            │  meetings/          │
     │  adrs/        │            │  decisions/         │
     │  assets/      │            │  concepts/          │
     └───────────────┘            │  entities/          │
                                  │  sources/           │
                                  │  queries/           │
                                  │  code/              │
                                  └─────────────────────┘
```

---

## Architecture

### Layers

There are six layers in the `llm-wiki/` folder:

| #   | Layer       | Path                             | Owner             | Purpose                                     |
| --- | ----------- | -------------------------------- | ----------------- | ------------------------------------------- |
| 1   | MCP Servers | Azure DevOps, GitHub, SharePoint | Automated         | Live, read-only access to project data      |
| 2   | Raw sources | `raw/`                           | Human + MCP dumps | Immutable source documents                  |
| 3   | Wiki        | `wiki/`                          | LLM               | Persistent, cross-referenced knowledge base |
| 4   | Schema      | `AGENTS.md`                      | Both              | Operating manual for the LLM                |
| 5   | Skills      | `skills/`                        | Human             | Executable procedures (one per operation)   |
| 6   | Setup       | `setup/`                         | Human             | Templates and agent prompts for integration |

### 1. MCP Servers — Live integrations

| MCP Server           | Source                                                                                            | What it provides                                                | Required?  |
| -------------------- | ------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- | ---------- |
| **Azure DevOps MCP** | [microsoft/azure-devops-mcp](https://github.com/microsoft/azure-devops-mcp)                       | Features, User Stories, Tasks, Bugs, WIQL queries, Sprint board | ⬜ Optional |
| **GitHub MCP**       | [github/github-mcp-server](https://github.com/github/github-mcp-server)                           | Repos, branches, PRs, issues, commits, file contents            | ⬜ Optional |
| **SharePoint MCP**   | [memori-ai/mcp-sharepoint](https://github.com/memori-ai/mcp-sharepoint)                           | BBP documents, specs, analysis docs                             | ⬜ Optional |
| **MarkItDown MCP**   | [microsoft/markitdown](https://github.com/microsoft/markitdown/tree/main/packages/markitdown-mcp) | Converts Office docs, PDFs, images, audio to Markdown           | ⬜ Optional |

**GitHub MCP limitation:** The GitHub MCP proxy does not support the `ref` parameter on `get_file_contents` — it can only read files from the default branch. For non-default branches (e.g. `develop`, `feature/*`), use the `gh` CLI fallback:

```powershell
gh api "repos/{owner}/{repo}/contents/{path}?ref={branch}" -H "Accept: application/vnd.github.v3.raw"
```

**Authentication:**
- Azure DevOps: PAT (Personal Access Token) with work item read permissions
- GitHub: PAT with `repo` scope, or use the built-in VS Code Copilot MCP proxy
- SharePoint: Azure AD app registration with Graph API permissions

### 2. `raw/` — Source documents and MCP dumps

All external data lands here first. The LLM **never modifies** human-curated files (except `.md` conversions via [MarkItDown](https://github.com/microsoft/markitdown) and MCP dump files).

**Supported formats:** `.md`, `.docx`, `.pptx`, `.xlsx`, `.pdf`, `.txt`, `.html`, `.csv`, `.json`. Non-markdown files are converted via MarkItDown before processing. MarkItDown can be used as:

- **MCP Server:** `pip install markitdown-mcp` → tool `convert_to_markdown(uri)` available to the LLM directly
- **VS Code Extension:** install [`MarkItDown`](https://marketplace.visualstudio.com/items?itemName=bioinfo.markitdown-vscode) → right-click any file → "Convert to Markdown"
- **CLI:** `pip install "markitdown[all]"` → `markitdown file.pdf -o file.md`

```
raw/
├── meetings/       # meeting minutes, standup notes, retrospectives
├── analysis/       # BBP sections, functional analysis, feasibility studies
├── specs/          # technical specs, integration specs
├── adrs/           # Architecture Decision Records
├── assets/         # images, diagrams, Visio files
├── devops/         # MCP dumps: work items (JSON + MD)
└── github/         # MCP dumps: repos, PRs (JSON + MD)
    └── src/        # Source file archives (downloaded via gh api)
```

**MCP dump naming:** `<source>-YYYY-MM-DD.json` + `<source>-YYYY-MM-DD.md`. Same-day syncs overwrite (idempotent within a day).

### 3. `wiki/` — The persistent knowledge base

Entirely owned and maintained by the LLM.

```
wiki/
├── index.md             # content catalog — always read first
├── overview.md          # high-level project synthesis
├── log.md               # append-only operation log
│
├── delivery/            # ADF delivery tracking
│   ├── backlog-overview.md  # backlog hierarchy (Feature → US → Task)
│   ├── environments.md      # DEV / SIT / UAT / PROD status
│   ├── sprint-snapshots/    # one snapshot per sprint
│   └── release-notes/       # one page per release / go-live
│
├── projects/            # one page per GitHub repo
├── features/            # one page per DevOps Feature/epic
│
├── code/                # source code functional analysis
│   ├── index.md             # code wiki index + repo layout
│   ├── architecture.md      # tech stack, data flow, entity matrix
│   ├── datamodel.md         # Dataverse tables, relationships, option sets
│   ├── plugin.md            # Dataverse plugins & Custom APIs (C#)
│   ├── pcf.md               # PCF controls (React/TypeScript)
│   ├── web-resources.md     # JavaScript web resources
│   ├── forms.md             # Dataverse forms (main, quick create, quick view)
│   ├── views.md             # Dataverse views (system, personal)
│   ├── roles.md             # Security roles & privilege matrix
│   ├── flows.md             # Power Automate cloud flows
│   ├── batch.md             # Console apps & batch jobs (.NET)
│   ├── stampa-dinamica.md   # Dynamic printing templates & pipeline
│   └── infrastructure.md    # Solutions, CI/CD, build/deploy
│
├── meetings/            # synthesized meeting pages
│
└── reference/           # cross-cutting knowledge base
    ├── decisions/           # ADRs and key decisions
    ├── concepts/            # cross-cutting technical concepts
    ├── entities/            # people, teams, systems, external services
    ├── sources/             # one summary per ingested source
    └── queries/             # saved answers to questions
```
```

### 4. `AGENTS.md` — Operating manual

The LLM reads this file before every operation. It defines page format, inline markers, cross-reference conventions, and all operation workflows.

### 5. `skills/` — Executable procedures

One markdown file per operation. The LLM reads the relevant skill file **before** executing an operation.

| Skill           | File                                 | Trigger                           |
| --------------- | ------------------------------------ | --------------------------------- |
| Setup           | `skills/llm-wiki-setup.md`           | "setup the wiki" / first install  |
| Ingest          | `skills/llm-wiki-ingest.md`          | "ingest raw/..."                  |
| Ingest Meeting  | `skills/llm-wiki-ingest-meeting.md`  | "ingest raw/meetings/..."         |
| Sync DevOps     | `skills/llm-wiki-sync-devops.md`     | "sync devops"                     |
| Sync GitHub     | `skills/llm-wiki-sync-github.md`     | "sync github"                     |
| Sync Dataverse  | `skills/llm-wiki-sync-dataverse.md`  | "sync dataverse"                  |
| Query           | `skills/llm-wiki-query.md`           | "what does the wiki say about..." |
| Lint            | `skills/llm-wiki-lint.md`            | "lint the wiki"                   |
| Sprint Snapshot | `skills/llm-wiki-sprint-snapshot.md` | "sprint snapshot"                 |
| Full Update     | `skills/llm-wiki-full-update.md`     | "update the wiki" / "sync all"    |
| Publish         | `skills/llm-wiki-publish.md`         | "publish wiki" / "push wiki"      |

### 6. `setup/` — Integration templates

Templates and agent prompts that integrate `llm-wiki/` with the host project. **No PowerShell installer** — setup is performed by an LLM agent via a dedicated prompt.

| File                             | Purpose                                                                         |
| -------------------------------- | ------------------------------------------------------------------------------- |
| `setup/llm-wiki-setup.prompt.md` | Agent entry point (`/llm-wiki-setup`) — delegates to `skills/llm-wiki-setup.md` |
| `setup/llm-wiki.prompt.md`       | Wiki agent prompt (copied to `.github/prompts/` during setup)                   |
| `setup/wiki.yml`                 | GitHub Actions workflow — creates issue assigned to Copilot                     |
| `setup/copilot-setup-steps.yml`  | Copilot Coding Agent environment (markitdown, gh)                               |
| `setup/env.sample`               | `.env` template with credential placeholders                                    |
| `setup/mcp-servers.json`         | MCP server config fragment (merged into `.vscode/mcp.json`)                     |
| `setup/copilot-snippet.md`       | Text appended to `.github/copilot-instructions.md`                              |

### Configuration: `wiki.config.yml`

Central configuration file — what to track and how to filter.

```yaml
devops:
  area_paths: []                    # empty = all areas
  iteration_prefix: ""              # e.g. "Project\\2026"
  work_item_types: [Feature, User Story, Task, Bug]
  excluded_states: [Removed]

github:
  repos:
    - owner/solution-repo
    - owner/plugin-repo
  branch_patterns:
    - "^main$"
    - "^develop$"
    - "^feature/"
    - "^release/"
    - "^hotfix/"

sharepoint:
  enabled: false
  site_url: ""
  document_libraries: []
```

---

## Page format

Every wiki page includes YAML frontmatter + structured content.

### Frontmatter

```yaml
---
type: project | feature | meeting | decision | concept | entity | source | query | delivery
project: solution-repo              # which repo (if applicable)
devops_id: "US-1234"                # Azure DevOps work item ID
branch: feature/auth-module         # Git branch
sprint: "2026-S08"                  # Sprint identifier
participants: [Marco, Alice]        # For meeting pages
date: 2026-04-28
status: active | completed | superseded | blocked
tags: [dataverse, plugin, custom-api]
---
```

### Content structure

```markdown
# Page Title

> One-paragraph TL;DR.

## Section 1

...

## Cross-References

- Related: [[features/F-42-user-authentication]], [[projects/solution-repo]]
- DevOps: `US-1234`, `T-567`
- Branch: `solution-repo#feature/auth-module`

## Source References

- `raw/meetings/2026-04-28-sprint-review.md`
- Via Azure DevOps MCP: `US-1234`
```

### Inline markers

```
> ⚠️ **Contradiction:** [[Page A]] says X, but [[Page B]] says Y. Unresolved.
> 🕐 **Stale:** This claim may be outdated. Last verified: YYYY-MM-DD.
> 🎯 **Action:** @Marco — Finalize data model by 2026-05-02. Source: [[meetings/2026-04-28-sprint-review]].
> 🚫 **Blocked:** Waiting on [[features/F-55-auth-provider]] before this can proceed.
```

### Mermaid diagrams

Use Mermaid fenced code blocks for visual documentation. Every `wiki/code/` page must include at least one diagram.

| Context                   | Diagram type                            |
| ------------------------- | --------------------------------------- |
| Architecture / overview   | `graph TD`, `C4Context` / `C4Container` |
| Dataverse data model      | `erDiagram`                             |
| Plugin / Custom API logic | `sequenceDiagram`, `flowchart`          |
| Power Automate flows      | `flowchart LR`                          |
| Build / deploy pipeline   | `flowchart LR`                          |
| Entity state / lifecycle  | `stateDiagram-v2`                       |
| Class structure (plugins) | `classDiagram`                          |

### Cross-reference conventions

| What             | Pattern                 | Example                             |
| ---------------- | ----------------------- | ----------------------------------- |
| Wiki page        | `[[path/page-name]]`    | `[[features/F-42-user-auth]]`       |
| DevOps work item | `` `<type>-<ID>` ``     | `F-42`, `US-128`, `T-567`, `BUG-89` |
| Git branch       | `` `<repo>#<branch>` `` | `solution-repo#feature/auth`        |
| Git commit       | `` `<repo>@<sha>` ``    | `solution-repo@a1b2c3d`             |
| Person/team      | `[[entities/<name>]]`   | `[[entities/team-backend]]`         |
| Sprint           | `` `YYYY-SNN` ``        | `2026-S08`                          |
| Dataverse table  | `` `dv:<table>` ``      | `dv:ray_asset`, `dv:contact`        |
| Dataverse plugin | `` `plugin:<name>` ``   | `plugin:ValidateAssetCreate`        |

### GitHub Wiki link rules

GitHub Wiki `[[wiki links]]` do **NOT** support pipe alias syntax. Use `[[Page-Name]]` only — never `[[Page-Name|Alias]]`. No emoji inside `[[wiki links]]` or `_Sidebar.md`.

---

## Operations

### Ingest (from `raw/`)

1. Check file format — convert non-markdown via `markitdown` (keep original).
2. Read the `.md` version.
3. Identify source type (meeting, analysis, spec, ADR).
4. Discuss key takeaways with the user (skip in headless mode).
5. Write summary page at `wiki/reference/sources/<slug>.md`.
6. Scan `wiki/index.md` for related pages.
7. Update related pages — add info, flag contradictions, update cross-refs.
8. Create pages for new projects, features, concepts, or entities.
9. Update `wiki/index.md`.
10. Update `wiki/overview.md` if the big picture changed.
11. Append to `wiki/log.md`.

### Ingest Meeting (from `raw/meetings/`)

1. Convert to markdown if needed.
2. Extract: **participants**, **decisions**, **action items** (🎯), **discussion points**, **blockers**.
3. Create meeting synthesis at `wiki/meetings/<date>-<slug>.md`.
4. Update project, feature, entity, and decision pages.
5. Flag contradictions with existing wiki content.
6. Update `wiki/index.md` and `wiki/log.md`.

### Sync DevOps (via MCP → raw/ → wiki/)

1. Query via MCP: `wit_query_by_wiql`, `wit_get_work_item`, `wit_list_work_items`.
2. Dump to `raw/devops/work-items-YYYY-MM-DD.json` + `.md`.
3. Process: create/update `wiki/features/<id>-<slug>.md` with frontmatter.
4. Map parent-child (Feature → User Stories → Tasks).
5. Update project pages, track blockers (🚫), detect drift (⚠️).
6. Update `wiki/index.md` and `wiki/log.md`.

### Sync GitHub (via MCP + `gh` CLI → raw/ → wiki/)

1. Query via MCP: repos, branches, PRs, commits.
2. Read source code from non-default branches via `gh api` REST fallback.
3. Dump to `raw/github/<repo>-YYYY-MM-DD.json` + `.md`.
4. Process: create/update `wiki/projects/<repo>.md`.
5. **Functional code analysis** — describe what components do, not just file listings:
   - Plugins: what entities they trigger on, what business logic they implement
   - PCF controls: what UI they provide, which Dataverse fields they bind to
   - Web resources: what form events they handle, what UX they add
   - Flows: what triggers them, what actions they perform
6. Cross-reference branches with feature pages.
7. Update `wiki/index.md` and `wiki/log.md`.

### Sync Dataverse (via PAC/PACX → raw/ → wiki/code/)

1. Read `wiki.config.yml` → `dataverse` section for solutions, prefixes, component flags.
2. Verify connection: `pacx auth ping`.
3. For each solution:
   - Export via `pac solution export` → `.zip` → extract
   - Reverse-engineer via `pacx script solution` → `.ps1` + `.csv`
   - Generate ER diagram via `pacx table print` → Mermaid
   - List plugins via `pacx plugin list`
   - Export per-table metadata via `pacx table exportMetadata`
4. Save human-readable summary to `raw/dataverse/<solution>-YYYY-MM-DD.md`.
5. Process into `wiki/code/` pages: `datamodel.md`, `plugin.md`, `forms.md`, `views.md`, `roles.md`, `flows.md`, `architecture.md`, `index.md`.
6. Cross-reference with existing feature and project pages.
7. Update `wiki/index.md` and `wiki/log.md`.

> **Note:** `pac` is used only for solution export (.zip). All analysis commands use `pacx`. Solution .zip files are gitignored.

### Query

1. Read `wiki/index.md` — always.
2. Load relevant pages.
3. Synthesize answer with `[[wiki-link]]` citations.
4. Offer to file as `wiki/reference/queries/<slug>.md`.
5. Never answer from general knowledge alone.

### Lint

Check for: contradictions, stale claims, orphan pages, dead references, missing pages, DevOps drift, stale action items, data gaps. Produce `wiki/lint-YYYY-MM-DD.md`. Fix safe issues automatically, flag contradictions for review.

### Sprint Snapshot

Collect active features, recent meetings, open action items (🎯), blockers (🚫). Generate `wiki/delivery/sprint-snapshots/YYYY-SNN.md`.

---

## Setup — agent-driven, no installer

Setup is performed by an LLM agent, not a shell script. The entry point is a VS Code prompt file.

### How to set up

1. **Copy** the `llm-wiki/` folder into your project root.
2. **Open** the setup prompt in VS Code: `/llm-wiki-setup` (file: `llm-wiki/setup/llm-wiki-setup.prompt.md`).
3. The agent reads `llm-wiki/skills/llm-wiki-setup.md` and asks you for:
   - Azure DevOps organization + project name
   - GitHub repo(s) to track
   - Azure DevOps PAT
   - Optional: area path filter, iteration prefix
4. The agent writes all integration files idempotently:

| File created/updated                 | Purpose                                        |
| ------------------------------------ | ---------------------------------------------- |
| `.github/copilot-instructions.md`    | Tells Copilot about the wiki (appended)        |
| `.vscode/mcp.json`                   | Azure DevOps + GitHub + MarkItDown MCP servers |
| `.github/workflows/wiki.yml`         | Scheduled workflow → issue → Copilot agent     |
| `.github/copilot-setup-steps.yml`    | Copilot Coding Agent environment               |
| `.github/prompts/llm-wiki.prompt.md` | Agent prompt for interactive operations        |
| `.env`                               | Credentials (gitignored)                       |
| `.gitignore`                         | LLM Wiki entries added                         |
| `llm-wiki/wiki.config.yml`           | Populated with your project settings           |

### MCP server configuration

The setup agent creates `.vscode/mcp.json` with:

```json
{
  "servers": {
    "azure-devops": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@azure-devops/mcp@latest", "YOUR_DEVOPS_ORG", "-d", "dev.azure.com"],
      "envFile": "${workspaceFolder}/.env"
    },
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/"
    },
    "markitdown": {
      "type": "stdio",
      "command": "markitdown-mcp"
    }
  }
}
```

For non-VS Code agents (Claude Desktop, etc.), copy the server entries into your agent's config file.

---

## Scheduled updates — Copilot Coding Agent

The wiki updates itself automatically via **GitHub Copilot Coding Agent**:

1. A **scheduled workflow** (`.github/workflows/wiki.yml`) runs weekly (configurable cron).
2. The workflow creates a **GitHub issue** assigned to `copilot`, specifying the operation (`full-update`, `sync-devops`, `lint`, `sprint-snapshot`).
3. **Copilot Coding Agent** picks up the issue, reads `AGENTS.md` + the relevant skill file, executes the operation in headless mode.
4. Copilot opens a **Pull Request** with all wiki changes for review.

### Copilot setup steps

The file `.github/copilot-setup-steps.yml` prepares the Copilot agent environment:

```yaml
name: "Copilot Setup Steps"
on: copilot_setup
jobs:
  copilot-setup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: "8.x"
      - name: Install markitdown
        run: pip install "markitdown[all]>=0.1.0"
      - name: Install PAC CLI
        run: dotnet tool install --global Microsoft.PowerApps.CLI.Tool
      - name: Verify tools
        run: |
          markitdown --version
          gh --version
          pac --version
```

### Manual trigger

```sh
gh workflow run wiki.yml -f operation=full-update
```

### Headless mode rules

When running without a human in the loop:

- Skip interactive discussion and confirmation steps.
- Run all syncs automatically (DevOps, GitHub, Dataverse, SharePoint).
- Auto-convert non-markdown files via MarkItDown.
- Process new files in `raw/` not yet in `wiki/log.md`.
- Generate sprint snapshot if a sprint boundary is detected.
- Run a lint pass at the end.
- Commit message: `docs(wiki): auto-update [YYYY-MM-DD] — N pages updated`

---

## Power Platform–specific conventions

### Dataverse entity references

When referencing Dataverse tables, use the pattern `` `dv:<logical_name>` `` — e.g. `dv:ray_asset`, `dv:account`. This distinguishes Dataverse entities from general concepts and makes them searchable.

### Plugin documentation

For each plugin class, document:

- **Entity + Message** — what triggers it (e.g. `Create` on `ray_asset`)
- **Stage** — Pre-Validation, Pre-Operation, Post-Operation
- **Business logic** — what it does in plain language
- **Dependencies** — other plugins, custom APIs, or flows it interacts with
- **Known issues** — gotchas, edge cases

### PCF control documentation

For each PCF control, document:

- **Bound field(s)** — what Dataverse column(s) it renders
- **Technology** — React, Angular, vanilla TS
- **UI behavior** — what the user sees and can do
- **Configuration** — manifest parameters and their effect

### Solution structure

Document the Dataverse solution layout:

- Solution name and publisher prefix
- Which tables, plugins, flows, web resources are in the solution
- Dependencies on other solutions (e.g. base D365 modules)
- Deployment order and environment strategy (DEV → TEST → UAT → PROD)

---

## Folder structure

```
llm-wiki/
├── AGENTS.md              # LLM operating manual
├── CLAUDE.md              # Claude-specific instructions
├── wiki.config.yml        # What to track (edit this)
├── raw/                   # Drop source documents here
│   ├── meetings/          # Meeting minutes (.md, .docx, .pdf)
│   ├── analysis/          # BBP, functional analysis
│   ├── specs/             # Technical specs
│   ├── adrs/              # Architecture Decision Records
│   ├── assets/            # Images, diagrams
│   ├── devops/            # MCP dumps (auto-generated)
│   ├── github/            # MCP dumps (auto-generated)
│   │   └── src/           # Source archives (downloaded via gh api)
│   └── dataverse/         # Dataverse solution exports & analysis (PAC/PACX)
├── wiki/                  # LLM-maintained knowledge base
│   ├── index.md           # Content catalog (read first)
│   ├── overview.md        # High-level synthesis
│   ├── log.md             # Append-only operation log
│   ├── sources/
│   ├── projects/
│   ├── features/
│   ├── meetings/
│   ├── decisions/
│   ├── concepts/
│   ├── entities/
│   ├── queries/
│   └── code/              # Source code functional analysis
│       ├── index.md
│       ├── architecture.md
│       ├── datamodel.md
│       ├── plugin.md
│       ├── pcf.md
│       ├── web-resources.md
│       ├── forms.md
│       ├── views.md
│       ├── roles.md
│       ├── flows.md
│       ├── batch.md
│       └── infrastructure.md
├── skills/                # Operation procedures
│   ├── setup.md
│   ├── ingest.md
│   ├── ingest-meeting.md
│   ├── sync-devops.md
│   ├── sync-github.md
│   ├── sync-dataverse.md
│   ├── query.md
│   ├── lint.md
│   ├── sprint-snapshot.md
│   └── full-update.md
├── setup/                 # Setup templates (no installer)
│   ├── llm-wiki-setup.prompt.md
│   ├── llm-wiki.prompt.md
│   ├── wiki.yml
│   ├── copilot-setup-steps.yml
│   ├── env.sample
│   ├── mcp-servers.json
│   └── copilot-snippet.md
└── .markdownlint.json     # Lint config
```

---

## Conventions

- Markdown files only in `wiki/`. No exceptions.
- `raw/` accepts any format — converted via MarkItDown during ingest.
- `[[Wiki Links]]` for all internal cross-references.
- YAML frontmatter on every wiki page.
- Meeting pages are **syntheses**, not copies.
- DevOps pages are **living documents** — note what changed and when.
- One page per concept — cross-link from multiple features.
- The wiki is a compounding artifact — it gets more valuable with every ingest.
- The LLM writes and maintains the wiki. The human curates sources and asks questions.
- `llm-wiki.md` (this file) is a reference document. The operational schema is `AGENTS.md`.
- Skills in `skills/` are the authoritative procedures. The LLM reads them before every operation.

---

## Prerequisites

- **VS Code** with GitHub Copilot
- **GitHub Copilot** plan with Coding Agent enabled (for scheduled auto-updates)
- **GitHub CLI** (`gh`) — authenticated, required for reading code from non-default branches
- **Node.js/npx** — for the Azure DevOps MCP server
- **PAC CLI** (optional) — for Dataverse solution export: `dotnet tool install --global Microsoft.PowerApps.CLI.Tool`
- **PACX** (optional) — for Dataverse solution analysis: [neronotte/Greg.Xrm.Command](https://github.com/neronotte/Greg.Xrm.Command)
- **markitdown** (optional) — for converting Office files, PDFs, images to Markdown. Pick **one**:
  - **MCP Server:** `pip install markitdown-mcp` (LLM converts files directly via MCP tool)
  - **VS Code Extension:** install [`MarkItDown`](https://marketplace.visualstudio.com/items?itemName=bioinfo.markitdown-vscode) (right-click → Convert to Markdown)
  - **CLI:** `pip install "markitdown[all]"` (command-line `markitdown file.pdf`)

---

## Tips

- **Obsidian** works as a companion viewer — open it on `wiki/` and use Graph View to see how pages connect.
- **"Sync all"** — ask the LLM to run `full update` to pull DevOps + GitHub + lint in one pass.
- Meeting minutes are the main manual input. Everything else is automated via MCP.
- The wiki is a git repo — you get version history and branching for free.
- Use the Copilot Coding Agent workflow for hands-off weekly updates. Review the PR before merging.

---

## Generating a wiki repo from this document

Share this document with your LLM agent and say:

> *"Generate an llm-wiki repository based on this document. Create all the folders, files, templates, and skill files described here. Use the Power Platform–specific conventions for the wiki/code/ structure."*

The LLM should produce a complete, working `llm-wiki/` folder that you can drop into any Power Platform project repository. The setup prompt (`/llm-wiki-setup`) will handle the rest.

---

## Note

This document is opinionated about Power Platform documentation structure but flexible about implementation details. The exact solution names, Dataverse table prefixes, team structure, and sprint cadence will vary per project. MCP server packages may evolve — check the linked repositories for the latest setup instructions. Share this document with your LLM agent and customize it for your specific project.
