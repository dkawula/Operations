#Workaround for get-windowsautopilotinfo not working

$IntuneModule = Get-Module -Name "Microsoft.Graph.Intune" -ListAvailable
if (!$IntuneModule){
 
write-host "Microsoft.Graph.Intune Powershell module not installed..." -f Red
write-host "Install by running 'Install-Module Microsoft.Graph.Intune' from an elevated PowerShell prompt" -f Yellow
write-host "Script can't continue..." -f Red
write-host
exit
}
####################################################
# Importing the SDK Module
Import-Module -Name Microsoft.Graph.Intune
 
if(!(Connect-MSGraph)){
Connect-MSGraph
}
####################################################
 
#### Insert your script here
 
#### Gets all devices running Windows
$Devices = Get-IntuneManagedDevice -Filter "contains(operatingsystem,'Windows')"
#$Devices = $Devices1 | where DeviceName -eq DKSURFACE02 
 
#Now that we are connected to the Graph API we shouldn't need to connect again.
Install-Script Get-Windowsautopilotinfo
Get-WindowsAutoppilotinfo -online