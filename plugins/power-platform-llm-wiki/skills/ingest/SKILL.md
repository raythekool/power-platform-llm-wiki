---
name: ingest
description: "Process one source from llm-wiki/raw/ into the wiki: meeting minutes and Teams transcripts (structured synthesis with decisions, action items, risks), FDD / functional analysis (one requirement page per REQ id), TDD / specs (design pages), ADRs, generic documents. Uses standard templates, updates related pages and the index, flags contradictions, records provenance. Auto-detects the type from the folder; --type overrides."
argument-hint: "<file in llm-wiki/raw/> [--type meeting|fdd|tdd|adr|generic]"
user-invocable: true
---

# Ingest a source

Read `llm-wiki/AGENTS.md` first (page format, links, governance). Templates: `llm-wiki/templates/<name>.md` if present, otherwise `llm-wiki/.engine/templates/<name>.md`; translate headings to `project.language`. For many files at once use `update --full`.

## Ownership

| Scope | Permission |
| --- | --- |
| `llm-wiki/raw/` | READ only |
| `llm-wiki/wiki/` | WRITE (create/update pages, `index.md`, `overview.md`; `log.md` append only) |
| `llm-wiki/.state/` | WRITE through `Get-RawDelta.ps1 -MarkProcessed` |

## Step 1 - Readable input

The file must be `.md` or `.txt`. For other formats use the `.md` sibling with the same name; if missing, convert first (`markitdown <file> -o <file-without-ext>.md`, or the MarkItDown MCP tool) or stop and ask. For a Teams recording (`.mp4`) use a video-analysis skill to produce the transcript, or ask for the Teams transcript.

## Step 2 - Type

| Path / content | Type | Template | Output |
| --- | --- | --- | --- |
| `raw/meetings/`, transcript, minutes | `meeting` | `meeting.md` | `wiki/meetings/<date>-<slug>.md` |
| `raw/analysis/`, FDD, BBP, functional analysis | `fdd` | `requirement.md` | `wiki/requirements/<REQ-ID>-<slug>.md` (one per requirement) + source summary |
| `raw/specs/`, TDD, technical spec | `tdd` | `design.md` | `wiki/design/<slug>.md` + source summary |
| `raw/adrs/` or `# ADR-` heading | `adr` | `adr.md` | `wiki/reference/decisions/ADR-NNN-<slug>.md` |
| `raw/{code,devops,dataverse,fno,github}/` | dump | - | stop: use `update --source ...` |
| anything else | `generic` | `source.md` | `wiki/reference/sources/<slug>.md` |

## Step 3 - Read

Read the whole source, `wiki/index.md`, and the existing pages it is likely to affect (requirements, design, code pages, entities mentioned).

## Step 4 - Confirm (interactive only)

Summarise the source in 3-5 bullets and the pages you plan to create/update. Proceed after confirmation. Skip in headless mode.

## Step 5 - Synthesise by type

### Meeting

- Synthesis, never a transcript copy: executive summary, participants (name, organisation, role), objective, discussion as **question -> answer** per agenda topic, decisions table, 🎯 action items with owner and due date, risks with impact and mitigation, follow-up, references.
- Decisions that change scope or architecture: create or update an ADR and link it.
- Requirements discussed: update the matching requirement pages (new rule, open question, contradiction).
- Participants: create `reference/entities/<name>.md` only for recurring stakeholders (name, organisation, role - no contact data).
- PII (`governance.pii_redaction`): no e-mail addresses, phone numbers or personal details; quotes only when the exact wording matters.

### FDD / functional analysis

- One page per requirement with a stable ID: reuse IDs from the document; otherwise generate `REQ-<AREA>-<NNN>` (area = 3-letter process code) and record the original section in `Source references`.
- Fill business context, functional description, business rules, Given/When/Then acceptance criteria, non-functional requirements, open questions (🎯).
- If a requirement page already exists, update it; changed rules on certified pages go to `## 🔄 Pending updates`.
- Then check `wiki/code/` for components that implement each requirement (names, tables, objects): add links and `implements:` where the evidence is clear; otherwise leave the `Implementation` section to `update --source code`.
- Also create a source summary (`source.md`) listing the requirement pages created.

### TDD / technical spec

- `wiki/design/<slug>.md` with components, data model, integrations, security, deployment; `implements:` with the requirement IDs it covers.
- Compare with `wiki/code/`: where the as-built code differs from the design, flag `⚠️ Drift` on both pages.

### ADR

`wiki/reference/decisions/ADR-NNN-<slug>.md` (next free number if missing), linked from the affected requirement/design/code pages.

### Generic

`wiki/reference/sources/<slug>.md` with TL;DR, key points, impact on the wiki, open questions.

## Step 6 - Update related pages

- Add links in both directions (relative Markdown links).
- Contradictions: `> ⚠️ **Contradiction:** ...` on both pages; never overwrite.
- New concepts, systems, teams: create `reference/concepts/` or `reference/entities/` pages before linking.
- Every new page: `status: draft`, `updated: <today>`, `sources: [raw/...]`.

## Step 7 - Catalog and log

1. Add every new page to `wiki/index.md` under its folder; update `overview.md` only for big-picture changes.
2. Run `pwsh llm-wiki/.engine/scripts/Test-WikiLint.ps1 -WikiPath llm-wiki/wiki` and fix errors on the pages you touched.
3. `pwsh llm-wiki/.engine/scripts/Get-RawDelta.ps1 -RawPath llm-wiki/raw -MarkProcessed <file>`
4. Append to `wiki/log.md`:

```markdown
## [YYYY-MM-DD] ingest | <type> | <slug>

- Source: `raw/<path>`
- Pages created: <links>
- Pages updated: <links>
- Requirements: created N, updated N; decisions N; actions N; contradictions/drift N
```

## Output

Summary of the source, pages created/updated, decisions, action items (owner, due date), contradictions and drift to review.
