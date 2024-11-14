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
    $osDiskName = $vm.StorageProfile.OsDisk.Name
    Write-Output "Updating OS disk tier to $performanceTier for VM: $($vm.Name)..."
    
    # Configure the OS disk update with the desired performance tier
    $osDiskUpdateConfig = New-AzDiskUpdateConfig -Tier $performanceTier
    Update-AzDisk -ResourceGroupName $resourceGroupName -DiskName $osDiskName -DiskUpdate $osDiskUpdateConfig

    # Retrieve and update each data disk for the current VM
    foreach ($dataDisk in $vm.StorageProfile.DataDisks) {
        $dataDiskName = $dataDisk.Name
        Write-Output "Updating data disk tier to $performanceTier for VM: $($vm.Name), Disk: $dataDiskName..."
        
        # Configure the data disk update with the desired performance tier
        $dataDiskUpdateConfig = New-AzDiskUpdateConfig -Tier $performanceTier
        Update-AzDisk -ResourceGroupName $resourceGroupName -DiskName $dataDiskName -DiskUpdate $dataDiskUpdateConfig
    }
}

Write-Output "Script execution completed."
