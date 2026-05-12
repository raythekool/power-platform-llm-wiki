---
name: llm-wiki-sync-devops
description: "This skill should be used when the user asks to 'sync devops', 'update devops', or 'pull work items'. Pulls Features, User Stories, and Tasks from Azure DevOps via MCP, dumps to llm-wiki/raw/devops/, then processes into llm-wiki/wiki/features/ and llm-wiki/wiki/projects/."
---

# Skill: Sync DevOps

Pull Features, User Stories, and Tasks from Azure DevOps via MCP, dump to `llm-wiki/raw/devops/`, then process into llm-wiki/wiki/.

## Ownership

| Scope             | Permission                                        |
| ----------------- | ------------------------------------------------- |
| `llm-wiki/raw/devops/`     | WRITE — dump MCP query results (JSON + MD)        |
| `llm-wiki/wiki/features/`  | WRITE — create/update feature pages               |
| `llm-wiki/wiki/projects/`  | WRITE — update project pages with work item links |
| `llm-wiki/wiki/index.md`   | WRITE — add new entries                           |
| `llm-wiki/wiki/log.md`     | APPEND only                                       |
| `llm-wiki/wiki.config.yml` | READ only                                         |

This skill owns the `llm-wiki/raw/devops/` → `llm-wiki/wiki/features/` pipeline. It does NOT touch other `llm-wiki/raw/` subdirectories.

## Prerequisites

Azure DevOps MCP server configured. Tools: `wit_query_by_wiql`, `wit_get_work_item`, `wit_list_work_items`.

## Configuration

Read `llm-wiki/wiki.config.yml` → `devops` section for: `area_paths`, `iteration_prefix`, `work_item_types`, `excluded_states`.

## Steps

### Phase 1 — Query & Dump to llm-wiki/raw/

1. **Read `llm-wiki/wiki.config.yml`** to get the DevOps area paths and work item types.

2. **Query active work items** via MCP WIQL (adapt filters based on config):
   ```sql
   SELECT [System.Id], [System.Title], [System.State], [System.AssignedTo], [System.IterationPath]
   FROM WorkItems
   WHERE [System.WorkItemType] IN (<work_item_types from config>)
     AND [System.State] NOT IN (<excluded_states from config>)
     -- AND [System.AreaPath] UNDER '<area_path>'  (if configured)
     -- AND [System.IterationPath] UNDER '<iteration_prefix>'  (if configured)
   ORDER BY [System.WorkItemType], [System.Id]
   ```

3. **Batch-get work item details** via MCP for all IDs returned by the query.

4. **Save JSON dump** to `llm-wiki/raw/devops/work-items-YYYY-MM-DD.json` — the full structured API response (all fields, relations, parent-child links). Same-day re-syncs overwrite the previous file.

5. **Save MD dump** to `llm-wiki/raw/devops/work-items-YYYY-MM-DD.md` — a human-readable Markdown rendering of the same data (tables grouped by type: Features, User Stories, Tasks, with columns: ID, Title, State, Assigned To, Iteration, Parent).

### Phase 2 — Process from llm-wiki/raw/ into llm-wiki/wiki/

6. **Read `llm-wiki/wiki/index.md`** to understand existing feature and project pages.

7. **Read the dump files** (`llm-wiki/raw/devops/work-items-YYYY-MM-DD.json` or `.md`).

8. **For each Feature**, create or update `llm-wiki/wiki/features/<id>-<slug>.md` with frontmatter:
   ```yaml
   ---
   type: feature
   devops_id: "F-<ID>"
   project: repo-name
   branch: feature/branch-name
   sprint: "YYYY-SNN"
   date: YYYY-MM-DD
   status: active | completed | blocked
   tags: [area, topic]
   ---
   ```
   Sections: TL;DR, User Stories (list), Tasks (table with ID/Title/State/Assigned/Sprint), Cross-References, Change Log.

9. **Map parent-child** — Feature → User Stories → Tasks.

10. **Update project pages** with new/changed work items.

11. **Detect drift** — flag with `> ⚠️ **Drift:** Wiki says X, DevOps shows Y.`

12. **Track blockers** — flag with `> 🚫 **Blocked:**`.

### Phase 3 — Bookkeeping

13. **Update `llm-wiki/wiki/index.md`** — add new features under **Features**.

14. **Append to `llm-wiki/wiki/log.md`**:
    ```
    ## [YYYY-MM-DD] sync-devops | Full sync
   - Source: Azure DevOps MCP → `llm-wiki/raw/devops/work-items-YYYY-MM-DD.json`
    - Work items processed: N Features, M User Stories, K Tasks
    - Pages created: [[list]]
    - Pages updated: [[list]]
    - Drift detected: ...
    ```

## Output

Report: work items synced, raw dump files created, pages created, drift detected, blockers found.
