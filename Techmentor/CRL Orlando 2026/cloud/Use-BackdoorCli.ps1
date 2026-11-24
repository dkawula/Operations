<#
=====================================================================
 Use-BackdoorCli.ps1   (Module 0c - companion to Manage-CloudBackdoorScenario.ps1)

   Demo: "all an attacker needs is an over-privileged APP REGISTRATION".
   This signs the Azure CLI in AS the backdoor service principal - in an
   ISOLATED az context that never touches your real 'az login' - and then
   lets you run the normal DefXDRLabKit framework through that backdoor
   identity. The kit's run-command steps then execute as SYSTEM on the lab
   VMs while the control-plane caller is the app, not a human.

   It does NOT change DefXDRLabKit.ps1. It reuses the app/SP/role that
   Manage-CloudBackdoorScenario.ps1 -Action Seed creates (and will seed it
   for you if it isn't there yet).

 THE TEACHING POINT
   An app registration with an Azure RBAC role that includes
   Microsoft.Compute/.../runCommand/action = code execution as SYSTEM on
   every VM in scope, with NO user, NO password spray, NO endpoint foothold.
   A client secret is the whole key. That is why app-registration rights,
   secret lifetimes and 'Add app role assignment' events are tier-0 signals.

 SAFETY RAILS
   * The backdoor sign-in is written to an ISOLATED config dir
     (%USERPROFILE%\.defxdrlab\backdoor-cli), set via AZURE_CONFIG_DIR, so
     your normal 'az login' / Azure CLI session is never touched or logged
     out. 'Logoff' deletes that dir.
   * Everything stays scoped to ONE resource group (default rg-defxdr-lab).
     Even the "over-privileged" variant assigns Contributor at the RG scope
     only - never the subscription - so it can't reach anything else.
   * Subscription denylist + typed confirmation before it grants rights.
   * Fully reversible: 'Remove' tears down the app, SP, roles, assignment
     and the local credential via the existing scenario script.

 Usage (run from the kit folder, from YOUR normal elevated 'az login'):
   .\cloud\Use-BackdoorCli.ps1 -Action Login   [-Rights Scoped|Contributor]
   .\cloud\Use-BackdoorCli.ps1 -Action Whoami
   .\cloud\Use-BackdoorCli.ps1 -Action Shell          # new PS in the backdoor context
   .\cloud\Use-BackdoorCli.ps1 -Action RunKit         # launch DefXDRLabKit.ps1 as the SP
   .\cloud\Use-BackdoorCli.ps1 -Action Logoff         # drop the backdoor context only
   .\cloud\Use-BackdoorCli.ps1 -Action Remove         # full teardown (calls the scenario)

 Authorized lab use only.
=====================================================================
#>
[CmdletBinding()]
param(
    [ValidateSet('Login','Whoami','Shell','RunKit','Logoff','Remove')]
    [string]$Action = 'Whoami',
    [string]$ResourceGroup = 'rg-defxdr-lab',
    [string]$AppName       = 'defxdr-lab-contractor-DEMO',
    # Scoped  = reuse the minimal custom run-command role (least-privilege demo).
    # Contributor = the vivid "too much rights" variant: Contributor on the RG.
    [ValidateSet('Scoped','Contributor')]
    [string]$Rights = 'Contributor',
    [string[]]$DenySubstrings = @('SEWS','Sumitomo','PROD','Production'),
    [string]$CredDir   = (Join-Path $env:USERPROFILE '.defxdrlab\cloud-scenario'),
    [string]$BackdoorDir = (Join-Path $env:USERPROFILE '.defxdrlab\backdoor-cli')
)

$ErrorActionPreference = 'Stop'
$HERE = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
$KitDir      = Split-Path -Parent $HERE           # cloud\ -> kit root
$ScenarioPs1 = Join-Path $HERE 'Manage-CloudBackdoorScenario.ps1'
$KitPs1      = Join-Path $KitDir 'DefXDRLabKit.ps1'
$CredFile    = Join-Path $CredDir ("{0}.cred.json" -f $AppName)

function Say ($m){ Write-Host "[0c] $m" -ForegroundColor Cyan }
function Ok  ($m){ Write-Host "[0c] [OK] $m" -ForegroundColor Green }
function Warn($m){ Write-Host "[0c] [!!] $m" -ForegroundColor Yellow }
function Die ($m){ Write-Host "[0c] [XX] $m" -ForegroundColor Red; exit 1 }

# Run an az command in YOUR normal context (default config dir).
function Az-Me { param([string[]]$Args) & az @Args }
# Run an az command in the ISOLATED backdoor context.
function Az-Backdoor {
    param([string[]]$Args)
    $old = $env:AZURE_CONFIG_DIR
    $env:AZURE_CONFIG_DIR = $BackdoorDir
    try { & az @Args } finally { $env:AZURE_CONFIG_DIR = $old }
}

function Get-MyCtx {
    $raw = & az account show -o json 2>$null
    if (-not $raw){ Die "You're not signed in with your normal account. Run 'az login' (or kit menu L) first, then re-run this." }
    return ($raw | ConvertFrom-Json)
}

function Confirm-SafeSub {
    $ctx = Get-MyCtx
    Say "Current subscription: $($ctx.name)  [$($ctx.id)]   tenant $($ctx.tenantId)"
    foreach ($bad in $DenySubstrings){
        if ($ctx.name -and $ctx.name -match [regex]::Escape($bad)){
            Die "Subscription name matches denylist term '$bad'. Refusing. Switch with 'az account set --subscription <lab sub>'."
        }
    }
    $exists = & az group exists -n $ResourceGroup 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $exists){ Die "Azure CLI couldn't check '$ResourceGroup' - your az sign-in likely expired. Run 'az login' and retry." }
    if ("$exists".Trim() -ne 'true'){ Die "Resource group '$ResourceGroup' not found in this subscription. Deploy the lab first (kit menu 1 -> 1)." }
    return $ctx
}

function Ensure-Seeded {
    if (Test-Path $CredFile){ return }
    Warn "No backdoor app found yet - seeding it now (Manage-CloudBackdoorScenario.ps1 -Action Seed)."
    if (-not (Test-Path $ScenarioPs1)){ Die "Can't find $ScenarioPs1 - run this from the kit's cloud\ folder." }
    & pwsh -NoProfile -File $ScenarioPs1 -Action Seed -ResourceGroup $ResourceGroup -AppName $AppName
    if (-not (Test-Path $CredFile)){ Die "Seed did not produce a credential file. Aborting." }
}

function Read-Cred {
    if (-not (Test-Path $CredFile)){ Die "No credential file at $CredFile. Run -Action Login first." }
    $c = Get-Content $CredFile -Raw | ConvertFrom-Json
    if (-not $c.clientSecret){ Die "This demo needs a client-secret credential. Re-seed without -UseCertificate." }
    return $c
}

# --- the "too much rights" grant (Contributor at the RG scope only) ----------
function Grant-Rights {
    param($ctx, $appId)
    if ($Rights -ne 'Contributor'){ Say "Rights = Scoped: leaving the minimal run-command role as-is (least-privilege demo)."; return }
    $rgId = "/subscriptions/$($ctx.id)/resourceGroups/$ResourceGroup"
    $spObjectId = & az ad sp list --filter "appId eq '$appId'" --query "[0].id" -o tsv 2>$null
    if (-not $spObjectId){ Die "No service principal for appId $appId." }
    $have = & az role assignment list --assignee $spObjectId --scope $rgId --query "[?roleDefinitionName=='Contributor'] | length(@)" -o tsv 2>$null
    if ("$have".Trim() -eq '1'){ Ok "Service principal already has Contributor on $ResourceGroup."; return }
    Warn "Granting the built-in 'Contributor' role to the app's service principal at:"
    Warn "    $rgId   (this resource group ONLY - not the subscription)."
    Warn "This is the deliberately over-privileged 'too much rights' artifact. Reversible with -Action Remove."
    $r = Read-Host "  Type GRANT to assign Contributor on the lab RG"
    if ($r -ne 'GRANT'){ Die "Not confirmed - nothing granted." }
    & az role assignment create --assignee-object-id $spObjectId --assignee-principal-type ServicePrincipal `
        --role 'Contributor' --scope $rgId | Out-Null
    Ok "Contributor assigned at $rgId. (Teaching point: one RG-scoped role = full control of every VM in it.)"
}

function Do-Login {
    $ctx = Confirm-SafeSub
    Ensure-Seeded
    $cred = Read-Cred
    Grant-Rights -ctx $ctx -appId $cred.appId

    Say "Signing the Azure CLI in AS the app (service principal $($cred.appId)) in an ISOLATED context."
    Say "Your normal 'az login' is untouched - this session lives only in $BackdoorDir."
    New-Item -ItemType Directory -Force -Path $BackdoorDir | Out-Null
    $login = Az-Backdoor @('login','--service-principal','--username',$cred.appId,'--password',$cred.clientSecret,'--tenant',$cred.tenantId,'--allow-no-subscriptions','-o','json')
    if ($LASTEXITCODE -ne 0){ Die "Service-principal login failed. The secret may have expired ($($cred.expiresDays)-day). Re-seed with the scenario script -Action Seed." }
    Az-Backdoor @('account','set','--subscription',$cred.subscription) 2>$null | Out-Null
    Ok "Backdoor CLI signed in."
    Write-Host ""
    Do-Whoami
    Write-Host ""
    Say "Next:  -Action Shell   (open a shell in this context)  or  -Action RunKit  (run the framework as the app)."
    Say "When the demo is done:  -Action Logoff  (drop this context)  then  -Action Remove  (delete the app + roles)."
}

function Do-Whoami {
    if (-not (Test-Path (Join-Path $BackdoorDir 'azureProfile.json'))){ Die "No backdoor session. Run -Action Login first." }
    $who = Az-Backdoor @('account','show','-o','json') | ConvertFrom-Json
    Say "The Azure CLI is currently acting as:"
    Write-Host ("    name          : {0}" -f $who.user.name)   -ForegroundColor White
    Write-Host ("    type          : {0}" -f $who.user.type)   -ForegroundColor White
    Write-Host ("    subscription  : {0}  [{1}]" -f $who.name, $who.id) -ForegroundColor White
    Write-Host ("    tenant        : {0}" -f $who.tenantId)    -ForegroundColor White
    if ($who.user.type -eq 'servicePrincipal'){ Ok "Confirmed: this is the APP identity, not a user. No human signed in." }
    Write-Host ""
    Say "What this identity can do at the lab RG (its RBAC):"
    $rgId = "/subscriptions/$($who.id)/resourceGroups/$ResourceGroup"
    Az-Backdoor @('role','assignment','list','--assignee',$who.user.name,'--scope',$rgId,'--query',"[].{Role:roleDefinitionName,Scope:scope}",'-o','table')
    Write-Host ""
    Say "Blue-team framing: that role list + 'runCommand/action' = SYSTEM on every VM in scope."
    Say "Detections: 'Add service principal credentials', 'Add app role assignment' (T1098.001), AzureActivity roleAssignments/write."
}

function Do-Shell {
    if (-not (Test-Path (Join-Path $BackdoorDir 'azureProfile.json'))){ Die "No backdoor session. Run -Action Login first." }
    Say "Opening a NEW PowerShell window in the backdoor CLI context."
    Say "In it, 'az account show' reports the app, and you can run:  .\DefXDRLabKit.ps1"
    Warn "Close that window when you're done; this one stays in your normal context."
    $banner = "`$host.UI.RawUI.WindowTitle = 'DefXDRLabKit - BACKDOOR CLI CONTEXT (service principal)'; " +
              "Write-Host 'This shell acts as the backdoor APP registration (isolated az context).' -ForegroundColor Magenta; " +
              "Write-Host 'az account show  ->  user.type = servicePrincipal. Run .\DefXDRLabKit.ps1 here.' -ForegroundColor DarkGray; " +
              "Set-Location '$KitDir'"
    # The child inherits our environment, so set AZURE_CONFIG_DIR for the launch
    # then restore it (works on any PowerShell; avoids Start-Process -Environment,
    # which needs 7.4+).
    $old = $env:AZURE_CONFIG_DIR
    $env:AZURE_CONFIG_DIR = $BackdoorDir
    try { Start-Process pwsh -ArgumentList @('-NoExit','-NoProfile','-Command',$banner) }
    finally { $env:AZURE_CONFIG_DIR = $old }
    Ok "Launched. That window is your 'attacker with only an app secret' console."
}

function Do-RunKit {
    if (-not (Test-Path (Join-Path $BackdoorDir 'azureProfile.json'))){ Die "No backdoor session. Run -Action Login first." }
    if (-not (Test-Path $KitPs1)){ Die "Can't find $KitPs1." }
    Say "Launching DefXDRLabKit.ps1 in the backdoor context. The kit's startup Azure check will show the APP as the signed-in identity."
    Warn "Scoped rights (run-command only) run the attack/detect steps (menu 5, menu 4 hunts). Deploy/Sentinel need the Contributor variant."
    $old = $env:AZURE_CONFIG_DIR
    $env:AZURE_CONFIG_DIR = $BackdoorDir
    try { & pwsh -NoProfile -File $KitPs1 } finally { $env:AZURE_CONFIG_DIR = $old }
}

function Do-Logoff {
    if (Test-Path $BackdoorDir){
        Az-Backdoor @('logout') 2>$null | Out-Null
        Remove-Item $BackdoorDir -Recurse -Force -ErrorAction SilentlyContinue
        Ok "Backdoor CLI context signed out and removed ($BackdoorDir). Your normal 'az login' is unchanged."
    } else { Say "No backdoor context to remove." }
    Say "The app registration + roles still exist. Run -Action Remove to delete them too."
}

function Do-Remove {
    Do-Logoff
    if (-not (Test-Path $ScenarioPs1)){ Die "Can't find $ScenarioPs1 to tear down the app." }
    Say "Tearing down the app registration, service principal, custom role, any Contributor assignment, and the local credential."
    # The scenario's Remove deletes the app+SP (which drops ALL its role assignments,
    # including the Contributor one this script may have added) and the custom role.
    & pwsh -NoProfile -File $ScenarioPs1 -Action Remove -ResourceGroup $ResourceGroup -AppName $AppName
    Ok "Teardown handed off to the scenario script."
}

switch ($Action){
    'Login'  { Do-Login }
    'Whoami' { Do-Whoami }
    'Shell'  { Do-Shell }
    'RunKit' { Do-RunKit }
    'Logoff' { Do-Logoff }
    'Remove' { Do-Remove }
}
