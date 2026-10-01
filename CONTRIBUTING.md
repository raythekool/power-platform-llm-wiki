## 🤝 Contributing

Thanks for improving LLM Wiki. This repository is the source of the `power-platform-llm-wiki` VS Code agent plugin.

### 📏 Ground rules

- 🚫 **No customer data.** Never commit customer names, repository URLs, people, screenshots or documents. Use the fictional *Contoso* in examples and fixtures. The validator blocks known identifiers; add private patterns locally with `$env:LLMWIKI_DENYLIST` (semicolon-separated regexes).
- 🔑 **No secrets** in any file, including examples.
- 🐚 **Deterministic first.** If a step can be done by a script (parsing, checks, conversion), write or extend a PowerShell script in `plugins/power-platform-llm-wiki/scripts/` instead of adding instructions for the LLM.
- 🪶 **Keep the instructions small.** Every line of `AGENTS.md`, agent and skills costs tokens on every run. Prefer references loaded on demand (`references/`, profiles).
- 🖼️ **Images are SVG** in `docs/images/`: self-contained (no external fonts or links), with a background so they read well in light and dark themes, and a meaningful `<title>`/`<desc>`.

### 🗂️ Layout

| Path                                                     | Content                                                                      |
| -------------------------------------------------------- | ---------------------------------------------------------------------------- |
| `plugins/power-platform-llm-wiki/agents/`                | The LLM Wiki agent (routing and core rules)                                  |
| `plugins/power-platform-llm-wiki/skills/<name>/SKILL.md` | One skill per user intent: `init`, `config`, `update`, `ingest`, `query`     |
| `plugins/power-platform-llm-wiki/references/`            | `AGENTS.md` (installed in projects), `publishing.md`, `profiles/`            |
| `plugins/power-platform-llm-wiki/templates/`             | Page templates                                                               |
| `plugins/power-platform-llm-wiki/scripts/`               | PowerShell 7 scripts; JSON on stdout; shared helpers in `LlmWiki.Common.ps1` |
| `scripts/Validate-Plugin.ps1`                            | Release checks                                                               |
| `tests/`                                                 | Fixtures and `Invoke-Tests.ps1`                                              |
| `docs/`                                                  | User documentation (Italian) and images                                      |
| `site/`, `scripts/Build-Site.ps1`                        | Bilingual website (EN/IT); deployed to GitHub Pages by `pages.yml`           |

### 🧭 Conventions

- **Skills:** front matter with `name` (equal to the folder) and `description`; optional `argument-hint`, `user-invocable`. Do not use `context:` or `disable-model-invocation: true`. Each skill states its ownership (what it may read and write) and appends to `wiki/log.md`.
- **Paths in skills:** projects run the engine from `llm-wiki/.engine/`; refer to scripts as `llm-wiki/.engine/scripts/<name>.ps1` and to the plugin root as "two folders above this SKILL.md" (only `init` / `config` need it).
- **Scripts:** `#Requires -Version 7.0`, explicit UTF-8 I/O (`Read-Utf8Text` / `Write-Utf8Text`), JSON output, exit code 1 on failure. Never name a variable `$host`. New scripts used by projects are copied by `Install-Engine.ps1` (whole `scripts/` folder) and must be listed in the validator's required files.
- **Wiki content conventions** (links, front matter, lifecycle) live in `references/AGENTS.md`; change them there and in `Test-WikiLint.ps1` together.
- **Markdown:** relative links, no `[[wiki links]]` in templates, Mermaid in fenced blocks. Emoji are welcome in headings and tables of the docs; never inside link text of wiki pages.

### 🔁 Workflow

1. 🌿 Create a branch.
2. ✏️ Make the change; add or update a fixture and assertions in `tests/Invoke-Tests.ps1` for any script change.
3. ✅ Run the checks:

    ```powershell
    pwsh ./scripts/Validate-Plugin.ps1 -Human
    pwsh ./tests/Invoke-Tests.ps1
    ```

4. 📜 Update `CHANGELOG.md` (and copy it to `plugins/power-platform-llm-wiki/CHANGELOG.md`).
5. 🔀 Open a pull request; CI (`.github/workflows/validate.yml`) runs the same checks.

### 🏷️ Releasing

1. Bump the version (SemVer) in `plugins/power-platform-llm-wiki/plugin.json` and in `.github/plugin/marketplace.json` (`metadata.version` and `plugins[0].version`). The validator fails on mismatches.
2. Breaking changes to links, front matter, configuration or host layout require a major version, a CHANGELOG "Breaking" section and migration steps (`config --migrate` and `docs/`).
3. Tag the release (`vX.Y.Z`). Projects update the plugin, then run `config --refresh-engine`.
