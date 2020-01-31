Import-Module PSAdmin
Set-NetFirewallProfile -Profile Domain -Enabled False
$Server = "EPFCRDPRAS01"
$Cred = Get-Credential
$User = $Cred.UserName
$Pwd = $Cred.Password
$Password = ConvertTo-SecureString $Pwd -AsPlainText -Force
$Email = "dkawula@triconelite.com"
$Cred1 = Get-Credential
$EmailPwd = $cred1.Password
$EmailPassword = ConvertTo-SecureString $EmailPwd -AsPlainText -Force
New-RASSession -Server $Server
$RDS1 = New-RDS -Server "EPFCRDSH03"
$RDSList = Get-RDS
New-RDSGroup -Name "Windows 2019 RDSH" -RDSObject $RDSList
Set-RDSDefaultSettings -MaxSessions 100 -EnableAppMonitoring $true
New-PubRDSDesktop -Name "Desktop"
Set-RASTurboSettings -Enable $False
Set-2FASetting -Provider GAuthTOTP
Invoke-LicenseActivate
Invoke-Apply