# LLM Wiki — VS Code Agent Plugin

Persistent project knowledge base maintained by an LLM agent. Syncs from Azure DevOps, GitHub, and Dataverse; ingests meeting notes and analysis docs; publishes to GitHub Wiki.

**Marketplace repository:** `raythekool/power-platform-llm-wiki`

---

## Quick Start

### Install from repository marketplace

1. Open `File > Preferences > Settings`
2. Enable `Chat > Plugins: Enabled`
3. Add `raythekool/power-platform-llm-wiki` to `Chat > Plugins: Marketplaces`
4. Open the Extensions view and search for `@agentPlugins power-platform-llm-wiki`
5. Install the plugin

Do not use a GitHub `tree/.../plugins/llm-wiki` URL in clone or install flows.
That URL points to a folder view, not a Git repository. The supported source is
the repository root `https://github.com/raythekool/power-platform-llm-wiki`.

### First use

1. Install the plugin via VS Code agent plugins.
2. Switch to **LLM Wiki** in the agent picker.
3. Tell the agent: `init` — it will scaffold the wiki and integrate it into your project.
4. Then use: `update --source devops|github|dataverse|all`, `ingest raw/meetings/file.md`, `query <question>`, `update --lint`, `update --publish`.

---

## Distribution

This source plugin can be exported as a standalone marketplace repository.

- The export creates a repository root with `README.md`, `CHANGELOG.md`,
    `LICENSE`, and `.github/plugin/marketplace.json`.
- The plugin itself is exported under `plugins/power-platform-llm-wiki/`.
- The exported repository is ready to publish as
    `raythekool/power-platform-llm-wiki` or a similarly named marketplace repo.

### Export a marketplace repository

From the source repository root, run:

```powershell
./scripts/export-plugin.ps1
```

Default output:

```text
artifacts/power-platform-llm-wiki/
```

That folder is ready to:

1. Be zipped and shared directly.
2. Be pushed as the root of a separate marketplace repository.
3. Be attached to a GitHub release.

---

## Agent

| Name         | File                       | Description                                                                     |
| ------------ | -------------------------- | ------------------------------------------------------------------------------- |
| **LLM Wiki** | `agents/llm-wiki.agent.md` | Main orchestrator — interprets requests, routes to skills, manages data sources |

---

## Skills

| Skill      | Folder            | Description                                                                                                  |
| ---------- | ----------------- | ------------------------------------------------------------------------------------------------------------ |
| **init**   | `skills/init/`    | Scaffold wiki + raw/ folders, generate `wiki.config.yml`, integrate with the host repo (`.github/`, `.mcp.json`, `.env`, `.gitignore`). Wizard-based; all integrations optional. |
| **config** | `skills/config/`  | Reconfigure an existing wiki: add/remove integrations, update repos / area paths / solutions, change sprint settings, automation schedule, publish target, rotate secrets. |
| **update** | `skills/update/`  | Unified maintenance: `--source devops|github|dataverse|all`, `--full` (orchestrated), `--lint`, `--publish`, `--sprint [<id>]`. Headless-mode friendly. |
| **ingest** | `skills/ingest/`  | Process one source from `raw/` into the wiki. Auto-detects type (meeting / spec / analysis / ADR / generic) from path; `--type` overrides. Meetings produce structured synthesis (participants, decisions, action items, blockers). |
| **query**  | `skills/query/`   | Answer a project question using only wiki content (never general knowledge). Cites every claim with `[[wiki-links]]`. Optionally files the answer as `wiki/reference/queries/<slug>.md`. |

---

## MCP Servers

| Server           | Type                 | Required | Purpose                               |
| ---------------- | -------------------- | -------- | ------------------------------------- |
| **Azure DevOps** | stdio (npx)          | Yes      | Work items, sprints, WIQL queries     |
| **GitHub**       | http (Copilot proxy) | Yes      | Repos, branches, PRs, commits, issues |
| **MarkItDown**   | stdio                | Optional | Convert Office docs, PDFs to Markdown |

Configuration: `.mcp.json` at plugin root.

---

## Prerequisites

- **VS Code** with GitHub Copilot Chat
- **Node.js** ≥ 18 (for `npx` MCP servers)
- **`gh` CLI** installed and authenticated (`gh auth login`) — required for source code reads from non-default branches
- **`markitdown`** (optional) — `pip install "markitdown[all]"` for Office file conversion
- **PAC CLI** (optional) — for Dataverse sync: `dotnet tool install --global Microsoft.PowerApps.CLI.Tool`
- **PACX CLI** (optional) — for Dataverse analysis

---

## References

| File                                   | Purpose                                                   |
| -------------------------------------- | --------------------------------------------------------- |
| `plugin.json`                          | Plugin manifest (name, description, hooks, mcpServers)    |
| `hooks.json`                           | SessionStart hook: staleness check                        |
| `scripts/Check-PluginStaleness.ps1`    | Detects new commits to skill scripts on the default branch |
| `scripts/Validate-Plugin.ps1`          | Validates manifests, the 5 skills, agent routing, and root↔plugin parity (run with `-Human`) |
| `references/AGENTS.md`                 | Operating manual — wiki structure, conventions, workflows |
| `references/llm-wiki.md`               | Design rationale and pattern description                  |
| `references/powerplatform-llm-wiki.md` | Power Platform / D365 adaptation guide                    |

---

## Project Structure (after setup)

```
<project-root>/
├── .github/
│   ├── agents/llm-wiki.agent.md        # Custom agent (from plugin)
│   ├── prompts/llm-wiki.prompt.md       # Slash command /llm-wiki
│   ├── workflows/wiki.yml              # Scheduled CI workflow
│   ├── copilot-instructions.md          # Extended with wiki section
│   └── copilot-setup-steps.yml          # Copilot agent environment
├── .mcp.json                     # MCP servers
├── .env                                 # Credentials (gitignored)
└── llm-wiki/
    ├── AGENTS.md                        # Operating manual
    ├── wiki.config.yml                  # What to track
    ├── raw/                             # Source documents
    │   ├── meetings/
    │   ├── analysis/
    │   ├── devops/                      # MCP dumps
    │   ├── github/                      # MCP dumps
    │   └── dataverse/                   # Solution exports
    └── wiki/                            # LLM-maintained knowledge base
        ├── index.md                     # Content catalog
        ├── overview.md
        └── log.md                       # Append-only log

# Note: skills are provided by the plugin and are NOT copied into the host project.
```

---

## Version History

| Date       | Version | Changes                                                                        |
| ---------- | ------- | ------------------------------------------------------------------------------ |
| 2026-06-06 | 2.0.0   | **Breaking:** consolidated 11 skills into 5 (init, config, update, ingest, query); GitHub Copilot-only (removed Claude/Obsidian assets); source repo `ray-llm-wiki` is now directly installable as its own marketplace (plugin id `llm-wiki`); export rebrands the published marketplace + `plugin.json` name to `power-platform-llm-wiki`; added plugin.json, hooks.json, staleness + validation scripts (incl. marketplace↔plugin name check); single-agent routing; realigned references |
| 2026-05-12 | 1.2.1   | Updated export flow to generate a standalone marketplace repository structure  |
| 2026-05-12 | 1.2.0   | Added marketplace manifest alignment with the published standalone plugin repo |
| 2026-05-12 | 1.1.0   | Added standalone distribution assets and export workflow                       |
| 2026-04-29 | 1.0.0   | Initial plugin release — 1 agent, 11 skills                                    |

