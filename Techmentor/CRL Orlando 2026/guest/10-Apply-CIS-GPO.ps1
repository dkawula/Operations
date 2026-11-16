<#
.SYNOPSIS
    Import a CIS Benchmark Group Policy from a CIS GPO backup ZIP and link it to
    the right OU, so you can demo "the attack with CIS Level 1 applied" vs
    without. Also moves a target computer in/out of a hardened OU so you can
    control exactly which box is hardened for the 4-way test matrix.

.DESCRIPTION
    Runs in-guest on DC01. NOTHING from CIS ships in this lab package - at demo
    time you POINT this at a CIS GPO backup ZIP you downloaded with your own CIS
    SecureSuite / Build Kit membership (e.g. the Server 2022 or Windows 11
    benchmark export). The script:

      * extracts the ZIP to a temp folder,
      * finds the named policy folder you asked for (e.g. 'DC-L1' or 'COMP-L1'),
      * discovers the GPO backup inside it (its backup GUID + display name),
      * imports it into the domain as a GPO (created if needed),
      * links it to the correct OU, and
      * (for workstations) moves the chosen computer into a hardened OU so only
        that box gets the policy - the rest of the matrix is unaffected.

    This keeps the whole thing CIS-redistribution-safe: the benchmark content
    lives only in the ZIP the operator supplies, never in the repo.

    Actions:
      ApplyDC            - import the DC policy and link it to the built-in
                           'Domain Controllers' OU (hardens DC01).
      RemoveDC           - unlink that GPO from the Domain Controllers OU.
      ApplyWorkstation   - import the workstation policy, ensure the hardened OU
                           exists and is linked, and MOVE -ComputerName into it.
      RemoveWorkstation  - move -ComputerName back to the default Computers
                           container (drops the hardened policy on next gpupdate).

    Requires: the GroupPolicy and ActiveDirectory modules (present on a DC).

.EXAMPLE
    ./10-Apply-CIS-GPO.ps1 -Action ApplyDC -ZipPath C:\CIS\Server2022.zip -PolicyFolder 'DC-L1'
    ./10-Apply-CIS-GPO.ps1 -Action ApplyWorkstation -ZipPath C:\CIS\Windows11.zip -PolicyFolder 'COMP-L1' -ComputerName WIN11
    ./10-Apply-CIS-GPO.ps1 -Action RemoveWorkstation -ComputerName WIN11
#>
[CmdletBinding()]
param(
    [ValidateSet('ApplyDC','RemoveDC','ApplyWorkstation','RemoveWorkstation')]
    [string]$Action,
    [string]$ZipPath,
    [string]$PolicyFolder,                 # named folder inside the CIS zip (DC-L1 / COMP-L1 / MS-L1 ...)
    [string]$GpoName        = '',          # target GPO name; blank = derive from the backup's display name
    [string]$WorkstationsOU = 'CIS-Hardened-Workstations',
    [string]$ComputerName   = ''
)
$ErrorActionPreference = 'Stop'
function Say($m){ Write-Host "[cis] $m" -ForegroundColor Cyan }
function Warn($m){ Write-Host "[cis] $m" -ForegroundColor Yellow }

Import-Module GroupPolicy -ErrorAction Stop
Import-Module ActiveDirectory -ErrorAction Stop

$domainDN = (Get-ADDomain).DistinguishedName
$dcOU     = "OU=Domain Controllers,$domainDN"

# --- helper: extract the zip and locate the requested GPO backup ---------
function Resolve-GpoBackup {
    param([string]$Zip,[string]$Folder)
    if (-not (Test-Path $Zip)) { throw "CIS GPO zip not found on the DC at '$Zip'. Stage it there first (the framework uploads it for you)." }
    $work = Join-Path $env:TEMP ("cisgpo-" + [guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    Say "Extracting '$Zip'..."
    Expand-Archive -LiteralPath $Zip -DestinationPath $work -Force

    # find the named policy folder (e.g. DC-L1) anywhere in the extracted tree
    $polDir = Get-ChildItem -Path $work -Directory -Recurse -Filter $Folder -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $polDir) { throw "Policy folder '$Folder' not found inside the zip. Folders present: $((Get-ChildItem $work -Directory | Select-Object -Expand Name) -join ', ')" }

    # inside it, the GPO backup is a single {GUID} subfolder with a Backup.xml
    $backup = Get-ChildItem -Path $polDir.FullName -Directory | Where-Object { $_.Name -match '^\{[0-9A-Fa-f-]+\}$' -and (Test-Path (Join-Path $_.FullName 'Backup.xml')) } | Select-Object -First 1
    if (-not $backup) { throw "No GPO backup ({GUID} folder with Backup.xml) found under '$($polDir.FullName)'." }

    $backupId = $backup.Name.Trim('{','}')
    [xml]$bx  = Get-Content (Join-Path $backup.FullName 'Backup.xml')
    $display  = ($bx.GroupPolicyBackupScheme.GroupPolicyObject.GroupPolicyCoreSettings.DisplayName.'#cdata-section')
    if (-not $display) { $display = $Folder }
    [pscustomobject]@{ Path = $polDir.FullName; BackupId = $backupId; DisplayName = $display.Trim() }
}

function Import-CisGpo {
    param([string]$Zip,[string]$Folder,[string]$Name)
    $b = Resolve-GpoBackup -Zip $Zip -Folder $Folder
    $target = if ($Name) { $Name } else { "CIS - $($b.DisplayName)".Trim(' -') }
    Say "Found backup '$($b.DisplayName)'  (id $($b.BackupId))."
    Say "Importing into the domain as GPO '$target'..."
    Import-GPO -BackupId $b.BackupId -Path $b.Path -TargetName $target -CreateIfNeeded | Out-Null
    Say "GPO '$target' is in the domain."
    return $target
}

function Link-Gpo { param([string]$Name,[string]$OU)
    $existing = (Get-GPInheritance -Target $OU).GpoLinks | Where-Object { $_.DisplayName -eq $Name }
    if ($existing) { Say "GPO '$Name' is already linked to '$OU'." }
    else { New-GPLink -Name $Name -Target $OU -LinkEnabled Yes -Enforced No | Out-Null; Say "Linked '$Name' -> '$OU'." }
}
function Unlink-Gpo { param([string]$Name,[string]$OU)
    $existing = (Get-GPInheritance -Target $OU).GpoLinks | Where-Object { $_.DisplayName -eq $Name }
    if ($existing) { Remove-GPLink -Name $Name -Target $OU | Out-Null; Say "Unlinked '$Name' from '$OU'." }
    else { Say "GPO '$Name' was not linked to '$OU' - nothing to do." }
}

switch ($Action) {

    'ApplyDC' {
        Say "Hardening the Domain Controllers OU with the CIS DC policy."
        $name = Import-CisGpo -Zip $ZipPath -Folder $PolicyFolder -Name $GpoName
        Link-Gpo -Name $name -OU $dcOU
        Say "Forcing a policy refresh on this DC..."
        gpupdate /force /target:computer | Out-Null
        Say "DONE. DC01 now runs under: $name"
        Warn "CIS DC L1 tightens auth/SMB/NTLM/logon-rights - re-run your tests and compare the alerts and what still works."
    }

    'RemoveDC' {
        $name = if ($GpoName) { $GpoName } else { (Get-GPInheritance -Target $dcOU).GpoLinks | Where-Object { $_.DisplayName -like 'CIS*' } | Select-Object -First 1 -Expand DisplayName }
        if (-not $name) { Warn "No CIS GPO found linked to the Domain Controllers OU."; break }
        Unlink-Gpo -Name $name -OU $dcOU
        gpupdate /force /target:computer | Out-Null
        Say "DONE. Removed '$name' from the DC."
    }

    'ApplyWorkstation' {
        if (-not $ComputerName) { throw "ApplyWorkstation needs -ComputerName (the box to harden, e.g. WIN11)." }
        $ouDN = "OU=$WorkstationsOU,$domainDN"
        if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ouDN'" -ErrorAction SilentlyContinue)) {
            Say "Creating OU '$WorkstationsOU'..."
            New-ADOrganizationalUnit -Name $WorkstationsOU -Path $domainDN -ProtectedFromAccidentalDeletion $false
        }
        $name = Import-CisGpo -Zip $ZipPath -Folder $PolicyFolder -Name $GpoName
        Link-Gpo -Name $name -OU $ouDN

        $comp = Get-ADComputer -Identity $ComputerName -ErrorAction Stop
        if ($comp.DistinguishedName -notlike "*$ouDN") {
            Say "Moving $ComputerName into '$WorkstationsOU' so it picks up the CIS policy..."
            Move-ADObject -Identity $comp.DistinguishedName -TargetPath $ouDN
        } else { Say "$ComputerName is already in '$WorkstationsOU'." }
        Say "DONE. '$name' applies to $ComputerName (OU '$WorkstationsOU')."
        Warn "Now force a refresh ON $ComputerName (the framework runs gpupdate /force there), or reboot it, then re-run the test."
    }

    'RemoveWorkstation' {
        if (-not $ComputerName) { throw "RemoveWorkstation needs -ComputerName." }
        $comp = Get-ADComputer -Identity $ComputerName -ErrorAction Stop
        $computersContainer = "CN=Computers,$domainDN"
        if ($comp.DistinguishedName -ne "CN=$ComputerName,$computersContainer") {
            Say "Moving $ComputerName back to the default Computers container (drops the CIS OU policy)..."
            Move-ADObject -Identity $comp.DistinguishedName -TargetPath $computersContainer
        } else { Say "$ComputerName is already in the default Computers container." }
        Say "DONE. $ComputerName is back to its baseline (gpupdate /force on it to clear the managed CIS settings)."
    }
}
