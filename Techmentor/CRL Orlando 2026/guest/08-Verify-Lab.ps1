<#
.SYNOPSIS
    End-to-end readiness check for the lab (run on a Windows target).

.DESCRIPTION
    Confirms the things every detection lab depends on: domain membership,
    DNS to the DC, Defender real-time protection + onboarding, and the ASR /
    CFA posture. Prints a simple green/red summary.

.EXAMPLE
    ./08-Verify-Lab.ps1 -DomainName lab.local -DcIp 192.168.57.10
#>
[CmdletBinding()]
param(
    [string]$DomainName = 'lab.local',
    [string]$DcIp       = '192.168.57.10',
    # Member-server mode ('true' to enable): check domain join / DNS / Defender
    # AV only, and skip the endpoint-only MDE onboarding / ASR / CFA checks
    # (those apply to the victim workstations, not to a plain domain-member
    # server like SRV01). String (not [switch]) so it binds cleanly when passed
    # as CoreOnly=true through 'az vm run-command --parameters'.
    [string]$CoreOnly = 'false'
)
$core = ($CoreOnly -eq 'true')
function Check($label,[scriptblock]$test){
    try { $r = & $test } catch { $r = $false }
    $ok = [bool]$r
    $mark = if ($ok) {'[ OK ]'} else {'[FAIL]'}
    $col  = if ($ok) {'Green'} else {'Red'}
    Write-Host "$mark $label" -ForegroundColor $col
    return $ok
}

$role = if ($CoreOnly) { 'member server' } else { 'endpoint' }
Write-Host "=== Lab readiness: $env:COMPUTERNAME ($role) ===" -ForegroundColor Cyan
Check "Domain-joined to $DomainName" { (Get-CimInstance Win32_ComputerSystem).Domain -eq $DomainName }
Check "DNS resolves $DomainName via DC" { Resolve-DnsName $DomainName -Server $DcIp -ErrorAction Stop }
Check "Defender real-time protection on" { -not (Get-MpComputerStatus).RealTimeProtectionEnabled -eq $false }
if (-not $CoreOnly) {
    Check "MDE onboarded (OnboardingState = 1)" { (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows Advanced Threat Protection\Status' -ErrorAction Stop).OnboardingState -eq 1 }
    Check "Sense service running" { (Get-Service Sense -ErrorAction Stop).Status -eq 'Running' }
    Check "At least one ASR rule set" { ((Get-MpPreference).AttackSurfaceReductionRules_Ids).Count -gt 0 }
    Check "Controlled Folder Access on" { (Get-MpPreference).EnableControlledFolderAccess -ne 0 }
} else {
    Write-Host "[ -- ] Skipping MDE/ASR/CFA checks (member server, not an onboarded victim endpoint)" -ForegroundColor DarkGray
}
Write-Host "Done. Red lines above are what to fix before running the detection labs." -ForegroundColor Cyan
