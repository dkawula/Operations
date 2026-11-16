<#
.SYNOPSIS
    Start, stop (deallocate), check, or tear down the Azure workshop lab.

.DESCRIPTION
    Thin cost-control + lifecycle wrapper over the resource group created by
    Deploy-AzureLab.ps1. "Stop" deallocates every VM so compute billing stops
    while the disks (and your built lab) remain. "Destroy" deletes the whole
    resource group - the one-command teardown.

.EXAMPLE
    ./Manage-AzureLab.ps1 -Action Status
    ./Manage-AzureLab.ps1 -Action Stop
    ./Manage-AzureLab.ps1 -Action Start
    ./Manage-AzureLab.ps1 -Action Destroy
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Start','Stop','Status','Destroy')]
    [string]$Action,
    [string]$ResourceGroup = 'rg-defxdr-lab'
)
$ErrorActionPreference = 'Stop'
function Say($m){ Write-Host "[lab] $m" -ForegroundColor Cyan }

$rgOut = try { az group exists -n $ResourceGroup 2>$null } catch { $null }
if ($LASTEXITCODE -ne 0 -or -not $rgOut) {
    throw "Azure CLI couldn't check '$ResourceGroup' - your az sign-in has most likely expired. Run 'az login' (kit main menu -> L) and retry. Nothing was changed."
}
if ("$rgOut".Trim() -ne 'true') {
    throw "Resource group '$ResourceGroup' not found. Nothing to manage."
}

switch ($Action) {
    'Status' {
        Say "VM power states in '$ResourceGroup':"
        az vm list -g $ResourceGroup -d -o table --query "[].{Name:name, Power:powerState, PrivateIp:privateIps, PublicIp:publicIps}"
    }
    'Start' {
        Say "Starting all VMs (DC01 first so AD/DNS is up before the others)..."
        az vm start -g $ResourceGroup -n DC01 -o none 2>$null
        $others = az vm list -g $ResourceGroup --query "[?name!='DC01'].name" -o tsv
        foreach ($n in $others) { Say "  starting $n"; az vm start -g $ResourceGroup -n $n -o none }
        Say "All start commands issued. Current power states:"
        az vm list -g $ResourceGroup -d -o table --query "[].{Name:name, Power:powerState}"
    }
    'Stop' {
        Say "Deallocating all VMs (compute billing stops; disks remain)..."
        $all = az vm list -g $ResourceGroup --query "[].name" -o tsv
        foreach ($n in $all) { Say "  deallocating $n"; az vm deallocate -g $ResourceGroup -n $n -o none }
        Say "All deallocate commands issued. Current power states:"
        az vm list -g $ResourceGroup -d -o table --query "[].{Name:name, Power:powerState}"
    }
    'Destroy' {
        Write-Host "[lab] This DELETES the entire resource group '$ResourceGroup' and everything in it." -ForegroundColor Red
        Say "Resources that will be deleted:"
        az resource list -g $ResourceGroup -o table --query "sort_by([].{Name:name, Type:type}, &Type)" 2>$null
        $c = Read-Host "Type the resource group name to confirm (anything else cancels)"
        if ($c -ne $ResourceGroup) { Say "Name did not match; aborted. Nothing deleted."; return }
        Say "Submitting delete for '$ResourceGroup'..."
        az group delete -n $ResourceGroup --yes --no-wait
        Say "Delete submitted. Verifying teardown - this can take several minutes..."
        $start = Get-Date; $timeout = [TimeSpan]::FromMinutes(25)
        while ($true) {
            Start-Sleep -Seconds 15
            $exists = $false
            $exists = $true   # if az fails (e.g. expired sign-in) keep waiting rather than falsely report 'gone'
            try { $o = az group exists -n $ResourceGroup 2>$null; if ($LASTEXITCODE -eq 0 -and $o) { $exists = ("$o".Trim() -eq 'true') } } catch {}
            $elapsed = (Get-Date) - $start
            $mmss = '{0}m{1:00}s' -f [int]$elapsed.TotalMinutes, ($elapsed.Seconds)
            if (-not $exists) {
                Write-Host "[lab] CONFIRMED: resource group '$ResourceGroup' is gone. Teardown complete ($mmss)." -ForegroundColor Green
                break
            }
            $remaining = '?'
            try { $remaining = az resource list -g $ResourceGroup --query "length(@)" -o tsv 2>$null } catch {}
            Write-Host ("[lab]   still deleting... {0} resource(s) left, {1} elapsed" -f $remaining, $mmss) -ForegroundColor DarkGray
            if ($elapsed -gt $timeout) {
                Write-Host "[lab] Still deleting after $([int]$timeout.TotalMinutes) min. Azure will finish on its own - re-run '-Action Status' or check the portal to confirm." -ForegroundColor Yellow
                break
            }
        }
    }
}
