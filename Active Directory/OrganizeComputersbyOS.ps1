<#

Move Client computers to Organised OU Based on Operating System.
By Dave Kawula MVP


#>
Import-Module ActiveDirectory
 

$os7  = "Windows 7"
$os8  = "Windows 8" #includes 8.1 as well
$os10 = "Windows 10"
$os11 = "Windows 11"
 

# OU Locations change to what you have
$DestOU1 = "OU=windows 7,OU=Company Computers,DC=CompanyCorp,DC=com" 
$DestOU2 = "OU=windows 8,OU=Company Computers,DC=CompanyCorp,DC=com" 
$DestOU3 = "OU=windows 10,OU=Company Computers,DC=CompanyCorp,DC=com"
$DestOU4 = "OU=Windows 11,OU=Company Computers,DC=CompanyCorp,DC=com"



$computers = Get-ADComputer -Filter * -searchbase 'OU=Company Computers,DC=CompanyCorp,DC=COM' -Properties OperatingSystem

$computers | Out-GridView

$computers | measure
 
foreach($computer in $computers)
    {
$DistinguishedNme = $computer.DistinguishedName.Tostring()
$op = $computer.OperatingSystem
    if($op -match $os7){
        Move-ADobject -Identity $DistinguishedNme -TargetPath $DestOU1 -Verbose
    }
    ElseIf ($op -match $os8) {
        Move-ADobject -Identity $DistinguishedNme -TargetPath $DestOU2 -Verbose
    }
    ElseIf ($op -match $os10) {
        Move-ADobject -Identity $DistinguishedNme -TargetPath $DestOU3 -Verbose
    }
     ElseIf ($op -match $os11) {
        Move-ADobject -Identity $DistinguishedNme -TargetPath $DestOU4 -Verbose
    }

    else{
        write-output "Unknown OS or not specified $($computer.name) , $($Op)" |out-file c:\post-install\computersnotfound.txt -Append
   }
   }