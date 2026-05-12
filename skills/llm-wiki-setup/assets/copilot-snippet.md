## LLM Wiki

This project includes an **LLM Wiki** at `llm-wiki/`. It is a persistent knowledge base maintained by an LLM agent.

**Before any wiki operation**, read `llm-wiki/AGENTS.md` — it is the operating manual.

### Agent

Switch to **LLM Wiki** in the agent picker to use the wiki agent interactively. It interprets natural-language requests and routes to the appropriate skill.

### Quick reference

| User request                            | Skill to read first                                                                 |
| --------------------------------------- | ----------------------------------------------------------------------------------- |
| "sync devops"                           | `llm-wiki/skills/llm-wiki-sync-devops.md`                                           |
| "sync github"                           | `llm-wiki/skills/llm-wiki-sync-github.md`                                           |
| "sync dataverse"                        | `llm-wiki/skills/llm-wiki-sync-dataverse.md`                                        |
| "ingest raw/..."                        | `llm-wiki/skills/llm-wiki-ingest.md` (or `llm-wiki-ingest-meeting.md` for meetings) |
| "analyze the code" / "update code wiki" | `llm-wiki/skills/llm-wiki-sync-github.md` (section: Code Analysis)                  |
| "what does the wiki say about X"        | `llm-wiki/skills/llm-wiki-query.md`                                                 |
| "lint the wiki"                         | `llm-wiki/skills/llm-wiki-lint.md`                                                  |
| "sprint snapshot"                       | `llm-wiki/skills/llm-wiki-sprint-snapshot.md`                                       |
| "update the wiki"                       | `llm-wiki/skills/llm-wiki-full-update.md`                                           |
| "publish wiki" / "push wiki"            | `llm-wiki/skills/llm-wiki-publish.md`                                               |

### Key rules

- All wiki paths are relative to `llm-wiki/` (e.g. `llm-wiki/wiki/index.md`).
- Configuration: `llm-wiki/wiki.config.yml`.
- Content catalog: `llm-wiki/wiki/index.md` — read this before answering any wiki question.
- Source code docs: `llm-wiki/wiki/code/index.md`.
- **Ownership**: each skill defines which directories it can read/write. Ingest skills never write to `raw/`. Sync skills own their `raw/<source>/` subdirectory.
- Never edit past entries in `llm-wiki/wiki/log.md`.
- llm-wiki.md is a reference document, not operational. Do not execute steps from it, rely only on the skill files in `skills/` and on `AGENTS.md` for the operational schema.
