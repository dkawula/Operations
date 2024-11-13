#Needed to update the VM's to P30 to perform for the HoL Experience at Techmentor
#This Script will change the OS Disks on the Student VM's to P30 - 5000 IOPS, 200 MB/s
#by Dave Kawula-MVP

# Set your subscription context if needed
# Login to Azure if required
Connect-AzAccount -devicecode

# Define resource group name and performance tier
$resourceGroupName = 'TMHOLMIGSRV2025'
$performanceTier = 'P30'

# Get all VMs that start with "Student" in their name
$VMs = Get-AzVM -ResourceGroupName $resourceGroupName | Where-Object { $_.Name -like "Student*" }
$VMs

foreach ($vm in $VMs) {
    # Retrieve the OS disk name for the current VM
    $diskName = $vm.StorageProfile.OsDisk.Name
    $diskname
    
    # Configure the disk update with the desired performance tier
    $diskUpdateConfig = New-AzDiskUpdateConfig -Tier $performanceTier
    
    # Update the disk with the new tier
    Write-Output "Updating OS disk tier to $performanceTier for VM: $($vm.Name)..."
    Update-AzDisk -ResourceGroupName $resourceGroupName -DiskName $diskName -DiskUpdate $diskUpdateConfig
}

Write-Output "Script execution completed."

