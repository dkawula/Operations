<#
    .SYNOPSIS
    Creates a HTML Report describing Storage Spaces Status, Deduplication, ReFS, Data Integrity, and VM Checkpoints/Replicas
   
   	Original Version by :Michael Rüefli (www.miru.ch) - https://gallery.technet.microsoft.com/scriptcenter/Storage-Spaces-Status-2e8e7fbb
    Updated Version by Dave Kawula MVP (www.checkyourlogs.net) @DaveKawula
    Moved up to Github to allow for community edits.
	
	THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND. THE ENTIRE 
	RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.
	
	Version 1.2.0 (stable), January 22th, 2015
    Version 2.0.0 (stable), November 16, 2018
	
    .DESCRIPTION
	
    This script creates a HTML report showing the following information about a Windows
    Storage Spaces environment.
	
	* Report Generation Time, Reported Node
	* Storage Pools
	* Storage Enclosures
	* Virtual Disks
    * Physical Disks with Enclosure Mapping
    * MPIO Path Information per physical Disk
    * Storage Spaces Driver Events
    * Storage Tiering Statistics
    * Tested with Storage Spaces and Storage Spaces Direct
    * Runs locally on each node
    * Gathers Diagnostic information for Storage Spaces (ReFS, Data Integrity Scans)
    * Reports on Deduplication
    * Updated and runs on 2016 and 2019
	
  	
	.PARAMETER StorageNode
    The hostname of the storage node to query

	.PARAMETER IncludeMPIO
	This switch enables MPIO Information gathering
	
	.PARAMETER IncludeEvents
	This switch enables Eventlog Information gathering

    .PARAMETER IncludeTieringStats
	This switch enables Storage Tiering statistics gathering

    .PARAMETER OutputFile
	This parameter can be used to select an alternate output file location than %TEMP%\StorageReport.html

    .PARAMETER IncludeEvents
	This switch opens the report file with the default handler right after creation

    .PARAMETER MailFrom
	Email address to send to. Passed directly to Send-MailMessage as -From
	
	.PARAMETER MailTo
	Email address to send to. Passed directly to Send-MailMessage as -To
	
	.PARAMETER MailServer
	SMTP Mail server to attempt to send through. Passed directly to Send-MailMessage as -SmtpServer
    
    .PARAMETER IncludeDedupStats
    Gathers Information on Deduplication on the Storage Pools will work on ReFS and NTFS volumes with Deduplication Enabled

    .PARAMETER IncludeRefSDebugEvents
    Gathers infromation from the ReFS Event Logs

    .PARAMETER IncludeVMInfo
    Gathers General Information about the Hyper-V VM's and is used for Project Titan for Replicas / CheckPoints
     
    Note --> I have Hard coded the SMTP Settigns for now.
	.EXAMPLE
    Generate the HTML report and send it via Email
    .\CreateStorageReport.ps1 -StorageNode SOFSN01 -IncludeMPIO -IncludeEvents -OutputFile C:\Reports\StorageReport_demo.html -MailFrom storage@domain.com -Mailto support@domain.com -MailServer smtp.domain.com

    .NOTES
    Changes / Bugfixes
    V 1.1.0
    - Fixed Storage Enclosure Sensor Health errors
    - Added Physical Disk Reliability Counters
    - Fixed Pool gathering where physical disks where displayed multiple times
    - changed -Mailto Parameter to be an array of Strings to support multiple recipients

    V 1.2.0
    - Added Storage Tiering Statistics (-IncludeTieringStats)

    V 2.0 
    - Added Reporting for ReFS
    - Added Reporting for Deduplication
    - Added Reporting for Data Integrity Scans
    - Added Reporting for Hyper-V Checkpoint and general VM Info
    #>

Param(
    [Parameter(Mandatory=$True)]
    [STRING]$StorageNode,
    
    [Parameter(Mandatory=$false)]
    [SWITCH]$IncludeMPIO,

    [Parameter(Mandatory=$false)]
    [SWITCH]$IncludeEvents,

    [Parameter(Mandatory=$false)]
    [SWITCH]$IncludeTieringStats,

    [Parameter(Mandatory=$false)]
    [STRING]$OutPutFile="$ENV:TEMP\StorageReport_$StorageNode.html",

    [Parameter(Mandatory=$false)]
    [SWITCH]$OpenFileAfterCreation,
    
    [Parameter(Mandatory=$false)]
    [STRING]$MailFrom,

    [Parameter(Mandatory=$false)]
    [STRING[]]$MailTo,

    [Parameter(Mandatory=$false)]
    [STRING]$MailServer,

    [Parameter(Mandatory=$false)]
    [SWITCH]$IncludeDedupStats,

    [Parameter(Mandatory=$false)]
    [SWITCH]$IncludeReFSDebugEvents,

    [Parameter(Mandatory=$false)]
    [SWITCH]$IncludeVMInfo
)

$VerbosePreference="continue"

#We can add this back in later --> For now we are running this all locally
#Create Persistent Remote Session
#Write-Verbose "Creating new WinRM Ression with Computer: $StorageNode"
#$PSSession = New-PSSession -ComputerName $StorageNode

#region data gathering
#Get Storage Enclosure Info
Write-Verbose "Gathering Enclosure Information"
$Enclosures = Invoke-Command -ScriptBlock {
    $Enclosures = Get-StorageEnclosure | select *
    $EnclosureInfo = @()
    Foreach ($e in $Enclosures)
    {

        $eFANState = $e.FANOperationalStatus -join "."
        $ePWRSupplyState = $e.PowerSupplyOperationalStatus -join "."
        $eIOContrState = $e.IOControllerOperationalStatus -join "."
        $eTempSensorState = $e.TemperatureSensorOperationalStatus -join "."

        $encinfo = New-Object -TypeName PSObject -Property @{
            FriendlyName=$e.FriendlyName
            UniqueID=$e.UniqueId
            SerialNumber=$e.SerialNumber
            Firmware=$e.FirmwareVersion
            Slots=$e.NumberOfSlots
            HealthState=$e.HealthStatus
            IOControllerState=$eIOContrState
            FANState=$eFANState
            PowerSupplyState=$ePWRSupplyState
            TemperatureSensorState=$eTempSensorState
        }
        $EnclosureInfo += $encinfo
    }
    return $EnclosureInfo 
}

#Get Storage Pool Info
Write-Verbose "Gathering Storage Pool Information"
$StoragePoolInfo = Invoke-Command -ScriptBlock  {
    $StoragePoolInfo = @()
    $StoragePools = Get-StoragePool | Where-Object {$_.FriendlyName -ne 'Primordial'} 
    Foreach ($sp in $StoragePools)
    {
        $PoolObject = New-Object -TypeName PSObject -Property @{
            FriendlyName=$sp.FriendlyName
            SizeGB=($sp.Size / 1GB)
            AllocatedGB=($sp.AllocatedSize / 1GB)
            AllocatedPercent=[System.Math]::Round((100/$sp.Size)*($sp.AllocatedSize), 2)
            IsClustered=$sp.IsClustered
            EnclosureAwareDefault=$sp.EnclosureAwareDefault
            OperationalStatus=$sp.OperationalStatus
            HealthStatus=$sp.HealthStatus
        }
        $StoragePoolInfo += $PoolObject
    }
    Return $StoragePoolInfo
}

#Get virtual Disks
Write-Verbose "Gathering Virtual Disk (Spaces) Information"
$VirtualDiskInfo = Invoke-Command -ScriptBlock  {
    $StoragePools = Get-StoragePool
    $VirtualDiskInfo = @()

    Foreach ($sp in $StoragePools)
    {
        $VirtualDisks = Get-VirtualDisk -StoragePool $sp
        Foreach ($vd in $VirtualDisks)
        {
            $StorageTiers = $vd  | Get-StorageTier
            If ($StorageTiers)
            {
                Write-Verbose "Gathering Storage Tier Information"
                $IsTiered=$true
            }
            Else
            {
                $IsTiered=$false
            }
            
            $VirtualDiskobj = New-Object -TypeName PSObject -Property @{
            FriendlyName=$vd.FriendlyName
            StoragePool=$sp.FriendlyName
            ResiliencySettingName=$vd.ResiliencySettingName
            NumberOfDataCopies=$vd.NumberOfDataCopies
            NumberofColumns=$vd.NumberofColumns
            Interleave=$vd.Interleave
            IsEnclosureAware=$vd.IsEnclosureAware
            SizeGB=($vd.Size / 1GB)
            WriteCacheSizeGB=($vd.WriteCacheSize / 1GB)
            IsTiered=$IsTiered
            SSDTierSizeGB=(($StorageTiers | Where-Object {$_.MediaType -eq 'SSD'}).Size / 1GB)
            HDDTierSizeGB=(($StorageTiers | Where-Object {$_.MediaType -eq 'HDD'}).Size / 1GB)
            OperationalStatus=$vd.OperationalStatus
            HealthStatus=$vd.HealthStatus
            }
            $VirtualDiskInfo += $VirtualDiskobj
        }      

    }  
    Return $VirtualDiskInfo
}


#Get Physical Disks
Write-Verbose "Gathering Physical Disk Information"
$PhysicalDiskInfo = Invoke-Command -ScriptBlock  {
    #$Enclosures = $USING:Enclosures
    $PhysicalDiskInfo = @()

    $pdisks = Get-PhysicalDisk | where {($_.canpool) -or ($_.CannotPoolReason -match 'In a Pool')}
    Foreach ($pd in $pdisks)
    {
        $opsdata = Get-StorageReliabilityCounter -PhysicalDisk $pd
        $findstrg = $pd.PhysicalLocation -match '[0-9a-z]{16}'
        $EnslosureID = $matches[0]
        $dskobj = New-Object -TypeName PSObject -Property @{
            Name=$pd.FriendlyName
            Slot=$pd.SlotNumber
            EnclosureID=($EnslosureID)
            EnclosureSerial=($Enclosures | where-object {$_.UniqueId -eq $EnslosureID}).SerialNumber
            HealthState=$pd.HealthStatus
            Manufacturer=$pd.Manufacturer
            Model=$pd.Model
            FirmwareVersion=$pd.FirmwareVersion
            OperationalState=$pd.OperationalStatus
            MediaType=$pd.MediaType
            SizeGB=($pd.Size /1GB)
            Usage=$pd.Usage
            ID=$pd.UniqueId
            SerialNumber=$pd.SerialNumber
            PowerOnHours=$opsdata.PowerOnHours
            Temperature=$opsdata.Temperature
            TemperatureMax=$opsdata.TemperatureMax
            StartStopCycleCount=$opsdata.StartStopCycleCount
            MaxReadLatency_ms=$opsdata.ReadLatencyMax
            MaxWriteLatency_ms=$opsdata.WriteLatencyMax
            ReadErrors=$opsdata.ReadErrorsTotal
            WriteErrors=$opsdata.WriteErrorsTotal
        }
        $PhysicalDiskInfo += $dskobj
        }
    Return $PhysicalDiskInfo
}


If ($IncludeMPIO)
{
    #Get MPIO Info
    Write-Verbose "Gathering MPIO Path Information per Disk"
    $MPIOPathInfo = Invoke-Command -ScriptBlock {
        $StoragePools = Get-StoragePool | Where-Object {$_.FriendlyName -ne 'Primordial'} 
        $MPIOInfo = $StoragePools | Get-PhysicalDisk | Foreach-Object {mpclaim -s -d $_.DeviceID}
        Return $MPIOInfo
    } | Select-String "paths"
}

If ($IncludeDedupStats){
    Write-Verbose "Gathering Deduplication Statistics"

    $DedupStatus = Get-DedupStatus | Select-Object *
    $DedupVolumeStats = Get-dedupvolume D: | Select * 
    $Dedupevents = Get-WinEvent -MaxEvents 10 -LogName Microsoft-Windows-Deduplication/Diagnostic | Select-Object *
    $DedupDiagevents = Get-WinEvent -MaxEvents 10 -LogName Microsoft-Windows-Deduplication/Scrubbing | Select-Object *
}

If ($IncludeReFSDebugEvents){
    Write-Verbose "Gathering ReFS Operational Events"

     $ReFSEvents = Get-WinEvent -MaxEvents 10 -LogName Microsoft-Windows-ReFS/Operational | Select-Object * 
     $DataIntegrityAdmin = Get-WinEvent -MaxEvents 10 -LogName Microsoft-Windows-DataIntegrityScan/Admin | Select-Object * 
     $DataIntegrityCrash = Get-WinEvent -MaxEvents 10 -LogName Microsoft-Windows-DataIntegrityScan/CrashRecovery | Select-Object * 
}

If ($IncludeVMInfo){
    Write-Verbose "Gathering Hyper-V VM Information"
     $VMInfo = @()
     $VMInfo += Get-VM -ComputerName Localhost
#     $VMInfo += Get-VM -ComputerName EPFCS2D2
      
     $VMReplicaInfo = @()
     $VMReplicaInfo =  Get-VM -ComputerName Localhost | Get-VMSnapshot
     #$VMReplicaInfo =  Get-VM -ComputerName EPFCS2D2 | Get-VMSnapshot
}


If ($IncludeEvents)
{
    Write-Verbose "Gathering Storage Spaces Driver Events"
    #Get Storage Spaces Driver Events
    $StorageSpaceDriverEvts = Invoke-Command -ScriptBlock {
        Get-WinEvent -MaxEvents 20 -LogName  "Microsoft-Windows-StorageSpaces-Driver/Operational"
    }
}

If ($IncludeTieringStats)
{
    #Get Storage Tiering Statistics
    Write-Verbose "Gathering Storage Tiering Statistics"
    $TieringStats = Invoke-Command -ScriptBlock {

        $TierStats=@()
        $StorageOptInfo = get-winevent -LogName "Microsoft-Windows-Storage-Tiering/Admin" | ? {$_.ID -eq 22}
        Foreach ($entry in $StorageOptInfo)
        {
            $entrydate=$entry.TimeCreated
            $info = $entry.Message
            $info -match 'Percent of total I/Os serviced from the SSD tier: [0-9]{1,3}%' | out-null ; $FastTierHitRate = $matches[0]        
            $info -match 'Current size of the faster .* tier: [0-9]{1,3},[0-9]{1,2}.*?GB' | out-null ; $CurrentFastTierSize = $matches[0]        
            $info -match '100%.*?[0-9]{1,3},[0-9]{1,2}.*?[G|M|K|T]B' | out-null; $FastTierSizeReq100 = ($matches[0]).trim()
            $info -match '95%.*?[0-9]{1,3},[0-9]{1,2}.*?GB|MB|KB' | out-null; $FastTierSizeReq95 = $matches[0]
            $info -match '90%.*?[0-9]{1,3},[0-9]{1,2}.*?GB|MB|KB' | out-null; $FastTierSizeReq90 = $matches[0]
            $info -match '85%.*?[0-9]{1,3},[0-9]{1,2}.*?GB|MB|KB' | out-null; $FastTierSizeReq85 = $matches[0]
            $info -match '80%.*?[0-9]{1,3},[0-9]{1,2}.*?GB|MB|KB' | out-null; $FastTierSizeReq80 = $matches[0]
            $info -match '[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}' | out-null; [string]$VolumeGuid = $matches[0]
            $Volume = get-volume | ? {$_.path -match $VolumeGuid}
            $VolumeName = $Volume.FileSystemLabel
            $volinfo = New-Object -TypeName PSObject -Property @{
                Date=$entrydate
                VolumeName=$VolumeName
                FastTierSize=$CurrentFastTierSize
                FastTierHitRate=$FastTierHitRate
                FastTierRequiredSize="$FastTierSizeReq100; $FastTierSizeReq90; $FastTierSizeReq80"
            }
            $TierStats += $volinfo

        }
        Return $TierStats
    }    
}
#endregion


#Remove Persistent Remote Session
#Write-Verbose "Removing WinRM Session"
#$PSSession | Remove-PSSession


#region output formatting
Write-Verbose "Constructing Output"
$Output = ""
$TableHdr = @"
<style>
BODY{background-color:white;}
TABLE{border-width: 1px;border-style: solid;border-color: grey;border-collapse: collapse;}
TH{border-width: 1px;padding: 4px;border-style: solid;border-color: grey;background-color:#000099;font-family:arial;font-size: 8pt; color: #FBFBEF;}
TD{border-width: 1px;padding: 4px;border-style: solid;border-color: grey;font-family:arial;font-size: 8pt; color: black;}
</style>
"@



$Output+="<html>
<body>
<font size=""2"" face=""Arial,sans-serif"">
<h2 align=""center"">Storage Spaces Report</h3>
<h3 align=""center"">Node: $StorageNode</h3>
<h5 align=""center"">Generated $((Get-Date).ToString())</h5>
</font>"

$output += "<html>
<body>
<font size=""3"" face=""Arial,sans-serif"">
<h3 align=""left"">Storage Pools</h3>
</font>"
$output += $StoragePoolInfo | ConvertTo-Html -Property FriendlyName,SizeGB,AllocatedGB,AllocatedPercent,EnclosureAwareDefault,IsClustered,OperationalStatus,HealthStatus -Head $TableHdr | Foreach {
    If ($_ -like "*<td>Healthy</td>*") 
    {
        $_ -replace "<tr>", "<tr bgcolor=#CEF6CE>"
    }
    Else 
    {
        $_ -replace "<tr>", "<tr bgcolor=#F6CEE3>"
    }
}
$Output += " "

$output += "<html>
<body>
<font size=""3"" face=""Arial,sans-serif"">
<h3 align=""left"">Virtual Disks ( $($VirtualDiskInfo.count) )</h3>
</font>"
$output += $VirtualDiskInfo | ConvertTo-Html -Property FriendlyName,StoragePool,ResiliencySettingName,NumberOfDataCopies,NumberofColumns,Interleave,IsEnclosureAware,SizeGB,WriteCacheSizeGB,IsTiered,SSDTierSizeGB,HDDTierSizeGB,OperationalStatus,HealthStatus -Head $TableHdr | Foreach {
    If ($_ -like "*<td>Healthy</td>*") 
    {
        $_ -replace "<tr>", "<tr bgcolor=#CEF6CE>"
    }
    Else 
    {
        $_ -replace "<tr>", "<tr bgcolor=#F6CEE3>"
    }
}
$Output += " "


$output += "<html>
<body>
<font size=""3"" face=""Arial,sans-serif"">
<h3 align=""left"">Storage Enclosures ( $($Enclosures.count) )</h3>
</font>"
$output += $Enclosures | Sort-Object FriendlyName | ConvertTo-Html -Property FriendlyName,UniqueId,SerialNumber,Firmware,Slots,HealthState,PowerSupplyState,FANState,IOControllerState,TemperatureSensorState -Head $TableHdr | Foreach {
    If ($_ -like "*<td>Healthy</td>*") 
    {
        $_ -replace "<tr>", "<tr bgcolor=#CEF6CE>"
    }
    ElseIf ($_ -like "*<td>Unknown</td>*") 
    {
        $_ -replace "<tr>", "<tr bgcolor=#FFFF99>"
    }
    Else 
    {
        $_ -replace "<tr>", "<tr bgcolor=#F6CEE3>"
    }
}
$Output += " "

$output += "<html>
<body>
<font size=""3"" face=""Arial,sans-serif"">
<h3 align=""left"">Physical Disks ( $($PhysicalDiskInfo.count) )</h3>
</font>"
$output += $PhysicalDiskInfo | Sort-Object MediaType -Descending |  ConvertTo-Html -Property Name,Slot,Id,EnclosureID,Temperature,Mediatype,SizeGB,Manufacturer,Model,SerialNumber,FirmwareVersion,usage,OperationalState,HealthState,MaxReadLatency_ms,MaxWriteLatency_ms,PowerOnHours,TemperatureMax $TableHdr | Foreach {
    If ($_ -like "*<td>Healthy</td>*") 
    {
        $_ -replace "<tr>", "<tr bgcolor=#CEF6CE>"
    }
    Else 
    {
        $_ -replace "<tr>", "<tr bgcolor=#F6CEE3>"
    }
}
$Output += " "

If ($IncludeMPIO)
{
    $output += "<html>
    <body>
    <font size=""3"" face=""Arial,sans-serif"">
    <h3 align=""left"">MPIO Disk Path Info</h3>
    </font>"
    $output += $MPIOPathInfo |  ConvertTo-Html -Property Line | Foreach {
        If ($_ -like "*02 Paths*") 
        {
            $_ -replace "<tr>", "<tr bgcolor=#CEF6CE>"
        }
        Else 
        {
            $_ -replace "<tr>", "<tr bgcolor=#F6CEE3>"
        }
    }
    $Output += " "
}

If ($IncludeEvents)
{
    $output += "<html>
    <body>
    <font size=""3"" face=""Arial,sans-serif"">
    <h3 align=""left"">Storage Space Driver Events</h3>
    </font>"
    $output += $StorageSpaceDriverEvts |  ConvertTo-Html -Property TimeCreated,ID,LevelDisplayName,Message | Foreach {
        If ($_ -like "*<td>Warning</td>*") 
        {
            $_ -replace "<tr>", "<tr bgcolor=#FFFF99>"
        }
        ElseIf ($_ -like "*<td>Error</td>*")
        {
            $_ -replace "<tr>", "<tr bgcolor=#F6CEE3>"
        }
        Else 
        {
            $_ -replace "<tr>", "<tr bgcolor=#66CCFF>"
        }
    }
}

If ($IncludeTieringStats)
{
    $output += "<html>
    <body>
    <font size=""3"" face=""Arial,sans-serif"">
    <h3 align=""left"">Storage Tiering Statistics</h3>
    </font>"
    $output += $TieringStats |  ConvertTo-Html -Property Date,VolumeName,FastTierSize,FastTierHitRate,FastTierRequiredSize

}

if ($IncludeDedupStats){

 $output += "<html>
    <body>
    <font size=""3"" face=""Arial,sans-serif"">
    <h3 align=""left"">Deduplication Statistics</h3>
    </font>"
    $output += $DedupStatus |  ConvertTo-Html -Property Volume,Capacity,FreeSpace,SavingsRate,SavedSpace,UnoptimizedSize,UsedSpace,InPolicyFilesCount,InPolicyFileSize    
    

  $output += "<html>
    <body>
    <font size=""3"" face=""Arial,sans-serif"">
    <h3 align=""left"">Deduplication Events</h3>
    </font>"
    $output += $Dedupevents |  ConvertTo-Html -Property TimeCreated,ID,LevelDisplayName,Message | Foreach {
        If ($_ -like "*<td>Warning</td>*") 
        {
            $_ -replace "<tr>", "<tr bgcolor=#FFFF99>"
        }
        ElseIf ($_ -like "*<td>Error</td>*")
        {
            $_ -replace "<tr>", "<tr bgcolor=#F6CEE3>"
        }
        Else 
        {
            $_ -replace "<tr>", "<tr bgcolor=#66CCFF>"
        }
        }
    
   $output += "<html>
    <body>
    <font size=""3"" face=""Arial,sans-serif"">
    <h3 align=""left"">Deduplication Data Scrubbing</h3>
    </font>"
    $output += $DedupDiagevents |  ConvertTo-Html -Property TimeCreated,ID,LevelDisplayName,Message | Foreach {
        If ($_ -like "*<td>Warning</td>*") 
        {
            $_ -replace "<tr>", "<tr bgcolor=#FFFF99>"
        }
        ElseIf ($_ -like "*<td>Error</td>*")
        {
            $_ -replace "<tr>", "<tr bgcolor=#F6CEE3>"
        }
        Else 
        {
            $_ -replace "<tr>", "<tr bgcolor=#66CCFF>"
        }
        }
}

    If ($IncludeTieringStats)
{
    $output += "<html>
    <body>
    <font size=""3"" face=""Arial,sans-serif"">
    <h3 align=""left"">Storage Tiering Statistics</h3>
    </font>"
    $output += $TieringStats |  ConvertTo-Html -Property Date,VolumeName,FastTierSize,FastTierHitRate,FastTierRequiredSize

}

if ($IncludeReFSDebugEvents){

 $output += "<html>
    <body>
    <font size=""3"" face=""Arial,sans-serif"">
    <h3 align=""left"">ReFS Operational Events</h3>
    </font>"
    $output += $ReFSEvents |  ConvertTo-Html -Property TimeCreated,ID,LevelDisplayName,Message | Foreach {
        If ($_ -like "*<td>Warning</td>*") 
        {
            $_ -replace "<tr>", "<tr bgcolor=#FFFF99>"
        }
        ElseIf ($_ -like "*<td>Error</td>*")
        {
            $_ -replace "<tr>", "<tr bgcolor=#F6CEE3>"
        }
        Else 
        {
            $_ -replace "<tr>", "<tr bgcolor=#66CCFF>"
        }
        }

    $output += "<html>
    <body>
    <font size=""3"" face=""Arial,sans-serif"">
    <h3 align=""left"">Data Integrity Admin Events</h3>
    </font>"
    $output += $DataIntegrityAdmin |  ConvertTo-Html -Property TimeCreated,ID,LevelDisplayName,Message | Foreach {
        If ($_ -like "*<td>Warning</td>*") 
        {
            $_ -replace "<tr>", "<tr bgcolor=#FFFF99>"
        }
        ElseIf ($_ -like "*<td>Error</td>*")
        {
            $_ -replace "<tr>", "<tr bgcolor=#F6CEE3>"
        }
        Else 
        {
            $_ -replace "<tr>", "<tr bgcolor=#66CCFF>"
        }
        }

    $output += "<html>
    <body>
    <font size=""3"" face=""Arial,sans-serif"">
    <h3 align=""left"">Data Integrity Crash Debug Events</h3>
    </font>"
    $output += $DataIntegrityCrash |  ConvertTo-Html -Property TimeCreated,ID,LevelDisplayName,Message | Foreach {
        If ($_ -like "*<td>Warning</td>*") 
        {
            $_ -replace "<tr>", "<tr bgcolor=#FFFF99>"
        }
        ElseIf ($_ -like "*<td>Error</td>*")
        {
            $_ -replace "<tr>", "<tr bgcolor=#F6CEE3>"
        }
        Else 
        {
            $_ -replace "<tr>", "<tr bgcolor=#66CCFF>"
        }
        }
    }


If ($IncludeVMInfo)
{
    $output += "<html>
    <body>
    <font size=""3"" face=""Arial,sans-serif"">
    <h3 align=""left"">Hyper-V Titan Info </h3>
    </font>"
    $output += $VMInfo |  ConvertTo-Html -Property Name,State,CPUUsage,MemoryAssigned,Uptime,Status,Version
    If ($_ -like "*<td>Operating normally</td>*") 
    {
        $_ -replace "<tr>", "<tr bgcolor=#CEF6CE>"
    }
    Else 
    {
        $_ -replace "<tr>", "<tr bgcolor=#F6CEE3>"
    }

$Output += " "
    
    $output += "<html>
    <body>
    <font size=""3"" face=""Arial,sans-serif"">
    <h3 align=""left"">Hyper-V Replica Info </h3>
    </font>"
    $output += $VMReplicaInfo |  ConvertTo-Html -Property VMName,Name,Snapshottype,Creationtime,ParentSnapshotName
    
}
    #endregion


#Generate the output file
Write-Verbose "Writing Output to File $OutPutFile"
$output | Out-File $OutPutFile -Force
$emailbody = get-content $OutPutFile -Raw

#Openfile with default handler if switch is present
Write-Verbose "Opening Outputfile $OutPutFile"
If ($OpenFileAfterCreation)
{
    Invoke-Item  $OutPutFile
}





$Username ="username"

$Password = ConvertTo-SecureString "Passwordgoeshere" -AsPlainText -Force

$credential = New-Object System.Management.Automation.PSCredential $Username, $Password

$SMTPServer = "smtp.sendgrid.net"

$EmailFrom = "Titan-Operations-No-Reply@blah.com"

$EmailTo = "blah@blah.com"

$Subject = "Titan - Storage Spaces Report"

#$Body = "SendGrid testing successful"

#Mail the Report
#If ($MailTo -and $MailFrom -and $MailServer)
#Fore Mail to go with Hard Coded Parameters for now
    Send-MailMessage -From $EmailFrom -To $EmailTo -SmtpServer $SMTPServer -Credential $credential -Port 587 -Subject "Storage Spaces Report: $StorageNode" -Encoding UTF8 -BodyAsHtml -Body $output


#Send-MailMessage -smtpServer $SMTPServer -Credential $credential -Port 587 -from $EmailFrom -to $EmailTo -subject $Subject -Body $emailbody -BodyAsHtml 





Write-Verbose "Report Created Successfully"