$Cred = Get-Credential
Connect-MsolService -Credential $cred
Get-MsolAccountSku
$SKU = "reseller-account:ATP_Enterprise"

#Remove ATP LIcenses from EXTERNAL Users that should have it
Get-MsolUser | where UserPrincipalName -like "*EXT*" | Out-GridView
Get-MsolUser | where UserPrincipalName -like "*EXT*" | Set-MsolUserLicense -RemoveLicenses $sku
Get-MsolUser | where UserPrincipalName -eq "hysys@epfccorp.com" | Set-MsolUserLicense -RemoveLicenses $sku -verbose
#$import | ForEach-Object {Set-MsolUserLicense -UserPrincipalName $_ -RemoveLicenses $sku -Verbose}

$users = Get-MsolUser -all | where {$_.isLicensed -eq "True" -and $_.licenses.accountskuid -contains $license.accountskuid} | fl
$users

#Figure Out all of the Users that have ATP Enabled
Get-MSolUser -all | where {$_.isLicensed -eq "True" -and $_.licenses.accountskuid -contains $sku} | Out-GridView

#Figure out all of the Users that have ATP Missing
Get-MSolUser -all | where {$_.isLicensed -eq "True" -and $_.licenses.accountskuid -notcontains $sku} | Out-GridView

Get-MSolUser -all | where {$_.isLicensed -eq "True" -and $_.licenses.accountskuid -isnot $sku} | Out-GridView


Get-MSolUser -all | select userprincipalname,licenses | Out-GridView

$import = Get-Content G:\temp\o365fix.txt
$import
Get-MsolUser | Select UserPrincipalName, IsLicensed | Out-GridView



