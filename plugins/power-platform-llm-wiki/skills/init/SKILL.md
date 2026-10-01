---
name: init
description: "Initialize an LLM Wiki in the current project: interactive wizard (project, profiles CE/Power Platform/F&O, code repositories, Azure DevOps, Dataverse, F&O metadata, publishing to Azure DevOps Wiki or GitHub Wiki, governance), scaffolds llm-wiki/ (raw/, wiki/, .state/), installs the managed engine (AGENTS.md, scripts, templates, profiles), writes wiki.config.yml, .vscode/mcp.json, copilot instructions and .gitignore. Use for first-time setup or to repair missing scaffolding."
argument-hint: "Run from the root of the project that will host llm-wiki/"
user-invocable: true
---

# Initialize LLM Wiki

This skill creates structure and configuration only; it never writes wiki content pages. Paths below are relative to the host project root. `<plugin>` is the plugin root: two folders above this `SKILL.md`.

## Ownership

| Scope | Permission |
| --- | --- |
| `llm-wiki/` skeleton, `llm-wiki/wiki.config.yml`, seed `index.md` / `overview.md` / `log.md` | WRITE (create only if missing) |
| `llm-wiki/AGENTS.md`, `llm-wiki/.engine/` | WRITE via `Install-Engine.ps1` |
| `.vscode/mcp.json`, `.github/copilot-instructions.md`, `.gitignore`, `.github/workflows/copilot-setup-steps.yml` | WRITE (merge, never overwrite unrelated content) |
| Existing wiki content pages, `llm-wiki/raw/` files | NO ACCESS |

## Prerequisites

Detect and report (never install silently):

| Tool | Needed for | Check |
| --- | --- | --- |
| PowerShell 7 | all deterministic scripts | `pwsh --version` |
| git | code analysis, publishing | `git --version` |
| Git Credential Manager | Azure Repos clone, Azure DevOps Wiki push | `git credential-manager --version` |
| pacx / pac | Dataverse source | `pacx --version`, `pac help` |
| gh | GitHub source / GitHub Wiki | `gh auth status` |
| markitdown | Office / PDF sources | `markitdown --version` |

If `pwsh` is missing, stop: the engine cannot run without it.

## Wizard

Ask one step at a time, offering **Yes** before **No**. Pre-fill answers from an existing `llm-wiki/wiki.config.yml`.

1. **Mode** - guided, or self-service (write the commented `wiki.config.yml` from `assets/wiki.config.yml`, install the engine, stop and ask the user to fill the file and run `config`).
2. **Project** - name; content language (default `it`); profiles (multi-select): `power-platform` (Dynamics 365 CE / Dataverse), `dynamics-fno` (Finance & Operations), `generic` (integrations, Azure, .NET).
3. **Sources** (multi-select, all optional):
    - Code repositories (recommended: code is the primary source) - for each: name, provider (`azure-devops` / `github` / `local`), clone URL, local path, branch, optional include/exclude globs.
    - Azure DevOps Boards - organization, project, optional area paths and iteration prefix. Authentication is Microsoft Entra ID through the MCP server: **do not ask for a PAT**.
    - Dataverse - solution unique names, publisher prefixes (connection: the active `pacx auth` profile).
    - F&O metadata - folders of the **custom** packages (e.g. `<repo>/Metadata/<Package>`), optional model filter.
    - GitHub activity - `owner/repo` list (PRs, issues, branches).
    - SharePoint - site URL and libraries (documents are downloaded into `raw/` manually or through an MCP server approved by the tenant).
4. **Publishing** - Azure DevOps Wiki (project wiki: organization, project, wiki name; code wiki: repo, branch, folder; optional mount folder), GitHub Wiki (`owner/repo`), or none. Default `publish.headless: false`.
5. **Governance** - PII redaction (default Yes), stale threshold in days (default 30), names of the people who certify pages (optional).
6. **Automation** - only when the host repository is on GitHub: weekly / daily / manual. Explain that it uses a **Copilot cloud agent automation** (repository -> Agents -> Automations), available for private or internal repositories.
7. **Sprints** - only when Azure DevOps Boards is enabled: duration and pattern (defaults 2 weeks, `YYYY-SNN`).
8. **Confirm** - show the resolved configuration and the files that will be created or changed. Abort on No.

## File generation (idempotent)

1. **Skeleton** - create missing folders (add `.placeholder` to empty ones):
    - `llm-wiki/raw/{meetings,analysis,specs,adrs,assets}`, plus `code`, `devops`, `dataverse`, `fno`, `github` only for the selected sources;
    - `llm-wiki/wiki/{requirements,design,code,meetings,reference/decisions,reference/concepts,reference/entities,reference/sources,reference/queries}`, plus `features` and `delivery` (Boards) and `projects` (code repositories);
    - `llm-wiki/.state/`.
2. **Engine** - install the managed files (AGENTS.md, scripts, templates, profiles, headless skill copies):

    ```powershell
    pwsh -NoProfile -File "<plugin>/scripts/Install-Engine.ps1" -LlmWikiPath llm-wiki
    ```

3. **Seed pages** (only if missing): `wiki/index.md` from `assets/wiki-index.md`; `wiki/overview.md` (`type: overview`, `updated`, title, one-paragraph stub from the wizard answers); `wiki/log.md` (`type: log`, `updated`, `# Log`). Fill the `{{...}}` placeholders.
4. **`llm-wiki/wiki.config.yml`** - from `assets/wiki.config.yml`, enabling only the selected sections. If the file exists, merge without dropping user keys.
5. **`.vscode/mcp.json`** - merge into `servers` only what is needed, from `assets/mcp-servers.json`:
    - Boards selected: `ado-remote` with the organization (Microsoft-hosted, Entra ID sign-in). If the remote server is not available in the tenant, use `ado-local` (pinned version) instead.
    - `markitdown` only if `markitdown-mcp` is installed.
    - Keep unrelated servers untouched.
6. **`.github/copilot-instructions.md`** - append `assets/copilot-snippet.md`, or replace an existing `## LLM Wiki` section up to the next `## ` heading.
7. **`.gitignore`** - ensure a `# LLM Wiki` block with `llm-wiki/dist/`, `llm-wiki/wiki/lint-*.md`, `llm-wiki/raw/dataverse/*.zip`, `.env`.
8. **Automation** (GitHub host only, schedule not manual): copy `assets/copilot-setup-steps.yml` to `.github/workflows/copilot-setup-steps.yml` (drop the .NET / PAC steps when Dataverse is not selected; if the file exists, add only missing steps). Then give the user the prompt in `assets/automation-prompt.md` and the steps: repository -> **Agents** -> **Automations** -> **Create new**, trigger "On a schedule", tools: push changes and create pull request.
9. **Existing sources** - if `llm-wiki/raw/` already contains files, ask whether to process them now (`update --full`) or record them as already processed:

    ```powershell
    pwsh llm-wiki/.engine/scripts/Get-RawDelta.ps1 -RawPath llm-wiki/raw -Baseline
    ```

## Verification

Run `pwsh llm-wiki/.engine/scripts/Test-WikiLint.ps1 -WikiPath llm-wiki/wiki`: it must report 0 errors. Print a checklist with only the applicable items: engine version (`llm-wiki/.engine/VERSION`), config sections enabled, MCP servers added, instructions updated, `.gitignore`, automation.

## Next steps message

- Code repositories: `update --source code` (builds `wiki/code/` and `wiki/projects/`).
- Boards: `update --source devops`. Dataverse: `update --source dataverse` (check `pacx auth ping`). F&O: `update --source fno`.
- Documents and minutes: drop files in `llm-wiki/raw/<folder>/`, then `ingest <file>` or `update --full`.
- Publishing: `update --publish` once the lint is clean.
- Always available: `query <question>`, `update --lint`, `config`.

## Bookkeeping

Append to `llm-wiki/wiki/log.md`:

```markdown
## [YYYY-MM-DD] init | <project name>

- Engine: <version>
- Profiles: <list>
- Sources: <code | devops | dataverse | fno | github | sharepoint | none>
- Publish: <target or none>
- Files created/updated: <list>
```
