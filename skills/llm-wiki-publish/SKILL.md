---
name: llm-wiki-publish
description: "This skill should be used when the user asks to 'publish wiki', 'push wiki', 'pusha la wiki', or 'sync wiki to repo'. Converts the internal llm-wiki/wiki/ structure to GitHub Wiki flat format with working [[links]], sidebar, and footer, then pushes to the target repository wiki."
---

# Skill: Publish Wiki to GitHub

Publish the LLM Wiki content to a GitHub repository's wiki. Converts the internal `llm-wiki/wiki/` structure to GitHub Wiki flat format with working `[[links]]`, sidebar, and footer.

## Ownership

| Scope                  | Permission                                    |
| ---------------------- | --------------------------------------------- |
| `llm-wiki/wiki/`                | READ only                                     |
| `llm-wiki/wiki.config.yml`      | READ only                                     |
| GitHub Wiki (external) | WRITE — full ownership of target wiki content |

This skill does **NOT** modify any local file.

## Input

- `TARGET_REPO` — GitHub repo in `owner/repo` format. Source: user provides via chat, or read from `llm-wiki/wiki.config.yml` → `publish.repo`.

## Prerequisites

- `gh` CLI authenticated (`gh auth status`)
- Target repo exists and has wiki enabled (`hasWikiEnabled: true`)
- At least one wiki page must exist (Home.md seed) — GitHub requires this before the wiki repo can be cloned

## Steps

### Phase 1 — Prepare

1. Read `llm-wiki/wiki.config.yml` → `publish` section (if present) for default target repo and project name.
2. If `TARGET_REPO` not provided and not in config, **ask the user**.
3. Verify: `gh repo view <TARGET_REPO> --json hasWikiEnabled` → must be `true`.
4. Clone `https://github.com/<TARGET_REPO>.wiki.git` to a temp directory.

### Phase 2 — Generate Pages

5. **Collect all wiki pages**: scan `llm-wiki/wiki/` recursively for `.md` files (exclude `log.md` and `lint-*.md`).
6. **Build page map** — flatten paths to GitHub Wiki names:

   | Local path                  | Wiki page name         |
   | --------------------------- | ---------------------- |
   | `llm-wiki/wiki/index.md`             | `Home.md`              |
   | `llm-wiki/wiki/overview.md`          | `Overview.md`          |
   | `llm-wiki/wiki/<category>/<slug>.md` | `<Category>-<Slug>.md` |

   Rules:
   - First letter of each segment uppercase (PascalCase with hyphens preserved)
   - Path separator `/` → `-` (single dash)
   - Example: `llm-wiki/wiki/reference/sources/cr-customer-service-rom-2025.md` → `Reference-Sources-CR-Customer-Service-ROM-2025.md`
   - Example: `llm-wiki/wiki/meetings/2026-04-21-intro.md` → `Meetings-2026-04-21-Intro.md`

7. **Build link map** — for every page, map `[[original/path]]` → `[[Flat-Page-Name]]`:
   - `[[reference/sources/cr-customer-service-rom-2025]]` → `[[Reference-Sources-CR-Customer-Service-ROM-2025]]`
   - `[[projects/raiway-ticketing]]` → `[[Projects-Raiway-Ticketing]]`
   - Never use pipe syntax `[[Page|Alias]]` — it breaks on GitHub Wiki.

8. **For each page**:
   a. Read content from local `llm-wiki/wiki/` file.
   b. Strip YAML frontmatter (`---\n...\n---`).
   c. Replace all `[[wiki links]]` using the link map.
   d. Write to temp wiki directory with the flat page name.

### Phase 3 — Sidebar & Footer

9. **Generate `_Sidebar.md`**:
   - Group pages by category (Generale, Delivery, Progetti, Feature, Codice, Meeting, Riferimenti)
   - Use `[[Flat-Page-Name]]` links — **NO emoji** in link labels
   - Always include `[[Home]]` and `[[Overview]]` at the top
   - Read project name from `llm-wiki/wiki.config.yml` → `publish.project_name` or infer from `llm-wiki/wiki/overview.md` title

   Template:
   ```markdown
   ### <Project Name>

   **Generale**
   - [[Home]]
   - [[Overview]]

   **Delivery**
   - [[Delivery-Backlog-Overview]]
   - [[Delivery-Environments]]
   - [[Delivery-Sprint-Snapshots-Page-1]]
   - [[Delivery-Release-Notes-Page-1]]

   **Progetti**
   - [[Projects-Page-1]]

   **Feature**
   - [[Features-Page-1]]

   **Codice**
   - [[Code-Index]]
   - [[Code-Architecture]]
   - [[Code-Datamodel]]
   - [[Code-Plugin]]

   **Meeting**
   - [[Meetings-Page-1]]

   **Riferimenti**
   - [[Reference-Decisions-Page-1]]
   - [[Reference-Concepts-Page-1]]
   - [[Reference-Entities-Page-1]]
   - [[Reference-Sources-Page-1]]
   - [[Reference-Queries-Page-1]]
   ```

   Rules:
   - Skip empty categories
   - Sort pages alphabetically within each category
   - No emoji in `[[link]]` labels (GitHub Wiki breaks navigation)

10. **Generate `_Footer.md`**:
    ```markdown
    ---
    *Wiki generata da [LLM Wiki](https://github.com/raythekool/ray-llm-wiki) il YYYY-MM-DD. Progetto: <project_name>.*
    ```

### Phase 4 — Push

11. `git add -A` in temp wiki directory.
12. `git commit -m "docs(wiki): auto-update YYYY-MM-DD — N pages"`.
13. `git push origin master`.
14. Clean up temp directory.

## Link Validation Checklist

Before pushing, verify:
- [ ] Every `[[link]]` in page content has a corresponding `.md` file in the temp directory
- [ ] No `[[link]]` uses pipe syntax (`[[Page|Alias]]`)
- [ ] No `[[link]]` contains emoji
- [ ] `_Sidebar.md` links match actual page filenames (case-sensitive)
- [ ] `_Footer.md` contains no broken links
- [ ] `Home.md` exists (GitHub Wiki requires it)

## Configuration (wiki.config.yml)

Optional `publish` section:
```yaml
publish:
  repo: "owner/repo"           # default target repo
  project_name: "Project Name" # displayed in sidebar header and footer
  exclude:                     # pages to exclude from publishing
   - "llm-wiki/wiki/log.md"
   - "llm-wiki/wiki/lint-*.md"
```

## Output

Report: target repo, pages published, link validation result.
