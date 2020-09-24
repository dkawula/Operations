<#
Created:	 2020-09-24
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
    Patches virtual machines using powershell direct
    .DESCRIPTION
   Huge thank you to Gregory Strik.   It was his base code that I used to build this.

     Script: WSUS.ps1
         Author: Gregory Strike
         URL: //www.gregorystrike.com/2011/04/07/force-windows-automatic-updates-with-powershell/
         Date: 02-19-2010

    Honestly patching is a pain in my ass so I wanted a way to automate this with PowerShell.

    .EXAMPLE
    TODO: Dave, add something more meaningful in here
    .PARAMETER InstallUpdates
    After Download do you want to install updates
    .PARAMETER RebootNow
    Do you want to reboot post updates
    
#>

#region Parameters
[cmdletbinding()]
param
( 
    [Parameter(Mandatory)]
    [string]
    $InstallUpdates = 'Yes',

    [Parameter(Mandatory)]
    [string]
    $RebootNow = 'Yes'
)

    
#endregion

#region Worker Functions
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
            } -ea SilentlyContinue) -ne 'Test') {
        Start-Sleep -Seconds 1
    }
}


Function Wait-Sleep {
    param (
        [int]$sleepSeconds = 60,
        [string]$title = "... Waiting for $sleepSeconds Seconds... Be Patient",
        [string]$titleColor = "Yellow"
    )
    Write-Host -ForegroundColor $titleColor $title
    for ($sleep = 1; $sleep -le $sleepSeconds; $sleep++ ) {
        Write-Progress -ParentId -1 -Id 42 -Activity "Sleeping for $sleepSeconds seconds" -Status "Slept for $sleep Seconds:" -percentcomplete (($sleep / $sleepSeconds) * 100)
        Start-Sleep 1
    }
    Write-Progress -Completed -Id 42 -Activity "Done Sleeping"
}
    

function Restart-DemoVM {
    param
    (
        [string]
        $VMName
    )

    Write-Log $VMName 'Rebooting'
    stop-vm $VMName
    start-vm $VMName
}

function Confirm-Path {
    param
    (
        [string] $path
    )
    if (!(Test-Path $path)) {
        $null = mkdir $path
    }
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

function Clear-File {
    param
    (
        [string] $file
    )
    
    if (Test-Path $file) {
        $null = Remove-Item $file -Recurse
    }
}

#endregion

Function Install-VMWUUpdatesPSDirect{


    param
    (
        [string]$InstallUpdates, 
        [string]$RebootNow
    )


$UpdateSession = New-Object -Com Microsoft.Update.Session
$UpdateSearcher = $UpdateSession.CreateUpdateSearcher()

Write-Host("Searching for applicable updates...") -Fore Green

$SearchResult = $UpdateSearcher.Search("IsInstalled=0 and Type='Software'")

Write-Host("")
Write-Host("List of applicable items on the machine:") -Fore Green
For ($X = 0; $X -lt $SearchResult.Updates.Count; $X++){
    $Update = $SearchResult.Updates.Item($X)
    Write-Host( ($X + 1).ToString() + "> " + $Update.Title)
}

If ($SearchResult.Updates.Count -eq 0) {
    Write-Host("There are no applicable updates.")
    Exit
}

#Write-Host("")
#Write-Host("Creating collection of updates to download:") -Fore Green

$UpdatesToDownload = New-Object -Com Microsoft.Update.UpdateColl

For ($X = 0; $X -lt $SearchResult.Updates.Count; $X++){
    $Update = $SearchResult.Updates.Item($X)
    #Write-Host( ($X + 1).ToString() + "> Adding: " + $Update.Title)
    $Null = $UpdatesToDownload.Add($Update)
}

Write-Host("")
Write-Host("Downloading Updates...")  -Fore Green

$Downloader = $UpdateSession.CreateUpdateDownloader()
$Downloader.Updates = $UpdatesToDownload
$Null = $Downloader.Download()

#Write-Host("")
#Write-Host("List of Downloaded Updates...") -Fore Green

$UpdatesToInstall = New-Object -Com Microsoft.Update.UpdateColl

For ($X = 0; $X -lt $SearchResult.Updates.Count; $X++){
    $Update = $SearchResult.Updates.Item($X)
    If ($Update.IsDownloaded) {
        #Write-Host( ($X + 1).ToString() + "> " + $Update.Title)
        $Null = $UpdatesToInstall.Add($Update)
    }
}

$Install = [System.String]$Args[0]
$Reboot  = [System.String]$Args[1]

If (!$Install){
    $Install = $InstallUpdates
}

If ($Install.ToUpper() -eq "Yes" -or $Install.ToUpper() -eq "YES"){
    Write-Host("")
    Write-Host("Installing Updates...") -Fore Green

    $Installer = $UpdateSession.CreateUpdateInstaller()
    $Installer.Updates = $UpdatesToInstall

    $InstallationResult = $Installer.Install()

    Write-Host("")
    Write-Host("List of Updates Installed with Results:") -Fore Green

    For ($X = 0; $X -lt $UpdatesToInstall.Count; $X++){
        Write-Host($UpdatesToInstall.Item($X).Title + ": " + $InstallationResult.GetUpdateResult($X).ResultCode)
    }

    Write-Host("")
    Write-Host("Installation Result: " + $InstallationResult.ResultCode)
    Write-Host("    Reboot Required: " + $InstallationResult.RebootRequired)

    If ($InstallationResult.RebootRequired -eq $True){
        If (!$Reboot){
            $Reboot = $RebootNow
        }

        If ($Reboot.ToUpper() -eq "Yes" -or $Reboot.ToUpper() -eq "YES"){
            Write-Host("")
            Write-Host("Rebooting...") -Fore Green
            $WMIReboot = Get-WMIObject -Class Win32_OperatingSystem
            $WMIReboot.PSBase.Scope.Options.EnablePrivileges = $True
            $WMIReboot.Reboot()
        }
    }
}






}



