---
name: llm-wiki-sprint-snapshot
description: "This skill should be used when the user asks for a 'sprint snapshot', 'sprint report', or 'sprint status'. Generates a sprint status report by collecting active features, recent meetings, open action items, and blockers from llm-wiki/wiki/ data."
---

# Skill: Sprint Snapshot

Generate a sprint status report from wiki data.

## Ownership

| Scope                          | Permission                     |
| ------------------------------ | ------------------------------ |
| `llm-wiki/wiki/`                          | READ — all pages               |
| `llm-wiki/wiki/delivery/sprint-snapshots/` | WRITE — generate snapshot page |
| `llm-wiki/wiki/index.md`                  | WRITE — add snapshot entry     |
| `llm-wiki/wiki/log.md`                    | APPEND only                    |
| `llm-wiki/raw/`                           | NO ACCESS                      |

## Input

- `SPRINT_ID` (optional) — e.g., `2026-S08`. Auto-detect if not provided.

## Steps

1. **Read `llm-wiki/wiki/index.md`**.

2. **Collect active features** — `llm-wiki/wiki/features/*.md` with `status: active` and matching sprint.

3. **Collect recent meetings** from the sprint period.

4. **Collect open 🎯 action items** across all pages.

5. **Collect 🚫 blockers** across all pages.

6. **Generate snapshot** at `llm-wiki/wiki/delivery/sprint-snapshots/<ID>.md` with frontmatter (`type: delivery`, `sprint`) and sections:
   - Progress Summary (feature table: Feature, Status, Progress, Key Updates)
   - Key Decisions This Sprint
   - Open Action Items (table: Owner, Action, Due, Source)
   - Blockers & Risks
   - Meetings This Sprint

7. **Update `llm-wiki/wiki/index.md`** and **append to `llm-wiki/wiki/log.md`**.

## Output

Sprint progress per feature, action items, blockers, key decisions.
