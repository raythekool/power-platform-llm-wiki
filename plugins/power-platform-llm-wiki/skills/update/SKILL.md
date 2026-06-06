---
name: update
description: "Unified wiki maintenance operation. Modes (combine via flags): sync from data sources (DevOps, GitHub, Dataverse) dumping to raw/ then processing into wiki/; full update orchestrating all sources + ingest of new raw/ files + sprint snapshot + lint + publish; lint-only health check; publish-only to GitHub Wiki; sprint snapshot for the current/specified sprint. Headless-mode friendly; safe to run in CI."
argument-hint: "[--source devops|github|dataverse|all] [--full] [--lint] [--publish] [--sprint [<id>]]"
user-invocable: true
disable-model-invocation: true
context: fork
---

# Update LLM Wiki

A single skill that consolidates the maintenance operations: data-source sync, full orchestration, lint, publish, and sprint snapshot. The agent invokes the right subset based on arguments and `wiki.config.yml`.

## When to Use

- Refresh the wiki from one or more data sources (DevOps / GitHub / Dataverse)
- Run a full headless update (used by the scheduled GitHub Action)
- Run a wiki health check (lint)
- Publish the wiki to a GitHub Wiki repository
- Generate a sprint snapshot report

## Modes

The skill is **multi-mode** and the agent must combine flags as requested:

| Flag                          | Action                                                                |
| ----------------------------- | --------------------------------------------------------------------- |
| `--source devops`             | Sync Azure DevOps work items (raw/devops/ → wiki/features/, projects/) |
| `--source github`             | Sync GitHub repos + PRs + code analysis (raw/github/ → wiki/projects/, code/) |
| `--source dataverse`          | Export and analyse Dataverse solutions (raw/dataverse/ → wiki/code/)  |
| `--source all`                | Run all enabled sources from `wiki.config.yml`                        |
| `--full`                      | Full update: all sources + ingest new raw/ files + sprint + lint + publish |
| `--lint`                      | Health check only                                                     |
| `--publish`                   | Publish to GitHub Wiki only                                           |
| `--sprint [<id>]`             | Generate sprint snapshot (auto-detect sprint if not provided)         |

If no flags are provided, ask the user which mode to run; default to `--full` in **headless mode** (see Headless section).

## Ownership

| Scope                                          | Permission                                              |
| ---------------------------------------------- | ------------------------------------------------------- |
| `wiki.config.yml`                              | READ only                                               |
| `raw/devops/`, `raw/github/`, `raw/dataverse/` | WRITE — dump MCP/CLI query results (JSON + MD + extracts) |
| `raw/` (other subfolders)                      | WRITE only for markitdown conversions (`.md` alongside originals) — `--full` mode only |
| `wiki/`                                        | WRITE — create/update pages from dumped data            |
| `wiki/lint-*.md`                               | WRITE — lint reports                                    |
| `wiki/index.md`, `wiki/overview.md`            | WRITE — keep up to date                                 |
| `wiki/log.md`                                  | APPEND only                                             |
| External GitHub Wiki                           | WRITE — `--publish` mode only                           |

## Prerequisites (per mode)

| Mode               | Required                                                                  |
| ------------------ | ------------------------------------------------------------------------- |
| `--source devops`  | Azure DevOps MCP server configured (`wit_query_by_wiql`, `wit_get_work_item`) |
| `--source github`  | GitHub MCP + `gh` CLI authenticated (`gh auth status`) for non-default-branch reads |
| `--source dataverse` | `pacx auth ping` succeeds; `pac` CLI installed                          |
| `--full`           | All of the above for enabled sources + `markitdown` (CLI or MCP) for `raw/` conversions |
| `--publish`        | `gh` CLI authenticated; target repo has wiki enabled                      |

## Procedure

### Phase 0 — Bootstrap

1. Read `wiki.config.yml`. Determine which integrations are enabled.
2. Read `wiki/index.md` to know what already exists in the wiki.
3. Parse the requested flags. If `--full` is set, expand it to: `--source all`, `--sprint`, `--lint`, `--publish` (conditional on `wiki.config.yml`).

### Phase 1 — Source sync (when `--source` is set)

Run the matching sub-procedures in this order: **devops → github → dataverse**. Each sub-procedure has two stages: (a) **dump** to `raw/`, (b) **process** into `wiki/`.

#### A) DevOps sync

1. Read `wiki.config.yml` → `devops` section (`area_paths`, `iteration_prefix`, `work_item_types`, `excluded_states`).
2. Query work items via MCP WIQL with the configured filters.
3. Batch-get full work item details for the returned IDs.
4. Write `raw/devops/work-items-YYYY-MM-DD.json` (full API response) and `raw/devops/work-items-YYYY-MM-DD.md` (human-readable tables grouped by type). Same-day re-syncs overwrite the previous file.
5. For each Feature: create or update `wiki/features/<id>-<slug>.md` with frontmatter (`type: feature`, `devops_id`, `project`, `branch`, `sprint`, `status`, `tags`). Sections: TL;DR, User Stories, Tasks (table), Cross-References, Change Log.
6. Map parent-child relationships (Feature → User Story → Task).
7. Update related project pages with the new/changed work items.
8. Detect drift (`> ⚠️ **Drift:**`) and blockers (`> 🚫 **Blocked:**`).
9. Update `wiki/index.md` (Features section).

#### B) GitHub sync

1. Read `wiki.config.yml` → `github` section (`repos`, `branch_patterns`).
2. For each tracked repo, collect via MCP: repo metadata, branches (filtered), open PRs, recent commits, open issues.
3. For non-default-branch source reads, use `gh api`:
    ```powershell
    gh api "repos/{owner}/{repo}/contents/{path}?ref={branch}" -H "Accept: application/vnd.github.v3.raw"
    ```
    The GitHub MCP proxy does NOT support `ref`/`sha` parameters.
4. Write `raw/github/<repo>-YYYY-MM-DD.json` and `raw/github/<repo>-YYYY-MM-DD.md`.
5. For each repo: create or update `wiki/projects/<repo>.md` with frontmatter (`type: project`, `project`, `status`, `tags`). Sections: TL;DR, Repository Info, Branch Strategy, Code Components (with **functional descriptions**, not just file listings), Active Branches (table), Open PRs (table), Recent Activity, Related Features, Change Log.
6. Cross-reference branch names with feature pages (`feature/F-42-auth` → `[[features/F-42-*]]`).
7. Update `wiki/index.md` (Projects section).

**Code analysis sub-mode** (when the user says "analyze code" / "update code wiki"):
1. List all tracked branches via `gh api`.
2. Get full file tree per branch (`git/trees/{branch}?recursive=1`).
3. Download source files (skip binaries: `.snk`, `.png`, `package-lock.json`, etc.) into `raw/github/src/<repo>/`.
4. Read all downloaded files and generate `wiki/code/index.md`, `wiki/code/architecture.md`, and one page per major component (`plugin.md`, `pcf.md`, `web-resources.md`, `batch.md`, etc.).
5. Every `wiki/code/` page must include **at least one Mermaid diagram** (architecture: `graph TD`/`flowchart`/`erDiagram`; plugin/API: `sequenceDiagram`/`classDiagram`; pipelines: `flowchart LR`). Replace ASCII art with Mermaid equivalents.

#### C) Dataverse sync

1. Read `wiki.config.yml` → `dataverse` section (`solutions`, `publisher_prefixes`, `components`).
2. Verify connection: `pacx auth ping`. If it fails, ask the user to configure a profile.
3. Resolve solution list (by `name`, `publisher`, or `pattern`).
4. For each solution, into `raw/dataverse/<solution>-YYYY-MM-DD/`:
    - **Export .zip** via `pac solution export --name <name> --path raw/dataverse/<name>-YYYY-MM-DD.zip --managed false` and extract.
    - **Reverse-engineer** via `pacx script solution --solution <name> --output <dir>/ --includeStateFields`.
    - **ER diagram** via `pacx table print --solution <name>` → embedded Mermaid `classDiagram`.
    - **Plugins** via `pacx plugin list --solution <name>`.
    - **Per-table metadata** via `pacx table exportMetadata --table <logicalname>` (one JSON per table).
5. Write `raw/dataverse/<solution>-YYYY-MM-DD.md` summary.
6. Generate / update `wiki/code/` pages based on `components` flags:
    - `datamodel.md` — ER diagram, tables (columns, relationships, alt keys), global option sets, state/status codes
    - `plugin.md` — class/entity/message/stage/mode/order matrix, sequence diagrams of execution order per entity
    - `forms.md` — forms per entity (main, quick create, quick view, card) — fields, tabs, scripts
    - `views.md` — system + personal views per entity — columns, sort, filter (FetchXML summary)
    - `roles.md` — security role × entity × CRUD privilege matrix
    - `flows.md` — Power Automate flows (trigger, actions, connections, status)
    - `architecture.md` — solution dependency graph (`graph TD`), component inventory
    - `index.md` — code wiki catalog with last-sync date
7. Cross-reference Dataverse entities with `wiki/features/` (`dv:<table>` mentions) and plugins with project pages.

### Phase 2 — Ingest new raw/ files (only when `--full`)

1. Convert non-markdown files in `raw/` via `markitdown` (CLI or MCP). Write `.md` alongside originals. This is the **only** write to `raw/` outside of sync dumps.
2. Scan `wiki/log.md` for already-processed files.
3. For each new `.md` not yet in the log, run the matching ingest flow:
    - `raw/meetings/*` → meeting ingest (see `ingest` skill — meeting branch)
    - `raw/devops/*`, `raw/github/*`, `raw/dataverse/*` → already processed by Phase 1, skip
    - Others → generic ingest (see `ingest` skill)

(In multi-skill orchestration, prefer to delegate to the `ingest` skill rather than duplicating its logic.)

### Phase 3 — Sprint snapshot (when `--sprint` is set, or `--full` and a sprint boundary was crossed)

1. Determine sprint ID. If not provided, infer from the current date and `wiki.config.yml` → `sprints` pattern.
2. Collect from `wiki/`:
    - Active features matching the sprint (`features/*.md` with `status: active` and the sprint ID)
    - Recent meetings in the sprint period
    - Open 🎯 action items across all pages
    - 🚫 blockers across all pages
3. Generate `wiki/delivery/sprint-snapshots/<ID>.md` with frontmatter (`type: delivery`, `sprint`). Sections:
    - Progress Summary (feature table: Feature, Status, Progress, Key Updates)
    - Key Decisions This Sprint
    - Open Action Items (Owner, Action, Due, Source)
    - Blockers & Risks
    - Meetings This Sprint
4. Update `wiki/index.md` (Delivery section).

### Phase 4 — Lint (when `--lint` is set, or always at the end of `--full`)

1. Scan all pages in `wiki/` recursively.
2. Check for:

    | Issue                                | Action                            |
    | ------------------------------------ | --------------------------------- |
    | Dead `[[references]]`                | Auto-fix when target is obvious, otherwise flag |
    | Orphan pages (no backlinks)          | Report                            |
    | Contradictions across pages          | Flag `> ⚠️ **Contradiction:**`     |
    | Stale claims (>30 days, no update)   | Flag `> 🕐 **Stale:**`             |
    | Overdue 🎯 action items              | Report with list                  |
    | Missing concept pages                | Report                            |
    | DevOps drift (wiki ≠ MCP)            | Flag `> ⚠️ **Drift:**`             |
    | Missing YAML frontmatter             | Auto-fix                          |

3. Auto-fix safe issues. Flag unsafe ones for human review.
4. Write `wiki/lint-YYYY-MM-DD.md` with sections per issue type.

### Phase 5 — Publish (when `--publish` is set, or `--full` and `wiki.config.yml` → `publish.enabled: true`)

1. Resolve target repo from CLI arg or `wiki.config.yml` → `publish.repo`. Verify `gh repo view <repo> --json hasWikiEnabled` is `true`.
2. Clone `https://github.com/<owner>/<repo>.wiki.git` to a temp directory.
3. Collect all wiki pages (recursive `.md`, excluding `log.md`, `lint-*.md`, and `publish.exclude` patterns).
4. Build the **page map** — flatten paths to GitHub Wiki names:

    | Local path                            | Wiki page name                |
    | ------------------------------------- | ----------------------------- |
    | `wiki/index.md`                       | `Home.md`                     |
    | `wiki/overview.md`                    | `Overview.md`                 |
    | `wiki/<category>/<slug>.md`           | `<Category>-<Slug>.md`        |

    Rules: PascalCase per segment, hyphens preserved, path `/` → `-`. Example: `wiki/reference/sources/cr-foo.md` → `Reference-Sources-CR-Foo.md`.

5. Build the **link map**: rewrite every `[[original/path]]` to `[[Flat-Page-Name]]`. **Never use the pipe alias syntax** `[[Page|Alias]]` — GitHub Wiki silently breaks it.
6. For each page: strip YAML frontmatter, rewrite links, write to the temp wiki directory with the flat name.
7. Generate `_Sidebar.md`: group by category (Generale, Delivery, Progetti, Feature, Codice, Meeting, Riferimenti). Always include `[[Home]]` and `[[Overview]]` at the top. **No emoji** in `[[link]]` labels — GitHub Wiki breaks emoji links.
8. Generate `_Footer.md` with the wiki generator credit + timestamp + project name.
9. Validate (checklist): every `[[link]]` resolves, no pipe syntax, no emoji in links, `_Sidebar.md` links match actual filenames (case-sensitive), `Home.md` exists.
10. `git add -A` + `git commit -m "docs(wiki): auto-update YYYY-MM-DD — N pages"` + `git push origin master`. Clean up temp directory.

### Phase 6 — Bookkeeping (always)

Append one entry per phase that ran:

```
## [YYYY-MM-DD] update --source devops
- Source: Azure DevOps MCP → `raw/devops/work-items-YYYY-MM-DD.json`
- Work items: N Features, M User Stories, K Tasks
- Pages created: [[list]]
- Pages updated: [[list]]
- Drift detected: <count>

## [YYYY-MM-DD] update --source github
- Source: GitHub MCP + gh api → `raw/github/<repo>-YYYY-MM-DD.json`
- Repos scanned: N, Active branches: M, Open PRs: K
- Source files read via gh api: L
- Pages created/updated: [[list]]

## [YYYY-MM-DD] update --source dataverse
- Source: PAC/PACX → `raw/dataverse/<solution>-YYYY-MM-DD/`
- Solutions: N, Tables: M, Plugins: K, Flows: L
- Pages created/updated: [[list]]

## [YYYY-MM-DD] update --sprint <ID>
- Active features: N, Action items: M, Blockers: K
- Page: [[delivery/sprint-snapshots/<ID>]]

## [YYYY-MM-DD] update --lint
- Issues: N flagged, M auto-fixed
- Report: [[lint-YYYY-MM-DD]]

## [YYYY-MM-DD] update --publish
- Target: <owner>/<repo>
- Pages published: N
- Commit: <sha>
```

For `--full`, also append a top-level summary:

```
## [YYYY-MM-DD] update --full | Headless run
- See sub-entries above
```

CI commit message (when `--full` runs in CI): `docs(wiki): auto-update [YYYY-MM-DD] — N pages updated`.

## Headless Mode

When running without a human in the loop (scheduled GitHub Action / Copilot Coding Agent):

- Default to `--full` if no flags are provided.
- Skip interactive prompts; resolve all values from `wiki.config.yml`.
- Auto-convert non-markdown files in `raw/` via `markitdown`.
- Always run `--lint` at the end.
- Always commit with the standard auto-update message.

## Notes

- **Same-day re-syncs are idempotent**: dump files overwrite the previous same-day file.
- **Source-of-truth precedence**: `raw/` dumps are the source of truth for the sync time; wiki pages reflect the dumped data plus prior accumulated knowledge.
- **Drift handling**: when wiki content disagrees with the latest dump, flag with `> ⚠️ **Drift:**` — do not silently overwrite human-curated content.
- **Publish never modifies local files** — it only writes to the external GitHub Wiki repo.
- **Mermaid coverage**: every `wiki/code/` page must include at least one Mermaid diagram.
- **GitHub Wiki link rules**: never use pipe-alias syntax, never use emoji inside `[[link]]` labels.

## Resources

- See `ingest` for processing manually placed `raw/` sources.
- See `query` for read-only Q&A.
