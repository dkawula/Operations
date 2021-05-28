#PowerShell Script to Disable Internet Adapters 
#You need to know the name of the Adapter - In the example vEthernet (MGMT)

#Make an Array of Servers

$FabricServers = "Kender-S2D1","Server2","Server3"

#Test the Array

$FabricServers

#Get the Netadapter and Enable them when ready for patching

#Get-NetAdapter -Name "Ethernet 13" | Enable-NetAdapter -Verbose

#Get the Netadapter and Disable it when done patching

Get-NetAdapter -Name "Ethernet 13" | Disable-NetAdapter -Verbose -confirm:$false

#Get the Netadapter and cycle it restart

#Get-NetAdapter -Name "Ethernet 13" | Restart-NetAdapter -Verbose