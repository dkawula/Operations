$Cred = Get-Credential
Connect-MsolService -Credential $cred
Get-MSolUser -all | select userprincipalname,licenses | Out-GridView