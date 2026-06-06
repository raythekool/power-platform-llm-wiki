# 📚 LLM Wiki

A portable, LLM-maintained project wiki. Drop this folder into any repository and run the setup.

Based on the [LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) by Andrej Karpathy.

---

## 🔌 Install As A VS Code Plugin

This repository carries the marketplace manifest structure expected by GitHub
Copilot plugin marketplaces.

For installation, use the published marketplace repository:

```text
raythekool/power-platform-llm-wiki
```

### 1. Enable agent plugins in VS Code

1. Open `File > Preferences > Settings`
2. Search for `Chat > Plugins: Enabled`
3. Enable the setting

### 2. Add this repository as a plugin marketplace

1. Open `File > Preferences > Settings`
2. Search for `Chat > Plugins: Marketplaces`
3. Add this repository:

```text
raythekool/power-platform-llm-wiki
```

Do not use a GitHub folder URL such as
`https://github.com/raythekool/ray-llm-wiki/tree/main/plugins/llm-wiki`.
VS Code installs agent plugins by cloning the **repository root**.

### 3. Install the plugin

1. Open the Extensions view
2. Search for `@agentPlugins power-platform-llm-wiki`
3. Install the plugin from this repository marketplace

### Available Plugin

| Plugin                    | Description                                                                                       | Details                      |
| ------------------------- | ------------------------------------------------------------------------------------------------- | ---------------------------- |
| `power-platform-llm-wiki` | Power Platform-oriented LLM Wiki plugin for project knowledge bases, sync, ingest, and publishing | `plugins/power-platform-llm-wiki/README.md` |

---

## 🚀 Quick Start

### 1. Copy into your project

```
your-project/
+-- llm-wiki/          <-- copy this repo here
+-- src/
+-- ...
```

### 2. 🤖 Run setup

Open the setup prompt in VS Code and let the agent do the work:

```
/llm-wiki-setup
```

or pick **`llm-wiki-setup`** from the prompt picker (file: `llm-wiki/setup/llm-wiki-setup.prompt.md`).

The agent reads `llm-wiki/skills/init.md`, asks you for the required values (DevOps org/project, GitHub repos, PAT), and writes every integration file (`.github/`, `.mcp.json`, `.env`, `wiki.config.yml`) for you. **No PowerShell installer is involved.**

### 3. ⚙️ Configure (only if you skipped the prompt)

| What                      | File                       | What to set                    |
| ------------------------- | -------------------------- | ------------------------------ |
| **GitHub repos to track** | `llm-wiki/wiki.config.yml` | `github.repos: [ owner/repo ]` |
| **DevOps org name**       | `.mcp.json`         | Replace `YOUR_DEVOPS_ORG`      |
| **DevOps PAT**            | `.env`                     | `AZURE_DEVOPS_PAT=...`         |
| **DevOps filters**        | `llm-wiki/wiki.config.yml` | Area paths, iteration prefix   |

### 4. ✨ Use it

Switch to the **LLM Wiki** agent in VS Code's agent picker, or run `/llm-wiki` from the prompt picker. Then tell it what to do:

```
init                          -> scaffold the wiki + integrate the host repo
config                        -> reconfigure integrations, repos, secrets, publish target
update --source devops         -> imports work items from Azure DevOps
update --source github         -> imports repo/branch/PR info + code analysis
update --source dataverse      -> exports & analyzes Dataverse solutions
update --full                  -> runs all syncs + ingest + sprint + lint + publish
update --lint                  -> checks for contradictions, stale data
update --sprint                -> generates sprint status report
update --publish               -> pushes to GitHub Wiki
ingest raw/meetings/file.md    -> ingests a source document (auto-detects type)
query "What is X?"             -> answers from wiki pages
```

You can also phrase these in natural language (e.g. "sync devops", "lint the wiki", "publish") — the agent maps them to the right `update` mode.

---

## 📦 What the setup installs

| File                                       | Purpose                                                |
| ------------------------------------------ | ------------------------------------------------------ |
| `.github/copilot-instructions.md`          | Tells Copilot about the wiki (appended)                |
| `.mcp.json`                         | Azure DevOps + GitHub MCP servers (created/merged)     |
| `.github/workflows/wiki.yml`               | Scheduled workflow — creates issue assigned to Copilot |
| `.github/copilot-setup-steps.yml`          | Copilot Coding Agent environment (markitdown, gh)      |
| `.github/agents/llm-wiki.agent.md`         | Custom agent — interactive wiki management             |
| `.github/prompts/llm-wiki.prompt.md`       | Prompt for wiki operations                             |
| `.github/prompts/llm-wiki-setup.prompt.md` | Prompt for wiki setup                                  |
| `.env`                                     | Credentials (from template, gitignored)                |

---

## 🔄 How it works

| Layer       | Path                 | Owner     |
| ----------- | -------------------- | --------- |
| MCP Servers | Azure DevOps, GitHub | Automated |
| Raw sources | `llm-wiki/raw/`      | Human     |
| Wiki        | `llm-wiki/wiki/`     | LLM       |
| Schema      | `llm-wiki/AGENTS.md` | Both      |

The LLM reads `AGENTS.md`, syncs data via MCP, ingests documents from `raw/`, and writes/updates wiki pages in `wiki/`.

## ⏰ Scheduled Updates (Copilot Coding Agent)

The wiki can update itself automatically via **GitHub Copilot Coding Agent**:

1. A **scheduled workflow** (`.github/workflows/wiki.yml`) runs every Monday at 07:00 UTC.
2. The workflow creates a **GitHub issue** assigned to `copilot`, describing the operation to perform (`full-update`, `sync-devops`, `lint`, etc.).
3. **Copilot Coding Agent** picks up the issue, reads `AGENTS.md` + the relevant skill file, and executes the operation in headless mode.
4. Copilot opens a **Pull Request** with all wiki changes for review.

You can also trigger it manually:

```sh
gh workflow run wiki.yml -f operation=full-update
```

> **Prerequisite:** Your GitHub plan must include Copilot Coding Agent, and the repo must have it enabled in Settings → Copilot → Coding agent.

## 🗂️ Structure

```
llm-wiki/
+-- AGENTS.md              <-- LLM operating manual
+-- wiki.config.yml        <-- What to track (edit this)
+-- raw/                   <-- Drop source documents here
|   +-- meetings/          <-- Meeting minutes (.md, .docx, .pdf...)
|   +-- analysis/          <-- Analysis docs
|   +-- specs/             <-- Specifications
|   +-- adrs/              <-- Architecture Decision Records
|   +-- assets/            <-- Images, diagrams
|   +-- dataverse/         <-- Dataverse solution exports (PAC/PACX)
+-- wiki/                  <-- LLM-maintained knowledge base
|   +-- index.md           <-- Content catalog (read first)
|   +-- overview.md        <-- High-level synthesis
|   +-- log.md             <-- Operation log (append-only)
|   +-- ...                <-- sources/, projects/, features/, code/, etc.
+-- skills/                <-- Operation procedures (read by the LLM)

+-- setup/                 <-- Templates (copied during setup)
|   +-- llm-wiki.agent.md  <-- Custom agent (copied to .github/agents/)
|   +-- llm-wiki.prompt.md <-- Wiki prompt (copied to .github/prompts/)
|   +-- llm-wiki-setup.prompt.md  <-- Setup prompt (copied to .github/prompts/)
|   +-- wiki.yml           <-- Workflow template (creates Copilot issues)
|   +-- copilot-setup-steps.yml <-- Copilot agent environment setup
|   +-- env.sample         <-- .env template
|   +-- mcp-servers.json   <-- MCP config fragment
|   +-- copilot-snippet.md <-- Instructions snippet
+-- llm-wiki.md            <-- Design reference
```

## 📋 Prerequisites

- **VS Code** with GitHub Copilot
- **GitHub Copilot** plan with Coding Agent enabled (for scheduled auto-updates)
- **GitHub CLI** (`gh`) authenticated -- required for reading code from non-default branches
- **Node.js/npx** -- for Azure DevOps MCP server
- **PAC CLI** (optional) -- for Dataverse solution export: `dotnet tool install --global Microsoft.PowerApps.CLI.Tool`
- **PACX** (optional) -- for Dataverse solution analysis: [neronotte/Greg.Xrm.Command](https://github.com/neronotte/Greg.Xrm.Command)
- **markitdown** (optional) -- for converting Office files, PDFs, images to Markdown. Pick **one**:
  - **MCP Server:** `pip install markitdown-mcp` (LLM converts files directly via MCP tool)
  - **VS Code Extension:** install [`MarkItDown`](https://marketplace.visualstudio.com/items?itemName=bioinfo.markitdown-vscode) (right-click → Convert to Markdown)
  - **CLI:** `pip install "markitdown[all]"` (command-line `markitdown file.pdf`)

---

## 🇮🇹 Guida Rapida (IT)

### 1. Copia nel tuo progetto

Copia questa cartella come `llm-wiki/` nella root del tuo repository.

### 2. Esegui il setup

Apri il prompt di setup in VS Code:

```
/llm-wiki-setup
```

oppure seleziona **`llm-wiki-setup`** dal prompt picker (file: `llm-wiki/setup/llm-wiki-setup.prompt.md`). L'agente legge `llm-wiki/skills/init.md`, ti chiede i valori necessari e scrive tutti i file di integrazione. **Nessuno script PowerShell viene eseguito.**

### 3. Configura

| Cosa                         | File                       | Cosa impostare                 |
| ---------------------------- | -------------------------- | ------------------------------ |
| **Repo GitHub da tracciare** | `llm-wiki/wiki.config.yml` | `github.repos: [ owner/repo ]` |
| **Org DevOps**               | `.mcp.json`         | Sostituisci `YOUR_DEVOPS_ORG`  |
| **PAT DevOps**               | `.env`                     | `AZURE_DEVOPS_PAT=...`         |

### 4. Usa

Apri il prompt `.github/prompts/llm-wiki.prompt.md` o di' a Copilot:

```
init                          -> crea la scaffolding + integra il repo host
config                        -> riconfigura integrazioni, repo, segreti, target di pubblicazione
update --source devops         -> importa work item da Azure DevOps
update --source github         -> importa info repo/branch/PR + analisi codice
update --source dataverse      -> esporta e analizza soluzioni Dataverse
update --full                  -> esegue tutti i sync + ingest + sprint + lint + publish
update --lint                  -> controlla salute wiki
update --sprint                -> report stato sprint
update --publish               -> pubblica su GitHub Wiki
ingest raw/file.md             -> ingerisce un documento (rileva il tipo)
query "Cos'è X?"               -> risponde dalle pagine della wiki
```

Puoi anche usare linguaggio naturale (es. "sync devops", "lint", "pubblica") — l'agente mappa la richiesta alla mode `update` corretta.

### 📋 Prerequisiti

- **VS Code** con GitHub Copilot
- **GitHub CLI** (`gh`) autenticato
- **Node.js/npx** per il server MCP Azure DevOps
- **PAC CLI** (opzionale) -- per export soluzioni Dataverse: `dotnet tool install --global Microsoft.PowerApps.CLI.Tool`
- **PACX** (opzionale) -- per analisi soluzioni Dataverse: [neronotte/Greg.Xrm.Command](https://github.com/neronotte/Greg.Xrm.Command)
- **markitdown** (opzionale) -- per convertire file Office, PDF, immagini in Markdown. Scegli **una** opzione:
  - **MCP Server:** `pip install markitdown-mcp` (l'LLM converte i file direttamente via MCP)
  - **Estensione VS Code:** installa [`MarkItDown`](https://marketplace.visualstudio.com/items?itemName=bioinfo.markitdown-vscode) (tasto destro → Convert to Markdown)
  - **CLI:** `pip install "markitdown[all]"` (da riga di comando `markitdown file.pdf`)

