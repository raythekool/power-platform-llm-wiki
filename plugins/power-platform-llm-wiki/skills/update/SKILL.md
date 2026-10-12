---
name: update
description: "Maintain the LLM Wiki. Sync sources into raw/ and wiki/: code repositories (Azure Repos, GitHub, TFVC / TFS, local folders; code-first as-built docs with requirement traceability and FDD-vs-code drift), Azure DevOps work items, Dataverse metadata, Dynamics 365 F&O metadata, GitHub activity. Also: full incremental run (--full), deterministic lint (--lint), publish to Azure DevOps Wiki or GitHub Wiki (--publish), sprint snapshot (--sprint), review/certify pages on human request (--review / --certify). Headless-safe."
argument-hint: "[--source code|devops|dataverse|fno|github|all] [--full] [--lint] [--publish] [--sprint [<id>]] [--review|--certify <page> --by <name>]"
user-invocable: true
---

# Update LLM Wiki

Read `llm-wiki/AGENTS.md` first. All scripts live in `llm-wiki/.engine/scripts/` and run with `pwsh`; they print JSON. Templates: `llm-wiki/templates/<name>.md` if present, otherwise `llm-wiki/.engine/templates/<name>.md`. Profiles: `llm-wiki/.engine/profiles/<profile>.md`.

## Modes

| Flag | Action |
| --- | --- |
| `--source code` | Get the latest code (git pull, TFVC get, or read a local folder), run the code inventory, update `wiki/projects/` and `wiki/code/`, traceability and drift |
| `--source devops` | Azure DevOps work items -> `wiki/features/`, `wiki/delivery/` |
| `--source dataverse` | Dataverse solution metadata (pacx/pac) -> `wiki/code/` |
| `--source fno` | F&O metadata folders -> `wiki/code/` |
| `--source github` | GitHub PRs, issues, branches -> `wiki/projects/` |
| `--source all` | Every enabled source, in the order code, fno, dataverse, devops, github |
| `--full` | `--source all` + ingest new/changed `raw/` files + sprint snapshot (if a sprint ended) + `--lint` + `--publish` (only if `publish.enabled`, and in headless mode only if `publish.headless`) |
| `--lint` | Deterministic lint + semantic review |
| `--publish` | Export and push to the configured wiki |
| `--sprint [<id>]` | Sprint snapshot |
| `--review <page> --by <name>` / `--certify <page> --by <name>` | Lifecycle change requested by a person |

Without flags: ask which mode (interactive) or run `--full` (headless).

## Ownership

| Scope | Permission |
| --- | --- |
| `llm-wiki/wiki.config.yml` | READ |
| `llm-wiki/raw/{code,devops,dataverse,fno,github}/` | WRITE (dumps) |
| other `llm-wiki/raw/` folders | WRITE only `.md` conversions next to originals (`--full`) |
| `llm-wiki/.state/` | WRITE through `Get-RawDelta.ps1` |
| `llm-wiki/wiki/` | WRITE (respecting the content governance rules in `AGENTS.md`) |
| Clones and workspaces of code repositories | READ (git pull / TFVC get only; never commit, check in, check out, shelve or push) |
| `llm-wiki/.state/code-*.json` | WRITE through `Get-CodeInventory.ps1 -StatePath` / `-AcceptState` |
| Target wiki repository | WRITE only in `--publish` |

## Phase 0 - Bootstrap

1. Read `llm-wiki/wiki.config.yml` and `llm-wiki/wiki/index.md`.
2. Compare `llm-wiki/.engine/VERSION` with the plugin version (`plugin.json`, two folders above the plugin's skills). If they differ, tell the user to run `config --refresh-engine` (headless: continue with the installed engine and mention it in the PR).
3. Expand the flags into an ordered list of phases.

## Phase 1 - Sources

Each source follows the same pattern: **collect deterministically -> dump into `raw/<source>/` -> update pages -> record what changed**. Same-day dumps overwrite the previous one.

### A) Code (`--source code`) - primary source of as-built knowledge

For each entry in `code.repos` (the revision label `<rev>` is the git short SHA, the TFVC changeset `C<n>`, or the date `YYYY-MM-DD` for a plain folder):

1. **Get the code**, by `provider`:
    - `azure-devops`, `github` (git): if `path` exists, `git -C <path> fetch`, `git -C <path> checkout <branch>`, `git -C <path> pull --ff-only` (if the working tree is dirty, stop and ask: never discard local changes). Otherwise `git clone --branch <branch> <url> <path>` (Git Credential Manager; never put tokens in URLs). `<rev>` = `HEAD`.
    - `tfvc` (Team Foundation Version Control: TFS, Azure DevOps Server or Services): needs `tf.exe` (Visual Studio / Team Explorer; run from a Developer PowerShell or by full path). Read `.engine/tfvc.md` and follow it: reuse an existing workspace that maps `server_path` to `path`, or create a dedicated one; stop and ask if `tf status` shows pending changes; `tf get` the latest version; `<rev>` = latest changeset of `server_path`. If `tf.exe` is not available, ask the user to download the folder (web portal: Repos -> Files -> Download as Zip) into `path` and continue as `local`.
    - `local` (no version control, e.g. a copy exported from TFS or a dev VM folder): read `path` as is; never modify it.
2. **Skip unchanged repositories**: git and TFVC - the last `code` entry for the repo in `wiki/log.md` has the same `<rev>`; plain folders - the inventory reports no added, modified or deleted files.
3. **Inventory** (for `tfvc` and `local` add `-Revision <rev>` and the change state):

    ```powershell
    pwsh llm-wiki/.engine/scripts/Get-CodeInventory.ps1 -Path <path> -OutFile llm-wiki/raw/code/<repo>-<YYYY-MM-DD>.json
    pwsh llm-wiki/.engine/scripts/Get-CodeInventory.ps1 -Path <path> -OutFile llm-wiki/raw/code/<repo>-<YYYY-MM-DD>.json -Revision <rev> -StatePath llm-wiki/.state/code-<repo>.json
    ```

4. **Changed files since the last documented revision**: git - `git -C <path> diff --name-only <lastSha> HEAD`; TFVC and plain folders - `changes.added / modified / deleted` in the inventory (`changes.baseline: true` on the first run). On the first run, document everything; afterwards update only the pages whose components changed. When the pages are written, accept the snapshot so the next run compares with it: `Get-CodeInventory.ps1 -StatePath llm-wiki/.state/code-<repo>.json -AcceptState`. If the run fails, do not accept: the same changes are reported again next time.
5. **Pages** (follow the active profiles for the `wiki/code/` page set and use `code-component.md` for component pages):
    - `wiki/projects/<repo>.md` (`type: project`): purpose, version control (git or TFVC, branch / server path), structure, components with links to `code/` pages, last documented revision.
    - `wiki/code/*`: describe behaviour in business terms first, then technical detail, citing `<repo>@<rev>:<path>`; at least one Mermaid diagram per page. Open only the source files each page needs (inventory first).
6. **Traceability and drift** (the main value of code-first documentation):
    - For each `wiki/requirements/*.md`, look for implementing components (names, tables, messages, CoC targets, entities mentioned in the requirement). Add the requirement ID to the code page `implements:` and a row to its `Traceability` table; add the links in the requirement `## Implementation` section.
    - When the code contradicts a requirement or a design page, add `> ⚠️ **Drift:** ...` to both pages with evidence (`file:line` or method). Never "fix" the requirement text.
    - Components without a requirement: leave `implements: []`; the lint reports them as untraced.

### B) F&O metadata (`--source fno`)

Read `.engine/profiles/dynamics-fno.md`. For each path in `fno.metadata_paths` (custom packages only), run `Get-CodeInventory.ps1 -Path <path> -OutFile llm-wiki/raw/fno/<name>-<YYYY-MM-DD>.json` (add `-StatePath llm-wiki/.state/fno-<name>.json` when the folder is not a git clone, and accept it after the pages are written, as in A.4), then update the F&O `wiki/code/` pages (data model, extensions with CoC and `next`, classes, data entities, security, integrations) and the traceability as in A.6. When the metadata lives in a code repository already listed in `code.repos`, the code phase already produced the inventory: reuse it.

### C) Dataverse (`--source dataverse`)

Read `.engine/profiles/power-platform.md` and run its Dataverse commands (`pacx auth ping` first). Write the summary to `raw/dataverse/<solution>-<YYYY-MM-DD>.md`, then update `datamodel.md`, `plugins.md`, `flows.md`, `forms-views.md`, `security.md`, `alm.md`. When both the code inventory and the live metadata exist, flag differences (component in the environment but not in source control, or the opposite) as `⚠️ Drift`.

### D) Azure DevOps work items (`--source devops`)

1. Use the Azure DevOps MCP server tools for WIQL queries and work item details (tool names vary with the server version: pick the work-item query and batch-get tools). Filters: `devops.area_paths`, `iteration_prefix`, `work_item_types`, `excluded_states`.
2. Dump `raw/devops/work-items-<YYYY-MM-DD>.json` and a readable `.md` table.
3. Update `wiki/features/<id>-<slug>.md` (`type: feature`, `devops_id`, `state`, `sprint`), `wiki/delivery/backlog-overview.md`, links from features to requirements (`REQ-...` mentioned in titles/descriptions, or shared tags) and to code pages (branches / PRs linked to work items). Flag `🚫 Blocked` items and `⚠️ Drift` when the wiki disagrees with the board.

### E) GitHub activity (`--source github`)

Use the GitHub MCP tools (or `gh`) for branches matching `github.branch_patterns`, open PRs, recent merges and issues. Dump `raw/github/<repo>-<YYYY-MM-DD>.json` and update the `Activity` section of `wiki/projects/<repo>.md`. Source code analysis belongs to phase A, not here.

## Phase 2 - Ingest new sources (`--full`)

1. `pwsh llm-wiki/.engine/scripts/Get-RawDelta.ps1 -RawPath llm-wiki/raw`
2. Convert every `needsConversion` file with markitdown (`markitdown <file> -o <same-name>.md`, or the MarkItDown MCP tool). Teams recordings (`.mp4`): use a video-analysis skill if available, otherwise ask for the transcript.
3. For each `new` / `changed` file, run the `ingest` procedure (`.engine/skills/ingest/SKILL.md`).
4. After each successful ingest: `Get-RawDelta.ps1 -RawPath llm-wiki/raw -MarkProcessed <file>`.

## Phase 3 - Sprint snapshot (`--sprint`, or `--full` after a sprint boundary)

Create `wiki/delivery/sprint-snapshots/<id>.md` (`type: delivery`): progress per feature, decisions of the sprint (from meetings / ADR), open 🎯 actions (owner, due), 🚫 blockers, drift found in the period, meetings held. Link it from `index.md`.

## Phase 4 - Lint (`--lint`, always at the end of `--full`)

1. Deterministic checks:

    ```powershell
    pwsh llm-wiki/.engine/scripts/Test-WikiLint.ps1 -WikiPath llm-wiki/wiki -StaleAfterDays <governance.stale_after_days> -ReportPath llm-wiki/wiki/lint-<YYYY-MM-DD>.md
    ```

2. Fix the safe issues: missing front matter fields on draft pages, broken links with an obvious target, missing `index.md` entries, legacy `[[...]]` links. Re-run until no new safe fixes remain.
3. Never auto-fix: `SEC001` (remove the secret and tell the user immediately - it may need rotation), certified pages, contradictions, drift.
4. Semantic review (LLM, only pages changed since the previous lint): contradictions between pages, missing concept/entity pages, claims without sources.
5. Summarise errors / warnings / status counts (draft, reviewed, certified) and requirement coverage.

## Phase 5 - Publish (`--publish`)

Read `.engine/publishing.md` and follow its procedure: lint without errors -> clone target wiki -> `Export-Wiki.ps1` -> review warnings -> confirm (interactive) or `publish.headless` (headless) -> push -> verify.

## Lifecycle requests (`--review`, `--certify`)

Only on an explicit request from a person who names the reviewer/certifier. Set `status: reviewed` + `reviewed_by` or `status: certified` + `certified_by` + `certified_at` (today) on the named page, without changing its content; log the change. Never in headless mode. When a certified page has a `## 🔄 Pending updates` section, ask whether to apply the updates (status returns to `draft`) or keep them pending.

## Phase 6 - Bookkeeping

Append one entry per phase to `wiki/log.md`:

```markdown
## [YYYY-MM-DD] update --source code | <repo>

- Revision: <repo>@<rev> (previous <rev>)
- Inventory: `raw/code/<repo>-<date>.json` (plugins N, PCF N, Ax objects N)
- Pages created: <links>  Pages updated: <links>
- Traceability: requirements linked N; drift flagged N
- Files read: N
```

Lint entry: errors / warnings / info, report path. Publish entry: target, pages, pushed commit. `--full` adds a summary entry with `pendingKB` from `Get-RawDelta.ps1`.

## Headless rules

No questions; values from `wiki.config.yml`; dirty working trees and missing credentials are reported, not worked around; pages stay `draft`; no lifecycle changes; publish only with `publish.headless: true`; finish with lint and a pull request.
