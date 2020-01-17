#Draft Script to Migrate an Azure Stack HCI Cluster from one Domain to another.
#Full Details on the blog www.checkyourlogs.net
#Auther Dave Kawula - MVP
#Jan 16, 2020
#Version 1.0


#region 001 - Add another Virtual Adapter and setup the correct IPs for the new Fabric Domain B.
#Run the following on each Node

Add-VMNetworkAdapter -SwitchName VSW02 -Name MGMT02 -ManagementOS

 #endregion

#region 002 - Create Local Admin Account or Reset Local Admin Account Password

# 2.	Create a local Administrator account with the same name and password on all servers in the cluster. This may be needed to log in while the servers are moving between domains.

#endregion
 
#region 003 - Check the status of the Storage Pool, Virtual Disks, Dedup Jobs,  and ensure no Storage Jobs are running

Get-StoragePool
Get-VirtualDisk
Get-StorageJob
Get-Dedupjob

#Note: If a Dedup Job is running – Get-Dedupjob | Stop-DedupJob

#endregion
 
#region 004 - Sign in to the first server with a domain user or administrator account that has Active Directory permissions to the Cluster Name Object (CNO), Virtual Computer Objects (VCO), has access to the Cluster, and open PowerShell.

#Ensure all Cluster Network Name resources are in an Offline state and run the below command. This command will remove the Active Directory objects that the cluster may have.

 

Get-Cluster
Get-Cluster | Remove-ClusterNameAccount -DeleteComputerObjects -Verbose

 

#If you refresh the cluster, you will see the CNO and IP Address have been removed

#endregion

#region 005 - Use Active Directory Users and Computers to ensure the CNO and VCO computer objects associated with all clustered names have been removed.

#Note:  It’s a good idea to stop the cluster service on all the servers in the cluster and set the service startup type to Manual so that the Cluster Service doesn’t start when the servers are restarting while changing domains

#endregion

#region 006 - Take Virtual Disks Offine

#	Take the Virtual Disk Offline

#endregion

#region 007 - Take the Storage Pool Offline

#7.	Take the Storage Pool Offline

#endregion 

#region 008 - Shut Down the Cluster

#8.	Shut Down the Cluster

#endregion

#region 009 - Change the Startup Type of the CLuster Service to Manual

#9.	Change the Startup Type of the Cluster Service to Manual

$Nodes = ‘Server1,’ ‘Server2’
Invoke-Command $Nodes {
Set-Service -Name ClusSvc -StartupType Manual}

 #endregion

#region 010 - Change the nodes membership to workgroup and the to the new domain

#10.	Change the servers' domain membership to a workgroup, restart the servers, join the servers to the new domain, and restart again.

#endregion

#region 011 - Change the Cluster Service to Automatic and Start the Cluster Service

#11.	Once the servers are in the new domain, sign in to a server with a domain user or administrator account that has Active Directory permissions to create objects, has access to the Cluster, and open PowerShell. Start the Cluster Service, and set it back to Automatic.

$Nodes = ‘CAS2D1,’ ‘CAS2D2’
Invoke-Command $Nodes {
Set-Service -Name ClusSvc -StartupType Automatic
Start-Service -Name Clusvc
}

#endregion

#region 012 - Optional Change the IP Address of the Cluster Name


#12.	Open Failover Cluster Manager and change the IP Address of the Cluster Name Object

#endregion

#region 013 - Bring the Cluster Online


#13.	Bring the Cluster Name and all other cluster Network Name resources to an Online state.

Start-ClusterResource -Name "Cluster Name"

#endregion

#region 014 - Create a new Cluster Name Object in the new Domains


# Change the cluster to be a part of the new domain with associated active directory objects. To do this, the command is below, and the network name resources must be in an online state. What this command will do is recreate the name objects in Active Directory.

Stop-ClusterResource -Name “Cluster Name”
New-ClusterNameAccount -Name CAS2DCLU01 -Domain Titan.Local -UpgradeVCOs
Start-ClusterResource -Name “ClusterName”

 

#NOTE: If you do not have any additional groups with network names (i.e. a Hyper-V Cluster with only virtual machines), the -UpgradeVCOs parameter switch is not needed.

#endregion

#region 015 - Check AD Users and Computers for the new Cluster Name Object

#Use Active Directory Users and Computers to check the new domain and ensure the associated computer objects were created. If they have, then bring the remaining resources in the groups online.

#endregion

#region 016 - Start the Storage Pool

#16.	 Start the Storage Pool

#endregion

#region 017 - Start the Virtual Disks
 

#17.	Start the Virtual Disks

#endregion

#region 018 - Validate the Azure Stack HCI S2D Storage

 

#18.	 Validate the Storage for Azure Stack HCI (S2D)

Get-StoragePool
Get-VirtualDisk
Get-StorageJob
Get-Dedupjob

 #endregion

#region 019 - Validate that the CSV Volumes are back online
#19.	 Validate that the Volumes are back online

 #endregion

#region 020 - Validate that the Virtual Machines can Start

# Validate that the Virtual Machines can Start

#endregion

 

