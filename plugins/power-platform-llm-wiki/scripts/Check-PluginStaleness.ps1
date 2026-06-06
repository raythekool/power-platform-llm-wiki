<#
.SYNOPSIS
    Checks if llm-wiki plugin scripts have been updated since last check.
.DESCRIPTION
    Runs on SessionStart. Compares local skill scripts against the latest remote
    commits on the default branch. If newer commits exist, outputs a suggestion to
    re-run the relevant skill. Skips if less than 8 hours since last check.
.NOTES
    State is stored in $env:LOCALAPPDATA\llm-wiki-plugin\staleness-state.json
#>

$ErrorActionPreference = "SilentlyContinue"

$stateDir = Join-Path $env:LOCALAPPDATA "llm-wiki-plugin"
$stateFile = Join-Path $stateDir "staleness-state.json"
$checkIntervalHours = 8

$trackedFiles = @(
    @{
        Label       = "init"
        RelPath     = "plugins/llm-wiki/skills/init/SKILL.md"
        Skill       = "init"
        AlwaysCheck = $true
    },
    @{
        Label       = "config"
        RelPath     = "plugins/llm-wiki/skills/config/SKILL.md"
        Skill       = "config"
        AlwaysCheck = $false
    },
    @{
        Label       = "update"
        RelPath     = "plugins/llm-wiki/skills/update/SKILL.md"
        Skill       = "update"
        AlwaysCheck = $false
    },
    @{
        Label       = "ingest"
        RelPath     = "plugins/llm-wiki/skills/ingest/SKILL.md"
        Skill       = "ingest"
        AlwaysCheck = $false
    },
    @{
        Label       = "query"
        RelPath     = "plugins/llm-wiki/skills/query/SKILL.md"
        Skill       = "query"
        AlwaysCheck = $false
    }
)

function Get-RepoRoot {
    $root = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return $root.Replace("/", [IO.Path]::DirectorySeparatorChar)
}

function Read-State {
    if (Test-Path $stateFile) {
        return Get-Content $stateFile -Raw | ConvertFrom-Json
    }
    return $null
}

function Write-State([hashtable]$data) {
    if (-not (Test-Path $stateDir)) {
        New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    }
    $data | ConvertTo-Json -Depth 5 | Set-Content $stateFile -Encoding UTF8
}

$repoRoot = Get-RepoRoot
if (-not $repoRoot) { exit 0 }

$state = Read-State
$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

if ($state -and $state.lastCheckUtc) {
    $elapsed = $now - $state.lastCheckUtc
    if ($elapsed -lt ($checkIntervalHours * 3600)) {
        exit 0
    }
}

git fetch origin --quiet 2>$null
if ($LASTEXITCODE -ne 0) { exit 0 }

$defaultBranch = git symbolic-ref refs/remotes/origin/HEAD 2>$null
if (-not $defaultBranch) { $defaultBranch = "refs/remotes/origin/main" }
$remoteBranch = $defaultBranch -replace "^refs/remotes/", ""

$stale = @()
$newHashes = @{}

foreach ($file in $trackedFiles) {
    if (-not $file.AlwaysCheck) {
        $wikiMarker = Join-Path $repoRoot "wiki.config.yml"
        if (-not (Test-Path $wikiMarker)) {
            continue
        }
    }

    $remoteHash = git log -1 --format="%H" $remoteBranch -- $file.RelPath 2>$null
    if (-not $remoteHash) { continue }

    $newHashes[$file.Label] = $remoteHash

    $storedHash = $null
    if ($state -and $state.fileHashes -and $state.fileHashes.PSObject.Properties[$file.Label]) {
        $storedHash = $state.fileHashes.($file.Label)
    }

    if ($storedHash -and $storedHash -ne $remoteHash) {
        $stale += $file
    }
}

$updatedState = @{
    lastCheckUtc = $now
    fileHashes   = $newHashes
}
Write-State $updatedState

if ($stale.Count -gt 0) {
    Write-Host ""
    Write-Host "=== llm-wiki plugin update detected ==="
    foreach ($f in $stale) {
        Write-Host "  - '$($f.Label)' skill has been updated. Consider re-running the /$($f.Skill) skill."
    }
    Write-Host "================================================"
    Write-Host ""
}
