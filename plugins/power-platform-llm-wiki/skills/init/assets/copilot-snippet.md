## LLM Wiki

This project has an **LLM Wiki** in `llm-wiki/`: a code-first knowledge base maintained by the **LLM Wiki** agent (plugin `power-platform-llm-wiki` for GitHub Copilot in VS Code or Copilot CLI, and Claude Code, where the skills are `/power-platform-llm-wiki:<skill>`).

- Operating manual: `llm-wiki/AGENTS.md`. Configuration: `llm-wiki/wiki.config.yml`. Catalog: `llm-wiki/wiki/index.md`.
- Procedures (also used by headless runs): `llm-wiki/.engine/skills/<update|ingest|query>/SKILL.md`. Scripts: `llm-wiki/.engine/scripts/` (PowerShell 7).
- Answer project questions from `llm-wiki/wiki/` pages and cite them; say "Not documented yet" otherwise.
- Never edit `llm-wiki/.engine/`, `llm-wiki/AGENTS.md`, sources in `llm-wiki/raw/`, or past entries of `llm-wiki/wiki/log.md`.
- Wiki pages: YAML front matter, relative Markdown links (no `[[...]]`), status `draft` unless a person certifies the page.
