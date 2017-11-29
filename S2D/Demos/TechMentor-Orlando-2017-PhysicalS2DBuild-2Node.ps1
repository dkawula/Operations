#region  TechMentor Physical Lab Notes
#Before Continuing Install Mellanox CX3 or CX4 Cards
#Download WinOF Drivers --> WinOF for CX3 and WINOF2 for CX4
#Watch the Firmware versions as some have issues
#Download MST
#Download Firmware
#Run MST Status and FLINT to update the Firmware
#Reboot the Nodes / Can do without Rebooting but I always Reboot
#Create an OU for the Cluster Objects and S2D Nodes / Setup to Block Inheritance
#endregion

#region 001 - Update the Mellanox Firmware on the RDMA (RoCE) Adpaters if required

#Show mellanox Firmware

#Check the make of Mellanox Card / Device ID

#storagespacesdirect #s2d

mst status

#Check the Firmware Revision
flint -d /dev/mst/mt4117_pciconf0 q

#update the firmware
#flint -d /dev/mst/mt4117_pciconf0 i C:\Post-install\fw-ConnectX4Lx-rel-14_18_2000-MCX4121A-ACA_Ax-FlexBoot-3.5.110.bin\fw-ConnectX4Lx-rel-14_18_2000-MCX4121A-ACA_Ax-FlexBoot-3.5.110.bin burn

#endregion

#region 002 - Install the Core Roles Required for Storage Spaces Direct
$nodes = ("S2D2", "S2D3", "S2D4")

Invoke-Command $nodes {Install-WindowsFeature Data-Center-Bridging} 

Invoke-Command $nodes {Install-WindowsFeature File-Services} 

Invoke-Command $nodes {Install-WindowsFeature Failover-Clustering -IncludeAllSubFeature -IncludeManagementTools} 

Invoke-Command $nodes {Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart} 



$nodes = ("S2D1")

Invoke-Command $nodes {Install-WindowsFeature Data-Center-Bridging} 

Invoke-Command $nodes {Install-WindowsFeature File-Services} 

Invoke-Command $nodes {Install-WindowsFeature Failover-Clustering -IncludeAllSubFeature -IncludeManagementTools} 

Invoke-Command $nodes {Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart} 

#endregion

#region 003 - Tweak Physical Adapters and configure for Jumbo Packets and Disable Flow Control

$nodes = ("S2D1", "S2D2")
$nodes
#Validate that the required Features / Roles have been installed
Invoke-Command $nodes {Get-WindowsFeature | where-object {$_.Installed -match "True"} | Select-Object -Property Name} 

#Enable Jumbo Frames on the Mellanox Adapters
Invoke-Command $nodes {Get-NetAdapter  | ? InterfaceDescription -Match "Mellanox*" | Sort-Object number |% {$_ | Set-NetAdapterAdvancedProperty -RegistryKeyword "*JumboPacket" -RegistryValue 9000}} 

#Disable FLow Control on the Physical Adapters
#This is because Priorty Flow Control and Flow Control cannot exist on the same adapters

Invoke-Command $Nodes {Set-NetAdapterAdvancedProperty -Name "Ethernet 5" -RegistryKeyword "*FlowControl" -RegistryValue 0}

Invoke-Command $Nodes {Set-NetAdapterAdvancedProperty -Name "Ethernet 6" -RegistryKeyword "*FlowControl" -RegistryValue 0}

#endregion


#region 004 - Configure Data Center Bridging, NetQoS Policies, and Enable the Policies on the Physical Mellanox Adapters

#Create new Net Adapter QoS Policy
Invoke-Command $nodes {New-NetQosPolicy SMB -NetDirectPortMatchCondition 445 -PriorityValue8021Action 3 -Verbose} 

Invoke-Command $nodes {Enable-NetQosFlowControl -Priority 3 -Verbose} 

Invoke-Command $nodes {Disable-NetQosFlowControl -Priority 0,1,2,4,5,6,7 -Verbose} 

Invoke-Command $nodes {Get-NetAdapter | ? InterfaceDescription -Match "Mellanox" | Enable-NetAdapterQos -Verbose} 

Invoke-Command $nodes {New-NetQosTrafficClass "SMB" -Priority 3 -BandwidthPercentage 99 -Algorithm ETS -Verbose} 

Invoke-Command $nodes {Enable-NetAdapterQos -Name "Ethernet 5","Ethernet 6" -Verbose}

#endregion

#region 005 - Configure the Hyper-V SET (Switch Embedded Teaming) which supports RDMA over Teamed Connections, also create all the Virtual Adapters....

#Create Hyper-V Virtual SET Switch

Invoke-Command $Nodes {Get-Netadapter | FT Name, InterfaceDescription,Status,LinkSpeed}

Invoke-Command $Nodes {New-VmSwitch -Name VSW01 -NetAdapterName "Ethernet 5","Ethernet 6" -EnableEmbeddedTeaming $True -AllowManagementOS $False -verbose }


#Create the Virtual Adapters --> Open ncpa.cpl to see them being created
Invoke-Command $Nodes {

Add-VMNetworkAdapter -SwitchName VSW01 -Name SMB_1 -ManagementOS

Add-VMNetworkAdapter -SwitchName VSW01 -Name SMB_2 -ManagementOS

Add-VMNetworkAdapter -SwitchName VSW01 -Name LM -ManagementOS

Add-VMNetworkAdapter -SwitchName VSW01 -Name HB -ManagementOS

Add-VMNetworkAdapter -SwitchName VSW01 -Name MGMT -ManagementOS}

#endregion

#region 006 - Configure the VLANs for the LAB
#All of the configurations were done here per the Mellanox Guide
#Assign the VLANs to the Virtual Adapters
Invoke-Command $Nodes {

$Nic = Get-VMNetworkAdapter -Name SMB_1 -ManagementOS

Set-VMNetworkAdapterVlan -VMNetworkAdapter $Nic -VlanId 619 -Access

$Nic = Get-VMNetworkAdapter -Name SMB_2 -ManagementOS

Set-VMNetworkAdapterVlan -VMNetworkAdapter $nic -VlanId 619 -Access

$Nic = Get-VMNetworkAdapter -Name LM -ManagementOS

Set-VMNetworkAdapterVlan -VMNetworkAdapter $nic -VlanId 618 -Access

$Nic = Get-VMNetworkAdapter -Name HB -ManagementOS

Set-VMNetworkAdapterVlan -VMNetworkAdapter $nic -VlanId 617 -Access

$Nic = Get-VMNetworkAdapter -Name MGMT -ManagementOS

Set-VMNetworkAdapterVlan -VMNetworkAdapter $nic -VlanId 616 -Access



}

#Show the VLAN Configuraiton

Invoke-Command $Nodes {Get-VMNetworkAdapterVlan -ManagementOS} 

#endregion

#region 007 - Create Affinity between the vNic and a pNic ensures that traffic from a given vNic on a host (storage vNic) uses a  ...
#particular pNic to send traffic so that it passes through shorter path

Invoke-Command $Nodes {Get-NetAdapter -Name "Ethernet 5" | ? {Set-VMNetworkAdapterTeamMapping -VMNetworkAdapterName 'SMB_1' -ManagementOS -PhysicalNetAdapterName $_.Name}}
Invoke-Command $Nodes {Get-NetAdapter -Name "Ethernet 6" | ? {Set-VMNetworkAdapterTeamMapping -VMNetworkAdapterName 'SMB_2' -ManagementOS -PhysicalNetAdapterName $_.Name}}

#endregion

#region 008 - Check the Configuration view prior to RDMA being Enabled

#show the VM Network Adapters Created
Invoke-Command $Nodes {Get-VMNetworkAdapter -ManagementOS | ft}

#Check for RDMA Connections

$scriptblock = {Netstat -xan}

Invoke-Command $nodes -ScriptBlock $scriptblock


#Show NetAdapter RDMA Before
Invoke-Command $Nodes {
Get-NetAdapterRdma
}

#endregion

#region 009 - Enable RDMA on the Virtual Adapters created in Step 005 and re-verify ...


#Enable NetAdapter RDMA
Invoke-Command $nodes {

Get-NetAdapter *smb* | Enable-NetAdapterRdma -verbose

Get-NetAdapterRdma
}



#Check for RDMA Connections

$scriptblock = {Netstat -xan}

Invoke-Command $nodes -ScriptBlock $scriptblock

Invoke-Command $Nodes {Get-Counter -Counter "\RDMA Activity(*)\RDMA Active Connections"} | fl
Invoke-Command $Nodes {Get-Counter -Counter "\RDMA Activity(*)\RDMA Accepted Connections"} |fl

#endregion

#region 010 - Validate the VLANs configuration...


#Validate VLANS

Invoke-Command $Nodes {

Get-Host

Get-VmNetworkAdapterVlan -ManagementOS | Select ParentAdapter,AccessVLANID | FT

}

#Restart Virtual Adapters to engage VLANS

Invoke-Command $Nodes {

Restart-NetAdapter "vEthernet (SMB_1)"

Restart-NetAdapter "vEthernet (SMB_2)"

Restart-NetAdapter "vEthernet (LM)"

Restart-NetAdapter "vEthernet (HB)"

Restart-NetAdapter "vEthernet (MGMT)"

}

#endregion

#region 011 - Configure the IP Addresses for the Virtual Adapters and Networks in the Lab

####Check the IP Configuraiton of the Nodes
Invoke-Command $Nodes {

Get-Host

Get-SmbClientNetworkInterface | ft

}



#Configure the IP Addresses on the Nodes

#Configure everything from Node 1

New-NetIPAddress -IPAddress 10.10.19.1 -PrefixLength 24 -InterfaceAlias "vEthernet (SMB_1)"

New-NetIPAddress -IPAddress 10.10.19.10 -PrefixLength 24 -InterfaceAlias "vEthernet (SMB_2)"

New-NetIPAddress -IPAddress 10.10.18.1 -PrefixLength 24 -InterfaceAlias "vEthernet (LM)"

New-NetIPAddress -IPAddress 10.10.17.1 -PrefixLength 24 -InterfaceAlias "vEthernet (HB)"

New-NetIPAddress -IPAddress 10.10.16.1 -PrefixLength 24 -InterfaceAlias "vEthernet (MGMT)"

Invoke-Command -ComputerName S2D2 -ScriptBlock {

New-NetIPAddress -IPAddress 10.10.19.2 -PrefixLength 24 -InterfaceAlias "vEthernet (SMB_1)"

New-NetIPAddress -IPAddress 10.10.19.20 -PrefixLength 24 -InterfaceAlias "vEthernet (SMB_2)"

New-NetIPAddress -IPAddress 10.10.18.2 -PrefixLength 24 -InterfaceAlias "vEthernet (LM)"

New-NetIPAddress -IPAddress 10.10.17.2 -PrefixLength 24 -InterfaceAlias "vEthernet (HB)"

New-NetIPAddress -IPAddress 10.10.16.2 -PrefixLength 24 -InterfaceAlias "vEthernet (MGMT)"

}

<#>
Invoke-Command -ComputerName S2D3 -ScriptBlock {

New-NetIPAddress -IPAddress 10.10.19.3 -PrefixLength 24 -InterfaceAlias "vEthernet (SMB_1)"

New-NetIPAddress -IPAddress 10.10.19.30 -PrefixLength 24 -InterfaceAlias "vEthernet (SMB_2)"

New-NetIPAddress -IPAddress 10.10.18.3 -PrefixLength 24 -InterfaceAlias "vEthernet (LM)"

New-NetIPAddress -IPAddress 10.10.17.3 -PrefixLength 24 -InterfaceAlias "vEthernet (HB)"

New-NetIPAddress -IPAddress 10.10.16.3 -PrefixLength 24 -InterfaceAlias "vEthernet (MGMT)"

}

Invoke-Command -ComputerName S2D4 -ScriptBlock {

New-NetIPAddress -IPAddress 10.10.19.4 -PrefixLength 24 -InterfaceAlias "vEthernet (SMB_1)"

New-NetIPAddress -IPAddress 10.10.19.40 -PrefixLength 24 -InterfaceAlias "vEthernet (SMB_2)"

New-NetIPAddress -IPAddress 10.10.18.4 -PrefixLength 24 -InterfaceAlias "vEthernet (LM)"

New-NetIPAddress -IPAddress 10.10.17.4 -PrefixLength 24 -InterfaceAlias "vEthernet (HB)"

New-NetIPAddress -IPAddress 10.10.16.4 -PrefixLength 24 -InterfaceAlias "vEthernet (MGMT)"

}

</#>


#Check for Connectivity in the Lab  #This ensures the VLAN's have been setup properly

Test-NetConnection 10.10.16.2
Test-NetConnection 10.10.17.2
Test-NetConnection 10.10.18.2
Test-NetConnection 10.10.19.2

#endregion

#region 012 - Configure Active Memory Dumps from Full on all Nodes

#Configure the Active Memory Dummp from Full Memory Dump on all Nodes
Invoke-Command $Nodes {
Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl -Name CrashDumpEnabled -Value 1
Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl -Name FilterPages -Value 1
Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl -Name CrashDumpEnabled
Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl -Name FilterPages
}

#endregion

#region 013 - Join S2D Nodes to the Domain

<#>#Run this command from one of the nodes After S2D1 has been joined if not on a MGMT Server

$nodes = ("S2D2", "S2D3", "S2D4")

Invoke-Command $Nodes {

Add-Computer -DomainName Checkyourlogs.net -Reboot

}

</#>

#endregion

#region 014 - Configure the Cluster and double check the Storage SubSystems and Physical Disks
#DO NOT PROCEED if the disks = CANPOOL = False
#RUN the clear-sdsconfig.ps1 first otherwise you demos won't work Dave

#Viewing the Storage SubSystem
Invoke-Command $Nodes {Get-StorageSubSystem | ft}

#Viewing the PhysicalDisks --> Ensure CanPool=True
Invoke-Command $Nodes {Get-PhysicalDisk | ft}

#I just Test on one Node to save time in the demo.
#test-cluster -Node $nodes -Include "Storage Spaces Direct","System Configuration","Network","Inventory","Hyper-V Configuration"
test-cluster -Node S2D1 -Include "Storage Spaces Direct","System Configuration","Network","Inventory","Hyper-V Configuration"

$nodes = 's2d1','s2d2'
icm $nodes {clear-clusternode -Confirm:$False}
#Create a new Cluster #Review Failover Cluster Manager
New-Cluster -Name S2DCluster -Node $Nodes -NoStorage -StaticAddress 192.168.1.166/24 -Verbose
Test-NetConnection 192.168.1.166
Test-NetConnection s2dcluster

#Configure File Share Witness for Quorum
Set-ClusterQuorum -FileShareWitness \\dc01\FSW$

#You could also configure this as a cloud Witness if you wish

#endregion

#region 015 - Optional Configure Fault Domains https://technet.microsoft.com/en-us/library/mt703153.aspx

#just some examples for Rack/Chassis fault domains.

$numberofnodes = 2

$ServersNamePrefix = 'S2D'

if ($numberofnodes -eq 2){

$xml =  @"

<Topology>

    <Site Name="SEA" Location="CheckyourLogs HQ, 123 Example St, Room 4010, Seattle">

        <Rack Name="Rack01" Location="Checkyourlogs HQ, Room 4010, Aisle A, Rack 01">

                <Node Name="$($ServersNamePrefix)1"/>

                <Node Name="$($ServersNamePrefix)2"/>

        </Rack>

    </Site>

</Topology>

"@



Set-ClusterFaultDomainXML -XML $xml 
Get-ClusterFaultDomain

}

if ($numberofnodes -eq 4){

$xml =  @"

<Topology>

    <Site Name="SEA" Location="Checkyourlogs HQ, 123 Example St, Room 4010, Seattle">

        <Rack Name="Rack01" Location="Checkyourlogs HQ, Room 4010, Aisle A, Rack 01">

                <Node Name="$($ServersNamePrefix)1"/>

                <Node Name="$($ServersNamePrefix)2"/>

                <Node Name="$($ServersNamePrefix)3"/>

                <Node Name="$($ServersNamePrefix)4"/>

        </Rack>

    </Site>

</Topology>

"@



Set-ClusterFaultDomainXML -XML $xml -CimSession $ClusterName

}



if ($numberofnodes -eq 8){

$xml =  @"

<Topology>

    <Site Name="SEA" Location="Checkyourlogs HQ, 123 Example St, Room 4010, Seattle">

        <Rack Name="Rack01" Location="Checkyourlogs HQ, Room 4010, Aisle A, Rack 01">

            <Node Name="$($ServersNamePrefix)1"/>

            <Node Name="$($ServersNamePrefix)2"/>

        </Rack>

        <Rack Name="Rack02" Location="Checkyourlogs HQ, Room 4010, Aisle A, Rack 02">

            <Node Name="$($ServersNamePrefix)3"/>

            <Node Name="$($ServersNamePrefix)4"/>

        </Rack>

        <Rack Name="Rack03" Location="Checkyourlogs HQ, Room 4010, Aisle A, Rack 03">

            <Node Name="$($ServersNamePrefix)5"/>

            <Node Name="$($ServersNamePrefix)6"/>

        </Rack>

        <Rack Name="Rack04" Location="Checkyourlogs HQ, Room 4010, Aisle A, Rack 04">

            <Node Name="$($ServersNamePrefix)7"/>

            <Node Name="$($ServersNamePrefix)8"/>

        </Rack>

    </Site>

</Topology>

"@



Set-ClusterFaultDomainXML -XML $xml -CimSession $ClusterName

    

}





if ($numberofnodes -eq 16){

$xml =  @"

<Topology>

    <Site Name="SEA" Location="Checkyourlogs HQ, 123 Example St, Room 4010, Seattle">

        <Rack Name="Rack01" Location="Checkyourlogs HQ, Room 4010, Aisle A, Rack 01">

            <Chassis Name="Chassis01" Location="Rack Unit 1 (Upper)" >

                <Node Name="$($ServersNamePrefix)1"/>

                <Node Name="$($ServersNamePrefix)2"/>

                <Node Name="$($ServersNamePrefix)3"/>

                <Node Name="$($ServersNamePrefix)4"/>

            </Chassis>

            <Chassis Name="Chassis02" Location="Rack Unit 1 (Upper)" >

                <Node Name="$($ServersNamePrefix)5"/>

                <Node Name="$($ServersNamePrefix)6"/>

                <Node Name="$($ServersNamePrefix)7"/>

                <Node Name="$($ServersNamePrefix)8"/>

            </Chassis>

            <Chassis Name="Chassis03" Location="Rack Unit 1 (Lower)" >

                <Node Name="$($ServersNamePrefix)9"/>

                <Node Name="$($ServersNamePrefix)10"/>

                <Node Name="$($ServersNamePrefix)11"/>

                <Node Name="$($ServersNamePrefix)12"/>

            </Chassis>

            <Chassis Name="Chassis04" Location="Rack Unit 1 (Lower)" >

                <Node Name="$($ServersNamePrefix)13"/>

                <Node Name="$($ServersNamePrefix)14"/>

                <Node Name="$($ServersNamePrefix)15"/>

                <Node Name="$($ServersNamePrefix)16"/>

            </Chassis>

        </Rack>

    </Site>

</Topology>

"@



Set-ClusterFaultDomainXML -XML $xml -CimSession $ClusterName



}



    #show fault domain configuration

        Get-ClusterFaultDomainxml -CimSession $ClusterName



#endregion

#region 016 - Configure Storage Spaces Direct (S2D) and create vDisks



    #Enable-ClusterS2D

    #Enable Storage Spaces Direct We enable without Cache becuase all disks are SSD's there isn't a tier

    #Maybe take a break here this can take a few minutes --> Go grab coffee back in 5 min

    ##If you want to get S2D to work on older non-supported hardware you can unlock the Unsuppored RAID Controlled 
    ## By running the following
    #(get-cluster).S2DBusTypes=”0x100″   #Configured for support for RAID Controllers
    #(Get-Cluster).S2DBusTypes=4294967295 #Configured for support for ALL Controllers

    #You can view the configuraiton The Default Value is 0 which set it up for only support BUS Types
    #This is great if you don't have a Pass Through HBA and only have RAID Controllers on your test machines.
    #Now remember the above is only for the labs and is not supported in Production by Microsoft
    #(Get-Cluster).S2DBusTypes

    ##

    Enable-ClusterS2D -PoolFriendlyName S2DPool -CacheState Disabled -Verbose -Confirm:0

    ##HUGE NOTE --> IF YOU ARE CONFIGURING AN ALL FLASH ARRAY AND USE -CacheState Disabled
    ## YOU CANNOT ENABLE it later without starting over
    ## IE... You cannot add NVME Drives later as a Caching / Journal Tier


    #Create a New Volume
    New-Volume -StoragePoolFriendlyName S2DPool -FriendlyName BigDemo -FileSystem CSVFS_ReFS -Size 200GB -PhysicalDiskRedundancy 1
    New-Volume -StoragePoolFriendlyName S2DPool -FriendlyName BigDemo_SR -FileSystem CSVFS_ReFS -Size 200GB -PhysicalDiskRedundancy 1

#endregion

#region 017 - Validate RDMA Connectivity after S2D is running

    $scriptblock = {Netstat -xan}

    Invoke-Command $nodes -ScriptBlock $scriptblock

    Invoke-Command $Nodes {Get-Counter -Counter "\RDMA Activity(*)\RDMA Active Connections"} | fl
    Invoke-Command $Nodes {Get-Counter -Counter "\RDMA Activity(*)\RDMA Accepted Connections"} |fl


#endregion

#region 018 - Optional Create some more Virtual Disks / Volumes
    
    
    $NumberofDisks = 3

        if ($numberofnodes -le 3){

            1..$NumberOfDisks | ForEach-Object {

                New-Volume -StoragePoolFriendlyName "S2DPool" -FriendlyName MirrorDisk$_ -FileSystem CSVFS_ReFS -StorageTierFriendlyNames Capacity -StorageTierSizes 200GB 

            }

        }else{

            1..$NumberOfDisks | ForEach-Object {

                New-Volume -StoragePoolFriendlyName "S2DPool" -FriendlyName MultiResiliencyDisk$_ -FileSystem CSVFS_ReFS -StorageTierFriendlyNames performance,capacity -StorageTierSizes 2TB,8TB

                New-Volume -StoragePoolFriendlyName "S2DPool" -FriendlyName MirrorDisk$_ -FileSystem CSVFS_ReFS -StorageTierFriendlyNames performance -StorageTierSizes 2TB 

            }

        }



    start-sleep 10

#endregion

#region 019 - Optional Rename CSV(s) to match name

        Get-ClusterSharedVolume  | % {

            $volumepath=$_.sharedvolumeinfo.friendlyvolumename

            $newname=$_.name.Substring(22,$_.name.Length-23)

            Invoke-Command -ComputerName (Get-ClusterSharedVolume).ownernode -ScriptBlock {param($volumepath,$newname); Rename-Item -Path $volumepath -NewName $newname} -ArgumentList $volumepath,$newname -ErrorAction SilentlyContinue

        } 



#endregion

#region 020 - Optional Create some VMs and optimize pNICs and activate High Perf Power Plan



    #create some fake VMs

        Start-Sleep -Seconds 30 #just to a bit wait as I saw sometimes that first VM fails to create

        $CSVs=(Get-ClusterSharedVolume).Name

        foreach ($CSV in $CSVs){

            $CSV=$CSV.Substring(22)

            $CSV=$CSV.TrimEnd(")")

            1..3 | ForEach-Object {

                $VMName="TestVM$($CSV)_$_"

                Invoke-Command -ComputerName (Get-ClusterNode).name[0] -ArgumentList $CSV,$VMName -ScriptBlock {

                    param($CSV,$VMName);

                    New-VM -Name $VMName -NewVHDPath "c:\ClusterStorage\$CSV\$VMName\Virtual Hard Disks\$VMName.vhdx" -NewVHDSizeBytes 32GB -SwitchName VSW01 -Generation 2 -Path "c:\ClusterStorage\$CSV\"

                }

                Add-ClusterVirtualMachineRole -VMName $VMName -Cluster $ClusterName

            }

        }



        #activate High Performance Power plan

        #show enabled power plan

            Invoke-Command $Nodes {Get-CimInstance -Name root\cimv2\power -Class win32_PowerPlan | where isactive -eq $true | ft PSComputerName,ElementName}

        #Grab instances of power plans

         #   $instances=Invoke-Command $Nodes {Get-CimInstance -Name root\cimv2\power -Class win32_PowerPlan | where Elementname -eq "Balanced"}
         #   $Instances

        #activate plan

         #   foreach ($instance in $instances) {Invoke-CimMethod -InputObject $instance -MethodName Activate}
          #  $instances

        #show enabled power plan

          #  Invoke-Command $Nodes {Get-CimInstance -Name root\cimv2\power -Class win32_PowerPlan | where isactive -eq $true | ft PSComputerName,ElementName}

         #   Enter-PSSession -ComputerName S2D2
         #   $Instance = Get-CimInstance -Name root\cimv2\power -Class win32_PowerPlan | where Elementname -eq "High performance"
            
          #  Invoke-CimMethod -InputObject $instance -MethodName Activate



#endregion

#region 021 - Optional Testing with VMFleet

#https://github.com/Microsoft/diskspd download the files and store them in c:\post-install\VMVFleet


Get-ClusterNode |% {New-Volume -StoragePoolFriendlyName S2D* -FriendlyName $_ -FileSystem CSVFS_ReFS -Size 300GB -PhysicalDiskRedundancy 1}

New-Volume -StoragePoolFriendlyName S2D* -FriendlyName collect -FileSystem CSVFS_ReFS -Size 200GB -PhysicalDiskRedundancy 1

.\install-vmfleet.ps1 -source C:\Post-Install\VMFleet

.\test-clusterhealth.ps1

#Open in a new window!!!
#Take a break for 10 minutes need to copy files into the lab
.\watch-cluster.ps1

.\create-vmfleet.ps1 -basevhd "C:\ClusterStorage\Collect\WIN2016CORE.vhdx" -vms 5 -adminpass P@ssw0rd -connectpass "P@ssw0rd((^^&&" -connectuser "checkyourlogs\svc_vmfleet" -nodes "s2d1","s2d2"

.\start-vmfleet.ps1

.\clear-pause.ps1

.\Watch-Cluster.ps1

.\start-sweep.ps1 -b 4 -t 2 -o 40 -w 0 -d 300

.\start-sweep.ps1 -b 4 -t 2 -o 20 -w 30 -d 300

#endregion

#region 022 - Optional Finding the failed Disk 

Get-PhysicalDisk 
  
# Shutdown, take the disk out and reboot. Set the missing disk to a variable 
$missingDisk = Get-PhysicalDisk | Where-Object { $_.OperationalStatus -eq 'Lost Communication' } 
  
# Retire the missing disk 
$missingDisk | Set-PhysicalDisk -Usage Retired 
  
# Find the name of your new disk 
Get-PhysicalDisk 
  
# Set the replacement disk object to a variable 
$replacementDisk = Get-PhysicalDisk –FriendlyName PhysicalDisk1 
  
# Add replacement Disk to the Storage Pool 
Add-PhysicalDisk –PhysicalDisks $replacementDisk –StoragePoolFriendlyName pool 
  
# Repair each Volume 
Repair-VirtualDisk –FriendlyName <VolumeName> 
  
# Get the status of the rebuilds 
Get-StorageJob 
  
# Remove failed Virtual Disks 
Remove-VirtualDisk –FriendlyName <FriendlyName> 
  
# Remove the failed Physical Disk from the pool 
Remove-PhysicalDisk –PhysicalDisks $missingDisk –StoragePoolFriendlyName pool


#endregion

#region 023 - Optional Physical LAB RESET ###WARNING WILL WIPE ALL CLUSTER DISKS AND DATA #### Wiping the NIC Configuraiton to start the Demo Over

$Nodes = ('S2D1','S2D2')
Invoke-Command $Nodes {C:\post-install\Clear-SdsConfig.ps1 -confirm:$False}
Enter-PSSession -ComputerName S2D2

Invoke-Command $Nodes {
#DO NOT RUN THIS COMMAND IN PROD!!!
Get-VMNetworkAdapter -ManagementOS | Where-Object {$_.Name -ne 'Production'} | Remove-VMNetworkAdapter -confirm:$False
Get-VmSwitch | Where-Object {$_.Name -ne 'Embedded_vSwitch_Team_Production'} | Remove-Vmswitch -Confirm:$False
Get-NetQosPolicy | Remove-NetQosPolicy -confirm:$Falase
Get-NetQosTrafficClass | Remove-NetQosTrafficClass
#Clear-ClusterNode




}

Invoke-command $Nodes {Clear-ClusterNode}

Invoke-command $Nodes {Get-PhysicalDisk | ft}

Invoke-command $Nodes {Get-StorageSubSystem | ft}

#endregion