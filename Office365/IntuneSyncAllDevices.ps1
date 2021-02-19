#Sync script from https://timmyit.com/2019/06/04/intune-invoke-sync-to-all-devices-in-intune-with-the-intune-powershell-sdk/#:~:text=The%20manual%20way%20of%20invoking%20a%20sync%20to,with%20the%20help%20of%20the%20Intune%20Powershell%20SDK.
#Side note. If you want to sync more than 1000 devices you need to do something called Paging. 
#The Intune Powershell SDK uses Graph API which is a REST API and returns pages containing 1000 objects at the time, 
#if you exceed 1000 you need to get the next page containing the next 1000 objects and so on until you got all the objects. This can be done by using the cmdlet Get-MSGraphAllPages.


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
$Devices
 
Foreach ($Device in $Devices)
{
 
Invoke-IntuneManagedDeviceSyncDevice -managedDeviceId $Device.managedDeviceId
Write-Host "Sending Sync request to Device with DeviceID $($Device.managedDeviceId)" -ForegroundColor Yellow
 
}
 
####################################################