---
name: llm-wiki-lint
description: "This skill should be used when the user asks to 'lint the wiki', 'health check', or at the end of a scheduled run. Finds contradictions, stale data, dead links, orphan pages, DevOps drift, and overdue action items in llm-wiki/wiki/. Auto-fixes safe issues, flags the rest for human review."
---

# Skill: Lint Wiki

Health-check the wiki. Find issues, auto-fix safe ones, flag the rest.

## Ownership

| Scope            | Permission                                          |
| ---------------- | --------------------------------------------------- |
| `llm-wiki/wiki/`          | READ + WRITE — scan all pages, auto-fix safe issues |
| `llm-wiki/wiki/lint-*.md` | WRITE — generate lint report                        |
| `llm-wiki/wiki/log.md`    | APPEND only                                         |
| `llm-wiki/raw/`           | NO ACCESS                                           |

This skill may auto-fix: dead links, missing frontmatter fields, orphan page references. It flags contradictions and drift for human review.

## Steps

1. **Scan all pages** in `llm-wiki/wiki/` recursively.

2. **Check for:**

   | Issue                                         | Action                         |
   | --------------------------------------------- | ------------------------------ |
   | Dead `[[references]]`                         | Auto-fix or flag               |
   | Orphan pages (no backlinks)                   | Report                         |
   | Contradictions (same claim, different values) | Flag: `> ⚠️ **Contradiction:**` |
   | Stale claims (>30 days, no update)            | Flag: `> 🕐 **Stale:**`         |
   | Stale 🎯 action items (past due)               | Report with list               |
   | Missing concept pages                         | Report                         |
   | DevOps drift (wiki ≠ MCP data)                | Flag: `> ⚠️ **Drift:**`         |
   | Missing YAML frontmatter                      | Auto-fix                       |

3. **Auto-fix safe issues** — dead refs, missing cross-refs, missing frontmatter.

4. **Flag unsafe issues** for human review — contradictions, stale claims.

5. **Generate report** at `llm-wiki/wiki/lint-YYYY-MM-DD.md` with sections per issue type.

6. **Append to `llm-wiki/wiki/log.md`**.

## Output

Report: issues by category, auto-fixes applied, items needing human attention.
