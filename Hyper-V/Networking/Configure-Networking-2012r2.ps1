#old Configuration for Hyper-V Networking with Switch Independent 
#Works great for Windows 2012 R2 or DMZ 2016 Servers
#start-transcript -path c:\post-install\001-NetworkConfig.log
#Create the NIC Team
#New-NetlbfoTeam PRODVLAN “Ethernet 2”, “Ethernet 5” –verbose
#Get the Status of the Network Adapters
Get-NetAdapter | Sort Name
#Create the new Hyper-V Vswitch VSW02
new-vmswitch "VSW01" -MinimumBandwidthMode Weight -NetAdapterName "NIC TEAM - VLAN 245" -verbose -AllowManagementOS $false
#Check the Bindings
Get-NetadapterBinding | where {$_.DisplayName –like “Hyper-V*”}
#Check the Adapter Settings
Get-NetAdapter | sort name
#Now Create the Converged Adapters
Add-VMNetworkAdapter –ManagementOS –Name “LM” –SwitchName “VSW01” –verbose
#Add-VMNetworkAdapter –ManagementOS –Name “ISCSI” –SwitchName “VSW02” –verbose
Add-VMNetworkAdapter –ManagementOS –Name “CLUSTERCSV” –SwitchName “VSW01” –verbose
Add-VMNetworkAdapter –ManagementOS –Name “MGMT” –SwitchName “VSW01” –verbose
#Review the NIC Configuration Again
Get-NetAdapter | Sort name
#Rename the HOST NIC
#Rename-NetAdapter –Name “VEthernet (VSW01)” –NewName “vEthernet (Host)” –verbose
#Review the NIC Configuration Again
Get-NetAdapter | Sort name
#Set the weighting on the NIC's
Set-VMNetworkAdapter –ManagementOS –Name “CLUSTERCSV” –MinimumBandwidthWeight 10
Set-VMNetworkAdapter –ManagementOS –Name “LM” –MinimumBandwidthWeight 20
#Set-VMNetworkAdapter –ManagementOS –Name “ISCSI” –MinimumBandwidthWeight 10
Set-VMNetworkAdapter –ManagementOS –Name “VSW01” –MinimumBandwidthWeight 70
#Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "ISCSI" -Access -VLanID 10
#Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "LM" -Access -VLanID 1000
#Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "CLUSTERCSV" -Access -VLanID 1000
#SET VLAN for Production
Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "MGMT" -Access -VLanID 245
Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "LM" -Access -VLanID 245
Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "CLUSTERCSV" -Access -VLanID 245
#Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "VSW01" -Access -VLanID 1000 -SecondaryVlanIDList 7

#Stop-transcript
