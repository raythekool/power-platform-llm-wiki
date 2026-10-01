#Requires -Version 7.0
<#
.SYNOPSIS
    Converts the canonical llm-wiki/wiki (Markdown + relative links + front matter) into a ready-to-push
    Azure DevOps Wiki or GitHub Wiki tree. Pure file transformation: it never runs git.
.DESCRIPTION
    azure-devops  Page tree with sibling <Page>.md + <Page>/ folders and .order files; file names and link
                  targets encode literal hyphens as %2D and spaces as '-'; absolute links (/Mount/Page);
                  [[_TOC_]] on pages with 2+ sections; images copied to /.attachments.
    github        Flat page names (Category-Page), [text](Page-Name) links, _Sidebar.md, _Footer.md,
                  images copied to images/.
    Both: front matter is stripped and replaced by a one-line status callout; links that point outside
    the wiki (e.g. raw/) become plain text; legacy [[wiki links]] are resolved when possible.
.PARAMETER WikiPath
    Path to llm-wiki/wiki.
.PARAMETER OutPath
    Output folder (e.g. llm-wiki/dist/azure-devops). Typically the working tree of the cloned wiki repo.
.PARAMETER MountFolder
    Azure DevOps only: optional parent page that hosts the whole wiki (e.g. "Project Knowledge Base").
.PARAMETER Clean
    Delete everything in OutPath except .git before writing.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$WikiPath,
    [Parameter(Mandatory)][string]$OutPath,
    [Parameter(Mandatory)][ValidateSet('azure-devops', 'github')][string]$Target,
    [string]$ProjectName = '',
    [string]$MountFolder = '',
    [string[]]$Exclude = @('log.md', 'lint-*.md'),
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/LlmWiki.Common.ps1"

$WikiPath = (Resolve-Path -LiteralPath $WikiPath).Path
if (-not (Test-Path -LiteralPath $OutPath)) { New-Item -ItemType Directory -Path $OutPath -Force | Out-Null }
$OutPath = (Resolve-Path -LiteralPath $OutPath).Path
if (Test-PathUnder $OutPath $WikiPath) { throw 'OutPath must not be inside WikiPath.' }
if ($Clean) {
    Get-ChildItem -LiteralPath $OutPath -Force | Where-Object Name -ne '.git' | Remove-Item -Recurse -Force
}

$preferredOrder = @('delivery', 'requirements', 'design', 'features', 'projects', 'code', 'meetings', 'reference')
$warnings = [System.Collections.Generic.List[string]]::new()
$today = Get-Date -Format 'yyyy-MM-dd'

# ---------- load pages ----------
$pages = @{}
foreach ($f in (Get-MarkdownPages $WikiPath -Exclude $Exclude)) {
    $text = Read-Utf8Text $f.FullName
    $fm = Split-Frontmatter $text
    $rel = Get-RelativePath $WikiPath $f.FullName
    $pages[$f.FullName.ToLowerInvariant()] = [pscustomobject]@{
        Rel   = $rel
        Full  = $f.FullName
        Data  = $fm.Data
        Body  = $fm.Body
        Title = Get-PageTitle $fm.Body (ConvertTo-TitleCase ([System.IO.Path]::GetFileNameWithoutExtension($f.Name)))
        Link  = $null
        Out   = $null
    }
}

function Get-SortedChildren([string]$Dir, [object[]]$Files, [object[]]$Dirs) {
    $dirName = Split-Path -Leaf $Dir
    $isDated = @($Files | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}' }).Count -gt ($Files.Count / 2)
    $sortedFiles = if ($isDated -or $dirName -eq 'meetings') { $Files | Sort-Object Name -Descending } else { $Files | Sort-Object Name }
    $sortedDirs = $Dirs | Sort-Object @{ e = { $i = $preferredOrder.IndexOf($_.Name); if ($i -lt 0) { 999 } else { $i } } }, Name
    return @{ Files = @($sortedFiles); Dirs = @($sortedDirs) }
}

# ---------- shared body transformation ----------
function Add-Callout([string]$Body, $Data, [bool]$Toc) {
    $parts = @()
    $status = Get-FmValue $Data 'status'
    if ($status) { $parts += "**Status:** $status" }
    $owner = Get-FmValue $Data 'owner'
    if ($owner) { $parts += "**Owner:** $owner" }
    $certBy = Get-FmValue $Data 'certified_by'
    if ($status -eq 'certified' -and $certBy) { $parts += "**Certified by:** $certBy ($(Get-FmValue $Data 'certified_at'))" }
    $updated = Get-FmValue $Data 'updated'
    if ($updated) { $parts += "**Updated:** $updated" }
    $insert = @()
    if ($parts.Count) { $insert += '> ' + ($parts -join ' &middot; ') }
    if ($Toc) { $insert += '[[_TOC_]]' }
    if (-not $insert.Count) { return $Body }
    $block = "`n" + ($insert -join "`n`n") + "`n"
    $h1 = [regex]::Match((Remove-CodeSpans $Body), '(?m)^#[ \t]+.+$')
    if ($h1.Success) { return $Body.Insert($h1.Index + $h1.Length, "`n" + $block) }
    return $block.TrimStart() + "`n" + $Body
}

$attachments = @{}
function Get-AttachmentLink([string]$Full) {
    $key = $Full.ToLowerInvariant()
    if (-not $attachments.ContainsKey($key)) {
        $name = [System.IO.Path]::GetFileName($Full) -replace '[^\w.\-]', '_'
        if ($attachments.Values.Name -contains $name) { $name = "$($attachments.Count)-$name" }
        $folder = if ($Target -eq 'azure-devops') { '.attachments' } else { 'images' }
        $dest = Join-Path (Join-Path $OutPath $folder) $name
        New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
        Copy-Item -LiteralPath $Full -Destination $dest -Force
        $link = if ($Target -eq 'azure-devops') { "/.attachments/$name" } else { "images/$name" }
        $attachments[$key] = [pscustomobject]@{ Name = $name; Link = $link }
    }
    return $attachments[$key].Link
}

function Convert-Body($Page) {
    $body = $Page.Body
    # legacy [[wiki links]]
    foreach ($wl in (@(Get-WikiLinks $body) | Sort-Object Index -Descending)) {
        $inner = ($wl.Inner -split '\|')[0].Trim()
        $label = ($wl.Inner -split '\|')[-1].Trim()
        $candidate = [System.IO.Path]::GetFullPath((Join-Path $WikiPath ($inner + $(if ($inner.EndsWith('.md')) { '' } else { '.md' }))))
        $p = $pages[$candidate.ToLowerInvariant()]
        $replacement = if ($p) { "[$($p.Title)]($($p.Link))" } else { $warnings.Add("$($Page.Rel): unresolved [[$inner]]"); $label }
        $body = $body.Remove($wl.Index, $wl.Length).Insert($wl.Index, $replacement)
    }
    foreach ($l in (@(Get-LocalLinks $body) | Sort-Object Index -Descending)) {
        $resolved = Resolve-LinkPath $Page.Full $l.Path
        $p = $pages[$resolved.ToLowerInvariant()]
        if ($p) { $replacement = "$(if ($l.IsImage) { '!' })[$($l.Text)]($($p.Link)$($l.Anchor))" }
        elseif ((Test-Path -LiteralPath $resolved -PathType Leaf) -and $resolved -notmatch '\.md$') {
            $replacement = "$(if ($l.IsImage) { '!' })[$($l.Text)]($(Get-AttachmentLink $resolved))"
        }
        else {
            if (-not $l.IsImage -and -not (Test-PathUnder $resolved $WikiPath)) { $replacement = "$($l.Text) (``$($l.Path)``)" }
            else { $warnings.Add("$($Page.Rel): unresolved link $($l.Target)"); $replacement = $l.Text }
        }
        $body = $body.Remove($l.Index, $l.Length).Insert($l.Index, $replacement)
    }
    $toc = ($Target -eq 'azure-devops') -and (([regex]::Matches((Remove-CodeSpans $body), '(?m)^##[ \t]')).Count -ge 2)
    return (Add-Callout $body $Page.Data $toc).TrimStart("`r", "`n")
}

# ---------- Azure DevOps ----------
function ConvertTo-AdoName([string]$Title) {
    $t = ($Title -replace '[\\/:*?"<>|#%\[\]]', ' ' -replace '\s+', ' ').Trim()
    if ($t.Length -gt 120) { $t = $t.Substring(0, 120).Trim() }
    if (-not $t) { $t = 'Page' }
    return $t
}
function ConvertTo-AdoSegment([string]$Name) { return (($Name -replace '-', '%2D') -replace ' ', '-') }

function New-AdoNode([string]$Name, $Page, [string]$GeneratedTitle) {
    [pscustomobject]@{ Name = $Name; Page = $Page; GeneratedTitle = $GeneratedTitle; Children = [System.Collections.Generic.List[object]]::new(); Segments = @() }
}

function Add-UniqueChild($Parent, $Node) {
    $base = $Node.Name; $n = 2
    while ($Parent.Children | Where-Object { $_.Name -eq $Node.Name }) { $Node.Name = "$base $n"; $n++ }
    $Parent.Children.Add($Node)
}

function Build-AdoTree([string]$Dir, $Parent) {
    $files = @(Get-ChildItem -LiteralPath $Dir -File -Filter '*.md' | Where-Object { $pages.ContainsKey($_.FullName.ToLowerInvariant()) })
    $dirs = @(Get-ChildItem -LiteralPath $Dir -Directory | Where-Object { @(Get-ChildItem -LiteralPath $_.FullName -Recurse -File -Filter '*.md' | Where-Object { $pages.ContainsKey($_.FullName.ToLowerInvariant()) }).Count -gt 0 })
    $isRoot = ($Dir -eq $WikiPath)
    $sorted = Get-SortedChildren $Dir ($files | Where-Object { $isRoot -or $_.Name -ne 'index.md' }) $dirs
    $rootPages = @()
    foreach ($f in $sorted.Files) {
        $p = $pages[$f.FullName.ToLowerInvariant()]
        if ($isRoot -and $f.Name -eq 'index.md') { continue }
        $name = if ($isRoot -and $f.Name -eq 'overview.md') { 'Overview' } else { ConvertTo-AdoName $p.Title }
        $node = New-AdoNode $name $p $null
        if ($isRoot -and $f.Name -eq 'overview.md') { $rootPages = @($node) + $rootPages } else { $rootPages += $node }
    }
    $dirNodes = @()
    foreach ($d in $sorted.Dirs) {
        $hubFile = Join-Path $d.FullName 'index.md'
        $hub = $pages[$hubFile.ToLowerInvariant()]
        $title = if ($hub) { ConvertTo-AdoName $hub.Title } else { ConvertTo-TitleCase $d.Name }
        $node = New-AdoNode $title $hub $title
        Build-AdoTree $d.FullName $node
        $dirNodes += $node
    }
    if ($isRoot) {
        foreach ($n in ($rootPages | Where-Object { $_.Name -eq 'Overview' })) { Add-UniqueChild $Parent $n }
        foreach ($n in $dirNodes) { Add-UniqueChild $Parent $n }
        foreach ($n in ($rootPages | Where-Object { $_.Name -ne 'Overview' })) { Add-UniqueChild $Parent $n }
    }
    else {
        foreach ($n in $dirNodes) { Add-UniqueChild $Parent $n }
        foreach ($n in $rootPages) { Add-UniqueChild $Parent $n }
    }
}

function Set-AdoSegments($Node, [string[]]$ParentSegments) {
    foreach ($c in $Node.Children) {
        $c.Segments = @($ParentSegments) + (ConvertTo-AdoSegment $c.Name)
        if ($c.Page) { $c.Page.Link = '/' + ($c.Segments -join '/') }
        Set-AdoSegments $c $c.Segments
    }
}

function Write-AdoNode($Node, [string]$Dir) {
    if ($Node.Children.Count -eq 0) { return }
    $folder = $Dir
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    Write-Utf8Text (Join-Path $folder '.order') ((($Node.Children | ForEach-Object { ConvertTo-AdoSegment $_.Name }) -join "`n") + "`n")
    foreach ($c in $Node.Children) {
        $seg = ConvertTo-AdoSegment $c.Name
        $content = if ($c.Page) { Convert-Body $c.Page }
        else {
            $lines = @("# $($c.GeneratedTitle)", '')
            foreach ($child in $c.Children) { $lines += "- [$($child.Name)](/$($child.Segments -join '/'))" }
            ($lines -join "`n") + "`n"
        }
        Write-Utf8Text (Join-Path $folder "$seg.md") $content
        Write-AdoNode $c (Join-Path $folder $seg)
    }
}

# ---------- GitHub ----------
function ConvertTo-GitHubName([string]$Rel) {
    if ($Rel -eq 'index.md') { return 'Home' }
    if ($Rel -eq 'overview.md') { return 'Overview' }
    $noExt = $Rel -replace '\.md$', '' -replace '/index$', ''
    $segs = $noExt -split '/' | ForEach-Object { (ConvertTo-TitleCase $_) -replace '[^A-Za-z0-9 ]', '' -replace ' ', '-' }
    return ($segs -join '-')
}

# ---------- run ----------
if ($Target -eq 'azure-devops') {
    $root = New-AdoNode '' $null $null
    $homePage = $pages[(Join-Path $WikiPath 'index.md').ToLowerInvariant()]
    if (-not $homePage) { throw 'wiki/index.md is required.' }
    if ($MountFolder) {
        $mount = New-AdoNode (ConvertTo-AdoName $MountFolder) $homePage $null
        Build-AdoTree $WikiPath $mount
        $root.Children.Add($mount)
    }
    else {
        $root.Children.Add((New-AdoNode 'Home' $homePage $null))
        Build-AdoTree $WikiPath $root
    }
    Set-AdoSegments $root @()
    foreach ($p in $pages.Values) { if (-not $p.Link) { $warnings.Add("$($p.Rel): not placed in tree") } }
    Write-AdoNode $root $OutPath
}
else {
    $names = @{}
    foreach ($p in ($pages.Values | Sort-Object Rel)) {
        $n = ConvertTo-GitHubName $p.Rel; $base = $n; $i = 2
        while ($names.ContainsKey($n)) { $n = "$base-$i"; $i++ }
        $names[$n] = $true
        $p.Link = $n
        $p.Out = Join-Path $OutPath "$n.md"
    }
    foreach ($p in $pages.Values) { Write-Utf8Text $p.Out (Convert-Body $p) }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("**$(if ($ProjectName) { $ProjectName } else { 'Project wiki' })**")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('- [Home](Home)')
    if ($pages.Values | Where-Object Rel -eq 'overview.md') { [void]$sb.AppendLine('- [Overview](Overview)') }
    $groups = $pages.Values | Where-Object { $_.Rel.Contains('/') } | Group-Object { $_.Rel.Split('/')[0] } |
    Sort-Object @{ e = { $i = $preferredOrder.IndexOf($_.Name); if ($i -lt 0) { 999 } else { $i } } }, Name
    foreach ($g in $groups) {
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine("**$(ConvertTo-TitleCase $g.Name)**")
        [void]$sb.AppendLine('')
        $items = if ($g.Name -eq 'meetings') { $g.Group | Sort-Object Rel -Descending } else { $g.Group | Sort-Object Rel }
        foreach ($p in $items) { [void]$sb.AppendLine("- [$($p.Title)]($($p.Link))") }
    }
    foreach ($p in ($pages.Values | Where-Object { -not $_.Rel.Contains('/') -and $_.Rel -notin @('index.md', 'overview.md') } | Sort-Object Rel)) {
        [void]$sb.AppendLine("- [$($p.Title)]($($p.Link))")
    }
    Write-Utf8Text (Join-Path $OutPath '_Sidebar.md') $sb.ToString()
    Write-Utf8Text (Join-Path $OutPath '_Footer.md') "Generated by LLM Wiki$(if ($ProjectName) { " - $ProjectName" }) - $today`n"
}

[ordered]@{
    target      = $Target
    outPath     = $OutPath
    pages       = $pages.Count
    attachments = $attachments.Count
    warnings    = @($warnings)
} | ConvertTo-Json -Depth 4
