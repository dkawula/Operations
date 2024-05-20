# Full Credit for this initial script to: #https://gist.githubusercontent.com/TechnologistAU/33c61dced4f4437695f5c8beb7ab5144/raw
#Script Updated and tested on Windows 2016 VM
#This Script Requires WMF 5.1 to be installed first other than that it works
#If it fails check the URL's for PHP those constantly change
#Updated by Dave Kawula -MVP
#May 7, 2024
<#
================================================================================
===== WordPress Installation Script for Windows Server 2012/2016 and Windows 10 =====
================================================================================
#>

"`r`nWordPress Installation Script for Windows Server 2016 and Windows 10"
"===================================================================="

cd ~\Downloads

<#
======================== Internet Information Services =========================
#>

"`r`nInternet Information Server ..."
"  - Installing Features"
If ((Get-CimInstance Win32_OperatingSystem).ProductType -eq 1) {

	# Windows Client

	Enable-WindowsOptionalFeature -FeatureName `
		IIS-WebServerRole,IIS-WebServer,IIS-CommonHttpFeatures,IIS-StaticContent, `
		IIS-DefaultDocument,IIS-DirectoryBrowsing,IIS-HttpErrors, `
		IIS-ApplicationDevelopment,IIS-CGI,IIS-HealthAndDiagnostics, `
		IIS-HttpLogging,IIS-LoggingLibraries,IIS-RequestMonitor,IIS-Security, `
		IIS-RequestFiltering,IIS-Performance,IIS-HttpCompressionStatic, `
		IIS-WebServerManagementTools,IIS-ManagementConsole,IIS-ManagementService, `
		WAS-WindowsActivationService,WAS-ProcessModel,WAS-NetFxEnvironment, `
		WAS-ConfigurationAPI,NetFx3 -Online -All -Source D:\Sources\sxs | Out-Null
}
Else {

	# Windows Server

	Install-WindowsFeature `
		Web-Server,Web-Common-Http,Web-Static-Content,Web-Default-Doc, `
		Web-Dir-Browsing,Web-Http-Errors,Web-App-Dev,Web-CGI,Web-Health, `
		Web-Http-Logging,Web-Log-Libraries,Web-Request-Monitor,Web-Security, `
		Web-Filtering,Web-Performance,Web-Stat-Compression,Web-Mgmt-Tools, `
		Web-Mgmt-Service,WAS,WAS-Process-Model,WAS-NET-Environment, `
		WAS-Config-APIs,Net-Framework-Core -IncludeManagementTools | Out-Null
}

# Enable Remote Management Service
"  - Enabling Remote Management"
Set-ItemProperty HKLM:\SOFTWARE\Microsoft\WebManagement\Server EnableRemoteManagement 1
Set-Service WMSVC -StartupType Automatic
Start-Service WMSVC

"Done."

# Download and install the "URL Rewrite 2.1" Extension for IIS
"`r`nURL Rewrite 2.1 Extension for IIS ..."
"  - Downloading"
Invoke-WebRequest "http://download.microsoft.com/download/D/D/E/DDE57C26-C62C-4C59-A1BB-31D58B36ADA2/rewrite_amd64_en-US.msi" -OutFile "rewrite_amd64.msi"
"  - Installing"
Start-Process "msiexec.exe" "/i rewrite_amd64.msi /qn" -Wait
"Done."

<#
==================== File System Security PowerShell Module ====================
#>

# Download and extract the "File System Security PowerShell Module"
"`r`nFile System Security PowerShell Module ..."
#"  - Downloading"
#Invoke-WebRequest "https://gallery.technet.microsoft.com/scriptcenter/1abd77a5-9c0b-4a2b-acef-90dbb2b84e85/file/107400/19/NTFSSecurity.zip" -OutFile "NTFSSecurity.zip"
#"  - Expanding"
#Expand-Archive "NTFSSecurity.zip" "$env:ProgramFiles\WindowsPowerShell\Modules\NTFSSecurity"
#Need WMF5.1 if installing this on 2012R2
Install-Module -Name NTFSSecurity -RequiredVersion 4.2.4
Import-Module NTFSSecurity

"Done."

<#
===================== Visual C++ Redistributable Packages ======================
#>

# Download and install the Visual C++ 2013 Redistributable (required for MySQL)
"`r`nVisual C++ Redistributables ..."
#"  - Downloading"
#Invoke-WebRequest "https://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe" -OutFile "vc_redist_2013_x64.exe"
#"  - Installing"
#.\vc_redist_2013_x64.exe /Q

Install-Module VcRedist
Import-Module VcRedist
New-Item -Itemtype Directory -Path C:\Post-Install -Name VcRedist
$VcList = Get-VcList | Get-VcRedist -Path "C:\Post-Install\VcRedist"
$VcList | Install-VcRedist -Path C:\Post-Install\VcRedist


"Done."

# Download and install the Visual C++ 2015 Redistributable (required for PHP 7.x)
#"`r`nVisual C++ 2015 Redistributable ..."
#"  - Downloading"
#Invoke-WebRequest "https://download.microsoft.com/download/9/3/F/93FCF1E7-E6A4-478B-96E7-D4B285925B00/vc_redist.x64.exe" -OutFile "vc_redist_2015_x64.exe"
#"  - Installing"
#.\vc_redist_2015_x64.exe /Q
#"Done."

<#
============================== MySQL Server 5.7 ================================
#>

# Set temporary variables to be used during MySQL installation
$MYSQL_ZIP = "mysql-5.7.21-winx64"
#https://downloads.mysql.com/archives/get/p/23/file/mysql-5.7.21-winx64.zip
$MYSQL_URL = "https://downloads.mysql.com/archives/get/p/23/file/$MYSQL_ZIP.zip"
$MYSQL_NAME = "MySQL"
$MYSQL_PROD = "$MYSQL_NAME Server 5.7"
$MYSQL_PATH = "$env:ProgramFiles\$MYSQL_NAME"
$MYSQL_BASE = "$MYSQL_PATH\$MYSQL_PROD"
$MYSQL_PDTA = "$env:ProgramData\$MYSQL_NAME\$MYSQL_PROD"
$MYSQL_DATA = "$MYSQL_PDTA\data"
$MYSQL_INIT = "$MYSQL_PDTA\mysql-init.sql"

# Download and install MySQL
"`r`n$MYSQL_PROD ..."
"  - Downloading"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -uri "$MYSQL_URL" -OutFile "$MYSQL_ZIP.zip"
"  - Expanding"
Expand-Archive "$MYSQL_ZIP.zip" "$MYSQL_PATH"
"  - Renaming destination directory"
Rename-Item "$MYSQL_PATH\$MYSQL_ZIP" "$MYSQL_BASE"

# Add the MySQL â€œbinâ€ directory to the search Path variable
"  - Setting PATH variable"
$env:Path += ";$MYSQL_BASE\bin"
setx Path $env:Path /m

# Create a MySQL Option File
"  - Creating MY.INI"
Set-Content "$MYSQL_BASE\my.ini" "[mysqld]`r`nbasedir=""$MYSQL_BASE""`r`ndatadir=""$MYSQL_DATA""`r`nexplicit_defaults_for_timestamp=1"

# Create the MySQL database directory
"  - Creating database directory"
New-Item $MYSQL_DATA -ItemType "Directory" | Out-Null

# Initialise the MySQL database files
"  - Initialising database directory"
mysqld --initialize-insecure # --console

# Install MySQL as a Windows service
"  - Installing MySQL as Windows Service"
mysqld --install

# Start the MySQL service
"  - Starting MySQL Windows Service"
Start-Service MySQL

# Generate random passwords for 'root' and 'wordpress' accounts
Add-Type -AssemblyName System.Web
$MYSQL_ROOT_PWD = [System.Web.Security.Membership]::GeneratePassword(18,3)
$MYSQL_WORD_PWD = [System.Web.Security.Membership]::GeneratePassword(18,3)

# Create a MySQL initialisation script
"  - Generating initialisation script"
Set-Content $MYSQL_INIT "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PWD';"
Add-Content $MYSQL_INIT "CREATE DATABASE wordpress;"
Add-Content $MYSQL_INIT "CREATE USER 'wordpress'@'localhost' IDENTIFIED BY '$MYSQL_WORD_PWD';"
Add-Content $MYSQL_INIT "GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'localhost';"

# Execute the MySQL initialisation script
"  - Executing initialisation script"
mysql --user=root --execute="source $MYSQL_INIT"

# Delete the MySQL initialisation script
"  - Deleting initialisation script"
Remove-Item $MYSQL_INIT

"Done."

<#
=================================== PHP 7.1 ====================================
#>

# Set temporary variables to be used during PHP installation
$PHP_ZIP = "php-7.4.30-nts-Win32-VC15-x64.zip"
$PHP_PATH = "$env:ProgramFiles\PHP\v7.4"
$PHP_DATA = "$env:ProgramData\PHP\v7.4"
$WINCACHE = "wincache-2.0.0.8-dev-7.1-nts-vc14-x64"
$WINCacheURI = "https://sourceforge.net/projects/wincache/files/development/wincache-2.0.0.8-dev-7.1-nts-vc14-x64.exe/download"
$WINCacheEXE = "wincache-2.0.0.8-dev-7.1-nts-vc14-x64.exe"

# Download and install PHP
"`r`nPHP 7.1 ..."
"  - Downloading"
Invoke-WebRequest "https://windows.php.net/downloads/releases/archives/$PHP_ZIP" -OutFile "$PHP_ZIP"
"  - Expanding"
Expand-Archive "$PHP_ZIP" "$PHP_PATH"
"  - Creating PHP.INI"
Copy-Item "$PHP_PATH\php.ini-production" "$PHP_PATH\php.ini"
"Done."

#Download and install chrome
" - Downloading and installing Chrome"
$LocalTempDir = $env:TEMP; $ChromeInstaller = "ChromeInstaller.exe"; (new-object System.Net.WebClient).DownloadFile('http://dl.google.com/chrome/install/375.126/chrome_installer.exe', "$LocalTempDir\$ChromeInstaller"); & "$LocalTempDir\$ChromeInstaller" /silent /install; $Process2Monitor =  "ChromeInstaller"; Do { $ProcessesFound = Get-Process | ?{$Process2Monitor -contains $_.Name} | Select-Object -ExpandProperty Name; If ($ProcessesFound) { "Still running: $($ProcessesFound -join ', ')" | Write-Host; Start-Sleep -Seconds 2 } else { rm "$LocalTempDir\$ChromeInstaller" -ErrorAction SilentlyContinue -Verbose } } Until (!$ProcessesFound)


# Download and install WinCache
"`r`nWinCache 2.0 ..."
"  - Downloading"

Invoke-WebRequest -Uri $WINCacheURI -OutFile $WINCacheEXE -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::Chrome

"  - Expanding"
Start-Process "wincache-2.0.0.8-dev-7.1-nts-vc14-x64.exe" "/Q /C /T:""$env:USERPROFILE\Downloads\$WINCACHE""" -Wait
"  - Installing"
Copy-Item "$WINCACHE\php_wincache.dll" "$PHP_PATH\ext\php_wincache.dll"
"  - Removing temporary files"
Remove-Item "$WINCACHE" -Recurse -Force
"Done."

# Download and install PHP Manager for IIS
"`r`nPHP Manager for IIS 1.4.0 ..."
"  - Downloading"
Invoke-WebRequest "https://github.com/edgardo001/PHPManagerForIIS-Versiones/raw/master/PHPManagerForIIS-1.4.0-x64%20-%20IIS%2010.msi" -OutFile "PHPManagerForIIS-1.4.0-x64.msi"
"  - Installing"
Start-Process "msiexec.exe" "/i PHPManagerForIIS-1.4.0-x64.msi /qn" -Wait
"  - Waiting"
Start-Sleep -s 5
"Done."

"`r`nConfigure PHP with IIS ..."

# Add the PHP Manager PowerShell Snap-In
Add-PsSnapin PHPManagerSnapin

# Register PHP with Internet Information Services (IIS)
New-PHPVersion "$PHP_PATH\php-cgi.exe"

# Configure various PHP extensions
Set-PHPExtension php_wincache.dll Enabled
Set-PHPExtension php_mysql.dll Disabled

# Configure various PHP settings
Set-PHPSetting date.timezone UTC
Set-PHPSetting upload_max_filesize 20M

# Relocate the PHP "Logs" directory
$PHP_LOGS = "$PHP_DATA\Logs"
New-Item $PHP_LOGS -ItemType Directory -Force | Out-Null
Set-PHPSetting error_log "$PHP_LOGS\php_errors.log"

# Relocate the PHP â€œUploadâ€ directory to address potential media permission issues
$PHP_UPLOAD = "$PHP_DATA\Upload"
New-Item $PHP_UPLOAD -ItemType Directory -force | Out-Null
Add-NTFSAccess $PHP_UPLOAD IUSR Modify
Add-NTFSAccess $PHP_UPLOAD IIS_IUSRS Modify
Set-PHPSetting upload_tmp_dir "$PHP_UPLOAD"

"Done."

<#
================================== WordPress ===================================
#>

# Set temporary variables to be used during the WordPress installation
$IIS_PATH = "$env:SystemDrive\inetpub"
$WORDPRESS_PATH = "$IIS_PATH\wordpress"
$WORDPRESS_URL = "https://wordpress.org/latest.zip"
$WORDPRESS_ZIP = "wordpress.zip"

# Download and install WordPress
"`r`nWordPress ..."
"  - Downloading"
Invoke-WebRequest "$WORDPRESS_URL" -OutFile "$WORDPRESS_ZIP"
"  - Expanding"
Expand-Archive "$WORDPRESS_ZIP" "$IIS_PATH"

# Grant the IIS_IUSRS and IUSR accounts Modify rights to the WordPress directory
"  - Appying NTFS Permissions (IIS_IUSRS)"
Add-NTFSAccess "$WORDPRESS_PATH" IIS_IUSRS Modify
"  - Appying NTFS Permissions (IUSR)"
Add-NTFSAccess "$WORDPRESS_PATH" IUSR Modify

# Create a new Internet Information Services application pool for WordPress
"  - Creating Application Pool"
$WebAppPool = New-WebAppPool "WordPress"
$WebAppPool.managedPipelineMode = "Classic"
$WebAppPool.managedRuntimeVersion = ""
$WebAppPool | Set-Item

# Create a new Internet Information Services website for WordPress
"  - Creating WebSite"
New-Website "WordPress" -ApplicationPool "WordPress" -PhysicalPath "$WORDPRESS_PATH"  | Out-Null

# Remove the â€œDefault Web Siteâ€ and start the new â€œWordPressâ€ website
"  - Activating WebSite"
Remove-Website "Default Web Site"
Start-Website "WordPress"

"Done."

<#
================================================================================
#>

"`r`nInstallation Complete!`r`n"
"MySQL Accounts"
"       root = $MYSQL_ROOT_PWD"
"  wordpress = $MYSQL_WORD_PWD"
$IPADDRESS = (Get-NetIPAddress | ? {($_.AddressFamily -eq "IPv4") -and ($_.IPAddress -ne "127.0.0.1")}).IPAddress
"`r`nConnect your web browser to http://$IPADDRESS/ to complete this WordPress`r`ninstallation.`r`n"