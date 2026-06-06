## Changelog

## 2.0.0 - 2026-06-06

- **GitHub Copilot only:** removed Claude Code and Obsidian assets and references (`CLAUDE.md`, `.obsidian/`, the generic Claude skill-authoring guide, and Claude Desktop / `@anthropic` / Obsidian prose). The plugin now targets GitHub Copilot exclusively.
- **Directly installable source repo:** `raythekool/ray-llm-wiki` is now a self-consistent marketplace — `marketplace.json` plugin name and `plugin.json` name both `llm-wiki`, so `@agentPlugins llm-wiki` resolves when you add the repo directly. Install + usage instructions added to the READMEs.
- **Publish fix:** the export rebrands the marketplace name, the exported `plugin.json` name, the SessionStart hook matcher, and the README identity tokens to `power-platform-llm-wiki`, so the published `raythekool/power-platform-llm-wiki` distribution resolves as `@agentPlugins power-platform-llm-wiki`.
- **Validation:** `Validate-Plugin.ps1` now checks that `marketplace.json` plugins[0].name matches `plugin.json` name and points to `plugins/llm-wiki/`.
- **Breaking:** consolidated 11 skills into 5 — `init`, `config`, `update`, `ingest`, `query`.
  - `init` replaces `llm-wiki-setup` (scaffolds `wiki/` + `raw/`, integrates the host repo).
  - `config` is new — wizard to reconfigure integrations, repos, sprint settings, automation, publish target, and secrets.
  - `update` merges `sync-devops`, `sync-github`, `sync-dataverse`, `full-update`, `lint`, `publish`, and `sprint-snapshot` behind flags (`--source`, `--full`, `--lint`, `--publish`, `--sprint`).
  - `ingest` merges `ingest` and `ingest-meeting` with path-based type auto-detection (`--type` override).
  - `query` unchanged in purpose.
- Added PRISMA-style plugin scaffolding: `plugin.json` manifest (with `version`), `hooks.json` (SessionStart staleness check), and `scripts/Check-PluginStaleness.ps1`.
- Single agent `agents/llm-wiki.agent.md` rewritten with a 5-skill routing table.
- Bundled `references/` docs realigned to the 5-skill model.

## 1.1.0 - 2026-05-12

- Added standalone distribution assets: `LICENSE` and `CHANGELOG.md`.
- Added a repeatable export path from the monorepo via
  `scripts/export-plugin.ps1`.
- Documented how to publish the plugin as a separate repository or zip.

## 1.0.0 - 2026-04-29

- Initial plugin release with 1 agent and 11 skills.
