
$DomainCred = Get-Credential

    $VMName = 'TMWSUS01'
    $GuestOSName = 'TMWSUS01'
    $VmPath = 'E:\DCBuild_TMOrlando2019\VHDs\TMWSUS01'
  

    #Adding WSUS Drive 

    New-VHD -Path "$($VMPath)\$($GuestOSName) - WSUS Data 1.vhdx" -Dynamic -SizeBytes 100GB 
    Mount-VHD -Path "$($VMPath)\$($GuestOSName) - WSUS Data 1.vhdx"
    $DiskNumber = (Get-Diskimage -ImagePath "$($VMPath)\$($GuestOSName) - WSUS Data 1.vhdx").Number
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT 
    Get-Disk -Number $DiskNumber | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "WSUS" -Confirm:$False
    Dismount-VHD -Path "$($VMPath)\$($GuestOSName) - WSUS Data 1.vhdx"
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($GuestOSName) - WSUS Data 1.vhdx" -ControllerType SCSI
  

  



    icm -VMName $VMName -Credential $domainCred { 

    Get-Disk | Where OperationalStatus -EQ "Offline" | Set-Disk -IsOffline $False 
    Get-Disk | Where Number -NE "0" |  Set-Disk -IsReadOnly $False
    $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object {$_.Label -like "WSUS*"}
    $WSUSDrive = $Driveletter.DriveLetter
    
    Install-WindowsFeature -Name UpdateServices -IncludeManagementTools
    Install-WindowsFeature -Name UpdateServices-Ui
    New-Item -Path $WSUSDrive -Name WSUS -ItemType Directory
    CD "C:\Program Files\Update Services\Tools"
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
    #Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Windows Server 2016" } | Set-WsusProduct
    Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Windows Server 2008 R2" } | Set-WsusProduct

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
    $subscription.SynchronizeAutomatically=$true

    Write-Verbose "Set synchronization scheduled for midnight each night" -Verbose
    $subscription.SynchronizeAutomaticallyTimeOfDay= (New-TimeSpan -Hours 0)
    $subscription.NumberOfSynchronizationsPerDay=1
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

    icm -VMName $VMName -Credential $domainCred {
    #Change server name and port number and $True if it is on SSL

    $Computer = $env:COMPUTERNAME
    [String]$updateServer1 = $Computer
    [Boolean]$useSecureConnection = $False
    [Int32]$portNumber = 8530

    # Load .NET assembly

    [void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")

    $count = 0

    # Connect to WSUS Server

    $updateServer = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer($updateServer1,$useSecureConnection,$portNumber)

    write-host "<<<Connected sucessfully >>>" -foregroundcolor "yellow"

    $updatescope = New-Object Microsoft.UpdateServices.Administration.UpdateScope

    $u=$updateServer.GetUpdates($updatescope )

    foreach ($u1 in $u )

    {

    if ($u1.IsSuperseded -eq 'True')

    {

    write-host Decline Update : $u1.Title

    $u1.Decline()

    $count=$count + 1

    }

    }

    write-host Total Declined Updates: $count

    trap

    {

    write-host "Error Occurred"

    write-host "Exception Message: "

    write-host $_.Exception.Message

    write-host $_.Exception.StackTrace

    exit

    }

    # EOF


    }
    