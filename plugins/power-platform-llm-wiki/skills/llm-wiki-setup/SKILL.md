---
name: llm-wiki-setup
description: "This skill should be used when the user asks to 'setup llm-wiki', 'install llm-wiki', 'configure the wiki', or has just copied the llm-wiki/ folder into a project. Guides the user through an interactive integration-choice flow where all data sources (DevOps, GitHub, Dataverse, SharePoint) are optional. Also offers a self-service path for manual config editing."
argument-hint: 'Run in the root of a project that has llm-wiki/ as a subfolder'
---

# Skill: Setup LLM Wiki

Integrate the `llm-wiki/` folder with the host project. This skill is performed by an LLM agent — there is no installer script. All integrations are **optional** — the wiki works with just `llm-wiki/raw/` and manual ingest.

## Ownership

| Scope                   | Permission                                               |
| ----------------------- | -------------------------------------------------------- |
| Host project `.github/` | WRITE — copilot-instructions, workflows, prompts, agents |
| Host project `.vscode/` | WRITE — mcp.json                                         |
| Host project root       | WRITE — `.env`, `.gitignore`                             |
| `llm-wiki/wiki.config.yml` | WRITE — populate from user input                     |
| `llm-wiki/wiki/log.md` | APPEND only                                              |
| `llm-wiki/raw/`        | NO ACCESS                                                |
| `llm-wiki/wiki/` (content pages) | NO ACCESS                                      |

This skill only creates/updates integration files. It does NOT create wiki content pages.

## Pre-flight

1. Verify the agent is running from the **project root** (not from inside `llm-wiki/`).
   - Check that `llm-wiki/AGENTS.md` exists. If not, ask the user to copy the folder first.
2. Read these template files once into context (from the plugin assets):
   - `${PLUGIN_ROOT}/skills/llm-wiki-setup/assets/copilot-snippet.md`
   - `${PLUGIN_ROOT}/skills/llm-wiki-setup/assets/mcp-servers.json`
   - `${PLUGIN_ROOT}/skills/llm-wiki-setup/assets/wiki.yml`
   - `${PLUGIN_ROOT}/skills/llm-wiki-setup/assets/copilot-setup-steps.yml`
   - `${PLUGIN_ROOT}/skills/llm-wiki-setup/assets/llm-wiki.prompt.md`
   - `${PLUGIN_ROOT}/skills/llm-wiki-setup/assets/llm-wiki-setup.prompt.md`
   - `${PLUGIN_ROOT}/skills/llm-wiki-setup/assets/llm-wiki.agent.md`
   - `${PLUGIN_ROOT}/skills/llm-wiki-setup/assets/env.sample`
3. Read existing config files if present (`.env`, `.vscode/mcp.json`, `llm-wiki/wiki.config.yml`) — pre-populate answers from them.
4. Detect prerequisites (don't install — just report missing ones to the user):
   - `gh auth status` (required for GitHub sync and `gh api` fallback)
   - `npx --version` (required for Azure DevOps MCP)
   - `markitdown --version` or `markitdown-mcp --help` (optional)

## Interactive setup flow

The agent is the **single touchpoint** for wiki configuration. Guide the user through these steps in order.

### Step A — Setup mode choice

Ask: "Vuoi che ti guidi nella configurazione passo-passo, o preferisci compilare il file di config in autonomia?"

- **Interactive** → proceed with Step B.
- **Self-service** → generate `llm-wiki/wiki.config.yml` with full comments explaining each section. Tell the user: "Ho generato il file di config con tutti i commenti. Compilalo e poi torna da me per completare il setup." Then skip to Step G (file generation) when the user returns.

### Step B — Integration selection

Ask (multi-select): "Quali fonti dati vuoi collegare alla wiki?"

| Option             | What it enables                            |
| ------------------ | ------------------------------------------ |
| Azure DevOps       | Work items, sprint tracking, backlog sync  |
| GitHub             | Repos, PRs, branches, code analysis        |
| Dataverse          | Solution analysis, data model, plugins     |
| SharePoint         | Document libraries, analysis docs          |
| Nessuna            | Solo ingest manuale da `llm-wiki/raw/`     |

If "Nessuna" is selected, skip to Step E. Otherwise proceed with Step C for each selected integration.

### Step C — Per-integration details

Collect details **only for selected integrations**. Batch questions per integration.

#### If Azure DevOps selected:

| Field                 | Required | Example                |
| --------------------- | -------- | ---------------------- |
| Organization name     | yes      | `MyCompany`            |
| Project name          | yes      | `EAM-Project`          |
| Azure DevOps PAT      | yes      | *(goes to `.env`)*     |
| Area path filter      | no       | `EAM-Project\\Team A`  |
| Iteration prefix      | no       | `2026`                 |

#### If GitHub selected:

| Field                        | Required | Example                       |
| ---------------------------- | -------- | ----------------------------- |
| Repo(s) to track             | yes      | `acme/backend, acme/frontend` |
| GitHub PAT (for CI only)     | no       | *(goes to `.env`)*            |

Explain: "Se usi VS Code con Copilot, il token GitHub è già configurato. Un PAT separato serve solo per l'auto-update in CI (il `GITHUB_TOKEN` del workflow è sufficiente nella maggior parte dei casi)."

#### If Dataverse selected:

| Field                  | Required | Example                              |
| ---------------------- | -------- | ------------------------------------ |
| Solution name(s)       | yes      | `MySolution, OtherSolution`          |
| Publisher prefix(es)   | no       | `ava_, ray_`                         |

Explain: "La connessione a Dataverse avviene tramite `pacx auth create`. Assicurati di avere un profilo PACX configurato."

#### If SharePoint selected:

| Field                  | Required | Example                              |
| ---------------------- | -------- | ------------------------------------ |
| Site URL               | yes      | `https://company.sharepoint.com/...` |
| Document library paths | yes      | `Shared Documents/Analysis`          |
| Tenant ID              | yes      | *(goes to `.env`)*                   |
| Client ID              | yes      | *(goes to `.env`)*                   |
| Client Secret          | yes      | *(goes to `.env`)*                   |

### Step D — Publishing

Ask: "Vuoi pubblicare la wiki su GitHub Wiki?"

- **Yes** → collect:
  - Target repo (`owner/repo`)
  - Project name (for sidebar header)
- **No** → set `publish.enabled: false` in config.

### Step E — Automated updates

Ask: "Vuoi configurare un aggiornamento automatico della wiki?"

Explain the mechanism: "Un GitHub Action crea un issue ogni giorno (o con la frequenza che scegli), assegnato al Copilot Coding Agent, che esegue il sync e apre una PR con le modifiche."

| Option      | Cron             | Description                         |
| ----------- | ---------------- | ----------------------------------- |
| Daily       | `0 7 * * *`      | Every day at 07:00 UTC *(default)*  |
| Weekly      | `0 7 * * 1`      | Every Monday at 07:00 UTC           |
| Manual only | —                | No scheduled workflow               |

- **Daily** or **Weekly** → install `wiki.yml` workflow with the chosen schedule.
- **Manual only** → skip workflow creation. The user can still trigger syncs via the agent.

### Step F — Sprint settings

Only ask if Azure DevOps or GitHub was selected.

| Field              | Default      | Example    |
| ------------------ | ------------ | ---------- |
| Sprint duration    | 2 weeks      | `3`        |
| Sprint pattern     | `YYYY-SNN`   | `YYYY-SNN` |

Accept defaults silently if the user has no preference.

## File generation steps

Perform every step idempotently — if a target file already contains the LLM Wiki section, **patch** it rather than re-appending. Skip steps for integrations that were not selected.

### 1. `.github/copilot-instructions.md`

- If file does not exist: create it with the contents of the copilot-snippet asset.
- If file exists and contains the marker `## LLM Wiki`: leave the existing block untouched, refresh **only** the skill table inside that section if it differs.
- If file exists without the marker: append the snippet content.

### 2. `.vscode/mcp.json`

- Read the mcp-servers asset.
- **Include only server entries for selected integrations:**
  - `azure-devops` → only if Azure DevOps was selected. Substitute `YOUR_DEVOPS_ORG` with the collected org name.
  - `github` → only if GitHub was selected (or if auto-update is enabled).
  - `sharepoint` → only if SharePoint was selected.
  - `markitdown` → optional — include if `markitdown-mcp` is installed or the user wants it.
- If `.vscode/mcp.json` does not exist: create it with the selected entries.
- If it exists: parse the JSON, merge new entries (do not overwrite other servers).

### 3. `.github/workflows/wiki.yml` *(skip if manual-only)*

- Copy the wiki.yml asset to `.github/workflows/wiki.yml`.
- Set the cron schedule based on Step E (daily or weekly).
- If the destination already exists and the user customised it: create `.github/workflows/wiki.yml.new` and ask the user to merge.

### 3a. `.github/copilot-setup-steps.yml` *(skip if manual-only)*

- Copy the copilot-setup-steps asset to `.github/copilot-setup-steps.yml`.
- If Dataverse was NOT selected, remove the PAC CLI installation step from the copied file.
- If the destination already exists: leave it.

### 4. `.github/prompts/llm-wiki.prompt.md`

- Always overwrite from the llm-wiki.prompt asset.

### 4a. `.github/prompts/llm-wiki-setup.prompt.md`

- Always overwrite from the llm-wiki-setup.prompt asset.

### 4b. `.github/agents/llm-wiki.agent.md`

- Always overwrite from the llm-wiki.agent asset.
- Create `.github/agents/` directory if it doesn't exist.

### 5. `.env` *(skip if no integration needs secrets)*

- If `.env` does not exist: create it with only the relevant variables.
- If `.env` exists: read it; add/update only the missing keys.
- **Include only variables for selected integrations:**
  - `AZURE_DEVOPS_PAT` → only if Azure DevOps was selected
  - `GITHUB_PERSONAL_ACCESS_TOKEN` → only if GitHub PAT was provided
  - `TENANT_ID`, `CLIENT_ID`, `CLIENT_SECRET` → only if SharePoint was selected
- Never log secret values back to the user.

### 6. `.gitignore`

Ensure these entries exist (add a section header `# LLM Wiki` if you create them):

```
.env
llm-wiki/wiki/lint-*.md
llm-wiki/.obsidian/
__pycache__/
*.pyc
```

If `.gitignore` already contains `# LLM Wiki`: do nothing.

### 7. `llm-wiki/wiki.config.yml`

Generate based on user choices. Populate only enabled sections; comment out disabled ones.

```yaml
# ─── Azure DevOps ───
devops:
  area_paths: []          # empty = all areas
  iteration_prefix: ""    # empty = all iterations
  work_item_types: [Feature, User Story, Task]
  excluded_states: [Removed]

# ─── GitHub ───
github:
  repos: []               # empty = discover via MCP
  branch_patterns: ["^main$", "^develop$", "^feature/", "^release/", "^hotfix/"]

# ─── Dataverse ───
dataverse:
  solutions: []
  publisher_prefixes: []
  components:
    tables: true
    plugins: true
    forms: true
    views: true
    security_roles: true
    business_rules: true
    flows: true
    option_sets: true

# ─── SharePoint ───
sharepoint:
  enabled: false
  site_url: ""
  document_libraries: []

# ─── Sprint settings ───
sprints:
  duration_weeks: 2
  pattern: "YYYY-SNN"

# ─── Automated updates ───
automation:
  enabled: true
  schedule: daily          # daily | weekly | manual

# ─── Publishing ───
publish:
  enabled: false
  repo: ""                 # owner/repo — target GitHub Wiki
  project_name: ""         # displayed in sidebar header
  exclude:
    - "wiki/log.md"
    - "wiki/lint-*.md"
```

Preserve any fields the user added manually that aren't in the template.

## Verification

After all steps, report a **conditional checklist** — only include items for integrations that were selected and files that were actually created.

**Always created:**
- [ ] `.github/copilot-instructions.md` contains LLM Wiki section
- [ ] `.github/prompts/llm-wiki.prompt.md` installed
- [ ] `.github/prompts/llm-wiki-setup.prompt.md` installed
- [ ] `.github/agents/llm-wiki.agent.md` installed
- [ ] `.gitignore` updated
- [ ] `llm-wiki/wiki.config.yml` populated

**If any integration selected:**
- [ ] `.vscode/mcp.json` has entries for: `<list of selected servers>`
- [ ] `.env` populated (secrets redacted in report)

**If auto-update enabled:**
- [ ] `.github/workflows/wiki.yml` exists (schedule: `<daily|weekly>`)
- [ ] `.github/copilot-setup-steps.yml` exists

**If publish enabled:**
- [ ] `llm-wiki/wiki.config.yml` → `publish.repo` = `<value>`

## Next steps message

Tailor the message to the enabled integrations:

> Setup complete. To use the wiki, switch to the **LLM Wiki** agent.

Then append the relevant suggestions:

- **If DevOps enabled:** "Prova `sync devops` per importare i work item da Azure DevOps."
- **If GitHub enabled:** "Prova `sync github` per analizzare i repository."
- **If Dataverse enabled:** "Prova `sync dataverse` per analizzare le soluzioni Dataverse (assicurati che `pacx auth ping` funzioni)."
- **If no integration:** "Inserisci documenti in `llm-wiki/raw/meetings/`, `llm-wiki/raw/analysis/`, etc. e poi chiedi all'agente di fare `ingest raw/meetings/...`."
- **If auto-update enabled:** "Il GitHub Action creerà un issue `<daily|weekly>` assegnato a Copilot, che aprirà una PR con gli aggiornamenti. Trigger manuale: `gh workflow run wiki.yml`."
- **If publish enabled:** "Quando la wiki ha contenuti, usa `publish wiki` per pubblicare su GitHub Wiki."
- **Always:** "Puoi sempre tornare da me per `lint`, `query`, `sprint snapshot`, o `full update`."

## Log

Append an entry to `llm-wiki/wiki/log.md`:

```
## [YYYY-MM-DD] setup | Integration
- Integrations: <DevOps|GitHub|Dataverse|SharePoint|none>
- DevOps: <org/project or "not configured">
- GitHub repos: <list or "not configured">
- Automation: <daily|weekly|manual>
- Publish: <repo or "not configured">
- Files created/updated: <list of files actually created>
```
