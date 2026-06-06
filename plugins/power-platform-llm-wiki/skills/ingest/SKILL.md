---
name: ingest
description: "Process a source file from llm-wiki/raw/ into the wiki: identify type (meeting / analysis / spec / ADR / generic), create the appropriate synthesis page, update related wiki pages, flag contradictions. Meetings produce a structured synthesis (participants, decisions, action items, blockers) — not a verbatim copy. Auto-detects type from path; user can override with --type."
argument-hint: "<file-path-in-raw> [--type meeting|spec|analysis|adr|generic]"
user-invocable: true
disable-model-invocation: false
context: fork
---

# Ingest Source into LLM Wiki

Process a single markdown source from `llm-wiki/raw/` and integrate it into `llm-wiki/wiki/`. Auto-detects the source type and routes to the right synthesis flow.

## When to Use

- The user dropped a file in `llm-wiki/raw/` and asks to add it to the wiki
- Processing meeting minutes from `raw/meetings/`
- Ingesting analysis docs, specs, ADRs, or generic notes
- Re-ingesting a source after the original was updated

For bulk ingest of all unprocessed files in `raw/`, use `update --full` instead.

## Ownership

| Scope                          | Permission                                                       |
| ------------------------------ | ---------------------------------------------------------------- |
| `raw/`                         | **READ only** — never write, convert, or modify files in raw/    |
| `wiki/meetings/`               | WRITE — create meeting synthesis pages                           |
| `wiki/reference/sources/`      | WRITE — create generic source summary pages                      |
| `wiki/reference/decisions/`    | WRITE — create/update ADRs                                       |
| `wiki/` (other)                | WRITE — update related pages (features, projects, entities)      |
| `wiki/index.md`                | WRITE — add new entries                                          |
| `wiki/overview.md`             | WRITE — update if big picture changes                            |
| `wiki/log.md`                  | APPEND only                                                      |

> **Important:** This skill does NOT convert files. If the source is not `.md`/`.txt`, a `.md` conversion must already exist alongside it (run `markitdown` first, or use `update --full` which converts automatically).

## Input

- `FILE_PATH` — path to the markdown source inside `raw/` (e.g., `llm-wiki/raw/meetings/2026-04-28-sprint-review.md`).
- `--type` (optional) — override the auto-detected type. Values: `meeting`, `spec`, `analysis`, `adr`, `generic`.

## Procedure

### Step 1 — Locate the readable file

1. Verify `FILE_PATH` exists.
2. If it is not `.md` or `.txt`, check whether a `.md` conversion exists alongside it (same name, `.md` extension).
3. If no markdown version is available, **stop** and ask the user to convert it (`markitdown <path>` or run `update --full`).

### Step 2 — Detect type

Detection rules (`--type` overrides all):

| Path / Heuristic                                                | Detected type |
| --------------------------------------------------------------- | ------------- |
| `raw/meetings/...`                                              | `meeting`     |
| `raw/specs/...`                                                 | `spec`        |
| `raw/analysis/...`                                              | `analysis`    |
| `raw/adrs/...` or content has `# ADR-` heading                  | `adr`         |
| `raw/devops/...`, `raw/github/...`, `raw/dataverse/...`         | `dump` (skip — use `update --source ...` instead) |
| Anything else                                                   | `generic`     |

If detection is `dump`, stop and tell the user to use the appropriate `update --source` mode.

### Step 3 — Pre-flight read

1. Read the source content completely.
2. Read `wiki/index.md` to know existing pages.
3. For meetings, also read related feature/project/entity pages mentioned in the source so the synthesis can cross-reference correctly.

### Step 4 — Discuss key takeaways (interactive mode only)

In interactive mode, summarise the source to the user and confirm the synthesis approach before writing. Skip in headless mode.

### Step 5 — Type-specific synthesis

#### A) Meeting

Extract structured data:
- **Participants** — who was present
- **Decisions** — what was decided
- **Action items** — who does what by when (flag with 🎯)
- **Discussion points** — key topics and positions
- **Blockers** — what is blocked and why (flag with 🚫)

Create `wiki/meetings/<date>-<slug>.md` with frontmatter:

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

Update related pages:
- **Feature pages** — decisions, action items, status changes
- **Project pages** — what was discussed
- **Entity pages** — action items per participant
- **Decision pages** — create/update ADR if a formal decision was reached

#### B) ADR

Create or update `wiki/reference/decisions/ADR-NNN-<slug>.md` with frontmatter:

```yaml
---
type: decision
adr_id: "ADR-NNN"
date: YYYY-MM-DD
status: proposed | accepted | superseded | deprecated
tags: [topic]
---
```

Sections: Context, Decision, Consequences, Alternatives Considered, Source References. Link the ADR from the related feature/project pages.

#### C) Spec

Create `wiki/reference/sources/<slug>.md` with frontmatter (`type: source`, `tags: [spec]`). Synthesise:
- Scope and out-of-scope
- Functional requirements (linked to features when matching)
- Non-functional requirements
- Open questions / 🎯 action items
- Cross-references

#### D) Analysis

Create `wiki/reference/sources/<slug>.md` with frontmatter (`type: source`, `tags: [analysis]`). Synthesise:
- TL;DR
- Findings
- Recommendations
- Open questions
- Cross-references

#### E) Generic

Create `wiki/reference/sources/<slug>.md` with frontmatter (`type: source`). Sections: TL;DR, Key Points, Cross-References, Source References.

### Step 6 — Update related pages

For every page that should reference the new content:
- Add a cross-reference under "Related" or in the relevant section.
- Add new info to existing sections when applicable.
- **Flag contradictions** with `> ⚠️ **Contradiction:** [[Page A]] says X, but the new source says Y. Unresolved.`
- Keep existing content intact — never silently overwrite.

### Step 7 — Create missing entity / concept / project pages

If the source introduces a new person/team, system, technical concept, or project, create the corresponding page in `wiki/reference/entities/`, `wiki/reference/concepts/`, or `wiki/projects/` before linking to it.

### Step 8 — Update catalogs

1. **`wiki/index.md`** — add the new page under the right category (Meetings, Reference → Sources, Reference → Decisions, etc.).
2. **`wiki/overview.md`** — update only if the source changes the big picture.

### Step 9 — Bookkeeping

Append to `llm-wiki/wiki/log.md`. Use the entry that matches the detected type:

```
## [YYYY-MM-DD] ingest | <type> | <slug>
- Source: `<FILE_PATH>`
- Type: <meeting|spec|analysis|adr|generic>
- Pages created: [[list]]
- Pages updated: [[list]]
- Contradictions flagged: <count>
```

For meetings, also include:

```
- Participants: <list>
- Decisions: <count>, Action items: <count>, Blockers: <count>
```

## Output

Report to the user:
- Source summary
- Pages created and pages updated
- Contradictions flagged for review
- For meetings: decisions, action items (with owner + due date), blockers

## Notes

- **Never modifies `raw/` files.** Reads only. Conversions happen outside this skill.
- **Synthesises, never copies.** Meeting pages must extract structured data, not paste the transcript.
- **One pass per source.** Re-running on the same file produces an idempotent update (no duplicate sections, no duplicate index entries).
- **Cross-references are mandatory.** Every new page must link to at least one existing wiki page; if no relevant page exists, create the entity/concept page first.
- For MCP dump files (`raw/devops/`, `raw/github/`, `raw/dataverse/`), use `update --source ...` instead — those have dedicated processing logic.

## Resources

- See `update --full` to process every unprocessed file in `raw/` automatically.
- See `query` to ask questions against the ingested content.
