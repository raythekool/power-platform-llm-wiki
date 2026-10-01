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
    Assert (Test-Path (Join-Path $work 'lint.md')) 'markdown report written'

    Write-Host 'Test-WikiLint (broken copy)'
    $broken = Join-Path $wiki 'code/plugins.md'
    Add-Content -LiteralPath $broken -Value "`nSee [missing](../nowhere.md) and [[old|alias]].`n`nclient_secret = abcdefgh12345678`n"
    $certified = Join-Path $wiki 'requirements/REQ-SAL-001-credit-check.md'
    (Get-Content -LiteralPath $certified -Raw) -replace 'certified_by: John Customer\r?\n', '' | Set-Content -LiteralPath $certified -NoNewline
    $r = Invoke-Json 'Test-WikiLint.ps1' @{ WikiPath = $wiki; Today = '2026-10-01' }
    $rules = @($r.Json.issues | ForEach-Object rule)
    Assert ($r.Exit -eq 1) 'exit code 1 on errors'
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

    Write-Host 'Export-Wiki azure-devops'
    $ado = Join-Path $work 'ado'
    $r = Invoke-Json 'Export-Wiki.ps1' @{ WikiPath = $wiki; OutPath = $ado; Target = 'azure-devops'; ProjectName = 'Contoso' }
    Assert ($r.Json.pages -eq 7) "7 pages exported (got $($r.Json.pages))"
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
    foreach ($f in @('AGENTS.md', '.engine/VERSION', '.engine/publishing.md', '.engine/skills/update/SKILL.md', '.engine/skills/ingest/SKILL.md', '.engine/skills/query/SKILL.md', '.engine/scripts/Test-WikiLint.ps1', '.engine/templates/requirement.md', '.engine/profiles/dynamics-fno.md')) {
        Assert (Test-Path -LiteralPath (Join-Path $hostWiki $f)) "installed $f"
    }
    $out = & pwsh -NoProfile -File (Join-Path $hostWiki '.engine/scripts/Test-WikiLint.ps1') -WikiPath $wiki -Today '2026-10-01'
    Assert ($LASTEXITCODE -eq 0 -and (($out -join "`n") | ConvertFrom-Json).pages -eq 8) 'vendored lint runs standalone'
}
finally {
    Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host "Passed: $script:passes  Failed: $script:failures"
if ($script:failures -gt 0) { exit 1 }
