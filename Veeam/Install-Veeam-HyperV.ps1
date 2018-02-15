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
    Deploys Veeam Backup and Replication 9.5 + UR3 to a Hyper-V Lab VM
    .DESCRIPTION
    This Script was part of my BIGDemo series and I have broken it out into a standalone function

    You will need to have a Veeam Service Account Pre-Created, Veeam B&R ISO and Product Key for this lab to work
    The Script will prompt for the path of the ISO and .LIC files
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
    

    Usage: Install-Veeam -Vmname YOURVM -GuestOS VEEAMSERVER -VMpath f:\VMs\Veeam -WorkingDir f:\Temp
#>
  #Installs Veeam 9.5 and UR 3
  
  Function Install-Veeam {
  
  param
  (
    [string]$VMName, 
    [string]$GuestOSName,
    [string]$VMPath,
    [string]$WorkingDir
  )
     

     #Ask for Veeam ISO

        [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
        $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            Title="Please Select the Veeam 9.5 UR3 ISO"
        }
        $openFile.Filter = "iso files (*.iso)|*.iso|All files (*.*)|*.*" 
        If($openFile.ShowDialog() -eq "OK")
        {
            Write-Log  "File $($openfile.FileName) selected"
        } 
        if (!$openFile.FileName){
                WriteErrorAndExit  "Iso was not selected... Exitting"
            }
            $VeeamISO = $openfile.FileName
            #$VeeamISO
      #Ask for Veeam License

       [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
        $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            Title="Please Select the Veeam License File"
        }
        $openFile.Filter = "lic files (*.lic)|*.lic|All files (*.*)|*.*" 
        If($openFile.ShowDialog() -eq "OK")
        {
            Write-Log  "File $($openfile.FileName) selected"
        } 
        if (!$openFile.FileName){
                WriteErrorAndExit  "Iso was not selected... Exitting"
            }
            $VeeamLic = $openfile.FileName
            #$VeeamLic


     $DomainCred = Get-Credential
     #$VMName = 'Management01'
     #$GuestOSname = 'Management01'
     #$VMPath = 'f:\dcbuild_Test\VMs'
    
    Write-Output -InputObject "[$($VMName)]:: Adding Drive for Veeam Install"

    New-VHD -Path "$($VMPath)\$($GuestOSName) - Veeam Data 4.vhdx" -Dynamic -SizeBytes 60GB
    Mount-VHD -Path "$($VMPath)\$($GuestOSName) - Veeam Data 4.vhdx"
    $DiskNumber = (Get-Diskimage -ImagePath "$($VMPath)\$($GuestOSName) - Veeam Data 4.vhdx").Number
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT 
    Get-Disk -Number $DiskNumber | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Veeam" -Confirm:$False
    $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object {$_.Label -like "Veeam*"}
    $VeeamDriveLetter = $DriveLetter.DriveLetter
    
    
    Write-Output -InputObject "[$($VMName)]:: Copying Veeam ISO and Rollups into the new VHDx"
    Copy-Item -Path $VeeamIso -Destination "$($VeeamDriveLetter)\VeeamBackup&Replication_9.5.0.1536.Update3.iso" -Force
    Write-Output -InputObject "[$($VMName)]:: Copying Veeam license and Rollups into the new VHDx"
    Copy-Item -Path $VeeamLic -Destination "$($VeeamDriveLetter)\veeam_backup_nfr_0_12.lic" -Force
    Dismount-VHD -Path "$($VMPath)\$($GuestOSName) - Veeam Data 3.vhdx"
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($GuestOSName) - Veeam Data 4.vhdx" -ControllerType SCSI
  

    
    icm -VMName $VMName -Credential $domainCred {



    Write-Output -InputObject "[$($VMName)]:: Adding the new VHDx for the Veeam Install"
    Get-Disk | Where OperationalStatus -EQ "Offline" | Set-Disk -IsOffline $False 
    Get-Disk | Where Number -NE "0" |  Set-Disk -IsReadOnly $False
    $Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object {$_.Label -like "Veeam*"}
    $VeeamDrive = $Driveletter.DriveLetter
    $VeeamDrive

    Write-Output -InputObject "[$($VMName)]:: Mounting Veeam ISO"

    $iso = Get-ChildItem -Path "$($VeeamDrive)\VeeamBackup&Replication_9.5.0.1536.Update3.iso"  #CHANGE THIS!

    Mount-DiskImage $iso.FullName

    Write-Output -InputObject "[$($VMName)]:: Installing Veeam Unattended"

        $setup = $(Get-DiskImage -ImagePath $iso.FullName | Get-Volume).DriveLetter +':' 
        $setup
       
    <#>   
        ===========================================================================

    Original Source Created by: Markus Kraus

    Twitter: @VMarkus_K

    Private Blog: mycloudrevolution.com
    #Source PowerShell Code from https://gist.githubusercontent.com/mycloudrevolution/b176f5ab987ff787ba4fce5c177780dc/raw/f20a78dc9b7c1085b1fe4d243de3fcb514970d70/VeeamBR95-Silent.ps1

    ===========================================================================
    </#>

            # Requires PowerShell 5.1
        # Requires .Net 4.5.2 and Reboot
        

        #region: Variables
        $source = $setup
        $licensefile = "$($VeeamDrive)\veeam_backup_nfr_0_12.lic"
        $username = "svc_veeam"
        $fulluser = "MVPDays\svc_Veeam"
        $password = "P@ssw0rd"
        $CatalogPath = "$($VeeamDrive)\VbrCatalog"
        $vPowerPath = "$($VeeamDrive)\vPowerNfs"
        #endregion

        #region: logdir
        $logdir = "$($VeeamDrive)\logdir"
        $trash = New-Item -ItemType Directory -path $logdir  -ErrorAction SilentlyContinue
        #endregion

        ### Optional .Net 4.5.2
        <#
        Write-Host "    Installing .Net 4.5.2 ..." -ForegroundColor Yellow
        $Arguments = "/quiet /norestart"
        Start-Process "$source\Redistr\NDP452-KB2901907-x86-x64-AllOS-ENU.exe" -ArgumentList $Arguments -Wait -NoNewWindow
        Restart-Computer -Confirm:$true
        #>

        ### Optional PowerShell 5.1
        <#
        Write-Host "    Installing PowerShell 5.1 ..." -ForegroundColor Yellow
        $Arguments = "C:\_install\Win8.1AndW2K12R2-KB3191564-x64.msu /quiet /norestart"
        Start-Process "wusa.exe" -ArgumentList $Arguments -Wait -NoNewWindow
        Restart-Computer -Confirm:$true
        #>

        #region: Installation
        #  Info: https://www.veeam.com/unattended_installation_ds.pdf

        ## Global Prerequirements
        Write-Host "Installing Global Prerequirements ..." -ForegroundColor Yellow
        ### 2012 System CLR Types
        Write-Host "    Installing 2012 System CLR Types ..." -ForegroundColor Yellow
        $MSIArguments = @(
            "/i"
            "$source\Redistr\x64\SQLSysClrTypes.msi"
            "/qn"
            "/norestart"
            "/L*v"
            "$logdir\01_CLR.txt"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        if (Select-String -path "$logdir\01_CLR.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
            }
            else {
                throw "Setup Failed"
                }

        ### 2012 Shared management objects
        Write-Host "    Installing 2012 Shared management objects ..." -ForegroundColor Yellow
        $MSIArguments = @(
            "/i"
            "$source\Redistr\x64\SharedManagementObjects.msi"
            "/qn"
            "/norestart"
            "/L*v"
            "$logdir\02_Shared.txt"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        if (Select-String -path "$logdir\02_Shared.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
            }
            else {
                throw "Setup Failed"
                }

        ### SQL Express
        ### Info: https://msdn.microsoft.com/en-us/library/ms144259.aspx
        Write-Host "    Installing SQL Express ..." -ForegroundColor Yellow
        $Arguments = "/HIDECONSOLE /Q /IACCEPTSQLSERVERLICENSETERMS /ACTION=install /FEATURES=SQLEngine,SNAC_SDK /INSTANCENAME=VEEAMSQL2012 /SQLSVCACCOUNT=`"NT AUTHORITY\SYSTEM`" /SQLSYSADMINACCOUNTS=`"$fulluser`" `"Builtin\Administrators`" /TCPENABLED=1 /NPENABLED=1 /UpdateEnabled=0"
        Start-Process "$source\Redistr\x64\SQLEXPR_x64_ENU.exe" -ArgumentList $Arguments -Wait -NoNewWindow

        ## Veeam Backup & Replication
        Write-Host "Installing Veeam Backup & Replication ..." -ForegroundColor Yellow
        ### Backup Catalog
        Write-Host "    Installing Backup Catalog ..." -ForegroundColor Yellow
        $trash = New-Item -ItemType Directory -path $CatalogPath -ErrorAction SilentlyContinue
        $MSIArguments = @(
            "/i"
            "$source\Catalog\VeeamBackupCatalog64.msi"
            "/qn"
            "/L*v"
            "$logdir\04_Catalog.txt"
            "VM_CATALOGPATH=$CatalogPath"
            "VBRC_SERVICE_USER=$fulluser"
            "VBRC_SERVICE_PASSWORD=$password"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        if (Select-String -path "$logdir\04_Catalog.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
            }
            else {
                throw "Setup Failed"
                }

        ### Backup Server
        Write-Host "    Installing Backup Server ..." -ForegroundColor Yellow
        $trash = New-Item -ItemType Directory -path $vPowerPath -ErrorAction SilentlyContinue
        $MSIArguments = @(
            "/i"
            "$source\Backup\Server.x64.msi"
            "/qn"
            "/L*v"
            "$logdir\05_Backup.txt"
            "ACCEPTEULA=YES"
            "VBR_LICENSE_FILE=$licensefile"
            "VBR_SERVICE_USER=$fulluser"
            "VBR_SERVICE_PASSWORD=$password"
            "PF_AD_NFSDATASTORE=$vPowerPath"
            "VBR_SQLSERVER_SERVER=$env:COMPUTERNAME\VEEAMSQL2012"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        if (Select-String -path "$logdir\05_Backup.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
            }
            else {
                throw "Setup Failed"
                }

        ### Backup Console
        Write-Host "    Installing Backup Console ..." -ForegroundColor Yellow
        $MSIArguments = @(
            "/i"
            "$source\Backup\Shell.x64.msi"
            "/qn"
            "/L*v"
            "$logdir\06_Console.txt"
            "ACCEPTEULA=YES"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        if (Select-String -path "$logdir\06_Console.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
            }
            else {
                throw "Setup Failed"
                }

        ### Explorers
        Write-Host "    Installing Explorer For ActiveDirectory ..." -ForegroundColor Yellow
        $MSIArguments = @(
            "/i"
            "$source\Explorers\VeeamExplorerForActiveDirectory.msi"
            "/qn"
            "/L*v"
            "$logdir\07_ExplorerForActiveDirectory.txt"
            "ACCEPTEULA=YES"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        if (Select-String -path "$logdir\07_ExplorerForActiveDirectory.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
            }
            else {
                throw "Setup Failed"
                }

        Write-Host "    Installing Explorer For Exchange ..." -ForegroundColor Yellow
        $MSIArguments = @(
            "/i"
            "$source\Explorers\VeeamExplorerForExchange.msi"
            "/qn"
            "/L*v"
            "$logdir\08_VeeamExplorerForExchange.txt"
            "ACCEPTEULA=YES"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        if (Select-String -path "$logdir\08_VeeamExplorerForExchange.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
            }
            else {
                throw "Setup Failed"
                }

        Write-Host "    Installing Explorer For SQL ..." -ForegroundColor Yellow
        $MSIArguments = @(
            "/i"
            "$source\Explorers\VeeamExplorerForSQL.msi"
            "/qn"
            "/L*v"
            "$logdir\09_VeeamExplorerForSQL.txt"
            "ACCEPTEULA=YES"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        if (Select-String -path "$logdir\09_VeeamExplorerForSQL.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
            }
            else {
                throw "Setup Failed"
                }

        Write-Host "    Installing Explorer For Oracle ..." -ForegroundColor Yellow
        $MSIArguments = @(
            "/i"
            "$source\Explorers\VeeamExplorerForOracle.msi"
            "/qn"
            "/L*v"
            "$logdir\10_VeeamExplorerForOracle.txt"
            "ACCEPTEULA=YES"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        if (Select-String -path "$logdir\10_VeeamExplorerForOracle.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
            }
            else {
                throw "Setup Failed"
                }

        Write-Host "    Installing Explorer For SharePoint ..." -ForegroundColor Yellow
        $MSIArguments = @(
            "/i"
            "$source\Explorers\VeeamExplorerForSharePoint.msi"
            "/qn"
            "/L*v"
            "$logdir\11_VeeamExplorerForSharePoint.txt"
            "ACCEPTEULA=YES"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        if (Select-String -path "$logdir\11_VeeamExplorerForSharePoint.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
            }
            else {
                throw "Setup Failed"
                }

        ## Enterprise Manager
        Write-Host "Installing Enterprise Manager ..." -ForegroundColor Yellow
        ### Enterprise Manager Prereqirements
        Write-Host "    Installing Enterprise Manager Prereqirements ..." -ForegroundColor Yellow
        $trash = Install-WindowsFeature Web-Default-Doc,Web-Dir-Browsing,Web-Http-Errors,Web-Static-Content,Web-Windows-Auth -Restart:$false -WarningAction SilentlyContinue
        $trash = Install-WindowsFeature Web-Http-Logging,Web-Stat-Compression,Web-Filtering,Web-Net-Ext45,Web-Asp-Net45,Web-ISAPI-Ext,Web-ISAPI-Filter,Web-Mgmt-Console -Restart:$false  -WarningAction SilentlyContinue

        $MSIArguments = @(
            "/i"
            "$source\Redistr\x64\rewrite_amd64.msi"
            "/qn"
            "/norestart"
            "/L*v"
            "$logdir\12_Rewrite.txt"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        if (Select-String -path "$logdir\12_Rewrite.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
            }
            else {
                throw "Setup Failed"
                }

        ### Enterprise Manager Web
        Write-Host "    Installing Enterprise Manager Web ..." -ForegroundColor Yellow
        $MSIArguments = @(
            "/i"
            "$source\EnterpriseManager\BackupWeb_x64.msi"
            "/qn"
            "/L*v"
            "$logdir\13_EntWeb.txt"
            "ACCEPTEULA=YES"
            "VBREM_LICENSE_FILE=$licensefile"
            "VBREM_SERVICE_USER=$fulluser"
            "VBREM_SERVICE_PASSWORD=$password"
            "VBREM_SQLSERVER_SERVER=$env:COMPUTERNAME\VEEAMSQL2012"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        if (Select-String -path "$logdir\13_EntWeb.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
            }
            else {
                throw "Setup Failed"
                }

        ### Enterprise Manager Cloud Portal
        Write-Host "    Installing Enterprise Manager Cloud Portal ..." -ForegroundColor Yellow
        <#
        $MSIArguments = @(
            "/i"
            "$source\Cloud Portal\BackupCloudPortal_x64.msi"
            "/L*v"
            "$logdir\14_EntCloudPortal.txt"
            "/qn"
            "ACCEPTEULA=YES"
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow
        #>
        Start-Process "msiexec.exe" -ArgumentList "/i `"$source\Cloud Portal\BackupCloudPortal_x64.msi`" /l*v $logdir\14_EntCloudPortal.txt /qn ACCEPTEULA=`"YES`"" -Wait -NoNewWindow

        if (Select-String -path "$logdir\14_EntCloudPortal.txt" -pattern "Installation success or error status: 0.") {
            Write-Host "    Setup OK" -ForegroundColor Green
            }
            else {
                throw "Setup Failed"
                }

        ### Update 3
        Write-Host "Installing Update 3 ..." -ForegroundColor Yellow
        $Arguments = "/silent /noreboot /log $logdir\15_update.txt VBR_AUTO_UPGRADE=1"
        Start-Process "$source\Updates\veeam_backup_9.5.0.1536.update3_setup.exe" -ArgumentList $Arguments -Wait -NoNewWindow
        #endregion

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
 }
 
