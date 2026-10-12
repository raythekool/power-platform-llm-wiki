# TFVC sources (Team Foundation Version Control)

Read this file only for a `code.repos` entry with `provider: tfvc`. Typical case: older Dynamics 365 F&O projects (and some CE / .NET projects) whose code is in TFS, Azure DevOps Server or an Azure DevOps Services TFVC project instead of git.

## What you need

- `tf.exe`, installed with Visual Studio (any edition with Team Explorer). It is not on `PATH` by default: run from a **Developer PowerShell for VS**, or call it by full path (`<VS install>\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\TF.exe`). Check: `tf help`.
- Read access to `server_path`. Authentication is the user's own: Windows integrated authentication on premises, Microsoft Entra ID sign-in for Azure DevOps Services. Never use `/login` with a password and never write credentials in files.

Config entry:

```yaml
- name: fno-main
  provider: tfvc
  url: https://tfs.contoso.local/tfs/DefaultCollection   # collection URL (Azure DevOps Services: https://dev.azure.com/<org>)
  server_path: $/Contoso/Trunk/Main                      # folder to document; map only what is needed
  path: ../fno-main                                       # local workspace folder
```

## Procedure (read-only)

Allowed commands: `workspaces`, `workspace /new`, `workfold`, `status`, `get`, `history`. Never `checkin`, `checkout`, `add`, `delete`, `undo`, `shelve` or `branch`: the wiki only reads the code.

1. **Find the workspace.** `tf workfold "<path>"` prints the mapping if `path` is already in a workspace (for example on an F&O developer VM, where the workspace usually maps `$/<Project>/Trunk/Main/Metadata` to `K:\AosService\PackagesLocalDirectory`). Reuse it and skip step 2.
2. **Create a dedicated workspace** (only the first time, when nothing maps `path`), from inside the empty `path` folder:

    ```powershell
    tf workspace /new /noprompt /location:local /collection:<url> llmwiki-<name>
    tf workfold /unmap /workspace:llmwiki-<name> /collection:<url> '$/'   # removes the default mapping, if any; ignore "not mapped"
    tf workfold /map '<server_path>' '<path>' /workspace:llmwiki-<name> /collection:<url>
    ```

    Quote `$/...` paths with single quotes in PowerShell. A local workspace keeps a hidden `$tf` folder at the mapping root: `Get-CodeInventory.ps1` uses it to report `vcs: tfvc` and skips it.
3. **Check for local work.** `tf status "<path>" /recursive /noprompt`: if there are pending changes (typical on a developer VM), stop and ask. Never overwrite them.
4. **Get the latest version.** `tf get "<path>" /recursive /noprompt`. In headless runs without `tf.exe`, skip this step and document the folder as it is.
5. **Revision.** `tf history '<server_path>' /recursive /stopafter:1 /noprompt /format:brief /collection:<url>`: the first data row starts with the latest changeset number `<n>`. The revision label is `C<n>` (citations: `<repo>@C<n>:<path>`).
6. **Inventory and changes.** Run `Get-CodeInventory.ps1` with `-Revision C<n> -StatePath llm-wiki/.state/code-<name>.json` and use `changes.added / modified / deleted` (TFVC has no `git diff`). Accept the snapshot with `-AcceptState` once the pages are written.

Optional context for the pages: `tf history '<server_path>' /recursive /stopafter:20 /noprompt /format:detailed /collection:<url>` lists recent changesets with comments and linked work items; use them for `wiki/projects/<name>.md` (recent activity), not as a source of behaviour.

## Without `tf.exe`

- **Download the folder**: Azure DevOps web portal -> Repos -> Files -> select `server_path` -> **Download as Zip**. Extract it into `path` and set `provider: local`. Changes between downloads come from the hash snapshot (`-StatePath`); the revision label is the download date.
- **Migrated to git**: if the project has moved (or is moving) to git, document the git repository instead and keep TFVC only for history.
