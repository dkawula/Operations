<#
.SYNOPSIS
    Turn on Controlled Folder Access, network protection, and report Tamper
    Protection status - the ransomware-defense posture for Lab 5.

.DESCRIPTION
    Runs in-guest on WIN11. Enables Controlled Folder Access (CFA) protecting a
    "crown jewels" folder so the benign ransomware simulator is blocked, turns
    network protection to block, and reports Tamper Protection (which is set in
    the portal / Intune, not locally, in the modern platform). All defensive.

.EXAMPLE
    ./07-Harden-TamperProtection-CFA.ps1 -ProtectedFolder C:\CrownJewels
#>
[CmdletBinding()]
param(
    [string]$ProtectedFolder = 'C:\CrownJewels',
    [ValidateSet('Block','Audit','Off')][string]$Mode = 'Block'
)
$ErrorActionPreference = 'Stop'
function Say($m){ Write-Host "[harden] $m" -ForegroundColor Cyan }

if (-not (Test-Path $ProtectedFolder)) {
    New-Item -ItemType Directory -Path $ProtectedFolder | Out-Null
    "lab crown-jewel document" | Out-File (Join-Path $ProtectedFolder 'important.txt')
    Say "Created $ProtectedFolder with a sample document."
}

$cfa = switch ($Mode) { 'Block' {'Enabled'} 'Audit' {'AuditMode'} 'Off' {'Disabled'} }
Say "Setting Controlled Folder Access = $cfa ..."
Set-MpPreference -EnableControlledFolderAccess $cfa
Add-MpPreference -ControlledFolderAccessProtectedFolders $ProtectedFolder

Say "Enabling network protection ($Mode)..."
Set-MpPreference -EnableNetworkProtection $(if ($Mode -eq 'Off'){'Disabled'}elseif($Mode -eq 'Audit'){'AuditMode'}else{'Enabled'})

$tp = (Get-MpComputerStatus).IsTamperProtected
Say "Tamper Protection currently: $tp  (manage it in the Defender portal / Intune, not locally)."
Say "Done. With CFA on, the benign ransomware simulator is blocked from $ProtectedFolder and logged in DeviceEvents."
