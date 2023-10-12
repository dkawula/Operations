#Harden IIS 8.5 on Server 2012 R2  HSTS
#Just replace the Server with something more modern but if you can't here you go.
#Do this site by site.
#This doesn't require a reboot
#Validate by going to https://securityheaders.com

Import-Module WebAdministration
Add-WebConfigurationProperty -Filter "system.webServer/httpProtocol/customHeaders" -PSPath "IIS:\Sites\Default Web Site" -Name . -AtElement @{name="Strict-Transport-Security"} -Value @{name="Strict-Transport-Security";value="max-age=31536000; includeSubDomains"}  #MaxAge 31536000 = 1 year