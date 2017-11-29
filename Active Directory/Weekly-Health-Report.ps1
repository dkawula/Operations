#Simple Weekly Active Directory Health Report
#We eamil this report weekly with our Clients
#Dave Kawula MVP


Function Getservicestatus($service, $server)
{
	$st = Get-service -computername $server | where-object { $_.name -eq $service }
	if($st)
	{$servicestatus= $st.status}
	else
	{$servicestatus = "Not found"}
	
	Return $servicestatus
}

$Forest = [system.directoryservices.activedirectory.Forest]::GetCurrentForest()

[string[]]$computername = $Forest.domains | ForEach-Object {$_.DomainControllers} | ForEach-Object {$_.Name} 


$report1= @()
foreach ($server in $computername){
$temp1 = "" | select server, pingstatus
if ( Test-Connection -ComputerName $server -Count 1 -ErrorAction SilentlyContinue ) {
$temp1.pingstatus = "Pinging"
}
else {
$temp1.pingstatus = "Not pinging"
}
$temp1.server = $server
$report1+=$temp1
}

$b = $report1 | select server, pingstatus  | ConvertTo-HTML -Fragment -As Table -PreContent "<h2>Server Availability</h2>" | Out-String


$report = @()

foreach ($server in $computername){
$temp = "" | select server, NTDS, DNS, DFSR, netlogon, w32Time
$temp.server = $server

$temp.NTDS = Getservicestatus -service "NTDS" -server $server
$temp.DNS = Getservicestatus -service "DNS" -server $server
$temp.DFSR = Getservicestatus -service "DFSR" -server $server
$temp.netlogon = Getservicestatus -service "netlogon" -server $server
$temp.w32Time = Getservicestatus -service "w32Time" -server $server
$report+=$temp
}

$b+= $REPORT | select server, NTDS, DNS, DFSR, netlogon, w32Time | ConvertTo-HTML -Fragment -As Table -PreContent "<h2>Service Status</h2>" | Out-String


add-type -AssemblyName microsoft.visualbasic 
$strings = "microsoft.visualbasic.strings" -as [type] 


$report = @()
foreach ($server in $computername){
$temp = "" | select server, SysvolTest
$temp.server = $server
$svt = dcdiag /test:netlogons /s:$server
if($strings::instr($svt, "passed test NetLogons")){$temp.SysvolTest = "Passed"}
else
{$temp.SysvolTest = "Failed"}
$report+=$temp
}
$b+= $REPORT | select server, SysvolTest | ConvertTo-HTML -Fragment -As Table -PreContent "<h2>NetLogon Test</h2>" | Out-String



$workfile = repadmin.exe /showrepl * /csv 
$results = ConvertFrom-Csv -InputObject $workfile | where {$_.'Number of Failures' -ge 1}
 
 
$results = $results | where {$_.'Number of Failures' -gt 1 }
 
if ($results -ne $null ) {
    $results = $results | select "Source DSA", "Naming Context", "Destination DSA" ,"Number of Failures", "Last Failure Time", "Last Success Time", "Last Failure Status"
    $b+= $results | select "Source DSA", "Naming Context", "Destination DSA" ,"Number of Failures", "Last Failure Time", "Last Success Time", "Last Failure Status" | ConvertTo-HTML -Fragment -As Table -PreContent "<h2>Replication Status</h2>" | Out-String    

} else {
    $results = "There were no Replication Errors"
    $b+= $results | ConvertTo-HTML -Fragment  -PreContent "<h2>Replication Status</h2>" | Out-String
     
}




$head = @'
<style>
body { background-color:#dddddd;
       font-family:Tahoma;
       font-size:12pt; }
td, th { border:1px solid black; 
         border-collapse:collapse; }
th { color:white;
     background-color:black; }
table, tr, td, th { padding: 2px; margin: 0px }
table { margin-left:50px; }
</style>
'@
 
$s = ConvertTo-HTML -head $head -PostContent $b -Body "<h1>BLAH - Active Directory Checklist</h1>" | Out-string

$CredUser = "apikey"
$CredPassword = "BLAH"

$emailFrom = "AD-WeeklyhealthCheck@stringam.ca" 
$emailTo = "BLAH@BLAH.com"

$smtpserver= "smtp.sendgrid.net" 
$smtp=new-object Net.Mail.SmtpClient($smtpServer,587)
$smtp.EnableSsl = $true
$smtp.Credentials = New-Object System.Net.NetworkCredential($CredUser,$CredPassword);

$msg = new-object Net.Mail.MailMessage
$msg.From = $emailFrom
$msg.To.Add($emailTo)
$msg.IsBodyHTML = $true
$msg.subject="Active Directory Health Check Report" 
$msg.Body = $s
$smtp.Send($msg)


