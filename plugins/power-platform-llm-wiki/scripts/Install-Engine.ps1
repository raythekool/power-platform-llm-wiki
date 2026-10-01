#Requires -Version 7.0
<#
.SYNOPSIS
    Installs or refreshes the managed LLM Wiki engine in a host project (used by `init` and `config --refresh-engine`).
.DESCRIPTION
    Copies from the plugin into <LlmWikiPath>:
      AGENTS.md                         <- references/AGENTS.md
      .engine/skills/<name>/SKILL.md    <- skills/{update,ingest,query}/SKILL.md (for headless runs)
      .engine/scripts/                  <- scripts/*.ps1
      .engine/templates/                <- templates/*.md
      .engine/profiles/                 <- references/profiles/*.md
      .engine/publishing.md             <- references/publishing.md
      .engine/VERSION                   <- plugin.json version
    Never touches wiki/, raw/, templates/ (project overrides), .state/ or wiki.config.yml.
.PARAMETER LlmWikiPath
    Path of the host project's llm-wiki folder (created if missing).
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$LlmWikiPath)

$ErrorActionPreference = 'Stop'
$pluginRoot = Split-Path -Parent $PSScriptRoot
$version = (Get-Content -LiteralPath (Join-Path $pluginRoot 'plugin.json') -Raw | ConvertFrom-Json).version

New-Item -ItemType Directory -Path $LlmWikiPath -Force | Out-Null
$engine = Join-Path $LlmWikiPath '.engine'
if (Test-Path -LiteralPath $engine) { Remove-Item -LiteralPath $engine -Recurse -Force }
New-Item -ItemType Directory -Path $engine | Out-Null

$copied = [System.Collections.Generic.List[string]]::new()
function Copy-Into([string]$Source, [string]$Destination) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $Destination) -Force | Out-Null
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
    $copied.Add([System.IO.Path]::GetRelativePath($LlmWikiPath, $Destination).Replace('\', '/'))
}

Copy-Into (Join-Path $pluginRoot 'references/AGENTS.md') (Join-Path $LlmWikiPath 'AGENTS.md')
Copy-Into (Join-Path $pluginRoot 'references/publishing.md') (Join-Path $engine 'publishing.md')
foreach ($s in @('update', 'ingest', 'query')) {
    Copy-Into (Join-Path $pluginRoot "skills/$s/SKILL.md") (Join-Path $engine "skills/$s/SKILL.md")
}
foreach ($f in Get-ChildItem -LiteralPath (Join-Path $pluginRoot 'scripts') -Filter '*.ps1' -File) { Copy-Into $f.FullName (Join-Path $engine "scripts/$($f.Name)") }
foreach ($f in Get-ChildItem -LiteralPath (Join-Path $pluginRoot 'templates') -Filter '*.md' -File) { Copy-Into $f.FullName (Join-Path $engine "templates/$($f.Name)") }
foreach ($f in Get-ChildItem -LiteralPath (Join-Path $pluginRoot 'references/profiles') -Filter '*.md' -File) { Copy-Into $f.FullName (Join-Path $engine "profiles/$($f.Name)") }
[System.IO.File]::WriteAllText((Join-Path $engine 'VERSION'), "$version`n", [System.Text.UTF8Encoding]::new($false))
$copied.Add('.engine/VERSION')

[ordered]@{ version = $version; llmWiki = (Resolve-Path -LiteralPath $LlmWikiPath).Path; files = $copied } | ConvertTo-Json -Depth 3
