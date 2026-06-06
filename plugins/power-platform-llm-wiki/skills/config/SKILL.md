---
name: config
description: "Reconfigure an existing LLM Wiki: edit wiki.config.yml (data-source filters, sprint settings, publish target, automation schedule), add/remove MCP server entries in .mcp.json, manage secrets in .env. Use after init when integrations, repos, or settings change. Does NOT create or modify wiki content."
argument-hint: "Run in the project root where llm-wiki/ is already initialized"
user-invocable: true
disable-model-invocation: true
context: fork
---

# Configure LLM Wiki

## When to Use

- Change which data sources are connected (add/remove DevOps, GitHub, Dataverse, SharePoint)
- Update tracked repositories, area paths, solutions, or publisher prefixes
- Change sprint duration or pattern
- Enable/disable publishing or change the target wiki repo
- Switch automation schedule (daily/weekly/manual) or disable it
- Rotate or add secrets (PATs, client secrets)

Use **`init`** instead if `wiki.config.yml` does not exist or the wiki scaffolding is missing.

## Ownership

| Scope                     | Permission                                                |
| ------------------------- | --------------------------------------------------------- |
| `wiki.config.yml`         | WRITE — merge new values, preserve user-added fields      |
| Host project `.mcp.json`  | WRITE — add/remove server entries (only those listed)     |
| Host project `.env`       | WRITE — add/update/remove tracked secret keys             |
| `.github/workflows/wiki.yml` | WRITE — update cron / create / remove                  |
| `.github/copilot-setup-steps.yml` | WRITE — update only the PAC CLI step              |
| `.gitignore`              | WRITE — ensure LLM Wiki section is present                |
| `wiki/log.md`             | APPEND only                                               |
| `wiki/` content pages     | NO ACCESS                                                 |
| `raw/`                    | NO ACCESS                                                 |

This skill never modifies wiki content pages and never deletes existing data.

## Prerequisites

- `wiki.config.yml` already exists (run `init` first if not).
- Read the current `wiki.config.yml`, `.mcp.json`, `.env` to pre-populate answers.

## Procedure

### Step 1 — Detect current state

1. Parse `wiki.config.yml`. Determine which integrations are enabled (`devops`, `github`, `dataverse`, `sharepoint`, `publish`, `automation`).
2. Parse `.mcp.json`. List currently configured MCP servers.
3. Parse `.env`. List currently configured secret keys (do not display values).
4. Present a compact summary of the current state to the user.

### Step 2 — Operation selection

> **"Cosa vuoi modificare?"** (multi-select)

| Option                       | What it changes                                           |
| ---------------------------- | --------------------------------------------------------- |
| Add an integration           | Enable a new data source (DevOps / GitHub / Dataverse / SharePoint) |
| Remove an integration        | Disable an existing data source                           |
| Update integration settings  | Change repos, area paths, solutions, prefixes             |
| Sprint settings              | Change duration or pattern                                |
| Publishing                   | Enable/disable, change target repo                        |
| Automation schedule          | Daily / Weekly / Manual                                   |
| Rotate / add secrets         | Update `.env` keys                                        |
| View full config             | Display resolved current settings, then exit              |

### Step 3 — Per-operation wizard

For each selected operation, run the matching mini-wizard. Use the same per-integration question batches as `init` (Step 3). When changing an existing field, pre-populate the prompt with the current value.

#### Add an integration

For each new integration: ask the same questions as `init` Step 3, then:
- Update `wiki.config.yml` (enable the section, set values).
- Merge the MCP server entry in `.mcp.json` (preserve unrelated servers).
- Add the relevant secret keys to `.env` (prompt for values; never log them).
- If automation is enabled, ensure the relevant tools are listed in `.github/copilot-setup-steps.yml`.

#### Remove an integration

> **"Sei sicuro di voler rimuovere `<integration>`? Le pagine wiki esistenti collegate rimarranno, ma non saranno più aggiornate."** (Yes / No)

- Set the integration section in `wiki.config.yml` to `enabled: false` (do not delete user-added fields).
- Remove the matching server entry from `.mcp.json`.
- Ask whether to remove the related secrets from `.env`. Default: keep (in case the user re-enables later).

#### Update integration settings

Present the current values for the chosen integration. Re-ask only the fields the user wants to change. Update `wiki.config.yml` in place; never lose unrelated keys.

#### Sprint settings

| Field           | Current      | New           |
| --------------- | ------------ | ------------- |
| Sprint duration | `<weeks>`    | `<new value>` |
| Sprint pattern  | `<pattern>`  | `<new value>` |

#### Publishing

- Toggle `publish.enabled`. If enabling, collect `repo` (`owner/repo`) and `project_name`.
- Verify `gh repo view <owner/repo> --json hasWikiEnabled` returns `true`.

#### Automation schedule

| Option      | Cron        | Description                  |
| ----------- | ----------- | ---------------------------- |
| Daily       | `0 7 * * *` | Every day at 07:00 UTC       |
| Weekly      | `0 7 * * 1` | Every Monday at 07:00 UTC    |
| Manual only | —           | Remove the workflow          |

- If switching to **Daily/Weekly**: install or patch `.github/workflows/wiki.yml` cron.
- If switching to **Manual only**: do not delete the workflow file; comment out the `schedule:` trigger and leave `workflow_dispatch:` enabled. Ask before deleting the file.

#### Rotate / add secrets

For each selected key:
- Prompt for the new value (input hidden if supported).
- Update `.env` in place. Never echo the value back.
- If the key did not exist in `.env`, add it under the right integration section.

### Step 4 — Final confirmation

Present a diff-like summary of what will change (sections updated, keys added/removed, secrets rotated — values redacted). Ask:

> **"Procedere con le modifiche?"** (Yes / No)

If **No**, abort without writing.

### Step 5 — Apply changes (idempotent)

Write only the files affected by the selected operations. Validate each file after writing:
- `wiki.config.yml` → must be valid YAML
- `.mcp.json` → must be valid JSON
- `.env` → must be parseable as `KEY=VALUE` lines
- `.github/workflows/wiki.yml` → must be valid YAML and contain a valid cron string

If validation fails, restore the previous version and report the error.

### Step 6 — Verification

Conditional checklist of what was actually changed. Include the new resolved values (secrets redacted).

## Bookkeeping

Append to `llm-wiki/wiki/log.md`:

```
## [YYYY-MM-DD] config | <operation summary>
- Operations: <list>
- Integrations enabled: <list>
- Integrations disabled: <list>
- Secrets rotated: <key names only>
- Files updated: <list>
```

## Notes

- Never delete user-added fields in `wiki.config.yml` — always merge.
- Never overwrite unrelated server entries in `.mcp.json`.
- Never log secret values.
- If the user disables an integration, archived wiki pages are kept intact and just become read-only. They can be removed manually if desired.
- Re-run `update` after a `config` change to ensure the wiki reflects the new settings.

## Resources

- See `init` for first-time setup.
