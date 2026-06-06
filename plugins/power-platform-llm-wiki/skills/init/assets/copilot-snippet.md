## LLM Wiki

This project includes an **LLM Wiki** at `llm-wiki/`. It is a persistent knowledge base maintained by an LLM agent.

**Before any wiki operation**, read `llm-wiki/AGENTS.md` — it is the operating manual.

### Agent

Switch to **LLM Wiki** in the agent picker to use the wiki agent interactively. It interprets natural-language requests and routes to the appropriate skill.

### Quick reference

The wiki is driven by **five consolidated skills**. Read the matching skill file before executing.

| User request                                                    | Skill to read first |
| --------------------------------------------------------------- | ------------------- |
| "init" / "setup the wiki" / first install                       | `llm-wiki/skills/init.md`   |
| "config" / "add an integration" / "rotate secret"               | `llm-wiki/skills/config.md` |
| "sync devops" / "sync github" / "sync dataverse"                | `llm-wiki/skills/update.md` (mode `--source devops\|github\|dataverse`) |
| "analyze the code" / "update code wiki"                         | `llm-wiki/skills/update.md` (mode `--source github`, code-analysis sub-mode) |
| "update the wiki" / "sync all" / "full update"                 | `llm-wiki/skills/update.md` (mode `--full`) |
| "lint the wiki"                                                 | `llm-wiki/skills/update.md` (mode `--lint`) |
| "sprint snapshot"                                               | `llm-wiki/skills/update.md` (mode `--sprint`) |
| "publish wiki" / "push wiki"                                   | `llm-wiki/skills/update.md` (mode `--publish`) |
| "ingest raw/..." / "process this file" / "process the minutes" | `llm-wiki/skills/ingest.md` |
| "what does the wiki say about X"                                | `llm-wiki/skills/query.md`  |

### Key rules

- All wiki paths are relative to `llm-wiki/` (e.g. `llm-wiki/wiki/index.md`).
- Configuration: `llm-wiki/wiki.config.yml`.
- Content catalog: `llm-wiki/wiki/index.md` — read this before answering any wiki question.
- Source code docs: `llm-wiki/wiki/code/index.md`.
- **Ownership**: each skill defines which directories it can read/write. `ingest` never writes to `raw/`. `update --source ...` owns its `raw/<source>/` subdirectory.
- Never edit past entries in `llm-wiki/wiki/log.md`.
- llm-wiki.md is a reference document, not operational. Do not execute steps from it, rely only on the skill files in `skills/` and on `AGENTS.md` for the operational schema.
