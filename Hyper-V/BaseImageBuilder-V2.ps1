<#
Created:	 2017-01-02
Version:	 1.0
Author       Dave Kawula MVP and Thomas Rayner MVP
Homepage:    http://www.checkyourlogs.net

Disclaimer:
This script is provided "AS IS" with no warranties, confers no rights and 
is not supported by the authors or DeploymentArtist.

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

    You will need to change the <ProductKey> Variable as it has been removed for the purposes of the print in this book.

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
    $adminPassword = 'P@ssw0rd'

   

   


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

Function Initialize-BaseImage
{

    Mount-DiskImage $ServerISO
    $DVDDriveLetter = (Get-DiskImage $ServerISO | Get-Volume).DriveLetter
    Copy-Item -Path "$($DVDDriveLetter):\NanoServer\NanoServerImageGenerator\Convert-WindowsImage.ps1" -Destination "$($WorkingDir)\Convert-WindowsImage.ps1" -Force
    Import-Module -Name "$($DVDDriveLetter):\NanoServer\NanoServerImagegenerator\NanoServerImageGenerator.psm1" -Force
   
 <#>
            if (!(Test-Path "$($BaseVHDPath)\NanoBase.vhdx")) 
            {
            New-NanoServerImage -MediaPath "$($DVDDriveLetter):\" -BasePath $BaseVHDPath -TargetPath "$($BaseVHDPath)\NanoBase.vhdx" -Edition Standard -DeploymentType Guest -Compute -Clustering -AdministratorPassword (ConvertTo-SecureString $adminPassword -AsPlainText -Force)
           # New-NanoServerImage -MediaPath "$($DVDDriveLetter):\" -BasePath $BaseVDHPath -TargetPath "$($BaseVHDPath)\NanoBase.vhdx" -GuestDrivers -DeploymentType Guest -Edition Standard -Compute -Clustering -Defender -Storage -AdministratorPassword (ConvertTo-SecureString $adminPassword -AsPlainText -Force)

            
            }
</#>

    #Copy-Item -Path '$WorkingDir\Convert-WindowsImage.ps1' -Destination "$($WorkingDir)\Convert-WindowsImage.ps1" -Force
    New-UnattendFile "$WorkingDir\unattend.xml"
    New-UnattendFile1 "$WorkingDir\unattend1.xml"


    #Build the Windows 2016 Core Base VHDx for the Lab
    
            if (!(Test-Path "$($BaseVHDPath)\VMServerBaseCore.vhdx")) 
                        {
            

            Set-Location $workingdir 
            #Watch the Editions --> 17079 is SERVERDATACENTERACORE and 2016 is SERVERDATACENTERCORE
            # Load (aka "dot-source) the Function 
            . .\Convert-WindowsImage.ps1 
            # Prepare all the variables in advance (optional) 
            $ConvertWindowsImageParam = @{  
                SourcePath          = $ServerISO1
                RemoteDesktopEnable = $True  
                Passthru            = $True  
                Edition    = "SERVERDATACENTERACORE"
                VHDFormat = "VHDX"
                SizeBytes = 60GB
                WorkingDirectory = $workingdir
                VHDPath = "$($BaseVHDPath)\VMServerBaseCore.vhdx"
                DiskLayout = 'UEFI'
                UnattendPath = "$($workingdir)\unattend1.xml" 
            }

            $VHDx = Convert-WindowsImage @ConvertWindowsImageParam

            }


            #Build the Windows 2016 Full UI Base VHDx for the Lab
    
            if (!(Test-Path "$($BaseVHDPath)\VMServerBase.vhdx")) 
                        {
            

            Set-Location $workingdir 

            # Load (aka "dot-source) the Function 
            . .\Convert-WindowsImage.ps1 
            # Prepare all the variables in advance (optional) 
            $ConvertWindowsImageParam = @{  
                SourcePath          = $ServerISO
                RemoteDesktopEnable = $True  
                Passthru            = $True  
                Edition    = "ServerDataCenter"
                VHDFormat = "VHDX"
                SizeBytes = 60GB
                WorkingDirectory = $workingdir
                VHDPath = "$($BaseVHDPath)\VMServerBase.vhdx"
                DiskLayout = 'UEFI'
                UnattendPath = "$($workingdir)\unattend.xml" 
                Package = @(  
                            "$($BaseVHDPath)\windows10.0-kb3213986-x64_a1f5adacc28b56d7728c92e318d6596d9072aec4.msu"  
                            )  


            }

            $VHDx = Convert-WindowsImage @ConvertWindowsImageParam

            }
            
    
    Clear-File "$($BaseVHDPath)\unattend.xml"
    Clear-File "$($BaseVHDPath)\unattend1.xml"
    Dismount-DiskImage $ServerISO
    Dismount-DiskImage $ServerISO1 
    #Clear-File "$($WorkingDir)\Convert-WindowsImage.ps1"

}

function Download-BaseImageUpdates
{

 
            if (!(Test-Path "$($BaseVHDPath)\windows10.0-kb3213986-x64_a1f5adacc28b56d7728c92e318d6596d9072aec4.msu")) 
                        {
    Invoke-WebRequest -Uri http://download.windowsupdate.com/d/msdownload/update/software/secu/2016/12/windows10.0-kb3213986-x64_a1f5adacc28b56d7728c92e318d6596d9072aec4.msu -OutFile "$($BaseVHDPath)\windows10.0-kb3213986-x64_a1f5adacc28b56d7728c92e318d6596d9072aec4.msu" -Verbose
    }
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
            Title="Please select ISO image with Windows Server vNext LTSC Preview - Build 17623"
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


$WindowsKey = '<PRODUCTKEY>' #Dave's Technet KEY Remove for Publishing of Book

$unattendSource = [xml]@"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <servicing></servicing>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <ComputerName>*</ComputerName>
            <ProductKey><PRODUCTKEY></ProductKey> 
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
    . Get-ISOUI
Write-Log 'Host' 'Locate the Windows Windows Server vNext LTSC Preview - Build 17623'
    . Get-ISOUI1

Write-Log $ServerISO
Write-Log $ServerISO1

    . Download-BaseImageUpdates


    . Initialize-BaseImage

Write-Log 'Host' 'Tasks Complete'