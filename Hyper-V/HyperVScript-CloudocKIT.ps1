#Grab All of the Servers from AD running Hyper-V

if (!(get-module -name "ActiveDirectory") ){
    Add-WindowsFeature RSAT-AD-PowerShell | out-null;
    import-module -name "ActiveDirectory" -DisableNameChecking | out-null;
    }

function List-hyperVHosts {            
  [cmdletbinding()]            
  param(
  	[string]$forest
  )            
  try {            
   Import-Module ActiveDirectory -ErrorAction Stop            
  } catch {            
   Write-Warning "Failed to import Active Directory module. Cannot continue. Aborting..."            
   break;
  }            

  $domains=(Get-ADForest -Identity $forest).Domains 
  foreach ($domain in $domains){
  #"$domain`: `n"
  [string]$dc=(get-addomaincontroller -DomainName $domain -Discover -NextClosestSite).HostName
  try {             
   $hyperVs = Get-ADObject -Server $dc -Filter 'ObjectClass -eq "serviceConnectionPoint" -and Name -eq "Microsoft Hyper-V"' -ErrorAction Stop;
  } catch {            
   "Failed to query $dc of $domain";         
  }            
  foreach($hyperV in $hyperVs) {            
     $x = $hyperV.DistinguishedName.split(",")            
     $HypervDN = $x[1..$x.Count] -join ","  
      
     if ( !($HypervDN -match "CN=LostAndFound")) {     
     $Comp = Get-ADComputer -Id $HypervDN -Prop *
     $OutputObj = New-Object PSObject -Prop (
     @{
     HyperVName = $Comp.Name
     OSVersion = $($comp.operatingSystem)
     })
     $OutputObj
     }           
   }
   }
}

function listForests{
	$GLOBAL:forests=Get-ADForest | select Name;
	if ($forests.length -gt 1){
		#for ($i=0;$i -lt $forests.length;$i++){$forests[$i].Name;}
		$forests | %{$_.Name;}
	}else{
		$forests.Name;
	}
}

function listHyperVHostsInForests{
	listForests|%{List-HyperVHosts $_}
}

listHyperVHostsInForests
listHyperVHostsInForests | measure

$Nodes1 = listHyperVHostsInForests

$nodes = $nodes1.HyperVName
$nodes

#GatherHyper-V Reporting Info

Foreach ($Node in $nodes){
If (Test-Connection -ComputerName $node -Quiet ) { 
Write-host $Node is "online"

Write-host Gathering Hyper-V Inventory for $Node
invoke-command $node{

$path = "C:\Post-Install\999-HVDocs"
If(!(test-path -PathType container $path))
{
      New-Item -ItemType Directory -Path $path
}

$virtualMachinesJSON = Get-VM | ConvertTo-Json -Compress -Depth 5
$hostJSON = Get-VMHost| ConvertTo-Json -Compress -Depth 5
$onPremConfigurationJSON = "{`"exportType`" : `"hyperV`",`"exportVersion`" : `"1.0`", `"virtualMachines`" : $virtualMachinesJSON, `"host`" : $hostJSON }"
$onPremConfigurationJSON > "c:\post-install\999-HVDocs\$env:computername-cdk-export.json" 
}

Write-Host "Copying Inventory to \\YOURSERVER\upload$"
Copy-item -path "\\$($Node)\c$\Post-install\999-HVDocs\$($node)-cdk-export.json" -Destination "C:\Post-Install\009-CloudOCKIT\Upload$" -force -Verbose
  }
  
  Else
     {
     Write-Host $Node is "offline"
     }
     }
     
