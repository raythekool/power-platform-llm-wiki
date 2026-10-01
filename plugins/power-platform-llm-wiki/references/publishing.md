# Publishing reference

Read this file only for `update --publish`. The canonical wiki in `llm-wiki/wiki/` never changes during publishing: `Export-Wiki.ps1` produces a converted copy that is pushed to the target wiki repository.

## Choose the target

| Target                               | When                                                                                            | Source of the wiki repo                                                           |
| ------------------------------------ | ----------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| `azure-devops-wiki` (type `project`) | Default for Avanade / customer projects on Azure DevOps                                         | `https://dev.azure.com/<org>/<project>/_git/<WikiName>.wiki`, branch `wikiMaster` |
| `azure-devops-wiki` (type `code`)    | The project wants wiki changes reviewed with PRs in an Azure Repos repo of the **same** project | any Azure Repos repo + branch + folder ("Publish code as wiki")                   |
| `github-wiki`                        | Host repository on GitHub                                                                       | `https://github.com/<owner>/<repo>.wiki.git`, branch `master`                     |

A GitHub-hosted repository cannot be published as an Azure DevOps code wiki: use a project wiki.

## Azure DevOps Wiki conventions (applied by `Export-Wiki.ps1 -Target azure-devops`)

- A page with children is `<Page>.md` plus a sibling folder `<Page>/` with a `.order` file listing children (one name per line, no extension).
- File names and `.order` entries: spaces become `-`, literal hyphens become `%2D` (`REQ-SAL-001 Credit check` -> `REQ%2DSAL%2D001-Credit-check.md`).
- Internal links are absolute and use the same encoding: `/Mount/Requirements/REQ%2DSAL%2D001-Credit-check`.
- `[[_TOC_]]` is added to pages with two or more sections; Mermaid stays in standard ```` ```mermaid ```` fences.
- Images and attachments go to `/.attachments/`.
- Front matter is removed and replaced by a one-line status callout (status, owner, certification, updated).
- Never create or reorder pages with the wiki UI or page APIs for bulk changes: new pages are inserted at the top and the order breaks. Always publish through git.

## GitHub Wiki conventions (applied by `Export-Wiki.ps1 -Target github`)

- Flat namespace: `Category-Page` file names; `index.md` -> `Home.md`; links `[text](Page-Name)`.
- `_Sidebar.md` (grouped by folder, no emoji in link labels) and `_Footer.md` are generated.
- Images go to `images/`.

## Procedure

1. Run the lint first; do not publish when it reports errors.
2. Clone the target wiki repository into a temp folder (credentials: Git Credential Manager locally; a `AZURE_DEVOPS_PAT` / `GITHUB_TOKEN` secret in CI - never in files).

    ```powershell
    git clone <wiki-repo-url> $tmp
    ```

3. Export into the clone, replacing everything except `.git` (for a code wiki, export into the configured sub-folder):

    ```powershell
    pwsh llm-wiki/.engine/scripts/Export-Wiki.ps1 -WikiPath llm-wiki/wiki -OutPath $tmp -Target azure-devops -MountFolder "<mount or empty>" -ProjectName "<name>" -Clean
    ```

4. Review the JSON output: `warnings` must be empty or explained. Show `git -C $tmp status --short` to the user.
5. **Interactive mode:** ask for confirmation before pushing (it updates a shared wiki). **Headless mode:** push only when `publish.headless: true`.
6. Commit and push: `git -C $tmp add -A; git -C $tmp commit -m "docs(wiki): publish YYYY-MM-DD - N pages"; git -C $tmp push`.
7. Verify: `git ls-remote <wiki-repo-url> <branch>` equals `git -C $tmp rev-parse HEAD`. Ask the user to open the home page and one deep link once after the first publish.
8. Remove the temp folder and append a `publish` entry to `wiki/log.md` (target, pages, commit).

## Consumption by Copilot

The published wiki is the knowledge source for questions from people outside the delivery team:

- **Microsoft 365 Copilot / Copilot Studio**: connect the Azure DevOps Wiki through the Microsoft Graph connector for Azure DevOps Wiki (tenant admin), or publish an export to a SharePoint library used as knowledge source. Pages with front matter-derived status callouts let users see whether content is certified.
- **VS Code**: the `query` skill answers from `llm-wiki/wiki/` directly.
