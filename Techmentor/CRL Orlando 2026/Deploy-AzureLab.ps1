<#
.SYNOPSIS
    Stands up the Red/Blue Defender XDR workshop lab in Azure.

.DESCRIPTION
    Provisions a single, self-contained resource group that holds the whole
    lab: a virtual network, a locked-down network security group, and the lab
    VMs (DC01, WIN11, WIN11B, KALI, and optionally SRV01).

    This mirrors the manual's "Option B - Azure" design: the range is
    internet-facing for management, so inbound RDP/SSH is locked to YOUR public
    IP only, while the Windows targets keep outbound access so their Defender
    telemetry reaches the cloud. Every VM gets a daily auto-shutdown for cost
    control, and the whole lab lives in one resource group so teardown is a
    single command (Manage-AzureLab.ps1 -Action Destroy).

    This script PROVISIONS INFRASTRUCTURE ONLY. In-guest configuration
    (promoting the domain controller, seeding the lab domain, onboarding
    Defender, ASR/CFA) is done by the numbered guest/ scripts afterward.

.NOTES
    Requires: Azure CLI (az) signed in to the target subscription (az login),
    PowerShell 7+. Run it against a subscription you own. Authorized lab use
    only. Always deallocate or destroy the lab when idle to control cost.

.EXAMPLE
    ./Deploy-AzureLab.ps1 -Location eastus
    ./Deploy-AzureLab.ps1 -Location eastus -IncludeSrv01
#>
[CmdletBinding()]
param(
    [string]$ResourceGroup = 'rg-defxdr-lab',
    [string]$Location      = 'eastus',
    [string]$VNetName      = 'vnet-lab',
    [string]$SubnetName    = 'snet-lab',
    [string]$AdminUser     = 'labadmin',

    # Your public IP (CIDR ok). Left blank, the script auto-detects it so the
    # NSG can lock inbound management to just you.
    [string]$AdminIp       = '',

    # The lab AD domain the DC will host (used by the guest config scripts).
    [string]$DomainName    = 'lab.local',

    # Optional extra VM (a plain domain-member file server).
    [switch]$IncludeSrv01,

    # VM sizes (defaults are the smallest that run comfortably).
    [string]$WinSize   = 'Standard_D2s_v5',
    [string]$KaliSize  = 'Standard_D2s_v5',

    # Kali OS/boot disk size (GB). The base Kali image ships ~30 GB; the
    # workshop installs tooling by hand, so give it room.
    [int]$KaliOsDiskGb = 100,

    # Private IPs on the lab subnet (192.168.57.0/24 to match the manual).
    [string]$AddressSpace = '192.168.57.0/24',
    [string]$IpDC01   = '192.168.57.10',
    [string]$IpWin11  = '192.168.57.20',
    [string]$IpWin11b = '192.168.57.21',
    [string]$IpSrv01  = '192.168.57.30',
    [string]$IpKali   = '192.168.57.5',

    [int]$AutoShutdownUtc = 200,   # daily deallocate time (HHmm, UTC) IF enabled
    [switch]$EnableAutoShutdown,   # off by default - VMs stay up during build
    # Defender for Cloud is LEFT ON by default (the workshop shows Azure-native
    # server alerts + secure score). Pass -QuietDefenderForCloud to exclude the
    # lab VMs (resource-level Free) if you want a silent baseline instead.
    [switch]$QuietDefenderForCloud,
    [switch]$WhatIfPlan            # print the plan and exit, create nothing
)

$ErrorActionPreference = 'Stop'
if (-not $env:PYTHONWARNINGS){ $env:PYTHONWARNINGS = 'ignore' }  # silence az bundled-Python 32-bit OpenSSL warnings
function Say($m){ Write-Host "[deploy] $m" -ForegroundColor Cyan }
function Warn($m){ Write-Host "[deploy] $m" -ForegroundColor Yellow }
$script:FailedVms = @()

# --- preflight -----------------------------------------------------------
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI 'az' not found. Install it and run 'az login' first."
}
$acct = az account show -o json 2>$null | ConvertFrom-Json
if (-not $acct) { throw "Not signed in. Run 'az login' (and 'az account set --subscription <id>')." }
Say "Subscription: $($acct.name)  ($($acct.id))"
Say "Tenant      : $($acct.tenantId)"
# Safety gate: never deploy into the wrong (customer) tenant by accident.
Warn "Confirm this is your LAB subscription, NOT a customer tenant."
$confirmSub = Read-Host "Type the subscription NAME exactly to proceed, or anything else to cancel"
if ($confirmSub -ne $acct.name) { Warn "Subscription name did not match - CANCELLED. Nothing was created."; return }

if (-not $AdminIp) {
    try { $AdminIp = (Invoke-RestMethod -Uri 'https://api.ipify.org').Trim() } catch {}
    if (-not $AdminIp) { throw "Could not auto-detect your public IP; pass -AdminIp <ip>." }
    Say "Auto-detected your public IP: $AdminIp (inbound will be locked to this)"
}

# Secure admin password (used for all VMs; change per-VM later if you prefer).
$sec = Read-Host "Set the local admin password for the lab VMs" -AsSecureString
$AdminPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
if ($AdminPass.Length -lt 12) { throw "Use a 12+ character password (Azure requires complexity)." }

# --- the plan ------------------------------------------------------------
$vms = @('DC01  (Windows Server 2025, domain controller)',
         'WIN11 (Windows 11, victim A - onboarded to Defender XDR)',
         'WIN11B (Windows 11, victim B - stock Defender AV only, NOT onboarded)',
         'KALI  (Kali Linux, attacker + C2)')
if ($IncludeSrv01)  { $vms += 'SRV01 (Windows Server 2025, member/file server)' }

Say "PLAN - resource group '$ResourceGroup' in ${Location}:"
Say "  VNet $VNetName / $SubnetName  ($AddressSpace)"
Say "  NSG  inbound RDP(3389)+SSH(22) from $AdminIp only; deny rest"
$vms | ForEach-Object { Say "  VM   $_" }
if ($EnableAutoShutdown) {
    Say "  Auto-shutdown daily at $([string]::Format('{0:00}:{1:00}', [int]($AutoShutdownUtc/100), $AutoShutdownUtc%100)) UTC"
} else {
    Say "  Auto-shutdown OFF (VMs stay up - enable it from the Lab lifecycle menu when you're done building)"
}
if ($WhatIfPlan) { Warn "WhatIfPlan set - nothing created. Re-run without -WhatIfPlan to build."; return }
Read-Host "Press Enter to CREATE these resources (this spends money), or Ctrl+C to cancel" | Out-Null

# --- resource group ------------------------------------------------------
Say "Creating resource group..."
az group create -n $ResourceGroup -l $Location -o none

# --- network -------------------------------------------------------------
Say "Creating VNet + subnet..."
az network vnet create -g $ResourceGroup -n $VNetName --address-prefix $AddressSpace `
    --subnet-name $SubnetName --subnet-prefix $AddressSpace -o none

Say "Creating NSG (inbound locked to $AdminIp)..."
$nsg = 'nsg-lab'
az network nsg create -g $ResourceGroup -n $nsg -o none
az network nsg rule create -g $ResourceGroup --nsg-name $nsg -n allow-mgmt-from-me `
    --priority 1000 --access Allow --direction Inbound --protocol Tcp `
    --source-address-prefixes $AdminIp --destination-port-ranges 3389 22 -o none
az network nsg rule create -g $ResourceGroup --nsg-name $nsg -n allow-vnet-internal `
    --priority 1100 --access Allow --direction Inbound --protocol '*' `
    --source-address-prefixes VirtualNetwork --destination-port-ranges '*' -o none
az network vnet subnet update -g $ResourceGroup --vnet-name $VNetName -n $SubnetName `
    --network-security-group $nsg -o none

# --- resolve the Kali Marketplace image (publisher is 'kali-linux', and it's a
#     plan/Marketplace offer whose terms must be accepted first). SKU names
#     change over time (kali-2024-x, kali-2025-x ...), so pick the newest that
#     actually exists in this region instead of hardcoding one. --------------
function Resolve-KaliImage {
    $pub = 'kali-linux'; $offer = 'kali'
    Say "Looking up the current Kali image SKU (publisher $pub)..."
    $skusRaw = az vm image list-skus --location $Location --publisher $pub --offer $offer --query "[].name" -o tsv 2>$null
    $skus = @($skusRaw -split "\r?\n" | Where-Object { $_ })
    # The x64 lab VM size (Standard_D2s_v5) can't run an Arm64 image, and the
    # catalog now carries '-arm64' SKUs that sort HIGHER than the x64 ones, so
    # exclude them and pick the newest remaining (x64) SKU.
    $x64 = @($skus | Where-Object { $_ -notmatch 'arm64' })
    if (-not $x64) {
        Warn "Couldn't list x64 Kali SKUs (check 'az vm image list-skus -l $Location -p $pub -f $offer'). Falling back to 'kali-2024-2'."
        $sku = 'kali-2024-2'
    } else {
        $sku = ($x64 | Sort-Object -Descending | Select-Object -First 1)
        Say "  Using newest x64 Kali SKU: $sku  (x64 available: $($x64 -join ', '); arm64 skipped)"
    }
    [pscustomobject]@{ Publisher=$pub; Offer=$offer; Sku=$sku; Urn="${pub}:${offer}:${sku}:latest" }
}

# --- helper to create one VM --------------------------------------------
function New-LabVm {
    param($Name,$Image,$Size,$PrivateIp,[switch]$Linux,
          [string]$PlanName,[string]$PlanProduct,[string]$PlanPublisher,
          [int]$OsDiskGb = 0)
    # Idempotent: if the VM already exists, skip it. This makes re-running the
    # build after one VM failed safe - only the missing VM(s) get created.
    az vm show -g $ResourceGroup -n $Name -o none 2>$null
    if ($LASTEXITCODE -eq 0) { Say "  $Name already exists - skipping."; return }
    Say "Creating VM $Name ($Image)..."
    # Plan/Marketplace image: accept terms, then pass --plan-* on create.
    if ($PlanName) {
        Say "  Accepting Marketplace terms for $PlanPublisher/$PlanProduct/$PlanName (free offer, one-time)..."
        az vm image terms accept --urn $Image -o none
        if ($LASTEXITCODE -ne 0) { Warn "  Couldn't accept image terms for $Name - skipping this VM."; $script:FailedVms += $Name; return }
    }
    $pip = "pip-$Name".ToLower()
    $nic = "nic-$Name".ToLower()
    az network public-ip create -g $ResourceGroup -n $pip --sku Standard --allocation-method Static -o none
    az network nic create -g $ResourceGroup -n $nic --vnet-name $VNetName --subnet $SubnetName `
        --private-ip-address $PrivateIp --public-ip-address $pip --network-security-group $nsg -o none
    $common = @('-g',$ResourceGroup,'-n',$Name,'--image',$Image,'--size',$Size,
                '--nics',$nic,'--admin-username',$AdminUser)
    if ($OsDiskGb -gt 0) { $common += @('--os-disk-size-gb',$OsDiskGb) }
    if ($PlanName) { $common += @('--plan-name',$PlanName,'--plan-product',$PlanProduct,'--plan-publisher',$PlanPublisher) }
    if ($Linux) {
        az vm create @common --authentication-type password --admin-password $AdminPass -o none
    } else {
        az vm create @common --admin-password $AdminPass -o none
    }
    # az is a native command: a failure sets $LASTEXITCODE but does NOT throw,
    # so check it explicitly instead of falsely reporting success.
    if ($LASTEXITCODE -ne 0) {
        Warn "  $Name FAILED to create (az exit $LASTEXITCODE). Lab continues; re-run this VM after fixing the cause."
        $script:FailedVms += $Name
        return
    }
    # daily auto-shutdown (deallocate) for cost control - ONLY if opted in,
    # so a build session isn't killed mid-way.
    if ($EnableAutoShutdown) { az vm auto-shutdown -g $ResourceGroup -n $Name --time $AutoShutdownUtc -o none 2>$null }
    # Push the Defender for Endpoint extension (MDE.Windows) at provisioning time, so
    # the Windows VMs are protected from first boot rather than waiting for Defender
    # for Cloud's own provisioning cycle. --no-wait keeps the build moving; the kit's
    # menu 4 -> E re-pushes it and waits if you need to confirm it finished.
    if (-not $Linux) {
        az vm extension set --publisher Microsoft.Azure.AzureDefenderForServers --name MDE.Windows `
            -g $ResourceGroup --vm-name $Name --enable-auto-upgrade true --no-wait -o none 2>$null
        if ($LASTEXITCODE -eq 0) { Say "  $Name : MDE.Windows extension queued (protection starts once it provisions)." }
        else { Warn "  $Name : MDE.Windows push failed. Re-run it from the kit (menu 4 -> E)." }
    }
    Say "  $Name done (private $PrivateIp)."
}

# --- the VMs -------------------------------------------------------------
New-LabVm -Name 'DC01'   -Image 'MicrosoftWindowsServer:WindowsServer:2025-datacenter-azure-edition:latest' -Size $WinSize -PrivateIp $IpDC01
New-LabVm -Name 'WIN11'  -Image 'MicrosoftWindowsDesktop:windows-11:win11-23h2-ent:latest'                  -Size $WinSize -PrivateIp $IpWin11
New-LabVm -Name 'WIN11B' -Image 'MicrosoftWindowsDesktop:windows-11:win11-23h2-ent:latest'                  -Size $WinSize -PrivateIp $IpWin11b
$kali = Resolve-KaliImage
New-LabVm -Name 'KALI' -Image $kali.Urn -Size $KaliSize -PrivateIp $IpKali -Linux -OsDiskGb $KaliOsDiskGb `
          -PlanName $kali.Sku -PlanProduct $kali.Offer -PlanPublisher $kali.Publisher
if ($IncludeSrv01)  { New-LabVm -Name 'SRV01'  -Image 'MicrosoftWindowsServer:WindowsServer:2025-datacenter-azure-edition:latest' -Size $WinSize -PrivateIp $IpSrv01 }

# --- Defender for Cloud: quiet baseline on the LAB VMs ONLY ---------------
# Resource-level Defender for Servers so only this RG's VMs are excluded; the
# rest of the subscription is never touched. Done AFTER the VMs exist (resource-
# level pricing needs the resource). Turn it back ON as a hardening demo per-VM
# (framework menu 4 -> D). Opt out of the baseline exclusion with -KeepDefenderForCloud.
if ($QuietDefenderForCloud) {
    Say "Excluding the lab VMs from Defender for Servers (resource-level Free) - quiet baseline, lab RG only..."
    $labVms = @('DC01','WIN11','WIN11B','KALI')
    if ($IncludeSrv01)  { $labVms += 'SRV01' }
    $labVms = @($labVms | Where-Object { $script:FailedVms -notcontains $_ })
    $dfcBody = Join-Path $env:TEMP 'dfc-free.json'
    '{"properties":{"pricingTier":"Free"}}' | Set-Content $dfcBody -Encoding ascii
    foreach ($vm in $labVms) {
        $u = "https://management.azure.com/subscriptions/$($acct.id)/resourceGroups/$ResourceGroup/providers/Microsoft.Compute/virtualMachines/$vm/providers/Microsoft.Security/pricings/virtualMachines?api-version=2024-01-01"
        az rest --method put --url $u --body "@$dfcBody" -o none 2>$null
        if ($LASTEXITCODE -eq 0) { Say "  $vm excluded (Free)" } else { Warn "  $vm : couldn't set resource-level pricing" }
    }
    Remove-Item $dfcBody -ErrorAction SilentlyContinue
} else {
    Say "Defender for Cloud / Servers left ON (the workshop shows Azure-native server alerts + secure score)."
    Say "  Pass -QuietDefenderForCloud if you want a silent baseline instead."
}

# --- summary -------------------------------------------------------------
Say "Lab provisioned. Public IPs:"
az vm list-ip-addresses -g $ResourceGroup -o table

Say ""
Say "NEXT STEPS (in-guest config):"
Say "  1. RDP to DC01 ($IpDC01) and run guest/03-Configure-DomainController.ps1 -DomainName $DomainName"
Say "  2. RDP to WIN11/WIN11B/SRV01 and run guest/04-Join-and-Prep-Targets.ps1 -DomainName $DomainName -DcIp $IpDC01"
Say "  3. Onboard Defender on WIN11 ONLY:  guest/05-Onboard-Defender.ps1 (WIN11B stays stock AV for the comparison)"
Say "  4. Harden WIN11 (CFA/network protection): guest/07-Harden-TamperProtection-CFA.ps1   (ASR is shown manually via GPO/Intune)"
Say "  5. KALI ($IpKali): SSH in (framework menu 3) and install your own C2 (e.g. Sliver) by hand."
Say "  Manage cost:  Manage-AzureLab.ps1 -Action Stop   (deallocate)"
Say "  Tear down:    Manage-AzureLab.ps1 -Action Destroy (delete the whole RG)"
