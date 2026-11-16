<#
.SYNOPSIS
    Promote DC01 to a new AD forest and seed the lab's detection targets.

.DESCRIPTION
    Runs IN-GUEST on DC01 (via RDP, or remotely through
    'az vm run-command invoke' from the framework). Installs AD DS + DNS,
    creates the forest, and seeds the deliberate, well-understood weaknesses
    the detection labs rely on - most importantly a service account with a
    Service Principal Name (the Kerberoasting target). These are intentional
    lab conditions in a domain you own, created so Defender for Identity has
    something to detect. Nothing here attacks anything.

    After the forest is created the machine reboots to finish promotion; run
    the seeding part (-Action Seed) once it is back up and you have signed in
    as the new domain admin.

.EXAMPLE
    # Step 1 (promotes, then reboots):
    ./03-Configure-DomainController.ps1 -Action Promote -DomainName lab.local
    # Step 2 (after reboot, as domain admin):
    ./03-Configure-DomainController.ps1 -Action Seed -DomainName lab.local
#>
[CmdletBinding()]
param(
    [ValidateSet('Promote','Seed','Dns','All')][string]$Action = 'All',
    [string]$DomainName = 'lab.local',
    [string]$NetbiosName = 'LAB',
    # This DC's own private IP - the DC points its DNS client at itself.
    [string]$DcIp = '192.168.57.10',
    # Azure-provided DNS (WireServer). The DC forwards anything its AD zones
    # can't answer here, so the DC (and the whole domain) still resolves the
    # internet. This is a fixed Azure platform address, not a secret.
    [string]$AzureDns = '168.63.129.16',
    # Safe-mode / DSRM password for the DC, and the labadmin-da Domain Admin
    # password. No defaults: the kit generates random ones per lab
    # (menu 2 -> P) and passes them in.
    [string]$SafeModePassword = '',
    [string]$DaPassword = ''
)
$ErrorActionPreference = 'Stop'
function Say($m){ Write-Host "[dc01] $m" -ForegroundColor Cyan }

function Invoke-Promote {
    # Idempotent: if this box is already a domain controller, don't try to
    # promote again (Install-ADDSForest would fail). Let the caller seed.
    $role = (Get-CimInstance Win32_ComputerSystem).DomainRole
    if ($role -ge 4) { Say "Already a domain controller (DomainRole=$role) - skipping promotion."; return }
    Say "Installing AD DS + DNS roles..."
    Install-WindowsFeature AD-Domain-Services,DNS -IncludeManagementTools | Out-Null
    Say "Promoting to a new forest: $DomainName ($NetbiosName). The machine reboots when done."
    Import-Module ADDSDeployment
    if (-not $SafeModePassword) { throw "No -SafeModePassword given. Run this from the kit (menu 2 -> 1), which generates one per lab." }
    $sm = ConvertTo-SecureString $SafeModePassword -AsPlainText -Force
    Install-ADDSForest -DomainName $DomainName -DomainNetbiosName $NetbiosName `
        -InstallDns -SafeModeAdministratorPassword $sm -Force -NoRebootOnCompletion:$false
}

function Invoke-Seed {
    Import-Module ActiveDirectory
    $dn = ($DomainName.Split('.') | ForEach-Object { "DC=$_" }) -join ','
    Say "Seeding lab accounts in $dn ..."

    # A normal low-privilege domain user (the "foothold" identity).
    if (-not (Get-ADUser -Filter "SamAccountName -eq 'labuser'")) {
        New-ADUser -Name 'labuser' -SamAccountName 'labuser' `
            -AccountPassword (ConvertTo-SecureString 'P@ssw0rd!' -AsPlainText -Force) `
            -Enabled $true -PasswordNeverExpires $true
        Say "  created labuser (low-priv foothold account)"
    }

    # THE detection target: a service account with an SPN = Kerberoastable.
    # Weak, in-a-wordlist password on purpose so the offline-crack demo is
    # fast and the Defender for Identity alert is the lesson.
    if (-not (Get-ADUser -Filter "SamAccountName -eq 'svc-sql'")) {
        New-ADUser -Name 'svc-sql' -SamAccountName 'svc-sql' `
            -AccountPassword (ConvertTo-SecureString 'Summer2026!' -AsPlainText -Force) `
            -Enabled $true -PasswordNeverExpires $true
        # Register an MSSQL SPN so the account is roastable. Use THIS DC's own
        # hostname so the SPN is correct in any forest (DC01 in lab.local, DC02
        # in redblue.lab, etc.) - Kerberoasting targets the account via its SPN.
        setspn -S "MSSQLSvc/$($env:COMPUTERNAME).$DomainName:1433" svc-sql | Out-Null
        Say "  created svc-sql + MSSQLSvc SPN (Kerberoasting detection target)"
    }

    # Optional: a second admin for lateral-movement/DCSync demos.
    if (-not $DaPassword) { throw "No -DaPassword given. Run this from the kit (menu 2 -> 1), which generates one per lab." }
    if (Get-ADUser -Filter "SamAccountName -eq 'labadmin-da'") {
        # Keep the account in step with the kit's saved password for this lab.
        Set-ADAccountPassword -Identity 'labadmin-da' -Reset -NewPassword (ConvertTo-SecureString $DaPassword -AsPlainText -Force)
        Say "  labadmin-da exists - password synced to this lab's saved value"
    } else {
        New-ADUser -Name 'labadmin-da' -SamAccountName 'labadmin-da' `
            -AccountPassword (ConvertTo-SecureString $DaPassword -AsPlainText -Force) `
            -Enabled $true -PasswordNeverExpires $true
        Add-ADGroupMember -Identity 'Domain Admins' -Members 'labadmin-da'
        Say "  created labadmin-da (Domain Admin, for the DCSync/lateral-movement labs)"
    }

    Say "Seeding complete. The DC is ready for the detection labs."

    # Make sure the DC points at itself and can forward to the internet.
    Invoke-ConfigureDns

    Say "Install the Defender for Identity sensor on DC01 next (portal -> Settings -> Identities -> Sensors)."
}

function Invoke-ConfigureDns {
    # Point THIS domain controller at itself for DNS and forward everything its
    # AD zones can't answer to the Azure-provided DNS resolver. This replaces
    # the old "set DNS on the whole VNet/subnet" approach: DNS is configured
    # per-machine instead - the DC points at itself, each member points at the
    # DC (guest/04). All standard, reversible Windows DNS configuration.
    Import-Module DnsServer -ErrorAction SilentlyContinue

    Say "Pointing this DC's DNS client at itself ($DcIp, then loopback)..."
    # Target the real primary NIC: prefer the 'Up' adapter that holds the DC's
    # own IP, then the one with the IPv4 default gateway, then any Up adapter
    # with a usable (non-APIPA) IPv4. Avoids phantom NICs with no DNS-client obj.
    $cfg = Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object {
        $_.NetAdapter.Status -eq 'Up' -and ($_.IPv4Address | Where-Object { $_.IPAddress -eq $DcIp })
    } | Select-Object -First 1
    if (-not $cfg) {
        $cfg = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
               Where-Object { $_.NetAdapter.Status -eq 'Up' -and $_.IPv4DefaultGateway } |
               Select-Object -First 1
    }
    if (-not $cfg) {
        $cfg = Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object {
            $_.NetAdapter.Status -eq 'Up' -and ($_.IPv4Address | Where-Object { $_.IPAddress -notlike '169.254.*' })
        } | Select-Object -First 1
    }
    if ($cfg) {
        try {
            Set-DnsClientServerAddress -InterfaceIndex $cfg.InterfaceIndex -ServerAddresses @($DcIp,'127.0.0.1') -ErrorAction Stop
            Say "  NIC '$($cfg.InterfaceAlias)' (ifIndex $($cfg.InterfaceIndex)) DNS -> $DcIp, 127.0.0.1"
        } catch { Say "  WARNING: couldn't set DNS on NIC '$($cfg.InterfaceAlias)': $($_.Exception.Message)" }
    } else { Say "  WARNING: no 'Up' NIC with a usable IPv4 found to set DNS on." }

    Say "Creating a DNS forwarder to Azure-provided DNS ($AzureDns)..."
    try {
        # Replace any existing forwarders with just Azure DNS; turn off root
        # hints so unresolved lookups go to the Azure resolver.
        Set-DnsServerForwarder -IPAddress $AzureDns -UseRootHint $false -ErrorAction Stop
        Say "  forwarder -> $AzureDns (root hints off)."
    } catch {
        try { Add-DnsServerForwarder -IPAddress $AzureDns -ErrorAction Stop; Say "  forwarder added -> $AzureDns." }
        catch { Say "  WARNING: could not set DNS forwarder: $($_.Exception.Message)" }
    }

    Clear-DnsClientCache -ErrorAction SilentlyContinue
    Register-DnsClient -ErrorAction SilentlyContinue
    Say "DC DNS configured: resolves $DomainName locally, forwards the rest to $AzureDns."
}

switch ($Action) {
    'Promote' { Invoke-Promote }
    'Seed'    { Invoke-Seed }
    'Dns'     { Invoke-ConfigureDns }
    'All'     { Say "Running Promote now; after the reboot, re-run with -Action Seed."; Invoke-Promote }
}
