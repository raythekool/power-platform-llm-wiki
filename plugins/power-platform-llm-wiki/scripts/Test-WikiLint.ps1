#Requires -Version 7.0
<#
.SYNOPSIS
    Deterministic health check of an LLM Wiki (no LLM tokens needed).
.DESCRIPTION
    Checks front matter, content lifecycle (draft/reviewed/certified), relative links, orphans,
    index coverage, overdue actions, stale pages, Mermaid on code pages, requirement <-> code
    traceability, and likely secrets. Emits JSON on stdout; optionally writes a Markdown report.
    Exit code 1 when at least one error is found.
.PARAMETER WikiPath
    Path to llm-wiki/wiki.
.PARAMETER StaleAfterDays
    Pages whose 'updated' date is older than this are reported as stale.
.PARAMETER Today
    Reference date (yyyy-MM-dd). Defaults to the current date.
.PARAMETER ReportPath
    Optional Markdown report path (e.g. llm-wiki/wiki/lint-2026-10-01.md).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$WikiPath,
    [int]$StaleAfterDays = 30,
    [string]$Today = (Get-Date -Format 'yyyy-MM-dd'),
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/LlmWiki.Common.ps1"

$WikiPath = (Resolve-Path -LiteralPath $WikiPath).Path
$todayDate = [datetime]::ParseExact($Today, 'yyyy-MM-dd', $null)
$validStatus = @('draft', 'reviewed', 'certified', 'superseded', 'deprecated')
$noStatusTypes = @('index', 'overview', 'log', 'lint')
$hubFiles = @('index.md', 'overview.md', 'log.md')
$target = [char]::ConvertFromUtf32(0x1F3AF)
$done = [char]::ConvertFromUtf32(0x2705)

$issues = [System.Collections.Generic.List[object]]::new()
function Add-Issue([string]$Severity, [string]$Rule, [string]$File, [int]$Line, [string]$Message) {
    $issues.Add([pscustomobject]@{ severity = $Severity; rule = $Rule; file = $File; line = $Line; message = $Message })
}

$secretPatterns = @(
    '(?i)\b(password|passwd|pwd|client_secret|clientsecret|secret|accountkey|sharedaccesskey)\b\s*[:=]\s*["'']?[^\s"''<>]{8,}',
    '\bghp_[A-Za-z0-9]{36}\b',
    '\bgithub_pat_[A-Za-z0-9_]{40,}\b',
    '-----BEGIN [A-Z ]*PRIVATE KEY-----',
    '\bAKIA[0-9A-Z]{16}\b'
)

$pages = @(Get-MarkdownPages $WikiPath -Exclude @('lint-*.md'))
$pageInfo = @{}
$incoming = @{}
$requirements = @{}
$codeImplements = @{}
$emailCount = 0

foreach ($file in $pages) {
    $rel = Get-RelativePath $WikiPath $file.FullName
    $text = Read-Utf8Text $file.FullName
    $fm = Split-Frontmatter $text
    $data = $fm.Data
    $info = [pscustomobject]@{ Rel = $rel; Full = $file.FullName; Data = $data; Body = $fm.Body; Offset = $fm.BodyLineOffset }
    $pageInfo[$file.FullName.ToLowerInvariant()] = $info
    if (-not $incoming.ContainsKey($file.FullName.ToLowerInvariant())) { $incoming[$file.FullName.ToLowerInvariant()] = 0 }

    if ($null -eq $data) {
        Add-Issue 'error' 'FM001' $rel 1 'Missing YAML front matter.'
    }
    else {
        $type = Get-FmValue $data 'type'
        $status = Get-FmValue $data 'status'
        if (-not $type) { Add-Issue 'error' 'FM002' $rel 1 "Front matter has no 'type'." }
        if ($type -notin $noStatusTypes) {
            if (-not $status) { Add-Issue 'error' 'FM003' $rel 1 "Front matter has no 'status' (draft|reviewed|certified|superseded|deprecated)." }
            elseif ($status -notin $validStatus) { Add-Issue 'error' 'FM004' $rel 1 "Invalid status '$status'. Use $($validStatus -join '|'); put work-item state in 'state'." }
            if ($status -eq 'certified' -and (-not (Get-FmValue $data 'certified_by') -or -not (Get-FmValue $data 'certified_at'))) {
                Add-Issue 'error' 'FM005' $rel 1 "Certified page without 'certified_by' and 'certified_at'."
            }
            if ($status -eq 'reviewed' -and -not (Get-FmValue $data 'reviewed_by')) {
                Add-Issue 'warning' 'FM005' $rel 1 "Reviewed page without 'reviewed_by'."
            }
            $updated = Get-FmValue $data 'updated'
            if (-not $updated) { Add-Issue 'warning' 'FM006' $rel 1 "Front matter has no 'updated' date." }
            else {
                $d = [datetime]::MinValue
                if (-not [datetime]::TryParseExact([string]$updated, 'yyyy-MM-dd', $null, 'None', [ref]$d)) {
                    Add-Issue 'warning' 'FM006' $rel 1 "'updated' is not a yyyy-MM-dd date: $updated"
                }
                elseif (($todayDate - $d).TotalDays -gt $StaleAfterDays -and $status -notin @('superseded', 'deprecated')) {
                    Add-Issue 'info' 'STL001' $rel 1 "Not updated for $([int]($todayDate - $d).TotalDays) days (threshold $StaleAfterDays)."
                }
            }
        }
        if ($type -eq 'requirement') {
            $reqId = Get-FmValue $data 'req_id'
            if (-not $reqId) { Add-Issue 'error' 'TRC000' $rel 1 "Requirement page without 'req_id'." }
            else { $requirements[$reqId] = $info }
        }
        if ($type -in @('code', 'design')) {
            $impl = @(Get-FmList $data 'implements')
            $codeImplements[$rel] = $impl
            if ($type -eq 'code' -and $impl.Count -eq 0) { Add-Issue 'info' 'TRC003' $rel 1 "Code page does not declare 'implements' (untraced component)." }
            if ($type -eq 'code' -and $fm.Body -notmatch '(?m)^[ \t]*```mermaid') { Add-Issue 'warning' 'COD001' $rel 1 'Code page without a Mermaid diagram.' }
        }
    }

    foreach ($wl in (Get-WikiLinks $fm.Body)) {
        if ($wl.Inner.Contains('|')) { Add-Issue 'error' 'LNK002' $rel ($wl.Line + $fm.BodyLineOffset) "Pipe-alias wiki link [[$($wl.Inner)]] breaks on publish; use a Markdown link." }
        else { Add-Issue 'warning' 'LNK002' $rel ($wl.Line + $fm.BodyLineOffset) "Legacy wiki link [[$($wl.Inner)]]; use a relative Markdown link." }
    }

    $clean = Remove-CodeSpans $fm.Body
    $lines = $clean -split '\r?\n'
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $l = $lines[$i]
        if ($l.Contains($target) -and -not $l.Contains($done) -and $l -notmatch '~~') {
            foreach ($dm in [regex]::Matches($l, '\b(20\d\d-\d\d-\d\d)\b')) {
                $d = [datetime]::MinValue
                if ([datetime]::TryParseExact($dm.Value, 'yyyy-MM-dd', $null, 'None', [ref]$d) -and $d -lt $todayDate) {
                    Add-Issue 'warning' 'ACT001' $rel ($i + 1 + $fm.BodyLineOffset) "Overdue action (due $($dm.Value))."
                    break
                }
            }
        }
    }

    foreach ($pattern in $secretPatterns) {
        foreach ($sm in [regex]::Matches($text, $pattern)) {
            Add-Issue 'error' 'SEC001' $rel (Get-LineNumber $text $sm.Index) 'Possible secret or credential in page content.'
        }
    }
    $emailCount += ([regex]::Matches($text, '\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b')).Count
}

# Links: existence + incoming counts
foreach ($info in $pageInfo.Values) {
    foreach ($link in (Get-LocalLinks $info.Body)) {
        $resolved = Resolve-LinkPath $info.Full $link.Path
        $line = $link.Line + $info.Offset
        if (-not (Test-Path -LiteralPath $resolved)) {
            Add-Issue 'error' 'LNK001' $info.Rel $line "Broken link: $($link.Target)"
            continue
        }
        if (-not (Test-PathUnder $resolved $WikiPath)) {
            Add-Issue 'warning' 'LNK003' $info.Rel $line "Link points outside wiki/ and will not resolve once published: $($link.Target)"
            continue
        }
        $key = $resolved.ToLowerInvariant()
        if ($key -ne $info.Full.ToLowerInvariant() -and $incoming.ContainsKey($key)) { $incoming[$key]++ }
    }
}

$indexFull = (Join-Path $WikiPath 'index.md').ToLowerInvariant()
$indexTargets = @{}
if ($pageInfo.ContainsKey($indexFull)) {
    foreach ($link in (Get-LocalLinks $pageInfo[$indexFull].Body)) {
        $indexTargets[(Resolve-LinkPath $pageInfo[$indexFull].Full $link.Path).ToLowerInvariant()] = $true
    }
}
else { Add-Issue 'error' 'IDX000' 'index.md' 0 'wiki/index.md is missing.' }

foreach ($info in $pageInfo.Values) {
    $isRootHub = ((Split-Path -Parent $info.Full) -eq $WikiPath) -and ((Split-Path -Leaf $info.Full) -in $hubFiles)
    if ($isRootHub) { continue }
    $key = $info.Full.ToLowerInvariant()
    if ($incoming[$key] -eq 0) { Add-Issue 'warning' 'ORP001' $info.Rel 0 'Orphan page: no incoming links.' }
    if (-not $indexTargets.ContainsKey($key)) { Add-Issue 'warning' 'IDX001' $info.Rel 0 'Page is not listed in index.md.' }
}

# Traceability
$implemented = @{}
foreach ($entry in $codeImplements.GetEnumerator()) {
    foreach ($req in $entry.Value) {
        if (-not $requirements.ContainsKey($req)) { Add-Issue 'error' 'TRC001' $entry.Key 1 "'implements' references unknown requirement '$req'." }
        else { $implemented[$req] = $true }
    }
}
foreach ($req in $requirements.GetEnumerator()) {
    $byPage = @(Get-FmList $req.Value.Data 'implemented_by')
    $status = Get-FmValue $req.Value.Data 'status'
    if (-not $implemented.ContainsKey($req.Key) -and $byPage.Count -eq 0 -and $status -in @('reviewed', 'certified')) {
        Add-Issue 'warning' 'TRC002' $req.Value.Rel 1 "Requirement $($req.Key) has no implementation evidence (no code/design page implements it)."
    }
}

$statusCounts = [ordered]@{}
foreach ($s in $validStatus) { $statusCounts[$s] = @($pageInfo.Values | Where-Object { (Get-FmValue $_.Data 'status') -eq $s }).Count }

$sorted = @($issues | Sort-Object @{ e = { @('error', 'warning', 'info').IndexOf($_.severity) } }, file, line)
$result = [ordered]@{
    wiki           = $WikiPath
    date           = $Today
    pages          = $pages.Count
    errors         = @($sorted | Where-Object severity -eq 'error').Count
    warnings       = @($sorted | Where-Object severity -eq 'warning').Count
    infos          = @($sorted | Where-Object severity -eq 'info').Count
    status         = $statusCounts
    requirements   = [ordered]@{ total = $requirements.Count; withImplementation = $implemented.Count }
    emailAddresses = $emailCount
    issues         = $sorted
}

if ($ReportPath) {
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('---')
    [void]$sb.AppendLine('type: lint')
    [void]$sb.AppendLine("updated: $Today")
    [void]$sb.AppendLine('---')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("# Lint report $Today")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("Pages: $($pages.Count) - errors: $($result.errors) - warnings: $($result.warnings) - info: $($result.infos)")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| Status | Pages |')
    [void]$sb.AppendLine('| --- | --- |')
    foreach ($s in $statusCounts.GetEnumerator()) { [void]$sb.AppendLine("| $($s.Key) | $($s.Value) |") }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("Requirements: $($requirements.Count) - with implementation evidence: $($implemented.Count). E-mail addresses found: $emailCount.")
    foreach ($sev in @('error', 'warning', 'info')) {
        $group = @($sorted | Where-Object severity -eq $sev)
        if ($group.Count -eq 0) { continue }
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine("## $sev ($($group.Count))")
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('| Rule | File | Line | Message |')
        [void]$sb.AppendLine('| --- | --- | --- | --- |')
        foreach ($i in $group) { [void]$sb.AppendLine("| $($i.rule) | $($i.file) | $($i.line) | $($i.message -replace '\|', '\|') |") }
    }
    Write-Utf8Text $ReportPath $sb.ToString()
}

$result | ConvertTo-Json -Depth 6
if ($result.errors -gt 0) { exit 1 } else { exit 0 }
