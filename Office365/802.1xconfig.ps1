#Setting some parameters to make this work for intune.
#Create an Install.cmd with - powershell.exe -executionpolicy bypass -command "& '.\802.1xconfig.ps1' -install"
#Create an Uninstall.cmd with - powershell.exe -executionpolicy bypass -command "& '.\802.1xconfig.ps1' -uninstall"
#Put this script in the same working folder
#Package it with the https://github.com/Microsoft/Microsoft-Win32-Content-Prep-Tool

#Adding some logic for the install and uninstall switches

#region Parameters
[cmdletbinding()]
param
( 

 [Parameter(Mandatory=$false)] 
    [SWITCH]$install,

    [Parameter(Mandatory=$false)] 
    [SWITCH]$uninstall
    
) 


If ($Install)

{
#Windows 10 Post Configuration Script
#Turn on 802.1x Authentication Tab on the Network Adapter Properties
#Deploy the Root Certificates first using Intune

#This might get packaged as a Win32 App / Required
#It will come down after the Certs so it should work.

#Service is set to manual by default
Get-Service -Name dot3svc | Set-Service -StartupType Automatic

#Start the Service if not running
Get-Service -Name dot3svc | Set-Service -Status Running  

#Take the XML File that was exported and copy it into the script then generate a new XML File in c:\Temp

$LanProfileSource = [xml]@"
<?xml version="1.0"?>
<LANProfile xmlns="http://www.microsoft.com/networking/LAN/profile/v1">
	<MSM>
		<security>
			<OneXEnforced>false</OneXEnforced>
			<OneXEnabled>true</OneXEnabled>
			<OneX xmlns="http://www.microsoft.com/networking/OneX/v1">
				<cacheUserData>true</cacheUserData>
				<EAPConfig><EapHostConfig xmlns="http://www.microsoft.com/provisioning/EapHostConfig"><EapMethod><Type xmlns="http://www.microsoft.com/provisioning/EapCommon">13</Type><VendorId xmlns="http://www.microsoft.com/provisioning/EapCommon">0</VendorId><VendorType xmlns="http://www.microsoft.com/provisioning/EapCommon">0</VendorType><AuthorId xmlns="http://www.microsoft.com/provisioning/EapCommon">0</AuthorId></EapMethod><Config xmlns="http://www.microsoft.com/provisioning/EapHostConfig"><Eap xmlns="http://www.microsoft.com/provisioning/BaseEapConnectionPropertiesV1"><Type>13</Type><EapType xmlns="http://www.microsoft.com/provisioning/EapTlsConnectionPropertiesV1"><CredentialsSource><CertificateStore><SimpleCertSelection>true</SimpleCertSelection></CertificateStore></CredentialsSource><ServerValidation><DisableUserPromptForServerValidation>false</DisableUserPromptForServerValidation><ServerNames></ServerNames><TrustedRootCA>62 52 dc 40 f7 11 43 a2 2f de 9e f7 34 8e 06 42 51 b1 81 18 </TrustedRootCA><TrustedRootCA>07 e0 32 e0 20 b7 2c 3f 19 2f 06 28 a2 59 3a 19 a7 0f 06 9e </TrustedRootCA></ServerValidation><DifferentUsername>false</DifferentUsername><PerformServerValidation xmlns="http://www.microsoft.com/provisioning/EapTlsConnectionPropertiesV2">true</PerformServerValidation><AcceptServerName xmlns="http://www.microsoft.com/provisioning/EapTlsConnectionPropertiesV2">false</AcceptServerName></EapType></Eap></Config></EapHostConfig></EAPConfig>
			</OneX>
		</security>
	</MSM>
</LANProfile>
"@
$LanProfileSource.Save("c:\temp\ethernet.xml")

#Import Lan Profile

netsh lan add profile filename="c:\temp\ethernet.xml" interface="Ethernet 2"

#Reconnect the Interfaces
netsh lan reconnect interface=*

#Now we need a simple detection Method for the App It will just check to see if this file is here.

New-Item c:\temp\802.1x.installed.log -ItemType file -Force | out-null 

<#>
#Working

#Export existing configuration
netsh lan export profile folder=c:\temp interface="Ethernet 2"

#Sample Configuration
$LanProfileSource = [xml]@"
<?xml version="1.0"?>
<LANProfile xmlns="http://www.microsoft.com/networking/LAN/profile/v1">
	<MSM>
		<security>
			<OneXEnforced>false</OneXEnforced>
			<OneXEnabled>true</OneXEnabled>
			<OneX xmlns="http://www.microsoft.com/networking/OneX/v1">
				<cacheUserData>true</cacheUserData>
				<EAPConfig><EapHostConfig xmlns="http://www.microsoft.com/provisioning/EapHostConfig"><EapMethod><Type xmlns="http://www.microsoft.com/provisioning/EapCommon">13</Type><VendorId xmlns="http://www.microsoft.com/provisioning/EapCommon">0</VendorId><VendorType xmlns="http://www.microsoft.com/provisioning/EapCommon">0</VendorType><AuthorId xmlns="http://www.microsoft.com/provisioning/EapCommon">0</AuthorId></EapMethod><Config xmlns="http://www.microsoft.com/provisioning/EapHostConfig"><Eap xmlns="http://www.microsoft.com/provisioning/BaseEapConnectionPropertiesV1"><Type>13</Type><EapType xmlns="http://www.microsoft.com/provisioning/EapTlsConnectionPropertiesV1"><CredentialsSource><CertificateStore><SimpleCertSelection>true</SimpleCertSelection></CertificateStore></CredentialsSource><ServerValidation><DisableUserPromptForServerValidation>false</DisableUserPromptForServerValidation><ServerNames></ServerNames><TrustedRootCA>62 52 dc 40 f7 11 43 a2 2f de 9e f7 34 8e 06 42 51 b1 81 18 </TrustedRootCA><TrustedRootCA>07 e0 32 e0 20 b7 2c 3f 19 2f 06 28 a2 59 3a 19 a7 0f 06 9e </TrustedRootCA></ServerValidation><DifferentUsername>false</DifferentUsername><PerformServerValidation xmlns="http://www.microsoft.com/provisioning/EapTlsConnectionPropertiesV2">true</PerformServerValidation><AcceptServerName xmlns="http://www.microsoft.com/provisioning/EapTlsConnectionPropertiesV2">false</AcceptServerName></EapType></Eap></Config></EapHostConfig></EAPConfig>
			</OneX>
		</security>
	</MSM>
</LANProfile>
"@
$LanProfileSource.Save("c:\temp\ethernet.xml")

</#>

}

If ($uninstall)

{
#If uninstall we should just need to Stopp the Service and return to a Manual Startup Type
#Yes I know settings will be held we can work on some more logic later

#Service is set to manual by default
Get-Service -Name dot3svc | Set-Service -StartupType Manual

#Start the Service if not running
Get-Service -Name dot3svc | Stop-Service -Force

#Reconnect the Interfaces
netsh lan reconnect interface=*

}

else

{
Write-Host "No Options Selected"| Out-null
}