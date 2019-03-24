#View the Deduplication Event logs and statistics on Windows Server 2019

    $DedupStatus = Get-DedupStatus | Select-Object *

    $DedupVolumeStats = Get-dedupvolume D: | Select * 

    $Dedupevents = Get-WinEvent -MaxEvents 10 -LogName Microsoft-Windows-Deduplication/Diagnostic | Select-Object *

    $DedupDiagevents = Get-WinEvent -MaxEvents 10 -LogName Microsoft-Windows-Deduplication/Scrubbing | Select-Object *

#View the existing Deduplication Schedule on Windows Server 2019
get-dedupschedule | select Type,Priority,Inputoutputthrottlelevel,days,cores,duration,enabled,faststart,full,idletimeout,inputoutputthrottle,memory,name,readonly,scheduledtask | out-gridview



#Sample - Tweak the Deduplication Schedule to run with higher performance during off peak hours


#1.	Disable the scheduled hourly Opimization Jobs
Set-DedupSchedule -Name BackgroundOptimization -Enabled $false
Set-DedupSchedule -Name PriorityOptimization -Enabled $false


#2.	Remove the currently scheduled Garbage Collection and Integrity Scrubbing Jobs.
Get-DedupSchedule -Type GarbageCollection | ForEach-Object { Remove-DedupSchedule -InputObject $_ }
Get-DedupSchedule -Type Scrubbing | ForEach-Object { Remove-DedupSchedule -InputObject $_ }
New-DedupSchedule -Name "NightlyOptimization" -Type Optimization -DurationHours 11 -Memory 100 -Cores 100 -Priority High -Days @(1,2,3,4,5) -Start (Get-Date "2016-08-08 19:00:00")


#3.	Create a Nightly Optimization jobs that runs at 7:00 PM with high priority and all the CPUs and memory available on the system
New-DedupSchedule -Name "NightlyOptimization" -Type Optimization -DurationHours 11 -Memory 100 -Cores 100 -Priority High -Days @(1,2,3,4,5) -Start (Get-Date "2018-08-08 19:00:00")

#4.	Create a weekly Garbarge Colelction job that runs on Saturday starting at 7:00 AM with high priority and all the CPUs and memory available on the system
New-DedupSchedule -Name "WeeklyGarbageCollection" -Type GarbageCollection -DurationHours 23 -Memory 100 -Cores 100 -Priority High -Days @(6) -Start (Get-Date "2016-08-13 07:00:00")

#5.	Create a weekly integrity scrubbing job that runs on Sunday starting at 7AM with high priority and all the CPUs and memory available on the system
New-DedupSchedule -Name "WeeklyIntegrityScrubbing" -Type Scrubbing -DurationHours 23 -Memory 100 -Cores 100 -Priority High -Days @(0) -Start (Get-Date "2016-08-14 07:00:00")




#Enable Optimization on Partial Files (Optional) on a per volume level
Get-DedupVolume -Volume C:\ClusterStorage\Volume1 | Select *
Set-DedupVolume -Volume C:\ClusterStorage\Volume1 -OptimizePartialFiles


#Manually run Full Garbage Colelction to gain approximately another 5% or so free disk space back
#If Dedup type is set to Backup --> Then Garbage colelction is NEVER Run you need to do it manually
Start-DedupJob -Type GarbageCollection -Full




