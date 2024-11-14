# Define variables for the Azure resource parameters
# PowerShell Script to Build the Student VM's for the HOL
# This script configures 50 Student VM's from the TechmentorOrlando2024-HOL VMImage
# It also creates 1 central NSG so that we can open up access easily to each of the student VM's
# It creates a Public Static IP for the LAB VM's for external Access
# Created by Dave Kawula - MVP
$resourceGroup = "TMHOLMIGSRV2025"
$location = "Canada Central" 
$imageId = "/subscriptions/<InsertSUB>/resourceGroups/<ResourceGroup>/providers/Microsoft.Compute/galleries/HoLGallery/images/TechmentorOrlando2024-HOL3/versions/2.0.0"
$sku = "Standard_D8s_v3" 
$vmPrefix = "Student"
$vnetName = "TMLABVNET04"
$subnetName = "default"

# Login to Azure if required
Connect-AzAccount -devicecode

# Create a resource group if it doesn’t already exist
if (-not (Get-AzResourceGroup -Name $resourceGroup -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup -Name $resourceGroup -Location $location
}

# Retrieve the existing VNet and Subnet
$vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $resourceGroup
$subnet = $vnet | Select-Object -ExpandProperty Subnets | Where-Object {$_.Name -eq $subnetName}

# Define a single NSG for all VMs and create it if it doesn't exist
$nsgName = "StudentVM-NSG"
if (-not (Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $resourceGroup -ErrorAction SilentlyContinue)) {
    $nsgRuleRDP = New-AzNetworkSecurityRuleConfig -Name myNetworkSecurityGroupRuleRDP -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Deny
    $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name $nsgName -SecurityRules $nsgRuleRDP
} else {
    $nsg = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $resourceGroup
}

$cred = Get-Credential

# Loop to create 50 VMs with unique names
for ($i = 1; $i -le 60; $i++) {
    # Format the VM name as StudentXX (e.g., Student01, Student02)
    $vmName = "{0}{1:D2}" -f $vmPrefix, $i

    # Check if the VM already exists
    if (Get-AzVM -ResourceGroupName $resourceGroup -Name $vmName -ErrorAction SilentlyContinue) {
        Write-Output "VM $vmName already exists. Skipping creation."
        continue
    }

    Write-Output "Creating VM $vmName..."

    # Create a Public IP Address for the VM
    $pip = New-AzPublicIpAddress -ResourceGroupName $resourceGroup -Location $location -Name "$vmName-Public-IP" -AllocationMethod Static -IdleTimeoutInMinutes 4

    # Create a Network Interface for the VM using the single NSG
    $nic = New-AzNetworkInterface -Name "$vmName-nic" -ResourceGroupName $resourceGroup -Location $location -SubnetId $subnet.Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id

    # Configure the VM using the gallery image
    $vmConfig = New-AzVMConfig -VMName $vmName -VMSize $sku |
        Set-AzVMSourceImage -Id $imageId |
        Add-AzVMNetworkInterface -Id $nic.Id
        Set-AzVMOperatingSystem -VM $VMname -Windows -ComputerName $VMname -Credential $cred

    # Create the VM
    $vm = New-AzVM -ResourceGroupName $resourceGroup -Location $location -VM $vmConfig -Verbose

   }
