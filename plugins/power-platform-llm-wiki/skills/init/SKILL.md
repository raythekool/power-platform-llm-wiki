---
name: init
description: "Initialize an LLM Wiki in the host project: scaffold wiki/ and raw/ folder structure, copy plugin templates, generate wiki.config.yml, integrate with the host repository (.github/, .mcp.json, .env, .gitignore), and produce the first index. Use when setting up llm-wiki in a new project, after copying the llm-wiki/ folder, or to refresh missing scaffolding. Wizard-based; all data-source integrations are optional."
argument-hint: "Run in the root of a project where you want to host the wiki"
user-invocable: true
disable-model-invocation: true
context: fork
---

# Initialize LLM Wiki

## When to Use

- First-time setup of LLM Wiki in a host project
- After copying the `llm-wiki/` folder into a project
- Onboarding a new contributor (regenerates missing integration files)
- Resetting the wiki scaffold to defaults
- When `wiki.config.yml` is missing or the wiki folder structure is incomplete

## Ownership

| Scope                                | Permission                                               |
| ------------------------------------ | -------------------------------------------------------- |
| Host project `.github/`              | WRITE — copilot-instructions, workflows, prompts, agents |
| Host project root                    | WRITE — `.mcp.json`, `.env`, `.gitignore`                |
| `wiki.config.yml`                    | WRITE — populate from user input                         |
| `wiki/` (skeleton + `index.md`, `overview.md`, `log.md`) | WRITE — create empty scaffolding         |
| `raw/` (skeleton)                    | WRITE — create empty subfolders only                     |
| `wiki/` (content pages)              | NO ACCESS — content is created by `ingest` / `update`    |

This skill creates structure only. It never writes wiki content pages.

## Prerequisites

- Run from the **project root** (the folder that contains, or will contain, `llm-wiki/`).
- Recommended tools (detect, do not auto-install — report missing):
  - `gh` CLI authenticated (`gh auth status`) — required for GitHub sync and `gh api` fallback
  - `npx --version` — required for Azure DevOps MCP server
  - `markitdown` / `markitdown-mcp` (optional, for converting Office/PDF sources)

## Bundled templates

Canonical template files ship with this skill under `${CLAUDE_PLUGIN_ROOT}/skills/init/assets/`. Copy from these (don't regenerate from memory) when writing the host integration files:

| Asset                          | Copied to (host)                              |
| ------------------------------ | --------------------------------------------- |
| `copilot-snippet.md`           | appended to `.github/copilot-instructions.md` |
| `mcp-servers.json`             | merged into `.mcp.json`                        |
| `wiki.yml`                     | `.github/workflows/wiki.yml`                   |
| `copilot-setup-steps.yml`      | `.github/copilot-setup-steps.yml`              |
| `llm-wiki.prompt.md`           | `.github/prompts/llm-wiki.prompt.md`           |
| `llm-wiki-setup.prompt.md`     | `.github/prompts/llm-wiki-setup.prompt.md`     |
| `llm-wiki.agent.md`            | `.github/agents/llm-wiki.agent.md`             |
| `env.sample`                   | basis for `.env`                               |
| `AGENTS.md`                    | `llm-wiki/AGENTS.md`                            |
| `wiki.config.yml`              | basis for `llm-wiki/wiki.config.yml`           |

## Procedure

Run the wizard in numbered steps. Ask only the questions for the current step. Answer options for yes/no questions must be presented as **Yes** first, **No** second.

### Step 1 — Setup mode

> **"Vuoi una configurazione guidata passo-passo, oppure preferisci compilare il file `wiki.config.yml` in autonomia?"**

- **Guided** → continue with Step 2.
- **Self-service** → generate a fully commented `wiki.config.yml`, write minimal `.gitignore` entries, instruct the user to fill in `wiki.config.yml` and re-run this skill (or run `/config`). Stop here.

### Step 2 — Integration selection

> **"Quali fonti dati vuoi collegare alla wiki?"** (multi-select)

| Option        | Enables                                   |
| ------------- | ----------------------------------------- |
| Azure DevOps  | Work items, sprint tracking, backlog sync |
| GitHub        | Repos, PRs, branches, code analysis       |
| Dataverse     | Solution analysis, data model, plugins    |
| SharePoint    | Document libraries, analysis docs         |
| None          | Manual ingest only (from `raw/`)          |

If **None** is selected, skip Step 3 and go to Step 4.

### Step 3 — Per-integration details

Batch the questions per selected integration. Ask only the integrations chosen in Step 2.

**Azure DevOps:** organization (required), project (required), PAT (required, stored in `.env`), optional area path filter, optional iteration prefix.

**GitHub:** repos to track (required, comma-separated `owner/repo`), optional PAT for CI (stored in `.env`). Note: VS Code Copilot already provides a token; a separate PAT is only required for unattended CI runs.

**Dataverse:** solution name(s) (required), publisher prefix(es) (optional, e.g. `ava_`). Note: connection is configured externally via `pacx auth create`.

**SharePoint:** site URL (required), document library paths (required), tenant ID, client ID, client secret (all stored in `.env`).

### Step 4 — Publishing

> **"Vuoi pubblicare la wiki su GitHub Wiki?"**

- **Yes** → collect target repo (`owner/repo`) and project name (for sidebar header).
- **No** → set `publish.enabled: false` in `wiki.config.yml`.

### Step 5 — Automated updates

Only ask if at least one data-source integration was selected.

> **"Vuoi configurare un aggiornamento automatico della wiki?"**

Explain: "Un GitHub Action crea un issue periodico assegnato al Copilot Coding Agent, che esegue il sync e apre una PR con le modifiche."

| Option      | Cron        | Description                  |
| ----------- | ----------- | ---------------------------- |
| Daily       | `0 7 * * *` | Every day at 07:00 UTC (default) |
| Weekly      | `0 7 * * 1` | Every Monday at 07:00 UTC    |
| Manual only | —           | No scheduled workflow        |

### Step 6 — Sprint settings

Only ask if Azure DevOps or GitHub was selected.

| Field           | Default    | Example    |
| --------------- | ---------- | ---------- |
| Sprint duration | 2 weeks    | `3`        |
| Sprint pattern  | `YYYY-SNN` | `YYYY-SNN` |

Accept defaults silently if the user has no preference.

### Step 7 — Final confirmation

Present a compact summary of resolved inputs (with secrets redacted) and ask:

> **"Procedere con la creazione della scaffolding e l'integrazione nel repo?"** (Yes / No)

If **No**, abort without writing anything.

### Step 8 — File generation (idempotent)

Perform each step idempotently — if a target file already contains an `## LLM Wiki` marker section, patch it instead of re-appending. Skip entries that depend on integrations the user did not select.

1. **Create `llm-wiki/` folder skeleton** (only missing folders, never overwrite):

    ```
    llm-wiki/
    ├── raw/
    │   ├── meetings/
    │   ├── analysis/
    │   ├── specs/
    │   ├── adrs/
    │   ├── assets/
    │   ├── devops/        # only if Azure DevOps selected
    │   ├── github/        # only if GitHub selected
    │   └── dataverse/     # only if Dataverse selected
    └── wiki/
        ├── index.md       # seed catalog
        ├── overview.md    # one-paragraph stub
        ├── log.md         # append-only header
        ├── delivery/      # only if DevOps or GitHub selected
        ├── projects/      # only if GitHub selected
        ├── features/      # only if DevOps selected
        ├── code/          # only if Dataverse or GitHub-code-analysis selected
        ├── meetings/
        └── reference/{decisions, concepts, entities, sources, queries}/
    ```

    Empty folders get a `.placeholder` file so Git tracks them.

2. **`.github/copilot-instructions.md`** — append the LLM Wiki section (or patch the existing marker block). Source template: bundled `references/AGENTS.md` summary.

3. **`.mcp.json`** — merge only the selected MCP server entries (azure-devops, github, sharepoint, markitdown). Never overwrite unrelated servers. Substitute placeholders (`YOUR_DEVOPS_ORG`).

4. **`.github/workflows/wiki.yml`** — install only if Step 5 chose Daily or Weekly. Set the cron from the chosen schedule. If destination exists and was customised, write `.github/workflows/wiki.yml.new` and ask the user to merge.

5. **`.github/copilot-setup-steps.yml`** — install only when automation is enabled. Remove PAC CLI installation if Dataverse was not selected.

6. **`.github/prompts/llm-wiki.prompt.md`** — always install/overwrite.

7. **`.github/agents/llm-wiki.agent.md`** — always install/overwrite. Create `.github/agents/` if it does not exist.

8. **`.env`** — only if any integration needs secrets. Add/update only the missing keys (`AZURE_DEVOPS_PAT`, `GITHUB_PERSONAL_ACCESS_TOKEN`, `TENANT_ID`, `CLIENT_ID`, `CLIENT_SECRET`). Never log secret values back to the user.

9. **`.gitignore`** — ensure a `# LLM Wiki` section exists with:
    ```
    .env
    llm-wiki/wiki/lint-*.md
    llm-wiki/raw/dataverse/*.zip
    __pycache__/
    *.pyc
    ```

10. **`wiki.config.yml`** — generate based on user choices. Enable only the sections that match the selected integrations. Preserve any existing user-added fields.

11. **`llm-wiki/wiki/index.md`** — seed with a catalog header and empty category sections (Delivery, Projects, Features, Code, Meetings, Reference). Populate as ingest/sync skills run.

12. **`llm-wiki/wiki/log.md`** — seed with a header. Append the initial `setup` entry (see Bookkeeping below).

### Step 9 — Verification

Report a conditional checklist. Only include items for the chosen integrations:

- [ ] `wiki.config.yml` populated
- [ ] `wiki/index.md`, `wiki/overview.md`, `wiki/log.md` created
- [ ] `raw/` skeleton created
- [ ] `.github/copilot-instructions.md` contains the LLM Wiki section
- [ ] `.github/prompts/llm-wiki.prompt.md` installed
- [ ] `.github/agents/llm-wiki.agent.md` installed
- [ ] `.gitignore` updated
- [ ] `.mcp.json` contains: `<list of selected servers>` (if any integration selected)
- [ ] `.env` populated with secrets (values redacted in report) (if any integration needs secrets)
- [ ] `.github/workflows/wiki.yml` exists with schedule `<daily|weekly>` (if automation enabled)
- [ ] `.github/copilot-setup-steps.yml` exists (if automation enabled)
- [ ] `wiki.config.yml` → `publish.repo = <value>` (if publish enabled)

### Step 10 — Next steps message

Tailor the message to the chosen integrations:

> Setup complete. Switch to the **LLM Wiki** agent to start using the wiki.

Append the relevant suggestions:

- **DevOps enabled:** "Run `update --source devops` to import work items."
- **GitHub enabled:** "Run `update --source github` to analyse the repositories."
- **Dataverse enabled:** "Run `update --source dataverse` (ensure `pacx auth ping` works)."
- **No integration:** "Drop files in `llm-wiki/raw/...` then run `ingest`."
- **Automation enabled:** "The GitHub Action will create a `<daily|weekly>` issue assigned to Copilot, which opens a PR. Manual trigger: `gh workflow run wiki.yml`."
- **Publish enabled:** "When the wiki has content, run `update --publish`."
- Always: "You can run `/config` later to reconfigure, `/ingest` to add sources, `/query` to ask, and `update --lint`."

## Bookkeeping

Append to `llm-wiki/wiki/log.md`:

```
## [YYYY-MM-DD] init | Integration
- Integrations: <DevOps|GitHub|Dataverse|SharePoint|none>
- DevOps: <org/project or "not configured">
- GitHub repos: <list or "not configured">
- Automation: <daily|weekly|manual>
- Publish: <repo or "not configured">
- Files created/updated: <list>
```

## Notes

- Idempotent — existing files are patched, never blindly overwritten.
- All integrations are optional. Manual-ingest-only mode is fully supported.
- This skill creates **structure**. Use `config` to change settings later, `ingest` to add sources, `update` to refresh from data sources.
- The wizard order matters — never ask credentials for integrations the user did not opt into.

## Resources

- Bundled templates: `${CLAUDE_PLUGIN_ROOT}/skills/init/assets/`
- Reference docs: `${CLAUDE_PLUGIN_ROOT}/references/AGENTS.md`
