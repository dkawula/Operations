<#
Created:	 2020-01-09
Version:	 1.0
Author       Dave Kawula MVP
Homepage:    http://www.checkyourlogs.net

Disclaimer:
This script is provided "AS IS" with no warranties, confers no rights and 
is not supported by the authors or Checkyourlogs.net

Author - Dave Kawula
    Twitter: @DaveKawula
    Blog   : http://www.checkyourlogs.net

    .Synopsis
    Creates a big demo lab.
    .DESCRIPTION
    Huge Thank you to Ben Armstrong @VirtualPCGuy for giving me the source starter code for this :)
    This script will build a sample lab configruation on a single Hyper-V Server:

    It includes in this version 2 Domain Controllers, 1 x DHCP Server, 1 x MGMT Server, 16 x S2D Nodes

    It is fully customizable as it has been created with base functions.

    The Parameters at the beginning of the script will setup the domain name, organization name etc.

    You will need to change the <ProductKey> Variable as it has been removed for the purposes of the print in this book.

    .EXAMPLE
    TODO: Dave, add something more meaningful in here
    .PARAMETER WorkingDir
    Transactional directory for files to be staged and written
    .PARAMETER Organization
    Org that the VMs will belong to
    .PARAMETER Owner
    Name to fill in for the OSs Owner field
    .PARAMETER TimeZone
    Timezone used by the VMs
    .PARAMETER AdminPassword
    Administrative password for the VMs
    .PARAMETER DomainName
    AD Domain to setup/join VMs to
    .PARAMETER DomainAdminPassword
    Domain recovery/admin password
    .PARAMETER VirtualSwitchName
    Name of the vSwitch for Hyper-V
    .PARAMETER Subnet
    The /24 Subnet to use for Hyper-V networking
#>

#region Parameters
[cmdletbinding()]
param
( 
    [Parameter(Mandatory)]
    [ValidateScript( { $_ -match '[^\\]$' })] #ensure WorkingDir does not end in a backslash, otherwise issues are going to come up below
    [string]
    $WorkingDir = 'c:\ClusterStoreage\Volume1\DCBuild',

    [Parameter(Mandatory)]
    [string]
    $Organization = 'MVP Rockstars',

    [Parameter(Mandatory)]
    [string]
    $Owner = 'Dave Kawula',

    [Parameter(Mandatory)]
    [ValidateScript( { $_ -in ([System.TimeZoneInfo]::GetSystemTimeZones()).ID })] #ensure a valid TimeZone was passed
    [string]
    $Timezone = 'Pacific Standard Time',

    [Parameter(Mandatory)]
    [string]
    $adminPassword = 'P@ssw0rd',

    [Parameter(Mandatory)]
    [string]
    $domainName = 'MVPDays.Com',

    [Parameter(Mandatory)]
    [string]
    $domainAdminPassword = 'P@ssw0rd',

    [Parameter(Mandatory)]
    [string]
    $virtualSwitchName = 'Dave MVP Demo',

    [Parameter(Mandatory)]
    [ValidatePattern('(\d{1,3}\.){3}')] #ensure that Subnet is formatted like the first three octets of an IPv4 address
    [string]
    $Subnet = '172.16.200.',

    [Parameter(Mandatory)]
    [string]
    $ExtraLabfilesSource = 'C:\ClusterStorage\Volume1\DCBuild\Extralabfiles'


)
#endregion


#region Functions

function Wait-PSDirect {
    param
    (
        [string]
        $VMName,

        [Object]
        $cred
    )

    Write-Log $VMName "Waiting for PowerShell Direct (using $($cred.username))"
    while ((Invoke-Command -VMName $VMName -Credential $cred {
                'Test'
            } -ea SilentlyContinue) -ne 'Test') {
        Start-Sleep -Seconds 1
    }
}


Function Wait-Sleep {
    param (
        [int]$sleepSeconds = 60,
        [string]$title = "... Waiting for $sleepSeconds Seconds... Be Patient",
        [string]$titleColor = "Yellow"
    )
    Write-Host -ForegroundColor $titleColor $title
    for ($sleep = 1; $sleep -le $sleepSeconds; $sleep++ ) {
        Write-Progress -ParentId -1 -Id 42 -Activity "Sleeping for $sleepSeconds seconds" -Status "Slept for $sleep Seconds:" -percentcomplete (($sleep / $sleepSeconds) * 100)
        Start-Sleep 1
    }
    Write-Progress -Completed -Id 42 -Activity "Done Sleeping"
}
    

function Restart-DemoVM {
    param
    (
        [string]
        $VMName
    )

    Write-Log $VMName 'Rebooting'
    stop-vm $VMName
    start-vm $VMName
}

function Confirm-Path {
    param
    (
        [string] $path
    )
    if (!(Test-Path $path)) {
        $null = mkdir $path
    }
}

function Write-Log {
    param
    (
        [string]$systemName,
        [string]$message
    )

    Write-Host -Object (Get-Date).ToShortTimeString() -ForegroundColor Cyan -NoNewline
    Write-Host -Object ' - [' -ForegroundColor White -NoNewline
    Write-Host -Object $systemName -ForegroundColor Yellow -NoNewline
    Write-Host -Object "]::$($message)" -ForegroundColor White
}

function Clear-File {
    param
    (
        [string] $file
    )
    
    if (Test-Path $file) {
        $null = Remove-Item $file -Recurse
    }
}

function Invoke-DemoVMPrep {
    param
    (
        [string] $VMName, 
        [string] $GuestOSName, 
        [switch] $FullServer2016,
        [switch] $FullServer2019,
        [switch] $CoreServer2016,
        [switch] $CoreServer2019
    ) 

    Write-Log $VMName 'Removing old VM'
    get-vm $VMName -ErrorAction SilentlyContinue |
    stop-vm -TurnOff -Force -Passthru |
    remove-vm -Force
    Clear-File "$($VMPath)\$($GuestOSName).vhdx"
   
    Write-Log $VMName 'Creating new differencing disk'
    if ($FullServer2016) {
        $null = New-VHD -Path "$($VMPath)\$($GuestOSName).vhdx" -ParentPath "$($BaseVHDPath)\VMServerBase2016.vhdx" -Differencing
    }

    Elseif ($FullServer2019) {
        $null = New-VHD -Path "$($VMPath)\$($GuestOSName).vhdx" -ParentPath "$($BaseVHDPath)\VMServerBase2019.vhdx" -Differencing
    }

    Elseif ($CoreServer2016) {
        $null = New-VHD -Path "$($VMPath)\$($GuestOSName).vhdx" -ParentPath "$($BaseVHDPath)\VMServerCore2016.vhdx" -Differencing
    }
    Elseif ($CoreServer2019) {
        $null = New-VHD -Path "$($VMPath)\$($GuestOSName).vhdx" -ParentPath "$($BaseVHDPath)\VMServerCore2019.vhdx" -Differencing
    }

    else {
        $null = New-VHD -Path "$($VMPath)\$($GuestOSName).vhdx" -ParentPath "$($BaseVHDPath)\VMServerBase2019.vhdx" -Differencing
    }

    Write-Log $VMName 'Creating virtual machine'
    new-vm -Name $VMName -MemoryStartupBytes 4GB -SwitchName $virtualSwitchName `
        -Generation 2 -Path "$($VMPath)\" | Set-VM -ProcessorCount 2 

    Set-VMFirmware -VMName $VMName -SecureBootTemplate MicrosoftUEFICertificateAuthority
    Set-VMFirmware -Vmname $VMName -EnableSecureBoot off
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($GuestOSName).vhdx" -ControllerType SCSI
    Write-Log $VMName 'Starting virtual machine'
    Enable-VMIntegrationService -Name 'Guest Service Interface' -VMName $VMName
    start-vm $VMName
}

function Invoke-FabricVMPrep {
    param
    (
        [string] $VMName, 
        [string] $GuestOSName, 
        [switch] $FullServer2016,
        [switch] $FullServer2019,
        [switch] $CoreServer2016,
        [switch] $CoreServer2019
    ) 

    Write-Log $VMName 'Removing old VM'
    get-vm $VMName -ErrorAction SilentlyContinue |
    stop-vm -TurnOff -Force -Passthru |
    remove-vm -Force
    Clear-File "$($VMPath)\$($GuestOSName).vhdx"
   
    Write-Log $VMName 'Copying Gold VHDx Template'
    if ($FullServer2016) {
        $null = Copy-Item "$($BaseVHDPath)\VMServerBase2016.vhdx" -Destination "$($VMPath)\$($GuestOSName).vhdx"
        
    }

    Elseif ($FullServer2019) {
        $null = Copy-Item "$($BaseVHDPath)\VMServerBase2019.vhdx" -Destination "$($VMPath)\$($GuestOSName).vhdx"
    }

    Elseif ($CoreServer2016) {
        $null = Copy-Item "$($BaseVHDPath)\VMServerCore2016.vhdx" -Destination "$($VMPath)\$($GuestOSName).vhdx"
    }
    Elseif ($CoreServer2019) {
        $null = Copy-Item "$($BaseVHDPath)\VMServerCore2019.vhdx" -Destination "$($VMPath)\$($GuestOSName).vhdx"
    }

    else {
        $null = Copy-Item "$($BaseVHDPath)\VMServerBase2019.vhdx" -Destination "$($VMPath)\$($GuestOSName).vhdx"
    }

    Write-Log $VMName 'Creating virtual machine'
    new-vm -Name $VMName -MemoryStartupBytes 4GB -SwitchName $virtualSwitchName `
        -Generation 2 -Path "$($VMPath)\" | Set-VM -ProcessorCount 2 

    Set-VMFirmware -VMName $VMName -SecureBootTemplate MicrosoftUEFICertificateAuthority
    Set-VMFirmware -Vmname $VMName -EnableSecureBoot off
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($GuestOSName).vhdx" -ControllerType SCSI
    Write-Log $VMName 'Starting virtual machine'
    Enable-VMIntegrationService -Name 'Guest Service Interface' -VMName $VMName
    start-vm $VMName
}

function Create-DemoVM {
    param
    (
        [string] $VMName, 
        [string] $GuestOSName, 
        [string] $IPNumber = '0'
    ) 
  
    Wait-PSDirect $VMName -cred $localCred

    Invoke-Command -VMName $VMName -Credential $localCred {
        param($IPNumber, $GuestOSName, $VMName, $domainName, $Subnet)
        if ($IPNumber -ne '0') {
            Write-Output -InputObject "[$($VMName)]:: Setting IP Address to $($Subnet)$($IPNumber)"
            $null = New-NetIPAddress -IPAddress "$($Subnet)$($IPNumber)" -InterfaceAlias 'Ethernet' -PrefixLength 24
            Write-Output -InputObject "[$($VMName)]:: Setting DNS Address"
            Get-DnsClientServerAddress | ForEach-Object -Process {
                Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ServerAddresses "$($Subnet)1"
            }
        }
        Write-Output -InputObject "[$($VMName)]:: Renaming OS to `"$($GuestOSName)`""
        Rename-Computer -NewName $GuestOSName
        Write-Output -InputObject "[$($VMName)]:: Configuring WSMAN Trusted hosts"
        Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value "*.$($domainName)" -Force
        Set-Item WSMan:\localhost\client\trustedhosts "$($Subnet)*" -Force -concatenate
        Enable-WSManCredSSP -Role Client -DelegateComputer "*.$($domainName)" -Force
    } -ArgumentList $IPNumber, $GuestOSName, $VMName, $domainName, $Subnet

    Restart-DemoVM $VMName
    
    Wait-PSDirect $VMName -cred $localCred
}

function Create-FabricVM {
    param
    (
        [string] $VMName, 
        [string] $GuestOSName, 
        [string] $IPNumber = '0'
    ) 
  
    Wait-PSDirect $VMName -cred $localCred

    Invoke-Command -VMName $VMName -Credential $localCred {
        param($IPNumber, $GuestOSName, $VMName, $domainName, $Subnet)
        if ($IPNumber -ne '0') {
            Write-Output -InputObject "[$($VMName)]:: Setting IP Address to $($Subnet)$($IPNumber)"
            $null = New-NetIPAddress -IPAddress "$($Subnet)$($IPNumber)" -InterfaceAlias 'Ethernet' -PrefixLength 24
            Write-Output -InputObject "[$($VMName)]:: Setting DNS Address"
            Get-DnsClientServerAddress | ForEach-Object -Process {
                Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ServerAddresses "$($Subnet)1"
            }
        }
        Write-Output -InputObject "[$($VMName)]:: Renaming OS to `"$($GuestOSName)`""
        Rename-Computer -NewName $GuestOSName
        Write-Output -InputObject "[$($VMName)]:: Configuring WSMAN Trusted hosts"
        Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value "*.$($domainName)" -Force
        Set-Item WSMan:\localhost\client\trustedhosts "$($Subnet)*" -Force -concatenate
        Enable-WSManCredSSP -Role Client -DelegateComputer "*.$($domainName)" -Force
    } -ArgumentList $IPNumber, $GuestOSName, $VMName, $domainName, $Subnet

    Restart-DemoVM $VMName
    
    Wait-PSDirect $VMName -cred $localCred
}

function Invoke-NodeStorageBuild {
    param
    (
        [string]$VMName, 
        [string]$GuestOSName
    )

    Create-DemoVM $VMName $GuestOSName
    1..16 | ForEach-Object { Clear-File "$($VMPath)\$($GuestOSName) - Data $_.vhdx" }
    Get-VM $VMName | Stop-VM 
    Add-VMNetworkAdapter -VMName $VMName -SwitchName $virtualSwitchName
    1..16 | ForEach-Object { New-VHD -Path "$($VMPath)\$($GuestOSName) - Data $_.vhdx" -Dynamic -SizeBytes 10000GB }
    1..16 | ForEach-Object { Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($GuestOSName) - Data $_.vhdx" -ControllerType SCSI }
    Set-VMProcessor -VMName $VMName -Count 2 -ExposeVirtualizationExtensions $True
    Add-VMNetworkAdapter -VMName $VMName -SwitchName $virtualSwitchName
    Add-VMNetworkAdapter -VMName $VMName -SwitchName $virtualSwitchName
    Add-VMNetworkAdapter -VMName $VMName -SwitchName $virtualSwitchName
    Get-VMNetworkAdapter -VMName $VMName | Set-VMNetworkAdapter -AllowTeaming On
    Get-VMNetworkAdapter -VMName $VMName | Set-VMNetworkAdapter -MacAddressSpoofing on
 
    Start-VM $VMName
    Wait-PSDirect $VMName -cred $localCred


    Invoke-Command -VMName $VMName -Credential $localCred {
        param($VMName, $domainCred, $domainName)
        Write-Output -InputObject "[$($VMName)]:: Installing Clustering"
        $null = Install-WindowsFeature -Name File-Services, Failover-Clustering, Hyper-V, FS-Data-Deduplication -IncludeManagementTools
        Write-Output -InputObject "[$($VMName)]:: Joining domain as `"$($env:computername)`""
    
        while (!(Test-Connection -ComputerName $domainName -BufferSize 16 -Count 1 -Quiet -ea SilentlyContinue)) {
            Start-Sleep -Seconds 1
        }
    
        do {
            Add-Computer -DomainName $domainName -Credential $domainCred -ea SilentlyContinue
        }
        until ($?)
    } -ArgumentList $VMName, $domainCred, $domainName

    Wait-PSDirect $VMName -cred $domainCred
    Restart-DemoVM $VMName
    Wait-PSDirect $VMName -cred $domainCred

    Invoke-Command -VMName $VMName -Credential $domainCred {
        Rename-NetAdapter -Name 'Ethernet' -NewName 'LOM-P0'
        Rename-NetAdapter -Name 'Ethernet 2' -NewName 'LOM-P1'
        Rename-NetAdapter -Name 'Ethernet 3' -NewName 'Riser-P0'
        Get-NetAdapter -Name 'Ethernet 5' | Rename-NetAdapter -NewName 'Riser-P1'
   
        New-VmSwitch -Name VSW01 -NetAdapterName "LOM-P0", "LOM-P1" -EnableEmbeddedTeaming $True -AllowManagementOS $False -verbose
        Add-VMNetworkAdapter -SwitchName VSW01 -Name SMB_1 -ManagementOS
        Add-VMNetworkAdapter -SwitchName VSW01 -Name SMB_2 -ManagementOS
        Add-VMNetworkAdapter -SwitchName VSW01 -Name LM -ManagementOS
        Add-VMNetworkAdapter -SwitchName VSW01 -Name HB -ManagementOS
        Add-VMNetworkAdapter -SwitchName VSW01 -Name MGMT -ManagementOS

   
        # Adding the hidden Registry Key to make S2D Work in Windows Server 2019
        # https://social.technet.microsoft.com/Forums/en-US/7e7cfd1e-b9e2-410c-b6ab-26f5f564a50e/registry-key-to-enable-s2d-on-windows-server-2019?forum=ws2016&prof=required
        $Key = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\ClusSvc\Parameters"
        If ( -Not ( Test-Path "Registry::$Key")) { New-Item -Path "Registry::$Key" -ItemType RegistryKey -Force }
        Set-ItemProperty -path "Registry::$Key" -Name "S2D" -Type "Dword" -Value "1"

    }

    Restart-DemoVM $VMName
    #Wait-PSDirect $VMName -cred $domainCred

  
}

Function Install-WSUS {
    #Installs WSUS to the Target VM in the Lab
    #Script core functions from Eric @XenAppBlog
    param
    (
        [string]$VMName, 
        [string]$GuestOSName
    )

    #Adding WSUS Drive 

    New-VHD -Path "$($VMPath)\$($GuestOSName) - WSUS Data 1.vhdx" -Dynamic -SizeBytes 400GB 
    Mount-VHD -Path "$($VMPath)\$($GuestOSName) - WSUS Data 1.vhdx"
    $DiskNumber = (Get-Diskimage -ImagePath "$($VMPath)\$($GuestOSName) - WSUS Data 1.vhdx").Number
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT 
    Get-Disk -Number $DiskNumber | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "WSUS" -Confirm:$False
    Dismount-VHD -Path "$($VMPath)\$($GuestOSName) - WSUS Data 1.vhdx"
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($GuestOSName) - WSUS Data 1.vhdx" -ControllerType SCSI
  



    Invoke-Command -VMName $VMName -Credential $domainCred {

        Get-Disk | Where-Object OperationalStatus -EQ "Offline" | Set-Disk -IsOffline $False 
        Get-Disk | Where-Object Number -NE "0" | Set-Disk -IsReadOnly $False
        $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object { $_.Label -like "WSUS*" }
        $WSUSDrive = $Driveletter.DriveLetter
    
        Install-WindowsFeature -Name UpdateServices -IncludeManagementTools
        Install-WindowsFeature -Name UpdateServices-Ui
        New-Item -Path $WSUSDrive -Name WSUS -ItemType Directory
        Set-Location "C:\Program Files\Update Services\Tools"
        .\wsusutil.exe postinstall "CONTENT_DIR=$($WSUSDrive)\WSUS"
        Write-Verbose "Get WSUS Server Object" -Verbose
        $wsus = Get-WSUSServer

        Write-Verbose "Connect to WSUS server configuration" -Verbose
        $wsusConfig = $wsus.GetConfiguration()

        Write-Verbose "Set to download updates from Microsoft Updates" -Verbose
        Set-WsusServerSynchronization -SyncFromMU

        Write-Verbose "Set Update Languages to English and save configuration settings" -Verbose
        $wsusConfig.AllUpdateLanguagesEnabled = $false           
        $wsusConfig.SetEnabledUpdateLanguages("en")           
        $wsusConfig.Save()

        Write-Verbose "Get WSUS Subscription and perform initial synchronization to get latest categories" -Verbose
        $subscription = $wsus.GetSubscription()
        $subscription.StartSynchronizationForCategoryOnly()

        While ($subscription.GetSynchronizationStatus() -ne 'NotProcessing') {
            Write-Host "." -NoNewline
            Start-Sleep -Seconds 5
        }

        Write-Verbose "Sync is Done" -Verbose

        Write-Verbose "Disable Products" -Verbose
        Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Office" } | Set-WsusProduct -Disable
        Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Windows" } | Set-WsusProduct -Disable
						
        Write-Verbose "Enable Products" -Verbose
        Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Windows Server 2016" } | Set-WsusProduct

        Write-Verbose "Disable Language Packs" -Verbose
        Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Language Packs" } | Set-WsusProduct -Disable

        Write-Verbose "Configure the Classifications" -Verbose

        Get-WsusClassification | Where-Object {
            $_.Classification.Title -in (
                'Critical Updates',
                'Definition Updates',
                'Feature Packs',
                'Security Updates',
                'Service Packs',
                'Update Rollups',
                'Updates')
        } | Set-WsusClassification

        Write-Verbose "Configure Synchronizations" -Verbose
        $subscription.SynchronizeAutomatically = $true

        Write-Verbose "Set synchronization scheduled for midnight each night" -Verbose
        $subscription.SynchronizeAutomaticallyTimeOfDay = (New-TimeSpan -Hours 0)
        $subscription.NumberOfSynchronizationsPerDay = 1
        $subscription.Save()

        Write-Verbose "Kick Off Synchronization" -Verbose
        $subscription.StartSynchronization()

        Write-Verbose "Monitor Progress of Synchronisation" -Verbose

        <#>Start-Sleep -Seconds 60 # Wait for sync to start before monitoring
	    while ($subscription.GetSynchronizationProgress().ProcessedItems -ne $subscription.GetSynchronizationProgress().TotalItems) {
		    #$subscription.GetSynchronizationProgress().ProcessedItems * 100/($subscription.GetSynchronizationProgress().TotalItems)
		    Start-Sleep -Seconds 5
   
	}
    </#>
    }


    #Restart-DemoVM $VMName
    
    #Wait-PSDirect $VMName -cred $DomainCred

    Invoke-Command -VMName $VMName -Credential $domainCred {
        #Change server name and port number and $True if it is on SSL

        $Computer = $env:COMPUTERNAME
        [String]$updateServer1 = $Computer
        [Boolean]$useSecureConnection = $False
        [Int32]$portNumber = 8530

        # Load .NET assembly

        [void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")

        $count = 0

        # Connect to WSUS Server

        $updateServer = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer($updateServer1, $useSecureConnection, $portNumber)

        write-host "<<<Connected sucessfully >>>" -foregroundcolor "yellow"

        $updatescope = New-Object Microsoft.UpdateServices.Administration.UpdateScope

        $u = $updateServer.GetUpdates($updatescope )

        foreach ($u1 in $u ) {

            if ($u1.IsSuperseded -eq 'True') {

                write-host Decline Update : $u1.Title

                $u1.Decline()

                $count = $count + 1

            }

        }

        write-host Total Declined Updates: $count

        trap {

            write-host "Error Occurred"

            write-host "Exception Message: "

            write-host $_.Exception.Message

            write-host $_.Exception.StackTrace

            exit

        }

        # EOF


    }
}
    
Function Install-NetNat {
    param
    (
        [string]$VMName, 
        [string]$GuestOSName
    )

    Write-Output -InputObject "[$($VMName)]:: Configuring NAT on the Hyper-V Internal Switch `"$($env:computername)`""
    $CheckNATSwitch = get-vmswitch | Where-Object Name -eq $virtualNATSwitchName | Select-Object Name

    If ($CheckNATSwitch -ne $null) {
        write-Host "Internal NAT Switch Found"
    }
    Else {
    
        write-Host "Not Found"
        Write-Host "Creating NAT Switch"

        New-VMSwitch -SwitchName $virtualNATSwitchName -SwitchType Internal 
        $ifindex = Get-NetAdapter | Where-Object Name -like *$virtualNATSwitchName* | New-NetIPAddress 192.168.10.1 -PrefixLength 24 
    
        Get-Netnat | Remove-NetNat -confirm:$false
        New-NetNat -Name $virtualNATSwitchName -InternalIPInterfaceAddressPrefix 192.168.10.0/24
               
    }
}

Function Install-RRAS {
    param
    (
        [string] $VMName, 
        [string] $GuestOSName,
        [string] $IPAddress
    ) 

    Add-VMNetworkAdapter -VMName $VMName -SwitchName $InternetVSwitch

    Invoke-Command -VMName $VMName -Credential $domainCred {
        Write-Output -InputObject "[$($VMName)]:: Setting InternetIP Address to 192.168.100.254"


  
        $null = New-NetIPAddress -IPAddress "192.168.100.254" -InterfaceAlias 'Ethernet 2' -PrefixLength 24
        $newroute = '192.168.100.1'
        Write-Output -InputObject "[$($VMName)]:: Configuring Default Gateway"
        $null = Get-Netroute | Where-Object DestinationPrefix -eq "0.0.0.0/0" | Remove-NetRoute -Confirm:$False
        #$null = Test-NetConnection localhost
        new-netroute -InterfaceAlias "Ethernet 2" -NextHop $newroute  -DestinationPrefix '0.0.0.0/0' -verbose
        $null = Get-NetAdapter | Where-Object name -EQ "Ethernet" | Rename-NetAdapter -NewName CorpNet
        $null = Get-NetAdapter | Where-Object name -EQ "Ethernet 2" | Rename-NetAdapter -NewName Internet
        Write-Output -InputObject "[$($VMName)]:: Installing RRAS"
        $null = Install-WindowsFeature -Name RemoteAccess, Routing, RSAT-RemoteAccess-Mgmt 
        #$null =  Stop-Service -Name WDSServer -ErrorAction SilentlyContinue
        #$null = Set-Service -Name WDSServer -StartupType Disabled -ErrorAction SilentlyContinue

        $ExternalInterface = "Internet"
        $InternalInterface = "CorpNet"
        Write-Output -InputObject "[$($VMName)]:: Coniguring RRAS - Adding Internal and External Adapters"
        $null = Start-Process -Wait:$true -FilePath "netsh" -ArgumentList "ras set conf ENABLED"
        $null = Set-Service -Name RemoteAccess -StartupType Automatic
        $null = Start-Service -Name RemoteAccess

        Write-Output -InputObject "[$($VMName)]:: Configuring NAT - Lab is now Internet Enabled"
        $null = Start-Process -Wait:$true -FilePath "netsh" -ArgumentList "routing ip nat install"
        $null = Start-Process -Wait:$true -FilePath "netsh" -ArgumentList "routing ip nat add interface ""CorpNet"""
        $null = Test-NetConnection 192.168.100.1
        $null = Test-NetConnection 4.2.2.2
        $null = cmd.exe /c "netsh routing ip nat add interface $externalinterface"
        $null = cmd.exe /c "netsh routing ip nat set interface $externalinterface mode=full"
        $null = Test-NetConnection 192.168.100.1
        # $null = Test-NetConnection $($Subnet)1
        $null = Test-NetConnection 4.2.2.2
        Write-Output -InputObject "[$($VMName)]:: Disable FireWall"
        $null = cmd.exe /c "netsh firewall set opmode disable"
      
    
    }
}

Function Create-SQLInstallFile {
    #You will need to modify this for your environment accounts
    #I have defaulted to MVPDays\svc_SQL and a password of P@ssw0rd
    #If you are changing in your lab adjust acordingly 
    #I will automate this later on.

    Write-Output -InputObject "[$($VMName)]:: Creating SQL Install INI File"
    $functionText = @"
;SQL Server 2016 Configuration File
[OPTIONS]
; Specifies a Setup work flow, like INSTALL, UNINSTALL, or UPGRADE. This is a required parameter. 
ACTION="Install"
; Specifies that SQL Server Setup should not display the privacy statement when ran from the command line. 
SUPPRESSPRIVACYSTATEMENTNOTICE="True"
IACCEPTSQLSERVERLICENSETERMS="True"
; By specifying this parameter and accepting Microsoft R Open and Microsoft R Server terms, you acknowledge that you have read and understood the terms of use. 
IACCEPTROPENLICENSETERMS="True"
; Use the /ENU parameter to install the English version of SQL Server on your localized Windows operating system. 
ENU="True"
; Setup will not display any user interface. 
QUIET="True"
; Setup will display progress only, without any user interaction. 
QUIETSIMPLE="False"
; Parameter that controls the user interface behavior. Valid values are Normal for the full UI,AutoAdvance for a simplied UI, and EnableUIOnServerCore for bypassing Server Core setup GUI block. 
;UIMODE="Normal"
; Specify whether SQL Server Setup should discover and include product updates. The valid values are True and False or 1 and 0. By default SQL Server Setup will include updates that are found. 
UpdateEnabled="True"
; If this parameter is provided, then this computer will use Microsoft Update to check for updates. 
USEMICROSOFTUPDATE="True"
; Specifies features to install, uninstall, or upgrade. The list of top-level features include SQL, AS, RS, IS, MDS, and Tools. The SQL feature will install the Database Engine, Replication, Full-Text, and Data Quality Services (DQS) server. The Tools feature will install shared components. 
FEATURES=SQLENGINE,RS,FULLTEXT
; Specify the location where SQL Server Setup will obtain product updates. The valid values are "MU" to search Microsoft Update, a valid folder path, a relative path such as .\MyUpdates or a UNC share. By default SQL Server Setup will search Microsoft Update or a Windows Update service through the Window Server Update Services. 
UpdateSource="MU"
; Displays the command line parameters usage 
HELP="False"
; Specifies that the detailed Setup log should be piped to the console. 
INDICATEPROGRESS="False"
; Specifies that Setup should install into WOW64. This command line argument is not supported on an IA64 or a 32-bit system. 
X86="False"
; Specify a default or named instance. MSSQLSERVER is the default instance for non-Express editions and SQLExpress for Express editions. This parameter is required when installing the SQL Server Database Engine (SQL), Analysis Services (AS), or Reporting Services (RS). 
INSTANCENAME="MSSQLSERVER"
; Specify the root installation directory for shared components.  This directory remains unchanged after shared components are already installed. 
INSTALLSHAREDDIR="E:\Program Files\Microsoft SQL Server"
; Specify the root installation directory for the WOW64 shared components.  This directory remains unchanged after WOW64 shared components are already installed. 
INSTALLSHAREDWOWDIR="E:\Program Files (x86)\Microsoft SQL Server"
; Specify the Instance ID for the SQL Server features you have specified. SQL Server directory structure, registry structure, and service names will incorporate the instance ID of the SQL Server instance. 
INSTANCEID="MSSQLSERVER"
; Specifies which mode report server is installed in.  
; Default value: “FilesOnly”  
RSINSTALLMODE="FilesOnlyMode"
; TelemetryUserNameConfigDescription 
SQLTELSVCACCT="NT Service\SQLTELEMETRY"
; TelemetryStartupConfigDescription 
SQLTELSVCSTARTUPTYPE="Automatic"
; Specify the installation directory. 
INSTANCEDIR="E:\Program Files\Microsoft SQL Server"
; Agent account name 
AGTSVCACCOUNT="SH\SVC_SQL_AGENT"
AGTSVCPASSWORD="P@ssw0rd"
; Auto-start service after installation.  
AGTSVCSTARTUPTYPE="Automatic"
; CM brick TCP communication port 
COMMFABRICPORT="0"
; How matrix will use private networks 
COMMFABRICNETWORKLEVEL="0"
; How inter brick communication will be protected 
COMMFABRICENCRYPTION="0"
; TCP port used by the CM brick 
MATRIXCMBRICKCOMMPORT="0"
; Startup type for the SQL Server service. 
SQLSVCSTARTUPTYPE="Automatic"
; Level to enable FILESTREAM feature at (0, 1, 2 or 3). 
FILESTREAMLEVEL="0"
; Set to "1" to enable RANU for SQL Server Express. 
ENABLERANU="False"
; Specifies a Windows collation or an SQL collation to use for the Database Engine. 
SQLCOLLATION="SQL_Latin1_General_CP1_CI_AS"
; Account for SQL Server service: Domain\User or system account. 
SQLSVCACCOUNT="SH\SVC_SQL"
SQLSVCPASSWORD="P@ssw0rd"
; Set to "True" to enable instant file initialization for SQL Server service. If enabled, Setup will grant Perform Volume Maintenance Task privilege to the Database Engine Service SID. This may lead to information disclosure as it could allow deleted content to be accessed by an unauthorized principal. 
SQLSVCINSTANTFILEINIT="True"
; Windows account(s) to provision as SQL Server system administrators. 
SQLSYSADMINACCOUNTS="SH\Domain Admins"
; The number of Database Engine TempDB files. 
SQLTEMPDBFILECOUNT="2"
; Specifies the initial size of a Database Engine TempDB data file in MB. 
SQLTEMPDBFILESIZE="8"
; Specifies the automatic growth increment of each Database Engine TempDB data file in MB. 
SQLTEMPDBFILEGROWTH="64"
; Specifies the initial size of the Database Engine TempDB log file in MB. 
SQLTEMPDBLOGFILESIZE="8"
; Specifies the automatic growth increment of the Database Engine TempDB log file in MB. 
SQLTEMPDBLOGFILEGROWTH="64"
; Provision current user as a Database Engine system administrator for %SQL_PRODUCT_SHORT_NAME% Express. 
ADDCURRENTUSERASSQLADMIN="False"
; Specify 0 to disable or 1 to enable the TCP/IP protocol. 
TCPENABLED="1"
; Specify 0 to disable or 1 to enable the Named Pipes protocol. 
NPENABLED="0"
; Startup type for Browser Service. 
BROWSERSVCSTARTUPTYPE="Disabled"
; Specifies which account the report server NT service should execute under.  When omitted or when the value is empty string, the default built-in account for the current operating system.
; The username part of RSSVCACCOUNT is a maximum of 20 characters long and
; The domain part of RSSVCACCOUNT is a maximum of 254 characters long. 
RSSVCACCOUNT="MVPDAYS\SVC_SQL_RS"
RSSVCPASSWORD="P@ssw0rd"
; Specifies how the startup mode of the report server NT service.  When 
; Manual - Service startup is manual mode (default).
; Automatic - Service startup is automatic mode.
; Disabled - Service is disabled 
RSSVCSTARTUPTYPE="Automatic"
FTSVCACCOUNT="MVPDAYS\SVC_SQL"
"@

    New-Item "$($WorkingDir)\SqlInstall.ini" -type file -force -value $functionText

}

Function Install-SQLDPM {
    <#
Created:	 2018-02-01
Version:	 1.0
Author       Dave Kawula MVP
Homepage:    http://www.checkyourlogs.net

Disclaimer:
This script is provided "AS IS" with no warranties, confers no rights and 
is not supported by the authors or CheckyourLogs or MVPDays Publishing

Author - Dave Kawula
    Twitter: @DaveKawula
    Blog   : http://www.checkyourlogs.net


    .Synopsis
    Deploys System Center SQL Server 2016 Instance to  a Hyper-V Lab VM
    .DESCRIPTION
    This Script was part of my BIGDemo series and I have broken it out into a standalone function

    You will need to have a SVC_SQL Pre-Created and SQL 2016 Media for this lab to work
    The Script will prompt for the path of the Files Required
    The Script will prompt for an Admin Account which will be used in $DomainCred
    If your File names are different than mine adjust accordingly.

    We will use PowerShell Direct to setup the Veeam Server in Hyper-V

    The Source Hyper-V Virtual Machine needs to be Windows Server 2016

    .EXAMPLE
    TODO: Dave, add something more meaningful in here
    .PARAMETER WorkingDir
    Transactional directory for files to be staged and written
    .PARAMETER VMname
    The name of the Virtual Machine
    .PARAMETER VMPath
    The Path to the VM Working Folder - We create a new VHDx for the DPM Install
    .PARAMETER GuestOSName
    Name of the Guest Operating System Name
    

    Usage: Install-DPM -Vmname YOURVM -GuestOS VEEAMSERVER -VMpath f:\VMs\SCVMM -WorkingDir f:\Temp 
#>
    #Installs SCVMM 1801 for your lab

    param
    (
        [string]$VMName, 
        [string]$GuestOSName,
        [string]$VMPath
   

    )
     

    #$DomainCred = Get-Credential
    #$VMName = 'DPM01'
    #$GuestOSname = 'DPM01'
    #$VMPath = 'f:\dcbuild_Test\VMs'
    #$SQL = 'VMM01\MSSQLSERVER'
    #$SCOMDrive = 'd:'

   
     
    Invoke-Command -VMName $VMName -Credential $DomainCred {

        Write-Output -InputObject "[$($VMName)]:: Configure DPM Service Account as a Local Admin"

        # Add-LocalGroupMember -Group Administrators -Member $DPMServiceAcct

    
        Write-Output -InputObject "[$($VMName)]:: Enable .Net Framework 3.5"

        Dism.exe /Online /Enable-Feature /FeatureName:NetFx3 /All /Source:$setup1\sources\sxs

     
    }

    Restart-DemoVM -VMName $VMname
    Wait-PSDirect -VMName $VMName -cred $DomainCred



    Write-Output -InputObject "[$($VMName)]:: Adding Drive for DPM Install"

    New-VHD -Path "$($VMPath)\$($GuestOSName) - SQL Data 2.vhdx" -Dynamic -SizeBytes 50GB 
    Mount-VHD -Path "$($VMPath)\$($GuestOSName) - SQL Data 2.vhdx" 
    $DiskNumber = (Get-Diskimage -ImagePath "$($VMPath)\$($GuestOSName) - SQL Data 2.vhdx").Number
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT 
    Get-Disk -Number $DiskNumber | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "SQL" -Confirm:$False
    $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object { $_.Label -like "SQL*" }
    $SQLDriveLetter = $DriveLetter.DriveLetter
    Write-Output -InputObject "[$($VMName)]:: Copying SQL ISO to the new VHDx"
    Copy-Item -Path "$($WorkingDir)\en_sql_server_2016_standard_with_service_pack_1_x64_dvd_9540929.iso" -Destination "$($SQLDriveLetter)\en_sql_server_2016_standard_with_service_pack_1_x64_dvd_9540929.iso" -Force
    Write-Output -InputObject "[$($VMName)]:: Copying SSMS to the new VHDx"
    Copy-Item -Path "$($WorkingDir)\SSMS-Setup-ENU-16.5.exe" -Destination "$($SQLDriveLetter)\SSMS-Setup-ENU.exe" -Force
    Dismount-VHD -Path "$($VMPath)\$($GuestOSName) - SQL Data 2.vhdx"
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($GuestOSName) - SQL Data 2.vhdx" -ControllerType SCSI
  


    Invoke-Command -VMName $VMName -Credential $domainCred {
      
        Write-Output -InputObject "[$($VMName)]:: Adding the new VHDx for the SQL Install"
        Get-Disk | Where-Object OperationalStatus -EQ "Offline" | Set-Disk -IsOffline $False 
        Get-Disk | Where-Object Number -NE "0" | Set-Disk -IsReadOnly $False
        $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object { $_.Label -like "SQL*" }
        $SQLDrive = $Driveletter.DriveLetter

        Write-Output -InputObject "[$($VMName)]:: Mounting SQL ISO"

        $iso = Get-ChildItem -Path "$($SQLDrive)\en_sql_server_2016_standard_with_service_pack_1_x64_dvd_9540929.iso"  #CHANGE THIS!

        Mount-DiskImage $iso.FullName

        $setup = $(Get-DiskImage -ImagePath $iso.FullName | Get-Volume).DriveLetter + ':' 
        $setup

        Write-Output -InputObject "[$($VMName)]:: Mounting WS2016 ISO"

        $iso = Get-ChildItem -Path "$($DPMDrive)\en_windows_server_2016_x64_dvd_9718492.iso"  #CHANGE THIS!

        Mount-DiskImage $iso.FullName

        $setup1 = $(Get-DiskImage -ImagePath $iso.FullName | Get-Volume).DriveLetter + ':' 
        $setup1
    

        #You will need to modify this for your environment accounts
        #I have defaulted to MVPDays\svc_SQL and a password of P@ssw0rd
        #If you are changing in your lab adjust acordingly 
        #I will automate this later on.

        Write-Output -InputObject "[$($VMName)]:: Creating SQL Install INI File"
        $functionText = @"
;SQL Server 2016 Configuration File
[OPTIONS]
; Specifies a Setup work flow, like INSTALL, UNINSTALL, or UPGRADE. This is a required parameter. 
ACTION="Install"
; Specifies that SQL Server Setup should not display the privacy statement when ran from the command line. 
SUPPRESSPRIVACYSTATEMENTNOTICE="True"
IACCEPTSQLSERVERLICENSETERMS="True"
; By specifying this parameter and accepting Microsoft R Open and Microsoft R Server terms, you acknowledge that you have read and understood the terms of use. 
IACCEPTROPENLICENSETERMS="True"
; Use the /ENU parameter to install the English version of SQL Server on your localized Windows operating system. 
ENU="True"
; Setup will not display any user interface. 
QUIET="True"
; Setup will display progress only, without any user interaction. 
QUIETSIMPLE="False"
; Parameter that controls the user interface behavior. Valid values are Normal for the full UI,AutoAdvance for a simplied UI, and EnableUIOnServerCore for bypassing Server Core setup GUI block. 
;UIMODE="Normal"
; Specify whether SQL Server Setup should discover and include product updates. The valid values are True and False or 1 and 0. By default SQL Server Setup will include updates that are found. 
UpdateEnabled="True"
; If this parameter is provided, then this computer will use Microsoft Update to check for updates. 
USEMICROSOFTUPDATE="True"
; Specifies features to install, uninstall, or upgrade. The list of top-level features include SQL, AS, RS, IS, MDS, and Tools. The SQL feature will install the Database Engine, Replication, Full-Text, and Data Quality Services (DQS) server. The Tools feature will install shared components. 
FEATURES=SQLENGINE,RS,FULLTEXT
; Specify the location where SQL Server Setup will obtain product updates. The valid values are "MU" to search Microsoft Update, a valid folder path, a relative path such as .\MyUpdates or a UNC share. By default SQL Server Setup will search Microsoft Update or a Windows Update service through the Window Server Update Services. 
UpdateSource="MU"
; Displays the command line parameters usage 
HELP="False"
; Specifies that the detailed Setup log should be piped to the console. 
INDICATEPROGRESS="False"
; Specifies that Setup should install into WOW64. This command line argument is not supported on an IA64 or a 32-bit system. 
X86="False"
; Specify a default or named instance. MSSQLSERVER is the default instance for non-Express editions and SQLExpress for Express editions. This parameter is required when installing the SQL Server Database Engine (SQL), Analysis Services (AS), or Reporting Services (RS). 
INSTANCENAME="MSSQLSERVER"
; Specify the root installation directory for shared components.  This directory remains unchanged after shared components are already installed. 
INSTALLSHAREDDIR="$SQLDrive\Program Files\Microsoft SQL Server"
; Specify the root installation directory for the WOW64 shared components.  This directory remains unchanged after WOW64 shared components are already installed. 
INSTALLSHAREDWOWDIR="$SQLDrive\Program Files (x86)\Microsoft SQL Server"
; Specify the Instance ID for the SQL Server features you have specified. SQL Server directory structure, registry structure, and service names will incorporate the instance ID of the SQL Server instance. 
INSTANCEID="MSSQLSERVER"
; Specifies which mode report server is installed in.  
; Default value: “FilesOnly”  
RSINSTALLMODE="DefaultNativeMode"
; TelemetryUserNameConfigDescription 
SQLTELSVCACCT="NT Service\SQLTELEMETRY"
; TelemetryStartupConfigDescription 
SQLTELSVCSTARTUPTYPE="Automatic"
; Specify the installation directory. 
INSTANCEDIR="$SQLDrive\Program Files\Microsoft SQL Server"
; Agent account name 
AGTSVCACCOUNT="MVPDAYS\SVC_SQL"
AGTSVCPASSWORD="P@ssw0rd"
; Auto-start service after installation.  
AGTSVCSTARTUPTYPE="Automatic"
; CM brick TCP communication port 
COMMFABRICPORT="0"
; How matrix will use private networks 
COMMFABRICNETWORKLEVEL="0"
; How inter brick communication will be protected 
COMMFABRICENCRYPTION="0"
; TCP port used by the CM brick 
MATRIXCMBRICKCOMMPORT="0"
; Startup type for the SQL Server service. 
SQLSVCSTARTUPTYPE="Automatic"
; Level to enable FILESTREAM feature at (0, 1, 2 or 3). 
FILESTREAMLEVEL="0"
; Set to "1" to enable RANU for SQL Server Express. 
ENABLERANU="False"
; Specifies a Windows collation or an SQL collation to use for the Database Engine. 
SQLCOLLATION="SQL_Latin1_General_CP1_CI_AS"
; Account for SQL Server service: Domain\User or system account. 
SQLSVCACCOUNT="MVPDAYS\SVC_SQL"
SQLSVCPASSWORD="P@ssw0rd"
; Set to "True" to enable instant file initialization for SQL Server service. If enabled, Setup will grant Perform Volume Maintenance Task privilege to the Database Engine Service SID. This may lead to information disclosure as it could allow deleted content to be accessed by an unauthorized principal. 
SQLSVCINSTANTFILEINIT="True"
; Windows account(s) to provision as SQL Server system administrators. 
SQLSYSADMINACCOUNTS="MVPDays\Domain Admins"
; The number of Database Engine TempDB files. 
SQLTEMPDBFILECOUNT="2"
; Specifies the initial size of a Database Engine TempDB data file in MB. 
SQLTEMPDBFILESIZE="8"
; Specifies the automatic growth increment of each Database Engine TempDB data file in MB. 
SQLTEMPDBFILEGROWTH="64"
; Specifies the initial size of the Database Engine TempDB log file in MB. 
SQLTEMPDBLOGFILESIZE="8"
; Specifies the automatic growth increment of the Database Engine TempDB log file in MB. 
SQLTEMPDBLOGFILEGROWTH="64"
; Provision current user as a Database Engine system administrator for %SQL_PRODUCT_SHORT_NAME% Express. 
ADDCURRENTUSERASSQLADMIN="False"
; Specify 0 to disable or 1 to enable the TCP/IP protocol. 
TCPENABLED="1"
; Specify 0 to disable or 1 to enable the Named Pipes protocol. 
NPENABLED="0"
; Startup type for Browser Service. 
BROWSERSVCSTARTUPTYPE="Disabled"
; Specifies which account the report server NT service should execute under.  When omitted or when the value is empty string, the default built-in account for the current operating system.
; The username part of RSSVCACCOUNT is a maximum of 20 characters long and
; The domain part of RSSVCACCOUNT is a maximum of 254 characters long. 
RSSVCACCOUNT="MVPDAYS\SVC_SQL"
RSSVCPASSWORD="P@ssw0rd"
; Specifies how the startup mode of the report server NT service.  When 
; Manual - Service startup is manual mode (default).
; Automatic - Service startup is automatic mode.
; Disabled - Service is disabled 
RSSVCSTARTUPTYPE="Automatic"
FTSVCACCOUNT="MVPDAYS\SVC_SQL"
"@

        New-Item "$($SQLDrive)\SqlInstall.ini" -type file -force -value $functionText

        Write-Output -InputObject "[$($VMName)]:: Configuring WIndows Firewall for SQL New Rules"
        New-NetFirewallRule -DisplayName "SQL 2016 Exceptions-TCP" -Direction Inbound -Protocol TCP -Profile Domain -LocalPort 135, 1433, 1434, 4088, 80, 443 -Action Allow
 

        Write-Output -InputObject "[$($VMName)]:: Running SQL Unattended Install"

        $setup = $(Get-DiskImage -ImagePath $iso.FullName | Get-Volume).DriveLetter + ':' 
        $setup
        cmd.exe /c "$($Setup)\setup.exe /ConfigurationFile=$($SQLDrive)\SqlInstall.ini"
        

        # run installer with arg-list built above, including config file and service/SA accounts

        #Start-Process -Verb runas -FilePath $setup -ArgumentList $arglist -Wait


        # Write-Output -InputObject "[$($VMName)]:: Downloading SSMS"
        #Invoke-Webrequest was REALLY SLOW
        #Invoke-webrequest -uri https://go.microsoft.com/fwlink/?linkid=864329 -OutFile "$($SQLDrive)\SSMS-Setup-ENU.exe"
        #Changing to System.Net.WebClient
        # (New-Object System.Net.WebClient).DownloadFile("https://go.microsoft.com/fwlink/?linkid=864329","$($SQLDrive)\SSMS-Setup-ENU.exe")    



        # You can grab SSMS here:    https://docs.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms



        Start-Transcript -Path "$($SQLDrive)\SSMS-Install.log"



        $StartDateTime = get-date

        Write-Output -InputObject "[$($VMName)]:: Script started at $StartDateTime"

        #$setupfile = "$($VMMDrive)\SSMS-Setup-ENU.exe"
        Write-Output -InputObject "[$($VMName)]:: Installing SSMS"

        cmd.exe /c "$($SQLDrive)\SSMS-Setup-ENU.exe /install /quiet /norestart /log $($SQLDrive)\ssmssetup.log"

        Stop-Transcript

        # un-mount the install image when done after waiting 1 second (just for kicks)

        Start-Sleep -Seconds 1

        Dismount-DiskImage $iso.FullName
    
    }

    Restart-DemoVM -VMName $VMName
    Wait-PSDirect -VMName $VMName -cred $DomainCred

}

Function Install-SQL {
    #Installs SQL Server 2016 in the Lab
    param
    (
        [string]$VMName, 
        [string]$GuestOSName
    )

    Write-Output -InputObject "[$($VMName)]:: Adding Drive for SQL Install"

    New-VHD -Path "$($VMPath)\$($GuestOSName) - SQL Data 1.vhdx" -Dynamic -SizeBytes 60GB 
    Mount-VHD -Path "$($VMPath)\$($GuestOSName) - SQL Data 1.vhdx"
    $DiskNumber = (Get-Diskimage -ImagePath "$($VMPath)\$($GuestOSName) - SQL Data 1.vhdx").Number
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT 
    Get-Disk -Number $DiskNumber | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "SQLInstall" -Confirm:$False
    $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object { $_.Label -like "SQLInstall*" }
    New-VHD -Path "$($VMPath)\$($GuestOSName) - SQL Data 2.vhdx" -Dynamic -SizeBytes 400GB 
    Mount-VHD -Path "$($VMPath)\$($GuestOSName) - SQL Data 2.vhdx"
    $DiskNumber = (Get-Diskimage -ImagePath "$($VMPath)\$($GuestOSName) - SQL Data 2.vhdx").Number
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT 
    Get-Disk -Number $DiskNumber | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "SQLData" -AllocationUnitSize "65536" -Confirm:$False
    New-VHD -Path "$($VMPath)\$($GuestOSName) - SQL Data 3.vhdx" -Dynamic -SizeBytes 100GB 
    Mount-VHD -Path "$($VMPath)\$($GuestOSName) - SQL Data 3.vhdx"
    $DiskNumber = (Get-Diskimage -ImagePath "$($VMPath)\$($GuestOSName) - SQL Data 3.vhdx").Number
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT 
    Get-Disk -Number $DiskNumber | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "SQLLOG" -AllocationUnitSize "65536" -Confirm:$False
    New-VHD -Path "$($VMPath)\$($GuestOSName) - SQL Data 4.vhdx" -Dynamic -SizeBytes 30GB 
    Mount-VHD -Path "$($VMPath)\$($GuestOSName) - SQL Data 4.vhdx"
    $DiskNumber = (Get-Diskimage -ImagePath "$($VMPath)\$($GuestOSName) - SQL Data 4.vhdx").Number
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT 
    Get-Disk -Number $DiskNumber | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "TEMPDB" -AllocationUnitSize "65536" -Confirm:$False
    New-VHD -Path "$($VMPath)\$($GuestOSName) - SQL Data 5.vhdx" -Dynamic -SizeBytes 30GB 
    Mount-VHD -Path "$($VMPath)\$($GuestOSName) - SQL Data 5.vhdx"
    $DiskNumber = (Get-Diskimage -ImagePath "$($VMPath)\$($GuestOSName) - SQL Data 5.vhdx").Number
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT 
    Get-Disk -Number $DiskNumber | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "TEMPLOG" -AllocationUnitSize "65536" -Confirm:$False
    $SQLDriveLetter = $DriveLetter.DriveLetter
    Write-Output -InputObject "[$($VMName)]:: Copying SQL ISO to the new VHDx"
    Copy-Item -Path "$($WorkingDir)\en_sql_server_2016_standard_with_service_pack_1_x64_dvd_9540929.iso" -Destination "$($SQLDriveLetter)\en_sql_server_2016_standard_with_service_pack_1_x64_dvd_9540929.iso" -Force
    Write-Output -InputObject "[$($VMName)]:: Copying SQLInstall.ini to the new VHDx"
    Copy-Item -Path "$($WorkingDir)\SQLInstall.ini" -Destination "$($SQLDriveLetter)\SQLInstall.ini" -Force
    Write-Output -InputObject "[$($VMName)]:: Copying SSMS to the new VHDx"
    Copy-Item -Path "$($WorkingDir)\SSMS-Setup-ENU.exe" -Destination "$($SQLDriveLetter)\SSMS-Setup-ENU.exe" -Force
    Dismount-VHD -Path "$($VMPath)\$($GuestOSName) - SQL Data 1.vhdx"
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($GuestOSName) - SQL Data 1.vhdx" -ControllerType SCSI
  

     
    Invoke-Command -VMName $VMName -Credential $domainCred {

        Write-Output -InputObject "[$($VMName)]:: Adding the new VHDx for the SQL Install"
        Get-Disk | Where-Object OperationalStatus -EQ "Offline" | Set-Disk -IsOffline $False 
        Get-Disk | Where-Object Number -NE "0" | Set-Disk -IsReadOnly $False
        $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object { $_.Label -like "SQL*" }
        $SQLDrive = $Driveletter.DriveLetter
        $SQLDrive

        Write-Output -InputObject "[$($VMName)]:: Mounting SQL ISO"

        $iso = Get-ChildItem -Path "$($SQLDrive)\en_sql_server_2016_standard_with_service_pack_1_x64_dvd_9540929.iso"  #CHANGE THIS!

        Mount-DiskImage $iso.FullName

        Write-Output -InputObject "[$($VMName)]:: Configuring WIndows Firewall for SQL New Rules"
        New-NetFirewallRule -DisplayName "SQL 2016 Exceptions-TCP" -Direction Inbound -Protocol TCP -Profile Domain -LocalPort 135, 1433, 1434, 4088, 80, 443 -Action Allow
 

        Write-Output -InputObject "[$($VMName)]:: Running SQL Unattended Install"

        $setup = $(Get-DiskImage -ImagePath $iso.FullName | Get-Volume).DriveLetter + ':' 
        $setup
        cmd.exe /c "$($Setup)\setup.exe /ConfigurationFile=$($SQLDrive)\SqlInstall.ini"
    }

    # run installer with arg-list built above, including config file and service/SA accounts

    #Start-Process -Verb runas -FilePath $setup -ArgumentList $arglist -Wait


    Write-Output -InputObject "[$($VMName)]:: Downloading SSMS"
    #Invoke-Webrequest was REALLY SLOW
    #Invoke-webrequest -uri https://go.microsoft.com/fwlink/?linkid=864329 -OutFile "$($SQLDrive)\SSMS-Setup-ENU.exe"
    #Changing to System.Net.WebClient
    # (New-Object System.Net.WebClient).DownloadFile("https://go.microsoft.com/fwlink/?linkid=864329","$($SQLDrive)\SSMS-Setup-ENU.exe")    



    # You can grab SSMS here:    https://docs.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms



    Start-Transcript -Path "$($SQLDrive)\SSMS-Install.log"



    $StartDateTime = get-date

    Write-Output -InputObject "[$($VMName)]:: Script started at $StartDateTime"

    #$setupfile = "$($VMMDrive)\SSMS-Setup-ENU.exe"
    Write-Output -InputObject "[$($VMName)]:: Installing SSMS"

    cmd.exe /c "$($SQLDrive)\SSMS-Setup-ENU.exe /install /quiet /norestart /log .\ssmssetup.log"

    Stop-Transcript

    # un-mount the install image when done after waiting 1 second (just for kicks)

    Start-Sleep -Seconds 1

    Dismount-DiskImage $iso.FullName
    
}
    
Function Install-VMM {
    #Installs VMM 1801 in the Lab
    param
    (
        [string]$VMName, 
        [string]$GuestOSName,
        [string]$VMMDomain
    )

    Write-Output -InputObject "[$($VMName)]:: Adding Drive for VMM Install"

    New-VHD -Path "$($VMPath)\$($GuestOSName) - VMM Data 2.vhdx" -Dynamic -SizeBytes 50GB 
    Mount-VHD -Path "$($VMPath)\$($GuestOSName) - VMM Data 2.vhdx" 
    $DiskNumber = (Get-Diskimage -ImagePath "$($VMPath)\$($GuestOSName) - VMM Data 2.vhdx").Number
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT 
    Get-Disk -Number $DiskNumber | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "VMM" -Confirm:$False
    $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object { $_.Label -like "VMM*" }
    $VMMDriveLetter = $DriveLetter.DriveLetter
    Write-Output -InputObject "[$($VMName)]:: Copying VMM 1801 EXE to the new VHDx"
    Copy-Item -Path "$($WorkingDir)\SCVMM_1801.exe" -Destination "$($VMMDriveLetter)\SCVMM_1801.exe" -Force
    Write-Output -InputObject "[$($VMName)]:: Copying ADK to the new VHDx"
    Copy-Item -Path "$($WorkingDir)\adksetup.exe" -Destination "$($VMMDriveLetter)\adksetup.exe" -Force
    Dismount-VHD -Path "$($VMPath)\$($GuestOSName) - VMM Data 2.vhdx"
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($GuestOSName) - VMM Data 2.vhdx" -ControllerType SCSI
  

    Invoke-Command -VMName $VMName -Credential $domainCred {

        Write-Output -InputObject "[$($VMName)]:: Adding the new VHDx for the VMM Install"
        Get-Disk | Where-Object OperationalStatus -EQ "Offline" | Set-Disk -IsOffline $False 
        Get-Disk | Where-Object Number -NE "0" | Set-Disk -IsReadOnly $False
        $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object { $_.Label -like "VMM*" }
        $VMMDrive = $Driveletter.DriveLetter

        Write-Output -InputObject "[$($VMName)]:: Downloading ADK"
        #Invoke-webrequest -uri https://go.microsoft.com/fwlink/p/?linkid=859206 -OutFile "$($VMMDrive)\adksetup.exe"
        # (New-Object System.Net.WebClient).DownloadFile("https://go.microsoft.com/fwlink/p/?linkid=859206","f:\iso\adksetup.exe")

        #Sample ADK install



        # You can grab ADK here:     https://msdn.microsoft.com/en-us/windows/hardware/dn913721.aspx



        Start-Transcript -Path "$($VMMDrive)\ADK_Install.log"



        $StartDateTime = get-date

        Write-Output -InputObject "[$($VMName)]:: Script started at $StartDateTime"

        $setupfile = "$($VMMDrive)\ADKsetup.exe"
        
        Write-Output -InputObject "[$($VMName)]:: Installing ADK..."

        Write-Output -InputObject "[$($VMName)]:: ADK Is being installed..."
  
        Start-Process -Wait -FilePath $setupfile -ArgumentList "/features OptionID.DeploymentTools OptionID.WindowsPreinstallationEnvironment /quiet"

        Write-Output -InputObject "[$($VMName)]:: ADK install finished at $(Get-date) and took $(((get-date) - $StartDateTime).TotalMinutes) Minutes"

        
        Stop-Transcript

        

        Start-Transcript -Path "$($VMmDrive)\SCVMM_Install.log"



        $StartDateTime = get-date

        $null = Get-Service MSSQLServer | Start-Service

        $Null = cmd.exe /c "$($VMMDrive)\SCVMM_1801.exe /dir=$($vmmdrive)\SCVMM /silent"

        Write-Output -InputObject "[$($VMName)]:: Waiting for VMM Install to Extract"
        Start-Sleep 120

        $setupfile = "$($VMMDrive)\SCVMM\setup.exe"
        Write-Output -InputObject "[$($VMName)]:: Installing VMM"

        



        ###Get workdirectory###

        #Install VMM
        $unattendFile = New-Item "$($VMMDrive)\VMServer.ini" -type File

        $FileContent = @"
        [OPTIONS]

        CompanyName=MVPDays

        CreateNewSqlDatabase=1

        SqlInstanceName=MSSQLSERVER

        SqlDatabaseName=VirtualManagerDB

        SqlMachineName=VMM01

        LibrarySharePath=$($VMMDrive)\MSCVMMLibrary

        ProgramFiles=$($VMMDrive)\Program Files\Microsoft System Center\Virtual Machine Manager

        LibraryShareName=MSSCVMMLibrary

        SQMOptIn = 1

        MUOptIn = 1
"@
        
        Set-Content $unattendFile $fileContent

        Write-Output -InputObject "[$($VMName)]:: VMM Is Being Installed"

        Get-Service MSSQLServer | Start-Service -WarningAction SilentlyContinue

        #02/13/2018 - DK $VMMDomain isn't quite working yet so I hard coded to MVPDays for now to get it working.

        cmd.exe /c "$vmmdrive\scvmm\setup.exe /server /i /f $VMMDrive\VMServer.ini /IACCEPTSCEULA /VmmServiceDomain MVPDays /VmmServiceUserName SVC_VMM /VmmServiceUserPassword P@ssw0rd"

        do {

            Start-Sleep 1

        }until ((Get-Process | Where-Object { $_.Description -eq "SetupVM" } -ErrorAction SilentlyContinue) -eq $null)

        Write-Output -InputObject "[$($VMName)]:: VMM has been Installed"



        Stop-Transcript

       
    }

}

Function Install-SCOM {

    #Installs VMM 1801 in the Lab
    param
    (
        [string]$VMName, 
        [string]$GuestOSName,
        [string]$VMMDomain
    )

    Write-Output -InputObject "[$($VMName)]:: Adding Drive for SCOM Install"

    New-VHD -Path "$($VMPath)\$($GuestOSName) - SCOM Data 1.vhdx" -Dynamic -SizeBytes 50GB 
    Mount-VHD -Path "$($VMPath)\$($GuestOSName) - SCOM Data 1.vhdx" 
    $DiskNumber = (Get-Diskimage -ImagePath "$($VMPath)\$($GuestOSName) - SCOM Data 1.vhdx").Number
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT 
    Get-Disk -Number $DiskNumber | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "SCOM" -Confirm:$False
    $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object { $_.Label -like "SCOM*" }
    $SCOMDriveLetter = $DriveLetter.DriveLetter
    Write-Output -InputObject "[$($VMName)]:: Copying SCOM 1801 EXE to the new VHDx"
    Copy-Item -Path "$($WorkingDir)\SCOM_1801_EN.exe" -Destination "$($SCOMDriveLetter)\SCOM_1801_EN.exe" -Force
    Dismount-VHD -Path "$($VMPath)\$($GuestOSName) - SCOM Data 1.vhdx"    
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($GuestOSName) - SCOM Data 1.vhdx" -ControllerType SCSI
  

    Invoke-Command -VMName $VMName -Credential $domainCred {

        Write-Output -InputObject "[$($VMName)]:: Adding the new VHDx for the SCOM Install"
        Get-Disk | Where-Object OperationalStatus -EQ "Offline" | Set-Disk -IsOffline $False 
        Get-Disk | Where-Object Number -NE "0" | Set-Disk -IsReadOnly $False
        $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object { $_.Label -like "SCOM*" }
        $SCOMDrive = $Driveletter.DriveLetter



        Write-Output -InputObject "[$($VMName)]:: Downloading SQLSysCLRTypes.MSI"

        #  SQLSysClrTypes: https://download.microsoft.com/download/1/3/0/13089488-91FC-4E22-AD68-5BE58BD5C014/ENU/x64/SQLSysClrTypes.msi
        Invoke-webrequest -uri https://download.microsoft.com/download/1/3/0/13089488-91FC-4E22-AD68-5BE58BD5C014/ENU/x64/SQLSysClrTypes.msi -OutFile "$($SCOMDrive)\SQLSysClrTypes.msi"


        Write-Output -InputObject "[$($VMName)]:: Downloading ReportViewer.msi"
        #ReportViewer: http://download.microsoft.com/download/F/B/7/FB728406-A1EE-4AB5-9C56-74EB8BDDF2FF/ReportViewer.msi

        Invoke-webrequest -uri http://download.microsoft.com/download/A/1/2/A129F694-233C-4C7C-860F-F73139CF2E01/ENU/x86/ReportViewer.msi -OutFile "$($SCOMDrive)\ReportViewer.msi"
        #Invoke-webrequest -uri https://go.microsoft.com/fwlink/p/?linkid=859206 -OutFile "$($VMMDrive)\adksetup.exe"
        # (New-Object System.Net.WebClient).DownloadFile("https://go.microsoft.com/fwlink/p/?linkid=859206","f:\iso\adksetup.exe")

        #Sample ADK install


        Write-Output -InputObject "[$($VMName)]:: Enabling Feature AuthManager"
        dism /online /enable-feature /featurename:AuthManager 

        Write-Output -InputObject "[$($VMName)]:: Enabling Other Features for SCOM 1801"
        Add-WindowsFeature Web-Static-Content, Web-Default-Doc, Web-Dir-Browsing, Web-Http-Errors, Web-Http-Logging, Web-Request-Monitor, Web-Filtering, Web-Stat-Compression, Web-Metabase, Web-Asp-Net, Web-Windows-Auth, Web-ASP, Web-CGI


        Add-WindowsFeature NET-WCF-HTTP-Activation45

        Write-Output -InputObject "[$($VMName)]:: Installing SQLSYSCLRTypes"
        cmd.exe /c "msiexec /i $SCOMDrive\SQLSysClrTypes.msi /q"

        Write-Output -InputObject "[$($VMName)]:: Installing ReportViewer"
        cmd.exe /c "msiexec /i $SCOMDrive\ReportViewer.msi /q"


        Write-Output -InputObject "[$($VMName)]:: Extracting SCOM 1801"
        $Null = cmd.exe /c "$($SCOMDrive)\SCOM_1801_EN.exe /dir=$($SCOMdrive)\SCOM /silent"

        Write-Output -InputObject "[$($VMName)]:: Installing SCOM 1801"
        cmd.exe /c "$SCOMDrive\SCOM\setup.exe /install /components:OMServer,OMWebConsole,OMConsole /ManagementGroupName:MVPDays /SqlServerInstance:VMM01\MSSQLSERVER /DatabaseName:OperationsManager /DWSqlServerInstance:VMM01\MSSQLSERVER /DWDatabaseName:OperationsManagerDW /ActionAccountUser:MVPDays\svc_omsvc /ActionAccountPassword:P@ssw0rd /DASAccountUser:MVPDays\svc_omaccess /DASAccountPassword:P@ssw0rd /DataReaderUser:MVPDays\svc_omreader /DataReaderPassword:P@ssw0rd /DataWriterUser:MVPDays\svc_omwriter /DataWriterPassword:P@ssw0rd /WebSiteName:""Default Web Site"" /WebConsoleAuthorizationMode:Mixed /EnableErrorReporting:Always /SendCEIPReports:1 /UseMicrosoftUpdate:1 /AcceptEndUserLicenseAgreement:1 /silent "

    }
}

Function Install-DPM {

    <#
Created:	 2018-02-01
Version:	 1.0
Author       Dave Kawula MVP
Homepage:    http://www.checkyourlogs.net

Disclaimer:
This script is provided "AS IS" with no warranties, confers no rights and 
is not supported by the authors or CheckyourLogs or MVPDays Publishing

Author - Dave Kawula
    Twitter: @DaveKawula
    Blog   : http://www.checkyourlogs.net


    .Synopsis
    Deploys System Center Data Protection Manager (DPM )1801 Server to a Hyper-V Lab VM
    .DESCRIPTION
    This Script was part of my BIGDemo series and I have broken it out into a standalone function

    You will need to have a SCVMM Service Accounts Pre-Created and DPM 1801 Trial Media for this lab to work
    The Script will prompt for the path of the Files Required
    The Script will prompt for an Admin Account which will be used in $DomainCred
    If your File names are different than mine adjust accordingly.

    We will use PowerShell Direct to setup the Veeam Server in Hyper-V

    The Source Hyper-V Virtual Machine needs to be Windows Server 2016

    .EXAMPLE
    TODO: Dave, add something more meaningful in here
    .PARAMETER WorkingDir
    Transactional directory for files to be staged and written
    .PARAMETER VMname
    The name of the Virtual Machine
    .PARAMETER VMPath
    The Path to the VM Working Folder - We create a new VHDx for the DPM Install
    .PARAMETER GuestOSName
    Name of the Guest Operating System Name
    

    Usage: Install-DPM -Vmname YOURVM -GuestOS VEEAMSERVER -VMpath f:\VMs\SCVMM -WorkingDir f:\Temp 
#>
    #Installs SCVMM 1801 for your lab

  
    param
    (
        [string]$VMName, 
        [string]$GuestOSName,
        [string]$VMPath
   

    )
     

    #$DomainCred = Get-Credential
    #$VMName = 'DPM01'
    #$GuestOSname = 'DPM01'
    #$VMPath = 'f:\dcbuild_Test\VMs'
    #$SQL = 'VMM01\MSSQLSERVER'
    #$SCOMDrive = 'd:'


    Invoke-Command -VMName $VMName -Credential $DomainCred {

        Write-Output -InputObject "[$($VMName)]:: Configure DPM Service Account as a Local Admin"

        # Add-LocalGroupMember -Group Administrators -Member $DPMServiceAcct

    
        Write-Output -InputObject "[$($VMName)]:: Disable Server Manager"

        Get-ScheduledTask -Taskname Servermanager | Disable-ScheduledTask

        Write-Output -InputObject "[$($VMName)]:: Enable Netadapter RSS"

        Enable-NetAdapterRss -Name *

        Write-Output -InputObject "[$($VMName)]:: Add Hyper-V PowerShell Features"

        Dism.exe /Online /Enable-Feature /FeatureName:Microsoft-Hyper-V /FeatureName:microsoft-Hyper-V-Management-PowerShell /quiet 


    }

    Restart-DemoVM -VMName $VMname
    Wait-PSDirect -VMName $VMName -cred $DomainCred


    Write-Output -InputObject "[$($VMName)]:: Adding Drive for DPM Install"

    New-VHD -Path "$($VMPath)\$($GuestOSName) - DPM Data 5.vhdx" -Dynamic -SizeBytes 50GB 
    Mount-VHD -Path "$($VMPath)\$($GuestOSName) - DPM Data 5.vhdx" 
    $DiskNumber = (Get-Diskimage -ImagePath "$($VMPath)\$($GuestOSName) - DPM Data 5.vhdx").Number
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT 
    Get-Disk -Number $DiskNumber | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "DPM" -Confirm:$False
    $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object { $_.Label -like "DPM*" }
    $DPMDriveLetter = $DriveLetter.DriveLetter
    Write-Output -InputObject "[$($VMName)]:: Copying SCDPM 1801 EXE to the new VHDx"
    Copy-Item -Path "$($Workingdir)\SCDPM_1801.exe" -Destination "$($DPMDriveLetter)\SCDPM_1801.exe" -Force
    Dismount-VHD -Path "$($VMPath)\$($GuestOSName) - DPM Data 5.vhdx"
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($GuestOSName) - DPM Data 5.vhdx" -ControllerType SCSI
  

    Invoke-Command -VMName $VMName -Credential $domainCred {
      
        Write-Output -InputObject "[$($VMName)]:: Adding the new VHDx for the DPM Install"
        Get-Disk | Where-Object OperationalStatus -EQ "Offline" | Set-Disk -IsOffline $False 
        Get-Disk | Where-Object Number -NE "0" | Set-Disk -IsReadOnly $False
        $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object { $_.Label -like "DPM*" }
        $DPMDrive = $Driveletter.DriveLetter

        
        Write-Output -InputObject "[$($VMName)]:: Configuring WIndows Firewall for DPM"
        Set-NetFirewallRule -DisplayName 'File and Printer Sharing (Echo Request - ICMPv4-In)' -Profile Domain -Enabled True -Direction Inbound -Action Allow
        Set-NetFirewallRule -DisplayName 'File and Printer Sharing (Echo Request - ICMPv6-In)' -Profile Domain -Enabled True -Direction Inbound -Action Allow
        Set-NetFirewallRule -DisplayName 'File and Printer Sharing (SMB-In)' -Profile Domain -Enabled True -Direction Inbound -Action Allow
        Set-NetFirewallRule -DisplayName 'Remote Desktop - User Mode (TCP-In)' -Profile Domain -Enabled True -Direction Inbound -Action Allow
        Set-NetFirewallRule -DisplayName 'Remote Desktop - User Mode (UDP-In)' -Profile Domain -Enabled True -Direction Inbound -Action Allow

        Write-Output -InputObject "[$($VMName)]:: Configuring WIndows Firewall for DPM New Rules"
        New-NetFirewallRule -DisplayName "SCDPM-TCP" -Direction Inbound -Protocol TCP -Profile Domain -LocalPort 135, 5718, 5719, 6075, 88, 389, 139, 445 -Action Allow
        New-NetFirewallRule -DisplayName "SCDPM-UDP" -Direction Inbound -Protocol UDP -Profile Domain -LocalPort 53, 88, 389, 137, 138 -Action Allow
        New-NetFirewallRule -DisplayName "Remote-SQL Server TCP" -Direction Inbound -Protocol TCP -Profile Domain -LocalPort 80, 1433 -Action Allow
        New-NetFirewallRule -DisplayName "Remote-SQL Server UDP" -Direction Inbound -Protocol UDP -Profile Domain -LocalPort 1434 -Action Allow


        $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object { $_.Label -eq "DPM" }
        $DPMDriveLetter1 = $DriveLetter.DriveLetter
       
        #Install VMM
        $unattendFile = New-Item "$($DPMriveletter1)\DPMSetup.ini" -type File

        $FileContent = @"
        [OPTIONS]

        CompanyName=MVPDays

        UserName=MVPDays\SVC_DPM

        ProgramFiles=$DPMDrive\Program Files

        DatabaseFiles=$DPMDrive\Program Files

        IntegratedInstallSource=$DPMDrive\SCDPM

        SQLMachineName=DPM01

        SQLInstanceName=MSSQLSERVER

        SQLMachineUserName=MVPDays\SVC_SQL

        SQLMachinePassword=P@ssw0rd

        SQLMachineDomainName=MVPDays

        SQLAccountPassword=P@ssw0rd

        ReportingMachineName=DPM01

        ReportingInstanceName=MSSQLSERVER

        ReportingMachineUserName=MVPDays\SVC_SQL

        ReportingMachinePassword=P@ssw0rd

        ReportingMachineDOmainName=MVPDays

        
"@
        
        Set-Content $unattendFile $fileContent -Force

        copy-item c:\dpmsetup.ini $DPMDriveLetter1\dpmsetup.ini -Force



         
        #I was having some issues with the path for $DPMdriveLetter Getting lost
    
        Write-Output -InputObject "[$($VMName)]:: Extracting SCDPM 1801"
        $DPMDriveletter1

        cmd.exe /c "$DPMDriveletter1\SCDPM_1801.exe /dir=$DPMdriveletter1\SCDPM /silent"
    
        Get-Service MSSQLSERVER | Start-Service
        Get-Service SQLSERVERAGENT | Start-Service
  
        Write-Output -InputObject "[$($VMName)]:: Installing DPM 1801"
        cmd.exe /c "$DPMDriveletter1\SCDPM\setup.exe /i /f $dpmdriveletter1\DPMSetup.ini /l $DPMdriveletter1\dpmlog.txt"
    
    }

}

Function Install-StorageSpacesPool {

    param
    (
        [string]$VMName, 
        [string]$GuestOSName,
        [string]$VMPath,
        [string]$WorkingDir
    )


    Write-Output -InputObject "[$($VMName)]:: Adding in Virtual Disks for The Pool"
    Set-Location -Path $WorkingDir
    1..8 | ForEach-Object { New-VHD -Path "$($VMPath)\$($GuestOSName) - StorageSpacesData $_.vhdx" -Dynamic -SizeBytes 10000GB }
    1..8 | ForEach-Object { Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($GuestOSName) - StorageSpacesData $_.vhdx" -ControllerType SCSI }
    
    
    Invoke-Command -VMName $VMName -Credential $domainCred { 
        Write-Output -InputObject "[$($VMName)]:: Creating the Storage Pool and adding a S Drive"
        $StorageSubsystem = Get-StorageSubsystem
        New-StoragePool -FriendlyName StoragePool01 -StorageSubSystemUniqueId $StorageSubsystem.UniqueID -PhysicalDisks (Get-PhysicalDisk -CanPool $True)
        $StoragePool = Get-Storagepool StoragePool01
        $StoragePool.FriendlyName
        New-VirtualDisk –FriendlyName VirtualDisk01 -size 1000GB –StoragePoolFriendlyName $StoragePool.FriendlyName -ProvisioningType Thin
        $Disks = Get-VirtualDisk -FriendlyName "VirtualDisk01" | Get-Disk
        $Disks | Get-partition | Remove-Partition
        $Disks | Initialize-Disk
        New-Partition -DiskNumber $Disks.Number -size 999GB -DriveLetter S
        Format-Volume -DriveLetter S -FileSystem ReFS -AllocationUnitSize 65536 -NewFileSystemLabel SDS001 -confirm:$False
        Write-Output -InputObject "[$($VMName)]:: Adding Deduplication for the lab"
        Add-WindowsFeature FS-Data-Deduplication
    }
}

Function Configure-StoragePool {

    param
    (
        [string]$VMName, 
        [string]$GuestOSName,
        [string]$VMPath,
        [string]$WorkingDir
    )

    Set-Location -Path $WorkingDir
    Invoke-Command -VMName $VMName -Credential $domainCred { 
        Write-Output -InputObject "[$($VMName)]:: Creating the Storage Pool and adding a V Drive"
        $StorageSubsystem = Get-StorageSubsystem
        New-StoragePool -FriendlyName StoragePool01 -StorageSubSystemUniqueId $StorageSubsystem.UniqueID -PhysicalDisks (Get-PhysicalDisk -CanPool $True)
        $StoragePool = Get-Storagepool StoragePool01
        $StoragePool.FriendlyName
        New-VirtualDisk –FriendlyName VirtualDisk01 -size 1000GB –StoragePoolFriendlyName $StoragePool.FriendlyName -ProvisioningType Thin
        $Disks = Get-VirtualDisk -FriendlyName "VirtualDisk01" | Get-Disk
        $Disks | Get-partition | Remove-Partition
        $Disks | Initialize-Disk
        New-Partition -DiskNumber $Disks.Number -size 999GB -DriveLetter S
        Format-Volume -DriveLetter S -FileSystem ReFS -AllocationUnitSize 65536 -NewFileSystemLabel SDS001 -confirm:$False
        Write-Output -InputObject "[$($VMName)]:: Adding Deduplication for the lab"
        Add-WindowsFeature FS-Data-Deduplication
    }
}

Function Copy-LabFiles {
    param
    (
        [string]$VMName, 
        [string]$GuestOSName,
        [string]$VMPath,
        [string]$WorkingDir,
        [string]$BashVHDPath
    )

    
    Set-Location -Path $WorkingDir
    Write-Output -InputObject "[$($VMName)]:: Copying Labfiles"

    New-VHD -Path "$($VMPath)\$($GuestOSName) - Labfiles Data 1.vhdx" -Dynamic -SizeBytes 200GB 
    Mount-VHD -Path "$($VMPath)\$($GuestOSName) - Labfiles Data 1.vhdx"
    $DiskNumber = (Get-Diskimage -ImagePath "$($VMPath)\$($GuestOSName) - Labfiles Data 1.vhdx").Number
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT 
    Get-Disk -Number $DiskNumber | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem ReFS -NewFileSystemLabel "Labfiles" -AllocationUnitSize 65536 -Confirm:$False
    $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object { $_.Label -like "Labfiles*" }
    $LabfilesDriveLetter = $DriveLetter.DriveLetter
    
    
    Write-Output -InputObject "[$($VMName)]:: Copying Gold VHDx"
    Copy-Item -Path "$($BaseVHDPath)\VMServerBase2019.vhdx" -Destination "$($LabfilesDriveLetter)\VMServerBase2019.vhdx" -Force
    Write-Output -InputObject "[$($VMName)]:: Windows Server 2019 ISO"
    Copy-Item -Path "$($WorkingDir)\en_windows_server_2019_x64_dvd_4cb967d8.iso" -Destination "$($LabfilesDriveLetter)\en_windows_server_2019_x64_dvd_4cb967d8.iso" -Force
    Dismount-VHD -Path "$($VMPath)\$($GuestOSName) - Labfiles Data 1.vhdx"
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($GuestOSName) - Labfiles Data 1.vhdx" -ControllerType SCSI


}

 
Function Install-VeeamOld {

    #Installs Veeam 9.5 UR4 Community Edition
    param
    (
        [string]$VMName, 
        [string]$GuestOSName,
        [string]$VMPath,
        [string]$WorkingDir
    )

    Set-Location $WorkingDir
    Write-Output -InputObject "[$($VMName)]:: Adding Drive for Veeam Install"

    New-VHD -Path "$($VMPath)\$($GuestOSName) - Veeam Data 1.vhdx" -Dynamic -SizeBytes 60GB 
    Mount-VHD -Path "$($VMPath)\$($GuestOSName) - Veeam Data 1.vhdx"
    $DiskNumber = (Get-Diskimage -ImagePath "$($VMPath)\$($GuestOSName) - Veeam Data 1.vhdx").Number
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT 
    Get-Disk -Number $DiskNumber | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Veeam" -Confirm:$False
    $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object { $_.Label -like "Veeam*" }
    $VeeamDriveLetter = $DriveLetter.DriveLetter
    
    
    Write-Output -InputObject "[$($VMName)]:: Copying Veeam ISO and Rollups into the new VHDx"
    Copy-Item -Path "$($WorkingDir)\VeeamBackup&Replication_9.5.4.2866.Update4b_20191210.iso" -Destination "$($VeeamDriveLetter)\VeeamBackup&Replication_9.5.4.2866.Update4b_20191210.iso" -Force
    Write-Output -InputObject "[$($VMName)]:: Copying Veeam license and Rollups into the new VHDx"
    #Copy-Item -Path "$($WorkingDir)\veeam_backup_nfr_0_12.lic" -Destination "$($VeeamDriveLetter)\veeam_backup_nfr_0_12.lic" -Force
    Dismount-VHD -Path "$($VMPath)\$($GuestOSName) - Veeam Data 1.vhdx"
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($GuestOSName) - Veeam Data 1.vhdx" -ControllerType SCSI


    #$DomainCred = Get-Credential 
    Invoke-Command -VMName $VMName -Credential $domainCred {



        Write-Output -InputObject "[$($VMName)]:: Adding the new VHDx for the Veeam Install"
        Get-Disk | Where-Object OperationalStatus -EQ "Offline" | Set-Disk -IsOffline $False 
        Get-Disk | Where-Object Number -NE "0" | Set-Disk -IsReadOnly $False
        $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object { $_.Label -like "Veeam*" }
        $VeeamDrive = $Driveletter.DriveLetter
        $VeeamDrive

        Write-Output -InputObject "[$($VMName)]:: Mounting Veeam ISO"

        $iso = Get-ChildItem -Path "$($VeeamDrive)\VeeamBackup&Replication_9.5.4.2866.Update4b_20191210.iso"  #CHANGE THIS!

        Mount-DiskImage $iso.FullName

        Write-Output -InputObject "[$($VMName)]:: Installing Veeam Unattended"

        $setup = $(Get-DiskImage -ImagePath $iso.FullName | Get-Volume).DriveLetter + ':' 
        $setup
       
        <#>   
        ===========================================================================

    Original Source Created by: Markus Kraus

    Twitter: @VMarkus_K

    Private Blog: mycloudrevolution.com
    #Source PowerShell Code from https://gist.githubusercontent.com/mycloudrevolution/b176f5ab987ff787ba4fce5c177780dc/raw/f20a78dc9b7c1085b1fe4d243de3fcb514970d70/VeeamBR95-Silent.ps1

    ===========================================================================
    </#>

        # Requires PowerShell 5.1
        # Requires .Net 4.5.2 and Reboot
        

        #region: Variables
        $source = $setup
        #  $licensefile = "$($VeeamDrive)\veeam_backup_nfr_0_12.lic"
        #  $username = "svc_veeam"
        $fulluser = "SH\svc_Veeam"
        $password = "P@ssw0rd"
        $CatalogPath = "$($VeeamDrive)\VbrCatalog"
        $vPowerPath = "$($VeeamDrive)\vPowerNfs"
        #endregion

        #region: logdir
        $logdir = "$($VeeamDrive)\logdir"
        $trash = New-Item -ItemType Directory -path $logdir  -ErrorAction SilentlyContinue
        #endregion

        ### Optional .Net 4.5.2
        <#
        Write-Host "    Installing .Net 4.5.2 ..." -ForegroundColor Yellow
        $Arguments = "/quiet /norestart"
        Start-Process "$source\Redistr\NDP452-KB2901907-x86-x64-AllOS-ENU.exe" -ArgumentList $Arguments -Wait -NoNewWindow
        Restart-Computer -Confirm:$true
        #>

        ### Optional PowerShell 5.1
        <#
        Write-Host "    Installing PowerShell 5.1 ..." -ForegroundColor Yellow
        $Arguments = "C:\_install\Win8.1AndW2K12R2-KB3191564-x64.msu /quiet /norestart"
        Start-Process "wusa.exe" -ArgumentList $Arguments -Wait -NoNewWindow
        Restart-Computer -Confirm:$true
        #>

        #region: Installation
        #  Info: https://www.veeam.com/unattended_installation_ds.pdf

        ## Global Prerequirements
        Write-Host "Installing Global Prerequirements ..." -ForegroundColor Yellow
        ### 2012 System CLR Types
        Write-Host "    Installing 2012 System CLR Types ..." -ForegroundColor Yellow
        $MSIArguments = @(
            "/i"
            "$source\Redistr\x64\SQLSysClrTypes.msi"
            "/qn"
            "/norestart"
            "/L*v"
            "$logdir\01_CLR.txt"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        if (Select-String -path "$logdir\01_CLR.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
        }
        else {
            throw "Setup Failed"
        }

        ### 2012 Shared management objects
        Write-Host "    Installing 2012 Shared management objects ..." -ForegroundColor Yellow
        $MSIArguments = @(
            "/i"
            "$source\Redistr\x64\SharedManagementObjects.msi"
            "/qn"
            "/norestart"
            "/L*v"
            "$logdir\02_Shared.txt"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        if (Select-String -path "$logdir\02_Shared.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
        }
        else {
            throw "Setup Failed"
        }

        ### SQL Express
        ### Info: https://msdn.microsoft.com/en-us/library/ms144259.aspx
        Write-Host "    Installing SQL Express ..." -ForegroundColor Yellow
        $Arguments = "/HIDECONSOLE /Q /IACCEPTSQLSERVERLICENSETERMS /ACTION=install /FEATURES=SQLEngine,SNAC_SDK /INSTANCENAME=VEEAMSQL2012 /SQLSVCACCOUNT=`"NT AUTHORITY\SYSTEM`" /SQLSYSADMINACCOUNTS=`"$fulluser`" `"Builtin\Administrators`" /TCPENABLED=1 /NPENABLED=1 /UpdateEnabled=0"
        Start-Process "$source\Redistr\x64\SQLEXPR_x64_ENU.exe" -ArgumentList $Arguments -Wait -NoNewWindow

        ## Veeam Backup & Replication
        Write-Host "Installing Veeam Backup & Replication ..." -ForegroundColor Yellow
        ### Backup Catalog
        Write-Host "    Installing Backup Catalog ..." -ForegroundColor Yellow
        $trash = New-Item -ItemType Directory -path $CatalogPath -ErrorAction SilentlyContinue
        $MSIArguments = @(
            "/i"
            "$source\Catalog\VeeamBackupCatalog64.msi"
            "/qn"
            "/L*v"
            "$logdir\04_Catalog.txt"
            "VM_CATALOGPATH=$CatalogPath"
            "VBRC_SERVICE_USER=$fulluser"
            "VBRC_SERVICE_PASSWORD=$password"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        if (Select-String -path "$logdir\04_Catalog.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
        }
        else {
            throw "Setup Failed"
        }

        ### Backup Server
        Write-Host "    Installing Backup Server ..." -ForegroundColor Yellow
        $trash = New-Item -ItemType Directory -path $vPowerPath -ErrorAction SilentlyContinue
        $MSIArguments = @(
            "/i"
            "$source\Backup\Server.x64.msi"
            "/qn"
            "/L*v"
            "$logdir\05_Backup.txt"
            "ACCEPTEULA=YES"
            "PF_AD_NFSDATASTORE=$vPowerPath"
            "VBR_SQLSERVER_SERVER=$env:COMPUTERNAME\VEEAMSQL2012"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        if (Select-String -path "$logdir\05_Backup.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
        }
        else {
            throw "Setup Failed"
        }

        ### Backup Console
        Write-Host "    Installing Backup Console ..." -ForegroundColor Yellow
        $MSIArguments = @(
            "/i"
            "$source\Backup\Shell.x64.msi"
            "/qn"
            "/L*v"
            "$logdir\06_Console.txt"
            "ACCEPTEULA=YES"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        if (Select-String -path "$logdir\06_Console.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
        }
        else {
            throw "Setup Failed"
        }

   

    }
}

Function Install-Veeam {
  #Install Veeam 10

  param
  (
    [string]$VMName, 
    [string]$GuestOSName,
    [string]$VMPath,
    [string]$WorkingDir
  )
     
    #Must Change this
    $VeeamISO = "D:\Fabric\VeeamBackup&Replication_10.0.1.4854_20200723.iso"
    Write-Output -InputObject "[$($VMName)]:: Copying Veeam ISO to Data Drive"

    New-VHD -Path "$($VMPath)\$($GuestOSName) - Veeam Data 1.vhdx" -Dynamic -SizeBytes 60GB
    #Remove-VMHardDiskDrive -VMName $VMName -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 1
   
    Mount-VHD -Path "$($VMPath)\$($GuestOSName) - Veeam Data 1.vhdx"
    $DiskNumber = (Get-Diskimage -ImagePath "$($VMPath)\$($GuestOSName) - Veeam Data 1.vhdx").Number
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT 
    Get-Disk -Number $DiskNumber | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Veeam" -Confirm:$False
    $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object {$_.Label -like "Veeam*"}
    $VeeamDriveLetter = $DriveLetter.DriveLetter
    $VeeamDriveLetter
    
    Write-Output -InputObject "[$($VMName)]:: Copying Veeam ISO and Rollups into the new VHDx"
    Copy-Item -Path $VeeamIso -Destination "$($VeeamDriveLetter)\VeeamBackup&Replication_10.0.1.4854_20200723.iso" -Force
    #Write-Output -InputObject "[$($VMName)]:: Copying Veeam license and Rollups into the new VHDx"
    #Copy-Item -Path $VeeamLic -Destination "$($VeeamDriveLetter)\veeam_backup_nfr_0_12.lic" -Force
    Dismount-VHD -Path "$($VMPath)\$($GuestOSName) - Veeam Data 1.vhdx"
    Add-VMHardDiskDrive -VMName $VMname -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 1 -Path "$($VMPath)\$($GuestOSName) - Veeam Data 1.vhdx"
  

    
    Invoke-Command -VMName $VMName -Credential $domainCred {



    Write-Output -InputObject "[$($VMName)]:: Adding the new VHDx for the Veeam Install"
    Get-Disk | Where OperationalStatus -EQ "Offline" | Set-Disk -IsOffline $False 
    Get-Disk | Where Number -NE "0" |  Set-Disk -IsReadOnly $False
    $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object {$_.Label -like "Veeam*"}
    $VeeamDrive = $Driveletter.DriveLetter
    $VeeamDrive

    Write-Output -InputObject "[$($VMName)]:: Mounting Veeam ISO"

    $iso = Get-ChildItem -Path "$($VeeamDrive)\VeeamBackup&Replication_10.0.1.4854_20200723.iso"  #CHANGE THIS!

    Mount-DiskImage $iso.FullName

    Write-Output -InputObject "[$($VMName)]:: Installing Veeam Unattended"

        $setup = $(Get-DiskImage -ImagePath $iso.FullName | Get-Volume).DriveLetter +':' 
        $setup
       
    <#>   
        ===========================================================================

    Original Source Created by: Markus Kraus

    Twitter: @VMarkus_K

    Private Blog: mycloudrevolution.com
    #Source PowerShell Code from https://gist.githubusercontent.com/mycloudrevolution/b176f5ab987ff787ba4fce5c177780dc/raw/f20a78dc9b7c1085b1fe4d243de3fcb514970d70/VeeamBR95-Silent.ps1

    ===========================================================================
    </#>

            # Requires PowerShell 5.1
        # Requires .Net 4.5.2 and Reboot
        

        #region: Variables
        $source = $setup
        $licensefile = "$($VeeamDrive)\veeam_backup_nfr_0_12.lic"
        $username = "svc_veeam"
        $fulluser = "Titan\svc_Veeam"
        $password = "C@ngeme2019!!@@##"
        $CatalogPath = "$($VeeamDrive)\VbrCatalog"
        $vPowerPath = "$($VeeamDrive)\vPowerNfs"
        #endregion

        #region: logdir
        $logdir = "$($VeeamDrive)\logdir"
        $trash = New-Item -ItemType Directory -path $logdir  -ErrorAction SilentlyContinue
        #endregion

        ### Optional .Net 4.5.2
        <#>
        Write-Host "    Installing .Net 4.5.2 ..." -ForegroundColor Yellow
        $Arguments = "/quiet /norestart"
        Start-Process "$source\Redistr\NDP452-KB2901907-x86-x64-AllOS-ENU.exe" -ArgumentList $Arguments -Wait -NoNewWindow
        Restart-Computer -Confirm:$true
        #>

        ### Optional PowerShell 5.1
        <#
        Write-Host "    Installing PowerShell 5.1 ..." -ForegroundColor Yellow
        $Arguments = "C:\_install\Win8.1AndW2K12R2-KB3191564-x64.msu /quiet /norestart"
        Start-Process "wusa.exe" -ArgumentList $Arguments -Wait -NoNewWindow
        Restart-Computer -Confirm:$true
        #>

        #region: Installation
        #  Info: https://www.veeam.com/unattended_installation_ds.pdf


        
        ## Global Prerequirements
        Write-Host "Installing Global Prerequirements ..." -ForegroundColor Yellow
        ### 2012 System CLR Types
        Write-Host "    Installing 2012 System CLR Types ..." -ForegroundColor Yellow
        $MSIArguments = @(
            "/i"
            "$source\Redistr\x64\SQLSysClrTypes.msi"
            "/qn"
            "/norestart"
            "/L*v"
            "$logdir\01_CLR.txt"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        if (Select-String -path "$logdir\01_CLR.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
            }
            else {
                throw "Setup Failed"
                }

        ### 2012 Shared management objects
        Write-Host "    Installing 2016 Shared management objects ..." -ForegroundColor Yellow
        $MSIArguments = @(
            "/i"
            "$source\Redistr\x64\SharedManagementObjects.msi"
            "/qn"
            "/norestart"
            "/L*v"
            "$logdir\02_Shared.txt"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        if (Select-String -path "$logdir\02_Shared.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
            }
            else {
                throw "Setup Failed"
                }

        ### SQL Express
        ### Info: https://msdn.microsoft.com/en-us/library/ms144259.aspx
        Write-Host "    Installing SQL Express ..." -ForegroundColor Yellow
        $Arguments = "/HIDECONSOLE /Q /IACCEPTSQLSERVERLICENSETERMS /ACTION=install /FEATURES=SQLEngine,SNAC_SDK /INSTANCENAME=VEEAMSQL2016 /SQLSVCACCOUNT=`"NT AUTHORITY\SYSTEM`" /SQLSYSADMINACCOUNTS=`"$fulluser`" `"Builtin\Administrators`" /TCPENABLED=1 /NPENABLED=1 /UpdateEnabled=0"
        Start-Process "$source\Redistr\x64\SQLExpress\2016SP2\SQLEXPR_x64_ENU.exe" -ArgumentList $Arguments -Wait -NoNewWindow
       
        ## Veeam Backup & Replication
        Write-Host "Installing Veeam Backup & Replication ..." -ForegroundColor Yellow
        ### Backup Catalog
        Write-Host "    Installing Backup Catalog ..." -ForegroundColor Yellow
        $trash = New-Item -ItemType Directory -path $CatalogPath -ErrorAction SilentlyContinue
        $MSIArguments = @(
            "/i"
            "$source\Catalog\VeeamBackupCatalog64.msi"
            "/qn"
            "/L*v"
            "$logdir\04_Catalog.txt"
            "VM_CATALOGPATH=$CatalogPath"
            "VBRC_SERVICE_USER=$fulluser"
            "VBRC_SERVICE_PASSWORD=$password"
            "VBRC_SERVICE_PORT=9391"
            "ACCEPT_THIRDPARTY_LICENSES=1"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        if (Select-String -path "$logdir\04_Catalog.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
            }
            else {
                throw "Setup Failed"
                }
                 
        ### Backup Server
        Write-Host "    Installing Backup Server ..." -ForegroundColor Yellow
        $trash = New-Item -ItemType Directory -path $vPowerPath -ErrorAction SilentlyContinue
        $MSIArguments = @(
            "/i"
            "$source\Backup\Server.x64.msi"
            "/qn"
            "/L*v"
            "$logdir\05_Backup.txt"
            "ACCEPTEULA=YES"
            "VBR_SERVICE_USER=$fulluser"
            "VBR_SERVICE_PASSWORD=$password"
            "PF_AD_NFSDATASTORE=$vPowerPath"
            "VBR_SQLSERVER_SERVER=$env:COMPUTERNAME\VEEAMSQL2016"
            "ACCEPT_THIRDPARTY_LICENSES=1"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        if (Select-String -path "$logdir\05_Backup.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
            }
            else {
                throw "Setup Failed"
                }
             
        ### Backup Console
        Write-Host "    Installing Backup Console ..." -ForegroundColor Yellow
        $MSIArguments = @(
            "/i"
            "$source\Backup\Shell.x64.msi"
            "/qn"
            "/L*v"
            "$logdir\06_Console.txt"
            "ACCEPTEULA=YES"
            "ACCEPT_THIRDPARTY_LICENSES=1"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        if (Select-String -path "$logdir\06_Console.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
            }
            else {
                throw "Setup Failed"
                }
                   
        ### Explorers
        Write-Host "    Installing Explorer For ActiveDirectory ..." -ForegroundColor Yellow
        $MSIArguments = @(
            "/i"
            "$source\Explorers\VeeamExplorerForActiveDirectory.msi"
            "/qn"
            "/L*v"
            "$logdir\07_ExplorerForActiveDirectory.txt"
            "ACCEPT_EULA=1"
            "ACCEPT_THIRDPARTY_LICENSES=1"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        if (Select-String -path "$logdir\07_ExplorerForActiveDirectory.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
            }
            else {
                throw "Setup Failed"
                }

        Write-Host "    Installing Explorer For Exchange ..." -ForegroundColor Yellow
        $MSIArguments = @(
            "/i"
            "$source\Explorers\VeeamExplorerForExchange.msi"
            "/qn"
            "/L*v"
            "$logdir\08_VeeamExplorerForExchange.txt"
            "ACCEPT_EULA=1"
            "ACCEPT_THIRDPARTY_LICENSES=1"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        if (Select-String -path "$logdir\08_VeeamExplorerForExchange.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
            }
            else {
                throw "Setup Failed"
                }

        Write-Host "    Installing Explorer For SQL ..." -ForegroundColor Yellow
        $MSIArguments = @(
            "/i"
            "$source\Explorers\VeeamExplorerForSQL.msi"
            "/qn"
            "/L*v"
            "$logdir\09_VeeamExplorerForSQL.txt"
            "ACCEPT_EULA=1"
            "ACCEPT_THIRDPARTY_LICENSES=1"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        if (Select-String -path "$logdir\09_VeeamExplorerForSQL.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
            }
            else {
                throw "Setup Failed"
                }

        Write-Host "    Installing Explorer For Oracle ..." -ForegroundColor Yellow
        $MSIArguments = @(
            "/i"
            "$source\Explorers\VeeamExplorerForOracle.msi"
            "/qn"
            "/L*v"
            "$logdir\10_VeeamExplorerForOracle.txt"
            "ACCEPT_EULA=1"
            "ACCEPT_THIRDPARTY_LICENSES=1"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        if (Select-String -path "$logdir\10_VeeamExplorerForOracle.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
            }
            else {
                throw "Setup Failed"
                }

        Write-Host "    Installing Explorer For SharePoint ..." -ForegroundColor Yellow
        $MSIArguments = @(
            "/i"
            "$source\Explorers\VeeamExplorerForSharePoint.msi"
            "/qn"
            "/L*v"
            "$logdir\11_VeeamExplorerForSharePoint.txt"
            "ACCEPT_EULA=1"
            "ACCEPT_THIRDPARTY_LICENSES=1"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        if (Select-String -path "$logdir\11_VeeamExplorerForSharePoint.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
            }
            else {
                throw "Setup Failed"
                }

        ## Enterprise Manager
        Write-Host "Installing Enterprise Manager ..." -ForegroundColor Yellow
        ### Enterprise Manager Prereqirements
        Write-Host "    Installing Enterprise Manager Prereqirements ..." -ForegroundColor Yellow
        $trash = Install-WindowsFeature Web-Default-Doc,Web-Dir-Browsing,Web-Http-Errors,Web-Static-Content,Web-Windows-Auth -Restart:$false -WarningAction SilentlyContinue
        $trash = Install-WindowsFeature Web-Http-Logging,Web-Stat-Compression,Web-Filtering,Web-Net-Ext45,Web-Asp-Net45,Web-ISAPI-Ext,Web-ISAPI-Filter,Web-Mgmt-Console -Restart:$false  -WarningAction SilentlyContinue

        $MSIArguments = @(
            "/i"
            "$source\Redistr\x64\rewrite_amd64.msi"
            "/qn"
            "/norestart"
            "/L*v"
            "$logdir\12_Rewrite.txt"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        if (Select-String -path "$logdir\12_Rewrite.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
            }
            else {
                throw "Setup Failed"
                }
                
        ### Enterprise Manager Web
        Write-Host "    Installing Enterprise Manager Web ..." -ForegroundColor Yellow
        $MSIArguments = @(
            "/i"
            "$source\EnterpriseManager\BackupWeb_x64.msi"
            "/qn"
            "/L*v"
            "$logdir\13_EntWeb.txt"
            "ACCEPT_EULA=1"
            "VBREM_LICENSE_FILE=$licensefile"
            "VBREM_SERVICE_USER=$fulluser"
            "VBREM_SERVICE_PASSWORD=$password"
            "VBREM_SQLSERVER_SERVER=$env:COMPUTERNAME\VEEAMSQL2016"
            "ACCEPT_THIRDPARTY_LICENSES=1"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        if (Select-String -path "$logdir\13_EntWeb.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
            }
            else {
                throw "Setup Failed"
                }

        ### Enterprise Manager Cloud Portal
        #Write-Host "    Installing Enterprise Manager Cloud Portal ..." -ForegroundColor Yellow
        <#
        $MSIArguments = @(
            "/i"
            "$source\Cloud Portal\BackupCloudPortal_x64.msi"
            "/L*v"
            "$logdir\14_EntCloudPortal.txt"
            "/qn"
            "ACCEPTEULA=YES"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow
        #>
        <#>
        Start-Process "msiexec.exe" -ArgumentList "/i `"$source\Cloud Portal\BackupCloudPortal_x64.msi`" /l*v $logdir\14_EntCloudPortal.txt /qn ACCEPTEULA=`"YES`"" -Wait -NoNewWindow

        if (Select-String -path "$logdir\14_EntCloudPortal.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
            }
            else {
                throw "Setup Failed"
                }
                </#>
        ### Update 3
       # Write-Host "Installing Update 3 ..." -ForegroundColor Yellow
       # $Arguments = "/silent /noreboot /log $logdir\15_update.txt VBR_AUTO_UPGRADE=1"
      #  Start-Process "$source\Updates\veeam_backup_9.5.0.1536.update3_setup.exe" -ArgumentList $Arguments -Wait -NoNewWindow
        #endregion

 }

 }
 

Function Install-WindowsAdminCenter {
    param
    (
        [string]$VMName, 
        [string]$GuestOSName,
        [string]$VMPath,
        [string]$WorkingDir
    )


    #Download Windows Admin Center to c:\post-install


    Invoke-Command -VMName $VMName -Credential $domainCred {

        New-Item -ItemType Directory -Path "c:\Post-Install" -Force:$true | Out-Null
        Write-Output "Downloading Windows Admin Center"
        #Ping the internet to get things working in the lab
        ping www.google.com

        Invoke-WebRequest -UseBasicParsing -Uri https://aka.ms/WACDownload -OutFile "c:\Post-Install\WindowsAdminCenter.msi"


        Write-Output "Installing Windows Admin Center"
        Start-Process msiexec.exe -Wait -ArgumentList "/i c:\post-install\WindowsAdminCenter.msi /qn /L*v log.txt SME_PORT=6516 SSL_CERTIFICATE_OPTION=generate"


    }


}

Function Create-ADusers {
    param
    (
        [string]$VMName, 
        [string]$GuestOSName,
        [string]$VMPath,
        [string]$WorkingDir
    )


    Invoke-Command -VMName $VMName -Credential $domainCred {
        param($VMName, $password)

        Write-Output -InputObject "[$($VMName)]:: Creating user account for Dave"
        do {
            Start-Sleep -Seconds 5
            New-ADUser `
                -Name 'Dave_Admin' `
                -SamAccountName  'Dave_Admin' `
                -DisplayName 'Dave_Admin' `
                -AccountPassword (ConvertTo-SecureString -String $password -AsPlainText -Force) `
                -ChangePasswordAtLogon $false  `
                -Enabled $true -ea 0
        }
        until ($?)
        Add-ADGroupMember -Identity 'Domain Admins' -Members 'Dave_Admin'
    } -ArgumentList $VMName, $domainAdminPassword

    Invoke-Command -VMName $VMName -Credential $domainCred {
        param($VMName, $password)

        Write-Output -InputObject "[$($VMName)]:: Creating user account for SVC_SQL"
        do {
            Start-Sleep -Seconds 5
            New-ADUser `
                -Name 'SVC_SQL' `
                -SamAccountName  'SVC_SQL' `
                -DisplayName 'SVC_SQL' `
                -AccountPassword (ConvertTo-SecureString -String $password -AsPlainText -Force) `
                -ChangePasswordAtLogon $false  `
                -Enabled $true -ea 0
        }
        until ($?)
        Add-ADGroupMember -Identity 'Domain Admins' -Members 'SVC_SQL'
    } -ArgumentList $VMName, $domainAdminPassword

    Invoke-Command -VMName $VMName -Credential $domainCred {
        param($VMName, $password)

        Write-Output -InputObject "[$($VMName)]:: Creating user account for SVC_SQL_AGENT"
        do {
            Start-Sleep -Seconds 5
            New-ADUser `
                -Name 'SVC_SQL_AGENT' `
                -SamAccountName  'SVC_SQL_AGENT' `
                -DisplayName 'SVC_SQL_AGENT' `
                -AccountPassword (ConvertTo-SecureString -String $password -AsPlainText -Force) `
                -ChangePasswordAtLogon $false  `
                -Enabled $true -ea 0
        }
        until ($?)
        Add-ADGroupMember -Identity 'Domain Admins' -Members 'SVC_SQL_AGENT'
    } -ArgumentList $VMName, $domainAdminPassword

    Invoke-Command -VMName $VMName -Credential $domainCred {
        param($VMName, $password)

        Write-Output -InputObject "[$($VMName)]:: Creating user account for SVC_SQL_RS"
        do {
            Start-Sleep -Seconds 5
            New-ADUser `
                -Name 'SVC_SQL_RS' `
                -SamAccountName  'SVC_SQL_RS' `
                -DisplayName 'SVC_SQL_RS' `
                -AccountPassword (ConvertTo-SecureString -String $password -AsPlainText -Force) `
                -ChangePasswordAtLogon $false  `
                -Enabled $true -ea 0
        }
        until ($?)
        Add-ADGroupMember -Identity 'Domain Admins' -Members 'SVC_SQL_RS'
    } -ArgumentList $VMName, $domainAdminPassword

    Invoke-Command -VMName $VMName -Credential $domainCred {
        param($VMName, $password)

        Write-Output -InputObject "[$($VMName)]:: Creating user account for SVC_Veeam"
        do {
            Start-Sleep -Seconds 5
            New-ADUser `
                -Name 'SVC_Veeam' `
                -SamAccountName  'SVC_Veeam' `
                -DisplayName 'SVC_Veeam' `
                -AccountPassword (ConvertTo-SecureString -String $password -AsPlainText -Force) `
                -ChangePasswordAtLogon $false  `
                -Enabled $true -ea 0
        }
        until ($?)
        Add-ADGroupMember -Identity 'Domain Admins' -Members 'SVC_Veeam'
    } -ArgumentList $VMName, $domainAdminPassword




}

Function Configure-ADCS {

    param
    (
        [string]$VMName, 
        [string]$GuestOSName,
        [string]$VMPath,
        [string]$WorkingDir
    )


    Write-Output -InputObject "[$($VMName)]:: Enabling Active Directory Certificate Enterprise Root CA with SHA 256"
    Invoke-Command -vmname $VMName -Credential $DomainCred { Install-AdcsCertificationAuthority -CAType EnterpriseRootCa -CryptoProviderName "ECDSA_P256#Microsoft Software Key Storage Provider" -KeyLength 256 -HashAlgorithmName SHA256 -confirm:$False -verbose }
    Stop-VM -VMName $VMName
    Set-VMMemory -VMName $VMName -StartupBytes 2GB
    Set-VMProcessor -VMName $VMName -Count 2
    Start-VM -VMName $VMName
    Wait-PSDirect -VMName $VMName -cred $domainCred

}

 Function Get-VeeamISO {
 
 #Ask for Veeam ISO

        [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
        $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            Title="Please Select the Veeam 9.5 UR3 ISO"
        }
        $openFile.Filter = "iso files (*.iso)|*.iso|All files (*.*)|*.*" 
        If($openFile.ShowDialog() -eq "OK")
        {
              Write-Host "File $($openfile.FileName) selected"
        } 
        if (!$openFile.FileName){
                WriteErrorAndExit  "Iso was not selected... Exitting"
            }
            $VeeamISO = $openfile.FileName
            $veeamISO
            }

Function Download-SecurityBaselines {
    param
    (
        [string]$VMName, 
        [string]$GuestOSName,
        [string]$VMPath,
        [string]$WorkingDir,
        [string]$Domainname
    )


    #Download Windows Admin Center to c:\post-install


    Invoke-Command -VMName $VMName -Credential $domainCred {

        New-Item -ItemType Directory -Path "c:\Post-Install" -Force:$true | Out-Null
        Write-Output "Microsoft Security Compliance Toolkit"
        #Ping the internet to get things working in the lab
        ping www.google.com

        Write-Output "Download Security Compliance Toolkit Server 2019 - 1909"     
        $sourceURI = "https://download.microsoft.com/download/8/5/C/85C25433-A1B0-4FFA-9429-7E023E7DA8D8/Windows%2010%20Version%201909%20and%20Windows%20Server%20Version%201909%20Security%20Baseline.zip"
        $Destinationfilename = "c:\post-install\SecurityBaselineServer2019-1909.zip"
        invoke-webrequest -UseBasicParsing -Uri "$sourceURI" -outfile "$destinationfilename" -passthru | select -Expand headers -verbose


        Write-Output "Expanding Zip File"
        Expand-Archive -LiteralPath "$Destinationfilename" -DestinationPath 'c:\post-install\MSSECCOMP-2019-1909'


        Write-Output "Download Security Compliance Toolkit Baseline Windows 10 2004 and Server 2004"     
        $sourceURI = "https://download.microsoft.com/download/8/5/C/85C25433-A1B0-4FFA-9429-7E023E7DA8D8/Windows%2010%20Version%202004%20and%20Windows%20Server%20Version%202004%20Security%20Baseline.zip"
        $Destinationfilename = "c:\post-install\SecurityBaselineServer2004.zip"
        invoke-webrequest -UseBasicParsing -Uri "$sourceURI" -outfile "$destinationfilename" -passthru | select -Expand headers -verbose


        Write-Output "Expanding Zip File"
        Expand-Archive -LiteralPath "$Destinationfilename" -DestinationPath 'c:\post-install\MSSECCOMP-2004'


       
        Write-Output "Creating Group Policy Central Store"
        New-Item -ItemType Directory -Path "C:\Windows\SYSVOL\sysvol\$($Domainname)\Policies\PolicyDefinitions" -Force:$true | Out-Null
        

               
    }


}
#endregion

#region Variable Init
$BaseVHDPath = "$($WorkingDir)\BaseVHDs"
$VMPath = "$($WorkingDir)\VMs"

$localCred = New-Object -TypeName System.Management.Automation.PSCredential `
    -ArgumentList 'Administrator', (ConvertTo-SecureString -String $adminPassword -AsPlainText -Force)

$domainCred = New-Object -TypeName System.Management.Automation.PSCredential `
    -ArgumentList "$($domainName)\Administrator", (ConvertTo-SecureString -String $domainAdminPassword -AsPlainText -Force)

#endregion

Write-Log 'Host' 'Getting started...'

Write-Output -InputObject "Grabbing the location of the Veeam ISO"
#Get-VeeamISO
#$VeeamISO
Confirm-Path $BaseVHDPath
Confirm-Path $VMPath
#Write-Log 'Host' 'Building Base Images'
#Write-Log 'Host' 'Downloading January 2018 CU for Windows Server 2016'

#if ((Get-VMSwitch | Where-Object -Property name -EQ -Value $virtualSwitchName) -eq $null) {
#    New-VMSwitch -Name $virtualSwitchName -SwitchType Private
#}
#Write-Log 'Host' 'Select the Internet VSwitch for the Lab -- It will be added to the RRAS Router'
#$InternetVSwitch1 = Get-VMSwitch | Where-Object Switchtype -ne Private | Select-Object Name, SwitchType | Out-GridView -PassThru -Title "Choose the Internet VSwitch for the Lab" | Select-Object Name
#$InternetVSwitch = $InternetVSwitch1.Name

#region - 009 Building LAB VMs....

#Invoke-FabricVMPrep 'FABDC01' 'FABDC01' -FullServer2019
#Invoke-FabricVmPrep 'FABDC02' 'FABDC02' -FullServer2019
#Invoke-FabricVmPrep 'FABDHCP01' 'FABDHCP01'-FullServer2019
#Invoke-FabricVmPrep 'FABMGMT01' 'FABMGMT01' -FullServer2019
#Invoke-FabricVmPrep 'FABRouter01' 'FABRouter01' -FullServer2019
#Invoke-FabricVmPrep 'FABWSUS01' 'FABWSUS01' -FullServer2019
#Invoke-FabricVmPrep 'DRTitan01' 'DRTitan01' -FullServer2019
#Invoke-DemoVMPrep 'VMM01' 'VMM01' -FullServer2019
#Invoke-DemoVMPrep 'SCOM01' 'SCOM01' -FullServer2019
#Invoke-DemoVMPrep 'DPM01' 'DPM01' -FullServer2019
1..2 | ForEach-Object -Process {
    Invoke-FabricVMPrep "S2D2019-$_" "S2D2019-$_" -FullServer2019
}
#
#1..4 | ForEach-Object -Process {
#    Invoke-DemoVMPrep "S2D2019DR-$_" "S2D2019DR-$_" -FullServer2019
#}

#1..4 | ForEach-Object -Process {
#    Invoke-DemoVMPrep "HyperV$_" "HyperV$_" -FullServer2019
#}
#</#>

#endregion
$VMName = 'S2D2019-1'
$GuestOSName = 'S2D2019-1'

1..2 | ForEach-Object -Process {
  Invoke-NodeStorageBuild "S2D2019-$_" "S2D2019-$_"
}

#endregion



Write-Log 'Done' 'Done!'

