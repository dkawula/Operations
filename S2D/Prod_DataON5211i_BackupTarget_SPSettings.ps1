#Store all physical disks that can be pooled into a variable, $pd
$pd = (Get-PhysicalDisk -CanPool $True | Where MediaType -NE UnSpecified)
$pd
#Create a new Storage Pool using the disks in variable $pd with a name of My Storage Pool
Get-StorageSubSystem | New-StoragePool -PhysicalDisks $pd -FriendlyName “VeeamSP01” -Verbose
#View the disks in the Storage Pool just created
Get-StoragePool -FriendlyName “VeeamSP01” | Get-PhysicalDisk | Select FriendlyName, MediaType

#Create two tiers in the Storage Pool created. One for SSD disks and one for HDD disks
$ssd_Tier = New-StorageTier -StoragePoolFriendlyName “VeeamSP01” -FriendlyName SSD_Tier -MediaType SSD
$hdd_Tier = New-StorageTier -StoragePoolFriendlyName “VeeamSP01” -FriendlyName HDD_Tier -MediaType HDD

#New-VirtualDisk –SNtoragePoolFriendlyName “My Storage Pool” –ResiliencySettingName Simple –Size 10TB –Provisioningtype Thin –FriendlyName “Documents”
#Create a new virtual disk in the pool with a name of TieredSpace using the SSD (50GB) and HDD (300GB) tiers
$vd1 = New-VirtualDisk -StoragePoolFriendlyName “VeeamSP01” -FriendlyName TieredSpace -StorageTiers @($ssd_tier, $hdd_tier) -StorageTierSizes @(50GB, 300GB) -ResiliencySettingName Mirror -WriteCacheSize 1GB #cannot also specify -size if using tiers and also cannot use provisioning type, e.g. Thin