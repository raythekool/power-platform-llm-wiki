## Changelog

## Unreleased

## 3.1.0 - 2026-10-12

- 🗃️ Code in **TFVC** (TFS, Azure DevOps Server, Azure DevOps Services TFVC projects), typical of older F&O projects: new `provider: tfvc` for `code.repos` with a read-only procedure (`references/tfvc.md`, installed as `.engine/tfvc.md`: reuse or create a workspace, `tf get`, latest changeset as revision, never check in). Without `tf.exe`, or for any folder without version control, `provider: local` with a downloaded copy.
- 🔍 `Get-CodeInventory.ps1`: reports `vcs` (`git`, `tfvc`, `none`) and `revision` (`-Revision`, e.g. `C1234`), skips `$tf` folders, and with `-StatePath` lists files added / modified / deleted since the last accepted SHA-256 snapshot (`-AcceptState` promotes it after the pages are written), so non-git sources stay incremental.
- 📝 Citations and logs use a generic revision `<repo>@<rev>:<path>` (git SHA, TFVC changeset `C<n>`, or copy date).

## 3.0.1 - 2026-10-12

- 🌍 Bilingual (EN/IT) promo website in `site/`, built by `scripts/Build-Site.ps1` and deployed to GitHub Pages by `.github/workflows/pages.yml`.
- 🧙 Interactive setup wizard page (`site/wizard.html`), the web version of `docs/wizard-configurazione.md`, with per-step navigation and progress saved in the browser.
- 📦 Install instructions for GitHub Copilot CLI and Claude Code (README, website, user guide). New `.claude-plugin/marketplace.json` (checked by the validator together with `.github/plugin/marketplace.json`); `plugin.json` now declares `mcpServers` as `./.mcp.json`, as Claude Code requires.

## 3.0.0 - 2026-10-01

This repository is now the primary source of the plugin (no longer an export of another repository).

### 💥 Breaking

- **Links:** wiki pages use relative Markdown links (`[Title](../folder/page.md)`) instead of `[[wiki links]]`; the publish step converts them per target. `config --migrate` converts v2 wikis.
- **Front matter:** `status` is now the content lifecycle (`draft | reviewed | certified | superseded | deprecated`); work-item / decision state moves to `state`. New fields: `owner`, `updated`, `sources`, `reviewed_by`, `certified_by`, `certified_at`, `req_id`, `implements`, `implemented_by`.
- **Configuration:** `wiki.config.yml` schema 3 (`project.profiles`, `code.repos`, `fno`, `governance`, `publish.target`).
- **Host integration:** the engine (AGENTS.md, scripts, templates, profiles, headless skill copies) is installed into `llm-wiki/` by `Install-Engine.ps1`; `.vscode/mcp.json` replaces `.mcp.json`; the host agent and prompt copies are no longer installed.
- **Automation:** the issue-creating workflow is replaced by a Copilot cloud agent automation prompt and a correct `.github/workflows/copilot-setup-steps.yml`.

### ✨ Added

- Code-first documentation: `update --source code` for Azure Repos, GitHub and local clones, incremental by commit, with requirement traceability and `⚠️ Drift` between FDD/TDD and code.
- Dynamics 365 Finance & Operations profile and `update --source fno` (Ax* metadata: tables, extensions, Chain of Command, data entities, security, model descriptors).
- Profiles `power-platform`, `dynamics-fno`, `generic`.
- Templates: meeting minutes (Q&A, decisions, actions, risks), requirement (FDD), design (TDD), ADR, code component, source summary.
- Publishing to **Azure DevOps Wiki** (project and code wiki: `.order`, `%2D` names, absolute links, attachments) besides GitHub Wiki.
- Content governance: lifecycle and certification (`update --review` / `--certify`), pending updates for certified pages, PII redaction, provenance.
- Deterministic scripts: `Get-RawDelta.ps1` (incremental sources), `Get-CodeInventory.ps1`, `Test-WikiLint.ps1`, `Export-Wiki.ps1`, `Install-Engine.ps1`.
- Tests (`tests/Invoke-Tests.ps1` with CE and F&O fixtures) and CI (`.github/workflows/validate.yml`).
- Documentation: user guide, governance and v2 -> v3 migration in `docs/` (Italian), `CONTRIBUTING.md`, illustrated READMEs with SVG images in `docs/images/`.

### 🛠️ Fixed / removed

- Removed customer-specific identifiers from the distributed docs; the validator now blocks them.
- Removed the SessionStart staleness hook (checked wrong paths and ran `git fetch` in the host repository).
- Azure DevOps MCP: pinned version, correct domain arguments, Entra ID sign-in (no PAT); remote server preferred.
- Skills no longer hide themselves from the agent (`disable-model-invocation`) or use unsupported keys (`context: fork`).
- Removed redundant reference documents (`llm-wiki.md`, `powerplatform-llm-wiki.md`); the operating manual is now ~10 KB.

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
