---
name: config
description: "Reconfigure an initialized LLM Wiki: add or remove sources (code repositories, Azure DevOps Boards, Dataverse, F&O metadata, GitHub, SharePoint), change profiles, language, governance, publish target (Azure DevOps Wiki / GitHub Wiki), automation, sprint settings; refresh the managed engine after a plugin update (--refresh-engine); migrate a v2 wiki to the v3 conventions (--migrate). Never changes wiki content except during --migrate."
argument-hint: "[--refresh-engine] [--migrate]"
user-invocable: true
---

# Configure LLM Wiki

`<plugin>` is the plugin root: two folders above this `SKILL.md`. Use `init` instead when `llm-wiki/wiki.config.yml` does not exist.

## Ownership

| Scope | Permission |
| --- | --- |
| `llm-wiki/wiki.config.yml` | WRITE - merge, keep user keys |
| `llm-wiki/AGENTS.md`, `llm-wiki/.engine/` | WRITE via `Install-Engine.ps1` |
| `.vscode/mcp.json`, `.github/copilot-instructions.md`, `.github/workflows/copilot-setup-steps.yml`, `.gitignore` | WRITE - only the LLM Wiki entries |
| `llm-wiki/wiki/` | NO ACCESS, except `--migrate` (after confirmation) and `log.md` (append) |
| `llm-wiki/raw/` | NO ACCESS |

## Modes

### Default - change settings

1. Read `llm-wiki/wiki.config.yml`, `.vscode/mcp.json`, `llm-wiki/.engine/VERSION` and `<plugin>/plugin.json`. Show a compact summary (enabled sources, profiles, publish target, automation, engine version vs plugin version).
2. Ask what to change (multi-select): sources, profiles / language, governance, publishing, automation, sprints, project conventions, view only.
3. For each choice reuse the questions of `init` (wizard steps 2-7), pre-filled with current values. Removing a source sets `enabled: false` (or removes the repo entry) and leaves existing wiki pages untouched.
4. Show a diff-style summary and ask for confirmation, then write only the affected files. Validate: YAML/JSON parse, MCP entries present for enabled sources.
5. Append a `config` entry to `wiki/log.md` (operations, sources enabled/disabled, files updated).

### `--refresh-engine`

Run after a plugin update, or when the agent reports that `llm-wiki/.engine/VERSION` differs from the plugin version:

```powershell
pwsh -NoProfile -File "<plugin>/scripts/Install-Engine.ps1" -LlmWikiPath llm-wiki
```

Show the old and new version, then suggest `update --lint` because lint rules may have changed. Log `config --refresh-engine`.

### `--migrate` (v2 -> v3 conventions)

For wikis created with plugin 2.x. Run `Test-WikiLint.ps1` first and show the counts, then, after explicit confirmation, convert page by page:

1. `[[path/page]]` and `[[Page|Alias]]` -> relative Markdown links `[Title](relative/path.md)`.
2. `status: active|completed|blocked` -> move the value to `state:` and set `status: draft`; add `updated:` from `date:` when missing.
3. Old config keys -> v3 (`github.repos` stays for activity; add a `code.repos` entry per repository whose code is documented; `publish.repo` -> `publish.target`).
4. Record existing sources as processed: `Get-RawDelta.ps1 -RawPath llm-wiki/raw -Baseline`.
5. Re-run the lint until it reports 0 errors; list remaining warnings for the user.

Log `config --migrate` with the number of pages converted.

## Notes

- Never write secrets into files. Azure DevOps uses Entra ID sign-in (MCP) and Git Credential Manager; CI uses repository secrets.
- Turning `publish.headless` on lets scheduled runs push to a shared wiki: ask for explicit confirmation.
