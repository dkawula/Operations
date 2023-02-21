$action = New-ScheduledTaskAction powershell.exe -Argument " -command 'c:\post-install\005-MonitorADG\Monitor-ADGroupMemberShip.ps1' -group \'Domain Admins\',\'Schema Admins\',\'Enterprise Admins\' -htmllog\"
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 3)
$principal = New-ScheduledTaskPrincipal -UserID MFGTitan\S2DReporting$ -LogonType Password
Register-ScheduledTask MonitorADG –Action $action –Trigger $trigger –Principal $principal

Set-ScheduledTask -TaskName "Titan Daily Health Report" -Principal $principal
