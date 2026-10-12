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

1. Ask the knowledge graph which pages matter (0 tokens), with the ids and key words of the question:

    ```powershell
    pwsh llm-wiki/.engine/scripts/Get-WikiGraph.ps1 -WikiPath llm-wiki/wiki -Query "REQ-SAL-001","CustTable" -Depth 2 -MaxNodes 30
    ```

    It returns the matching nodes, their neighbourhood (summary, status, area, relation types) and `pagesToRead`. Impact questions ("what changes if X changes?"): `-Impact <id>`. Connection questions ("how is A related to B?"): `-From <a> -To <b>`. If the graph finds nothing, fall back to `llm-wiki/wiki/index.md` and pick candidates by folder, title and summary. Requirements, design and code pages answer "what/why/how"; meetings and ADRs answer "who decided what, when".
2. Read `pagesToRead` (and only those) completely; follow further links only when the answer spans pages the graph did not return. Node summaries are enough for overview answers ("quick answer" mode: do not open pages).
3. Answer:
    - every claim followed by its source link (`[REQ-SAL-001](llm-wiki/wiki/requirements/REQ-SAL-001-credit-check.md)`);
    - state the status of the main sources (draft / reviewed / certified) - prefer certified content when sources disagree;
    - surface `⚠️ Contradiction` / `⚠️ Drift` markers (`flags` and `drift` / `contradiction` relations in the graph) and `🕐 Stale` pages that affect the answer;
    - say clearly what the wiki does not cover.
4. If the wiki has no answer: reply **"Not documented yet."** and propose the step that would add it (`ingest <file>`, `update --source code`, `update --source devops`, ...). Do not use general knowledge.
5. Offer to save the answer (Yes / No). If Yes, create `wiki/reference/queries/<slug>.md` (`type: query`, `status: draft`, `updated`, `question`), with sections Question, Answer, Sources, Open questions; add it to `index.md`; append to `log.md`:

```markdown
## [YYYY-MM-DD] query | <slug>

- Question: <text>
- Pages consulted: <links>
- Saved: <link or "no">
```
