#region Factory Reset the Networking Configuraitons on all nodes

$Nodes = ('S2D1','S2D2')
#Invoke-Command $Nodes {C:\post-install\Clear-SdsConfig.ps1 -confirm:$False}
#Enter-PSSession -ComputerName S2D2

Invoke-Command $Nodes {
#DO NOT RUN THIS COMMAND IN PROD!!!
Get-VMNetworkAdapter -ManagementOS | Where-Object {$_.Name -ne 'Production'} | Remove-VMNetworkAdapter -confirm:$False
Get-VmSwitch | Where-Object {$_.Name -ne 'Embedded_vSwitch_Team_Production'} | Remove-Vmswitch -Confirm:$False
Get-NetQosPolicy | Remove-NetQosPolicy -confirm:$Falase
Get-NetQosTrafficClass | Remove-NetQosTrafficClass
#Clear-ClusterNode




}

#Invoke-command $Nodes {Clear-ClusterNode}

Invoke-command $Nodes {Get-PhysicalDisk | ft}

Invoke-command $Nodes {Get-StorageSubSystem | ft}

#endregion