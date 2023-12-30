#Script to Import STIGS into an Intune Tenant
#Dave Kawula-MVP
#Install Required Modules
Install-Module -Name AzureAD -Force
Install-Module -Name MSGraphFunctions -Force
Install-Module -Name Microsoft.Graph.Intune
Install-Module -Name IntuneBackupandRestore -Force

#Import Modules
Import-Module IntuneBackupandRestore -verbose

