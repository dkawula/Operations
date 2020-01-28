function Wait-PSDirect {
     param
     (
         [string]
         $VMName,

         [Object]
         $cred
     )

    Write-Log $VMName "Waiting for PowerShell Direct (using $($cred.username))"
    while ((Invoke-Command -VMName $VMName -Credential $cred {
                'Test'
    } -ea SilentlyContinue) -ne 'Test') 
    {
        Start-Sleep -Seconds 1
    }
}

function Restart-ProdVM {
     param
     (
         [string]
         $VMName
     )

    Write-Log $VMName 'Rebooting'
    stop-vm $VMName
    start-vm $VMName
}

function Write-Log {
    param
    (
        [string]$systemName,
        [string]$message
    )

    Write-Host -Object (Get-Date).ToShortTimeString() -ForegroundColor Cyan -NoNewline
    Write-Host -Object ' - [' -ForegroundColor White -NoNewline
    Write-Host -Object $systemName -ForegroundColor Yellow -NoNewline
    Write-Host -Object "]::$($message)" -ForegroundColor White
}

Function Install-SQL2019AGClusterPreReq {
    #Installs Failover Clustering and Configures Networking for the AG Cluster

    
    param
    (
        [string]$VMName, 
        [string]$GuestOSName,
        [string]$VMPath,
        [string]$WorkingDir,
        [string]$VirtualSwitchname,
        [string]$DomainName
    )


    If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] “Administrator”))

{
    Write-Warning “You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!”
    Break
}
    #Adding Additional Network Adapter for DAG and HB

    Add-VMNetworkAdapter -VMName $VMName -SwitchName $virtualSwitchName


    Invoke-Command -VMName $VMName -Credential $DomainCred {
    param($VMName, $domainCred, $domainName)
    Write-Output -InputObject "[$($VMName)]:: Installing Clustering"
    $null = Install-WindowsFeature -Name File-Services, Failover-Clustering -IncludeManagementTools
    Rename-NetAdapter -Name 'Ethernet 2' -NewName 'SQLAG' }

    Restart-ProdVM $VMName
    Wait-PSDirect $VMName -cred $DomainCred

    }

Function Configure-SQL2019AGCluster {

  
    param
    (
        [string]$VMName, 
        [string]$VMName2,
        [string]$GuestOSName,
        [string]$VMPath,
        [string]$WorkingDir,
        [string]$VirtualSwitchname,
        [string]$DomainName
    )



    Invoke-Command -VMName $VMName -Credential $domainCred {
  param ($domainName)
  do 
  {
    New-Cluster -Name HACA1-SQLSVRCL1 -Node HACA1-SQLSVR-A,HACA1-SQLSVR-B -NoStorage
  }
  until ($?)
  
  while (!(Test-Connection -ComputerName "$($ClusterName).$($domainName)" -BufferSize 16 -Count 1 -Quiet -ea SilentlyContinue)) 
  {
    ipconfig.exe /flushdns
    Start-Sleep -Seconds 1
  }
} -ArgumentList $domainName



#Configure File Share Witness for Quorum
Invoke-Command -VMName $VMName -Credential $domainCred {
Set-ClusterQuorum -FileShareWitness \\HACA1-dc02\FSW$}

}

$DomainCred = Get-Credential

Install-SQL2019AGClusterPreReq -VMName HACA1-SQLSVR-A -VirtualSwitchname VSW02
Install-SQL2019AGClusterPreReq -VMName HACA1-SQLSVR-B -VirtualSwitchname VSW02

Configure-SQL2019AGCluster -VMName HACA1-SQLSVR-A -VMName2 HACA1-SQLSVR-B -ClusterName HACA1-SQLSVR -DomainName SH.Com


