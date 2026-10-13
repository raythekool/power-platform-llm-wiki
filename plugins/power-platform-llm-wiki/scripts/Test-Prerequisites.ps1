#Requires -Version 7.0
<#
.SYNOPSIS
    Read-only check of the tools used by the LLM Wiki: what is installed, what is missing, what the selected features require.
.DESCRIPTION
    Used by `init` (before the wizard and again with the chosen features) and by `config` (when sources or publishing change).
    Never installs or changes anything. Each check reports status (ok | missing | warning), version, path, what it enables,
    whether the selected features require it and an install hint. Probes run in parallel.
    PowerShell 7 and git are always required. -Features adds:
      azure-repos   Git Credential Manager          ado-wiki      Git Credential Manager
      tfvc          tf.exe (Visual Studio)          github        gh, signed in
      dataverse     pacx or pac                     github-wiki   gh, signed in
      documents     markitdown                      ado-local     node (local Azure DevOps MCP server)
    Agent tools (VS Code, Copilot CLI, Claude Code) and markitdown-mcp are reported for information only.
    Exit code 0 when every required tool is available, 1 otherwise; the JSON is printed in both cases.
.PARAMETER Features
    Features selected in the wizard, as an array or a comma-separated string (works with pwsh -File).
.PARAMETER TimeoutSeconds
    Maximum time to wait for all version probes (default 30). A tool that is found but slow is still reported as ok.
#>
[CmdletBinding()]
param(
    [string[]]$Features = @(),
    [int]$TimeoutSeconds = 30
)

$ErrorActionPreference = 'Stop'
$allowed = 'azure-repos', 'tfvc', 'dataverse', 'github', 'github-wiki', 'ado-wiki', 'documents', 'ado-local'
$Features = @($Features | ForEach-Object { $_ -split '[,;\s]+' } | Where-Object { $_ } | ForEach-Object { $_.ToLowerInvariant() } | Select-Object -Unique)
$unknown = @($Features | Where-Object { $_ -notin $allowed })
if ($unknown) { throw "Unknown feature(s): $($unknown -join ', '). Allowed: $($allowed -join ', ')" }

function Find-Tool([string]$Name) {
    $cmd = Get-Command -Name $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    return $null
}

function Start-Probe([string]$Path, [string[]]$Arguments) {
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    if ($IsWindows -and [IO.Path]::GetExtension($Path) -in '.cmd', '.bat') {
        # npm-style shims only run through cmd.exe
        $psi.FileName = if ($env:ComSpec) { $env:ComSpec } else { 'cmd.exe' }
        $psi.Arguments = "/d /c `"`"$Path`" $($Arguments -join ' ')`""
    }
    else {
        $psi.FileName = $Path
        foreach ($a in $Arguments) { $psi.ArgumentList.Add($a) }
    }
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.Environment['NO_COLOR'] = '1'
    $psi.Environment['GH_PROMPT_DISABLED'] = '1'
    try {
        $p = [System.Diagnostics.Process]::Start($psi)
        $p.StandardInput.Close()
        return [pscustomobject]@{ Process = $p; Out = $p.StandardOutput.ReadToEndAsync(); Err = $p.StandardError.ReadToEndAsync(); Error = $null }
    }
    catch { return [pscustomobject]@{ Process = $null; Error = $_.Exception.Message } }
}

function Wait-Probe($Probe, [datetime]$Deadline) {
    if (-not $Probe) { return $null }
    if ($Probe.Error) { return [pscustomobject]@{ Exit = -1; Output = $Probe.Error } }
    $p = $Probe.Process
    $ms = [int][Math]::Max(0, ($Deadline - [datetime]::UtcNow).TotalMilliseconds)
    if (-not $p.WaitForExit($ms)) {
        try { $p.Kill($true) } catch { }
        return [pscustomobject]@{ Exit = -1; Output = "timed out after $TimeoutSeconds s" }
    }
    $p.WaitForExit()
    return [pscustomobject]@{ Exit = $p.ExitCode; Output = "$($Probe.Out.Result)`n$($Probe.Err.Result)".Trim() }
}

function Get-Version([string]$Text) {
    $m = [regex]::Match($Text, '\d+\.\d+(?:\.\d+){0,2}')
    if ($m.Success) { return $m.Value }
    return $null
}

function Get-FirstLine([string]$Text) {
    $line = "$(@($Text -split '\r?\n' | Where-Object { $_.Trim() })[0])"
    if ($line.Length -gt 200) { $line = $line.Substring(0, 200) }
    return $line
}

# Tool catalogue. Args = version probe (none: presence only). Group = alternatives that satisfy the same need.
$tfNeeded = 'Code in TFVC (TFS, Azure DevOps Server); otherwise use provider local with a downloaded copy'
$specs = @(
    @{ Id = 'git'; Name = 'git'; Command = 'git'; Args = @('--version'); RequiredBy = @('always'); NeededFor = 'Code analysis, publishing'; Install = 'winget install Git.Git (Windows) or https://git-scm.com/downloads' }
    @{ Id = 'git-credential-manager'; Name = 'Git Credential Manager'; Command = 'git'; Args = @('credential-manager', '--version'); RequiredBy = @('azure-repos', 'ado-wiki'); NeededFor = 'Azure Repos clone, Azure DevOps Wiki push (Entra ID sign-in, no PAT)'; Install = 'Included in Git for Windows; otherwise https://github.com/git-ecosystem/git-credential-manager'; ExitDecides = $true }
    @{ Id = 'tf'; Name = 'tf.exe (TFVC)'; Command = 'tf'; Args = @('help'); RequiredBy = @('tfvc'); NeededFor = $tfNeeded; Install = 'Visual Studio with the Team Explorer component; run from a Developer PowerShell for VS'; WindowsOnly = $true }
    @{ Id = 'pacx'; Name = 'PACX'; Command = 'pacx'; Args = @('--version'); RequiredBy = @('dataverse'); Group = 'dataverse-cli'; NeededFor = 'Dataverse source (pacx or pac)'; Install = 'dotnet tool install --global Greg.Xrm.Command, then pacx auth create' }
    @{ Id = 'pac'; Name = 'Power Platform CLI'; Command = 'pac'; Args = @('help'); RequiredBy = @('dataverse'); Group = 'dataverse-cli'; NeededFor = 'Dataverse source (pacx or pac)'; Install = 'dotnet tool install --global Microsoft.PowerApps.CLI.Tool, then pac auth create' }
    @{ Id = 'gh'; Name = 'GitHub CLI'; Command = 'gh'; Args = @('--version'); RequiredBy = @('github', 'github-wiki'); NeededFor = 'GitHub activity source, GitHub Wiki publishing'; Install = 'winget install GitHub.cli (Windows) or https://cli.github.com, then gh auth login' }
    @{ Id = 'markitdown'; Name = 'MarkItDown'; Command = 'markitdown'; Args = @('--version'); RequiredBy = @('documents'); NeededFor = 'Word, PowerPoint, Excel and PDF sources in raw/'; Install = "pip install 'markitdown[all]'" }
    @{ Id = 'markitdown-mcp'; Name = 'MarkItDown MCP server'; Command = 'markitdown-mcp'; Args = @(); RequiredBy = @(); NeededFor = 'Optional markitdown MCP entry written by init'; Install = 'pip install markitdown-mcp' }
    @{ Id = 'node'; Name = 'Node.js'; Command = 'node'; Args = @('--version'); RequiredBy = @('ado-local'); NeededFor = 'Local Azure DevOps MCP server (ado-local, through npx) when ado-remote is not available'; Install = 'winget install OpenJS.NodeJS.LTS (Windows) or https://nodejs.org' }
    @{ Id = 'code'; Name = 'VS Code'; Command = 'code'; Args = @('--version'); RequiredBy = @(); NeededFor = 'Agent tool: VS Code with GitHub Copilot'; Install = 'https://code.visualstudio.com' }
    @{ Id = 'copilot'; Name = 'GitHub Copilot CLI'; Command = 'copilot'; Args = @('--version'); RequiredBy = @(); NeededFor = 'Agent tool: GitHub Copilot CLI'; Install = 'npm install -g @github/copilot' }
    @{ Id = 'claude'; Name = 'Claude Code'; Command = 'claude'; Args = @('--version'); RequiredBy = @(); NeededFor = 'Agent tool: Claude Code (2.1.275 or later)'; Install = 'npm install -g @anthropic-ai/claude-code'; MinVersion = '2.1.275' }
)

# Resolve paths and start every probe before waiting for any of them.
$deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
foreach ($s in $specs) {
    $s.Path = if ($s.WindowsOnly -and -not $IsWindows) { $null } else { Find-Tool $s.Command }
    if ($s.Id -eq 'tf' -and -not $s.Path -and $IsWindows) {
        $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
        if (Test-Path -LiteralPath $vswhere) {
            $found = @(& $vswhere -latest -products * -find '**\TF.exe' 2>$null)
            if ($found) { $s.Path = $found[0]; $s.Note = 'not on PATH: use a Developer PowerShell for VS or the full path' }
        }
    }
    $s.Probe = if ($s.Path -and $s.Args.Count) { Start-Probe $s.Path $s.Args } else { $null }
    # Only the exit code of gh auth status is used: its output can contain account details.
    if ($s.Id -eq 'gh' -and $s.Path) { $s.AuthProbe = Start-Probe $s.Path @('auth', 'status') }
}

$checks = [System.Collections.Generic.List[object]]::new()
$checks.Add([pscustomobject][ordered]@{
        id = 'pwsh'; name = 'PowerShell 7'; status = 'ok'; version = $PSVersionTable.PSVersion.ToString(); path = (Get-Process -Id $PID).Path
        required = $true; neededFor = 'All engine scripts'; detail = ''; install = 'winget install Microsoft.PowerShell (Windows) or https://aka.ms/powershell'; group = 'pwsh'
    })
foreach ($s in $specs) {
    $result = Wait-Probe $s.Probe $deadline
    $status = if ($s.Path) { 'ok' } else { 'missing' }
    $version = if ($result -and $result.Exit -eq 0) { Get-Version $result.Output } else { $null }
    $detail = if ($s.WindowsOnly -and -not $IsWindows) { 'Windows only' } elseif ($s.Note) { $s.Note } else { '' }
    if ($result -and $result.Exit -ne 0) {
        # A git subcommand exists only if it runs; for the other tools presence is enough.
        if ($s.ExitDecides) { $status = 'missing' } elseif (-not $detail) { $detail = "version probe failed: $(Get-FirstLine $result.Output)" }
    }
    if ($s.AuthProbe) {
        if ((Wait-Probe $s.AuthProbe $deadline).Exit -eq 0) { $detail = 'signed in' }
        else { $status = 'warning'; $detail = 'not signed in: run gh auth login' }
    }
    if ($status -eq 'ok' -and $s.MinVersion -and $version -and [version]$version -lt [version]$s.MinVersion) {
        $status = 'warning'; $detail = "older than $($s.MinVersion): update it"
    }
    $checks.Add([pscustomobject][ordered]@{
            id        = $s.Id
            name      = $s.Name
            status    = $status
            version   = $version
            path      = if ($s.ExitDecides) { $null } else { $s.Path }
            required  = ($s.RequiredBy -contains 'always') -or [bool](@($s.RequiredBy | Where-Object { $_ -in $Features }).Count)
            neededFor = $s.NeededFor
            detail    = $detail
            install   = $s.Install
            group     = if ($s.Group) { $s.Group } else { $s.Id }
        })
}

# A group is satisfied when any of its members is ok (e.g. pacx or pac).
$blocking = [System.Collections.Generic.List[string]]::new()
foreach ($g in @($checks | Where-Object required | ForEach-Object group | Select-Object -Unique)) {
    $members = @($checks | Where-Object group -eq $g)
    if (-not ($members | Where-Object status -eq 'ok')) { $blocking.Add(($members.id -join ' or ')) }
}

[ordered]@{
    platform        = if ($IsWindows) { 'windows' } elseif ($IsMacOS) { 'macos' } else { 'linux' }
    features        = @($Features)
    ready           = ($blocking.Count -eq 0)
    blocking        = @($blocking)
    optionalMissing = @($checks | Where-Object { -not $_.required -and $_.status -ne 'ok' } | ForEach-Object id)
    checks          = @($checks)
} | ConvertTo-Json -Depth 4

if ($blocking.Count -gt 0) { exit 1 }
