---
name: init
description: "Initialize an LLM Wiki in the current project: interactive wizard (project, agent tools VS Code / Copilot CLI / Claude Code, profiles CE/Power Platform/F&O, code repositories, Azure DevOps, Dataverse, F&O metadata, publishing to Azure DevOps Wiki or GitHub Wiki, governance), scaffolds llm-wiki/ (raw/, wiki/, .state/), installs the managed engine (AGENTS.md, scripts, templates, profiles), writes wiki.config.yml, MCP configuration (.vscode/mcp.json, .mcp.json), agent instructions (copilot-instructions, CLAUDE.md) and .gitignore. Use for first-time setup or to repair missing scaffolding."
argument-hint: "Run from the root of the project that will host llm-wiki/"
user-invocable: true
---

# Initialize LLM Wiki

This skill creates structure and configuration only; it never writes wiki content pages. Paths below are relative to the host project root. `<plugin>` is the plugin root: two folders above this `SKILL.md`.

## Ownership

| Scope                                                                                                                                      | Permission                                       |
| ------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------ |
| `llm-wiki/` skeleton, `llm-wiki/wiki.config.yml`, seed `index.md` / `overview.md` / `log.md`                                               | WRITE (create only if missing)                   |
| `llm-wiki/AGENTS.md`, `llm-wiki/.engine/`                                                                                                  | WRITE via `Install-Engine.ps1`                   |
| `.vscode/mcp.json`, `.mcp.json`, `.github/copilot-instructions.md`, `CLAUDE.md`, `.gitignore`, `.github/workflows/copilot-setup-steps.yml` | WRITE (merge, never overwrite unrelated content) |
| Existing wiki content pages, `llm-wiki/raw/` files                                                                                         | NO ACCESS                                        |

## Prerequisites

Check `pwsh --version` first: if PowerShell 7 is missing, stop, the engine cannot run without it. Then run the read-only check, which never installs anything:

```powershell
pwsh -NoProfile -File "<plugin>/scripts/Test-Prerequisites.ps1"
```

It prints JSON: `ready`, `blocking`, `optionalMissing` and one entry per tool in `checks` (`status` `ok` | `missing` | `warning`, `version`, `required`, `neededFor`, `detail`, `install`). Show the user a short table of what is available and what is missing, with the wizard choices each missing tool affects. Wizard answers map to features:

| Wizard answer                   | Feature       | Tool                   |
| ------------------------------- | ------------- | ---------------------- |
| Code in Azure Repos             | `azure-repos` | Git Credential Manager |
| Code in TFVC                    | `tfvc`        | tf.exe (Visual Studio) |
| Dataverse                       | `dataverse`   | pacx or pac            |
| GitHub activity                 | `github`      | gh, signed in          |
| Publish to Azure DevOps Wiki    | `ado-wiki`    | Git Credential Manager |
| Publish to GitHub Wiki          | `github-wiki` | gh, signed in          |
| Word / PowerPoint / Excel / PDF | `documents`   | markitdown             |
| Boards through `ado-local`      | `ado-local`   | node                   |

After the Confirm step, run it again with the selected features, e.g. `-Features azure-repos,dataverse,ado-wiki`. Exit code 1 with `ready: false` means the chosen setup cannot fully run yet: list each `blocking` item with its `install` hint and ask whether to continue (the configuration can be written; the affected source or publish step fails until the tool is available). Never install anything without the user's explicit request.

## Wizard

Ask one step at a time, offering **Yes** before **No**. Pre-fill answers from an existing `llm-wiki/wiki.config.yml`.

1. **Mode** - guided, or self-service (write the commented `wiki.config.yml` from `assets/wiki.config.yml`, install the engine, stop and ask the user to fill the file and run `config`).
2. **Project** - name; content language (default `it`); profiles (multi-select): `power-platform` (Dynamics 365 CE / Dataverse), `dynamics-fno` (Finance & Operations), `generic` (integrations, Azure, .NET).
3. **Agent tools** (multi-select) - which tools the team uses with this wiki: `vscode` (GitHub Copilot in VS Code), `copilot-cli` (GitHub Copilot CLI), `claude-code` (Claude Code). Pre-select the tool running this skill. They decide which MCP and instruction files are written (see File generation, steps 5-6).
4. **Sources** (multi-select, all optional):
   - Code repositories (recommended: code is the primary source) - for each: name and provider, then:
     - `azure-devops` / `github` (git): clone URL, local path, branch;
     - `tfvc` (TFS, Azure DevOps Server, or a TFVC project in Azure DevOps Services - common in older F&O projects): collection URL, server path (`$/Project/Trunk/Main`), local workspace folder (if a workspace already maps it, e.g. on an F&O developer VM, use that folder). If `tf.exe` is missing, offer `local` with a downloaded copy instead (see `.engine/tfvc.md`);
     - `local` (any folder without version control, e.g. a copy exported from TFS): local path;
     - optional include/exclude globs for all.
   - Azure DevOps Boards - organization, project, optional area paths and iteration prefix. Authentication is Microsoft Entra ID through the MCP server: **do not ask for a PAT**.
   - Dataverse - solution unique names, publisher prefixes (connection: the active `pacx auth` profile).
   - F&O metadata - folders of the **custom** packages (e.g. `<repo>/Metadata/<Package>`), optional model filter.
   - GitHub activity - `owner/repo` list (PRs, issues, branches).
   - SharePoint - site URL and libraries (documents are downloaded into `raw/` manually or through an MCP server approved by the tenant).
5. **Publishing** - Azure DevOps Wiki (project wiki: organization, project, wiki name; code wiki: repo, branch, folder; optional mount folder), GitHub Wiki (`owner/repo`), or none. Default `publish.headless: false`.
6. **Governance** - PII redaction (default Yes), stale threshold in days (default 30), names of the people who certify pages (optional).
7. **Automation** - only when the host repository is on GitHub: weekly / daily / manual. Explain that it uses a **Copilot cloud agent automation** (repository -> Agents -> Automations), available for private or internal repositories.
8. **Sprints** - only when Azure DevOps Boards is enabled: duration and pattern (defaults 2 weeks, `YYYY-SNN`).
9. **Confirm** - show the resolved configuration and the files that will be created or changed. Abort on No.

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
4. **`llm-wiki/wiki.config.yml`** - from `assets/wiki.config.yml`, enabling only the selected sections and setting `project.tools`. If the file exists, merge without dropping user keys.
5. **MCP configuration** - only the servers that are needed, taken from `assets/mcp-servers.json`:
   - Boards selected: `ado-remote` with the organization (Microsoft-hosted, Entra ID sign-in). If the remote server is not available in the tenant, use `ado-local` (pinned version) instead.
   - `markitdown` only if the prerequisites check reports `markitdown-mcp` as `ok`.
   - `vscode` in `project.tools`: merge the entries into `.vscode/mcp.json` under `servers`.
   - `copilot-cli` or `claude-code` in `project.tools`: merge the same entries into `.mcp.json` at the project root under `mcpServers` (both tools read this file; neither reads `.vscode/mcp.json`). Keep the `type` field on every entry.
   - Keep unrelated servers untouched. Write nothing when no server is needed.
6. **Agent instructions** - `assets/copilot-snippet.md` is the single source:
   - always: append it to `.github/copilot-instructions.md`, or replace an existing `## LLM Wiki` section up to the next `## ` heading (read by VS Code and Copilot CLI);
   - `claude-code` in `project.tools`: make sure `CLAUDE.md` at the project root contains the import line `@.github/copilot-instructions.md` (create the file with that line, or append it to an existing `CLAUDE.md`; never duplicate it).
7. **`.gitignore`** - ensure a `# LLM Wiki` block with `llm-wiki/dist/`, `llm-wiki/wiki/lint-*.md`, `llm-wiki/raw/dataverse/*.zip`, `.env`.
8. **Automation** (GitHub host only, schedule not manual): copy `assets/copilot-setup-steps.yml` to `.github/workflows/copilot-setup-steps.yml` (drop the .NET / PAC steps when Dataverse is not selected; if the file exists, add only missing steps). Then give the user the prompt in `assets/automation-prompt.md` and the steps: repository -> **Agents** -> **Automations** -> **Create new**, trigger "On a schedule", tools: push changes and create pull request.
9. **Existing sources** - if `llm-wiki/raw/` already contains files, ask whether to process them now (`update --full`) or record them as already processed:

   ```powershell
   pwsh llm-wiki/.engine/scripts/Get-RawDelta.ps1 -RawPath llm-wiki/raw -Baseline
   ```

## Verification

Run `pwsh llm-wiki/.engine/scripts/Test-WikiLint.ps1 -WikiPath llm-wiki/wiki`: it must report 0 errors. Check that every JSON file written parses. Print a checklist with only the applicable items: prerequisites (`ready`, open `blocking` items), engine version (`llm-wiki/.engine/VERSION`), config sections enabled, agent tools, MCP files and servers added, instructions updated (`.github/copilot-instructions.md`, `CLAUDE.md`), `.gitignore`, automation.

First-run notes, only for the selected tools:

- Copilot CLI: project MCP servers load only in a trusted folder (accept the trust prompt when starting `copilot`); check them with `/mcp`.
- Claude Code: approve the project servers from `.mcp.json` when prompted at the next start, then sign in to `ado-remote` with `/mcp`; check that `CLAUDE.md` is listed by `/context` under Memory files.

## Next steps message

In Claude Code every command below is a skill with the plugin prefix, e.g. `/power-platform-llm-wiki:update --source code`.

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
- Tools: <vscode | copilot-cli | claude-code>
- Sources: <code | devops | dataverse | fno | github | sharepoint | none>
- Publish: <target or none>
- Files created/updated: <list>
```
