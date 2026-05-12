---
name: llm-wiki-ingest
description: "This skill should be used when the user asks to 'ingest llm-wiki/raw/...', 'add this to the wiki', or refers to a file in llm-wiki/raw/. Reads llm-wiki/raw/ sources (markdown only), writes summary pages to llm-wiki/wiki/reference/sources/, and updates related wiki pages. Does NOT convert files — non-markdown sources must be converted before calling this skill."
---

# Skill: Ingest Source

Ingest a file from `llm-wiki/raw/` into the wiki.

## Ownership

| Scope              | Permission                                                    |
| ------------------ | ------------------------------------------------------------- |
| `llm-wiki/raw/`             | **READ only** — never write, convert, or modify files in llm-wiki/raw/ |
| `llm-wiki/wiki/`            | WRITE — create/update pages                                             |
| `llm-wiki/wiki/index.md`    | WRITE — add new entries                                                 |
| `llm-wiki/wiki/overview.md` | WRITE — update if big picture changes                                   |
| `llm-wiki/wiki/log.md`      | APPEND only                                                             |

> **Important:** This skill does NOT convert files. If the source is not `.md` or `.txt`, the file must be converted **before** calling this skill (via `markitdown` CLI or MCP, or by the `llm-wiki-full-update` orchestrator). If a `.md` conversion already exists alongside the original, read the `.md` version.

## Input

- `FILE_PATH` — path to the **markdown** file in `llm-wiki/raw/` (e.g., `llm-wiki/raw/analysis/auth-study.md`)

## Steps

1. **Locate readable file.** If `FILE_PATH` is not `.md`/`.txt`, check if a `.md` conversion exists alongside it (same name, `.md` extension). If not, **stop** and ask the user to convert first.

2. **Read the source content** completely.

3. **Read `llm-wiki/wiki/index.md`** to understand existing wiki pages and find related content.

4. **Identify the source type**: meeting, analysis, spec, ADR, MCP dump, etc.
    - If the file is in `llm-wiki/raw/meetings/`, switch to `llm-wiki-ingest-meeting` instead.
    - If the file is in `llm-wiki/raw/devops/` or `llm-wiki/raw/github/`, these are MCP sync dumps — use `llm-wiki-sync-devops` or `llm-wiki-sync-github` instead.

5. **Discuss key takeaways** with the user.

6. **Create a summary page** at `llm-wiki/wiki/reference/sources/<slug>.md` with YAML frontmatter (`type: source`) and sections: TL;DR, Key Points, Cross-References, Source References.

7. **Update related pages** — add new info, flag contradictions with `> ⚠️ **Contradiction:**`, update cross-references.

8. **Create new pages** if the source introduces new projects, features, concepts, or entities.

9. **Update `llm-wiki/wiki/index.md`** — add entries under the appropriate category.

10. **Update `llm-wiki/wiki/overview.md`** if the source changes the big picture.

11. **Append to `llm-wiki/wiki/log.md`**:
    ```
    ## [YYYY-MM-DD] ingest | <source-name>
    - Source: `<FILE_PATH>`
    - Pages created: [[reference/sources/<slug>]]
    - Pages updated: [[list]]
    - Processed <FILE_PATH>
    ```

## Output

Report: summary of the source, pages created/updated, contradictions flagged.
