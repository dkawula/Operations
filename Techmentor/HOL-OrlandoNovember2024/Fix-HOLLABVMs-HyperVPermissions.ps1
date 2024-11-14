# Script to fix Hyper-V VHDx permissions in the event that you need to swap a data DRIVE
# In the case of this lab we needed to expand the C: but the E: was an REFS Partition that was right beside it
# The easier solution was to Simply create a DataDrive in the VM copy all the files to the new drive
# Delete the old Parition Expand the OS Drive and Change the Drive letter back to the E: (On the Data Disk)
# The issue is if you do this you will get an access is denied error message and you won't be able to start VM's
#This Script takes the VMGUID and reassigns the required permissions from Hyper-V to fix this
#Dave Kawula-MVP


# Retrieve all VMs from the specified Hyper-V host
$VMs = Get-VM 

foreach ($VM in $VMs) {
    # Retrieve the VM GUID
    $VMGUID = $VM.VMId.Guid

    # Retrieve the VHDX paths
    $VHDXPathList = $VM | Get-VMHardDiskDrive | Select-Object -ExpandProperty Path

    foreach ($VHDX in $VHDXPathList) {
        # Use icacls to grant access back to the VM after moving VHDX files
        $icaclsCommand = "icacls `"$VHDX`" /grant `"${VMGUID}`:F`""
        Invoke-Expression $icaclsCommand

        # Output result
        Write-Output "Granted full access to $VHDX for VM GUID $VMGUID"
    }
}

Write-Output "Access granted for all VM VHDX files."
