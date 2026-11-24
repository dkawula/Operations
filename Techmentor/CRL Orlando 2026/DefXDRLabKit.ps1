<#
.SYNOPSIS
    DefXDRLabKit - a guided framework to build, configure, demo, and tear down
    the Red/Blue Microsoft Defender XDR lab in Azure, entirely from your
    Windows machine. Built for presenting live: every step narrates what it is
    doing and ECHOES the actual command on screen before it runs it, so the
    workshop audience sees exactly what you are doing - and you never have to
    remember or re-type a command.

.DESCRIPTION
    One menu-driven orchestrator over the whole lab, grouped the way you run a
    workshop:

        1) Lab lifecycle        - build / start / stop / status / destroy
        2) Lab configuration    - domain, DNS, AD weaken/harden, hardened OU
        3) Attacker box (Kali)  - SSH into a base Kali VM; bring your own C2
        4) Blue-team / Defender - onboard, CFA, MDI (+ gMSA), Defender for Cloud
        5) Run & re-run tests   - fire a technique by ATT&CK ID, or re-run all,
                                  then flip to the portal and show the detection
        6) Advanced detection   - Microsoft Sentinel + the hunting pack
        7) CIS benchmark        - apply your CIS GPO zips + the 4-way matrix

    It pushes in-guest configuration into each VM remotely through
    'az vm run-command' (so you never need direct RDP/SSH for setup), and runs
    every technique via CITED PUBLIC runners (Atomic Red Team) invoked by ATT&CK
    ID on the target to GENERATE telemetry - there is no exploit code in this
    framework. Everything runs in a range you own, for detection training.

    The PowerShell core also works headless (-Action ...) so an Electron front
    end (the "Demo Theater") can drive the exact same steps.

.NOTES
    Requires: Azure CLI (az) + PowerShell 7 on your Windows box; 'az login' to a
    subscription you own. The guest/ folder must sit beside this file.

.EXAMPLE
    ./DefXDRLabKit.ps1                        # interactive, grouped menu
    ./DefXDRLabKit.ps1 -Action Deploy         # headless (for the Electron app)
    ./DefXDRLabKit.ps1 -Action Invoke -TechniqueId T-04   # headless single technique
#>
[CmdletBinding()]
param(
    [ValidateSet('Menu','Prereqs','AzLogin','Configure','Deploy','Start','Stop','Status','Destroy','AutoShutdown','AuthorizeIp','BootDiag',
                 'ConfigureDC','JoinTargets','Verify','WeakenAD','HardenAD','ReportAD','HardenedOU','MoveToHardenedOU','DefenderBaselineGpo','CreateCisOU',
                 'Ssh','BackdoorLogin','BackdoorLoginScoped','BackdoorWhoami','BackdoorShell','BackdoorRunKit','BackdoorLogoff','BackdoorRemove',
                 'GetOnboarding','Onboard','Harden','VerifyDefense',
                 'DefenderCloudOn','DefenderCloudOff','PushMdeExtension',
                 'CloudSeed','CloudHunt','CloudStatus','CloudRemove',
                 'GetMdi','InstallMdi','MdiGmsa','DeploySentinel','OpenHunting','HuntingPack','Hunt','HuntSetup',
                 'CisApplyDC','CisRemoveDC','CisApplyWks','CisRemoveWks','CopyCisToDc','CisSplit','Matrix',
                 'Invoke','InvokeAll','KqlFolder',
                 'DeployCopy2','CompleteCopy2','DestroyCopy2')]
    [string]$Action = 'Menu',
    [string]$TechniqueId = 'T-04',
    # Which lab copy to drive: 1 = the original (rg-defxdr-lab), 2 = the isolated
    # second copy (rg-defxdr-lab-2). Every step uses the active copy's settings.
    [ValidateSet('1','2')]
    [string]$Lab = '1',
    [switch]$NonInteractive
)

$ErrorActionPreference = 'Stop'
$HERE   = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
$CFGDIR = Join-Path $env:USERPROFILE '.defxdrlab'
# Copy 1 keeps the original config.json; copy 2 has its own config-2.json, so the
# two labs never share a resource group, workspace or any saved setting.
function Get-CfgFile([string]$n){ if ($n -eq '2') { Join-Path $CFGDIR 'config-2.json' } else { Join-Path $CFGDIR 'config.json' } }
$script:ActiveLab = $Lab
$CFGFILE= Get-CfgFile $Lab
# Logs go in a 'logs' folder BESIDE this script (i.e. inside the synced
# lab-package folder) so they're visible without extra access; falls back to
# ~\.defxdrlab\logs if the script folder isn't writable.
$LOGDIR = Join-Path $HERE 'logs'
try { New-Item -ItemType Directory -Force -Path $LOGDIR -ErrorAction Stop | Out-Null }
catch { $LOGDIR = Join-Path $CFGDIR 'logs' }
$script:LogFile   = $null   # full console transcript (Start-Transcript owns this handle)
$script:EventFile = $null   # tagged [CMD]/[STEP]/[RESULT]/[ERROR] markers (separate file - no lock fight)

# --- run logging ---------------------------------------------------------
# Two files per run in logs\: <stamp>.log is the full console transcript;
# <stamp>.events.log is a clean, greppable marker trail. They're kept separate
# because the transcript holds an exclusive handle on its own file, so writing
# markers into it would collide ("file in use by another process").
function Log($m,[string]$level='INFO'){
    if (-not $script:EventFile){ return }
    $line = "[{0:yyyy-MM-dd HH:mm:ss}] [{1}] {2}" -f (Get-Date), $level, $m
    try { Add-Content -LiteralPath $script:EventFile -Value $line -Encoding utf8 -ErrorAction Stop } catch {}
}
function Start-Logging {
    # Silence Azure CLI's bundled-Python cosmetic warnings (e.g. the 32-bit
    # OpenSSL/cryptography UserWarning) so they don't clutter the screen/log.
    if (-not $env:PYTHONWARNINGS){ $env:PYTHONWARNINGS = 'ignore' }
    try {
        New-Item -ItemType Directory -Force -Path $LOGDIR | Out-Null
        $stamp = "{0:yyyyMMdd-HHmmss}" -f (Get-Date)
        $script:LogFile   = Join-Path $LOGDIR "defxdrlab-$stamp.log"
        $script:EventFile = Join-Path $LOGDIR "defxdrlab-$stamp.events.log"
        try { Start-Transcript -Path $script:LogFile -Append | Out-Null } catch {}
        Log "DefXDRLabKit run started (PID $PID, host $($env:COMPUTERNAME), user $($env:USERNAME))" 'START'
    } catch { Write-Host "  (logging unavailable: $($_.Exception.Message))" -ForegroundColor DarkYellow }
}
function Stop-Logging { try { Stop-Transcript | Out-Null } catch {} }

# --- presentation helpers ------------------------------------------------
# Each also writes a clean marker to the log so the transcript stays greppable.
function Ok($m){ Write-Host "  $m" -ForegroundColor Green; Log $m 'OK' }
function Info($m){ Write-Host "  $m" -ForegroundColor Cyan; Log $m 'INFO' }
function Warn($m){ Write-Host "  $m" -ForegroundColor Yellow; Log $m 'WARN' }
function Narrate($m){ Write-Host "`n  >> $m`n" -ForegroundColor Magenta; Log $m 'STEP' }
# ShowCmd is the whole point of the demo: print the command on screen, in a
# distinct colour, EXACTLY as it will run, so the audience follows along.
function ShowCmd($cmd){ Write-Host "  `$ $cmd" -ForegroundColor White -BackgroundColor DarkBlue; Log $cmd 'CMD' }

function Banner {
@"

  ====================================================================
   DefXDRLabKit   -   Red & Blue Teaming with Microsoft Defender XDR
   Build -> configure -> attack -> detect -> harden -> tear down,
   driven from your Windows box.   Every command shown on screen.
   Authorized lab use only.
  ====================================================================
"@ | Write-Host -ForegroundColor Cyan
}

function Pause { if (-not $NonInteractive){ Read-Host "`n  [Enter] to return to the menu" | Out-Null } }

# --- config --------------------------------------------------------------
$DefaultCfg = [ordered]@{
    ResourceGroup = 'rg-defxdr-lab'
    Location      = 'eastus'
    DomainName    = 'lab.local'
    NetbiosName   = 'LAB'
    DcIp          = '192.168.57.10'
    Win11         = 'WIN11'    # victim A - onboarded to Defender XDR
    Win11b        = 'WIN11B'   # victim B - stock Defender AV only, NOT onboarded
    AttackTarget  = 'WIN11'    # which victim the attack steps hit (toggle in menu 5)
    Dc            = 'DC01'
    Kali          = 'KALI'
    AdminUser     = 'labadmin'
    IncludeSrv01  = $false
    HardenedOU    = 'Hardened Systems'   # OU + simple hardening GPO - demo: move a box in, re-attack
    WorkspaceName = 'law-defxdr-lab'   # Sentinel / Log Analytics workspace
    MdiStagePath  = 'C:\MDI'           # where the MDI sensor installer is staged on DC01
    SubscriptionId   = ''   # the LAB subscription; confirmed at startup / before deploy
    SubscriptionName = ''
    # --- CIS Benchmark GPOs (operator supplies the zips; nothing CIS is bundled)
    CisServerZip   = ''        # path on YOUR Windows box to the CIS Server benchmark GPO zip
    CisWin11Zip    = ''        # path on YOUR Windows box to the CIS Windows 11 benchmark GPO zip
    CisDcPolicy    = 'DC-L1'   # named policy folder inside the Server zip to apply to the DCs
    CisMsPolicy    = 'MS-L1'   # Member Server policy folder inside the Server zip (used by the split, menu 7->8)
    CisWin11Policy = 'COMP-L1' # named policy folder inside the Win11 zip to apply to workstations
    CisWorkstationsOU = 'CIS-Hardened-Workstations'
    CisStagePath   = 'C:\CIS'  # where the chosen policy zip is staged on DC01
}
function Load-Cfg {
    if (Test-Path $CFGFILE) {
        $j = Get-Content $CFGFILE -Raw | ConvertFrom-Json
        $c = [ordered]@{}; $DefaultCfg.Keys | ForEach-Object { $c[$_] = if ($null -ne $j.$_) { $j.$_ } else { $DefaultCfg[$_] } }
        return $c
    }
    $c = [ordered]@{}; $DefaultCfg.Keys | ForEach-Object { $c[$_] = $DefaultCfg[$_] }
    return $c
}
function Save-Cfg($c){ New-Item -ItemType Directory -Force -Path $CFGDIR | Out-Null; ($c | ConvertTo-Json) | Set-Content $CFGFILE }

# --- lab copies (1 = original, 2 = isolated second copy in the same tenant) ---
# Copy 2 starts as a clone of copy 1's settings (same subscription, region,
# domain, VM names, IP plan) with '-2' appended to the resource group and the
# Sentinel workspace. Re-using 192.168.57.0/24 is safe: each copy gets its OWN
# VNet in its OWN resource group and the kit never peers or connects them, so
# the two address spaces can't see each other.
function Get-Lab1Rg {
    $f = Get-CfgFile '1'
    if (Test-Path $f) { $j = Get-Content $f -Raw | ConvertFrom-Json; if ($j.ResourceGroup) { return $j.ResourceGroup } }
    return $DefaultCfg.ResourceGroup
}
function New-Copy2Cfg {
    $f = Get-CfgFile '1'
    $base = if (Test-Path $f) { Get-Content $f -Raw | ConvertFrom-Json } else { $null }
    $c = [ordered]@{}
    $DefaultCfg.Keys | ForEach-Object { $c[$_] = if ($base -and $null -ne $base.$_) { $base.$_ } else { $DefaultCfg[$_] } }
    $c.ResourceGroup = ($c.ResourceGroup -replace '-2$','') + '-2'
    $c.WorkspaceName = ($c.WorkspaceName -replace '-2$','') + '-2'
    return $c
}
function Get-Copy2Rg {
    $f = Get-CfgFile '2'
    if (Test-Path $f) { $j = Get-Content $f -Raw | ConvertFrom-Json; if ($j.ResourceGroup) { return $j.ResourceGroup } }
    return (New-Copy2Cfg).ResourceGroup
}
function Switch-Lab([string]$n){
    $script:ActiveLab = $n
    $script:CFGFILE   = Get-CfgFile $n
    if ($n -eq '2' -and -not (Test-Path $script:CFGFILE)) { $script:CFG = New-Copy2Cfg; Save-Cfg $script:CFG }
    else { $script:CFG = Load-Cfg }
}
function Step-SwitchLab {
    $other = if ($script:ActiveLab -eq '2') { '1' } else { '2' }
    Switch-Lab $other
    Ok "Active lab is now COPY $($script:ActiveLab): $($CFG.ResourceGroup) ($($CFG.DomainName)). Every menu now acts on this copy."
}
Switch-Lab $Lab

# --- remoting helpers (drive the VMs from Windows via the Azure agent) ----
# Each one prints the az command first (ShowCmd), so the "remoting into the
# client via our custom shell" is visible to the room.
# az can print WARNING/deprecation lines to stderr (notably the 32-bit-az
# OpenSSL/cryptography warning). With '2>&1' those get merged ahead of the JSON
# and break ConvertFrom-Json ("Unexpected character W at position 0"). This
# strips anything before the first JSON bracket, then parses - so a stray
# warning never kills a run-command result.
function ConvertFrom-RunCmdJson($raw){
    if ($null -eq $raw){ return $null }
    $s = ($raw | Out-String)
    $i = $s.IndexOfAny([char[]]@('{','['))
    if ($i -lt 0){ return $null }
    try { return ($s.Substring($i) | ConvertFrom-Json) } catch { return $null }
}
function Invoke-OnWindowsVm($VmName,$ScriptPath,[string[]]$Params){
    Info "Remoting into $VmName and running $(Split-Path -Leaf $ScriptPath)..."
    ShowCmd "az vm run-command invoke -g $($CFG.ResourceGroup) -n $VmName --command-id RunPowerShellScript --scripts @$(Split-Path -Leaf $ScriptPath)"
    $argv = @('vm','run-command','invoke','-g',$CFG.ResourceGroup,'-n',$VmName,
              '--command-id','RunPowerShellScript','--scripts',"@$ScriptPath")
    # az run-command needs parameters as Name=Value tokens; callers pass them as
    # alternating ('Name',value,'Name',value), so fold each pair into 'Name=value'.
    # (Passing them as separate tokens makes az rename them arg1/arg2 and the
    #  guest script rejects '-arg1'.)
    if ($Params){
        $pairs = @()
        for ($i=0; $i -lt $Params.Count; $i += 2){
            if ($i+1 -lt $Params.Count){ $pairs += ("{0}={1}" -f $Params[$i], $Params[$i+1]) }
        }
        if ($pairs){ $argv += @('--parameters') + $pairs }
    }
    try {
        $raw = az @argv -o json 2>&1
        if ($LASTEXITCODE -ne 0){ Warn "az run-command on $VmName exited $LASTEXITCODE."; Log "az run-command $VmName exit=$LASTEXITCODE :: $raw" 'ERROR'; return }
        $obj = ConvertFrom-RunCmdJson $raw
        if ($null -eq $obj){ Warn "Couldn't parse the run-command result from $VmName."; Log "run-command $VmName unparseable :: $raw" 'ERROR'; return }
        $out = $obj.value | ForEach-Object { $_.message }
        $out | Write-Host
        Log "RESULT $VmName / $(Split-Path -Leaf $ScriptPath):`n$($out -join "`n")" 'RESULT'
    } catch { Warn "run-command on $VmName failed: $($_.Exception.Message)"; Log "run-command $VmName EXCEPTION: $($_.Exception.Message)" 'ERROR' }
}
function Invoke-OnLinuxVm($VmName,$ScriptPath){
    Info "Remoting into $VmName and running $(Split-Path -Leaf $ScriptPath)..."
    ShowCmd "az vm run-command invoke -g $($CFG.ResourceGroup) -n $VmName --command-id RunShellScript --scripts @$(Split-Path -Leaf $ScriptPath)"
    try {
        $raw = az vm run-command invoke -g $CFG.ResourceGroup -n $VmName --command-id RunShellScript --scripts "@$ScriptPath" -o json 2>&1
        if ($LASTEXITCODE -ne 0){ Warn "az run-command on $VmName exited $LASTEXITCODE."; Log "az run-command $VmName exit=$LASTEXITCODE :: $raw" 'ERROR'; return }
        $obj = ConvertFrom-RunCmdJson $raw
        if ($null -eq $obj){ Warn "Couldn't parse the run-command result from $VmName."; Log "run-command $VmName unparseable :: $raw" 'ERROR'; return }
        $out = $obj.value | ForEach-Object { $_.message }
        $out | Write-Host
        Log "RESULT $VmName / $(Split-Path -Leaf $ScriptPath):`n$($out -join "`n")" 'RESULT'
    } catch { Warn "run-command on $VmName failed: $($_.Exception.Message)"; Log "run-command $VmName EXCEPTION: $($_.Exception.Message)" 'ERROR' }
}
# Run a single inline shell command on a Linux VM (as root) and RETURN its output
# as a string - for little reads like a service status / fetching a value,
# without needing a .sh file on disk. Quiet suppresses the echoed az line.
function Invoke-LinuxCmd($VmName,[string]$Cmd,[switch]$Quiet){
    $tmp = Join-Path $env:TEMP ("lx-" + [guid]::NewGuid().ToString('N').Substring(0,8) + '.sh')
    $Cmd | Set-Content $tmp -Encoding utf8
    if (-not $Quiet){ ShowCmd "az vm run-command invoke -g $($CFG.ResourceGroup) -n $VmName --command-id RunShellScript --scripts <inline>" }
    $msg = ''
    try {
        $raw = az vm run-command invoke -g $CFG.ResourceGroup -n $VmName --command-id RunShellScript --scripts "@$tmp" -o json 2>&1
        if ($LASTEXITCODE -eq 0){
            $obj = ConvertFrom-RunCmdJson $raw
            if ($null -ne $obj){ $msg = ($obj.value | ForEach-Object { $_.message }) -join "`n" }
            else { Warn "Couldn't parse the run-command result from $VmName."; Log "Invoke-LinuxCmd $VmName unparseable :: $raw" 'ERROR' }
        }
        else { Warn "run-command on $VmName exited $LASTEXITCODE."; Log "Invoke-LinuxCmd $VmName exit=$LASTEXITCODE :: $raw" 'ERROR' }
    } catch { Warn "run-command on $VmName failed: $($_.Exception.Message)" }
    Remove-Item $tmp -ErrorAction SilentlyContinue
    return $msg
}
# Push a (small) local file onto a Windows VM with no RDP/SSH: base64 it into a
# tiny staging script and run that via the Azure agent. Good for GPO backup zips
# (tens of KB); not for large installers (stage those manually - see MDI).
function Push-FileToVm($VmName,$LocalPath,$RemotePath){
    if (-not (Test-Path $LocalPath)) { Warn "File not found: $LocalPath"; return $false }
    $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($LocalPath))
    $kb  = [math]::Round($b64.Length/1KB)
    Info "Uploading $(Split-Path -Leaf $LocalPath) to ${VmName}:$RemotePath (~${kb} KB, base64 over the Azure agent)..."
    ShowCmd "az vm run-command invoke -g $($CFG.ResourceGroup) -n $VmName --command-id RunPowerShellScript --scripts <decode base64 -> $RemotePath>"
    $dir = Split-Path -Parent $RemotePath
    $stage = @"
New-Item -ItemType Directory -Force -Path '$dir' | Out-Null
[IO.File]::WriteAllBytes('$RemotePath', [Convert]::FromBase64String('$b64'))
if (Test-Path '$RemotePath') { "staged $RemotePath (" + (Get-Item '$RemotePath').Length + " bytes)" } else { "FAILED to stage $RemotePath" }
"@
    $tmp = Join-Path $env:TEMP ("push-" + [guid]::NewGuid().ToString('N').Substring(0,8) + '.ps1')
    $stage | Set-Content $tmp -Encoding utf8
    az vm run-command invoke -g $CFG.ResourceGroup -n $VmName `
        --command-id RunPowerShellScript --scripts "@$tmp" -o json |
        ConvertFrom-Json | ForEach-Object { $_.value.message } | Write-Host
    Remove-Item $tmp -ErrorAction SilentlyContinue
    return $true
}
# Force a Group Policy refresh on a Windows VM (so a CIS GPO applies now).
function Invoke-GpUpdate($VmName){
    Info "Forcing a Group Policy refresh on $VmName..."
    ShowCmd "gpupdate /force   # on $VmName, via run-command"
    $tmp = Join-Path $env:TEMP 'gpupdate.ps1'
    "gpupdate /force | Out-String" | Set-Content $tmp -Encoding utf8
    Invoke-OnWindowsVm $VmName $tmp $null
}

# --- the cited-technique map (ATT&CK IDs run via public runners) ----------
$TechniqueMap = [ordered]@{
    'T-02' = @{ Attack='T1003.001'; Name='Credential access from LSASS' }
    'T-03' = @{ Attack='T1087';     Name='AD account discovery (BloodHound)' }
    'T-04' = @{ Attack='T1558.003'; Name='Kerberoasting (svc-sql)' }
    'T-05' = @{ Attack='T1558.004'; Name='AS-REP roasting' }
    'T-07' = @{ Attack='T1550.002'; Name='Pass-the-hash lateral movement' }
    'T-09' = @{ Attack='T1003.006'; Name='DCSync' }
    'T-11' = @{ Attack='T1486';     Name='Ransomware behaviour (benign)' }
}

# =========================================================================
#  STEPS
# =========================================================================

# --- 1) lab lifecycle ----------------------------------------------------
# Pre-req checker: prints a pass/fail table with the exact fix command for each
# miss. Runs at startup and on menu 9. Returns $true if all HARD pre-reqs pass.
function Test-Prereqs {
    param([switch]$Quiet)
    Narrate "Checking prerequisites on your Windows box."
    $checks = @()

    # --- PowerShell 7+ (HARD) ---
    $psOk = $PSVersionTable.PSVersion.Major -ge 7
    $checks += [pscustomobject]@{ Name='PowerShell 7+'; Required=$true; Ok=$psOk
        Detail = if ($psOk){ "v$($PSVersionTable.PSVersion)" } else { "v$($PSVersionTable.PSVersion) - too old" }
        Fix='winget install --id Microsoft.PowerShell  (or github.com/PowerShell/PowerShell/releases), then relaunch in "pwsh"' }

    # --- Azure CLI (HARD) ---
    $az = Get-Command az -ErrorAction SilentlyContinue
    $azVer = ''
    if ($az){ try { $azVer = (az version -o json 2>$null | ConvertFrom-Json).'azure-cli' } catch {} }
    $checks += [pscustomobject]@{ Name='Azure CLI (az)'; Required=$true; Ok=[bool]$az
        Detail = if ($az){ "v$azVer" } else { 'not found on PATH' }
        Fix='winget install --id Microsoft.AzureCLI  (or aka.ms/installazurecliwindows), then reopen the terminal' }

    # --- az bitness (SOFT - 32-bit az spams the OpenSSL/cryptography warning) ---
    if ($az) {
        $is32 = $az.Source -match '\(x86\)'   # 32-bit az installs under 'Program Files (x86)'
        $checks += [pscustomobject]@{ Name='Azure CLI 64-bit (optional)'; Required=$false; Ok=(-not $is32)
            Detail = if ($is32){ "32-bit build at $($az.Source) - causes the OpenSSL/cryptography warning" } else { "64-bit ($($az.Source))" }
            Fix='Uninstall the 32-bit Azure CLI, then install 64-bit: winget install --id Microsoft.AzureCLI (or the 64-bit MSI at aka.ms/installazurecliwindows). Cosmetic only - deploys work either way.' }
    }

    # --- az signed in (HARD) ---
    $acct = $null; if ($az){ try { $acct = az account show -o json 2>$null | ConvertFrom-Json } catch {} }
    $checks += [pscustomobject]@{ Name='Azure sign-in'; Required=$true; Ok=[bool]$acct
        Detail = if ($acct){ "$($acct.name)" } else { 'not signed in' }
        Fix='Menu L (Azure login / switch subscription) - signs in and picks your LAB subscription' }

    # --- Git (SOFT - only needed to clone the repo) ---
    $git = Get-Command git -ErrorAction SilentlyContinue
    $checks += [pscustomobject]@{ Name='Git (optional)'; Required=$false; Ok=[bool]$git
        Detail = if ($git){ (git --version) } else { 'not found - only needed to clone this repo' }
        Fix='winget install --id Git.Git  (optional)' }

    # --- Python 3 (SOFT - not needed by the Windows kit) ---
    $py = Get-Command python -ErrorAction SilentlyContinue; if (-not $py){ $py = Get-Command python3 -ErrorAction SilentlyContinue }
    $pyVer = ''; if ($py){ try { $pyVer = (& $py.Source --version 2>&1) } catch {} }
    $checks += [pscustomobject]@{ Name='Python 3 (optional)'; Required=$false; Ok=[bool]$py
        Detail = if ($py){ "$pyVer" } else { 'not found - NOT required for the Windows kit' }
        Fix='winget install --id Python.Python.3.12  (optional; python.org) - only if you run Python tooling locally' }

    # --- Microsoft.Graph.Authentication module (SOFT - only the Graph-based hunting menus need it) ---
    $mg = Get-Module -ListAvailable -Name Microsoft.Graph.Authentication | Sort-Object Version -Descending | Select-Object -First 1
    $checks += [pscustomobject]@{ Name='Microsoft.Graph.Authentication (module)'; Required=$false; Ok=[bool]$mg
        Detail = if ($mg){ "v$($mg.Version)" } else { 'not installed - needed only for Graph-based advanced hunting (Blue / hunting-pack menus)' }
        Fix='Install-Module Microsoft.Graph.Authentication -Scope CurrentUser  (the prereqs installer, menu 9, can do this for you)' }

    # expose the full result so the installer (Step-Prereqs -> Install-Prereqs) can act on it
    $script:LastPrereqChecks = $checks

    # --- render ---
    Write-Host ""
    Write-Host ("  {0,-22} {1,-8} {2}" -f 'Prerequisite','Status','Detail') -ForegroundColor Yellow
    Write-Host ("  {0,-22} {1,-8} {2}" -f ('-'*22),'------',('-'*34)) -ForegroundColor DarkGray
    foreach ($c in $checks){
        $tag = if ($c.Ok){ '  OK ' } elseif ($c.Required){ ' FAIL' } else { ' n/a ' }
        $col = if ($c.Ok){ 'Green' } elseif ($c.Required){ 'Red' } else { 'DarkYellow' }
        Write-Host ("  {0,-22} " -f $c.Name) -NoNewline
        Write-Host ("{0,-8}" -f $tag) -ForegroundColor $col -NoNewline
        Write-Host (" {0}" -f $c.Detail)
        Log ("PREREQ {0} = {1} ({2})" -f $c.Name, $(if($c.Ok){'OK'}elseif($c.Required){'FAIL'}else{'optional-missing'}), $c.Detail) 'STEP'
    }
    $hardFails = $checks | Where-Object { $_.Required -and -not $_.Ok }
    $softMiss  = $checks | Where-Object { -not $_.Required -and -not $_.Ok }
    Write-Host ""
    if ($hardFails){
        Warn "Fix these before you build:"
        foreach ($f in $hardFails){ Write-Host "    * $($f.Name): $($f.Fix)" -ForegroundColor White }
    } else { Ok "All required prerequisites are present." }
    if ($softMiss -and -not $Quiet){
        Write-Host "  Optional (install only if you need them):" -ForegroundColor DarkGray
        foreach ($f in $softMiss){ Write-Host "    - $($f.Name): $($f.Fix)" -ForegroundColor DarkGray }
    }
    if ($acct){ Show-AzContext | Out-Null }
    return (-not $hardFails)
}
# Names here are the ONLY prerequisites the auto-installer will touch, mapped to
# how it installs each one: a winget package id, or a PowerShell module name.
$script:PrereqInstallMap = [ordered]@{
    'PowerShell 7+'                           = @{ Winget = 'Microsoft.PowerShell' }
    'Azure CLI (az)'                          = @{ Winget = 'Microsoft.AzureCLI' }
    'Git (optional)'                          = @{ Winget = 'Git.Git' }
    'Python 3 (optional)'                     = @{ Winget = 'Python.Python.3.12' }
    'Microsoft.Graph.Authentication (module)' = @{ Module = 'Microsoft.Graph.Authentication' }
}
function Install-Prereqs {
    param([object[]]$Checks)
    $missing = @($Checks | Where-Object { -not $_.Ok -and $script:PrereqInstallMap.Contains($_.Name) })
    if (-not $missing){ return }   # nothing the installer manages is missing - stay quiet
    Write-Host ''
    Warn 'The installer can add these for you:'
    foreach ($m in $missing){
        $spec = $script:PrereqInstallMap[$m.Name]
        $how  = if ($spec.Winget){ "winget: $($spec.Winget)" } else { "PowerShell module: $($spec.Module)" }
        Write-Host "    * $($m.Name)  ($how)" -ForegroundColor White
    }
    if (-not $NonInteractive){
        if ((Read-Host "`n  Install the above now? (y/n)") -notmatch '^[Yy]'){ Info 'Skipped - nothing was installed.'; return }
    }
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    $restartNeeded = $false
    foreach ($m in $missing){
        $spec = $script:PrereqInstallMap[$m.Name]
        if ($spec.Winget){
            if (-not $winget){ Warn "winget not found - install $($m.Name) by hand: $($m.Fix)"; continue }
            ShowCmd "winget install --id $($spec.Winget) -e --accept-package-agreements --accept-source-agreements"
            winget install --id $spec.Winget -e --source winget --accept-package-agreements --accept-source-agreements
            if ($LASTEXITCODE -ne 0){ Warn "winget could not install $($m.Name) (exit $LASTEXITCODE). Fix by hand: $($m.Fix)" }
            else { Ok "$($m.Name) installed."; $restartNeeded = $true }
        }
        elseif ($spec.Module){
            if (-not (Get-Module -ListAvailable -Name $spec.Module)){
                ShowCmd "Install-Module $($spec.Module) -Scope CurrentUser -Force -AllowClobber"
                try { Install-Module $spec.Module -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop; Ok "$($m.Name) installed." }
                catch { Warn "Could not install $($m.Name): $($_.Exception.Message)" }
            } else { Ok "$($m.Name) already present." }
        }
    }
    if ($restartNeeded){
        Warn 'A command-line tool was just installed. CLOSE this window and relaunch in a NEW "pwsh" so the updated PATH loads, then run the prerequisites check again (menu 9).'
    }
}
function Step-Prereqs {
    Test-Prereqs | Out-Null
    Install-Prereqs -Checks $script:LastPrereqChecks
}

# --- Azure context safety: never deploy into the wrong (customer) tenant --
function Show-AzContext {
    ShowCmd "az account show"
    $acct = az account show -o json 2>$null | ConvertFrom-Json
    if ($acct) {
        Write-Host ""
        Write-Host "  Current Azure context" -ForegroundColor Yellow
        Write-Host ("    Subscription : {0}" -f $acct.name) -ForegroundColor White
        Write-Host ("    Sub ID       : {0}" -f $acct.id)
        Write-Host ("    Tenant       : {0}" -f $acct.tenantId)
        Write-Host ("    Signed in as : {0}" -f $acct.user.name)
        Write-Host ""
    } else { Warn "Not signed in to Azure (az account show returned nothing)." }
    return $acct
}
function Step-AzLogin {
    Narrate "Signing in to Azure. Pick the LAB subscription - never a customer tenant."
    ShowCmd "az login"
    az login -o none
    ShowCmd "az account list -o table"
    $subs = az account list --query "[].{name:name,id:id,tenant:tenantId}" -o json 2>$null | ConvertFrom-Json
    if (-not $subs) { Warn "No subscriptions visible after login."; return }
    Write-Host "  Subscriptions you can see:" -ForegroundColor Yellow
    for ($i=0; $i -lt $subs.Count; $i++){ Write-Host ("   {0,2}) {1}   [{2}]" -f ($i+1), $subs[$i].name, $subs[$i].id) }
    $pick = Read-Host "  Which one is your LAB subscription? (number)"
    if ($pick -match '^\d+$' -and [int]$pick -ge 1 -and [int]$pick -le $subs.Count){
        $sel = $subs[[int]$pick-1]
        ShowCmd "az account set --subscription $($sel.id)"
        az account set --subscription $sel.id
        $CFG.SubscriptionId = $sel.id; $CFG.SubscriptionName = $sel.name; Save-Cfg $CFG
        Ok "Lab subscription set and remembered: $($sel.name)"
    } else { Warn "No valid choice - subscription not changed." }
    Show-AzContext | Out-Null
}
# Called at startup and before deploy: show the context and make the user
# confirm (or re-login) so a stale customer-tenant login can't be used by mistake.
function Confirm-AzContext {
    $acct = Show-AzContext
    if (-not $acct) { Warn "You must sign in first."; Step-AzLogin; return (az account show -o json 2>$null | ConvertFrom-Json) }
    if ($CFG.SubscriptionId -and $acct.id -ne $CFG.SubscriptionId) {
        Warn "ACTIVE subscription is NOT your saved lab subscription ($($CFG.SubscriptionName))."
    }
    Warn "Make sure this is your LAB subscription, NOT a customer tenant."
    $r = Read-Host "  [Enter] to re-login / switch subscription (recommended), or K to keep this one"
    if ($r -notmatch '^[Kk]$') { Step-AzLogin; $acct = az account show -o json 2>$null | ConvertFrom-Json }
    return $acct
}
function Step-Deploy {
    Narrate "Provisioning the Azure range (one resource group, inbound locked to your public IP)."
    # --- subscription safety gate: never deploy into the wrong tenant -----
    $acct = Confirm-AzContext
    if (-not $acct) { Warn "No Azure context - cancelled."; return }
    Warn "DEPLOY TARGET -> subscription '$($acct.name)'  ($($acct.id)), tenant $($acct.tenantId)."
    $typed = Read-Host "  Type the subscription NAME exactly to confirm deploy, or anything else to cancel"
    if ($typed -ne $acct.name) { Warn "Name did not match - CANCELLED. Nothing deployed."; return }
    $deploy = Join-Path $HERE 'Deploy-AzureLab.ps1'
    # Azure region names have no spaces/case ("canada central" -> "canadacentral").
    $loc = ($CFG.Location -replace '\s','').ToLower()
    if ($loc -ne $CFG.Location) { Warn "Normalised region '$($CFG.Location)' -> '$loc' (Azure region names have no spaces)."; $CFG.Location = $loc; Save-Cfg $CFG }
    ShowCmd ".\Deploy-AzureLab.ps1 -ResourceGroup $($CFG.ResourceGroup) -Location $loc -DomainName $($CFG.DomainName)$(if($CFG.IncludeSrv01){' -IncludeSrv01'})"
    # Hashtable splat binds by NAME (an array splat would bind positionally and
    # swallow the -Parameter labels as values).
    $p = @{ ResourceGroup = $CFG.ResourceGroup; Location = $loc; DomainName = $CFG.DomainName }
    if ($CFG.IncludeSrv01){ $p.IncludeSrv01 = $true }
    & $deploy @p
}
function Step-Manage([string]$act){
    ShowCmd ".\Manage-AzureLab.ps1 -Action $act -ResourceGroup $($CFG.ResourceGroup)"
    & (Join-Path $HERE 'Manage-AzureLab.ps1') -Action $act -ResourceGroup $CFG.ResourceGroup
}
function Lab-VmNames {
    $n = @($CFG.Dc,$CFG.Win11,$CFG.Win11b,$CFG.Kali)
    if ($CFG.IncludeSrv01){ $n += 'SRV01' }
    return $n
}

# --- second, isolated copy of the lab (menu 1 -> D, then menu 2 -> B) -------
# Read-only quota check so a 2nd copy doesn't fail half-way on vCPU limits.
function Test-Copy2Quota([string]$loc){
    $need = 2 * $(if ($CFG.IncludeSrv01) { 5 } else { 4 })   # Standard_D2s_v5 = 2 vCPU each
    ShowCmd "az vm list-usage -l $loc --query ""[?name.value=='standardDSv5Family' || name.value=='cores']"" -o table"
    $u = az vm list-usage -l $loc --query "[?name.value=='standardDSv5Family' || name.value=='cores'].{n:name.value,cur:currentValue,lim:limit}" -o json 2>$null | ConvertFrom-Json
    if (-not $u) { Warn "Couldn't read vCPU quota for '$loc' - continuing; if a VM fails with a quota error, raise it in the portal (Subscriptions > Usage + quotas)."; return $true }
    $ok = $true
    foreach ($q in $u) {
        $free = [int]$q.lim - [int]$q.cur
        $label = if ($q.n -eq 'cores') { 'Total regional vCPUs' } else { 'DSv5-family vCPUs' }
        if ($free -lt $need) { Warn ("{0}: {1} used of {2} - only {3} free, copy 2 needs {4}." -f $label,$q.cur,$q.lim,$free,$need); $ok = $false }
        else { Ok ("{0}: {1} used of {2} - {3} free, copy 2 needs {4}." -f $label,$q.cur,$q.lim,$free,$need) }
    }
    return $ok
}
function Step-DeployCopy2 {
    $lab1Rg = Get-Lab1Rg
    Switch-Lab '2'
    if ($CFG.ResourceGroup -eq $lab1Rg) {
        Warn "Copy 2's resource group is the same as copy 1's ($lab1Rg). Set a different one (menu 1 -> 7) - CANCELLED."
        return
    }
    Narrate "Deploying a 2nd, fully isolated copy of the lab into '$($CFG.ResourceGroup)' (same tenant + subscription)."
    Write-Host "    What's separate (nothing is shared with $lab1Rg):" -ForegroundColor DarkGray
    Write-Host "      - its own resource group      $($CFG.ResourceGroup)" -ForegroundColor DarkGray
    Write-Host "      - its own VNet + subnet       vnet-lab / snet-lab  192.168.57.0/24 (same range is fine:" -ForegroundColor DarkGray
    Write-Host "                                    the VNets are never peered, so they can't see each other)" -ForegroundColor DarkGray
    Write-Host "      - its own NSG + public IPs    nsg-lab, inbound locked to your public IP" -ForegroundColor DarkGray
    Write-Host "      - its own AD forest           DC01 / WIN11 / WIN11B / KALI$(if($CFG.IncludeSrv01){' / SRV01'})" -ForegroundColor DarkGray
    Write-Host "      - its own Sentinel workspace  $($CFG.WorkspaceName) (only if you deploy Sentinel for copy 2)" -ForegroundColor DarkGray
    Write-Host ""
    Warn "Shared on purpose: the Defender XDR tenant. Both copies report into the SAME portal, so with the"
    Warn "same domain + VM names you'll see two DC01 / WIN11 devices. MDI in particular expects unique forest"
    Warn "names - if you'll run MDI on both copies, give copy 2 its own domain (e.g. lab2.local) below."
    Write-Host ""
    $d  = Read-Host "  Domain for copy 2 [$($CFG.DomainName)]";  if ($d)  { $CFG.DomainName  = $d.Trim() }
    $nb = Read-Host "  NetBIOS for copy 2 [$($CFG.NetbiosName)]"; if ($nb) { $CFG.NetbiosName = $nb.Trim().ToUpper() }
    Save-Cfg $CFG; Ok "Copy 2 settings saved to $CFGFILE"

    $loc = ($CFG.Location -replace '\s','').ToLower()
    Narrate "Pre-check: vCPU quota in $loc (copy 1 is already using some of it)."
    if (-not (Test-Copy2Quota $loc)) {
        if ((Read-Host "  Quota looks too low - continue anyway? (y/N)") -notmatch '^[Yy]') { Warn "CANCELLED. Nothing deployed. Raise the quota, or Stop copy 1 first (deallocated VMs don't use vCPU quota)."; return }
    }
    ShowCmd "az group exists -n $($CFG.ResourceGroup)"
    $rgx = Test-RgExists $CFG.ResourceGroup
    if ($null -eq $rgx) { Warn "CANCELLED. Nothing deployed."; return }
    if ($rgx) {
        Warn "'$($CFG.ResourceGroup)' already exists - the build is idempotent and only creates what's missing."
    }
    Step-Deploy
    Write-Host ""
    Ok "Copy 2 is now the ACTIVE lab ($($CFG.ResourceGroup)). Next: menu 2 -> B to finish building it."
}
function Test-RgExists([string]$rg){
    # Returns $true / $false, or $null when az itself FAILED (expired sign-in,
    # conditional-access re-auth, network). A failed az call prints nothing on
    # stdout, so without this check an expired token looked like "doesn't exist".
    $out = try { az group exists -n $rg 2>$null } catch { $null }
    if ($LASTEXITCODE -ne 0 -or -not $out) {
        Warn "Azure CLI couldn't check '$rg' - your az sign-in has most likely expired"
        Warn "(conditional access can force a fresh sign-in every 24h). Nothing was changed."
        Warn "Sign in again with main menu -> L, then retry."
        return $null
    }
    return ((@($out) | ForEach-Object { "$_".Trim() }) -contains 'true')
}
function Step-DestroyCopy2 {
    $prev   = $script:ActiveLab
    $lab1Rg = Get-Lab1Rg
    Switch-Lab '2'
    try {
        if ($CFG.ResourceGroup -eq $lab1Rg) { Warn "Copy 2's resource group equals copy 1's ($lab1Rg) - REFUSING to destroy. Fix it in menu 1 -> 7 (with copy 2 active)."; return }
        Narrate "Destroying COPY 2 ONLY: resource group '$($CFG.ResourceGroup)'. Copy 1 ($lab1Rg) is not touched."
        ShowCmd "az group exists -n $($CFG.ResourceGroup)"
        $rgx = Test-RgExists $CFG.ResourceGroup
        if ($null -eq $rgx) { return }
        if (-not $rgx) { Warn "'$($CFG.ResourceGroup)' doesn't exist - nothing to destroy."; return }
        Step-Manage 'Destroy'   # lists the resources, then you must TYPE the RG name to confirm
        if ((Test-RgExists $CFG.ResourceGroup) -eq $false) {
            Ok "Copy 2 is gone. Its settings stay in $CFGFILE, so menu 1 -> D rebuilds it the same way."
        }
    } finally {
        if ($prev -ne '2') { Switch-Lab $prev; Info "Active lab is back to copy $($script:ActiveLab) ($($CFG.ResourceGroup))." }
    }
}
function Step-CompleteCopy2 {
    if ($script:ActiveLab -ne '2') { Switch-Lab '2' }
    Narrate "Finishing copy 2 ($($CFG.ResourceGroup), $($CFG.DomainName)): DC -> join -> verify."
    ShowCmd "az group exists -n $($CFG.ResourceGroup)"
    $rgx = Test-RgExists $CFG.ResourceGroup
    if ($null -eq $rgx) { return }
    if (-not $rgx) {
        Warn "'$($CFG.ResourceGroup)' doesn't exist yet. Deploy it first: menu 1 -> D."; return
    }
    Narrate "Making sure copy 2's VMs are running (DC01 first)."
    Step-Manage 'Start'
    $go = { param($label) if ($NonInteractive) { return $true }; return ((Read-Host "  Run '$label' now? (Y/n/s=skip)") -notmatch '^[NnSs]') }
    if (& $go 'B1  Configure DC01 (promote + seed + DNS)') { Step-ConfigureDC }
    if (& $go 'B2  Join WIN11 / WIN11B to the domain')    { Step-JoinTargets }
    if (& $go 'B3  Verify lab readiness')                 { Step-Verify }
    if (-not $NonInteractive -and (Read-Host "  B4  WEAKEN copy 2's AD now too, so the attacks work? (y/N)") -match '^[Yy]') { Step-WeakenAD }
    if (& $go "B5  Build the '$($CFG.HardenedOU)' OU + simple hardening GPO (same as 2 -> 7)") { Step-HardenedOU }
    if (& $go "B6  Build the 'Defender Baseline' GPO - ASR / CFA / network protection (same as 2 -> 9)") { Step-DefenderBaselineGpo }
    Write-Host ""
    Narrate "Copy 2 build steps done. Remaining checks (all from the menus, with copy 2 active):"
    Write-Host "    - 4 -> E  push MDE.Windows again if WIN11 isn't in Defender yet (deploy already queued it)"
    Write-Host "    - 4 -> S  confirm copy 2's devices show up in Defender (look for the second DC01 / WIN11)"
    Write-Host "    - 1 -> 9  re-authorize your IP on copy 2's NSG if you've changed networks"
    Write-Host "    - 3       SSH to copy 2's KALI"
    Write-Host "    - C       (main menu) switch back to copy 1 when you're done"
}
function Step-AutoShutdown {
    Narrate "Auto-shutdown control (it's OFF after a build so VMs stay up; turn it on to save cost)."
    Write-Host "    1) Turn ON  - set a daily deallocate time (UTC)"
    Write-Host "    2) Turn OFF - keep the VMs up"
    Write-Host "    0) Back`n"
    $c = Read-Host "  Select"
    $vms = Lab-VmNames
    switch ($c) {
        '1' {
            $t = Read-Host "  Daily shutdown time, 24h UTC as HHMM (e.g. 0200)"
            if ($t -notmatch '^\d{3,4}$'){ Warn "Use HHMM like 0200."; return }
            foreach ($v in $vms){
                ShowCmd "az vm auto-shutdown -g $($CFG.ResourceGroup) -n $v --time $t"
                az vm auto-shutdown -g $CFG.ResourceGroup -n $v --time $t -o none 2>$null
                Ok "$v -> auto-shutdown $t UTC"
            }
        }
        '2' {
            foreach ($v in $vms){
                ShowCmd "az vm auto-shutdown -g $($CFG.ResourceGroup) -n $v --off"
                az vm auto-shutdown -g $CFG.ResourceGroup -n $v --off -o none 2>$null
                Ok "$v -> auto-shutdown OFF"
            }
        }
    }
}
# Re-lock the NSG to wherever you are NOW. Use after you change networks
# (new office, hotel, conference wifi). Only RDP/SSH into the VMs is IP-fenced -
# the kit's own 'az vm run-command' automation goes through Azure's API and
# works from any IP - so this is specifically what re-opens console/RDP access.
function Step-BootDiagnostics {
    Narrate "Boot diagnostics: turns on the portal's boot screenshot + Serial Console for every lab VM (managed storage - no storage account to create)."
    $rgs = @($CFG.ResourceGroup)
    $other = if ($script:ActiveLab -eq '2') { Get-Lab1Rg } else { Get-Copy2Rg }
    if ($other -and $other -ne $CFG.ResourceGroup) {
        $oe = Test-RgExists $other
        if ($oe -and -not $NonInteractive -and (Read-Host "  Also do the other lab copy ($other)? (y/N)") -match '^[Yy]') { $rgs += $other }
    }
    $ok = @(); $bad = @()
    foreach ($rg in $rgs) {
        $e = Test-RgExists $rg
        if ($null -eq $e) { return }
        if (-not $e) { Warn "'$rg' doesn't exist - skipping."; continue }
        ShowCmd "az vm list -g $rg --query `"[].name`" -o tsv"
        $vms = @(az vm list -g $rg --query "[].name" -o tsv 2>$null | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
        if ($LASTEXITCODE -ne 0 -or -not $vms) { Warn "No VMs found in '$rg'."; continue }
        foreach ($vm in $vms) {
            $now = az vm show -g $rg -n $vm --query "diagnosticsProfile.bootDiagnostics.enabled" -o tsv 2>$null
            if ("$now".Trim() -eq 'true') { Ok "$rg / $vm : already on"; $ok += "$rg/$vm"; continue }
            ShowCmd "az vm boot-diagnostics enable -g $rg -n $vm"
            az vm boot-diagnostics enable -g $rg -n $vm -o none 2>$null
            # verify from Azure rather than trusting the exit code
            $now = az vm show -g $rg -n $vm --query "diagnosticsProfile.bootDiagnostics.enabled" -o tsv 2>$null
            if ("$now".Trim() -eq 'true') { Ok "$rg / $vm : boot diagnostics ON (verified)"; $ok += "$rg/$vm" }
            else { Warn "$rg / $vm : NOT enabled (Azure still reports '$("$now".Trim())')"; $bad += "$rg/$vm" }
        }
    }
    Write-Host ""
    if ($ok)  { Ok "Boot diagnostics on: $($ok.Count) VM(s). Portal: VM > Help > Boot diagnostics (screenshot) or Serial console." }
    if ($bad) { Warn "Failed on: $($bad -join ', '). Check your sign-in (main menu -> L) and retry B." }
    Log "Boot diagnostics ok=[$($ok -join ',')] failed=[$($bad -join ',')]" 'INFO'
}
function Step-AuthorizeIp {
    param([string]$Mode = 'replace')   # 'replace' = lock to this IP only; 'add' = also keep existing
    Narrate "Authorizing your CURRENT public IP for RDP/SSH into the lab (updates the NSG)."
    Info "Run this whenever you move networks. Building/configuring the lab works from anywhere (that goes through Azure's API); this only governs RDP/SSH straight into the VMs - e.g. SSHing into $($CFG.Kali)."

    # --- detect this machine's current public IP ---
    $ip = $null
    ShowCmd "Invoke-RestMethod https://api.ipify.org"
    try { $ip = (Invoke-RestMethod -Uri 'https://api.ipify.org').Trim() } catch {}
    if (-not $ip) { try { $ip = (Invoke-RestMethod -Uri 'https://ifconfig.me/ip').Trim() } catch {} }
    if (-not $ip -or $ip -notmatch '^\d{1,3}(\.\d{1,3}){3}$') {
        Warn "Couldn't auto-detect your public IP. Set it by hand once you know it:"
        Write-Host "    az network nsg rule update -g $($CFG.ResourceGroup) --nsg-name nsg-lab -n allow-mgmt-from-me --source-address-prefixes <your-ip>" -ForegroundColor White
        return
    }
    Ok "Your current public IP: $ip"

    $nsg = 'nsg-lab'; $rule = 'allow-mgmt-from-me'
    # Read the rule as JSON and look at BOTH source fields. A rule holding one
    # IP stores it in sourceAddressPrefix (singular) and leaves the plural list
    # empty, so reading only the plural field showed nothing.
    $readRule = {
        $raw = az network nsg rule show -g $CFG.ResourceGroup --nsg-name $nsg -n $rule -o json 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $raw) { return $null }
        try { return (($raw | Out-String) | ConvertFrom-Json) } catch { return $null }
    }
    $srcOf = { param($r) @(@($r.sourceAddressPrefix) + @($r.sourceAddressPrefixes) | Where-Object { $_ -and $_ -ne '*' } | Select-Object -Unique) }

    $sub = az account show --query "[name, id]" -o tsv 2>$null
    if ($sub) { Info "Azure subscription: $(@($sub) -join '  ')   RG: $($CFG.ResourceGroup)" }
    ShowCmd "az network nsg rule show -g $($CFG.ResourceGroup) --nsg-name $nsg -n $rule -o json"
    $r = & $readRule
    if (-not $r) {
        Warn "Couldn't read NSG rule '$rule' in RG '$($CFG.ResourceGroup)'. Either your az sign-in expired, the lab isn't"
        Warn "deployed in this subscription, or az is pointed at the wrong subscription. Fix with main menu -> L, then retry."
        return
    }
    $curList = & $srcOf $r
    if ($curList){ Write-Host "    NSG currently allows: $($curList -join ', ')" -ForegroundColor DarkGray }

    if ($curList -contains $ip -and $Mode -ne 'add') {
        if ($curList.Count -eq 1) { Ok "The NSG already allows $ip and nothing else - you're set. RDP/SSH will work from here."; return }
        Info "$ip is already allowed, but other IPs are too. Re-locking to just $ip."
    }

    # --- build the new source set ---
    if ($Mode -eq 'add') {
        $new = @(@($curList) + $ip | Select-Object -Unique)
        Narrate "Adding $ip to the allowed set (keeping the existing entries)."
    } else {
        $new = @($ip)
        Narrate "Re-locking RDP/SSH to $ip only (dropping any previous location)."
    }

    # Rewrite the WHOLE rule (create = PUT) instead of 'rule update'. 'update' can
    # return success while leaving a singular sourceAddressPrefix untouched, which
    # is exactly the "it says it worked but the portal still shows the old IP" bug.
    $prio  = if ($r.priority) { $r.priority } else { 1000 }
    $ports = @(@($r.destinationPortRange) + @($r.destinationPortRanges) | Where-Object { $_ })
    if (-not $ports) { $ports = @('3389','22') }
    ShowCmd "az network nsg rule create -g $($CFG.ResourceGroup) --nsg-name $nsg -n $rule --priority $prio --access Allow --direction Inbound --protocol Tcp --source-address-prefixes $($new -join ' ') --destination-port-ranges $($ports -join ' ')"
    az network nsg rule create -g $CFG.ResourceGroup --nsg-name $nsg -n $rule --priority $prio --access Allow `
        --direction Inbound --protocol Tcp --source-address-prefixes @($new) --source-port-ranges '*' `
        --destination-address-prefixes '*' --destination-port-ranges @($ports) -o none 2>$null
    $rc = $LASTEXITCODE

    # --- verify: read it back from Azure, don't trust the exit code alone ---
    ShowCmd "az network nsg rule show -g $($CFG.ResourceGroup) --nsg-name $nsg -n $rule -o json   (verify)"
    $after = & $readRule
    $afterList = if ($after) { & $srcOf $after } else { @() }
    $match = ($afterList.Count -eq $new.Count) -and -not ($new | Where-Object { $afterList -notcontains $_ })
    if ($rc -eq 0 -and $match) {
        Ok "VERIFIED in Azure: '$rule' on $($CFG.ResourceGroup)/$nsg now allows RDP(3389)+SSH(22) from: $($afterList -join ', ')."
        Info "The portal can take a minute to show it - press Refresh on the NSG page."
        Log "NSG $rule source -> $($afterList -join ',') (verified)" 'OK'
    } else {
        Warn "NOT applied. Azure still shows '$rule' allowing: $(if($afterList){$afterList -join ', '}else{'(could not read)'})  (az exit code $rc)."
        Warn "Check you're in the right subscription (main menu -> L), or set it in the portal: $($CFG.ResourceGroup) > $nsg > $rule > Source IP = $ip"
    }
}
function Step-Configure {
    Narrate "Edit lab settings (Enter keeps the current value)."
    foreach ($k in @('ResourceGroup','Location','DomainName')) {
        $v = Read-Host "  $k [$($CFG.$k)]"; if ($v){ $CFG.$k = $v }
    }
    $nb = Read-Host "  NetBIOS name [$($CFG.NetbiosName)]"; if ($nb){ $CFG.NetbiosName = $nb }
    $s = Read-Host "  Include SRV01 file server? (y/n) [$([bool]$CFG.IncludeSrv01)]"; if ($s){ $CFG.IncludeSrv01 = ($s -match '^(y|Y)') }
    Save-Cfg $CFG; Ok "Saved to $CFGFILE"
}
function Step-Logs {
    Narrate "Run logs - everything you do is captured here so you can paste one to get help."
    Write-Host "    Active log : $(if($script:LogFile){$script:LogFile}else{'(none - logging not started)'})" -ForegroundColor White
    Write-Host "    Log folder : $LOGDIR`n" -ForegroundColor White
    Write-Host "    Events log : $(if($script:EventFile){$script:EventFile}else{'(none)'})`n" -ForegroundColor White
    Write-Host "    1) Tail the clean events markers (last 40)"
    Write-Host "    2) Tail the full transcript (last 40)"
    Write-Host "    3) List all logs"
    Write-Host "    4) Open the log folder"
    Write-Host "    5) Zip the latest run (transcript + events) for sharing -> Desktop"
    Write-Host "    0) Back`n"
    $c = Read-Host "  Select"
    switch ($c) {
        '1' { if ($script:EventFile -and (Test-Path $script:EventFile)){ Get-Content $script:EventFile -Tail 40 | Write-Host } else { Warn "No events log yet." } }
        '2' { if ($script:LogFile -and (Test-Path $script:LogFile)){ Get-Content $script:LogFile -Tail 40 | Write-Host } else { Warn "No active transcript." } }
        '3' { if (Test-Path $LOGDIR){ Get-ChildItem $LOGDIR -Filter *.log | Sort-Object LastWriteTime -Desc | Select-Object LastWriteTime,@{n='KB';e={[int]($_.Length/1KB)}},Name | Format-Table -Auto | Out-String | Write-Host } else { Warn "No logs yet." } }
        '4' { ShowCmd "Start-Process '$LOGDIR'"; try { Start-Process $LOGDIR } catch { Warn "Open it manually: $LOGDIR" } }
        '5' {
            $stampPart = if ($script:LogFile){ [IO.Path]::GetFileNameWithoutExtension($script:LogFile) } else { '' }
            $files = Get-ChildItem $LOGDIR -Filter "$stampPart*" -ErrorAction SilentlyContinue
            if (-not $files){ $files = Get-ChildItem $LOGDIR -Filter *.log -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Desc | Select-Object -First 2 }
            if (-not $files){ Warn "No log to zip."; break }
            $zip = Join-Path ([Environment]::GetFolderPath('Desktop')) ("DefXDRLabKit-log-{0:yyyyMMdd-HHmmss}.zip" -f (Get-Date))
            Compress-Archive -Path ($files.FullName) -DestinationPath $zip -Force
            Ok "Zipped $($files.Count) file(s) -> $zip  (attach this when you ask for help)."
        }
    }
}

# --- 2) lab configuration ------------------------------------------------
# Poll DC01 until it has rebooted AND Active Directory is actually up (NTDS +
# AD Web Services), so we can seed without a manual "press Enter" gate.
function Wait-ForDc {
    param([int]$TimeoutMin = 15,[string]$Vm = $CFG.Dc,[string]$Label = 'DC01')
    Narrate "Waiting for $Label to finish promotion and come back online (checking AD services)..."
    $probe = @'
$ntds = (Get-Service NTDS -ErrorAction SilentlyContinue).Status
$adws = (Get-Service ADWS -ErrorAction SilentlyContinue).Status
if ($ntds -eq 'Running' -and $adws -eq 'Running') {
  try { $d = (Get-ADDomain -ErrorAction Stop).DNSRoot; "DCREADY:$d" }
  catch { "ADWS up, directory still warming up" }
} else { "not-ready (NTDS=$ntds ADWS=$adws)" }
'@
    $tmp = Join-Path $env:TEMP 'dc-probe.ps1'; $probe | Set-Content $tmp -Encoding utf8
    $start = Get-Date; $deadline = $start.AddMinutes($TimeoutMin)
    # give the reboot a head start so we don't catch it pre-shutdown
    Start-Sleep -Seconds 45
    while ((Get-Date) -lt $deadline) {
        $elapsed = '{0}m{1:00}s' -f [int]((Get-Date)-$start).TotalMinutes, (((Get-Date)-$start).Seconds)
        $msg = ''
        try {
            $raw = az vm run-command invoke -g $CFG.ResourceGroup -n $Vm --command-id RunPowerShellScript --scripts "@$tmp" -o json 2>$null
            if ($LASTEXITCODE -eq 0) { $msg = (($raw | ConvertFrom-Json).value | ForEach-Object { $_.message }) -join ' ' }
        } catch {}
        if ($msg -match 'DCREADY:(\S+)') {
            Ok "$Label is up and AD is serving '$($Matches[1])' (after $elapsed)."
            Log "$Label ready after $elapsed ($($Matches[1]))" 'OK'
            return $true
        }
        $state = if($msg){$msg.Trim()}else{'no answer yet (DC likely rebooting / agent not responding)'}
        Write-Host ("  ...$Label not ready yet ($elapsed): $state") -ForegroundColor DarkGray
        Log "Wait-ForDc poll @ $elapsed -> $state" 'INFO'
        Start-Sleep -Seconds 20
    }
    Warn "$Label didn't report ready within $TimeoutMin min. It may still be finishing - re-run Configure, or check it, then seed."
    return $false
}
# --- lab admin passwords (random per lab copy, kept OUT of the repo) ---------
# DSRM + the labadmin-da Domain Admin get a random password per lab copy,
# generated on first use and saved in %USERPROFILE%\.defxdrlab\secrets-<copy>.json
# (gitignored, outside the kit folder). The seeded ATTACK-TARGET accounts
# (labuser, svc-sql, the 11-Weaken-AD set) keep their deliberately weak
# passwords - weak where the lesson needs it, random everywhere else.
function New-LabPassword([int]$Length = 20) {
    # Letters + digits only (3 of the 4 AD complexity classes), so the value
    # passes through az run-command parameters with no quoting problems.
    $sets = @('ABCDEFGHJKLMNPQRSTUVWXYZ','abcdefghijkmnopqrstuvwxyz','23456789')
    $all  = -join $sets
    $rng  = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $next = { param([int]$max) $b = New-Object byte[] 4; $rng.GetBytes($b); [int]([BitConverter]::ToUInt32($b,0) % [uint32]$max) }
    $c = New-Object System.Collections.Generic.List[char]
    foreach ($set in $sets) { $c.Add($set[(& $next $set.Length)]) }
    while ($c.Count -lt $Length) { $c.Add($all[(& $next $all.Length)]) }
    for ($i = $c.Count - 1; $i -gt 0; $i--) { $j = & $next ($i + 1); $t = $c[$i]; $c[$i] = $c[$j]; $c[$j] = $t }
    return (-join $c)
}
function Get-LabSecretsFile { Join-Path $CFGDIR "secrets-$($script:ActiveLab).json" }
function Get-LabSecrets([switch]$Regenerate) {
    $f = Get-LabSecretsFile
    if (-not $Regenerate -and (Test-Path $f)) {
        try { $s = Get-Content $f -Raw | ConvertFrom-Json; if ($s.DsrmPassword -and $s.DomainAdminPassword) { return $s } } catch {}
    }
    $s = [pscustomobject]@{ DsrmPassword = (New-LabPassword); DomainAdminPassword = (New-LabPassword); Created = (Get-Date -Format s) }
    New-Item -ItemType Directory -Force -Path $CFGDIR | Out-Null
    $s | ConvertTo-Json | Set-Content $f
    Ok "Generated random admin passwords for lab copy $($script:ActiveLab) (DSRM + labadmin-da), saved to $f. Menu 2 -> P copies them."
    return $s
}
function Step-LabSecrets {
    $s = Get-LabSecrets
    Narrate "Lab copy $($script:ActiveLab) admin passwords. Random per lab and kept in $(Get-LabSecretsFile) - never in the repo or the run log."
    Write-Host "    1) Copy the labadmin-da (Domain Admin) password to the clipboard"
    Write-Host "    2) Copy the DSRM (DC safe-mode) password to the clipboard"
    Write-Host "    3) Generate NEW passwords (DSRM applies to the next build; labadmin-da after menu 2 -> 1)"
    Write-Host "    0) Back`n"
    $c = Read-Host "  Select"
    switch ($c) {
        '1' { try { Set-Clipboard -Value $s.DomainAdminPassword; Ok "Copied the password for $($CFG.NetbiosName)\labadmin-da." } catch { Warn "Clipboard unavailable - open $(Get-LabSecretsFile)." } }
        '2' { try { Set-Clipboard -Value $s.DsrmPassword; Ok "Copied the DSRM password." } catch { Warn "Clipboard unavailable - open $(Get-LabSecretsFile)." } }
        '3' { if ((Read-Host "  Replace this lab's saved admin passwords? (y/N)") -match '^[Yy]') { Get-LabSecrets -Regenerate | Out-Null; Info "Re-run menu 2 -> 1 to apply the new labadmin-da password on DC01." } }
    }
}
function Step-ConfigureDC {
    $s = Join-Path $HERE 'guest/03-Configure-DomainController.ps1'
    $sec = Get-LabSecrets
    Write-Host ""
    Narrate "DC01 configuration - 3 phases. Everything below is echoed to the run log."
    Write-Host "    Phase 1/3  Promote DC01 to the $($CFG.DomainName) forest (installs AD DS + DNS)" -ForegroundColor DarkGray
    Write-Host "    Phase 2/3  Wait for the reboot + AD services (auto-polled, nothing to press)" -ForegroundColor DarkGray
    Write-Host "    Phase 3/3  Seed the detection accounts, then print a readiness report" -ForegroundColor DarkGray
    Write-Host ""

    Narrate "[Phase 1/3] Promoting DC01 - this installs the roles and starts the forest build."
    Invoke-OnWindowsVm $CFG.Dc $s @('DomainName',$CFG.DomainName,'NetbiosName',$CFG.NetbiosName,'DcIp',$CFG.DcIp,'Action','Promote','SafeModePassword',$sec.DsrmPassword)

    Narrate "[Phase 2/3] DC01 reboots to finish promotion - waiting for it to come back online."
    Warn "This usually takes 3-8 minutes. You'll see a poll line every ~20s below (nothing to press)."
    if (Wait-ForDc) {
        Narrate "[Phase 3/3] DC01 is back - seeding labuser / svc-sql / labadmin-da."
        Invoke-OnWindowsVm $CFG.Dc $s @('DomainName',$CFG.DomainName,'NetbiosName',$CFG.NetbiosName,'DcIp',$CFG.DcIp,'Action','Seed','DaPassword',$sec.DomainAdminPassword)
        # Readiness report: show the domain + the seeded accounts so Dave sees proof.
        Narrate "Readiness check - confirming the forest and the seeded accounts exist:"
        $report = @'
Import-Module ActiveDirectory
$d = Get-ADDomain
"DOMAIN  : {0}  (NetBIOS {1}, functional level {2})" -f $d.DNSRoot,$d.NetBIOSName,$d.DomainMode
"DC      : {0}" -f (Get-ADDomainController).HostName
foreach ($u in 'labuser','svc-sql','labadmin-da'){
  $o = Get-ADUser -Filter "SamAccountName -eq '$u'" -Properties servicePrincipalName -ErrorAction SilentlyContinue
  if ($o){ "ACCOUNT : {0}  (enabled={1}{2})" -f $u,$o.Enabled,$(if($o.servicePrincipalName){' SPN='+($o.servicePrincipalName -join ',')}else{''}) }
  else  { "ACCOUNT : {0}  (MISSING)" -f $u }
}
'@
        $tmp = Join-Path $env:TEMP 'dc-report.ps1'; $report | Set-Content $tmp -Encoding utf8
        Invoke-OnWindowsVm $CFG.Dc $tmp $null
        # --- DNS is configured PER-MACHINE, not on the VNet/subnet:
        #   * The DC (above, in guest/03 Seed) points its own DNS client at
        #     itself ($($CFG.DcIp) + 127.0.0.1) and forwards anything its AD
        #     zones can't answer to Azure-provided DNS (168.63.129.16).
        #   * Each member (the Join step, guest/04) sets the DC as its DNS
        #     server directly on its NIC.
        Ok "DC01 DNS set to itself + forwarder to Azure DNS (168.63.129.16). No VNet/subnet DNS is used."
        Ok "DC01 configuration complete. Next: menu 2 -> 2 to join the targets (each target points its NIC at the DC)."
    } else {
        Warn "Skipped the Seed pass because DC01 wasn't confirmed ready. Re-run Configure (menu 2 -> 1) once it's up; the promote step is idempotent (it won't re-promote)."
    }
}
function Step-JoinTargets {
    Narrate "Pointing both victim PCs at the DC and joining them to the domain."
    $s = Join-Path $HERE 'guest/04-Join-and-Prep-Targets.ps1'
    $jp = (Get-LabSecrets).DomainAdminPassword
    Invoke-OnWindowsVm $CFG.Win11  $s @('DomainName',$CFG.DomainName,'DcIp',$CFG.DcIp,'JoinPassword',$jp)
    Invoke-OnWindowsVm $CFG.Win11b $s @('DomainName',$CFG.DomainName,'DcIp',$CFG.DcIp,'JoinPassword',$jp)
    if ($CFG.IncludeSrv01){ Invoke-OnWindowsVm 'SRV01' $s @('DomainName',$CFG.DomainName,'DcIp',$CFG.DcIp,'JoinPassword',$jp) }
}
function Step-Verify {
    Narrate "Checking lab readiness on the victim PCs$(if($CFG.IncludeSrv01){' and SRV01'})."
    $v = Join-Path $HERE 'guest/08-Verify-Lab.ps1'
    Invoke-OnWindowsVm $CFG.Win11  $v @('DomainName',$CFG.DomainName,'DcIp',$CFG.DcIp)
    Invoke-OnWindowsVm $CFG.Win11b $v @('DomainName',$CFG.DomainName,'DcIp',$CFG.DcIp)
    if ($CFG.IncludeSrv01){
        # SRV01 is a plain domain-member server, not an onboarded victim -
        # core checks only (join / DNS / AV), no MDE/ASR/CFA red noise.
        Invoke-OnWindowsVm 'SRV01' $v @('DomainName',$CFG.DomainName,'DcIp',$CFG.DcIp,'CoreOnly','true')
    }
}

# --- vulnerable-AD: seed deliberate misconfigurations, then close them -----
# Category list mirrors safebuffer/wazehell 'vulnerable-AD' (MIT); our own
# reversible seeding code. This only sets/removes AD *conditions* - no attack
# code. Pair it with the weakness-explainer doc for the teach-through.
function Step-WeakenAD {
    Write-Host ""
    Narrate "Weakening the lab AD on purpose so traditional tooling (BloodHound/PingCastle/roasting) has real findings."
    Warn "Lab-only, and fully reversible (menu 2 -> 5 Harden). Never run this anywhere you don't own."
    Invoke-OnWindowsVm $CFG.Dc (Join-Path $HERE 'guest/11-Weaken-AD.ps1') @('Action','Weaken','DomainName',$CFG.DomainName)
    # The run-command exit code does not reliably report a failed step, so this does
    # not claim success. Check the output: every category should show a [WEAK] line.
    Info "Check the output above: all nine [WEAK] categories should appear. If one is missing or shows an error, fix it and re-run menu 2 -> 4."
    Info "Next: show the before-state with menu 2 -> 6 (Report), run the attacks, then Harden (2 -> 5)."
}
function Step-HardenAD {
    Write-Host ""
    Narrate "Closing every seeded AD weakness 1:1 (the 'how it gets fixed' half of the lesson)."
    Invoke-OnWindowsVm $CFG.Dc (Join-Path $HERE 'guest/11-Weaken-AD.ps1') @('Action','Harden','DomainName',$CFG.DomainName)
    Ok "AD hardened (quick-win baseline). Enforce it domain-wide with the CIS L1 GPO (menu 8)."
}

function Step-ReportAD {
    Narrate "Reporting the current AD weakness state (read-only) - project this for the before/after."
    Invoke-OnWindowsVm $CFG.Dc (Join-Path $HERE 'guest/11-Weaken-AD.ps1') @('Action','Report','DomainName',$CFG.DomainName)
}

# --- GPO hardening + "Hardened Systems" OU --------------------------------
# A SIMPLE (non-CIS) hardening baseline in its own OU, so the demo is: run an
# attack against a box in the default OU, move the box into "Hardened Systems",
# re-run the same attack, and show what the baseline closed. All applied on DC01.
function Step-CreateCisOU {
    Narrate "Creating the CIS-Hardened-Workstations OU on DC01. No GPOs are linked here; you link the CIS policies yourself."
    Invoke-OnWindowsVm $CFG.Dc (Join-Path $HERE 'guest/12-Create-CIS-OU.ps1') @('DomainName',$CFG.DomainName,'OuName',$CFG.CisWorkstationsOU)
    Info "Check the output above: it should say the OU was created or already exists. Then link the CIS policies in gpmc.msc."
}
function Step-HardenedOU {
    Narrate "Creating the '$($CFG.HardenedOU)' OU + a simple hardening GPO on $($CFG.Dc), and linking them."
    Info "Non-CIS, deliberately simple: WDigest off, LSASS RunAsPPL, SMBv1 off + SMB signing, LLMNR off, restrict-anonymous. The CIS menu is the deeper hardening."
    $body = @'
param([string]$OuName,[string]$GpoName)
Import-Module ActiveDirectory,GroupPolicy -ErrorAction Stop
$d  = Get-ADDomain
$dn = $d.DistinguishedName
$ouDn = "OU=$OuName,$dn"
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$OuName'" -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name $OuName -Path $dn -ProtectedFromAccidentalDeletion $false
    "OU created: $ouDn"
} else { "OU already present: $ouDn" }
$gpo = Get-GPO -Name $GpoName -ErrorAction SilentlyContinue
if (-not $gpo) { $gpo = New-GPO -Name $GpoName -Comment "Workshop simple hardening baseline"; "GPO created: $GpoName" }
else { "GPO already present: $GpoName" }
function Set-Reg($k,$v,$t,$d){ Set-GPRegistryValue -Name $GpoName -Key $k -ValueName $v -Type $t -Value $d | Out-Null }
# 1. WDigest: do not cache cleartext credentials
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest' 'UseLogonCredential' DWord 0
# 2. LSASS protection (RunAsPPL)
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Lsa' 'RunAsPPL' DWord 1
# 3. Disable SMBv1 server
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' 'SMB1' DWord 0
# 4. Require SMB signing (server + client)
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' 'RequireSecuritySignature' DWord 1
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' 'RequireSecuritySignature' DWord 1
# 5. Disable LLMNR (poisoning defence)
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' 'EnableMulticast' DWord 0
# 6. Restrict anonymous enumeration
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Lsa' 'RestrictAnonymous' DWord 1
"Hardening values written to '$GpoName'."
$links = @((Get-GPInheritance -Target $ouDn).GpoLinks | ForEach-Object { $_.DisplayName })
if ($links -notcontains $GpoName) {
    New-GPLink -Name $GpoName -Target $ouDn -LinkEnabled Yes -ErrorAction SilentlyContinue | Out-Null
    "Linked '$GpoName' -> $ouDn"
} else { "Link already present." }
"DONE. Move a machine in with menu 2 -> 8, then re-run the attack to show the difference."
'@
    $tmp = Join-Path $env:TEMP 'hardened-ou.ps1'; $body | Set-Content $tmp -Encoding utf8
    Invoke-OnWindowsVm $CFG.Dc $tmp @('OuName',$CFG.HardenedOU,'GpoName',"$($CFG.HardenedOU) - Baseline")
    Ok "Done. '$($CFG.HardenedOU)' OU + hardening GPO are in place. Move a box in (menu 2 -> 8) to harden it."
}
function Step-MoveToHardenedOU {
    $b = Read-Host "  Move which box into '$($CFG.HardenedOU)'? 1=$($CFG.Win11) (onboarded)  2=$($CFG.Win11b) (stock AV)"
    $box = if ($b -eq '2'){ $CFG.Win11b } else { $CFG.Win11 }
    Narrate "Moving $box into the '$($CFG.HardenedOU)' OU and refreshing policy."
    $body = @'
param([string]$OuName,[string]$Box)
Import-Module ActiveDirectory -ErrorAction Stop
$d = Get-ADDomain; $ouDn = "OU=$OuName,$($d.DistinguishedName)"
$c = Get-ADComputer -Identity $Box -ErrorAction Stop
if ($c.DistinguishedName -like "*$ouDn") { "$Box is already in $ouDn" }
else { Move-ADObject -Identity $c.DistinguishedName -TargetPath $ouDn; "Moved $Box -> $ouDn" }
'@
    $tmp = Join-Path $env:TEMP 'move-ou.ps1'; $body | Set-Content $tmp -Encoding utf8
    Invoke-OnWindowsVm $CFG.Dc $tmp @('OuName',$CFG.HardenedOU,'Box',$box)
    Invoke-GpUpdate $box
    Ok "$box is in '$($CFG.HardenedOU)'. It needs a reboot for RunAsPPL/SMB to take full effect - restart it, then re-run the attack."
}


# --- Defender baseline GPO (ASR + CFA + network protection + recommended AV) --
# Builds a GPO you can OPEN IN GPMC to show the recommended endpoint posture as
# policy. ASR / CFA / Network Protection default to AUDIT so it's safe to link
# and review without breaking the attack demos; flip to Block when you want it
# enforcing (the function prints the block values). Linked to the Hardened
# Systems OU alongside the OS-hardening GPO. Tamper Protection is NOT settable by
# GPO (Intune / portal only) - noted on screen.
function Step-DefenderBaselineGpo {
    $m = Read-Host "  Mode for ASR / CFA / Network protection?  1=Audit (safe to review, default)  2=Block (enforce)"
    $enf = ($m -eq '2')
    $modeWord = if ($enf){ 'Block (enforce)' } else { 'Audit (log only)' }
    Narrate "Building the 'Defender Baseline' GPO on $($CFG.Dc) in $modeWord mode, linked to the '$($CFG.HardenedOU)' OU."
    Info "Open it afterwards in Group Policy Management (gpmc.msc) to walk the class through the settings as policy."
    $body = @'
param([string]$GpoName,[string]$OuName,[string]$Enforce)
Import-Module ActiveDirectory,GroupPolicy -ErrorAction Stop
$block = ($Enforce -eq 'True')
$asr = if ($block){ '1' } else { '2' }   # 1 = Block, 2 = Audit
$eg  = 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard'
$wd  = 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender'
$d   = Get-ADDomain; $ouDn = "OU=$OuName,$($d.DistinguishedName)"
if (-not (Get-GPO -Name $GpoName -ErrorAction SilentlyContinue)) { New-GPO -Name $GpoName -Comment "Defender recommended baseline: ASR + CFA + network protection + AV" | Out-Null; "GPO created: $GpoName" } else { "GPO already present: $GpoName" }
$script:fails = 0
function SR($k,$v,$t,$d){
    try { Set-GPRegistryValue -Name $GpoName -Key $k -ValueName $v -Type $t -Value $d -ErrorAction Stop | Out-Null }
    catch { $script:fails++; "FAILED: $k\$v - $($_.Exception.Message)" }
}
# --- Attack Surface Reduction rules (Microsoft's recommended set) ---
$rules = @{
  '9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2' = 'Block credential stealing from LSASS'
  'd1e49aac-8f56-4280-b9ba-993a6d77406c' = 'Block process creations from PSExec and WMI'
  'e6db77e5-3df2-4cf1-b95a-636979351e5b' = 'Block persistence through WMI event subscription'
  'be9ba2d9-53ea-4cdc-84e5-9b1eeee46550' = 'Block executable content from email/webmail'
  'd4f940ab-401b-4efc-aadc-ad5f3c50688a' = 'Block Office apps creating child processes'
  '3b576869-a4ec-4529-8536-b80a7769e899' = 'Block Office apps creating executable content'
  '75668c1f-73b5-4cf0-bb93-3ecf5cb7cc84' = 'Block Office apps injecting into other processes'
  '5beb7efe-fd9a-4556-801d-275e5ffc04cc' = 'Block obfuscated scripts'
  'd3e037e1-3eb8-44c8-a917-57927947596d' = 'Block JS/VBScript launching downloaded executable content'
  '92e97fa1-2edf-4476-bdd6-9dd0b4dddc7b' = 'Block Win32 API calls from Office macros'
  'c1db55ab-c21a-4637-bb3f-a12568109d35' = 'Use advanced ransomware protection'
  '01443614-cd74-433a-b99e-2ecdc07bfc25' = 'Block executables unless prevalence/age/trusted'
  '26190899-1602-49e8-8b27-eb1d0a1ce869' = 'Block Office comm apps creating child processes'
  '7674ba52-37eb-4a4f-a9a1-f0f9a1619a2c' = 'Block Adobe Reader creating child processes'
}
foreach ($g in $rules.Keys){ SR "$eg\ASR\Rules" $g String $asr }
SR "$eg\ASR" 'ExploitGuard_ASR_Rules' DWord 1
"ASR: $($rules.Count) recommended rules set to $(if($block){'Block'}else{'Audit'})."
# --- Controlled Folder Access (anti-ransomware) ---
SR "$eg\Controlled Folder Access" 'EnableControlledFolderAccess' DWord $(if($block){1}else{2})
"Controlled Folder Access: $(if($block){'Block'}else{'Audit'})."
# --- Network protection ---
SR "$eg\Network Protection" 'EnableNetworkProtection' DWord $(if($block){1}else{2})
"Network protection: $(if($block){'Block'}else{'Audit'})."
# --- Recommended AV engine settings (always on) ---
SR "$wd\Real-Time Protection" 'DisableRealtimeMonitoring' DWord 0
SR "$wd\Real-Time Protection" 'DisableBehaviorMonitoring' DWord 0
SR "$wd\Real-Time Protection" 'DisableScriptScanning' DWord 0
SR "$wd\Real-Time Protection" 'DisableIOAVProtection' DWord 0
SR "$wd" 'PUAProtection' DWord 1
SR "$wd\Spynet" 'SpynetReporting' DWord 2
SR "$wd\Spynet" 'SubmitSamplesConsent' DWord 1
SR "$wd\MpEngine" 'MpCloudBlockLevel' DWord 2
SR "$wd\MpEngine" 'MpBafsExtendedTimeout' DWord 50
"AV: real-time + behavior + script scan ON, PUA block, cloud-delivered protection High, sample submission ON."
if ($script:fails -gt 0) { "RESULT: $($script:fails) registry write(s) FAILED. The GPO is only partly built. Read the FAILED lines above." } else { "RESULT: all registry writes succeeded." }
# --- link to the Hardened Systems OU ---
$links = @((Get-GPInheritance -Target $ouDn).GpoLinks | ForEach-Object { $_.DisplayName })
if ($links -notcontains $GpoName) { New-GPLink -Name $GpoName -Target $ouDn -LinkEnabled Yes -ErrorAction SilentlyContinue | Out-Null; "Linked '$GpoName' -> $ouDn" } else { "Link already present." }
"NOTE: Tamper Protection is NOT configurable via GPO - set it in the Defender portal or Intune (Settings -> Endpoints -> Advanced features / Intune endpoint security)."
"DONE. Open it in Group Policy Management (gpmc.msc) to review the settings."
'@
    $tmp = Join-Path $env:TEMP 'defender-baseline-gpo.ps1'; $body | Set-Content $tmp -Encoding utf8
    Invoke-OnWindowsVm $CFG.Dc $tmp @('GpoName','Defender Baseline','OuName',$CFG.HardenedOU,'Enforce',"$enf")
    Write-Host ""
    Write-Host "  To look at it on $($CFG.Dc): run gpmc.msc -> Forest -> Domains -> $($CFG.DomainName) -> Group Policy Objects -> 'Defender Baseline'" -ForegroundColor Yellow
    Write-Host "  ASR events (when a box has the policy) show in Advanced hunting: DeviceEvents | where ActionType startswith 'Asr'" -ForegroundColor DarkGray
    Ok "'Defender Baseline' GPO built ($modeWord) and linked to '$($CFG.HardenedOU)'. Tamper Protection stays a portal/Intune setting."
}

# --- 3) attacker box (Kali) ----------------------------------------------
# Lean workshop: Kali is deployed from the base Azure image and nothing is
# auto-installed on it. You SSH in and bring up Sliver / whatever C2 you want
# by hand (paste your own commands). Bring your own C2.
function Step-SshInto {
    param([string]$Target = '')
    Narrate "Open an SSH console to KALI (its public IP is looked up for you)."

    if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
        Warn "The OpenSSH client isn't installed on this box. Add it once:"
        Write-Host "    Settings > System > Optional features > Add a feature > 'OpenSSH Client'" -ForegroundColor White
        Write-Host "    or in an elevated pwsh:  Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0" -ForegroundColor White
        return
    }

    $Target = $CFG.Kali
    ShowCmd "az vm show -d -g $($CFG.ResourceGroup) -n $Target --query publicIps -o tsv"
    $ip = az vm show -d -g $CFG.ResourceGroup -n $Target --query "publicIps" -o tsv 2>$null
    $ip = ($ip | Select-Object -First 1)
    if (-not $ip) {
        Warn "Couldn't get a public IP for $Target. Make sure it's running (menu 1 -> 4 Status; 1 -> 2 to start),"
        Warn "and that your current IP is authorized for SSH (menu 1 -> 9)."
        return
    }
    $user = if ($CFG.AdminUser){ $CFG.AdminUser } else { 'labadmin' }
    Ok "$Target  ->  $ip   (SSH user: $user; it'll prompt for the admin password you set at deploy)"
    # --- make sure KALI can resolve + auth to the AD zone --------------------
    # KALI isn't domain-joined, so nothing set its DNS; left alone it uses Azure
    # DNS and can't resolve the lab domain (NXDOMAIN on dc01), and kinit trips on
    # the realm case. Fix both once, as root via run-command (no SSH/sudo): a
    # DC-only resolver persisted by a tiny boot service + a correct krb5.conf.
    $dcIp   = if ($CFG.DcIp)       { $CFG.DcIp }       else { '192.168.57.10' }
    $dom    = if ($CFG.DomainName) { $CFG.DomainName } else { 'lab.local' }
    $realm  = $dom.ToUpper()
    $dcHost = "$($CFG.Dc).$dom"
    $kaliDns = @'
set +e
IF=$(ip route show default | awk '{print $5; exit}')
resolvectl dns "$IF" __DCIP__
resolvectl domain "$IF" __DOM__
cat >/usr/local/sbin/lab-dns.sh <<'LDNS'
#!/bin/bash
IF=$(ip route show default | awk '{print $5; exit}')
resolvectl dns "$IF" __DCIP__
resolvectl domain "$IF" __DOM__
resolvectl flush-caches
LDNS
chmod +x /usr/local/sbin/lab-dns.sh
cat >/etc/systemd/system/lab-dns.service <<'LSVC'
[Unit]
Description=Point resolver at lab DC (__DOM__)
After=network-online.target
Wants=network-online.target
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/lab-dns.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
LSVC
cat >/etc/krb5.conf <<'KRB'
[libdefaults]
    default_realm = __REALM__
    dns_lookup_realm = false
    dns_lookup_kdc = true
    rdns = false
[realms]
    __REALM__ = {
        kdc = __DCHOST__
        admin_server = __DCHOST__
    }
[domain_realm]
    .__DOM__ = __REALM__
    __DOM__ = __REALM__
KRB
systemctl daemon-reload
systemctl enable --now lab-dns.service >/dev/null 2>&1
resolvectl flush-caches
echo LABDNS_DONE
'@ -replace '__DCIP__',$dcIp -replace '__DOM__',$dom -replace '__REALM__',$realm -replace '__DCHOST__',$dcHost
    Info "Pointing $Target's resolver at the DC ($dcIp) + writing krb5.conf so it can resolve and auth to $dom ..."
    Log "Configure KALI DNS+krb5 -> $dcIp / $realm via run-command" 'CMD'
    $dnsMsg = Invoke-LinuxCmd $Target $kaliDns -Quiet
    if ($dnsMsg -match 'LABDNS_DONE'){
        Ok "$Target resolver now points at the DC and krb5.conf is set  (kinit labuser@$realm will work; lowercase works too)."
    } else {
        Warn "Couldn't auto-configure $Target DNS (opening the session anyway). If AD names don't resolve, paste once in the shell:"
        Write-Host "    IF=`$(ip route show default | awk '{print `$5; exit}'); sudo resolvectl dns `"`$IF`" $dcIp; sudo resolvectl domain `"`$IF`" $dom; sudo resolvectl flush-caches" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "  Base Kali - install your own tooling once you're in. For example (Sliver):" -ForegroundColor Yellow
    Write-Host "    curl https://sliver.sh/install | sudo bash     # Bishop Fox Sliver (sliver.sh/docs)" -ForegroundColor White
    Write-Host "    sudo systemctl start sliver                    # or: sliver-server    (operator console)" -ForegroundColor White
    Write-Host "    #  bind a listener on the lab wire (192.168.57.5) -> beacon -> run on WIN11 -> detect in the portal" -ForegroundColor DarkGray
    Write-Host ""
    ShowCmd "ssh $user@$ip"
    Warn "Launching SSH in this window. Type 'exit' in the session to come back to the menu."
    Log "SSH to $Target ($user@$ip)" 'CMD'
    try { & ssh "$user@$ip" } catch { Warn "SSH exited / failed: $($_.Exception.Message)" }
}

# --- 4) blue-team / Defender XDR -----------------------------------------
function Step-GetOnboarding {
    Narrate "Getting the Defender for Endpoint onboarding package from the portal."
    $pkgDir = Join-Path $HERE 'guest'
    Info "Opening the Defender portal onboarding page in your browser..."
    $url = 'https://security.microsoft.com/securitysettings/endpoints/onboarding'
    ShowCmd "Start-Process '$url'"
    try { Start-Process $url } catch { Warn "Couldn't auto-open a browser. Go to: $url" }
    Write-Host ""
    Info "In the portal:"
    Write-Host "    1. Settings -> Endpoints -> Onboarding"
    Write-Host "    2. Operating system: 'Windows 10 and 11'   (do the same for 'Windows Server' if you onboard DC01/SRV01)"
    Write-Host "    3. Deployment method: 'Local Script'"
    Write-Host "    4. Click 'Download onboarding package' (a .zip)"
    Write-Host "    5. Extract it and copy 'WindowsDefenderATPLocalOnboardingScript.cmd' into:"
    Write-Host "         $pkgDir" -ForegroundColor White
    Write-Host ""
    Warn "Requires Defender for Endpoint Plan 2 on the tenant. The onboarding step (next) runs that package on the target for you."
    $cmd = Join-Path $pkgDir 'WindowsDefenderATPLocalOnboardingScript.cmd'
    if (Test-Path $cmd) { Ok "Found the onboarding script in guest\ - you're ready for the Onboard step." }
    else { Warn "Not found yet in guest\ - drop the .cmd there, then run the Onboard step." }
}
function Step-Onboard {
    Narrate "Onboarding victim A ($($CFG.Win11)) to Defender for Endpoint."
    Info "By design we onboard $($CFG.Win11) ONLY. $($CFG.Win11b) stays on stock Defender AV (not onboarded) so you can compare what the XDR console sees on each."
    $cmd = Join-Path $HERE 'guest/WindowsDefenderATPLocalOnboardingScript.cmd'
    if (-not (Test-Path $cmd)) { Warn "Onboarding package not found in guest\. Run 'Get the onboarding package' first (menu 4 -> 1)."; return }
    Invoke-OnWindowsVm $CFG.Win11 (Join-Path $HERE 'guest/05-Onboard-Defender.ps1') $null
}
function Step-Harden {
    Narrate "Applying Controlled Folder Access + network protection (the ransomware-defense posture)."
    Invoke-OnWindowsVm $CFG.Win11 (Join-Path $HERE 'guest/07-Harden-TamperProtection-CFA.ps1') @('Mode','Block')
}
function Step-VerifyDefense {
    Narrate "Confirming the defensive posture (onboarding, Sense, ASR, CFA) on the target."
    Invoke-OnWindowsVm $CFG.Win11 (Join-Path $HERE 'guest/08-Verify-Lab.ps1') @('DomainName',$CFG.DomainName,'DcIp',$CFG.DcIp)
}
# --- Defender for Identity (MDI) - sensor on the DC -----------------------
function Step-GetMdi {
    Narrate "Getting the Defender for Identity (MDI) sensor package from the portal."
    $url = 'https://security.microsoft.com/settings/identities'
    ShowCmd "Start-Process '$url'"
    try { Start-Process $url } catch { Warn "Couldn't auto-open a browser. Go to: $url" }
    Write-Host ""
    Info "In the portal (Settings -> Identities):"
    Write-Host "    1. Sensors -> 'Add sensor' -> download the sensor installer (.zip), and COPY the Access Key shown there."
    Write-Host "    2. Extract the zip, then copy 'Azure ATP sensor Setup.exe' onto DC01 at:  $($CFG.MdiStagePath)"
    Write-Host "    3. Put the Access Key in a text file on DC01 at:  $($CFG.MdiStagePath)\mdi-accesskey.txt"
    Write-Host "       (RDP to DC01 to copy them, or use your own file-copy method.)"
    Write-Host ""
    Warn "MDI needs a Directory Service Account too (Settings -> Identities -> Directory service accounts; a gMSA is recommended)."
    Info "Then run 'Install MDI sensor on DC01' (next item)."
}
function Step-InstallMdi {
    Narrate "Installing the MDI sensor on $($CFG.Dc) from the staged package ($($CFG.MdiStagePath))."
    Info "This runs the documented silent install on the DC; it can reboot the DC if .NET gets installed."
    Invoke-OnWindowsVm $CFG.Dc (Join-Path $HERE 'guest/09-Install-MDI-Sensor.ps1') @('StagePath',$CFG.MdiStagePath)
    Narrate "Give it a few minutes, then check security.microsoft.com -> Settings -> Identities -> Sensors for $($CFG.Dc), and don't forget the Directory Service Account."
}
function Step-MdiGmsa {
    Narrate "Automating the MDI Directory Service Account (gMSA) on $($CFG.Dc) - the one manual MDI piece the portal can't do for you."
    Info "Your tenant already has auto Windows-auditing + auto sensor v3.x ON, so the DSA (gMSA) is all that's left. This creates it; you then register it once in the portal (steps printed below)."
    Warn "NOTE: this is a BRAND-NEW AD forest, so there is no KDS root key yet - a gMSA cannot exist without one. This step creates it (Add-KdsRootKey). Normally you wait 10 hours for it to replicate before use; in a single-DC lab we backdate it so it's usable immediately."
    $body = @'
param([string]$GmsaName)
Import-Module ActiveDirectory -ErrorAction Stop
# KDS root key - required before any gMSA. Backdate 10h so it's usable now (lab).
if (-not (Get-KdsRootKey)) {
    # New forest => no KDS root key exists yet, and a gMSA cannot be created
    # without one. Backdate it 10h so it's usable now (lab single-DC shortcut;
    # in production you wait ~10h for domain-wide replication first).
    Add-KdsRootKey -EffectiveTime ((Get-Date).AddHours(-10)) | Out-Null
    "KDS root key created (new AD had none; backdated so the gMSA works immediately)."
} else { "KDS root key already present." }
# A group of principals allowed to retrieve the password = the Domain Controllers.
$grpName = 'MDI-gMSA-Readers'
if (-not (Get-ADGroup -Filter "Name -eq '$grpName'" -ErrorAction SilentlyContinue)) {
    New-ADGroup -Name $grpName -GroupScope Global -GroupCategory Security | Out-Null
    "Group $grpName created."
}
# add every domain controller computer account to the readers group
Get-ADDomainController -Filter * | ForEach-Object {
    $dc = Get-ADComputer $_.Name
    Add-ADGroupMember -Identity $grpName -Members $dc -ErrorAction SilentlyContinue
}
if (-not (Get-ADServiceAccount -Filter "Name -eq '$GmsaName'" -ErrorAction SilentlyContinue)) {
    $dnsHost = "$GmsaName." + (Get-ADDomain).DNSRoot
    New-ADServiceAccount -Name $GmsaName -DNSHostName $dnsHost `
        -PrincipalsAllowedToRetrieveManagedPassword $grpName -ErrorAction Stop
    "gMSA created: $GmsaName  (DNSHostName $dnsHost)"
} else { "gMSA $GmsaName already present." }
"DONE. Register this gMSA as the MDI Directory Service Account in the portal."
'@
    $tmp = Join-Path $env:TEMP 'mdi-gmsa.ps1'; $body | Set-Content $tmp -Encoding utf8
    Invoke-OnWindowsVm $CFG.Dc $tmp @('GmsaName','svc-mdi')
    Write-Host ""
    Write-Host "  Finish in the portal (Settings -> Identities -> Microsoft Defender for Identity):" -ForegroundColor Yellow
    Write-Host "    1. Directory service accounts -> Add credentials"
    Write-Host "    2. Account type: Group managed service account (gMSA)"
    Write-Host "    3. Account name: svc-mdi     Domain: $($CFG.DomainName)"
    Write-Host "    4. Save. The sensor on $($CFG.Dc) will start using it within a few minutes."
    $url = 'https://security.microsoft.com/settings/identities'
    try { Start-Process $url } catch {}
    Ok "gMSA svc-mdi created on $($CFG.Dc). Register it in the portal (page opened; steps above)."
}
# --- Microsoft Sentinel - advanced detection + hunting -------------------
function Step-DeploySentinel {
    Narrate "Deploying Microsoft Sentinel (Log Analytics workspace + enable + Azure Activity)."
    $acct = Show-AzContext
    if (-not $acct) { Warn "Sign in first (menu L)."; return }
    Warn "Sentinel is a PAID service. Target subscription: $($acct.name). Keep it in the lab subscription."
    if (-not $NonInteractive) {
        $go = Read-Host "  Type YES to deploy Sentinel into '$($acct.name)', or anything else to cancel"
        if ($go -ne 'YES') { Warn "Cancelled."; return }
    }
    $loc = ($CFG.Location -replace '\s','').ToLower()
    ShowCmd ".\Deploy-Sentinel.ps1 -ResourceGroup $($CFG.ResourceGroup) -Location $loc -WorkspaceName $($CFG.WorkspaceName)"
    & (Join-Path $HERE 'Deploy-Sentinel.ps1') -ResourceGroup $CFG.ResourceGroup -Location $loc -WorkspaceName $CFG.WorkspaceName
}
function Step-OpenHunting {
    Narrate "Opening Advanced hunting (Defender portal) to run KQL across the lab's signals."
    $url = 'https://security.microsoft.com/v2/advanced-hunting'
    ShowCmd "Start-Process '$url'"
    try { Start-Process $url } catch { Warn "Go to: $url" }
    Info "Starter queries are in the Lab Guide / Course Map. The Defender XDR connector feeds MDE+MDI alerts into Sentinel too."
}
# --- Hunt from the kit ----------------------------------------------------
# Run the course's KQL hunts against the lab and show the results right here.
# Three ways to reach the data, tried in this order:
#   1. Microsoft Graph advanced hunting (runHuntingQuery) - the XDR tables
#      (Device*, Identity*, Alert*). Uses the Microsoft.Graph.Authentication
#      module if installed (menu 4 -> G sets it up), else tries 'az rest'.
#   2. The lab's Sentinel / Log Analytics workspace (menu 6 -> 1) - AzureActivity,
#      AuditLogs, SecurityEvent, and the XDR tables if they're streamed there.
#   3. Otherwise: copy the query to the clipboard and open Advanced hunting.
# All queries are read-only. {WINDOW} is replaced with the time window you pick.
$HuntCatalog = @(
    [ordered]@{ Id='1'; Src='XDR'; Name='Lab devices in Defender: onboarding + sensor health'; Kql=@'
DeviceInfo
| where Timestamp > ago({WINDOW})
| summarize arg_max(Timestamp, *) by DeviceName
| project DeviceName, OSPlatform, OnboardingStatus, SensorHealthState, LastSeen = Timestamp
| order by DeviceName asc
'@ },
    [ordered]@{ Id='2'; Src='XDR'; Name='Alerts by product (MDE, MDI, Defender for Cloud...)'; Kql=@'
AlertInfo
| where Timestamp > ago({WINDOW})
| summarize Alerts = count(), Titles = make_set(Title, 8) by ServiceSource, Severity
| order by Alerts desc
'@ },
    [ordered]@{ Id='3'; Src='XDR'; Name='Recent alerts with the devices and accounts involved'; Kql=@'
AlertInfo
| where Timestamp > ago({WINDOW})
| join kind=inner (AlertEvidence
    | where Timestamp > ago({WINDOW})
    | where EntityType in ("Machine", "User")
    | project AlertId, EntityType, DeviceName, AccountName) on AlertId
| project Timestamp, Title, ServiceSource, Severity, EntityType, DeviceName, AccountName
| order by Timestamp desc
'@ },
    [ordered]@{ Id='4'; Src='XDR'; Name='Beat 2 - who is asking the directory questions (MDI)'; Kql=@'
IdentityQueryEvents
| where Timestamp > ago({WINDOW})
| summarize Queries = count(), Types = make_set(QueryType), Targets = make_set(QueryTarget, 10)
    by DeviceName, AccountName, Protocol
| order by Queries desc
'@ },
    [ordered]@{ Id='5'; Src='XDR'; Name='Beat 3 - one account reaching many hosts'; Kql=@'
DeviceLogonEvents
| where Timestamp > ago({WINDOW})
| where ActionType == "LogonSuccess"
| where LogonType in ("Network", "RemoteInteractive")
| summarize Hosts = dcount(DeviceName), HostList = make_set(DeviceName) by AccountDomain, AccountName
| where Hosts >= 2
| order by Hosts desc
'@ },
    [ordered]@{ Id='6'; Src='XDR'; Name='Beat 4 - Kerberos activity seen by MDI (RC4 hints)'; Kql=@'
IdentityLogonEvents
| where Timestamp > ago({WINDOW})
| where Protocol == "Kerberos"
| where AdditionalFields has "0x17" or AdditionalFields has "rc4"
| project Timestamp, AccountName, DeviceName, TargetDeviceName, ActionType
| order by Timestamp desc
'@ },
    [ordered]@{ Id='7'; Src='XDR'; Name='PowerShell on the Windows 11 boxes, with its parent'; Kql=@'
DeviceProcessEvents
| where Timestamp > ago({WINDOW})
| where DeviceName startswith "win11"
| where FileName in~ ("powershell.exe", "pwsh.exe")
| project Timestamp, DeviceName, AccountName, InitiatingProcessFileName, ProcessCommandLine
| order by Timestamp desc
'@ },
    [ordered]@{ Id='8'; Src='XDR'; Name='Processes touching LSASS (credential access)'; Kql=@'
DeviceEvents
| where Timestamp > ago({WINDOW})
| where ActionType in ("OpenProcessApiCall", "ReadProcessMemoryApiCall")
| where FileName =~ "lsass.exe"
| where InitiatingProcessFileName !in~ ("MsMpEng.exe", "wininit.exe", "svchost.exe", "csrss.exe")
| project Timestamp, DeviceName, InitiatingProcessFileName, InitiatingProcessCommandLine, InitiatingProcessAccountName
| order by Timestamp desc
'@ },
    [ordered]@{ Id='9'; Src='XDR'; Name='ASR rules: what was audited or blocked'; Kql=@'
DeviceEvents
| where Timestamp > ago({WINDOW})
| where ActionType startswith "Asr"
| summarize Events = count(), Devices = dcount(DeviceName) by ActionType, FileName, InitiatingProcessFileName
| order by Events desc
'@ },
    [ordered]@{ Id='10'; Src='XDR'; Name='Antivirus detections on the lab boxes'; Kql=@'
DeviceEvents
| where Timestamp > ago({WINDOW})
| where ActionType == "AntivirusDetection"
| project Timestamp, DeviceName, FileName, FolderPath, InitiatingProcessFileName
| order by Timestamp desc
'@ },
    [ordered]@{ Id='11'; Src='LA'; Name='Module 0 - run command on the lab VMs (Azure Activity)'; Kql=@'
AzureActivity
| where TimeGenerated > ago({WINDOW})
| where OperationNameValue =~ "MICROSOFT.COMPUTE/VIRTUALMACHINES/RUNCOMMAND/ACTION"
| where ActivityStatusValue == "Success"
| extend VM = tostring(split(_ResourceId, "/")[-1])
| project TimeGenerated, Caller, CallerIpAddress, ResourceGroup, VM
| order by TimeGenerated desc
'@ },
    [ordered]@{ Id='12'; Src='LA'; Name='Module 0b - credentials added to apps / service principals'; Kql=@'
AuditLogs
| where TimeGenerated > ago({WINDOW})
| where OperationName == "Add service principal credentials"
     or OperationName has "Certificates and secrets management"
| extend Actor = tostring(InitiatedBy.user.userPrincipalName), Target = tostring(TargetResources[0].displayName)
| project TimeGenerated, OperationName, Actor, Target, Result
| order by TimeGenerated desc
'@ }
)

function Get-LabWorkspaceId {
    $id = az monitor log-analytics workspace show -g $CFG.ResourceGroup -n $CFG.WorkspaceName --query customerId -o tsv 2>$null
    if ($LASTEXITCODE -eq 0 -and $id) { return $id.Trim() }
    return $null
}
function Show-HuntRows($rows, [int]$Max = 25){
    $rows = @($rows)
    if ($rows.Count -eq 0) {
        Info "No results in this window. The lab may be quiet, or the data hasn't arrived yet (XDR data can take a few minutes; MDI and Activity log can take longer)."
        return
    }
    Ok "$($rows.Count) row(s)$(if($rows.Count -gt $Max){" - showing the first $Max"})"
    $rows | Select-Object -First $Max | Select-Object * -ExcludeProperty TableName, TenantId |
        Format-Table -AutoSize -Wrap | Out-String -Width 220 | Write-Host
    Log "HUNT returned $($rows.Count) row(s)" 'RESULT'
}
# Path 1a: Graph via the Microsoft.Graph.Authentication module (best: one consent, cached)
function Invoke-HuntGraphModule([string]$Kql){
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) { return $null }
    try {
        Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
        $ctx = Get-MgContext
        if (-not $ctx -or ($ctx.Scopes -notcontains 'ThreatHunting.Read.All')) {
            Info "Signing in to Microsoft Graph for advanced hunting (ThreatHunting.Read.All). A browser window may open once."
            Connect-MgGraph -Scopes 'ThreatHunting.Read.All' -NoWelcome -ErrorAction Stop
        }
        $resp = Invoke-MgGraphRequest -Method POST -Uri 'https://graph.microsoft.com/v1.0/security/runHuntingQuery' `
                    -Body (@{ Query = $Kql } | ConvertTo-Json) -ContentType 'application/json' -ErrorAction Stop
        return ,@($resp.results | ForEach-Object { [pscustomobject]$_ })
    } catch { Warn "Graph (module) hunting failed: $($_.Exception.Message)"; return $null }
}
# Path 1b: Graph via az rest (works only if your tenant lets the Azure CLI app use ThreatHunting.Read.All)
function Invoke-HuntGraphAz([string]$Kql){
    $tmp = Join-Path $env:TEMP ('hunt-' + [guid]::NewGuid().ToString('N').Substring(0,8) + '.json')
    (@{ Query = $Kql } | ConvertTo-Json) | Set-Content $tmp -Encoding utf8
    $raw = az rest --method post --url 'https://graph.microsoft.com/v1.0/security/runHuntingQuery' `
               --headers 'Content-Type=application/json' --body "@$tmp" -o json 2>&1
    $code = $LASTEXITCODE
    Remove-Item $tmp -ErrorAction SilentlyContinue
    if ($code -ne 0) { Log "az rest runHuntingQuery failed :: $raw" 'ERROR'; return $null }
    try { return ,@((($raw | Out-String) | ConvertFrom-Json).results) } catch { return $null }
}
# Path 2: the lab's Log Analytics / Sentinel workspace
function Invoke-HuntWorkspace([string]$Kql){
    $ws = Get-LabWorkspaceId
    if (-not $ws) { return $null }
    $raw = az monitor log-analytics query -w $ws --analytics-query $Kql -o json 2>&1
    if ($LASTEXITCODE -ne 0) { Log "log-analytics query failed :: $raw" 'ERROR'; Warn "Workspace query failed (table not in the workspace yet?). See the log for details."; return $null }
    try { return ,@(($raw | Out-String) | ConvertFrom-Json) } catch { return $null }
}
function Invoke-LabHunt([string]$Kql, [string]$Src = 'XDR'){
    Write-Host ""
    Write-Host $Kql -ForegroundColor DarkCyan
    Write-Host ""
    Log "HUNT ($Src):`n$Kql" 'CMD'
    $rows = $null
    if ($Src -eq 'XDR') {
        $rows = Invoke-HuntGraphModule $Kql
        if ($null -eq $rows) { $rows = Invoke-HuntGraphAz $Kql; if ($null -ne $rows) { Info "(ran through Microsoft Graph advanced hunting, via az)" } }
        else { Info "(ran through Microsoft Graph advanced hunting)" }
    }
    if ($null -eq $rows) {
        $rows = Invoke-HuntWorkspace $Kql
        if ($null -ne $rows) { Info "(ran in the lab workspace '$($CFG.WorkspaceName)')" }
    }
    if ($null -eq $rows) {
        Warn "Couldn't run this from here. The query is on your clipboard - paste it into Advanced hunting."
        if ($Src -eq 'XDR') { Info "To run XDR hunts from the kit: menu 4 -> G (one-time Graph sign-in), or stream the Defender XDR tables to Sentinel (menu 6 -> 2)." }
        else { Info "This one needs the lab's Sentinel workspace (menu 6 -> 1) with the connector for that table." }
        try { Set-Clipboard -Value $Kql } catch {}
        try { Start-Process 'https://security.microsoft.com/v2/advanced-hunting' } catch {}
        return
    }
    Show-HuntRows $rows
}
function Step-HuntSetup {
    Narrate "One-time setup so the kit can run advanced hunting (XDR tables) straight from here."
    Info "Installs the small Microsoft.Graph.Authentication module for YOUR user only, then signs you in with ThreatHunting.Read.All (read-only)."
    Info "The first sign-in may ask an admin to consent to 'Microsoft Graph Command Line Tools' reading hunting data."
    if (-not $NonInteractive) { if ((Read-Host "  Go ahead? (y/n)") -notmatch '^[Yy]') { return } }
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
        ShowCmd "Install-Module Microsoft.Graph.Authentication -Scope CurrentUser"
        try { Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop }
        catch { Warn "Install failed: $($_.Exception.Message)"; return }
    }
    try {
        Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
        ShowCmd "Connect-MgGraph -Scopes ThreatHunting.Read.All"
        Connect-MgGraph -Scopes 'ThreatHunting.Read.All' -NoWelcome -ErrorAction Stop
        Ok "Signed in as $((Get-MgContext).Account). Hunts will now run through Graph."
    } catch { Warn "Sign-in failed: $($_.Exception.Message)" }
}
function Step-Hunt {
    $window = '1d'
    do {
        Header
        Write-Host "  HUNT THE LAB - run the course's KQL and see the results here   (window: $window)`n" -ForegroundColor Yellow
        foreach ($h in $HuntCatalog) {
            $tag = if ($h.Src -eq 'LA') { ' [Sentinel]' } else { '' }
            Write-Host ("    {0,2}) {1}{2}" -f $h.Id, $h.Name, $tag)
        }
        Write-Host "     W) Change the time window (1h, 4h, 1d, 7d)" -ForegroundColor DarkGray
        Write-Host "     Q) Type your own KQL" -ForegroundColor DarkGray
        Write-Host "     0) Back`n"
        $c = Read-Host "  Select"
        if ($c -match '^[Ww]$') { $w = Read-Host "  Window [$window]"; if ($w -match '^\d+[mhd]$') { $window = $w } else { Warn "Use a number plus m, h or d (e.g. 4h)." }; continue }
        if ($c -match '^[Qq]$') {
            Info "Paste your KQL. Finish with a line containing only a dot (.)"
            $lines = @(); while (($l = Read-Host) -ne '.') { $lines += $l }
            $src = if ((Read-Host "  Source: X=XDR advanced hunting, S=Sentinel workspace [X]") -match '^[Ss]$') { 'LA' } else { 'XDR' }
            Invoke-LabHunt ($lines -join "`n") $src; Pause; continue
        }
        $h = $HuntCatalog | Where-Object { $_.Id -eq $c } | Select-Object -First 1
        if ($h) {
            Narrate $h.Name
            Invoke-LabHunt ($h.Kql -replace '\{WINDOW\}', $window) $h.Src
            Pause
        }
    } while ($c -ne '0')
}

function Step-HuntingPack {
    Narrate "Post-exploit threat-hunting pack - KQL you can paste into Advanced hunting for each technique we run."
    $doc = Join-Path $HERE 'Sentinel-Hunting-Pack.md'
    if (Test-Path $doc){
        Info "Full pack: $doc"
        ShowCmd "Start-Process '$doc'"
        try { Start-Process $doc } catch {}
    } else {
        Warn "Sentinel-Hunting-Pack.md not found beside this script - the queries are also in the Course Map."
    }
    Write-Host ""
    Write-Host "  A few headline queries (paste into security.microsoft.com -> Advanced hunting):" -ForegroundColor Yellow
    Write-Host "    # Kerberoasting (svc-sql) - MDI alert + raw Kerberos TGS" -ForegroundColor DarkGray
    Write-Host '    IdentityLogonEvents | where Timestamp > ago(1h) | where Protocol == "Kerberos"' -ForegroundColor White
    Write-Host "    # LSASS access (credential theft)" -ForegroundColor DarkGray
    Write-Host '    DeviceEvents | where ActionType == "OpenProcessApiCall" | where FileName =~ "lsass.exe"' -ForegroundColor White
    Write-Host "    # DCSync / replication from a non-DC" -ForegroundColor DarkGray
    Write-Host '    IdentityDirectoryEvents | where ActionType == "Directory Services replication"' -ForegroundColor White
    Info "The full .md has one hunting query per technique (T-02..T-11) with what-to-look-for notes."
}

function Step-KqlFolder {
    Narrate "Run a whole folder of your own KQL hunts from here - each one read-only, row counts and a preview shown, with an optional PASS/FAIL test pass and CSV/JSON export."
    $runner = Join-Path $HERE 'Invoke-KqlHunt.ps1'
    if (-not (Test-Path $runner)) { Warn "Invoke-KqlHunt.ps1 not found beside this script ($HERE)."; return }
    $def = Join-Path $HERE 'queries'
    $folder = if (-not $NonInteractive) { Read-Host "  Folder of .kql files [$def]" } else { $def }
    if (-not $folder) { $folder = $def }
    $folder = $folder.Trim('"')
    if (-not (Test-Path $folder)) { Warn "Not found: $folder"; return }
    $runArgs = @('-Path', $folder, '-ResourceGroup', $CFG.ResourceGroup, '-Workspace', $CFG.WorkspaceName)
    if (-not $NonInteractive) {
        $only = Read-Host "  Filter (wildcard on file name; blank = all, e.g. 3* or *lsass*)"
        if ($only) { $runArgs += @('-Only', $only) }
        if ((Read-Host "  Test mode - add PASS/EMPTY/FAIL per query? (y/N)") -match '^[Yy]') { $runArgs += '-Test' }
        if ((Read-Host "  Export results (CSV+JSON) to a folder? (y/N)") -match '^[Yy]') {
            $out = Join-Path $HERE ("hunt-results\{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
            $runArgs += @('-Export', $out)
        }
    } else {
        $out = Join-Path $HERE ("hunt-results\{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
        $runArgs += @('-Test', '-Export', $out)
    }
    ShowCmd ("Invoke-KqlHunt.ps1 " + ($runArgs -join ' '))
    & $runner @runArgs
}

# --- CIS Benchmark hardening (operator supplies the GPO zip) --------------
# Extract ONLY the requested policy folder from the (large) CIS benchmark zip
# into a small zip we can push to the DC over the Azure agent.
function Shrink-CisZip([string]$LocalZip,[string]$PolicyFolder){
    if (-not (Test-Path $LocalZip)) { Warn "CIS zip not found: $LocalZip"; return $null }
    $work = Join-Path $env:TEMP ("cissrc-" + [guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    Info "Extracting '$PolicyFolder' from $(Split-Path -Leaf $LocalZip)..."
    Expand-Archive -LiteralPath $LocalZip -DestinationPath $work -Force
    $pol = Get-ChildItem -Path $work -Directory -Recurse -Filter $PolicyFolder -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $pol) { Warn "Policy folder '$PolicyFolder' not inside the zip. Present: $((Get-ChildItem $work -Directory|Select-Object -Expand Name) -join ', ')"; return $null }
    $small = Join-Path $env:TEMP ("cis-$PolicyFolder.zip")
    if (Test-Path $small) { Remove-Item $small -Force }
    Compress-Archive -Path $pol.FullName -DestinationPath $small
    Ok "Prepared $small"
    return $small
}
function Ask-CisZip([string]$which){
    # which = 'Server' or 'Win11'; returns the saved/prompted local zip path
    $key = if ($which -eq 'Server'){ 'CisServerZip' } else { 'CisWin11Zip' }
    $cur = $CFG.$key
    $p = Read-Host "  Path to your CIS $which benchmark GPO zip [$cur]"
    if (-not $p) { $p = $cur }
    if (-not $p) { Warn "No zip path given."; return $null }
    $p = $p.Trim('"')
    if (-not (Test-Path $p)) { Warn "Not found: $p"; return $null }
    $CFG.$key = $p; Save-Cfg $CFG
    return $p
}
function Step-CisApplyDC {
    Narrate "Applying the CIS Server benchmark (Level 1) to the Domain Controllers OU."
    $zip = Ask-CisZip 'Server'; if (-not $zip){ return }
    $pf  = Read-Host "  Policy folder inside the zip [$($CFG.CisDcPolicy)]"; if ($pf){ $CFG.CisDcPolicy = $pf; Save-Cfg $CFG }
    $small = Shrink-CisZip $zip $CFG.CisDcPolicy; if (-not $small){ return }
    $remote = "$($CFG.CisStagePath)\$($CFG.CisDcPolicy).zip"
    if (-not (Push-FileToVm $CFG.Dc $small $remote)){ return }
    Invoke-OnWindowsVm $CFG.Dc (Join-Path $HERE 'guest/10-Apply-CIS-GPO.ps1') @('Action','ApplyDC','ZipPath',$remote,'PolicyFolder',$CFG.CisDcPolicy)
    Narrate "DC01 is now CIS-hardened. Re-run a DC-side technique (e.g. DCSync / Kerberoast) and compare what still works and what alerts fire."
}
function Step-CisRemoveDC {
    Narrate "Removing the CIS policy from the Domain Controllers OU (back to baseline)."
    Invoke-OnWindowsVm $CFG.Dc (Join-Path $HERE 'guest/10-Apply-CIS-GPO.ps1') @('Action','RemoveDC')
}
function Step-CisApplyWks([string]$box){
    if (-not $box){ $box = $CFG.AttackTarget }
    Narrate "Applying the CIS Windows 11 benchmark (Level 1) to $box."
    $zip = Ask-CisZip 'Win11'; if (-not $zip){ return }
    $pf  = Read-Host "  Policy folder inside the zip [$($CFG.CisWin11Policy)]"; if ($pf){ $CFG.CisWin11Policy = $pf; Save-Cfg $CFG }
    $small = Shrink-CisZip $zip $CFG.CisWin11Policy; if (-not $small){ return }
    $remote = "$($CFG.CisStagePath)\$($CFG.CisWin11Policy).zip"
    if (-not (Push-FileToVm $CFG.Dc $small $remote)){ return }
    Invoke-OnWindowsVm $CFG.Dc (Join-Path $HERE 'guest/10-Apply-CIS-GPO.ps1') `
        @('Action','ApplyWorkstation','ZipPath',$remote,'PolicyFolder',$CFG.CisWin11Policy,'ComputerName',$box,'WorkstationsOU',$CFG.CisWorkstationsOU)
    Invoke-GpUpdate $box
    Narrate "$box is now CIS-hardened. Re-run the same technique and compare the outcome against the un-hardened box."
}
function Step-CisRemoveWks([string]$box){
    if (-not $box){ $box = $CFG.AttackTarget }
    Narrate "Removing CIS hardening from $box (move back to baseline)."
    Invoke-OnWindowsVm $CFG.Dc (Join-Path $HERE 'guest/10-Apply-CIS-GPO.ps1') @('Action','RemoveWorkstation','ComputerName',$box)
    Invoke-GpUpdate $box
}
function Step-CisSettings {
    Narrate "CIS settings (zip paths + policy folder names)."
    foreach ($k in @('CisServerZip','CisWin11Zip','CisDcPolicy','CisMsPolicy','CisWin11Policy','CisWorkstationsOU','CisStagePath')) {
        $v = Read-Host "  $k [$($CFG.$k)]"; if ($v){ $CFG.$k = $v.Trim('"') }
    }
    Save-Cfg $CFG; Ok "Saved."
}
# Push a (possibly multi-MB) local file to a Windows VM over the Azure agent by
# splitting base64 into chunks appended to the remote file (run-command caps the
# per-call script size, so a single base64 blob won't fit for a big zip).
function Push-LargeFileToVm($VmName,$LocalPath,$RemotePath){
    if (-not (Test-Path $LocalPath)) { Warn "File not found: $LocalPath"; return $false }
    $bytes = [IO.File]::ReadAllBytes($LocalPath)
    $b64 = [Convert]::ToBase64String($bytes)
    $chunk = 150000   # base64 chars per run-command call (safe under the size cap)
    $total = [math]::Ceiling($b64.Length / $chunk)
    $dir = Split-Path -Parent $RemotePath
    Info "Uploading $(Split-Path -Leaf $LocalPath) to ${VmName}:$RemotePath ($([math]::Round($bytes.Length/1MB,1)) MB in $total chunks)..."
    for ($i=0; $i -lt $total; $i++){
        $part = $b64.Substring($i*$chunk, [math]::Min($chunk, $b64.Length - $i*$chunk))
        if ($i -eq 0){
            $ps = "New-Item -ItemType Directory -Force -Path '$dir' | Out-Null; Set-Content -Path '$RemotePath.b64' -Value '$part' -NoNewline"
        } else {
            $ps = "Add-Content -Path '$RemotePath.b64' -Value '$part' -NoNewline"
        }
        $tmp = Join-Path $env:TEMP ("chunk-$i.ps1"); $ps | Set-Content $tmp -Encoding ascii
        az vm run-command invoke -g $CFG.ResourceGroup -n $VmName --command-id RunPowerShellScript --scripts "@$tmp" -o none 2>$null
        Remove-Item $tmp -ErrorAction SilentlyContinue
        Write-Host ("    chunk {0}/{1}" -f ($i+1), $total) -ForegroundColor DarkGray
    }
    # decode on the VM
    $fin = "[IO.File]::WriteAllBytes('$RemotePath',[Convert]::FromBase64String((Get-Content '$RemotePath.b64' -Raw))); Remove-Item '$RemotePath.b64'; if(Test-Path '$RemotePath'){'staged '+(Get-Item '$RemotePath').Length+' bytes -> $RemotePath'}else{'FAILED'}"
    $tmp = Join-Path $env:TEMP 'finalize.ps1'; $fin | Set-Content $tmp -Encoding ascii
    Invoke-OnWindowsVm $VmName $tmp $null
    return $true
}
# Copy the two CIS benchmark zips (operator supplies them) to the DC's Public
# Desktop so they can be shown/opened during the class. Nothing CIS is bundled.
function Step-CopyCisToDc {
    Narrate "Copying the CIS Benchmark zips to $($CFG.Dc)'s Public Desktop (so you can show them in class)."
    Info "You supply the zips (your CIS membership export); they are NOT stored in the kit."
    $srv = Ask-CisZip 'Server'
    $wks = Ask-CisZip 'Win11'
    if (-not $srv -and -not $wks){ Warn "No zips set - nothing to copy."; return }
    $deskDir = 'C:\Users\Public\Desktop\CIS-Benchmarks'
    if ($srv){ Push-LargeFileToVm $CFG.Dc $srv "$deskDir\$(Split-Path -Leaf $srv)" | Out-Null }
    if ($wks){ Push-LargeFileToVm $CFG.Dc $wks "$deskDir\$(Split-Path -Leaf $wks)" | Out-Null }
    Ok "CIS zips copied to $($CFG.Dc): $deskDir (visible on the DC's desktop)."
}
# Split the CIS L1 policies (DC, Member Server, Windows 11) into one GPO per
# settings area and import them on DC01 UNLINKED, named
# "DefXDR CIS L1 <DC|MS|Win11> - <area>". The split runs here on your PC
# from your own zips (tools/Split-CisGpo.ps1); only the split backups go to DC01.
function Step-CisSplit {
    # The 42 split GPOs are already built and ship in CIS-GPOs\ (keep that folder
    # out of any public repo - it is CIS content). If it is there, just import them.
    $prebuilt = Join-Path $HERE 'CIS-GPOs/DefXDR-CIS-L1-Split.zip'
    if (Test-Path $prebuilt) {
        Narrate "Creating the 42 'DefXDR CIS L1' GPOs on $($CFG.Dc), UNLINKED (from the pre-built set in CIS-GPOs\)."
        $remote = "$($CFG.CisStagePath)\cis-split.zip"
        if (-not (Push-LargeFileToVm $CFG.Dc $prebuilt $remote)){ return }
        Invoke-OnWindowsVm $CFG.Dc (Join-Path $HERE 'guest/13-Import-CIS-Split.ps1') @('ZipPath',$remote)
        Info "Check the RESULT line above. The GPOs are unlinked; link them in GPMC where you want them."
        Info "Account Policies (password/lockout/Kerberos) only take effect for domain accounts when linked at the DOMAIN ROOT."
        Info "Security Options rename only the built-in guest account to CISGUEST - the Administrator rename was removed so the lab keeps its known admin logon - and MS/Win11 User Rights deny RDP to local accounts."
        return
    }
    Narrate "Splitting the CIS L1 policies into one GPO per settings area, imported on $($CFG.Dc) UNLINKED."
    Info "No pre-built set in CIS-GPOs\ - splitting from your own CIS zips instead."
    $splitter = Join-Path $HERE 'tools/Split-CisGpo.ps1'
    if (-not (Test-Path $splitter)) { Warn "Missing $splitter"; return }
    $srv = Ask-CisZip 'Server'
    $wks = Ask-CisZip 'Win11'
    if (-not $srv -and -not $wks){ Warn "No zips set - nothing to split."; return }

    $work = Join-Path $env:TEMP ('cis-split-' + [guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    $jobs = @()
    if ($srv){ $jobs += ,@($srv, $CFG.CisDcPolicy, 'DC'); $jobs += ,@($srv, $CFG.CisMsPolicy, 'MS') }
    if ($wks){ $jobs += ,@($wks, $CFG.CisWin11Policy, 'Win11') }
    foreach ($j in $jobs){
        Info "Splitting $($j[1]) from $(Split-Path -Leaf $j[0]) ..."
        try { & $splitter -ZipPath $j[0] -PolicyFolder $j[1] -Label $j[2] -OutDir $work }
        catch { Warn "Split of $($j[1]) failed: $($_.Exception.Message)"; Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue; return }
    }
    $zip = Join-Path $env:TEMP 'cis-split.zip'
    Remove-Item $zip -ErrorAction SilentlyContinue
    Compress-Archive -Path (Join-Path $work '*') -DestinationPath $zip
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue

    $remote = "$($CFG.CisStagePath)\cis-split.zip"
    if (-not (Push-LargeFileToVm $CFG.Dc $zip $remote)){ return }
    Invoke-OnWindowsVm $CFG.Dc (Join-Path $HERE 'guest/13-Import-CIS-Split.ps1') @('ZipPath',$remote)
    Remove-Item $zip -ErrorAction SilentlyContinue
    Info "Check the RESULT line above. The GPOs are unlinked; link them in GPMC where you want them."
    Info "Account Policies (password/lockout/Kerberos) only take effect for domain accounts when linked at the DOMAIN ROOT."
    Info "Security Options rename only the built-in guest account to CISGUEST - the Administrator rename was removed so the lab keeps its known admin logon - and MS/Win11 User Rights deny RDP to local accounts."
}
# The 4-way test matrix: run ONE technique under each condition, labelled, so
# the room sees exactly what XDR and CIS each stop.
function Step-Matrix([string]$id){
    if (-not $id){ $id = Read-Host "  Technique id for the matrix (e.g. $($TechniqueMap.Keys -join '/'))" }
    $t = $TechniqueMap[$id]
    if (-not $t){ Warn "Unknown technique '$id'."; return }
    Narrate "4-WAY MATRIX for $id ($($t.Attack) - $($t.Name)). Same attack, four defensive postures."
    Write-Host "    Cell 1: NO XDR        -> $($CFG.Win11b) (stock AV, no CIS)"      -ForegroundColor White
    Write-Host "    Cell 2: XDR           -> $($CFG.Win11)  (onboarded, no CIS)"     -ForegroundColor White
    Write-Host "    Cell 3: XDR + CIS L1  -> $($CFG.Win11)  (onboarded + CIS)"       -ForegroundColor White
    Write-Host "    Cell 4: CIS L1 only   -> $($CFG.Win11b) (CIS, NOT onboarded)`n"  -ForegroundColor White
    Warn "Prereqs: $($CFG.Win11) onboarded to XDR (Blue menu); your CIS Win11 zip set (CIS settings). The matrix drives CIS apply/remove per cell for you."
    if (-not $NonInteractive){ if ((Read-Host "  Run the full matrix now? (y/n)") -notmatch '^[Yy]') { return } }

    # Cell 1 - no XDR, no CIS (stock-AV box, baseline)
    Narrate "CELL 1/4  -  NO XDR, NO CIS   (baseline on $($CFG.Win11b))"
    Step-CisRemoveWks $CFG.Win11b
    $CFG.AttackTarget = $CFG.Win11b; Save-Cfg $CFG; Step-Invoke $id
    Narrate "CELL 1 result: stock AV only. Expect the attack to succeed and little/nothing in the XDR console."
    Pause

    # Cell 2 - XDR, no CIS (onboarded box, baseline)
    Narrate "CELL 2/4  -  XDR, NO CIS   (onboarded $($CFG.Win11))"
    Step-CisRemoveWks $CFG.Win11
    $CFG.AttackTarget = $CFG.Win11; Save-Cfg $CFG; Step-Invoke $id
    Narrate "CELL 2 result: XDR sees it - show the incident/alert. CIS not applied, so the technique still runs."
    Pause

    # Cell 3 - XDR + CIS L1 (onboarded box, hardened)
    Narrate "CELL 3/4  -  XDR + CIS L1   (onboarded $($CFG.Win11), hardened)"
    Step-CisApplyWks $CFG.Win11
    $CFG.AttackTarget = $CFG.Win11; Save-Cfg $CFG; Step-Invoke $id
    Narrate "CELL 3 result: CIS closes the door AND XDR detects - the strongest posture. Compare how far the attack gets vs cell 2."
    Pause

    # Cell 4 - CIS L1 only, no XDR (stock-AV box, hardened)
    Narrate "CELL 4/4  -  CIS L1 ONLY, NO XDR   (hardened $($CFG.Win11b))"
    Step-CisApplyWks $CFG.Win11b
    $CFG.AttackTarget = $CFG.Win11b; Save-Cfg $CFG; Step-Invoke $id
    Narrate "CELL 4 result: CIS may stop/limit the technique, but with no XDR you're BLIND - nothing in the console. That's the case for XDR."
    Ok "Matrix complete for $id. Four postures, one attack - the whole 'what CIS stops vs what XDR sees' story."
}

# --- 5) run & re-run tests -----------------------------------------------
# Build the in-guest Atomic Red Team invocation. Hardened so it can't hang a
# run-command: bounded TimeoutSeconds, -GetPrereqs, no interactive prompts,
# a single test number, silenced progress, and start/finish markers so the
# (synchronous, output-at-the-end) run-command log shows life.
function Build-AtomicScript([string]$attack){
    return @"
`$ProgressPreference = 'SilentlyContinue'
`$ErrorActionPreference = 'Continue'
Write-Host "[atomic] START $attack @ `$(Get-Date -Format HH:mm:ss)"
if (-not (Get-Module -ListAvailable invoke-atomicredteam)) {
  Write-Host "[atomic] First run: installing invoke-atomicredteam + atomics (downloads a few hundred MB; this is the slow part)..."
  try {
    IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing)
    Install-AtomicRedTeam -getAtomics -Force
  } catch { Write-Host "[atomic] INSTALL FAILED: `$(`$_.Exception.Message)"; Write-Host "[atomic] END $attack (install error)"; return }
}
Import-Module invoke-atomicredteam -Force
Write-Host "[atomic] Fetching prerequisites for $attack (test #1)..."
try { Invoke-AtomicTest $attack -TestNumbers 1 -GetPrereqs -PromptForInputArgs:`$false -ErrorAction Continue } catch { Write-Host "[atomic] prereq step: `$(`$_.Exception.Message)" }
Write-Host "[atomic] Running $attack (test #1, 180s cap)..."
try { Invoke-AtomicTest $attack -TestNumbers 1 -TimeoutSeconds 180 -PromptForInputArgs:`$false -ErrorAction Continue } catch { Write-Host "[atomic] run: `$(`$_.Exception.Message)" }
Write-Host "[atomic] END $attack @ `$(Get-Date -Format HH:mm:ss)"
"@
}
function Target-Label { if ($CFG.AttackTarget -eq $CFG.Win11b){ "$($CFG.Win11b) (stock AV, NOT onboarded)" } else { "$($CFG.Win11) (onboarded to Defender XDR)" } }
function Step-Invoke([string]$id){
    $t = $TechniqueMap[$id]
    if (-not $t){ Warn "Unknown technique id '$id'. Known: $($TechniqueMap.Keys -join ', ')"; return }
    $target = $CFG.AttackTarget
    Narrate "Technique $id -> ATT&CK $($t.Attack): $($t.Name).   Target: $(Target-Label)"
    Info "This asks the cited public runner (Atomic Red Team) to run $($t.Attack) on $target to GENERATE the telemetry - no exploit code here."
    ShowCmd "Invoke-AtomicTest $($t.Attack) -TestNumbers 1 -GetPrereqs -TimeoutSeconds 180   # on $target, via run-command"
    Info "First run downloads the Atomic atomics (~a few hundred MB) - that step is slow and silent over run-command; after that it's fast. Each test is capped at 180s so it can't hang."
    $script = Build-AtomicScript $t.Attack
    $tmp = Join-Path $env:TEMP "atomic-$id.ps1"; $script | Set-Content $tmp
    Invoke-OnWindowsVm $target $tmp $null
    if ($target -eq $CFG.Win11b) {
        Narrate "This was the STOCK-AV box: check security.microsoft.com - you should see little or NOTHING in the XDR console (only local AV may act). That's the teaching contrast."
    } else {
        Narrate "Now flip to security.microsoft.com -> Incidents and show the detection for $($t.Name). KQL is in the Lab Guide / Appendix D."
    }
}
function Step-ToggleTarget {
    if ($CFG.AttackTarget -eq $CFG.Win11){ $CFG.AttackTarget = $CFG.Win11b } else { $CFG.AttackTarget = $CFG.Win11 }
    Save-Cfg $CFG
    Ok "Attack target is now: $(Target-Label)"
}
function Step-InvokeAll {
    Narrate "Re-running the full technique set end to end (then detect each in the portal)."
    foreach ($id in $TechniqueMap.Keys){ Step-Invoke $id; if (-not $NonInteractive){ Read-Host "  [Enter] for the next technique" | Out-Null } }
    Ok "All techniques fired. The incident queue should now show the full attack story."
}

# =========================================================================
#  HEADLESS DISPATCH (for the Electron "Demo Theater" front end)
# =========================================================================
if ($Action -ne 'Menu') {
    Start-Logging
    try {
    switch ($Action) {
        'Prereqs'      { Step-Prereqs }
        'AzLogin'      { Step-AzLogin }
        'Configure'    { Step-Configure }
        'Deploy'       { Step-Deploy }
        'Start'        { Step-Manage 'Start' }
        'Stop'         { Step-Manage 'Stop' }
        'Status'       { Step-Manage 'Status' }
        'Destroy'      { Step-Manage 'Destroy' }
        'AutoShutdown' { Step-AutoShutdown }
        'AuthorizeIp'  { Step-AuthorizeIp }
        'BootDiag'     { Step-BootDiagnostics }
        'ConfigureDC'  { Step-ConfigureDC }
        'JoinTargets'  { Step-JoinTargets }
        'Verify'       { Step-Verify }
        'WeakenAD'     { Step-WeakenAD }
        'HardenAD'     { Step-HardenAD }
        'ReportAD'     { Step-ReportAD }
        'HardenedOU'   { Step-HardenedOU }
        'MoveToHardenedOU' { Step-MoveToHardenedOU }
        'DefenderBaselineGpo' { Step-DefenderBaselineGpo }
        'CreateCisOU' { Step-CreateCisOU }
        'CisSplit'    { Step-CisSplit }
        'Ssh'          { Step-SshInto }
        'BackdoorLogin'       { Step-BackdoorLogin }
        'BackdoorLoginScoped' { Step-BackdoorLoginScoped }
        'BackdoorWhoami'      { Step-BackdoorWhoami }
        'BackdoorShell'       { Step-BackdoorShell }
        'BackdoorRunKit'      { Step-BackdoorRunKit }
        'BackdoorLogoff'      { Step-BackdoorLogoff }
        'BackdoorRemove'      { Step-BackdoorRemove }
        'GetOnboarding'{ Step-GetOnboarding }
        'Onboard'      { Step-Onboard }
        'Harden'       { Step-Harden }
        'VerifyDefense'{ Step-VerifyDefense }
        'DefenderCloudOn'  { Step-DefenderCloudOn }
        'PushMdeExtension' { Step-PushMdeExtension }
        'DefenderCloudOff' { Step-DefenderCloudOff }
        'CloudSeed'    { Step-CloudSeed }
        'CloudHunt'    { Step-CloudHunt }
        'CloudStatus'  { Step-CloudStatus }
        'CloudRemove'  { Step-CloudRemove }
        'GetMdi'       { Step-GetMdi }
        'InstallMdi'   { Step-InstallMdi }
        'MdiGmsa'      { Step-MdiGmsa }
        'DeploySentinel'{ Step-DeploySentinel }
        'OpenHunting'  { Step-OpenHunting }
        'HuntingPack'  { Step-HuntingPack }
        'Hunt'         { Step-Hunt }
        'HuntSetup'    { Step-HuntSetup }
        'KqlFolder'    { Step-KqlFolder }
        'CisApplyDC'   { Step-CisApplyDC }
        'CisRemoveDC'  { Step-CisRemoveDC }
        'CisApplyWks'  { Step-CisApplyWks $CFG.AttackTarget }
        'CisRemoveWks' { Step-CisRemoveWks $CFG.AttackTarget }
        'CopyCisToDc'  { Step-CopyCisToDc }
        'Matrix'       { Step-Matrix $TechniqueId }
        'Invoke'       { Step-Invoke $TechniqueId }
        'InvokeAll'    { Step-InvokeAll }
        'DeployCopy2'  { Step-DeployCopy2 }
        'CompleteCopy2'{ Step-CompleteCopy2 }
        'DestroyCopy2' { Step-DestroyCopy2 }
    }
    } catch { Warn "Action '$Action' failed: $($_.Exception.Message)"; Log "Action $Action EXCEPTION: $($_ | Out-String)" 'ERROR' }
    finally { Stop-Logging }
    return
}

# =========================================================================
#  INTERACTIVE MENU (grouped, with submenus)
# =========================================================================
function Header {
    Banner
    if ($script:ActiveLab -eq '2') {
        Write-Host "  ACTIVE LAB: COPY 2  ->  $($CFG.ResourceGroup) / $($CFG.Location) / $($CFG.DomainName)   (C on the main menu switches)" -ForegroundColor Magenta
    } else {
        Write-Host "  Lab: copy 1  ->  $($CFG.ResourceGroup) / $($CFG.Location) / $($CFG.DomainName)" -ForegroundColor DarkGray
    }
    if ($script:LogFile){ Write-Host "  Log: $(Split-Path -Leaf $script:LogFile)  (menu 1 -> 8 to tail/zip)" -ForegroundColor DarkGray }
    Write-Host ""
}

function Menu-Lifecycle {
    do {
        Header
        Write-Host "  [1] LAB LIFECYCLE - build & teardown`n" -ForegroundColor Yellow
        Write-Host "    1) Deploy the Azure range (build)"
        Write-Host "    2) Start   (power the VMs on)"
        Write-Host "    3) Stop    (deallocate - stop paying for compute)"
        Write-Host "    4) Status  (what's running)"
        Write-Host "    5) Destroy (tear the whole range down)"
        Write-Host "    6) Auto-shutdown (on/off + time) - off during build"
        Write-Host "    7) Configure lab settings (RG, region, domain, NetBIOS, SRV01)"
        Write-Host "    8) Run logs (tail / list / open folder / zip for sharing)"
        Write-Host "    9) Authorize my current public IP (re-lock NSG when you change networks)" -ForegroundColor Cyan
        Write-Host "    B) Enable boot diagnostics on the lab VMs (boot screenshot + Serial Console)" -ForegroundColor Cyan
        Write-Host "    -- second, isolated copy in the same tenant --" -ForegroundColor DarkGray
        Write-Host "    D) Deploy a 2nd copy of the lab -> $(Get-Copy2Rg) (own RG + VNet; then menu 2 -> B)" -ForegroundColor Cyan
        Write-Host "    X) DESTROY the 2nd copy -> $(Get-Copy2Rg) only (copy 1 untouched; you type the RG name to confirm)" -ForegroundColor Red
        Write-Host "    C) Switch active lab (now: copy $($script:ActiveLab) - $($CFG.ResourceGroup))"
        Write-Host "    0) Back`n"
        $c = Read-Host "  Select"
        switch ($c) {   # (switch is case-insensitive: d/D, c/C both work)
            'D' { Step-DeployCopy2; Pause }
            'X' { Step-DestroyCopy2; Pause }
            'C' { Step-SwitchLab; Pause }
            '1' { Step-Deploy; Pause }
            '2' { Step-Manage 'Start'; Pause }
            '3' { Step-Manage 'Stop'; Pause }
            '4' { Step-Manage 'Status'; Pause }
            '5' { Step-Manage 'Destroy'; Pause }
            '6' { Step-AutoShutdown; Pause }
            '7' { Step-Configure; Pause }
            '8' { Step-Logs; Pause }
            '9' { Step-AuthorizeIp; Pause }
            'B' { Step-BootDiagnostics; Pause }
        }
    } while ($c -ne '0')
}

function Menu-Configure {
    do {
        Header
        Write-Host "  [2] LAB CONFIGURATION - domain, DNS, AD hardening`n" -ForegroundColor Yellow
        Write-Host "    1) Configure DC01 (promote $($CFG.DomainName) forest + seed accounts + DC DNS -> itself + forwarder to Azure DNS)"
        Write-Host "    2) Join targets to the domain (WIN11, WIN11B$(if($CFG.IncludeSrv01){', SRV01'}))"
        Write-Host "    3) Verify lab readiness"
        Write-Host "    -- vulnerable-AD: make the traditional attacks work, then close them --" -ForegroundColor DarkGray
        Write-Host "    4) WEAKEN the AD (seed ACL/Kerberoast/AS-REP/DnsAdmins/DCSync/etc.)" -ForegroundColor Cyan
        Write-Host "    5) HARDEN the AD (close every seeded weakness 1:1)"
        Write-Host "    6) Report current weakness state (read-only; for the before/after)"
        Write-Host "    -- simple hardening demo: move a box into a hardened OU, re-attack --" -ForegroundColor DarkGray
        Write-Host "    7) Build the '$($CFG.HardenedOU)' OU + simple hardening GPO (create + link)" -ForegroundColor Cyan
        Write-Host "    8) Move a box into '$($CFG.HardenedOU)' (then reboot it + re-run the attack)"
        Write-Host "    9) Build the 'Defender Baseline' GPO (ASR + CFA + network protection + recommended AV)" -ForegroundColor Cyan
        Write-Host "    A) Create the CIS-Hardened-Workstations OU (no GPOs linked - you link the CIS policies)" -ForegroundColor Cyan
        Write-Host "    P) Lab admin passwords (labadmin-da + DSRM, random per lab) - copy to clipboard / regenerate"
        Write-Host "    -- second, isolated copy (deploy it first: menu 1 -> D) --" -ForegroundColor DarkGray
        Write-Host "    B) FINISH COPY 2 ($(Get-Copy2Rg)): start VMs -> DC01 -> join -> verify -> (weaken) -> Hardened OU (7) -> Defender Baseline GPO (9)" -ForegroundColor Cyan
        Write-Host "    0) Back`n"
        $c = Read-Host "  Select"
        switch -Regex ($c) {
            '^[Bb]$' { Step-CompleteCopy2; Pause }
            '^1$' { Step-ConfigureDC; Pause }
            '^2$' { Step-JoinTargets; Pause }
            '^3$' { Step-Verify; Pause }
            '^4$' { Step-WeakenAD; Pause }
            '^5$' { Step-HardenAD; Pause }
            '^6$' { Step-ReportAD; Pause }
            '^7$' { Step-HardenedOU; Pause }
            '^8$' { Step-MoveToHardenedOU; Pause }
            '^9$' { Step-DefenderBaselineGpo; Pause }
            '^[Aa]$' { Step-CreateCisOU; Pause }
            '^[Pp]$' { Step-LabSecrets; Pause }
        }
    } while ($c -notmatch '^0$')
}

# --- Module 0c: run the framework through an over-privileged app registration -
# Thin wrappers around cloud/Use-BackdoorCli.ps1 (standalone; signs the CLI in
# AS the backdoor service principal in an ISOLATED context, so your own
# 'az login' is never touched). Demo: app reg + run-command rights = SYSTEM on
# every VM, no user needed.
function Invoke-BackdoorCli([string]$Act,[string[]]$Extra){
    $script = Join-Path $HERE 'cloud/Use-BackdoorCli.ps1'
    if (-not (Test-Path $script)){ Warn "Backdoor CLI script missing: $script"; return }
    $argv = @('-NoProfile','-File',$script,'-Action',$Act,'-ResourceGroup',$CFG.ResourceGroup)
    if ($Extra){ $argv += $Extra }
    ShowCmd "pwsh -File cloud/Use-BackdoorCli.ps1 -Action $Act -ResourceGroup $($CFG.ResourceGroup)$(if($Extra){' '+($Extra -join ' ')})"
    & pwsh @argv
}
function Step-BackdoorLogin       { Narrate "Login the CLI AS the over-privileged app (grants Contributor on the lab RG - the 'too much rights' artifact)."; Invoke-BackdoorCli 'Login' @('-Rights','Contributor') }
function Step-BackdoorLoginScoped { Narrate "Login the CLI AS the app with ONLY the minimal run-command role (least-privilege contrast)."; Invoke-BackdoorCli 'Login' @('-Rights','Scoped') }
function Step-BackdoorWhoami      { Invoke-BackdoorCli 'Whoami' }
function Step-BackdoorShell       { Invoke-BackdoorCli 'Shell' }
function Step-BackdoorRunKit      { Invoke-BackdoorCli 'RunKit' }
function Step-BackdoorLogoff      { Invoke-BackdoorCli 'Logoff' }
function Step-BackdoorRemove      { Invoke-BackdoorCli 'Remove' }
# Run an existing kit step IN the backdoor CLI context, so every az call inside
# it is the service principal, not you. Restores your normal context after.
function Invoke-AsBackdoor([ScriptBlock]$Step,[string]$Label){
    $bd = Join-Path $CFGDIR 'backdoor-cli'
    if (-not (Test-Path (Join-Path $bd 'azureProfile.json'))){ Warn "No backdoor session yet. Run 3 -> B -> 1 (login as the app) first."; return }
    Narrate "Running '$Label' AS THE APP (backdoor CLI context) - every az call below is the service principal, not you."
    $old = $env:AZURE_CONFIG_DIR
    $env:AZURE_CONFIG_DIR = $bd
    try { & $Step } finally { $env:AZURE_CONFIG_DIR = $old }
    Ok "'$Label' finished as the app. Your normal az context is restored."
}
function Menu-Backdoor {
    do {
        Header
        Write-Host "  [3 -> B] BACKDOOR CLI - run the framework as an over-privileged app registration`n" -ForegroundColor Yellow
        Write-Host "    Demo: an app reg + Azure RBAC (run-command) = SYSTEM on every VM, no user, no password, no endpoint." -ForegroundColor DarkGray
        Write-Host "    Signs the Azure CLI in AS the app in an ISOLATED context - your own 'az login' is left untouched.`n" -ForegroundColor DarkGray
        Write-Host "    1) Login as the app  (Contributor on the lab RG - the 'too much rights' artifact)" -ForegroundColor Cyan
        Write-Host "    2) Login as the app  (scoped: run-command only - least-privilege contrast)"
        Write-Host "    3) Whoami            (prove it's a service principal + show its rights)" -ForegroundColor Cyan
        Write-Host "    4) Open a shell in the backdoor context (then run .\DefXDRLabKit.ps1 there)"
        Write-Host "    5) Run the framework now, as the app"
        Write-Host "    6) Logoff the backdoor context (your normal az login stays signed in)"
        Write-Host "    7) REMOVE everything (app, service principal, roles, local credential)" -ForegroundColor Red
        Write-Host "    -- run the framework's SETUP steps AS the app (into the existing lab RG) --" -ForegroundColor DarkGray
        Write-Host "    D) Deploy / repair the lab range" -ForegroundColor Cyan
        Write-Host "    G) Configure the domain  (promote DC + join targets + verify)" -ForegroundColor Cyan
        Write-Host "    O) Onboard Defender on WIN11"
        Write-Host "    T) Run an attack technique (menu 5, as the app)"
        Write-Host "    0) Back`n"
        $c = Read-Host "  Select"
        switch ($c) {
            '1' { Step-BackdoorLogin; Pause }
            '2' { Step-BackdoorLoginScoped; Pause }
            '3' { Step-BackdoorWhoami; Pause }
            '4' { Step-BackdoorShell; Pause }
            '5' { Step-BackdoorRunKit; Pause }
            '6' { Step-BackdoorLogoff; Pause }
            '7' { Step-BackdoorRemove; Pause }
            'D' { Invoke-AsBackdoor { Step-Deploy } 'Deploy / repair the lab range'; Pause }
            'G' { Invoke-AsBackdoor { Step-ConfigureDC; Step-JoinTargets; Step-Verify } 'Configure the domain'; Pause }
            'O' { Invoke-AsBackdoor { Step-Onboard } 'Onboard Defender on WIN11'; Pause }
            'T' { Invoke-AsBackdoor { Menu-Tests } 'Attack techniques'; Pause }
        }
    } while ($c -notmatch '^0$')
}
function Menu-Attacker {
    do {
        Header
        Write-Host "  [3] ATTACKER BOX (KALI) - base Kali, bring your own tooling`n" -ForegroundColor Yellow
        Write-Host "    This is a plain Kali VM from the Azure Marketplace. Nothing is auto-installed." -ForegroundColor DarkGray
        Write-Host "    SSH in and set up Sliver (or whatever C2 you want) by hand - you own execution.`n" -ForegroundColor DarkGray
        Write-Host "    1) SSH into KALI (opens a live console; prints a Sliver one-liner to paste)" -ForegroundColor Cyan
        Write-Host "    B) Backdoor CLI - run the framework as an over-privileged app registration" -ForegroundColor Cyan
        Write-Host "    0) Back`n"
        $c = Read-Host "  Select"
        switch -Regex ($c) {
            '^1$' { Step-SshInto; Pause }
            '^[Bb]$' { Menu-Backdoor }
        }
    } while ($c -notmatch '^0$')
}

# --- Module 0b: cloud persistence scenario (seed/hunt/remove) ----------------
# Thin wrappers around cloud/Manage-CloudBackdoorScenario.ps1. The scenario
# seeds a deliberately over-privileged, RG-scoped service principal as a LAB
# ARTIFACT for detection training (the cloud analogue of Weaken-AD), lets you
# hunt it from the blue side, and removes it. Scoped to $CFG.ResourceGroup only.
function Invoke-CloudScenario([string]$Act,[string[]]$Extra){
    $script = Join-Path $HERE 'cloud/Manage-CloudBackdoorScenario.ps1'
    if (-not (Test-Path $script)){ Warn "Scenario script missing: $script"; return }
    $argv = @('-NoProfile','-File',$script,'-Action',$Act,'-ResourceGroup',$CFG.ResourceGroup)
    if ($Extra){ $argv += $Extra }
    ShowCmd "pwsh -File cloud/Manage-CloudBackdoorScenario.ps1 -Action $Act -ResourceGroup $($CFG.ResourceGroup)"
    & pwsh @argv
}
function Step-CloudSeed   { Narrate "Module 0b: SEED the scoped service-principal lab artifact in $($CFG.ResourceGroup) (reversible, detection training)."; Invoke-CloudScenario 'Seed' }
function Step-CloudHunt   { Narrate "Module 0b: HUNT the over-privileged service principal from the blue side."; Invoke-CloudScenario 'Hunt' }
function Step-CloudStatus { Invoke-CloudScenario 'Status' }
function Step-CloudRemove { Narrate "Module 0b: REMOVE the lab artifact - full cleanup."; Invoke-CloudScenario 'Remove' }
function Menu-CloudScenario {
    do {
        Header
        Write-Host "  [4C] CLOUD PERSISTENCE SCENARIO (Module 0b) - seed / hunt / remove`n" -ForegroundColor Yellow
        Write-Host "    Scoped to $($CFG.ResourceGroup) ONLY. Reversible. Detection training on a lab you own." -ForegroundColor DarkGray
        Write-Host "    Credential is short-lived + stored locally (outside OneDrive). See Operator-Playbook.md Module 0b.`n" -ForegroundColor DarkGray
        Write-Host "    1) Seed   - create the scoped over-privileged app registration (lab artifact)"
        Write-Host "    2) Hunt   - find it from the blue side (role assignments + custom role + audit log)" -ForegroundColor Cyan
        Write-Host "    3) Status - is the artifact currently live?"
        Write-Host "    4) Remove - tear it all down (app/SP + custom role + assignment + cred file)"
        Write-Host "    0) Back`n"
        $c = Read-Host "  Select"
        switch ($c) {
            '1' { Step-CloudSeed; Pause }
            '2' { Step-CloudHunt; Pause }
            '3' { Step-CloudStatus; Pause }
            '4' { Step-CloudRemove; Pause }
        }
    } while ($c -ne '0')
}

# --- Defender for Cloud (Defender for Servers) - RESOURCE-SCOPED to the lab --
# A deliberate teaching lever: OFF at baseline (quiet, shows the "unprotected
# cloud" state), then turned ON as a hardening step so the class sees secure-
# score recommendations + Azure-native server alerts appear. This is the CLOUD
# posture/server-threat layer, SEPARATE from MDE/MDI (the endpoint + identity
# products the rest of the course uses).
#
# IMPORTANT: scoped to the LAB RG's VMs ONLY (resource-level
# Microsoft.Security/pricings/virtualMachines), so the rest of the subscription
# is never touched. Off = exclude the lab VMs (pricingTier Free); On = enable
# Defender for Servers Plan 1 on them. Both work regardless of the sub-level
# plan state. Docs: learn.microsoft.com/azure/defender-for-cloud/tutorial-enable-servers-plan
function Set-DefenderForCloud([string]$State){
    $acct = Confirm-AzContext
    if (-not $acct){ Warn "No Azure context - cancelled."; return }
    $sub = $acct.id
    $vms = @(Lab-VmNames)
    if (-not $vms){ Warn "No lab VMs known - deploy first (menu 1 -> 1)."; return }
    if ($State -eq 'On'){ $json = '{"properties":{"pricingTier":"Standard","subPlan":"P1"}}'; $lbl = 'Standard (Defender for Servers P1)' }
    else                { $json = '{"properties":{"pricingTier":"Free"}}';                      $lbl = 'Free (excluded)' }
    Narrate "Setting Defender for Servers to '$lbl' on the $($vms.Count) VMs in $($CFG.ResourceGroup) ONLY - the rest of '$($acct.name)' is untouched."
    $tmp = Join-Path $env:TEMP ("dfc-" + [guid]::NewGuid().ToString('N').Substring(0,6) + '.json')
    $json | Set-Content $tmp -Encoding ascii
    foreach ($vm in $vms){
        $url = "https://management.azure.com/subscriptions/$sub/resourceGroups/$($CFG.ResourceGroup)/providers/Microsoft.Compute/virtualMachines/$vm/providers/Microsoft.Security/pricings/virtualMachines?api-version=2024-01-01"
        az rest --method put --url $url --body "@$tmp" -o none 2>$null
        if ($LASTEXITCODE -eq 0){ Ok "  $vm -> $lbl" } else { Warn "  $vm : couldn't set (deployed? permissions?) - skipped" }
    }
    Remove-Item $tmp -ErrorAction SilentlyContinue
    if ($State -eq 'On'){
        Ok "Defender for Servers ENABLED on the lab VMs. Secure-score recommendations + server threat alerts will populate for these machines."
        Info "Teaching point: cloud posture/server-threat layer on the lab's own VMs - separate from MDE/MDI. In the portal show Defender for Cloud > Recommendations + Security alerts filtered to $($CFG.ResourceGroup)."
        Info "Pair it with the rest of the hardening (ASR, CFA, CIS, AD Harden) as the 'close the gaps' half of the lesson."
    } else {
        Ok "Lab VMs EXCLUDED from Defender for Servers (Free) - quiet baseline, and ONLY the lab RG's VMs are affected. MDE/MDI are unaffected."
    }
}
function Step-DefenderCloudOn  { Narrate "Hardening step: ENABLE Defender for Servers on the lab VMs (show WHY you turn it on) - lab RG only."; Set-DefenderForCloud 'On' }
function Step-DefenderCloudOff { Narrate "Exclude the lab VMs from Defender for Servers (quiet baseline) - lab RG only."; Set-DefenderForCloud 'Off' }

# Push the Defender for Endpoint extension (MDE.Windows) ourselves, so the Windows
# VMs get the sensor without waiting for Defender for Cloud's provisioning cycle.
# Microsoft's guidance: first onboarding in a tenant can take up to 12 hours, later
# machines up to 1 hour. The publisher/type below come from the extension's log folder
# name (Microsoft.Azure.AzureDefenderForServers.MDE.Windows); the image check confirms it.
function Step-PushMdeExtension {
    Narrate "Push the Defender for Endpoint extension (MDE.Windows) to the lab Windows VMs now, instead of waiting for Defender for Cloud."
    $acct = Confirm-AzContext
    if (-not $acct){ Warn "No Azure context - cancelled."; return }
    $pub = 'Microsoft.Azure.AzureDefenderForServers'; $typ = 'MDE.Windows'
    $winVms = @($CFG.Dc,$CFG.Win11,$CFG.Win11b)
    if ($CFG.IncludeSrv01){ $winVms += 'SRV01' }
    ShowCmd "az vm extension image list -p $pub -l $($CFG.Location) --query ""[?name=='$typ'].name"" -o tsv"
    $img = az vm extension image list -p $pub -l $CFG.Location --query "[?name=='$typ'].name | [0]" -o tsv 2>$null
    if (-not $img){ Warn "Could not find $pub / $typ in $($CFG.Location). Nothing was pushed. Check the publisher name with the image list command above."; return }
    foreach ($vm in $winVms){
        ShowCmd "az vm extension set --publisher $pub --name $typ --resource-group $($CFG.ResourceGroup) --vm-name $vm --enable-auto-upgrade true --no-wait"
        az vm extension set --publisher $pub --name $typ --resource-group $CFG.ResourceGroup --vm-name $vm --enable-auto-upgrade true --no-wait -o none 2>$null
        if ($LASTEXITCODE -eq 0){ Ok "  $vm : MDE.Windows queued" } else { Warn "  $vm : push failed (is the VM running? check the extension in the portal)" }
    }
    Info "Waiting for each extension to finish provisioning (up to 15 minutes per VM)."
    foreach ($vm in $winVms){
        $deadline = (Get-Date).AddMinutes(15); $state = ''
        do {
            $state = az vm extension show -g $CFG.ResourceGroup --vm-name $vm -n $typ --query provisioningState -o tsv 2>$null
            if ($state -in 'Succeeded','Failed'){ break }
            Start-Sleep -Seconds 30
        } while ((Get-Date) -lt $deadline)
        if ($state -eq 'Succeeded'){ Ok "  $vm : MDE.Windows Succeeded" } else { Warn "  $vm : state '$state'. Open VM > Extensions > MDE.Windows > View detailed status." }
    }
    Info "Teaching point: the extension finishing is not the same as the device showing in the portal. Visibility can still take up to 1 hour for later machines, or up to 12 hours for the first onboarding in a tenant."
}

function Menu-BlueTeam {
    do {
        Header
        Write-Host "  [4] BLUE-TEAM / DEFENDER XDR - see what the lab is telling you`n" -ForegroundColor Yellow
        Write-Host "    Devices onboard to Defender for Endpoint automatically (Defender for Cloud + the build-time push)," -ForegroundColor DarkGray
        Write-Host "    and the MDI sensor activates on DC01 by itself. So this menu is about HUNTING.`n" -ForegroundColor DarkGray
        Write-Host "    -- Hunt (KQL against the lab, results shown here) --" -ForegroundColor DarkGray
        Write-Host "    H) HUNT the lab - pick a query from the course pack and run it" -ForegroundColor Cyan
        Write-Host "    S) Quick check: every lab device in Defender (onboarding + sensor health)" -ForegroundColor Cyan
        Write-Host "    A) Quick check: alerts in the last 24h, by product" -ForegroundColor Cyan
        Write-Host "    G) One-time setup: let the kit run advanced hunting (Graph sign-in)"
        Write-Host "    K) RUN MY KQL FOLDER - batch-run a folder of .kql files (validate / export / PASS-FAIL test)" -ForegroundColor Cyan
        Write-Host "    -- Coverage (automatic; these are the manual levers) --" -ForegroundColor DarkGray
        Write-Host "    E) PUSH the MDE.Windows extension now (don't wait for Defender for Cloud)"
        Write-Host "    D) ENABLE Defender for Servers on the lab VMs   F) EXCLUDE the lab VMs"
        Write-Host "    3) Controlled Folder Access + network protection (ransomware posture)"
        Write-Host "    4) Verify defensive posture on the VMs"
        Write-Host "    -- cloud identity scenario (Module 0b) --" -ForegroundColor DarkGray
        Write-Host "    C) Cloud persistence scenario: seed / hunt / remove (scoped to $($CFG.ResourceGroup))"
        Write-Host "    M) Manual fallbacks (onboarding script, classic MDI sensor, gMSA) - only if auto didn't work" -ForegroundColor DarkGray
        Write-Host "    0) Back`n"
        $c = Read-Host "  Select"
        switch -Regex ($c) {
            '^[Hh]$' { Step-Hunt }
            '^[Ss]$' { Narrate $HuntCatalog[0].Name; Invoke-LabHunt ($HuntCatalog[0].Kql -replace '\{WINDOW\}', '7d') 'XDR'; Pause }
            '^[Aa]$' { Narrate $HuntCatalog[1].Name; Invoke-LabHunt ($HuntCatalog[1].Kql -replace '\{WINDOW\}', '1d') 'XDR'; Pause }
            '^[Gg]$' { Step-HuntSetup; Pause }
            '^[Kk]$' { Step-KqlFolder; Pause }
            '^3$' { Step-Harden; Pause }
            '^4$' { Step-VerifyDefense; Pause }
            '^[Dd]$' { Step-DefenderCloudOn;  Pause }
            '^[Ff]$' { Step-DefenderCloudOff; Pause }
            '^[Ee]$' { Step-PushMdeExtension; Pause }
            '^[Cc]$' { Menu-CloudScenario }
            '^[Mm]$' { Menu-BlueManual }
        }
    } while ($c -notmatch '^0$')
}
function Menu-BlueManual {
    do {
        Header
        Write-Host "  [4] -> M  MANUAL FALLBACKS - only if automatic onboarding didn't happen`n" -ForegroundColor Yellow
        Write-Host "    1) Get the onboarding package (open security.microsoft.com)"
        Write-Host "    2) Onboard Defender for Endpoint with the local script (WIN11)"
        Write-Host "    5) Get the classic MDI sensor package (open portal + staging steps)"
        Write-Host "    6) Install the classic MDI sensor on DC01"
        Write-Host "    7) Create the MDI Directory Service Account (gMSA on DC01)"
        Write-Host "    0) Back`n"
        $c = Read-Host "  Select"
        switch ($c) {
            '1' { Step-GetOnboarding; Pause }
            '2' { Step-Onboard; Pause }
            '5' { Step-GetMdi; Pause }
            '6' { Step-InstallMdi; Pause }
            '7' { Step-MdiGmsa; Pause }
        }
    } while ($c -ne '0')
}

function Menu-Advanced {
    do {
        Header
        Write-Host "  [6] ADVANCED DETECTION - Microsoft Sentinel + threat hunting`n" -ForegroundColor Yellow
        Write-Host "    1) Deploy Sentinel (Log Analytics workspace + enable + Azure Activity)"
        Write-Host "    2) Connect data connectors (Defender XDR / Entra) - portal steps"
        Write-Host "    3) Open Advanced hunting (KQL across the lab)"
        Write-Host "    4) Show the post-exploit hunting pack (KQL you can paste for each technique)" -ForegroundColor Cyan
        Write-Host "    0) Back`n"
        $c = Read-Host "  Select"
        switch ($c) {
            '1' { Step-DeploySentinel; Pause }
            '2' { Narrate "Sentinel data connectors (portal)."; Info "Sentinel -> Configuration -> Data connectors: enable 'Microsoft Defender XDR' (pulls MDE+MDI+Entra alerts) and 'Microsoft Entra ID'. The Azure Activity connector was wired by the deploy step."; Pause }
            '3' { Step-OpenHunting; Pause }
            '4' { Step-HuntingPack; Pause }
        }
    } while ($c -ne '0')
}

function Menu-Cis {
    do {
        Header
        Write-Host "  [7] CIS BENCHMARK HARDENING - prove what CIS L1 stops`n" -ForegroundColor Yellow
        Write-Host "    You supply the CIS GPO zip (your CIS membership export); nothing CIS is bundled." -ForegroundColor DarkGray
        Write-Host "    Server zip: $(if($CFG.CisServerZip){$CFG.CisServerZip}else{'(not set)'})" -ForegroundColor DarkGray
        Write-Host "    Win11 zip : $(if($CFG.CisWin11Zip){$CFG.CisWin11Zip}else{'(not set)'})`n" -ForegroundColor DarkGray
        Write-Host "    1) Apply CIS to the DCs        (Server policy -> Domain Controllers OU)"
        Write-Host "    2) Apply CIS to a workstation  (Win11 policy -> WIN11 or WIN11B)"
        Write-Host "    3) Remove CIS from the DCs"
        Write-Host "    4) Remove CIS from a workstation"
        Write-Host "    -- the headline experiment --" -ForegroundColor DarkGray
        Write-Host "    5) Run the 4-WAY MATRIX for one technique" -ForegroundColor Cyan
        Write-Host "         (no-XDR  /  XDR  /  XDR+CIS  /  CIS-only)"
        Write-Host "    6) CIS settings (zip paths, policy folder names, OU)"
        Write-Host "    7) Copy the CIS Benchmark zips to the DC desktop (to show in class)" -ForegroundColor Cyan
        Write-Host "    8) Create the 42 CIS L1 GPOs on DC01 (DC, MS, Win11 by area) - UNLINKED" -ForegroundColor Cyan
        Write-Host "         (DefXDR CIS L1 <DC|MS|Win11> - <area>; you link them)"
        Write-Host "    0) Back`n"
        $c = Read-Host "  Select"
        switch ($c) {
            '1' { Step-CisApplyDC; Pause }
            '2' {
                $b = Read-Host "  Which box? 1=$($CFG.Win11) (onboarded)  2=$($CFG.Win11b) (stock AV)"
                $box = if ($b -eq '2'){ $CFG.Win11b } else { $CFG.Win11 }
                Step-CisApplyWks $box; Pause
            }
            '3' { Step-CisRemoveDC; Pause }
            '4' {
                $b = Read-Host "  Which box? 1=$($CFG.Win11)  2=$($CFG.Win11b)"
                $box = if ($b -eq '2'){ $CFG.Win11b } else { $CFG.Win11 }
                Step-CisRemoveWks $box; Pause
            }
            '5' { Step-Matrix $null; Pause }
            '6' { Step-CisSettings; Pause }
            '7' { Step-CopyCisToDc; Pause }
            '8' { Step-CisSplit; Pause }
        }
    } while ($c -ne '0')
}

function Menu-Tests {
    do {
        Header
        Write-Host "  [5] RUN & RE-RUN TESTS - attack, then detect in the portal`n" -ForegroundColor Yellow
        Write-Host "    Attack target: $(Target-Label)" -ForegroundColor White
        Write-Host ""
        $TechniqueMap.GetEnumerator() | ForEach-Object { Write-Host "      $($_.Key) = $($_.Value.Attack)  $($_.Value.Name)" -ForegroundColor DarkGray }
        Write-Host ""
        Write-Host "    1) Run ONE technique by ID (then flip to the portal)"
        Write-Host "    2) Re-run ALL techniques end to end"
        Write-Host "    T) Toggle target  (WIN11 onboarded  <->  WIN11B stock-AV)" -ForegroundColor Cyan
        Write-Host "    0) Back`n"
        $c = Read-Host "  Select"
        switch -Regex ($c) {
            '^1$'    { $id = Read-Host "  Technique id"; Step-Invoke $id; Pause }
            '^2$'    { Step-InvokeAll; Pause }
            '^[Tt]$' { Step-ToggleTarget; Pause }
        }
    } while ($c -notmatch '^0$')
}

# --- startup safety: confirm / refresh the Azure context before anything --
Start-Logging
if (-not $NonInteractive) {
    Banner
    Info "This whole session is being logged to: $($script:LogFile)"
    Narrate "Azure safety check - confirm you are in the LAB subscription before you do anything."
    Confirm-AzContext | Out-Null
    Read-Host "`n  [Enter] for the main menu" | Out-Null
}

do {
    Header
    Write-Host "  MAIN MENU`n" -ForegroundColor Green
    Write-Host "    1) Lab lifecycle        (build / start / stop / status / destroy)"
    Write-Host "    2) Lab configuration    (domain, DNS, AD weaken/harden, hardened OU)"
    Write-Host "    3) Attacker box (Kali)  (SSH in - bring your own C2)"
    Write-Host "    4) Blue-team / Defender (onboard, CFA, MDI, Defender for Cloud)"
    Write-Host "    5) Run & re-run tests   (attack, then detect)"
    Write-Host "    6) Advanced detection   (Microsoft Sentinel + hunting pack)"
    Write-Host "    7) CIS benchmark + 4-way matrix (prove what CIS vs XDR stops)"
    Write-Host "    L) Azure login / switch subscription" -ForegroundColor Cyan
    Write-Host "    C) Switch active lab copy (now: copy $($script:ActiveLab) - $($CFG.ResourceGroup))" -ForegroundColor Cyan
    Write-Host "    9) Check prerequisites + show Azure context"
    Write-Host "    0) Exit`n"
    $c = Read-Host "  Select"
    switch -Regex ($c) {
        '^[Cc]$'  { Step-SwitchLab; Pause }
        '^1$'     { Menu-Lifecycle }
        '^2$'     { Menu-Configure }
        '^3$'     { Menu-Attacker }
        '^4$'     { Menu-BlueTeam }
        '^5$'     { Menu-Tests }
        '^6$'     { Menu-Advanced }
        '^7$'     { Menu-Cis }
        '^[Ll]$'  { Step-AzLogin; Pause }
        '^9$'     { Step-Prereqs; Pause }
        '^0$'     { Ok "Bye. Remember: Stop (deallocate) or Destroy when idle to control cost." }
        default   { Warn "Pick a number from the menu (L = switch subscription, C = switch lab copy)." }
    }
} while ($c -notmatch '^0$')

if ($script:LogFile){ Info "Full run log saved: $($script:LogFile)" }
Stop-Logging
