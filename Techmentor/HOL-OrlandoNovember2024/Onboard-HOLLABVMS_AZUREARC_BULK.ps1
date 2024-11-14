#This Script will onboard Student Machines Student01-Student60 to Azure 
#You will need to edit the Service Principal Secret
#Dave Kawula-MVP

# Define the range of student computer names
$studentNames = 1..60 | ForEach-Object { "Student{0:D2}" -f $_ }

# Set the script path as a global variable
$global:scriptPath = $MyInvocation.MyCommand.Definition

# Loop through each student computer and run the script remotely
foreach ($student in $studentNames) {
    Invoke-Command -ComputerName $student -ScriptBlock {
        param ($scriptPath)

        function Restart-AsAdmin {
            $pwshCommand = "powershell"
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                $pwshCommand = "pwsh"
            }

            try {
                Write-Host "This script requires administrator permissions to install the Azure Connected Machine Agent. Attempting to restart script with elevated permissions..."
                $arguments = "-NoExit -Command `"& '$scriptPath'`""
                Start-Process $pwshCommand -Verb runAs -ArgumentList $arguments
                exit 0
            } catch {
                throw "Failed to elevate permissions. Please run this script as Administrator."
            }
        }

        try {
            if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                if ([System.Environment]::UserInteractive) {
                    Restart-AsAdmin
                } else {
                    throw "This script requires administrator permissions to install the Azure Connected Machine Agent. Please run this script as Administrator."
                }
            }
            $ServicePrincipalId = "b5d2bdce-eefc-4def-bde5-4e7a7ca7a9ed"
            $ServicePrincipalClientSecret = "<Enter Secret here>"

            $env:SUBSCRIPTION_ID = "62bf0c70-c205-46d4-b220-37b2e262c9e9"
            $env:RESOURCE_GROUP = "rgtmlab"
            $env:TENANT_ID = "24de82e8-d5f5-4bf7-9aa8-91f573f12ace"
            $env:LOCATION = "canadacentral"
            $env:AUTH_TYPE = "principal"
            $env:CORRELATION_ID = "e641e828-d22b-4182-afa2-54558316b3ff"
            $env:CLOUD = "AzureCloud"

            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
            Invoke-WebRequest -UseBasicParsing -Uri "https://gbl.his.arc.azure.com/azcmagent-windows" -TimeoutSec 30 -OutFile "$env:TEMP\install_windows_azcmagent.ps1"
            & "$env:TEMP\install_windows_azcmagent.ps1"
            if ($LASTEXITCODE -ne 0) { exit 1 }
            & "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" connect --service-principal-id "$ServicePrincipalId" --service-principal-secret "$ServicePrincipalClientSecret" --resource-group "$env:RESOURCE_GROUP" --tenant-id "$env:TENANT_ID" --location "$env:LOCATION" --subscription-id "$env:SUBSCRIPTION_ID" --cloud "$env:CLOUD" --correlation-id "$env:CORRELATION_ID"
        }
        catch {
            $logBody = @{
                subscriptionId = "$env:SUBSCRIPTION_ID"
                resourceGroup = "$env:RESOURCE_GROUP"
                tenantId = "$env:TENANT_ID"
                location = "$env:LOCATION"
                correlationId = "$env:CORRELATION_ID"
                authType = "$env:AUTH_TYPE"
                operation = "onboarding"
                messageType = $_.FullyQualifiedErrorId
                message = "$_"
            }
            Invoke-WebRequest -UseBasicParsing -Uri "https://gbl.his.arc.azure.com/log" -Method "PUT" -Body ($logBody | ConvertTo-Json) | Out-Null
            Write-Host -ForegroundColor Red $_.Exception
        }
    } -ArgumentList $scriptPath 
}
