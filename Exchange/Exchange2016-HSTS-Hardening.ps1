#Harden Exchange Server 2016 with HSTS

Import-Module IISAdministration
Reset-IISServerManager -Confirm:$false
Start-IISCommitDelay

$iisConfig = Get-IISConfigSection -SectionPath "system.webServer/httpProtocol" -CommitPath "Default Web Site" | Get-IISConfigCollection -CollectionName "customHeaders"
New-IISConfigCollectionElement -ConfigCollection $iisConfig -ConfigAttribute @{"name"="Strict-Transport-Security"; "value"="max-age=31536000; includeSubDomains";} #MaxAge 31536000 = 1 year




Stop-IISCommitDelay
Remove-Module IISAdministration
