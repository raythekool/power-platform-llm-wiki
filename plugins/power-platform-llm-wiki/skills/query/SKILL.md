---
name: query
description: "Answer a project question using only the LLM Wiki (never general knowledge): reads wiki/index.md, follows relevant pages, cites every claim with links, reports certification status, contradictions, drift and gaps, and can save the answer as a reusable FAQ page in wiki/reference/queries/."
argument-hint: "<question>"
user-invocable: true
---

# Query the wiki

## Ownership

| Scope | Permission |
| --- | --- |
| `llm-wiki/wiki/` | READ |
| `llm-wiki/wiki/reference/queries/`, `index.md`, `log.md` (append) | WRITE only when the user asks to save the answer |
| `llm-wiki/raw/`, code | NO ACCESS |

## Procedure

1. Read `llm-wiki/wiki/index.md`; pick candidate pages by folder, title and summary. Requirements, design and code pages answer "what/why/how"; meetings and ADRs answer "who decided what, when".
2. Read the candidates completely and follow their links when the answer spans pages.
3. Answer:
    - every claim followed by its source link (`[REQ-SAL-001](llm-wiki/wiki/requirements/REQ-SAL-001-credit-check.md)`);
    - state the status of the main sources (draft / reviewed / certified) - prefer certified content when sources disagree;
    - surface `⚠️ Contradiction` / `⚠️ Drift` markers and `🕐 Stale` pages that affect the answer;
    - say clearly what the wiki does not cover.
4. If the wiki has no answer: reply **"Not documented yet."** and propose the step that would add it (`ingest <file>`, `update --source code`, `update --source devops`, ...). Do not use general knowledge.
5. Offer to save the answer (Yes / No). If Yes, create `wiki/reference/queries/<slug>.md` (`type: query`, `status: draft`, `updated`, `question`), with sections Question, Answer, Sources, Open questions; add it to `index.md`; append to `log.md`:

```markdown
## [YYYY-MM-DD] query | <slug>

- Question: <text>
- Pages consulted: <links>
- Saved: <link or "no">
```
