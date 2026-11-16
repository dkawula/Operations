<#
.SYNOPSIS
    Onboard a Windows target to Microsoft Defender for Endpoint (MDE).

.DESCRIPTION
    Runs in-guest. Microsoft gives you a tenant-specific onboarding package
    (Defender portal -> Settings -> Endpoints -> Onboarding -> "Local Script").
    Download it, drop WindowsDefenderATPLocalOnboardingScript.cmd next to this
    script (or pass -PackagePath), and this wrapper runs it elevated and
    confirms the Sense service and onboarding state.

    No secret is embedded here - the onboarding package is yours and tenant-
    specific. Managed fleets would onboard via Intune/GPO instead; this is the
    lab path.

.EXAMPLE
    ./05-Onboard-Defender.ps1 -PackagePath .\WindowsDefenderATPLocalOnboardingScript.cmd
#>
[CmdletBinding()]
param(
    [string]$PackagePath = "$PSScriptRoot\WindowsDefenderATPLocalOnboardingScript.cmd"
)
$ErrorActionPreference = 'Stop'
function Say($m){ Write-Host "[onboard] $m" -ForegroundColor Cyan }

if (-not (Test-Path $PackagePath)) {
    throw "Onboarding package not found at $PackagePath. Download the 'Local Script' package from the Defender portal (Settings -> Endpoints -> Onboarding) and place it here."
}

Say "Running the MDE onboarding package..."
cmd.exe /c "`"$PackagePath`""

Say "Verifying onboarding..."
$state = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows Advanced Threat Protection\Status' -ErrorAction SilentlyContinue).OnboardingState
$sense = (Get-Service Sense -ErrorAction SilentlyContinue).Status
Say "  OnboardingState = $state (1 = onboarded)"
Say "  Sense service   = $sense (should be Running)"
if ($state -eq 1 -and $sense -eq 'Running') {
    Say "Onboarded. The device should appear in the portal (Assets -> Devices) within a few minutes."
} else {
    Write-Host "[onboard] Not fully onboarded yet - re-check in a few minutes; confirm outbound access to the Defender cloud." -ForegroundColor Yellow
}
