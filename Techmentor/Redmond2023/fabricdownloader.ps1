<#
Created:	 2022-08-30
Version:	 1.0
Author       Dave Kawula MVP
Homepage:    http://www.checkyourlogs.net

Disclaimer:
This script is provided "AS IS" with no warranties, confers no rights and 
is not supported by the authors or Checkyourlogs.net

Author - Dave Kawula
    Twitter: @DaveKawula
    Blog   : http://www.checkyourlogs.net

    .Synopsis
    Downloads Required Files for Dark Fabric Builder
    .DESCRIPTION
    
    TBA
  
#>

<#> Download Links
#Download SQL 2019 Standard ISO -  to Download Manually
#Download SCOM 2022 ISO -  to Download Manually
#Download Server 2022 ISO -  to Download Manually
#Download SQL Server Management Studio
#Download SQL Server 2019 CU17 Cumulative Update
#Download Server 2022 August 2022 Cumulative Update - Offline
#Download Server 2019 August 2022 Cumulative Update - Offline
#Download CIS 2022 Benchmark ZIP - Dave's Repo
#Download CIS 2019 Benchmark ZIP - Dave's Repo
#Download Security Compliance Toolkit - Dave's Repo
#Download LAPS-X64.MSI - Dave's Repo
#Download SQL OLE 19.00
#Download ODBC 18.1
#Download Visual Studio Resitributables


#https://go.microsoft.com/fwlink/?linkid=2186934 - SQL OLE 19.00
#https://go.microsoft.com/fwlink/?linkid=2202930 - ODBC 18.1
#https://aka.ms/vs/17/release/vc_redist.x86.exe
#https://aka.ms/ssmsfullsetup
#https://download.microsoft.com/download/6/e/7/6e72dddf-dfa4-4889-bc3d-e5d3a0fd11ce/SQLServer2019-KB5016394-x64.exe
#https://github.com/dkawula/FBFabric/blob/main/Downloads/LAPS.x64.msi
#https://github.com/dkawula/FBFabric/blob/main/Downloads/SecurityComplianceToolkitMSFT.zip
#https://github.com/dkawula/FBFabric/blob/main/Downloads/Server2019v1.3.0%20(1).zip
#https://github.com/dkawula/FBFabric/blob/main/Downloads/Server2022v1.0.0.zip

</#>

#region Parameters
[cmdletbinding()]
param
( 
    [Parameter(Mandatory)]
    [ValidateScript( { $_ -match '[^\\]$' })] #ensure WorkingDir does not end in a backslash, otherwise issues are going to come up below
    [string]
    $DestinationDir = 'c:\ClusterStoreage\Volume1\DCBuild'

 )

#endregion

#region 001-Downloads

Write-Output "Downloading SQL OLE 19.00 ..."     
$sourceURI = "https://go.microsoft.com/fwlink/?linkid=2186934"
$Destinationfilename = "$DestinationDir\msoledbsql.msi"
invoke-webrequest -UseBasicParsing -Uri "$sourceURI" -outfile "$destinationfilename" -passthru | select -Expand headers -verbose

Write-Output "Downloading SQL ODBC 18.1 ..."     
$sourceURI = "https://go.microsoft.com/fwlink/?linkid=2202930"
$Destinationfilename = "$DestinationDir\msodbcsql.msi"
invoke-webrequest -UseBasicParsing -Uri "$sourceURI" -outfile "$destinationfilename" -passthru | select -Expand headers -verbose

Write-Output "Downloading Visual Studio Redist ..."     
$sourceURI = "https://aka.ms/vs/17/release/vc_redist.x86.exe"
$Destinationfilename = "$DestinationDir\VC_redist-x64.msi"
invoke-webrequest -UseBasicParsing -Uri "$sourceURI" -outfile "$destinationfilename" -passthru | select -Expand headers -verbose

Write-Output "Downloading SQL Server Management Studio ..."     
$sourceURI = "https://aka.ms/ssmsfullsetup"
$Destinationfilename = "$DestinationDir\SSMS-Setup-ENU.exe"
invoke-webrequest -UseBasicParsing -Uri "$sourceURI" -outfile "$destinationfilename" -passthru | select -Expand headers -verbose

Write-Output "Downloading SQL Server 2019 CU17 ..."     
$sourceURI = "https://download.microsoft.com/download/6/e/7/6e72dddf-dfa4-4889-bc3d-e5d3a0fd11ce/SQLServer2019-KB5016394-x64.exe"
$Destinationfilename = "$DestinationDir\SQLServer2019-KB5016394-x64.exe"
invoke-webrequest -UseBasicParsing -Uri "$sourceURI" -outfile "$destinationfilename" -passthru | select -Expand headers -verbose

<#>

Write-Output "Downloading Microsoft LAPS x64 ..."     
$sourceURI = 
$Destinationfilename = "$DestinationDir\LAPS-x64.msi"
invoke-webrequest -UseBasicParsing -Uri "$sourceURI" -outfile "$destinationfilename" -passthru | select -Expand headers -verbose

Write-Output "Downloading Microsoft Security Compliance Toolkit 2019/2022 ..."     
$sourceURI = 
$Destinationfilename = "$DestinationDir\SecurityComplianceToolkitMSFT.ZIP"
invoke-webrequest -UseBasicParsing -Uri "$sourceURI" -outfile "$destinationfilename" -passthru | select -Expand headers -verbose

Write-Output "Downloading CIS Benchmark for Server 2019 v1.3 ..."     
$sourceURI = 
$Destinationfilename = "$DestinationDir\Server2019v1.3.0.zip"
invoke-webrequest -UseBasicParsing -Uri "$sourceURI" -outfile "$destinationfilename" -passthru | select -Expand headers -verbose

Write-Output "Downloading CIS Benchmark for Server 2022 v1.0 ..."     
$sourceURI = 
$Destinationfilename = "$DestinationDir\Server2022v1.0.0.zip"
invoke-webrequest -UseBasicParsing -Uri "$sourceURI" -outfile "$destinationfilename" -passthru | select -Expand headers -verbose
</#>
#endregion