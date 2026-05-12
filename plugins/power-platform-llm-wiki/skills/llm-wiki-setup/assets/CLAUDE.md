# CLAUDE.md — LLM Wiki

This folder is a portable LLM Wiki for project documentation.
When used inside a project, it lives at `llm-wiki/` — all paths below are relative to this folder.

## Instructions

1. **Read `AGENTS.md`** before performing any wiki operation — it is the operational schema.
2. **Read `wiki.config.yml`** to understand which DevOps project and GitHub repos are tracked.
3. **Read `wiki/index.md`** before answering any question — it is the content catalog.
4. **Never edit `raw/`** — source documents are immutable (except `.md` conversions via markitdown, and dump files written to `raw/devops/`, `raw/github/`, and `raw/dataverse/` during sync operations).
5. **Never edit past entries in `wiki/log.md`** — it is append-only.

## Setup

Open `setup/llm-wiki-setup.prompt.md` from VS Code's prompt picker (or run `/llm-wiki-setup`). The setup agent reads `skills/llm-wiki-setup.md` and integrates the wiki with the host project (copilot instructions, MCP config, workflow, agent prompt). There is no shell installer.

## Agent

Switch to the **LLM Wiki** agent in VS Code's agent picker (file: `.github/agents/llm-wiki.agent.md`). The agent interprets natural-language requests, routes to the appropriate skill, and manages data sources (DevOps, GitHub, Dataverse, raw files).

## Skills

Executable procedures for each wiki operation are in `skills/`:

| Skill           | File                                 | When to use                       |
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

**Read the relevant skill file before executing an operation.**

### Ownership boundaries

- **Sync** skills write to `raw/<source>/` + `wiki/`
- **Ingest** skills read `raw/` only, write `wiki/` only (never modify raw/)
- **Publish** reads `wiki/`, writes to external GitHub Wiki
- **Query/Lint/Sprint** read + write `wiki/` only
- **Full Update** is the orchestrator — it runs markitdown conversions in `raw/` then delegates to other skills

## Key rules

- Use `[[WikiLink]]` syntax for all internal cross-references.
- Every wiki page must have YAML frontmatter.
- Never answer project questions from general knowledge — ground answers in wiki pages.
- Use inline markers: 🎯 Action, 🚫 Blocked, ⚠️ Contradiction, 🕐 Stale.
