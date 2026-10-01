#Requires -Version 7.0
<#
.SYNOPSIS
    Assembles the GitHub Pages site into a single folder (default: _site).
.DESCRIPTION
    Copies site/ and the shared SVG images from docs/images/ (single source of truth for README and site),
    replaces the placeholders {{BASE_URL}}, {{REPO_URL}}, {{REPO_SLUG}}, {{VERSION}} and adds .nojekyll.
    BaseUrl / RepoUrl default to values derived from the 'origin' remote (owner.github.io/repo).
.PARAMETER OutPath
    Output folder. Deleted and recreated.
.PARAMETER BaseUrl
    Public URL of the site without trailing slash, e.g. https://owner.github.io/repo.
.PARAMETER RepoUrl
    Repository URL, e.g. https://github.com/owner/repo.
#>
[CmdletBinding()]
param(
    [string]$OutPath = '_site',
    [string]$BaseUrl,
    [string]$RepoUrl
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$siteDir = Join-Path $repoRoot 'site'
$imagesDir = Join-Path $repoRoot 'docs/images'

if (-not $RepoUrl) {
    $remote = (& git -C $repoRoot remote get-url origin 2>$null)
    if (-not $remote) { throw 'Cannot derive the repository URL: pass -RepoUrl.' }
    $RepoUrl = ($remote.Trim() -replace '^git@github\.com:', 'https://github.com/' -replace '\.git$', '')
}
$RepoUrl = $RepoUrl.TrimEnd('/')
$slug = $RepoUrl -replace '^https://github\.com/', ''
if ($slug -notmatch '^[^/]+/[^/]+$') { throw "Unexpected repository URL: $RepoUrl" }
$owner, $name = $slug -split '/'
if (-not $BaseUrl) { $BaseUrl = "https://$owner.github.io/$name" }
$BaseUrl = $BaseUrl.TrimEnd('/')
$version = (Get-Content -LiteralPath (Join-Path $repoRoot 'plugins/power-platform-llm-wiki/plugin.json') -Raw | ConvertFrom-Json).version

if (-not [System.IO.Path]::IsPathRooted($OutPath)) { $OutPath = Join-Path (Get-Location) $OutPath }
if (Test-Path -LiteralPath $OutPath) { Remove-Item -LiteralPath $OutPath -Recurse -Force }
New-Item -ItemType Directory -Path $OutPath | Out-Null

Copy-Item -Path (Join-Path $siteDir '*') -Destination $OutPath -Recurse
$outImages = Join-Path $OutPath 'images'
New-Item -ItemType Directory -Path $outImages -Force | Out-Null
Copy-Item -Path (Join-Path $imagesDir '*.svg') -Destination $outImages
New-Item -ItemType File -Path (Join-Path $OutPath '.nojekyll') | Out-Null

$utf8 = [System.Text.UTF8Encoding]::new($false)
$replaced = 0
foreach ($f in (Get-ChildItem -LiteralPath $OutPath -Recurse -File | Where-Object Extension -in '.html', '.xml', '.txt')) {
    $text = [System.IO.File]::ReadAllText($f.FullName)
    $new = $text.Replace('{{BASE_URL}}', $BaseUrl).Replace('{{REPO_URL}}', $RepoUrl).Replace('{{REPO_SLUG}}', $slug).Replace('{{VERSION}}', $version)
    if ($new -match '\{\{[A-Z_]+\}\}') { throw "Unresolved placeholder in $($f.Name): $($Matches[0])" }
    if ($new -ne $text) { [System.IO.File]::WriteAllText($f.FullName, $new, $utf8); $replaced++ }
}

[ordered]@{
    outPath  = $OutPath
    baseUrl  = $BaseUrl
    repoUrl  = $RepoUrl
    version  = $version
    files    = @(Get-ChildItem -LiteralPath $OutPath -Recurse -File).Count
    replaced = $replaced
} | ConvertTo-Json
