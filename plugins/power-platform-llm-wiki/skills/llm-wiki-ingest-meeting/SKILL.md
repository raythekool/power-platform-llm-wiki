---
name: llm-wiki-ingest-meeting
description: "This skill should be used when the user asks to 'ingest llm-wiki/raw/meetings/...', drops meeting notes in llm-wiki/raw/meetings/, or mentions ingesting meeting minutes. Creates a structured synthesis with participants, decisions, action items, and blockers — not a verbatim copy."
---

# Skill: Ingest Meeting

Ingest meeting minutes from `llm-wiki/raw/meetings/`. Creates a structured synthesis — not a copy.

## Ownership

| Scope            | Permission                                                    |
| ---------------- | ------------------------------------------------------------- |
| `llm-wiki/raw/`           | **READ only** — never write, convert, or modify files in llm-wiki/raw/ |
| `llm-wiki/wiki/meetings/` | WRITE — create synthesis pages                                          |
| `llm-wiki/wiki/` (other)  | WRITE — update related pages                                            |
| `llm-wiki/wiki/index.md`  | WRITE — add new entries                                                 |
| `llm-wiki/wiki/log.md`    | APPEND only                                                             |

> **Important:** This skill does NOT convert files. If the source is not `.md` or `.txt`, it must be converted **before** calling this skill. If a `.md` conversion exists alongside the original, read the `.md` version.

## Input

- `FILE_PATH` — path to the meeting **markdown** file (e.g., `llm-wiki/raw/meetings/2026-04-28-sprint-review.md`)

## Steps

1. **Locate readable file.** If `FILE_PATH` is not `.md`/`.txt`, check if a `.md` conversion exists alongside it. If not, **stop** and ask the user to convert first.

2. **Read the meeting document** completely.

3. **Read `llm-wiki/wiki/index.md`** to find related pages.

4. **Extract structured data:**
   - **Participants** — who was present
   - **Decisions** — what was decided
   - **Action items** — who does what by when (flag with 🎯)
   - **Discussion points** — key topics and positions
   - **Blockers** — what is blocked and why (flag with 🚫)

5. **Create a meeting synthesis page** at `llm-wiki/wiki/meetings/<date>-<slug>.md` with frontmatter:
   ```yaml
   ---
   type: meeting
   date: YYYY-MM-DD
   participants: [Name1, Name2]
   status: active
   tags: [sprint-review, topic]
   ---
   ```
   Sections: TL;DR, Participants, Decisions, Action Items, Discussion Points, Blockers, Cross-References, Source References.

6. **Update related pages:**
   - **Feature pages** — decisions, action items, status changes
   - **Project pages** — what was discussed
   - **Entity pages** — action items per participant
   - **Decision pages** — create/update ADR if applicable

7. **Flag contradictions** with `> ⚠️ **Contradiction:**`.

8. **Update `llm-wiki/wiki/index.md`** — add under **Meetings**.

9. **Append to `llm-wiki/wiki/log.md`**:
    ```
    ## [YYYY-MM-DD] ingest-meeting | <slug>
    - Participants: Name1, Name2
    - Decisions: N, Action items: M
    - Pages created: [[meetings/<date>-<slug>]]
    - Pages updated: [[list]]
    - Processed <FILE_PATH>
    ```

## Output

Report: meeting summary, decisions, action items with owners/deadlines, contradictions.
