# LLM Wiki — VS Code Agent Plugin Marketplace

Plugin marketplace for **LLM Wiki** — a persistent project knowledge base maintained by an LLM agent. Syncs from Azure DevOps, GitHub, and Dataverse; ingests meeting notes and analysis docs; publishes to GitHub Wiki.

**Marketplace repository:** `raythekool/power-platform-llm-wiki`

---

## Quick Start

### Install from marketplace

1. Open VS Code Settings (JSON)
2. Add this repository to `chat.plugins.marketplaces`:

   ```jsonc
   "chat.plugins.marketplaces": [
     "raythekool/power-platform-llm-wiki"
   ]
   ```

3. Reload VS Code
4. The plugin appears automatically — switch to **D - LLM Wiki** in the agent picker

### First use

1. Install the plugin via the marketplace setting above.
2. Switch to **D - LLM Wiki** in the agent picker.
3. Tell the agent: `setup` — it will integrate the wiki scaffold into your project.
4. Start using: `sync devops`, `sync github`, `ingest raw/meetings/file.md`, `lint`, `publish wiki`.

---

## Plugins

| Plugin                      | Path                               | Description                                            |
| --------------------------- | ---------------------------------- | ------------------------------------------------------ |
| **power-platform-llm-wiki** | `plugins/power-platform-llm-wiki/` | Persistent project knowledge base — 1 agent, 11 skills |

See [plugins/power-platform-llm-wiki/README.md](plugins/power-platform-llm-wiki/README.md) for full plugin documentation.

---

## Repository Structure

```text
.
├── .github/
│   └── plugin/
│       └── marketplace.json        # Marketplace manifest
├── plugins/
│   └── power-platform-llm-wiki/
│       ├── .mcp.json               # MCP server definitions
│       ├── agents/                 # Agent definitions
│       ├── skills/                 # 11 skills
│       ├── references/             # Operating manuals
│       └── README.md               # Plugin documentation
├── CHANGELOG.md
├── LICENSE
└── README.md                       # This file
```

---

## Version History

| Date       | Version | Changes                                                         |
| ---------- | ------- | --------------------------------------------------------------- |
| 2026-05-12 | 1.2.0   | Converted to marketplace format for `chat.plugins.marketplaces` |
| 2026-05-12 | 1.1.1   | Added plugin manifest and corrected source install flow         |
| 2026-05-12 | 1.1.0   | Added standalone distribution assets and export workflow        |
| 2026-04-29 | 1.0.0   | Initial plugin release — 1 agent, 11 skills                     |
