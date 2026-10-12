## Repository instructions

This repository is the source of the `power-platform-llm-wiki` VS Code agent plugin. See [CONTRIBUTING.md](../CONTRIBUTING.md) for layout, conventions and workflow.

### Version management on commit and push

VS Code offers a plugin update only when the version changes (the same applies to Copilot CLI and Claude Code), so check before every commit or push:

1. Look at the changed files. A version bump is needed when anything under `plugins/power-platform-llm-wiki/` changed, except its `CHANGELOG.md` and `README.md`.
2. Changes limited to `site/`, `docs/`, `tests/` or `scripts/` do not need a bump.
3. When a bump is needed, propose the SemVer level and ask for confirmation before applying it:
   - patch: fixes;
   - minor: new features;
   - major: breaking changes to links, front matter, configuration or host layout (also requires a CHANGELOG "Breaking" section and migration steps in `config --migrate` and `docs/`).
4. After confirmation:
   - bump `version` in `plugins/power-platform-llm-wiki/plugin.json` and in both `.github/plugin/marketplace.json` and `.claude-plugin/marketplace.json` (`metadata.version` and `plugins[0].version` in each);
   - move the CHANGELOG "Unreleased" entries under the new version with its date, then copy `CHANGELOG.md` to `plugins/power-platform-llm-wiki/CHANGELOG.md`;
   - run `pwsh ./scripts/Validate-Plugin.ps1 -Human` and `pwsh ./tests/Invoke-Tests.ps1`;
   - suggest the tag `vX.Y.Z`.
5. Never push or create tags without explicit confirmation.
