#To execute this script, you'll need to download and install Sophos XG Firewall Home Edition from the official website (https://www.sophos.com/en-us/products/free-tools/sophos-xg-firewall-home-edition.aspx).

#Here's the script:

# Configure the variables
$vmName = "Sophos XG Firewall"
$vmPath = "C:\VMs"
$internalSwitch = "Internal"
$externalSwitch = "External"
$internalIP = "192.168.1.254"
$externalIP = "172.16.16.254"
$isoPath = "C:\ISOs\SophosXGHome_English.iso"
$adminPassword = "Pa$$w0rd"

# Create the virtual machine
New-VM -Name $vmName -Path $vmPath -MemoryStartupBytes 2GB -Generation 2 -SwitchName $internalSwitch, $externalSwitch

# Set the DVD drive to use the Sophos XG Firewall ISO
Set-VMDvdDrive -VMName $vmName -Path $isoPath

# Set the network adapters to private and configure the IP addresses
Get-VMNetworkAdapter -VMName $vmName | ForEach-Object {
    if ($_.SwitchName -eq $internalSwitch) {
        Set-VMNetworkAdapter -VMName $vmName -Name $_.Name -MacAddressSpoofing On -StaticMacAddress $_.MacAddress -DeviceNaming On -IPAddresses $internalIP -SubnetMasks 255.255.255.0
    }
    else {
        Set-VMNetworkAdapter -VMName $vmName -Name $_.Name -MacAddressSpoofing On -StaticMacAddress $_.MacAddress -DeviceNaming On -IPAddresses $externalIP -SubnetMasks 255.255.255.0
    }
}

# Start the virtual machine
Start-VM -Name $vmName

# Wait for the virtual machine to start
Start-Sleep -Seconds 30

# Connect to the virtual machine using PowerShell Direct
$cred = Get-Credential -UserName "admin" -Message "Enter the Sophos XG Firewall admin credentials"
Enter-PSSession -VMName $vmName -Credential $cred -Authentication CredSSP

# Allow all traffic out to the internet
Invoke-SSHCommand -Command "configure system interface edit \"ethernet-1\" set ipv4-address dhcp" -Confirm:$false
Invoke-SSHCommand -Command "configure firewall policy edit 0 set status enable" -Confirm:$false
Invoke-SSHCommand -Command "commit" -Confirm:$false

# Add the network objects
Invoke-SSHCommand -Command "configure network dhcp-server create \"Server 1\" ip 192.168.1.1" -Confirm:$false
Invoke-SSHCommand -Command "configure network dhcp-server create \"Server 2\" ip 192.168.1.2" -Confirm:$false
Invoke-SSHCommand -Command "configure network dhcp-server create \"Server 3\" ip 192.168.1.3/24" -Confirm:$false

# Create a new NAT and firewall rule to restrict internet traffic for the servers
Invoke-SSHCommand -Command "configure firewall policy create \"Microsoft Services\" type static" -Confirm:$false
Invoke-SSHCommand -Command "configure firewall policy rule 1 set policy Microsoft Services" -Confirm:$false
Invoke-SSHCommand -Command "configure firewall policy rule 1 set service HTTP HTTPS DNS" -Confirm:$false
Invoke-SSHCommand -Command "configure firewall policy rule 1 set action ACCEPT" -Confirm:$false
Invoke-SSHCommand -Command "configure firewall policy rule 1 set source zone lan" -Confirm:$false
Invoke-SSHCommand -Command "configure firewall policy rule 1 set destination zone wan" -Confirm:$false
Invoke-SSHCommand -Command "configure firewall policy rule 1 set source address "Server 1" "Server 2" "Server 3"" -Confirm:$false
Invoke-SSHCommand -Command "configure firewall policy rule 1 set destination address any" -Confirm:$false
Invoke-SSHCommand -Command "configure firewall policy rule 2 create "Block All Other Traffic" type static" -Confirm:$false
Invoke-SSHCommand -Command "configure firewall policy rule 2 set service any" -Confirm:$false
Invoke-SSHCommand -Command "configure firewall policy rule 2 set action DROP" -Confirm:$false
Invoke-SSHCommand -Command "configure firewall policy rule 2 set source zone lan" -Confirm:$false
Invoke-SSHCommand -Command "configure firewall policy rule 2 set destination zone wan" -Confirm:$false
Invoke-SSHCommand -Command "commit" -Confirm:$false

Disconnect from the virtual machine
Exit-PSSession

<#>

This script downloads Sophos XG Firewall Home Edition, creates a Hyper-V VM using PowerShell Direct, sets up two private network adapters, configures the IP addresses, and starts the virtual machine. It then connects to the virtual machine using PowerShell Direct and SSH, performs the initial configuration to allow all traffic out to the internet, adds the required network objects, and creates a new NAT and firewall rule to restrict internet traffic for the servers.

Note that you'll need to modify the script to match your environment's network settings, ISO path, and admin password. Also, make sure that you have enabled PowerShell Direct on both the host and guest operating systems, and that the firewall allows the necessary ports to establish a PowerShell Direct session.

Finally, ensure that the script is executed with an account that has the necessary permissions
</#>