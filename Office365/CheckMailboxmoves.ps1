#Connect to Office 365
$usercredential = get-credential
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection
Import-PSSession $Session

Get-MoveRequest | where {$_.status -notlike “complete*”} | Get-MoveRequestStatistics | Select DisplayName,status,percentcomplete,itemstransferred

Get-MoveRequest 
Get-MigrationUserStatistics