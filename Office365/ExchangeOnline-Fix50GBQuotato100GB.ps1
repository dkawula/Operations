#fix for users getting up to full 10 GB on E3 License
#We noticed a bug that had them set at a 50 GB quota
Set-ExecutionPolicy RemoteSigned [a for all]
Import-Module ExchangeOnlineManagement
#Connection that works for an account with MFA
Connect-ExchangeOnline -UserPrincipalName dkawula@customer.com -ShowProgress $true 
Install-Module -Name AzureAD

get-Mailbox dkawula@customer.com | Format-List IssueWarningQuota,ProhibitSendQuota,ProhibitSendReceiveQuota,UseDatabaseQuotaDefaults

Set-Mailbox -Identity "dkawula@tcustomer.com" -IssueWarningQuota 98gb -ProhibitSendQuota 98gb -ProhibitSendReceiveQuota 99gb -UseDatabaseQuotaDefaults $false -verbose

get-Mailbox dkawula@customer.com | Format-List IssueWarningQuota,ProhibitSendQuota,ProhibitSendReceiveQuota,UseDatabaseQuotaDefaults

#after this verify that your quota looks something like this
#IssueWarningQuota        : 98 GB (105,226,698,752 bytes)
#ProhibitSendQuota        : 98 GB (105,226,698,752 bytes)
#ProhibitSendReceiveQuota : 99 GB (106,300,440,576 bytes)
#UseDatabaseQuotaDefaults : False


#NOTE:  I had to cut a ticket with MSFT Support to get them to run a backend sync on my mailboxes because the quotas were not propogating to their front end farms.
#After this was done it only took an hour and it was good.
