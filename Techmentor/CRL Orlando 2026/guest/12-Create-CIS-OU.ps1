<#
.SYNOPSIS
    Create the CIS-Hardened-Workstations OU on DC01. Creates the OU only:
    no GPO is imported or linked, so each CIS policy can be linked by hand.

.EXAMPLE
    ./12-Create-CIS-OU.ps1 -DomainName lab.local -OuName CIS-Hardened-Workstations
#>
[CmdletBinding()]
param(
    [string]$DomainName = 'lab.local',
    [string]$OuName     = 'CIS-Hardened-Workstations'
)
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory
function Say($m){ Write-Host "[dc01] $m" -ForegroundColor Cyan }

$domainDN = 'DC=' + ($DomainName -replace '\.',',DC=')
$ouDN     = "OU=$OuName,$domainDN"
if (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ouDN'" -ErrorAction SilentlyContinue) {
    Say "OU '$OuName' already exists - nothing to do."
} else {
    New-ADOrganizationalUnit -Name $OuName -Path $domainDN -ProtectedFromAccidentalDeletion $false
    Say "Created OU '$OuName' at $ouDN. No GPOs are linked to it."
}
