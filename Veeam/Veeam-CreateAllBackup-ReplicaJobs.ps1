<#
.SYNOPSIS
Builds Veeam Backup Jobs based on Platinum, Gold, and Silver Virtual Machines
.DESCRIPTION
.Param PlatinumJobs
Process all of the Hyper-V Virtual Machines with a prefix of Platinum-
.Param GoldJobs
Process all of the Hyper-V Virtual Machines with a prefix of Gold-
.Param SilverJobs
Process all of the Hyper-V Virtual Machines with a prefix of Silver-
.Param DeleteAllJobs
Removes all of the Platinum-,Gold-,and Silver-Jobs
.Param PlatinumReplicaJobs
Process all of the Hyper-V Virtual Machines with a prefix of Platinum-
.Param GoldReplicaJobs
Process all of the Hyper-V Virtual Machines with a prefix of Gold-
.Param SilverReplicaJobs
Process all of the Hyper-V Virtual Machines with a prefix of Silver-
.Param DeleteAllReplicaJobs
Removes all of the Platinum-,Gold-,and Silver-Jobs
.Param PlatinumBackupCopyJobs
Process all of the Hyper-V Virtual Machines with a prefix of Platinum-
.Param GoldBackupCopyJobs
Process all of the Hyper-V Virtual Machines with a prefix of Gold-
.Param SilverBackupCopyJobs
Process all of the Hyper-V Virtual Machines with a prefix of Silver-
.Param DeleteAllBackupCopyJobs
Removes all of the Platinum-,Gold-,and Silver-Jobs
.Param CreateVLAB
Creates the Virtual Lab required for SureBackup
.Param PlatinumSureBackupJobs
Creates all of the Platinum SureBackup Job
.Param DeleteAllSureBackupJobs
Deletes all of the SureBackup Jobs.
Create_All_VeeamBackup_Jobs.ps1
Creates all Veeam Backup Jobs - One for each of the Platinum, Gold, and Silver VM's
No Virtual Machines are processed unless the above parameters are set
.Example
VeeamSolution.ps1 -platinumjobs -goldjobs -silverjobs
Creates jobs for all of the Platinum Prefix, Gold Prefix, and Silver Prefix VM's
#>
<#
Version: 1.0.7
Date: 2015-05-24
Author: Dave Kawula MVP
Twitter: @DaveKawula
Revisions
============
2015-05-24  v1.0.0 Initial Release
2015-06-01  v1.0.1 Added Cleanup Parameter
2015-06-02  v1.0.2 Added Time OffSet to stagger Job Creation
2015-06-03  v1.0.3 Added Backup Copy Job Creation for Platinum,Gold,Silver + DeleteAll
2015-06-03  v1.0.4 Cleaned up output in the Script - check c:\programdata\veeam\powershell logs for full logging
2015-06-03  v1.0.5 Cleaned up some minor errors in code
2015-06-05  v1.0.6 Added VLAB Creation, SureBackup Platinum, and a Delete SureBackup 
2015-06-05  v1.0.7 Cleaned up some structure in the Script
#>

# Waits "x" Amount of Seconds and Displays a Progress Bar
Param (
    [switch]$PlatinumJobs = $false,[switch]$GoldJobs = $false,[switch]$SilverJobs = $false, [switch]$DeleteAllJobs = $false,[switch]$PlatinumReplicaJobs = $False,[switch]$GoldReplicaJobs = $False,[Switch]$SilverReplicaJobs = $False,[Switch]$DeleteAllReplicaJobs = $False,[Switch]$PlatinumBackupCopyJobs = $False,[Switch]$GoldBackupCopyJobs = $False,[Switch]$SilverBackupCopyJobs = $False,[Switch]$DeleteAllBackupCopyJobs = $False,[Switch]$CreateVLAB = $False,[Switch]$PlatinumSureBackupJobs = $False,[Switch]$DeleteAllSureBackupJobs = $False
    )
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

If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(` 
		[Security.Principal.WindowsBuiltInRole] "Administrator")) { 
	Write-Warning "Script must be executed in an elevated PowerShell process!"
	Write-Warning "Aborting script..." 
	Exit 1 
}


Write-Host 'About to build all of the jobs you can check c:\programdata\veeam\backup\VeeamPowerShell.log for output' -ForegroundColor Yellow
#Write-Host "Input the Name of the Hyper-V Host Server For Multiple Server's separate with a comma" -ForegroundColor Green
$VMHost = Read-Host "Enter the Hyper-V Host Server Name"
$VMHostServerSource = $VMHost
#Write-Host "Input the Name of the Veeam Repository you want to use * Wild Cards are accepted For exampe VeeamSR*" -ForegroundColor Green
$RepositoryName = Read-Host "Enter the Name of the Repository you want to use"
Asnp VeeamPSSnapin
$Date = Get-Date -format "MMM d yyyy"
$hour = 18
$minute = 05
$Description = "$_ backup job created by Dave Kawula on $Date"
$HVServer = Get-VBRServer -Name $VMHost
$HVMachinesPlatinum = Find-VBRHvEntity -Server $HVServer | ? {$_.name -like "Platinum*"}
$HVMachinesGold = Find-VBRHvEntity -Server $HVServer | ? {$_.name -like "Gold*"}
$HVMachinesSilver = Find-VBRHvEntity -Server $HVServer | ? {$_.name -like "Silver*"}
$Repository = Get-VBRBackupRepository -Name $RepositoryName

#Builds our Platinum Jobs for all VM's with a Prefix of -Platinum

if ($PlatinumJobs -eq $true)  {
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes",""
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No",""
    $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    $choice = $Host.UI.PromptForChoice("-=Build all Platinum Jobs=-", "Are you Sure you want to build all of the Veeam Platinum Jobs?", $choices, 1)
    if ($choice -eq 0) {
        Write-Host -ForegroundColor Green "Building all of the Platinum Jobs"}
      if ($Choice -eq 1) {
        Write-Warning "Aborting script..." 
	    Exit 1 }      
        
       
  
foreach ($HVMachine in $HVMachinesPlatinum){
  Write-Host 'Bulding Platinum Backup Job for' $HVMachine.Name -ForegroundColor Green
  $newjob = Add-VBRHvBackupJob -Entity $HVMachine -Name $HVMachine.Name -BackupRepository $Repository -Description $Description -ErrorAction SilentlyContinue 
  $template = Get-VBRJob | where {$_.name -eq 'Platinum_Template'}
  $templateoptions = Get-VBRJobOptions $template
  $templateoptionsvss = Get-VBRJobVSSOptions $template
  $templateoptionssched = Get-VBRJobScheduleOptions $template

 Write-Host 'Configuring Settings for Platinum Job on' $HVMachine.Name -ForegroundColor Green
  Set-VBRJobOptions -job $newjob -options $templateoptions -ErrorAction SilentlyContinue | Out-Null
  Set-VBRJobVSSOptions -job $newjob -options $templateoptionsvss -ErrorAction SilentlyContinue | Out-Null
    # Set the job schedule and increment by 5 minutes
    $ScheduleOptions = New-VBRJobScheduleOptions
    #$ScheduleOptions.OptionsContinuous.Enabled = $False
    #$ScheduleOptions.OptionsMonthly.Enabled = $False
    #$ScheduleOptions.OptionsScheduleAfterJob.IsEnabled = $False
    #$ScheduleOptions.OptionsPeriodically.Enabled = $False
  

    IF ($minute -gt 55) 
    {
    $hour += 1
    $minute = 00
    }
    IF ($hour -gt 23)
    {
    $hour = 00
    }

    ELSE 
    {
    $Date = Get-Date -Hour $hour -Minute $minute
    $minute += 5
    }

    $ScheduleOptions.StartDateTime = $Date
    $ScheduleOptions.OptionsDaily.Enabled = $True
    $ScheduleOptions.OptionsDaily.Kind = "Everyday"
    $ScheduleOptions.OptionsDaily.Time = $Date
 

    # Apply the schedule
    Write-Host 'Configuring the Schedule Options on Platinum Job for' $HVMachine.Name $Date -ForegroundColor Green
    Set-VBRJobScheduleOptions -Job $NewJob -Options $ScheduleOptions -ErrorAction SilentlyContinue | Out-Null

    # Disable the job because we don't want things taking off on their own yet
    Write-Host 'Disabling the Job' $HVMachine.Name -ForegroundColor Green
    Disable-VBRJob -Job $HVMachine.Name -ErrorAction SilentlyContinue |Out-Null

    
    }
    }


#Builds our Platinum Jobs for all VM's with a Prefix of -Gold

    if ($GoldJobs -eq $true)  {
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes",""
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No",""
    $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    $choice = $Host.UI.PromptForChoice("-=Build all Gold Jobs=-", "Are you Sure you want to build all of the Veeam Gold Jobs?", $choices, 1)
    if ($choice -eq 0) {
        Write-Host -ForegroundColor Green "Building all of the Gold Jobs"}
    if ($Choice -eq 1) {
        Write-Warning "Aborting script..." 
	    Exit 1 }
        
       
  
foreach ($HVMachine in $HVMachinesGold){
  Write-Host 'Building Gold Backup Jobs for' $HVMachine.Name -ForegroundColor Green
  $newjob = Add-VBRHvBackupJob -Entity $HVMachine -Name $HVMachine.Name -BackupRepository $Repository -Description $Description -ErrorAction SilentlyContinue
  $template = Get-VBRJob | where {$_.name -eq "Gold_Template"}
  $templateoptions = Get-VBRJobOptions $template
  $templateoptionsvss = Get-VBRJobVSSOptions $template
  $templateoptionssched = Get-VBRJobScheduleOptions $template

  Write-Host 'Configuring the Gold Job Settings on' $HVMachine.Name -ForegroundColor Green
  Set-VBRJobOptions -job $newjob -options $templateoptions -ErrorAction SilentlyContinue | Out-Null
  Set-VBRJobVSSOptions -job $newjob -options $templateoptionsvss -ErrorAction SilentlyContinue | Out-Null
    # Set the job schedule and increment by 5 minutes
    $ScheduleOptions = New-VBRJobScheduleOptions
    #$ScheduleOptions.OptionsContinuous.Enabled = $False
    #$ScheduleOptions.OptionsMonthly.Enabled = $False
    #$ScheduleOptions.OptionsScheduleAfterJob.IsEnabled = $False
    #$ScheduleOptions.OptionsPeriodically.Enabled = $False
  

    IF ($minute -gt 55) 
    {
    $hour += 1
    $minute = 00
    }
    IF ($hour -gt 23)
    {
    $hour = 00
    }

    ELSE 
    {
    $Date = Get-Date -Hour $hour -Minute $minute
    $minute += 5
    }

    $ScheduleOptions.StartDateTime = $Date
    $ScheduleOptions.OptionsDaily.Enabled = $True
    $ScheduleOptions.OptionsDaily.Kind = "Everyday"
    $ScheduleOptions.OptionsDaily.Time = $Date
 

    # Apply the schedule
    Write-Host 'Configuring the Schedule on Gold Backup Job' $HVMachine.Name $Date -ForegroundColor Green
    Set-VBRJobScheduleOptions -Job $NewJob -Options $ScheduleOptions -ErrorAction SilentlyContinue |Out-Null

    # Disable the job because we don't want things taking off on their own yet
    Write-Host 'Disabling the Job' $HVMachine.Name -ForegroundColor Green
    Disable-VBRJob -Job $HVMachine.Name -ErrorAction SilentlyContinue | Out-Null
    
    }
    }


#Builds our Platinum Jobs for all VM's with a Prefix of -Silver
    
    if ($SilverJobs -eq $true)  {
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes",""
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No",""
    $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    $choice = $Host.UI.PromptForChoice("-=Build all Silver Jobs=-", "Are you Sure you want to build all of the Veeam Silver Jobs?", $choices, 1)
    if ($choice -eq 0) {
        Write-Host -ForegroundColor Green "Building all of the Silver Jobs"}
    if ($Choice -eq 1) {
        Write-Warning "Aborting script..." 
	    Exit 1 }   
        
       

foreach ($HVMachine in $HVMachinesSilver){
  Write-Host 'Building Silver Backup Jobs for' $HVMachine.Name -ForegroundColor Green
  $newjob = Add-VBRHvBackupJob -Entity $HVMachine -Name $HVMachine.Name -BackupRepository $Repository -Description $Description -ErrorAction SilentlyContinue
  $template = Get-VBRJob | where {$_.name -eq "Silver_Template"}
  $templateoptions = Get-VBRJobOptions $template
  $templateoptionsvss = Get-VBRJobVSSOptions $template
  $templateoptionssched = Get-VBRJobScheduleOptions $template

  Write-Host 'Configuring Silver Backup Job Options on' $HVMachine.Name -ForegroundColor Green
  Set-VBRJobOptions -job $newjob -options $templateoptions -ErrorAction SilentlyContinue | Out-Null
  Set-VBRJobVSSOptions -job $newjob -options $templateoptionsvss -ErrorAction SilentlyContinue | Out-Null
    # Set the job schedule and increment by 5 minutes
    $ScheduleOptions = New-VBRJobScheduleOptions
    #$ScheduleOptions.OptionsContinuous.Enabled = $False
    #$ScheduleOptions.OptionsMonthly.Enabled = $False
    #$ScheduleOptions.OptionsScheduleAfterJob.IsEnabled = $False
    #$ScheduleOptions.OptionsPeriodically.Enabled = $False
  

    IF ($minute -gt 55) 
    {
    $hour += 1
    $minute = 00
    }
    IF ($hour -gt 23)
    {
    $hour = 00
    }

    ELSE 
    {
    $Date = Get-Date -Hour $hour -Minute $minute
    $minute += 5
    }

    $ScheduleOptions.StartDateTime = $Date
    $ScheduleOptions.OptionsDaily.Enabled = $True
    $ScheduleOptions.OptionsDaily.Kind = "Everyday"
    $ScheduleOptions.OptionsDaily.Time = $Date
 

    # Apply the schedule
    Write-Host 'Configuring the Silver Backup Jobs Schedule Options for' $HVMachine.Name $Date -ForegroundColor Green
    Set-VBRJobScheduleOptions -Job $NewJob -Options $ScheduleOptions -ErrorAction SilentlyContinue |Out-Null

    # Disable the job because we don't want things taking off on their own yet
    
    Write-Host 'Disabling the Job for' $HVmachine.Name -ForegroundColor Green
    Disable-VBRJob -Job $HVMachine.Name -ErrorAction SilentlyContinue | Out-Null
  
    
    }
    }

#Cleans up all of the Jobs Created for Platinum, Gold, and Silver
    
    if ($DeleteAllJobs -eq $true)  {
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes",""
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No",""
    $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    $choice = $Host.UI.PromptForChoice("-=Delete All Platinum,Gold, and Silver Jobs=-", "Are you Sure you want to Remove all of the Platinum,Gold, and Silver Jobs?", $choices, 1)
    if ($choice -eq 0) {
        Write-Host -ForegroundColor RED "Deleting All of Backup the Jobs -"}
    if ($Choice -eq 1) {
        Write-Warning "Aborting script..." 
	    Exit 1 }
    
    Write-Host 'Removing All Platinum- Jobs' -ForegroundColor Red
    Get-vbrjob -name 'platinum-*' | remove-vbrjob -confirm:$false -ErrorAction SilentlyContinue | Out-Null
    Write-Host 'Removing All Gold- Jobs' -ForegroundColor Red
    Get-vbrjob -name 'Gold-*' | remove-vbrjob -confirm:$false -ErrorAction SilentlyContinue | Out-Null
    Write-Host 'Removing All Silver- Jobs' -ForegroundColor Red
    Get-vbrjob -name 'Silver-*' | remove-vbrjob -confirm:$False -ErrorAction SilentlyContinue |out-null
    }



#########################
#Creation of Veeam Replica Jobs
#Need to designate the Veeam Replica ServerName Target and Target Repository to Run this


#Builds our Platinum Replica Jobs for all VM's with a Prefix of -Platinum

if ($PlatinumReplicaJobs -eq $true)  {
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes",""
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No",""
    $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    $choice = $Host.UI.PromptForChoice("-=Platinum Replica Jobs=-", "Are you Sure you want to Create the Platinum Replica Jobs?", $choices, 1)
    if ($choice -eq 0) {
        Write-Host -ForegroundColor Green "Building Platinum Replica Jobs"}
    if ($Choice -eq 1) {
        Write-Warning "Aborting script..." 
	    Exit 1 }


$VMHostServerSource = Read-Host "Type the Name of the Source Hyper-V Host"
$VMHostReplicaTarget = Read-Host "Type the Name of the Target Hyper-V Host"
$VMHostReplicaVolume = Read-Host "Type the Volume that you would like the Replica's Stored on ex. f:\Replicas"
$HVMachinesReplicaPlatinum = (Find-VBRHvEntity | Select-Object -Skip 1) | where {$_.type -eq "VM"} | where {$_.VMHostName -eq $VMHostServerSource} | where {$_.name -like 'Platinum-*'}
$HVMachinesReplicaGold = (Find-VBRHvEntity | Select-Object -Skip 1) | where {$_.type -eq "VM"} | where {$_.VMHostName -eq $VMHostServerSource} | where {$_.name -like 'Gold-*'}
$HVMachinesReplicaSilver = (Find-VBRHvEntity | Select-Object -Skip 1) | where {$_.type -eq "VM"} | where {$_.VMHostName -eq $VMHostServerSource} | where {$_.name -like 'Silver-*'}
#$Repository = Get-VBRBackupRepository -Name $RepositoryName

foreach ($HVMachine in $HVMachinesReplicaPlatinum){




#$AllProtectedVMs = (Find-VBRHvEntity | Select-Object -Skip 1) | where {$_.type -eq "VM"} | where {$_.VMHostName -eq $VMHostServerSource} | where {$_.name -like 'Platinum-*'}

#$AllProtectedVMs | select Name,path,VMHostName,PowerState,ProvisionedSize,UsedSize | out-gridview
Write-Host 'Building new Platium Replica Job for' $HVMachine.Name -ForegroundColor Green
$newJob = Add-VBRHvReplicaJob -Entity $HVMachine -Name ('Replica-' + $HVMachine.name).ToString() -Server $VMHostReplicaTarget.ToString() -Suffix "_replica" -path $VMHostReplicaVolume.ToString() -ErrorAction SilentlyContinue

$template = Get-VBRJob | where {$_.name -eq "Platinum_Replica_Template"}
  $templateoptions = Get-VBRJobOptions $template
  $templateoptionsvss = Get-VBRJobVSSOptions $template
  #$templateoptionssched = Get-VBRJobScheduleOptions $template
  Write-Host 'Configuring Settings for Platium Replica Job on' $HVMachine.Name -ForegroundColor Green
  Set-VBRJobOptions -job $newjob -options $templateoptions -ErrorAction SilentlyContinue | Out-Null
  Set-VBRJobVSSOptions -job $newjob -options $templateoptionsvss -ErrorAction SilentlyContinue | Out-Null

  
  
  # Apply the job options
    #$NewJob = Get-VBRJob -name $HVmachine.Name
    #$NewJob.SetOptions($Options)

    # Apply the VSS Settings
    #$NewJob | Set-VBRJobVssOptions -Options $vssoptions   
    #$NewJob | Set-VBRJobVssOptions -Credentials "TriCon\dkawula_1"

    # Set the job schedule and increment by 5 minutes
    $ScheduleOptions = New-VBRJobScheduleOptions
    #$ScheduleOptions.OptionsContinuous.Enabled = $False
    #$ScheduleOptions.OptionsMonthly.Enabled = $False
    #$ScheduleOptions.OptionsScheduleAfterJob.IsEnabled = $False
    #$ScheduleOptions.OptionsPeriodically.Enabled = $False

    IF ($minute -gt 55) 
    {
    $hour += 1
    $minute = 00
    }
    IF ($hour -gt 23)
    {
    $hour = 00
    }

    ELSE 
    {
    $Date = Get-Date -Hour $hour -Minute $minute
    $minute += 5
    }

    $ScheduleOptions.StartDateTime = $Date
    $ScheduleOptions.OptionsDaily.Enabled = $True
    $ScheduleOptions.OptionsDaily.Kind = "Everyday"
    $ScheduleOptions.OptionsDaily.Time = $Date
   # $Options = $Job.GetOptions()
    #$Options.JobOptions.RunManually = $False
    #$Job.SetOptions($Options)

    # Apply the schedule
   
   Write-Host 'Configuring the Platinum Replica Job Schedule for' $HVMachine.Name $Date -ForegroundColor Green
    Set-VBRJobScheduleOptions -Job $NewJob -Options $ScheduleOptions -ErrorAction SilentlyContinue | Out-Null

    # Disable the job because we don't want things taking off on their own yet
   Write-Host 'Disabling Platium Replica Jobs for' $HVMachine.Name -ForegroundColor Green
   Disable-VBRJob -Job ('Replica-' + $HVMachine.Name).ToString() -ErrorAction SilentlyContinue | Out-Null




    }
    }


#Builds our Platinum Replica Jobs for all VM's with a Prefix of -Gold

if ($GoldReplicaJobs -eq $true)  {
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes",""
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No",""
    $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    $choice = $Host.UI.PromptForChoice("-=Gold Replica Jobs=-", "Are you Sure you want to Create the Gold Replica Jobs?", $choices, 1)
    if ($choice -eq 0) {
        Write-Host -ForegroundColor Green "Building Gold Replica Jobs"}
    if ($Choice -eq 1) {
        Write-Warning "Aborting script..." 
	    Exit 1 }


$VMHostServerSource = Read-Host "Type the Name of the Source Hyper-V Host"
$VMHostReplicaTarget = Read-Host "Type the Name of the Target Hyper-V Host"
$VMHostReplicaVolume = Read-Host "Type the Volume that you would like the Replica's Stored on ex. f:\Replicas"
$HVMachinesReplicaPlatinum = (Find-VBRHvEntity | Select-Object -Skip 1) | where {$_.type -eq "VM"} | where {$_.VMHostName -eq $VMHostServerSource} | where {$_.name -like 'Platinum-*'}
$HVMachinesReplicaGold = (Find-VBRHvEntity | Select-Object -Skip 1) | where {$_.type -eq "VM"} | where {$_.VMHostName -eq $VMHostServerSource} | where {$_.name -like 'Gold-*'}
$HVMachinesReplicaSilver = (Find-VBRHvEntity | Select-Object -Skip 1) | where {$_.type -eq "VM"} | where {$_.VMHostName -eq $VMHostServerSource} | where {$_.name -like 'Silver-*'}
#$Repository = Get-VBRBackupRepository -Name $RepositoryName

foreach ($HVMachine in $HVMachinesReplicaGold){




#$AllProtectedVMs = (Find-VBRHvEntity | Select-Object -Skip 1) | where {$_.type -eq "VM"} | where {$_.VMHostName -eq $VMHostServerSource} | where {$_.name -like 'Platinum-*'}

#$AllProtectedVMs | select Name,path,VMHostName,PowerState,ProvisionedSize,UsedSize | out-gridview
Write-Host 'Building Gold Replica Job for' $HVMachine.Name -ForegroundColor Green
$newJob = Add-VBRHvReplicaJob -Entity $HVMachine -Name ('Replica-' + $HVMachine.name).ToString() -Server $VMHostReplicaTarget.ToString() -Suffix "_replica" -path $VMHostReplicaVolume.ToString() -ErrorAction SilentlyContinue

$template = Get-VBRJob | where {$_.name -eq "Gold_Replica_Template"}
  $templateoptions = Get-VBRJobOptions $template
  $templateoptionsvss = Get-VBRJobVSSOptions $template
  #$templateoptionssched = Get-VBRJobScheduleOptions $template
  Write-Host 'Configuring Settings for Gold Replica Jobs for' $HVMachine.Name -ForegroundColor Green
  Set-VBRJobOptions -job $newjob -options $templateoptions -ErrorAction SilentlyContinue | Out-Null
  Set-VBRJobVSSOptions -job $newjob -options $templateoptionsvss -ErrorAction SilentlyContinue | Out-Null

  
  
  # Apply the job options
    #$NewJob = Get-VBRJob -name $HVmachine.Name
    #$NewJob.SetOptions($Options)

    # Apply the VSS Settings
    #$NewJob | Set-VBRJobVssOptions -Options $vssoptions   
    #$NewJob | Set-VBRJobVssOptions -Credentials "TriCon\dkawula_1"

    # Set the job schedule and increment by 5 minutes
    $ScheduleOptions = New-VBRJobScheduleOptions
    #$ScheduleOptions.OptionsContinuous.Enabled = $False
    #$ScheduleOptions.OptionsMonthly.Enabled = $False
    #$ScheduleOptions.OptionsScheduleAfterJob.IsEnabled = $False
    #$ScheduleOptions.OptionsPeriodically.Enabled = $False

    IF ($minute -gt 55) 
    {
    $hour += 1
    $minute = 00
    }
    IF ($hour -gt 23)
    {
    $hour = 00
    }

    ELSE 
    {
    $Date = Get-Date -Hour $hour -Minute $minute
    $minute += 5
    }

    $ScheduleOptions.StartDateTime = $Date
    $ScheduleOptions.OptionsDaily.Enabled = $True
    $ScheduleOptions.OptionsDaily.Kind = "Everyday"
    $ScheduleOptions.OptionsDaily.Time = $Date
   # $Options = $Job.GetOptions()
    #$Options.JobOptions.RunManually = $False
    #$Job.SetOptions($Options)

    # Apply the schedule
    Write-Host 'Applying Schule options for Gold Replica Job on' $HVMachine.Name $Date -ForegroundColor Green
    Set-VBRJobScheduleOptions -Job $NewJob -Options $ScheduleOptions -ErrorAction SilentlyContinue | Out-Null

    # Disable the job because we don't want things taking off on their own yet
   Write-Host 'Disabling the Gold Replica Jobs for' $HVMachine.Name -ForegroundColor Green
   Disable-VBRJob -Job ('Replica-' + $HVMachine.Name).ToString() -ErrorAction SilentlyContinue | Out-Null




    }
    }


#Builds our Platinum Replica Jobs for all VM's with a Prefix of -Silver

if ($SilverReplicaJobs -eq $true)  {
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes",""
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No",""
    $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    $choice = $Host.UI.PromptForChoice("-=Silver Replica Jobs=-", "Are you Sure you want to Create the Silver Replica Jobs?", $choices, 1)
    if ($choice -eq 0) {
        Write-Host -ForegroundColor Green "Building Silver Replica Jobs"}
    if ($Choice -eq 1) {
        Write-Warning "Aborting script..." 
	    Exit 1 }


$VMHostServerSource = Read-Host "Type the Name of the Source Hyper-V Host"
$VMHostReplicaTarget = Read-Host "Type the Name of the Target Hyper-V Host"
$VMHostReplicaVolume = Read-Host "Type the Volume that you would like the Replica's Stored on ex. f:\Replicas"
$HVMachinesReplicaPlatinum = (Find-VBRHvEntity | Select-Object -Skip 1) | where {$_.type -eq "VM"} | where {$_.VMHostName -eq $VMHostServerSource} | where {$_.name -like 'Platinum-*'}
$HVMachinesReplicaGold = (Find-VBRHvEntity | Select-Object -Skip 1) | where {$_.type -eq "VM"} | where {$_.VMHostName -eq $VMHostServerSource} | where {$_.name -like 'Gold-*'}
$HVMachinesReplicaSilver = (Find-VBRHvEntity | Select-Object -Skip 1) | where {$_.type -eq "VM"} | where {$_.VMHostName -eq $VMHostServerSource} | where {$_.name -like 'Silver-*'}
#$Repository = Get-VBRBackupRepository -Name $RepositoryName

foreach ($HVMachine in $HVMachinesReplicaSilver){




#$AllProtectedVMs = (Find-VBRHvEntity | Select-Object -Skip 1) | where {$_.type -eq "VM"} | where {$_.VMHostName -eq $VMHostServerSource} | where {$_.name -like 'Platinum-*'}

#$AllProtectedVMs | select Name,path,VMHostName,PowerState,ProvisionedSize,UsedSize | out-gridview
Write-Host 'Building Silver Replica Jobs for' $HVMachine.Name -ForegroundColor Green
$newJob = Add-VBRHvReplicaJob -Entity $HVMachine -Name ('Replica-' + $HVMachine.name).ToString() -Server $VMHostReplicaTarget.ToString() -Suffix "_replica" -path $VMHostReplicaVolume.ToString() -ErrorAction SilentlyContinue

$template = Get-VBRJob | where {$_.name -eq "Silver_Replica_Template"}
  $templateoptions = Get-VBRJobOptions $template
  $templateoptionsvss = Get-VBRJobVSSOptions $template
  #$templateoptionssched = Get-VBRJobScheduleOptions $template
  Write-Host 'Configuring Settings for Silver Replica Job on' $HVMachine.Name -ForegroundColor Green
  Set-VBRJobOptions -job $newjob -options $templateoptions -ErrorAction SilentlyContinue |Out-Null
  Set-VBRJobVSSOptions -job $newjob -options $templateoptionsvss -ErrorAction SilentlyContinue |Out-Null

  
  
  # Apply the job options
    #$NewJob = Get-VBRJob -name $HVmachine.Name
    #$NewJob.SetOptions($Options)

    # Apply the VSS Settings
    #$NewJob | Set-VBRJobVssOptions -Options $vssoptions   
    #$NewJob | Set-VBRJobVssOptions -Credentials "TriCon\dkawula_1"

    # Set the job schedule and increment by 5 minutes
    $ScheduleOptions = New-VBRJobScheduleOptions
    #$ScheduleOptions.OptionsContinuous.Enabled = $False
    #$ScheduleOptions.OptionsMonthly.Enabled = $False
    #$ScheduleOptions.OptionsScheduleAfterJob.IsEnabled = $False
    #$ScheduleOptions.OptionsPeriodically.Enabled = $False

    IF ($minute -gt 55) 
    {
    $hour += 1
    $minute = 00
    }
    IF ($hour -gt 23)
    {
    $hour = 00
    }

    ELSE 
    {
    $Date = Get-Date -Hour $hour -Minute $minute
    $minute += 5
    }

    $ScheduleOptions.StartDateTime = $Date
    $ScheduleOptions.OptionsDaily.Enabled = $True
    $ScheduleOptions.OptionsDaily.Kind = "Everyday"
    $ScheduleOptions.OptionsDaily.Time = $Date
   # $Options = $Job.GetOptions()
    #$Options.JobOptions.RunManually = $False
    #$Job.SetOptions($Options)

    # Apply the schedule
    Write-Host 'Applying Schedule to Job for' $HVMachine.Name 'set to' $Date -ForegroundColor Green
    Set-VBRJobScheduleOptions -Job $NewJob -Options $ScheduleOptions -ErrorAction SilentlyContinue | Out-Null

    # Disable the job because we don't want things taking off on their own yet
   Write-Host 'Disabling the Replica job for' $hvmachine.Name -ForegroundColor Green
   Disable-VBRJob -Job ('Replica-' + $HVMachine.Name).ToString() -ErrorAction SilentlyContinue |Out-Null




    }
    }

#Deletes all of the Replica Jobs for Platinum, Gold, and Silver
if ($DeleteAllReplicaJobs -eq $true)  {
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes",""
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No",""
    $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    $choice = $Host.UI.PromptForChoice("-=Delete All Platinum,Gold, and Silver Jobs=-", "Are you Sure you want to Remove all of the Platinum,Gold, and Silver Jobs?", $choices, 1)
    if ($choice -eq 0) {
        Write-Host -ForegroundColor RED "Deleting All of Replica the Jobs -"}
    if ($Choice -eq 1) {
        Write-Warning "Aborting script..." 
	    Exit 1 }
    
    Write-Host 'Removing All Platinum- Jobs' -ForegroundColor Red
    Get-vbrjob -name 'replica-platinum-*' | remove-vbrjob -ErrorAction SilentlyContinue -confirm:$False |Out-Null
    Write-Host 'Removing All Gold- Jobs' -ForegroundColor Red 
    Get-vbrjob -name 'replica-Gold-*' | remove-vbrjob -ErrorAction SilentlyContinue -confirm:$False |Out-Null
    Write-Host 'Removing All Silver- Jobs' -ForegroundColor Red
    Get-vbrjob -name 'replica-Silver-*' | remove-vbrjob -ErrorAction SilentlyContinue -confirm:$False |Out-Null
    }

 
#Builds our Platinum Backup Copy Jobs for all VM's with a Prefix of -Platinum
if ($PlatinumBackupCopyJobs -eq $true)  {
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes",""
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No",""
    $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    $choice = $Host.UI.PromptForChoice("-=Platinum Backup Copy Jobs=-", "Are you Sure you want to Create the Platinum Backup Copy Jobs?", $choices, 1)
    if ($choice -eq 0) {
        Write-Host -ForegroundColor Green "Building Platinum Backup Copy Jobs"}
    if ($Choice -eq 1) {
        Write-Warning "Aborting script..." 
	    Exit 1 }

$Tier1RepositoryName = Read-Host "Type the Name of the Veeam Repository that will Store the Tier 1 Data ex VeeamSR*"
$Tier2RepositoryName = Read-Host "Type the Name of the Veeam Repository that will store the Tier 2 Data ex DRVeeamSR*"
$Tier3RepositoryName = Read-Host "Type the Name of the Veeam Repository that will store the Tier 3 Data ex AzureVeeamSR*"
$WanAccelSourceName = Read-Host "Type the Name of the Source Wan Accerator"
$WanAccelTargetTier2Name = Read-Host "Type the Name of the Target Wan Accelerator Tier 2"
$WanAccelTargetTier3Name = Read-Host "Type the Name of the Target Wan Accelerator Tier 3 Azure"

$HVMachinesReplicaPlatinum = (Find-VBRHvEntity | Select-Object -Skip 1) | where {$_.type -eq "VM"} | where {$_.VMHostName -eq $VMHostServerSource} | where {$_.name -like 'Platinum-*'}
$HVMachinesReplicaGold = (Find-VBRHvEntity | Select-Object -Skip 1) | where {$_.type -eq "VM"} | where {$_.VMHostName -eq $VMHostServerSource} | where {$_.name -like 'Gold-*'}
$HVMachinesReplicaSilver = (Find-VBRHvEntity | Select-Object -Skip 1) | where {$_.type -eq "VM"} | where {$_.VMHostName -eq $VMHostServerSource} | where {$_.name -like 'Silver-*'}
#$VeeamServer = (Get-VBRServer -name $VS | select-object -Skip 1)
#$VeeamServer1 = (Get-VBRServer -name $VS1 | select-object -Skip 1)
#$VeeamServer2 = (Get-VBRServer -Name $VS2 | select-object -Skip 1)
$Tier1Repository = Get-VBRBackupRepository -Name $Tier1RepositoryName
$Tier2Repository = Get-VBRBackupRepository -Name $Tier2RepositoryName
$Tier3Repository = Get-VBRBackupRepository -Name $Tier3RepositoryName
$WanAccelSource = Get-VBRWANAccelerator -name $WanAccelSourceName
$WanAccelTargetTier2 = Get-VBRWANAccelerator -Name $WanAccelTargetTier2Name
$WanAccelTargetTier3 = Get-VBRWANAccelerator -Name $WanAccelTargetTier3Name

foreach ($HVMachine in $HVMachinesReplicaPlatinum){

Write-Host 'Building Tier 1 Platinum Jobs for' $HVMachine.Name -ForegroundColor Green
  $newjob1 = Add-VBRHvBackupCopyJob -BackupJob ($HVMachine.Name).ToString() -Name ('Tier1-' + $HVMachine.Name).ToString() -DirectOperation -Repository $Tier1Repository
Write-Host 'Building Tier 2 Platinum Jobs for' $HVMachine.Name -ForegroundColor Green
  $newjob2 = Add-VBRHvBackupCopyJob -BackupJob ($HVMachine.Name).ToString() -Name ('Tier2-' + $HVMachine.Name).ToString() -SourceAccelerator $WanAccelSource -TargetAccelerator $WanAccelTargetTier2 -Repository $Tier2Repository
Write-Host 'Building Tier 3 Platinum Jobs for' $HVMachine.Name -ForegroundColor Green
  $newjob3 = Add-VBRHvBackupCopyJob -BackupJob ($HVMachine.Name).ToString() -Name ('Tier3-' + $HVMachine.Name).ToString() -SourceAccelerator $WanAccelSource -TargetAccelerator $WanAccelTargetTier3 -Repository $Tier3Repository

  $template = Get-VBRJob | where {$_.name -eq "BCJ-Platinum_Template-Tier1"}
  $templateoptions = Get-VBRJobOptions $template
  $templateoptionsvss = Get-VBRJobVSSOptions $template
  $template2 = Get-VBRJob | where {$_.name -eq "BCJ-Platinum_Template-Tier2"}
  $templateoptions2 = Get-VBRJobOptions $template2
  $templateoptionsvss2 = Get-VBRJobVSSOptions $template2
  $template3 = Get-VBRJob | where {$_.name -eq "BCJ-Platinum_Template-Tier3"}
  $templateoptions3 = Get-VBRJobOptions $template3
  $templateoptionsvss3 = Get-VBRJobVSSOptions $template3


  #$templateoptionssched = Get-VBRJobScheduleOptions $template
  Write-Host 'Configuring Settings for Tier 1 Platinum Jobs for' $HVMachine.Name -ForegroundColor Green
  Set-VBRJobOptions -job $newjob1 -options $templateoptions -ErrorAction SilentlyContinue | out-null
  Set-VBRJobVSSOptions -job $newjob1 -options $templateoptionsvss -ErrorAction SilentlyContinue | Out-Null
  Write-Host 'Configuring Settings for Tier 2 Platinum Jobs for' $HVMachine.Name -ForegroundColor Green
    Set-VBRJobOptions -job $newjob2 -options $templateoptions2 -ErrorAction SilentlyContinue | Out-Null
  Set-VBRJobVSSOptions -job $newjob2 -options $templateoptionsvss2 -ErrorAction SilentlyContinue |Out-Null
  Write-Host 'Configuring Settings for Tier 3 Platinum Jobs for' $HVMachine.Name -ForegroundColor Green
    Set-VBRJobOptions -job $newjob3 -options $templateoptions3 -ErrorAction SilentlyContinue | Out-Null
  Set-VBRJobVSSOptions -job $newjob3 -options $templateoptionsvss3 -ErrorAction SilentlyContinue | Out-Null
    # Set the job schedule and increment by 5 minutes
    $ScheduleOptions = New-VBRJobScheduleOptions
   
    IF ($minute -gt 55) 
    {
    $hour += 1
    $minute = 00
    }
    IF ($hour -gt 23)
    {
    $hour = 00
    }

    ELSE 
    {
    $Date = Get-Date -Hour $hour -Minute $minute
    $minute += 5
    }

    $ScheduleOptions.StartDateTime = $Date
    $ScheduleOptions.OptionsDaily.Enabled = $True
    $ScheduleOptions.OptionsDaily.Kind = "Everyday"
    $ScheduleOptions.OptionsDaily.Time = $Date
  
    # Apply the schedule
    Write-Host 'Configuring Schedule for Tier 1 Backup Job for' $hvmachine.name 'at' $Date -ForegroundColor Green
    Set-VBRJobScheduleOptions -Job $NewJob1 -Options $ScheduleOptions -ErrorAction SilentlyContinue | Out-Null

    # Loop for Tier 2 Jobs
    $ScheduleOptions = New-VBRJobScheduleOptions
    
    IF ($minute -gt 55) 
    {
    $hour += 1
    $minute = 00
    }
    IF ($hour -gt 23)
    {
    $hour = 00
    }

    ELSE 
    {
    $Date = Get-Date -Hour $hour -Minute $minute
    $minute += 5
    }

    $ScheduleOptions.StartDateTime = $Date
    $ScheduleOptions.OptionsDaily.Enabled = $True
    $ScheduleOptions.OptionsDaily.Kind = "Everyday"
    $ScheduleOptions.OptionsDaily.Time = $Date
    # Apply the schedule
    Write-Host "Configuring Schedule for Tier 2 Backup Job for" $hvmachine.name 'at' $Date -ForegroundColor Green
    Set-VBRJobScheduleOptions -Job $NewJob2 -Options $ScheduleOptions -ErrorAction SilentlyContinue | Out-Null

   #Loop for Tier 3 Jobs
    $ScheduleOptions = New-VBRJobScheduleOptions
    
    IF ($minute -gt 55) 
    {
    $hour += 1
    $minute = 00
    }
    IF ($hour -gt 23)
    {
    $hour = 00
    }

    ELSE 
    {
    $Date = Get-Date -Hour $hour -Minute $minute
    $minute += 5
    }

    $ScheduleOptions.StartDateTime = $Date
    $ScheduleOptions.OptionsDaily.Enabled = $True
    $ScheduleOptions.OptionsDaily.Kind = "Everyday"
    $ScheduleOptions.OptionsDaily.Time = $Date
   
    # Apply the schedule
    Write-Host "Configuring Schedule for Tier 3 Backup Job for" $hvmachine.name 'at' $Date -ForegroundColor Green
    Set-VBRJobScheduleOptions -Job $NewJob3 -Options $ScheduleOptions -ErrorAction SilentlyContinue | out-null

    

    }
    }


#Builds our Gold Backup Copy Jobs for all VM's with a Prefix of -Gold
if ($GoldBackupCopyJobs -eq $true) {
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes",""
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No",""
    $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    $choice = $Host.UI.PromptForChoice("-=Gold Backup Copy Jobs=-", "Are you Sure you want to Create the Gold Backup Copy Jobs?", $choices, 1)
    if ($choice -eq 0) {
        Write-Host -ForegroundColor Green "Building Gold Backup Copy Jobs"}
    if ($Choice -eq 1) {
        Write-Warning "Aborting script..." 
	    Exit 1 }

$Tier1RepositoryName = Read-Host "Type the Name of the Veeam Repository that will Store the Tier 1 Data ex VeeamSR*"
$Tier2RepositoryName = Read-Host "Type the Name of the Veeam Repository that will store the Tier 2 Data ex DRVeeamSR*"
$Tier3RepositoryName = Read-Host "Type the Name of the Veeam Repository that will store the Tier 3 Data ex AzureVeeamSR*"
$WanAccelSourceName = Read-Host "Type the Name of the Source Wan Accerator"
$WanAccelTargetTier2Name = Read-Host "Type the Name of the Target Wan Accelerator Tier 2"
$WanAccelTargetTier3Name = Read-Host "Type the Name of the Target Wan Accelerator Tier 3 Azure"

$HVMachinesReplicaPlatinum = (Find-VBRHvEntity | Select-Object -Skip 1) | where {$_.type -eq "VM"} | where {$_.VMHostName -eq $VMHostServerSource} | where {$_.name -like 'Platinum-*'}
$HVMachinesReplicaGold = (Find-VBRHvEntity | Select-Object -Skip 1) | where {$_.type -eq "VM"} | where {$_.VMHostName -eq $VMHostServerSource} | where {$_.name -like 'Gold-*'}
$HVMachinesReplicaSilver = (Find-VBRHvEntity | Select-Object -Skip 1) | where {$_.type -eq "VM"} | where {$_.VMHostName -eq $VMHostServerSource} | where {$_.name -like 'Silver-*'}
#$VeeamServer = (Get-VBRServer -name $VS | select-object -Skip 1)
#$VeeamServer1 = (Get-VBRServer -name $VS1 | select-object -Skip 1)
#$VeeamServer2 = (Get-VBRServer -Name $VS2 | select-object -Skip 1)
$Tier1Repository = Get-VBRBackupRepository -Name $Tier1RepositoryName
$Tier2Repository = Get-VBRBackupRepository -Name $Tier2RepositoryName
$Tier3Repository = Get-VBRBackupRepository -Name $Tier3RepositoryName
$WanAccelSource = Get-VBRWANAccelerator -name $WanAccelSourceName
$WanAccelTargetTier2 = Get-VBRWANAccelerator -Name $WanAccelTargetTier2Name
$WanAccelTargetTier3 = Get-VBRWANAccelerator -Name $WanAccelTargetTier3Name

foreach ($HVMachine in $HVMachinesReplicaGold){

Write-Host 'Building Tier 1 Gold Jobs for' $HVMachine.Name -ForegroundColor Green
  $newjob1 = Add-VBRHvBackupCopyJob -BackupJob ($HVMachine.Name).ToString() -Name ('Tier1-' + $HVMachine.Name).ToString() -DirectOperation -Repository $Tier1Repository
Write-Host 'Building Tier 2 Gold Jobs for' $HVMachine.Name -ForegroundColor Green
  $newjob2 = Add-VBRHvBackupCopyJob -BackupJob ($HVMachine.Name).ToString() -Name ('Tier2-' + $HVMachine.Name).ToString() -SourceAccelerator $WanAccelSource -TargetAccelerator $WanAccelTargetTier2 -Repository $Tier2Repository
Write-Host 'Building Tier 3 Gold Jobs for' $HVMachine.Name -ForegroundColor Green
  $newjob3 = Add-VBRHvBackupCopyJob -BackupJob ($HVMachine.Name).ToString() -Name ('Tier3-' + $HVMachine.Name).ToString() -SourceAccelerator $WanAccelSource -TargetAccelerator $WanAccelTargetTier3 -Repository $Tier3Repository
 
  $template = Get-VBRJob | where {$_.name -eq "BCJ-Gold_Template-Tier1"}
  $templateoptions = Get-VBRJobOptions $template
  $templateoptionsvss = Get-VBRJobVSSOptions $template
  $template2 = Get-VBRJob | where {$_.name -eq "BCJ-Gold_Template-Tier2"}
  $templateoptions2 = Get-VBRJobOptions $template2
  $templateoptionsvss2 = Get-VBRJobVSSOptions $template2
  $template3 = Get-VBRJob | where {$_.name -eq "BCJ-Gold_Template-Tier3"}
  $templateoptions3 = Get-VBRJobOptions $template3
  $templateoptionsvss3 = Get-VBRJobVSSOptions $template3


  #$templateoptionssched = Get-VBRJobScheduleOptions $template
  Write-Host 'Configuring Settings for Tier 1 Gold Jobs for' $HVMachine.Name -ForegroundColor Green
  Set-VBRJobOptions -job $newjob1 -options $templateoptions -ErrorAction SilentlyContinue | out-null
  Set-VBRJobVSSOptions -job $newjob1 -options $templateoptionsvss -ErrorAction SilentlyContinue | Out-Null
  Write-Host 'Configuring Settings for Tier 2 Gold Jobs for' $HVMachine.Name -ForegroundColor Green
    Set-VBRJobOptions -job $newjob2 -options $templateoptions2 -ErrorAction SilentlyContinue | Out-Null
  Set-VBRJobVSSOptions -job $newjob2 -options $templateoptionsvss2 -ErrorAction SilentlyContinue |Out-Null
  Write-Host 'Configuring Settings for Tier 3 Gold Jobs for' $HVMachine.Name -ForegroundColor Green
    Set-VBRJobOptions -job $newjob3 -options $templateoptions3 -ErrorAction SilentlyContinue | Out-Null
  Set-VBRJobVSSOptions -job $newjob3 -options $templateoptionsvss3 -ErrorAction SilentlyContinue | Out-Null
    # Set the job schedule and increment by 5 minutes
    $ScheduleOptions = New-VBRJobScheduleOptions
   
    IF ($minute -gt 55) 
    {
    $hour += 1
    $minute = 00
    }
    IF ($hour -gt 23)
    {
    $hour = 00
    }

    ELSE 
    {
    $Date = Get-Date -Hour $hour -Minute $minute
    $minute += 5
    }

    $ScheduleOptions.StartDateTime = $Date
    $ScheduleOptions.OptionsDaily.Enabled = $True
    $ScheduleOptions.OptionsDaily.Kind = "Everyday"
    $ScheduleOptions.OptionsDaily.Time = $Date
  
    # Apply the schedule
    Write-Host 'Configuring Schedule for Tier 1 Backup Job for' $hvmachine.name 'at' $Date -ForegroundColor Green
    Set-VBRJobScheduleOptions -Job $NewJob1 -Options $ScheduleOptions -ErrorAction SilentlyContinue | Out-Null

    # Loop for Tier 2 Jobs
    $ScheduleOptions = New-VBRJobScheduleOptions
    
    IF ($minute -gt 55) 
    {
    $hour += 1
    $minute = 00
    }
    IF ($hour -gt 23)
    {
    $hour = 00
    }

    ELSE 
    {
    $Date = Get-Date -Hour $hour -Minute $minute
    $minute += 5
    }

    $ScheduleOptions.StartDateTime = $Date
    $ScheduleOptions.OptionsDaily.Enabled = $True
    $ScheduleOptions.OptionsDaily.Kind = "Everyday"
    $ScheduleOptions.OptionsDaily.Time = $Date
    # Apply the schedule
    Write-Host "Configuring Schedule for Tier 2 Backup Job for" $hvmachine.name 'at' $Date -ForegroundColor Green
    Set-VBRJobScheduleOptions -Job $NewJob2 -Options $ScheduleOptions -ErrorAction SilentlyContinue | Out-Null

   #Loop for Tier 3 Jobs
    $ScheduleOptions = New-VBRJobScheduleOptions
    
    IF ($minute -gt 55) 
    {
    $hour += 1
    $minute = 00
    }
    IF ($hour -gt 23)
    {
    $hour = 00
    }

    ELSE 
    {
    $Date = Get-Date -Hour $hour -Minute $minute
    $minute += 5
    }

    $ScheduleOptions.StartDateTime = $Date
    $ScheduleOptions.OptionsDaily.Enabled = $True
    $ScheduleOptions.OptionsDaily.Kind = "Everyday"
    $ScheduleOptions.OptionsDaily.Time = $Date
   
    # Apply the schedule
    Write-Host "Configuring Schedule for Tier 3 Backup Job for" $hvmachine.name 'at' $Date -ForegroundColor Green
    Set-VBRJobScheduleOptions -Job $NewJob3 -Options $ScheduleOptions -ErrorAction SilentlyContinue | out-null

    

    }
    }


#Builds our Silver Backup Copy Jobs for all VM's with a Prefix of -Silver 
if ($SilverBackupCopyJobs -eq $true)  {
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes",""
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No",""
    $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    $choice = $Host.UI.PromptForChoice("-=Silver Backup Copy Jobs=-", "Are you Sure you want to Create the Silver Backup Copy Jobs?", $choices, 1)
    if ($choice -eq 0) {
        Write-Host -ForegroundColor Green "Building Silver Backup Copy Jobs"}
    if ($Choice -eq 1) {
        Write-Warning "Aborting script..." 
	    Exit 1 }

$Tier1RepositoryName = Read-Host "Type the Name of the Veeam Repository that will Store the Tier 1 Data ex VeeamSR*"
#$Tier2RepositoryName = Read-Host "Type the Name of the Veeam Repository that will store the Tier 2 Data ex DRVeeamSR*"
$Tier3RepositoryName = Read-Host "Type the Name of the Veeam Repository that will store the Tier 3 Data ex AzureVeeamSR*"
$WanAccelSourceName = Read-Host "Type the Name of the Source Wan Accerator"
$WanAccelTargetTier2Name = Read-Host "Type the Name of the Target Wan Accelerator Tier 2"
$WanAccelTargetTier3Name = Read-Host "Type the Name of the Target Wan Accelerator Tier 3 Azure"

$HVMachinesReplicaPlatinum = (Find-VBRHvEntity | Select-Object -Skip 1) | where {$_.type -eq "VM"} | where {$_.VMHostName -eq $VMHostServerSource} | where {$_.name -like 'Platinum-*'}
$HVMachinesReplicaGold = (Find-VBRHvEntity | Select-Object -Skip 1) | where {$_.type -eq "VM"} | where {$_.VMHostName -eq $VMHostServerSource} | where {$_.name -like 'Gold-*'}
$HVMachinesReplicaSilver = (Find-VBRHvEntity | Select-Object -Skip 1) | where {$_.type -eq "VM"} | where {$_.VMHostName -eq $VMHostServerSource} | where {$_.name -like 'Silver-*'}
#$VeeamServer = (Get-VBRServer -name $VS | select-object -Skip 1)
#$VeeamServer1 = (Get-VBRServer -name $VS1 | select-object -Skip 1)
#$VeeamServer2 = (Get-VBRServer -Name $VS2 | select-object -Skip 1)
$Tier1Repository = Get-VBRBackupRepository -Name $Tier1RepositoryName
#$Tier2Repository = Get-VBRBackupRepository -Name $Tier2RepositoryName
$Tier3Repository = Get-VBRBackupRepository -Name $Tier3RepositoryName
$WanAccelSource = Get-VBRWANAccelerator -name $WanAccelSourceName
$WanAccelTargetTier2 = Get-VBRWANAccelerator -Name $WanAccelTargetTier2Name
$WanAccelTargetTier3 = Get-VBRWANAccelerator -Name $WanAccelTargetTier3Name

foreach ($HVMachine in $HVMachinesReplicaSilver){

Write-Host 'Building Tier 1 Silver Jobs for' $HVMachine.Name -ForegroundColor Green
  $newjob1 = Add-VBRHvBackupCopyJob -BackupJob ($HVMachine.Name).ToString() -Name ('Tier1-' + $HVMachine.Name).ToString() -DirectOperation -Repository $Tier1Repository
#Write-Host 'Building Tier 2 Silver Jobs for' $HVMachine.Name -ForegroundColor Green
#  $newjob2 = Add-VBRHvBackupCopyJob -BackupJob ($HVMachine.Name).ToString() -Name ('Tier2-' + $HVMachine.Name).ToString() -SourceAccelerator $WanAccelSource -TargetAccelerator $WanAccelTargetTier2 -Repository $Tier2Repository
Write-Host 'Building Tier 3 Silver Jobs for' $HVMachine.Name -ForegroundColor Green
  $newjob3 = Add-VBRHvBackupCopyJob -BackupJob ($HVMachine.Name).ToString() -Name ('Tier3-' + $HVMachine.Name).ToString() -SourceAccelerator $WanAccelSource -TargetAccelerator $WanAccelTargetTier3 -Repository $Tier3Repository
 

  $template = Get-VBRJob | where {$_.name -eq "BCJ-Silver_Template-Tier1"}
  $templateoptions = Get-VBRJobOptions $template
  $templateoptionsvss = Get-VBRJobVSSOptions $template
  #$template2 = Get-VBRJob | where {$_.name -eq "BCJ-Silver_Template-Tier2"}
  #$templateoptions2 = Get-VBRJobOptions $template2
  #$templateoptionsvss2 = Get-VBRJobVSSOptions $template2
  $template3 = Get-VBRJob | where {$_.name -eq "BCJ-Silver_Template-Tier3"}
  $templateoptions3 = Get-VBRJobOptions $template3
  $templateoptionsvss3 = Get-VBRJobVSSOptions $template3


  #$templateoptionssched = Get-VBRJobScheduleOptions $template
  Write-Host 'Configuring Settings for Tier 1 Silver Jobs for' $HVMachine.Name -ForegroundColor Green
  Set-VBRJobOptions -job $newjob1 -options $templateoptions -ErrorAction SilentlyContinue | out-null
  Set-VBRJobVSSOptions -job $newjob1 -options $templateoptionsvss -ErrorAction SilentlyContinue | Out-Null
 # Write-Host 'Configuring Settings for Tier 2 Silver Jobs for' $HVMachine.Name -ForegroundColor Green
 #   Set-VBRJobOptions -job $newjob2 -options $templateoptions2 -ErrorAction SilentlyContinue | Out-Null
 # Set-VBRJobVSSOptions -job $newjob2 -options $templateoptionsvss2 -ErrorAction SilentlyContinue |Out-Null
  Write-Host 'Configuring Settings for Tier 3 Silver Jobs for' $HVMachine.Name -ForegroundColor Green
    Set-VBRJobOptions -job $newjob3 -options $templateoptions3 -ErrorAction SilentlyContinue | Out-Null
  Set-VBRJobVSSOptions -job $newjob3 -options $templateoptionsvss3 -ErrorAction SilentlyContinue | Out-Null
    # Set the job schedule and increment by 5 minutes
    $ScheduleOptions = New-VBRJobScheduleOptions
   
    IF ($minute -gt 55) 
    {
    $hour += 1
    $minute = 00
    }
    IF ($hour -gt 23)
    {
    $hour = 00
    }

    ELSE 
    {
    $Date = Get-Date -Hour $hour -Minute $minute
    $minute += 5
    }

    $ScheduleOptions.StartDateTime = $Date
    $ScheduleOptions.OptionsDaily.Enabled = $True
    $ScheduleOptions.OptionsDaily.Kind = "Everyday"
    $ScheduleOptions.OptionsDaily.Time = $Date
  
    # Apply the schedule
    Write-Host 'Configuring Schedule for Tier 1 Backup Job for' $hvmachine.name 'at' $Date -ForegroundColor Green
    Set-VBRJobScheduleOptions -Job $NewJob1 -Options $ScheduleOptions -ErrorAction SilentlyContinue | Out-Null

    # Loop for Tier 2 Jobs
    $ScheduleOptions = New-VBRJobScheduleOptions
    
    IF ($minute -gt 55) 
    {
    $hour += 1
    $minute = 00
    }
    IF ($hour -gt 23)
    {
    $hour = 00
    }

    ELSE 
    {
    $Date = Get-Date -Hour $hour -Minute $minute
    $minute += 5
    }

    $ScheduleOptions.StartDateTime = $Date
    $ScheduleOptions.OptionsDaily.Enabled = $True
    $ScheduleOptions.OptionsDaily.Kind = "Everyday"
    $ScheduleOptions.OptionsDaily.Time = $Date
    # Apply the schedule
    #Write-Host "Configuring Schedule for Tier 2 Backup Job for" $hvmachine.name 'at' $Date -ForegroundColor Green
    #Set-VBRJobScheduleOptions -Job $NewJob2 -Options $ScheduleOptions -ErrorAction SilentlyContinue | Out-Null

   #Loop for Tier 3 Jobs
    $ScheduleOptions = New-VBRJobScheduleOptions
    
    IF ($minute -gt 55) 
    {
    $hour += 1
    $minute = 00
    }
    IF ($hour -gt 23)
    {
    $hour = 00
    }

    ELSE 
    {
    $Date = Get-Date -Hour $hour -Minute $minute
    $minute += 5
    }

    $ScheduleOptions.StartDateTime = $Date
    $ScheduleOptions.OptionsDaily.Enabled = $True
    $ScheduleOptions.OptionsDaily.Kind = "Everyday"
    $ScheduleOptions.OptionsDaily.Time = $Date
   
    # Apply the schedule
    Write-Host "Configuring Schedule for Tier 3 Backup Job for" $hvmachine.name 'at' $Date -ForegroundColor Green
    Set-VBRJobScheduleOptions -Job $NewJob3 -Options $ScheduleOptions -ErrorAction SilentlyContinue | out-null

    

    }
    }

#Deletes all of the Backup Copy Jobs for Platinum Gold and Silver
    if ($DeleteAllBackupCopyJobs -eq $true)  {
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes",""
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No",""
    $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    $choice = $Host.UI.PromptForChoice("-=Delete All Platinum,Gold, and Silver Backup Copy Jobs=-", "Are you Sure you want to Remove all of the Platinum,Gold, and Silver Backup Copy Jobs?", $choices, 1)
    if ($choice -eq 0) {
        Write-Host -ForegroundColor RED "Deleting All of Backup Copy -"}
    if ($Choice -eq 1) {
        Write-Warning "Aborting script..." 
	    Exit 1 }
    
    Write-Host 'Removing All Platinum- Jobs' -ForegroundColor Red
    Get-vbrjob -name 'Tier1-*' | remove-vbrjob -ErrorAction SilentlyContinue -confirm:$false | Out-Null
    Write-Host 'Removing All Gold- Jobs' -ForegroundColor Red
    Get-vbrjob -name 'Tier2-*' | remove-vbrjob -ErrorAction SilentlyContinue -Confirm:$false | Out-Null
    Write-Host 'Removing All Silver- Jobs' -ForegroundColor Red
    Get-vbrjob -name 'Tier3-*' | remove-vbrjob -ErrorAction SilentlyContinue -confirm:$false | Out-Null
    }

#Creates the Virtual Labs
if ($CreateVLAB -eq $True){  
   $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes",""
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No",""
    $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    $choice = $Host.UI.PromptForChoice("-=Create the Virtual Labs=-", "Are you Sure you want to Create The Virtual Labs?", $choices, 1)
    if ($choice -eq 0) {
        Write-Host -ForegroundColor Green "Virtual Labs -"}
    if ($Choice -eq 1) {
        Write-Warning "Aborting script..." 
	    Exit 1 } 

  $VlabHostName = read-host 'Provide the name of the Target Hyper-V Host Server that will be used to create the Lab'
  $VlabHost = Get-VBRServer -Type HvServer -Name $VlabHostName
  $VlabPath = read-host 'Enter the Path for the new Virtual Lab For Exchange and SQL ex. g:\Veeam_SB_LAB_Exchange'
  $VlabPath1 = read-host 'Enter the Path for the Platinum Jobs ex. g:\Veeam_SB_LAB'
  Write-Host 'Creating Virtual Lab Platinum Exchagne-SQL' -ForegroundColor Green
  Add-VSBHvVirtualLab -Name 'Platinum Exchange-SQL LAB' -server $vlabhostname.ToString() -folder $vlabpath
  Write-Host 'Creating Virtual Lab Platinum Jobs' -ForegroundColor Green
  Add-VSBHvVirtualLab -Name 'Platinum Jobs' -server $vlabhostname.ToString() -folder $vlabpath1

  }




#Creates SureBackup Jobs for all Platinum Jobs and places them into the 'Platinum Jobs' Virtual Lab
#This has a requires that the virtual Lab be created first

  if ($PlatinumSureBackupJObs -eq $True){ 
  
   $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes",""
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No",""
    $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    $choice = $Host.UI.PromptForChoice("-=Create the Platinum SureBackup Jobs=-", "Are you Sure you want to Create all of the Platinum SureBackup Jobs?", $choices, 1)
    if ($choice -eq 0) {
        Write-Host -ForegroundColor Green "Creating the Platinum SureBackup Jobs -"}
    if ($Choice -eq 1) {
        Write-Warning "Aborting script..." 
	    Exit 1 } 
  
  $HVMachinesPlatinum = (Find-VBRHvEntity | Select-Object -Skip 1) | where {$_.type -eq "VM"} | where {$_.VMHostName -eq $VMHostServerSource} | where {$_.name -like 'Platinum-*'}

  $VLABPlatinum = Get-VSBHvVirtualLab -name 'Platinum Jobs'
  
  foreach ($hvmachine in $HVMachinesPlatinum){
  Write-Host 'Building SureBackup Platinum Jobs for' $HvMachine.Name -ForegroundColor Green
  
  $NewJob = Add-VSBHvJob -name ('SureBackup-' + $hvmachine.Name).ToString() -VirtualLab $VLABPlatinum -LinkedJob $HvMachine.name.ToString() | Set-VSBJobSchedule -Daily -At "11:00"
    
    # Set the job schedule and increment by 5 minutes
  
    $ScheduleOptions = New-VBRJobScheduleOptions

     
    IF ($minute -gt 55) 
    {
    $hour += 1
    $minute = 00
    }
    IF ($hour -gt 23)
    {
    $hour = 00
    }

    ELSE 
    {
    $Date = Get-Date -Hour $hour -Minute $minute
    $minute += 5
    }

    $ScheduleOptions.StartDateTime = $Date
    $ScheduleOptions.OptionsDaily.Enabled = $True
    $ScheduleOptions.OptionsDaily.Kind = "Everyday"
    $ScheduleOptions.OptionsDaily.Time = $Date
  
    # Apply the schedule
    Write-Host 'Configuring Schedule for Platinum SureBackup Backup Job for' $hvmachine.name 'at' $Date -ForegroundColor Green
    Set-VSBJobScheduleOptions -Job $newjob -Options $ScheduleOptions -ErrorAction SilentlyContinue | Out-Null
    Write-Host 'Enabling the Schedule for' $HVMachine.Name -ForegroundColor Green
    Enable-VBRJobSchedule -Job $NewJob.name -ErrorAction SilentlyContinue | Out-Null
    Write-Host 'Disabling the Job for' $HVMachine.Name -ForegroundColor Green
    Disable-VBRJob -Job ('SureBackup-' + $HVMachine.Name).ToString() -ErrorAction SilentlyContinue |Out-Null


    
  
  
  
  }}

    
##Removes all of the SureBackup Jobs with a Prefix of SureBackup-
    if ($DeleteAllSureBackupJobs -eq $true)  {
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes",""
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No",""
    $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    $choice = $Host.UI.PromptForChoice("-=Delete All Platinum SureBackup Jobs=-", "Are you Sure you want to Remove all of the Platinum SureBackup Jobs?", $choices, 1)
    if ($choice -eq 0) {
        Write-Host -ForegroundColor RED "Deleting All of SureBackup Jobs -"}
    if ($Choice -eq 1) {
        Write-Warning "Aborting script..." 
	    Exit 1 }
    
    Write-Host 'Removing All Platinum- Jobs' -ForegroundColor Red
    Get-vsbjob -name 'SureBackup-*' | remove-vsbjob -ErrorAction SilentlyContinue -confirm:$false | Out-Null
    
    }     