#Expand an existing 3-way mirror volume in S2D
#Dave Kawula - MVP @DaveKawula
#10/10/2023

#Check the health of the cluster Virtual Disks
Get-VirtualDisk #Note the Virtual Disk you want to expand ie. CSV05

#Check the health of the cluster Physical Disks

Get-PhysicalDisk

#Count the disks

Get-PhysicalDisk | Measure #Count is almost always N-1

#Double check to see if there are any faults in the cluster

Get-HealthFault -verbose

#Expand the Virtual Disk

#Get a list of the virtual disks by running the following command:
Get-VirtualDisk
#Use the list to find the name of the virtual disk that must be expanded with command: 
Get-VirtualDisk CSV05 | Resize-VirtualDisk -Size 3TB
#Expand the volumes by running the following three commands:
$VirtualDisk = Get-VirtualDisk CSV05
$Partition = $VirtualDisk | Get-Disk | Get-Partition | Where PartitionNumber -Eq 2
$Partition | Resize-Partition -Size ($Partition | Get-PartitionSupportedSize).SizeMax
#Run the following command and verify that the volume has expanded:
Get-Volume
Get-VirtualDisk