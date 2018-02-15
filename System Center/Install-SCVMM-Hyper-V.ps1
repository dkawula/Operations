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
    Deploys SCVMM 1801 Server to a Hyper-V Lab VM
    .DESCRIPTION
    This Script was part of my BIGDemo series and I have broken it out into a standalone function

    You will need to have a SCVMM Service Accounts Pre-Created and SCOM1801 Trial Media for this lab to work
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
    The Path to the VM Working Folder - We create a new VHDx for the Veeam Install
    .PARAMETER GuestOSName
    Name of the Guest Operating System Name
    

    Usage: Install-SCVMM -Vmname YOURVM -GuestOS VEEAMSERVER -VMpath f:\VMs\SCVMM -WorkingDir f:\Temp 
#>
  #Installs SCVMM 1801 for your lab

 Function Install-SCVMM{
 
 param
  (
    [string]$VMName, 
    [string]$GuestOSName,
    [string]$VMPath,
    [string]$WorkingDir
  

  )
     

     #Ask for SCVMM EXE

        [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
        $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            Title="Please Select the SCVMM 1801 .EXE"
        }
        $openFile.Filter = "exe files (*.exe)|*.exe|All files (*.*)|*.*" 
        If($openFile.ShowDialog() -eq "OK")
        {
              Write-Host "File $($openfile.FileName) selected"
        } 
        if (!$openFile.FileName){
                WriteErrorAndExit  "Iso was not selected... Exitting"
            }
            $SCVMMEXE = $openfile.FileName
           
     
     #Ask for ADK1709 EXE

        [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
        $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            Title="Please Select the ADK1709 .EXE"
        }
        $openFile.Filter = "exe files (*.exe)|*.exe|All files (*.*)|*.*" 
        If($openFile.ShowDialog() -eq "OK")
        {
              Write-Host "File $($openfile.FileName) selected"
        } 
        if (!$openFile.FileName){
                WriteErrorAndExit  "Iso was not selected... Exitting"
            }
            $SCVMMEXE = $openfile.FileName
           

       
     $DomainCred = Get-Credential
     #$VMName = 'SCOM01'
     #$GuestOSname = 'SCOM01'
     #$VMPath = 'f:\dcbuild_Test\VMs'
     #$SQL = 'VMM01\MSSQLSERVER'
     #$SCOMDrive = 'd:'


    Write-Output -InputObject "[$($VMName)]:: Adding Drive for VMM Install"

    New-VHD -Path "$($VMPath)\$($GuestOSName) - VMM Data 2.vhdx" -Dynamic -SizeBytes 50GB 
    Mount-VHD -Path "$($VMPath)\$($GuestOSName) - VMM Data 2.vhdx" 
    $DiskNumber = (Get-Diskimage -ImagePath "$($VMPath)\$($GuestOSName) - VMM Data 2.vhdx").Number
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT 
    Get-Disk -Number $DiskNumber | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "VMM" -Confirm:$False
    $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object {$_.Label -like "VMM*"}
    $VMMDriveLetter = $DriveLetter.DriveLetter
    Write-Output -InputObject "[$($VMName)]:: Copying VMM 1801 EXE to the new VHDx"
    Copy-Item -Path "$SCVMMEXE\SCVMM_1801.exe" -Destination "$($VMMDriveLetter)\SCVMM_1801.exe" -Force
    Write-Output -InputObject "[$($VMName)]:: Copying ADK 1709 to the new VHDx"
    Copy-Item -Path "$ADKEXE\adksetup.exe" -Destination "$($VMMDriveLetter)\adksetup.exe" -Force
    Dismount-VHD -Path "$($VMPath)\$($GuestOSName) - VMM Data 2.vhdx"
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($GuestOSName) - VMM Data 2.vhdx" -ControllerType SCSI
  

      icm -VMName $VMName -Credential $domainCred {

    Write-Output -InputObject "[$($VMName)]:: Adding the new VHDx for the VMM Install"
    Get-Disk | Where OperationalStatus -EQ "Offline" | Set-Disk -IsOffline $False 
    Get-Disk | Where Number -NE "0" |  Set-Disk -IsReadOnly $False
    $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object {$_.Label -like "VMM*"}
    $VMMDrive = $Driveletter.DriveLetter

     Write-Output -InputObject "[$($VMName)]:: Downloading ADK"
     #Invoke-webrequest -uri https://go.microsoft.com/fwlink/p/?linkid=859206 -OutFile "$($VMMDrive)\adksetup.exe"
    # (New-Object System.Net.WebClient).DownloadFile("https://go.microsoft.com/fwlink/p/?linkid=859206","f:\iso\adksetup.exe")

     #Sample ADK install



        # You can grab ADK here:     https://msdn.microsoft.com/en-us/windows/hardware/dn913721.aspx



        Start-Transcript -Path "$($VMMDrive)\ADK_Install.log"



        $StartDateTime = get-date

        Write-Output -InputObject "[$($VMName)]:: Script started at $StartDateTime"

        $setupfile = "$($VMMDrive)\ADKsetup.exe"
        
        Write-Output -InputObject "[$($VMName)]:: Installing ADK..."

        Write-Output -InputObject "[$($VMName)]:: ADK Is being installed..."
  
        Start-Process -Wait -FilePath $setupfile -ArgumentList "/features OptionID.DeploymentTools OptionID.WindowsPreinstallationEnvironment /quiet"

        Write-Output -InputObject "[$($VMName)]:: ADK install finished at $(Get-date) and took $(((get-date) - $StartDateTime).TotalMinutes) Minutes"

        
        Stop-Transcript

        

        Start-Transcript -Path "$($VMmDrive)\SCVMM_Install.log"



        $StartDateTime = get-date

       $null = Get-Service MSSQLServer | Start-Service

       $Null = cmd.exe /c "$($VMMDrive)\SCVMM_1801.exe /dir=$($vmmdrive)\SCVMM /silent"

       Write-Output -InputObject "[$($VMName)]:: Waiting for VMM Install to Extract"
       Start-Sleep 120

       $setupfile = "$($VMMDrive)\SCVMM\setup.exe"
       Write-Output -InputObject "[$($VMName)]:: Installing VMM"

        



        ###Get workdirectory###

        #Install VMM
        $unattendFile = New-Item "$($VMMDrive)\VMServer.ini" -type File

     $FileContent = @"
        [OPTIONS]

        CompanyName=MVPDays

        CreateNewSqlDatabase=1

        SqlInstanceName=MSSQLSERVER

        SqlDatabaseName=VirtualManagerDB

        SqlMachineName=VMM01

        LibrarySharePath=$($VMMDrive)\MSCVMMLibrary

        ProgramFiles=$($VMMDrive)\Program Files\Microsoft System Center\Virtual Machine Manager

        LibraryShareName=MSSCVMMLibrary

        SQMOptIn = 1

        MUOptIn = 1
"@
        
        Set-Content $unattendFile $fileContent

        Write-Output -InputObject "[$($VMName)]:: VMM Is Being Installed"

        Get-Service MSSQLServer | Start-Service -WarningAction SilentlyContinue

        #02/13/2018 - DK $VMMDomain isn't quite working yet so I hard coded to MVPDays for now to get it working.

        cmd.exe /c "$vmmdrive\scvmm\setup.exe /server /i /f $VMMDrive\VMServer.ini /IACCEPTSCEULA /VmmServiceDomain MVPDays /VmmServiceUserName SVC_VMM /VmmServiceUserPassword P@ssw0rd"

        do{

        Start-Sleep 1

        }until ((Get-Process | Where-Object {$_.Description -eq "SetupVM"} -ErrorAction SilentlyContinue) -eq $null)

        Write-Output -InputObject "[$($VMName)]:: VMM has been Installed"



        Stop-Transcript

       
    }

 }