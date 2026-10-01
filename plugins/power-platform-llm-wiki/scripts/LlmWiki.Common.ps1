# Shared helpers for the LLM Wiki scripts. Dot-source it: . "$PSScriptRoot/LlmWiki.Common.ps1"
# Requires PowerShell 7+. All file I/O is explicit UTF-8 (no BOM) to avoid code-page corruption.

$script:Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Read-Utf8Text([string]$Path) {
    [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Write-Utf8Text([string]$Path, [string]$Content) {
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Content, $script:Utf8NoBom)
}

function Get-RelativePath([string]$From, [string]$To) {
    [System.IO.Path]::GetRelativePath($From, $To).Replace('\', '/')
}

function Get-YamlScalar([string]$Value) {
    $v = $Value.Trim()
    if ($v -match '^"(.*)"$') { return $Matches[1] }
    if ($v -match "^'(.*)'$") { return $Matches[1] }
    return ($v -replace '\s+#.*$', '').Trim()
}

# Minimal YAML reader for page front matter: scalars, inline lists [a, b] and block lists (- a).
function ConvertFrom-SimpleYaml([string]$Yaml) {
    $data = [ordered]@{}
    $currentKey = $null
    foreach ($line in ($Yaml -split '\r?\n')) {
        if ($line -match '^\s*(#.*)?$') { continue }
        if ($currentKey -and $line -match '^\s+-\s*(.*)$') {
            if ($data[$currentKey] -isnot [System.Collections.IList]) {
                $data[$currentKey] = [System.Collections.Generic.List[string]]::new()
            }
            $data[$currentKey].Add((Get-YamlScalar $Matches[1]))
            continue
        }
        if ($line -match '^([A-Za-z0-9_\-]+):\s*(.*)$') {
            $currentKey = $Matches[1]
            $value = $Matches[2].Trim()
            if ($value -eq '') { $data[$currentKey] = $null }
            elseif ($value -match '^\[(.*)\]$') {
                $items = [System.Collections.Generic.List[string]]::new()
                foreach ($item in ($Matches[1] -split ',')) {
                    $t = Get-YamlScalar $item
                    if ($t -ne '') { $items.Add($t) }
                }
                $data[$currentKey] = $items
            }
            else { $data[$currentKey] = Get-YamlScalar $value }
        }
    }
    return $data
}

function Split-Frontmatter([string]$Text) {
    $m = [regex]::Match($Text, '\A\uFEFF?---\r?\n(.*?)\r?\n---[ \t]*(\r?\n|\z)', 'Singleline')
    if (-not $m.Success) { return @{ Data = $null; Body = $Text; BodyLineOffset = 0 } }
    $offset = ([regex]::Matches($m.Value, '\n')).Count
    return @{ Data = (ConvertFrom-SimpleYaml $m.Groups[1].Value); Body = $Text.Substring($m.Length); BodyLineOffset = $offset }
}

function Get-FmValue($Data, [string]$Key) {
    if ($null -eq $Data -or -not $Data.Contains($Key)) { return $null }
    return $Data[$Key]
}

function Get-FmList($Data, [string]$Key) {
    $v = Get-FmValue $Data $Key
    if ($null -eq $v) { return @() }
    if ($v -is [System.Collections.IList]) { return @($v) }
    return @($v)
}

# Blank out fenced code blocks and inline code (length and line breaks preserved, so indexes stay valid).
function Remove-CodeSpans([string]$Text) {
    $noFences = [regex]::Replace($Text, '(?ms)^[ \t]*(```|~~~).*?^[ \t]*\1[ \t]*$', {
            param($m) ($m.Value -replace '[^\r\n]', ' ')
        })
    return [regex]::Replace($noFences, '`[^`\r\n]*`', { param($m) ' ' * $m.Length })
}

function Get-LineNumber([string]$Text, [int]$Index) {
    return ([regex]::Matches($Text.Substring(0, $Index), '\n')).Count + 1
}

# Markdown links and images whose target is a local path (no URI scheme, not an anchor).
function Get-LocalLinks([string]$Body) {
    $clean = Remove-CodeSpans $Body
    $results = @()
    foreach ($m in [regex]::Matches($clean, '(!?)\[([^\]]*)\]\(([^)\s]+)(?:\s+"[^"]*")?\)')) {
        $target = $m.Groups[3].Value
        if ($target -match '^[A-Za-z][A-Za-z0-9+.\-]*:' -or $target.StartsWith('#') -or $target.StartsWith('//') -or $target.StartsWith('<')) { continue }
        $path = $target
        $anchor = ''
        $hash = $target.IndexOf('#')
        if ($hash -ge 0) { $path = $target.Substring(0, $hash); $anchor = $target.Substring($hash) }
        $results += [pscustomobject]@{
            Text    = $m.Groups[2].Value
            Target  = $target
            Path    = [Uri]::UnescapeDataString($path)
            Anchor  = $anchor
            IsImage = ($m.Groups[1].Value -eq '!')
            Index   = $m.Index
            Length  = $m.Length
            Line    = (Get-LineNumber $clean $m.Index)
        }
    }
    return $results
}

function Get-WikiLinks([string]$Body) {
    $clean = Remove-CodeSpans $Body
    $results = @()
    foreach ($m in [regex]::Matches($clean, '\[\[([^\]]+)\]\]')) {
        $inner = $m.Groups[1].Value
        if ($inner -in @('_TOC_', '_TOSP_')) { continue }
        $results += [pscustomobject]@{ Inner = $inner; Index = $m.Index; Length = $m.Length; Line = (Get-LineNumber $clean $m.Index) }
    }
    return $results
}

function Resolve-LinkPath([string]$FromFile, [string]$LinkPath) {
    if ([string]::IsNullOrEmpty($LinkPath)) { return $FromFile }
    $base = Split-Path -Parent $FromFile
    return [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($base, $LinkPath))
}

function Test-PathUnder([string]$Path, [string]$Root) {
    $r = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    return [System.IO.Path]::GetFullPath($Path).StartsWith($r, [StringComparison]::OrdinalIgnoreCase)
}

# Title from the first H1, without emoji / inline markup.
function Get-PageTitle([string]$Body, [string]$Fallback) {
    $m = [regex]::Match((Remove-CodeSpans $Body), '(?m)^#[ \t]+(.+?)[ \t]*#*[ \t]*$')
    $title = if ($m.Success) { $m.Groups[1].Value } else { $Fallback }
    $title = [regex]::Replace($title, '[\p{So}\p{Cs}\uFE0F\u200D]', '')
    $title = $title -replace '[*_`]', ''
    return ($title -replace '\s+', ' ').Trim()
}

function ConvertTo-TitleCase([string]$Slug) {
    $words = $Slug -split '[-_ ]+' | Where-Object { $_ }
    return ($words | ForEach-Object { $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1) }) -join ' '
}

function Get-MarkdownPages([string]$Root, [string[]]$Exclude = @()) {
    Get-ChildItem -LiteralPath $Root -Recurse -File -Filter '*.md' | Where-Object {
        $rel = Get-RelativePath $Root $_.FullName
        -not ($Exclude | Where-Object { $rel -like $_ })
    } | Sort-Object FullName
}
