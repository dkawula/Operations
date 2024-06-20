# Import the Active Directory module
Import-Module ActiveDirectory

# Get the current domain information
$domain = Get-ADDomain

# Extract the domain name
$domainName = $domain.DNSRoot

# Define the Organizational Unit
$OU = "OU=BKUP Targets,OU=Patch Group 2,OU=Veeam,OU=Fabric,DC=" + $domainName.Replace(".", ",DC=")
$OU1 = "OU=BKUP Targets,OU=Patch Group 1,OU=Veeam,OU=Fabric,DC=" + $domainName.Replace(".", ",DC=")
$OU2 = "OU=Hyper-V Hosts,OU=Fabric,DC=" + $domainName.Replace(".", ",DC=")
$OU3 = "OU=HCI Clusters,OU=Fabric,DC=" + $domainName.Replace(".", ",DC=")

# Query Active Directory for computer objects in the specified OU
$computers = Get-ADComputer -Filter * -SearchBase $OU
$computers += Get-ADComputer -Filter * -SearchBase $OU1
$computers += Get-ADComputer -Filter * -SearchBase $OU2

$computers2 = Get-ADComputer -LDAPFilter "(&(objectClass=computer)(description=Failover cluster virtual network name account))" -SearchBase $OU3


# Loop through each computer and create a scheduled task for Standalone Hyper-V Hosts and Backup Targets running Hyper-V

foreach ($computer in $computers) {
    $computerName = $computer.Name
    $taskName = "$computerName-HV-Report"
    $reportFileNamePrefix = $computerName
    $reportFilePath = "C:\HyperVReport\Reports"

    # Define the action for the scheduled task
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File C:\HyperVReport\Get-HyperVReport-VMHost.ps1 -VMHost $computerName -ReportFileNamePrefix $reportFileNamePrefix -ReportFilePath $reportFilePath"

    # Define the trigger for the scheduled task
    $trigger = New-ScheduledTaskTrigger -Daily -At 9:30am

    # Define the principal for the scheduled task
    $principal = New-ScheduledTaskPrincipal -UserId "s2dreporting$" -LogonType Password

    # Register the scheduled task
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal
}


# Loop through each computer and create a scheduled task for HCI Clusters

foreach ($computer in $computers2) {
    $computerName = $computer.Name
    $taskName = "$computerName-HV-Report"
    $reportFileNamePrefix = $computerName
    $reportFilePath = "C:\HyperVReport\Reports"

    # Define the action for the scheduled task
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File C:\HyperVReport\Get-HyperVReport-VMHost.ps1 -Cluster $computerName -ReportFileNamePrefix $reportFileNamePrefix -ReportFilePath $reportFilePath"

    # Define the trigger for the scheduled task
    $trigger = New-ScheduledTaskTrigger -Daily -At 9:30am

    # Define the principal for the scheduled task
    $principal = New-ScheduledTaskPrincipal -UserId "s2dreporting$" -LogonType Password

    # Register the scheduled task
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal
}

