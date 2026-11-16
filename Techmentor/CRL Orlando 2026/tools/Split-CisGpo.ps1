<#
.SYNOPSIS
    Split one CIS Benchmark GPO backup into several smaller GPO backups, one per
    logical settings area (account policies, user rights, audit, firewall, ...).

.DESCRIPTION
    CIS Build Kits ship each benchmark level as ONE large GPO with hundreds of
    settings. That is hard to read, hard to troubleshoot and all-or-nothing to
    link. This script reads one CIS policy folder (for example DC-L1, MS-L1 or
    COMP-L1) from YOUR CIS zip and writes a set of standard GPO backups, one per
    area, each holding only that area's settings. Every setting lands in exactly
    one output GPO, and the script checks that before it finishes.

    The output is a normal GPO backup set, so it imports with Import-GPO (or the
    GPMC "Import Settings" wizard). The kit's import step creates the GPOs
    UNLINKED: you decide where to link each one.

    Pure PowerShell, no modules needed. Nothing from CIS is stored in the kit:
    the script works on the zip you supply.

    How the split works:
      * GptTmpl.inf (security template)
          [System Access] password/lockout keys + [Kerberos Policy] -> Account Policies
          [Privilege Rights]                                       -> User Rights Assignment
          [Registry Values] + the other [System Access] keys       -> Security Options
          [Event Audit]                                            -> Audit Policy
          [Service General Setting]                                -> System Services
          [File Security] / [Registry Keys]                        -> File and Registry Permissions
      * audit.csv (advanced audit policy)                          -> Audit Policy
      * registry.pol (Administrative Templates), by registry key   -> Defender, Firewall,
          Remote Desktop and WinRM, Windows Update, Network, Printing, Event Logs,
          Credentials and Device Security, Apps Privacy and Store, System and Logon

    Each output GPO keeps the original backup's file set (Backup.xml, bkupInfo.xml,
    comment.cmtx, ...) so Import-GPO accepts it; files outside the area are written
    with no settings in them (an empty template, a header-only audit.csv, a
    header-only registry.pol), which apply nothing.

.EXAMPLE
    ./Split-CisGpo.ps1 -ZipPath C:\CIS\Server2022.zip -PolicyFolder DC-L1 -Label DC -OutDir C:\CIS\split
    ./Split-CisGpo.ps1 -ZipPath C:\CIS\Server2022.zip -PolicyFolder MS-L1 -Label MS -OutDir C:\CIS\split
    ./Split-CisGpo.ps1 -ZipPath C:\CIS\Windows11.zip  -PolicyFolder COMP-L1 -Label Win11 -OutDir C:\CIS\split
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ZipPath,
    [Parameter(Mandatory)][string]$PolicyFolder,          # DC-L1 / MS-L1 / COMP-L1 ...
    [Parameter(Mandatory)][string]$Label,                 # DC / MS / Win11 (goes into the GPO name)
    [Parameter(Mandatory)][string]$OutDir,
    [string]$Prefix = 'DefXDR CIS L1'
)
$ErrorActionPreference = 'Stop'
function Say($m){ Write-Host "[split] $m" -ForegroundColor Cyan }

# ---------------------------------------------------------------- the groups
# GptTmpl.inf [System Access] keys that are ACCOUNT POLICIES (the rest of that
# section are Security Options, e.g. rename administrator, anonymous SID lookup).
$AccountKeys = @('MinimumPasswordAge','MaximumPasswordAge','MinimumPasswordLength','PasswordComplexity',
                 'PasswordHistorySize','LockoutBadCount','ResetLockoutCount','LockoutDuration',
                 'AllowAdministratorLockout','ClearTextPassword','RequireLogonToChangePassword')

# registry.pol key prefixes -> group (first match wins; everything else -> System and Logon).
$RegGroups = [ordered]@{
    'Defender Antivirus' = @(
        'software\policies\microsoft\windows defender',
        'software\policies\microsoft\windows defender security center')
    'Windows Firewall' = @(
        'software\policies\microsoft\windowsfirewall')
    'Remote Desktop and WinRM' = @(
        'software\policies\microsoft\windows nt\terminal services',
        'software\policies\microsoft\windows\winrm')
    'Windows Update' = @(
        'software\policies\microsoft\windows\windowsupdate',
        'software\policies\microsoft\windows\deliveryoptimization',
        'software\policies\microsoft\windows\previewbuilds')
    'Network' = @(
        'software\policies\microsoft\windows nt\dnsclient',
        'software\policies\microsoft\windows nt\rpc',
        'software\policies\microsoft\windows\lanmanworkstation',
        'software\policies\microsoft\windows\network connections',
        'software\policies\microsoft\windows\networkprovider',
        'software\policies\microsoft\windows\wcmsvc',
        'software\microsoft\wcmsvc',
        'software\policies\microsoft\windows\homegroup',
        'software\policies\microsoft\windows\connect',
        'system\currentcontrolset\services\netbt',
        'system\currentcontrolset\services\tcpip',
        'system\currentcontrolset\services\tcpip6',
        'system\currentcontrolset\services\lanmanserver',
        'system\currentcontrolset\services\lanmanworkstation',
        'system\currentcontrolset\services\mrxsmb10')
    'Printing' = @(
        'software\policies\microsoft\windows nt\printers',
        'system\currentcontrolset\control\print')
    'Event Logs' = @(
        'software\policies\microsoft\windows\eventlog',
        'system\currentcontrolset\services\eventlog')
    'Credentials and Device Security' = @(
        'software\policies\microsoft\windows\credentialsdelegation',
        'software\policies\microsoft\windows\credui',
        'software\policies\microsoft\windows\deviceguard',
        'software\policies\microsoft\windows\kernel dma protection',
        'software\policies\microsoft\windows\sandbox',
        'software\policies\microsoft\windows\wtds',
        'software\policies\microsoft\apphvsi',
        'software\policies\microsoft\biometrics',
        'software\policies\microsoft\systemcertificates',
        'software\microsoft\policies\passportforwork',
        'software\microsoft\cryptography',
        'software\wow6432node\microsoft\cryptography',
        'system\currentcontrolset\control\securityproviders',
        'system\currentcontrolset\control\lsa',
        'system\currentcontrolset\control\session manager',
        'system\currentcontrolset\policies\earlylaunch')
    'Apps Privacy and Store' = @(
        'software\policies\microsoft\windows\appinstaller',
        'software\policies\microsoft\windows\appx',
        'software\policies\microsoft\windows\appprivacy',
        'software\policies\microsoft\windowsstore',
        'software\policies\microsoft\windows\gamedvr',
        'software\policies\microsoft\windows\cloudcontent',
        'software\policies\microsoft\windows\onedrive',
        'software\policies\microsoft\windows\windows search',
        'software\policies\microsoft\windows\personalization',
        'software\policies\microsoft\windows\datacollection',
        'software\policies\microsoft\inputpersonalization',
        'software\policies\microsoft\windowsinkworkspace',
        'software\policies\microsoft\dsh',
        'software\policies\microsoft\internet explorer',
        'software\policies\microsoft\microsoftaccount')
}
$CatchAll = 'System and Logon'

# Output order (and the number in each folder name).
$Order = @('Account Policies','User Rights Assignment','Security Options','Audit Policy',
           'System Services','File and Registry Permissions',
           'Defender Antivirus','Windows Firewall','Remote Desktop and WinRM','Windows Update',
           'Network','Printing','Event Logs','Credentials and Device Security',
           'Apps Privacy and Store','System and Logon')

function Get-RegGroup([string]$Key){
    $k = $Key.ToLowerInvariant().TrimStart('\')
    foreach ($g in $RegGroups.Keys){
        foreach ($p in $RegGroups[$g]){
            if ($k -eq $p -or $k.StartsWith($p + '\')) { return $g }
        }
    }
    return $CatchAll
}

# ------------------------------------------------------ registry.pol (PReg)
# Format: 'PReg' + version 1, then entries [key;value;type;size;data] in UTF-16LE.
# We only need each entry's key (to group it) and its exact bytes (to copy it).
function Read-PolEntries([byte[]]$b){
    $list = New-Object System.Collections.Generic.List[object]
    if ($b.Length -lt 8 -or [Text.Encoding]::ASCII.GetString($b,0,4) -ne 'PReg') { throw "Not a registry.pol file." }
    $i = 8
    while ($i -lt $b.Length) {
        $start = $i
        if ($b[$i] -ne 0x5B -or $b[$i+1] -ne 0) { throw "registry.pol: expected '[' at byte $i" }
        $j = $i + 2
        $k = $j; while (-not ($b[$k] -eq 0 -and $b[$k+1] -eq 0)) { $k += 2 }
        $key = [Text.Encoding]::Unicode.GetString($b, $j, $k - $j)
        $j = $k + 4                                   # key terminator + ';'
        $k = $j; while (-not ($b[$k] -eq 0 -and $b[$k+1] -eq 0)) { $k += 2 }
        $j = $k + 4                                   # value-name terminator + ';'
        $j += 6                                       # type (4) + ';'
        $size = [BitConverter]::ToUInt32($b, $j); $j += 6   # size (4) + ';'
        $j += [int]$size
        if ($b[$j] -ne 0x5D -or $b[$j+1] -ne 0) { throw "registry.pol: expected ']' at byte $j" }
        $j += 2
        $list.Add([pscustomobject]@{ Key = $key; Start = $start; Length = $j - $start })
        $i = $j
    }
    return ,$list
}
function Write-PolEntries([string]$Path,[byte[]]$Src,$Entries){
    $ms = New-Object IO.MemoryStream
    $ms.Write($Src, 0, 8)                             # 'PReg' + version from the original
    foreach ($e in $Entries){ $ms.Write($Src, $e.Start, $e.Length) }
    [IO.File]::WriteAllBytes($Path, $ms.ToArray())
}

# ------------------------------------------------------------- GptTmpl.inf
function Read-Inf([string]$Path){
    $sections = [ordered]@{}; $cur = $null
    foreach ($line in [IO.File]::ReadAllLines($Path)) {        # BOM-aware (UTF-16LE in CIS kits)
        if ($line -match '^\s*\[(.+)\]\s*$') { $cur = $Matches[1]; if (-not $sections.Contains($cur)) { $sections[$cur] = New-Object System.Collections.Generic.List[string] }; continue }
        if ($cur -and $line.Trim()) { $sections[$cur].Add($line) }
    }
    return $sections
}
function Write-Inf([string]$Path,$Parts){
    # $Parts: ordered dictionary  sectionName -> lines
    $sb = New-Object Text.StringBuilder
    [void]$sb.Append("[Unicode]`r`nUnicode=yes`r`n")
    foreach ($s in $Parts.Keys){
        if ($Parts[$s].Count -eq 0) { continue }
        [void]$sb.Append("[$s]`r`n")
        foreach ($l in $Parts[$s]) { [void]$sb.Append("$l`r`n") }
    }
    [void]$sb.Append("[Version]`r`nsignature=`"`$CHICAGO`$`"`r`nRevision=1`r`n")
    [IO.File]::WriteAllText($Path, $sb.ToString(), (New-Object Text.UnicodeEncoding($false,$true)))
}

# ================================================================== main
if (-not (Test-Path $ZipPath)) { throw "Zip not found: $ZipPath" }
$work = Join-Path ([IO.Path]::GetTempPath()) ("cis-split-" + [guid]::NewGuid().ToString('N').Substring(0,8))
Say "Reading $PolicyFolder from $(Split-Path -Leaf $ZipPath)..."
Expand-Archive -Path $ZipPath -DestinationPath $work -Force
$polRoot = Join-Path $work $PolicyFolder
if (-not (Test-Path $polRoot)) { throw "Policy folder '$PolicyFolder' not found in the zip." }
$bkDir = Get-ChildItem $polRoot -Directory | Where-Object { $_.Name -match '^\{[0-9A-Fa-f-]{36}\}$' } | Select-Object -First 1
if (-not $bkDir) { throw "No {GUID} backup folder under $PolicyFolder." }
$backupId = $bkDir.Name
$machine  = Join-Path $bkDir.FullName 'DomainSysvol\GPO\Machine'
$infPath  = Join-Path $machine 'microsoft\windows nt\SecEdit\GptTmpl.inf'
$csvPath  = Join-Path $machine 'microsoft\windows nt\Audit\audit.csv'
$polPath  = Join-Path $machine 'registry.pol'

# --- read everything once -------------------------------------------------
$inf = if (Test-Path $infPath) { Read-Inf $infPath } else { [ordered]@{} }
$csv = if (Test-Path $csvPath) { [IO.File]::ReadAllLines($csvPath) } else { @() }
$polBytes = if (Test-Path $polPath) { [IO.File]::ReadAllBytes($polPath) } else { $null }
$pol = if ($polBytes) { Read-PolEntries $polBytes } else { New-Object System.Collections.Generic.List[object] }

# --- assign every setting to exactly one group ---------------------------
$infBy = @{}; $csvBy = @{}; $polBy = @{}
foreach ($g in $Order) { $infBy[$g] = [ordered]@{}; $csvBy[$g] = New-Object System.Collections.Generic.List[string]; $polBy[$g] = New-Object System.Collections.Generic.List[object] }
function Add-InfLine($group,$section,$line){
    if (-not $infBy[$group].Contains($section)) { $infBy[$group][$section] = New-Object System.Collections.Generic.List[string] }
    $infBy[$group][$section].Add($line)
}
$infTotal = 0
foreach ($s in $inf.Keys) {
    if ($s -in @('Unicode','Version')) { continue }
    foreach ($line in $inf[$s]) {
        $name = ($line -split '=',2)[0].Trim()
        # Lab change: never rename the built-in Administrator. The CIS
        # "Rename administrator account" (NewAdministratorName) renames RID-500
        # and locks the lab out of the known admin logon. Drop it so it is
        # neither emitted into Security Options nor counted in the split check.
        # (NewGuestName / "Rename guest account" is left in place - harmless.)
        if ($s -eq 'System Access' -and $name -eq 'NewAdministratorName') { continue }
        $infTotal++
        $g = switch ($s) {
            'System Access'           { if ($AccountKeys -contains $name) { 'Account Policies' } else { 'Security Options' } }
            'Kerberos Policy'         { 'Account Policies' }
            'Privilege Rights'        { 'User Rights Assignment' }
            'Event Audit'             { 'Audit Policy' }
            'Service General Setting' { 'System Services' }
            'File Security'           { 'File and Registry Permissions' }
            'Registry Keys'           { 'File and Registry Permissions' }
            default                   { 'Security Options' }     # [Registry Values] and anything unexpected
        }
        Add-InfLine $g $s $line
    }
}
$csvHeader = if ($csv.Count) { $csv[0] } else { 'Machine Name,Policy Target,Subcategory,Subcategory GUID,Inclusion Setting,Exclusion Setting,Setting Value' }
$csvRows = @($csv | Select-Object -Skip 1 | Where-Object { $_.Trim() })
foreach ($r in $csvRows) { $csvBy['Audit Policy'].Add($r) }
foreach ($e in $pol) { $polBy[(Get-RegGroup $e.Key)].Add($e) }

# --- write one GPO backup per non-empty group -----------------------------
$outPolicy = Join-Path $OutDir $Label
New-Item -ItemType Directory -Force -Path $outPolicy | Out-Null
$index = @()
$n = 0
foreach ($g in $Order) {
    $infCount = 0; foreach ($s in $infBy[$g].Keys) { $infCount += $infBy[$g][$s].Count }
    $count = $infCount + $csvBy[$g].Count + $polBy[$g].Count
    if ($count -eq 0) { continue }
    $n++
    $folder = ('{0}-{1:D2}-{2}' -f $Label, $n, ($g -replace '[^A-Za-z0-9]',''))
    $dest = Join-Path $outPolicy $folder
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Copy-Item (Join-Path $polRoot 'manifest.xml') $dest -ErrorAction SilentlyContinue
    Copy-Item $bkDir.FullName $dest -Recurse
    $m = Join-Path $dest "$backupId\DomainSysvol\GPO\Machine"
    if (Test-Path $infPath) { Write-Inf (Join-Path $m 'microsoft\windows nt\SecEdit\GptTmpl.inf') $infBy[$g] }
    if (Test-Path $csvPath) { [IO.File]::WriteAllLines((Join-Path $m 'microsoft\windows nt\Audit\audit.csv'), [string[]](@($csvHeader) + @($csvBy[$g]))) }
    if ($polBytes)          { Write-PolEntries (Join-Path $m 'registry.pol') $polBytes $polBy[$g] }
    # The original settings report would describe the WHOLE benchmark - drop it so
    # nobody mistakes it for this part's settings (Import-GPO does not need it).
    Remove-Item (Join-Path $dest "$backupId\gpreport.xml") -ErrorAction SilentlyContinue
    $name = "$Prefix $Label - $g"
    $index += [pscustomobject]@{ GpoName = $name; Folder = "$Label\$folder"; BackupId = $backupId; Settings = $count
                                 TemplateLines = $infCount; AuditRows = $csvBy[$g].Count; RegistryValues = $polBy[$g].Count }
    Say ("  {0,-58} {1,4} settings" -f $name, $count)
}

# --- prove nothing was lost or duplicated ---------------------------------
$sumInf = ($index | Measure-Object TemplateLines -Sum).Sum
$sumCsv = ($index | Measure-Object AuditRows -Sum).Sum
$sumPol = ($index | Measure-Object RegistryValues -Sum).Sum
if ($sumInf -ne $infTotal -or $sumCsv -ne $csvRows.Count -or $sumPol -ne $pol.Count) {
    throw "Split check FAILED: template $sumInf/$infTotal, audit $sumCsv/$($csvRows.Count), registry $sumPol/$($pol.Count)."
}
Say "Check passed: all $infTotal template lines, $($csvRows.Count) audit rows and $($pol.Count) registry values placed exactly once."

# --- append to the shared index (one CSV for every policy split into OutDir) --
$idxPath = Join-Path $OutDir 'split-index.csv'
$existing = @(); if (Test-Path $idxPath) { $existing = @(Import-Csv $idxPath | Where-Object { $_.Folder -notlike "$Label\*" }) }
@($existing) + @($index) | Export-Csv $idxPath -NoTypeInformation
Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
Say "Wrote $($index.Count) GPO backups for $PolicyFolder to $outPolicy (index: $idxPath)."
$index
