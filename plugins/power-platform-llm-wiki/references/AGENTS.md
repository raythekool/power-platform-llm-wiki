# LLM Wiki Schema — Project Documentation

This is the operating manual for this wiki. It defines the structure, conventions, and workflows the LLM must follow. Co-evolved with the team over time.

For the design rationale and full pattern description, see `llm-wiki.md` (reference only — this file is the operational schema).

---

## Layers

There are four layers in this repository:

### 1. MCP Servers — Live integrations (automated)

The LLM connects to external systems via MCP (Model Context Protocol) servers for **live, read-only access** to project data.

| MCP Server           | What it provides                                                   | Required?  |
| -------------------- | ------------------------------------------------------------------ | ---------- |
| **Azure DevOps MCP** | Features, User Stories, Tasks, Sprint queries (WIQL), board status | ⬜ Optional |
| **GitHub MCP**       | Repos, branches, PRs, issues, commits, file contents               | ⬜ Optional |
| **SharePoint MCP**   | Documents, specs, analysis docs from SharePoint sites              | ⬜ Optional |
| **MarkItDown MCP**   | Converts Office docs, PDFs, images, audio to Markdown              | ⬜ Optional |

#### GitHub MCP limitation: reading non-default branches

The GitHub MCP proxy (`api.githubcopilot.com/mcp/`) does **not** support the `ref` or `sha` parameters on `get_file_contents`. It can only read files from the **default branch** (`main`).

**Fallback — GitHub REST API via `gh` CLI:**

To read files from any branch (e.g. `develop`, `feature/*`), use the GitHub CLI directly:

```powershell
gh api "repos/{owner}/{repo}/contents/{path}?ref={branch}" -H "Accept: application/vnd.github.v3.raw"
```

Examples:
```powershell
# Read a single file from develop
gh api "repos/ava-client-iceg-raiway/eam-immobiliare/contents/plugin/MyPlugin.cs?ref=develop" -H "Accept: application/vnd.github.v3.raw"

# List directory contents on develop (returns JSON metadata)
gh api "repos/ava-client-iceg-raiway/eam-immobiliare/contents/plugin?ref=develop"

# Read multiple files in a loop
$files = @("path/to/File1.cs", "path/to/File2.cs")
foreach ($f in $files) {
    gh api "repos/{owner}/{repo}/contents/$($f)?ref=develop" -H "Accept: application/vnd.github.v3.raw"
}
```

**Decision matrix — which tool to use:**

| What you need                             | Tool                                       | Notes                     |
| ----------------------------------------- | ------------------------------------------ | ------------------------- |
| Repo metadata, branches, PRs, commits     | GitHub MCP                                 | Full support              |
| File contents from **default branch**     | GitHub MCP `get_file_contents`             | Works                     |
| File contents from **non-default branch** | `gh api` (REST API fallback)               | MCP doesn't support `ref` |
| Directory listing on non-default branch   | `gh api` (without `Accept: raw`)           | Returns JSON array        |
| Commit diffs                              | GitHub MCP `get_commit(include_diff=true)` | Works for any branch      |

### 2. `raw/` — Source documents and MCP dumps

All external data — whether manually added or pulled via MCP — lands here first. The LLM **never modifies** human-curated files (except to write `.md` conversions of Office files alongside the originals). However, the LLM **does write** dump files into `raw/devops/`, `raw/github/`, and `raw/dataverse/` during sync operations.

**Supported formats:** `.md`, `.docx`, `.pptx`, `.xlsx`, `.pdf`, `.txt`, `.html`, `.csv`, `.json`. Non-markdown files are converted via [MarkItDown](https://github.com/microsoft/markitdown) before processing. MarkItDown can be used as:

- **MCP Server:** `pip install markitdown-mcp` → tool `convert_to_markdown(uri)` available to the LLM directly
- **VS Code Extension:** install `bioinfo.markitdown-vscode` → right-click any file → "Convert to Markdown"
- **CLI:** `pip install "markitdown[all]"` → `markitdown file.pdf -o file.md`

```
raw/
├── meetings/       # meeting minutes, standup notes, retrospectives
├── analysis/       # analysis docs (if not on SharePoint)
├── specs/          # specs (if not on SharePoint)
├── adrs/           # Architecture Decision Records
├── assets/         # images, diagrams, attachments
├── devops/         # MCP dumps: Azure DevOps work items (JSON + MD)
├── github/         # MCP dumps: GitHub repos, branches, PRs (JSON + MD)
│   └── src/        # Source file archives (downloaded via gh api)
└── dataverse/      # Dataverse solution exports & analysis (PAC/PACX)
```

**MCP dump naming:** `<source>-YYYY-MM-DD.json` (raw API data) + `<source>-YYYY-MM-DD.md` (human-readable). Same-day syncs overwrite the previous dump (idempotent within a day).

### 3. `wiki/`

The persistent knowledge base, entirely owned and maintained by the LLM.

```
wiki/
├── index.md              # content catalog — always read first
├── overview.md           # high-level project synthesis
├── log.md                # append-only operation log
│
├── delivery/             # ADF delivery tracking
│   ├── backlog-overview.md   # backlog hierarchy (Feature → US → Task)
│   ├── environments.md       # DEV / SIT / UAT / PROD status
│   ├── sprint-snapshots/     # one snapshot per sprint
│   └── release-notes/        # one page per release / go-live
│
├── projects/             # one page per GitHub repo
├── features/             # one page per DevOps Feature or epic
│
├── code/                 # functional source code analysis
│   ├── index.md              # code wiki index with repo layout
│   ├── architecture.md       # tech stack, data flow, entity matrix
│   ├── datamodel.md          # Dataverse tables, columns, relationships (ER diagram)
│   ├── plugin.md             # Dataverse plugins & Custom APIs (C#)
│   ├── pcf.md                # PCF control (React/TypeScript)
│   ├── web-resources.md      # JavaScript web resources
│   ├── forms.md              # Dataverse forms (main, quick create, quick view)
│   ├── views.md              # Dataverse views (system, personal)
│   ├── roles.md              # Security roles & privilege matrix
│   ├── flows.md              # Power Automate flows
│   ├── batch.md              # Console apps & batch jobs (.NET 8)
│   ├── stampa-dinamica.md    # Dynamic printing templates & pipeline
│   └── infrastructure.md    # Solutions, datamodel, build/deploy
│
├── meetings/             # synthesized meeting pages (not 1:1 copies)
│
└── reference/            # cross-cutting knowledge base
    ├── decisions/            # ADRs and key decisions
    ├── concepts/             # cross-cutting technical concepts
    ├── entities/             # people, teams, systems, external services
    ├── sources/              # one summary page per ingested source
    └── queries/              # saved answers to questions
```

### 4. `AGENTS.md` (this file)

The LLM's operating manual. Think of it as the schema for the wiki.

### 5. `wiki.config.yml`

Central configuration: which DevOps project, GitHub repos, SharePoint sites, automation schedule, and publish targets to track. **Read this before any sync operation.**

### 6. `skills/`

Executable procedures (one per operation). Agents should read the relevant skill file before executing an operation. See `skills/*.md`.

### 7. External authoring reference

When creating or modifying skills, agents, prompts, setup assets, or other agent-related artifacts, always consult `https://github.com/agentskills/agentskills/` as the default external reference.

Use this repository's files as the source of truth when they define repo-specific behavior, naming, ownership, sync rules, or path conventions that differ from the external reference.

---

## Page Format

Every wiki page must include **YAML frontmatter** and follow this structure:

```yaml
---
type: project | feature | meeting | decision | concept | entity | source | query | delivery
project: repo-name              # which repo/project (if applicable)
devops_id: "US-1234"            # Azure DevOps work item ID (if applicable)
branch: feature/auth-module     # Git branch (if applicable)
sprint: "2026-S08"              # Sprint identifier (if applicable)
participants: [Marco, Alice]    # For meeting pages
date: 2026-04-28
status: active | completed | superseded | blocked
tags: [authentication, api]
---
```

```markdown
# Page Title

> One-paragraph TL;DR.

## Section 1

...

## Cross-References

- Related: [[features/F-42-user-authentication]], [[projects/repo-backend]]
- DevOps: `US-1234`, `T-567`
- Branch: `repo-backend#feature/auth-module`

## Source References

- `raw/meetings/2026-04-28-sprint-review.md`
- Via Azure DevOps MCP: `US-1234`
```

### Inline markers

```
> ⚠️ **Contradiction:** [[Page A]] says X, but [[Page B]] says Y. Unresolved.
> 🕐 **Stale:** This claim may be outdated. Last verified: YYYY-MM-DD.
> 🎯 **Action:** @Marco — Finalize API contract by 2026-05-02. Source: [[meetings/2026-04-28-sprint-review]].
> 🚫 **Blocked:** Waiting on [[features/F-55-auth-provider]] before this can proceed.
```

### Mermaid Diagrams

Use Mermaid fenced code blocks (` ```mermaid `) to describe architectures and processes visually. Include diagrams whenever they add clarity — especially in `wiki/code/` pages.

**Required diagram types by context:**

| Context                 | Diagram Types                                               |
| ----------------------- | ----------------------------------------------------------- |
| Architecture / overview | `graph TD` (component diagram), `C4Context` / `C4Container` |
| Data flow / pipelines   | `flowchart LR` or `sequenceDiagram`                         |
| Plugin / API logic      | `sequenceDiagram` (call flow), `flowchart` (algorithm)      |
| Entity relationships    | `erDiagram`                                                 |
| Build / deploy          | `flowchart LR` (pipeline steps)                             |
| State / lifecycle       | `stateDiagram-v2`                                           |
| Class structure         | `classDiagram`                                              |

**Rules:**
- Every `wiki/code/` page must include at least one Mermaid diagram.
- Replace ASCII art diagrams with Mermaid equivalents where feasible.
- Keep diagrams focused — split complex systems into multiple diagrams.
- Use descriptive node IDs (e.g., `PCF[AssetPcf Control]` not `A[Control]`).

### Emoji

Use emoji in page titles (`# 🏗️ Architecture`) and section headers (`## 🔄 Data Flow`) to improve readability. **Do NOT use emoji inside `[[wiki links]]`** — on GitHub Wiki, emoji in link display text break navigation. The `_Sidebar.md` index must use plain text labels.

| Where                      | Emoji allowed? | Example                             |
| -------------------------- | -------------- | ----------------------------------- |
| Page title (`#`)           | ✅ Yes          | `# 🏗️ Architettura`                  |
| Section headers (`##/###`) | ✅ Yes          | `## 🔄 Flusso Dati`                  |
| Inline markers             | ✅ Yes          | `> ⚠️ **Contradiction:** ...`        |
| Body text                  | ✅ Yes          | Descriptive paragraphs, table cells |
| `_Sidebar.md` links        | 🚫 No           | `[[Codice-Architettura]]`           |
| `[[wiki link]]` labels     | 🚫 No           | `[[Page-Name]]`                     |

### GitHub Wiki `[[link]]` syntax

GitHub Wiki `[[wiki links]]` do **NOT** support the pipe alias syntax `[[PageName|Display Text]]`. The pipe syntax silently breaks: the link points to a page named after the display text instead of the actual page name.

**Rules:**
- Always use `[[Page-Name]]` — never `[[Page-Name|Alias]]`.
- The display text shown in the sidebar/page will be the page name with hyphens replaced by spaces automatically by GitHub.
- If you need a shorter display label, use standard Markdown links instead: `[Display Text](Page-Name)`.

---

## Operations

### Ingest (from `raw/`)

When asked to ingest a new source from `raw/`:

1. **Check file format.** If the file is not `.md` or `.txt`, convert it first.
   If the MarkItDown MCP server is available, use its `convert_to_markdown` tool directly.
   Otherwise, use the CLI:
   ```bash
   markitdown raw/path/to/file.docx -o raw/path/to/file.md
   ```
   Keep the original file. The `.md` conversion sits alongside it.
2. Read the source content (the `.md` version).
3. **Identify the source type** (meeting, analysis, spec, ADR, etc.).
4. **Discuss** key takeaways with the user (skip in headless mode).
5. Write a summary page at `wiki/reference/sources/<slug>.md`.
6. Scan `wiki/index.md` for related pages.
7. Update each related page: add new info, flag contradictions, update cross-references.
8. If the source introduces new projects, features, concepts, or entities — create their pages.
9. Update `wiki/index.md` with all new entries.
10. Update `wiki/overview.md` if the source changes the big picture.
11. Append an entry to `wiki/log.md`.

### Ingest Meeting (from `raw/meetings/`)

1. **Check file format** — convert to markdown via `markitdown` if needed.
2. Read the meeting document.
3. Extract structured data:
   - **Participants** — who was present
   - **Decisions** — what was decided
   - **Action items** — who does what by when (flag with 🎯)
   - **Discussion points** — key topics
   - **Blockers** — what is blocked and why
4. Create a meeting synthesis page at `wiki/meetings/<date>-<slug>.md`.
5. Update related pages (project, feature, entity, decision pages).
6. Flag any contradictions with existing wiki content.
7. Update `wiki/index.md` and append to `wiki/log.md`.

### Sync DevOps (via MCP 🔌 → raw/ → wiki/)

Query Azure DevOps via MCP, **dump raw data to `raw/devops/`**, then process into wiki.

1. Use MCP tools: `wit_query_by_wiql`, `wit_get_work_item`, `wit_list_work_items`.
2. **Dump to raw/** — save the full API response:
   - `raw/devops/work-items-YYYY-MM-DD.json` — structured JSON (all work items with fields, relations)
   - `raw/devops/work-items-YYYY-MM-DD.md` — human-readable Markdown table/list of the same data
3. **Process from raw/** — read the dumped files and for each Feature/User Story/Task:
   - Create or update a page in `wiki/features/<id>-<slug>.md`
   - Set frontmatter with `devops_id`, `status`, linked `project` and `branch`
   - Map parent-child relationships (Feature → User Stories → Tasks)
   - Cross-reference with existing wiki pages
4. Update project pages with new/changed work items.
5. Track dependencies — flag blockers with 🚫.
6. Detect **drift** — flag if wiki pages don't match live DevOps state.
7. Update `wiki/index.md` and append to `wiki/log.md` (referencing the raw dump file as source).

### Sync GitHub (via MCP 🔌 + `gh` CLI → raw/ → wiki/)

Query GitHub via MCP for metadata, **use `gh api` for source code on non-default branches**, dump raw data to `raw/github/`, then process into wiki.

1. Use MCP tools to list repos, branches, PRs, issues, commits.
2. **Read source code from non-default branches** via `gh api` REST fallback:
   ```powershell
   gh api "repos/{owner}/{repo}/contents/{path}?ref={branch}" -H "Accept: application/vnd.github.v3.raw"
   ```
   Use this to read actual source files (plugins, components, configs) for functional analysis.
3. **Dump to raw/** — save the full API response per repo:
   - `raw/github/<repo>-YYYY-MM-DD.json` — structured JSON (repo info, branches, PRs, commits, code structure)
   - `raw/github/<repo>-YYYY-MM-DD.md` — human-readable Markdown summary of the same data
4. **Process from raw/** — read the dumped files and for each tracked repo:
   - Create or update `wiki/projects/<repo>.md`
   - Track active branches, link to DevOps work items
   - Note recent PR activity and merges
   - **Describe what the code does** — functional descriptions of components, not just file listings
5. Cross-reference branch names with feature pages.
6. Update `wiki/index.md` and append to `wiki/log.md` (referencing the raw dump file as source).

### Sync Dataverse (via PAC/PACX → raw/ → wiki/code/)

Export Dataverse solutions and analyze their metadata, **dump to `raw/dataverse/`**, then process into wiki.

1. Read `wiki.config.yml` → `dataverse` section for solutions, prefixes, component flags.
2. Verify connection: `pacx auth ping`.
3. For each solution:
   - Export via `pac solution export --name <name> --path raw/dataverse/<name>-YYYY-MM-DD.zip --managed false`
   - Reverse-engineer via `pacx script solution --solution <name> --output raw/dataverse/<name>-YYYY-MM-DD/`
   - Generate ER diagram via `pacx table print --solution <name>`
   - List plugins via `pacx plugin list --solution <name>`
   - Export per-table metadata via `pacx table exportMetadata --table <name>`
4. Save human-readable summary to `raw/dataverse/<name>-YYYY-MM-DD.md`.
5. Process into `wiki/code/` pages: `datamodel.md`, `plugin.md`, `forms.md`, `views.md`, `roles.md`, `flows.md`, `architecture.md`, `index.md`.
6. Cross-reference with existing feature and project pages.
7. Update `wiki/index.md` and append to `wiki/log.md`.

> **Note:** `pac` is used only for solution export (.zip). All analysis commands use `pacx`. Solution .zip files are gitignored.

### Sync SharePoint (via MCP 🔌 — optional)

If configured, pull documents directly from SharePoint.

1. Search for new or updated documents via MCP.
2. For each document: download/read content, run standard Ingest workflow.
3. Track ingested documents via `wiki/log.md` to avoid re-processing.

**Fallback:** If no SharePoint MCP, paste documents into `raw/analysis/` or `raw/specs/`.

### Query

1. Read `wiki/index.md` first — always.
2. Identify relevant pages from the index.
3. Load those pages.
4. Synthesize an answer with `[[wiki-link]]` citations.
5. Ask the user: "Should I file this answer as a wiki page?"
6. If yes: create `wiki/reference/queries/<slug>.md`, update `wiki/index.md`, append to `wiki/log.md`.

Never answer from general knowledge alone. If the answer is not in the wiki, say: "Not documented yet." Then offer to ingest relevant sources.

### Lint

Periodically health-check the wiki. Check for:

- **Contradictions** — same claim, different values across pages
- **Stale claims** — flag with `> 🕐 Stale:`
- **Orphan pages** — no incoming `[[backlinks]]`
- **Dead references** — `[[links]]` to non-existent pages
- **Missing pages** — concepts mentioned but lacking their own page
- **Missing cross-references** — related pages that should link to each other
- **DevOps drift** — wiki pages that don't match latest MCP data
- **Stale action items** — 🎯 items past due date
- **Data gaps** — topics with known unknowns

Produce `wiki/lint-YYYY-MM-DD.md`. Fix safe issues automatically. Flag contradictions for human review. Append to `wiki/log.md`.

### Sprint Snapshot

1. Collect active features matching current sprint.
2. Collect recent meetings from the sprint period.
3. Collect open action items (🎯) and blockers (🚫).
4. Generate `wiki/delivery/sprint-snapshots/YYYY-SNN.md`.
5. Update `wiki/index.md` and append to `wiki/log.md`.

---

## Special Files

### `wiki/index.md`

**Always read this first.** One entry per wiki page, grouped by category:

**Delivery**, **Projects**, **Features**, **Code**, **Meetings**, **Reference** (Decisions, Concepts, Entities, Sources, Queries)

Format: `- [[Page Name]] — one-line summary`

### `wiki/log.md`

Append-only chronological record. Never edit past entries.

```
## [YYYY-MM-DD] ingest-meeting | Sprint Review
- Participants: Marco, Alice
- Pages created: [[meetings/2026-04-28-sprint-review]]

## [YYYY-MM-DD] sync-devops | Full sync
- Source: Azure DevOps MCP → `raw/devops/work-items-YYYY-MM-DD.json`
- Work items processed: 3 Features, 12 User Stories

## [YYYY-MM-DD] sync-github | Full sync
- Source: GitHub MCP → `raw/github/<repo>-YYYY-MM-DD.json`
- Repos scanned: 3, Active branches: 7
```

### `wiki/overview.md`

High-level synthesis of the project. Update when the big picture changes.

---

## Cross-Reference Conventions

| What             | Pattern                         | Example                                 |
| ---------------- | ------------------------------- | --------------------------------------- |
| Wiki page        | `[[path/page-name]]`            | `[[features/F-42-user-authentication]]` |
| DevOps work item | `` `<type>-<ID>` ``             | `F-42`, `US-128`, `T-567`               |
| Git branch       | `` `<repo>#<branch>` ``         | `repo-backend#feature/auth-module`      |
| Git commit       | `` `<repo>@<sha>` ``            | `repo-backend@a1b2c3d`                  |
| Person/team      | `[[reference/entities/<name>]]` | `[[reference/entities/team-backend]]`   |
| Sprint           | `` `YYYY-SNN` ``                | `2026-S08`                              |

---

## Conventions

- Markdown files throughout in `wiki/`, no exceptions.
- `raw/` accepts **any format** — Office docs, PDFs, etc. Convert via `markitdown` during ingest.
- `[[Wiki Links]]` for all internal cross-references.
- YAML frontmatter on every wiki page.
- Prefer persistent synthesis: write knowledge into the wiki so it never needs to be re-derived.
- The wiki is a **compounding artifact** — it gets more valuable with every ingest.
- The LLM writes and maintains the wiki. The human curates sources and asks questions.
- **Meeting pages are syntheses, not copies.**
- **DevOps pages are living documents.** Note what changed and when.
- **One page per concept.** Cross-link from multiple features.

---

## Headless / Scheduled Mode

When running without a human in the loop (e.g. via **Copilot Coding Agent** triggered by a scheduled GitHub Actions workflow):

- Skip interactive discussion and confirmation steps.
- **Run all syncs automatically** (DevOps, GitHub, Dataverse, SharePoint) — each sync dumps raw data to `raw/devops/`, `raw/github/`, or `raw/dataverse/` first, then processes into wiki.
- **Auto-convert non-markdown files** in `raw/` via `markitdown`.
- Process all new files in `raw/` not yet in `wiki/log.md` (including freshly dumped MCP files).
- Always write all outputs.
- Auto-detect source type from directory path (`raw/devops/` → DevOps sync, `raw/github/` → GitHub sync, `raw/dataverse/` → Dataverse sync, `raw/meetings/` → meeting ingest, etc.).
- Generate sprint snapshot if a sprint boundary is detected.
- Run a lint pass at the end.
- Commit message: `docs(wiki): auto-update [YYYY-MM-DD] — N pages updated`

### GitHub Actions integration

The scheduled workflow (`.github/workflows/wiki.yml`) creates a GitHub issue assigned to `copilot`. The Copilot Coding Agent picks it up, uses `.github/copilot-setup-steps.yml` to prepare the environment (Python, markitdown), then executes the requested operation following the skill files. Results are delivered as a Pull Request.

---

## MCP Server Configuration

A pre-configured template is included at **`.vscode/mcp.json`**. Fill in your credentials:

| Server                      | Env vars to set                                                  | Docs                                                                                              |
| --------------------------- | ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| **Azure DevOps** (optional) | `AZURE_DEVOPS_ORG`, `AZURE_DEVOPS_PROJECT`, `AZURE_DEVOPS_PAT`   | [microsoft/azure-devops-mcp](https://github.com/microsoft/azure-devops-mcp)                       |
| **GitHub** (optional)       | `GITHUB_PERSONAL_ACCESS_TOKEN` (PAT with `repo` scope)           | [github/github-mcp-server](https://github.com/github/github-mcp-server)                           |
| **SharePoint** (optional)   | `TENANT_ID`, `CLIENT_ID`, `CLIENT_SECRET`, `SHAREPOINT_SITE_URL` | [memori-ai/mcp-sharepoint](https://github.com/memori-ai/mcp-sharepoint)                           |
| **MarkItDown** (optional)   | — (no env vars needed)                                           | [microsoft/markitdown](https://github.com/microsoft/markitdown/tree/main/packages/markitdown-mcp) |

### GitHub CLI (`gh`) — required for non-default branch reads

The `gh` CLI must be installed and authenticated (`gh auth login`) to use the REST API fallback for reading files from non-default branches. This is required because the GitHub MCP proxy does not support the `ref` parameter.

```powershell
# Verify gh is available and authenticated
gh auth status
```

For non-VS Code agents (Claude Desktop, etc.), copy the server entries from `.vscode/mcp.json` into your agent's config file.
