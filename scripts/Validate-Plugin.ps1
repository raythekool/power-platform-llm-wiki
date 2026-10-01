#Requires -Version 7.0
<#
.SYNOPSIS
    Validates the LLM Wiki plugin before release (structure, manifests, skills, confidentiality).
.DESCRIPTION
    Checks:
      1. plugin.json, .mcp.json and marketplace.json are valid; versions match; marketplace entry points to the plugin.
      2. The five skills exist with front matter (name = folder, description) and no unsupported keys.
      3. The agent references only existing skills.
      4. Every file installed by Install-Engine.ps1 exists (scripts, templates, profiles, publishing.md, AGENTS.md).
      5. No legacy v2 references and no [[wiki links]] in templates.
      6. Confidentiality: no customer-specific identifiers or e-mail addresses in distributed files.
         Extra private patterns can be passed with $env:LLMWIKI_DENYLIST (semicolon-separated regexes).
    Exit code 0 when no errors.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$Human
)

$ErrorActionPreference = 'Stop'
$pluginRoot = Join-Path $RepoRoot 'plugins/power-platform-llm-wiki'
$expectedSkills = @('init', 'config', 'update', 'ingest', 'query')
$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

function Read-Json([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { $errors.Add("Missing file: $Path"); return $null }
    try { return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }
    catch { $errors.Add("Invalid JSON: $Path ($($_.Exception.Message))"); return $null }
}

# 1. Manifests
$plugin = Read-Json (Join-Path $pluginRoot 'plugin.json')
$null = Read-Json (Join-Path $pluginRoot '.mcp.json')
$market = Read-Json (Join-Path $RepoRoot '.github/plugin/marketplace.json')
if ($plugin) {
    if (-not $plugin.version) { $errors.Add('plugin.json has no version') }
    if ($plugin.PSObject.Properties['hooks'] -and -not (Test-Path (Join-Path $pluginRoot $plugin.hooks))) { $errors.Add("plugin.json hooks file not found: $($plugin.hooks)") }
}
if ($plugin -and $market) {
    $entry = @($market.plugins)[0]
    if ($entry.name -ne $plugin.name) { $errors.Add("marketplace plugins[0].name '$($entry.name)' != plugin.json name '$($plugin.name)'") }
    if (($entry.source -replace '^\./', '' -replace '/$', '') -ne 'plugins/power-platform-llm-wiki') { $errors.Add("marketplace source '$($entry.source)' does not point to plugins/power-platform-llm-wiki") }
    if ($entry.version -ne $plugin.version -or $market.metadata.version -ne $plugin.version) { $errors.Add("Version mismatch: plugin.json $($plugin.version), marketplace entry $($entry.version), marketplace metadata $($market.metadata.version)") }
}

# 2. Skills
foreach ($s in $expectedSkills) {
    $path = Join-Path $pluginRoot "skills/$s/SKILL.md"
    if (-not (Test-Path -LiteralPath $path)) { $errors.Add("Missing skill: skills/$s/SKILL.md"); continue }
    $raw = Get-Content -LiteralPath $path -Raw
    $fm = [regex]::Match($raw, '(?s)\A---\r?\n(.*?)\r?\n---')
    if (-not $fm.Success) { $errors.Add("skills/$s/SKILL.md has no front matter"); continue }
    $name = [regex]::Match($fm.Groups[1].Value, '(?m)^name:\s*(.+?)\s*$').Groups[1].Value.Trim('"', "'")
    if ($name -ne $s) { $errors.Add("skills/$s/SKILL.md name '$name' != folder '$s'") }
    if ($fm.Groups[1].Value -notmatch '(?m)^description:\s*\S') { $errors.Add("skills/$s/SKILL.md has no description") }
    if ($fm.Groups[1].Value -match '(?m)^context:') { $errors.Add("skills/$s/SKILL.md uses unsupported 'context:' key") }
    if ($fm.Groups[1].Value -match '(?m)^disable-model-invocation:\s*true') { $warnings.Add("skills/$s/SKILL.md hides itself from the agent (disable-model-invocation: true)") }
    if ((Get-Item -LiteralPath $path).Length -gt 20KB) { $warnings.Add("skills/$s/SKILL.md is larger than 20 KB (token cost)") }
}
foreach ($d in (Get-ChildItem -LiteralPath (Join-Path $pluginRoot 'skills') -Directory)) {
    if ($d.Name -notin $expectedSkills) { $warnings.Add("Unexpected skill folder: skills/$($d.Name)") }
}

# 3. Agent
$agentPath = Join-Path $pluginRoot 'agents/llm-wiki.agent.md'
if (-not (Test-Path -LiteralPath $agentPath)) { $errors.Add('Missing agents/llm-wiki.agent.md') }
else {
    $agent = Get-Content -LiteralPath $agentPath -Raw
    foreach ($s in $expectedSkills) { if ($agent -notmatch "``$s``") { $warnings.Add("Agent does not route to skill '$s'") } }
}

# 4. Engine payload
$required = @('references/AGENTS.md', 'references/publishing.md', 'scripts/Install-Engine.ps1', 'scripts/LlmWiki.Common.ps1', 'scripts/Test-WikiLint.ps1', 'scripts/Get-RawDelta.ps1', 'scripts/Get-CodeInventory.ps1', 'scripts/Export-Wiki.ps1',
    'templates/meeting.md', 'templates/requirement.md', 'templates/design.md', 'templates/adr.md', 'templates/code-component.md', 'templates/source.md',
    'references/profiles/power-platform.md', 'references/profiles/dynamics-fno.md', 'references/profiles/generic.md',
    'skills/init/assets/wiki.config.yml', 'skills/init/assets/mcp-servers.json', 'skills/init/assets/copilot-snippet.md', 'skills/init/assets/wiki-index.md', 'skills/init/assets/automation-prompt.md', 'skills/init/assets/copilot-setup-steps.yml')
foreach ($r in $required) { if (-not (Test-Path -LiteralPath (Join-Path $pluginRoot $r))) { $errors.Add("Missing engine file: $r") } }
$null = Read-Json (Join-Path $pluginRoot 'skills/init/assets/mcp-servers.json')

# 5. Legacy references and link syntax
$docs = Get-ChildItem -LiteralPath $pluginRoot -Recurse -File -Include '*.md', '*.yml', '*.json'
$legacy = 'CLAUDE_PLUGIN_ROOT|llm-wiki/skills/|skills/init\.md|llm-wiki-sync-|llm-wiki-full-update|copilot_setup\b|@azure-devops/mcp@latest'
foreach ($f in $docs) {
    foreach ($m in (Select-String -LiteralPath $f.FullName -Pattern $legacy)) { $errors.Add("Legacy reference in $([IO.Path]::GetRelativePath($RepoRoot, $f.FullName)):$($m.LineNumber): $($m.Matches[0].Value)") }
}
foreach ($f in (Get-ChildItem -LiteralPath (Join-Path $pluginRoot 'templates') -File)) {
    if ((Get-Content -LiteralPath $f.FullName -Raw) -match '\[\[(?!_TOC_)') { $errors.Add("Template uses [[wiki links]]: templates/$($f.Name)") }
}

# 6. Confidentiality
$deny = @('ava-client-[a-z0-9\-]+')
if ($env:LLMWIKI_DENYLIST) { $deny += $env:LLMWIKI_DENYLIST -split ';' | Where-Object { $_ } }
$distributed = Get-ChildItem -LiteralPath $pluginRoot -Recurse -File | Where-Object Extension -in '.md', '.yml', '.json', '.ps1'
foreach ($f in $distributed) {
    $text = Get-Content -LiteralPath $f.FullName -Raw
    foreach ($p in $deny) {
        foreach ($m in [regex]::Matches($text, $p, 'IgnoreCase')) { $errors.Add("Confidential identifier '$($m.Value)' in $([IO.Path]::GetRelativePath($RepoRoot, $f.FullName))") }
    }
    foreach ($m in [regex]::Matches($text, '\b[A-Za-z0-9._%+\-]+@(?!example\.|contoso\.)[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b')) {
        if ($m.Value -notmatch '^(azure-devops/mcp|copilot)@') { $warnings.Add("E-mail-like string '$($m.Value)' in $([IO.Path]::GetRelativePath($RepoRoot, $f.FullName))") }
    }
}

# 7. Documentation: relative links / images exist, SVGs are well-formed
$docFiles = @(Join-Path $RepoRoot 'README.md'; Join-Path $RepoRoot 'CONTRIBUTING.md'; Join-Path $pluginRoot 'README.md')
$docsDir = Join-Path $RepoRoot 'docs'
if (Test-Path -LiteralPath $docsDir) { $docFiles += (Get-ChildItem -LiteralPath $docsDir -Filter '*.md' -File).FullName }
foreach ($d in $docFiles) {
    if (-not (Test-Path -LiteralPath $d)) { $errors.Add("Missing documentation file: $([IO.Path]::GetRelativePath($RepoRoot, $d))"); continue }
    $text = Get-Content -LiteralPath $d -Raw
    $text = [regex]::Replace($text, '(?ms)^[ \t]*```.*?^[ \t]*```', '')
    $text = [regex]::Replace($text, '`[^`\r\n]*`', '')
    $targets = @([regex]::Matches($text, '(?<!\!)\]\(([^)\s#]+)(?:#[^)]*)?\)') | ForEach-Object { $_.Groups[1].Value }) +
    @([regex]::Matches($text, '(?:src|href)="([^"#]+)(?:#[^"]*)?"') | ForEach-Object { $_.Groups[1].Value }) +
    @([regex]::Matches($text, '!\[[^\]]*\]\(([^)\s#]+)\)') | ForEach-Object { $_.Groups[1].Value })
    foreach ($t in ($targets | Sort-Object -Unique)) {
        if ($t -match '^[A-Za-z][A-Za-z0-9+.\-]*:' -or $t.StartsWith('#')) { continue }
        $resolved = [IO.Path]::GetFullPath([IO.Path]::Combine((Split-Path -Parent $d), [Uri]::UnescapeDataString($t)))
        if (-not (Test-Path -LiteralPath $resolved)) { $errors.Add("Broken link '$t' in $([IO.Path]::GetRelativePath($RepoRoot, $d))") }
    }
}
if (Test-Path -LiteralPath (Join-Path $docsDir 'images')) {
    foreach ($svg in (Get-ChildItem -LiteralPath (Join-Path $docsDir 'images') -Filter '*.svg' -File)) {
        try {
            $x = [xml](Get-Content -LiteralPath $svg.FullName -Raw)
            if (-not $x.svg.title -or -not $x.svg.desc) { $warnings.Add("SVG without title/desc (accessibility): docs/images/$($svg.Name)") }
        }
        catch { $errors.Add("Invalid SVG: docs/images/$($svg.Name) ($($_.Exception.Message))") }
    }
}

# 8. Website (site/): required files, local references resolve, placeholders known, confidentiality
$siteDir = Join-Path $RepoRoot 'site'
if (Test-Path -LiteralPath $siteDir) {
    foreach ($r in @('index.html', 'styles.css', 'main.js', 'favicon.svg', 'sitemap.xml', 'robots.txt', 'assets/og.png')) {
        if (-not (Test-Path -LiteralPath (Join-Path $siteDir $r))) { $errors.Add("Missing site file: site/$r") }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot 'scripts/Build-Site.ps1'))) { $errors.Add('Missing scripts/Build-Site.ps1') }
    $known = '{{BASE_URL}}', '{{REPO_URL}}', '{{REPO_SLUG}}', '{{VERSION}}'
    foreach ($f in (Get-ChildItem -LiteralPath $siteDir -Recurse -File | Where-Object Extension -in '.html', '.css', '.js', '.xml', '.txt', '.svg')) {
        $rel = [IO.Path]::GetRelativePath($RepoRoot, $f.FullName)
        $text = Get-Content -LiteralPath $f.FullName -Raw
        foreach ($m in [regex]::Matches($text, '\{\{[A-Z_]+\}\}')) { if ($m.Value -notin $known) { $errors.Add("Unknown placeholder '$($m.Value)' in $rel") } }
        foreach ($p in $deny) { foreach ($m in [regex]::Matches($text, $p, 'IgnoreCase')) { $errors.Add("Confidential identifier '$($m.Value)' in $rel") } }
    }
    $indexPath = Join-Path $siteDir 'index.html'
    if (Test-Path -LiteralPath $indexPath) {
        $html = Get-Content -LiteralPath $indexPath -Raw
        $refs = [regex]::Matches($html, '(?:src|href|content)="([^"#]+)(?:#[^"]*)?"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
        foreach ($t in $refs) {
            if ($t -match '^[A-Za-z][A-Za-z0-9+.\-]*:' -or $t -match '^\{\{(REPO_URL|REPO_SLUG|VERSION)\}\}' -or $t -notmatch '[/.]') { continue }
            $local = $t -replace '^\{\{BASE_URL\}\}/?', ''
            if ($local -match '[\s{}]') { continue }
            $candidate = if ($local -like 'images/*') { Join-Path $RepoRoot ('docs/' + $local) } else { Join-Path $siteDir $local }
            if ($local -and -not (Test-Path -LiteralPath $candidate)) { $errors.Add("Broken reference '$t' in site/index.html") }
        }
    }
}

$ok = $errors.Count -eq 0
if ($Human) {
    Write-Host "=== LLM Wiki plugin validation ($(if ($plugin) { $plugin.version }))"
    Write-Host ("RESULT: " + $(if ($ok) { 'PASS' } else { 'FAIL' }))
    if ($errors.Count) { Write-Host 'Errors:'; $errors | ForEach-Object { Write-Host "  - $_" } }
    if ($warnings.Count) { Write-Host 'Warnings:'; $warnings | ForEach-Object { Write-Host "  - $_" } }
}
else {
    [ordered]@{ ok = $ok; version = $plugin.version; errors = $errors; warnings = $warnings } | ConvertTo-Json -Depth 3
}
if (-not $ok) { exit 1 }
