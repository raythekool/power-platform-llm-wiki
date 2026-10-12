#Requires -Version 7.0
<#
.SYNOPSIS
    Knowledge graph of an LLM Wiki (no LLM tokens needed): build, analyse, query and export for AI consumers.
.DESCRIPTION
    Nodes: wiki pages, entities cited in them (REQ-..., `AxType:Name`, `dv:table`, work items, repositories,
    sprints, raw sources) and, unless -NoInventory, the custom objects of the latest code inventories
    (llm-wiki/raw/code/*.json, raw/fno/*.json produced by Get-CodeInventory.ps1).
    Edges (relation, confidence, evidence): links_to, implements, implemented_by, cites, mentions, drift, contradiction
    (EXTRACTED, from Markdown and front matter); related_to, depends_on (INFERRED, declared by the agent in front matter);
    extends, extension_of, relates_to, uses_table, grants, opens (EXTRACTED, from the inventory).
    Analysis: communities (deterministic label propagation seeded by requirement areas), hubs, cross-area bridges, gaps.
    Without a mode switch it prints a JSON summary. Modes can be combined with the outputs:
      -Query <terms>      neighbourhood of the matching nodes (what to read to answer a question)
      -Impact <id>        what depends on a node (reverse traversal)
      -From <id> -To <id> shortest connection between two nodes
      -OutFile            graph.json in node-link format (networkx / graphify / GraphRAG)
      -ReportPath         Markdown knowledge map (a generated wiki page)
      -AiExportPath       folder with graph.json, llms.txt, llms-full.txt and graph.html
      -HtmlPath           standalone interactive viewer (no external dependencies)
    Pages with `generated: true` in the front matter (the knowledge map itself) are not part of the graph.
.PARAMETER WikiPath
    Path to llm-wiki/wiki.
.PARAMETER InventoryPath
    Inventory JSON files to include. Default: the latest file per repository in <llm-wiki>/raw/code and raw/fno.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$WikiPath,
    [string[]]$InventoryPath,
    [switch]$NoInventory,
    [string[]]$Query,
    [string]$Impact,
    [string]$From,
    [string]$To,
    [int]$Depth = 2,
    [int]$MaxNodes = 30,
    [string]$OutFile,
    [string]$ReportPath,
    [string]$AiExportPath,
    [string]$HtmlPath,
    [string]$ProjectName,
    [string]$Today = (Get-Date -Format 'yyyy-MM-dd')
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/LlmWiki.Common.ps1"

$WikiPath = (Get-Item -LiteralPath $WikiPath).FullName.TrimEnd('\', '/')
$llmRoot = Split-Path -Parent $WikiPath
$hubFiles = @('index.md', 'overview.md', 'log.md')
$ci = [StringComparer]::OrdinalIgnoreCase

$nodes = [System.Collections.Generic.Dictionary[string, object]]::new($ci)
$edges = [System.Collections.Generic.List[object]]::new()
$edgeKeys = [System.Collections.Generic.HashSet[string]]::new($ci)
$alias = [System.Collections.Generic.Dictionary[string, string]]::new($ci)
$nameIndex = [System.Collections.Generic.Dictionary[string, string]]::new($ci)
$ambiguousNames = [System.Collections.Generic.HashSet[string]]::new($ci)

function Add-Node([string]$Id, [string]$Kind, [string]$Label, [hashtable]$Props = @{}) {
    if (-not $nodes.ContainsKey($Id)) { $nodes[$Id] = [ordered]@{ id = $Id; kind = $Kind; label = $Label } }
    $n = $nodes[$Id]
    # sorted: hashtable key order changes between processes and graph.json must be byte-stable
    foreach ($k in ($Props.Keys | Sort-Object)) { if ($null -ne $Props[$k] -and -not $n.Contains($k)) { $n[$k] = $Props[$k] } }
}

function Add-Edge([string]$Source, [string]$Target, [string]$Relation, [string]$Confidence, [string]$Evidence) {
    if (-not $Source -or -not $Target -or $Source -eq $Target) { return }
    if ($edgeKeys.Add("$Source|$Target|$Relation")) {
        $edges.Add([ordered]@{ source = $Source; target = $Target; relation = $Relation; confidence = $Confidence; evidence = $Evidence })
    }
}

# Entity id from a reference string; $null when the text is not an entity.
function Get-Entity([string]$Text) {
    $t = $Text.Trim()
    if ($t -match '^REQ-[A-Za-z0-9]+-\d+$') { $u = $t.ToUpperInvariant(); return @{ Id = "req:$u"; Kind = 'requirement'; Label = $u } }
    if ($t -match '^(Ax[A-Za-z]+):([\w.]+)$') { return @{ Id = "ax:$($Matches[1]):$($Matches[2])"; Kind = 'ax'; Label = "$($Matches[1]):$($Matches[2])"; Props = @{ type = $Matches[1] } } }
    if ($t -match '^dv:([A-Za-z0-9_]+)$') { $l = $Matches[1].ToLowerInvariant(); return @{ Id = "dv:$l"; Kind = 'dataverse'; Label = "dv:$l" } }
    if ($t -match '^(?:ado:)?((?:Epic|Feature|US|Story|Bug|Task|PBI|Issue)-\d+)$') { return @{ Id = "wi:$($Matches[1])"; Kind = 'workitem'; Label = $Matches[1] } }
    if ($t -match '^ado:(\d+)$') { return @{ Id = "wi:$($Matches[1])"; Kind = 'workitem'; Label = "#$($Matches[1])" } }
    if ($t -match '^ADR-\d+$') { $u = $t.ToUpperInvariant(); return @{ Id = "adr:$u"; Kind = 'decision'; Label = $u } }
    if ($t -match '^\d{4}-S\d{2}$') { return @{ Id = "sprint:$t"; Kind = 'sprint'; Label = $t } }
    if ($t -match '^raw/\S+$') { return @{ Id = "src:$t"; Kind = 'source'; Label = $t } }
    if ($t -match '^([A-Za-z0-9_.\-]+)@([A-Za-z0-9_.\-]+)(?::\S+)?$' -and $t -notmatch '@[^:]+\.[A-Za-z]{2,}$') {
        return @{ Id = "repo:$($Matches[1])"; Kind = 'repo'; Label = $Matches[1]; Rev = $Matches[2] }
    }
    return $null
}

function Resolve-Entity($Entity) {
    if ($alias.ContainsKey($Entity.Id)) { return $alias[$Entity.Id] }
    Add-Node $Entity.Id $Entity.Kind $Entity.Label ($Entity.Props ?? @{})
    return $Entity.Id
}

function Get-InventoryFiles {
    if ($NoInventory) { return @() }
    if ($InventoryPath) { return @($InventoryPath | ForEach-Object { (Resolve-Path -LiteralPath $_).Path }) }
    $latest = @{}
    foreach ($dir in @('raw/code', 'raw/fno')) {
        $full = Join-Path $llmRoot $dir
        if (-not (Test-Path -LiteralPath $full)) { continue }
        foreach ($f in (Get-ChildItem -LiteralPath $full -Filter '*.json' -File)) {
            if ($f.BaseName -notmatch '^(.+)-(\d{4}-\d{2}-\d{2})$') { continue }
            $key = "$dir/$($Matches[1])"
            if (-not $latest.ContainsKey($key) -or $latest[$key].BaseName -lt $f.BaseName) { $latest[$key] = $f }
        }
    }
    return @($latest.Values | Sort-Object FullName | ForEach-Object FullName)
}

function Add-Name([string]$Name, [string]$Id) {
    if (-not $Name -or $ambiguousNames.Contains($Name)) { return }
    if ($nameIndex.ContainsKey($Name) -and $nameIndex[$Name] -ne $Id) { [void]$nameIndex.Remove($Name); [void]$ambiguousNames.Add($Name); return }
    $nameIndex[$Name] = $Id
}

function Add-AxTarget([string]$Type, [string]$Name) {
    $id = "ax:${Type}:$Name"
    if (-not $nodes.ContainsKey($id)) { Add-Node $id 'ax' "${Type}:$Name" @{ type = $Type; external = $true } }
    return $id
}

# ---------- inventories ----------
$inventories = @()
foreach ($file in (Get-InventoryFiles)) {
    $inv = Read-Utf8Text $file | ConvertFrom-Json -Depth 30
    $repo = ([System.IO.Path]::GetFileNameWithoutExtension($file)) -replace '-\d{4}-\d{2}-\d{2}$', ''
    $ev = Get-RelativePath $llmRoot $file
    $inventories += $ev
    $add = {
        param($Id, $Type, $Label, $Name, $File)
        Add-Node $Id 'component' $Label @{ type = $Type; repo = $repo; file = $File; inventory = $true }
        Add-Name $Name $Id
    }
    foreach ($c in @($inv.components.dataversePlugins)) { if ($c) { & $add "code:plugin:$($c.class)" 'dataverse-plugin' $c.class $c.class $c.file } }
    foreach ($c in @($inv.components.workflowActivities)) { if ($c) { & $add "code:activity:$($c.class)" 'workflow-activity' $c.class $c.class $c.file } }
    foreach ($c in @($inv.components.pcfControls)) { if ($c) { & $add "code:pcf:$($c.namespace).$($c.constructor)" 'pcf-control' $c.constructor $c.constructor $c.file } }
    foreach ($c in @($inv.components.solutions)) { if ($c) { & $add "code:solution:$($c.uniqueName)" 'solution' $c.uniqueName $c.uniqueName $c.file } }
    foreach ($c in @($inv.components.flows)) { if ($c) { & $add "code:flow:$($c.name)" 'cloud-flow' $c.name $c.name $c.file } }

    if ($inv.fno -and $inv.fno.objects) {
        foreach ($typeProp in $inv.fno.objects.PSObject.Properties) {
            $type = $typeProp.Name
            foreach ($o in @($typeProp.Value)) {
                $id = "ax:${type}:$($o.name)"
                Add-Node $id 'ax' "${type}:$($o.name)" @{ type = $type; repo = $repo; file = $o.file; inventory = $true }
                if ($nodes[$id].Contains('external')) { $nodes[$id].Remove('external') }
                Add-Name $o.name $id
            }
        }
        foreach ($typeProp in $inv.fno.objects.PSObject.Properties) {
            $type = $typeProp.Name
            foreach ($o in @($typeProp.Value)) {
                $id = "ax:${type}:$($o.name)"
                $e = "${ev}:$($o.file)"
                switch -Regex ($type) {
                    '^AxTableExtension$' { if ($o.extends) { Add-Edge $id (Add-AxTarget 'AxTable' $o.extends) 'extends' 'EXTRACTED' $e } }
                    '^AxFormExtension$' { if ($o.extends) { Add-Edge $id (Add-AxTarget 'AxForm' $o.extends) 'extends' 'EXTRACTED' $e } }
                    '^AxEnumExtension$' { Add-Edge $id (Add-AxTarget 'AxEnum' (($o.name -split '\.')[0])) 'extends' 'EXTRACTED' $e }
                    '^AxClass$' {
                        if ($o.extensionOf) { Add-Edge $id (Add-AxTarget 'AxClass' $o.extensionOf) 'extension_of' 'EXTRACTED' $e }
                        if ($o.extends) { Add-Edge $id (Add-AxTarget 'AxClass' $o.extends) 'extends' 'EXTRACTED' $e }
                    }
                    '^AxEdt' { if ($o.extends) { Add-Edge $id (Add-AxTarget $type $o.extends) 'extends' 'EXTRACTED' $e } }
                    '^AxDataEntityView$' { foreach ($t in @($o.tables)) { if ($t) { Add-Edge $id (Add-AxTarget 'AxTable' $t) 'uses_table' 'EXTRACTED' $e } } }
                    '^AxSecurityRole$' {
                        foreach ($d in @($o.duties)) { if ($d) { Add-Edge $id (Add-AxTarget 'AxSecurityDuty' $d) 'grants' 'EXTRACTED' $e } }
                        foreach ($p in @($o.privileges)) { if ($p) { Add-Edge $id (Add-AxTarget 'AxSecurityPrivilege' $p) 'grants' 'EXTRACTED' $e } }
                    }
                    '^AxSecurityDuty$' { foreach ($p in @($o.privileges)) { if ($p) { Add-Edge $id (Add-AxTarget 'AxSecurityPrivilege' $p) 'grants' 'EXTRACTED' $e } } }
                    '^AxSecurityPrivilege$' {
                        foreach ($ep in @($o.entryPoints)) { if ($ep -and $ep.object -and $ep.objectType) { Add-Edge $id (Add-AxTarget "Ax$($ep.objectType)" $ep.object) 'grants' 'EXTRACTED' $e } }
                    }
                    '^AxMenuItem' { if ($o.object -and $o.objectType) { Add-Edge $id (Add-AxTarget "Ax$($o.objectType)" $o.object) 'opens' 'EXTRACTED' $e } }
                }
                if ($type -match '^AxTable(Extension)?$') {
                    foreach ($r in @($o.relations)) { if ($r -and $r.relatedTable) { Add-Edge $id (Add-AxTarget 'AxTable' $r.relatedTable) 'relates_to' 'EXTRACTED' $e } }
                }
            }
        }
    }
}

# ---------- pages ----------
$pages = [ordered]@{}
foreach ($f in (Get-MarkdownPages $WikiPath -Exclude @('lint-*.md'))) {
    $text = Read-Utf8Text $f.FullName
    $fm = Split-Frontmatter $text
    if ((Get-FmValue $fm.Data 'generated') -eq 'true') { continue }
    $rel = Get-RelativePath $WikiPath $f.FullName
    $id = "page:$rel"
    $isHub = (-not $rel.Contains('/')) -and ($rel -in $hubFiles)
    $props = @{
        type    = Get-FmValue $fm.Data 'type'
        status  = Get-FmValue $fm.Data 'status'
        path    = $rel
        updated = Get-FmValue $fm.Data 'updated'
        summary = Get-PageSummary $fm.Body
        tags    = @(Get-FmList $fm.Data 'tags')
    }
    if ($isHub) { $props.hub = $true }
    Add-Node $id 'page' (Get-PageTitle $fm.Body (ConvertTo-TitleCase ([System.IO.Path]::GetFileNameWithoutExtension($f.Name)))) $props
    foreach ($key in @('req_id', 'adr_id', 'devops_id')) {
        $v = Get-FmValue $fm.Data $key
        if (-not $v) { continue }
        $ent = Get-Entity ([string]$v)
        if ($ent -and -not $alias.ContainsKey($ent.Id)) { $alias[$ent.Id] = $id; $nodes[$id]['ids'] = @($nodes[$id]['ids']) + $ent.Label | Where-Object { $_ } }
    }
    $pages[$f.FullName.ToLowerInvariant()] = [pscustomobject]@{ Id = $id; Full = $f.FullName; Rel = $rel; Data = $fm.Data; Body = $fm.Body; Offset = $fm.BodyLineOffset }
}

function Add-RefEdge($Page, [string]$Relation, [string]$Ref, [string]$Confidence) {
    $r = $Ref.Trim()
    if (-not $r) { return }
    $ev = "$($Page.Rel):front-matter"
    $ent = Get-Entity $r
    if ($ent) { Add-Edge $Page.Id (Resolve-Entity $ent) $Relation $Confidence $(if ($ent.Rev) { "$ev ($($ent.Rev))" } else { $ev }); return }
    if ($r -match '\.md(#.*)?$') {
        $target = $pages[(Resolve-LinkPath $Page.Full ($r -replace '#.*$', '')).ToLowerInvariant()]
        if ($target) { Add-Edge $Page.Id $target.Id $Relation $Confidence $ev }
        return
    }
    if ($nameIndex.ContainsKey($r)) { Add-Edge $Page.Id $nameIndex[$r] $Relation $Confidence $ev }
}

foreach ($p in $pages.Values) {
    foreach ($l in (Get-LocalLinks $p.Body)) {
        if ($l.IsImage) { continue }
        $target = $pages[(Resolve-LinkPath $p.Full $l.Path).ToLowerInvariant()]
        if ($target) { Add-Edge $p.Id $target.Id 'links_to' 'EXTRACTED' "$($p.Rel):$($l.Line + $p.Offset)" }
    }
    foreach ($r in (Get-FmList $p.Data 'implements')) { Add-RefEdge $p 'implements' $r 'EXTRACTED' }
    foreach ($r in (Get-FmList $p.Data 'implemented_by')) { Add-RefEdge $p 'implemented_by' $r 'EXTRACTED' }
    foreach ($r in (Get-FmList $p.Data 'sources')) { Add-RefEdge $p 'cites' $r 'EXTRACTED' }
    foreach ($r in (Get-FmList $p.Data 'related')) { Add-RefEdge $p 'related_to' $r 'INFERRED' }
    foreach ($r in (Get-FmList $p.Data 'depends_on')) { Add-RefEdge $p 'depends_on' $r 'INFERRED' }

    foreach ($c in (Get-InlineCode $p.Body)) {
        $ev = "$($p.Rel):$($c.Line + $p.Offset)"
        $ent = Get-Entity $c.Value
        if ($ent -and $ent.Kind -ne 'source') { Add-Edge $p.Id (Resolve-Entity $ent) 'mentions' 'EXTRACTED' $ev }
        elseif ($nameIndex.ContainsKey($c.Value)) { Add-Edge $p.Id $nameIndex[$c.Value] 'mentions' 'EXTRACTED' $ev }
    }
    $clean = Remove-CodeSpans $p.Body
    foreach ($m in [regex]::Matches($clean, '\bREQ-[A-Z0-9]+-\d+\b')) {
        Add-Edge $p.Id (Resolve-Entity (Get-Entity $m.Value)) 'mentions' 'EXTRACTED' "$($p.Rel):$((Get-LineNumber $clean $m.Index) + $p.Offset)"
    }
    $lines = $p.Body -split '\r?\n'
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $kind = if ($lines[$i] -match '\*\*Drift:?\*\*') { 'drift' } elseif ($lines[$i] -match '\*\*Contradiction:?\*\*') { 'contradiction' } else { $null }
        if (-not $kind) { continue }
        $flags = @($nodes[$p.Id]['flags']) + $kind | Where-Object { $_ } | Select-Object -Unique
        $nodes[$p.Id]['flags'] = @($flags)
        foreach ($l in (Get-LocalLinks $lines[$i])) {
            $target = $pages[(Resolve-LinkPath $p.Full $l.Path).ToLowerInvariant()]
            if ($target) { Add-Edge $p.Id $target.Id $kind 'EXTRACTED' "$($p.Rel):$($i + 1 + $p.Offset)" }
        }
    }
}

# A mention adds nothing when a stronger relation already links the same two nodes.
$strong = [System.Collections.Generic.HashSet[string]]::new($ci)
foreach ($e in $edges) { if ($e.relation -ne 'mentions') { [void]$strong.Add("$($e.source)|$($e.target)") } }
$edgeList = @($edges | Where-Object { $_.relation -ne 'mentions' -or -not $strong.Contains("$($_.source)|$($_.target)") } |
    Sort-Object { $_.source }, { $_.target }, { $_.relation })

# ---------- metrics ----------
$degree = @{}; $out = @{}; $in = @{}
foreach ($id in $nodes.Keys) { $degree[$id] = 0; $out[$id] = [System.Collections.Generic.List[object]]::new(); $in[$id] = [System.Collections.Generic.List[object]]::new() }
foreach ($e in $edgeList) {
    $degree[$e.source]++; $degree[$e.target]++
    $out[$e.source].Add($e); $in[$e.target].Add($e)
}
foreach ($n in $nodes.Values) {
    $n['degree'] = $degree[$n.id]
    if ($n.kind -ne 'page') { $n['documented'] = [bool](@($in[$n.id] | Where-Object { $_.source.StartsWith('page:') }).Count) }
}
function Test-Hub([string]$Id) { $n = $nodes[$Id]; return ($n.kind -eq 'page' -and $n.Contains('hub')) }

# ---------- communities: label propagation, deterministic (sorted order, ordinal tie-break, area seeds fixed) ----------
$ids = @($nodes.Keys | Where-Object { -not (Test-Hub $_) } | Sort-Object)
$adj = @{}
foreach ($id in $ids) { $adj[$id] = [System.Collections.Generic.List[string]]::new() }
foreach ($e in $edgeList) {
    if ($adj.ContainsKey($e.source) -and $adj.ContainsKey($e.target)) { $adj[$e.source].Add($e.target); $adj[$e.target].Add($e.source) }
}
$label = @{}
$fixed = [System.Collections.Generic.HashSet[string]]::new($ci)
foreach ($id in $ids) {
    $n = $nodes[$id]
    $reqId = if ($id -match '^req:REQ-([A-Z0-9]+)-') { $Matches[1] } elseif ($n.type -eq 'requirement' -and @($n.ids) -match '^REQ-') { (@($n.ids) -match '^REQ-')[0].Split('-')[1] }
    if ($reqId) { $label[$id] = "area:$reqId"; [void]$fixed.Add($id) } else { $label[$id] = $id }
}
for ($iter = 0; $iter -lt 30; $iter++) {
    $changed = 0
    foreach ($id in $ids) {
        if ($fixed.Contains($id) -or $adj[$id].Count -eq 0) { continue }
        $counts = @{}
        foreach ($nb in $adj[$id]) { $counts[$label[$nb]] = 1 + ($counts[$label[$nb]] ?? 0) }
        $max = ($counts.Values | Measure-Object -Maximum).Maximum
        $best = @($counts.Keys | Where-Object { $counts[$_] -eq $max } | Sort-Object)
        if ($best -contains $label[$id]) { continue }
        $label[$id] = $best[0]; $changed++
    }
    if ($changed -eq 0) { break }
}
$communities = @()
$groups = $ids | Group-Object { $label[$_] } | Where-Object Count -ge 2 |
    Sort-Object @{ e = { $_.Count }; Descending = $true }, Name
$c = 0
foreach ($g in $groups) {
    $c++
    $members = @($g.Group | ForEach-Object { $nodes[$_] })
    $name = if ($g.Name -like 'area:*') { $g.Name.Substring(5) } else {
        $tag = $members | Where-Object { $_.kind -eq 'page' } | ForEach-Object { @($_.tags) } | Where-Object { $_ } | Group-Object | Sort-Object @{ e = { $_.Count }; Descending = $true }, Name | Select-Object -First 1
        if ($tag) { $tag.Name } else { ($members | Sort-Object @{ e = { $_.degree }; Descending = $true }, id | Select-Object -First 1).label }
    }
    $cid = "c$c"
    foreach ($m in $members) { $m['community'] = $cid }
    $communities += [ordered]@{
        id    = $cid
        name  = $name
        size  = $members.Count
        pages = @($members | Where-Object kind -eq 'page').Count
        hubs  = @($members | Sort-Object @{ e = { $_.degree }; Descending = $true }, id | Select-Object -First 5 | ForEach-Object id)
    }
}
$communityName = @{}
foreach ($cm in $communities) { $communityName[$cm.id] = $cm.name }

$hubs = @($nodes.Values | Where-Object { -not (Test-Hub $_.id) -and $_.kind -ne 'source' -and $_.degree -gt 0 } |
    Sort-Object @{ e = { $_.degree }; Descending = $true }, id | Select-Object -First 10 |
    ForEach-Object { [ordered]@{ id = $_.id; label = $_.label; kind = $_.kind; degree = $_.degree; path = $_.path } })
$bridgeMap = [ordered]@{}
foreach ($e in $edgeList) {
    $a = $nodes[$e.source]['community']; $b = $nodes[$e.target]['community']
    if (-not $a -or -not $b -or $a -eq $b) { continue }
    $key = (@($a, $b) | Sort-Object) -join '|'
    if (-not $bridgeMap.Contains($key)) { $bridgeMap[$key] = [ordered]@{ between = @($communityName[($key -split '\|')[0]], $communityName[($key -split '\|')[1]]); edges = 0; examples = @() } }
    $bridgeMap[$key].edges++
    if ($bridgeMap[$key].examples.Count -lt 3) { $bridgeMap[$key].examples += "$($nodes[$e.source].label) -$($e.relation)-> $($nodes[$e.target].label)" }
}
$bridges = @($bridgeMap.Values | Sort-Object @{ e = { $_.edges }; Descending = $true } | Select-Object -First 10)

$undocumented = @($nodes.Values | Where-Object { $_.Contains('inventory') -and -not $_.documented } | Sort-Object id)
$gaps = [ordered]@{
    undocumentedComponents = [ordered]@{ count = $undocumented.Count; items = @($undocumented | Select-Object -First 50 | ForEach-Object label) }
    entitiesWithoutPage    = @($nodes.Values | Where-Object { $_.kind -in @('requirement', 'decision') } | Sort-Object id | ForEach-Object label)
    pagesWithoutSummary    = @($nodes.Values | Where-Object { $_.kind -eq 'page' -and -not $_.Contains('hub') -and -not $_.summary } | Sort-Object id | ForEach-Object path)
}

# ---------- traversal ----------
function Find-Seeds([string]$Term) {
    $t = $Term.Trim()
    $ent = Get-Entity $t
    if ($ent) { $id = if ($alias.ContainsKey($ent.Id)) { $alias[$ent.Id] } else { $ent.Id }; if ($nodes.ContainsKey($id)) { return @($id) } }
    foreach ($candidate in @($t, "page:$t", "page:$($t -replace '^(llm-wiki/)?wiki/', '')")) { if ($nodes.ContainsKey($candidate)) { return @($candidate) } }
    if ($nameIndex.ContainsKey($t)) { return @($nameIndex[$t]) }
    $exact = @($nodes.Values | Where-Object { $_.label -eq $t } | ForEach-Object id)
    if ($exact.Count) { return $exact }
    return @($nodes.Values | Where-Object { -not (Test-Hub $_.id) -and ($_.label -like "*$t*" -or $_.id -like "*$t*" -or (@($_.tags) -contains $t)) } |
        Sort-Object @{ e = { $_.degree }; Descending = $true }, id | Select-Object -First 5 | ForEach-Object id)
}

function Get-NodeView([string]$Id, [int]$Distance) {
    $n = $nodes[$Id]
    $v = [ordered]@{ id = $Id; label = $n.label; kind = $n.kind; distance = $Distance }
    foreach ($k in @('type', 'status', 'path', 'summary', 'flags', 'documented')) { if ($n.Contains($k) -and $null -ne $n[$k]) { $v[$k] = $n[$k] } }
    if ($n.Contains('community')) { $v.community = $communityName[$n.community] }
    return $v
}

function Invoke-Bfs([string[]]$Seeds, [bool]$Reverse, [int]$MaxDepth) {
    $dist = [ordered]@{}
    $queue = [System.Collections.Generic.Queue[string]]::new()
    foreach ($s in $Seeds) { if (-not $dist.Contains($s)) { $dist[$s] = 0; $queue.Enqueue($s) } }
    while ($queue.Count) {
        $id = $queue.Dequeue()
        if ($dist[$id] -ge $MaxDepth -or ((Test-Hub $id) -and $Seeds -notcontains $id)) { continue }
        $next = if ($Reverse) { @($in[$id] | ForEach-Object source) } else { @($out[$id] | ForEach-Object target) + @($in[$id] | ForEach-Object source) }
        foreach ($nb in ($next | Sort-Object -Unique)) {
            if ($dist.Contains($nb) -or ((Test-Hub $nb) -and $Seeds -notcontains $nb)) { continue }
            $dist[$nb] = $dist[$id] + 1; $queue.Enqueue($nb)
        }
    }
    return $dist
}

function Get-Subgraph([string]$Mode, [string[]]$Seeds, [bool]$Reverse) {
    $dist = Invoke-Bfs $Seeds $Reverse $Depth
    $picked = @($dist.Keys | Sort-Object @{ e = { $dist[$_] } }, @{ e = { if ($nodes[$_].kind -eq 'page') { 0 } else { 1 } } }, @{ e = { $nodes[$_].degree }; Descending = $true }, @{ e = { $_ } } |
        Select-Object -First $MaxNodes)
    $set = [System.Collections.Generic.HashSet[string]]::new([string[]]$picked, $ci)
    [ordered]@{
        mode        = $Mode
        seeds       = @($Seeds)
        nodes       = @($picked | ForEach-Object { Get-NodeView $_ $dist[$_] })
        edges       = @($edgeList | Where-Object { $set.Contains($_.source) -and $set.Contains($_.target) } | ForEach-Object { [ordered]@{ source = $_.source; target = $_.target; relation = $_.relation; confidence = $_.confidence } })
        pagesToRead = @($picked | Where-Object { $nodes[$_].kind -eq 'page' -and -not (Test-Hub $_) } | ForEach-Object { "llm-wiki/wiki/$($nodes[$_].path)" })
        truncated   = $dist.Count -gt $picked.Count
    }
}

function Get-Path([string]$A, [string]$B) {
    $prev = @{ $A = $null }
    $queue = [System.Collections.Generic.Queue[string]]::new(); $queue.Enqueue($A)
    while ($queue.Count -and -not $prev.ContainsKey($B)) {
        $id = $queue.Dequeue()
        foreach ($e in (@($out[$id]) + @($in[$id]) | Sort-Object { $_.source }, { $_.target })) {
            $nb = if ($e.source -eq $id) { $e.target } else { $e.source }
            if ($prev.ContainsKey($nb) -or ((Test-Hub $nb) -and $nb -ne $B)) { continue }
            $prev[$nb] = $e; $queue.Enqueue($nb)
        }
    }
    if (-not $prev.ContainsKey($B)) { return $null }
    $steps = @(); $cur = $B
    while ($cur -ne $A) { $e = $prev[$cur]; $steps = , $e + $steps; $cur = if ($e.source -eq $cur) { $e.target } else { $e.source } }
    $ids = @($A); foreach ($e in $steps) { $ids += $(if ($e.source -eq $ids[-1]) { $e.target } else { $e.source }) }
    return [ordered]@{
        nodes = @($ids | ForEach-Object { Get-NodeView $_ ([array]::IndexOf($ids, $_)) })
        edges = @($steps | ForEach-Object { [ordered]@{ source = $_.source; target = $_.target; relation = $_.relation; confidence = $_.confidence; evidence = $_.evidence } })
    }
}

# ---------- outputs ----------
function Get-GraphJson {
    $wikiUpdated = ($nodes.Values | Where-Object { $_.updated } | ForEach-Object updated | Sort-Object | Select-Object -Last 1)
    [ordered]@{
        directed   = $true
        multigraph = $true
        graph      = [ordered]@{ name = $(if ($ProjectName) { $ProjectName } else { 'LLM Wiki' }); wikiUpdated = $wikiUpdated; communities = $communities }
        nodes      = @($nodes.Keys | Sort-Object | ForEach-Object { $nodes[$_] })
        links      = @($edgeList)
    } | ConvertTo-Json -Depth 8
}

$folderTitles = [ordered]@{ '' = 'Overview'; requirements = 'Requirements'; design = 'Design'; code = 'Code (as-built)'; features = 'Features'; projects = 'Projects'; delivery = 'Delivery'; meetings = 'Meetings'; reference = 'Reference' }
function Get-PageGroups {
    $list = @($nodes.Values | Where-Object { $_.kind -eq 'page' -and $_.path -notin @('index.md', 'log.md') })
    $list | Group-Object { if ($_.path.Contains('/')) { $_.path.Split('/')[0] } else { '' } } |
        Sort-Object @{ e = { $i = @($folderTitles.Keys).IndexOf($_.Name); if ($i -lt 0) { 99 } else { $i } } }, Name
}

function Get-ProjectTitle {
    if ($ProjectName) { return $ProjectName }
    $index = $nodes['page:index.md']
    if ($index) { return $index.label }
    return 'LLM Wiki'
}

function Write-AiExport([string]$Dir) {
    New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    Write-Utf8Text (Join-Path $Dir 'graph.json') (Get-GraphJson)
    $title = Get-ProjectTitle
    $overview = $nodes['page:overview.md']
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# $title").AppendLine('')
    $intro = if ($overview -and $overview.summary) { $overview.summary } else {
        $first = if ($overview) { [regex]::Match(($pages[[System.IO.Path]::GetFullPath((Join-Path $WikiPath 'overview.md')).ToLowerInvariant()].Body -replace '(?m)^#.*$', '').Trim(), '^[^\r\n]+(\r?\n[^\r\n]+)*').Value }
        if ($first) { ($first -replace '\[([^\]]+)\]\([^)]+\)', '$1' -replace '\s+', ' ').Trim() } else { 'Project knowledge base maintained by LLM Wiki: requirements, design, as-built code documentation, meetings and decisions.' }
    }
    [void]$sb.AppendLine("> $intro").AppendLine('')
    [void]$sb.AppendLine("Every page states its lifecycle status (draft, reviewed, certified): prefer certified content. Relations between pages and technical objects are in graph.json.")
    foreach ($g in (Get-PageGroups)) {
        $name = if ($folderTitles.Contains($g.Name)) { $folderTitles[$g.Name] } else { ConvertTo-TitleCase $g.Name }
        [void]$sb.AppendLine('').AppendLine("## $name").AppendLine('')
        foreach ($n in ($g.Group | Sort-Object path)) {
            $desc = if ($n.summary) { $n.summary } else { $n.type }
            $status = if ($n.status) { " ($($n.status))" } else { '' }
            [void]$sb.AppendLine("- [$($n.label)]($($n.path)): $desc$status")
        }
    }
    [void]$sb.AppendLine('').AppendLine('## Optional').AppendLine('')
    [void]$sb.AppendLine('- [Knowledge graph](graph.json): nodes and typed relations in node-link JSON (networkx, GraphRAG)')
    [void]$sb.AppendLine('- [Full text](llms-full.txt): every page in one file')
    Write-Utf8Text (Join-Path $Dir 'llms.txt') $sb.ToString()

    $full = [System.Text.StringBuilder]::new()
    [void]$full.AppendLine("# $title").AppendLine('')
    foreach ($g in (Get-PageGroups)) {
        foreach ($n in ($g.Group | Sort-Object path)) {
            $page = $pages[[System.IO.Path]::GetFullPath((Join-Path $WikiPath $n.path)).ToLowerInvariant()]
            $meta = @("Path: $($n.path)")
            foreach ($k in @('type', 'status', 'updated')) { if ($n[$k]) { $meta += "$((Get-Culture).TextInfo.ToTitleCase($k)): $($n[$k])" } }
            if ($n.ids) { $meta += "IDs: $(@($n.ids) -join ', ')" }
            [void]$full.AppendLine('---').AppendLine('').AppendLine("<!-- $($meta -join ' | ') -->").AppendLine('')
            [void]$full.AppendLine($page.Body.Trim()).AppendLine('')
        }
    }
    Write-Utf8Text (Join-Path $Dir 'llms-full.txt') $full.ToString()
    Write-GraphHtml (Join-Path $Dir 'graph.html')
}

function Write-GraphHtml([string]$Path) {
    $index = @{}; $i = 0
    $ordered = @($nodes.Keys | Sort-Object)
    foreach ($id in $ordered) { $index[$id] = $i++ }
    $data = [ordered]@{
        title       = Get-ProjectTitle
        generated   = $Today
        communities = @($communities | ForEach-Object { $_.name })
        nodes       = @($ordered | ForEach-Object {
                $n = $nodes[$_]
                $v = [ordered]@{ id = $n.id; l = $n.label; k = $n.kind; d = $n.degree }
                if ($n.type) { $v.t = $n.type }
                if ($n.status) { $v.s = $n.status }
                if ($n.path) { $v.p = $n.path }
                if ($n.summary) { $v.m = $n.summary }
                if ($n.community) { $v.c = [int]$n.community.Substring(1) - 1 }
                if ($n.Contains('documented') -and -not $n.documented) { $v.u = 1 }
                if ($n.flags) { $v.f = @($n.flags) }
                $v
            })
        links       = @($edgeList | ForEach-Object { , @($index[$_.source], $index[$_.target], $_.relation, $(if ($_.confidence -eq 'INFERRED') { 1 } else { 0 })) })
    }
    # \u003c keeps page text from closing the <script> element
    $json = ($data | ConvertTo-Json -Depth 6 -Compress) -replace '<', '\u003c' -replace '>', '\u003e' -replace '&', '\u0026'
    Write-Utf8Text $Path $script:GraphHtmlTemplate.Replace('/*__GRAPH_DATA__*/null', $json)
}

function Write-KnowledgeMap([string]$Path) {
    $full = [System.IO.Path]::GetFullPath($Path)
    $dir = Split-Path -Parent $full
    $link = {
        param($Node)
        $t = $Node.label -replace '\|', '\|' -replace '[\[\]]', ''
        if ($Node.kind -eq 'page') { "[$t]($([System.IO.Path]::GetRelativePath($dir, (Join-Path $WikiPath $Node.path)).Replace('\', '/')))" } else { "``$($Node.label)``" }
    }
    $pageCount = @($nodes.Values | Where-Object kind -eq 'page').Count
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('---').AppendLine('type: index').AppendLine("updated: $Today").AppendLine('generated: true').AppendLine('---').AppendLine('')
    [void]$sb.AppendLine('# Knowledge map').AppendLine('')
    [void]$sb.AppendLine("> Generated by ``Get-WikiGraph.ps1`` on ${Today}: $pageCount pages, $($nodes.Count - $pageCount) entities and components, $($edgeList.Count) relations, $($communities.Count) areas. Do not edit: it is regenerated at every lint.")
    [void]$sb.AppendLine('').AppendLine('## Areas').AppendLine('')
    foreach ($cm in $communities) {
        $members = @($nodes.Values | Where-Object { $_.community -eq $cm.id })
        [void]$sb.AppendLine("### $($cm.name) ($($cm.size))").AppendLine('')
        $kinds = $members | Group-Object { if ($_.kind -eq 'page') { "page:$($_.type)" } else { $_.kind } } | Sort-Object Name
        foreach ($k in $kinds) {
            $items = @($k.Group | Sort-Object @{ e = { $_.degree }; Descending = $true }, id | Select-Object -First 12 | ForEach-Object { & $link $_ })
            $more = if ($k.Count -gt 12) { " and $($k.Count - 12) more" } else { '' }
            [void]$sb.AppendLine("- **$($k.Name -replace '^page:', '')**: $($items -join ', ')$more")
        }
        [void]$sb.AppendLine('')
    }
    [void]$sb.AppendLine('## Entry points').AppendLine('')
    [void]$sb.AppendLine('| Node | Kind | Relations |').AppendLine('| --- | --- | --- |')
    foreach ($h in $hubs) { [void]$sb.AppendLine("| $(& $link $nodes[$h.id]) | $($h.kind) | $($h.degree) |") }
    if ($bridges.Count) {
        [void]$sb.AppendLine('').AppendLine('## Cross-area connections').AppendLine('')
        [void]$sb.AppendLine('| Areas | Relations | Examples |').AppendLine('| --- | --- | --- |')
        foreach ($b in $bridges) { [void]$sb.AppendLine("| $($b.between -join ' / ') | $($b.edges) | $(($b.examples | ForEach-Object { $_ -replace '\|', '\|' }) -join '<br>') |") }
    }
    [void]$sb.AppendLine('').AppendLine('## Gaps').AppendLine('')
    $u = $gaps.undocumentedComponents
    $codeList = { param($Items) (@($Items) | ForEach-Object { '`' + $_ + '`' }) -join ', ' }
    $line = "- Components without a wiki page or mention: $($u.count)"
    if ($u.count) { $line += ' - ' + (& $codeList ($u.items | Select-Object -First 20)) }
    [void]$sb.AppendLine($line)
    $missing = @($gaps.entitiesWithoutPage)
    $line = "- Entities cited without a page: $($missing.Count)"
    if ($missing.Count) { $line += ' - ' + (& $codeList $missing) }
    [void]$sb.AppendLine($line)
    $noSum = @($gaps.pagesWithoutSummary | ForEach-Object { & $link $nodes["page:$_"] })
    $line = "- Pages without a TL;DR: $($noSum.Count)"
    if ($noSum.Count) { $line += ' - ' + ($noSum -join ', ') }
    [void]$sb.AppendLine($line)
    Write-Utf8Text $full $sb.ToString()
}

$script:GraphHtmlTemplate = @'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Knowledge graph</title>
<style>
:root { --bg: #0b1220; --panel: #111a2e; --line: #23304d; --text: #e2e8f0; --muted: #94a3b8; --cyan: #22d3ee; --violet: #8b5cf6; }
* { box-sizing: border-box; }
html, body { margin: 0; height: 100%; background: var(--bg); color: var(--text); font: 14px/1.5 "Segoe UI", system-ui, -apple-system, Roboto, Arial, sans-serif; }
#app { display: grid; grid-template-columns: 340px 1fr; height: 100%; }
aside { background: var(--panel); border-right: 1px solid var(--line); overflow-y: auto; padding: 18px; display: grid; gap: 16px; align-content: start; }
h1 { font-size: 17px; margin: 0; line-height: 1.3; }
h1 small { display: block; color: var(--muted); font-weight: 400; font-size: 12.5px; }
h2 { font-size: 12px; text-transform: uppercase; letter-spacing: .1em; color: var(--muted); margin: 0 0 8px; }
.bar { height: 4px; border-radius: 4px; background: linear-gradient(90deg, var(--cyan), var(--violet)); }
input[type=search] { width: 100%; padding: 9px 11px; border-radius: 10px; border: 1px solid var(--line); background: #0b1220; color: var(--text); font: inherit; }
label.f { display: flex; align-items: center; gap: 8px; font-size: 13px; cursor: pointer; }
label.f span.n { margin-left: auto; color: var(--muted); }
.legend button, .rel button { display: flex; align-items: center; gap: 8px; width: 100%; text-align: left; border: 0; background: none; color: var(--text); font: inherit; font-size: 13px; padding: 3px 4px; border-radius: 6px; cursor: pointer; }
.legend button:hover, .rel button:hover { background: #1b2742; }
.dot { width: 11px; height: 11px; border-radius: 50%; flex: none; }
#details { border: 1px solid var(--line); border-radius: 12px; padding: 12px; background: #0e1628; }
#details h3 { margin: 0 0 4px; font-size: 15px; }
#details .meta { color: var(--muted); font-size: 12.5px; }
#details p { margin: 8px 0; }
.rel { display: grid; gap: 2px; margin-top: 6px; }
.rel em { color: var(--muted); font-style: normal; font-size: 12px; }
.tag { display: inline-block; font-size: 11px; padding: 1px 7px; border-radius: 999px; background: #3b1d1d; color: #fca5a5; margin-right: 4px; }
main { position: relative; overflow: hidden; }
canvas { display: block; width: 100%; height: 100%; cursor: grab; }
canvas:active { cursor: grabbing; }
#tip { position: absolute; pointer-events: none; background: #0e1628ee; border: 1px solid var(--line); padding: 4px 8px; border-radius: 8px; font-size: 12.5px; display: none; }
.hint { position: absolute; right: 14px; bottom: 10px; color: var(--muted); font-size: 12px; }
:focus-visible { outline: 2px solid var(--cyan); outline-offset: 2px; }
@media (max-width: 760px) { #app { grid-template-columns: 1fr; grid-template-rows: auto 60vh; } aside { max-height: 45vh; } }
</style>
</head>
<body>
<div id="app">
  <aside>
    <div class="bar"></div>
    <h1 id="title">Knowledge graph</h1>
    <div><label for="q"><h2>Search</h2></label><input id="q" type="search" placeholder="REQ-SAL-001, CustTable, plugin..." autocomplete="off"></div>
    <div id="details" aria-live="polite"><div class="meta">Select a node to see its summary and relations.</div></div>
    <div><h2>Show</h2><div id="filters"></div></div>
    <div><h2>Areas</h2><div class="legend" id="legend"></div></div>
  </aside>
  <main>
    <canvas id="c" aria-label="Knowledge graph: use the search box and the panel to explore nodes"></canvas>
    <div id="tip"></div>
    <div class="hint">Scroll to zoom &middot; drag to pan &middot; click a node</div>
  </main>
</div>
<script>
(function () {
  'use strict';
  var D = /*__GRAPH_DATA__*/null;
  var N = D.nodes, L = D.links;
  var palette = ['#22d3ee', '#a78bfa', '#f59e0b', '#34d399', '#f472b6', '#60a5fa', '#fb7185', '#facc15', '#2dd4bf', '#c084fc', '#fb923c', '#4ade80'];
  var kindNames = { page: 'Wiki pages', requirement: 'Requirements without page', ax: 'F&O objects', component: 'Code components', dataverse: 'Dataverse tables', workitem: 'Work items', repo: 'Repositories', sprint: 'Sprints', source: 'Raw sources', decision: 'Decisions without page' };
  var $ = function (id) { return document.getElementById(id); };
  $('title').textContent = D.title;
  var sub = document.createElement('small');
  sub.textContent = N.length + ' nodes, ' + L.length + ' relations, generated ' + D.generated;
  $('title').appendChild(sub);

  var seed = 7;
  function rnd() { seed = (seed + 0x6D2B79F5) | 0; var t = Math.imul(seed ^ (seed >>> 15), 1 | seed); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }
  function color(n) { return n.c === undefined ? '#64748b' : palette[n.c % palette.length]; }
  function radius(n) { return (n.k === 'page' ? 5 : 3) + Math.sqrt(n.d || 0) * 1.6; }

  var adj = N.map(function () { return []; });
  L.forEach(function (l, i) { adj[l[0]].push(i); adj[l[1]].push(i); });
  var nc = Math.max(1, D.communities.length);
  N.forEach(function (n, i) {
    var a = n.c === undefined ? rnd() * Math.PI * 2 : (n.c / nc) * Math.PI * 2;
    var r = n.c === undefined ? 520 : 260;
    n.cx = Math.cos(a) * r; n.cy = Math.sin(a) * r;
    n.x = n.cx + (rnd() - 0.5) * 160; n.y = n.cy + (rnd() - 0.5) * 160; n.vx = 0; n.vy = 0; n.i = i;
  });

  var alpha = 1;
  function tick() {
    var cell = 90, grid = new Map();
    N.forEach(function (n) { var k = Math.floor(n.x / cell) + ',' + Math.floor(n.y / cell); if (!grid.has(k)) grid.set(k, []); grid.get(k).push(n); });
    N.forEach(function (a) {
      var gx = Math.floor(a.x / cell), gy = Math.floor(a.y / cell);
      for (var dx = -1; dx <= 1; dx++) for (var dy = -1; dy <= 1; dy++) {
        var b2 = grid.get((gx + dx) + ',' + (gy + dy)); if (!b2) continue;
        for (var j = 0; j < b2.length; j++) {
          var b = b2[j]; if (b.i <= a.i) continue;
          var x = a.x - b.x, y = a.y - b.y, d2 = x * x + y * y || 0.01, f = 900 / d2;
          a.vx += x * f; a.vy += y * f; b.vx -= x * f; b.vy -= y * f;
        }
      }
    });
    L.forEach(function (l) {
      var a = N[l[0]], b = N[l[1]], x = b.x - a.x, y = b.y - a.y, d = Math.sqrt(x * x + y * y) || 1, f = (d - 70) * 0.02;
      a.vx += x / d * f; a.vy += y / d * f; b.vx -= x / d * f; b.vy -= y / d * f;
    });
    N.forEach(function (n) {
      n.vx += (n.cx - n.x) * 0.004; n.vy += (n.cy - n.y) * 0.004;
      n.x += Math.max(-20, Math.min(20, n.vx * alpha)); n.y += Math.max(-20, Math.min(20, n.vy * alpha));
      n.vx *= 0.6; n.vy *= 0.6;
    });
    alpha *= 0.985;
  }

  var canvas = $('c'), ctx = canvas.getContext('2d'), view = { s: 1, x: 0, y: 0 }, dpr = window.devicePixelRatio || 1;
  var hidden = {}, selected = null, focusCommunity = null, hideUndocumented = false;
  function visible(n) { return !hidden[n.k] && !(hideUndocumented && n.u); }
  function resize() { canvas.width = canvas.clientWidth * dpr; canvas.height = canvas.clientHeight * dpr; draw(); }
  function toScreen(n) { return [(n.x * view.s + view.x) * dpr + canvas.width / 2, (n.y * view.s + view.y) * dpr + canvas.height / 2]; }
  function draw() {
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.setTransform(view.s * dpr, 0, 0, view.s * dpr, canvas.width / 2 + view.x * dpr, canvas.height / 2 + view.y * dpr);
    var near = {};
    if (selected) { near[selected.i] = 1; adj[selected.i].forEach(function (li) { near[L[li][0]] = 1; near[L[li][1]] = 1; }); }
    L.forEach(function (l) {
      var a = N[l[0]], b = N[l[1]]; if (!visible(a) || !visible(b)) return;
      var hot = selected && (a === selected || b === selected);
      var dim = (selected && !hot) || (focusCommunity !== null && (a.c !== focusCommunity || b.c !== focusCommunity));
      ctx.globalAlpha = dim ? 0.08 : (hot ? 0.9 : 0.35);
      ctx.strokeStyle = (l[2] === 'drift' || l[2] === 'contradiction') ? '#f87171' : (hot ? '#e2e8f0' : '#64748b');
      ctx.lineWidth = (hot ? 1.6 : 0.8) / view.s;
      ctx.setLineDash(l[3] ? [4 / view.s, 3 / view.s] : []);
      ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
    });
    ctx.setLineDash([]);
    N.forEach(function (n) {
      if (!visible(n)) return;
      var dim = (selected && !near[n.i]) || (focusCommunity !== null && n.c !== focusCommunity);
      ctx.globalAlpha = dim ? 0.15 : 1;
      var r = radius(n);
      ctx.beginPath(); ctx.arc(n.x, n.y, r, 0, Math.PI * 2);
      if (n.u) { ctx.strokeStyle = color(n); ctx.lineWidth = 1.5 / view.s; ctx.stroke(); }
      else { ctx.fillStyle = color(n); ctx.fill(); }
      if (n.k === 'page') { ctx.strokeStyle = '#ffffff'; ctx.lineWidth = (n === selected ? 3 : 1.2) / view.s; ctx.stroke(); }
      if (n.f) { ctx.strokeStyle = '#f87171'; ctx.lineWidth = 2 / view.s; ctx.beginPath(); ctx.arc(n.x, n.y, r + 3 / view.s, 0, Math.PI * 2); ctx.stroke(); }
      if (!dim && (n === selected || near[n.i] || n.d >= 6 || view.s > 1.6)) {
        ctx.fillStyle = '#e2e8f0'; ctx.font = (12 / view.s) + 'px Segoe UI, sans-serif';
        ctx.fillText(n.l.length > 40 ? n.l.slice(0, 39) + '…' : n.l, n.x + r + 3 / view.s, n.y + 4 / view.s);
      }
    });
    ctx.globalAlpha = 1;
  }

  function pick(ev) {
    var rect = canvas.getBoundingClientRect();
    var x = ((ev.clientX - rect.left) * dpr - canvas.width / 2 - view.x * dpr) / (view.s * dpr);
    var y = ((ev.clientY - rect.top) * dpr - canvas.height / 2 - view.y * dpr) / (view.s * dpr);
    var best = null, bd = Infinity;
    N.forEach(function (n) { if (!visible(n)) return; var d = Math.hypot(n.x - x, n.y - y); if (d < radius(n) + 6 / view.s && d < bd) { bd = d; best = n; } });
    return best;
  }

  function el(tag, text, cls) { var e = document.createElement(tag); if (text !== undefined) e.textContent = text; if (cls) e.className = cls; return e; }
  function select(n, center) {
    selected = n; var box = $('details'); box.textContent = '';
    if (!n) { box.appendChild(el('div', 'Select a node to see its summary and relations.', 'meta')); draw(); return; }
    box.appendChild(el('h3', n.l));
    var meta = [n.k]; if (n.t && n.t !== n.k) meta.push(n.t); if (n.s) meta.push(n.s); if (n.c !== undefined) meta.push('area: ' + D.communities[n.c]);
    box.appendChild(el('div', meta.join(' · '), 'meta'));
    if (n.f) { var flags = el('div'); n.f.forEach(function (f) { flags.appendChild(el('span', f, 'tag')); }); box.appendChild(flags); }
    if (n.p) box.appendChild(el('div', 'wiki/' + n.p, 'meta'));
    if (n.u) box.appendChild(el('p', 'Not documented in the wiki yet.'));
    if (n.m) box.appendChild(el('p', n.m));
    var rel = el('div', undefined, 'rel');
    adj[n.i].slice(0, 60).forEach(function (li) {
      var l = L[li], out = l[0] === n.i, other = N[out ? l[1] : l[0]];
      var b = el('button'); b.type = 'button';
      var dot = el('span', undefined, 'dot'); dot.style.background = color(other); b.appendChild(dot);
      b.appendChild(el('em', (out ? '' : '← ') + l[2].replace(/_/g, ' ') + (out ? ' →' : '') + (l[3] ? ' (inferred)' : '')));
      b.appendChild(el('span', other.l));
      b.addEventListener('click', function () { select(other, true); });
      rel.appendChild(b);
    });
    if (adj[n.i].length) { box.appendChild(el('h2', 'Relations (' + adj[n.i].length + ')')); box.appendChild(rel); }
    if (center) { view.x = -n.x * view.s; view.y = -n.y * view.s; }
    draw();
  }

  var counts = {};
  N.forEach(function (n) { counts[n.k] = (counts[n.k] || 0) + 1; });
  Object.keys(counts).sort().forEach(function (k) {
    var lab = el('label', undefined, 'f'), cb = el('input'); cb.type = 'checkbox'; cb.checked = true;
    if (k === 'source') { cb.checked = false; hidden[k] = true; }
    cb.addEventListener('change', function () { hidden[k] = !cb.checked; draw(); });
    lab.appendChild(cb); lab.appendChild(el('span', kindNames[k] || k)); lab.appendChild(el('span', String(counts[k]), 'n'));
    $('filters').appendChild(lab);
  });
  var und = el('label', undefined, 'f'), ucb = el('input'); ucb.type = 'checkbox';
  ucb.addEventListener('change', function () { hideUndocumented = ucb.checked; draw(); });
  und.appendChild(ucb); und.appendChild(el('span', 'Hide undocumented components')); $('filters').appendChild(und);
  D.communities.forEach(function (name, i) {
    var b = el('button'); b.type = 'button';
    var dot = el('span', undefined, 'dot'); dot.style.background = palette[i % palette.length]; b.appendChild(dot);
    b.appendChild(el('span', name));
    b.addEventListener('click', function () { focusCommunity = focusCommunity === i ? null : i; draw(); });
    $('legend').appendChild(b);
  });

  $('q').addEventListener('keydown', function (e) {
    if (e.key !== 'Enter') return;
    var q = this.value.trim().toLowerCase(); if (!q) { select(null); return; }
    var hit = N.filter(function (n) { return n.l.toLowerCase() === q || n.id.toLowerCase() === q; })[0] ||
      N.filter(function (n) { return n.l.toLowerCase().indexOf(q) >= 0 || n.id.toLowerCase().indexOf(q) >= 0; }).sort(function (a, b) { return b.d - a.d; })[0];
    if (hit) { hidden[hit.k] = false; select(hit, true); }
  });

  var drag = null, moved = false;
  canvas.addEventListener('mousedown', function (e) { drag = { x: e.clientX, y: e.clientY }; moved = false; });
  window.addEventListener('mouseup', function (e) { if (drag && !moved) select(pick(e), false); drag = null; });
  window.addEventListener('mousemove', function (e) {
    if (drag) { var dx = e.clientX - drag.x, dy = e.clientY - drag.y; if (Math.abs(dx) + Math.abs(dy) > 3) moved = true; view.x += dx; view.y += dy; drag = { x: e.clientX, y: e.clientY }; draw(); return; }
    if (e.target !== canvas) return;
    var n = pick(e), tip = $('tip');
    if (n) { tip.textContent = n.l; tip.style.display = 'block'; tip.style.left = (e.offsetX + 14) + 'px'; tip.style.top = (e.offsetY + 10) + 'px'; }
    else tip.style.display = 'none';
  });
  canvas.addEventListener('wheel', function (e) {
    e.preventDefault();
    var k = Math.exp(-e.deltaY * 0.0015), rect = canvas.getBoundingClientRect();
    var mx = e.clientX - rect.left - rect.width / 2, my = e.clientY - rect.top - rect.height / 2;
    view.x = mx - (mx - view.x) * k; view.y = my - (my - view.y) * k; view.s *= k; draw();
  }, { passive: false });
  window.addEventListener('resize', resize);

  var steps = 0, total = N.length > 1500 ? 120 : 300;
  function run() { for (var i = 0; i < 3 && steps < total; i++, steps++) tick(); draw(); if (steps < total) requestAnimationFrame(run); }
  resize(); run();
})();
</script>
</body>
</html>
'@

$written = [ordered]@{}
if ($OutFile) { Write-Utf8Text $OutFile (Get-GraphJson); $written.graph = $OutFile }
if ($AiExportPath) { Write-AiExport $AiExportPath; $written.aiExport = $AiExportPath }
if ($HtmlPath) { Write-GraphHtml $HtmlPath; $written.html = $HtmlPath }
if ($ReportPath) { Write-KnowledgeMap $ReportPath; $written.report = $ReportPath }

if ($Query) {
    $seeds = @($Query | ForEach-Object { Find-Seeds $_ } | Select-Object -Unique)
    $r = Get-Subgraph 'query' $seeds $false
    $r.terms = @($Query)
    $r | ConvertTo-Json -Depth 8
}
elseif ($Impact) {
    $seeds = @(Find-Seeds $Impact | Select-Object -First 1)
    $r = Get-Subgraph 'impact' $seeds $true
    $r.target = $Impact
    $r | ConvertTo-Json -Depth 8
}
elseif ($From -or $To) {
    if (-not ($From -and $To)) { throw 'Use -From and -To together.' }
    $a = @(Find-Seeds $From | Select-Object -First 1); $b = @(Find-Seeds $To | Select-Object -First 1)
    $path = if ($a.Count -and $b.Count) { Get-Path $a[0] $b[0] }
    [ordered]@{ mode = 'path'; from = $a; to = $b; found = [bool]$path; nodes = @($path.nodes); edges = @($path.edges) } | ConvertTo-Json -Depth 8
}
else {
    $byKind = [ordered]@{}; foreach ($g in ($nodes.Values | Group-Object { $_.kind } | Sort-Object Name)) { $byKind[$g.Name] = $g.Count }
    $byRelation = [ordered]@{}; foreach ($g in ($edgeList | Group-Object { $_.relation } | Sort-Object Name)) { $byRelation[$g.Name] = $g.Count }
    [ordered]@{
        wiki        = $WikiPath
        inventories = $inventories
        nodes       = $nodes.Count
        edges       = $edgeList.Count
        byKind      = $byKind
        byRelation  = $byRelation
        communities = $communities
        hubs        = $hubs
        bridges     = $bridges
        gaps        = $gaps
        outputs     = $written
    } | ConvertTo-Json -Depth 8
}
