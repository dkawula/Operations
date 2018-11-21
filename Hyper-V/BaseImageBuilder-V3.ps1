<#
Created:	 2018-11-21
Version:	 3.0
Author       Dave Kawula MVP and Thomas Rayner MVP
Homepage:    http://www.checkyourlogs.net

Disclaimer:
This script is provided "AS IS" with no warranties, confers no rights and 
is not supported by the authors or Checkyourlogs.

Author - Dave Kawula
    Twitter: @DaveKawula
    Blog   : http://www.checkyourlogs.net

Author - Thomas Rayner
    Twitter: @MrThomasRayner
    Blog   : http://workingsysadmin.com


    .Synopsis
    Creates a big demo lab.
    .DESCRIPTION
    Script is used to create base images for the lab

    This Script has been updated for Windows Server 2019 and has Switches to choose the editions of Windows for the Lab
    Gold VHDx Files Reuqired

    For Windows Server 2016 you have to download the latest CU from:http://catalog.update.microsoft.com/v7/site/search.aspx?q=cumulative%20update%20for%20windows%20server%202016%20for%20x64-based%20systems%20

    Just Download the ISO's or Windows Server 2019 and Windows Server 2016 from your MSDN site

    .EXAMPLE
    TODO: Dave, add something more meaningful in here
    .PARAMETER WorkingDir
    Transactional directory for files to be staged and written
    .PARAMETER Organization
    Org that the VMs will belong to
    .PARAMETER Owner
    Name to fill in for the OSs Owner field
    .PARAMETER TimeZone
    Timezone used by the VMs
    .PARAMETER AdminPassword
    Administrative password for the VMs
    .PARAMETER DomainName
    Build a Windows 2019 LTSC GUI (Desktop Experience) Gold VHDx
    .PARAMETER IncludeWIndows2019GUI
     Build a Windows 2019 Core Gold VHDx
    .PARAMETER IncludeWIndows2019Core
     Build a Windows 2016 GUI (Desktop Experience) Gold VHDx
    .PARAMETER IncludeWIndows2019GUI
     Build a Windows 2016 Core Gold VHDx
    .PARAMETER IncludeWIndows2019GUI
     Need a Windows 2019 Product Key - Get it from your MSDN Site
    .PARAMETER WindowsKey2019
     Need a Windows 2016 Product Key - Get it from your MSDN Site
    .PARAMETER WindowsKey2016
   #>

#region Parameters
[cmdletbinding()]
param
( 
    [Parameter(Mandatory)]
    [ValidateScript({ $_ -match '[^\\]$' })] #ensure WorkingDir does not end in a backslash, otherwise issues are going to come up below
    [string]
    $WorkingDir = 'c:\ClusterStoreage\Volume1\DCBuild',

    [Parameter(Mandatory)]
    [string]
    $Organization = 'MVP Rockstars',

    [Parameter(Mandatory)]
    [string]
    $Owner = 'Dave Kawula',

    [Parameter(Mandatory)]
    [ValidateScript({ $_ -in ([System.TimeZoneInfo]::GetSystemTimeZones()).ID })] #ensure a valid TimeZone was passed
    [string]
    $Timezone = 'Pacific Standard Time',

    [Parameter(Mandatory)]
    [string]
    $adminPassword = 'P@ssw0rd',

    [Parameter(Mandatory=$false)] 
    [SWITCH]$IncludeWindows2019GUI, 

    [Parameter(Mandatory=$false)] 
    [SWITCH]$IncludeWindows2019Core,

    [Parameter(Mandatory=$false)] 
    [SWITCH]$IncludeWindows2016GUI, 

    [Parameter(Mandatory=$false)] 
    [SWITCH]$IncludeWindows2016Core,
    
    [Parameter(Mandatory=$false)]
    [string]
    $WindowsKey2019 = 'aaaaa-bbbbb-ccccc-ddddd-eeee',

    [Parameter(Mandatory=$false)]
    [string]
    $WindowsKey2016 = 'aaaaa-bbbbb-ccccc-ddddd-eeee'


   

   


)
#endregion

#region functions ...


function New-UnattendFile 
{
    param
    (
        [string] $filePath
    ) 

    # Reload template - clone is necessary as PowerShell thinks this is a "complex" object
    $unattend = $unattendSource.Clone()
     
    # Customize unattend XML
    Get-UnattendChunk 'specialize' 'Microsoft-Windows-Shell-Setup' $unattend | ForEach-Object -Process {
        $_.RegisteredOrganization = 'Azure Sea Class Covert Trial' #TR-Egg
    }
    Get-UnattendChunk 'specialize' 'Microsoft-Windows-Shell-Setup' $unattend | ForEach-Object -Process {
        $_.RegisteredOwner = 'Thomas Rayner - @MrThomasRayner - workingsysadmin.com' #TR-Egg
    }
    Get-UnattendChunk 'specialize' 'Microsoft-Windows-Shell-Setup' $unattend | ForEach-Object -Process {
        $_.TimeZone = $Timezone
    }
    Get-UnattendChunk 'oobeSystem' 'Microsoft-Windows-Shell-Setup' $unattend | ForEach-Object -Process {
        $_.UserAccounts.AdministratorPassword.Value = $adminPassword
    }
    Get-UnattendChunk 'specialize' 'Microsoft-Windows-Shell-Setup' $unattend | ForEach-Object -Process {
        $_.ProductKey = $WindowsKey
    }

    Clear-File $filePath
    $unattend.Save($filePath)
}


function New-UnattendFile1 
{
    param
    (
        [string] $filePath
    ) 

    # Reload template - clone is necessary as PowerShell thinks this is a "complex" object
    $unattend = $unattendSource.Clone()
     
    # Customize unattend XML
    Get-UnattendChunk 'specialize' 'Microsoft-Windows-Shell-Setup' $unattend | ForEach-Object -Process {
        $_.RegisteredOrganization = 'Azure Sea Class Covert Trial' #TR-Egg
    }
    Get-UnattendChunk 'specialize' 'Microsoft-Windows-Shell-Setup' $unattend | ForEach-Object -Process {
        $_.RegisteredOwner = 'Thomas Rayner - @MrThomasRayner - workingsysadmin.com' #TR-Egg
    }
    Get-UnattendChunk 'specialize' 'Microsoft-Windows-Shell-Setup' $unattend | ForEach-Object -Process {
        $_.TimeZone = $Timezone
    }
    Get-UnattendChunk 'oobeSystem' 'Microsoft-Windows-Shell-Setup' $unattend | ForEach-Object -Process {
        $_.UserAccounts.AdministratorPassword.Value = $adminPassword
    }
    

    Clear-File $filePath
    $unattend.Save($filePath)
}

Function Download-ConvertWindowsImage

{
# Download convert-windowsimage into Temp
    Write-Log "Testing convert-windowsimage presence"
    If ( Test-Path -Path "$($WorkingDir)\Convert-WindowsImage.ps1") {
        Write-Log "`t Convert-windowsimage.ps1 is present, skipping download"
    }else{ 
        Write-Log "`t Downloading Convert-WindowsImage"
        try{
            Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/MicrosoftDocs/Virtualization-Documentation/live/hyperv-tools/Convert-WindowsImage/Convert-WindowsImage.ps1 -OutFile "$($WorkingDir)\Convert-WindowsImage.ps1"
        }catch{
            Write-Log "`t Failed to download convert-windowsimage.ps1!"
        }
    }



}


Function Initialize-BaseImage
{

If ($IncludeWindows2019GUI)

{
    $WindowsKey = $WindowsKey2019
    #New-UnattendFile "$($WorkingDir)\unattend.xml"
    New-UnattendFile1 "$($WorkingDir)\unattend1.xml"


    #Build the Windows 2016 Core Base VHDx for the Lab
    
            if (!(Test-Path "$($BaseVHDPath)\VMServerBase2019.vhdx")) 
                        {
            

            Set-Location $workingdir 
            # Load (aka "dot-source) the Function 
            . .\Convert-WindowsImage.ps1 
            # Prepare all the variables in advance (optional) 
            $ConvertWindowsImageParam = @{  
                SourcePath          = $ServerISO1
                RemoteDesktopEnable = $True  
                Passthru            = $True  
                Edition    = "4"
                VHDFormat = "VHDX"
                SizeBytes = 60GB
                WorkingDirectory = $workingdir
                VHDPath = "$($BaseVHDPath)\VMServerBase2019.vhdx"
                DiskLayout = 'UEFI'
                UnattendPath = "$($workingdir)\unattend1.xml" 
            }

            $VHDx = Convert-WindowsImage @ConvertWindowsImageParam

            }
            }
if ($IncludeWindows2019Core)
{
            
    $WindowsKey = $WindowsKey2019
    #New-UnattendFile "$($WorkingDir)\unattend.xml"
    New-UnattendFile1 "$($WorkingDir)\unattend1.xml"
  

      
            if (!(Test-Path "$($BaseVHDPath)\VMServerCore2019.vhdx")) 
                        {
            

            Set-Location $workingdir 
            # Load (aka "dot-source) the Function 
            . .\Convert-WindowsImage.ps1 
            # Prepare all the variables in advance (optional) 
            $ConvertWindowsImageParam = @{  
                SourcePath          = $ServerISO1
                RemoteDesktopEnable = $True  
                Passthru            = $True  
                Edition    = "3"
                VHDFormat = "VHDX"
                SizeBytes = 60GB
                WorkingDirectory = $workingdir
                VHDPath = "$($BaseVHDPath)\VMServerCore2019.vhdx"
                DiskLayout = 'UEFI'
                UnattendPath = "$($workingdir)\unattend1.xml" 
            }

            $VHDx = Convert-WindowsImage @ConvertWindowsImageParam

            }
            }

if ($IncludeWindows2016GUI)

{

            $WindowsKey = $WindowsKey2016
            New-UnattendFile "$($WorkingDir)\unattend.xml"
            
          
    
            if (!(Test-Path "$($BaseVHDPath)\VMServerBase2016.vhdx")) 
                        {
            

            Set-Location $workingdir 

            # Load (aka "dot-source) the Function 
            . .\Convert-WindowsImage.ps1 
            # Prepare all the variables in advance (optional) 
            $ConvertWindowsImageParam = @{  
                SourcePath          = $ServerISO
                RemoteDesktopEnable = $True  
                Passthru            = $True  
                Edition    = "4"
                VHDFormat = "VHDX"
                SizeBytes = 60GB
                WorkingDirectory = $workingdir
                VHDPath = "$($BaseVHDPath)\VMServerBase2016.vhdx"
                DiskLayout = 'UEFI'
                UnattendPath = "$($workingdir)\unattend.xml" 
                Package = @(  
                             "$LatestCU"    
                            )  


            }

            $VHDx = Convert-WindowsImage @ConvertWindowsImageParam

            }
            }

if ($IncludeWindows2016Core)
{
            $WindowsKey = $WindowsKey2016
            New-UnattendFile "$($WorkingDir)\unattend.xml"
          
    
            if (!(Test-Path "$($BaseVHDPath)\VMServerCore2016.vhdx")) 
                        {
            

            Set-Location $workingdir 

            # Load (aka "dot-source) the Function 
            . .\Convert-WindowsImage.ps1 
            # Prepare all the variables in advance (optional) 
            $ConvertWindowsImageParam = @{  
                SourcePath          = $ServerISO
                RemoteDesktopEnable = $True  
                Passthru            = $True  
                Edition    = "3"
                VHDFormat = "VHDX"
                SizeBytes = 60GB
                WorkingDirectory = $workingdir
                VHDPath = "$($BaseVHDPath)\VMServerCore2016.vhdx"
                DiskLayout = 'UEFI'
                UnattendPath = "$($workingdir)\unattend.xml" 
                Package = @(  
                            "$LatestCU"  
                            )  


            }

            $VHDx = Convert-WindowsImage @ConvertWindowsImageParam

            }
            }
    
    Clear-File "$($BaseVHDPath)\unattend.xml"
    Clear-File "$($BaseVHDPath)\unattend1.xml"
    Dismount-DiskImage $ServerISO -ErrorAction SilentlyContinue
    Dismount-DiskImage $ServerISO1 -ErrorAction SilentlyContinue
    #Clear-File "$($WorkingDir)\Convert-WindowsImage.ps1"

}


function Download-BaseImageUpdates
{

 
            if (!(Test-Path "$($BaseVHDPath)\windows10.0-kb3213986-x64_a1f5adacc28b56d7728c92e318d6596d9072aec4.msu")) 
                        {
    Invoke-WebRequest -Uri http://download.windowsupdate.com/d/msdownload/update/software/secu/2016/12/windows10.0-kb3213986-x64_a1f5adacc28b56d7728c92e318d6596d9072aec4.msu -OutFile "$($BaseVHDPath)\windows10.0-kb3213986-x64_a1f5adacc28b56d7728c92e318d6596d9072aec4.msu" -Verbose
    }
    }


function Get-LatestCU
{

        [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
        $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            Title="Please select .MSU Update Package for Windows 2016"
        }
        $openFile.Filter = "msu files (*.msu)|*.msu|All files (*.*)|*.*" 
        If($openFile.ShowDialog() -eq "OK")
        {
            Write-Log  "File $($openfile.FileName) selected"
        } 
        if (!$openFile.FileName){
                WriteErrorAndExit  "msu was not selected... Exitting"
            }
            $LatestCU = $openfile.FileName
            #$ServerISO
        }




function Get-ISOUI {
#Ask for ISO

        [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
        $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            Title="Please select ISO image with Windows Server 2016"
        }
        $openFile.Filter = "iso files (*.iso)|*.iso|All files (*.*)|*.*" 
        If($openFile.ShowDialog() -eq "OK")
        {
            Write-Log  "File $($openfile.FileName) selected"
        } 
        if (!$openFile.FileName){
                WriteErrorAndExit  "Iso was not selected... Exitting"
            }
            $ServerISO = $openfile.FileName
            #$ServerISO
        }

function Get-ISOUI1 {
#Ask for ISO 

        [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
        $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            Title="Please select ISO image with Windows Server 2019"
        }
        $openFile.Filter = "iso files (*.iso)|*.iso|All files (*.*)|*.*" 
        If($openFile.ShowDialog() -eq "OK")
        {
            Write-Log  "File $($openfile.FileName) selected"
        } 
        if (!$openFile.FileName){
                WriteErrorAndExit  "Iso was not selected... Exitting"
            }
             $ServerISO1 = $openfile.FileName
             $ServerISO1
        }

function Confirm-Path
{
    param
    (
        [string] $path
    )
    if (!(Test-Path $path)) 
    {
        $null = mkdir $path
    }
}

function Write-Log 
{
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

function Clear-File
{
    param
    (
        [string] $file
    )
    
    if (Test-Path $file) 
    {
        $null = Remove-Item $file -Recurse
    }
}

function Get-UnattendChunk 
{
    param
    (
        [string] $pass, 
        [string] $component, 
        [xml] $unattend
    ) 
    
    return $unattend.unattend.settings |
    Where-Object -Property pass -EQ -Value $pass `
    |
    Select-Object -ExpandProperty component `
    |
    Where-Object -Property name -EQ -Value $component
}

#endregion

#region Variable Init
$BaseVHDPath = "$($WorkingDir)\BaseVHDs"

#$ServerISO = Get-ISOUI #ISO for Windows Server 2016
#$ServerISO
#$ServerISO1 = Get-ISOUI1 #ISO for Windows Insider
#$ServerISO1



$unattendSource = [xml]@"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <servicing></servicing>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <ComputerName>*</ComputerName>
            <ProductKey>$WindowsKey</ProductKey> 
            <RegisteredOrganization>Organization</RegisteredOrganization>
            <RegisteredOwner>Owner</RegisteredOwner>
            <TimeZone>TZ</TimeZone>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideLocalAccountScreen>true</HideLocalAccountScreen>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <NetworkLocation>Work</NetworkLocation>
                <ProtectYourPC>1</ProtectYourPC>
            </OOBE>
            <UserAccounts>
                <AdministratorPassword>
                    <Value>password</Value>
                    <PlainText>True</PlainText>
                </AdministratorPassword>
            </UserAccounts>
        </component>
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>en-us</InputLocale>
            <SystemLocale>en-us</SystemLocale>
            <UILanguage>en-us</UILanguage>
            <UILanguageFallback>en-us</UILanguageFallback>
            <UserLocale>en-us</UserLocale>
        </component>
    </settings>
</unattend>
"@
#endregion


Write-Log 'Host' 'Getting started...'
Confirm-Path $BaseVHDPath
Write-Log 'Host' 'Building Base Images'
Write-Log 'Host' 'Downloading January 2018 CU for Windows Server 2016'
Write-Log 'Host' 'Locate the Windows Server 2016 ISO'
 if ($IncludeWindows2016GUI)

 {
 . Get-ISOUI
 . Get-LatestCU
 }

 elseif ($IncludeWindows2016Core)
 {
 . Get-ISOUI
 . Get-LatestCU
 }
 
 
 
Write-Log 'Host' 'Locate the Windows Windows Server 2016 ISO'
   
if ($IncludeWindows2019GUI)
{   
    . Get-ISOUI1
    }
elseif ($IncludeWindows2019Core)
{
    . Get-ISOUI1
}
 

Write-Log $ServerISO
Write-Log $ServerISO1
     . Download-ConvertWindowsImage
   
     . Initialize-BaseImage

Write-Log 'Host' 'Tasks Complete'
