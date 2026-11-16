<#
.SYNOPSIS
    Run a folder of KQL threat-hunting queries against Microsoft Defender XDR
    (advanced hunting) and/or a Sentinel / Log Analytics workspace, straight
    from the command line - no portal round-trips.

.DESCRIPTION
    Part of the DefXDRLabKit blue-team toolkit. Point it at a folder of .kql
    files (or a single file, or an inline query) and it will:
      * discover and order the .kql files,
      * read each file's header to decide where it runs (XDR vs Sentinel),
      * run it read-only, show the row count and a preview here,
      * optionally export every result to CSV + JSON (evidence), and
      * in -Test mode, print a PASS / FAIL / EMPTY summary you can use as a
        blue-team detection regression check.

    Two back-ends, picked per file from the header, or forced with -Source:
      XDR       Microsoft Graph advanced hunting  (Device*/Identity*/Alert*),
                via the Microsoft.Graph.Authentication module if present,
                else 'az rest' to /security/runHuntingQuery.
      Sentinel  az monitor log-analytics query against the lab workspace
                (SecurityEvent, AzureActivity, AuditLogs, ...).

    All queries are READ-ONLY. The script never writes to the tenant.

    HEADER DIRECTIVES (comment lines at the top of a .kql file):
      // name: Friendly name                 (else the first "// NN: Title" line)
      // source: XDR | Sentinel | LA         (else auto-detected from the header)
      // expect: rows | empty | >=N | ==N | >N | <N   (for -Test; default: rows)
    The runner also auto-detects the source from the marker lines this query
    pack already uses: "DEFENDER XDR ADVANCED HUNTING" -> XDR,
    "SENTINEL" or "SECURITYEVENT" -> Sentinel.

.PARAMETER Path
    A folder of .kql files, or a single .kql file. Default: .\queries next to
    this script, else the current directory.

.PARAMETER Query
    Run an inline KQL string instead of files (use with -Source).

.PARAMETER Source
    Auto (default), XDR, or Sentinel. Overrides per-file detection when not Auto.

.PARAMETER Only
    Wildcard filter on file name, e.g. -Only '3*'  or  -Only '*lsass*'.

.PARAMETER ResourceGroup
    Lab resource group (default: from ~/.defxdrlab/config.json, else rg-defxdr-lab).

.PARAMETER Workspace
    Log Analytics workspace name (default: from config, else law-defxdr-lab).

.PARAMETER Export
    Folder to write per-query .json + .csv results and a run summary into.

.PARAMETER Test
    Blue-team test mode: evaluate each file's // expect: directive and print a
    PASS/FAIL/EMPTY summary table at the end. Sets exit code 1 if any FAIL.

.PARAMETER Max
    Max rows to print per query (default 20). Export always writes all rows.

.PARAMETER List
    Discover and show the queries + detected source/expectation, but run nothing.

.EXAMPLE
    .\Invoke-KqlHunt.ps1 -Path .\queries
.EXAMPLE
    .\Invoke-KqlHunt.ps1 -Path .\queries -Test -Export .\hunt-results
.EXAMPLE
    .\Invoke-KqlHunt.ps1 -Path .\queries -Only '6*' -Source Sentinel
#>
[CmdletBinding(DefaultParameterSetName = 'Files')]
param(
    [Parameter(ParameterSetName = 'Files', Position = 0)]
    [string]$Path,
    [Parameter(ParameterSetName = 'Inline', Mandatory = $true)]
    [string]$Query,
    [ValidateSet('Auto', 'XDR', 'Sentinel', 'LA')]
    [string]$Source = 'Auto',
    [string]$Only,
    [string]$ResourceGroup,
    [string]$Workspace,
    [string]$Export,
    [switch]$Test,
    [int]$Max = 20,
    [switch]$List,
    [int]$ThrottleMs = 400
)

$ErrorActionPreference = 'Stop'
$env:PYTHONWARNINGS = 'ignore'   # silence az bundled-Python 32-bit OpenSSL noise

# ---- console helpers -----------------------------------------------------
function Say  ($m, $c = 'Gray')    { Write-Host $m -ForegroundColor $c }
function Info ($m) { Write-Host "  $m" -ForegroundColor Cyan }
function Ok   ($m) { Write-Host "  $m" -ForegroundColor Green }
function Warn ($m) { Write-Host "  $m" -ForegroundColor Yellow }
function Err  ($m) { Write-Host "  $m" -ForegroundColor Red }
function Rule { Write-Host ("-" * 78) -ForegroundColor DarkGray }

$Here = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

# ---- config (resource group + workspace) ---------------------------------
function Get-LabConfig {
    $cfg = @{ ResourceGroup = 'rg-defxdr-lab'; WorkspaceName = 'law-defxdr-lab' }
    $userHome = if ($env:USERPROFILE) { $env:USERPROFILE } elseif ($env:HOME) { $env:HOME } else { [Environment]::GetFolderPath('UserProfile') }
    $file = Join-Path $userHome '.defxdrlab/config.json'
    if (Test-Path $file) {
        try {
            $j = Get-Content $file -Raw | ConvertFrom-Json
            if ($j.ResourceGroup) { $cfg.ResourceGroup = $j.ResourceGroup }
            if ($j.WorkspaceName) { $cfg.WorkspaceName = $j.WorkspaceName }
        } catch { Warn "Could not read $file ($($_.Exception.Message)) - using defaults." }
    }
    if ($ResourceGroup) { $cfg.ResourceGroup = $ResourceGroup }
    if ($Workspace)     { $cfg.WorkspaceName = $Workspace }
    return $cfg
}

# ---- header parsing ------------------------------------------------------
function Read-QueryMeta {
    param([string]$Text, [string]$FileName)
    $name = $null; $src = $null; $expect = $null
    foreach ($line in ($Text -split "`n")) {
        $t = $line.Trim()
        if ($t -notmatch '^(//|#)') {
            if ($t -ne '' -and $t -notmatch '^let\s') { break }  # past the header
            if ($t -match '^let\s') { continue }
            continue
        }
        $body = ($t -replace '^(//|#)\s?', '')
        if ($body -match '^(?i)name\s*:\s*(.+)$')       { $name   = $Matches[1].Trim() }
        elseif ($body -match '^(?i)source\s*:\s*(.+)$')  { $src    = $Matches[1].Trim() }
        elseif ($body -match '^(?i)expect\s*:\s*(.+)$')  { $expect = $Matches[1].Trim() }
        elseif (-not $name -and $body -match '^\d+\s*:\s*(.+)$') { $name = $Matches[1].Trim() }
        if ($body -match '(?i)DEFENDER\s+XDR|ADVANCED\s+HUNTING') { if (-not $src) { $src = 'XDR' } }
        if ($body -match '(?i)SENTINEL|SECURITYEVENT|LOG\s*ANALYTICS') { if (-not $src) { $src = 'Sentinel' } }
    }
    if (-not $name) { $name = [IO.Path]::GetFileNameWithoutExtension($FileName) }
    # normalise source
    $s = switch -Regex ($src) { '(?i)^xdr'  { 'XDR'; break } '(?i)^(sentinel|la|loganalytics)' { 'Sentinel'; break } default { $null } }
    if (-not $expect) { $expect = 'rows' }
    return [pscustomobject]@{ Name = $name; Source = $s; Expect = $expect }
}

# ---- back-end: Microsoft Graph advanced hunting (XDR) --------------------
$script:GraphMode = $null   # 'module' | 'az' | 'none'  (resolved once)
function Initialize-XdrBackend {
    if ($script:GraphMode) { return }
    if (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication) {
        try {
            Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
            $ctx = Get-MgContext
            if (-not $ctx -or ($ctx.Scopes -notcontains 'ThreatHunting.Read.All')) {
                Info "Signing in to Microsoft Graph for advanced hunting (ThreatHunting.Read.All, read-only). A browser may open once."
                Connect-MgGraph -Scopes 'ThreatHunting.Read.All' -NoWelcome -ErrorAction Stop
            }
            Ok "Graph advanced hunting ready (signed in as $((Get-MgContext).Account))."
            $script:GraphMode = 'module'; return
        } catch { Warn "Graph module sign-in failed: $($_.Exception.Message). Falling back to az rest." }
    }
    $script:GraphMode = 'az'
    Info "Using 'az rest' for XDR advanced hunting (install Microsoft.Graph.Authentication for a smoother sign-in)."
}
function Invoke-XdrQuery {
    param([string]$Kql)
    Initialize-XdrBackend
    if ($script:GraphMode -eq 'module') {
        $resp = Invoke-MgGraphRequest -Method POST -Uri 'https://graph.microsoft.com/v1.0/security/runHuntingQuery' `
                    -Body (@{ Query = $Kql } | ConvertTo-Json) -ContentType 'application/json' -ErrorAction Stop
        return , @($resp.results | ForEach-Object { [pscustomobject]$_ })
    }
    $tmp = Join-Path $env:TEMP ('hunt-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.json')
    (@{ Query = $Kql } | ConvertTo-Json) | Set-Content $tmp -Encoding utf8
    try {
        $raw = az rest --method post --url 'https://graph.microsoft.com/v1.0/security/runHuntingQuery' `
                   --headers 'Content-Type=application/json' --body "@$tmp" -o json 2>&1
        $code = $LASTEXITCODE
    } finally { Remove-Item $tmp -ErrorAction SilentlyContinue }
    if ($code -ne 0) { throw "az rest runHuntingQuery failed: $(( $raw | Out-String).Trim())" }
    return , @((($raw | Out-String) | ConvertFrom-Json).results)
}

# ---- back-end: Sentinel / Log Analytics ----------------------------------
$script:WorkspaceId = $null
function Resolve-WorkspaceId {
    param($Cfg)
    if ($script:WorkspaceId) { return $script:WorkspaceId }
    $id = az monitor log-analytics workspace show -g $Cfg.ResourceGroup -n $Cfg.WorkspaceName --query customerId -o tsv 2>$null
    if ($LASTEXITCODE -eq 0 -and $id) { $script:WorkspaceId = $id.Trim(); return $script:WorkspaceId }
    throw "Could not resolve workspace '$($Cfg.WorkspaceName)' in RG '$($Cfg.ResourceGroup)'. Is Sentinel deployed and is az pointed at the lab subscription?"
}
function Invoke-SentinelQuery {
    param([string]$Kql, $Cfg)
    $ws = Resolve-WorkspaceId $Cfg
    $raw = az monitor log-analytics query -w $ws --analytics-query $Kql -o json 2>&1
    if ($LASTEXITCODE -ne 0) { throw "log-analytics query failed: $(( $raw | Out-String).Trim())" }
    return , @((($raw | Out-String) | ConvertFrom-Json))
}

# ---- rows -> display / export --------------------------------------------
function Flatten-Cell($v) {
    if ($null -eq $v) { return '' }
    if ($v -is [System.Collections.IEnumerable] -and $v -isnot [string]) { return (($v | ForEach-Object { "$_" }) -join '; ') }
    return "$v"
}
function Show-Rows($rows, [int]$MaxRows) {
    $rows = @($rows)
    if ($rows.Count -eq 0) { Warn "0 rows in this window."; return }
    Ok "$($rows.Count) row(s)$(if ($rows.Count -gt $MaxRows) { " - showing first $MaxRows" })"
    $rows | Select-Object -First $MaxRows |
        Select-Object * -ExcludeProperty TableName, TenantId |
        Format-Table -AutoSize -Wrap | Out-String -Width 200 | Write-Host
}
function Export-Result {
    param($Rows, [string]$Dir, [string]$BaseName)
    $rows = @($Rows)
    $json = Join-Path $Dir "$BaseName.json"
    $csv  = Join-Path $Dir "$BaseName.csv"
    ($rows | ConvertTo-Json -Depth 8) | Set-Content $json -Encoding utf8
    if ($rows.Count) {
        $props = $rows[0].PSObject.Properties.Name | Where-Object { $_ -notin @('TableName', 'TenantId') }
        $flat  = foreach ($r in $rows) {
            $o = [ordered]@{}
            foreach ($p in $props) { $o[$p] = Flatten-Cell $r.$p }
            [pscustomobject]$o
        }
        $flat | Export-Csv $csv -NoTypeInformation -Encoding utf8
    } else { '' | Set-Content $csv -Encoding utf8 }
}

# ---- -Test expectation evaluation ----------------------------------------
function Test-Expect {
    param([int]$Rows, [string]$Expect, [bool]$Ran)
    if (-not $Ran) { return 'FAIL' }
    switch -Regex ($Expect) {
        '(?i)^rows?$'        { if ($Rows -gt 0) { 'PASS' } else { 'EMPTY' }; break }
        '(?i)^(empty|none)$' { if ($Rows -eq 0) { 'PASS' } else { 'FAIL' }; break }
        '^>=\s*(\d+)$'       { if ($Rows -ge [int]$Matches[1]) { 'PASS' } else { 'FAIL' }; break }
        '^>\s*(\d+)$'        { if ($Rows -gt [int]$Matches[1]) { 'PASS' } else { 'FAIL' }; break }
        '^<\s*(\d+)$'        { if ($Rows -lt [int]$Matches[1]) { 'PASS' } else { 'FAIL' }; break }
        '^==?\s*(\d+)$'      { if ($Rows -eq [int]$Matches[1]) { 'PASS' } else { 'FAIL' }; break }
        default              { if ($Rows -gt 0) { 'PASS' } else { 'EMPTY' } }
    }
}

# ---- discover the queries ------------------------------------------------
$Cfg = Get-LabConfig
$items = @()
if ($PSCmdlet.ParameterSetName -eq 'Inline') {
    $items += [pscustomobject]@{ File = '(inline)'; Text = $Query }
} else {
    if (-not $Path) {
        $def = Join-Path $Here 'queries'
        $Path = if (Test-Path $def) { $def } else { (Get-Location).Path }
    }
    if (Test-Path $Path -PathType Leaf) {
        $files = @(Get-Item $Path)
    } else {
        $files = Get-ChildItem -Path $Path -Filter *.kql -File | Sort-Object Name
    }
    if ($Only) { $files = $files | Where-Object { $_.Name -like $Only } }
    foreach ($f in $files) { $items += [pscustomobject]@{ File = $f.Name; Text = (Get-Content $f.FullName -Raw) } }
}

if ($items.Count -eq 0) { Err "No .kql files found under '$Path'."; exit 2 }

Say ""
Say "  KQL THREAT-HUNTING RUNNER" Yellow
Say "  lab RG '$($Cfg.ResourceGroup)'  workspace '$($Cfg.WorkspaceName)'  queries: $($items.Count)" DarkGray
if ($Export) { New-Item -ItemType Directory -Force -Path $Export | Out-Null; Say "  export -> $Export" DarkGray }
Rule

# ---- list-only -----------------------------------------------------------
if ($List) {
    foreach ($it in $items) {
        $m = Read-QueryMeta -Text $it.Text -FileName $it.File
        $src = if ($Source -ne 'Auto') { $Source } elseif ($m.Source) { $m.Source } else { 'XDR?' }
        "{0,-52} {1,-9} expect:{2}" -f $it.File, $src, $m.Expect | ForEach-Object { Write-Host "  $_" }
    }
    Rule; exit 0
}

# ---- run -----------------------------------------------------------------
$results = @()
$i = 0
foreach ($it in $items) {
    $i++
    $m = Read-QueryMeta -Text $it.Text -FileName $it.File
    $src = if ($Source -ne 'Auto') { $Source } elseif ($m.Source) { $m.Source } else { 'XDR' }
    if ($src -eq 'LA') { $src = 'Sentinel' }

    Write-Host ""
    Say ("[{0}/{1}] {2}" -f $i, $items.Count, $it.File) White
    Say ("        {0}  ·  source: {1}" -f $m.Name, $src) DarkGray

    $rows = @(); $ran = $false; $errMsg = $null
    try {
        if ($src -eq 'Sentinel') { $rows = @(Invoke-SentinelQuery -Kql $it.Text -Cfg $Cfg) }
        else                     { $rows = @(Invoke-XdrQuery      -Kql $it.Text) }
        $ran = $true
        Show-Rows $rows $Max
    } catch {
        $errMsg = $_.Exception.Message
        Err "ERROR: $errMsg"
    }

    if ($Export -and $ran) {
        $base = [IO.Path]::GetFileNameWithoutExtension($it.File)
        try { Export-Result -Rows $rows -Dir $Export -BaseName $base } catch { Warn "export failed: $($_.Exception.Message)" }
    }

    $status = if (-not $ran) { 'ERROR' } elseif ($rows.Count -gt 0) { 'DATA' } else { 'EMPTY' }
    $verdict = if ($Test) { Test-Expect -Rows $rows.Count -Expect $m.Expect -Ran $ran } else { $null }
    $results += [pscustomobject]@{
        File = $it.File; Name = $m.Name; Source = $src; Rows = $rows.Count
        Status = $status; Expect = $m.Expect; Result = $verdict; Error = $errMsg
    }
    if ($ThrottleMs -gt 0 -and $i -lt $items.Count) { Start-Sleep -Milliseconds $ThrottleMs }
}

# ---- summary -------------------------------------------------------------
Write-Host ""
Rule
Say "  SUMMARY" Yellow
$cols = if ($Test) { 'File', 'Source', 'Rows', 'Status', 'Expect', 'Result' } else { 'File', 'Source', 'Rows', 'Status' }
$results | Format-Table $cols -AutoSize | Out-String -Width 200 | Write-Host

$data = @($results | Where-Object Status -eq 'DATA').Count
$empty = @($results | Where-Object Status -eq 'EMPTY').Count
$errs = @($results | Where-Object Status -eq 'ERROR').Count
Say ("  {0} with data · {1} empty · {2} error(s)" -f $data, $empty, $errs) DarkGray
if ($Test) {
    $pass = @($results | Where-Object Result -eq 'PASS').Count
    $fail = @($results | Where-Object Result -eq 'FAIL').Count
    $emp  = @($results | Where-Object Result -eq 'EMPTY').Count
    Say ("  TEST: {0} PASS · {1} EMPTY · {2} FAIL" -f $pass, $emp, $fail) $(if ($fail) { 'Red' } else { 'Green' })
}

if ($Export) {
    $results | Export-Csv (Join-Path $Export 'run-summary.csv') -NoTypeInformation -Encoding utf8
    $md = @("# KQL hunt run - $(Get-Date -Format 'yyyy-MM-dd HH:mm')", "",
            "RG ``$($Cfg.ResourceGroup)`` · workspace ``$($Cfg.WorkspaceName)``", "",
            "| File | Source | Rows | Status |" + $(if ($Test) { ' Expect | Result |' } else { '' }),
            "|------|--------|------|--------|" + $(if ($Test) { '--------|--------|' } else { '' }))
    foreach ($r in $results) {
        $md += "| $($r.File) | $($r.Source) | $($r.Rows) | $($r.Status) |" + $(if ($Test) { " $($r.Expect) | $($r.Result) |" } else { '' })
    }
    $md -join "`n" | Set-Content (Join-Path $Export 'run-summary.md') -Encoding utf8
    Ok "Wrote run-summary.csv / .md + per-query .json/.csv to $Export"
}
Rule

if ($Test -and (@($results | Where-Object Result -eq 'FAIL').Count -gt 0)) { exit 1 }
exit 0
