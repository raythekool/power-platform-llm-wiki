<#
.SYNOPSIS
    Validates the llm-wiki plugin structure and root↔plugin skill parity.
.DESCRIPTION
    Deterministic checks (emits JSON + a human-readable summary on -Human):
      1. plugin.json / hooks.json / .mcp.json are valid JSON.
      2. The five expected skills exist as skills/<name>/SKILL.md with YAML frontmatter (name + description).
      3. Each SKILL.md 'name' matches its folder name.
      4. The agent file (agents/llm-wiki.agent.md) references only existing skills.
      5. Root skills/<name>.md mirror the plugin skills (same five names).
      6. No stale legacy skill-name references remain in plugin docs.
    Exit code 0 when all checks pass, 1 otherwise.
.PARAMETER RepoRoot
    Repository root. Defaults to two levels above this script (plugin root's parent's parent).
.PARAMETER Human
    Emit a human-readable summary instead of raw JSON.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [switch]$Human
)

$ErrorActionPreference = "Stop"

if (-not $RepoRoot) {
    # script is at <repoRoot>/plugins/llm-wiki/scripts/Validate-Plugin.ps1
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
}

$pluginRoot = Join-Path $RepoRoot "plugins\llm-wiki"
$expectedSkills = @("init", "config", "update", "ingest", "query")
$legacyPattern = 'llm-wiki-setup\.md|llm-wiki-sync-|llm-wiki-full-update|llm-wiki-ingest\.md|llm-wiki-ingest-meeting|llm-wiki-lint\.md|llm-wiki-publish\.md|llm-wiki-query\.md|llm-wiki-sprint-snapshot|skills/llm-wiki-'

$errors = @()
$warnings = @()

function Get-Frontmatter([string]$path) {
    $raw = Get-Content $path -Raw
    if ($raw -notmatch '(?s)^\s*---\r?\n(.*?)\r?\n---') { return $null }
    return $Matches[1]
}

# 1. JSON manifests
foreach ($j in @("plugin.json", "hooks.json", ".mcp.json")) {
    $p = Join-Path $pluginRoot $j
    if (-not (Test-Path $p)) { $errors += "Missing manifest: $j"; continue }
    try { Get-Content $p -Raw | ConvertFrom-Json | Out-Null }
    catch { $errors += "Invalid JSON: $j ($($_.Exception.Message))" }
}

# plugin.json version present
$pjPath = Join-Path $pluginRoot "plugin.json"
if (Test-Path $pjPath) {
    $pj = Get-Content $pjPath -Raw | ConvertFrom-Json
    if (-not $pj.version) { $warnings += "plugin.json has no 'version' field" }
}

# 2 & 3. Plugin skills
$pluginSkillNames = @()
foreach ($s in $expectedSkills) {
    $sk = Join-Path $pluginRoot "skills\$s\SKILL.md"
    if (-not (Test-Path $sk)) { $errors += "Missing plugin skill: skills/$s/SKILL.md"; continue }
    $fm = Get-Frontmatter $sk
    if (-not $fm) { $errors += "skills/$s/SKILL.md has no YAML frontmatter"; continue }
    $nameMatch = [regex]::Match($fm, '(?m)^name:\s*(.+?)\s*$')
    $descMatch = [regex]::Match($fm, '(?m)^description:\s*')
    if (-not $nameMatch.Success) { $errors += "skills/$s/SKILL.md frontmatter missing 'name'" }
    else {
        $nm = $nameMatch.Groups[1].Value.Trim().Trim('"').Trim("'")
        $pluginSkillNames += $nm
        if ($nm -ne $s) { $errors += "skills/$s/SKILL.md name '$nm' != folder '$s'" }
    }
    if (-not $descMatch.Success) { $errors += "skills/$s/SKILL.md frontmatter missing 'description'" }
}

# Unexpected extra plugin skill folders
$actualSkillDirs = @()
$skillsDir = Join-Path $pluginRoot "skills"
if (Test-Path $skillsDir) {
    $actualSkillDirs = Get-ChildItem $skillsDir -Directory | Select-Object -ExpandProperty Name
    foreach ($d in $actualSkillDirs) {
        if ($expectedSkills -notcontains $d) { $warnings += "Unexpected plugin skill folder: skills/$d" }
    }
}

# 4. Agent references existing skills
$agentPath = Join-Path $pluginRoot "agents\llm-wiki.agent.md"
if (-not (Test-Path $agentPath)) { $errors += "Missing agent: agents/llm-wiki.agent.md" }
else {
    $agent = Get-Content $agentPath -Raw
    foreach ($s in $expectedSkills) {
        if ($agent -notmatch "\b$s\b") { $warnings += "Agent file does not mention skill '$s'" }
    }
    # any reference to a non-existent skill folder name pattern
    $refMatches = [regex]::Matches($agent, 'skills/([a-z0-9\-]+)/')
    foreach ($m in $refMatches) {
        $ref = $m.Groups[1].Value
        if ($expectedSkills -notcontains $ref) { $errors += "Agent references non-existent skill 'skills/$ref'" }
    }
}

# 5. Root skill parity
$rootSkillsDir = Join-Path $RepoRoot "skills"
foreach ($s in $expectedSkills) {
    $rp = Join-Path $rootSkillsDir "$s.md"
    if (-not (Test-Path $rp)) { $warnings += "Root skill missing (parity): skills/$s.md" }
}

# 6. Legacy references in plugin docs
$pluginDocs = Get-ChildItem $pluginRoot -Recurse -Include *.md -File
$legacyHits = @()
foreach ($f in $pluginDocs) {
    $m = Select-String -Path $f.FullName -Pattern $legacyPattern -ErrorAction SilentlyContinue
    if ($m) { $legacyHits += $m | ForEach-Object { "$($_.Path):$($_.LineNumber)" } }
}
if ($legacyHits.Count -gt 0) { $errors += "Legacy skill references in plugin docs: $($legacyHits -join ', ')" }

$ok = ($errors.Count -eq 0)
$result = [ordered]@{
    Ok                = $ok
    RepoRoot          = $RepoRoot
    ExpectedSkills    = $expectedSkills
    PluginSkillNames  = $pluginSkillNames
    ActualSkillDirs   = $actualSkillDirs
    Errors            = $errors
    Warnings          = $warnings
}

if ($Human) {
    Write-Host ""
    Write-Host "=== llm-wiki plugin validation ==="
    Write-Host "Repo root : $RepoRoot"
    Write-Host "Skills    : $($actualSkillDirs -join ', ')"
    if ($ok) { Write-Host "RESULT    : PASS" } else { Write-Host "RESULT    : FAIL" }
    if ($errors.Count) {
        Write-Host ""
        Write-Host "Errors:"
        $errors | ForEach-Object { Write-Host "  - $_" }
    }
    if ($warnings.Count) {
        Write-Host ""
        Write-Host "Warnings:"
        $warnings | ForEach-Object { Write-Host "  - $_" }
    }
    Write-Host "=================================="
}
else {
    $result | ConvertTo-Json -Depth 5
}

if (-not $ok) { exit 1 } else { exit 0 }
