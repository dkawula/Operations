<#
Created:	 2022-08-30
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
    Creates a DARK FABRIC environment used to Manage HCI Hosts, Backup Targets, and other Secured Servers
    .DESCRIPTION
    Huge Thank you to Ben Armstrong @VirtualPCGuy for giving me the source starter code many moons ago :)
    
    This Script requires a BaseGolden VHDx to be created first.   I use my BaseImageBuilder_V5 for this
    https://github.com/dkawula/Operations/blob/master/Hyper-V/BaseImageBuilder_V5.ps1

    Once you have this you can build you base images.
    THis script has been tested with Server 2016,2019,2022
    Core has limited testing but you can build whatever servers you want.
    #Future TODO - Working on Automating Getting the GPO's created via PowerShell and imported
    #Future TODO - Test with CIS Benchmarks level2 - Level 1 has been tested and works
    
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
    $Timezone = 'Central Standard Time',

    [Parameter(Mandatory)]
    [string]
    $adminPassword = 'P@ssw0rd',

    [Parameter(Mandatory)]
    [string]
    $domainName = 'MVPDays.Com',

    [Parameter(Mandatory)]
    [string]
    $domainDN = 'DC=MVPDays,DC=Com',

    [Parameter(Mandatory)]
    [string]
    $domainAdminPassword = 'P@ssw0rd',

    [Parameter(Mandatory)]
    [string]
    $dsrestoremodePassword = 'P@ssw0rd',

    [Parameter(Mandatory)]
    [string]
    $Dave_Admin_Password = 'P@ssw0rd',

    [Parameter(Mandatory)]
    [string]
    $sv_sql_Password = 'P@ssw0rd',

    [Parameter(Mandatory)]
    [string]
    $sv_sql_agent_Password = 'P@ssw0rd',

    [Parameter(Mandatory)]
    [string]
    $sv_sql_srs_Password = 'P@ssw0rd',

    [Parameter(Mandatory)]
    [string]
    $SV_Veeam_Password = 'P@ssw0rd',

    [Parameter(Mandatory)]
    [string]
    $SCOM_AA_Password = 'P@ssw0rd',

    [Parameter(Mandatory)]
    [string]
    $SCOM_DAS_Password = 'P@ssw0rd',

    [Parameter(Mandatory)]
    [string]
    $SCOM_READ_Password = 'P@ssw0rd',

    [Parameter(Mandatory)]
    [string]
    $SCOM_WRITE_Password = 'P@ssw0rd',

    [Parameter(Mandatory)]
    [string]
    $Sami_password = 'P@ssw0rd',

    [Parameter(Mandatory)]
    [string]
    $Dave_password = 'P@ssw0rd',

    [Parameter(Mandatory)]
    [string]
    $Emile_password = 'P@ssw0rd',

    [Parameter(Mandatory)]
    [string]
    $Cary_password = 'P@ssw0rd',

    [Parameter(Mandatory)]
    [string]
    $SA_Sami_password = 'P@ssw0rd',

    [Parameter(Mandatory)]
    [string]
    $SA_DAVE_password = 'P@ssw0rd',

    [Parameter(Mandatory)]
    [string]
    $SA_EMILE_password = 'P@ssw0rd',

    [Parameter(Mandatory)]
    [string]
    $SA_Cary_password = 'P@ssw0rd',

    [Parameter(Mandatory)]
    [string]
    $DA_Sami_password = 'P@ssw0rd',

    [Parameter(Mandatory)]
    [string]
    $DA_Dave_password = 'P@ssw0rd',

    [Parameter(Mandatory)]
    [string]
    $DA_Emile_password = 'P@ssw0rd',

    [Parameter(Mandatory)]
    [string]
    $DA_Cary_password = 'P@ssw0rd',

    [Parameter(Mandatory)]
    [string]
    $SCOMMGMTGroup = 'DOMAINNAME',

    [Parameter(Mandatory)]
    [string]
    $virtualSwitchName = 'Dave MVP Demo',

    [Parameter(Mandatory)]
    [ValidatePattern('(\d{1,3}\.){3}')] #ensure that Subnet is formatted like the first three octets of an IPv4 address
    [string]
    $Subnet = '172.16.200.',

    [Parameter(Mandatory)]
    [string]
    $VLANID = '4444',

    [Parameter(Mandatory)]
    [string]
    $Gateway = '172.16.200.1',

    [Parameter(Mandatory)]
    [string]
    $NTPServer = '172.16.200.1',

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
    

function Restart-FabricVM {
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

function Invoke-FabricVMPrep {
    param
    (
        [string] $VMName, 
        [string] $GuestOSName, 
        [switch] $FullServer2016,
        [switch] $FullServer2019,
        [switch] $FullServer2022,
        [switch] $CoreServer2016,
        [switch] $CoreServer2019,
        [switch] $CoreServer2022
    ) 

    Write-Log $VMName 'Removing old VM'
    get-vm $VMName -ErrorAction SilentlyContinue |
    stop-vm -TurnOff -Force -Passthru |
    remove-vm -Force
    New-Item -ItemType Directory -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\" -force
    Clear-File "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName)-C.vhdx"
   
    Write-Log $VMName 'Copying Gold VHDx Template'
    if ($FullServer2016) {
        $null = Copy-Item "$($BaseVHDPath)\VMServerBase2016.vhdx" -Destination "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName)-C.vhdx"
        
    }

    Elseif ($FullServer2019) {
        $null = Copy-Item "$($BaseVHDPath)\VMServerBase2019.vhdx" -Destination "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName)-C.vhdx"
    }

     Elseif ($FullServer2022) {
        $null = Copy-Item "$($BaseVHDPath)\VMServerBase2022.vhdx" -Destination "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName)-C.vhdx"
    }

    Elseif ($CoreServer2016) {
        $null = Copy-Item "$($BaseVHDPath)\VMServerCore2016.vhdx" -Destination "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName)-C.vhdx"
    }
    Elseif ($CoreServer2019) {
        $null = Copy-Item "$($BaseVHDPath)\VMServerCore2019.vhdx" -Destination "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName)-C.vhdx"
    }

     Elseif ($CoreServer2022) {
        $null = Copy-Item "$($BaseVHDPath)\VMServerCore2022.vhdx" -Destination "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName)-C.vhdx"
    }

    else {
        $null = Copy-Item "$($BaseVHDPath)\VMServerBase2019.vhdx" -Destination "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName)-C.vhdx"
    }

    Write-Log $VMName 'Creating virtual machine'
    New-VM -Name $VMName -MemoryStartupBytes 4GB -SwitchName $virtualSwitchName -Generation 2 -Path "$($VMPath)\" | Set-VM -ProcessorCount 2 
    Write-Log $VMName 'Setting VM VLAN to '$($VLANID)''
    Set-VMNetworkAdapterVlan -VMName $VMName -VlanId $VLANID -Access #Steve this is custom and needs to be changed here during build time
    Write-Log $VMName 'Configuring Secure Boot Template'
    Set-VMFirmware -VMName $VMName -SecureBootTemplate MicrosoftUEFICertificateAuthority
    Set-VMFirmware -Vmname $VMName -EnableSecureBoot off
    Write-Log $VMName 'Adding Virtual Hard Disk C'
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName)-C.vhdx" -ControllerType SCSI
    Write-Log $VMName 'Starting virtual machine'
    Enable-VMIntegrationService -Name 'Guest Service Interface' -VMName $VMName
    start-vm $VMName
}

function Create-FabricVM {
    #Updated 08-30-22 - Setting Default IP Address of Domain Controller DNS Server to ($Subnet)11 from ($Subnet)1
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
                Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ServerAddresses "$($Subnet)11" #Modify this with the IP of your 1st DC in the Dark Fabric -DK 08-30-22
            }
        }
        Write-Output -InputObject "[$($VMName)]:: Renaming OS to `"$($GuestOSName)`""
        Rename-Computer -NewName $GuestOSName
        Write-Output -InputObject "[$($VMName)]:: Configuring WSMAN Trusted hosts"
        Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value "*.$($domainName)" -Force
        Set-Item WSMan:\localhost\client\trustedhosts "$($Subnet)*" -Force -concatenate
        Enable-WSManCredSSP -Role Client -DelegateComputer "*.$($domainName)" -Force
        
    } -ArgumentList $IPNumber, $GuestOSName, $VMName, $domainName, $Subnet

    Restart-FabricVM -VMName $VMName
    
    Wait-PSDirect $VMName -cred $localCred
}

Function Install-WSUS {
    #Installs WSUS to the Target VM in the Lab
    #Script core functions from Eric @XenAppBlog
    #Modified 08-30-22 - Remove Requirements for Online Access for SYNC - DARK Fabric
    param
    (
        [string]$VMName, 
        [string]$GuestOSName
    )

    #Adding WSUS Drive 

    New-VHD -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - WSUS Data 1.vhdx" -Dynamic -SizeBytes 400GB 
    Mount-VHD -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - WSUS Data 1.vhdx"
    $DiskNumber = (Get-Diskimage -ImagePath "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - WSUS Data 1.vhdx").Number
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT 
    Get-Disk -Number $DiskNumber | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "WSUS" -Confirm:$False
    Dismount-VHD -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - WSUS Data 1.vhdx"
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - WSUS Data 1.vhdx" -ControllerType SCSI
  



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
        Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Windows Server 2022" } | Set-WsusProduct
        Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Windows Server 2019" } | Set-WsusProduct
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
        #$subscription.StartSynchronization()

        Write-Verbose "Monitor Progress of Synchronisation" -Verbose

        <#>Start-Sleep -Seconds 60 # Wait for sync to start before monitoring
	    while ($subscription.GetSynchronizationProgress().ProcessedItems -ne $subscription.GetSynchronizationProgress().TotalItems) {
		    #$subscription.GetSynchronizationProgress().ProcessedItems * 100/($subscription.GetSynchronizationProgress().TotalItems)
		    Start-Sleep -Seconds 5
   
	}
    </#>
    }


    #Restart-FabricVM $VMName
    
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
 
function Get-SQLServerISO {
#Ask for ISO 
#Needs to be Copied Manually for the Dark Fabric

        [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
        $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            Title="Please select ISO image with SQL Server 2019"
        }
        $openFile.Filter = "iso files (*.iso)|*.iso|All files (*.*)|*.*" 
        If($openFile.ShowDialog() -eq "OK")
        {
            Write-Log  "File $($openfile.FileName) selected"
        } 
        if (!$openFile.FileName){
                WriteErrorAndExit  "Iso was not selected... Exitting"
            }
             $Global:SQLServerISO = $openfile.FileName
             Write-Host "File $SQLServerISO Selected" -ForegroundColor Cyan
        } 

function Get-SQLServerSSMS {
#Ask for SMSS ISO 
#Needs to be copied Manually for the Dark Fabric

        [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
        $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            Title="Please select SQL Server SSMS Executable"
        }
        $openFile.Filter = "iso files (*.iso)|*.iso|All files (*.*)|*.*" 
        If($openFile.ShowDialog() -eq "OK")
        {
            Write-Log  "File $($openfile.FileName) selected"
        } 
        if (!$openFile.FileName){
                WriteErrorAndExit  "Iso was not selected... Exitting"
            }
             $Global:SQLServerSSMS = $openfile.FileName
             Write-Host "File $SQLServerSSMS Selected" -ForegroundColor Cyan 
        } 

function Get-SQLServerCU {
#Ask for Latest Cumulative Update - Currently at CU17 as of August 2022
#I just manually downloaded this to the working folder
#Needs to be copied Manually for the Dark Fabric

        [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
        $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            Title="Please select SQL Server Latest CU"
        }
        $openFile.Filter = "iso files (*.iso)|*.iso|All files (*.*)|*.*" 
        If($openFile.ShowDialog() -eq "OK")
        {
            Write-Log  "File $($openfile.FileName) selected"
        } 
        if (!$openFile.FileName){
                WriteErrorAndExit  "Iso was not selected... Exitting"
            }
             $Global:SQLServerCU = $openfile.FileName
             Write-Host "File $SQLServerCU Selected" -ForegroundColor Cyan
        } 

function Get-SCOMISO {
#I just manually downloaded this to the working folder
#Needs to be copied Manually for the Dark Fabric

        [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
        $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            Title="Please select System Center Operations Manager 2022 ISO"
        }
        $openFile.Filter = "iso files (*.iso)|*.iso|All files (*.*)|*.*" 
        If($openFile.ShowDialog() -eq "OK")
        {
            Write-Log  "File $($openfile.FileName) selected"
        } 
        if (!$openFile.FileName){
                WriteErrorAndExit  "Iso was not selected... Exitting"
            }
             $Global:SCOMISO = $openfile.FileName
             Write-Host "File $SCOMISO Selected" -ForegroundColor Cyan 
        } 

function Get-Server2022CISBenchmarks {


        [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
        $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            Title="Please select Server 2022 CIS Benchmarks ZIP File"
        }
        $openFile.Filter = "iso files (*.iso)|*.iso|All files (*.*)|*.*" 
        If($openFile.ShowDialog() -eq "OK")
        {
            Write-Log  "File $($openfile.FileName) selected"
        } 
        if (!$openFile.FileName){
                WriteErrorAndExit  "Iso was not selected... Exitting"
            }
             $Global:Server2022CISBenchmarks = $openfile.FileName
             Write-Host "File $Server2022CISBenchmarks Selected" -ForegroundColor Cyan
        } 

function Get-Server2019CISBenchmarks {


        [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
        $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            Title="Please select Server 2019 CIS Benchmarks ZIP File"
        }
        $openFile.Filter = "iso files (*.iso)|*.iso|All files (*.*)|*.*" 
        If($openFile.ShowDialog() -eq "OK")
        {
            Write-Log  "File $($openfile.FileName) selected"
        } 
        if (!$openFile.FileName){
                WriteErrorAndExit  "Iso was not selected... Exitting"
            }
             $Global:Server2019CISBenchmarks = $openfile.FileName
             Write-Host "File $Server2019CISBenchmarks Selected" -ForegroundColor Cyan 
        } 

function Get-Server2022MicrosoftBaselines {


        [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
        $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            Title="Please select Microsoft Security Compliance Toolkit Downloads"
        }
        $openFile.Filter = "iso files (*.iso)|*.iso|All files (*.*)|*.*" 
        If($openFile.ShowDialog() -eq "OK")
        {
            Write-Log  "File $($openfile.FileName) selected"
        } 
        if (!$openFile.FileName){
                WriteErrorAndExit  "Iso was not selected... Exitting"
            }
             $Global:Server2022MicrosoftBaselines = $openfile.FileName
             Write-Host "File $Server2022MicrosoftBaselines Selected" -ForegroundColor Cyan 
        } 

function Get-Server2022DavesPolicies {


        [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
        $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            Title="Please select Dave's Zip file with Custom Group Policy Objects"
        }
        $openFile.Filter = "iso files (*.iso)|*.iso|All files (*.*)|*.*" 
        If($openFile.ShowDialog() -eq "OK")
        {
            Write-Log  "File $($openfile.FileName) selected"
        } 
        if (!$openFile.FileName){
                WriteErrorAndExit  "Iso was not selected... Exitting"
            }
             $Global:Server2022DavesPolicies = $openfile.FileName
             Write-Host "File $Server2022DavesPolicies Selected" -ForegroundColor Cyan 
        } 

function Get-MSODBC18 {


        [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
        $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            Title="Please select MS ODBC 18.1 Installer"
        }
        $openFile.Filter = "msodbcsql.msi|*.iso|All files (*.*)|*.*" 
        If($openFile.ShowDialog() -eq "OK")
        {
            Write-Log  "File $($openfile.FileName) selected"
        } 
        if (!$openFile.FileName){
                WriteErrorAndExit  "Iso was not selected... Exitting"
            }
             $Global:MSODBC = $openfile.FileName
             Write-Host "File $MSODBC Selected" -ForegroundColor Cyan 
        } 

function Get-MSOLEDBSQL {


        [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
        $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            Title="Please select MS OLEDBSQL 19 Installer"
        }
        $openFile.Filter = "msoledbsql.msi|*.iso|All files (*.*)|*.*" 
        If($openFile.ShowDialog() -eq "OK")
        {
            Write-Log  "File $($openfile.FileName) selected"
        } 
        if (!$openFile.FileName){
                WriteErrorAndExit  "Iso was not selected... Exitting"
            }
             $Global:MSOLEDBSQL = $openfile.FileName
             Write-Host "File $MSOLEDBSQL Selected" -ForegroundColor Cyan 
        }
        
function Get-MSNET462 {


        [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
        $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            Title="Please select MS .Net Framework 4.6.2 Offline Installer"
        }
        $openFile.Filter = "ndp462-kb3151800-x86-x64-allos-enu.exe|*.iso|All files (*.*)|*.*" 
        If($openFile.ShowDialog() -eq "OK")
        {
            Write-Log  "File $($openfile.FileName) selected"
        } 
        if (!$openFile.FileName){
                WriteErrorAndExit  "Iso was not selected... Exitting"
            }
             $Global:MSNet462 = $openfile.FileName
             Write-Host "File $MSNet462 Selected" -ForegroundColor Cyan 
        }  

function Get-VC_redistx64 {


        [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
        $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            Title="Please select Visual Studio Redistributable x64"
        }
        $openFile.Filter = "All files (*.*)|*.*" 
        If($openFile.ShowDialog() -eq "OK")
        {
            Write-Log  "File $($openfile.FileName) selected"
        } 
        if (!$openFile.FileName){
                WriteErrorAndExit  "Iso was not selected... Exitting"
            }
             $Global:VC_Redistx64 = $openfile.FileName
             Write-Host "File $VC_Redistx64 Selected" -ForegroundColor Cyan 
        } 

function Get-Server2022ISO {


        [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
        $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            Title="Please select Server2022 ISO"
        }
        $openFile.Filter = "iso files (*.iso)|*.iso|All files (*.*)|*.*" 
        If($openFile.ShowDialog() -eq "OK")
        {
            Write-Log  "File $($openfile.FileName) selected"
        } 
        if (!$openFile.FileName){
                WriteErrorAndExit  "Iso was not selected... Exitting"
            }
             $Global:Server2022ISO = $openfile.FileName
             Write-Host "File $Server2022ISO Selected" -ForegroundColor Cyan 
        } 


function Get-LAPSInstaller {


        [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
        $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            Title="Please select LAPS.x64.msi Installer"
        }
        $openFile.Filter = "iso files (*.iso)|*.iso|All files (*.*)|*.*" 
        If($openFile.ShowDialog() -eq "OK")
        {
            Write-Log  "File $($openfile.FileName) selected"
        } 
        if (!$openFile.FileName){
                WriteErrorAndExit  "Iso was not selected... Exitting"
            }
             $Global:LAPSMSI = $openfile.FileName
             Write-Host "File $LAPSMSI Selected" -ForegroundColor Cyan 
        } 

function Copy-DarkFabricAddonsDC1 {

    #Adds Extra Drive on Domain Controller for Group Policy Files to be imported
    param
    (
        [string]$VMName, 
        [string]$GuestOSName
    )

    Write-Output -InputObject "[$($VMName)]:: Adding Drive for Additional Files "

    New-VHD -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - Data 1.vhdx" -Dynamic -SizeBytes 60GB 
    Mount-VHD -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - Data 1.vhdx"
    $DiskNumber = (Get-Diskimage -ImagePath "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - Data 1.vhdx").Number
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT 
    Get-Disk -Number $DiskNumber | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data" -Confirm:$False
    $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object { $_.Label -like "Data" }
    
    $DataDriveLetter = $DriveLetter.DriveLetter
    Write-Output -InputObject "[$($VMName)]:: Copying CIS Server 2022 Security Baselines to $($VMName)"
    Copy-Item -Path $Server2022CISBenchmarks -Destination "$($DataDriveLetter)\CISServer2022v1.0.0.zip" -Force
    Write-Output -InputObject "[$($VMName)]:: Copying CIS Server 2019 Security Baselines to $($VMName)"
    Copy-Item -Path $Server2019CISBenchmarks -Destination "$($DataDriveLetter)\CISServer2019v1.3.0 (1).zip" -Force
    Write-Output -InputObject "[$($VMName)]:: Copying Microsoft Server 2019 and 2022 Baselines to $($VMName)"
    Copy-Item -Path $Server2022MicrosoftBaselines -Destination "$($DataDriveLetter)\MicrosoftServer2022Baselines.zip" -Force
    Write-Output -InputObject "[$($VMName)]:: Copying Custom Group Policy Objects - Dave's Policies to $($VMName)"
    Copy-Item -Path $Server2022DavesPolicies -Destination "$($DataDriveLetter)\DavesPolicies.zip" -Force
    Write-Output -InputObject "[$($VMName)]:: Copying LAPS.X64.MSI to $($VMName)"
    Copy-Item -Path $LAPSMSI -Destination "$($DataDriveLetter)\LAPS-X64.MSI" -Force
    Dismount-VHD -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - Data 1.vhdx"
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - Data 1.vhdx" -ControllerType SCSI

    Invoke-Command -VMName $VMName -Credential $domainCred {

        Write-Output -InputObject "[$($VMName)]:: Bringing 2nd VHDx online"
        Get-Disk | Where-Object OperationalStatus -EQ "Offline" | Set-Disk -IsOffline $False 
        Get-Disk | Where-Object Number -NE "0" | Set-Disk -IsReadOnly $False
        #$Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object { $_.Label -like "SCOM*" }
        #$SCOMDrive = $Driveletter.DriveLetter

        }
} 

function Copy-DarkFabricAddonsPAW {

    #Adds Extra Drive on Domain Controller for Group Policy Files to be imported
    param
    (
        [string]$VMName, 
        [string]$GuestOSName
    )

    Write-Output -InputObject "[$($VMName)]:: Adding Drive for Additional Files "

    New-VHD -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - Data 1.vhdx" -Dynamic -SizeBytes 60GB 
    Mount-VHD -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - Data 1.vhdx"
    $DiskNumber = (Get-Diskimage -ImagePath "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - Data 1.vhdx").Number
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT 
    Get-Disk -Number $DiskNumber | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data" -Confirm:$False
    $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object { $_.Label -like "Data" }
    $DataDriveLetter = $DriveLetter.DriveLetter
    Write-Output -InputObject "[$($VMName)]:: Copying LAPS.X64.MSI to $($VMName)"
    Copy-Item -Path $LAPSMSI -Destination "$($DataDriveLetter)\LAPS-X64.MSI" -Force
    Write-Output -InputObject "[$($VMName)]:: Copying SSMS to the new VHDx"
    Copy-Item -Path $SQLServerSSMS -Destination "$($DataDriveLetter)\SSMS-Setup-ENU.exe" -Force
    Dismount-VHD -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - Data 1.vhdx"
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - Data 1.vhdx" -ControllerType SCSI

    Invoke-Command -VMName $VMName -Credential $domainCred {

        Write-Output -InputObject "[$($VMName)]:: Bringing 2nd VHDx online"
        Get-Disk | Where-Object OperationalStatus -EQ "Offline" | Set-Disk -IsOffline $False 
        Get-Disk | Where-Object Number -NE "0" | Set-Disk -IsReadOnly $False
        #$Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object { $_.Label -like "SCOM*" }
        #$SCOMDrive = $Driveletter.DriveLetter

        }
} 

function Install-LAPSDC {

   
    param
    (
        [string]$VMName, 
        [string]$GuestOSName
    )

    Invoke-Command -VMName $VMName -Credential $domainCred {
    Write-Output -InputObject "[$($VMName)]:: Finding DataDrive "

    $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object { $_.Label -like "Data" }
    
    $DataDriveLetter = $DriveLetter.DriveLetter
    Write-Output -InputObject "[$($VMName)]:: Installing LAPS X64 to $($VMName)"
    cmd.exe /c "MsiExec.exe /i $DataDriveLetter\LAPS-x64.msi ADDLOCAL=Management,Management.UI,Management.PS,Management.ADMX ALLUSERS=1 /qn /l*v $datadriveletter\laps-x64-install.log"
    Write-Output -InputObject "[$($VMName)]:: Importing LAPS Powershell Module"
    Import-Module AdmPwd.PS
    Write-Output -InputObject "[$($VMName)]:: Update AD Schema to Support LAPS"
    Update-AdmPwdADSchema
    Write-Output -InputObject "[$($VMName)]:: Configuring OU Permssions for LAPS"
    Set-AdmPwdComputerSelfPermission -OrgUnit Fabric
    Set-AdmPwdReadPasswordPermission -Identity Fabric -AllowedPrincipals "LAPS Admins"
    Find-AdmPwdExtendedRights -Identity Fabric -verbose
    Write-Output -InputObject "[$($VMName)]:: Finished LAPS Base Install You will need to configure additional Settings GPO etc."
    }
}

function Install-LAPSPAW {

   
    param
    (
        [string]$VMName, 
        [string]$GuestOSName
    )

    Invoke-Command -VMName $VMName -Credential $domainCred {
    Write-Output -InputObject "[$($VMName)]:: Finding DataDrive "

    $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object { $_.Label -like "Data" }
    
    $DataDriveLetter = $DriveLetter.DriveLetter
    Write-Output -InputObject "[$($VMName)]:: Installing LAPS X64 to $($VMName)"
    MsiExec.exe /i $DataDriveLetter\LAPS-x64.msi ADDLOCAL=Management,Management.UI,Management.PS,Management.ADMX ALLUSERS=1 /qn /l*v d:\laps-x64-install.log
        }
}

function Remove-MSEdge {

 param
    (
        [string]$VMName, 
        [string]$GuestOSName
    )

Invoke-Command -VMName $VMName -Credential $domainCred {

Write-Output -InputObject "[$($VMName)]:: Removing / Uninstalling MSEdge "
 
$location = get-location 
set-location 'C:\Program Files (x86)\Microsoft\Edge\Application\86.0.622.38\installer'
cmd.exe /c ".\setup.exe --uninstall --system-level --verbose-logging --force-uninstall"
set-location $location

}
}


function Install-WSUSADMINPAW {

   
    param
    (
        [string]$VMName, 
        [string]$GuestOSName
    )

    Invoke-Command -VMName $VMName -Credential $domainCred {
    Write-Output -InputObject "[$($VMName)]:: Installing WSUS Admin Console "

    Install-WindowsFeature -Name UpdateServices-UI -Verbose
        }
}

function Install-SSMSPAW{
 param
    (
        [string]$VMName, 
        [string]$GuestOSName
    )

 Invoke-Command -VMName $VMName -Credential $domainCred {

$Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object { $_.Label -eq "Data" }
$DataDrive = $Driveletter.DriveLetter
$DataDrive

#$setupfile = "$($VMMDrive)\SSMS-Setup-ENU.exe"
Write-Output -InputObject "[$($VMName)]:: Installing SSMS"
cmd.exe /c "$($DataDrive)\SSMS-Setup-ENU.exe /install /quiet /norestart /log .\ssmssetup.log"

}
}

function Install-SSMSSCOM{
 param
    (
        [string]$VMName, 
        [string]$GuestOSName
    )

 Invoke-Command -VMName $VMName -Credential $domainCred {

$Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object { $_.Label -eq "SQLInstall" }
$DataDrive = $Driveletter.DriveLetter
$DataDrive

Write-Output -InputObject "[$($VMName)]:: Installing SSMS"
cmd.exe /c "$($DataDrive)\SSMS-Setup-ENU.exe /install /quiet /norestart /log .\ssmssetup.log"

}
}
    
Function Create-SQLInstallFile {
    #You will need to modify this for your environment accounts
    #Updated With Password Variables now and Domain Variables - 08-30-2022 -DK
    #I will automate this later on - Steve we need to work on this

    Write-Output -InputObject "[$($VMName)]:: Creating SQL Install INI File"
    $functionText = @"
;SQL Server 2019 Configuration File
[OPTIONS]

; By specifying this parameter and accepting Microsoft Python Open and Microsoft Python Server terms, you acknowledge that you have read and understood the terms of use. 

IACCEPTPYTHONLICENSETERMS="True"

; Specifies a Setup work flow, like INSTALL, UNINSTALL, or UPGRADE. This is a required parameter. 

ACTION="Install"

; By specifying this parameter and accepting Microsoft R Open and Microsoft R Server terms, you acknowledge that you have read and understood the terms of use. 

IACCEPTROPENLICENSETERMS="True"
IAcceptSQLServerLicenseTerms="True"

; Specifies that SQL Server Setup should not display the privacy statement when ran from the command line. 

SUPPRESSPRIVACYSTATEMENTNOTICE="True"

; Use the /ENU parameter to install the English version of SQL Server on your localized Windows operating system. 

ENU="True"

; Setup will not display any user interface. 

QUIET="True"

; Setup will display progress only, without any user interaction. 

QUIETSIMPLE="False"

; Parameter that controls the user interface behavior. Valid values are Normal for the full UI,AutoAdvance for a simplied UI, and EnableUIOnServerCore for bypassing Server Core setup GUI block. 

;UIMODE="Normal"

; Specify whether SQL Server Setup should discover and include product updates. The valid values are True and False or 1 and 0. By default SQL Server Setup will include updates that are found. 

UpdateEnabled="False"

; If this parameter is provided, then this computer will use Microsoft Update to check for updates. 

USEMICROSOFTUPDATE="False"

; Specifies that SQL Server Setup should not display the paid edition notice when ran from the command line. 

SUPPRESSPAIDEDITIONNOTICE="False"

; Specify the location where SQL Server Setup will obtain product updates. The valid values are "MU" to search Microsoft Update, a valid folder path, a relative path such as .\MyUpdates or a UNC share. By default SQL Server Setup will search Microsoft Update or a Windows Update service through the Window Server Update Services. 

UpdateSource="MU"

; Specifies features to install, uninstall, or upgrade. The list of top-level features include SQL, AS, IS, MDS, and Tools. The SQL feature will install the Database Engine, Replication, Full-Text, and Data Quality Services (DQS) server. The Tools feature will install shared components. 

FEATURES=SQLENGINE,FullText

; Displays the command line parameters usage. 

HELP="False"

; Specifies that the detailed Setup log should be piped to the console. 

INDICATEPROGRESS="False"

; Specifies that Setup should install into WOW64. This command line argument is not supported on an IA64 or a 32-bit system. 

X86="False"

; Specify a default or named instance. MSSQLSERVER is the default instance for non-Express editions and SQLExpress for Express editions. This parameter is required when installing the SQL Server Database Engine (SQL), or Analysis Services (AS). 

INSTANCENAME="MSSQLSERVER"

; Specify the root installation directory for shared components.  This directory remains unchanged after shared components are already installed. 

INSTALLSHAREDDIR="D:\Program Files\Microsoft SQL Server"

; Specify the root installation directory for the WOW64 shared components.  This directory remains unchanged after WOW64 shared components are already installed. 

INSTALLSHAREDWOWDIR="D:\Program Files (x86)\Microsoft SQL Server"

; Specify the Instance ID for the SQL Server features you have specified. SQL Server directory structure, registry structure, and service names will incorporate the instance ID of the SQL Server instance. 

INSTANCEID="MSSQLSERVER"

; Account for SQL Server CEIP service: Domain\User or system account. 

SQLTELSVCACCT="NT Service\SQLTELEMETRY"

; Startup type for the SQL Server CEIP service. 

SQLTELSVCSTARTUPTYPE="Automatic"

; Specify the installation directory. 

INSTANCEDIR="D:\Program Files\Microsoft SQL Server"

; Agent account name 

AGTSVCACCOUNT="$DomainName\SV_SQL_AGENT"
AGTSVCPASSWORD="$SV_SQL_AGENT_Password"


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

; The max degree of parallelism (MAXDOP) server configuration option. 

SQLMAXDOP="2"

; Set to "1" to enable RANU for SQL Server Express. 

ENABLERANU="False"

; Specifies a Windows collation or an SQL collation to use for the Database Engine. 

SQLCOLLATION="SQL_Latin1_General_CP1_CI_AS"

; Account for SQL Server service: Domain\User or system account. 

SQLSVCACCOUNT="$DomainName\SV_SQL"
SQLSVCPASSWORD="$SV_SQL_Password"

; Set to "True" to enable instant file initialization for SQL Server service. If enabled, Setup will grant Perform Volume Maintenance Task privilege to the Database Engine Service SID. This may lead to information disclosure as it could allow deleted content to be accessed by an unauthorized principal. 

SQLSVCINSTANTFILEINIT="True

; Windows account(s) to provision as SQL Server system administrators. 

SQLSYSADMINACCOUNTS="$DomainName\SQL Admins"

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

; The Database Engine root data directory. 

INSTALLSQLDATADIR="H:\Program Files\Microsoft SQL Server"

; Default directory for the Database Engine user database logs. 

SQLUSERDBLOGDIR="F:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\Data"

; Directories for Database Engine TempDB files. 

SQLTEMPDBDIR="E:\TEMPDB"

; Directory for the Database Engine TempDB log files. 

SQLTEMPDBLOGDIR="G:\TEMPLogs"

; Provision current user as a Database Engine system administrator for SQL Server 2019 Express. 

ADDCURRENTUSERASSQLADMIN="False"

; Specify 0 to disable or 1 to enable the TCP/IP protocol. 

TCPENABLED="1"

; Specify 0 to disable or 1 to enable the Named Pipes protocol. 

NPENABLED="0"

; Startup type for Browser Service. 

BROWSERSVCSTARTUPTYPE="Disabled"

; Use USESQLRECOMMENDEDMEMORYLIMITS to minimize the risk of the OS experiencing detrimental memory pressure. 

USESQLRECOMMENDEDMEMORYLIMITS="True"

"@

    New-Item "$($WorkingDir)\SqlInstall.ini" -type file -force -value $functionText

}


Function Install-SQL {
    #Installs SQL Server 2019 in the Lab
    param
    (
        [string]$VMName, 
        [string]$GuestOSName
    )

    Write-Output -InputObject "[$($VMName)]:: Adding Drive for SQL Install"

    New-VHD -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SQL Data 1.vhdx" -Dynamic -SizeBytes 60GB 
    Mount-VHD -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SQL Data 1.vhdx"
    $DiskNumber = (Get-Diskimage -ImagePath "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SQL Data 1.vhdx").Number
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT 
    Get-Disk -Number $DiskNumber | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "SQLInstall" -Confirm:$False
    $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object { $_.Label -like "SQLInstall*" }
    $SQLDriveLetter = $DriveLetter.DriveLetter
    Write-Output -InputObject "[$($VMName)]:: Copying SQL ISO to the new VHDx"
    Copy-Item -Path $SQLServerIso -Destination "$($SQLDriveLetter)\en_sql_server_2019.iso" -Force
    Write-Output -InputObject "[$($VMName)]:: Copying SQLInstall.ini to the new VHDx"
    Copy-Item -Path "$($WorkingDir)\SQLInstall.ini" -Destination "$($SQLDriveLetter)\SQLInstall.ini" -Force
    Write-Output -InputObject "[$($VMName)]:: Copying SSMS to the new VHDx"
    Copy-Item -Path $SQLServerSSMS -Destination "$($SQLDriveLetter)\SSMS-Setup-ENU.exe" -Force
    Write-Output -InputObject "[$($VMName)]:: Copying SQL Server Cumulative Update KB5016394-x64 to the new VHDx" #Modify This depending on the newer Version this is as of AUG 2022
    Copy-Item -Path $SQLServerCU -Destination "$($SQLDriveLetter)\SQLServer2019-KB5016394-x64.exe" -Force
    Dismount-VHD -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SQL Data 1.vhdx"
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SQL Data 1.vhdx" -ControllerType SCSI
    New-VHD -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SQL Data 2.vhdx" -Dynamic -SizeBytes 400GB 
    Mount-VHD -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SQL Data 2.vhdx"
    $DiskNumber = (Get-Diskimage -ImagePath "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SQL Data 2.vhdx").Number
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT 
    Get-Disk -Number $DiskNumber | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "SQLData" -AllocationUnitSize "65536" -Confirm:$False
    New-VHD -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SQL Data 3.vhdx" -Dynamic -SizeBytes 100GB
    Dismount-VHD -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SQL Data 2.vhdx"
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SQL Data 2.vhdx" -ControllerType SCSI 
    Mount-VHD -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SQL Data 3.vhdx"
    $DiskNumber = (Get-Diskimage -ImagePath "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SQL Data 3.vhdx").Number
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT 
    Get-Disk -Number $DiskNumber | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "SQLLOG" -AllocationUnitSize "65536" -Confirm:$False
    Dismount-VHD -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SQL Data 3.vhdx"
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SQL Data 3.vhdx" -ControllerType SCSI
    New-VHD -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SQL Data 4.vhdx" -Dynamic -SizeBytes 30GB 
    Mount-VHD -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SQL Data 4.vhdx"
    $DiskNumber = (Get-Diskimage -ImagePath "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SQL Data 4.vhdx").Number
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT 
    Get-Disk -Number $DiskNumber | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "TEMPDB" -AllocationUnitSize "65536" -Confirm:$False
    Dismount-VHD -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SQL Data 4.vhdx"
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SQL Data 4.vhdx" -ControllerType SCSI
    New-VHD -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SQL Data 5.vhdx" -Dynamic -SizeBytes 30GB 
    Mount-VHD -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SQL Data 5.vhdx"
    $DiskNumber = (Get-Diskimage -ImagePath "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SQL Data 5.vhdx").Number
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT 
    Get-Disk -Number $DiskNumber | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "TEMPLOG" -AllocationUnitSize "65536" -Confirm:$False
    Dismount-VHD -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SQL Data 5.vhdx"
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SQL Data 5.vhdx" -ControllerType SCSI
         
    Invoke-Command -VMName $VMName -Credential $domainCred {

        Write-Output -InputObject "[$($VMName)]:: Adding the new VHDx for the SQL Install"
        Get-Disk | Where-Object OperationalStatus -EQ "Offline" | Set-Disk -IsOffline $False 
        Get-Disk | Where-Object Number -NE "0" | Set-Disk -IsReadOnly $False
        $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object { $_.Label -eq "SQLInstall" }
        $SQLDrive = $Driveletter.DriveLetter
        $SQLDrive

        Write-Output -InputObject "[$($VMName)]:: Mounting SQL ISO"

        $iso = Get-ChildItem -Path "$($SQLDrive)\en_sql_server_2019.iso"  #CHANGE THIS!

        Mount-DiskImage $iso.FullName

        Write-Output -InputObject "[$($VMName)]:: Configuring WIndows Firewall for SQL New Rules"
        New-NetFirewallRule -DisplayName "SQL 2019 Exceptions-TCP" -Direction Inbound -Protocol TCP -Profile Domain -LocalPort 135, 1433, 1434, 4088, 80, 443 -Action Allow
 
        Write-Output -InputObject "[$($VMName)]:: Adding sv_sql to the Local Admins Group"
        Add-LocalGroupMember -Group "Administrators" -Member "$DomainName\sv_sql"

        Write-Output -InputObject "[$($VMName)]:: Running SQL Unattended Install"

        $setup = $(Get-DiskImage -ImagePath $iso.FullName | Get-Volume).DriveLetter + ':' 
        $setup
        cmd.exe /c "$($Setup)\setup.exe /ConfigurationFile=$($SQLDrive)\SqlInstall.ini"

        Write-Output -InputObject "[$($VMName)]:: Updating SQL Server 2019 with CU17"
        cmd.exe /c "$($SQLDrive)\SQLServer2019-KB5016394-x64 /X:$($SQLDrive)\sqlserver_cu\KB5016394-64"
        cmd.exe /c "$($SQLDrive)\sqlserver_cu\KB5016394-64\setup.exe /action=patch /instancename=MSSQLSERVER /quiet /IAcceptSQLServerLicenseTerms"

        Write-Output -InputObject "[$($VMName)]:: Installing SSMS"

        cmd.exe /c "$($SQLDrive)\SSMS-Setup-ENU.exe /install /quiet /norestart /log .\ssmssetup.log"

    }

    # run installer with arg-list built above, including config file and service/SA accounts

    #Start-Process -Verb runas -FilePath $setup -ArgumentList $arglist -Wait


    #Write-Output -InputObject "[$($VMName)]:: Downloading SSMS"
    #Invoke-Webrequest was REALLY SLOW
    #Invoke-webrequest -uri https://go.microsoft.com/fwlink/?linkid=864329 -OutFile "$($SQLDrive)\SSMS-Setup-ENU.exe"
    #Changing to System.Net.WebClient
    # (New-Object System.Net.WebClient).DownloadFile("https://go.microsoft.com/fwlink/?linkid=864329","$($SQLDrive)\SSMS-Setup-ENU.exe")    



    # You can grab SSMS here:    https://docs.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms



    #$setupfile = "$($VMMDrive)\SSMS-Setup-ENU.exe"
   # Write-Output -InputObject "[$($VMName)]:: Installing SSMS"

    #cmd.exe /c "$($SQLDrive)\SSMS-Setup-ENU.exe /install /quiet /norestart /log .\ssmssetup.log"

  

    # un-mount the install image when done after waiting 1 second (just for kicks)

    Start-Sleep -Seconds 1

    Dismount-DiskImage $iso.FullName
    
}

Function Configure-TLS1.2 {
#Harden Server 2022 by only allowing TLS1.2
#Required for SCOM 2022 Security and to pass Cyber Audit
#This is breaking the SCOM 2022 Installer right now - 09-01-22 - DK

param
    (
        [string]$VMName, 
        [string]$GuestOSName
    )
     Write-Output -InputObject "[$($VMName)]:: Hardening for TLS 1.2"
Invoke-Command -VMName $VMName -Credential $domainCred {

$ProtocolList       = @("SSL 2.0", "SSL 3.0", "TLS 1.0", "TLS 1.1", "TLS 1.2")
$ProtocolSubKeyList = @("Client", "Server")
$DisabledByDefault  = "DisabledByDefault"
$registryPath       = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\"

foreach ($Protocol in $ProtocolList)
{
	foreach ($key in $ProtocolSubKeyList)
	{
		$currentRegPath = $registryPath + $Protocol + "\" + $key
		Write-Output "Current Registry Path: `"$currentRegPath`""

		if (!(Test-Path $currentRegPath))
		{
			Write-Output " `'$key`' not found: Creating new Registry Key"
			New-Item -Path $currentRegPath -Force | out-Null
		}
		if ($Protocol -eq "TLS 1.2")
		{
			Write-Output " Enabling - TLS 1.2"
			New-ItemProperty -Path $currentRegPath -Name $DisabledByDefault -Value "0" -PropertyType DWORD -Force | Out-Null
			New-ItemProperty -Path $currentRegPath -Name 'Enabled' -Value "1" -PropertyType DWORD -Force | Out-Null
		}
		else
		{
			Write-Output " Disabling - $Protocol"
			New-ItemProperty -Path $currentRegPath -Name $DisabledByDefault -Value "1" -PropertyType DWORD -Force | Out-Null
			New-ItemProperty -Path $currentRegPath -Name 'Enabled' -Value "0" -PropertyType DWORD -Force | Out-Null
		}
		Write-Output " "
	}
}

Exit 0

}

Invoke-Command -VMName $VMName -Credential $domainCred {
    # Tighten up the .NET Framework
$NetRegistryPath = "HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319"
New-ItemProperty -Path $NetRegistryPath -Name "SchUseStrongCrypto" -Value "1" -PropertyType DWORD -Force | Out-Null

$NetRegistryPath = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319"
New-ItemProperty -Path $NetRegistryPath -Name "SchUseStrongCrypto" -Value "1" -PropertyType DWORD -Force | Out-Null
}
}


Function Install-SCOMPrereqs {

#Clean this up there are duplicate features - Create one install block
 param
    (
        [string]$VMName, 
        [string]$GuestOSName,
        [string]$VMMDomain
    )
    Write-Output -InputObject "[$($VMName)]:: Adding Roles and Features for SCOM Install"

    Invoke-Command -VMName $VMName -Credential $domainCred {
    Add-WindowsFeature NET-WCF-HTTP-Activation45,Web-Static-Content,Web-Default-Doc,Web-Dir-Browsing,Web-Http-Errors,Web-Http-Logging,Web-Request-Monitor,Web-Filtering,Web-Stat-Compression,Web-Mgmt-Console,Web-Metabase,Web-Asp-Net,Web-Windows-Auth
    Write-Output -InputObject "[$($VMName)]:: Enabling Feature AuthManager"
    dism /online /enable-feature /featurename:AuthManager 

    Write-Output -InputObject "[$($VMName)]:: Enabling Other Features for SCOM 2022"
    Add-WindowsFeature Web-Static-Content, Web-Default-Doc, Web-Dir-Browsing, Web-Http-Errors, Web-Http-Logging, Web-Request-Monitor, Web-Filtering, Web-Stat-Compression, Web-Metabase, Web-Asp-Net, Web-Windows-Auth, Web-ASP, Web-CGI
  
}
}
    
Function Install-SCOM {

    #Installs SCOM 2022 in the Lab Offline Instalelr
    #First Download the following Pre-Reqs
    #Special Considerations for Pre-Reqs for TLS 1.2 Support for Server 2022 and SCOM 2022 --> This is causing issues with the installer
    #https://go.microsoft.com/fwlink/?linkid=2186934 - SQL OLE 19.00
    #https://go.microsoft.com/fwlink/?linkid=2202930 - ODBC 18.1
    #https://aka.ms/vs/17/release/vc_redist.x86.exe
    
    
  






    param
    (
        [string]$VMName, 
        [string]$GuestOSName,
        [string]$VMMDomain
    )

    Write-Output -InputObject "[$($VMName)]:: Adding Drive for SCOM Install"
    New-VHD -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SCOM Data 1.vhdx" -Dynamic -SizeBytes 50GB 
    Mount-VHD -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SCOM Data 1.vhdx" 
    $DiskNumber = (Get-Diskimage -ImagePath "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SCOM Data 1.vhdx").Number
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT 
    Get-Disk -Number $DiskNumber | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "SCOM" -Confirm:$False
    $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object { $_.Label -like "SCOM*" }
    $SCOMDriveLetter = $DriveLetter.DriveLetter
    Write-Output -InputObject "[$($VMName)]:: Copying SCOM 2022 ISO to the new VHDx"
    Copy-Item -Path $SCOMISO -Destination "$($SCOMDriveLetter)\SCOM2022.iso" -Force
    Write-Output -InputObject "[$($VMName)]:: Copying MSOLEDBSQL 19 Installer to the new VHDx"
    Copy-Item -Path $MSOLEDBSQL -Destination "$($SCOMDriveLetter)\msoledbsql.msi" -Force
    Write-Output -InputObject "[$($VMName)]:: Copying MSODBC 18.1 Installer to the new VHDx"
    Copy-Item -Path $MSODBC -Destination "$($SCOMDriveLetter)\msodbcsql.msi" -Force
    #Write-Output -InputObject "[$($VMName)]:: Copying .Net Framework 4.6.2 Offline Installer to the new VHDx"
    #Copy-Item -Path $MSNet462 -Destination "$($SCOMDriveLetter)\ndp462-kb3151800-x86-x64-allos-enu.exe" -Force
    Write-Output -InputObject "[$($VMName)]:: Copying VC_Redistributable x64 to the new VHDx"
    Copy-Item -Path $VC_Redistx64 -Destination "$($SCOMDriveLetter)\VC_redist.x64.exe" -Force
    Write-Output -InputObject "[$($VMName)]:: Copying Server 2022 ISO to the new VHDx"
    Copy-Item -Path $Server2022ISO -Destination "$($SCOMDriveLetter)\Server2022.ISO" -Force
    Dismount-VHD -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SCOM Data 1.vhdx"    
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - SCOM Data 1.vhdx" -ControllerType SCSI
  

    Invoke-Command -VMName $VMName -Credential $domainCred {

        Write-Output -InputObject "[$($VMName)]:: Bringing the new VHDx for the SCOM Install online"
        Get-Disk | Where-Object OperationalStatus -EQ "Offline" | Set-Disk -IsOffline $False 
        Get-Disk | Where-Object Number -NE "0" | Set-Disk -IsReadOnly $False
        $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object { $_.Label -like "SCOM*" }
        $SCOMDrive = $Driveletter.DriveLetter

        # Write-Output -InputObject "[$($VMName)]:: Mounting SCOM 2022 ISO"
        #$iso1 = Get-ChildItem -Path "$($SCOMDRIVE)\SCOM2022.iso"  #CHANGE THIS!

       # Mount-DiskImage $iso1.FullName

       # $setup = $(Get-DiskImage -ImagePath $iso1.FullName | Get-Volume).DriveLetter + ':' 
        
        
        
        Write-Output -InputObject "[$($VMName)]:: Mounting Server 2022 ISO"
        $iso2 = Get-ChildItem -Path "$($SCOMDRIVE)\Server2022.iso"  #CHANGE THIS!

        Mount-DiskImage $iso2.FullName

        $setup1 = $(Get-DiskImage -ImagePath $iso2.FullName | Get-Volume).DriveLetter + ':' 
        Write-Output -InputObject "[$($VMName)]:: Mounted Server 2022 ISO as Drive:$setup"

        Write-Output -InputObject "[$($VMName)]:: Working Some Magic to Install ASP.NET on Server 2022"

        dism.exe /online /enable-feature /all /featurename:NetFX3 /source:$setup1\sources\sxs /LimitAccess

        
        }

    Restart-FabricVM -VMName $VMName
    Wait-PSDirect -VMName $VMName -cred $DomainCred 
    Invoke-Command -VMName $VMName -Credential $domainCred {
      Write-Output -InputObject "[$($VMName)]:: Now Installing Features for SCOM"
      Add-WindowsFeature NET-WCF-HTTP-Activation45,Web-Static-Content,Web-Default-Doc,Web-Dir-Browsing,Web-Http-Errors,Web-Http-Logging,Web-Request-Monitor,Web-Filtering,Web-stat-Compression,Web-Metabase,Web-Asp-Net,Web-Windows-Auth,web-mgmt-console,web-asp,web-asp-net,-verbose

        }

    Restart-FabricVM -VMName $VMName
    Wait-PSDirect -VMName $VMName -cred $DomainCred
        #Add-WindowsFeature Web-ASP-Net -verbose
        #Add-WindowsFeature Web-Metabase, Web-Asp,Web-Asp-Net,Web-Windows-Auth,Web-Static-Content,Web-Dir-Browsing,Web-Http-Errors,Web-Http-Logging,Web-Request-Monitor,Web-Stat-Compression -verbose
        #Add-WindowsFeature NET-WCF-HTTP-Activation45 -verbose
        #Was having an issue with above failing SCOM Pre-Reqs on Server 2022
        #This VooDoo Fixed it - 09-01-22 -DK - Looks like SxS old .NET issues still persist in Server 2022
       
       

       <#>SCOM 2019 stuff to be removed
        Write-Output -InputObject "[$($VMName)]:: Downloading SQLSysCLRTypes.MSI"

        #  SQLSysClrTypes: https://download.microsoft.com/download/1/3/0/13089488-91FC-4E22-AD68-5BE58BD5C014/ENU/x64/SQLSysClrTypes.msi
        Invoke-webrequest -uri https://download.microsoft.com/download/1/3/0/13089488-91FC-4E22-AD68-5BE58BD5C014/ENU/x64/SQLSysClrTypes.msi -OutFile "$($SCOMDrive)\SQLSysClrTypes.msi"


        Write-Output -InputObject "[$($VMName)]:: Downloading ReportViewer.msi"
        #ReportViewer: http://download.microsoft.com/download/F/B/7/FB728406-A1EE-4AB5-9C56-74EB8BDDF2FF/ReportViewer.msi

        Invoke-webrequest -uri http://download.microsoft.com/download/A/1/2/A129F694-233C-4C7C-860F-F73139CF2E01/ENU/x86/ReportViewer.msi -OutFile "$($SCOMDrive)\ReportViewer.msi"
        #Invoke-webrequest -uri https://go.microsoft.com/fwlink/p/?linkid=859206 -OutFile "$($VMMDrive)\adksetup.exe"
        # (New-Object System.Net.WebClient).DownloadFile("https://go.microsoft.com/fwlink/p/?linkid=859206","f:\iso\adksetup.exe")

        #Sample ADK install


            

        Write-Output -InputObject "[$($VMName)]:: Installing SQLSYSCLRTypes"
        cmd.exe /c "msiexec /i $SCOMDrive\SQLSysClrTypes.msi /q"

        Write-Output -InputObject "[$($VMName)]:: Installing ReportViewer"
        cmd.exe /c "msiexec /i $SCOMDrive\ReportViewer.msi /q"

        </#>
Invoke-Command -VMName $VMName -Credential $domainCred {
        Write-Output -InputObject "[$($VMName)]:: Mounting SCOM ISO"
        $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object { $_.Label -like "SCOM*" }
        $SCOMDrive = $Driveletter.DriveLetter

        Write-Output -InputObject "[$($VMName)]:: Mounting SCOM 2022 ISO"
        $iso1 = Get-ChildItem -Path "$($SCOMDRIVE)\SCOM2022.iso"  #CHANGE THIS!

        Mount-DiskImage $iso1.FullName

        $setup = $(Get-DiskImage -ImagePath $iso1.FullName | Get-Volume).DriveLetter + ':' 

        Write-Output -InputObject "[$($VMName)]:: Un-Blocking files on $ScomDrive blocked by SmartScreen"
        #dir $scomdrive /s | Unblock-File -verbose

        Write-Output -InputObject "[$($VMName)]:: Adding SCOM Admins to the Local Admins Group"
        Add-LocalGroupMember -Group "Administrators" -Member "$DomainName\SCOM Admins"
        Add-LocalGroupMember -Group "Administrators" -Member "$DomainName\sv_scom_das"
        Add-LocalGroupMember -Group "Administrators" -Member "$DomainName\sv_scom_aa"
        Add-LocalGroupMember -Group "Administrators" -Member "$DomainName\sv_scom_read"
        Add-LocalGroupMember -Group "Administrators" -Member "$DomainName\sv_scom_write"

        Write-Output -InputObject "[$($VMName)]:: VC Redistributable x64 - Pre-req"
        cmd.exe /c "$Scomdrive\vc_redist.x64.exe /install /quiet /norestart /log $scomdrive\VC_ReDIST_x64-Install.log"

        Write-Output -InputObject "[$($VMName)]:: Installing MSOLEDBSQL 19"
        cmd.exe /c "msiexec /i $SCOMDrive\msoledbsql.msi /qn IACCEPTMSOLEDBSQLLICENSETERMS=YES /l*v $SCOMDRIVE\MSOLEDBInstall.log"

        Write-Output -InputObject "[$($VMName)]:: Installing MSODBC 18.1"
        cmd.exe /c "msiexec /i $SCOMDrive\msodbcsql.msi /qn IACCEPTMSODBCSQLLICENSETERMS=YES /l*v $SCOMDRIVE\MSODBCSQLInstall.log"

        #Write-Output -InputObject "[$($VMName)]:: Installing .NET Framework 4.6.2 offline installer"
        #cmd.exe /c "$SCOMDrive\ndp462-kb3151800-x86-x64-allos-enu.exe /q /norestart"
        Write-Output -InputObject "[$($VMName)]:: Extracting SCOM 2022"
        $Null = cmd.exe /c "$Setup\SCOM_2022.exe /dir=$SCOMdrive\SCOM /silent"
                    
        Write-Output -InputObject "[$($VMName)]:: Installing SCOM 2022"
        cmd.exe /c "$SCOMDrive\SCOM\setup.exe /install /components:OMServer,OMWebConsole,OMConsole /InstallPath:""$SCOMDrive\Program Files\System Center\Operations Manager"" /ManagementGroupName:$SCOMMGMTGRoup /SqlServerInstance:$SQLServer\MSSQLSERVER /DatabaseName:OperationsManager /DWSqlServerInstance:$SQLServer\MSSQLSERVER /DWDatabaseName:OperationsManagerDW /ActionAccountUser:$DomainName\sv_scom_aa /ActionAccountPassword:$SCOM_AA_Password /DASAccountUser:$DomainName\sv_scom_das /DASAccountPassword:$SCOM_DAS_Password /DataReaderUser:$DomainName\sv_scom_read /DataReaderPassword:$SCOM_READ_Password /DataWriterUser:$DomainName\sv_scom_write /DataWriterPassword:$SCOM_WRITE_Password /WebSiteName:""Default Web Site"" /WebConsoleAuthorizationMode:Mixed /EnableErrorReporting:Always /SendCEIPReports:0 /UseMicrosoftUpdate:0 /AcceptEndUserLicenseAgreement:1 /silent "

        

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

Function Configure-ExternalNTP {
  #Configure External NTP Services

  param
  (
    [string]$VMName, 
    [string]$GuestOSName,
    [string]$VMPath,
    [string]$WorkingDir
  )
     
     
    Write-Output -InputObject "[$($VMName)]:: Configuring Active Directory Time Services"
      
    Invoke-Command -VMName $VMName -Credential $domainCred {

    cmd.exe /c 'w32tm.exe /config /manualpeerlist:$Using:NTPServer,0x8 /syncfromflags:manual /update'
    cmd.exe /c 'w32tm.exe /config /reliable:yes'
    cmd.exe /c 'net stop w32time'
    cmd.exe /c 'net start w32time'
    cmd.exe /c 'w32tm.exe /resync'
    cmd.exe /c 'w32tm.exe /query /peers'
    
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
        $username = "SV_veeam"
        $fulluser = "Titan\SV_Veeam"
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
        $Arguments = "/HIDECONSOLE /Q /IACCEPTSQLSERVERLICENSETERMS /ACTION=install /FEATURES=SQLEngine,SNAC_SDK /INSTANCENAME=VEEAMSQL2016 /SQLSVACCOUNT=`"NT AUTHORITY\SYSTEM`" /SQLSYSADMINACCOUNTS=`"$fulluser`" `"Builtin\Administrators`" /TCPENABLED=1 /NPENABLED=1 /UpdateEnabled=0"
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

Function Create-ADGPOs {

 param
    (
        [string]$VMName, 
        [string]$GuestOSName,
        [string]$VMPath,
        [string]$WorkingDir
    )

#Powershell script to disable RC4 encryption type when doing kerberos exchanges


 <#>Invoke-Command -VMName $VMName -Credential $domainCred {

        Import-Module ActiveDirectory
        Import-Module GroupPolicy

        ## Define variables 
        $GPOName = 'Disable-RC4-etype'
        $basedn = ( [ADSI]"LDAP://RootDSE" ).defaultNamingContext.Value
        $AES128 = 0x8
        $AES256 = 0x10

        ##create New GPO
        $GPO = New-GPO -Name $GPOName

        #
        Set-GPPrefRegistryValue -Name $GPOName -Action Update -Context Computer `
        -Key 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\policies\system\kerberos\parameters' `
        -Type DWord  -ValueName 'supportedencryptiontypes' -Value 2147483640 | out-null
        #
        ##Link the new GPO to the Domain Controller
        New-GPLink -Name $GPOName -Target $basedn
        #
        ## Update GPO
        Invoke-GPUpdate  -Force

        ## Fetch all users from an OU with their current support encryption types attribute
        # Though the above enables AES-128. Existing users would still have RC4. So need
        # to enable AES in msDS-SupportedEncryptionTypes attribte. 
        $Users = Get-ADUser -Filter * -SearchBase "CN=Users,$basedn" -Properties "msDS-SupportedEncryptionTypes"
        foreach($User in $Users)
        {
                Set-ADUser $User -Replace @{"msDS-SupportedEncryptionTypes"=($AES128)}
        }
        }
        https://social.technet.microsoft.com/Forums/SECURITY/en-US/01fe4703-08a5-4012-8ced-c9133b7115e9/configuring-group-policy-using-powershell-to-disable-rc4-kerberos-etype?forum=winserver8gen
        </#>


Invoke-Command -VMName $VMName -Credential $domainCred {

        Import-Module ActiveDirectory
        Import-Module GroupPolicy

        Write-Output -InputObject "[$($VMName)]:: Creating Group Policy Object to MS Baseline Harden Fabric HCI Clusters"
        $GPOName = 'Server Hardening MS Server 2019 Baseline-HCI-Level1'
        $basedn = "OU=HCI Clusters,OU=Fabric,$Using:DomainDN"
        
        
        $GPO = New-GPO -Name $GPOName

        
        New-GPLink -Name $GPOName -Target $basedn
       
        }

Invoke-Command -VMName $VMName -Credential $domainCred {

        Import-Module ActiveDirectory
        Import-Module GroupPolicy

        Write-Output -InputObject "[$($VMName)]:: Creating Group Policy Object to CIS Benchmark Harden Fabric HCI Clusters"
        $GPOName = 'Server Hardening CIS Server 2019 v1.3-HCI-Level1'
        $basedn = "OU=HCI Clusters,OU=Fabric,$Using:DomainDN"
        
        
        $GPO = New-GPO -Name $GPOName

        
        New-GPLink -Name $GPOName -Target $basedn
       
        }

Invoke-Command -VMName $VMName -Credential $domainCred {

        Import-Module ActiveDirectory
        Import-Module GroupPolicy

        Write-Output -InputObject "[$($VMName)]:: Creating Group Policy Object to MS Baseline Harden Domain Controllers"
        $GPOName = 'Server Hardening MS Server 2022 Baseline-DC-Level1'
        $basedn = "OU=Domain Controllers,$Using:DomainDN"
        
        
        $GPO = New-GPO -Name $GPOName

        
        New-GPLink -Name $GPOName -Target $basedn
       
        }

Invoke-Command -VMName $VMName -Credential $domainCred {

        Import-Module ActiveDirectory
        Import-Module GroupPolicy

        Write-Output -InputObject "[$($VMName)]:: Creating Group Policy Object to CIS Benchmark Harden Domain Controllers"
        $GPOName = 'Server Hardening CIS Server 2022 v1.0-DC-Level1'
        $basedn = "OU=Domain Controllers,$Using:DomainDN"
        
        
        $GPO = New-GPO -Name $GPOName

        
        New-GPLink -Name $GPOName -Target $basedn
       
        }


Invoke-Command -VMName $VMName -Credential $domainCred {

        Import-Module ActiveDirectory
        Import-Module GroupPolicy

        Write-Output -InputObject "[$($VMName)]:: Creating Group Policy Object to MS Baseline Harden Server 2022 Member Servers"
        $GPOName = 'Server Hardening MS Server 2022 Baseline MS-Level1'
        $basedn = "OU=Member Servers,OU=Fabric,$Using:DomainDN"
        
        
        $GPO = New-GPO -Name $GPOName

        
        New-GPLink -Name $GPOName -Target $basedn
       
        }


Invoke-Command -VMName $VMName -Credential $domainCred {

        Import-Module ActiveDirectory
        Import-Module GroupPolicy

        Write-Output -InputObject "[$($VMName)]:: Creating Group Policy Object to CIS Benchmark Harden Server 2022 Member Servers"
        $GPOName = 'Server Hardening CIS Server 2022-MS-Level1'
        $basedn = "OU=Member Servers,OU=Fabric,$Using:DomainDN"
        
        
        $GPO = New-GPO -Name $GPOName

        
        New-GPLink -Name $GPOName -Target $basedn
       
        }

Invoke-Command -VMName $VMName -Credential $domainCred {

        Import-Module ActiveDirectory
        Import-Module GroupPolicy

        Write-Output -InputObject "[$($VMName)]:: Creating Group Policy Object MS Baseline Harden Domain"
        $GPOName = 'Server Hardening MS Domain-Level1'
        $basedn = "$Using:DomainDN"
        
        
        $GPO = New-GPO -Name $GPOName

        
        New-GPLink -Name $GPOName -Target $basedn
       
        }

Invoke-Command -VMName $VMName -Credential $domainCred {

        Import-Module ActiveDirectory
        Import-Module GroupPolicy

        Write-Output -InputObject "[$($VMName)]:: Creating Group Policy Object CIS Benchmark Harden Domain"
        $GPOName = 'Server Hardening CIS Server 2022-Domain-Level1'
        $basedn = "$Using:DomainDN"
        
        
        $GPO = New-GPO -Name $GPOName

        
        New-GPLink -Name $GPOName -Target $basedn
       
        }

Invoke-Command -VMName $VMName -Credential $domainCred {

        Import-Module ActiveDirectory
        Import-Module GroupPolicy

        Write-Output -InputObject "[$($VMName)]:: Creating Group Policy Object to Deploy MDATP Agent"
        $GPOName = 'Deploy MDATP Agent'
        $basedn = "$Using:DomainDN"
        
        
        $GPO = New-GPO -Name $GPOName

        
        New-GPLink -Name $GPOName -Target $basedn
       
        }

Invoke-Command -VMName $VMName -Credential $domainCred {

        Import-Module ActiveDirectory
        Import-Module GroupPolicy

        Write-Output -InputObject "[$($VMName)]:: Creating Group Policy Object to Configure Defender Settings"
        $GPOName = 'Configure MDATP'
        $basedn = "$Using:DomainDN"
        
        
        $GPO = New-GPO -Name $GPOName

        
        New-GPLink -Name $GPOName -Target $basedn
       
        }

Invoke-Command -VMName $VMName -Credential $domainCred {

        Import-Module ActiveDirectory
        Import-Module GroupPolicy

        Write-Output -InputObject "[$($VMName)]:: Creating Group Policy Object to June 2022 MDATP Recommendations"
        $GPOName = 'Server Hardening MDATP Recommendations June 2022'
        $basedn = "$Using:DomainDN"
        
        
        $GPO = New-GPO -Name $GPOName

        
        New-GPLink -Name $GPOName -Target $basedn
       
        }

Invoke-Command -VMName $VMName -Credential $domainCred {

        Import-Module ActiveDirectory
        Import-Module GroupPolicy

        Write-Output -InputObject "[$($VMName)]:: Creating Group Policy Object to July 2022 MDATP Recommendations"
        $GPOName = 'Server Hardening MDATP Recommendations July 2022'
        $basedn = "$Using:DomainDN"
        
        
        $GPO = New-GPO -Name $GPOName

        
        New-GPLink -Name $GPOName -Target $basedn
       
        }

Invoke-Command -VMName $VMName -Credential $domainCred {

        Import-Module ActiveDirectory
        Import-Module GroupPolicy

        Write-Output -InputObject "[$($VMName)]:: Creating Group Policy Object to August 2022 MDATP Recommendations"
        $GPOName = 'Server Hardening MDATP Recommendations August 2022'
        $basedn = "$Using:DomainDN"
        
        
        $GPO = New-GPO -Name $GPOName

        
        New-GPLink -Name $GPOName -Target $basedn
       
        }

Invoke-Command -VMName $VMName -Credential $domainCred {

        Write-Output -InputObject "[$($VMName)]:: Creating Group Policy Central Store"          
          
        New-Item -ItemType Directory -Path "C:\Windows\SYSVOL\sysvol\$($Domainname)\Policies\PolicyDefinitions" -Force:$true | Out-Null
}
}

Function Enable-SCOMTLS1.0{
 param
    (
        [string]$VMName, 
        [string]$GuestOSName,
        [string]$VMPath,
        [string]$WorkingDir
    )


    Invoke-Command -VMName $VMName -Credential $domainCred {
    $ProtocolList       = @("SSL 2.0", "SSL 3.0", "TLS 1.0", "TLS 1.1", "TLS 1.2","TLS 1.3")
$ProtocolSubKeyList = @("Client", "Server")
$DisabledByDefault  = "DisabledByDefault"
$registryPath       = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\"

foreach ($Protocol in $ProtocolList)
{
	foreach ($key in $ProtocolSubKeyList)
	{
		$currentRegPath = $registryPath + $Protocol + "\" + $key
		Write-Output "Current Registry Path: `"$currentRegPath`""

		if (!(Test-Path $currentRegPath))
		{
			Write-Output " `'$key`' not found: Creating new Registry Key"
			New-Item -Path $currentRegPath -Force | out-Null
		}
		if ($Protocol -eq "TLS 1.0")
		{
			Write-Output " Enabling - TLS 1.2"
			New-ItemProperty -Path $currentRegPath -Name $DisabledByDefault -Value "0" -PropertyType DWORD -Force | Out-Null
			New-ItemProperty -Path $currentRegPath -Name 'Enabled' -Value "1" -PropertyType DWORD -Force | Out-Null
		}
		else
		{
			Write-Output " Disabling - $Protocol"
			New-ItemProperty -Path $currentRegPath -Name $DisabledByDefault -Value "1" -PropertyType DWORD -Force | Out-Null
			New-ItemProperty -Path $currentRegPath -Name 'Enabled' -Value "0" -PropertyType DWORD -Force | Out-Null
		}
		Write-Output " "
	}
}

Exit 0

    }

}

Function Enable-SCOMTLS1.0{
 param
    (
        [string]$VMName, 
        [string]$GuestOSName,
        [string]$VMPath,
        [string]$WorkingDir
    )


    Invoke-Command -VMName $VMName -Credential $domainCred {
      Write-Output -InputObject "[$($VMName)]:: Lowering TLS Value for the SCOM Install to TLS 1.0"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls
    }

}

Function Disable-SCOMTLS1.0{
 param
    (
        [string]$VMName, 
        [string]$GuestOSName,
        [string]$VMPath,
        [string]$WorkingDir
    )


    Invoke-Command -VMName $VMName -Credential $domainCred {
      Write-Output -InputObject "[$($VMName)]:: Configuring TLS Value to System Default"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::SystemDefault
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
    
        Write-Output -InputObject "[$($Using:VMName)]:: Creating user account for Sami"
        do {
            Start-Sleep -Seconds 5
            New-ADUser `
                -Name 'Sami' `
                -SamAccountName  'Sami' `
                -DisplayName 'Sami' `
                -AccountPassword (ConvertTo-SecureString -String $Using:Sami_password -AsPlainText -Force) `
                -ChangePasswordAtLogon $true  `
                -Enabled $true -ea 0 `
                -Path "OU=Fabric Users,OU=Fabric,$Using:DomainDN"
        }
        until ($?)
        
    } 

      Invoke-Command -VMName $VMName -Credential $domainCred {
    
        Write-Output -InputObject "[$($Using:VMName)]:: Creating user account for Dave"
        do {
            Start-Sleep -Seconds 5
            New-ADUser `
                -Name 'Dave' `
                -SamAccountName  'Dave' `
                -DisplayName 'Dave' `
                -AccountPassword (ConvertTo-SecureString -String $Using:Dave_password -AsPlainText -Force) `
                -ChangePasswordAtLogon $true  `
                -Enabled $true -ea 0 `
                -Path "OU=Fabric Users,OU=Fabric,$Using:DomainDN"
        }
        until ($?)
        
    } 

          Invoke-Command -VMName $VMName -Credential $domainCred {
    
        Write-Output -InputObject "[$($Using:VMName)]:: Creating user account for Emile"
        do {
            Start-Sleep -Seconds 5
            New-ADUser `
                -Name 'Emile' `
                -SamAccountName  'Emile' `
                -DisplayName 'Emile' `
                -AccountPassword (ConvertTo-SecureString -String $Using:Emile_password -AsPlainText -Force) `
                -ChangePasswordAtLogon $true  `
                -Enabled $true -ea 0 `
                -Path "OU=Fabric Users,OU=Fabric,$Using:DomainDN"
        }
        until ($?)
        
    } 

        Invoke-Command -VMName $VMName -Credential $domainCred {
    
        Write-Output -InputObject "[$($Using:VMName)]:: Creating user account for Cary"
        do {
            Start-Sleep -Seconds 5
            New-ADUser `
                -Name 'Cary' `
                -SamAccountName  'Cary' `
                -DisplayName 'Cary' `
                -AccountPassword (ConvertTo-SecureString -String $Using:Cary_password -AsPlainText -Force) `
                -ChangePasswordAtLogon $true  `
                -Enabled $true -ea 0 `
                -Path "OU=Fabric Users,OU=Fabric,$Using:DomainDN"
        }
        until ($?)
        
    } 

      Invoke-Command -VMName $VMName -Credential $domainCred {
    
        Write-Output -InputObject "[$($Using:VMName)]:: Creating user account for SA_Sami"
        do {
            Start-Sleep -Seconds 5
            New-ADUser `
                -Name 'SA_Sami' `
                -SamAccountName  'SA_Sami' `
                -DisplayName 'SA_Sami' `
                -AccountPassword (ConvertTo-SecureString -String $Using:SA_Sami_password -AsPlainText -Force) `
                -ChangePasswordAtLogon $true  `
                -Enabled $true -ea 0 `
                -Path "OU=Fabric Admins,OU=Fabric,$Using:DomainDN"
        }
        until ($?)
        
    } 

          Invoke-Command -VMName $VMName -Credential $domainCred {
    
        Write-Output -InputObject "[$($Using:VMName)]:: Creating user account for SA_DAVE"
        do {
            Start-Sleep -Seconds 5
            New-ADUser `
                -Name 'SA_DAVE' `
                -SamAccountName  'SA_DAVE' `
                -DisplayName 'SA_DAVE' `
                -AccountPassword (ConvertTo-SecureString -String $Using:SA_DAVE_password -AsPlainText -Force) `
                -ChangePasswordAtLogon $true  `
                -Enabled $true -ea 0 `
                -Path "OU=Fabric Admins,OU=Fabric,$Using:DomainDN"
        }
        until ($?)
        
    } 

            Invoke-Command -VMName $VMName -Credential $domainCred {
    
        Write-Output -InputObject "[$($Using:VMName)]:: Creating user account for SA_EMILE"
        do {
            Start-Sleep -Seconds 5
            New-ADUser `
                -Name 'SA_EMILE' `
                -SamAccountName  'SA_EMILE' `
                -DisplayName 'SA_EMILE' `
                -AccountPassword (ConvertTo-SecureString -String $Using:SA_EMILE_password -AsPlainText -Force) `
                -ChangePasswordAtLogon $true  `
                -Enabled $true -ea 0 `
                -Path "OU=Fabric Admins,OU=Fabric,$Using:DomainDN"
        }
        until ($?)
        
    } 

            Invoke-Command -VMName $VMName -Credential $domainCred {
    
        Write-Output -InputObject "[$($Using:VMName)]:: Creating user account for SA_Cary"
        do {
            Start-Sleep -Seconds 5
            New-ADUser `
                -Name 'SA_Cary' `
                -SamAccountName  'SA_Cary' `
                -DisplayName 'SA_Cary' `
                -AccountPassword (ConvertTo-SecureString -String $Using:SA_Cary_password -AsPlainText -Force) `
                -ChangePasswordAtLogon $true  `
                -Enabled $true -ea 0 `
                -Path "OU=Fabric Admins,OU=Fabric,$Using:DomainDN"
        }
        until ($?)
        
    } 

         Invoke-Command -VMName $VMName -Credential $domainCred {
    
        Write-Output -InputObject "[$($Using:VMName)]:: Creating user account for DA_Sami"
        do {
            Start-Sleep -Seconds 5
            New-ADUser `
                -Name 'DA_Sami' `
                -SamAccountName  'DA_Sami' `
                -DisplayName 'DA_Sami' `
                -AccountPassword (ConvertTo-SecureString -String $Using:DA_Sami_password -AsPlainText -Force) `
                -ChangePasswordAtLogon $true  `
                -Enabled $true -ea 0 `
                -Path "OU=Fabric Admins,OU=Fabric,$Using:DomainDN"
        }
        until ($?)
        Add-ADGroupMember -Identity 'Domain Admins' -Members 'DA_Sami'
    } 

        Invoke-Command -VMName $VMName -Credential $domainCred {
    
        Write-Output -InputObject "[$($Using:VMName)]:: Creating user account for DA_Dave"
        do {
            Start-Sleep -Seconds 5
            New-ADUser `
                -Name 'DA_Dave' `
                -SamAccountName  'DA_Dave' `
                -DisplayName 'DA_Dave' `
                -AccountPassword (ConvertTo-SecureString -String $Using:DA_Dave_password -AsPlainText -Force) `
                -ChangePasswordAtLogon $true  `
                -Enabled $true -ea 0 `
                -Path "OU=Fabric Admins,OU=Fabric,$Using:DomainDN"
        }
        until ($?)
        Add-ADGroupMember -Identity 'Domain Admins' -Members 'DA_Dave'
    } 

         Invoke-Command -VMName $VMName -Credential $domainCred {
    
        Write-Output -InputObject "[$($Using:VMName)]:: Creating user account for DA_Emile"
        do {
            Start-Sleep -Seconds 5
            New-ADUser `
                -Name 'DA_Emile' `
                -SamAccountName  'DA_Emile' `
                -DisplayName 'DA_Emile' `
                -AccountPassword (ConvertTo-SecureString -String $Using:DA_Emile_password -AsPlainText -Force) `
                -ChangePasswordAtLogon $true  `
                -Enabled $true -ea 0 `
                -Path "OU=Fabric Admins,OU=Fabric,$Using:DomainDN"
        }
        until ($?)
        Add-ADGroupMember -Identity 'Domain Admins' -Members 'DA_Emile'
    }
    
         Invoke-Command -VMName $VMName -Credential $domainCred {
    
        Write-Output -InputObject "[$($Using:VMName)]:: Creating user account for DA_Cary"
        do {
            Start-Sleep -Seconds 5
            New-ADUser `
                -Name 'DA_Cary' `
                -SamAccountName  'DA_Cary' `
                -DisplayName 'DA_Cary' `
                -AccountPassword (ConvertTo-SecureString -String $Using:DA_Cary_password -AsPlainText -Force) `
                -ChangePasswordAtLogon $true  `
                -Enabled $true -ea 0 `
                -Path "OU=Fabric Admins,OU=Fabric,$Using:DomainDN"
        }
        until ($?)
        Add-ADGroupMember -Identity 'Domain Admins' -Members 'DA_Cary'
    } 

    Invoke-Command -VMName $VMName -Credential $domainCred {
        

        Write-Output -InputObject "[$($Using:VMName)]:: Creating user account for sv_sql"
        do {
            Start-Sleep -Seconds 5
            New-ADUser `
                -Name 'sv_sql' `
                -SamAccountName  'sv_sql' `
                -DisplayName 'sv_sql' `
                -AccountPassword (ConvertTo-SecureString -String $Using:sv_sql_password -AsPlainText -Force) `
                -ChangePasswordAtLogon $false  `
                -Enabled $true -ea 0 `
                -Path "OU=Service Accounts,OU=Fabric,$Using:DomainDN"
        }
        until ($?)
        
    }

    Invoke-Command -VMName $VMName -Credential $domainCred {
       

        Write-Output -InputObject "[$($Using:VMName)]:: Creating user account for sv_sql_agent"
        do {
            Start-Sleep -Seconds 5
            New-ADUser `
                -Name 'sv_sql_agent' `
                -SamAccountName  'sv_sql_agent' `
                -DisplayName 'sv_sql_agent' `
                -AccountPassword (ConvertTo-SecureString -String $Using:sv_sql_agent_password -AsPlainText -Force) `
                -ChangePasswordAtLogon $false  `
                -Enabled $true -ea 0 `
                -Path "OU=Service Accounts,OU=Fabric,$Using:DomainDN"
        }
        until ($?)
        
    } 

    Invoke-Command -VMName $VMName -Credential $domainCred {
        

        Write-Output -InputObject "[$($Using:VMName)]:: Creating user account for sv_sql_srs"
        do {
            Start-Sleep -Seconds 5
            New-ADUser `
                -Name 'sv_sql_srs' `
                -SamAccountName  'sv_sql_srs' `
                -DisplayName 'sv_sql_srs' `
                -AccountPassword (ConvertTo-SecureString -String $Using:sv_sql_srs_password -AsPlainText -Force) `
                -ChangePasswordAtLogon $false  `
                -Enabled $true -ea 0 `
                -Path "OU=Service Accounts,OU=Fabric,$Using:DomainDN"
        }
        until ($?)
        
    }

    Invoke-Command -VMName $VMName -Credential $domainCred {
        

        Write-Output -InputObject "[$($Using:VMName)]:: Creating user account for SCOM_AA"
        do {
            Start-Sleep -Seconds 5
            New-ADUser `
                -Name 'sv_scom_aa' `
                -SamAccountName  'sv_scom_aa' `
                -DisplayName 'sv_scom_aa' `
                -AccountPassword (ConvertTo-SecureString -String $Using:SCOM_AA_Password -AsPlainText -Force) `
                -ChangePasswordAtLogon $false  `
                -Enabled $true -ea 0 `
                -Path "OU=Service Accounts,OU=Fabric,$Using:DomainDN"
        }
        until ($?)
        
    }

    Invoke-Command -VMName $VMName -Credential $domainCred {
        

        Write-Output -InputObject "[$($Using:VMName)]:: Creating user account for SCOM_DAS"
        do {
            Start-Sleep -Seconds 5
            New-ADUser `
                -Name 'sv_scom_das' `
                -SamAccountName  'sv_scom_das' `
                -DisplayName 'sv_scom_das' `
                -AccountPassword (ConvertTo-SecureString -String $Using:SCOM_DAS_Password -AsPlainText -Force) `
                -ChangePasswordAtLogon $false  `
                -Enabled $true -ea 0 `
                -Path "OU=Service Accounts,OU=Fabric,$Using:DomainDN"
        }
        until ($?)
        
    }

    Invoke-Command -VMName $VMName -Credential $domainCred {
        

        Write-Output -InputObject "[$($Using:VMName)]:: Creating user account for sv_scom_read"
        do {
            Start-Sleep -Seconds 5
            New-ADUser `
                -Name 'sv_scom_read' `
                -SamAccountName  'sv_scom_read' `
                -DisplayName 'sv_scom_read' `
                -AccountPassword (ConvertTo-SecureString -String $Using:SCOM_READ_Password -AsPlainText -Force) `
                -ChangePasswordAtLogon $false  `
                -Enabled $true -ea 0 `
                -Path "OU=Service Accounts,OU=Fabric,$Using:DomainDN"
        }
        until ($?)
        
    }

    Invoke-Command -VMName $VMName -Credential $domainCred {
        

        Write-Output -InputObject "[$($Using:VMName)]:: Creating user account for sv_scom_write"
        do {
            Start-Sleep -Seconds 5
            New-ADUser `
                -Name 'sv_scom_write' `
                -SamAccountName  'sv_scom_write' `
                -DisplayName 'sv_scom_write' `
                -AccountPassword (ConvertTo-SecureString -String $Using:SCOM_WRITE_Password -AsPlainText -Force) `
                -ChangePasswordAtLogon $false  `
                -Enabled $true -ea 0 `
                -Path "OU=Service Accounts,OU=Fabric,$Using:DomainDN"
        }
        until ($?)
        
    }

    Invoke-Command -VMName $VMName -Credential $domainCred {
        
        Write-Output -InputObject "[$($Using:VMName)]:: Creating LAPS Admins Group"
        do {
            Start-Sleep -Seconds 5
            New-AdGroup `
                -Name 'LAPS Admins' `
                -SamAccountName  'LAPS Admins' `
                -DisplayName 'LAPS Admins' `
                -GroupCategory 'Security'`
                -GroupScope 'Global' `
                -Path "OU=Fabric Admins,OU=Fabric,$Using:DomainDN"
             }  
                       
        until ($?)
        Add-ADGroupMember -Identity 'Laps Admins' -Members 'SA_Sami'
        Add-ADGroupMember -Identity 'Laps Admins' -Members 'SA_DAVE'
        Add-ADGroupMember -Identity 'Laps Admins' -Members 'SA_EMILE'
        Add-ADGroupMember -Identity 'Laps Admins' -Members 'SA_Cary'

    }

        Invoke-Command -VMName $VMName -Credential $domainCred {
        
        Write-Output -InputObject "[$($Using:VMName)]:: Creating Server Admins Group"
        do {
            Start-Sleep -Seconds 5
            New-AdGroup `
                -Name 'Server Admins' `
                -SamAccountName  'Server Admins' `
                -DisplayName 'Server Admins' `
                -GroupCategory 'Security'`
                -GroupScope 'Global' `
                -Path "OU=Fabric Admins,OU=Fabric,$Using:DomainDN"
             }  
                       
        until ($?)
        Add-ADGroupMember -Identity 'Server Admins' -Members 'SA_Sami'
        Add-ADGroupMember -Identity 'Server Admins' -Members 'SA_DAVE'
        Add-ADGroupMember -Identity 'Server Admins' -Members 'SA_EMILE'
        Add-ADGroupMember -Identity 'Server Admins' -Members 'SA_Cary'

    }

    Invoke-Command -VMName $VMName -Credential $domainCred {
        
        Write-Output -InputObject "[$($Using:VMName)]:: Creating SCOM Admins Group"
        do {
            Start-Sleep -Seconds 5
            New-AdGroup `
                -Name 'SCOM Admins' `
                -SamAccountName  'SCOM Admins' `
                -DisplayName 'SCOM Admins' `
                -GroupCategory 'Security'`
                -GroupScope 'Global' `
                -Path "OU=Fabric Admins,OU=Fabric,$Using:DomainDN"
             }  
                       
        until ($?)
        Add-ADGroupMember -Identity 'SCOM Admins' -Members 'SA_Sami'
        Add-ADGroupMember -Identity 'SCOM Admins' -Members 'SA_DAVE'
        Add-ADGroupMember -Identity 'SCOM Admins' -Members 'SA_EMILE'
        Add-ADGroupMember -Identity 'SCOM Admins' -Members 'SA_Cary'

    }

        Invoke-Command -VMName $VMName -Credential $domainCred {
        

        Write-Output -InputObject "[$($Using:VMName)]:: Creating SQL Admins Group"
        do {
            Start-Sleep -Seconds 5
            New-AdGroup `
                -Name 'SQL Admins' `
                -SamAccountName  'SQL Admins' `
                -DisplayName 'SQL Admins' `
                -GroupCategory 'Security'`
                -GroupScope 'Global' `
                -Path "OU=Fabric Admins,OU=Fabric,$Using:DomainDN"
             }  
                       
        until ($?)
        Add-ADGroupMember -Identity 'SQL Admins' -Members 'SA_Sami'
        Add-ADGroupMember -Identity 'SQL Admins' -Members 'SA_DAVE'
        Add-ADGroupMember -Identity 'SQL Admins' -Members 'SA_EMILE'
        Add-ADGroupMember -Identity 'SQL Admins' -Members 'SA_Cary'

    }

    Invoke-Command -VMName $VMName -Credential $domainCred {
       

        Write-Output -InputObject "[$($Using:VMName)]:: Creating user account for SV_Veeam"
        do {
            Start-Sleep -Seconds 5
            New-ADUser `
                -Name 'sv_veeam' `
                -SamAccountName  'sv_veeam' `
                -DisplayName 'sv_veeam' `
                -AccountPassword (ConvertTo-SecureString -String $Using:SV_Veeam_password -AsPlainText -Force) `
                -ChangePasswordAtLogon $false  `
                -Enabled $true -ea 0 `
                -Path "OU=Service Accounts,OU=Fabric,$Using:DomainDN"
        }
        until ($?)
        
    }




}

Function Create-ADOUs {
    param
    (
        [string]$VMName, 
        [string]$GuestOSName,
        [string]$VMPath,
        [string]$WorkingDir
    )


    Invoke-Command -VMName $VMName -Credential $domainCred {
        
        Write-Output -InputObject "[$($Using:VMName)]:: Creating Fabic Organization Unit"
        do {
            Start-Sleep -Seconds 5
            New-ADOrganizationalUnit -Name 'Fabric' -Path "$Using:DomainDN"  
                
        }
        until ($?)
        
    }

   
     Invoke-Command -VMName $VMName -Credential $domainCred {
      

        Write-Output -InputObject "[$($Using:VMName)]:: Creating Veeam Servers Organization Unit"
        do {
            Start-Sleep -Seconds 5
            New-ADOrganizationalUnit -Name 'Veeam Servers' -Path "OU=Fabric,$Using:DomainDN" 
                
        }
        until ($?)
        
    }

   

   Invoke-Command -VMName $VMName -Credential $domainCred {
        

        Write-Output -InputObject "[$($Using:VMName)]:: Creating Veeam Backup Targets Organization Unit"
        do {
            Start-Sleep -Seconds 5
            New-ADOrganizationalUnit -Name 'Veeam Backup Targets' -Path "OU=Fabric,$Using:DomainDN" 
                
        }
        until ($?)
        
    }


   Invoke-Command -VMName $VMName -Credential $domainCred {
       

        Write-Output -InputObject "[$($Using:VMName)]:: Creating Fabric Admins Organization Unit"
        do {
            Start-Sleep -Seconds 5
            New-ADOrganizationalUnit -Name 'Fabric Admins' -Path "OU=Fabric,$Using:DomainDN"
                
        }
        until ($?)
        
    }

       Invoke-Command -VMName $VMName -Credential $domainCred {
       

        Write-Output -InputObject "[$($Using:VMName)]:: Creating Fabric Users Organization Unit"
        do {
            Start-Sleep -Seconds 5
            New-ADOrganizationalUnit -Name 'Fabric Users' -Path "OU=Fabric,$Using:DomainDN"
                
        }
        until ($?)
        
    }

   Invoke-Command -VMName $VMName -Credential $domainCred {
      
        Write-Output -InputObject "[$($Using:VMName)]:: Creating HCI Clusters Organization Unit"
        do {
            Start-Sleep -Seconds 5
            New-ADOrganizationalUnit -Name 'HCI Clusters' -Path "OU=Fabric,$Using:DomainDN"
                
        }
        until ($?)
        
    } 

 Invoke-Command -VMName $VMName -Credential $domainCred {
        

        Write-Output -InputObject "[$($Using:VMName)]:: Creating Member Servers Organization Unit"
        do {
            Start-Sleep -Seconds 5
            New-ADOrganizationalUnit -Name 'Member Servers' -Path "OU=Fabric,$Using:DomainDN"
                
        }
        until ($?)
        
    } 

 Invoke-Command -VMName $VMName -Credential $domainCred {
       

        Write-Output -InputObject "[$($Using:VMName)]:: Creating PAW Organization Unit"
        do {
            Start-Sleep -Seconds 5
            New-ADOrganizationalUnit -Name 'PAW' -Path "OU=Fabric,$Using:DomainDN"
                
        }
        until ($?)
        
    }

Invoke-Command -VMName $VMName -Credential $domainCred {
        

        Write-Output -InputObject "[$($Using:VMName)]:: Creating Service Accounts Organization Unit"
        do {
            Start-Sleep -Seconds 5
            New-ADOrganizationalUnit -Name 'Service Accounts' -Path "OU=Fabric,$Using:DomainDN"
                
        }
        until ($?)
        
    } 

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

Function Rename-Localadmin {

  param
        (
            [string]$VMName, 
            [string]$GuestOSName
            
        )
        Invoke-Command -VMName $VMName -Credential $domainCred {
        Write-Output -InputObject "[$($VMName)]:: Renaming Local Administrator to Fabric ADMIN - for LAPS Config"
        Rename-LocalUser -Name "administrator" -NewName "FabricAdmin" -Verbose

        }

}

Function Expand-Benchmarks {
    param
        (
            [string]$VMName, 
            [string]$GuestOSName,
            [string]$VMPath,
            [string]$WorkingDir,
            [string]$Domainname
        )

    Invoke-Command -VMName $VMName -Credential $domainCred {

        $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object { $_.Label -eq "Data" }
        $DataDrive = $Driveletter.DriveLetter
        $DataDrive
        

        $Destinationfilename = "$datadrive\Securitycompliancetoolkit.zip"
        Write-Output -InputObject "[$($Using:VMName)]:: Expanding Security Compliance Toolkit ZIP"
        Expand-Archive -LiteralPath "$Destinationfilename" -DestinationPath "$DataDrive\SecurityComplianceToolkit"

        $Destinationfilename = "$datadrive\Server2019v1.3.0 (1).zip"
        Write-Output -InputObject "[$($Using:VMName)]:: Expanding CIS Benchmark Buildkit for Server 2019 V1.3.0"
        Expand-Archive -LiteralPath "$Destinationfilename" -DestinationPath "$DataDrive\Server2019v1.3.0"

        $Destinationfilename = "$datadrive\Server2022v1.0.0.zip"
        Write-Output -InputObject "[$($Using:VMName)]:: Expanding CIS Benchmark Buildkit for Server 2022 V1.0.0"
        Expand-Archive -LiteralPath "$Destinationfilename" -DestinationPath "$DataDrive\Server2022v1.0.0"

         
            

               
    }


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

Function Configure-FabricVMCleanup {
    param
    (
        [string]$VMName, 
        [string]$GuestOSName,
        [string]$VMPath,
        [string]$WorkingDir,
        [string]$Domainname
    )


    Invoke-Command -VMName $VMName -Credential $domainCred {

        Write-Output "Enabling ICMP Windows Firewall RUle"

        Enable-NetFirewallRule -Name 'FPS-ICMP4-ERQ-In'

        Write-Output "Removing Unattend Files"    

        get-childitem c:\unattend.xml | Remove-Item -Force
        get-childitem c:\unattend1.xml | Remove-Item -Force
        get-childitem c:\autounattend.xml | Remove-Item -Force

        }


}

function Invoke-FabricNodeStorageBuild {
  param
  (
    [string]$VMName, 
    [string]$GuestOSName
  )

  #Create-DemoVM $VMName $GuestOSName
  1..24 | ForEach-Object {  Clear-File "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - Data $_.vhdx"}
  Get-VM $VMName | Stop-VM 
  Add-VMNetworkAdapter -VMName $VMName -SwitchName $virtualSwitchName
  1..24 | ForEach-Object { New-VHD -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - Data $_.vhdx" -Dynamic -SizeBytes 4TB }
  1..24 | ForEach-Object { Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($VMName)\Virtual Hard Disks\$($GuestOSName) - Data $_.vhdx" -ControllerType SCSI}
  Set-VMProcessor -VMName $VMName -Count 2 -ExposeVirtualizationExtensions $True
  Add-VMNetworkAdapter -VMName $VMName -SwitchName $virtualSwitchName
  Add-VMNetworkAdapter -VMName $VMName -SwitchName $virtualSwitchName
  Add-VMNetworkAdapter -VMName $VMName -SwitchName $virtualSwitchName
  Add-VMNetworkAdapter -VMName $VMName -SwitchName $virtualSwitchName
  Add-VMNetworkAdapter -VMName $VMName -SwitchName $virtualSwitchName
  Get-VMNetworkAdapter -VMName $VMName | Set-VMNetworkAdapter -AllowTeaming On
  Get-VMNetworkAdapter -VMName $VMName | Set-VMNetworkAdapter -MacAddressSpoofing on
  Write-Log $VMName 'Setting VM VLAN to '$($VLANID)''
  Get-VM -VMName $VMName | Get-VMNetworkadapter | Set-VMNetworkAdapterVlan -VlanId $VLANID -Access #Steve this is custom and needs to be changed here during build time
  Start-VM $VMName
  Wait-PSDirect $VMName -cred $localCred

  Invoke-Command -VMName $VMName -Credential $localcred {
    Rename-NetAdapter -Name 'Ethernet' -NewName 'NIC1'
    Rename-NetAdapter -Name 'Ethernet 2' -NewName 'RDMA1'
    Rename-NetAdapter -Name 'Ethernet 3' -NewName 'RDMA2'
    Rename-NetAdapter -Name 'Ethernet 4' -NewName 'RDMA3'
    Rename-NetAdapter -Name 'Ethernet 5' -NewName 'RDMA4' 
  
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

#region 000 -  Starter

Write-Log 'Host' 'Getting started...'

#Write-Output -InputObject "Grabbing the location of the Veeam ISO"
#Get-VeeamISO
#$VeeamISO
Confirm-Path $BaseVHDPath
Confirm-Path $VMPath

Write-Log 'Host' 'Remember your VSwitch Name must match one created in Hyper-V Already'
Write-Log 'Host' 'Selecting SQL Server ISO'
Get-SQLServerISO
Get-SQLServerSSMS
Get-SQLServerCU
#Get-SCOMISO
Get-Server2022CISBenchmarks
Get-Server2019CISBenchmarks
Get-Server2022MicrosoftBaselines
Get-Server2022DavesPolicies
Get-LAPSInstaller
#Get-MSNET462
#Get-MSOLEDBSQL
#Get-MSODBC18
#Get-VC_redistx64
Get-Server2022ISO

#endregion

#region 001 -  Building DARK FABRIC VMs....

Invoke-FabricVMPrep 'FABDC01' 'FABDC01' -FullServer2022
Invoke-FabricVmPrep 'FABDC02' 'FABDC02' -FullServer2022
Invoke-FabricVmPrep 'FABSQL01' 'FABSQL01' -FullServer2022
#Invoke-FabricVmPrep 'FABSCOM01' 'FABSCOM01' -FullServer2022
#Invoke-FabricVmPrep 'FABWSUS01' 'FABWSUS01' -FullServer2022
#Invoke-FabricVmPrep 'PC01' 'PC01' -FullServer2022

#Section Added by DK - 09-08-22
#This is to test the 3Node S2D Build Scripts
#Optional to build LAB S2D 3 Node Cluster
#1..3 | ForEach-Object -Process {
#  Invoke-FabricVMPrep "VS2DP0$_" "VS2DP0$_" -FullServer2022
#}

#endregion

#region 002 -  Building DC01 ...
Write-Output -InputObject "Building The Fabric"
$VMName = 'FABDC01'
$GuestOSName = 'FABDC01'
$IPNumber = '11'

Create-FabricVM $VMName $GuestOSName $IPNumber
Write-Output -InputObject "[$($VMName)]:: Dark Fabic File Copy"
Copy-DarkFabricAddonsDC1 -VMName $VMname -GuestOSName $GuestOSName #This is new and needs some testing - Software Required to complete the build inside of the Dark Fabric

Invoke-Command -VMName $VMName -Credential $localCred {
    param($VMName, $domainName, $domainAdminPassword, $dsrestoremodePassword)

    $newroute = $Gateway
    Write-Output -InputObject "[$($VMName)]:: Configuring Default Gateway"
    $null = Get-Netroute | Where DestinationPrefix -eq "0.0.0.0/0" | Remove-NetRoute -Confirm:$False
    $null = Test-NetConnection localhost
    new-netroute -InterfaceAlias "Ethernet" -NextHop $newroute  -DestinationPrefix '0.0.0.0/0' -verbose

    Write-Output -InputObject "[$($VMName)]:: Installing AD"
    $null = Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
    Write-Output -InputObject "[$($VMName)]:: Enabling Active Directory and promoting to domain controller"
    Install-ADDSForest -DomainName $domainName -InstallDNS -NoDNSonNetwork -NoRebootOnCompletion `
        -SafeModeAdministratorPassword (ConvertTo-SecureString -String $dsrestoremodePassword -AsPlainText -Force) -confirm:$false
} -ArgumentList $VMName, $domainName, $domainAdminPassword,$dsrestoremodePassword



Restart-FabricVM $VMName 
Start-Sleep -Seconds 180
#BUG Here - Isn't accepting the Credentials - I need to manually reset the Domain Admin Password - Needs Troubleshooting -08-30-22 DK
#It stalls the build script until you login and change this then continues fine.
Invoke-Command -VMName $VMName -Credential $localCred {
    
    Write-Output -InputObject "[$($VMName)]:: Resetting the Password for Administrator"
    Set-ADAccountPassword -Identity Administrator -Reset -NewPassword (ConvertTo-SecureString -String $Using:domainadminpassword -AsPlainText -Force)
     
}


Wait-PSDirect $VMName -cred $domainCred
Write-Output -InputObject "[$($VMName)]:: Disabling Automatic Checkpoints"
Set-VM -Name $VMName -AutomaticCheckpointsEnabled $False
Write-Output -InputObject "[$($VMName)]:: Disabling Time Synchronization Integration Services"
Get-VMIntegrationService -VMName $VMName -Name "Time Synchronization" | Disable-VMIntegrationService -Verbose
Restart-FabricVM $VMName
#Write-Output -InputObject "[$($VMName)]:: Configuring NTP on the Domain Controller"
#Configure-ExternalNTP -VMName $VMname -GuestOSName $GuestOSName
Wait-PSDirect $VMName -cred $domainCred
Invoke-Command -VMName $VMName -Credential $domainCred {
    param($VMName, $domainName, $domainAdminPassword)

    Write-Output -InputObject "[$($VMName)]:: Installing ADCS"
    $null = Install-WindowsFeature AD-Certificate -IncludeAllSubFeature -IncludeManagementTools
} -ArgumentList $VMName, $domainName, $domainAdminPassword
Restart-FabricVM $VMName 
Wait-PSDirect $VMName -cred $domainCred
Write-Output -InputObject "[$($VMName)]:: Creating AD OUs for the Fabric" #Check because I'm not sure of the Naming Convention - We can pre-create all of othese - DK 08-30-22
Create-ADOUs -VMName $VMName
Write-Output -InputObject "[$($VMName)]:: Creating AD Users for the Fabric" #Check because I'm not sure of the Naming Convention - We can pre-create all of othese - DK 08-30-22
Create-ADusers -VMName $VMName
Write-Output -InputObject "[$($VMName)]:: Creating AD Group Policy Objects for the Fabric" 
Create-ADGPOs -VMName $VMName
Write-Output -InputObject "[$($VMName)]:: Expanding MS Baselines and CIS Benchmarks" 
#Expand-Benchmarks -VMName $VMName 
Write-Output -InputObject "[$($VMName)]:: Configuring AD Certificate Services" 
Configure-ADCS -VMName $VMName
#Write-Output -InputObject "[$($VMName)]:: Uninstalling Microsoft Edge" 
#Remove-MSEdge -VMname $VMName
Write-Output -InputObject "[$($VMName)]:: Cleaning up Fabric VM" 
Configure-FabricVMCleanup -VMName $VMName
Restart-FabricVM $VMName 
Wait-PSDirect $VMName -cred $domainCred
Write-Output -InputObject "[$($VMName)]:: Installing Local Admin Password Solution" 
Install-LAPSDC -VMName $VMName
Write-Output -InputObject "[$($VMName)]:: Creating FSW$ Share for the S2D Cluster" 
Invoke-Command -VMName $VMName -Credential $domainCred {
        New-Item -Path "c:\" -Name "FSW$" -ItemType "directory" -Verbose
        New-SmbShare -Name "FSW$" -Path "C:\FSW$" -FullAccess "Everyone" -verbose
        }
#Configure-TLS1.2 -VMName $VMName

#endregion

#region 003 - Building SQL Server
$VMName = 'FABSQL01'
$GuestOSName = 'FABSQL01'
$IPNumber = '20'

Create-FabricVM $VMName $GuestOSName $IPNumber

Invoke-Command -VMName $VMName -Credential $localCred {
    param($VMName, $domainCred, $domainName)

    $newroute = $Gateway
    Write-Output -InputObject "[$($VMName)]:: Configuring Default Gateway"
    $null = Get-Netroute | Where-Object DestinationPrefix -eq "0.0.0.0/0" | Remove-NetRoute -Confirm:$False
    $null = Test-NetConnection localhost
    new-netroute -InterfaceAlias "Ethernet" -NextHop $newroute  -DestinationPrefix '0.0.0.0/0' -verbose

    Write-Output -InputObject "[$($VMName)]:: Joining domain as `"$($env:computername)`""
    while (!(Test-Connection -ComputerName $domainName -BufferSize 16 -Count 1 -Quiet -ea SilentlyContinue)) {
        Start-Sleep -Seconds 1
    }
    do {
        Add-Computer -DomainName $domainName -Credential $domainCred -ea SilentlyContinue -verbose
    } 
    until ($?)
} -ArgumentList $VMName, $domainCred, $domainName

Restart-FabricVM $VMName
Wait-PSDirect $VMName -cred $domainCred
Write-Output -InputObject "[$($VMName)]:: Disabling Automatic Checkpoints"
Set-VM -Name $VMName -AutomaticCheckpointsEnabled $False
Write-Output -InputObject "[$($VMName)]:: Disabling Time Synchronization Integration Services"
Get-VMIntegrationService -VMName $VMName -Name "Time Synchronization" | Disable-VMIntegrationService -Verbose

Restart-FabricVM $VMName 

Wait-PSDirect $VMName -cred $domainCred
Write-Output -InputObject "[$($VMName)]:: Creating SQL Install Answer File"
Create-SQLInstallFile
Write-Output -InputObject "[$($VMName)]:: Starting SQL Install and VM Configuration"
Install-SQL -VMName $VMName -GuestOSName $GuestOSName 
Install-SSMSSCOM -VMName $VMName -GuestOSName $GuestOSName
#Write-Output -InputObject "[$($VMName)]:: Hardening for TLS1.2"
#Configure-TLS1.2 -VMName $VMName
#Write-Output -InputObject "[$($VMName)]:: Installing SCOM 2022 Pre Reqs"
#Install-SCOMPrereqs -VMName $VMName
Restart-FabricVM -VMName $VMname
Wait-PSDirect $VMName -cred $domainCred
#Write-Output -InputObject "[$($VMName)]:: Installing SCOM 2022"
#Install-SCOM $VMName -GuestOSName $GuestOSName
#Write-Output -InputObject "[$($VMName)]:: Uninstalling Microsoft Edge" 
#Remove-MSEdge -VMname $VMName
Configure-FabricVMCleanup -VMName $VMName
$SQLServer=$VMName
Rename-Localadmin -VMName $VMName
#endregion


<#>



#region 004 - Building PAW Server 

$VMName = 'PC01'
$GuestOSName = 'PC01'
$IPNumber = '61'

Create-FabricVM $VMName $GuestOSName $IPNumber

Invoke-Command -VMName $VMName -Credential $localCred {
    param($VMName, $domainCred, $domainName)

    $newroute = $Gateway
    Write-Output -InputObject "[$($VMName)]:: Configuring Default Gateway"
    $null = Get-Netroute | Where-Object DestinationPrefix -eq "0.0.0.0/0" | Remove-NetRoute -Confirm:$False
    $null = Test-NetConnection localhost
    new-netroute -InterfaceAlias "Ethernet" -NextHop $newroute  -DestinationPrefix '0.0.0.0/0' -verbose

    Write-Output -InputObject "[$($VMName)]:: Management tools"
    $null = Install-WindowsFeature RSAT-Clustering, RSAT-Hyper-V-Tools
    Write-Output -InputObject "[$($VMName)]:: Joining domain as `"$($env:computername)`""
    while (!(Test-Connection -ComputerName $domainName -BufferSize 16 -Count 1 -Quiet -ea SilentlyContinue)) {
        Start-Sleep -Seconds 1
    }
    do {
        Add-Computer -DomainName $domainName -Credential $domainCred -ea SilentlyContinue
    }
    until ($?)
} -ArgumentList $VMName, $domainCred, $domainName

Restart-FabricVM $VMName
Wait-PSDirect $VMName -cred $domainCred

Write-Output -InputObject "[$($VMName)]:: Disabling Automatic Checkpoints"
Set-VM -Name $VMName -AutomaticCheckpointsEnabled $False
Write-Output -InputObject "[$($VMName)]:: Disabling Time Synchronization Integration Services"
Get-VMIntegrationService -VMName $VMName -Name "Time Synchronization" | Disable-VMIntegrationService -Verbose
Write-Output -InputObject "[$($VMName)]:: Uninstalling Microsoft Edge" 
#Remove-MSEdge -VMname $VMName
Configure-FabricVMCleanup -VMName $VMName
Copy-DarkFabricAddonsPAW -VMName $VMName -GuestOSName $GuestOSName
Install-LAPSPAW -VMName $VMName -GuestOSName $GuestOSName
Install-WSUSADMINPAW -VMName $VMname -GuestOSName $GuestOSName
Install-SSMSPAW -VMName $VMName -GuestOSName $GuestOSName
#Configure-TLS1.2 -VMName $VMName
Rename-Localadmin -VMName $VMName
Restart-FabricVM $VMName 

Wait-PSDirect $VMName -cred $domainCred


#endregion

#region 005 - Building WSUS Server
$VMName = 'FABWSUS01'
$GuestOSName = 'FABWSUS01'
$IPNumber = '31'

Create-FabricVM $VMName $GuestOSName $IPNumber

Invoke-Command -VMName $VMName -Credential $localCred {
    param($VMName, $domainCred, $domainName)

    $newroute = $Gateway
    Write-Output -InputObject "[$($VMName)]:: Configuring Default Gateway"
    $null = Get-Netroute | Where-Object DestinationPrefix -eq "0.0.0.0/0" | Remove-NetRoute -Confirm:$False
    $null = Test-NetConnection localhost
    new-netroute -InterfaceAlias "Ethernet" -NextHop $newroute  -DestinationPrefix '0.0.0.0/0' -verbose

    Write-Output -InputObject "[$($VMName)]:: Joining domain as `"$($env:computername)`""
    while (!(Test-Connection -ComputerName $domainName -BufferSize 16 -Count 1 -Quiet -ea SilentlyContinue)) {
        Start-Sleep -Seconds 1
    }
    do {
        Add-Computer -DomainName $domainName -Credential $domainCred -ea SilentlyContinue
    }
    until ($?)
} -ArgumentList $VMName, $domainCred, $domainName

Restart-FabricVM $VMName
Wait-PSDirect $VMName -cred $domainCred
Write-Output -InputObject "[$($VMName)]:: Disabling Automatic Checkpoints"
Set-VM -Name $VMName -AutomaticCheckpointsEnabled $False
Write-Output -InputObject "[$($VMName)]:: Disabling Time Synchronization Integration Services"
Get-VMIntegrationService -VMName $VMName -Name "Time Synchronization" | Disable-VMIntegrationService -Verbose

Restart-FabricVM $VMName 

Wait-PSDirect $VMName -cred $domainCred
Install-WSUS -VMName $VMName -GuestOSName $GuestOSName
#Configure-TLS1.2 -VMName $VMName
Write-Output -InputObject "[$($VMName)]:: Uninstalling Microsoft Edge" 
#Remove-MSEdge -VMname $VMName
Rename-Localadmin -VMName $VMName
Configure-FabricVMCleanup -VMName $VMName
#endregion

</#>

#region 006 - Building DC02...


$VMName = 'FABDC02'
$GuestOSName = 'FABDC02'
$IPNumber = '12'

  
Create-FabricVM $VMName $GuestOSName $IPNumber
Invoke-Command -VMName $VMName -Credential $localCred {
    param($VMName, $domainCred, $domainName,$dsrestoremodePassword)

    $newroute = $Gateway
    Write-Output -InputObject "[$($VMName)]:: Configuring Default Gateway"
    $null = Get-Netroute | Where-Object DestinationPrefix -eq "0.0.0.0/0" | Remove-NetRoute -Confirm:$False
    $null = Test-NetConnection localhost
    new-netroute -InterfaceAlias "Ethernet" -NextHop $newroute  -DestinationPrefix '0.0.0.0/0' -verbose


    Write-Output -InputObject "[$($VMName)]:: Installing AD"
    $null = Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
    Write-Output -InputObject "[$($VMName)]:: Joining domain as `"$($env:computername)`""
    while (!(Test-Connection -ComputerName $domainName -BufferSize 16 -Count 1 -Quiet -ea SilentlyContinue)) {
        Start-Sleep -Seconds 1
    }
 
    do {
        Add-Computer -DomainName $domainName -Credential $domainCred -ea SilentlyContinue
    }

    until ($?)

} -ArgumentList $VMName, $domainCred, $domainName

Restart-FabricVM $VMName
Wait-PSDirect $VMName -cred $domainCred

Invoke-Command -VMName $VMName -Credential $domainCred {
    param($VMName, $domainName, $domainAdminPassword,$dsrestoremodePassword)
    Write-Output -InputObject "[$($VMName)]:: Waiting for name resolution"
    while ((Test-NetConnection -ComputerName $domainName).PingSucceeded -eq $false) {
        Start-Sleep -Seconds 1
    }
    Write-Output -InputObject "[$($VMName)]:: Enabling Active Directory and promoting to domain controller"
    Install-ADDSDomainController -DomainName $domainName -InstallDNS -NoRebootOnCompletion -SafeModeAdministratorPassword (ConvertTo-SecureString -String $dsrestoremodePassword -AsPlainText -Force) -confirm:$false 
} -ArgumentList $VMName, $domainName, $domainAdminPassword,$dsrestoremodePassword
Restart-FabricVM $VMName

Write-Output -InputObject "[$($VMName)]:: Disabling Automatic Checkpoints"
Set-VM -Name $VMName -AutomaticCheckpointsEnabled $False
Write-Output -InputObject "[$($VMName)]:: Disabling Time Synchronization Integration Services"
Get-VMIntegrationService -VMName $VMName -Name "Time Synchronization" | Disable-VMIntegrationService -Verbose
Write-Output -InputObject "[$($VMName)]:: Configuring NTP on the Domain Controller"
#Configure-ExternalNTP -VMName $VMName -GuestOSName $GuestOSName
Write-Output -InputObject "[$($VMName)]:: Uninstalling Microsoft Edge" 
#Remove-MSEdge -VMname $VMName
Configure-FabricVMCleanup -VMName $VMName
#Configure-TLS1.2 -VMName $VMName
Restart-FabricVM $VMName 

Wait-PSDirect $VMName -cred $domainCred

#endregion


#region _Scratch
<#>
#region TEMP 010 - Building Optional 3 Node Switchless S2D Nodes for Lab and Testing...
$VMName = 'vs2dp01'
$GuestOSName = 'vs2dp01'
$IPNumber = '80'

Create-FabricVM $VMName $GuestOSName $IPNumber

Invoke-Command -VMName $VMName -Credential $localCred {
    param($VMName, $domainCred, $domainName)

    $newroute = $Gateway
    Write-Output -InputObject "[$($VMName)]:: Configuring Default Gateway"
    $null = Get-Netroute | Where-Object DestinationPrefix -eq "0.0.0.0/0" | Remove-NetRoute -Confirm:$False
    $null = Test-NetConnection localhost
    new-netroute -InterfaceAlias "Ethernet" -NextHop $newroute  -DestinationPrefix '0.0.0.0/0' -verbose

    Write-Output -InputObject "[$($VMName)]:: Joining domain as `"$($env:computername)`""
    while (!(Test-Connection -ComputerName $domainName -BufferSize 16 -Count 1 -Quiet -ea SilentlyContinue)) {
        Start-Sleep -Seconds 1
    }
    do {
        Add-Computer -DomainName $domainName -Credential $domainCred -ea SilentlyContinue
    }
    until ($?)
} -ArgumentList $VMName, $domainCred, $domainName
Write-Output -InputObject "[$($VMName)]:: Disabling Automatic Checkpoints"
Set-VM -Name $VMName -AutomaticCheckpointsEnabled $False
Write-Output -InputObject "[$($VMName)]:: Disabling Time Synchronization Integration Services"
Get-VMIntegrationService -VMName $VMName -Name "Time Synchronization" | Disable-VMIntegrationService -Verbose
#Write-Output -InputObject "[$($VMName)]:: Uninstalling Microsoft Edge" 
#Remove-MSEdge -VMname $VMName
#Rename-Localadmin -VMName $VMName
Configure-FabricVMCleanup -VMName $VMName
#Configure-TLS1.2 -VMName $VMName


Invoke-FabricNodeStorageBuild $VMName $GuestOSName

Restart-FabricVM $VMName 

$VMName = 'vs2dp02'
$GuestOSName = 'vs2dp02'
$IPNumber = '81'

Create-FabricVM $VMName $GuestOSName $IPNumber

Invoke-Command -VMName $VMName -Credential $localCred {
    param($VMName, $domainCred, $domainName)

    $newroute = $Gateway
    Write-Output -InputObject "[$($VMName)]:: Configuring Default Gateway"
    $null = Get-Netroute | Where-Object DestinationPrefix -eq "0.0.0.0/0" | Remove-NetRoute -Confirm:$False
    $null = Test-NetConnection localhost
    new-netroute -InterfaceAlias "Ethernet" -NextHop $newroute  -DestinationPrefix '0.0.0.0/0' -verbose

    Write-Output -InputObject "[$($VMName)]:: Joining domain as `"$($env:computername)`""
    while (!(Test-Connection -ComputerName $domainName -BufferSize 16 -Count 1 -Quiet -ea SilentlyContinue)) {
        Start-Sleep -Seconds 1
    }
    do {
        Add-Computer -DomainName $domainName -Credential $domainCred -ea SilentlyContinue
    }
    until ($?)
} -ArgumentList $VMName, $domainCred, $domainName
Write-Output -InputObject "[$($VMName)]:: Disabling Automatic Checkpoints"
Set-VM -Name $VMName -AutomaticCheckpointsEnabled $False
Write-Output -InputObject "[$($VMName)]:: Disabling Time Synchronization Integration Services"
Get-VMIntegrationService -VMName $VMName -Name "Time Synchronization" | Disable-VMIntegrationService -Verbose
#Write-Output -InputObject "[$($VMName)]:: Uninstalling Microsoft Edge" 
#Remove-MSEdge -VMname $VMName
#Rename-Localadmin -VMName $VMName
Configure-FabricVMCleanup -VMName $VMName
#Configure-TLS1.2 -VMName $VMName


Invoke-FabricNodeStorageBuild $VMName $GuestOSName
Restart-FabricVM $VMName 


$VMName = 'vs2dp03'
$GuestOSName = 'vs2dp03'
$IPNumber = '82'

Create-FabricVM $VMName $GuestOSName $IPNumber

Invoke-Command -VMName $VMName -Credential $localCred {
    param($VMName, $domainCred, $domainName)

    $newroute = $Gateway
    Write-Output -InputObject "[$($VMName)]:: Configuring Default Gateway"
    $null = Get-Netroute | Where-Object DestinationPrefix -eq "0.0.0.0/0" | Remove-NetRoute -Confirm:$False
    $null = Test-NetConnection localhost
    new-netroute -InterfaceAlias "Ethernet" -NextHop $newroute  -DestinationPrefix '0.0.0.0/0' -verbose

    Write-Output -InputObject "[$($VMName)]:: Joining domain as `"$($env:computername)`""
    while (!(Test-Connection -ComputerName $domainName -BufferSize 16 -Count 1 -Quiet -ea SilentlyContinue)) {
        Start-Sleep -Seconds 1
    }
    do {
        Add-Computer -DomainName $domainName -Credential $domainCred -ea SilentlyContinue
    }
    until ($?)
} -ArgumentList $VMName, $domainCred, $domainName

Write-Output -InputObject "[$($VMName)]:: Disabling Automatic Checkpoints"
Set-VM -Name $VMName -AutomaticCheckpointsEnabled $False
Write-Output -InputObject "[$($VMName)]:: Disabling Time Synchronization Integration Services"
Get-VMIntegrationService -VMName $VMName -Name "Time Synchronization" | Disable-VMIntegrationService -Verbose
#Write-Output -InputObject "[$($VMName)]:: Uninstalling Microsoft Edge" 
#Remove-MSEdge -VMname $VMName
#Rename-Localadmin -VMName $VMName
Configure-FabricVMCleanup -VMName $VMName
#Configure-TLS1.2 -VMName $VMName


Invoke-FabricNodeStorageBuild $VMName $GuestOSName

Restart-FabricVM $VMName 
#endregion
</#>

#Steve we should build a function that deploys this or we need to know the basics
#What Windows Features and Roles
#What Configurations are required
#What Firewall Ports ETC - I have no clue
#Shell Server Install for now
#endregion

Write-Log 'Done' 'Done!'

#region TODO Wishlist
#Todo
#Write Function to remove Edge from Systems
####Fix Global Variable issue on Copy Functions $Global:VariableName
####Need to Write Function to Move Servers to the right OU's
#Need to Edit the Import of Dave's Policies to match  User and Passwords
###Need to Write a Function to install and Deploy LAPS - Troubleshoot First Run Failing on Install / Installed ok now
#Need to Write a Function to Deploy MDATP Agents
#Need to Write a Function to Deploy RSAT Clustering, Hyper-v, and whatever Other tools to PAW
#Need to Write a Function for the Time Server Connectivity - <GetfromDave>
#Need to Write and Create JEA Access Groups for Local Admins on Server / HCI
#Need to Write and Create Zero Trust Access Groups and Users for DC_Admins
#Need to modify Logon Locally Policy to only allow DC Logins using DC_ADmin
#Need to Modify Logon Locally Policy to only Allow HCI Admins to login to HCI and Hyper-Visors
#Need to script the Delina Secret Server Install
#Need to load the consoles on the PAW
#Need to Configure IPSEC Network Isolation Policies between Jump Box and other Sources inside the Fabric
#Need to Remove Domain Admins from Local Administrators Group - Default Policy
#Need to Configure the CIS Policies for SMB Signing and Encryption for HCI Hosts RDMA Usage on 2019 - Ensure 2019 CIS Benchmarks applied there
####Need to Configure and LINK Group Policy Objects - See if there is a better way to automate this.   Maybe pull the XML out from the GPOs and recopy back in
#Need to Configure and figure out Windows Firewall Policies to block all unwanted traffic (Network Isolation)
#endregion