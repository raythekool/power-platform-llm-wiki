---
name: llm-wiki-full-update
description: "This skill should be used when the user asks to 'update the wiki', 'full sync', 'sync all', or during a scheduled CI run. Orchestrates all other skills: pulls MCP data to llm-wiki/raw/, converts Office files, ingests new sources, generates sprint snapshot, publishes, and lints."
---

# Skill: Full Wiki Update

Complete wiki sync: pull MCP data to llm-wiki/raw/, convert files, ingest into llm-wiki/wiki/, publish, lint. Used in scheduled/headless mode.

## Ownership

| Scope             | Permission                                                          |
| ----------------- | ------------------------------------------------------------------- |
| `llm-wiki/raw/`            | WRITE — only for markitdown conversions (`.md` alongside originals) |
| `llm-wiki/wiki/`           | WRITE — via delegated skills                                        |
| `llm-wiki/wiki.config.yml` | READ only                                                           |

This skill is an **orchestrator**. It delegates to other `llm-wiki-*` skills. The only direct `llm-wiki/raw/` write it performs is the markitdown conversion step (step 4).

## Steps (in order)

1. **Sync DevOps** — run skill `llm-wiki-sync-devops` (MCP → `llm-wiki/raw/devops/` → `llm-wiki/wiki/`)
2. **Sync GitHub** — run skill `llm-wiki-sync-github` (MCP + `gh api` → `llm-wiki/raw/github/` → `llm-wiki/wiki/`)
3. **Sync Dataverse** — run skill `llm-wiki-sync-dataverse` (PAC/PACX → `llm-wiki/raw/dataverse/` → `llm-wiki/wiki/code/`)
4. **Convert Office files** in `llm-wiki/raw/` via `markitdown` — write `.md` conversions alongside originals. This is the ONLY step that writes to `llm-wiki/raw/` outside of sync dumps.
5. **Ingest new sources** — check `llm-wiki/wiki/log.md` for already-processed; for each new `.md` file:
   - `llm-wiki/raw/meetings/*` → run skill `llm-wiki-ingest-meeting`
   - `llm-wiki/raw/devops/*`, `llm-wiki/raw/github/*` → already processed by sync steps above (skip)
   - Other → run skill `llm-wiki-ingest`
6. **Sprint Snapshot** — if sprint boundary crossed, run skill `llm-wiki-sprint-snapshot`
7. **Publish** — if `llm-wiki/wiki.config.yml` has `publish.repo`, run skill `llm-wiki-publish`
8. **Lint** — run skill `llm-wiki-lint`

## Bookkeeping

Append to `llm-wiki/wiki/log.md`:
```
## [YYYY-MM-DD] full-sync | Complete wiki update
- DevOps: N features, M stories, K tasks → `llm-wiki/raw/devops/work-items-YYYY-MM-DD.json`
- GitHub: N repos, M branches, K PRs → `llm-wiki/raw/github/<repo>-YYYY-MM-DD.json`
- Dataverse: N solutions, M tables, K plugins → `llm-wiki/raw/dataverse/<solution>-YYYY-MM-DD/`
- Raw: N new files ingested
- Lint: N issues found, M auto-fixed
```

Git commit (CI): `docs(wiki): auto-update [YYYY-MM-DD] — N pages updated`
