# Please follow the below the command PowerShell script step by step to finish the S2D setup. There 5 catalogues show,
# <<MUST>> This step can't be miss!
# <<Optional>> This step is optional!
# <<Check>> To check the previously step 
# <<Undo>> Undo the previously step
# <<Clear>> 

# =============== # Pre-Setup =====================
<# <<MUST>> Please have these servers renamed to the appropriate computer names, 
joined to the domain and set the time zone. Reboot for the changes to take effect. 
Run the following commands sections at at time.
#>

$S1 = "Hostname-N1"
$S2 = "Hostname-N2"
$S3 = "Hostname-N3"

$nodes = ($S1,$S2,$S3)

# <<MUST>> Enable Remote Desktop Connnection
Invoke-Command -ComputerName $nodes -ScriptBlock {
    # Enable Remote Desktop
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-Name "fDenyTSConnections" -Value 0

    # Allow connections NOT only  from computers running RDP with Network Level Authentication
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0 
    
    # Allow RDP on Firewall
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
    Get-NetFirewallRule -DisplayGroup "Remote Desktop" | ft Name,Enabled,Profile
} 
 
# <<MUST>> Enable Ping 
Invoke-Command -ComputerName $nodes -ScriptBlock {
    Enable-NetFirewallRule -Name 'FPS-ICMP4-ERQ-In'
}

# <<Optional>> Disable Firewall
Invoke-Command -ComputerName $nodes -ScriptBlock {
    Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled False
}

# <<MUST>> Clear all the disk before setup 
Invoke-Command -ComputerName $nodes -ScriptBlock {
    Set-ExecutionPolicy Unrestricted -Force
    cd C:\DataON\Script\
    .\Clear-SdsConfig.ps1
}

# <<MUST>> Show all disk status
Invoke-Command -ComputerName $nodes -ScriptBlock {
    Get-PhysicalDisk -CanPool $true
} | measure

# =============== # Networking Setup =====================

# <<MUST>> Rename All NICs to DataON standard names
Invoke-Command -ComputerName $nodes -ScriptBlock {
    Set-ExecutionPolicy Unrestricted
    c:\DataON\script\NicConfig.ps1 C:\DataON\Script\nic.config Rename
}

# <<MUST>> Get NIC
Invoke-Command -ComputerName $nodes -ScriptBlock {
    Get-NetAdapter | where Status -Like Up | ft ifAlias, Status,LinkSpeed
}

# <<MUST>> Get Disconnected/ Disabled NIC
Invoke-Command -ComputerName $nodes -ScriptBlock {
    Get-NetAdapter | where Status -Like "Disconnected" | ft Name, Status
    Get-NetAdapter | where Status -Like "Disabled" | ft Name, Status
}

# <<MUST>> Disable Disconnected NIC
Invoke-Command -ComputerName $nodes -ScriptBlock {
    $nics = Get-NetAdapter | Where-Object Status -NE "Up"| Select-Object -ExpandProperty Name
    foreach( $nic in $nics) {
        Write-Verbose 'Disable $nic' 
        Disable-NetAdapter $nic -Confirm:$false
    }
}

# <<MUST>> Node 1
Invoke-Command -ComputerName $S1 -ScriptBlock {
    Set-NetIPInterface -InterfaceAlias "RDMA1" -DHCP Disabled 
    Remove-NetIPAddress -InterfaceAlias "RDMA1" -Confirm:$false 
    New-NetIPAddress -InterfaceAlias "RDMA1" -IPAddress 192.168.101.11 -PrefixLength 24 
    Set-NetAdapter -Name "RDMA1" -VlanID 8 

    Set-NetIPInterface -InterfaceAlias "RDMA2" -DHCP Disabled 
    Remove-NetIPAddress -InterfaceAlias "RDMA2" -Confirm:$false 
    New-NetIPAddress -InterfaceAlias "RDMA2" -IPAddress 192.168.102.11 -PrefixLength 24 
    Set-NetAdapter -Name "RDMA2" -VlanID 8 

    Set-NetIPInterface -InterfaceAlias "RDMA3" -DHCP Disabled 
    Remove-NetIPAddress -InterfaceAlias "RDMA3" -Confirm:$false 
    New-NetIPAddress -InterfaceAlias "RDMA3" -IPAddress 192.168.103.11 -PrefixLength 24 
    Set-NetAdapter -Name "RDMA3" -VlanID 9 

    Set-NetIPInterface -InterfaceAlias "RDMA4" -DHCP Disabled 
    Remove-NetIPAddress -InterfaceAlias "RDMA4" -Confirm:$false 
    New-NetIPAddress -InterfaceAlias "RDMA4" -IPAddress 192.168.104.11 -PrefixLength 24 
    Set-NetAdapter -Name "RDMA4" -VlanID 9 
}

# <<Check>> Node 1
Invoke-Command -ComputerName $S1 -ScriptBlock {
    Get-NetAdapter -Name "NIC1" |select Name,InterfaceDescription,ifIndex,Status,LinkSpeed,VlanID -ExcludeProperty RunspaceID
    Get-NetIPAddress -InterfaceAlias "NIC1" |Select InterfaceAlias,IPAddress -ExcludeProperty RunspaceID
    Write-Output "=================="
    Get-NetAdapter -Name "RDMA1" |select Name,InterfaceDescription,ifIndex,Status,LinkSpeed,VlanID -ExcludeProperty RunspaceID
    Get-NetIPAddress -InterfaceAlias "RDMA1" |Select InterfaceAlias,IPAddress -ExcludeProperty RunspaceID
    Write-Output "=================="
    Get-NetAdapter -Name "RDMA2" |select Name,InterfaceDescription,ifIndex,Status,LinkSpeed,VlanID -ExcludeProperty RunspaceID
    Get-NetIPAddress -InterfaceAlias "RDMA2" |Select InterfaceAlias,IPAddress -ExcludeProperty RunspaceID
    Write-Output "=================="
    Get-NetAdapter -Name "RDMA3" |select Name,InterfaceDescription,ifIndex,Status,LinkSpeed,VlanID -ExcludeProperty RunspaceID
    Get-NetIPAddress -InterfaceAlias "RDMA3" |Select InterfaceAlias,IPAddress -ExcludeProperty RunspaceID
    Write-Output "=================="
    Get-NetAdapter -Name "RDMA4" |select Name,InterfaceDescription,ifIndex,Status,LinkSpeed,VlanID -ExcludeProperty RunspaceID
    Get-NetIPAddress -InterfaceAlias "RDMA4" |Select InterfaceAlias,IPAddress -ExcludeProperty RunspaceID
}

# <<MUST>> Node 2
Invoke-Command -ComputerName $S2 -ScriptBlock {
    Set-NetIPInterface -InterfaceAlias "RDMA1" -DHCP Disabled 
    Remove-NetIPAddress -InterfaceAlias "RDMA1" -Confirm:$false 
    New-NetIPAddress -InterfaceAlias "RDMA1" -IPAddress 192.168.105.12 -PrefixLength 24
    Set-NetAdapter -Name "RDMA1" -VlanID 8  

    Set-NetIPInterface -InterfaceAlias "RDMA2" -DHCP Disabled 
    Remove-NetIPAddress -InterfaceAlias "RDMA2" -Confirm:$false 
    New-NetIPAddress -InterfaceAlias "RDMA2" -IPAddress 192.168.102.12 -PrefixLength 24 
    Set-NetAdapter -Name "RDMA2" -VlanID 8

    Set-NetIPInterface -InterfaceAlias "RDMA3" -DHCP Disabled 
    Remove-NetIPAddress -InterfaceAlias "RDMA3" -Confirm:$false 
    New-NetIPAddress -InterfaceAlias "RDMA3" -IPAddress 192.168.106.12 -PrefixLength 24 
    Set-NetAdapter -Name "RDMA3" -VlanID 9

    Set-NetIPInterface -InterfaceAlias "RDMA4" -DHCP Disabled 
    Remove-NetIPAddress -InterfaceAlias "RDMA4" -Confirm:$false 
    New-NetIPAddress -InterfaceAlias "RDMA4" -IPAddress 192.168.104.12 -PrefixLength 24 
    Set-NetAdapter -Name "RDMA4" -VlanID 9
}

# <<Check>> Node 2
Invoke-Command -ComputerName $S2 -ScriptBlock {
    Get-NetAdapter -Name "NIC1" |select Name,InterfaceDescription,ifIndex,Status,LinkSpeed,VlanID -ExcludeProperty RunspaceID
    Get-NetIPAddress -InterfaceAlias "NIC1" |Select InterfaceAlias,IPAddress -ExcludeProperty RunspaceID
    Write-Output "=================="
    Get-NetAdapter -Name "RDMA1" |select Name,InterfaceDescription,ifIndex,Status,LinkSpeed,VlanID -ExcludeProperty RunspaceID
    Get-NetIPAddress -InterfaceAlias "RDMA1" |Select InterfaceAlias,IPAddress -ExcludeProperty RunspaceID
    Write-Output "=================="
    Get-NetAdapter -Name "RDMA2" |select Name,InterfaceDescription,ifIndex,Status,LinkSpeed,VlanID -ExcludeProperty RunspaceID
    Get-NetIPAddress -InterfaceAlias "RDMA2" |Select InterfaceAlias,IPAddress -ExcludeProperty RunspaceID
    Write-Output "=================="
    Get-NetAdapter -Name "RDMA3" |select Name,InterfaceDescription,ifIndex,Status,LinkSpeed,VlanID -ExcludeProperty RunspaceID
    Get-NetIPAddress -InterfaceAlias "RDMA3" |Select InterfaceAlias,IPAddress -ExcludeProperty RunspaceID
    Write-Output "=================="
    Get-NetAdapter -Name "RDMA4" |select Name,InterfaceDescription,ifIndex,Status,LinkSpeed,VlanID -ExcludeProperty RunspaceID
    Get-NetIPAddress -InterfaceAlias "RDMA4" |Select InterfaceAlias,IPAddress -ExcludeProperty RunspaceID
}

# <<MUST>> Node 3
Invoke-Command -ComputerName $S3 -ScriptBlock {
    Set-NetIPInterface -InterfaceAlias "RDMA1" -DHCP Disabled 
    Remove-NetIPAddress -InterfaceAlias "RDMA1" -Confirm:$false 
    New-NetIPAddress -InterfaceAlias "RDMA1" -IPAddress 192.168.101.13 -PrefixLength 24 
    Set-NetAdapter -Name "RDMA1" -VlanID 8

    Set-NetIPInterface -InterfaceAlias "RDMA2" -DHCP Disabled 
    Remove-NetIPAddress -InterfaceAlias "RDMA2" -Confirm:$false 
    New-NetIPAddress -InterfaceAlias "RDMA2" -IPAddress 192.168.105.13 -PrefixLength 24 
    Set-NetAdapter -Name "RDMA2" -VlanID 8

    Set-NetIPInterface -InterfaceAlias "RDMA3" -DHCP Disabled 
    Remove-NetIPAddress -InterfaceAlias "RDMA3" -Confirm:$false 
    New-NetIPAddress -InterfaceAlias "RDMA3" -IPAddress 192.168.103.13 -PrefixLength 24 
    Set-NetAdapter -Name "RDMA3" -VlanID 9

    Set-NetIPInterface -InterfaceAlias "RDMA4" -DHCP Disabled 
    Remove-NetIPAddress -InterfaceAlias "RDMA4" -Confirm:$false 
    New-NetIPAddress -InterfaceAlias "RDMA4" -IPAddress 192.168.106.13 -PrefixLength 24 
    Set-NetAdapter -Name "RDMA4" -VlanID 9
}

# <<Check>> Node 3
Invoke-Command -ComputerName $S3 -ScriptBlock {
    Get-NetAdapter -Name "NIC1" |select Name,InterfaceDescription,ifIndex,Status,LinkSpeed,VlanID -ExcludeProperty RunspaceID
    Get-NetIPAddress -InterfaceAlias "NIC1" |Select InterfaceAlias,IPAddress -ExcludeProperty RunspaceID
    Write-Output "=================="
    Get-NetAdapter -Name "RDMA1" |select Name,InterfaceDescription,ifIndex,Status,LinkSpeed,VlanID -ExcludeProperty RunspaceID
    Get-NetIPAddress -InterfaceAlias "RDMA1" |Select InterfaceAlias,IPAddress -ExcludeProperty RunspaceID
    Write-Output "=================="
    Get-NetAdapter -Name "RDMA2" |select Name,InterfaceDescription,ifIndex,Status,LinkSpeed,VlanID -ExcludeProperty RunspaceID
    Get-NetIPAddress -InterfaceAlias "RDMA2" |Select InterfaceAlias,IPAddress -ExcludeProperty RunspaceID
    Write-Output "=================="
    Get-NetAdapter -Name "RDMA3" |select Name,InterfaceDescription,ifIndex,Status,LinkSpeed,VlanID -ExcludeProperty RunspaceID
    Get-NetIPAddress -InterfaceAlias "RDMA3" |Select InterfaceAlias,IPAddress -ExcludeProperty RunspaceID
    Write-Output "=================="
    Get-NetAdapter -Name "RDMA4" |select Name,InterfaceDescription,ifIndex,Status,LinkSpeed,VlanID -ExcludeProperty RunspaceID
    Get-NetIPAddress -InterfaceAlias "RDMA4" |Select InterfaceAlias,IPAddress -ExcludeProperty RunspaceID
}
# <<MUST>> Check IP setup success 
ipconfig.exe /flushdns
ping $S1
ping $S2
ping $S3

# =============== # Install Windows Features =====================

# <<MUST>> Install Hyper-V and Failover Cluster features

Invoke-Command $nodes {Install-WindowsFeature Failover-Clustering -IncludeAllSubFeature -IncludeManagementTools}
Invoke-Command $nodes {Install-WindowsFeature -Name Hyper-V, File-Services -IncludeManagementTools}
Invoke-Command $nodes {Install-WindowsFeature -Name Data-Center-Bridging}
Invoke-Command $nodes {Install-WindowsFeature -Name FS-SMBBW} #For Live Migration Bandwidth Management
Invoke-Command $nodes {shutdown.exe -r -t 5}

# =============== # QoS Setup=====================

# <<MUST>> Set NetQos for Cluster
Invoke-Command $nodes {
    New-NetQosPolicy "Cluster" -Cluster -PriorityValue8021Action 7
    Set-NetQosPolicy -Name "Cluster" -PriorityValue8021Action 7
    Get-NetQosPolicy -Name "Cluster" |select Name, PriorityValue8021Action #Should return with 7
}

# <<MUST>> Set NetQos for SMB
Invoke-Command $nodes {
    New-NetQosPolicy "SMB" -NetDirectPortMatchCondition 445 -PriorityValue8021Action 3
    Set-NetQosPolicy -Name "SMB" -NetDirectPortMatchCondition 445 -PriorityValue8021Action 3
    Get-NetQosPolicy -Name "SMB" |select Name, PriorityValue8021Action    # Should return with 3
}   

# <<MUST>> Set NetQos for Default
Invoke-Command $nodes {    
    New-NetQosPolicy "DEFAULT" -Default -PriorityValue8021Action 0
    Set-NetQosPolicy -Name "DEFAULT" -PriorityValue8021Action 0
    Get-NetQosPolicy -Name "DEFAULT" |select Name, PriorityValue8021Action    # Should return with 0
}

# <<MUST>> Set Other NetQos Settings
Invoke-Command $nodes {    
    # Turn on Flow Control for SMB
    Enable-NetQosFlowControl -Priority 3
    Enable-NetQosFlowControl -Priority 7
    # Make sure flow control is off for other traffic
    Disable-NetQosFlowControl -Priority 0,1,2,4,5,6
    # Apply a Quality of Service (QoS) policy to the target adapters
    Enable-NetAdapterQos -InterfaceAlias "RDMA1","RDMA2","RDMA3","RDMA4"
    # Give SMB Direct a minimum bandwidth of 50%

    Set-NetQosDcbxSetting -InterfaceAlias RDMA1 -Willing $False 
    Set-NetQosDcbxSetting -InterfaceAlias RDMA2 -Willing $False
    Set-NetQosDcbxSetting -InterfaceAlias RDMA3 -Willing $False
    Set-NetQosDcbxSetting -InterfaceAlias RDMA4 -Willing $False

    New-NetQosTrafficClass "Cluster" -Priority 7 -BandwidthPercentage 1 -Algorithm ETS
    New-NetQosTrafficClass "SMB" -Priority 3 -BandwidthPercentage 50 -Algorithm ETS

    if ((Get-NetAdapter -Name RDMA1).ifDesc -like "Mellanox*")
    {
        Set-NetAdapterAdvancedProperty -Name "RDMA1" -RegistryKeyword "*FlowControl" -RegistryValue 0
        Set-NetAdapterAdvancedProperty -Name "RDMA1" -DisplayName "NetworkDirect Technology" -DisplayValue "RoCEv2" 
    }
    if ((Get-NetAdapter -Name RDMA2).ifDesc -like "Mellanox*")
    {
        Set-NetAdapterAdvancedProperty -Name "RDMA2" -RegistryKeyword "*FlowControl" -RegistryValue 0
        Set-NetAdapterAdvancedProperty -Name "RDMA2" -DisplayName "NetworkDirect Technology" -DisplayValue "RoCEv2" 
    }
    if ((Get-NetAdapter -Name RDMA3).ifDesc -like "Mellanox*")
    {
        Set-NetAdapterAdvancedProperty -Name "RDMA3" -RegistryKeyword "*FlowControl" -RegistryValue 0
        Set-NetAdapterAdvancedProperty -Name "RDMA3" -DisplayName "NetworkDirect Technology" -DisplayValue "RoCEv2" 
    }
    if ((Get-NetAdapter -Name RDMA4).ifDesc -like "Mellanox*")
    {
        Set-NetAdapterAdvancedProperty -Name "RDMA4" -RegistryKeyword "*FlowControl" -RegistryValue 0
        Set-NetAdapterAdvancedProperty -Name "RDMA4" -DisplayName "NetworkDirect Technology" -DisplayValue "RoCEv2" 
    }

}

# <<Check>> Check NetQos settings
Invoke-Command $nodes {
    Get-NetQosPolicy | ft Name
}
Invoke-Command $nodes {
    Get-NetQosFlowControl | where Enabled -EQ $true | ft Priority
}
Invoke-Command $nodes {
    Get-NetAdapterQos | ft Name
}
Invoke-Command $nodes {
    Get-NetQosTrafficClass | ft PriorityFriendly, Name, Bandwidth
}

Invoke-Command $nodes {
    Get-NetAdapterAdvancedProperty -Name "RDMA1" -RegistryKeyword "*FlowControl" | ft Name, RegistryKeyword, RegistryValue #Should be 0
    Get-NetAdapterAdvancedProperty -Name "RDMA1" -DisplayName "NetworkDirect Technology" | ft Name, Displayname, DisplayValue #Should be RoCEv2
    Get-NetAdapterAdvancedProperty -Name "RDMA2" -RegistryKeyword "*FlowControl" | ft Name, RegistryKeyword, RegistryValue #Should be 0
    Get-NetAdapterAdvancedProperty -Name "RDMA2" -DisplayName "NetworkDirect Technology" | ft Name, Displayname, DisplayValue #Should be RoCEv2
    Get-NetAdapterAdvancedProperty -Name "RDMA3" -RegistryKeyword "*FlowControl" | ft Name, RegistryKeyword, RegistryValue #Should be 0
    Get-NetAdapterAdvancedProperty -Name "RDMA3" -DisplayName "NetworkDirect Technology" | ft Name, Displayname, DisplayValue #Should be RoCEv2
    Get-NetAdapterAdvancedProperty -Name "RDMA4" -RegistryKeyword "*FlowControl" | ft Name, RegistryKeyword, RegistryValue #Should be 0
    Get-NetAdapterAdvancedProperty -Name "RDMA4" -DisplayName "NetworkDirect Technology" | ft Name, Displayname, DisplayValue #Should be RoCEv2

}

# <<MUST>> Check RDMA NICs are RDMA Capable
    Invoke-Command $nodes {
    Get-SmbClientNetworkInterface | where RdmaCapable -EQ $true | ft FriendlyName
}

# <<MUST>> Set JumboFrame configuration on physical NICs
Invoke-Command $nodes {
    Get-NetAdapter -Name "RDMA1" | Set-NetAdapterAdvancedProperty -RegistryKeyword "*JumboPacket" -RegistryValue 9014
    Get-NetAdapter -Name "RDMA2" | Set-NetAdapterAdvancedProperty -RegistryKeyword "*JumboPacket" -RegistryValue 9014
    Get-NetAdapter -Name "RDMA3" | Set-NetAdapterAdvancedProperty -RegistryKeyword "*JumboPacket" -RegistryValue 9014
    Get-NetAdapter -Name "RDMA4" | Set-NetAdapterAdvancedProperty -RegistryKeyword "*JumboPacket" -RegistryValue 9014
}

# <<Check>> Verify JumboFrame configuration on physical NICs
Invoke-Command $nodes {
    Get-NetAdapter -Name "RDMA1" | Get-NetAdapterAdvancedProperty -RegistryKeyword "*JumboPacket"
    Get-NetAdapter -Name "RDMA2" | Get-NetAdapterAdvancedProperty -RegistryKeyword "*JumboPacket"
    Get-NetAdapter -Name "RDMA3" | Get-NetAdapterAdvancedProperty -RegistryKeyword "*JumboPacket"
    Get-NetAdapter -Name "RDMA4" | Get-NetAdapterAdvancedProperty -RegistryKeyword "*JumboPacket"
}

# ============= Create Failover Cluster==============================

# <<MUST>> Test S2D cluster 
Test-Cluster -node $nodes -Include "Storage Spaces Direct",Inventory,Network, "System Configuration" -ReportName C:\Windows\cluster\Reports\report

# <<Check>> Check the cluster report
& 'C:\Program Files (x86)\Internet Explorer\iexplore.exe' C:\Windows\cluster\Reports\report.htm

# <<MUST>> Create Failover cluster , name the cluster and provide staticIP if neccessary
New-Cluster -Name <cluster name> -Node $nodes –NoStorage 

# <<Check>> Check the cluster create log 
Invoke-Item C:\Windows\cluster\Reports\

# ============ Create Storage Options ============

# C. No tiered no cache ( Only one media) - Standard Setup- Single Pool - One Virtual Disk per Node


# ============ C. No tiered no cache (Only one media) - Single Pool ===========

# <<MUST,Option C >> Enable S2D
Enable-ClusterS2D 

# <<MUST,Option C >> Check the Enable-ClusterS2D log 
Invoke-Item C:\Windows\cluster\Reports\

# <<MUST,Option C >> Check Pool size in TB or GB
Get-StoragePool S2* | ft FriendlyName, @{n='Size in TB';e={$_.Size / 1TB}}
Get-StoragePool S2* | ft FriendlyName, @{n='Size in GB';e={$_.Size / 1GB}}

# <<MUST,Optional C >> Create VD per Node, modify the filesystem "CSVFS_NTFS" or " CSVFS-ReFS" , Resiliency setting "Mirror" or " Parity" , disk redundancy " 1 " or "2", and size.   
Get-ClusterNode |% { New-Volume -StoragePoolFriendlyName S2D* -FriendlyName $_ -FileSystem CSVFS_ReFS -Size 10.8TB -ResiliencySettingName "Mirror" -PhysicalDiskRedundancy 2 }

#================================================================
# <<Optional>> Configure Hyper-V Host Settings
# Use SMB for Live Migration
icm $nodes {Set-VMHost -VirtualMachineMigrationPerformanceOption SMB}
# Enable Enhanced Sessions
icm $nodes {Set-VMHost -EnableEnhancedSessionMode $true}
# Set a Limit on LiveMigration Bandwdith
icm $nodes {Set-SmbBandwidthLimit -Category LiveMigration -BytesPerSecond 750MB}

# To verify
icm $nodes {Get-VMHost |select VirtualMachineMigrationPerformanceOption, MaximumVirtualMachineMigrations, EnableEnhancedSessionMode}
icm $nodes {Get-SmbBandWidthLimit -Category LiveMigration}


# Use this ONLY to REMOVE S2D and Failover Cluster to start fresh ===========
<# ========== Clear S2D Setting ===========

<# << Clear>> 1. Remove all VDs
Get-VirtualDisk | Remove-VirtualDisk

#<< Clear>> 2. Remove all StoragePool
Get-StoragePool S2d* | Remove-StoragePool

#<< Clear>> 3. Disable S2D
Disable-ClusterS2D

#<< Clear>> 4. Remove cluster
Remove-Cluster <cluster name> -Force

#<< Clear>> IF step 4 failed, apply this command on all of nodes
Clear-ClusterNode $nodes -Force

#<< Clear>> 5. Clear all disks 
$S1 = "Node01"
$S2 = "Node02"
$S3 = "Node03"
$S4 = "Node04"
$S5 = "Node05"

$nodes = ($S1,$S2,$S3,$S4,$S5)

Invoke-Command -ComputerName $nodes -ScriptBlock {
    Set-ExecutionPolicy Unrestricted
    cd C:\DataON\Script\
    .\Clear-SdsConfig.ps1
}
#>