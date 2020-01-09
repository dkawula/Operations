#Build Script for DataON 5212 Veeam Backup Repository and Replica Target
#This Configuration assume no RoCE / RDMA
#Note -When I have more Time I'll automate the configuration of the Storage Pool, Virtual Disks, Journal Disk, and Volumes via PowerShell.


#region 001 - Install the Core Roles Required for Storage Spaces Standalone
$nodes = ("Nakaro-BK01")

Invoke-Command $nodes {Install-WindowsFeature FS-Data-Deduplication}

Invoke-Command $nodes {Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart} 

#DataON Specific Settings

# <<MUST>> Enable Remote Desktop Connnection
Invoke-Command $Nodes {
    # Enable Remote Desktop
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-Name "fDenyTSConnections" -Value 0

    # Allow connections NOT only  from computers running RDP with Network Level Authentication
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0 
    
    # Allow RDP on Firewall
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
    Get-NetFirewallRule -DisplayGroup "Remote Desktop" | ft Name,Enabled,Profile

} 
 

# <<MUST>> Enable Ping 
Invoke-Command -ComputerName $nodes -ScriptBlock {

    Enable-NetFirewallRule -Name 'FPS-ICMP4-ERQ-In'
}

# NEW - Fixed Windows Update Settings for Server2019
#Configure Automatic Updates to Download Only / DO NOT DOWNLOAD Drivers post
Invoke-Command $Nodes {
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX -Name IsConvergedUpdateStackEnabled -Value 0 -verbose
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings -Name ExcludeWUDriversInQualityUpdate -Value 1 -verbose
}

#endregion


#region 002 - Configure the Hyper-V SET (Switch Embedded Teaming) which supports RDMA over Teamed Connections, also create all the Virtual Adapters....

#Create Hyper-V Virtual SET Switch

Invoke-Command $Nodes {Get-Netadapter | FT Name, InterfaceDescription,Status,LinkSpeed}

#Invoke-Command $Nodes {New-VmSwitch -Name VSW01 -NetAdapterName "RDMA_1","RDMA_2" -EnableEmbeddedTeaming $True -AllowManagementOS $False -verbose }

Invoke-Command $Nodes {New-VmSwitch -Name VSW02 -NetAdapterName "Ethernet" -EnableEmbeddedTeaming $True -AllowManagementOS $False -verbose }

#Create the Virtual Adapters --> Open ncpa.cpl to see them being created
Invoke-Command $Nodes {

#Add-VMNetworkAdapter -SwitchName VSW01 -Name SMB_1 -ManagementOS

#Add-VMNetworkAdapter -SwitchName VSW01 -Name SMB_2 -ManagementOS

#Add-VMNetworkAdapter -SwitchName VSW01 -Name LM -ManagementOS

#Add-VMNetworkAdapter -SwitchName VSW01 -Name HB -ManagementOS

Add-VMNetworkAdapter -SwitchName VSW02 -Name MGMT -ManagementOS}

Invoke-Command $Nodes {
$vmswitch = Get-VMSwitch -Name "vsw02"
Add-VMSwitchTeamMember -VMSwitch $VMSwitch -NetAdapterName "Ethernet 2"}

#endregion

#region 003 - Configure the VLANs for the LAB
#All of the configurations were done here per the Mellanox Guide
#Assign the VLANs to the Virtual Adapters

Invoke-Command $Nodes {

$Nic = Get-VMNetworkAdapter -Name SMB_1 -ManagementOS

Set-VMNetworkAdapterVlan -VMNetworkAdapter $Nic -VlanId 619 -Access

$Nic = Get-VMNetworkAdapter -Name SMB_2 -ManagementOS

Set-VMNetworkAdapterVlan -VMNetworkAdapter $nic -VlanId 619 -Access

$Nic = Get-VMNetworkAdapter -Name LM -ManagementOS

Set-VMNetworkAdapterVlan -VMNetworkAdapter $nic -VlanId 618 -Access

$Nic = Get-VMNetworkAdapter -Name HB -ManagementOS

Set-VMNetworkAdapterVlan -VMNetworkAdapter $nic -VlanId 617 -Access

#$Nic = Get-VMNetworkAdapter -Name MGMT -ManagementOS

#Set-VMNetworkAdapterVlan -VMNetworkAdapter $nic -VlanId 877 -Access



}



#Show the VLAN Configuraiton

Invoke-Command $Nodes {Get-VMNetworkAdapterVlan -ManagementOS} 

#endregion

#region 004 - Configure Active Memory Dumps from Full on all Nodes 


#Configure the Active Memory Dummp from Full Memory Dump on all Nodes

Invoke-Command $Nodes {
Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl -Name CrashDumpEnabled -Value 1
Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl -Name FilterPages -Value 1
Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl -Name CrashDumpEnabled
Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl -Name FilterPages
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

dism /online /Set-Edition:ServerDataCenter /ProductKey:<REATIL KEY> /AcceptEula

slmgr.vbs /ipk <DATACENTERKEY>
slmgr /ato

#endregion

#region 007 - Change Power Plan  ****************MANUAL SETUP on BOTH Nodes**********************

#Manually go change the powerplan to HIGHPOWER in the control Panel -- This is already set by DATAON

#DataON Configured this in their Image

#endregion

#region 008 - Validate Settings
    Get-StoragePool | ft
    Get-VirtualDisk | ft
    Get-PhysicalDisk | ft
#endregion


