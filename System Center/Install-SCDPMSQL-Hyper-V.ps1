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
    Deploys System Center SQL Server 2016 Instance to  a Hyper-V Lab VM
    .DESCRIPTION
    This Script was part of my BIGDemo series and I have broken it out into a standalone function

    You will need to have a SVC_SQL Pre-Created and SQL 2016 Media for this lab to work
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

 Function Install-SQLDPM{
 
 param
  (
    [string]$VMName, 
    [string]$GuestOSName,
    [string]$VMPath
   

  )
     

     #Ask for DPM EXE

        [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
        $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            Title="Please SQL Server ISO"
        }
        $openFile.Filter = "iso files (*.iso)|*.iso|All files (*.*)|*.*" 
        If($openFile.ShowDialog() -eq "OK")
        {
              Write-Host "File $($openfile.FileName) selected"
        } 
        if (!$openFile.FileName){
                WriteErrorAndExit  "Iso was not selected... Exitting"
            }
            $SQLISO = $openfile.FileName
           
     
     #Ask for SSMS EXE

        [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
        $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            Title="Please Select the SQL Server Management Studio SSMS .exe Version 16.5 ONLY!!!"
        }
        $openFile.Filter = "exe files (*.exe)|*.exe|All files (*.*)|*.*" 
        If($openFile.ShowDialog() -eq "OK")
        {
              Write-Host "File $($openfile.FileName) selected"
        } 
        if (!$openFile.FileName){
                WriteErrorAndExit  "Iso was not selected... Exitting"
            }
            $SSMSEXE = $openfile.FileName

              
     #Ask for Windows Server ISO

        [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
        $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            Title="Please Select the Windows Server 2016 ISO"
        }
        $openFile.Filter = "ISO files (*.ISO)|*.ISO|All files (*.*)|*.*" 
        If($openFile.ShowDialog() -eq "OK")
        {
              Write-Host "File $($openfile.FileName) selected"
        } 
        if (!$openFile.FileName){
                WriteErrorAndExit  "Iso was not selected... Exitting"
            }
            $WS2016ISO = $openfile.FileName
           

       
     $DomainCred = Get-Credential
     #$VMName = 'DPM01'
     #$GuestOSname = 'DPM01'
     #$VMPath = 'f:\dcbuild_Test\VMs'
     #$SQL = 'VMM01\MSSQLSERVER'
     #$SCOMDrive = 'd:'

   
     
      icm -VMName $VMName -Credential $DomainCred {

      Write-Output -InputObject "[$($VMName)]:: Configure DPM Service Account as a Local Admin"

   # Add-LocalGroupMember -Group Administrators -Member $DPMServiceAcct

    
     Write-Output -InputObject "[$($VMName)]:: Enable .Net Framework 3.5"

     Dism.exe /Online /Enable-Feature /FeatureName:NetFx3 /All /Source:$setup1\sources\sxs

     
     }

    Restart-DemoVM -VMName $VMname
    Wait-PSDirect -VMName $VMName -cred $DomainCred



    Write-Output -InputObject "[$($VMName)]:: Adding Drive for DPM Install"

    New-VHD -Path "$($VMPath)\$($GuestOSName) - SQL Data 2.vhdx" -Dynamic -SizeBytes 50GB 
    Mount-VHD -Path "$($VMPath)\$($GuestOSName) - SQL Data 2.vhdx" 
    $DiskNumber = (Get-Diskimage -ImagePath "$($VMPath)\$($GuestOSName) - SQL Data 2.vhdx").Number
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT 
    Get-Disk -Number $DiskNumber | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "SQL" -Confirm:$False
    $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object {$_.Label -like "SQL*"}
    $SQLDriveLetter = $DriveLetter.DriveLetter
    Write-Output -InputObject "[$($VMName)]:: Copying SQL ISO to the new VHDx"
    Copy-Item -Path $SQLISO -Destination "$($SQLDriveLetter)\en_sql_server_2016_standard_with_service_pack_1_x64_dvd_9540929.iso" -Force
    Write-Output -InputObject "[$($VMName)]:: Copying SSMS EXE to the new VHDx"
    Copy-Item -Path $SSMSEXE -Destination "$($SQLDriveLetter)\SSMS-Setup-ENU.exe" -Force
    Write-Output -InputObject "[$($VMName)]:: Copying WS 2016 ISO to the new VHDx"
    Copy-Item -Path $WS2016ISO -Destination "$($DPMDriveLetter)\en_windows_server_2016_x64_dvd_9718492.iso" -Force
    Dismount-VHD -Path "$($VMPath)\$($GuestOSName) - SQL Data 2.vhdx"
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($GuestOSName) - SQL Data 2.vhdx" -ControllerType SCSI
  


    icm -VMName $VMName -Credential $domainCred {
      
    Write-Output -InputObject "[$($VMName)]:: Adding the new VHDx for the SQL Install"
    Get-Disk | Where OperationalStatus -EQ "Offline" | Set-Disk -IsOffline $False 
    Get-Disk | Where Number -NE "0" |  Set-Disk -IsReadOnly $False
    $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object {$_.Label -like "SQL*"}
    $SQLDrive = $Driveletter.DriveLetter

    Write-Output -InputObject "[$($VMName)]:: Mounting SQL ISO"

    $iso = Get-ChildItem -Path "$($SQLDrive)\en_sql_server_2016_standard_with_service_pack_1_x64_dvd_9540929.iso"  #CHANGE THIS!

    Mount-DiskImage $iso.FullName

    $setup = $(Get-DiskImage -ImagePath $iso.FullName | Get-Volume).DriveLetter +':' 
    $setup

    Write-Output -InputObject "[$($VMName)]:: Mounting WS2016 ISO"

    $iso = Get-ChildItem -Path "$($DPMDrive)\en_windows_server_2016_x64_dvd_9718492.iso"  #CHANGE THIS!

    Mount-DiskImage $iso.FullName

    $setup1 = $(Get-DiskImage -ImagePath $iso.FullName | Get-Volume).DriveLetter +':' 
    $setup1
    

#You will need to modify this for your environment accounts
#I have defaulted to MVPDays\svc_SQL and a password of P@ssw0rd
#If you are changing in your lab adjust acordingly 
#I will automate this later on.

Write-Output -InputObject "[$($VMName)]:: Creating SQL Install INI File"
$functionText = @"
;SQL Server 2016 Configuration File
[OPTIONS]
; Specifies a Setup work flow, like INSTALL, UNINSTALL, or UPGRADE. This is a required parameter. 
ACTION="Install"
; Specifies that SQL Server Setup should not display the privacy statement when ran from the command line. 
SUPPRESSPRIVACYSTATEMENTNOTICE="True"
IACCEPTSQLSERVERLICENSETERMS="True"
; By specifying this parameter and accepting Microsoft R Open and Microsoft R Server terms, you acknowledge that you have read and understood the terms of use. 
IACCEPTROPENLICENSETERMS="True"
; Use the /ENU parameter to install the English version of SQL Server on your localized Windows operating system. 
ENU="True"
; Setup will not display any user interface. 
QUIET="True"
; Setup will display progress only, without any user interaction. 
QUIETSIMPLE="False"
; Parameter that controls the user interface behavior. Valid values are Normal for the full UI,AutoAdvance for a simplied UI, and EnableUIOnServerCore for bypassing Server Core setup GUI block. 
;UIMODE="Normal"
; Specify whether SQL Server Setup should discover and include product updates. The valid values are True and False or 1 and 0. By default SQL Server Setup will include updates that are found. 
UpdateEnabled="True"
; If this parameter is provided, then this computer will use Microsoft Update to check for updates. 
USEMICROSOFTUPDATE="True"
; Specifies features to install, uninstall, or upgrade. The list of top-level features include SQL, AS, RS, IS, MDS, and Tools. The SQL feature will install the Database Engine, Replication, Full-Text, and Data Quality Services (DQS) server. The Tools feature will install shared components. 
FEATURES=SQLENGINE,RS,FULLTEXT
; Specify the location where SQL Server Setup will obtain product updates. The valid values are "MU" to search Microsoft Update, a valid folder path, a relative path such as .\MyUpdates or a UNC share. By default SQL Server Setup will search Microsoft Update or a Windows Update service through the Window Server Update Services. 
UpdateSource="MU"
; Displays the command line parameters usage 
HELP="False"
; Specifies that the detailed Setup log should be piped to the console. 
INDICATEPROGRESS="False"
; Specifies that Setup should install into WOW64. This command line argument is not supported on an IA64 or a 32-bit system. 
X86="False"
; Specify a default or named instance. MSSQLSERVER is the default instance for non-Express editions and SQLExpress for Express editions. This parameter is required when installing the SQL Server Database Engine (SQL), Analysis Services (AS), or Reporting Services (RS). 
INSTANCENAME="MSSQLSERVER"
; Specify the root installation directory for shared components.  This directory remains unchanged after shared components are already installed. 
INSTALLSHAREDDIR="$SQLDrive\Program Files\Microsoft SQL Server"
; Specify the root installation directory for the WOW64 shared components.  This directory remains unchanged after WOW64 shared components are already installed. 
INSTALLSHAREDWOWDIR="$SQLDrive\Program Files (x86)\Microsoft SQL Server"
; Specify the Instance ID for the SQL Server features you have specified. SQL Server directory structure, registry structure, and service names will incorporate the instance ID of the SQL Server instance. 
INSTANCEID="MSSQLSERVER"
; Specifies which mode report server is installed in.  
; Default value: “FilesOnly”  
RSINSTALLMODE="DefaultNativeMode"
; TelemetryUserNameConfigDescription 
SQLTELSVCACCT="NT Service\SQLTELEMETRY"
; TelemetryStartupConfigDescription 
SQLTELSVCSTARTUPTYPE="Automatic"
; Specify the installation directory. 
INSTANCEDIR="$SQLDrive\Program Files\Microsoft SQL Server"
; Agent account name 
AGTSVCACCOUNT="MVPDAYS\SVC_SQL"
AGTSVCPASSWORD="P@ssw0rd"
; Auto-start service after installation.  
AGTSVCSTARTUPTYPE="Automatic"
; CM brick TCP communication port 
COMMFABRICPORT="0"
; How matrix will use private networks 
COMMFABRICNETWORKLEVEL="0"
; How inter brick communication will be protected 
COMMFABRICENCRYPTION="0"
; TCP port used by the CM brick 
MATRIXCMBRICKCOMMPORT="0"
; Startup type for the SQL Server service. 
SQLSVCSTARTUPTYPE="Automatic"
; Level to enable FILESTREAM feature at (0, 1, 2 or 3). 
FILESTREAMLEVEL="0"
; Set to "1" to enable RANU for SQL Server Express. 
ENABLERANU="False"
; Specifies a Windows collation or an SQL collation to use for the Database Engine. 
SQLCOLLATION="SQL_Latin1_General_CP1_CI_AS"
; Account for SQL Server service: Domain\User or system account. 
SQLSVCACCOUNT="MVPDAYS\SVC_SQL"
SQLSVCPASSWORD="P@ssw0rd"
; Set to "True" to enable instant file initialization for SQL Server service. If enabled, Setup will grant Perform Volume Maintenance Task privilege to the Database Engine Service SID. This may lead to information disclosure as it could allow deleted content to be accessed by an unauthorized principal. 
SQLSVCINSTANTFILEINIT="True"
; Windows account(s) to provision as SQL Server system administrators. 
SQLSYSADMINACCOUNTS="MVPDays\Domain Admins"
; The number of Database Engine TempDB files. 
SQLTEMPDBFILECOUNT="2"
; Specifies the initial size of a Database Engine TempDB data file in MB. 
SQLTEMPDBFILESIZE="8"
; Specifies the automatic growth increment of each Database Engine TempDB data file in MB. 
SQLTEMPDBFILEGROWTH="64"
; Specifies the initial size of the Database Engine TempDB log file in MB. 
SQLTEMPDBLOGFILESIZE="8"
; Specifies the automatic growth increment of the Database Engine TempDB log file in MB. 
SQLTEMPDBLOGFILEGROWTH="64"
; Provision current user as a Database Engine system administrator for %SQL_PRODUCT_SHORT_NAME% Express. 
ADDCURRENTUSERASSQLADMIN="False"
; Specify 0 to disable or 1 to enable the TCP/IP protocol. 
TCPENABLED="1"
; Specify 0 to disable or 1 to enable the Named Pipes protocol. 
NPENABLED="0"
; Startup type for Browser Service. 
BROWSERSVCSTARTUPTYPE="Disabled"
; Specifies which account the report server NT service should execute under.  When omitted or when the value is empty string, the default built-in account for the current operating system.
; The username part of RSSVCACCOUNT is a maximum of 20 characters long and
; The domain part of RSSVCACCOUNT is a maximum of 254 characters long. 
RSSVCACCOUNT="MVPDAYS\SVC_SQL"
RSSVCPASSWORD="P@ssw0rd"
; Specifies how the startup mode of the report server NT service.  When 
; Manual - Service startup is manual mode (default).
; Automatic - Service startup is automatic mode.
; Disabled - Service is disabled 
RSSVCSTARTUPTYPE="Automatic"
FTSVCACCOUNT="MVPDAYS\SVC_SQL"
"@

New-Item "$($SQLDrive)\SqlInstall.ini" -type file -force -value $functionText

Write-Output -InputObject "[$($VMName)]:: Configuring WIndows Firewall for SQL New Rules"
    New-NetFirewallRule -DisplayName "SQL 2016 Exceptions-TCP" -Direction Inbound -Protocol TCP -Profile Domain -LocalPort 135,1433,1434,4088,80,443 -Action Allow
 

        Write-Output -InputObject "[$($VMName)]:: Running SQL Unattended Install"

        $setup = $(Get-DiskImage -ImagePath $iso.FullName | Get-Volume).DriveLetter +':' 
        $setup
        cmd.exe /c "$($Setup)\setup.exe /ConfigurationFile=$($SQLDrive)\SqlInstall.ini"
        

        # run installer with arg-list built above, including config file and service/SA accounts

        #Start-Process -Verb runas -FilePath $setup -ArgumentList $arglist -Wait


        # Write-Output -InputObject "[$($VMName)]:: Downloading SSMS"
         #Invoke-Webrequest was REALLY SLOW
         #Invoke-webrequest -uri https://go.microsoft.com/fwlink/?linkid=864329 -OutFile "$($SQLDrive)\SSMS-Setup-ENU.exe"
         #Changing to System.Net.WebClient
        # (New-Object System.Net.WebClient).DownloadFile("https://go.microsoft.com/fwlink/?linkid=864329","$($SQLDrive)\SSMS-Setup-ENU.exe")    



        # You can grab SSMS here:    https://docs.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms



        Start-Transcript -Path "$($SQLDrive)\SSMS-Install.log"



        $StartDateTime = get-date

        Write-Output -InputObject "[$($VMName)]:: Script started at $StartDateTime"

        #$setupfile = "$($VMMDrive)\SSMS-Setup-ENU.exe"
        Write-Output -InputObject "[$($VMName)]:: Installing SSMS"

        cmd.exe /c "$($SQLDrive)\SSMS-Setup-ENU.exe /install /quiet /norestart /log $($SQLDrive)\ssmssetup.log"

        Stop-Transcript

        # un-mount the install image when done after waiting 1 second (just for kicks)

        Start-Sleep -Seconds 1

        Dismount-DiskImage $iso.FullName
    
    }

   Restart-DemoVM -VMName $VMName
   Wait-PSDirect -VMName $VMName -cred $DomainCred
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