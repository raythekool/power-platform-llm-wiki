# LLM Wiki — VS Code Agent Plugin

Persistent project knowledge base maintained by an LLM agent. Syncs from Azure DevOps, GitHub, and Dataverse; ingests meeting notes and analysis docs; publishes to GitHub Wiki.

**Repository marketplace:** `raythekool/power-platform-llm-wiki`

---

## Quick Start

### Install from repository marketplace

1. Open `File > Preferences > Settings`
2. Enable `Chat > Plugins: Enabled`
3. Add `raythekool/power-platform-llm-wiki` to `Chat > Plugins: Marketplaces`
4. Open the Extensions view and search for `@agentPlugins llm-wiki`
5. Install the plugin

Do not use a GitHub `tree/.../plugins/llm-wiki` URL in clone or install flows.
That URL points to a folder view, not a Git repository. The supported source is
the repository root `https://github.com/raythekool/power-platform-llm-wiki`.

### First use

1. Install the plugin via VS Code agent plugins.
2. Switch to **LLM Wiki** in the agent picker.
3. Tell the agent: `setup` — it will integrate the wiki scaffold into your project.
4. Start using: `sync devops`, `sync github`, `ingest raw/meetings/file.md`, `lint`, `publish wiki`.

---

## Distribution

This folder is self-contained and can be distributed on its own.

- For a private share, zip the contents of `plugins/llm-wiki/`.
- For a dedicated repository, publish the exported plugin-only folder created by
    `scripts/export-plugin.ps1`.
- The standalone package should contain `README.md`, `.mcp.json`, `agents/`,
    `skills/`, `references/`, `LICENSE`, and `CHANGELOG.md` at repository root.

### Export a plugin-only package

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
2. Be pushed as the root of a separate Git repository.
3. Be attached to a GitHub release.

---

## Agent

| Name         | File                       | Description                                                                     |
| ------------ | -------------------------- | ------------------------------------------------------------------------------- |
| **LLM Wiki** | `agents/llm-wiki.agent.md` | Main orchestrator — interprets requests, routes to skills, manages data sources |

---

## Skills

| Skill               | Folder                             | Description                                                                                  |
| ------------------- | ---------------------------------- | -------------------------------------------------------------------------------------------- |
| **Setup**           | `skills/llm-wiki-setup/`           | Integrate the wiki into a host project (copilot-instructions, MCP, workflow, agent, prompts) |
| **Ingest**          | `skills/llm-wiki-ingest/`          | Ingest a file from `raw/` into the wiki                                                      |
| **Ingest Meeting**  | `skills/llm-wiki-ingest-meeting/`  | Ingest meeting minutes — creates structured synthesis                                        |
| **Sync DevOps**     | `skills/llm-wiki-sync-devops/`     | Pull Features/User Stories/Tasks from Azure DevOps via MCP                                   |
| **Sync GitHub**     | `skills/llm-wiki-sync-github/`     | Pull repo info, branches, PRs, source code from GitHub                                       |
| **Sync Dataverse**  | `skills/llm-wiki-sync-dataverse/`  | Export & analyze Dataverse solutions via PAC/PACX                                            |
| **Query**           | `skills/llm-wiki-query/`           | Answer questions using only wiki content                                                     |
| **Lint**            | `skills/llm-wiki-lint/`            | Health-check the wiki — find contradictions, stale data, drift                               |
| **Sprint Snapshot** | `skills/llm-wiki-sprint-snapshot/` | Generate sprint status report from wiki data                                                 |
| **Full Update**     | `skills/llm-wiki-full-update/`     | Orchestrate all syncs + ingest + lint + publish                                              |
| **Publish**         | `skills/llm-wiki-publish/`         | Push wiki content to a GitHub repository's wiki                                              |

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
│   ├── prompts/llm-wiki-setup.prompt.md # Slash command /llm-wiki-setup
│   ├── workflows/wiki.yml              # Scheduled CI workflow
│   ├── copilot-instructions.md          # Extended with wiki section
│   └── copilot-setup-steps.yml          # Copilot agent environment
├── .vscode/mcp.json                     # MCP servers
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
    ├── wiki/                            # LLM-maintained knowledge base
    │   ├── index.md                     # Content catalog
    │   ├── overview.md
    │   ├── log.md                       # Append-only log
    │   └── ...
    └── skills/                          # Operation procedures
```

---

## Version History

| Date       | Version | Changes                                                  |
| ---------- | ------- | -------------------------------------------------------- |
| 2026-05-12 | 1.1.0   | Added standalone distribution assets and export workflow |
| 2026-04-29 | 1.0.0   | Initial plugin release — 1 agent, 11 skills              |
