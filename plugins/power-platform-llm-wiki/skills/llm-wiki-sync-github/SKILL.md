---
name: llm-wiki-sync-github
description: "This skill should be used when the user asks to 'sync github', 'update repos', 'pull github', 'analyze the code', or 'update code wiki'. Pulls repository info, branches, PRs, and source code via MCP and gh CLI, dumps to llm-wiki/raw/github/, then processes into llm-wiki/wiki/projects/ and llm-wiki/wiki/code/."
---

# Skill: Sync GitHub

Pull repository info, branches, PRs, and activity from GitHub via MCP, dump to `llm-wiki/raw/github/`, then process into llm-wiki/wiki/. Use `gh api` REST fallback to read source code from non-default branches.

## Ownership

| Scope             | Permission                                           |
| ----------------- | ---------------------------------------------------- |
| `llm-wiki/raw/github/`     | WRITE — dump MCP/gh query results (JSON + MD + src/) |
| `llm-wiki/wiki/projects/`  | WRITE — create/update project pages                  |
| `llm-wiki/wiki/code/`      | WRITE — create/update code analysis pages            |
| `llm-wiki/wiki/index.md`   | WRITE — add new entries                              |
| `llm-wiki/wiki/log.md`     | APPEND only                                          |
| `llm-wiki/wiki.config.yml` | READ only                                            |

This skill owns the `llm-wiki/raw/github/` → `llm-wiki/wiki/projects/` + `llm-wiki/wiki/code/` pipeline. It does NOT touch other `llm-wiki/raw/` subdirectories.

## Prerequisites

- GitHub MCP server configured. Tools: list repos, get repo info, list branches, list PRs, list issues, list commits.
- `gh` CLI installed and authenticated (`gh auth status`) — required for reading files from non-default branches.

## Configuration

Read `llm-wiki/wiki.config.yml` → `github` section for: `repos` (list of repos to track), `branch_patterns` (regex filters).

## Steps

### Phase 1 — Query & Dump to llm-wiki/raw/

1. **Read `llm-wiki/wiki.config.yml`** to get the list of repos to track.

2. **List repositories** via GitHub MCP. If `repos` is specified in config, only sync those. Otherwise discover repos via MCP.

3. **For each repo**, collect via MCP:
   - Repository metadata (description, default branch, visibility)
   - Branches (filter by `branch_patterns` from config)
   - Open Pull Requests (title, author, source/target branch, status)
   - Recent commits on tracked branches
   - Open issues (if any)

4. **Read source code from non-default branches** via `gh api` REST fallback:
   ```powershell
   # Read a single file
   gh api "repos/{owner}/{repo}/contents/{path}?ref={branch}" -H "Accept: application/vnd.github.v3.raw"

   # List directory contents (returns JSON array)
   gh api "repos/{owner}/{repo}/contents/{path}?ref={branch}"

   # Read multiple files
   $files = @("path/File1.cs", "path/File2.cs")
   foreach ($f in $files) {
       gh api "repos/{owner}/{repo}/contents/$($f)?ref={branch}" -H "Accept: application/vnd.github.v3.raw"
   }
   ```
   **Why:** The GitHub MCP proxy (`api.githubcopilot.com/mcp/`) does NOT support `ref`/`sha` parameters on `get_file_contents`. It only reads from the default branch.

   **What to read:** Focus on key source files (plugins, components, configs, README) to produce functional descriptions — not just file listings.

   **Decision matrix:**
   | What you need                             | Tool                                       |
   | ----------------------------------------- | ------------------------------------------ |
   | Repo metadata, branches, PRs, commits     | GitHub MCP                                 |
   | File contents from **default branch**     | GitHub MCP `get_file_contents`             |
   | File contents from **non-default branch** | `gh api` REST fallback                     |
   | Directory listing on non-default branch   | `gh api` (without `Accept: raw`)           |
   | Commit diffs                              | GitHub MCP `get_commit(include_diff=true)` |

5. **Save JSON dump** to `llm-wiki/raw/github/<repo>-YYYY-MM-DD.json` — structured JSON with all collected data (repo info, branches, PRs, commits, code structure). Same-day re-syncs overwrite the previous file.

6. **Save MD dump** to `llm-wiki/raw/github/<repo>-YYYY-MM-DD.md` — human-readable Markdown summary: repo overview, branch table, PR table, recent commit list, code component descriptions.

### Phase 2 — Process from llm-wiki/raw/ into llm-wiki/wiki/

7. **Read `llm-wiki/wiki/index.md`** to understand existing project and feature pages.

8. **Read the dump files** (`llm-wiki/raw/github/<repo>-YYYY-MM-DD.json` or `.md`).

9. **For each repo**, create or update `llm-wiki/wiki/projects/<repo>.md` with frontmatter:
   ```yaml
   ---
   type: project
   project: repo-name
   date: YYYY-MM-DD
   status: active
   tags: [backend, frontend, infra]
   ---
   ```
   Sections: TL;DR, Repository Info, Branch Strategy, Code Components (**with functional descriptions of what the code does**), Active Branches (table), Open Pull Requests (table), Recent Activity, Related Features, Change Log.

10. **Cross-reference branches with features** — match `feature/F-42-auth` → `F-42`. Update both pages.

11. **Track PR activity** — open PRs, recently merged, link to features.

### Phase 3 — Bookkeeping

12. **Update `llm-wiki/wiki/index.md`** — add new projects under **Projects**.

13. **Append to `llm-wiki/wiki/log.md`**:
    ```
    ## [YYYY-MM-DD] sync-github | Full sync
   - Source: GitHub MCP + `gh api` → `llm-wiki/raw/github/<repo>-YYYY-MM-DD.json`
    - Repos scanned: N
    - Active branches: M, Open PRs: K
    - Source files read via gh api: L
    - Pages created: [[list]]
    - Pages updated: [[list]]
    ```

## Code Analysis

When asked to "analyze the code" or "update code wiki", perform a deep code analysis:

### Phase A — Source Acquisition

1. **List all branches** via `gh api repos/{owner}/{repo}/branches --jq ".[].name"`
2. **Get full file tree** for each active branch:
   ```powershell
   gh api repos/{owner}/{repo}/git/trees/{branch}?recursive=1 --jq "[.tree[] | select(.type==""blob"")] | .[].path"
   ```
3. **Download source files** to `llm-wiki/raw/github/src/<repo>/`:
   ```powershell
   $files = @("path/File1.cs", "path/File2.cs")
   foreach ($f in $files) {
       $dest = Join-Path $outDir $f
       $dir = Split-Path $dest -Parent
       if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
       gh api "repos/{owner}/{repo}/contents/$($f)?ref={branch}" -H "Accept: application/vnd.github.v3.raw" | Set-Content -Path $dest -Encoding UTF8
   }
   ```
   Skip binary files (`.snk`, `.png`, images, `package-lock.json`). Focus on source code, configs, and documentation.

### Phase B — Analysis & Wiki Generation

4. **Read all downloaded source files** from `llm-wiki/raw/github/src/<repo>/`.
5. **Create/update `llm-wiki/wiki/code/index.md`** with repository layout and page catalog.
6. **Create/update per-component pages** in `llm-wiki/wiki/code/`:
   - `architecture.md` — tech stack, data flow, plugin/API maps, entity matrix, known issues
   - One page per major component (e.g., `plugin.md`, `pcf.md`, `web-resources.md`, `batch.md`)
   - For each file: purpose, class/function inventory, key logic, Dataverse entities used, dependencies
   - **Include Mermaid diagrams** — every `llm-wiki/wiki/code/` page must have at least one:
     - Architecture pages: `graph TD` (component), `flowchart LR` (data flow), `erDiagram` (entities)
     - Plugin/API pages: `sequenceDiagram` (call flow), `classDiagram` (DTOs)
     - Pipeline pages: `flowchart LR` (build/deploy steps), `sequenceDiagram` (pipeline stages)
     - Replace ASCII art with Mermaid equivalents
7. **Update `llm-wiki/wiki/index.md`** with Code Documentation section.
