# Changelog

## 1.2.0 - 2026-05-12

- Converted repository to marketplace format (`chat.plugins.marketplaces`).
- Added `.github/plugin/marketplace.json` manifest.
- Moved plugin content into `plugins/power-platform-llm-wiki/`.
- Removed root `plugin.json` (not needed for marketplace repos).

## 1.1.1 - 2026-05-12

- Added the required `plugin.json` manifest at repository root.
- Corrected installation guidance to use `Chat: Install Plugin From Source`
  instead of treating this repository as a plugin marketplace.

## 1.1.0 - 2026-05-12

- Added standalone distribution assets: `LICENSE` and `CHANGELOG.md`.
- Added a repeatable export path from the monorepo via
  `scripts/export-plugin.ps1`.
- Documented how to publish the plugin as a separate repository or zip.

## 1.0.0 - 2026-04-29

- Initial plugin release with 1 agent and 11 skills.
