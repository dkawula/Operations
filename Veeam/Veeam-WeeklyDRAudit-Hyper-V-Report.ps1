#Initial Script written by Tom Sightler for VMWare
#Converted to Hyper-V
# Verify protected VM's in Hyper-V
#
####################################################################

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
$HourstoCheck = 500
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


$allJobs = @()
foreach ($job in Get-VBRJob |  Where-Object {$_.Name -notlike "*GHOST*" -and $_.JobType -eq "Replica" }) {
   
   $Objects = $Job | Get-VBRJobObject 

   foreach ( $obj in $objects ) {
    $addJob = New-Object -TypeName PSObject
    $addJob | Add-Member -MemberType NoteProperty -Name "JobName" -value $job.name
    $addJob | Add-Member -MemberType NoteProperty -Name "VM" -value $obj.Name
    $addJob | Add-Member -MemberType NoteProperty -Name 'BackupPlatfrom' -Value $job.BackupPlatform
    $addjob | Add-Member -MemberType NoteProperty -Name 'Result' -Value $job.GetLastResult()
    $addjob | Add-Member -MemberType NoteProperty -Name 'ObjectID' -Value $job.info.Id
    $addjob | Add-Member -MemberType NoteProperty -Name 'LastRun' -Value $job.SheduleEnabledTime
    $allJobs += $addJob
   }
   
   
 }
 $allJobs | ft

 Write-Host "Number of VM's in Veeam VBR Infrastructure" $VMs.count
 Write-Host "Number of VM's Protected at the DR Site" $Alljobs.count


 $missing = @()
 $got = @()
 foreach ( $item in $($vms.GetEnumerator()) ) {
    $found = $null
    $found = $alljobs | Where-Object { $item.value[1] -in $allJobs.VM }
    if ( -not $found ) {
        $missing += $item
    }
    else {
        $got += $item
    }
 }
 $missing.count
 $got.count

$vms = $vms.GetEnumerator() | Sort-Object Value


 $Protectedvms = @()
 $UnProtectedvms = @()
$VMInfo = foreach ($vm in $missing) {
     write-host -foregroundcolor red (($vm.Value[1]) + "\" + ($vm.Value[2]) + "\" + ($vm.Value[3])) "is not replicated by any jobs:" $vm.Value[0]
     $reportObject = "" | Select-Object ComputerName,text,Job,TimeSpanHrs
     $ReportObject.ComputerName =  ($vm.Value[1]).ToString()
     $ReportObject.text = " Has NOT been Replicated to DR"
     $ReportObject.Job =  ($got.Value[0]).ToString() 
     $ReportObject.TimeSpanHrs = $HourstoCheck
     $UnProtectedvms += $ReportObject
        
  }

#$alljobs.jobname
#$alljobs.Result


  $VMInfo = foreach ($vm in $alljobs) {

      write-host -foregroundcolor green $vm.vm + "is protected by replica Job" + $vm.JobName + "and was:" + $vm.Result
     $reportObject1 = "" | Select-Object ComputerName,text,Job,Result1,TimeSpanHrs,LastRun
     $ReportObject1.ComputerName =  $vm.vm
     $ReportObject1.text = "is protected by Replica Job     "
     $ReportObject1.Job =  $vm.JobName
     $ReportObject1.Result1 = $vm.Result
     $ReportObject1.TimeSpanHrs = $HourstoCheck
     $ReportObject1.LastRun = $vm.LastRun 
     $Protectedvms += $ReportObject1
      
         }



  # $Protectedvms
  # $Unprotectedvms

#$VMInfo


$Header = @"
<style>
TABLE {border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse;}
TH {border-width: 1px; padding: 3px; border-style: solid; border-color: black; background-color: #6495ED;}
TD {border-width: 1px; padding: 3px; border-style: solid; border-color: black;}
</style>
"@

$vmcount=$vm.count
$protectedcount=$alljobs.count
$Missingcount=$Missing.count

$Date = Get-Date 
Set-Location C:\post-install\VeeamReports 
$body = ConvertTo-Html -Body "<H1>Customer Labs Veeam DR Replica Audit Report </H1><H3> Weekly DR Replica Audit </H3> <H3>Total Unprotected VM's $missingcount</H3><H3> Total Protected VM's $ProtectedCount</H3><H1>Unprotected VM's</H1>$($UnProtectedVMs | Convertto-Html -Property * -Fragment) <H1> Protected VM's at DR  </H1> $($ProtectedVMs | Convertto-Html -Property * -Fragment) <H3> Report Generated on $Date  </H3> " -Title "Veeam Replica Weekly Audit" -Head $Header |out-file .\Veeam-Weekly-DRReplica-Report.Html
$body1 = get-content .\Veeam-Weekly-DRReplica-Report.Html -Raw


$Username ="apikey"
$Password = ConvertTo-SecureString "BLAH" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential $Username, $Password
$SMTPServer = "smtp.sendgrid.net"
$EmailFrom = "Blah@Blah.com"
$EmailTo = "BLAH@blah.com"
$Subject = "Veeam DR-Replica Audit Weekly Report"
#$Body = "SendGrid testing successful"
Send-MailMessage -smtpServer $SMTPServer -Credential $credential -Port 587 -from $EmailFrom -to $EmailTo -subject $Subject -Body $body1 -BodyAsHtml 

$Protectedvms