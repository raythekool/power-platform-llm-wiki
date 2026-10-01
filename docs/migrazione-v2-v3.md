## Migrazione da v2 a v3

La versione 3 cambia link, front matter, configurazione e integrazione nel progetto. Le wiki create con la v2 si migrano con l'agente in pochi passi.

### Cosa cambia

| Area | v2 | v3 |
| --- | --- | --- |
| Link interni | `[[path/page]]`, `[[Page\|Alias]]` | Link Markdown relativi `[Titolo](../cartella/pagina.md)` |
| `status` | Stato del lavoro (`active`, `completed`, `blocked`) | Ciclo di vita del contenuto (`draft`, `reviewed`, `certified`, ...); lo stato del lavoro va in `state` |
| Nuovi campi | - | `owner`, `updated`, `sources`, `reviewed_by`, `certified_by`, `certified_at`, `req_id`, `implements` |
| Configurazione | `wiki.config.yml` v2 | Schema 3: `project.profiles`, `code.repos`, `fno`, `governance`, `publish.target` |
| Integrazione | Copie di agent e prompt in `.github/`, `.mcp.json` | Motore in `llm-wiki/.engine/`, `.vscode/mcp.json` |
| Elaborazione incrementale | Ricerca nel `log.md` | Manifest `llm-wiki/.state/raw-manifest.json` |
| Automazione | Workflow che crea issue per Copilot | Automazione del Copilot cloud agent (prompt fornito da `init`) |
| Pubblicazione | Solo GitHub Wiki | Azure DevOps Wiki o GitHub Wiki |

### Procedura

1. **Aggiorna la plugin** a 3.x (Extensions -> `@agentPlugins` -> Update).
2. In una branch dedicata del progetto, scrivi all'agente **LLM Wiki**: `config --refresh-engine`. Installa `llm-wiki/AGENTS.md` e `llm-wiki/.engine/`.
3. Esegui `config --migrate`. L'agente:
    1. mostra il risultato del lint prima della migrazione;
    2. dopo conferma converte i link `[[...]]` in link Markdown relativi;
    3. sposta i vecchi valori di `status` in `state` e imposta `status: draft`; aggiunge `updated`;
    4. converte `wiki.config.yml` allo schema 3, chiedendo i dati mancanti (profili, repository di codice, target di pubblicazione);
    5. registra le fonti già elaborate (`Get-RawDelta.ps1 -Baseline`);
    6. ripete il lint finché non restano errori.
4. Esegui `init` solo per completare le integrazioni mancanti (`.vscode/mcp.json`, istruzioni Copilot, `.gitignore`): i file esistenti vengono uniti, non sovrascritti.
5. Rimuovi i residui v2 non più usati, se presenti: `.github/workflows/wiki.yml`, `.github/agents/llm-wiki.agent.md`, `.github/prompts/llm-wiki*.prompt.md`, `.mcp.json` (dopo aver verificato che i server siano in `.vscode/mcp.json`), eventuali PAT in `.env`.
6. Rivedi la pull request: le modifiche sono meccaniche (link e front matter), il contenuto delle pagine non cambia.
7. Ripubblica con `update --publish`. Se passi da GitHub Wiki ad Azure DevOps Wiki, configura il nuovo target con `config`.

### Dopo la migrazione

- Tutte le pagine sono `draft`: pianifica la revisione delle più importanti (requisiti e architettura) e la certificazione prima del prossimo rilascio.
- Lancia `update --source code` per creare la tracciabilità requisito -> codice, che nella v2 non esisteva.
