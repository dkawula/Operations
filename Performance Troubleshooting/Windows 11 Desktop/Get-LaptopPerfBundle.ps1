<#
.SYNOPSIS
  Laptop Performance Triage Collector (Safe-Run Edition)

.DESCRIPTION
  Collects a comprehensive, support-friendly diagnostics bundle from Windows 10/11 laptops/desktops to
  investigate slow logons, Wi-Fi instability, CPU throttling/thermals, update loops, GPO/script delays,
  scheduled task run-as issues, Defender/MDE posture (including Passive Mode), Attack Surface Reduction (ASR),
  Reliability Monitor events, and (optionally) Diagnostic Data Viewer (DDV) telemetry.
  Outputs a timestamped folder and ZIP with CSV/HTML reports and EVTX exports.

.FEATURES
  • Colored step/status logging (Write-Status) and hardened Safe-Run wrapper with verbose tracing
  • Core HW/OS inventory, drivers, services, startup Run keys
  • Power & battery: powercfg reports (energy, battery), sleep states, optional sleep study
  • Network/WLAN: adapter properties/stats, ipconfig/route, TCP settings, WLAN report (HTML)
  • Disk/FS: TRIM status, basic winSAT disk sample
  • Updates & Defender: merged WindowsUpdate.log, HotFixes, Defender status/preferences, registry checks
    (ForceDefenderPassiveMode/PassiveMode), MDE Sensor (Sense) service state, SecurityCenter2 AV inventory,
    quick verdict (Active vs Passive; MDE onboarded or not)
  • ASR: effective rules via Get-MpPreference and policy/local registry, exclusions, action mapping (Block/Audit/Warn)
  • Group Policy & Logon: gpresult HTML, Diagnostics-Performance log (boot/logon/shutdown), key EVTX exports
  • Scheduled Tasks: full detail (triggers/actions), Run-As user, non-SYSTEM filters, gMSA detection
  • Reliability Monitor: Win32_ReliabilityRecords + Stability Index to CSV/HTML
  • (Optional) DDV: installs/imports module, enables viewing, exports data types and recent diagnostic events

.PARAMETER SinceDays
  Number of days to include for time-filtered CSV extracts (default: 7).

.PARAMETER IncludeETL
  When present, copies available WLAN/Windows Update ETL files if found (no live trace sessions started).

.OUTPUTS
  A folder named “LaptopPerfBundle_yyyyMMdd_HHmmss” plus a ZIP. Subfolders include:
  00_Metadata, 00_QuickLooks, 01_Core, 02_Power, 03_Network_WLAN, 04_Disk_FS, 05_Updates_Defender,
  06_GroupPolicy_Logon, 07_EventLogs, 08_Apps, 09_CPU_Thermal, 10_DiagnosticDataViewer, 11_Reliability.

.REQUIREMENTS
  • Windows PowerShell 5.1 (tested) or PowerShell 7+
  • Windows 10/11
  • Elevated PowerShell recommended for complete data collection
  • Internet access only if installing the Diagnostic Data Viewer module (optional)

.LIMITATIONS
  • Certain logs/channels/features may not exist on all SKUs/builds; these steps warn and continue.
  • Reliability/Diagnostic Data Viewer may be empty until features are enabled and data accumulates.

.AUTHOR
  Dave Kawula, MVP (Microsoft Most Valuable Professional)
 @Davekawula
  Notes: Community contributor, author, and enterprise consultant specializing in Windows, Azure, security, and operations.

.VERSION
  1.0.0

.LASTUPDATED
  2025-08-26

.COPYRIGHT
  (c) Licensed for internal troubleshooting use. No warranty; use at your own risk.

.NOTES
  • Designed for desktop engineering teams and suitable for Intune/RMM “Collect Logs” actions.
  • All checks are read-only. No system settings are changed.

.EXAMPLE
  PS> .\Get-LaptopPerfBundle.ps1 -Verbose
  PS> .\Get-LaptopPerfBundle.ps1 -SinceDays 3 -IncludeETL -Verbose
#>

[CmdletBinding()]
param(
  [int]$SinceDays = 7,
  [switch]$IncludeETL
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

# ========== Status/Helpers ==========

function Write-Status {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][ValidateSet('OK','WARN','ERROR','INFO','STEP')]
    [string]$Level,
    [Parameter(Mandatory)][string]$Message
  )
  $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
  $fc = switch ($Level) {
    'OK'    { 'Green' }
    'WARN'  { 'Yellow' }
    'ERROR' { 'Red' }
    'INFO'  { 'Cyan' }
    'STEP'  { 'White' }
  }
  Write-Host "[$ts] [$Level] $Message" -ForegroundColor $fc
}

function Ensure-Admin {
  [CmdletBinding()]
  param()
  Write-Verbose "Checking for administrative token..."
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p  = New-Object Security.Principal.WindowsPrincipal($id)
  if ($p.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Status -Level OK -Message "Running with administrative privileges."
    $true
  } else {
    Write-Status -Level WARN -Message "Not running as Administrator. Some collectors may be incomplete."
    $false
  }
}

<#>function Safe-Run {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position=0)]
    [object]$Script,                 # { scriptblock } or "string command"

    [string]$Name = "Unnamed step",  # For status lines
    [switch]$FatalOnError,           # Stop script on error
    [switch]$WarnOnly                # Demote errors to WARN (yellow)
  )
  Write-Status -Level STEP -Message "▶ $Name"
  Write-Verbose "Starting: $Name"

  try {
    if ($Script -is [scriptblock]) {
      & $Script
    }
    elseif ($Script -is [string]) {
      $null = Invoke-Expression $Script
      if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) {
        throw "Command exited with code $LASTEXITCODE"
      }
    }
    else {
      throw "Unsupported input type: $($Script.GetType().FullName)"
    }
    Write-Status -Level OK -Message "$Name — completed successfully."
    Write-Verbose "Finished: $Name"
  }
  catch {
    $msg = "$Name — failed: $($_.Exception.Message)"
    if ($WarnOnly) { Write-Status -Level WARN -Message $msg }
    else { Write-Status -Level ERROR -Message $msg }
    if ($FatalOnError) { throw }
  }
}
</#>


function Safe-Run {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position=0)]
    [object]$Script,
    [string]$Name = "Unnamed step",
    [switch]$FatalOnError,
    [switch]$WarnOnly
  )

  Write-Status -Level STEP -Message "▶ $Name"
  Write-Verbose "Starting: $Name"

  $oldEAP = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Stop'

    if ($Script -is [scriptblock]) {
      & $Script
    } elseif ($Script -is [string]) {
      $null = Invoke-Expression $Script
      if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) {
        throw "Command exited with code $LASTEXITCODE"
      }
    } else {
      throw "Unsupported input type: $($Script.GetType().FullName)"
    }

    Write-Status -Level OK -Message "$Name — completed successfully."
    Write-Verbose "Finished: $Name"
  }
  catch {
    $msg = "$Name — failed: $($_.Exception.Message)"
    if ($WarnOnly) { Write-Status -Level WARN -Message $msg } else { Write-Status -Level ERROR -Message $msg }
    if ($FatalOnError) { throw }
  }
  finally {
    $ErrorActionPreference = $oldEAP
  }
}

function Save-Text {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Content
  )
  $dir = Split-Path -Path $Path -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $Content | Out-File -FilePath $Path -Encoding UTF8 -Force
}

function Capture-Cmd {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Command,
    [string]$Args = "",
    [Parameter(Mandatory)][string]$OutPath,
    [string]$Name
  )
  $stepName = if ($Name) { $Name } else { "$Command $Args" }
  $dir = Split-Path -Path $OutPath -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

  Safe-Run -Name $stepName -Script {
    & $Command $Args 2>&1 | Out-File -FilePath $OutPath -Encoding UTF8
    if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) {
      throw "Exit code $LASTEXITCODE"
    }
  }
}

# ========== Setup ==========

$IsAdmin = Ensure-Admin
$stamp   = (Get-Date).ToString('yyyyMMdd_HHmmss')
$root    = Join-Path -Path (Get-Location) -ChildPath "LaptopPerfBundle_$stamp"
$null    = New-Item -ItemType Directory -Path $root -Force

$metaDir = Join-Path $root '00_Metadata'
$quick   = Join-Path $root '00_QuickLooks'
$core    = Join-Path $root '01_Core'
$power   = Join-Path $root '02_Power'
$net     = Join-Path $root '03_Network_WLAN'
$disk    = Join-Path $root '04_Disk_FS'
$sec     = Join-Path $root '05_Updates_Defender'
$gp      = Join-Path $root '06_GroupPolicy_Logon'
$evt     = Join-Path $root '07_EventLogs'
$app     = Join-Path $root '08_Apps'
$cpu     = Join-Path $root '09_CPU_Thermal'
$etlDir  = Join-Path $root '10_ETL'

foreach ($d in @($metaDir,$quick,$core,$power,$net,$disk,$sec,$gp,$evt,$app,$cpu)) {
  if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

$since = (Get-Date).AddDays(-[math]::Abs($SinceDays))

Save-Text -Path (Join-Path $metaDir 'bundle_metadata.txt') -Content @"
CollectedAtUtc:  $(Get-Date).ToUniversalTime().ToString('o')
CollectedBy:     $env:USERNAME
ComputerName:    $env:COMPUTERNAME
SinceDays:       $SinceDays
IncludeETL:      $IncludeETL
IsAdmin:         $IsAdmin
"@

# ========== 01 Core ==========

Safe-Run -Name "Export Get-ComputerInfo" -Script {
  Get-ComputerInfo | Export-Clixml -Path (Join-Path $core 'Get-ComputerInfo.clixml')
}

Safe-Run -Name "Export hardware/OS (CIM)" -Script ({
    $out = Join-Path $core 'Hardware_OS'
    if (-not (Test-Path $out)) { New-Item -ItemType Directory -Path $out -Force | Out-Null }

    Get-CimInstance -ClassName Win32_ComputerSystem  -ErrorAction Continue |
        Export-Csv -NoTypeInformation -Path (Join-Path $out 'Win32_ComputerSystem.csv')

    Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Continue |
        Export-Csv -NoTypeInformation -Path (Join-Path $out 'Win32_OperatingSystem.csv')

    Get-CimInstance -ClassName Win32_BIOS -ErrorAction Continue |
        Export-Csv -NoTypeInformation -Path (Join-Path $out 'Win32_BIOS.csv')

    Get-CimInstance -ClassName Win32_Processor -ErrorAction Continue |
        Export-Csv -NoTypeInformation -Path (Join-Path $out 'Win32_Processor.csv')

    Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction Continue |
        Export-Csv -NoTypeInformation -Path (Join-Path $out 'Win32_PhysicalMemory.csv')
})


Capture-Cmd -Name "systeminfo" -Command 'systeminfo.exe' -OutPath (Join-Path $core 'systeminfo.txt')
#WMIC is deprecated
#Capture-Cmd -Name "WMIC driver list" -Command 'wmic.exe' -Args 'path Win32_PnPSignedDriver get DeviceName,DriverVersion,DriverProviderName,DriverDate /format:list' -OutPath (Join-Path $core 'drivers_wmic.txt')
Capture-Cmd -Name "driverquery /v" -Command 'driverquery.exe' -Args '/v /fo csv' -OutPath (Join-Path $core 'driverquery.csv')

Safe-Run -Name "Top processes by CPU (sampled % over 1.5s)" -Script ({
  $cores    = [Environment]::ProcessorCount
  $t1       = Get-Date
  $s1       = Get-Process | Select-Object Id, ProcessName, CPU
  Start-Sleep -Milliseconds 1500
  $t2       = Get-Date
  $interval = ($t2 - $t1).TotalSeconds
  $s2       = Get-Process | Select-Object Id, ProcessName, CPU

  # Join on Id and compute delta CPU seconds -> % utilization
  $byId = @{}
  foreach ($p in $s1) { $byId[$p.Id] = $p }

  $rows = foreach ($p2 in $s2) {
    $p1 = $byId[$p2.Id]
    if ($null -ne $p1 -and $null -ne $p1.CPU -and $null -ne $p2.CPU -and $interval -gt 0) {
      $deltaCpuSec = [double]$p2.CPU - [double]$p1.CPU
      $cpuPct      = if ($cores -gt 0) { 100.0 * ($deltaCpuSec / ($interval * $cores)) } else { 0 }
      [pscustomobject]@{
        PID         = $p2.Id
        ProcessName = $p2.ProcessName
        CpuPercent  = [math]::Round([math]::Max($cpuPct,0), 1)
        CpuSeconds  = [math]::Round([math]::Max($deltaCpuSec,0), 2)
      }
    }
  }

  $rows |
    Sort-Object CpuPercent -Descending |
    Select-Object -First 200 |
    Export-Csv -NoTypeInformation -Path (Join-Path $core 'TopProcesses_ByCPU.csv')
})

Safe-Run -Name "Top processes by Memory (Working Set)" -Script ({
  Get-Process |
    Select-Object Id, ProcessName, WS, PM, NPM, CPU -ErrorAction Continue |
    Sort-Object WS -Descending |
    Select-Object -First 200 |
    Export-Csv -NoTypeInformation -Path (Join-Path $core 'TopProcesses_ByMemory.csv')
})

Safe-Run -Name "Services inventory" -Script {
  Get-Service | Sort-Object Status,StartType,DisplayName |
    Export-Csv -Path (Join-Path $core 'Services.csv') -NoTypeInformation
}
Safe-Run -Name "Scheduled tasks inventory" -Script {
  Get-ScheduledTask | Select-Object TaskName,TaskPath,State,LastRunTime,NextRunTime |
    Export-Csv -Path (Join-Path $core 'ScheduledTasks.csv') -NoTypeInformation
}

Safe-Run -Name "Scheduled tasks inventory (with Run-As details)" -Script ({
  $all  = Get-ScheduledTask
  $rows = foreach ($t in $all) {
    # Try to get runtime info (can fail on protected tasks)
    $info = $null
    try { $info = Get-ScheduledTaskInfo -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction Stop } catch { }

    # ---- Triggers (readable) ----
    $trigs = ''
    if ($t.Triggers) {
      $trigs = ($t.Triggers | ForEach-Object {
        $typ = $null
        try { if ($_.PSObject.Properties.Match('CimClass').Count -and $_.CimClass) { $typ = $_.CimClass.CimClassName } } catch { }
        if (-not $typ) { $typ = $_.GetType().Name }

        $start = $null
        if ($_.PSObject.Properties.Match('StartBoundary').Count) { $start = $_.StartBoundary }

        $rep = $null
        if ($_.PSObject.Properties.Match('Repetition').Count -and $_.Repetition) {
          if ($_.Repetition.PSObject.Properties.Match('Interval').Count) { $rep = $_.Repetition.Interval }
        }

        $s = $typ
        if ($start) { $s = $s + " @ $start" }
        if ($rep)   { $s = $s + " every $rep" }
        $s
      }) -join '; '
    }

    # ---- Actions (handle types safely) ----
    $acts = ''
    if ($t.Actions) {
      $acts = ($t.Actions | ForEach-Object {
        $atype = $null
        try { if ($_.PSObject.Properties.Match('CimClass').Count -and $_.CimClass) { $atype = $_.CimClass.CimClassName } } catch { }
        if (-not $atype) { $atype = $_.GetType().Name }

        if ($atype -eq 'MSFT_TaskExecAction') {
          $exe = $null; $arg = $null
          if ($_.PSObject.Properties.Match('Execute').Count) { $exe = $_.Execute }
          if (-not $exe -and $_.PSObject.Properties.Match('Path').Count) { $exe = $_.Path }
          if ($_.PSObject.Properties.Match('Arguments').Count) { $arg = $_.Arguments }

          $s = ($atype + ': ')
          if ($exe) { $s = $s + $exe } else { $s = $s + '<cmd?>' }
          if ($arg) { $s = $s + ' ' + $arg }
          $s
        }
        elseif ($atype -eq 'MSFT_TaskComHandlerAction') {
          $cls = $null; $dat = $null
          if ($_.PSObject.Properties.Match('ClassId').Count) { $cls = $_.ClassId }
          if ($_.PSObject.Properties.Match('Data').Count)    { $dat = $_.Data }
          $s = ($atype + ': ')
          if ($cls) { $s = $s + $cls }
          if ($dat) { $s = $s + ' ' + $dat }
          $s
        }
        else {
          # Fallback: compact stringify
          (($atype + ': ') + ((($_ | Out-String) -replace '\s+', ' ').Trim()))
        }
      }) -join '; '
    }

    [pscustomobject]@{
      TaskName       = $t.TaskName
      TaskPath       = $t.TaskPath
      State          = $t.State
      Enabled        = $t.Settings.Enabled
      RunLevel       = $t.Principal.RunLevel
      LogonType      = $t.Principal.LogonType
      RunAsUser      = $t.Principal.UserId
      LastRunTime    = if ($info) { $info.LastRunTime }    else { $null }
      NextRunTime    = if ($info) { $info.NextRunTime }    else { $null }
      LastTaskResult = if ($info) { $info.LastTaskResult } else { $null }
      Triggers       = $trigs
      Actions        = $acts
    }
  }

  $outAll = Join-Path $core 'ScheduledTasks_Detail.csv'
  $rows | Sort-Object TaskPath,TaskName | Export-Csv -NoTypeInformation -Path $outAll

  # Built-in service accounts to exclude when surfacing named/gMSA
  $builtin = @(
    '^NT AUTHORITY\\SYSTEM$','^NT AUTHORITY\\LOCAL SERVICE$','^NT AUTHORITY\\NETWORK SERVICE$',
    '^SYSTEM$','^LOCAL SERVICE$','^NETWORK SERVICE$'
  )

  $nonSystem = $rows | Where-Object {
    $u = $_.RunAsUser
    $u -and -not ($builtin | ForEach-Object { $u -match $_ })
  }
  $outNonSys = Join-Path $core 'ScheduledTasks_RunAs_NonSystem.csv'
  $nonSystem | Sort-Object TaskPath,TaskName | Export-Csv -NoTypeInformation -Path $outNonSys

  # gMSA heuristic: account ends with '$'
  $gmsa = $rows | Where-Object { $_.RunAsUser -match '\$+$' }
  $outGmsa = Join-Path $core 'ScheduledTasks_gMSA.csv'
  $gmsa | Sort-Object TaskPath,TaskName | Export-Csv -NoTypeInformation -Path $outGmsa
})

# Startup Run keys (local-safe, no $using:)
$startupDir = Join-Path $core 'Startup'
if (-not (Test-Path $startupDir)) { New-Item -ItemType Directory -Path $startupDir -Force | Out-Null }

$runKeys = @(
  'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
  'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
  'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
  'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
)

foreach ($rk in $runKeys) {
  $rkLocal = $rk
  $dest    = Join-Path $startupDir ( ($rkLocal -replace '[:\\]','_') + '.txt' )

  Safe-Run -Name ("Startup key: " + $rkLocal) -WarnOnly -Script ({
    if (Test-Path -LiteralPath $rkLocal) {
      Get-ItemProperty -LiteralPath $rkLocal |
        Out-File -FilePath $dest -Encoding UTF8
    } else {
      Write-Verbose ("Registry path not found: {0}" -f $rkLocal)
    }
  })
}

# ========== 02 Power / Battery / Sleep ==========

# Write HTMLs to the Power folder
$energyHtml  = Join-Path $power 'energy-report.html'
$batteryHtml = Join-Path $power 'battery-report.html'

# Schemes / current plan / reports (direct invocation; no Capture-Cmd)
Safe-Run -Name "powercfg /LIST (schemes)" -Script ({
  powercfg /LIST 2>&1 | Out-File -FilePath (Join-Path $power 'powercfg_list.txt') -Encoding UTF8
})

Safe-Run -Name "powercfg /QUERY (current plan)" -Script ({
  powercfg /QUERY 2>&1 | Out-File -FilePath (Join-Path $power 'powercfg_query.txt') -Encoding UTF8
})


#Checking tick length: Via Sami Laiho
#It takes down the tick length. Tick is normally 15,6ms but apps can take it down to 1ms (even 0.5ms but I've never seen it). This makes your computers clock tick 15 times faster so it consumes more energy as it can't rest.
#you can find the apps that do this with Powercfg /energy /duration 5

Safe-Run -Name "powercfg /ENERGY (60s)" -Script ({
  powercfg /ENERGY /OUTPUT "$energyHtml" /DURATION 60 2>&1 |
    Out-File -FilePath (Join-Path $power 'powercfg_energy_cmd.txt') -Encoding UTF8
})

Safe-Run -Name "powercfg /BATTERYREPORT" -Script ({
  powercfg /BATTERYREPORT /OUTPUT "$batteryHtml" 2>&1 |
    Out-File -FilePath (Join-Path $power 'powercfg_battery_cmd.txt') -Encoding UTF8
})


Safe-Run -Name "powercfg /a (sleep states)" -Script {
  powercfg /a | Out-File -FilePath (Join-Path $power 'powercfg_sleepstates.txt') -Encoding UTF8
}
Safe-Run -Name "powercfg /sleepstudy" -WarnOnly -Script {
  powercfg /sleepstudy /output sleepstudy-report.html 2>&1 |
    Out-File -FilePath (Join-Path $power 'powercfg_sleepstudy_command_output.txt') -Encoding UTF8
  if (Test-Path 'sleepstudy-report.html') { Move-Item -Path 'sleepstudy-report.html' -Destination (Join-Path $power 'sleepstudy-report.html') -Force }
}






# ========== 03 Network / WLAN ==========

Safe-Run -Name "ipconfig /all" -Script ({
  ipconfig /all 2>&1 | Out-File -FilePath (Join-Path $net 'ipconfig_all.txt') -Encoding UTF8
})

Safe-Run -Name "route print" -Script ({
  route print 2>&1 | Out-File -FilePath (Join-Path $net 'route_print.txt') -Encoding UTF8
})

Safe-Run -Name "netsh int tcp show global" -Script ({
  netsh int tcp show global 2>&1 | Out-File -FilePath (Join-Path $net 'tcp_global.txt') -Encoding UTF8
})

Safe-Run -Name "netsh wlan show interfaces" -Script ({
  netsh wlan show interfaces 2>&1 | Out-File -FilePath (Join-Path $net 'wlan_interfaces.txt') -Encoding UTF8
})

Safe-Run -Name "netsh wlan show drivers" -Script ({
  netsh wlan show drivers 2>&1 | Out-File -FilePath (Join-Path $net 'wlan_drivers.txt') -Encoding UTF8
})

# Build the WLAN report first
Safe-Run -Name "netsh wlan show wlanreport" -Script ({
  netsh wlan show wlanreport 2>&1 |
    Out-File -FilePath (Join-Path $net 'wlan_wlanreport_command_output.txt') -Encoding UTF8
})

# Prepare absolute paths (outside the scriptblock)
$wlanSrc = Join-Path $env:ProgramData 'Microsoft\windows\WlanReport\wlan-report-latest.html'
$wlanDst = Join-Path $net 'wlan-report-latest.html'

# Copy with checks (PS 5.1-safe)
Safe-Run -Name "Copy wlan-report-latest.html to bundle" -Script ({
  if (Test-Path -LiteralPath $wlanSrc) {
    Copy-Item -LiteralPath $wlanSrc -Destination $wlanDst -Force -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $wlanDst)) {
      throw "Copy reported success but file not found at '$wlanDst'"
    }
  } else {
    throw "Source report not found at '$wlanSrc' (did 'netsh wlan show wlanreport' run first?)"
  }
})

Safe-Run -Name "Net adapters" -Script {
  Get-NetAdapter | Select-Object Name,InterfaceDescription,Status,LinkSpeed,DriverInformation |
    Export-Csv -NoTypeInformation -Path (Join-Path $net 'NetAdapters.csv')
}
Safe-Run -Name "Net adapter advanced properties" -Script {
  Get-NetAdapterAdvancedProperty | Sort-Object Name,DisplayName |
    Export-Csv -NoTypeInformation -Path (Join-Path $net 'NetAdapterAdvancedProps.csv')
}
Safe-Run -Name "Net adapter statistics" -Script {
  Get-NetAdapterStatistics | Export-Csv -NoTypeInformation -Path (Join-Path $net 'NetAdapterStatistics.csv')
}
Safe-Run -Name "DNS client server addresses" -Script {
  Get-DnsClientServerAddress | Export-Csv -NoTypeInformation -Path (Join-Path $net 'DNS_ServerAddresses.csv')
}
Safe-Run -Name "NetIPConfiguration" -Script {
  Get-NetIPConfiguration | Export-Clixml -Path (Join-Path $net 'NetIPConfiguration.clixml')
}

# ========== 04 Disk / File System ==========

Safe-Run -Name "PhysicalDisk inventory" -Script {
  Get-PhysicalDisk | Select-Object FriendlyName,MediaType,Size,HealthStatus,BusType |
    Export-Csv -NoTypeInformation -Path (Join-Path $disk 'PhysicalDisk.csv')
}
Safe-Run -Name "Get-Disk inventory" -Script {
  Get-Disk | Select-Object Number,FriendlyName,SerialNumber,BusType,PartitionStyle,OperationalStatus,HealthStatus,IsBoot,IsSystem |
    Export-Csv -NoTypeInformation -Path (Join-Path $disk 'Get-Disk.csv')
}
Safe-Run -Name "Get-Volume inventory" -Script {
  Get-Volume | Select-Object DriveLetter,FileSystem,HealthStatus,Size,SizeRemaining,AllocationUnitSize |
    Export-Csv -NoTypeInformation -Path (Join-Path $disk 'Get-Volume.csv')
}

Safe-Run -Name "TRIM status" -Script ({
  fsutil behavior query DisableDeleteNotify 2>&1 |
    Out-File -FilePath (Join-Path $disk 'TRIM_status.txt') -Encoding UTF8
})

Safe-Run -Name "winsat disk (C:)" -WarnOnly -Script ({
  winsat disk -drive C 2>&1 |
    Out-File -FilePath (Join-Path $disk 'winsat_disk_C.txt') -Encoding UTF8
})


# ========== 05 Updates / Defender ==========

# --- Windows Update artifacts ---
Safe-Run -Name "Generate WindowsUpdate.log" -Script ({
  $out = Join-Path $sec 'WindowsUpdate.log'
  Get-WindowsUpdateLog -LogPath $out | Out-Null
})

Safe-Run -Name "HotFix history" -Script ({
  Get-HotFix | Sort-Object InstalledOn -Descending |
    Export-Csv -NoTypeInformation -Path (Join-Path $sec 'HotFixes.csv')
})

# --- Core Defender/MDE services ---
Safe-Run -Name "Defender core services (WinDefend, WdNisSvc, Sense)" -Script ({
  $svcNames = @('WinDefend','WdNisSvc','Sense')
  $rows = foreach ($n in $svcNames) {
    $svc = Get-Service -Name $n -ErrorAction SilentlyContinue
    $cim = Get-CimInstance -ClassName Win32_Service -Filter ("Name='{0}'" -f $n) -ErrorAction SilentlyContinue
    [pscustomobject]@{
      Name        = $n
      DisplayName = if ($svc) { $svc.DisplayName } else { $null }
      Status      = if ($svc) { $svc.Status } else { 'NotInstalled' }
      StartMode   = if ($cim) { $cim.StartMode } else { $null }
      State       = if ($cim) { $cim.State } else { $null }
      PathName    = if ($cim) { $cim.PathName } else { $null }
    }
  }
  $rows | Export-Csv -NoTypeInformation -Path (Join-Path $sec 'Defender_Services.csv')
})

# --- Defender status + quick view (shows Passive/Normal, RTP, etc.) ---
Safe-Run -Name "Defender status (Get-MpComputerStatus)" -WarnOnly -Script ({
  $statusPath = Join-Path $sec 'DefenderStatus.clixml'
  $quickPath  = Join-Path $sec 'DefenderStatus_Quick.txt'
  if (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue) {
    $s = $null
    try { $s = Get-MpComputerStatus -ErrorAction Stop } catch { }
    if ($s) {
      $s | Export-Clixml -Path $statusPath
      $lines = @(
        "AMRunningMode: $($s.AMRunningMode)"                    # 'Normal' or 'Passive Mode'
        "RealTimeProtectionEnabled: $($s.RealTimeProtectionEnabled)"
        "NISEnabled: $($s.NISEnabled)"
        "IsTamperProtected: $($s.IsTamperProtected)"
        "EngineVersion: $($s.AMEngineVersion)"
        "AntivirusSignatureVersion: $($s.AntivirusSignatureVersion)"
        "AntivirusSignatureLastUpdated: $($s.AntivirusSignatureLastUpdated)"
      )
      $lines | Out-File -FilePath $quickPath -Encoding UTF8
    } else {
      "Get-MpComputerStatus failed or not available." | Out-File -FilePath $quickPath -Encoding UTF8
    }
  } else {
    "Get-MpComputerStatus not available on this system." | Out-File -FilePath $quickPath -Encoding UTF8
  }
})

# --- Defender preferences (useful context) ---
Safe-Run -Name "Defender preferences (Get-MpPreference)" -WarnOnly -Script ({
  if (Get-Command Get-MpPreference -ErrorAction SilentlyContinue) {
    $pref = Get-MpPreference -ErrorAction SilentlyContinue
    if ($pref) {
      $pref | Export-Clixml -Path (Join-Path $sec 'DefenderPreferences.clixml')
      $pref | ConvertTo-Json -Depth 5 | Out-File -FilePath (Join-Path $sec 'DefenderPreferences.json') -Encoding UTF8
    }
  }
})

# --- Registry: Passive mode & policy toggles ---
Safe-Run -Name "Registry: Defender passive mode & policies" -Script ({
  $out = Join-Path $sec 'Defender_Registry.txt'
  $sb  = New-Object System.Text.StringBuilder
  $paths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows Defender',
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'
  )
  foreach ($p in $paths) {
    try {
      $vals = Get-ItemProperty -LiteralPath $p -ErrorAction Stop
      $null = $sb.AppendLine("[$p]")
      foreach ($prop in $vals.PSObject.Properties) {
        if ($prop.Name -notmatch '^PS(.*)$') {
          $null = $sb.AppendLine(("  {0} = {1}" -f $prop.Name, $prop.Value))
        }
      }
      $null = $sb.AppendLine("")
    } catch {
      $null = $sb.AppendLine("[$p] <not found>`r`n")
    }
  }
  $sb.ToString() | Out-File -FilePath $out -Encoding UTF8
})

# --- Registry: MDE (ATP/EDR) sensor status keys ---
Safe-Run -Name "Registry: MDE (ATP/EDR) status" -Script ({
  $out = Join-Path $sec 'MDE_Registry.txt'
  $sb  = New-Object System.Text.StringBuilder
  $paths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows Advanced Threat Protection',
    'HKLM:\SOFTWARE\Microsoft\Windows Advanced Threat Protection\Status'
  )
  foreach ($p in $paths) {
    try {
      $vals = Get-ItemProperty -LiteralPath $p -ErrorAction Stop
      $null = $sb.AppendLine("[$p]")
      foreach ($prop in $vals.PSObject.Properties) {
        if ($prop.Name -notmatch '^PS(.*)$') {
          $null = $sb.AppendLine(("  {0} = {1}" -f $prop.Name, $prop.Value))
        }
      }
      $null = $sb.AppendLine("")
    } catch {
      $null = $sb.AppendLine("[$p] <not found>`r`n")
    }
  }
  $sb.ToString() | Out-File -FilePath $out -Encoding UTF8
})

# --- SecurityCenter2: list registered AV (helps spot CrowdStrike, etc.) ---
Safe-Run -Name "SecurityCenter2: installed AV products" -WarnOnly -Script ({
  $csv = Join-Path $sec 'SecurityCenter2_AntiVirusProducts.csv'
  try {
    Get-CimInstance -Namespace "root/SecurityCenter2" -ClassName AntiVirusProduct -ErrorAction Stop |
      Select-Object displayName, pathToSignedProductExe, pathToSignedReportingExe, productState |
      Export-Csv -NoTypeInformation -Path $csv
  } catch {
    "SecurityCenter2 namespace not available (non-client OS or WMI restricted)." |
      Out-File -FilePath (Join-Path $sec 'SecurityCenter2_AntiVirusProducts.txt') -Encoding UTF8
  }
})

# --- Quick verdict (Active vs Passive, MDE sensor present) ---

# --- Defender threat history (optional) ---
Safe-Run -Name "Defender threat history" -WarnOnly -Script ({
  if (Get-Command Get-MpThreat -ErrorAction SilentlyContinue) {
    Get-MpThreat | Export-Csv -NoTypeInformation -Path (Join-Path $sec 'DefenderThreats.csv')
  }
})

# --- ASR: create output folder ---
$asrOut = Join-Path $sec 'ASR'
if (-not (Test-Path $asrOut)) { New-Item -ItemType Directory -Path $asrOut -Force | Out-Null }

# --- ASR (effective via Get-MpPreference) ---
Safe-Run -Name "ASR rules (Get-MpPreference)" -WarnOnly -Script ({
  # Local helper for action names
  function Convert-AsrAction([object]$c) {
    switch ([string]$c) { '0' {'Disabled'} '1' {'Block'} '2' {'Audit'} '6' {'Warn'} default { "Unknown($c)" } }
  }

  $pref = $null
  try { $pref = Get-MpPreference -ErrorAction Stop } catch { }

  $rows = @()
  if ($pref -and $pref.AttackSurfaceReductionRules_Ids -and $pref.AttackSurfaceReductionRules_Actions) {
    $ids  = @($pref.AttackSurfaceReductionRules_Ids)
    $acts = @($pref.AttackSurfaceReductionRules_Actions)
    $n    = [Math]::Min($ids.Count, $acts.Count)

    for ($i=0; $i -lt $n; $i++) {
      $id  = $ids[$i]
      $act = $acts[$i]
      $rows += [pscustomobject]@{
        Source      = 'Get-MpPreference'
        RuleId      = ($id -as [string]).ToUpper()
        ActionCode  = [string]$act
        Action      = Convert-AsrAction $act
      }
    }
  }

  # Exclusions (if present)
  $exFile = Join-Path $asrOut 'ASR_Exclusions.txt'
  if ($pref -and $pref.AttackSurfaceReductionOnlyExclusions) {
    @($pref.AttackSurfaceReductionOnlyExclusions) | Sort-Object |
      Out-File -FilePath $exFile -Encoding UTF8
  } else {
    "No ASR-only exclusions found." | Out-File -FilePath $exFile -Encoding UTF8
  }

  $rows | Sort-Object RuleId | Export-Csv -NoTypeInformation -Path (Join-Path $asrOut 'ASR_From_MpPreference.csv')

  # Quick counts
  $summary = $rows | Group-Object Action | Select-Object Name,Count
  $quick   = @("ASR (Get-MpPreference) summary:")
  foreach ($s in $summary) { $quick += ("  {0}: {1}" -f $s.Name, $s.Count) }
  $quick | Out-File -FilePath (Join-Path $asrOut 'ASR_Quick.txt') -Encoding UTF8
})

# --- ASR (Policy Registry) ---
Safe-Run -Name "ASR rules (Policy registry)" -Script ({
  function Convert-AsrAction([object]$c) {
    switch ([string]$c) { '0' {'Disabled'} '1' {'Block'} '2' {'Audit'} '6' {'Warn'} default { "Unknown($c)" } }
  }

  $key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\ASR\Rules'
  $rows = @()

  if (Test-Path -LiteralPath $key) {
    $vals = Get-ItemProperty -LiteralPath $key
    foreach ($p in $vals.PSObject.Properties) {
      if ($p.Name -match '^[0-9a-fA-F\-]{36}$') {
        $id  = ($p.Name -as [string]).ToUpper()
        $act = [string]$p.Value
        $rows += [pscustomobject]@{
          Source     = 'PolicyRegistry'
          RuleId     = $id
          ActionCode = $act
          Action     = Convert-AsrAction $act
        }
      }
    }
  }

  if ($rows.Count -eq 0) {
    "No Policy ASR rules found at $key" | Out-File -FilePath (Join-Path $asrOut 'ASR_From_PolicyRegistry.txt') -Encoding UTF8
  } else {
    $rows | Sort-Object RuleId | Export-Csv -NoTypeInformation -Path (Join-Path $asrOut 'ASR_From_PolicyRegistry.csv')
  }
})

# --- ASR (Local/Non-policy Registry) ---
Safe-Run -Name "ASR rules (Local registry)" -WarnOnly -Script ({
  function Convert-AsrAction([object]$c) {
    switch ([string]$c) { '0' {'Disabled'} '1' {'Block'} '2' {'Audit'} '6' {'Warn'} default { "Unknown($c)" } }
  }

  $key = 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Windows Defender Exploit Guard\ASR\Rules'
  $rows = @()

  if (Test-Path -LiteralPath $key) {
    $vals = Get-ItemProperty -LiteralPath $key
    foreach ($p in $vals.PSObject.Properties) {
      if ($p.Name -match '^[0-9a-fA-F\-]{36}$') {
        $id  = ($p.Name -as [string]).ToUpper()
        $act = [string]$p.Value
        $rows += [pscustomobject]@{
          Source     = 'LocalRegistry'
          RuleId     = $id
          ActionCode = $act
          Action     = Convert-AsrAction $act
        }
      }
    }
  }

  if ($rows.Count -eq 0) {
    "No Local ASR rules found at $key" | Out-File -FilePath (Join-Path $asrOut 'ASR_From_LocalRegistry.txt') -Encoding UTF8
  } else {
    $rows | Sort-Object RuleId | Export-Csv -NoTypeInformation -Path (Join-Path $asrOut 'ASR_From_LocalRegistry.csv')
  }
})



# ========== 06 Group Policy / Logon Context ==========

Safe-Run -Name "gpresult RSOP (HTML)" -WarnOnly -Script {
  gpresult /h (Join-Path $gp 'gpresult_user_machine.html') 2>&1 |
    Out-File -FilePath (Join-Path $gp 'gpresult_command_output.txt') -Encoding UTF8
}

Save-Text -Path (Join-Path $gp 'since_utc.txt') -Content ("SinceUtc: {0:o}" -f $since.ToUniversalTime())

Safe-Run -Name "Diagnostics-Performance (CSV extract)" -Script {
  Get-WinEvent -FilterHashtable @{
    LogName='Microsoft-Windows-Diagnostics-Performance/Operational'
    StartTime=$since
  } | Select-Object TimeCreated,Id,LevelDisplayName,Message |
      Export-Csv -NoTypeInformation -Path (Join-Path $gp 'Diagnostics-Performance_Events.csv')
}

# ========== 07 Event Logs (CSV extracts + EVTX) ==========

# CSV extracts (time-filtered)
$TextLogs = @(
  @{ Log='System';                                   Name='System' },
  @{ Log='Application';                              Name='Application' },
  @{ Log='Microsoft-Windows-GroupPolicy/Operational';Name='GroupPolicy_Operational' },
  @{ Log='Microsoft-Windows-Winlogon/Operational';   Name='Winlogon_Operational' },
  @{ Log='Microsoft-Windows-User Profile Service/Operational'; Name='UserProfileService_Operational' },
  @{ Log='Microsoft-Windows-WLAN-AutoConfig/Operational';      Name='WLAN_AutoConfig_Operational' },
  @{ Log='Microsoft-Windows-NetworkProfile/Operational';       Name='NetworkProfile_Operational' },
  @{ Log='Microsoft-Windows-Kernel-Boot/Operational';          Name='KernelBoot_Operational' },
  @{ Log='Microsoft-Windows-Kernel-Power/Thermal-Operational'; Name='KernelPower_Thermal' },
  @{ Log='Microsoft-Windows-Time-Service/Operational';         Name='TimeService_Operational' },
  @{ Log='Microsoft-Windows-DNS-Client/Operational';           Name='DNSClient_Operational' }
)

# CSV extracts (time-filtered) — no $using:
foreach ($l in $TextLogs) {
  $logName = $l.Log
  $name    = $l.Name
  $destCsv = Join-Path $evt ("{0}_Since_{1}d.csv" -f $name, $SinceDays)
  $start   = $since  # capture locally

  Safe-Run -Name ("Export CSV: " + $name) -WarnOnly -Script ({
    Get-WinEvent -FilterHashtable @{ LogName = $logName; StartTime = $start } |
      Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message |
      Export-Csv -NoTypeInformation -Path $destCsv
  })
}

# EVTX deep-dive (no time filter)
$EvtxTargets = @(
  @{ Path='System';                                          File='System.evtx' },
  @{ Path='Application';                                     File='Application.evtx' },
  @{ Path='Microsoft-Windows-GroupPolicy/Operational';       File='GroupPolicy_Operational.evtx' },
  @{ Path='Microsoft-Windows-WLAN-AutoConfig/Operational';   File='WLAN_AutoConfig_Operational.evtx' },
  @{ Path='Microsoft-Windows-Diagnostics-Performance/Operational'; File='Diagnostics-Performance.evtx' },
  @{ Path='Microsoft-Windows-Winlogon/Operational';          File='Winlogon_Operational.evtx' },
  @{ Path='Microsoft-Windows-User Profile Service/Operational';    File='UserProfileService_Operational.evtx' }
)
# EVTX deep-dive (no time filter) — no $using:
foreach ($t in $EvtxTargets) {
  $channel  = $t.Path
  $destEvtx = Join-Path $evt $t.File

  Safe-Run -Name ("Export EVTX: " + $channel) -WarnOnly -Script ({
    wevtutil epl "$channel" "$destEvtx"
  })
}

# ========== 08 Apps (installed programs) ==========

Safe-Run -Name "Installed apps (x64/x86 registry)" -Script {
  Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*,
                   HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |
    Select-Object DisplayName,DisplayVersion,Publisher,InstallDate |
    Sort-Object DisplayName |
    Export-Csv -NoTypeInformation -Path (Join-Path $app 'InstalledApps.csv')
}

# ========== 09 CPU / Thermal hints ==========

Safe-Run -Name "Win32_Processor snapshot" -Script {
  Get-CimInstance Win32_Processor |
    Select-Object Name,NumberOfCores,MaxClockSpeed,CurrentClockSpeed,LoadPercentage |
    Export-Csv -NoTypeInformation -Path (Join-Path $cpu 'Win32_Processor.csv')
}
Safe-Run -Name "SystemProfile reg (power throttling hints)" -WarnOnly -Script {
  reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /s 2>&1 |
    Out-File -FilePath (Join-Path $cpu 'SystemProfile_reg.txt') -Encoding UTF8
}



# ========== 10) Diagnostic Data Viewer (DDV) ==========
# Requires: Admin + Windows 10/11 (1803+) + PS 5.1+. Enabling viewing stores local history (default 1GB / 30 days).
# Docs: Install/Enable/Get-DiagnosticData, capacity defaults, etc.

# --- Diagnostic Data Viewer module bootstrap (hardened) ---
# Requires $ddv already set to your Section 10 output folder, e.g.:
   $ddv = Join-Path $root '10_DiagnosticDataViewer'
if (-not (Test-Path $ddv)) { New-Item -ItemType Directory -Path $ddv -Force | Out-Null }

# 1) Ensure CurrentUser module path exists (avoids DirectoryNotFoundException)
Safe-Run -Name "DDV: Ensure CurrentUser module path" -WarnOnly -Script ({
  $userModRoot = Join-Path $HOME 'Documents\WindowsPowerShell\Modules'
  if (-not (Test-Path $userModRoot)) {
    New-Item -ItemType Directory -Path $userModRoot -Force | Out-Null
  }
})

# 2) Repo + provider bootstrap (TLS 1.2, PSGallery trust, NuGet provider)
Safe-Run -Name "DDV: Repo bootstrap" -WarnOnly -Script ({
  try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
  try { $null = Get-PSRepository -Name PSGallery -ErrorAction Stop } catch { Register-PSRepository -Default -ErrorAction SilentlyContinue }
  try {
    $repo = Get-PSRepository -Name PSGallery -ErrorAction Stop
    if ($repo.InstallationPolicy -ne 'Trusted') { Set-PSRepository -Name PSGallery -InstallationPolicy Trusted }
  } catch {}
  if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope AllUsers -Force -ErrorAction SilentlyContinue | Out-Null
  }
})

# 3) Install/Import with fallbacks (fixed)
Safe-Run -Name "DDV: Install/Import module" -WarnOnly -Script ({
  $modName = 'Microsoft.DiagnosticDataViewer'

  # Already available?
  $installed = Get-Module -ListAvailable -Name $modName | Sort-Object Version -Descending | Select-Object -First 1

  if (-not $installed) {
    try {
      Install-Module -Name $modName -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    } catch {
      $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
      if ($isAdmin) {
        try {
          Install-Module -Name $modName -Scope AllUsers -Force -AllowClobber -ErrorAction Stop
        } catch {
          $savePath = Join-Path $ddv 'Module'
          if (-not (Test-Path $savePath)) { New-Item -ItemType Directory -Path $savePath -Force | Out-Null }
          Save-Module -Name $modName -Path $savePath -Force
        }
      } else {
        $savePath = Join-Path $ddv 'Module'
        if (-not (Test-Path $savePath)) { New-Item -ItemType Directory -Path $savePath -Force | Out-Null }
        Save-Module -Name $modName -Path $savePath -Force
      }
    }
  }

  # Candidate PSD1 locations (build patterns first)
  $cand1 = Join-Path $HOME 'Documents\WindowsPowerShell\Modules\Microsoft.DiagnosticDataViewer\*\Microsoft.DiagnosticDataViewer.psd1'
  $cand2 = 'C:\Program Files\WindowsPowerShell\Modules\Microsoft.DiagnosticDataViewer\*\Microsoft.DiagnosticDataViewer.psd1'
  $cand3 = Join-Path $ddv 'Module\Microsoft.DiagnosticDataViewer\*\Microsoft.DiagnosticDataViewer.psd1'
  $candidates = @($cand1, $cand2, $cand3)

  # Expand patterns and pick the newest path
  $psd1 = $null
  foreach ($pattern in $candidates) {
    $matches = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | Sort-Object FullName -Descending
    if ($matches -and $matches.Count -gt 0) {
      $psd1 = $matches[0].FullName
      break
    }
  }

  if ($psd1) {
    Import-Module $psd1 -Force
  } else {
    Import-Module Microsoft.DiagnosticDataViewer -Force
  }
})


# 4) Verify cmdlets available (writes a note if anything is missing)
Safe-Run -Name "DDV: Verify cmdlets" -WarnOnly -Script ({
  $need = 'Get-DiagnosticData','Get-DiagnosticDataTypes','Enable-DiagnosticDataViewing','Get-DiagnosticStoreCapacity','Get-DiagnosticDataViewingSetting'
  $missing = @()
  foreach ($n in $need) { if (-not (Get-Command $n -ErrorAction SilentlyContinue)) { $missing += $n } }
  if ($missing.Count -gt 0) {
    ("Missing cmdlets: " + ($missing -join ', ')) | Out-File -FilePath (Join-Path $ddv 'DDV_MissingCmdlets.txt') -Encoding UTF8
  }
})


# 5) Ensure viewing is enabled (records data from this point forward)
Safe-Run -Name "Enable Diagnostic Data Viewing (if needed)" -WarnOnly -Script ({
  $statusFile = Join-Path $ddv 'DDV_ViewingStatus.txt'
  $state = $null
  try { $state = Get-DiagnosticDataViewingSetting } catch { }
  if ($state -and $state -match 'Enabled') {
    'Enabled' | Out-File -FilePath $statusFile -Encoding UTF8
  } else {
    Enable-DiagnosticDataViewing | Out-File -FilePath $statusFile -Encoding UTF8
  }
})

# 6)Store capacity (defaults typically 1024 MB / 30 days)
Safe-Run -Name "DDV store capacity" -Script ({
  $capFile = Join-Path $ddv 'DDV_StoreCapacity.txt'
  $sizeMB  = Get-DiagnosticStoreCapacity -Size
  $days    = Get-DiagnosticStoreCapacity -Time
  @("SizeMB=$sizeMB","Days=$days") | Out-File -FilePath $capFile -Encoding UTF8
})

# 7) Data types catalog
Safe-Run -Name "DDV data types catalog" -WarnOnly -Script ({
  $typesCsv  = Join-Path $ddv 'DDV_DataTypes.csv'
  $typesJson = Join-Path $ddv 'DDV_DataTypes.json'
  $types = Get-DiagnosticDataTypes
  $types | Select-Object * | Export-Csv -NoTypeInformation -Path $typesCsv
  $types | ConvertTo-Json -Depth 6 | Out-File -FilePath $typesJson -Encoding UTF8
})

# 8) Pull diagnostic data window (since $SinceDays to now) — JSON + CSV
Safe-Run -Name "DDV diagnostic data (events)" -WarnOnly -Script ({
  $start = $since
  $end   = Get-Date
  $json  = Join-Path $ddv 'DDV_Data.json'
  $csv   = Join-Path $ddv 'DDV_Data.csv'

  $data = $null
  try {
    # Limit record count to keep size sane; adjust as needed
    $data = Get-DiagnosticData -StartTime $start -EndTime $end -RecordCount 10000 -ErrorAction Stop
  } catch { }

  if ($data) {
    $data | ConvertTo-Json -Depth 10 | Out-File -FilePath $json -Encoding UTF8
    # Flatten top-level fields for a quick spreadsheet view; nested payload remains in JSON
    $data | Select-Object * | Export-Csv -NoTypeInformation -Path $csv
  } else {
    "No diagnostic data available in window $($start) .. $($end) (enable just occurred or store is empty)." |
      Out-File -FilePath (Join-Path $ddv 'DDV_Data.txt') -Encoding UTF8
  }
})

# Optional: Basic telemetry only sample (smaller)
Safe-Run -Name "DDV diagnostic data (basic only)" -WarnOnly -Script ({
  $start = $since
  $end   = Get-Date
  $csv   = Join-Path $ddv 'DDV_Data_Basic.csv'
  try {
    Get-DiagnosticData -StartTime $start -EndTime $end -BasicTelemetryOnly -RecordCount 5000 |
      Select-Object * | Export-Csv -NoTypeInformation -Path $csv
  } catch {
    "BasicTelemetryOnly call failed or no data." | Out-File -FilePath (Join-Path $ddv 'DDV_Data_Basic.txt') -Encoding UTF8
  }
})

# (Optional) Leave viewing enabled so history accumulates; to turn off later:
# Safe-Run -Name "Disable Diagnostic Data Viewing" -Script ({ Disable-DiagnosticDataViewing })

#You can optionally install the Windows Store App to view data in a GUI




# ========== 11 Optional ETL copies ==========

if ($IncludeETL) {
  if (-not (Test-Path $etlDir)) { New-Item -ItemType Directory -Path $etlDir -Force | Out-Null }
  $candidateEtls = @(
    "$env:ProgramData\Microsoft\WlanReport\*.etl",
    "$env:ProgramData\Microsoft\Windows\WlanReport\*.etl",
    "$env:ProgramData\Microsoft\Windows\WindowsUpdate\*.etl"
  )
  foreach ($pattern in $candidateEtls) {
    Safe-Run -Name "Copy ETL(s) from $pattern" -WarnOnly -Script {
      Get-ChildItem -Path $using:pattern -ErrorAction SilentlyContinue | Copy-Item -Destination $etlDir -Force
    }
  }
}

# ========== 12) Reliability Monitor (RAC) ==========
$rel = Join-Path $root '12_Reliability'
if (-not (Test-Path $rel)) { New-Item -ItemType Directory -Path $rel -Force | Out-Null }

# A simple HTML table style for the reports
$relHtmlHead = '<style>body{font-family:Segoe UI,Arial,sans-serif;font-size:12px;margin:16px}
h1{font-size:18px} table{border-collapse:collapse;width:100%}
th,td{border:1px solid #ddd;padding:6px} th{background:#f3f3f3;text-align:left;position:sticky;top:0}
tr:nth-child(even){background:#fafafa}</style>'

# Reliability Records (events shown in Reliability Monitor) → CSV + HTML
Safe-Run -Name "Reliability: Records (CSV/HTML)" -Script ({
  $start = (Get-Date).AddDays(-1 * [math]::Abs($SinceDays))
  $csv   = Join-Path $rel 'ReliabilityRecords.csv'
  $html  = Join-Path $rel 'ReliabilityRecords.html'

  $raw = $null
  try {
    $raw = Get-CimInstance -Namespace root\cimv2 -ClassName Win32_ReliabilityRecords -ErrorAction Stop
  } catch { }

  if ($raw) {
    # Normalize timestamps and filter to the window
    $rows = foreach ($r in $raw) {
      $dt = $r.TimeGenerated
      if (-not ($dt -is [datetime])) {
        try { $dt = [Management.ManagementDateTimeConverter]::ToDateTime($r.TimeGenerated) } catch { $dt = $null }
      }
      if ($dt -and $dt -ge $start) {
        [pscustomobject]@{
          TimeGenerated = $dt
          SourceName    = $r.SourceName
          EventId       = $r.EventIdentifier
          ProductName   = $r.ProductName
          Message       = $r.Message
        }
      }
    }

    $rows | Sort-Object TimeGenerated -Descending | Export-Csv -NoTypeInformation -Path $csv

    # Also a quick per-source summary table in the HTML header
    $summary = $rows | Group-Object SourceName | Sort-Object Count -Descending | Select-Object Name,Count
    $summaryHtml = ($summary | ConvertTo-Html -Fragment)

    $body = @()
    $body += "<h1>Reliability Records (last $SinceDays days)</h1>"
    $body += "<h2>Summary by Source</h2>"
    $body += $summaryHtml
    $body += "<h2>Events</h2>"
    $body += ($rows | Sort-Object TimeGenerated -Descending |
              Select-Object TimeGenerated, SourceName, EventId, ProductName, Message |
              ConvertTo-Html -Fragment)

    ConvertTo-Html -Head $relHtmlHead -Title "Reliability Records (last $SinceDays days)" -Body $body |
      Out-File -FilePath $html -Encoding UTF8
  } else {
    "Win32_ReliabilityRecords not available on this system." |
      Out-File -FilePath (Join-Path $rel 'ReliabilityRecords.txt') -Encoding UTF8
  }
})

# Stability Index (daily 1–10) → CSV + HTML (if the class is present)
Safe-Run -Name "Reliability: Stability Index (CSV/HTML)" -WarnOnly -Script ({
  $start = (Get-Date).AddDays(-1 * [math]::Abs($SinceDays))
  $csv   = Join-Path $rel 'StabilityIndex.csv'
  $html  = Join-Path $rel 'StabilityIndex.html'

  $raw = $null
  try {
    $raw = Get-CimInstance -Namespace root\cimv2 -ClassName Win32_ReliabilityStabilityMetrics -ErrorAction Stop
  } catch { }

  if ($raw) {
    $rows = foreach ($m in $raw) {
      $dt = $m.TimeStamp
      if (-not ($dt -is [datetime])) {
        try { $dt = [Management.ManagementDateTimeConverter]::ToDateTime($m.TimeStamp) } catch { $dt = $null }
      }
      if ($dt -and $dt -ge $start) {
        [pscustomobject]@{
          Date                 = $dt.Date
          TimeStamp            = $dt
          SystemStabilityIndex = [double]$m.SystemStabilityIndex
        }
      }
    }

    $rows | Sort-Object TimeStamp | Export-Csv -NoTypeInformation -Path $csv

    $body = @()
    $body += "<h1>Stability Index (last $SinceDays days)</h1>"
    $body += ($rows | Sort-Object TimeStamp |
              Select-Object Date, SystemStabilityIndex |
              ConvertTo-Html -Fragment)

    ConvertTo-Html -Head $relHtmlHead -Title "Stability Index (last $SinceDays days)" -Body $body |
      Out-File -FilePath $html -Encoding UTF8
  } else {
    "Win32_ReliabilityStabilityMetrics not available on this system." |
      Out-File -FilePath (Join-Path $rel 'StabilityIndex.txt') -Encoding UTF8
  }
})



# ========== 00 QuickLooks summaries ==========

Safe-Run -Name "QuickLook: Boot/Shutdown perf events (100-199)" -Script {
  Get-WinEvent -FilterHashtable @{
    LogName='Microsoft-Windows-Diagnostics-Performance/Operational'
    StartTime=$since
    Id=@(100..199)
  } | Select-Object TimeCreated,Id,Message |
      Export-Csv -NoTypeInformation -Path (Join-Path $quick 'Boot_And_Shutdown_PerfEvents.csv')
}

Safe-Run -Name "QuickLook: WLAN disconnects/reasons" -Script {
  Get-WinEvent -FilterHashtable @{
    LogName='Microsoft-Windows-WLAN-AutoConfig/Operational'
    StartTime=$since
  } | Where-Object { $_.Id -in 8000,8001,8002,8003,8006,8007,11000,11001,11002,11004,12011,12013 } |
      Select-Object TimeCreated,Id,Message |
      Export-Csv -NoTypeInformation -Path (Join-Path $quick 'WLAN_Disconnects_Reasons.csv')
}

Safe-Run -Name "QuickLook: Group Policy events" -Script {
  Get-WinEvent -FilterHashtable @{
    LogName='Microsoft-Windows-GroupPolicy/Operational'
    StartTime=$since
  } | Select-Object TimeCreated,Id,Message |
      Export-Csv -NoTypeInformation -Path (Join-Path $quick 'GroupPolicy_Events.csv')
}

# ========== Package up ==========

$zipPath = Join-Path (Get-Location) ("LaptopPerfBundle_{0}.zip" -f $stamp)
Safe-Run -Name "Create ZIP: $zipPath" -Script {
  Add-Type -AssemblyName 'System.IO.Compression.FileSystem' -ErrorAction SilentlyContinue
  [System.IO.Compression.ZipFile]::CreateFromDirectory($root, $zipPath)
  Write-Host "Bundle created: $zipPath"
}

Write-Status -Level OK -Message "Collection complete. Folder: $root"
Write-Status -Level INFO -Message "Tip: Run with -Verbose for more step-by-step detail."