#Requires -Version 7.0
<#
.SYNOPSIS
    Regression tests for the deterministic LLM Wiki scripts, run against tests/fixtures.
    Exit code 0 when every assertion passes.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$scripts = Join-Path $repoRoot 'plugins/power-platform-llm-wiki/scripts'
$fixtures = Join-Path $PSScriptRoot 'fixtures'
$work = Join-Path ([System.IO.Path]::GetTempPath()) ("llm-wiki-tests-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null

$script:failures = 0
$script:passes = 0
function Assert([bool]$Condition, [string]$Message) {
    if ($Condition) { $script:passes++; Write-Host "  PASS $Message" }
    else { $script:failures++; Write-Host "  FAIL $Message" -ForegroundColor Red }
}
function Invoke-Json([string]$Script, [hashtable]$Params) {
    $out = & (Join-Path $scripts $Script) @Params
    $code = $LASTEXITCODE
    return @{ Json = (($out -join "`n") | ConvertFrom-Json -Depth 20); Exit = $code }
}

try {
    Copy-Item -Path (Join-Path $fixtures 'llm-wiki') -Destination $work -Recurse
    $wiki = Join-Path $work 'llm-wiki/wiki'
    $raw = Join-Path $work 'llm-wiki/raw'

    Write-Host 'Test-WikiLint (clean fixture)'
    $r = Invoke-Json 'Test-WikiLint.ps1' @{ WikiPath = $wiki; Today = '2026-10-01'; ReportPath = (Join-Path $work 'lint.md') }
    $rules = @($r.Json.issues | ForEach-Object rule)
    Assert ($r.Exit -eq 0) 'exit code 0 when no errors'
    Assert ($r.Json.errors -eq 0) "no errors (got $($r.Json.errors): $(($r.Json.issues | Where-Object severity -eq 'error' | ForEach-Object { "$($_.rule) $($_.file) $($_.message)" }) -join '; '))"
    Assert ($rules -contains 'ACT001') 'overdue action detected'
    Assert (@($r.Json.issues | Where-Object rule -eq 'ACT001').Count -eq 1) 'only the overdue action is reported'
    Assert ($rules -contains 'TRC002') 'requirement without implementation detected'
    Assert ($rules -contains 'LNK003') 'link outside wiki detected'
    Assert ($r.Json.status.certified -eq 1) 'certified page counted'
    Assert ($r.Json.requirements.total -eq 2 -and $r.Json.requirements.withImplementation -eq 1) 'traceability counts'
    Assert ($rules -notcontains 'AI001') 'every fixture page has a TL;DR'
    Assert (Test-Path (Join-Path $work 'lint.md')) 'markdown report written'

    Write-Host 'Test-WikiLint (broken copy)'
    $broken = Join-Path $wiki 'code/plugins.md'
    Add-Content -LiteralPath $broken -Value "`nSee [missing](../nowhere.md) and [[old|alias]].`n`nclient_secret = abcdefgh12345678`n"
    $certified = Join-Path $wiki 'requirements/REQ-SAL-001-credit-check.md'
    (Get-Content -LiteralPath $certified -Raw) -replace 'certified_by: John Customer\r?\n', '' | Set-Content -LiteralPath $certified -NoNewline
    $req2 = Join-Path $wiki 'requirements/REQ-SAL-002-discount-approval.md'
    (Get-Content -LiteralPath $req2 -Raw) -replace '(?m)^> Discounts.*$', 'Plain text.' | Set-Content -LiteralPath $req2 -NoNewline
    $r = Invoke-Json 'Test-WikiLint.ps1' @{ WikiPath = $wiki; Today = '2026-10-01'; MaxPageKB = 0 }
    $rules = @($r.Json.issues | ForEach-Object rule)
    Assert ($r.Exit -eq 1) 'exit code 1 on errors'
    Assert (@($r.Json.issues | Where-Object { $_.rule -eq 'AI001' }).file -contains 'requirements/REQ-SAL-002-discount-approval.md') 'page without TL;DR detected'
    Assert ($rules -contains 'AI002') 'long page detected'
    Assert ($rules -contains 'LNK001') 'broken link detected'
    Assert (@($r.Json.issues | Where-Object { $_.rule -eq 'LNK002' -and $_.severity -eq 'error' }).Count -eq 1) 'pipe-alias wiki link is an error'
    Assert ($rules -contains 'SEC001') 'secret detected'
    Assert ($rules -contains 'FM005') 'certified page without certifier detected'
    Remove-Item -Recurse -Force (Join-Path $work 'llm-wiki')
    Copy-Item -Path (Join-Path $fixtures 'llm-wiki') -Destination $work -Recurse

    Write-Host 'Get-RawDelta'
    $r = Invoke-Json 'Get-RawDelta.ps1' @{ RawPath = $raw }
    Assert (@($r.Json.new) -contains 'meetings/kickoff.md') 'new markdown source detected'
    Assert (@($r.Json.needsConversion) -contains 'analysis/fdd-sales.docx') 'docx without .md needs conversion'
    $r = Invoke-Json 'Get-RawDelta.ps1' @{ RawPath = $raw; MarkProcessed = @('raw/meetings/kickoff.md') }
    Assert (@($r.Json.new).Count -eq 0) 'processed source no longer new'
    Assert (Test-Path (Join-Path $work 'llm-wiki/.state/raw-manifest.json')) 'manifest written next to raw/'
    Add-Content -LiteralPath (Join-Path $raw 'meetings/kickoff.md') -Value 'Edited.'
    $r = Invoke-Json 'Get-RawDelta.ps1' @{ RawPath = $raw }
    Assert (@($r.Json.changed) -contains 'meetings/kickoff.md') 'edited source reported as changed'
    Set-Content -LiteralPath (Join-Path $raw 'analysis/fdd-sales.md') -Value '# FDD'
    $r = Invoke-Json 'Get-RawDelta.ps1' @{ RawPath = $raw }
    Assert (@($r.Json.needsConversion).Count -eq 0) 'conversion satisfied by .md sibling'
    Assert (@($r.Json.new) -contains 'analysis/fdd-sales.md') 'converted .md is new'
    $r = Invoke-Json 'Get-RawDelta.ps1' @{ RawPath = $raw; Baseline = $true }
    Assert ((@($r.Json.new).Count + @($r.Json.changed).Count) -eq 0) 'baseline marks everything processed'

    Write-Host 'Get-CodeInventory'
    $out = Join-Path $work 'inventory.json'
    $r = Invoke-Json 'Get-CodeInventory.ps1' @{ Path = (Join-Path $fixtures 'repo'); OutFile = $out }
    $inv = Get-Content -LiteralPath $out -Raw | ConvertFrom-Json -Depth 20
    Assert ($inv.components.dataversePlugins[0].class -eq 'CreditCheckPlugin') 'plugin class found'
    Assert ($inv.components.workflowActivities[0].class -eq 'RecalculateActivity') 'workflow activity found'
    Assert ($inv.components.pcfControls[0].constructor -eq 'CreditBadge' -and $inv.components.pcfControls[0].controlType -eq 'virtual') 'PCF control parsed'
    Assert ($inv.components.solutions[0].uniqueName -eq 'ContosoSales' -and $inv.components.solutions[0].prefix -eq 'cts') 'solution parsed'
    Assert ($inv.components.flows[0].name -eq 'NotifyCreditBlocked-0000') 'flow found'
    Assert ($inv.components.pipelines[0].kind -eq 'azure-pipelines') 'pipeline found'
    Assert ($inv.fno.models[0].name -eq 'ContosoExt' -and @($inv.fno.models[0].references) -contains 'ApplicationSuite') 'F&O model descriptor parsed'
    $table = $inv.fno.objects.AxTable[0]
    Assert ($table.name -eq 'ContosoCreditLimit' -and $table.fields.Count -eq 2 -and $table.relations[0].relatedTable -eq 'CustTable') 'AxTable fields and relations'
    $cls = $inv.fno.objects.AxClass[0]
    Assert ($cls.extensionOf -eq 'SalesFormLetter' -and $cls.methods[0].callsNext) 'Chain of Command extension detected'
    Assert ($inv.fno.objects.AxTableExtension[0].extends -eq 'CustTable') 'table extension base detected'
    $ent = $inv.fno.objects.AxDataEntityView[0]
    Assert ($ent.publicEntityName -eq 'ContosoCreditLimit' -and @($ent.tables) -contains 'ContosoCreditLimit') 'data entity parsed'

    Write-Host 'Get-CodeInventory (TFVC workspace, hash state)'
    $ws = Join-Path $work 'tfvc-ws'
    Copy-Item -Path (Join-Path $fixtures 'repo') -Destination $ws -Recurse
    New-Item -ItemType Directory -Path (Join-Path $ws '$tf') | Out-Null
    Set-Content -LiteralPath (Join-Path $ws '$tf/properties.tf1') -Value 'workspace metadata'
    $state = Join-Path $work 'llm-wiki/.state/code-legacy.json'
    $r = Invoke-Json 'Get-CodeInventory.ps1' @{ Path = $ws; OutFile = (Join-Path $work 'inv-tfvc.json'); Revision = 'C1234'; StatePath = $state }
    Assert ($r.Json.vcs -eq 'tfvc' -and $r.Json.revision -eq 'C1234') 'TFVC workspace detected, changeset recorded'
    Assert ($r.Json.changes.baseline -and (Test-Path "$state.pending") -and -not (Test-Path $state)) 'first run is a baseline; snapshot pending, not accepted'
    $inv = Get-Content -LiteralPath (Join-Path $work 'inv-tfvc.json') -Raw | ConvertFrom-Json -Depth 20
    Assert (-not ($inv.PSObject.Properties.Name -contains 'files') -and $inv.fileCount -eq (Get-ChildItem -LiteralPath $ws -Recurse -File | Where-Object FullName -notmatch '\$tf').Count) '$tf folder skipped and hashes kept out of the inventory'
    $r = Invoke-Json 'Get-CodeInventory.ps1' @{ StatePath = $state; AcceptState = $true }
    Assert ($r.Json.accepted -and (Test-Path $state) -and -not (Test-Path "$state.pending")) 'snapshot accepted'
    Add-Content -LiteralPath (Join-Path $ws 'src/Plugins/CreditCheckPlugin.cs') -Value '// changed'
    Set-Content -LiteralPath (Join-Path $ws 'src/Plugins/NewPlugin.cs') -Value 'class NewPlugin : IPlugin { }'
    Remove-Item -LiteralPath (Join-Path $ws 'azure-pipelines.yml')
    $r = Invoke-Json 'Get-CodeInventory.ps1' @{ Path = $ws; OutFile = (Join-Path $work 'inv-tfvc.json'); Revision = 'C1240'; StatePath = $state }
    $inv = Get-Content -LiteralPath (Join-Path $work 'inv-tfvc.json') -Raw | ConvertFrom-Json -Depth 20
    Assert (-not $inv.changes.baseline -and @($inv.changes.modified) -contains 'src/Plugins/CreditCheckPlugin.cs' -and @($inv.changes.added) -contains 'src/Plugins/NewPlugin.cs' -and @($inv.changes.deleted) -contains 'azure-pipelines.yml') 'added / modified / deleted files since the accepted snapshot'
    Assert ($r.Json.changes.added -eq 1 -and $r.Json.changes.modified -eq 1 -and $r.Json.changes.deleted -eq 1) 'change counts in the summary'
    $plain = Join-Path $work 'plain-copy'
    Copy-Item -Path (Join-Path $fixtures 'repo') -Destination $plain -Recurse
    $r = Invoke-Json 'Get-CodeInventory.ps1' @{ Path = $plain; OutFile = (Join-Path $work 'inv-plain.json') }
    Assert ($r.Json.vcs -eq 'none' -and $null -eq $r.Json.revision -and $null -eq $r.Json.changes) 'plain folder: no VCS, no revision, no change state unless requested'

    Write-Host 'Get-WikiGraph'
    $null = & (Join-Path $scripts 'Get-CodeInventory.ps1') -Path (Join-Path $fixtures 'repo') -OutFile (Join-Path $work 'llm-wiki/raw/code/contoso-2026-09-30.json')
    $r = Invoke-Json 'Get-WikiGraph.ps1' @{ WikiPath = $wiki; Today = '2026-10-01' }
    $g = $r.Json
    Assert ($r.Exit -eq 0 -and @($g.inventories).Count -eq 1) 'graph built with the latest code inventory'
    Assert ($g.byKind.page -eq 9 -and $g.byKind.ax -ge 5 -and $g.byKind.component -ge 4) 'pages, F&O objects and components are nodes'
    Assert ($g.byRelation.implements -eq 2 -and $g.byRelation.related_to -eq 1 -and $g.byRelation.depends_on -eq 1 -and $g.byRelation.drift -eq 1) 'front matter, inferred and drift relations'
    Assert ($g.byRelation.extension_of -eq 1 -and $g.byRelation.uses_table -eq 1 -and $g.byRelation.relates_to -ge 1) 'inventory relations'
    Assert (@($g.communities | ForEach-Object name) -contains 'SAL') 'requirement area SAL is a community'
    Assert ($g.hubs[0].id -eq 'page:code/fno-credit.md') 'most connected page is the first hub'
    Assert (@($g.gaps.undocumentedComponents.items) -contains 'RecalculateActivity' -and @($g.gaps.undocumentedComponents.items) -notcontains 'CreditCheckPlugin') 'undocumented components listed'
    $q = Invoke-Json 'Get-WikiGraph.ps1' @{ WikiPath = $wiki; Query = @('AxTable:CustTable'); Depth = 2 }
    Assert (@($q.Json.seeds) -contains 'ax:AxTable:CustTable' -and @($q.Json.pagesToRead) -contains 'llm-wiki/wiki/code/fno-credit.md') 'query returns the pages to read'
    $q = Invoke-Json 'Get-WikiGraph.ps1' @{ WikiPath = $wiki; Impact = 'AxTable:CustTable'; Depth = 3 }
    $impacted = @($q.Json.nodes | ForEach-Object id)
    Assert ($impacted -contains 'ax:AxTableExtension:CustTable.ContosoExt' -and $impacted -contains 'ax:AxDataEntityView:ContosoCreditLimitEntity' -and $impacted -contains 'page:code/fno-credit.md') 'impact follows extensions, entities and pages'
    $q = Invoke-Json 'Get-WikiGraph.ps1' @{ WikiPath = $wiki; From = 'REQ-SAL-001'; To = 'AxTable:CustTable' }
    Assert ($q.Json.found -and @($q.Json.edges).Count -le 3 -and @($q.Json.nodes)[0].id -eq 'page:requirements/REQ-SAL-001-credit-check.md') 'shortest connection between a requirement and a table'
    $ai = Join-Path $work 'ai'
    $map = Join-Path $wiki 'reference/knowledge-map.md'
    $null = Invoke-Json 'Get-WikiGraph.ps1' @{ WikiPath = $wiki; OutFile = (Join-Path $work 'graph1.json'); AiExportPath = $ai; ReportPath = $map; Today = '2026-10-01' }
    foreach ($f in @('graph.json', 'llms.txt', 'llms-full.txt', 'graph.html')) { Assert (Test-Path -LiteralPath (Join-Path $ai $f)) "AI export: $f" }
    $null = Invoke-Json 'Get-WikiGraph.ps1' @{ WikiPath = $wiki; OutFile = (Join-Path $work 'graph2.json') }
    Assert ((Get-FileHash (Join-Path $work 'graph1.json')).Hash -eq (Get-FileHash (Join-Path $work 'graph2.json')).Hash) 'graph.json is byte-stable and ignores the generated knowledge map'
    $nl = Get-Content -LiteralPath (Join-Path $ai 'graph.json') -Raw | ConvertFrom-Json -Depth 20
    Assert ($nl.directed -and $nl.multigraph -and @($nl.nodes).Count -gt 0 -and $nl.links[0].source -and $nl.links[0].relation -and $nl.links[0].confidence) 'node-link JSON (networkx, GraphRAG)'
    $llms = Get-Content -LiteralPath (Join-Path $ai 'llms.txt') -Raw
    Assert ($llms -match '(?m)^# Contoso Sales' -and $llms -match '\[REQ-SAL-001 Credit check\]\(requirements/REQ-SAL-001-credit-check\.md\): Orders above') 'llms.txt lists pages with their TL;DR'
    Assert ((Get-Content -LiteralPath (Join-Path $ai 'llms-full.txt') -Raw) -match 'Path: requirements/REQ-SAL-001-credit-check\.md \| Type: requirement \| Status: certified') 'llms-full.txt has page metadata'
    $html = Get-Content -LiteralPath (Join-Path $ai 'graph.html') -Raw
    Assert ($html -notmatch '__GRAPH_DATA__' -and $html -notmatch '<script[^>]+src=' -and $html -notmatch 'https?://' -and $html -match '"REQ-SAL-001 Credit check"') 'graph.html is self-contained with embedded data'
    $mapText = Get-Content -LiteralPath $map -Raw
    Assert ($mapText -match 'generated: true' -and $mapText -match '\[REQ-SAL-001 Credit check\]\(\.\./requirements/REQ-SAL-001-credit-check\.md\)' -and $mapText -match 'RecalculateActivity') 'knowledge map with relative links and gaps'
    $r = Invoke-Json 'Test-WikiLint.ps1' @{ WikiPath = $wiki; Today = '2026-10-01' }
    Assert ($r.Json.errors -eq 0) 'wiki with the knowledge map has no lint errors'
    Remove-Item -LiteralPath $map

    Write-Host 'Export-Wiki azure-devops'
    $ado = Join-Path $work 'ado'
    $r = Invoke-Json 'Export-Wiki.ps1' @{ WikiPath = $wiki; OutPath = $ado; Target = 'azure-devops'; ProjectName = 'Contoso' }
    Assert ($r.Json.pages -eq 8) "8 pages exported (got $($r.Json.pages))"
    Assert (@($r.Json.warnings).Count -eq 0) "no export warnings ($(@($r.Json.warnings) -join '; '))"
    $rootOrder = Get-Content -LiteralPath (Join-Path $ado '.order')
    Assert ($rootOrder[0] -eq 'Home' -and $rootOrder[1] -eq 'Overview') 'root .order starts with Home, Overview'
    $req = Join-Path $ado 'Requirements/REQ%2DSAL%2D001-Credit-check.md'
    Assert (Test-Path -LiteralPath $req) 'hyphens encoded as %2D and spaces as - in file names'
    Assert (Test-Path -LiteralPath (Join-Path $ado 'Requirements.md')) 'generated hub page for folder without index'
    $plugins = Get-Content -LiteralPath (Join-Path $ado 'Code/Plugins.md') -Raw
    Assert ($plugins -match '\(/Requirements/REQ%2DSAL%2D001-Credit-check#acceptance-criteria\)') 'absolute ADO link with anchor'
    Assert ($plugins -match '\(/\.attachments/flow\.png\)') 'image copied to .attachments'
    Assert ($plugins -notmatch '(?m)^---\s*$' -and $plugins -match '\*\*Status:\*\* draft') 'front matter replaced by status callout'
    Assert ($plugins -match '\[\[_TOC_\]\]') 'TOC macro added'
    Assert ($plugins -match '```mermaid') 'mermaid fence preserved'
    Assert ($plugins -match '## 🔗 Related pages' -and $plugins -match '\[REQ-SAL-001 Credit check\]\(/Requirements/REQ%2DSAL%2D001-Credit-check\) \(links here\)') 'related pages section with converted links'
    $reqPage = Get-Content -LiteralPath $req -Raw
    Assert ($reqPage -match '\(implements\)' -and $reqPage -match '\*\*ID:\*\* REQ-SAL-001') 'traceability backlinks and page ID in the callout'
    $meeting = Get-Content -LiteralPath (Get-ChildItem -LiteralPath (Join-Path $ado 'Meetings') -Filter '*.md' | Select-Object -First 1).FullName -Raw
    Assert ($meeting -match 'Original notes \(`\.\./\.\./raw/meetings/kickoff\.md`\)') 'link outside wiki turned into plain text'
    Assert (Test-Path -LiteralPath (Join-Path $ado 'Reference/Decisions.md')) 'nested hub generated'

    Write-Host 'Export-Wiki github'
    $gh = Join-Path $work 'gh'
    $r = Invoke-Json 'Export-Wiki.ps1' @{ WikiPath = $wiki; OutPath = $gh; Target = 'github'; ProjectName = 'Contoso' }
    Assert (Test-Path (Join-Path $gh 'Home.md')) 'Home.md created'
    Assert (Test-Path (Join-Path $gh 'Requirements-REQ-SAL-001-Credit-Check.md')) 'flat page name'
    $plugins = Get-Content -LiteralPath (Join-Path $gh 'Code-Plugins.md') -Raw
    Assert ($plugins -match '\(Requirements-REQ-SAL-001-Credit-Check#acceptance-criteria\)') 'flat link with anchor'
    Assert ($plugins -match '\(images/flow\.png\)') 'image copied to images/'
    $sidebar = Get-Content -LiteralPath (Join-Path $gh '_Sidebar.md') -Raw
    Assert ($sidebar -match '\[Plugins\]\(Code-Plugins\)' -and $sidebar -notmatch '\[\[') 'sidebar uses Markdown links'

    Write-Host 'Install-Engine'
    $hostWiki = Join-Path $work 'host/llm-wiki'
    $r = Invoke-Json 'Install-Engine.ps1' @{ LlmWikiPath = $hostWiki }
    $version = (Get-Content -LiteralPath (Join-Path $repoRoot 'plugins/power-platform-llm-wiki/plugin.json') -Raw | ConvertFrom-Json).version
    Assert ($r.Json.version -eq $version) 'engine version matches plugin.json'
    foreach ($f in @('AGENTS.md', '.engine/VERSION', '.engine/publishing.md', '.engine/tfvc.md', '.engine/skills/update/SKILL.md', '.engine/skills/ingest/SKILL.md', '.engine/skills/query/SKILL.md', '.engine/scripts/Test-WikiLint.ps1', '.engine/templates/requirement.md', '.engine/profiles/dynamics-fno.md')) {
        Assert (Test-Path -LiteralPath (Join-Path $hostWiki $f)) "installed $f"
    }
    $out = & pwsh -NoProfile -File (Join-Path $hostWiki '.engine/scripts/Test-WikiLint.ps1') -WikiPath $wiki -Today '2026-10-01'
    Assert ($LASTEXITCODE -eq 0 -and (($out -join "`n") | ConvertFrom-Json).pages -eq 9) 'vendored lint runs standalone'

    Write-Host 'Build-Site'
    $siteOut = Join-Path $work '_site'
    $out = & pwsh -NoProfile -File (Join-Path $repoRoot 'scripts/Build-Site.ps1') -OutPath $siteOut -BaseUrl 'https://example.github.io/demo' -RepoUrl 'https://github.com/example/demo'
    Assert ($LASTEXITCODE -eq 0) 'site builds'
    $index = Get-Content -LiteralPath (Join-Path $siteOut 'index.html') -Raw
    Assert ($index -notmatch '\{\{[A-Z_]+\}\}') 'no unresolved placeholders'
    Assert ($index -match 'https://example\.github\.io/demo/assets/og\.png') 'BASE_URL applied to og:image'
    Assert ($index -match [regex]::Escape($version)) 'plugin version rendered'
    Assert ((Test-Path (Join-Path $siteOut '.nojekyll')) -and (Test-Path (Join-Path $siteOut 'images/architecture.svg'))) '.nojekyll and shared SVG images copied'
    Assert ((Get-Content -LiteralPath (Join-Path $siteOut 'sitemap.xml') -Raw) -match 'https://example\.github\.io/demo/wizard\.html') 'sitemap uses BASE_URL and lists the wizard'
    $wizard = Get-Content -LiteralPath (Join-Path $siteOut 'wizard.html') -Raw
    Assert ($wizard -notmatch '\{\{[A-Z_]+\}\}' -and $wizard -match 'chat\.plugins\.marketplaces[\s\S]*example/demo') 'wizard page built with REPO_SLUG'
    Assert ($index -match 'href="wizard\.html"') 'home links the wizard page'
    Assert ($index -match 'copilot plugin marketplace add example/demo' -and $index -match 'claude plugin marketplace add example/demo') 'home shows Copilot CLI and Claude Code install commands'
}
finally {
    Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host "Passed: $script:passes  Failed: $script:failures"
if ($script:failures -gt 0) { exit 1 }
