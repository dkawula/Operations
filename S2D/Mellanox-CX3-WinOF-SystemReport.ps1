#Mellanox System Report for Mellanox CX3-Pro wind WINOF Drivers
#Doesn't work on the Mellanox CX-4 Cards and WinOF2
#Author Dave Kawula MVP
#Creation Date August 20, 2017
#Builds a nice report of the Mellanox Cards in an S2D Cluster
$Header = @"
<style>
TABLE {border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse;}
TH {border-width: 1px; padding: 3px; border-style: solid; border-color: black; background-color: #6495ED;}
TD {border-width: 1px; padding: 3px; border-style: solid; border-color: black;}
</style>
"@

#$Job1 = Get-MlnxSoftwareIdentity | ConvertTo-Html -Property Name,Caption,VersionString,InstallDate,InstallLocation -Head $Header | Out-File -FilePath MellanoxSoftwareInstall.html


#$Job0 = Get-ComputerInfo | ConvertTo-Html -Property CsDNSHostName,CsDomain,

$Job0 = Get-ComputerInfo | ConvertTo-Html -Property CSDNSHostName,WindowsEditionId,OSServerLevel,OSUptime,OsFreePhysicalMemory,CSModel,CSManufacturer,CSNumberOfLogicalProcessors,CSNumberofProcessors,HyperVisorPresent -Fragment
$Job1 = Get-MLNXPCIDevice | ConvertTo-Html -Property Systemname,Caption,Description,DeviceID,LastErrorCode,DriverVersion,FirmwareVersion -Fragment
$Job2 = Get-MlnxPCIDeviceSetting | ConvertTo-Html -Property Systemname,Caption,Description,InstanceID -Fragment
$Job3 = Get-MLNXPCIDeviceCapabilities | ConvertTo-Html -Property Systemname,Caption,Description,PortOneAutoSense,PortOneDefault,PortOneAutoSenseAllowed,PortOneEth,PorttwoIb,PortTwoAutoSenseCap,PortTwoDefault,PortTwoDoSenseAllowed,PortTwoEth,PortTwoIB -Fragment
$Job4 = Get-MlnxNetAdapter | ConvertTo-Html -Property Systemname,Caption,Description,Name,ErrorDescription,MaxSpeed,MaxTransmissionUnit,AutoSense,FullDuplex,LinkTechnology,PortNumber,DroplessMode -Fragment
$job5 = Get-MlnxNetAdapterRoceSetting | ConvertTo-Html -Property Systemname,Caption,Description,InterfaceDescription,PortNumber,RoceMode,Enabled -Fragment
$job6 = Get-MlnxIBPort | ConvertTo-Html -Property Systemname,Caption,Description,MaxSpeed,PortType,Speed,ActiveMaximumTransmissionUnit,PortNumberSupportedMaximumTransmissionUnit,MaxMsgSize,MaxVls,NumGids,NumPkeys,Transport -Fragment
$job7 = Get-MlnxIBPortCounters | ConvertTo-Html -Property Systemname,Caption,Description,StatisticTime,BytesReceived,BytesTransmitted,PacketsReceived,PacketsTransmitted,ExcessiveBufferOverflows,LinkDownCounter,LinterErrorRecoveryCounter,PortRcvErrors -Fragment
#Todo Need to add the system name to this table
$job8 = Get-MlnxFirmwareIdentity | ConvertTo-Html -Property Caption,Description,Name,Manufacturer,VersionString 

ConvertTo-Html -Body "<H1>CheckyourLogs.Net Mellanox Storage Spaces Direct S2D Node Configuration Report </H1><H1> S2D System Information </H3> $Job0 <H1> Mellanox Software  </H1> $Job1 <h1>Mellanox PCI Device Settings</h1> $Job2 <H1> Mellanox Device Capabilities </H1> $Job3 <H1> Mellanox NetAdapter Info </H1>$Job4 <H1> Mellanox ROCE Settings </H1> $Job5 <H1> Mellanox IB Port Configuration </H1> $Job6 <H1> Mellanox IB Port Counters </H1>$Job7 <H1> Mellanox Adapter Firmware </H1> $Job8" -Title "Mellanox Adapter Configuraiton" -Head $Header |Out-File mellanoxreport.html


