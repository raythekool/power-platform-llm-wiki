---
name: llm-wiki-query
description: "This skill should be used when the user asks 'what does the wiki say about...', 'what did we decide...', 'who is responsible for...', 'what is the status of...', or any project question. Answers using only llm-wiki/wiki/ content — never from general knowledge. Optionally saves answers as llm-wiki/wiki/reference/queries/ pages."
---

# Skill: Query Wiki

Answer a question using only information from the wiki.

## Ownership

| Scope           | Permission                                           |
| --------------- | ---------------------------------------------------- |
| `llm-wiki/wiki/`                   | READ — all pages                                     |
| `llm-wiki/wiki/reference/queries/` | WRITE — save answers as wiki pages (on user request) |
| `llm-wiki/wiki/index.md`           | WRITE — add query page entry                         |
| `llm-wiki/wiki/log.md`             | APPEND only                                          |
| `llm-wiki/raw/`                    | NO ACCESS                                            |

This skill never modifies existing wiki pages (except index/log). It only creates new query pages.

## Steps

1. **Read `llm-wiki/wiki/index.md`** first — always.

2. **Identify relevant pages** from the index.

3. **Read those pages** completely.

4. **Synthesize an answer** with `[[wiki-link]]` citations. Ground every claim in a wiki page.

5. **If the answer is NOT in the wiki**, say: "Not documented yet." Then suggest:
   - "Try `sync devops` to pull latest work items."
   - "Drop meeting notes in `llm-wiki/raw/meetings/` and ingest."
   - "Try `sync github` to check recent activity."

6. **Ask**: "Should I file this answer as a wiki page?"

7. **If yes**, create `llm-wiki/wiki/reference/queries/<slug>.md` with frontmatter (`type: query`), the answer with citations, and sources consulted.

8. **Update `llm-wiki/wiki/index.md`** and **append to `llm-wiki/wiki/log.md`**.

## Key Rule

**Never answer from general knowledge alone.** All answers must be grounded in wiki content.
