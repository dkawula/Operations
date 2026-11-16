<#
.SYNOPSIS
    Install the Microsoft Defender for Identity (MDI) sensor on a domain
    controller, silently, from a staged package.

.DESCRIPTION
    Runs in-guest on DC01. MDI gives you the identity-side detections (the ones
    most of the lab's AD attacks trigger): Kerberoasting, AS-REP roasting, DCSync,
    pass-the-hash, golden ticket, reconnaissance, and more.

    The sensor package is tenant-specific and is downloaded from the Defender
    portal (Settings -> Identities -> Sensors -> Add sensor -> download the
    installer, and copy the Access Key). Because the installer is large and
    auth-gated, you STAGE it on the DC first (default C:\MDI\): put
    'Azure ATP sensor Setup.exe' there, plus either an access-key text file
    (mdi-accesskey.txt) or pass -AccessKey. This wrapper then runs the
    documented silent install and checks the sensor service.

    Command used (per Microsoft Learn):
      "Azure ATP sensor Setup.exe" /quiet NetFrameworkCommandLineArguments="/q" AccessKeyFile="..."

.EXAMPLE
    ./09-Install-MDI-Sensor.ps1 -StagePath C:\MDI
    ./09-Install-MDI-Sensor.ps1 -StagePath C:\MDI -AccessKey "<paste key>"
#>
[CmdletBinding()]
param(
    [string]$StagePath = 'C:\MDI',
    [string]$AccessKey  = ''
)
$ErrorActionPreference = 'Stop'
function Say($m){ Write-Host "[mdi] $m" -ForegroundColor Cyan }
function Warn($m){ Write-Host "[mdi] $m" -ForegroundColor Yellow }

$setup = Join-Path $StagePath 'Azure ATP sensor Setup.exe'
$keyFile = Join-Path $StagePath 'mdi-accesskey.txt'

if (-not (Test-Path $setup)) {
    throw "MDI sensor installer not found at '$setup'. Download it from the Defender portal (Settings -> Identities -> Sensors -> Add sensor), extract it, and copy 'Azure ATP sensor Setup.exe' into $StagePath on this DC."
}

Say "Found the sensor installer. Starting the silent install (this may reboot the DC if .NET is installed)..."
Push-Location $StagePath
try {
    if ($AccessKey) {
        & ".\Azure ATP sensor Setup.exe" /quiet NetFrameworkCommandLineArguments="/q" AccessKey="$AccessKey"
    } elseif (Test-Path $keyFile) {
        & ".\Azure ATP sensor Setup.exe" /quiet NetFrameworkCommandLineArguments="/q" AccessKeyFile="$keyFile"
    } else {
        throw "No access key. Put the workspace access key in '$keyFile' (plain text) or pass -AccessKey. You copy it from the same portal page you downloaded the sensor from."
    }
} finally { Pop-Location }

Start-Sleep -Seconds 25
# service is 'AATPSensor' (v2.x); the display name contains 'Azure Advanced Threat Protection Sensor'
$svc = Get-Service -Name 'AATPSensor' -ErrorAction SilentlyContinue
if (-not $svc) { $svc = Get-Service -DisplayName '*Defender for Identity*','*Azure Advanced Threat Protection*' -ErrorAction SilentlyContinue | Select-Object -First 1 }
if ($svc) {
    Say "Sensor service '$($svc.Name)' is $($svc.Status)."
    Say "Done. The DC should appear in security.microsoft.com -> Settings -> Identities -> Sensors within a few minutes."
} else {
    Warn "Sensor service not detected yet. Check the installer logs in %localappdata%\Temp, and confirm the DC can reach *.atp.azure.com."
}
Say "REMINDER: configure a Directory Service Account (DSA) in the portal (Settings -> Identities -> Microsoft Defender for Identity -> Directory service accounts) - a gMSA is recommended - or MDI can't read all the directory data it needs."
