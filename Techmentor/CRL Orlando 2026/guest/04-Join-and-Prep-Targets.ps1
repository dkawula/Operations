<#
.SYNOPSIS
    Point a target (WIN11 / SRV01) at the DC's DNS and join it to the lab domain.

.DESCRIPTION
    Runs in-guest on a Windows target. Sets the DC as the DNS server (so the
    domain resolves), then joins the machine to the lab domain and reboots.
    Run it on WIN11 and, if present, SRV01.

.EXAMPLE
    ./04-Join-and-Prep-Targets.ps1 -DomainName lab.local -DcIp 192.168.57.10
#>
[CmdletBinding()]
param(
    [string]$DomainName = 'lab.local',
    [string]$DcIp       = '192.168.57.10',
    # Secondary DNS: Azure-provided DNS, a fallback so the box still resolves
    # the internet if the DC is off. (Primary stays the DC so the domain
    # resolves.) Fixed Azure platform address, not a secret.
    [string]$AzureDns   = '168.63.129.16',
    [string]$JoinUser   = 'labadmin-da',          # domain account allowed to join
    [string]$JoinPassword = ''                   # passed in by the kit (random per lab, menu 2 -> P)
)
$ErrorActionPreference = 'Stop'
function Say($m){ Write-Host "[target] $m" -ForegroundColor Cyan }

Say "Setting DNS to DC $DcIp + Azure $AzureDns on the primary (gateway) adapter..."
# DNS is set PER-MACHINE (not on the VNet/subnet). Target ONLY the real primary
# NIC: the 'Up' adapter that owns the IPv4 default gateway. On an Azure VM that
# is the single routable Hyper-V NIC - targeting it avoids phantom/secondary
# adapters that have no DNS-client object (the "No MSFT_DNSClientServerAddress
# objects found with property 'InterfaceIndex'" error).
$cfg = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
       Where-Object { $_.NetAdapter.Status -eq 'Up' -and $_.IPv4DefaultGateway } |
       Select-Object -First 1
if (-not $cfg) {
    # Fallback: any Up adapter that has a usable (non-APIPA) IPv4 address.
    $cfg = Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object {
        $_.NetAdapter.Status -eq 'Up' -and
        ($_.IPv4Address | Where-Object { $_.IPAddress -notlike '169.254.*' })
    } | Select-Object -First 1
}
if (-not $cfg) { throw "No connected adapter with an IPv4 address was found." }
# Primary = DC (so the domain resolves); secondary = Azure DNS (internet / DC-off fallback).
Set-DnsClientServerAddress -InterfaceIndex $cfg.InterfaceIndex -ServerAddresses @($DcIp,$AzureDns)
Say "  NIC '$($cfg.InterfaceAlias)' (ifIndex $($cfg.InterfaceIndex)) DNS -> $DcIp (primary), $AzureDns (secondary)"
Clear-DnsClientCache -ErrorAction SilentlyContinue
Register-DnsClient -ErrorAction SilentlyContinue

Say "Waiting for the DC to answer for the domain..."
# Check the DC's own SRV record, not the bare domain name. lab.local is a real
# public domain, so an A-record lookup can succeed through Azure DNS even when the DC
# is not promoted yet. The _ldap SRV record exists only on a promoted DC, and asking
# $DcIp directly avoids the forwarder entirely.
$ok = $false
for ($i=0; $i -lt 20; $i++) {
    try {
        if (Resolve-DnsName -Name "_ldap._tcp.dc._msdcs.$DomainName" -Type SRV -Server $DcIp -ErrorAction Stop) { $ok=$true; break }
    } catch { Start-Sleep 15 }
}
if (-not $ok) { throw "The DC at $DcIp is not serving $DomainName (no _ldap SRV record). Is DC01 promoted and rebooted? Check Get-Service NTDS,DNS,Netlogon on DC01." }

if (-not $JoinPassword) { throw "No -JoinPassword given. Run this from the kit (menu 2 -> 2), which passes the lab's saved password." }
Say "Joining $DomainName (machine reboots when done)..."
$cred = New-Object System.Management.Automation.PSCredential(
    "$DomainName\$JoinUser",
    (ConvertTo-SecureString $JoinPassword -AsPlainText -Force))
Add-Computer -DomainName $DomainName -Credential $cred -Force -Restart
