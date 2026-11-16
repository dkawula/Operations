<#
.SYNOPSIS
    Set the workshop's Attack Surface Reduction (ASR) rules to Audit or Enforce.

.DESCRIPTION
    Runs in-guest on WIN11. Drives the "watch it die" lab: set the rules to
    Audit to measure, then flip the LSASS rule (or all of them) to Enforce and
    re-run the credential-theft step to watch it get blocked. These are
    defensive Windows controls; GUIDs are Microsoft's published ASR rule IDs.

.EXAMPLE
    ./06-Configure-ASR.ps1 -Mode Audit
    ./06-Configure-ASR.ps1 -Rule LSASS -Mode Enforce
    ./06-Configure-ASR.ps1 -Mode Enforce        # all workshop rules
#>
[CmdletBinding()]
param(
    [ValidateSet('Audit','Enforce','Off')][string]$Mode = 'Audit',
    [ValidateSet('All','LSASS')][string]$Rule = 'All'
)
$ErrorActionPreference = 'Stop'
function Say($m){ Write-Host "[asr] $m" -ForegroundColor Cyan }

# Microsoft's published ASR rule GUIDs (the workshop subset).
$rules = [ordered]@{
    'Block credential stealing from LSASS'               = '9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2'
    'Block process creations from PSExec and WMI'        = 'd1e49aac-8f56-4280-b9ba-993a6d77406c'
    'Block persistence through WMI event subscription'   = 'e6db77e5-3df2-4cf1-b95a-636979351e5b'
    'Block executable content from email and webmail'    = 'be9ba2d9-53ea-4cdc-84e5-9b1eeee46550'
    'Block Office apps from creating child processes'    = 'd4f940ab-401b-4efc-aadc-ad5f3c50688a'
    'Block obfuscated scripts'                           = '5beb7efe-fd9a-4556-801d-275e5ffc04cc'
}
$action = switch ($Mode) { 'Audit' {'AuditMode'} 'Enforce' {'Enabled'} 'Off' {'Disabled'} }

$targets = if ($Rule -eq 'LSASS') {
    @{ 'Block credential stealing from LSASS' = $rules['Block credential stealing from LSASS'] }
} else { $rules }

foreach ($name in $targets.Keys) {
    Add-MpPreference -AttackSurfaceReductionRules_Ids $targets[$name] -AttackSurfaceReductionRules_Actions $action
    Say "  [$Mode] $name"
}
Say "Done. Current ASR rule IDs:"
(Get-MpPreference).AttackSurfaceReductionRules_Ids | ForEach-Object { Say "   $_" }
Say "Events land in advanced hunting (DeviceEvents, ActionType startswith 'Asr')."
