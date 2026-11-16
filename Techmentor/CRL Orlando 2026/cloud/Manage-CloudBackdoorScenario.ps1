<#
=====================================================================
 Manage-CloudBackdoorScenario.ps1
   Module 0b lab scenario: a DELIBERATELY over-privileged, scoped
   service principal that the BLUE team then hunts and removes.

   This is detection training on a lab you own - the cloud analogue of
   the kit's Weaken-AD / Harden-AD steps. It SEEDS a misconfiguration,
   lets you HUNT it from the Defender/Entra/Activity-log side, and then
   REMOVES it. It contains NO exploitation and NO operator tooling - it
   only creates the lab artifact and the means to find and clean it up.

 SAFETY RAILS (because you run this from your own laptop):
   * Everything is scoped to ONE resource group (default rg-defxdr-lab).
     The custom role's AssignableScopes is that RG only, so it can never
     be assigned anywhere else in the subscription.
   * A subscription-safety gate confirms you're in the lab subscription
     and blocks a known denylist before it creates anything.
   * The credential is short-lived (default 7 days) and written to a
     local protected folder OUTSIDE OneDrive (never committed/synced).
   * Seed and Remove require a typed confirmation.
   * Remove fully deletes the app/SP, the role assignment, the custom
     role definition, and the local credential file.

 Usage:
   .\Manage-CloudBackdoorScenario.ps1 -Action Seed    [-UseCertificate]
   .\Manage-CloudBackdoorScenario.ps1 -Action Hunt
   .\Manage-CloudBackdoorScenario.ps1 -Action Status
   .\Manage-CloudBackdoorScenario.ps1 -Action Remove

 Authorized lab use only.
=====================================================================
#>
[CmdletBinding()]
param(
    [ValidateSet('Seed','Hunt','Status','Remove')]
    [string]$Action = 'Status',
    [string]$ResourceGroup = 'rg-defxdr-lab',
    [string]$AppName       = 'defxdr-lab-contractor-DEMO',
    [string]$RoleName      = 'DefXDR Lab VM Maintenance (DEMO)',
    [int]$SecretDays       = 7,
    [switch]$UseCertificate,
    [string]$ExpectedSubscription,                 # optional: name to require
    [string[]]$DenySubstrings = @('PROD','Production'),
    [string]$CredDir = (Join-Path $env:USERPROFILE '.defxdrlab\cloud-scenario')
)

$ErrorActionPreference = 'Stop'
function Say ($m){ Write-Host "[0b] $m" -ForegroundColor Cyan }
function Ok  ($m){ Write-Host "[0b] [OK] $m" -ForegroundColor Green }
function Warn($m){ Write-Host "[0b] [!!] $m" -ForegroundColor Yellow }
function Die ($m){ Write-Host "[0b] [XX] $m" -ForegroundColor Red; exit 1 }

function Get-Ctx {
    $raw = az account show -o json 2>$null
    if (-not $raw){ Die "Not logged in. Run 'az login' first." }
    return ($raw | ConvertFrom-Json)
}

# --- subscription safety gate -------------------------------------------------
function Confirm-SafeSub {
    $ctx = Get-Ctx
    Say "Current subscription: $($ctx.name)  [$($ctx.id)]"
    Say "Tenant: $($ctx.tenantId)"
    foreach ($bad in $DenySubstrings){
        if ($ctx.name -and $ctx.name -match [regex]::Escape($bad)){
            Die "Subscription name matches denylist term '$bad'. Refusing to touch it. Switch with 'az account set --subscription <lab sub>'."
        }
    }
    if ($ExpectedSubscription -and ($ctx.name -ne $ExpectedSubscription)){
        Die "Current sub '$($ctx.name)' != expected '$ExpectedSubscription'. Aborting."
    }
    # confirm the RG exists in this sub
    $exists = az group exists -n $ResourceGroup 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $exists){ Die "Azure CLI couldn't check '$ResourceGroup' - your az sign-in has most likely expired. Run 'az login' and retry." }
    if ("$exists".Trim() -ne 'true'){ Die "Resource group '$ResourceGroup' not found in this subscription. Deploy the lab first (kit menu 1 -> 1)." }
    return $ctx
}

function Typed-Confirm ($word){
    $r = Read-Host "  Type '$word' to proceed"
    if ($r -ne $word){ Die "Confirmation did not match. Aborting - nothing changed." }
}

$RoleNameUnique = "$RoleName $($ResourceGroup)"   # keep it findable + RG-specific
$CredFile = Join-Path $CredDir ("{0}.cred.json" -f $AppName)

# =====================================================================
#  SEED  - create the scoped lab artifact
# =====================================================================
function Do-Seed {
    $ctx = Confirm-SafeSub
    $subId = $ctx.id
    $rgId  = "/subscriptions/$subId/resourceGroups/$ResourceGroup"
    Warn "This SEEDS a deliberately over-privileged, RG-scoped service principal as a LAB ARTIFACT for detection training."
    Warn "Scope: $rgId  (this RG only). Credential expires in $SecretDays days."
    Typed-Confirm 'SEED'

    New-Item -ItemType Directory -Force -Path $CredDir | Out-Null

    # 1) Minimal custom role: just run-command + read, assignable ONLY in the lab RG.
    Say "Creating minimal custom role '$RoleNameUnique' (assignable scope = the lab RG only)..."
    $roleDef = [ordered]@{
        Name             = $RoleNameUnique
        IsCustom         = $true
        Description      = "DEMO lab artifact (Module 0b). Grants VM Run Command + read. Assignable in $ResourceGroup only. Safe to delete."
        Actions          = @(
            'Microsoft.Compute/virtualMachines/read',
            'Microsoft.Compute/virtualMachines/runCommand/action',
            'Microsoft.Compute/virtualMachines/runCommands/read'
        )
        NotActions       = @()
        DataActions      = @()
        NotDataActions   = @()
        AssignableScopes = @($rgId)
    }
    $roleTmp = Join-Path $CredDir 'role.json'
    $roleDef | ConvertTo-Json -Depth 5 | Set-Content $roleTmp -Encoding utf8
    $existingRole = az role definition list --name $RoleNameUnique --query "[0].name" -o tsv 2>$null
    if ($existingRole){ Ok "Custom role already exists - reusing." }
    else { az role definition create --role-definition "@$roleTmp" | Out-Null; Ok "Custom role created." }
    Remove-Item $roleTmp -ErrorAction SilentlyContinue

    # 2) App registration + service principal.
    Say "Creating app registration '$AppName'..."
    $appId = az ad app list --display-name $AppName --query "[0].appId" -o tsv 2>$null
    if (-not $appId){
        $appId = az ad app create --display-name $AppName --sign-in-audience AzureADMyOrg --query appId -o tsv
        Ok "App registration created (appId $appId)."
    } else { Ok "App registration already exists (appId $appId)." }
    $spId = az ad sp list --filter "appId eq '$appId'" --query "[0].id" -o tsv 2>$null
    if (-not $spId){ az ad sp create --id $appId | Out-Null; Ok "Service principal created." }
    else { Ok "Service principal already exists." }
    $spObjectId = az ad sp list --filter "appId eq '$appId'" --query "[0].id" -o tsv

    # 3) Credential (short-lived). Secret by default; certificate if asked.
    $cred = [ordered]@{
        note        = "DEMO lab artifact - Module 0b. Delete with -Action Remove. Do NOT commit or sync."
        appId       = $appId
        tenantId    = $ctx.tenantId
        subscription= $ctx.id
        resourceGrp = $ResourceGroup
        created     = (Get-Date).ToString('s')
        expiresDays = $SecretDays
        authType    = if ($UseCertificate){'certificate'} else {'secret'}
    }
    if ($UseCertificate){
        Say "Adding a self-signed certificate credential (expires in $SecretDays days)..."
        $certOut = az ad app credential reset --id $appId --create-cert --years 1 2>$null | ConvertFrom-Json
        $cred.certPath = $certOut.fileWithCertAndPrivateKey
        Ok "Certificate credential added (file: $($certOut.fileWithCertAndPrivateKey))."
    } else {
        Say "Adding a client secret (expires in $SecretDays days)..."
        $end = (Get-Date).AddDays($SecretDays).ToString('yyyy-MM-dd')
        $secret = az ad app credential reset --id $appId --append --end-date $end --query password -o tsv
        $cred.clientSecret = $secret
        Ok "Client secret added (expires $end)."
    }

    # 4) Role assignment, scoped to the RG only.
    Say "Assigning '$RoleNameUnique' to the service principal at the lab RG scope..."
    az role assignment create --assignee-object-id $spObjectId --assignee-principal-type ServicePrincipal `
        --role $RoleNameUnique --scope $rgId | Out-Null
    Ok "Role assigned at $rgId."

    # 5) Save credentials to a protected local file outside OneDrive.
    $cred | ConvertTo-Json -Depth 5 | Set-Content $CredFile -Encoding utf8
    try {
        $acl = Get-Acl $CredFile
        $acl.SetAccessRuleProtection($true,$false)
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($env:USERNAME,'FullControl','Allow')
        $acl.SetAccessRule($rule); Set-Acl $CredFile $acl
    } catch { Warn "Couldn't tighten ACL on the cred file (non-fatal)." }
    Ok "Credentials saved: $CredFile  (local only - not synced; delete with -Action Remove)."

    Write-Host ""
    Say "SEED complete. This is the lab artifact your blue team now HUNTS."
    Say "Next: run -Action Hunt (kit menu) to find it in role assignments + the audit log."
    Say "When done: -Action Remove tears the whole thing down."
}

# =====================================================================
#  HUNT  - find the artifact from the blue-team side
# =====================================================================
function Do-Hunt {
    $ctx = Get-Ctx
    $subId = $ctx.id
    $rgId  = "/subscriptions/$subId/resourceGroups/$ResourceGroup"
    Say "Hunting for over-privileged service principals scoped to $ResourceGroup ..."
    Write-Host ""
    Say "1) Role assignments at the lab RG whose principal is a service principal:"
    az role assignment list --scope $rgId --query "[?principalType=='ServicePrincipal'].{Principal:principalName, Role:roleDefinitionName, Scope:scope}" -o table
    Write-Host ""
    Say "2) Custom roles that grant VM Run Command (code-exec-as-SYSTEM = tier-0):"
    az role definition list --custom-role-only true --query "[?contains(to_string(permissions[0].actions), 'runCommand')].{Role:roleName, AssignableScopes:assignableScopes}" -o table
    Write-Host ""
    Say "3) Recent control-plane writes (role assignments / definitions) in the Activity Log:"
    $since = (Get-Date).AddDays(-7).ToString('yyyy-MM-ddTHH:mm:ssZ')
    az monitor activity-log list --resource-group $ResourceGroup --start-time $since `
        --query "[?contains(operationName.value,'roleAssignments/write') || contains(operationName.value,'roleDefinitions/write')].{Time:eventTimestamp, Op:operationName.localizedValue, Caller:caller, Status:status.value}" -o table 2>$null
    Write-Host ""
    Say "Blue-team note: in Defender XDR / Sentinel the same signals are 'Add service principal',"
    Say "'Add app role assignment', new SP secret (MITRE T1098.001), and AzureActivity roleAssignments/write."
    Say "Teaching point: a custom role named like 'VM Maintenance' that carries runCommand = SYSTEM on every VM in scope."
}

# =====================================================================
#  STATUS
# =====================================================================
function Do-Status {
    $appId = az ad app list --display-name $AppName --query "[0].appId" -o tsv 2>$null
    $role  = az role definition list --name $RoleNameUnique --query "[0].roleName" -o tsv 2>$null
    Say "App registration '$AppName': $(if($appId){"PRESENT (appId $appId)"}else{'absent'})"
    Say "Custom role '$RoleNameUnique': $(if($role){'PRESENT'}else{'absent'})"
    Say "Local cred file: $(if(Test-Path $CredFile){"PRESENT ($CredFile)"}else{'absent'})"
    if ($appId){ Warn "Lab artifact is live. Remove it with -Action Remove when the demo is done." }
}

# =====================================================================
#  REMOVE  - full reversible cleanup
# =====================================================================
function Do-Remove {
    $ctx = Confirm-SafeSub
    $subId = $ctx.id
    $rgId  = "/subscriptions/$subId/resourceGroups/$ResourceGroup"
    Warn "This REMOVES the lab artifact: the role assignment, the app registration + SP, the custom role, and the local cred file."
    Typed-Confirm 'REMOVE'

    $appId = az ad app list --display-name $AppName --query "[0].appId" -o tsv 2>$null
    if ($appId){
        $spObjectId = az ad sp list --filter "appId eq '$appId'" --query "[0].id" -o tsv 2>$null
        if ($spObjectId){
            Say "Removing role assignment at the lab RG..."
            az role assignment delete --assignee $spObjectId --role $RoleNameUnique --scope $rgId 2>$null
            Ok "Role assignment removed."
        }
        Say "Deleting app registration (removes the SP + its credentials)..."
        az ad app delete --id $appId 2>$null
        Ok "App registration deleted."
    } else { Say "No app registration '$AppName' found - nothing to delete." }

    $roleExists = az role definition list --name $RoleNameUnique --query "[0].name" -o tsv 2>$null
    if ($roleExists){
        Say "Deleting custom role definition..."
        az role definition delete --name $RoleNameUnique 2>$null
        Ok "Custom role deleted."
    }
    if (Test-Path $CredFile){ Remove-Item $CredFile -Force; Ok "Local cred file deleted." }
    Ok "REMOVE complete - the scenario is fully torn down."
}

switch ($Action){
    'Seed'   { Do-Seed }
    'Hunt'   { Do-Hunt }
    'Status' { Do-Status }
    'Remove' { Do-Remove }
}
