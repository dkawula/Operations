Import-Module 'C:\post-install\005 - Install-VMWUUpdatesPSDirect\Install-VMWUUpdates - Copy.ps1'


$cred = Get-Credential

$Node = Get-VM 
$Nodes1 = $Node | Where-Object VMName -NE HACA1-DC01
$Nodes = $Nodes1.VMName
$Nodes

Foreach ($Node in $Nodes) {

TRY{
Restart-DemoVM -VMName $Node
Wait-PSDirect -VMName $Node -cred $cred
Invoke-Command -VMName $Node -Credential $Cred {
Write-Host ($Node) "Working on Update Pass 1"
Get-ExecutionPolicy
Set-Executionpolicy bypass
#Unblock-File \\HACA1-DC01\scripts$\Install-VMWUUpdates.ps1
import-module \\HACA1-DC01\scripts$\Install-VMWUUpdates.ps1 -force -WarningAction Continue
Install-VMWUUpdatesPSDirect -InstallUpdates Yes -RebootNow Yes
#Set-ExecutionPolicy RemoteSigned
#Get-ExecutionPolicy
}


Wait-PSDirect -VMName $Node -cred $cred
Restart-DemoVM -VMName $Node
Wait-PSDirect -VMName $Node -cred $cred

Invoke-Command -VMName $Node -Credential $Cred {
Write-Host ($Node) "Working on Update Pass 2"
#Get-ExecutionPolicy
#Set-Executionpolicy unrestricted
#Unblock-File \\HACA1-DC01\scripts$\Install-VMWUUpdates.ps1
import-module \\HACA1-DC01\scripts$\Install-VMWUUpdates.ps1 -force -WarningAction Continue
Install-VMWUUpdatesPSDirect -InstallUpdates Yes -RebootNow Yes
#Set-ExecutionPolicy RemoteSigned
#Get-ExecutionPolicy
}

Wait-PSDirect -VMName $Node -cred $cred
Restart-DemoVM -VMName $Node
Wait-PSDirect -VMName $Node -cred $cred

Invoke-Command -VMName $Node -Credential $Cred {
Write-Host ($Node) "Working on Update Pass 3"
#Get-ExecutionPolicy
#Set-Executionpolicy unrestricted
#Unblock-File \\HACA1-DC01\scripts$\Install-VMWUUpdates.ps1
import-module \\HACA1-DC01\scripts$\Install-VMWUUpdates.ps1 -force -WarningAction Continue
Install-VMWUUpdatesPSDirect -InstallUpdates Yes -RebootNow Yes
#Set-ExecutionPolicy RemoteSigned
#Get-ExecutionPolicy
}

Wait-PSDirect -VMName $Node -cred $cred
Restart-DemoVM -VMName $Node
Wait-PSDirect -VMName $Node -cred $cred

Invoke-Command -VMName $Node -Credential $Cred {
Write-Host ($Node) "Working on Update Pass 4"
#Get-ExecutionPolicy
#Set-Executionpolicy unrestricted
#Unblock-File \\HACA1-DC01\scripts$\Install-VMWUUpdates.ps1
import-module \\HACA1-DC01\scripts$\Install-VMWUUpdates.ps1 -force -WarningAction Continue
Install-VMWUUpdatesPSDirect -InstallUpdates Yes -RebootNow Yes
Set-ExecutionPolicy RemoteSigned
Get-ExecutionPolicy}


Wait-PSDirect -VMName $Node -cred $cred
Restart-DemoVM -VMName $Node
Wait-PSDirect -VMName $Node -cred $cred
}
Catch {

"Error Contacting Server: $Node"


}


} #Run Update Pass 4 Times on $Nodes Array


