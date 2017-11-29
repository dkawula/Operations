##################################  WARNING  ################################
#                                                                           #
#                   ***    USE AT YOUR OWN RISK    ***                      #
#                    PERMANANT DATA LOSS WILL OCCUR                         #
#                                                                           #
# This script completely clears any existing Storage Spaces configuration   #
# and all data on EVERY non-system drive PERMANENTLY!                      #
#                                                                           #
# Notes:                                                                    #
#                                                                           #
#   If certain drives cannot be cleared and the reason given is             #
#   'Redundant Path' then MPIO may need to be installed and/or configured.  #
#                                                                           #
#   Power cycling the JBOD enclosures can also remove additional            #
#   errors encountered during the run.                                      #
#                                                                           #
#   Run cmdlet with Administrator rights.                                   #
#                                                                           #
##################################  WARNING  ################################

################################# Change Log ################################
#                                                                           #
# 02/13/2014: Changed logic to remove SAS-connected boot/system disks       #
# 02/13/2014: Changed output for clearing disks and tracking runtime        #
# 04/07/2014: Corrected logic to deal boot and system drives                #
# 04/07/2014: Added logic to deal with non-core cluster objects             #
# 07/23/2015: Changes to better support Storage Spaces Direct               #
#                                                                           #
############################################################################# 
#Script has been tested and verified to work to Factory Reset Storage Spaces Direct by Dave Kawula#

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="High")]
param()

if ($PSCmdlet.ShouldProcess("localhost","Clear Storage Spaces configuration and wipe disks"))
{

    Write-Host ""
    Write-Host Clearing existing Storage Spaces configuration and wiping disks...
    Write-Host ""

    $runStart = [DateTime]::Now

    # Install necessary tools if needed
    $toolsInstalled = $false
    if (!(Get-WindowsFeature -Name "RSAT-Clustering-PowerShell").Installed)
    {
        Write-Host Installing required tools... -ForegroundColor Cyan -NoNewline
        Install-WindowsFeature -Name "RSAT-Clustering-PowerShell"
        $toolsInstalled = $true
        Write-Host Done.
        Write-Host ""            
    }

    # Remove any cluster objects if present
    Write-Host "Removing any cluster objects" -NoNewline -ForegroundColor Cyan
    Write-Host "..." -NoNewline

    foreach ($clusterGroup in (Get-ClusterGroup -ErrorAction SilentlyContinue -WarningAction SilentlyContinue))
    {
        if (!$clusterGroup.IsCoreGroup)
        {
            Remove-ClusterGroup -Name $clusterGroup.Name -Force:$true -RemoveResources:$true -ErrorAction SilentlyContinue
        }
    }
    
    Remove-Cluster -Force -CleanupAD -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

    Write-Host "Done." 

    $disks = Get-PhysicalDisk | Where-Object {($_.BusType -EQ "SAS") -or ($_.BusType -EQ "SATA")} # -or ($_.BusType -EQ "RAID")}

    Write-Host ""
    Write-Host "Removing any stale PRs" -NoNewline -ForegroundColor Cyan
    Write-Host "..." -NoNewline
    foreach ($disk in $disks)
    {       
        Clear-ClusterDiskReservation -Disk $disk.DeviceId -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue      
    }
    Write-Host "Done."

    Write-Host ""
    Write-Host "Updating the storage provider cache (x2)" -NoNewline -ForegroundColor Cyan
    Write-Host "..." -NoNewline
    Update-StorageProviderCache -DiscoveryLevel Full
    Start-Sleep 1
    Update-StorageProviderCache -DiscoveryLevel Full
    Write-Host "Done."

    # Remove virtual disks and storage pools
    Write-Host ""
    Write-Host "Removing Virtual Disks and Pools" -NoNewline -ForegroundColor Cyan
    Write-Host "..." -NoNewline
    $storagePools = Get-StoragePool | ? FriendlyName -NE "primordial"
    $storagePools | Set-StoragePool -IsReadOnly:$false
    Get-VirtualDisk | Set-VirtualDisk -IsManualAttach:$false
    Get-VirtualDisk | Remove-VirtualDisk -Confirm:$false
    $storagePools | Remove-StoragePool -Confirm:$false
    Write-Host "Done."
    Write-Host ""

    Write-Host "Updating the storage provider cache (x2)" -NoNewline -ForegroundColor Cyan
    Write-Host "..." -NoNewline
    Update-StorageProviderCache -DiscoveryLevel Full
    Start-Sleep 1
    Update-StorageProviderCache -DiscoveryLevel Full
    Write-Host "Done."
    Write-Host ""

    # Collect IDs of any system/boot disks
    $disks = Get-Disk
    $diskIdsToRemove = @()
    foreach ($disk in $disks)
    {
        if ($disk.IsBoot -or $disk.IsSystem)
        {
            $diskIdsToRemove += $disk.UniqueId
        }
    }

    # Get collection of physical disks
    $allPhysicalDisks = Get-PhysicalDisk | Where-Object {($_.BusType -EQ "SAS") -or ($_.BusType -EQ "SATA")} # -or ($_.BusType -EQ "RAID")}

    # Create a new collection of physical disks without any system/boot disks
    $physicalDisks = @()
    foreach ($physicalDisk in $allPhysicalDisks)
    {
        $addDisk = $true

        foreach ($diskIdToRemove in $diskIdsToRemove)
        {
            if ($physicalDisk.UniqueId -eq $diskIdToRemove)
            {
                $addDisk = $false
            }
        }

        if ($addDisk)
        {
            $physicalDisks += $physicalDisk
        }
    }

    # Iterate through all remaining physcial disks and wipe
    Write-Host "Cleaning disks" -ForegroundColor Cyan -NoNewline
    Write-Host "..."
    $totalDisks = $physicalDisks.Count
    $counter = 1
    foreach ($physicalDisk in $physicalDisks)
    {
        $disk = $physicalDisk | Get-Disk        

        # Make sure disk is Online and not ReadOnly otherwise, display reason
        # and continue
        $disk | Set-Disk –IsOffline:$false -ErrorAction SilentlyContinue
        $disk | Set-Disk –IsReadOnly:$false -ErrorAction SilentlyContinue

        # Re-instantiate disks to update changes
        $disk = $physicalDisk | Get-Disk        

        if ($disk.IsOffline -or $disk.IsReadOnly)
        {
            Write-Host "Warning: " -NoNewline -ForegroundColor Yellow
            Write-Host "Unable to process disk " -NoNewline
            Write-Host $disk.Number -NoNewline
            Write-Host ": Offline Reason: " -NoNewline
            Write-Host ($disk.OfflineReason) -NoNewline -ForegroundColor Yellow
            Write-Host ", HealthStatus: " -NoNewline 
            Write-Host $disk.HealthStatus -ForegroundColor Yellow
        }
        else
        {
            Write-Host "Cleaning disk " -NoNewline
            Write-Host $disk.Number -NoNewline -ForegroundColor Cyan
            Write-Host " (" -NoNewline
            Write-Host $counter -NoNewline -ForegroundColor Cyan
            Write-Host " of " -NoNewline
            Write-Host $totalDisks -NoNewline -ForegroundColor Cyan
            Write-Host ")..." -NoNewline

            # Wipe disk and initialize
            $disk | ? PartitionStyle -NE "RAW" | Clear-Disk -RemoveData -RemoveOEM -Confirm:$false
            $disk | Initialize-Disk -PartitionStyle GPT

            Write-Host Done.
        }

        $counter++
    }

    # Remove any installed roles/tools
    if ($toolsInstalled)
    {
        Write-Host Uninstalling Failover Cluster tool... -NoNewline -ForegroundColor Cyan
        Remove-WindowsFeature -Name "Failover-Clustering","RSAT-Clustering-PowerShell"
        Write-Host Done.
    }

    Write-Host ""
    Write-Host "Updating the storage provider cache (x2)" -NoNewline -ForegroundColor Cyan
    Write-Host "..." -NoNewline
    Update-StorageProviderCache -DiscoveryLevel Full
    Start-Sleep 1
    Update-StorageProviderCache -DiscoveryLevel Full
    Write-Host "Done."

    # Output physical disk counts
    Write-Host ""
    Write-Host Physical Disks:
    Get-PhysicalDisk | Group-Object Manufacturer,Model,MediaType,Size | ft Count,Name -AutoSize

    Write-Host Configuration and data cleared!
    Write-Host ""
    Write-Host "Run duration: " -NoNewline
    Write-Host ([Math]::Round((([DateTime]::Now).Subtract($runStart)).TotalMinutes,2)) -ForegroundColor Yellow -NoNewline
    Write-Host " minutes"
}