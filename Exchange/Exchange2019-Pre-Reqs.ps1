#Installing Exchange 2019 PowerShell CMDS
#By Cary Sun - MVP and Dave Kawula - MVP
#Follow along with the step by step guide for the installation 


#region 001 - Install Exchange 2019 Mailbox Server Role Prerequisites

#This Installation is based on a two Server installation
#Will will install the Pre-Reqs on Both Servers at the same time to ensure consistency

$Nodes = 'ServerA','ServerB'
$Nodes


#Next Download and Install Visual C++ Redistributable Package for Visual Studio 2012. 
#https://www.microsoft.com/download/details.aspx?id=30679

# Define the URL of the download

Invoke-Command $Nodes {
$folder = "c:\post-install\exchange-prereqs"
if (-not (Test-Path $folder)) {
    New-Item -ItemType Directory -Path $folder
}

$url = "https://download.visualstudio.microsoft.com/download/pr/014120d7-d689-4305-befd-3cb711108212/0fd66638cde16859462a6243a4629a50/ndp48-x86-x64-allos-enu.exe"
$outfile = "$folder\ndp48-x86-x64-allos-enu.exe"
Invoke-WebRequest $url -OutFile $outfile

Start-Process -FilePath $outfile -ArgumentList "/q /norestart" -Wait

}


Invoke-Command $Nodes {
$folder = "c:\post-install\exchange-prereqs"
if (-not (Test-Path $folder)) {
    New-Item -ItemType Directory -Path $folder
}

$url = "https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x64.exe"
$outfile = "$folder\vcredist_x64-2012.exe"
Invoke-WebRequest $url -OutFile $outfile

Start-Process -FilePath $outfile -ArgumentList "/q" -Wait

}

Invoke-Command $Nodes {
$folder = "c:\post-install\exchange-prereqs"
if (-not (Test-Path $folder)) {
    New-Item -ItemType Directory -Path $folder
}

$url = "https://aka.ms/highdpimfc2013x64enu"
$outfile = "$folder\vcredist_x64-2013.exe"
Invoke-WebRequest $url -OutFile $outfile

Start-Process -FilePath $outfile -ArgumentList "/q" -Wait

}

Invoke-Command $Nodes {
$folder = "c:\post-install\exchange-prereqs"
if (-not (Test-Path $folder)) {
    New-Item -ItemType Directory -Path $folder
}

$url = "https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi"
$outfile = "$folder\rewrite_amd64_en-US.msi"
Invoke-WebRequest $url -OutFile $outfile

Start-Process msiexec.exe -ArgumentList "/i `"$outfile`" /quiet" -Wait

}

Invoke-Command $nodes {Install-WindowsFeature Server-Media-Foundation, NET-Framework-45-Features, RPC-over-HTTP-proxy, RSAT-Clustering, RSAT-Clustering-CmdInterface, RSAT-Clustering-Mgmt, RSAT-Clustering-PowerShell, WAS-Process-Model, Web-Asp-Net45, Web-Basic-Auth, Web-Client-Auth, Web-Digest-Auth, Web-Dir-Browsing, Web-Dyn-Compression, Web-Http-Errors, Web-Http-Logging, Web-Http-Redirect, Web-Http-Tracing, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Lgcy-Mgmt-Console, Web-Metabase, Web-Mgmt-Console, Web-Mgmt-Service, Web-Net-Ext45, Web-Request-Monitor, Web-Server, Web-Stat-Compression, Web-Static-Content, Web-Windows-Auth, Web-WMI, Windows-Identity-Foundation, RSAT-ADDS}


#download Exchange Server 2019 CU 12 from here

#https://www.microsoft.com/en-us/download/confirmation.aspx?id=104131
#The UCMA Redist is part of the Exchange 2019 ISO
#Assume it is mounted as E:  Change accordinly below.

Invoke-Command $Nodes {
$folder = "E:\UCMARedist"
if (-not (Test-Path $folder)) {
    New-Item -ItemType Directory -Path $folder
}

#$url = "https://www.microsoft.com/en-us/download/confirmation.aspx?id=34992"
$outfile = "$folder\setup.exe"
#Invoke-WebRequest $url -OutFile $outfile

Start-Process -FilePath $outfile -ArgumentList "/quiet /norestart" -Wait

}


#Reboot the nodes
Restart-Computer -ComputerName ServerB -force
Restart-Computer -ComputerName ServerA -force







#endregion

#region 002 - Extend SCHEMA - Process to be completed on a Domain Controller

Get-ADForest
Get-ADDomainController | Select Name,OperatingSystem

#Mount the Exchange 2019 CU12 ISO

.\Setup.exe /IAcceptExchangeServerLicenseTerms_DiagnosticDataON /PrepareSchema
.\Setup.exe /IAcceptExchangeServerLicenseTerms_DiagnosticDataON /PrepareAD
.\Setup.exe /IAcceptExchangeServerLicenseTerms_DiagnosticDataON /PrepareAllDomains







#endregion

#region 003 - Install Exchange 2019 Mailbox Role

#Ensure the Exchange 2019 CU12 ISO is mounted
#Run the on both nodes one at a time

.\Setup.exe /IAcceptExchangeServerLicenseTerms_DiagnosticDataON /mode:Install /r:MB

#Configure Windows Updates - Receive Updates for other Microsoft Products

#Run Windows Updates this will update to the latest SU

#endregion

#region 004 - Install SSL Certificate
#We are going to assume you have a *.Wildcard Cert for this example

#Login to the Exchange 2013 Server for this Step

Get-ExchangeCertificate | Select CertificateDomains, Thumbprint

#$bincert = Export-ExchangeCertificate -Thumbprint <Thumbprint> -BinaryEncoded -Password (Get-Credential).password
#$bincert = Export-ExchangeCertificate -Thumbprint 0F8621FD7020DE4DC46CA88A58E239B4EC2598CA -BinaryEncoded -Password (Get-Credential).password
#[System.IO.File]::WriteAllBytes('<path>\<file name>.pfx', $bincert.FileData)
#[System.IO.File]::WriteAllBytes('C:\Post-Install\certificate\wildcard_gooddealmart_cat.pfx', $bincert.FileData)

#Copy the Certificate to Both EX2019 Servers c:\post-install folder

#Login to EX2019 this step will need to be performed on both servers

#Import-ExchangeCertificate -Server <server name> -FileData ([System.IO.File]::ReadAllBytes('<path>\<certificate file name>')) -Password (Get-Credential).password
#Import-ExchangeCertificate -Server EX01-2019 -FileData ([System.IO.File]::ReadAllBytes('C:\Post-Install\certificate\wildcard_gooddealmart_ca.pfx')) -Password (Get-Credential).password

#Take a screenshot of the thumbprint and also copy it off for later use

#Enable-ExchangeCertificate -Thumbprint <Thumbprint> -Services <Service name>,<Service name>... [-Server < Exchange Server Name >]
#Enable-ExchangeCertificate -Thumbprint 0F8621FD7020DE4DC46CA88A58E239B4EC2598CA -Services SMTP, IIS -Server Ex01-2019

Get-ExchangeCertificate | Format-List FriendlyName,Subject,CertificateDomains,Thumbprint,Services

#endregion

#region 005 - Configure Exchange 2019 Co-existence

#This needs to be performed on both servers
#Check to see if a load balancer will be used here!!
#Get-ClientAccessService -Identity <Exchange Server Name> | Select Name,AutodiscoverServiceInternalUri | Fl
#Get-ClientAccessService -Identity "EX01-2019" | Select Name,AutodiscoverServiceInternalUri | Fl
#Set-ClientAccessService -Identity <Exchange Server Name> -AutoDiscoverServiceInternalUri  <Uri>
#Set-ClientAccessService -Identity "EX01-2019" -AutoDiscoverServiceInternalUri "https://mail.gooddealmart.ca/Autodiscover/Autodiscover.xml"

#endregion

#region 006 - Configuring the Client Access Namespaces for Exchange 2019

#The External and Internal Name is likely behind a load balancer / VIP
#Make sure to configure that first
#These steps need to be performed on each server
#Adjust the DNS Name according and Server name Accordingly

$ExternalHostname = ‘mail.gooddealmart.ca’

$InternalHostname = “mail.gooddealmart.ca”

$Servername = “EX01-2019”

Get-OWAVirtualDirectory -Server $Servername | Set-OWAVirtualDirectory -ExternalUrl https://$ExternalHostname/owa -InternalUrl https://$InternalHostname/owa

Get-ECPVirtualDirectory -Server $Servername | Set-ECPVirtualDirectory -ExternalUrl https://$ExternalHostname/ecp -InternalUrl https://$InternalHostname/ecp

Get-ActiveSyncVirtualDirectory -Server $Servername | Set-ActiveSyncVirtualDirectory -ExternalUrl https://$ExternalHostname/Microsoft-Server-ActiveSync -InternalUrl https://$InternalHostname/Microsoft-Server-ActiveSync

Get-WebServicesVirtualDirectory -Server $Servername | Set-WebServicesVirtualDirectory -ExternalUrl https://$ExternalHostname/EWS/Exchange.asmx -InternalUrl https://$InternalHostname/EWS/Exchange.asmx

Get-OABVirtualDirectory -Server $Servername | Set-OABVirtualDirectory -ExternalUrl https://$ExternalHostname/OAB -InternalUrl https://$InternalHostname/OAB

Get-MapiVirtualDirectory -Server $Servername | Set-MapiVirtualDirectory -ExternalUrl https://$ExternalHostname/mapi -InternalUrl https://$InternalHostname/Mapi

Get-OutlookAnywhere -Server $Servername | Set-OutlookAnywhere -ExternalHostname $ExternalHostname -InternalHostname $InternalHostname -ExternalClientsRequireSsl $true -InternalClientsRequireSsl $false -DefaultAuthenticationMethod NTLM,NTLM

#endregion

#region 007 - Creating a new OAB for EX2019

New-OfflineAddressBook -Name "OAB2019" -AddressLists "\Default Global Address List"

Set-OfflineAddressBook -Identity "OAB2019" -IsDefault $true
Get-OfflineAddressBook

#endregion

#region 008 - Configuring the Default Mailbox for EX2019

Get-MailboxDatabase -IncludePreExchange2013
Set-MailboxDatabase “Mailbox Database 1909041848” -Name DB01-2019
Get-MailboxDatabase DB01-2019 | Fl *path*
Move-DatabasePath -Identity DB01-2019 -EdbFilePath D:\DB01-2019\DB01-2019_DB\DB01-2019.edb -LogFolderPath D:\DB01-2019\DB01-2019_LOGS

#endregion

#region 009 - Create a new Mailbox Database for EX2019

New-MailboxDatabase -Name DB02-2019 -Server EX01-2019 -EdbFilePath D:\DB02-2019\DB02-2019_DB\DB02-2019.edb -LogFolderPath D:\DB02-2019\DB02-2019_LOGS

#Perform this on both servers
#Restart the Microsoft Exchange Information Store service

# Check if the Microsoft Exchange Information Store service is running
if ((Get-Service -Name "MSExchangeIS").Status -eq "Running") {
    # Stop the service
    Stop-Service -Name "MSExchangeIS" -Force
    Write-Host "Microsoft Exchange Information Store service stopped."
}
else {
    Write-Host "Microsoft Exchange Information Store service is not running."
}

# Start the service
Start-Service -Name "MSExchangeIS"
Write-Host "Microsoft Exchange Information Store service started."

Mount-Database -Identity DB02-2019

#endregion

#region 010 - Configuring Mailbox Database Quota

Get-MailboxDatabase -IncludePreExchange2013 | Select Name,IssueWarningQuota,ProhibitSendQuota,ProhibitSendReceiveQuota
Get-MailboxDatabase -Server Ex01-2019 | Set-MailboxDatabase –IssueWarningQuota 15GB –ProhibitSendQuota 16GB -ProhibitSendReceiveQuota 20GB
Get-MailboxDatabase -IncludePreExchange2013 | Select Name,IssueWarningQuota,ProhibitSendQuota,ProhibitSendReceiveQuota

#endregion

#region 011 - Configuring Offline Address Book

Get-MailboxDatabase -IncludePreExchange2013 | Select Name,offline*
New-OfflineAddressBook -Name "OAB2019" -AddressLists "Default Global Address List"  -GlobalWebDistributionEnabled $true
Get-OfflineAddressBook
Get-MailboxDatabase -Server EX01-2019 | Set-MailboxDatabase -OfflineAddressBook “OAB2019”
Get-MailboxDatabase -IncludePreExchange2013 | Select Name,offline*

#endregion

#region 012 - Migrate Arbitration Mailboxes

Get-Mailbox -Arbitration | Select Name,Database

Get-Mailbox -Arbitration |New-MoveRequest -TargetDatabase DB01-2019

Get-MoveRequest | Get-MoveRequestStatistics

Get-Mailbox -Arbitration | Select Name,Database

Get-MoveRequest -MoveStatus Completed | Remove-MoveRequest

#endregion

#region 013 - Migrate Audit Log Mailbox

Set-ADServerSettings -ViewEntireForest $true

Get-Mailbox -AuditLog | Format-Table Name, ServerName, Database, AdminDisplayVersion

Get-Mailbox -AuditLog | New-MoveRequest -TargetDatabase DB01-2019

Get-MoveRequest | Get-MoveRequestStatistics

Get-Mailbox -AuditLog | Format-Table Name, ServerName, Database, AdminDisplayVersion

Get-MoveRequest -MoveStatus Completed | Remove-MoveRequest

#endregion

#region 014 - Migrate Discovery Search Mailbox

Get-Mailbox -RecipientTypeDetails 
DiscoveryMailbox | Format-Table Name, Database

Get-Mailbox -RecipientTypeDetails DiscoveryMailbox | New-MoveRequest -TargetDatabase DB01-2019

Get-MoveRequest | Get-MoveRequestStatistics
Get-Mailbox -RecipientTypeDetails DiscoveryMailbox | Format-Table Name, Database

Get-MoveRequest -MoveStatus Completed | Remove-MoveRequest

#endregion


#region 015 - Uninstall EX2013 Servers

Get-MailboxDatabase -Server <Exchange 2016 server name> | Get-Mailbox | select Name,Database

Remove-MailboxDatabase -Identity <mailbox database name>

Remove-MailboxDatabaseCopy -Identity <mailbox database name>\<server name>

Remove-DatabaseAvailabilityGroupServer -Identity <DAG name> -MailboxServer <server name>

Get-PublicFolder -Server <server name> "\NON_IPM_SUBTREE" -Recurse -ResultSize:Unlimited | Remove-PublicFolder -Server <server name> -Recurse -ErrorAction:SilentlyContinue

Get-PublicFolder -Server <server name> "\" -Recurse -ResultSize:Unlimited | Remove-PublicFolder -Server <server name> -Recurse -ErrorAction:SilentlyContinue

.\MoveAllReplicas.ps1 -Server <source server name> -NewServer <destination server name>

Remove-PublicFolderDatabase -Identity <public folder database name>

Get-OfflineAddressBook

Remove-OfflineAddressBook -identity <offline address book name>

#endregion



