#Initial Script written by Tom Sightler for VMWare
#Dave Converted this to work with Hyper-V
# Verify protected VM's in Hyper-V
#
<#

Version: 1.0.0
Date: 2017-11-28
Author: Dave Kawula MVP
Contact: @DaveKawula

Revisions
============
2017-11-28  v1.0.0 Initial Release

#>
####################################################################
#
# Run the script against Hyper-V and Veeam server and checks which VM's
# have been protected in the last 168 hours, and which are not protected

asnp "VeeamPSSnapIn" -ErrorAction SilentlyContinue

####################################################################
# Configuration
#
# To exclude VMs from report add VM names to be excluded as follows
# simple wildcards are supported:
# $excludevms=@("vm1","vm2", "*_replica")
$excludeVMs = @("*_Replica","*_Ghost")
# Exclude VMs in the following vCenter folder(s) (does not exclude sub-folders)
# $excludeFolder =  = @("folder1","folder2","*_testonly")
$excludeFolder = @("")
# Exclude VMs in the following vCenter datacenter(s)
# $excludeDC =  = @("dc1","dc2","dc*")
$excludeDC = @("")#
# This variable sets the number of hours of session history to
# search for a successul backup of a VM before considering a VM
# "Unprotected".  For example, the default of "24" tells the script
# to search for all successful/warning session in the last 24 hours
# and if a VM is not found then assume that VM is "unprotected".
$HourstoCheck = 168
####################################################################

# Convert exclusion list to simple regular expression
$excludevms_regex = ('(?i)^(' + (($excludeVMs | ForEach {[regex]::escape($_)}) -join "|") + ')$') -replace "\\\*", ".*"
$excludefolder_regex = ('(?i)^(' + (($excludeFolder | ForEach {[regex]::escape($_)}) -join "|") + ')$') -replace "\\\*", ".*"
$excludedc_regex = ('(?i)^(' + (($excludeDC | ForEach {[regex]::escape($_)}) -join "|") + ')$') -replace "\\\*", ".*"

$vms=@{}

# Build a hash table of all VMs.  Key is either Job Object Id (for any VM ever in a Veeam job) or vCenter ID+MoRef
# Assume unprotected (!), and populate Cluster, DataCenter, and Name fields for hash key value
Find-VBRHVEntity -HostsAndVMs | 
    Where-Object {$_.Type -eq "Vm" } |
    Where-Object {$_.Name -notmatch $excludevms_regex} |
    Where-Object {$_.Path.Split("\")[1] -notmatch $excludedc_regex} |
    ForEach {$vms.Add(($_.FindObject().Id, $_.Id -ne $null)[0], @("!", $_.Path.Split("\")[1], $_.Path.Split("\")[2], $_.Name))}

# Find all backup task sessions that have ended in the last x hours and not ending in Failure
$vbrtasksessions = (Get-VBRBackupSession |
    Where-Object {$_.JobType -eq "Backup" -and $_.EndTime -ge (Get-Date).addhours(-$HourstoCheck)}) |
    Get-VBRTaskSession | Where-Object {$_.Status -ne "Failed"}

# Compare VM list to session list and update found VMs status to "Protected"
If ($vbrtasksessions) {
    Foreach ($vmtask in $vbrtasksessions) {
        If($vms.ContainsKey($vmtask.Info.ObjectId)) {
            $vms[$vmtask.Info.ObjectId][0]=$vmtask.JobName
        }
    }
}

$vms = $vms.GetEnumerator() | Sort-Object Value
#$vms

# Output VMs in color coded format based on status
# VM's with a job name of "!" were not found in any job

 $Protectedvms = @()
 $UnProtectedvms = @()
$VMInfo = foreach ($vm in $vms) {
    if ($vm.Value[0] -ne "!") {
        write-host -foregroundcolor green (($vm.Value[1]) + "\" + ($vm.Value[2]) + "\" + ($vm.Value[3])) "is backed up in job:" $vm.Value[0]
     $reportObject = "" | Select-Object ComputerName,text,Job,TimeSpanHrs
     $ReportObject.ComputerName =  ($vm.Value[1]).ToString()
     $ReportObject.text = " has been backed up by job"
     $ReportObject.Job =  ($vm.Value[0]).ToString() 
     $ReportObject.TimeSpanHrs = $HourstoCheck
     $Protectedvms += $ReportObject
        
      } else {
        write-host -foregroundcolor red (($vm.Value[1]) + "\" + ($vm.Value[2]) + "\" + ($vm.Value[3])) "is not found in any backup session in the last" $HourstoCheck "hours"
     $reportObject1 = "" | Select-Object ComputerName,text,Job,TimeSpanHrs
     $ReportObject1.ComputerName =  ($vm.Value[1]).ToString()
     $ReportObject1.text = "is not being protected"
     $ReportObject1.Job =  "Successful Job not found in the past"
     $ReportObject1.TimeSpanHrs = $HourstoCheck 
     $UnProtectedvms += $ReportObject1
      
         }
}


#   $Protectedvms
#  $Unprotectedvms

#$VMInfo

#Building up the Report
$Header = @"
<style>
TABLE {border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse;}
TH {border-width: 1px; padding: 3px; border-style: solid; border-color: black; background-color: #6495ED;}
TD {border-width: 1px; padding: 3px; border-style: solid; border-color: black;}
</style>
"@

 #You could easily save copies of the report on the Server if you like --> I just overwrite the file
 #The Report file will be saved in the working folder
 
$body = ConvertTo-Html -Body "<H1>COMPANY Veeam Backup Audit Report </H1><H3> Weekly Backup Audit </H3> <H1>Unprotected VM's</H1>$($UnProtectedVMs | Convertto-Html -Property * -Fragment) <H1> Protected VM's  </H1> $($ProtectedVMs | Convertto-Html -Property * -Fragment) <H1> Protected VM's  </H1> " -Title "Veeam Backup Weekly Audit Unprotected VM's" -Head $Header |out-file .\Veeam-Weekly-BackupAudit.html
$body1 = get-content .\Veeam-Weekly-BackupAudit.html -Raw


$Username ="BLAH"
$Password = ConvertTo-SecureString "Put Your Password in Here" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential $Username, $Password
$SMTPServer = "smtp.sendgrid.net"
$EmailFrom = "Operations-No-Reply@Company.com"
$EmailTo = "blah@blah.com"
$Subject = "Veeam Audit Weekly Report"
#$Body = "SendGrid testing successful"
Send-MailMessage -smtpServer $SMTPServer -Credential $credential -Port 587 -from $EmailFrom -to $EmailTo -subject $Subject -Body $body1 -BodyAsHtml 
