<#
.SYNOPSIS
    Deploy Microsoft Sentinel for the lab: a Log Analytics workspace, Sentinel
    enabled on it, and the Azure Activity connector wired up. Narrates the
    Defender XDR connector (portal-only) at the end.

.DESCRIPTION
    Advanced-detection layer for the workshop. Creates (or reuses) a Log
    Analytics workspace, enables Microsoft Sentinel on it by deploying the
    SecurityInsights solution, and connects the subscription's Azure Activity
    log so you have cross-source data and hunting straight away. The
    Defender XDR connector (MDE / MDI / Entra ID) is enabled with one toggle in
    the portal - this script prints exactly where.

    Requires: az signed in to your LAB subscription, Contributor on it.
    Sentinel is a paid service - keep it in the lab subscription and remove the
    resource group when you're done.

.EXAMPLE
    ./Deploy-Sentinel.ps1 -ResourceGroup rg-defxdr-lab -Location canadacentral
#>
[CmdletBinding()]
param(
    [string]$ResourceGroup = 'rg-defxdr-lab',
    [string]$Location      = 'eastus',
    [string]$WorkspaceName = 'law-defxdr-lab',
    [int]$RetentionDays    = 90
)
$ErrorActionPreference = 'Stop'
function Say($m){ Write-Host "[sentinel] $m" -ForegroundColor Cyan }
function Warn($m){ Write-Host "[sentinel] $m" -ForegroundColor Yellow }

$acct = az account show -o json 2>$null | ConvertFrom-Json
if (-not $acct) { throw "Not signed in. Run 'az login' first." }
Say "Subscription: $($acct.name)  ($($acct.id))"

# --- Log Analytics workspace --------------------------------------------
Say "Creating / reusing Log Analytics workspace '$WorkspaceName'..."
az monitor log-analytics workspace create -g $ResourceGroup -n $WorkspaceName -l $Location `
    --retention-time $RetentionDays -o none
$wsId = az monitor log-analytics workspace show -g $ResourceGroup -n $WorkspaceName --query id -o tsv

# --- enable Microsoft Sentinel (SecurityInsights solution) --------------
Say "Enabling Microsoft Sentinel on the workspace..."
$tpl = @'
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": { "workspaceName": {"type":"string"}, "location": {"type":"string"} },
  "resources": [
    {
      "type": "Microsoft.OperationsManagement/solutions",
      "apiVersion": "2015-11-01-preview",
      "name": "[concat('SecurityInsights(', parameters('workspaceName'), ')')]",
      "location": "[parameters('location')]",
      "properties": { "workspaceResourceId": "[resourceId('Microsoft.OperationalInsights/workspaces', parameters('workspaceName'))]" },
      "plan": {
        "name": "[concat('SecurityInsights(', parameters('workspaceName'), ')')]",
        "product": "OMSGallery/SecurityInsights",
        "publisher": "Microsoft",
        "promotionCode": ""
      }
    }
  ]
}
'@
$tf = Join-Path $env:TEMP 'sentinel-enable.json'; $tpl | Set-Content $tf -Encoding utf8
az deployment group create -g $ResourceGroup --template-file $tf `
    --parameters workspaceName=$WorkspaceName location=$Location -o none
Say "Sentinel enabled."

# --- Azure Activity connector (subscription diagnostic -> workspace) -----
Say "Connecting the Azure Activity log to the workspace..."
$logs = '[{"category":"Administrative","enabled":true},{"category":"Security","enabled":true},{"category":"Policy","enabled":true},{"category":"ServiceHealth","enabled":true},{"category":"ResourceHealth","enabled":true},{"category":"Alert","enabled":true}]'
try {
    az monitor diagnostic-settings subscription create --name 'defxdr-activity-to-sentinel' `
        --location $Location --subscription $acct.id --workspace $wsId --logs $logs -o none
    Say "Azure Activity -> Sentinel connected."
} catch {
    Warn "Couldn't auto-wire Azure Activity (permissions?). In Sentinel: Data connectors -> Azure Activity -> Open connector page."
}

# --- the portal-only connectors -----------------------------------------
Say ""
Say "NEXT (portal - one toggle each):"
Say "  Defender XDR connector (pulls MDE + MDI + Entra ID alerts into Sentinel):"
Say "    security.microsoft.com -> System -> Settings -> Microsoft Sentinel, OR"
Say "    Sentinel -> Configuration -> Data connectors -> 'Microsoft Defender XDR' -> Open connector page -> Connect."
Say "  Microsoft Entra ID connector: Data connectors -> 'Microsoft Entra ID' (needs a Sentinel/Global admin role)."
Say ""
Say "Hunt: Sentinel -> Logs (or Defender portal -> Advanced hunting). Try:  AzureActivity | take 50"
Say "Done. Workspace: $WorkspaceName   (retention ${RetentionDays}d). Remove the resource group to stop Sentinel charges."
