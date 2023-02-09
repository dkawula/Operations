#Hyper-V Cluster Daily Reporting
#Wrapper Script Great for running against multiple clusters in an environment

$nodes = 'S2DCLU02','S2DCLU02','S2DCLU01','S2DCLU01','S2DCLU01'
$nodes

#GatherHyper-V Reporting Info

Foreach ($Node in $nodes){
If (Test-Connection -ComputerName $node -Quiet ) { 
Write-host $Node is "online"

Write-host Running S2D Daily Report on Cluster $Node

$path = "C:\Post-Install\098-AuditS2D-EMAIL"
If(!(test-path -PathType container $path))
{
      New-Item -ItemType Directory -Path $path
}

Set-Location $path
.\Audit-S2D.ps1 -ClusterName $($Node) -DomainName 'Company.com' -Path $($path)

}

  }
  
  Else
     {
     Write-Host $Node is "offline"
     }
     