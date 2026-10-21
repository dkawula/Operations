<#
.SYNOPSIS
    Sets the time zone on all Active Directory computers to Alberta Standard Time.

    Requires the recent Windows TZDB update that introduces the "Alberta Standard Time"
    zone (shipped in a 2026 Windows cumulative). Hosts missing that update will report
    Status=TZNotAvailable and be skipped untouched.

.DESCRIPTION
    Framework-style script that:
      - Enumerates computers from Active Directory (filterable by OU / enabled / stale)
      - Tests connectivity (ping + WinRM) before touching the box
      - Reads current time zone, sets "Mountain Standard Time" if different
      - Writes a timestamped text log + a CSV result report
      - Runs in -WhatIf mode by default — pass -Apply to actually change anything

.PARAMETER TargetTimeZone
    Windows time zone id. Default "Alberta Standard Time" (ships in 2026 Windows cumulative;
    pre-patch hosts should use "Mountain Standard Time" instead).

.PARAMETER SearchBase
    Optional distinguishedName to scope the AD query (e.g. "OU=Workstations,DC=contoso,DC=com").

.PARAMETER IncludeServers
    Include server operating systems. Default = workstations only.

.PARAMETER StaleDays
    Skip computers whose LastLogonTimestamp is older than this many days. Default 90.

.PARAMETER Apply
    Actually change the time zone. Without this switch the script is read-only (dry run).

.PARAMETER MaxParallel
    Throttle for parallel remote work. Default 20.

.EXAMPLE
    .\Set-ADComputerTimeZone.ps1
    Dry run against all enabled, non-stale workstations.

.EXAMPLE
    .\Set-ADComputerTimeZone.ps1 -Apply -SearchBase "OU=Edmonton,DC=dac,DC=local"
    Set Mountain Standard Time on everything under the Edmonton OU.

.NOTES
    Author : Dave Kawula
    Needs  : RSAT ActiveDirectory module, WinRM reachable on targets, admin creds that can PSRemote.
#>

[CmdletBinding()]
param(
    [string]   $TargetTimeZone = 'Alberta Standard Time',
    [string]   $SearchBase,
    [switch]   $IncludeServers,
    [int]      $StaleDays      = 90,
    [switch]   $Apply,
    [int]      $MaxParallel    = 20,
    [string]   $LogRoot        = (Join-Path $PSScriptRoot 'Logs\TimeZone')
)

# ---------------------------------------------------------------------------
#  Logging
# ---------------------------------------------------------------------------
$script:RunStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
if (-not (Test-Path -LiteralPath $LogRoot)) {
    New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null
}
$script:LogFile = Join-Path $LogRoot "Set-ADComputerTimeZone-$RunStamp.log"
$script:CsvFile = Join-Path $LogRoot "Set-ADComputerTimeZone-$RunStamp.csv"

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Message,
        [ValidateSet('INFO','WARN','ERROR','DEBUG','OK')]
        [string] $Level = 'INFO'
    )
    $stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
    $line  = "[$stamp] [$Level] $Message"
    $colour = switch ($Level) {
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
        'OK'    { 'Green' }
        'DEBUG' { 'DarkGray' }
        default { 'Gray' }
    }
    Write-Host $line -ForegroundColor $colour
    try { Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 } catch { }
}

# ---------------------------------------------------------------------------
#  Pre-flight
# ---------------------------------------------------------------------------
Write-Log "========================================================================"
Write-Log "Set-ADComputerTimeZone starting"
Write-Log "  TargetTimeZone  : $TargetTimeZone"
Write-Log "  SearchBase      : $(if ($SearchBase) {$SearchBase} else {'<forest root>'})"
Write-Log "  IncludeServers  : $IncludeServers"
Write-Log "  StaleDays       : $StaleDays"
Write-Log "  Mode            : $(if ($Apply) {'APPLY (will change)'} else {'DRY RUN (read-only)'})"
Write-Log "  Log file        : $script:LogFile"
Write-Log "  CSV report      : $script:CsvFile"
Write-Log "========================================================================"

try {
    Import-Module ActiveDirectory -ErrorAction Stop
} catch {
    Write-Log "ActiveDirectory module not available. Install RSAT: 'Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0'" -Level ERROR
    throw
}

# Confirm the time-zone id exists on this machine (controller side)
$tzExists = $null -ne (Get-TimeZone -ListAvailable | Where-Object Id -eq $TargetTimeZone)
if (-not $tzExists) {
    Write-Log "Time zone id '$TargetTimeZone' not found on this host." -Level ERROR
    Write-Log "This likely means the TZDB cumulative isn't installed here. 'Alberta Standard Time' ships in a 2026 Windows CU." -Level ERROR
    Write-Log "Use 'Get-TimeZone -ListAvailable | ft Id' to list valid ids on this box." -Level ERROR
    throw "Invalid time zone id."
}
Write-Log "Target time zone '$TargetTimeZone' is valid on this host." -Level OK
Write-Log "NOTE: Target machines also need the TZDB update for this id; they will report Status=TZNotAvailable if missing." -Level WARN

# ---------------------------------------------------------------------------
#  Build target list from AD
# ---------------------------------------------------------------------------
Write-Log "Querying Active Directory ..."
$cutoff = (Get-Date).AddDays(-$StaleDays)

$adParams = @{
    Properties  = 'DNSHostName','OperatingSystem','LastLogonTimestamp','Enabled'
    ErrorAction = 'Stop'
}
if ($SearchBase) { $adParams['SearchBase'] = $SearchBase }

$filter = { Enabled -eq $true }
$allComputers = Get-ADComputer -Filter $filter @adParams

if (-not $IncludeServers) {
    $allComputers = $allComputers | Where-Object { $_.OperatingSystem -notlike '*Server*' }
}

$targets = foreach ($comp in $allComputers) {
    $lastLogon = if ($comp.LastLogonTimestamp) {
        [DateTime]::FromFileTime($comp.LastLogonTimestamp)
    } else { $null }

    if ($lastLogon -and $lastLogon -lt $cutoff) { continue }

    [pscustomobject]@{
        Name       = $comp.Name
        DNSHost    = $comp.DNSHostName
        OS         = $comp.OperatingSystem
        LastLogon  = $lastLogon
    }
}

$totalCount = ($targets | Measure-Object).Count
Write-Log "Found $totalCount candidate computer(s) after filtering." -Level OK

if ($totalCount -eq 0) {
    Write-Log "Nothing to do. Exiting." -Level WARN
    return
}

# ---------------------------------------------------------------------------
#  Remote worker scriptblock
# ---------------------------------------------------------------------------
$worker = {
    param($HostName, $TargetTz, $DoApply)

    $result = [ordered]@{
        ComputerName   = $HostName
        Reachable      = $false
        WinRM          = $false
        BeforeTimeZone = $null
        AfterTimeZone  = $null
        Changed        = $false
        Status         = 'Skipped'
        Error          = $null
    }

    try {
        if (-not (Test-Connection -ComputerName $HostName -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
            $result.Status = 'Offline'
            return [pscustomobject]$result
        }
        $result.Reachable = $true

        $wsmanOk = $false
        try { Test-WSMan -ComputerName $HostName -ErrorAction Stop | Out-Null; $wsmanOk = $true } catch { }
        if (-not $wsmanOk) {
            $result.Status = 'NoWinRM'
            return [pscustomobject]$result
        }
        $result.WinRM = $true

        $invokeSplat = @{
            ComputerName = $HostName
            ErrorAction  = 'Stop'
            ArgumentList = @($TargetTz, $DoApply)
            ScriptBlock  = {
                param($tz, $apply)
                $before = (Get-TimeZone).Id

                # Does the TARGET have this zone id? (needs the TZDB patch)
                $hasZone = $null -ne (Get-TimeZone -ListAvailable | Where-Object Id -eq $tz)
                if (-not $hasZone) {
                    [pscustomobject]@{
                        Before     = $before
                        After      = $before
                        Changed    = $false
                        TZPresent  = $false
                    }
                    return
                }

                $changed = $false
                if ($before -ne $tz) {
                    if ($apply) {
                        Set-TimeZone -Id $tz -ErrorAction Stop
                        $changed = $true
                    }
                }
                $after = (Get-TimeZone).Id
                [pscustomobject]@{
                    Before    = $before
                    After     = $after
                    Changed   = $changed
                    TZPresent = $true
                }
            }
        }

        $remote = Invoke-Command @invokeSplat
        $result.BeforeTimeZone = $remote.Before
        $result.AfterTimeZone  = $remote.After
        $result.Changed        = $remote.Changed

        if (-not $remote.TZPresent) {
            $result.Status = 'TZNotAvailable'
            $result.Error  = "Target '$TargetTz' not on this host; install the Windows TZDB cumulative."
        } elseif ($remote.Before -eq $TargetTz) {
            $result.Status = 'AlreadySet'
        } elseif ($remote.Changed) {
            $result.Status = 'Updated'
        } elseif (-not $DoApply) {
            $result.Status = 'WouldChange'
        } else {
            $result.Status = 'NoChange'
        }
    } catch {
        $result.Status = 'Error'
        $result.Error  = $_.Exception.Message
    }

    [pscustomobject]$result
}

# ---------------------------------------------------------------------------
#  Run against targets (parallel on PS 7+, serial on 5.1)
# ---------------------------------------------------------------------------
$results = New-Object System.Collections.Generic.List[object]
$index = 0

if ($PSVersionTable.PSVersion.Major -ge 7) {
    Write-Log "Running in parallel (ThrottleLimit=$MaxParallel) ..." -Level INFO

    # $using: cannot evaluate expressions, so stringify the worker here first.
    $workerText = $worker.ToString()
    $applyFlag  = $Apply.IsPresent

    $results.AddRange(@(
        $targets | ForEach-Object -ThrottleLimit $MaxParallel -Parallel {
            $wk = [ScriptBlock]::Create($using:workerText)
            & $wk $_.DNSHost $using:TargetTimeZone $using:applyFlag
        }
    ))
} else {
    Write-Log "Running serially (PowerShell $(($PSVersionTable.PSVersion).ToString()); use pwsh 7+ for parallel)." -Level WARN
    foreach ($t in $targets) {
        $index++
        Write-Log "[$index/$totalCount] $($t.DNSHost)" -Level DEBUG
        $r = & $worker $t.DNSHost $TargetTimeZone $Apply.IsPresent
        $results.Add($r) | Out-Null
    }
}

# ---------------------------------------------------------------------------
#  Report
# ---------------------------------------------------------------------------
$results | Export-Csv -LiteralPath $script:CsvFile -NoTypeInformation -Encoding UTF8

$grouped = $results | Group-Object Status | Sort-Object Count -Descending
Write-Log "------------------------- Summary -------------------------"
foreach ($g in $grouped) {
    $level = switch ($g.Name) {
        'Updated'        { 'OK' }
        'AlreadySet'     { 'OK' }
        'WouldChange'    { 'INFO' }
        'TZNotAvailable' { 'WARN' }
        'Error'          { 'ERROR' }
        'Offline'        { 'WARN' }
        'NoWinRM'        { 'WARN' }
        default          { 'INFO' }
    }
    Write-Log ("  {0,-12} : {1}" -f $g.Name, $g.Count) -Level $level
}

$errors = $results | Where-Object Status -eq 'Error'
if ($errors) {
    Write-Log "Error detail:" -Level ERROR
    foreach ($e in $errors) { Write-Log "  $($e.ComputerName): $($e.Error)" -Level ERROR }
}

Write-Log "CSV report : $script:CsvFile" -Level OK
Write-Log "Log file   : $script:LogFile" -Level OK
Write-Log "Done."
