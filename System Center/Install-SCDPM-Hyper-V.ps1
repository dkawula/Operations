 <#
Created:	 2018-02-01
Version:	 1.0
Author       Dave Kawula MVP
Homepage:    http://www.checkyourlogs.net

Disclaimer:
This script is provided "AS IS" with no warranties, confers no rights and 
is not supported by the authors or CheckyourLogs or MVPDays Publishing

Author - Dave Kawula
    Twitter: @DaveKawula
    Blog   : http://www.checkyourlogs.net


    .Synopsis
    Deploys System Center Data Protection Manager (DPM )1801 Server to a Hyper-V Lab VM
    .DESCRIPTION
    This Script was part of my BIGDemo series and I have broken it out into a standalone function

    You will need to have a SCVMM Service Accounts Pre-Created and DPM 1801 Trial Media for this lab to work
    The Script will prompt for the path of the Files Required
    The Script will prompt for an Admin Account which will be used in $DomainCred
    If your File names are different than mine adjust accordingly.

    We will use PowerShell Direct to setup the Veeam Server in Hyper-V

    The Source Hyper-V Virtual Machine needs to be Windows Server 2016

    .EXAMPLE
    TODO: Dave, add something more meaningful in here
    .PARAMETER WorkingDir
    Transactional directory for files to be staged and written
    .PARAMETER VMname
    The name of the Virtual Machine
    .PARAMETER VMPath
    The Path to the VM Working Folder - We create a new VHDx for the DPM Install
    .PARAMETER GuestOSName
    Name of the Guest Operating System Name
    

    Usage: Install-DPM -Vmname YOURVM -GuestOS VEEAMSERVER -VMpath f:\VMs\SCVMM -WorkingDir f:\Temp 
#>
  #Installs SCVMM 1801 for your lab

 Function Install-DPM{
 
 param
  (
    [string]$VMName, 
    [string]$GuestOSName,
    [string]$VMPath
   

  )
     

     #Ask for DPM EXE

        [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
        $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            Title="Please Select the DPM 1801 .EXE"
        }
        $openFile.Filter = "exe files (*.exe)|*.exe|All files (*.*)|*.*" 
        If($openFile.ShowDialog() -eq "OK")
        {
              Write-Host "File $($openfile.FileName) selected"
        } 
        if (!$openFile.FileName){
                WriteErrorAndExit  "Iso was not selected... Exitting"
            }
            $DPMEXE = $openfile.FileName
           
         

       
     $DomainCred = Get-Credential
     #$VMName = 'DPM01'
     #$GuestOSname = 'DPM01'
     #$VMPath = 'f:\dcbuild_Test\VMs'
     #$SQL = 'VMM01\MSSQLSERVER'
     #$SCOMDrive = 'd:'


     icm -VMName $VMName -Credential $DomainCred {

      Write-Output -InputObject "[$($VMName)]:: Configure DPM Service Account as a Local Admin"

   # Add-LocalGroupMember -Group Administrators -Member $DPMServiceAcct

    
     Write-Output -InputObject "[$($VMName)]:: Disable Server Manager"

     Get-ScheduledTask -Taskname Servermanager | Disable-ScheduledTask

     Write-Output -InputObject "[$($VMName)]:: Enable Netadapter RSS"

     Enable-NetAdapterRss -Name *

      Write-Output -InputObject "[$($VMName)]:: Add Hyper-V PowerShell Features"

     Dism.exe /Online /Enable-Feature /FeatureName:Microsoft-Hyper-V /FeatureName:microsoft-Hyper-V-Management-PowerShell /quiet 


     }

    Restart-DemoVM -VMName $VMname
    Wait-PSDirect -VMName $VMName -cred $DomainCred


    Write-Output -InputObject "[$($VMName)]:: Adding Drive for DPM Install"

    New-VHD -Path "$($VMPath)\$($GuestOSName) - DPM Data 5.vhdx" -Dynamic -SizeBytes 50GB 
    Mount-VHD -Path "$($VMPath)\$($GuestOSName) - DPM Data 5.vhdx" 
    $DiskNumber = (Get-Diskimage -ImagePath "$($VMPath)\$($GuestOSName) - DPM Data 5.vhdx").Number
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT 
    Get-Disk -Number $DiskNumber | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "DPM" -Confirm:$False
    $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object {$_.Label -like "DPM*"}
    $DPMDriveLetter = $DriveLetter.DriveLetter
    Write-Output -InputObject "[$($VMName)]:: Copying SCDPM 1801 EXE to the new VHDx"
    Copy-Item -Path $DPMEXE -Destination "$($DPMDriveLetter)\SCDPM_1801.exe" -Force
    Dismount-VHD -Path "$($VMPath)\$($GuestOSName) - DPM Data 5.vhdx"
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($GuestOSName) - DPM Data 5.vhdx" -ControllerType SCSI
  

    icm -VMName $VMName -Credential $domainCred {
      
    Write-Output -InputObject "[$($VMName)]:: Adding the new VHDx for the DPM Install"
    Get-Disk | Where OperationalStatus -EQ "Offline" | Set-Disk -IsOffline $False 
    Get-Disk | Where Number -NE "0" |  Set-Disk -IsReadOnly $False
    $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object {$_.Label -like "DPM*"}
    $DPMDrive = $Driveletter.DriveLetter

        
    Write-Output -InputObject "[$($VMName)]:: Configuring WIndows Firewall for DPM"
    Set-NetFirewallRule -DisplayName 'File and Printer Sharing (Echo Request - ICMPv4-In)' -Profile Domain -Enabled True -Direction Inbound -Action Allow
    Set-NetFirewallRule -DisplayName 'File and Printer Sharing (Echo Request - ICMPv6-In)' -Profile Domain -Enabled True -Direction Inbound -Action Allow
    Set-NetFirewallRule -DisplayName 'File and Printer Sharing (SMB-In)' -Profile Domain -Enabled True -Direction Inbound -Action Allow
    Set-NetFirewallRule -DisplayName 'Remote Desktop - User Mode (TCP-In)' -Profile Domain -Enabled True -Direction Inbound -Action Allow
    Set-NetFirewallRule -DisplayName 'Remote Desktop - User Mode (UDP-In)' -Profile Domain -Enabled True -Direction Inbound -Action Allow

    Write-Output -InputObject "[$($VMName)]:: Configuring WIndows Firewall for DPM New Rules"
    New-NetFirewallRule -DisplayName "SCDPM-TCP" -Direction Inbound -Protocol TCP -Profile Domain -LocalPort 135,5718,5719,6075,88,389,139,445 -Action Allow
    New-NetFirewallRule -DisplayName "SCDPM-UDP" -Direction Inbound -Protocol UDP -Profile Domain -LocalPort 53,88,389,137,138 -Action Allow
    New-NetFirewallRule -DisplayName "Remote-SQL Server TCP" -Direction Inbound -Protocol TCP -Profile Domain -LocalPort 80,1433 -Action Allow
    New-NetFirewallRule -DisplayName "Remote-SQL Server UDP" -Direction Inbound -Protocol UDP -Profile Domain -LocalPort 1434 -Action Allow


       $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object {$_.Label -eq "DPM"}
       $DPMDriveLetter1 = $DriveLetter.DriveLetter
       
      #Install VMM
      $unattendFile = New-Item "$($DPMriveletter1)\DPMSetup.ini" -type File

     $FileContent = @"
        [OPTIONS]

        CompanyName=MVPDays

        UserName=MVPDays\SVC_DPM

        ProgramFiles=$DPMDrive\Program Files

        DatabaseFiles=$DPMDrive\Program Files

        IntegratedInstallSource=$DPMDrive\SCDPM

        SQLMachineName=DPM01

        SQLInstanceName=MSSQLSERVER

        SQLMachineUserName=MVPDays\SVC_SQL

        SQLMachinePassword=P@ssw0rd

        SQLMachineDomainName=MVPDays

        SQLAccountPassword=P@ssw0rd

        ReportingMachineName=DPM01

        ReportingInstanceName=MSSQLSERVER

        ReportingMachineUserName=MVPDays\SVC_SQL

        ReportingMachinePassword=P@ssw0rd

        ReportingMachineDOmainName=MVPDays

        
"@
        
        Set-Content $unattendFile $fileContent -Force

        copy-item c:\dpmsetup.ini $DPMDriveLetter1\dpmsetup.ini -Force



         
    #I was having some issues with the path for $DPMdriveLetter Getting lost
    
    Write-Output -InputObject "[$($VMName)]:: Extracting SCDPM 1801"
    $DPMDriveletter1

    cmd.exe /c "$DPMDriveletter1\SCDPM_1801.exe /dir=$DPMdriveletter1\SCDPM /silent"
    $DPMDriveLetter1 = 'd:'

    Get-Service MSSQLSERVER | Start-Service
    Get-Service SQLSERVERAGENT | Start-Service
  
    Write-Output -InputObject "[$($VMName)]:: Installing DPM 1801"
    cmd.exe /c "$DPMDriveletter1\SCDPM\setup.exe /i /f $dpmdriveletter1\DPMSetup.ini /l $DPMdriveletter1\dpmlog.txt"
    
     }
     }

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