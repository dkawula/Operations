#This is the Fabric Post Configuration Script for MFG

#region 001 - Install the Core Roles Required for Storage Spaces Standalone
$nodes = ("FABDC01","FABDC02","FABMGMT01")

$DomainCred = Get-Credential
#General Cleanup Specific Settings

#Enable Remote Desktop Connnection

Foreach ($Node in $Nodes) {

Invoke-Command $Node -Credential $DomainCred {
    # Enable Remote Desktop
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-Name "fDenyTSConnections" -Value 0

    # Allow connections NOT only  from computers running RDP with Network Level Authentication
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0 
    
    # Allow RDP on Firewall
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
    Get-NetFirewallRule -DisplayGroup "Remote Desktop" | ft Name,Enabled,Profile

} 

}
 

#Enable Ping 

foreach ($node in $Nodes) {

Invoke-Command -ComputerName $nodes -ScriptBlock {

    Enable-NetFirewallRule -Name 'FPS-ICMP4-ERQ-In'
}

}

# NEW - Fixed Windows Update Settings for Server2019
#Configure Automatic Updates to Download Only / DO NOT DOWNLOAD Drivers post

foreach ($node in $nodes) {
Invoke-Command $Node {
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX -Name IsConvergedUpdateStackEnabled -Value 0 -verbose
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings -Name ExcludeWUDriversInQualityUpdate -Value 1 -verbose
}

}

#endregion



#region 004 - Configure Active Memory Dumps from Full on all Nodes 


#Configure the Active Memory Dummp from Full Memory Dump on all Nodes

foreach ($node in $Nodes){

Invoke-Command $Node {
Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl -Name CrashDumpEnabled -Value 1
Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl -Name FilterPages -Value 1
Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl -Name CrashDumpEnabled
Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl -Name FilterPages
}
}

#endregion

#region 005 - Join Backup Targets Nodes to the Domain

<#>#Run this command from one of the nodes After S2D1 has been joined if not on a MGMT Server

$nodes = ("S2D2", "S2D3", "S2D4")

Invoke-Command $Nodes {

Add-Computer -DomainName Checkyourlogs.net -Reboot

}

</#>

#endregion

#region 006 - [DATAON]Activate Windows DataCenter Edition with Customer KEY - It ships with the EVAL Edition

#The DataON Nodes we have Ship with Standard Edition on these Backup Targets
#If you want to Convert to DataCenter run the following.
#Need a Reatil KEY for this to work we will change it after
#Steps from https://www.checkyourlogs.net/?p=64153 - Cary Sun MVP CCIE

Invoke-Command $nodes {

#dism /online /Set-Edition:ServerDataCenter /ProductKey:D3KN4-FBMXT-3RWBH-Q8D4G-PDPH7 /AcceptEula

cmd.exe /c "slmgr.vbs /ipk xxxx"
cmd.exe /c "slmgr /ato"

}

#endregion

#Remove Unattend.xml 
Invoke-Command $Nodes {

get-childitem c:\unattend.xml | Remove-Item -Force

}


#Reset the Password of the local Admin Accounts
$computers = "MFGFABMGMT01","DESIREE"
$useracct = "Administrator"
$password = "xxx"

foreach ($computer in $computers)
{
    Write-Host "Setting $useracct's password on $computer"
    $user = [adsi]"WinNT://$computer/$useracct,user"
    $user.SetPassword($password)
    $user.SetInfo()
    Write-Host "Password set on $computer"
}
