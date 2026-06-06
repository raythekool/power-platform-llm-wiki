# LLM Wiki — Project Documentation Edition

> ⚠️ **This is a reference document, not the operational schema.** The LLM should follow `AGENTS.md` for all wiki operations. This file describes the pattern and rationale behind the design.

A pattern for building and maintaining **project knowledge bases** using LLMs.

This document extends the original LLM Wiki idea — a persistent, LLM-maintained wiki built from raw sources — and specializes it for **software project documentation**. It covers multiple GitHub repositories, Azure DevOps work items, meeting minutes, analysis documents, and architectural decisions. The LLM is your documentation team: it reads everything, connects everything, and keeps everything current.

---

## The core idea

Most project documentation is scattered: meeting notes in OneNote, specs in SharePoint, work items in DevOps, code in GitHub, decisions in people's heads. When someone asks "why did we choose this architecture?" or "what was decided in that meeting?", the answer requires digging through three tools and asking two people. Nothing is connected. Nothing accumulates.

The idea here is different. Instead of leaving knowledge fragmented across tools, the LLM **incrementally builds and maintains a persistent wiki** — a structured, interlinked collection of markdown files that synthesizes all your project sources into one coherent knowledge base. When you add a meeting transcript, the LLM doesn't just file it — it extracts decisions and action items, updates the relevant feature pages, links to the DevOps work items discussed, and notes where new information contradicts previous plans. The knowledge is compiled once and then *kept current*.

**The wiki is a persistent, compounding artifact.** The cross-references between a DevOps feature, the meeting where it was discussed, the repo where it's being built, and the analysis doc that motivated it — those links are already there. The contradictions between what was planned and what was decided have already been flagged. Every source you add makes the wiki richer.

You never write the wiki yourself — the LLM writes and maintains all of it. You're in charge of curating sources and asking the right questions. Most data flows in automatically via **MCP server integrations** (Azure DevOps, GitHub, SharePoint). For content that can't be pulled automatically — like meeting minutes — you paste it into `raw/`. The LLM does the summarizing, cross-referencing, filing, and bookkeeping.

---

## Project context

This wiki serves as the central knowledge hub for a multi-repository project ecosystem.

### What it tracks

- **GitHub Repositories** (via MCP 🔌) — multiple repos, each with active branches (feature, release, hotfix). The LLM queries repos directly via the GitHub MCP server to track PRs, branches, commits, and README changes.
- **Azure DevOps** (via MCP 🔌) — the project management layer. The LLM queries Features, User Stories, and Tasks directly via the Azure DevOps MCP server. No manual export needed.
- **SharePoint** (via MCP 🔌, optional) — if analysis docs and specs live on SharePoint, the LLM can pull them via a SharePoint MCP server. Otherwise, paste them into `raw/`.
- **Meeting minutes** (manual 📋) — standup notes, sprint reviews, design sessions, retrospectives. Paste into `raw/meetings/`. The wiki extracts decisions, action items, and key discussion points.
- **Analysis documents** (manual 📋 or SharePoint 🔌) — technical analysis, feasibility studies, design docs, RFCs.
- **Architectural decisions** (manual 📋) — ADRs tracked and cross-referenced.
- **Specs and requirements** (manual 📋 or SharePoint 🔌) — functional and technical specifications.

### How they connect

```
┌──────────────────────────────────────────────────────────────┐
│                    MCP Servers (live)                         │
│                                                              │
│  🔌 Azure DevOps MCP    🔌 GitHub MCP    🔌 SharePoint MCP  │
│  Features, US, Tasks    Repos, PRs,      Docs, Specs        │
│  Sprints, Queries       Branches, Issues (optional)          │
└──────────────┬───────────────┬───────────────┬───────────────┘
               │               │               │                
               ▼               ▼               ▼                
┌──────────────────────────────────────────────────────────────┐
│                         LLM Agent                            │
│                                                              │
│  Reads MCP servers (automated) + raw/ (manual content)       │
│  Writes and maintains wiki/                                  │
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
                                  └─────────────────────┘        
```

---

## Architecture

There are four layers:

### 1. MCP Servers — Live integrations (automated)

The LLM connects to external systems via MCP (Model Context Protocol) servers. These provide **live, read-only access** to project data without manual export.

| MCP Server           | Source                                                                             | What it provides                                                   | Required?  |
| -------------------- | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------ | ---------- |
| **Azure DevOps MCP** | [microsoft/azure-devops-mcp](https://github.com/microsoft/azure-devops-mcp)        | Features, User Stories, Tasks, Sprint queries (WIQL), board status | ⬜ Optional |
| **GitHub MCP**       | [github/github-mcp-server](https://github.com/github/github-mcp-server)            | Repos, branches, PRs, issues, commits, file contents               | ⬜ Optional |
| **SharePoint MCP**   | [memori-ai/mcp-sharepoint](https://github.com/memori-ai/mcp-sharepoint) or similar | Documents, specs, analysis docs from SharePoint sites              | ⬜ Optional |

**Authentication:**
- Azure DevOps: PAT (Personal Access Token) or Azure Identity / `az login`
- GitHub: PAT with `repo` scope
- SharePoint: Azure AD app registration with Graph API permissions

### 2. `raw/` — Manual source documents (fallback)

For content that **cannot be pulled via MCP** — primarily meeting minutes and any documents not on SharePoint. These are **immutable** — the LLM reads from them but never modifies them.

**Supported formats:** Files can be dropped in **any format** — `.md`, `.docx`, `.pptx`, `.xlsx`, `.pdf`, `.txt`, etc. Non-markdown files are automatically converted to markdown via [MarkItDown](https://github.com/microsoft/markitdown) before ingestion (see Operations below).

```
raw/
├── meetings/              # meeting minutes, standup notes, retrospectives
│   ├── 2026-04-28-sprint-review.md
│   ├── 2026-04-25-design-session.docx    ← Office files accepted
│   └── 2026-04-22-standup.pdf
├── analysis/              # analysis docs (if not on SharePoint)
│   ├── auth-module-analysis.md
│   └── api-migration-study.docx
├── specs/                 # specs (if not on SharePoint)
├── adrs/                  # Architecture Decision Records
└── assets/                # images, diagrams, attachments
```

> **Note:** The `raw/devops/` and `raw/repos/` directories from the original pattern are **no longer needed** — that data is now pulled live via MCP servers.

**Naming convention for meetings:** `YYYY-MM-DD-<type>-<topic>.<ext>` where `<type>` is one of: `standup`, `sprint-review`, `sprint-retro`, `design`, `kickoff`, `ad-hoc`. Extension can be `.md`, `.docx`, `.pdf`, etc.

### 3. `wiki/` — The persistent knowledge base

Entirely owned and maintained by the LLM. Organized by knowledge type:

```
wiki/
├── index.md               # content catalog — always read first
├── overview.md            # high-level project synthesis
├── log.md                 # append-only operation log
│
├── delivery/              # ADF delivery tracking
│   ├── backlog-overview.md    # backlog hierarchy (Feature → US → Task)
│   ├── environments.md        # DEV / SIT / UAT / PROD status
│   ├── sprint-snapshots/      # one snapshot per sprint
│   └── release-notes/         # one page per release / go-live
│
├── projects/              # one page per GitHub repo
│   ├── repo-frontend.md
│   └── repo-backend.md
├── features/              # one page per DevOps Feature or epic
│   └── F-42-user-authentication.md
│
├── code/                  # functional source code analysis
│   ├── index.md               # code wiki index with repo layout
│   └── architecture.md        # tech stack, data flow, entity matrix
│
├── meetings/              # synthesized meeting pages (not 1:1 copies)
│   └── 2026-04-28-sprint-review.md
│
└── reference/             # cross-cutting knowledge base
    ├── decisions/             # ADRs and key decisions
    │   └── ADR-001-auth-strategy.md
    ├── concepts/              # cross-cutting technical concepts
    │   └── api-versioning.md
    ├── entities/              # people, teams, systems, external services
    │   ├── team-backend.md
    │   └── service-auth.md
    ├── sources/               # one summary page per ingested source
    └── queries/               # saved answers to questions
```

### 4. Schema file (this document / `AGENTS.md`)

The operating manual that tells the LLM how the wiki is structured and what workflows to follow. Co-evolved with the team over time.

---

## Page format

Every wiki page should include **YAML frontmatter** for structured metadata, followed by the standard content format.

### Frontmatter

```yaml
---
type: project | feature | meeting | decision | concept | entity | source | query | delivery
project: repo-name              # which repo/project this relates to (if applicable)
devops_id: "US-1234"            # Azure DevOps work item ID (if applicable)
branch: feature/auth-module     # Git branch (if applicable)
sprint: "2026-S08"              # Sprint identifier (if applicable)
participants:                    # Meeting participants (for meeting pages)
  - Marco
  - Alice
date: 2026-04-28
status: active | completed | superseded | blocked
tags: [authentication, api, security]
---
```

Not all fields are required on every page — use what applies. The `type` and `date` fields are always required.

### Content structure

```markdown
# Page Title

> One-paragraph TL;DR — the single most important thing to know about this page.

## Section 1

...

## Cross-References

- Related: [[features/F-42-user-authentication]], [[projects/repo-backend]]
- DevOps: `US-1234`, `T-567`
- Branch: `repo-backend#feature/auth-module`

## Source References

- `raw/meetings/2026-04-28-sprint-review.md`
- `raw/devops/features/F-42-user-authentication.md`
```

### Inline markers

Flag contradictions:
```
> ⚠️ **Contradiction:** [[Page A]] says X, but [[Page B]] says Y. Unresolved.
```

Flag stale content:
```
> 🕐 **Stale:** This claim may be outdated. Last verified: YYYY-MM-DD.
```

Flag action items:
```
> 🎯 **Action:** @Marco — Finalize API contract by 2026-05-02. Source: [[meetings/2026-04-28-sprint-review]].
```

Flag blocked items:
```
> 🚫 **Blocked:** Waiting on [[features/F-55-auth-provider]] before this can proceed.
```

---

## Operations

### Ingest (general — from `raw/`)

When asked to ingest a new source from `raw/`:

1. **Check file format.** If the file is not `.md` or `.txt`, convert it to markdown first:
   ```bash
   markitdown raw/path/to/file.docx -o raw/path/to/file.md
   ```
   Supported formats: `.docx`, `.pptx`, `.xlsx`, `.pdf`, `.html`, `.csv`, `.json`, `.xml`, `.zip`, `.epub`.
   Keep the original file in `raw/` (immutable). The `.md` conversion sits alongside it.
2. Read the source content (the `.md` version).
3. **Identify the source type** (meeting, analysis, spec, ADR, etc.).
4. **Discuss** key takeaways with the user (skip in headless/scheduled mode).
5. Write a summary page at `wiki/reference/sources/<slug>.md`.
6. Scan `wiki/index.md` for related pages (projects, features, concepts, entities).
7. Update each related page: add new information, flag contradictions, update cross-references.
8. If the source introduces new projects, features, concepts, or entities — create their pages.
9. Update `wiki/index.md` with all new entries.
10. Update `wiki/overview.md` if the source changes the big picture.
11. Append an entry to `wiki/log.md`.

A single ingest may create or update many pages. That is expected and correct.

### Ingest Meeting (from `raw/meetings/`)

Specialized workflow for meeting minutes:

1. **Check file format** — if the file is `.docx`, `.pdf`, `.pptx`, etc., convert to markdown via `markitdown` first (same as general ingest step 1).
2. Read the meeting document (the `.md` version).
3. Extract structured data:
   - **Participants** — who was present
   - **Decisions** — what was decided (each becomes a potential update to a decision/feature page)
   - **Action items** — who does what by when (flag with 🎯 on relevant pages)
   - **Discussion points** — key topics and positions taken
   - **Blockers** — what is blocked and why
4. Create a meeting synthesis page at `wiki/meetings/<date>-<slug>.md` (not a 1:1 copy — a structured synthesis).
5. Update related pages:
   - **Project pages** — if a repo was discussed, update its page
   - **Feature pages** — if DevOps items were discussed, update their pages
   - **Entity pages** — update participant pages with action items
   - **Decision pages** — if a new decision was made, create or update an ADR page
6. Flag any contradictions with previous meetings or existing wiki content.
7. Update `wiki/index.md` and append to `wiki/log.md`.

### Sync DevOps (via MCP 🔌 — automated)

The LLM queries Azure DevOps **directly via the MCP server** — no manual export needed.

1. Use the Azure DevOps MCP tools to query work items:
   - `wit_query_by_wiql` — run WIQL queries (e.g., all items in current sprint, all active Features)
   - `wit_get_work_item` — get details of a specific work item by ID
   - `wit_list_work_items` — list work items by project/iteration
2. For each Feature/User Story/Task returned:
   - Create or update a page in `wiki/features/<id>-<slug>.md`
   - Set frontmatter with `devops_id`, `status`, linked `project` and `branch`
   - Map parent-child relationships (Feature → User Stories → Tasks)
   - Cross-reference with existing wiki pages (meetings where discussed, analysis docs, related concepts)
3. Update project pages with new/changed work items.
4. Track dependencies between work items — flag blockers with 🚫.
5. Detect **drift** — if wiki feature pages don't match the live DevOps state, flag and update.
6. Update `wiki/index.md` and append to `wiki/log.md`.

**Trigger:** Run on user request ("sync devops"), on schedule (headless mode), or automatically after every meeting ingest (to cross-reference discussed items).

### Sync GitHub (via MCP 🔌 — automated)

The LLM queries GitHub **directly via the MCP server** — no manual tracking needed.

1. Use the GitHub MCP tools to query repositories:
   - List repos and their branches
   - Get open PRs and their status
   - Read recent commits on active branches
   - Check issues and labels
2. For each tracked repo:
   - Create or update a project page at `wiki/projects/<repo>.md`
   - Track active branches and their purpose (feature, hotfix, release)
   - Link branches to corresponding DevOps work items
   - Note recent PR activity and merges
3. Cross-reference branch names with feature pages (e.g., `feature/auth-module` → `F-42`).
4. Update `wiki/index.md` and append to `wiki/log.md`.

**Trigger:** Run on user request ("sync github"), on schedule, or when the user mentions a branch/PR.

### Sync SharePoint (via MCP 🔌 — optional, automated)

If a SharePoint MCP server is configured, the LLM can pull documents directly.

1. Use the SharePoint MCP tools to search for new or updated documents.
2. For each document found:
   - Download/read the content
   - Run the standard **Ingest (general)** workflow
3. Track which SharePoint documents have already been ingested (via `wiki/log.md`) to avoid re-processing.

**Fallback:** If no SharePoint MCP is configured, the user pastes documents into `raw/analysis/` or `raw/specs/` and the LLM ingests them from there.

### Query

When asked a question:

1. Read `wiki/index.md` first — always.
2. Identify the relevant wiki pages from the index.
3. Load those pages.
4. Synthesize an answer with `[[wiki-link]]` citations.
5. Ask the user (interactive mode): "Should I file this answer as a wiki page?"
6. If yes: create `wiki/reference/queries/<slug>.md`, update `wiki/index.md`, append to `wiki/log.md`.

Never answer from general knowledge alone. If the answer is not in the wiki, say clearly: "Not documented yet." Then offer to ingest relevant sources.

### Lint

Periodically health-check the wiki. Check for:

- **Contradictions** — same claim, different values across pages
- **Stale claims** — content that may be outdated (flag with `> 🕐 Stale:`)
- **Orphan pages** — pages with no incoming `[[backlinks]]`
- **Dead references** — `[[links]]` pointing to non-existent pages
- **Missing pages** — concepts or entities mentioned inline but lacking their own page
- **Missing cross-references** — related pages that should link to each other but don't
- **DevOps drift** — wiki feature pages that don't match the latest DevOps export
- **Stale action items** — 🎯 items past their due date
- **Unlinked branches** — branches mentioned but not linked to a feature or project page
- **Data gaps** — topics with known unknowns worth researching

Produce a lint report at `wiki/lint-YYYY-MM-DD.md`. Fix safe issues automatically (dead links, missing cross-refs). Flag contradictions and stale claims for human review. Append a lint entry to `wiki/log.md`.

### Sprint Snapshot

When asked to generate a sprint snapshot (or at sprint boundaries in scheduled mode):

1. Collect all feature pages with `status: active` and matching `sprint` in frontmatter.
2. Collect all recent meetings from the sprint period.
3. Collect open action items (🎯) and blockers (🚫).
4. Generate a `wiki/delivery/sprint-snapshots/YYYY-SNN.md` with:
   - Progress summary per feature
   - Key decisions made this sprint
   - Open action items and owners
   - Blockers and risks
   - Cross-references to all relevant pages
5. Update `wiki/index.md` and append to `wiki/log.md`.

---

## Special files

### `wiki/index.md`

The content catalog. **Always read this first** before answering any question.

- One entry per wiki page
- Grouped by category: **Sources**, **Projects**, **Features**, **Meetings**, **Decisions**, **Concepts**, **Entities**, **Queries**
- Each entry: `- [[Page Name]] — one-line summary`
- Always update after every ingest or new page creation

### `wiki/log.md`

Append-only chronological record of all operations. Never edit past entries.

Format:
```
## [YYYY-MM-DD] ingest-meeting | Sprint Review 2026-04-28
- Participants: Marco, Alice, Bob
- Decisions: 2, Action items: 5
- Pages created: [[meetings/2026-04-28-sprint-review]]
- Pages updated: [[features/F-42-user-authentication]], [[projects/repo-backend]]

## [YYYY-MM-DD] sync-devops | Full sync
- Source: Azure DevOps MCP
- Work items processed: 3 Features, 12 User Stories, 28 Tasks
- Pages created: [[features/F-42-user-authentication]], [[features/F-43-payment-gateway]]
- Pages updated: [[projects/repo-backend]]
- Drift detected: F-41 status changed from Active to Closed

## [YYYY-MM-DD] sync-github | Full sync
- Source: GitHub MCP
- Repos scanned: 3
- Active branches: 7, Open PRs: 4
- Pages created: [[projects/repo-infra]]
- Pages updated: [[projects/repo-backend]], [[features/F-42-user-authentication]]

## [YYYY-MM-DD] sync-sharepoint | Analysis docs
- Source: SharePoint MCP
- Documents found: 2 new, 1 updated
- Pages created: [[sources/api-migration-study]]

## [YYYY-MM-DD] query | "What auth strategy did we choose?"
- Answer summary: JWT with refresh tokens, decided in [[meetings/2026-04-25-design-session]]
- Filed as: [[queries/auth-strategy-decision]]

## [YYYY-MM-DD] lint | Lint pass
- Issues found: 2 contradictions, 1 orphan, 3 stale action items
- Actions taken: fixed orphan, flagged contradictions for review

## [YYYY-MM-DD] sprint-snapshot | Sprint 2026-S08
- Filed as: [[queries/sprint-2026-S08-snapshot]]
```

### `wiki/overview.md`

High-level synthesis of the entire project. One page that gives a newcomer the full picture: what are we building, what repos exist, what's the current state, what are the key architectural decisions. Update this when the big picture changes after an ingest.

---

## Cross-reference conventions

Consistent linking is what makes the wiki valuable. Follow these patterns:

| What you're linking | Pattern                 | Example                                 |
| ------------------- | ----------------------- | --------------------------------------- |
| Wiki page           | `[[path/page-name]]`    | `[[features/F-42-user-authentication]]` |
| DevOps work item    | `` `<type>-<ID>` ``     | `F-42`, `US-128`, `T-567`               |
| Git branch          | `` `<repo>#<branch>` `` | `repo-backend#feature/auth-module`      |
| Git commit          | `` `<repo>@<sha>` ``    | `repo-backend@a1b2c3d`                  |
| Person/team         | `[[entities/<name>]]`   | `[[entities/team-backend]]`             |
| Sprint              | `` `YYYY-SNN` ``        | `2026-S08`                              |

Use `[[Wiki Links]]` for all internal cross-references between wiki pages. Use inline code for external identifiers (DevOps IDs, branches, commits, sprints).

---

## Conventions

- Markdown files throughout in `wiki/`, no exceptions.
- `raw/` accepts **any format** — Office docs, PDFs, etc. Non-markdown files are converted via `markitdown` during ingest.
- `[[Wiki Links]]` for all internal cross-references.
- YAML frontmatter on every wiki page for structured metadata.
- Prefer persistent synthesis: write knowledge into the wiki so it never needs to be re-derived from raw sources again.
- The wiki is a **compounding artifact** — it gets more valuable with every ingest.
- The LLM writes and maintains the wiki. The human curates sources and asks questions.
- No mandatory RAG infrastructure. The index is sufficient at small scale. CLI search tooling is optional and additive, not foundational.
- **Meeting pages are syntheses, not copies.** Don't replicate the raw meeting notes — extract, structure, and cross-reference.
- **DevOps pages are living documents.** They evolve as work items change status. Always note what changed and when.
- **One page per concept.** If a concept appears across multiple features, give it its own page in `wiki/reference/concepts/` and link to it.

---

## Headless / scheduled mode

When running in GitHub Actions or scheduled automation (no human in the loop):

- Skip interactive discussion and confirmation steps.
- **Run all MCP syncs automatically:**
  1. Sync DevOps — pull all work items and update feature pages
  2. Sync GitHub — pull repo/branch/PR status and update project pages
  3. Sync SharePoint (if configured) — pull new/updated documents
- **Auto-convert non-markdown files** in `raw/` via `markitdown` before processing.
- Process all new files in `raw/` that are not yet recorded in `wiki/log.md`.
- Always write all outputs.
- If a contradiction cannot be auto-resolved, flag it in the page but do not block the run.
- Auto-detect source type from directory path (`raw/meetings/` → Ingest Meeting, etc.).
- Generate sprint snapshot if a sprint boundary is detected.
- Run a lint pass at the end.
- Commit message: `docs(wiki): auto-update [YYYY-MM-DD] — N pages updated`

---

## MCP server configuration

The LLM agent needs access to the following MCP servers. Configure them in `.mcp.json` at the workspace root.

### Azure DevOps MCP (optional)

```json
{
  "azure-devops": {
    "command": "npx",
    "args": ["-y", "@azure-devops/mcp"],
    "env": {
      "AZURE_DEVOPS_ORG": "https://dev.azure.com/YOUR_ORG",
      "AZURE_DEVOPS_PROJECT": "YOUR_PROJECT",
      "AZURE_DEVOPS_PAT": "your-personal-access-token"
    }
  }
}
```

> Refer to [microsoft/azure-devops-mcp](https://github.com/microsoft/azure-devops-mcp) for the latest setup instructions. The Remote MCP Server (Public Preview) is recommended for new setups.

### GitHub MCP (optional)

```json
{
  "github": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-github"],
    "env": {
      "GITHUB_PERSONAL_ACCESS_TOKEN": "your-github-pat"
    }
  }
}
```

> Refer to [github/github-mcp-server](https://github.com/github/github-mcp-server) for the latest setup. Use a PAT with `repo` scope (read-only is sufficient for wiki purposes).

### SharePoint MCP (optional)

```json
{
  "sharepoint": {
    "command": "npx",
    "args": ["-y", "mcp-sharepoint"],
    "env": {
      "TENANT_ID": "your-azure-tenant-id",
      "CLIENT_ID": "your-app-client-id",
      "CLIENT_SECRET": "your-app-client-secret",
      "SHAREPOINT_SITE_URL": "https://yourorg.sharepoint.com/sites/YourSite"
    }
  }
}
```

> Requires an Azure AD app registration with Microsoft Graph permissions (`Sites.Read.All`, `Files.Read.All`). Refer to [memori-ai/mcp-sharepoint](https://github.com/memori-ai/mcp-sharepoint) for setup.

---

## Tips and tricks

- **"Sync all"** — ask the LLM to "sync devops and github" to pull all live data in one pass. In headless mode, this happens automatically.
- **Meeting minutes** are the only routine manual input. Paste them into `raw/meetings/` and tell the LLM to ingest. Everything else is automated.
- The wiki is a git repo. You get version history, branching, and collaboration for free. Consider using a `wiki-update` branch for automated updates and merging to `main` after review.

---

## Why this works for project documentation

Project documentation fails because nobody wants to maintain it. Meeting notes pile up unread. DevOps work items diverge from reality. Architecture decisions live in someone's memory. The wiki solves this by making the LLM responsible for all the maintenance work that humans abandon:

- **Cross-referencing** — the LLM connects a meeting decision to the feature it affects, the repo where it's implemented, and the ADR that records it. Humans never do this consistently.
- **Keeping things current** — when a new meeting updates a previous decision, the LLM updates the decision page and flags the change. Humans forget.
- **Contradiction detection** — when a new analysis doc contradicts the original spec, the LLM flags it immediately. Humans notice weeks later (if ever).
- **Onboarding** — a newcomer reads `wiki/overview.md` and has the full picture in minutes, with links to drill into any topic. No "ask Bob, he was in that meeting."

The human's job is to paste meeting minutes and ask good questions. The LLM does everything else — pulling data from DevOps and GitHub via MCP, synthesizing, cross-referencing, and keeping the wiki current.

---

## Note

This document is intentionally opinionated about project documentation structure but flexible about implementation details. The exact repos, DevOps project names, team structure, and sprint cadence will vary. The MCP server packages and configuration may evolve — always check the linked repositories for the latest setup instructions. Share this document with your LLM agent and work together to customize it for your specific project. The document's job is to communicate the pattern. Your LLM can figure out the rest.
