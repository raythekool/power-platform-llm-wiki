---
name: query
description: "Answer a project question using only information from the wiki — never from general knowledge. Reads wiki/index.md first to locate relevant pages, synthesises a grounded answer with [[wiki-link]] citations, then optionally files the answer as a new wiki/reference/queries/ page for future reuse."
argument-hint: "<the question to answer>"
user-invocable: true
disable-model-invocation: false
context: fork
---

# Query LLM Wiki

Answer a question using **only** the content of `llm-wiki/wiki/`. Every claim must be grounded in a wiki page; if the answer is not in the wiki, say so explicitly and propose a path to ingest the missing information.

## When to Use

- "What does the wiki say about <topic>?"
- "What did we decide about <topic>?"
- "Who is responsible for <feature>?"
- "What is the status of <work item>?"
- Any project question that should be answered from the documented knowledge base

For ingesting new sources, use `ingest`. For refreshing data from external systems, use `update`.

## Ownership

| Scope                          | Permission                                            |
| ------------------------------ | ----------------------------------------------------- |
| `wiki/`                        | READ — all pages                                      |
| `wiki/reference/queries/`      | WRITE — save the answer as a wiki page (on user opt-in) |
| `wiki/index.md`                | WRITE — register the new query page                   |
| `wiki/log.md`                  | APPEND only                                           |
| `raw/`                         | NO ACCESS                                             |
| All other wiki pages           | READ only — never modify existing content             |

This skill never edits existing wiki pages. It only creates new query pages on explicit user request.

## Procedure

### Step 1 — Read the catalog first

Always read `wiki/index.md` before anything else. It is the authoritative catalog of what the wiki knows.

### Step 2 — Locate relevant pages

From the index, identify candidate pages that could answer the question. Prefer pages whose category, frontmatter `tags`, or one-line summary matches the question. Consider multiple candidates if the topic is cross-cutting.

### Step 3 — Read the candidates

Read the identified pages completely. Follow `[[wiki-links]]` to related pages when the answer requires connecting multiple sources.

### Step 4 — Synthesise the answer

Compose the answer with the following constraints:

- **Ground every claim in a wiki page** using `[[wiki-link]]` citations inline.
- **Quote sparingly** — paraphrase the wiki content; quote only when precise wording matters.
- **Surface contradictions** — if two wiki pages disagree, present both with their citations and flag with `> ⚠️ **Contradiction:** ...`.
- **Be honest about gaps** — say what the wiki does NOT cover.
- **Mention freshness** — if the relevant pages have stale markers (`> 🕐 Stale:`) or are older than the related sprint, note that the answer may be outdated.

### Step 5 — If the answer is NOT in the wiki

Say explicitly: **"Not documented yet."** Then propose concrete next steps:

- "Try `update --source devops` to pull the latest work items."
- "Drop the meeting notes in `llm-wiki/raw/meetings/` then run `ingest`."
- "Try `update --source github` to refresh recent activity."
- "Try `update --source dataverse` to refresh solution metadata."

Do **not** fall back to general knowledge or guesses.

### Step 6 — Offer to file the answer

Ask:

> **"Vuoi che salvi questa risposta come pagina della wiki per future consultazioni?"** (Yes / No)

If **Yes**, continue with Step 7. If **No**, just log the query and stop.

### Step 7 — File the answer as a wiki page

Create `wiki/reference/queries/<slug>.md` with frontmatter:

```yaml
---
type: query
date: YYYY-MM-DD
question: "<the original question>"
status: active
tags: [topic]
---
```

Sections:
- **Question** — verbatim
- **Answer** — the synthesised answer with `[[wiki-link]]` citations
- **Sources consulted** — bullet list of the pages used to compose the answer
- **Open questions** — anything the wiki did not cover, with suggested next ingest action

Update `wiki/index.md` (under Reference → Queries) with the new entry.

### Step 8 — Bookkeeping

Append to `llm-wiki/wiki/log.md`:

```
## [YYYY-MM-DD] query | <slug>
- Question: <text>
- Pages consulted: [[list]]
- Filed: [[reference/queries/<slug>]]  (or "not filed")
```

## Output

Return to the user:
- The grounded answer with inline `[[wiki-link]]` citations
- A "Sources" footer listing every page consulted
- A note about freshness / contradictions if any were surfaced
- If filed, the path to the new query page

## Key Rules

- **Never answer from general knowledge.** All answers must be grounded in wiki content.
- **Always read `wiki/index.md` first.** Do not start synthesising before knowing the catalog.
- **No pipe-alias `[[Page|Alias]]` syntax** — GitHub Wiki breaks it silently. Use plain `[[Page-Name]]` or standard Markdown links.
- **No emoji inside `[[link]]` labels** — emoji break navigation when the wiki is published.
- **Cite, do not paraphrase silently.** Every factual claim needs a citation.

## Notes

- This skill is read-only against the existing wiki. It only writes the new query page (with explicit user opt-in) and the log entry.
- For complex, multi-page questions, consider running `update --lint` first to catch contradictions or stale data that could distort the answer.
- The `reference/queries/` folder becomes a growing FAQ; revisit periodically to consolidate duplicates.

## Resources

- See `ingest` to add new sources to the wiki.
- See `update --full` to refresh the wiki from all configured data sources before re-querying.
