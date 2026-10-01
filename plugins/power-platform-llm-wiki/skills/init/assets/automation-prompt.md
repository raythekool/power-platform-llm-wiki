Run the LLM Wiki scheduled update for this repository in headless mode.

1. Read `llm-wiki/AGENTS.md`, `llm-wiki/wiki.config.yml` and `llm-wiki/wiki/index.md`.
2. Follow `llm-wiki/.engine/skills/update/SKILL.md` with `--full`: sync every enabled source, ingest new or changed files reported by `pwsh llm-wiki/.engine/scripts/Get-RawDelta.ps1 -RawPath llm-wiki/raw`, then run the lint.
3. Keep every new or modified page in `status: draft`; never certify; never edit `llm-wiki/raw/` except sync dumps and conversions; append one entry per phase to `llm-wiki/wiki/log.md`.
4. Publish only if `publish.headless: true` in the configuration.
5. Open a pull request titled `docs(wiki): auto-update [YYYY-MM-DD] - N pages updated` that summarises sources processed, pages created/updated, lint errors/warnings and drift found. If nothing changed, do not open a pull request.
