#Requires -Version 7.0
<#
.SYNOPSIS
    Deterministic inventory of a source repository for code-first documentation (no LLM tokens needed).
.DESCRIPTION
    Walks a local clone and extracts a compact JSON inventory the agent reads instead of the raw code:
      - Dataverse / Power Platform: plugins, workflow activities, PCF controls, web resources,
        unpacked solutions (Solution.xml), cloud flows, .NET projects
      - Dynamics 365 Finance & Operations: model descriptors and Ax* metadata (tables, table/form/class
        extensions, classes incl. ExtensionOf / CoC methods, forms, data entities, enums, EDTs,
        security privileges / duties / roles, menu items)
      - CI/CD pipelines (Azure Pipelines, GitHub Actions)
    The agent then reads only the files that matter for each wiki page.
.PARAMETER Path
    Root of the local clone (or any folder, e.g. PackagesLocalDirectory/<Package>).
.PARAMETER OutFile
    Optional JSON output path (recommended: llm-wiki/raw/code/<repo>-<yyyy-MM-dd>.json). Stdout otherwise.
.PARAMETER MaxFileKB
    Text files larger than this are not parsed.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Path,
    [string]$OutFile,
    [int]$MaxFileKB = 1024
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/LlmWiki.Common.ps1"

$Path = (Resolve-Path -LiteralPath $Path).Path
$skipDirs = @('.git', 'bin', 'obj', 'node_modules', 'packages', '.vs', 'TestResults', 'dist', 'out', 'generated', '.idea', 'XppMetadata')
$xsi = 'http://www.w3.org/2001/XMLSchema-instance'

function Get-Files([string]$Root) {
    $stack = [System.Collections.Generic.Stack[string]]::new()
    $stack.Push($Root)
    while ($stack.Count -gt 0) {
        $dir = $stack.Pop()
        foreach ($d in [System.IO.Directory]::EnumerateDirectories($dir)) {
            if ((Split-Path -Leaf $d) -notin $skipDirs) { $stack.Push($d) }
        }
        foreach ($f in [System.IO.Directory]::EnumerateFiles($dir)) { [System.IO.FileInfo]::new($f) }
    }
}

function Get-Xml([string]$File) {
    try {
        $doc = [System.Xml.XmlDocument]::new()
        $doc.XmlResolver = $null
        $doc.Load($File)
        return $doc
    }
    catch { return $null }
}

function Get-Nodes($Node, [string]$LocalName) { @($Node.SelectNodes(".//*[local-name()='$LocalName']")) }
function Get-ChildText($Node, [string]$LocalName) {
    $n = $Node.SelectSingleNode("./*[local-name()='$LocalName']")
    if ($n) { return $n.InnerText.Trim() } else { return $null }
}

function Get-AxDetail([string]$Type, $Root) {
    $name = Get-ChildText $Root 'Name'
    $o = [ordered]@{ name = $name }
    switch -Regex ($Type) {
        '^AxTable(Extension)?$' {
            if ($Type -eq 'AxTableExtension') { $o.extends = ($name -split '\.')[0] }
            $o.fields = @(Get-Nodes $Root 'AxTableField' | ForEach-Object {
                    [ordered]@{
                        name = Get-ChildText $_ 'Name'
                        kind = ($_.GetAttribute('type', $xsi) -replace '^AxTableField', '')
                        edt  = Get-ChildText $_ 'ExtendedDataType'
                        enum = Get-ChildText $_ 'EnumType'
                    }
                })
            $o.relations = @(Get-Nodes $Root 'AxTableRelation' | ForEach-Object { [ordered]@{ name = Get-ChildText $_ 'Name'; relatedTable = Get-ChildText $_ 'RelatedTable' } })
            $o.indexes = @(Get-Nodes $Root 'AxTableIndex' | ForEach-Object { Get-ChildText $_ 'Name' })
            $o.methods = @(Get-Nodes $Root 'Method' | ForEach-Object { Get-ChildText $_ 'Name' })
        }
        '^AxClass$' {
            $decl = ($Root.SelectSingleNode(".//*[local-name()='Declaration']")).InnerText
            if ($decl) {
                $ext = [regex]::Match($decl, 'ExtensionOf\s*\(\s*\w+Str\s*\(\s*([^),]+)')
                if ($ext.Success) { $o.extensionOf = $ext.Groups[1].Value.Trim() }
                $inh = [regex]::Match($decl, '\bextends\s+(\w+)')
                if ($inh.Success) { $o.extends = $inh.Groups[1].Value }
                $impl = [regex]::Match($decl, '\bimplements\s+([\w\s,]+)')
                if ($impl.Success) { $o.implements = @($impl.Groups[1].Value -split '\s*,\s*' | Where-Object { $_ } | ForEach-Object { $_.Trim() }) }
                $o.attributes = @([regex]::Matches($decl, '^\s*\[(\w+)', 'Multiline') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
            }
            $o.methods = @(Get-Nodes $Root 'Method' | ForEach-Object {
                    $src = Get-ChildText $_ 'Source'
                    [ordered]@{ name = Get-ChildText $_ 'Name'; callsNext = [bool]($src -match '\bnext\s+\w+\s*\(') }
                })
        }
        '^AxForm(Extension)?$' {
            if ($Type -eq 'AxFormExtension') { $o.extends = ($name -split '\.')[0] }
            $o.dataSources = @(Get-Nodes $Root 'AxFormDataSource' | ForEach-Object { [ordered]@{ name = Get-ChildText $_ 'Name'; table = Get-ChildText $_ 'Table' } })
        }
        '^AxDataEntityView$' {
            $o.publicEntityName = Get-ChildText $Root 'PublicEntityName'
            $o.publicCollectionName = Get-ChildText $Root 'PublicCollectionName'
            $o.isPublic = Get-ChildText $Root 'IsPublic'
            $o.tables = @(Get-Nodes $Root 'Table' | ForEach-Object { $_.InnerText.Trim() } | Where-Object { $_ } | Select-Object -Unique)
            $o.fields = @(Get-Nodes $Root 'AxDataEntityViewField' | ForEach-Object { [ordered]@{ name = Get-ChildText $_ 'Name'; dataSource = Get-ChildText $_ 'DataSource'; dataField = Get-ChildText $_ 'DataField' } })
        }
        '^AxEnum(Extension)?$' {
            $o.values = @(Get-Nodes $Root 'AxEnumValue' | ForEach-Object { Get-ChildText $_ 'Name' })
        }
        '^AxEdt' {
            $o.kind = ($Root.GetAttribute('type', $xsi) -replace '^AxEdt', '')
            $o.extends = Get-ChildText $Root 'Extends'
        }
        '^AxSecurityPrivilege$' {
            $o.entryPoints = @(Get-Nodes $Root 'AxSecurityEntryPointReference' | ForEach-Object {
                    [ordered]@{ object = Get-ChildText $_ 'ObjectName'; objectType = Get-ChildText $_ 'ObjectType'; form = Get-ChildText $_ 'Forms' }
                })
        }
        '^AxSecurityDuty$' { $o.privileges = @(Get-Nodes $Root 'AxSecurityPrivilegeReference' | ForEach-Object { Get-ChildText $_ 'Name' }) }
        '^AxSecurityRole$' {
            $o.duties = @(Get-Nodes $Root 'AxSecurityDutyReference' | ForEach-Object { Get-ChildText $_ 'Name' })
            $o.privileges = @(Get-Nodes $Root 'AxSecurityPrivilegeReference' | ForEach-Object { Get-ChildText $_ 'Name' })
        }
        '^AxMenuItem' {
            $o.object = Get-ChildText $Root 'Object'
            $o.objectType = Get-ChildText $Root 'ObjectType'
        }
    }
    return $o
}

$inventory = [ordered]@{
    root        = $Path
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    gitHead     = $null
    gitBranch   = $null
    fileCount   = 0
    extensions  = [ordered]@{}
    components  = [ordered]@{
        dataversePlugins   = @()
        workflowActivities = @()
        pcfControls        = @()
        webResources       = @()
        solutions          = @()
        flows              = @()
        dotnetProjects     = @()
        pipelines          = @()
    }
    fno         = [ordered]@{ models = @(); counts = [ordered]@{}; objects = [ordered]@{} }
    warnings    = @()
}

if (Test-Path -LiteralPath (Join-Path $Path '.git')) {
    $inventory.gitHead = (& git -C $Path rev-parse HEAD 2>$null)
    $inventory.gitBranch = (& git -C $Path rev-parse --abbrev-ref HEAD 2>$null)
}

$extCounts = @{}
$axObjects = @{}
foreach ($f in (Get-Files $Path)) {
    $inventory.fileCount++
    $rel = Get-RelativePath $Path $f.FullName
    $ext = $f.Extension.ToLowerInvariant()
    $extCounts[$ext] = 1 + ($extCounts[$ext] ?? 0)
    $tooBig = $f.Length -gt ($MaxFileKB * 1KB)
    $parent = Split-Path -Leaf (Split-Path -Parent $f.FullName)

    if ($ext -eq '.xml' -and $parent -match '^Ax[A-Z]\w+$' -and -not $tooBig) {
        $doc = Get-Xml $f.FullName
        if ($doc) {
            $detail = Get-AxDetail $parent $doc.DocumentElement
            $detail.file = $rel
            if (-not $axObjects.ContainsKey($parent)) { $axObjects[$parent] = [System.Collections.Generic.List[object]]::new() }
            $axObjects[$parent].Add($detail)
        }
        else { $inventory.warnings += "Unparsable XML: $rel" }
        continue
    }
    if ($ext -eq '.xml' -and $parent -eq 'Descriptor') {
        $doc = Get-Xml $f.FullName
        if ($doc -and $doc.DocumentElement.LocalName -eq 'AxModelInfo') {
            $r = $doc.DocumentElement
            $inventory.fno.models += [ordered]@{
                name        = Get-ChildText $r 'Name'
                displayName = Get-ChildText $r 'DisplayName'
                layer       = Get-ChildText $r 'Layer'
                publisher   = Get-ChildText $r 'Publisher'
                references  = @(Get-Nodes $r 'string' | ForEach-Object { $_.InnerText })
                file        = $rel
            }
        }
        continue
    }
    if ($f.Name -eq 'ControlManifest.Input.xml') {
        $doc = Get-Xml $f.FullName
        $c = if ($doc) { $doc.SelectSingleNode("//*[local-name()='control']") }
        if ($c) {
            $inventory.components.pcfControls += [ordered]@{ namespace = $c.GetAttribute('namespace'); constructor = $c.GetAttribute('constructor'); version = $c.GetAttribute('version'); controlType = $c.GetAttribute('control-type'); file = $rel }
        }
        continue
    }
    if ($f.Name -eq 'Solution.xml') {
        $doc = Get-Xml $f.FullName
        if ($doc -and $doc.SelectSingleNode("//*[local-name()='SolutionManifest']")) {
            $m = $doc.SelectSingleNode("//*[local-name()='SolutionManifest']")
            $inventory.components.solutions += [ordered]@{
                uniqueName = Get-ChildText $m 'UniqueName'
                version    = Get-ChildText $m 'Version'
                managed    = Get-ChildText $m 'Managed'
                prefix     = ($m.SelectSingleNode(".//*[local-name()='CustomizationPrefix']")).InnerText
                file       = $rel
            }
        }
        continue
    }
    if ($ext -eq '.json' -and $rel -match '(^|/)Workflows/[^/]+\.json$') {
        $inventory.components.flows += [ordered]@{ name = [System.IO.Path]::GetFileNameWithoutExtension($f.Name); file = $rel }
        continue
    }
    if ($ext -eq '.csproj' -and -not $tooBig) {
        $doc = Get-Xml $f.FullName
        $tf = if ($doc) { ($doc.SelectSingleNode("//*[local-name()='TargetFramework' or local-name()='TargetFrameworks' or local-name()='TargetFrameworkVersion']")).InnerText }
        $inventory.components.dotnetProjects += [ordered]@{ name = [System.IO.Path]::GetFileNameWithoutExtension($f.Name); targetFramework = $tf; file = $rel }
        continue
    }
    if ($ext -eq '.cs' -and -not $tooBig) {
        $src = Read-Utf8Text $f.FullName
        foreach ($m in [regex]::Matches($src, 'class\s+(\w+)\s*:\s*([^{]+)\{')) {
            $bases = $m.Groups[2].Value
            if ($bases -match '\b(IPlugin|PluginBase)\b') {
                $inventory.components.dataversePlugins += [ordered]@{ class = $m.Groups[1].Value; bases = ($bases -replace '\s+', ' ').Trim(); file = $rel }
            }
            elseif ($bases -match '\bCodeActivity\b') {
                $inventory.components.workflowActivities += [ordered]@{ class = $m.Groups[1].Value; file = $rel }
            }
        }
        continue
    }
    if ($ext -in @('.yml', '.yaml') -and ($rel -match '(^|/)\.github/workflows/' -or $f.Name -match '^azure-pipelines' -or $rel -match '(^|/)(\.azuredevops|\.pipelines|pipelines)/')) {
        $kind = if ($rel -match '\.github/workflows/') { 'github-actions' } else { 'azure-pipelines' }
        $inventory.components.pipelines += [ordered]@{ kind = $kind; file = $rel }
        continue
    }
    if ($ext -in @('.js', '.ts', '.html', '.css', '.resx') -and $rel -match '(?i)(^|/)web ?resources?/') {
        $inventory.components.webResources += $rel
    }
}

foreach ($e in ($extCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 25)) { $inventory.extensions[$e.Key] = $e.Value }
foreach ($t in ($axObjects.Keys | Sort-Object)) {
    $inventory.fno.counts[$t] = $axObjects[$t].Count
    $inventory.fno.objects[$t] = @($axObjects[$t] | Sort-Object { $_.name })
}

$json = $inventory | ConvertTo-Json -Depth 8
if ($OutFile) {
    Write-Utf8Text $OutFile $json
    [ordered]@{
        outFile    = $OutFile
        fileCount  = $inventory.fileCount
        components = [ordered]@{
            dataversePlugins = $inventory.components.dataversePlugins.Count
            pcfControls      = $inventory.components.pcfControls.Count
            webResources     = $inventory.components.webResources.Count
            solutions        = $inventory.components.solutions.Count
            flows            = $inventory.components.flows.Count
            pipelines        = $inventory.components.pipelines.Count
        }
        fnoModels  = $inventory.fno.models.Count
        fnoCounts  = $inventory.fno.counts
    } | ConvertTo-Json -Depth 4
}
else { $json }
