#Install the Required Modules for this Script

Install-Module PSWriteHTML
Install-WindowsFeature -Name RSAT-AD-PowerShell
Install-WindowsFeature -Name Hyper-V-PowerShell

#Test Server Function to check connectivity
Function Test-Server {
        [CmdletBinding()]
                
        # Parameters used in this function
        param
        ( 
            [Parameter(Position=0, Mandatory = $true, HelpMessage="Provide server names", ValueFromPipeline = $false)] 
            $ComputerName
        ) 
 
        $Array = @()
 
        ForEach($Server in $ComputerName)
        {
            $Server = $Server.Trim()
 
            Write-Verbose "Checking $Server"
 
            $SMB = $null
            $Object = $null
            $Status = $null
 
            $SMB = Test-Path "\\$server\c$"
 
            If($SMB -eq "True")
            {
                Write-Verbose "$Server is up"
                $Status = "True"
                $Object = New-Object PSObject -Property ([ordered]@{ 
                      
                    Server                = $Server
                    "Is Online?"          = $Status
                })
    
                $Array += $Object
            }
            Else
            {
                Write-Verbose "$Server is down"
                $Status = "False"
                $Object = New-Object PSObject -Property ([ordered]@{ 
                      
                    Server                = $Server
                    "Is Online?"          = $Status
  
                })
    
                $Array += $Object
            }
        }
 
    If($Array)
    {
        return $Array
    }
}

#Get-HyperVServersinAD
#I had an issue where the SCP's were not defined on two of my cluster nodes
#Had to manually create the object and then the script worked

function Get-HyperVServersInAD {            
[cmdletbinding()]            
param(            
)            
try {            
 Import-Module ActiveDirectory -ErrorAction Stop            
} catch {            
 Write-Warning "Failed to import Active Directory module. Exiting"            
 return            
}            

try {            
 $Hypervs = Get-ADObject -Filter 'ObjectClass -eq "serviceConnectionPoint" -and Name -eq "Microsoft Hyper-V"' -ErrorAction Stop            
} catch {            
 Write-Error "Failed to query active directory. More details : $_"            
}            
foreach($Hyperv in $Hypervs) {            
 $temp = $Hyperv.DistinguishedName.split(",")            
 $HypervDN = $temp[1..$temp.Count] -join ","            
 $Comp = Get-ADComputer -Id $HypervDN -Prop *            
 $OutputObj = New-Object PSObject -Prop (            
 @{            
  HyperVName = $Comp.Name            
  OSVersion = $($comp.operatingSystem)            
 })            
 $OutputObj            
}            
}

$HyperVServers = Get-HyperVServersInAD
$HyperVServers1 = $HypervServers.HyperVName
$HyperVServers1


ForEach ($HyperVNode in $HyperVServers1) {
Try{
Write-Host "Gathering VM INfo for $HyperVNode"
$HypervVms += Invoke-Command $HyperVNode {Get-VM}
#$output += $HypervVMs | ConvertTo-Html
}
Catch{
"Connection Error: $HyperVNode" 

$ConnectionErrors += "Connection Error: $HyperVNode" 

}
}

$HypervVms | Where VMName -notlike *Replica* | Select VMName,PSComputerName,State,UpTime,Version,Generation,IntegrationServiceState,OperationalStatus,CPUUsage,ProcessorCount,MemoryAssigned,MemoryDemand,MemoryStatus,MemoryStartup,DynamicMemoryEnabled,MemoryMinimum,MemoryMaximum,IntegrationServicesVersion,ResourceMeteringEnabled,ConfigurationLocation,SnapshotFileLocation,AutomaticStartAction,AutomaticStopAction,AutomaticStartDelay,SmartPagingFilePath,NumaAligned,NumaNodesCount,NumaSocketCount,IsClustered,SizeofSystemFiles,ParentSnapshotId,ParentSnapshotName| Out-GridHtml -Title "Standalone HVHosts" 
$HypervVms | Where VMName -like *Replica* | Select VMName,PSComputerName,State,UpTime,Version,Generation,IntegrationServiceState,OperationalStatus,CPUUsage,ProcessorCount,MemoryAssigned,MemoryDemand,MemoryStatus,MemoryStartup,DynamicMemoryEnabled,MemoryMinimum,MemoryMaximum,IntegrationServicesVersion,ResourceMeteringEnabled,ConfigurationLocation,SnapshotFileLocation,AutomaticStartAction,AutomaticStopAction,AutomaticStartDelay,SmartPagingFilePath,NumaAligned,NumaNodesCount,NumaSocketCount,IsClustered,SizeofSystemFiles,ParentSnapshotId,ParentSnapshotName| Out-GridHtml -Title "Replica VMs" 
$HypervVms | Where IsClustered -eq True | Select VMName,PSComputerName,State,UpTime,Version,Generation,IntegrationServiceState,OperationalStatus,CPUUsage,ProcessorCount,MemoryAssigned,MemoryDemand,MemoryStatus,MemoryStartup,DynamicMemoryEnabled,MemoryMinimum,MemoryMaximum,IntegrationServicesVersion,ResourceMeteringEnabled,ConfigurationLocation,SnapshotFileLocation,AutomaticStartAction,AutomaticStopAction,AutomaticStartDelay,SmartPagingFilePath,NumaAligned,NumaNodesCount,NumaSocketCount,IsClustered,SizeofSystemFiles,ParentSnapshotId,ParentSnapshotName| Out-GridHtml -Title "HCI Clusters" 
$TestConnectivity | Test-Server -ComputerName $HyperVServers1 -verbose | Out-GridHtml -Title "Connectivity Checks" 
$ConnectionErrors | Out-GridHtml -Title "Connection Errors" 

