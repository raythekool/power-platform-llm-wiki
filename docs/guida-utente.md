## Guida utente

Questa guida spiega come usare LLM Wiki su un progetto Dynamics 365 (CE / Power Platform o Finance & Operations): installazione, primo setup, lavoro quotidiano, pubblicazione e consultazione.

### A chi serve

| Ruolo                  | Cosa fa con la wiki                                                                                      |
| ---------------------- | -------------------------------------------------------------------------------------------------------- |
| Consulente funzionale  | Carica FDD, verbali e trascrizioni; verifica le pagine dei requisiti; risponde alle domande dei key user |
| Sviluppatore / tecnico | Lancia l'analisi del codice; verifica le pagine `code/` e la tracciabilità requisito -> codice           |
| Project manager / lead | Pubblica la wiki, controlla lint, azioni aperte e drift; organizza revisione e certificazione            |
| Key user / cliente     | Consulta la wiki pubblicata (Azure DevOps Wiki o Copilot) e certifica i contenuti                        |

### Prerequisiti

- VS Code con GitHub Copilot e l'impostazione **Chat > Plugins: Enabled** attiva.
- PowerShell 7 (`pwsh`) e git.
- In base alle fonti del progetto: Git Credential Manager (Azure Repos, Azure DevOps Wiki), `pacx` / `pac` (Dataverse), `gh` (GitHub), `markitdown` (documenti Word, PowerPoint, Excel, PDF).

### 1. Installare la plugin

1. Aggiungi questo repository a **Chat > Plugins: Marketplaces** (formato `owner/repo`).
2. Nella vista Extensions cerca `@agentPlugins power-platform-llm-wiki` e installa.
3. Nella chat seleziona l'agente **LLM Wiki**.

### 2. Primo setup (`init`)

Apri la cartella del repository di progetto (quello che ospiterà la wiki) e scrivi `init` all'agente. Il wizard chiede:

1. **Progetto**: nome, lingua dei contenuti (default italiano), profili (`power-platform`, `dynamics-fno`, `generic`).
2. **Fonti** (tutte opzionali):
    - repository di codice (Azure Repos, GitHub o cartella locale) - consigliato, il codice è la fonte primaria;
    - Azure DevOps Boards (organizzazione e progetto; accesso con il proprio account, nessun PAT);
    - soluzioni Dataverse;
    - cartelle dei package F&O personalizzati;
    - attività GitHub, SharePoint.
3. **Pubblicazione**: Azure DevOps Wiki (project o code wiki), GitHub Wiki o nessuna.
4. **Governance**: redazione dei dati personali, soglia di "pagina non aggiornata", nomi dei certificatori.
5. **Automazione**: solo per repository su GitHub (aggiornamento schedulato tramite Copilot cloud agent).

Al termine il progetto contiene la cartella `llm-wiki/` (configurazione, motore, sorgenti, wiki) e le integrazioni per VS Code. Fai commit di tutto tranne quanto escluso da `.gitignore`.

### 3. Riempire la wiki

| Cosa vuoi fare               | Cosa fai                                                                    | Cosa produce l'agente                                                                       |
| ---------------------------- | --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| Documentare l'as-built       | `update --source code`                                                      | `wiki/projects/` e `wiki/code/` con diagrammi Mermaid, a partire dall'inventario del codice |
| Metadati F&O                 | `update --source fno`                                                       | Modello dati, estensioni (Chain of Command), data entity, sicurezza                         |
| Metadati Dataverse           | `update --source dataverse`                                                 | Modello dati, plugin, flow, sicurezza dall'ambiente                                         |
| Work item                    | `update --source devops`                                                    | `wiki/features/`, backlog, collegamenti a requisiti e codice                                |
| FDD / analisi funzionale     | copia il file in `llm-wiki/raw/analysis/`, poi `ingest raw/analysis/<file>` | Una pagina per requisito (`REQ-...`) con criteri di accettazione e collegamento al codice   |
| TDD / specifica tecnica      | file in `llm-wiki/raw/specs/`, poi `ingest ...`                             | Pagine `wiki/design/` confrontate con il codice                                             |
| Verbale o trascrizione Teams | file in `llm-wiki/raw/meetings/`, poi `ingest ...`                          | Verbale strutturato: domande e risposte, decisioni, action item, rischi                     |
| Decisione architetturale     | file in `llm-wiki/raw/adrs/` o richiesta diretta                            | Pagina ADR collegata a requisiti e design                                                   |
| Tutto ciò che è cambiato     | `update --full`                                                             | Sincronizza le fonti, elabora solo i file nuovi o modificati, lint finale                   |

I documenti Word, PowerPoint, Excel e PDF vengono convertiti in Markdown automaticamente (con `markitdown`). L'agente elabora solo i file nuovi o cambiati, quindi `update --full` si può lanciare spesso senza costi inutili.

### 4. Controllare la qualità (`update --lint`)

Il lint è uno script deterministico (non consuma token) e segnala:

- **errori**: link interrotti, front matter mancante, pagine certificate senza certificatore, possibili segreti nel testo;
- **avvisi**: pagine orfane o non presenti nell'indice, azioni scadute, requisiti senza implementazione, pagine di codice senza diagramma;
- **info**: pagine non aggiornate da troppo tempo, componenti di codice non tracciati a un requisito.

Correggi gli errori prima di pubblicare. Le segnalazioni `⚠️ Drift` (codice diverso da FDD/TDD) richiedono una decisione del team: aggiornare il documento o correggere il codice.

### 5. Revisionare e certificare

Le pagine nascono in stato `draft`. Quando una persona le ha verificate:

- `update --review llm-wiki/wiki/requirements/REQ-SAL-001-credit-check.md --by "Nome Cognome"`
- `update --certify llm-wiki/wiki/requirements/REQ-SAL-001-credit-check.md --by "Nome Cliente"`

Il processo completo è descritto in [governance.md](governance.md).

### 6. Pubblicare (`update --publish`)

L'agente converte la wiki nel formato del target (Azure DevOps Wiki o GitHub Wiki), mostra le modifiche e chiede conferma prima del push. Su Azure DevOps la struttura delle pagine, l'ordine e i link vengono generati automaticamente: non modificare la wiki pubblicata a mano, le modifiche vanno fatte nei sorgenti o nelle pagine di `llm-wiki/wiki/`.

### 7. Fare domande (`query`)

Esempi:

- `query "come è implementato il controllo fido?"`
- `query "cosa abbiamo deciso sulla wiki di progetto?"`
- `query "quali requisiti di vendita non hanno ancora un'implementazione?"`

L'agente risponde solo con il contenuto della wiki, cita le pagine e indica se sono certificate. Se l'informazione manca risponde "Not documented yet" e propone come aggiungerla. La risposta può essere salvata come FAQ in `wiki/reference/queries/`.

Chi non usa VS Code consulta la wiki pubblicata su Azure DevOps o tramite Microsoft 365 Copilot / Copilot Studio collegati alla wiki.

### Domande frequenti

**Posso modificare a mano le pagine della wiki?** Sì, in `llm-wiki/wiki/`. L'agente non sovrascrive i contenuti: segnala contraddizioni e, sulle pagine certificate, propone le modifiche in una sezione "Pending updates".

**Dove metto le regole specifiche del progetto?** In `llm-wiki/wiki.config.yml`, sezione `conventions`. Non modificare `llm-wiki/AGENTS.md` né `llm-wiki/.engine/`: vengono sovrascritti dagli aggiornamenti.

**Ho aggiornato la plugin, cosa faccio?** `config --refresh-engine`, poi `update --lint`.

**Quanto costa in token?** Gli script fanno il lavoro meccanico; l'agente legge solo inventari e file cambiati. Ogni voce di `wiki/log.md` riporta i KB elaborati per tenere traccia dei consumi.

**I dati del cliente sono al sicuro?** La wiki vive nel repository del progetto. Il lint blocca le credenziali più comuni; con `pii_redaction` attivo l'agente non copia dati personali oltre a nomi e ruoli dei partecipanti.
