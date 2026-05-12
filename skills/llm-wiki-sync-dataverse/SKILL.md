---
name: llm-wiki-sync-dataverse
description: "This skill should be used when the user asks to 'sync dataverse', 'pull solution', 'update datamodel', or 'analyze solution'. Exports Dataverse solutions via PAC/PACX, dumps metadata to llm-wiki/raw/dataverse/, then processes into llm-wiki/wiki/code/ pages (datamodel, plugins, forms, views, roles, flows, architecture)."
---

# Skill: Sync Dataverse

Export Dataverse solutions, analyze their metadata via PAC/PACX, dump to `llm-wiki/raw/dataverse/`, then process into llm-wiki/wiki/.

## Ownership

| Scope             | Permission                                                                              |
| ----------------- | --------------------------------------------------------------------------------------- |
| `llm-wiki/raw/dataverse/`  | WRITE — export solutions, scripts, metadata                                             |
| `llm-wiki/wiki/code/`      | WRITE — create/update datamodel, plugin, forms, views, roles, flows, architecture pages |
| `llm-wiki/wiki/index.md`   | WRITE — add new entries                                                                 |
| `llm-wiki/wiki/log.md`     | APPEND only                                                                             |
| `llm-wiki/wiki.config.yml` | READ only                                                                               |

This skill owns the `llm-wiki/raw/dataverse/` → `llm-wiki/wiki/code/` pipeline. It does NOT touch other `llm-wiki/raw/` subdirectories.

## Prerequisites

- **PACX** auth profile configured and selected (`pacx auth select -n <profile>` + `pacx auth ping`).
- **PAC CLI** installed (`pac solution list` to verify).
- Both tools connect to the same Dataverse environment.

## Configuration

Read `llm-wiki/wiki.config.yml` → `dataverse` section for: `solutions` (list of solutions to analyze), `publisher_prefixes` (custom table prefixes), `components` (which component types to include).

## Steps

### Phase 1 — Export & Dump to llm-wiki/raw/

1. **Read `llm-wiki/wiki.config.yml`** to get the Dataverse solution list, prefixes, and component flags.

2. **Verify connection:**

   ```powershell
   pacx auth ping
   ```

   If it fails, ask the user to configure a profile (`pacx auth create`).

3. **Resolve solution list.** For each entry in `solutions`:
   - `name: "X"` → use directly
   - `publisher: "ava"` → run `pacx solution list`, filter by publisher
   - `pattern: "ava_*"` → run `pacx solution list`, match pattern

4. **For each solution**, collect data into `llm-wiki/raw/dataverse/<solution>-YYYY-MM-DD/`:

   a. **Export solution .zip** (unmanaged):

   ```powershell
   pac solution export --name <SolutionName> --path "llm-wiki/raw/dataverse/<solution>-YYYY-MM-DD.zip" --managed false
   ```

   Extract to `llm-wiki/raw/dataverse/<solution>-YYYY-MM-DD/` for XML analysis. The .zip is gitignored.

   b. **Reverse-engineer data model** via PACX:

   ```powershell
   pacx script solution `
     --solution <SolutionName> `
     --output "llm-wiki/raw/dataverse/<solution>-YYYY-MM-DD/" `
     --includeStateFields
   ```

   Produces: `pacx_datamodel_script.ps1` (all table/column/relationship commands) + `states-definition.csv`.

   c. **Generate ER diagram** (Mermaid):

   ```powershell
   pacx table print --solution <SolutionName> > "llm-wiki/raw/dataverse/<solution>-YYYY-MM-DD/er-diagram.md"
   ```

   d. **List plugins:**

   ```powershell
   pacx plugin list --solution <SolutionName> > "llm-wiki/raw/dataverse/<solution>-YYYY-MM-DD/plugins.txt"
   ```

   e. **Export per-table metadata** (if `components.tables` is true):

   ```powershell
   # For each custom table in the solution
   pacx table exportMetadata --table <logicalname> > "llm-wiki/raw/dataverse/<solution>-YYYY-MM-DD/tables/<logicalname>.json"
   ```

5. **Save human-readable summary** to `llm-wiki/raw/dataverse/<solution>-YYYY-MM-DD.md`:
   - Solution name, version, publisher
   - Table count, plugin count, flow count
   - Link to subdirectory with detailed files

### Phase 2 — Process from llm-wiki/raw/ into llm-wiki/wiki/

6. **Read `llm-wiki/wiki/index.md`** to understand existing code and project pages.

7. **Read all dump files** from `llm-wiki/raw/dataverse/<solution>-YYYY-MM-DD/`.

8. **Create/update wiki/code/ pages** based on `components` flags:

   #### `llm-wiki/wiki/code/datamodel.md` — Dataverse Data Model

   - Include the Mermaid ER diagram from `er-diagram.md`
   - Table inventory: logical name, display name, description, ownership type
   - For each table: columns (name, type, required, description), relationships (N:1, N:N), alternative keys
   - Global option sets with values
   - State/status code definitions from `states-definition.csv`
   - Use frontmatter: `type: source`, `tags: [dataverse, datamodel]`

   #### `llm-wiki/wiki/code/plugin.md` — Plugins & Custom APIs

   - Plugin inventory table: class name, entity, message (Create/Update/Delete/etc.), stage (PreValidation/PreOperation/PostOperation), mode (Sync/Async), execution order
   - Pre/post images registered
   - Filtering attributes
   - Group by entity for readability
   - Include `sequenceDiagram` showing plugin execution order per entity
   - Cross-reference with `[[code/datamodel]]` for entity links

   #### `llm-wiki/wiki/code/forms.md` — Forms

   Parse `customizations.xml` from the extracted solution:
   - List all forms per entity (main, quick create, quick view, card)
   - For each main form: tabs, sections, fields (with visibility/required state)
   - Business rules attached to forms
   - Form scripts (JavaScript web resources referenced)
   - Use frontmatter: `type: source`, `tags: [dataverse, forms]`

   #### `llm-wiki/wiki/code/views.md` — Views

   Parse `customizations.xml`:
   - List all views per entity (system views, personal views)
   - For each view: columns displayed, sort order, filter criteria (FetchXML summary)
   - Default view identification
   - Use frontmatter: `type: source`, `tags: [dataverse, views]`

   #### `llm-wiki/wiki/code/roles.md` — Security Roles

   Parse `customizations.xml`:
   - Security role matrix: role name × entity × CRUD privileges (Create/Read/Write/Delete/Append/AppendTo/Assign/Share)
   - Privilege levels: None / User / BU / Parent:Child BU / Organization
   - Present as a table per role
   - Use frontmatter: `type: source`, `tags: [dataverse, security]`

   #### `llm-wiki/wiki/code/flows.md` — Power Automate Flows

   If flows are in the solution:
   - Flow inventory: name, trigger type (automated/instant/scheduled), trigger entity/event
   - Actions summary (high-level steps)
   - Connections used
   - Status (active/draft)

   #### `llm-wiki/wiki/code/architecture.md` — Solution Architecture

   - Solution dependency graph (which solutions depend on which)
   - Component inventory: N tables, M plugins, K flows, etc.
   - Publisher and prefix info
   - Include `graph TD` Mermaid diagram showing solution dependencies
   - Cross-reference with `[[projects/<repo>]]` for source code links

   #### `llm-wiki/wiki/code/index.md` — Code Wiki Index

   - Catalog of all code/ pages with one-line summaries
   - Solution metadata (name, version, last synced date)
   - Link to raw dump files

9. **Cross-reference** with existing wiki pages:
   - Link entities mentioned in `llm-wiki/wiki/features/` pages with `dv:<table>` references
   - Link plugins mentioned in project pages with `plugin:<name>` references
   - Flag drift if wiki pages describe entities that no longer exist in the solution

### Phase 3 — Bookkeeping

10. **Update `llm-wiki/wiki/index.md`** — add new pages under **Code Documentation** section (or create it).

11. **Append to `llm-wiki/wiki/log.md`:**

    ```
    ## [YYYY-MM-DD] sync-dataverse | Solution analysis
   - Source: PAC/PACX → `llm-wiki/raw/dataverse/<solution>-YYYY-MM-DD/`
    - Solutions analyzed: N
    - Tables: M, Plugins: K, Flows: L
    - Pages created: [[list]]
    - Pages updated: [[list]]
    ```

## Output

Report: solutions analyzed, raw dump files created, tables/plugins/flows counted, pages created/updated, drift detected.

## Notes

- `pac solution export` produces the .zip; PACX cannot export solutions.
- The .zip is gitignored (`llm-wiki/raw/dataverse/*.zip`). Only the extracted analysis files are tracked.
- PACX commands require Windows/.NET. If running in CI on Ubuntu, use only `pac` CLI for export and parse the XML directly.
- `pacx table print` outputs Mermaid class diagrams — embed directly in `llm-wiki/wiki/code/datamodel.md`.
- For incremental updates, compare with previous dump files to detect schema changes (added/removed tables, columns, relationships).
