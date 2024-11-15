# Set your subscription context if needed
# Login to Azure if required
Connect-AzAccount -devicecode

# Define resource group name and performance tier
$resourceGroupName = 'TMHOLMIGSRV2025'
$performanceTier = 'P30'

# Get all VMs that start with "Student" in their name
$VMs = Get-AzVM -ResourceGroupName $resourceGroupName | Where-Object { $_.Name -like "Student*" }
$VMs

# Define the batch size
$batchSize = 10
$jobs = @()

# Loop through the VMs in batches
for ($i = 0; $i -lt $VMs.Count; $i += $batchSize) {
    # Get the current batch
    $batch = $VMs[$i..[Math]::Min($i + $batchSize - 1, $VMs.Count - 1)]

    # Start a job for each VM in the current batch
    foreach ($vm in $batch) {
        $jobs += Start-Job -ArgumentList $vm, $resourceGroupName, $performanceTier -ScriptBlock {
            param ($vm, $resourceGroupName, $performanceTier)
            
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
    }

    # Wait for the current batch of jobs to complete
    $jobs | ForEach-Object { $_ | Wait-Job | Out-Null }

    # Clean up completed jobs
    $jobs | ForEach-Object { Remove-Job -Job $_ }
    $jobs.Clear()
}

Write-Output "Script execution completed."


Write-Output "Script execution completed."
