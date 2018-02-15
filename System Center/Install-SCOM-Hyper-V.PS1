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
    Deploys SCOM 1801 Server to a Hyper-V Lab VM
    .DESCRIPTION
    This Script was part of my BIGDemo series and I have broken it out into a standalone function

    You will need to have a SCOM Service Accounts Pre-Created and SCOM1801 Trial Media for this lab to work
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
    

    Usage: Import-Module Install-SCOM-Hyper-V  ## Loads the Install-SCOM Function then...
    Usage: Install-SCOM -Vmname YOURVM -GuestOS VEEAMSERVER -VMpath f:\VMs\SCOM -WorkingDir f:\Temp -SQL SQLSERVER\MSSQLSERVER


#>
  #Installs SCOM 1801 for your lab

 Function Install-SCOM{
 
 param
  (
    [string]$VMName, 
    [string]$GuestOSName,
    [string]$VMPath,
    [string]$WorkingDir,
    [string]$SQL

  )
     

     #Ask for Veeam ISO

        [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
        $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            Title="Please Select the SCOM 1801 .EXE"
        }
        $openFile.Filter = "exe files (*.exe)|*.exe|All files (*.*)|*.*" 
        If($openFile.ShowDialog() -eq "OK")
        {
              Write-Host "File $($openfile.FileName) selected"
        } 
        if (!$openFile.FileName){
                WriteErrorAndExit  "Iso was not selected... Exitting"
            }
            $SCOMEXE = $openfile.FileName
            #$VeeamISO
      #Ask for Veeam License

       
     $DomainCred = Get-Credential
     #$VMName = 'Management01'
     #$GuestOSname = 'Management01'
     #$VMPath = 'f:\dcbuild_Test\VMs'

    Write-Output -InputObject "[$($VMName)]:: Adding Drive for SCOM Install"

    New-VHD -Path "$($VMPath)\$($GuestOSName) - SCOM Data 1.vhdx" -Dynamic -SizeBytes 50GB 
    Mount-VHD -Path "$($VMPath)\$($GuestOSName) - SCOM Data 1.vhdx" 
    $DiskNumber = (Get-Diskimage -ImagePath "$($VMPath)\$($GuestOSName) - SCOM Data 1.vhdx").Number
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT 
    Get-Disk -Number $DiskNumber | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "SCOM" -Confirm:$False
    $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object {$_.Label -like "SCOM*"}
    $SCOMDriveLetter = $DriveLetter.DriveLetter
    Write-Output -InputObject "[$($VMName)]:: Copying SCOM 1801 EXE to the new VHDx"
    Copy-Item -Path $SCOMEXE -Destination "$($SCOMDriveLetter)\SCOM_1801_EN.exe" -Force
    Dismount-VHD -Path "$($VMPath)\$($GuestOSName) - SCOM Data 1.vhdx"    
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($GuestOSName) - SCOM Data 1.vhdx" -ControllerType SCSI
  

    icm -VMName $VMName -Credential $domainCred {

    Write-Output -InputObject "[$($VMName)]:: Adding the new VHDx for the SCOM Install"
    Get-Disk | Where OperationalStatus -EQ "Offline" | Set-Disk -IsOffline $False 
    Get-Disk | Where Number -NE "0" |  Set-Disk -IsReadOnly $False
    $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object {$_.Label -like "SCOM*"}
    $SCOMDrive = $Driveletter.DriveLetter



     Write-Output -InputObject "[$($VMName)]:: Downloading SQLSysCLRTypes.MSI"

    #  SQLSysClrTypes: https://download.microsoft.com/download/1/3/0/13089488-91FC-4E22-AD68-5BE58BD5C014/ENU/x64/SQLSysClrTypes.msi
    Invoke-webrequest -uri https://download.microsoft.com/download/1/3/0/13089488-91FC-4E22-AD68-5BE58BD5C014/ENU/x64/SQLSysClrTypes.msi -OutFile "$($SCOMDrive)\SQLSysClrTypes.msi"


      Write-Output -InputObject "[$($VMName)]:: Downloading ReportViewer.msi"
    #ReportViewer: http://download.microsoft.com/download/F/B/7/FB728406-A1EE-4AB5-9C56-74EB8BDDF2FF/ReportViewer.msi

    Invoke-webrequest -uri http://download.microsoft.com/download/A/1/2/A129F694-233C-4C7C-860F-F73139CF2E01/ENU/x86/ReportViewer.msi -OutFile "$($SCOMDrive)\ReportViewer.msi"
     #Invoke-webrequest -uri https://go.microsoft.com/fwlink/p/?linkid=859206 -OutFile "$($VMMDrive)\adksetup.exe"
    # (New-Object System.Net.WebClient).DownloadFile("https://go.microsoft.com/fwlink/p/?linkid=859206","f:\iso\adksetup.exe")

     #Sample ADK install


    Write-Output -InputObject "[$($VMName)]:: Enabling Feature AuthManager"
    dism /online /enable-feature /featurename:AuthManager 

    Write-Output -InputObject "[$($VMName)]:: Enabling Other Features for SCOM 1801"
    Add-WindowsFeature Web-Static-Content,Web-Default-Doc,Web-Dir-Browsing,Web-Http-Errors,Web-Http-Logging,Web-Request-Monitor,Web-Filtering,Web-Stat-Compression,Web-Metabase,Web-Asp-Net,Web-Windows-Auth,Web-ASP,Web-CGI


    Add-WindowsFeature NET-WCF-HTTP-Activation45

    Write-Output -InputObject "[$($VMName)]:: Installing SQLSYSCLRTypes"
    cmd.exe /c "msiexec /i $SCOMDrive\SQLSysClrTypes.msi /q"

    Write-Output -InputObject "[$($VMName)]:: Installing ReportViewer"
    cmd.exe /c "msiexec /i $SCOMDrive\ReportViewer.msi /q"


    Write-Output -InputObject "[$($VMName)]:: Extracting SCOM 1801"
    $Null = cmd.exe /c "$($SCOMDrive)\SCOM_1801_EN.exe /dir=$($SCOMdrive)\SCOM /silent"

    Write-Output -InputObject "[$($VMName)]:: Installing SCOM 1801"
    cmd.exe /c "$SCOMDrive\SCOM\setup.exe /install /components:OMServer,OMWebConsole,OMConsole /ManagementGroupName:MVPDays /SqlServerInstance:$SQL /DatabaseName:OperationsManager /DWSqlServerInstance:$SQL /DWDatabaseName:OperationsManagerDW /ActionAccountUser:MVPDays\svc_omsvc /ActionAccountPassword:P@ssw0rd /DASAccountUser:MVPDays\svc_omaccess /DASAccountPassword:P@ssw0rd /DataReaderUser:MVPDays\svc_omreader /DataReaderPassword:P@ssw0rd /DataWriterUser:MVPDays\svc_omwriter /DataWriterPassword:P@ssw0rd /WebSiteName:""Default Web Site"" /WebConsoleAuthorizationMode:Mixed /EnableErrorReporting:Always /SendCEIPReports:1 /UseMicrosoftUpdate:1 /AcceptEndUserLicenseAgreement:1 /silent "
    #Logs for the install are located in %APPDATALOCAL%\SCOM
     }
     }