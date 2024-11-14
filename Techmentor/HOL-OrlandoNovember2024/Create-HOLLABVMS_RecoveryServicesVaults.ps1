#This script will pre-create the base of the Recovery Service Vaults in Azure for the Techmentor Lab
#This is done to save time during the 1 day HOL Lab experience.
#Dave Kawula-MVP

# Define parameters
$resourceGroup = "rgtmlab"   # Replace with your resource group name
$location = "Canada Central"                 # Replace with the desired Azure region, e.g., "EastUS"

Connect-AzAccount -devicecode

# Create vaults from Student01Vault to Student60Vault
for ($i = 1; $i -le 50; $i++) {
    $vaultName = "Student{0:D2}Vault" -f $i
    Write-Output "Creating Site Recovery Vault: $vaultName in $location"

    # Create the Site Recovery Vault
    New-AzRecoveryServicesVault -ResourceGroupName $resourceGroup -Name $vaultName -Location $location

    Write-Output "Created: $vaultName"
}
