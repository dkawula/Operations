# The Output will be written to this file in the current working directory 
$LogFile = "Office_365_Licenses.csv" 
 
# Connect to Microsoft Online 
Import-Module MSOnline 
Connect-MsolService -Credential $cred
 
write-host "Connecting to Office 365..." 
 
# Get a list of all licences that exist within the tenant 
$licensetype = Get-MsolAccountSku | Where {$_.ConsumedUnits -ge 1} 
 
# Loop through all licence types found in the tenant 
foreach ($license in $licensetype)  
{     
    # Build and write the Header for the CSV file 
    $headerstring = "DisplayName,UserPrincipalName,AccountSku" 
     
    foreach ($row in $($license.ServiceStatus))  
    { 
        $headerstring = ($headerstring + "," + $row.ServicePlan.servicename) 
    } 
     
    Out-File -FilePath $LogFile -InputObject $headerstring -Encoding UTF8 -append 
     
    write-host ("Gathering users with the following subscription: " + $license.accountskuid) 
 
    # Gather users for this particular AccountSku 
    $users = Get-MsolUser -all | where {$_.isLicensed -eq "True" -and $_.licenses.accountskuid -contains $license.accountskuid} 
 
    # Loop through all users and write them to the CSV file 
    foreach ($user in $users) { 
         
        write-host ("Processing " + $user.displayname) 
 
        $thislicense = $user.licenses | Where-Object {$_.accountskuid -eq $license.accountskuid} 
 
        $datastring = ($user.displayname + "," + $user.userprincipalname + "," + $license.SkuPartNumber) 
         
        foreach ($row in $($thislicense.servicestatus)) { 
             
            # Build data string 
            $datastring = ($datastring + "," + $($row.provisioningstatus)) 
        } 
         
        Out-File -FilePath $LogFile -InputObject $datastring -Encoding UTF8 -append 
    } 
 
    Out-File -FilePath $LogFile -InputObject " " -Encoding UTF8 -append 
}             
 
write-host ("Script Completed.  Results available in " + $LogFile)