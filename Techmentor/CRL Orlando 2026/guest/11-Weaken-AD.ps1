<#
.SYNOPSIS
    Seed (and then close) a set of deliberate, well-understood Active Directory
    misconfigurations in the lab domain, so detection tooling has real
    conditions to find - and so the class can watch each one get fixed.

.DESCRIPTION
    Runs IN-GUEST on DC01 (via RDP, or remotely through
    'az vm run-command invoke' from the DefXDRLabKit framework). This is a
    DEFENSIVE teaching tool for a domain you own: it does NOT attack anything.
    It only sets Active Directory objects and attributes into the insecure
    states that real, aged domains drift into, so that:

      * traditional discovery tooling (BloodHound, PingCastle, PowerView,
        Rubeus/Kerberoast collection, etc.) actually surfaces findings;
      * Defender for Identity and Defender XDR have genuine signal to raise;
      * and the class can then run -Action Harden and watch every single one
        close, with a 1:1 before/after.

    The category list mirrors the "Supported Attacks" list published by
    safebuffer/wazehell's 'vulnerable-AD' project (MIT licensed) -
    https://github.com/safebuffer/vulnerable-AD - but the seeding here is our
    own code so it is fully auditable, idempotent, and exactly reversible. No
    exploitation code is reproduced; this script only creates and removes the
    *conditions*.

    EVERY weakness has a matching Harden step that reverses it. -Action Report
    shows the current state of each category without changing anything, which
    is what you project on screen for the before/after.

.PARAMETER Action
    Weaken  - seed all of the misconfigurations (idempotent; safe to re-run)
    Harden  - close every one of them (and apply the quick-win baseline)
    Report  - show the current state of each category; change nothing

.PARAMETER DomainName
    FQDN of the lab forest (default lab.local).

.EXAMPLE
    ./11-Weaken-AD.ps1 -Action Report  -DomainName lab.local
    ./11-Weaken-AD.ps1 -Action Weaken  -DomainName lab.local
    ./11-Weaken-AD.ps1 -Action Harden  -DomainName lab.local
#>
[CmdletBinding()]
param(
    [ValidateSet('Weaken','Harden','Report')][string]$Action = 'Report',
    [string]$DomainName = 'lab.local'
)
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory -ErrorAction Stop

function Say ($m){ Write-Host "[dc01] $m"        -ForegroundColor Cyan }
function Good($m){ Write-Host "[dc01] [+] $m"    -ForegroundColor Green }
function Note($m){ Write-Host "[dc01] [*] $m"    -ForegroundColor Yellow }
function Bad ($m){ Write-Host "[dc01] [WEAK] $m" -ForegroundColor Red }

$dom       = Get-ADDomain
$dnBase    = $dom.DistinguishedName          # e.g. DC=lab,DC=local
$dnsRoot   = $dom.DNSRoot
$usersCn   = "CN=Users,$dnBase"

# Deliberately weak, in-every-wordlist values. Lab-only, documented on purpose.
$DefaultPw = 'Changeme123!'                  # the "everyone starts with this" password
$SprayPw   = 'Autumn2026!'                   # the seasonal password people actually pick
$Wwids     = @('alice.hr','bob.finance','carol.it','dan.sales','erin.ops')  # spray/default-pw set
# Extra Kerberoastable service accounts (+ svc-sql 'Summer2026!' from step 03).
# DISTINCT passwords with GRADUATED crack difficulty on purpose, so the roast
# demo isn't a single instant win - students see that a top-10 password falls
# immediately, a seasonal one needs a wordlist, and a longer passphrase may not
# crack at all in class. That's the real-world lesson, not "all accounts = 1 pw".
$RoastSvc  = @(
    @{ Sam='svc-web';    Spn="HTTP/web01.$dnsRoot";           Pw='Password1'            }  # trivial: top of any wordlist
    @{ Sam='svc-backup'; Spn="BACKUP/backup01.$dnsRoot:9999"; Pw='Falcons#2019'          }  # medium: wordlist + rules
    @{ Sam='svc-app';    Spn="APP/app01.$dnsRoot:8080";       Pw='Tr1coneElite-Winter!' }  # hard: realistic, may survive class
)
$AsrepUser = 'jsmith.preauth'                # AS-REP roastable (no Kerberos pre-auth)
$AclOwner  = 'labuser'                        # low-priv account that will get risky rights
$DcsyncUsr = 'svc-report'                     # non-admin account that will get replication rights
$DnsAdmUsr = 'labuser'                        # low-priv account added to DnsAdmins

# --- small helpers --------------------------------------------------------
function Ensure-User {
    param([string]$Sam,[string]$Pw,[string]$Display = $null,[switch]$NeverExpire)
    $u = Get-ADUser -Filter "SamAccountName -eq '$Sam'" -ErrorAction SilentlyContinue
    if (-not $u){
        $name = if ($Display){$Display}else{$Sam}
        New-ADUser -Name $name -SamAccountName $Sam -DisplayName $name `
            -AccountPassword (ConvertTo-SecureString $Pw -AsPlainText -Force) `
            -Enabled $true -PasswordNeverExpires ([bool]$NeverExpire) -Path $usersCn
        $u = Get-ADUser -Filter "SamAccountName -eq '$Sam'"
    }
    return $u
}

# GUIDs for the two DCSync extended rights on the domain head.
$RightGetChanges    = [GUID]'1131f6aa-9c07-11d1-f79f-00c04fc2dcd2'  # DS-Replication-Get-Changes
$RightGetChangesAll = [GUID]'1131f6ad-9c07-11d1-f79f-00c04fc2dcd2'  # DS-Replication-Get-Changes-All

function Get-DomainAcl { Get-Acl "AD:$dnBase" }
function Has-DcsyncAce {
    param([string]$Sid)
    (Get-DomainAcl).Access | Where-Object {
        $_.IdentityReference -is [System.Security.Principal.SecurityIdentifier] -and
        $_.IdentityReference.Value -eq $Sid -and
        ($_.ObjectType -eq $RightGetChanges -or $_.ObjectType -eq $RightGetChangesAll)
    }
}

# =========================================================================
#  WEAKEN  - seed every condition (idempotent)
# =========================================================================
function Invoke-Weaken {
    Note "Seeding deliberate AD misconfigurations in $dnsRoot. Lab-only, fully reversible with -Action Harden."

    # 1) Default password on a batch of users (CIS: force change at next logon).
    foreach ($s in $Wwids){
        Ensure-User -Sam $s -Pw $DefaultPw | Out-Null
        Set-ADUser -Identity $s -ChangePasswordAtLogon:$false -PasswordNeverExpires:$true
    }
    Bad "Default password '$DefaultPw' on: $($Wwids -join ', ')  [User Objects With Default password]"

    # 2) Password-sprayable set: a common seasonal password, no forced change.
    #    (Same accounts double as the spray target; weak + guessable on purpose.)
    foreach ($s in $Wwids[0..2]){
        Set-ADAccountPassword -Identity $s -Reset `
            -NewPassword (ConvertTo-SecureString $SprayPw -AsPlainText -Force)
    }
    Bad "Seasonal spray password '$SprayPw' on: $($Wwids[0..2] -join ', ')  [Password Spraying]"

    # 3) Password stored in the Description field (a classic help-desk habit).
    $desc = "Temp login - password is $DefaultPw - please change"
    Set-ADUser -Identity $Wwids[0] -Description $desc
    Bad "Cleartext password left in Description of '$($Wwids[0])'  [Password in Object Description]"

    # 4) Extra Kerberoastable service accounts (SPN set + weak password).
    foreach ($svc in $RoastSvc){
        Ensure-User -Sam $svc.Sam -Pw $svc.Pw -NeverExpire | Out-Null
        Set-ADAccountPassword -Identity $svc.Sam -Reset `
            -NewPassword (ConvertTo-SecureString $svc.Pw -AsPlainText -Force)
        setspn -S $svc.Spn $svc.Sam | Out-Null
    }
    Bad "Service accounts with SPNs + weak passwords: $(( $RoastSvc | ForEach-Object { $_.Sam }) -join ', ')  [Kerberoasting]"

    # 5) AS-REP roastable user (Kerberos pre-authentication turned off).
    Ensure-User -Sam $AsrepUser -Pw 'Spring2026!' -NeverExpire | Out-Null
    Set-ADAccountControl -Identity $AsrepUser -DoesNotRequirePreAuth $true
    Bad "'$AsrepUser' has 'Do not require Kerberos pre-authentication'  [AS-REP Roasting]"

    # 6) Dangerous ACL: give a low-priv user GenericAll over a sensitive group.
    #    (BloodHound lights this up as a shortest-path edge.)
    $grp = Get-ADGroup -Filter "Name -eq 'Help Desk'" -ErrorAction SilentlyContinue
    if (-not $grp){ $grp = New-ADGroup -Name 'Help Desk' -GroupScope Global -Path $usersCn -PassThru }
    $ownerSid = (Get-ADUser $AclOwner).SID
    $acl = Get-Acl "AD:$($grp.DistinguishedName)"
    $ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
        $ownerSid,'GenericAll','Allow',[guid]'00000000-0000-0000-0000-000000000000','None',
        [guid]'00000000-0000-0000-0000-000000000000')
    $acl.AddAccessRule($ace); Set-Acl "AD:$($grp.DistinguishedName)" $acl
    Bad "'$AclOwner' granted GenericAll over group 'Help Desk'  [Abusing ACLs/ACEs]"

    # 7) DnsAdmins abuse: low-priv user in DnsAdmins (DLL-load-as-SYSTEM path).
    Add-ADGroupMember -Identity 'DnsAdmins' -Members $DnsAdmUsr -ErrorAction SilentlyContinue
    Bad "'$DnsAdmUsr' added to DnsAdmins  [Abuse DnsAdmins]"

    # 8) DCSync rights for a non-admin (replication rights on the domain head).
    # The domain rejects passwords containing parts of the account name (svc-report
    # contains 'report'), so this one must not reuse that word.
    Ensure-User -Sam $DcsyncUsr -Pw 'Lantern-Rpt-2026!' -NeverExpire | Out-Null
    $sid = (Get-ADUser $DcsyncUsr).SID
    if (-not (Has-DcsyncAce $sid.Value)){
        $acl = Get-DomainAcl
        foreach ($r in @($RightGetChanges,$RightGetChangesAll)){
            $ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
                $sid,'ExtendedRight','Allow',$r,'None')
            $acl.AddAccessRule($ace)
        }
        Set-Acl "AD:$dnBase" $acl
    }
    Bad "'$DcsyncUsr' granted DS-Replication-Get-Changes[-All]  [DCSync]"

    # 9) SMB signing NOT required on the DC (reversible registry toggle).
    #    (This is also what enables SMB relay / coerced-auth paths.)
    $lan = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters'
    New-ItemProperty -Path $lan -Name 'RequireSecuritySignature' -Value 0 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $lan -Name 'EnableSecuritySignature'  -Value 0 -PropertyType DWord -Force | Out-Null
    Bad "SMB signing not required on DC01  [SMB Signing Disabled]"

    Note "Note: Silver/Golden Ticket, Pass-the-Hash and Pass-the-Ticket are *downstream* of the"
    Note "above (weak service-account keys, krbtgt, local-admin reuse). No separate seed needed -"
    Note "they become possible because of 1-9. The explainer doc covers each in detail."
    Good "Weaken complete. Run -Action Report to show the class the current state."
}

# =========================================================================
#  HARDEN  - close every condition (the 1:1 fix)
# =========================================================================
function Invoke-Harden {
    Note "Closing every seeded misconfiguration in $dnsRoot."

    # 1+2+3) Rotate the default/spray passwords, force change at next logon,
    #        and wipe the Description password.
    foreach ($s in $Wwids){
        if (Get-ADUser -Filter "SamAccountName -eq '$s'" -ErrorAction SilentlyContinue){
            Set-ADAccountPassword -Identity $s -Reset `
                -NewPassword (ConvertTo-SecureString ("Fixed-" + [guid]::NewGuid().ToString('N').Substring(0,12) + "!Aa1") -AsPlainText -Force)
            Set-ADUser -Identity $s -ChangePasswordAtLogon:$true -PasswordNeverExpires:$false -Description $null
        }
    }
    Good "Default/spray passwords rotated, change-at-logon forced, Description cleared."

    # 4) Make service-account keys un-roastable: long random password + force a
    #    change, so even if the SPN stays, the offline crack can't win.
    foreach ($svc in $RoastSvc){
        if (Get-ADUser -Filter "SamAccountName -eq '$($svc.Sam)'" -ErrorAction SilentlyContinue){
            Set-ADAccountPassword -Identity $svc.Sam -Reset `
                -NewPassword (ConvertTo-SecureString ([guid]::NewGuid().ToString()+[guid]::NewGuid().ToString()) -AsPlainText -Force)
            Set-ADUser -Identity $svc.Sam -PasswordNeverExpires:$false
        }
    }
    Good "Service-account passwords replaced with long random keys (Kerberoast crack defeated). Prefer gMSA in production."

    # 5) Re-require Kerberos pre-authentication.
    if (Get-ADUser -Filter "SamAccountName -eq '$AsrepUser'" -ErrorAction SilentlyContinue){
        Set-ADAccountControl -Identity $AsrepUser -DoesNotRequirePreAuth $false
    }
    Good "Kerberos pre-authentication re-required on '$AsrepUser'."

    # 6) Remove the dangerous GenericAll ACE from the Help Desk group.
    $grp = Get-ADGroup -Filter "Name -eq 'Help Desk'" -ErrorAction SilentlyContinue
    if ($grp){
        $ownerSid = (Get-ADUser $AclOwner).SID
        $acl = Get-Acl "AD:$($grp.DistinguishedName)"
        $acl.Access | Where-Object {
            $_.IdentityReference -is [System.Security.Principal.SecurityIdentifier] -and
            $_.IdentityReference.Value -eq $ownerSid.Value
        } | ForEach-Object { [void]$acl.RemoveAccessRule($_) }
        Set-Acl "AD:$($grp.DistinguishedName)" $acl
    }
    Good "Removed '$AclOwner' GenericAll over 'Help Desk'."

    # 7) Pull the low-priv user back out of DnsAdmins.
    Remove-ADGroupMember -Identity 'DnsAdmins' -Members $DnsAdmUsr -Confirm:$false -ErrorAction SilentlyContinue
    Good "Removed '$DnsAdmUsr' from DnsAdmins."

    # 8) Strip the DCSync replication rights.
    if (Get-ADUser -Filter "SamAccountName -eq '$DcsyncUsr'" -ErrorAction SilentlyContinue){
        $sid = (Get-ADUser $DcsyncUsr).SID
        $acl = Get-DomainAcl
        $acl.Access | Where-Object {
            $_.IdentityReference -is [System.Security.Principal.SecurityIdentifier] -and
            $_.IdentityReference.Value -eq $sid.Value -and
            ($_.ObjectType -eq $RightGetChanges -or $_.ObjectType -eq $RightGetChangesAll)
        } | ForEach-Object { [void]$acl.RemoveAccessRule($_) }
        Set-Acl "AD:$dnBase" $acl
    }
    Good "Removed DCSync replication rights from '$DcsyncUsr'."

    # 9) Re-require SMB signing on the DC.
    $lan = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters'
    New-ItemProperty -Path $lan -Name 'RequireSecuritySignature' -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $lan -Name 'EnableSecuritySignature'  -Value 1 -PropertyType DWord -Force | Out-Null
    Good "SMB signing re-required on DC01."

    Note "This is the quick-win baseline. The CIS L1 GPO (menu 8) enforces these"
    Note "domain-wide and adds account-lockout, so password spraying trips a lockout instead of succeeding."
    Good "Harden complete. Run -Action Report to show the class the clean state."
}

# =========================================================================
#  REPORT  - show current state of each category (read-only)
# =========================================================================
function Invoke-Report {
    Say "=== AD weakness report for $dnsRoot ==="

    $spn = Get-ADUser -LDAPFilter '(servicePrincipalName=*)' -Properties servicePrincipalName |
           Where-Object { $_.SamAccountName -notlike 'krbtgt' -and $_.SamAccountName -notlike '*$' }
    Say ("Kerberoastable (SPN set)        : {0}" -f (($spn.SamAccountName) -join ', '))

    $asrep = Get-ADUser -LDAPFilter '(userAccountControl:1.2.840.113556.1.4.803:=4194304)'
    Say ("AS-REP roastable (no pre-auth)  : {0}" -f (($asrep.SamAccountName) -join ', '))

    $dnsAdmins = (Get-ADGroupMember 'DnsAdmins' -ErrorAction SilentlyContinue).SamAccountName
    Say ("DnsAdmins members               : {0}" -f ($dnsAdmins -join ', '))

    $dcsync = (Get-DomainAcl).Access | Where-Object {
        $_.ObjectType -eq $RightGetChanges -or $_.ObjectType -eq $RightGetChangesAll
    } | ForEach-Object {
        try { $_.IdentityReference.Translate([System.Security.Principal.NTAccount]).Value }
        catch { $_.IdentityReference.Value }
    } | Sort-Object -Unique
    Say ("Has DCSync replication rights    : {0}" -f ($dcsync -join ', '))

    $descPw = Get-ADUser -Filter * -Properties Description |
              Where-Object { $_.Description -match '(?i)pass' }
    Say ("Password-looking Description     : {0}" -f (($descPw.SamAccountName) -join ', '))

    $lan = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters'
    $sign = (Get-ItemProperty -Path $lan -Name RequireSecuritySignature -ErrorAction SilentlyContinue).RequireSecuritySignature
    Say ("SMB signing required on DC01     : {0}" -f ($(if($sign -eq 1){'YES'}else{'NO (weak)'})))

    Say "=== end of report ==="
}

switch ($Action) {
    'Weaken' { Invoke-Weaken }
    'Harden' { Invoke-Harden }
    'Report' { Invoke-Report }
}
