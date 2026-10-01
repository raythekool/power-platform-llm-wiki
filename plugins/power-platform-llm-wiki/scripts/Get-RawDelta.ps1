#Requires -Version 7.0
<#
.SYNOPSIS
    Incremental change detection for llm-wiki/raw/ (hash manifest), so only new or changed sources are processed.
.DESCRIPTION
    Compares SHA-256 hashes of files under raw/ with llm-wiki/.state/raw-manifest.json and returns JSON:
      new / changed      readable sources (.md/.txt) to ingest
      needsConversion    non-Markdown files (docx, pdf, pptx, xlsx, ...) with no up-to-date .md sibling
      deleted            files tracked in the manifest that no longer exist
    The manifest is only written with -MarkProcessed (after a successful ingest) or -Baseline.
    Sync dumps (raw/devops, raw/github, raw/dataverse, raw/code, raw/fno) are excluded unless -IncludeDumps.
.PARAMETER RawPath
    Path to llm-wiki/raw.
.PARAMETER StatePath
    Manifest path. Default: <RawPath>/../.state/raw-manifest.json
.PARAMETER MarkProcessed
    Relative paths (from raw/) to record as processed. Non-Markdown siblings with the same base name are recorded too.
.PARAMETER Baseline
    Record every current file as processed without ingesting (adopting an existing wiki).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RawPath,
    [string]$StatePath,
    [string[]]$MarkProcessed = @(),
    [switch]$Baseline,
    [switch]$IncludeDumps
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/LlmWiki.Common.ps1"

$RawPath = (Resolve-Path -LiteralPath $RawPath).Path
if (-not $StatePath) { $StatePath = Join-Path (Split-Path -Parent $RawPath) '.state/raw-manifest.json' }
$readable = @('.md', '.txt')
$dumpDirs = @('devops', 'github', 'dataverse', 'code', 'fno')

$manifest = @{ version = 1; files = @{} }
if (Test-Path -LiteralPath $StatePath) {
    $loaded = Read-Utf8Text $StatePath | ConvertFrom-Json -AsHashtable
    if ($loaded.files) { $manifest.files = $loaded.files }
}

$current = @{}
foreach ($f in (Get-ChildItem -LiteralPath $RawPath -Recurse -File)) {
    $rel = Get-RelativePath $RawPath $f.FullName
    if ($f.Name -in @('.placeholder', '.gitkeep')) { continue }
    if (-not $IncludeDumps -and ($rel.Split('/')[0] -in $dumpDirs)) { continue }
    $current[$rel] = [pscustomobject]@{ Rel = $rel; Full = $f.FullName; Ext = $f.Extension.ToLowerInvariant(); Size = $f.Length; Hash = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash }
}

function Get-MdSibling([string]$Rel) {
    $dot = $Rel.LastIndexOf('.')
    if ($dot -lt 0) { return "$Rel.md" }
    return $Rel.Substring(0, $dot) + '.md'
}

$now = (Get-Date).ToUniversalTime().ToString('o')
if ($Baseline -or $MarkProcessed.Count -gt 0) {
    $toMark = if ($Baseline) { @($current.Keys) } else {
        $set = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($p in $MarkProcessed) {
            $norm = $p.Replace('\', '/') -replace '^\./', ''
            if ($norm.StartsWith('raw/')) { $norm = $norm.Substring(4) }
            if (-not $current.ContainsKey($norm)) { Write-Warning "Not found under raw/: $p"; continue }
            [void]$set.Add($norm)
            if ($current[$norm].Ext -eq '.md') {
                foreach ($c in $current.Values) { if ($c.Ext -notin $readable -and (Get-MdSibling $c.Rel) -eq $norm) { [void]$set.Add($c.Rel) } }
            }
        }
        @($set)
    }
    foreach ($rel in $toMark) { $manifest.files[$rel] = @{ sha256 = $current[$rel].Hash; processedAt = $now } }
    foreach ($rel in @($manifest.files.Keys)) { if (-not $current.ContainsKey($rel) -and $Baseline) { $manifest.files.Remove($rel) } }
    Write-Utf8Text $StatePath ($manifest | ConvertTo-Json -Depth 5)
}

$new = @(); $changed = @(); $needsConversion = @(); $bytes = 0
foreach ($c in ($current.Values | Sort-Object Rel)) {
    $tracked = $manifest.files[$c.Rel]
    $isChanged = $tracked -and $tracked.sha256 -ne $c.Hash
    if ($c.Ext -in $readable) {
        if (-not $tracked) { $new += $c.Rel; $bytes += $c.Size }
        elseif ($isChanged) { $changed += $c.Rel; $bytes += $c.Size }
    }
    else {
        $sibling = Get-MdSibling $c.Rel
        if (-not $current.ContainsKey($sibling) -or $isChanged) { $needsConversion += $c.Rel }
    }
}
$deleted = @($manifest.files.Keys | Where-Object { -not $current.ContainsKey($_) } | Sort-Object)

[ordered]@{
    raw             = $RawPath
    manifest        = $StatePath
    new             = $new
    changed         = $changed
    needsConversion = $needsConversion
    deleted         = $deleted
    unchanged       = ($current.Count - $new.Count - $changed.Count - $needsConversion.Count)
    pendingKB       = [math]::Round($bytes / 1KB, 1)
} | ConvertTo-Json -Depth 4
