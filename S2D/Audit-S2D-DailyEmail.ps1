

#requires -version 5.0

<#
.SYNOPSYS
    This script audit an S2D hyperconverged infrastructure
.VERSION
    0.1: Initial version
    0.2: Add option to export path
    0.3: Change consolidation rate to not take into account hyperthreading
    0.4: Resolve bugs, add information
    0.5: Force charset to UTF-8, resolve special char issue. Add trademark.
    0.6: Resolve an issue to match the Network Adapter with VMNetworkAdapter
    2.0: Updated by Dave Kawula MVP to allow HTML Email Reporting Functionality
.AUTHOR
    Romain Serre
    Blog: https://www.tech-coffee.net
    Twitter: @RomSerre
.AUTHOR
    Dave Kawula
    Blog: https://www.checkyourlogs.net
    Twitter: @DaveKawula
#>

##### Parameters #####
# ----------------------------------------------------------------

[CmdletBinding()]
param(
    [Parameter(Mandatory=$True, HelpMessage='Specify the name of the cluster')]
    [Alias('S2DCluster')]
    [string]$ClusterName,
    [Parameter(Mandatory=$True, HelpMessage='Specify the domain')]
    [Alias('ComputerDomain')]
    [String]$DomainName,
    [Parameter(Mandatory=$True, HelpMessage='Specify the folder where the report will be exported')]
    [Alias('ExportPath')]
    [String]$Path
    #[Parameter(Mandatory=$True, HelpMessage='Specify Credentials')]
    #[Alias('Cred')]
    ##[PSCredential]$Credential
    )


##### Function #####
# ----------------------------------------------------------------
Function Get-OSLanguage {
# This function returns the human comprehensive os language from the WMI Win32_OperatingSystem OSLanguage method
    Param([int]$Language)

    Switch ($Language){
        1 {$Lang='Arabic'}
        4 {$Lang='Chinese (Simplified) &#8208; China'}
        9 {$Lang='English'}
        1025 {$Lang='Arabic &#8208; Saudi Arabia'}
        1026 {$Lang='Bulgarian'}
        1027 {$Lang='Catalan'}
        1028 {$Lang='Chinese (Traditional) &#8208; Taiwan'}
        1029 {$Lang='Czech'}
        1030 {$Lang='Danish'}
        1031 {$Lang='German &#8208; Germany'}
        1032 {$Lang='Greek'}
        1033 {$Lang='English &#8208; United States'}
        1034 {$Lang='Spanish &#8208; Traditional Sort'}
        1035 {$Lang='Finnish'}
        1036 {$Lang='French &#8208; France'}
        1037 {$Lang='Hebrew'}
        1038 {$Lang='Hungarian'}
        1039 {$Lang='Icelandic'}
        1040 {$Lang='Italian &#8208; Italy'}
        1041 {$Lang='Japanese'}
        1042 {$Lang='Korean'}
        1043 {$Lang='Dutch &#8208; Netherlands'}
        1044 {$Lang='Norwegian &#8208; Bokmal'}
        1045 {$Lang='Polish'}
        1046 {$Lang='Portuguese &#8208; Brazil'}
        1047 {$Lang='Rhaeto-Romanic'}
        1048 {$Lang='Romanian'}
        1049 {$Lang='Russian'}
        1050 {$Lang='Croatian'}
        1051 {$Lang='Slovak'}
        1052 {$Lang='Albanian'}
        1053 {$Lang='Swedish'}
        1054 {$Lang='Thai'}
        1055 {$Lang='Turkish'}
        1056 {$Lang='Urdu'}
        1057 {$Lang='Indonesian'}
        1058 {$Lang='Ukrainian'}
        1059 {$Lang='Belarusian'}
        1060 {$Lang='Slovenian'}
        1061 {$Lang='Estonian'}
        1062 {$Lang='Latvian'}
        1063 {$Lang='Lithuanian'}
        1065 {$Lang='Persian'}
        1066 {$Lang='Vietnamese'}
        1069 {$Lang='Basque (Basque)'}
        1070 {$Lang='Serbian'}
        1071 {$Lang='Macedonian (Macedonia (FYROM))'}
        1072 {$Lang='Sutu'}
        1073 {$Lang='Tsonga'}
        1074 {$Lang='Tswana'}
        1076 {$Lang='Xhosa'}
        1077 {$Lang='Zulu'}
        1078 {$Lang='Afrikaans'}
        1080 {$Lang='Faeroese'}
        1081 {$Lang='Hindi'}
        1082 {$Lang='Maltese'}
        1084 {$Lang='Scottish Gaelic (United Kingdom)'}
        1085 {$Lang='Yiddish'}
        1086 {$Lang='Malay &#8208; Malaysia'}
        2049 {$Lang='Arabic &#8208; Iraq'}
        2052 {$Lang='Chinese (Simplified) &#8208; PRC'}
        2055 {$Lang='German &#8208; Switzerland'}
        2057 {$Lang='English &#8208; United Kingdom'}
        2058 {$Lang='Spanish &#8208; Mexico'}
        2060 {$Lang='French &#8208; Belgium'}
        2064 {$Lang='Italian &#8208; Switzerland'}
        2067 {$Lang='Dutch &#8208; Belgium'}
        2068 {$Lang='Norwegian &#8208; Nynorsk'}
        2070 {$Lang='Portuguese &#8208; Portugal'}
        2072 {$Lang='Romanian &#8208; Moldova'}
        2073 {$Lang='Russian &#8208; Moldova'}
        2074 {$Lang='Serbian &#8208; Latin'}
        2077 {$Lang='Swedish &#8208; Finland'}
        3073 {$Lang='Arabic &#8208; Egypt'}
        3076 {$Lang='Chinese (Traditional) &#8208; Hong Kong SAR'}
        3079 {$Lang='German &#8208; Austria'}
        3081 {$Lang='English &#8208; Australia'}
        3082 {$Lang='Spanish &#8208; International Sort'}
        3084 {$Lang='French &#8208; Canada'}
        3098 {$Lang='Serbian &#8208; Cyrillic'}
        4097 {$Lang='Arabic &#8208; Libya'}
        4100 {$Lang='Chinese (Simplified) &#8208; Singapore'}
        4103 {$Lang='German &#8208; Luxembourg'}
        4105 {$Lang='English &#8208; Canada'}
        4106 {$Lang='Spanish &#8208; Guatemala'}
        4108 {$Lang='French &#8208; Switzerland'}
        5121 {$Lang='Arabic &#8208; Algeria'}
        5127 {$Lang='German &#8208; Liechtenstein'}
        5129 {$Lang='English &#8208; New Zealand'}
        5130 {$Lang='Spanish &#8208; Costa Rica'}
        5132 {$Lang='French &#8208; Luxembourg'}
        6145 {$Lang='Arabic &#8208; Morocco'}
        6153 {$Lang='English &#8208; Ireland'}
        6154 {$Lang='Spanish &#8208; Panama'}
        7169 {$Lang='Arabic &#8208; Tunisia'}
        7177 {$Lang='English &#8208; South Africa'}
        7178 {$Lang='Spanish &#8208; Dominican Republic'}
        8193 {$Lang='Arabic &#8208; Oman'}
        8201 {$Lang='English &#8208; Jamaica'}
        8202 {$Lang='Spanish &#8208; Venezuela'}
        9217 {$Lang='Arabic &#8208; Yemen'}
        9226 {$Lang=' Spanish &#8208; Colombia'}
        10241 {$Lang='Arabic &#8208; Syria'}
        10249 {$Lang='English &#8208; Belize'}
        10250 {$Lang='Spanish &#8208; Peru'}
        11265 {$Lang='Arabic &#8208; Jordan'}
        11273 {$Lang='English &#8208; Trinidad'}
        11274 {$Lang='Spanish &#8208; Argentina'}
        12289 {$Lang='Arabic &#8208; Lebanon'}
        12298 {$Lang='Spanish &#8208; Ecuador'}
        13313 {$Lang='Arabic &#8208; Kuwait'}
        13322 {$Lang='Spanish &#8208; Chile'}
        14337 {$Lang='Arabic &#8208; U.A.E.'}
        14346 {$Lang='Spanish &#8208; Uruguay'}
        15361 {$Lang='Arabic &#8208; Bahrain'}
        15370 {$Lang='Spanish &#8208; Paraguay'}
        16385 {$Lang='Arabic &#8208; Qatar'}
        16394 {$Lang='Spanish &#8208; Bolivia'}
        17418 {$Lang='Spanish &#8208; El Salvador'}
        18442 {$Lang='Spanish &#8208; Honduras'}
        19466 {$Lang='Spanish &#8208; Nicaragua'}
        20490 {$Lang='Spanish &#8208; Puerto Rico'}
    }
    Return $Lang
}

Function Get-VMHostHwInformation {
# This function collects Hyper-V hardware information and return an array
    Param([Array]$VMHosts,
          [String]$DomainName
          )

    $HWInformationArray = @()
    $i                  = 0

    Foreach ($VMHost in $VMHosts){
        # Show Progress bar
        Write-Progress -Activity "Collecting Hyper-V/S2D infrastructure information" `
                       -PercentComplete (($i/$VMHosts.Count)*100) `
                       -CurrentOperation "Collecting $($VMHost.Name) hardware information"
        $i++
        $CPUInfoArray = @()
        $VMHost       = $VMHost.Name + "." + $DomainName
        $VMHostObject = New-Object System.Object
        
        # Get Processor information
        $ComputerName = $env:ComputerName + "." + $DomainName

        # If the command is run on the local server, credential are not required
        If ($VMHost -like $ComputerName){
            $CPUs = Get-WmiObject -Class Win32_Processor -ComputerName $VMHost
        }
        else{
            $CPUs = Get-WmiObject -Class Win32_Processor -ComputerName $VMHost 
        }

        # Collecting CPU information for each socket
        Foreach ($CPU in $CPUs){
            $CPUObj = New-Object System.Object
            $CPUObj | Add-Member -Type NoteProperty -Name Name -Value $CPU.Name
            $CPUObj | Add-Member -Type NoteProperty -Name DeviceId -Value $CPU.DeviceId
            $CPUObj | Add-Member -Type NoteProperty -Name NumberOfCores -Value $CPU.NumberOfCores
            $CPUObj | Add-Member -TYpe NoteProperty -Name NumberOfLogicalProcessors -Value $CPU.NumberOfLogicalProcessors
            $CPUInfoArray += $CPUObj
        }
        $VMHostObject | Add-Member -Type NoteProperty -Name CPU -Value $CPUInfoArray

        # Get Physical Memory information
        If ($VMHost -like $ComputerName){
            $PhysicalMemory = ((Get-WmiObject -Class Win32_ComputerSystem -ComputerName $VMHost).TotalPhysicalMemory)/1GB
        }
        else {
            $PhysicalMemory = ((Get-WmiObject -Class Win32_ComputerSystem -ComputerName $VMHost).TotalPhysicalMemory)/1GB
        }

        # Memory is round to 0 decimal
        $PhysicalMemory = [Math]::Round($PhysicalMemory, 0)
        $VMHostObject | Add-Member -Type NoteProperty -Name Memory -Value $PhysicalMemory
        $VMHostObject | Add-Member -Type NoteProperty -Name Name   -Value $VMHost
        

        # Get Virtual Machine Information
        $vCPU        = 0
        $MemAssigned = 0
        $WorkloadObj = New-Object System.Object
        $VMs         = Get-VM -ComputerName $VMHost
        $VMs | Foreach {$vCPU += $_.ProcessorCount}
        $VMs | Foreach {$MemAssigned += $_.MemoryAssigned}
        $WorkloadObj  | Add-Member -Type NoteProperty -Name VMCount -Value $(($VMs | Measure-Object).Count)
        $WorkloadObj  | Add-Member -Type NoteProperty -Name vCPU -Value $($vCPU)
        $WorkloadObj  | Add-Member -Type NoteProperty -Name MemAssigned -Value $($MemAssigned/1GB)
        $VMHostObject | Add-Member -Type NoteProperty -Name Workload -Value $WorkloadObj

        $HwInformationArray += $VMHostObject
    }
    Return $HWInformationArray

}

Function Get-VMHostHyperVSettings {
# This function returns Hyper-V settings
    Param([Array]$VMHosts,
          [string]$DomainName)
  
    $HyperVConfArray = @()
    $i               = 0
    $ComputerName    = Get-Content ENV:COMPUTERNAME

    # foreach node in the cluster
    Foreach ($VMHost in $VMHosts){

        # Show Progress bar
        Write-Progress -Activity "Collecting Hyper-V/S2D infrastructure information" `
                       -PercentComplete (($i/$VMHosts.Count)*100) `
                       -CurrentOperation "Collecting $($VMHost.Name) Hyper-V information"
       
        $Hostname = $VMHost.Name + "." + $DomainName

        # if the script is executed from the current node,get information locally
        If ($VMHost.Name -like $ComputerName){
           $HyperVSettings = Get-VMHost 
        }
        # else connecting remotely to the node with credential to get Hyper-V settings
        Else {
            $HyperVSettings = Invoke-Command -ComputerName $HostName {Get-VMHost}
        }

        # Add information to an array
        $HyperVObj = New-Object System.Object
        $HyperVObj | Add-Member -Type NoteProperty -Name VMHost -Value $VMHost.Name
        $HyperVObj | Add-Member -Type NoteProperty -Name VMPath -Value $HyperVSettings.VirtualMachinePath
        $HyperVObj | Add-Member -Type NoteProperty -Name VHDPath -Value $HyperVSettings.VirtualHardDiskPath
        $HyperVObj | Add-Member -Type NoteProperty -Name MaximumLM -Value $HyperVSettings.MaximumVirtualMachineMigrations
        $HyperVObj | Add-Member -Type NoteProperty -Name MaximumStoMig -Value $HyperVSettings.MaximumStorageMigrations
        $HyperVObj | Add-Member -Type NoteProperty -Name LMAuthentication -Value $HyperVSettings.VirtualMachineMigrationAuthenticationType
        $HyperVObj | Add-Member -Type NoteProperty -Name LMPerformanceOption -Value $HyperVSettings.VirtualMachineMigrationPerformanceOption
        $HyperVConfArray += $HyperVObj

        $i++
    }
    Return $HyperVConfArray
}
    
Function Get-VMHostStorage {
# This function collects local Hyper-V host storage information and return an array
    Param([Array]$VMHosts,
          [String]$DomainName)

    $StoInformationArray = @()
    $i                   = 0
    Foreach ($VMHost in $VMHosts){
        # Show a progress bar
        Write-Progress -Activity "Collecting Hyper-V/S2D infrastructure information" `
                       -PercentComplete (($i/$VMHosts.Count)*100) `
                       -CurrentOperation "Collecting $($VMHost.Name) storage information"
        $i++
        $StoArray     = @()
        $VMHost       = $VMHost.Name + "." + $DomainName
        $StoObject = New-Object System.Object

        # if the script is run on a local computer, there is no need of credential
        $ComputerName = $env:ComputerName + "." + $DomainName
        If ($VMHost -like $ComputerName){
            $LocalStorage = Invoke-Command -ComputerName $VMHost {Get-Volume | Where-Object {($_.FileSystem -like "NTFS") -or ($_.FileSystem -like "REFS")}}
        }
        Else{
            $LocalStorage = Invoke-Command -ComputerName $VMHost {Get-Volume | Where-Object {($_.FileSystem -like "NTFS") -or ($_.FileSystem -like "REFS")}}
        }
        $StoObject | Add-Member -Type NoteProperty -Name Name -Value $VMHost

        # For each storage device, collecting its information (size, drive label, file system and so on)
        Foreach ($Storage in $LocalStorage){
            $StoObj    = New-Object System.Object
            $StoObj    | Add-Member -Type NoteProperty -Name DriveLetter -Value $Storage.DriveLetter
            $StoObj    | Add-Member -Type NoteProperty -Name FSLabel -Value $Storage.FileSystemLabel
            $StoObj    | Add-Member -Type NoteProperty -Name FileSystem -Value $Storage.FileSystem
            $StoObj    | Add-Member -Type NoteProperty -Name SizeRemaining -Value $Storage.SizeRemaining
            $StoObj    | Add-Member -Type NoteProperty -Name Size -Value $Storage.Size
            $StoObj    | Add-Member -Type NoteProperty -Name HealthStatus -Value $Storage.HealthStatus
            $StoArray += $StoObj       
        }
        $StoObject | Add-Member -Type NoteProperty -Name StorageInformation -Value $StoArray
        $StoInformationArray += $StoObject
        
    }
    Return $StoInformationArray
}

Function Get-VMHostNetwork {
#Get information about VM Host network adapter
    Param([Array]$VMHosts,
          [string]$DomainName)

    $VMHostNetworkArray = @()
    $ComputerName = Get-Content ENV:COMPUTERNAME
    $i = 0
    Foreach ($VMHost in $VMHosts){
        $Local = $Null

        # Show Progress bar
        Write-Progress -Activity "Collecting Hyper-V/S2D infrastructure information" `
                       -PercentComplete (($i/$VMHosts.Count)*100) `
                       -CurrentOperation "Collecting $($VMHost.Name) network adapter information"

        $i++
        # if the script is run on a node, don't need any credential and get information locally
        if ($VMHost.Name -like $ComputerName){
            $NICs  = Get-NetAdapter
            $Local = $True
        }

        # if the script is run remotely, get information with credential remotely.
        Else {
            $Cim   = New-CimSession -ComputerName $($VMHost.Name + "." + $DomainName) 
            $NICs  = Get-NetAdapter -CimSession $Cim
            $Local = $False
        }

        # for each network adapter
        Foreach ($NIC in $NICs) {
            $NicObj = New-Object System.Object
            $NicObj | Add-Member -Type NoteProperty -Name VMHost -Value $VMHost.Name
            $NicObj | Add-Member -Type NoteProperty -Name Name -Value $NIC.Name
            $NicObj | Add-Member -Type NoteProperty -Name Description -Value $NIC.InterfaceDescription
            $NicObj | Add-Member -Type NoteProperty -Name LinkSpeed -Value $Nic.LinkSpeed

            # if the script is run locally
            If ($Local){
                $RDMA = Get-NetAdapterRDMA -Name $Nic.Name -ErrorAction SilentlyContinue
                $MTU  = (Get-NetAdapterAdvancedProperty -Name $NIC.Name |? RegistryKeyword -like *Jumbo*).RegistryValue
                $RSS  = Get-NetAdapterRSS -Name $Nic.Name
                
                $IPaddress = Get-NetIPAddress -InterfaceAlias $NIC.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue
                
                $DefaultGw = (Get-NetRoute |? DestinationPrefix -like 0.0.0.0/0 |? InterfaceAlias -like $NIC.Name).NextHop
                $DNS       = Get-DnsClientServerAddress -InterfaceAlias $NIC.Name -ErrorAction SilentlyContinue | Select -Expand ServerAddresses
                $RegisterDNS = Get-DnsClient -InterfaceAlias $NIC.Name  -ErrorAction SilentlyContinue | Select -Expand RegisterThisConnectionsAddress
                
                # if there is no IP address, don't need to show information
                if ($IPAddress.IPaddress -like $Null){
                    $NicObj | Add-Member -Type NoteProperty -Name IPAddress -Value "N/a"
                    $NicObj | Add-Member -Type NoteProperty -Name Gateway -Value "GW: N/a"
                    $NicObj | Add-Member -Type NoteProperty -Name DNS -Value "DNS: N/a"
                    $NicObj | Add-Member -Type NoteProperty -Name DNSRegistration -Value "DNS Registration: N/a"
                }
                # else get IP information
                Else {
                    $Address = @()
                    Foreach ($IP in $IPAddress){
                        $Address += "$($IP.IPAddress)/$($IP.PrefixLength)"
                    }
                    $NicObj | Add-Member -Type NoteProperty -Name IPAddress -Value "$Address"
                    $NicObj | Add-Member -Type NoteProperty -Name Gateway -Value "GW: $DefaultGW"
                    $NicObj | Add-Member -Type NoteProperty -Name DNS -Value "DNS: $DNS"
                    $NicObj | Add-Member -Type NoteProperty -Name DNSRegistration -Value "DNS Registration: $RegisterDNS"
                }
                $NicObj | Add-Member -Type NoteProperty -Name RDMAState -Value $RDMA.Enabled
                $NicObj | Add-Member -Type NoteProperty -Name MTU -Value $MTU
                $NicObj | Add-Member -Type NoteProperty -Name RSSState -Value $RSS.Enabled
                $String = "$($RSS.BaseProcessorNumber) - $($RSS.MaxProcessorNumber) ($($RSS.MaxProcessors))"
                $NicObj | Add-Member -Type NoteProperty -Name RSS -Value $String
                

                # if it is a virtual interface
                if ($Nic.InterfaceDescription -like "*Hyper-V*"){

                    # gather information about vNIC
                    $vNIC = Get-VMNetworkAdapter -ManagementOS |? DeviceID -like $Nic.DeviceID
                    $VLAN = Get-VMNetworkAdapterVLAN -VMNetworkAdapterName $vNIC.Name -ManagementOS
                    $NicObj | Add-Member -Type NoteProperty -Name VMQState -Value "N/a"
                    $NicObj | Add-Member -Type NoteProperty -Name VMQ -Value "N/a"
                    $NicObj | Add-Member -Type NoteProperty -Name Type -Value Virtual
                    $NicObj | Add-Member -Type NoteProperty -Name VMMQ -Value $vNIC.VmmqEnabled
                    $NicObj | Add-Member -Type NoteProperty -Name SwitchName -Value $vNIC.SwitchName
                    $NicObj | Add-Member -Type NoteProperty -Name QoS -Value $vNIC.BandwidthPercentage

                    # Format text about VLAN
                    if ($VLAN.OperationMode -like "Untagged"){
                        $NicObj | Add-Member -Type NoteProperty -Name VLAN -Value "Untagged"
                    }
                    Elseif ($Vlan.OperationMode -Like "Access"){
                        $NicObj | Add-Member -Type NoteProperty -Name VLAN -Value "Access: $($VLAN.AccessVlanId)"
                    }
                    Else {
                        $NicObj | Add-Member -Type NoteProperty -Name VLAN -Value "Trunk: $($VLAN.AllowedVlanIdList) ($($VLAN.NativeVlanId))"
                    }
                    $TeamMapping = (Get-VMNetworkAdapterTeamMapping -ManagementOS -Name $vNIC.Name).NetAdapterName
                    if ($TeamMapping -like $Null){
                        $TeamMapping = "Not Configured"
                    }
                    $NicObj | Add-Member -Type NoteProperty -Name TeamMapping -Value $TeamMapping

                }

                # if it is a physical interface
                Else {
                    $VLAN = (Get-NetAdapterAdvancedProperty -Name $Nic.Name |? RegistryKeyword -like VlanID).RegistryValue
                    $VMQ  = Get-NetAdapterVMQ -Name $Nic.Name
                    $NicObj | Add-Member -Type NoteProperty -Name VMQState -Value $VMQ.Enabled
                    $String = "$($VMQ.BaseProcessorNumber) - $($VMQ.MaxProcessorNumber) ($($VMQ.MaxProcessors))"
                    $NicObj | Add-Member -Type NoteProperty -Name VMQ -Value $String
                    $NicObj | Add-Member -Type NoteProperty -Name Type -Value Physical
                    $NICObj | Add-Member -Type NoteProperty -Name VMMQ -Value "N/a"
                    $NICObj | Add-Member -Type NoteProperty -Name SwitchName -Value "N/a"
                    $NicObj | Add-Member -Type NoteProperty -Name QoS -Value "N/a"


                    # Format VLAN text
                    if ($VLAN -eq 0){
                        $NicObj | Add-Member -Type NoteProperty -Name VLAN -Value "Untagged"
                    }
                    Else {
                        $NicObj | Add-Member -Type NoteProperty -Name VLAN -Value "Access: $VLAN"
                    }
                    $NicObj | Add-Member -Type NoteProperty -Name TeamMapping -Value "N/a"
                }

            }

            # if it is a remote server, get information with cim session
            Else {
                $RDMA = Get-NetAdapterRDMA -Name $Nic.Name -CimSession $Cim -ErrorAction SilentlyContinue
                $MTU  = (Get-NetAdapterAdvancedProperty -Name $NIC.Name  -CimSession $Cim |? RegistryKeyword -like *Jumbo*).RegistryValue
                $RSS  = Get-NetAdapterRSS -Name $Nic.Name  -CimSession $Cim
                
                $IPaddress = Get-NetIPAddress -InterfaceAlias $NIC.Name -AddressFamily IPv4 -CimSession $Cim -ErrorAction SilentlyContinue

                $DefaultGw = (Get-NetRoute -CimSession $Cim |? DestinationPrefix -like 0.0.0.0/0 |? InterfaceAlias -like $NIC.Name).NextHop
                $DNS       = Get-DnsClientServerAddress -CimSession $Cim -InterfaceAlias $NIC.Name -ErrorAction SilentlyContinue | Select -Expand ServerAddresses
                $RegisterDNS = Get-DnsClient -InterfaceAlias $NIC.Name -ErrorAction SilentlyContinue -CimSession $Cim | Select -Expand RegisterThisConnectionsAddress
                
                # If there is no IP address, no need to gather information
                if ($IPAddress.IPAddress -like $Null){
 
                    $NicObj | Add-Member -Type NoteProperty -Name IPAddress -Value "N/a"
                    $NicObj | Add-Member -Type NoteProperty -Name Gateway -Value "GW: N/a"
                    $NicObj | Add-Member -Type NoteProperty -Name DNS -Value "DNS: N/a"
                    $NicObj | Add-Member -Type NoteProperty -Name DNSRegistration -Value "DNS Registration: N/a"
                }

                # if there is an IP address, gather information
                Else {
                    $Address = @()
                    Foreach ($IP in $IPAddress){
                        $Address += "$($IP.IPAddress)/$($IP.PrefixLength)"
                    }
                    $NicObj | Add-Member -Type NoteProperty -Name IPAddress -Value "$Address"
                    $NicObj | Add-Member -Type NoteProperty -Name Gateway -Value "GW: $DefaultGW"
                    $NicObj | Add-Member -Type NoteProperty -Name DNS -Value "DNS: $DNS"
                    $NicObj | Add-Member -Type NoteProperty -Name DNSRegistration -Value "DNS Registration: $RegisterDNS"
                }
                
                $NicObj | Add-Member -Type NoteProperty -Name RDMAState -Value $RDMA.Enabled
                $NicObj | Add-Member -Type NoteProperty -Name MTU -Value $MTU
                $NicObj | Add-Member -Type NoteProperty -Name RSSState -Value $RSS.Enabled
                $String = "$($RSS.BaseProcessorNumber) - $($RSS.MaxProcessorNumber) ($($RSS.MaxProcessors))"
                $NicObj | Add-Member -Type NoteProperty -Name RSS -Value $String

                # if the NIC is a vNIC
                if ($Nic.InterfaceDescription -like "*Hyper-V*"){

                    # Run invoke-command to get remote information. Don't have choice because get-VMNetworkAdapter -cim -computer return error
                    $vNIC = Invoke-Command -ComputerName $($VMHost.Name + "." + $DomainName) -ArgumentList $Nic.DeviceId -ScriptBlock {
                            Get-VMNetworkAdapter -ManagementOS |? DeviceID -like $Args[0]}

                    $VLAN = Invoke-Command -ComputerName $($VMHost.Name + "." + $DomainName) -ArgumentList $vNIC.Name -ScriptBlock {
                            Get-VMNetworkAdapterVLAN -VMNetworkAdapterName $Args[0] -ManagementOS}
                    $NicObj | Add-Member -Type NoteProperty -Name VMQState -Value "N/a"
                    $NicObj | Add-Member -Type NoteProperty -Name VMQ -Value "N/a"
                    $NicObj | Add-Member -Type NoteProperty -Name Type -Value Virtual
                    $NicObj | Add-Member -Type NoteProperty -Name VMMQ -Value $vNIC.VmmqEnabled
                    $NicObj | Add-Member -Type NoteProperty -Name SwitchName -Value $vNIC.SwitchName
                    $NicObj | Add-Member -Type NoteProperty -Name QoS -Value $vNIC.BandwidthPercentage

                    # format VLAn text
                    if ($VLAN.OperationMode -like "Untagged"){
                        $NicObj | Add-Member -Type NoteProperty -Name VLAN -Value "Untagged"
                    }
                    Elseif ($Vlan.OperationMode -Like "Access"){
                        $NicObj | Add-Member -Type NoteProperty -Name VLAN -Value "Access: $($VLAN.AccessVlanId)"
                    }
                    Else {
                        $NicObj | Add-Member -Type NoteProperty -Name VLAN -Value "Trunk: $($VLAN.AllowedVlanIdList) ($($VLAN.NativeVlanId))"
                    }
                    $TeamMapping = Invoke-Command -ComputerName $($VMHost.Name + "." + $DomainName) -ArgumentList $vNIC.Name -ScriptBlock {
                                   (Get-VMNetworkAdapterTeamMapping -ManagementOS -Name $Args[0]).NetAdapterName}

                    if ($TeamMapping -like $Null){
                        $TeamMapping = "Not Configured"
                    }
                    $NicObj | Add-Member -Type NoteProperty -Name TeamMapping -Value $TeamMapping

                }

                # if it is a physical NIC
                Else {
                    $VLAN = (Get-NetAdapterAdvancedProperty -Name $Nic.Name -CimSession $Cim |? RegistryKeyword -like VlanID).RegistryValue
                    $VMQ  = Get-NetAdapterVMQ -Name $Nic.Name  -CimSession $Cim
                    $NicObj | Add-Member -Type NoteProperty -Name VMQState -Value $VMQ.Enabled
                    $String = "$($VMQ.BaseProcessorNumber) - $($VMQ.MaxProcessorNumber) ($($VMQ.MaxProcessors))"
                    $NicObj | Add-Member -Type NoteProperty -Name VMQ -Value $String
                    $NicObj | Add-Member -Type NoteProperty -Name Type -Value Physical
                    $NICObj | Add-Member -Type NoteProperty -Name VMMQ -Value "N/a"
                    $NICObj | Add-Member -Type NoteProperty -Name SwitchName -Value "N/a"
                    $NicObj | Add-Member -Type NoteProperty -Name QoS -Value "N/a"
                    $NicObj | Add-Member -Type NoteProperty -Name TeamMapping -Value "N/a"
                    
                    # Format VLAN text
                    if ($VLAN -eq 0){
                        $NicObj | Add-Member -Type NoteProperty -Name VLAN -Value "Untagged"
                    }
                    Else {
                        $NicObj | Add-Member -Type NoteProperty -Name VLAN -Value "Access: $VLAN"
                    }

                }
            }
        $VMHostNetworkArray += $NicObj
        }
        if (!($Local)){
            Remove-CimSession $Cim
        }
    }

    Return $VMHostNetworkArray
}

Function Get-VMHostvSwitch {
# this function get information about VMSwitches
    Param([Array]$VMHosts,
          [string]$DomainName)

    $VMHostvSwitchArray = @()
    $i                  = 0

    # for each node in the cluster
    Foreach ($VMHost in $VMHosts){

        # Show Progress bar
        Write-Progress -Activity "Collecting Hyper-V/S2D infrastructure information" `
                       -PercentComplete (($i/$VMHosts.Count)*100) `
                       -CurrentOperation "Collecting $($VMHost.Name) VMSwitches information"

        $i++
              
        $Hostname = $VMHost.Name + "." + $DomainName  
        $ComputerName = Get-Content ENV:COMPUTERNAME

        # if the script is run on a node, run command locally
        if ($VMHost -like $ComputerName){
            $vSwitches = Get-VMSwitch
        }

        # if the script is remote, connect to the node with computername and credential
        Else {
        $vSwitches = Invoke-Command -ComputerName $Hostname {Get-VMSwitch}
        }

        # for each VMswitch, get information
        Foreach ($vSwitch in $vSwitches){
            $vSwitchObj = New-Object System.Object
            $vSwitchObj | Add-Member -Type NoteProperty -Name VMHost -Value $VMHost.Name
            $vSwitchObj | Add-Member -Type NoteProperty -Name Name -Value $vSwitch.Name
            $vSwitchObj | Add-Member -Type NoteProperty -Name Type -Value $vSwitch.SwitchType
            $vSwitchObj | Add-Member -Type NoteProperty -Name QoSmode -Value $vSwitch.BandwidthReservationMode
            $vSwitchObj | Add-Member -Type NoteProperty -Name EmbeddedTeaming -Value $vSwitch.EmbeddedTeamingEnabled
            $vSwitchObj | Add-Member -Type NoteProperty -Name PacketDirect -Value $vSwitch.PacketDirectEnabled
            $vSwitchObj | Add-Member -Type NoteProperty -Name IovSupport -Value $vSwitch.IovEnabled

            # trying to get the NIC name instead of the nic description. If local, get information locally
            If ($VMHost -like $ComputerName){
                $Nics = $vSwitch | select -expand NetAdapterInterfaceDescriptions |
                        % {Get-NetAdapter |? InterfaceDescription -like $_ | Select -Expand Name }
            } 

            # if remote, get information with credential
            Else {
                $Nics = $vSwitch | select -expand NetAdapterInterfaceDescriptions
                $Nics = Invoke-Command -ComputerName $Hostname -ArgumentList $Nics {
                        $Args |% {Get-NetAdapter |? InterfaceDescription -like $_ | Select -Expand Name} }
            }
        $vSwitchObj | Add-Member -Type NoteProperty -Name NICs -Value $NICs
        $VMHostvSwitchArray += $vSwitchObj
        }
    }
    Return $VMHostvSwitchArray
}

Function Get-ClusterStorage {
# This function collects cluster storage shared between each nodes and return an array
    Param([String]$ClusterName)

    $StoClusterArray  = @()
    $ClusterStoObject = New-Object System.Object
    $ClusterSto       = Get-ClusterSharedVolume -Cluster $ClusterName
    $ClusterStoObject | Add-Member -Type NoteProperty -Name Name -Value $ClusterName
    $StoArray         = @()
    $i                = 0

    # For eachstorage device in $ClusterSto, collecting some information as name, state, size and so on
    Foreach ($Storage in $ClusterSto){
       #Show a Progress bar
        Write-Progress -Activity "Collecting Hyper-V/S2D infrastructure information" `
                       -PercentComplete 50 `
                       -CurrentOperation "Collecting $ClusterName storage information"

        $StoObj = New-Object System.Object
        $StoObj | Add-Member -Type NoteProperty -Name Name -Value $Storage.Name
        $StoObj | Add-Member -Type NoteProperty -Name State -Value $Storage.State

        # Get specific information as maintenance mode and friendlyname
        $VolumeState = Get-ClusterSharedVolume -Cluster $ClusterName -Name $Storage.Name | select -Expand SharedVolumeInfo
        $StoObj | Add-Member -Type NoteProperty -Name MaintenanceMode $VolumeState.MaintenanceMode
        $StoObj | Add-Member -Type NoteProperty -Name FriendlyVolumename $VolumeState.FriendlyVolumeName

        # Get some information about the volume (size and used space)
        $PartitionState = Get-ClusterSharedVolume -Cluster $ClusterName -Name $Storage.Name | select -Expand SharedVolumeInfo | select -Expand Partition
        $StoObj | Add-Member -Type NoteProperty -Name Size $PartitionState.Size
        $StoObj | Add-Member -Type NoteProperty -Name UsedSpace $PartitionState.UsedSpace
        $StoArray += $StoObj

    }
    $ClusterStoObject | Add-Member -Type NoteProperty -Name StorageInformation -Value $StoArray
    $StoClusterArray += $ClusterStoObject
    Return $StoClusterArray
}

Function Get-ClusterNetInformation {
# This function collects cluster network information and return an array   
    Param([string]$ClusterName)

    $ClusterNetInfoArray = @()
    # Collect cluster network information
    $ClusterNetInfo      = Get-ClusterNetwork -Cluster $ClusterName
    # Collect network ID which are not allowed to transmit Live-Migration flows
    $LiveMigrationNet    = (Get-ClusterResourceType -Cluster $ClusterName "Virtual Machine" | Get-ClusterParameter -Name MigrationExcludeNetworks).Value
    
    # Split network id in an array
    $LMNetArray          = $LiveMigrationNet -Split ";"
    $i                   = 0  

    # For each cluster network, collect network information
    Foreach ($Network in $ClusterNetInfo){
        # show a progress bar
        Write-Progress -Activity "HTML file construction" -PercentComplete (($i/$ClusterNetInfo.Count)*100) -CurrentOperation "Network information gathering"
        $NetInfoObject = New-object System.Object
        $NetInfoObject | Add-Member -Type NoteProperty -Name Name -Value $Network.Name
        $NetInfoObject | Add-Member -Type NoteProperty -Name Role -Value $Network.Role
        $NetInfoObject | Add-Member -Type NoteProperty -Name Address -Value $Network.Address
        $NetInfoObject | Add-Member -Type NoteProperty -Name AddressMask -Value $Network.AddressMask
        $NetInfoObject | Add-Member -Type NoteProperty -Name State -Value $Network.State
        
        $LMNet = $True
        # Verifying if this network is excluded to transmit Live-Migration flows
        Foreach ($ExcludeNet in $LMNetArray){

            if ($Network.Id -like $ExcludeNet){
                $LMNet = $False
            }
        }
        $NetInfoObject        | Add-Member -Type NoteProperty -Name LMNet -Value $LMNet
        $ClusterNetInfoArray += $NetInfoObject
        
    }
    Return $ClusterNetInfoArray

}

Function Get-VMHostOsInformation {
# Collect Hyper-V Host OS information
    Param([Array]$VMHosts,
          [String]$DomainName)

    $OSInformationArray = @()
    $i                  = 0
    $ComputerName = $env:ComputerName + "." + $DomainName

    # For each Hyper-V Host in $VMHosts array, collecting information
    Foreach ($VMHost in $VMHosts){

        # Show a Progress Bar
        Write-Progress -Activity "Collecting Hyper-V/S2D infrastructure information" `
                       -PercentComplete (($i/$VMHosts.Count)*100) `
                       -CurrentOperation "Collecting $($VMHost.Name) OS information"
        $i++
        $VMHost        = $VMHost.Name + "." + $DomainName
        $VMHostOSObj   = New-Object System.Object
        $VMHostOSObj   | Add-Member -Type NoteProperty -Name Name -Value $VMHost
        $FirewallArray = @()

        # Collect Firewall state on remote Hyper-V Host
        $FirewallState = Invoke-Command -ComputerName $VMHost -ScriptBlock {Get-NetFirewallProfile}
        
        # For each firewall profile, collect state
        Foreach ($Firewall in $FirewallState){
            $FirewallObj    = New-Object System.object
            $FirewallObj    | Add-Member -type NoteProperty -Name Name -Value $Firewall.Name
            $FirewallObj    | Add-Member -type NoteProperty -Name State -Value $Firewall.Enabled
            $FirewallArray += $FirewallObj
        }
        $VMHostOSObj  | Add-Member -Type NoteProperty -Name Firewall -Value $FirewallArray

        # verifying if the server is in minimal interface mode. If the script is launched on the local server, don't need credential
        If ($VMHost -like $ComputerName){
            $GuiState = (Get-WindowsFeature -Name Server-Gui-Shell -ComputerName $VMHost).Installed
        }
        else{
            $GuiState = (Get-WindowsFeature -Name Server-Gui-Shell -ComputerName $VMHost).Installed
        }
   
        $VMHostOSObj  | Add-Member -Type NoteProperty -Name GUIInstalled -Value $GuiState

        # Collecting OS information in Win32_OperatingSystem WMI class
        If ($VMHost -like $ComputerName){
            $OSInfo = Get-WmiObject -ComputerName $VMHost -Class Win32_OperatingSystem
        }
        else{
            $OSInfo = Get-WmiObject -ComputerName $VMHost -Class Win32_OperatingSystem 
        }
        
        # Count hotfix installed
        If ($VMHost -like $ComputerName){
            $HotFixCount = (Get-HotFix -ComputerName $VMhost).Count
        }
        else{
            $HotFixCount = (Get-HotFix -ComputerName $VMhost).Count
        }
        
        $VMHostOSObj  | Add-Member -Type NoteProperty -Name OSVersion -Value $OSInfo.Caption
        $VMHostOSObj  | Add-Member -Type NoteProperty -Name OSLanguage -Value $OSInfo.OSLanguage
        $VMHostOSObj  | Add-Member -Type NoteProperty -Name OSHotfix -Value $HotFixCount
        $OSInformationArray += $VMHostOSObj
    }
    Return $OSInformationArray

}

Function Get-ClusterConfInformation {
# Collecting cluster information
    Param([string]$ClusterName)

    # Show a Progress bar
    Write-Progress -Activity "Collecting Hyper-V/S2D infrastructure information" `
                   -PercentComplete 50 `
                   -CurrentOperation "Collecting $ClusterName information"

    $ClustConfArray    = @()

    # Count the number of node in the cluster
    $NodeNbr           = (Get-ClusterNode -Cluster $ClusterName).Count
    # Collect cluster information
    $ClusterInfo       = Get-Cluster -Name $ClusterName
    # Collect Cluster Quorum information
    $QuorumInfo        = Get-ClusterQuorum -Cluster $ClusterName

    $ClustInfoObj      = New-Object System.Object
    $ClustInfoObj      | Add-Member -Type NoteProperty -Name Name -Value $ClusterName
    $ClustInfoObj      | Add-Member -Type NoteProperty -Name NodeNbr -Value $NodeNbr
    $ClustInfoObj      | Add-Member -Type NoteProperty -Name QuorumType -Value $QuorumInfo.QuorumType
    $ClustInfoObj      | Add-Member -Type NoteProperty -Name QuorumResource -Value $QuorumInfo.QuorumResource
    $ClustInfoObj      | Add-Member -Type NoteProperty -Name WitnessDynamicWeight -Value $ClusterInfo.WitnessDynamicWeight
    $ClustInfoObj      | Add-Member -Type NoteProperty -Name DynamicQuorum -Value $ClusterInfo.DynamicQuorum
    $ClustInfoObj      | Add-Member -Type NoteProperty -Name BlockCacheSize -Value $ClusterInfo.BlockCacheSize
    $ClusterConfArray += $ClustInfoObj

    Return $ClusterConfArray
}

Function Get-VMHostWorkloads {
# This function collects virtual machines information on Hyper-V Hosts and return an array
    Param([Array]$VMHosts,
          [string]$DomainName)

    $VMHostWorkloadArray = @()
    $i                   = 0

    # For each Hyper-V host in $VMHosts array, collecting VM information
    Foreach ($VMHost in $VMHosts){
        # Show a progress bar
        Write-Progress -Activity "Collecting Hyper-V/S2D infrastructure information" `
                       -PercentComplete (($i/$VMHosts.Count)*100) `
                       -CurrentOperation "Collecting VMs information on $($VMHost.Name)"
        $i++
        $VMHost       = $VMHost.Name + "." + $DomainName

        # Get Virtual Machines from remote Hyper-V nodes
        $VMs          = Invoke-Command -ComputerName $VMHost -ScriptBlock {Get-VM}

        # For each virtual machine in $VMs, collecting information
        Foreach ($VM in $VMs){
           $VMSnapArray  = @()
           $VMDiskArray  = @()

           $VMObject     = New-Object System.Object
           $VMObject     | Add-Member -Type NoteProperty -Name VMHost -Value $VMHost 
           $VMObject     | Add-Member -Type NoteProperty -Name Name -Value $VM.Name
           $VMObject     | Add-Member -Type NoteProperty -Name State -Value $VM.State
           $VMObject     | Add-Member -Type NoteProperty -Name IsClustered -Value $VM.IsClustered
           $VMObject     | Add-Member -Type NoteProperty -Name Generation -Value $VM.Generation
           $VMObject     | Add-Member -Type NoteProperty -Name ProcessorCount -Value $VM.ProcessorCount
           $VMObject     | Add-Member -Type NoteProperty -Name DynamicMemoryEnabled -Value $VM.DynamicMemoryEnabled
           $VMObject     | Add-Member -Type NoteProperty -Name MemoryAssigned -Value $VM.MemoryAssigned
           $VMObject     | Add-Member -Type NoteProperty -Name MemoryDemand -Value $VM.MemoryDemand
           
           # collect VirtualHardDrive information
           $VMDisks = Invoke-Command -ComputerName $VMHost `
                                     -ArgumentList $VM.Name `
                                     -ScriptBlock {Get-VMHardDiskDrive -VMName $Args[0]}
           
           # Collect Checkpoints information
           $VMSnaps = Invoke-Command -ComputerName $VMHost `
                                     -ArgumentList $VM.Name `
                                     -ScriptBlock {Get-VMSnapshot -VMName $Args[0]}

           # for each virtual disk, collecting information
           Foreach ($vDisk in $VMDisks){
               $vDiskObject = New-Object System.Object
               $vDiskObject | Add-member -Type NoteProperty -Name ControllerType -Value $vDisk.ControllerType
               $vDiskObject | Add-member -Type NoteProperty -Name Path -Value $vDisk.Path

               # Collecting advanced virtual disk information
               $vDiskInfo    = Invoke-Command -ComputerName $VMHost -ArgumentList $vDisk.Path -ScriptBlock {Get-VHD -Path $Args[0]}

               $vDiskObject | Add-member -Type NoteProperty -Name VHDType -Value $vDiskInfo.VHDType
               $vDiskObject | Add-member -Type NoteProperty -Name Size -Value $vDiskInfo.Size

               $VMDiskArray += $vDiskObject
           }
           $VMObject | Add-Member -Type NoteProperty -Name VMDisks -Value $VMDiskArray

           # for each checkpoint, collecting information
           Foreach ($Checkpoint in $VMSnaps){
               $CheckpointObject = New-Object System.Object
               $CheckpointObject | Add-Member -Type NoteProperty -Name Name -Value $Checkpoint.Name
               $CheckpointObject | Add-Member -Type NoteProperty -Name CreationTime -Value $Checkpoint.CreationTime
               $VMSnapArray += $CheckPointObject
           }
           $VMObject | Add-Member -Type NoteProperty -Name Checkpoints -Value $VMSnapArray
           $VMHostWorkloadArray += $VMObject 
              
        }
          
    }
    Return $VMHostWorkloadArray

}

Function Get-StoragePoolInfo {
#this function gets information about Storage Pool
    Param([string]$ClusterName,
          [string]$DomaiName)
    
    $StoragePoolInfo = @()

    $Cim             = New-CimSession -ComputerName $($ClusterName + "." + $DomainName) 

    # Get Storage Pool which are not primordial
    $StoragePools     = Get-StorageSubSystem -CimSession $Cim |? Name -like *$ClusterName*| Get-StoragePool |? isPrimordial -like $False
    Foreach ($StoragePool in $StoragePools){   

        # for each storage pool, add information to an array
        $SSObj = New-Object System.Object
        $SSObj | Add-Member -Type NoteProperty -Name FriendlyName $StoragePool.FriendlyName
        $SSObj | Add-Member -Type NoteProperty -Name OperationalStatus $StoragePool.OperationalStatus
        $SSObj | Add-Member -Type NoteProperty -Name HealthStatus $StoragePool.HealthStatus
        $SSObj | Add-Member -Type NoteProperty -Name Size $StoragePool.Size
        $SSObj | Add-Member -Type NoteProperty -Name AllocatedSize $StoragePool.AllocatedSize
        $StoragePoolInfo += $SSObj
    }
    Remove-CimSession -CimSession $CIM
    Return $StoragePoolInfo
}

Function Get-VirtualDiskInfo {
# this function gets information about virtual disks
    Param([string]$ClusterName,
          [string]$DomainName)

    $VDArray = @()
    $Cim = New-CimSession -ComputerName $($ClusterName + "." + $DomainName)

    # get virtual disks information from storage subsystem with the cluster name and storage pool not primordial
    $VirtualDisks = Get-StorageSubSystem -CimSession $Cim |? Name -like *$ClusterName* | Get-StoragePool |? isPrimordial -like $False | Get-VirtualDisk
    $i = 0

    Foreach ($VirtualDisk in $VirtualDisks){

        # Show a progress bar
        Write-Progress -Activity "Collecting Hyper-V/S2D infrastructure information" `
                       -PercentComplete (($i/$VirtualDisks.Count)*100) `
                       -CurrentOperation "Get virtual disk information on $($ClusterName)"
        $i++

        # for each virtual disk, gather information into an array
        $VDObj = New-Object System.Object
        $VDObj | Add-Member -Type NoteProperty -Name FriendlyName -Value $VirtualDisk.FriendlyName
        $VDObj | Add-Member -Type NoteProperty -Name NumberOfColumns -Value $VirtualDisk.NumberOfColumns
        $VDObj | Add-Member -Type NoteProperty -Name ResiliencySettingName -Value $VirtualDisk.ResiliencySettingName
        $VDObj | Add-Member -Type NoteProperty -Name NumberOfDataCopies -Value $VirtualDisk.NumberOfDataCopies
        $VDObj | Add-Member -Type NoteProperty -Name Size -Value $VirtualDisk.Size
        $VDObj | Add-Member -Type NoteProperty -Name FootprintOnPool -Value $VirtualDisk.FootprintOnPool
        $VDObj | Add-Member -Type NoteProperty -Name HealthStatus -Value $VirtualDisk.HealthStatus
        $VDArray += $VDObj
    }
    Remove-CimSession -CimSession $CIM
    Return $VDArray

}

Function Get-PhysicalDiskInfo {
# this function gets information about physical disks
    Param([string]$ClusterName,
          [string]$DomainName)

    $PhysicalDiskArray = @()
    $i                 = 0

    # connecting to an online node
    $Node = ((Get-ClusterNode -Cluster ($ClusterName + "." + $DomainName) |? State -Like up)[0]).Name
    $Node = $Node + "." + $DomainName

    # runnin the function remotely
    $PhysicalDiskArray = Invoke-Command -ComputerName $Node -Argumentlist $ClusterName -ScriptBlock {
       
        $PDArray      = @()
        $StoragePools = Get-StorageSubSystem |? Name -like *$($Args[0])* | Get-StoragePool |? isprimordial -like $false
       
        # for each storage pool
        Foreach ($StoragePool in $StoragePools){

            # Get physical disk in the storage pool
            $PhysicalDisks = $StoragePool | Get-PhysicalDisk
            # For each physical disk
            Foreach ($PhysicalDisk in $PhysicalDisks){

                # Show a progress bar
                Write-Progress -Activity "Collecting Hyper-V/S2D infrastructure information" `
                               -PercentComplete (($i/$PhysicalDisks.Count)*100) `
                               -CurrentOperation "Collecting physical disk information on $($ClusterName)"
                $i++
                
                # gather information about Physical disks
                $PDObj = New-Object System.Object
                $PDObj | Add-Member -Type NoteProperty -Name StoragePoolFriendlyName -Value $StoragePool.FriendlyName
                $PDObj | Add-Member -Type NoteProperty -Name FriendlyName -Value $PhysicalDisk.FriendlyName
                $PDObj | Add-Member -Type NoteProperty -Name FirmwareVersion -Value $PhysicalDisk.FirmwareVersion
                $PDObj | Add-Member -Type NoteProperty -Name Model -Value $PhysicalDisk.Model
                $PDObj | Add-Member -Type NoteProperty -Name SerialNumber -Value $PhysicalDisk.SerialNumber
                $PDObj | Add-Member -Type NoteProperty -Name Size -Value $PhysicalDisk.Size
                $PDObj | Add-Member -Type NoteProperty -Name AllocatedSize -Value $PhysicalDisk.AllocatedSize
                $PDObj | Add-Member -Type NoteProperty -Name MediaType -Value $PhysicalDisk.MediaType
                $PDObj | Add-Member -Type NoteProperty -Name BusType -Value $PhysicalDisk.BusType
                $PDObj | Add-Member -Type NoteProperty -Name HealthStatus -Value $PhysicalDisk.HealthStatus
                $PDObj | Add-Member -Type NoteProperty -Name OperationalStatus -Value $PhysicalDisk.OperationalStatus
                $PDObj | Add-Member -Type NoteProperty -Name Usage -Value $PhysicalDisk.Usage
                $PDArray += $PDObj
            }  
        }
        Return $PDArray

    }
    Return $PhysicalDiskArray

}

Function Get-VMHostSMBMultiChannel {
# This function get information about SMB MultiChannel
    Param([Array]$VMHosts,
          [String]$DomainName)

    $SMBMultiInfoArray = @()
    $ComputerName      = Get-Content ENV:COMPUTERNAME
    $i                 = 0

    # for each node
    Foreach ($VMHost in $VMHosts){
         # Show a progress bar
        Write-Progress -Activity "Collecting Hyper-V/S2D infrastructure information" `
                        -PercentComplete (($i/$VMHosts.Count)*100) `
                        -CurrentOperation "Collecting SMB MultiChannel information on $($VMHost.Name)"
        $i++
        
        # if the a node is running the script, connect locally
        if ($VMHost -like $ComputerName){
            $SBL = Get-SmbMultichannelConnection -SmbInstance SBL
            $CSV = Get-SMBMultiChannelConnection -SmbInstance CSV
        }

        # If the script is run remotely, connecting with credential and CIM session
        Else {
            $HostName = $VMHost.Name + "." + $DomainName
            $Cim = New-CimSession -ComputerName $hostname 
            $SBL = Get-SmbMultichannelConnection -SmbInstance SBL -CimSession $Cim
            $CSV = Get-SMBMultiChannelConnection -SmbInstance CSV -CimSession $Cim
            
        }

        # for each connection SBL information, add them to array
        Foreach ($Connection in $SBL){
            $SMBInfoObj = New-Object System.Object
            $SMBInfoObj | Add-Member -Type NoteProperty -Name VMHost -Value $VMHost.Name
            $SMBInfoObj | Add-Member -Type NoteProperty -Name ConnectionType -Value "SBL"
            $SMBInfoObj | Add-Member -Type NoteProperty -Name ClientIP -Value $Connection.ClientIpAddress
            $SMBInfoObj | Add-Member -Type NoteProperty -Name ServerIP -Value $Connection.ServerIpAddress
            $SMBInfoObj | Add-Member -Type NoteProperty -Name ClientNIC -Value $Connection.ClientInterfaceFriendlyName
            $SMBInfoObj | Add-Member -Type NoteProperty -Name ServerNIC -Value $Connection.ServerInterfaceIndex
            $SMBInfoObj | Add-Member -Type NoteProperty -Name ClientRSS -Value $Connection.ClientRSSCapable
            $SMBInfoObj | Add-Member -Type NoteProperty -Name ServerRSS -Value $Connection.ServerRSSCapable
            $SMBInfoObj | Add-Member -Type NoteProperty -Name ClientRDMA -Value $Connection.ClientRDMACapable
            $SMBInfoObj | Add-Member -Type NoteProperty -Name ServerRDMA -Value $Connection.ServerRDMACapable
            $SMBMultiInfoArray += $SMBInfoObj
       
        }

        # For each CSV connection, add them to array
        Foreach ($Connection in $CSV){
            $SMBInfoObj = New-Object System.Object
            $SMBInfoObj | Add-Member -Type NoteProperty -Name VMHost -Value $VMHost.Name
            $SMBInfoObj | Add-Member -Type NoteProperty -Name ConnectionType -Value "CSV"
            $SMBInfoObj | Add-Member -Type NoteProperty -Name ClientIP -Value $Connection.ClientIpAddress
            $SMBInfoObj | Add-Member -Type NoteProperty -Name ServerIP -Value $Connection.ServerIpAddress
            $SMBInfoObj | Add-Member -Type NoteProperty -Name ClientNIC -Value $Connection.ClientInterfaceFriendlyName
            $SMBInfoObj | Add-Member -Type NoteProperty -Name ServerNIC -Value $Connection.ServerInterfaceIndex
            $SMBInfoObj | Add-Member -Type NoteProperty -Name ClientRSS -Value $Connection.ClientRSSCapable
            $SMBInfoObj | Add-Member -Type NoteProperty -Name ServerRSS -Value $Connection.ServerRSSCapable
            $SMBInfoObj | Add-Member -Type NoteProperty -Name ClientRDMA -Value $Connection.ClientRDMACapable
            $SMBInfoObj | Add-Member -Type NoteProperty -Name ServerRDMA -Value $Connection.ServerRDMACapable
            $SMBMultiInfoArray += $SMBInfoObj
        }
        
    }
    Return $SMBMultiInfoArray
}

<#

Function Get-S2DConfiguration {
    Param([String]$ClusterName,
          [String]$DomainName,
          [PSCredential]$Credential)

    $S2DArray = @()
    $Cim      = New-CimSession -ComputerName $($ClusterName + "." + $DomainName) -Credential $Credential

    $StoragePools = Get-StorageSubSystem -CimSession $Cim |? Name -like *$ClusterName*| Get-StoragePool |? isPrimordial -like $False
    Foreach ($StoragePool in $StoragePools){
        $SPFreeSpace = $StoragePool.Size - $SotragePool.AllocatedSize
        $PhysicalDisks = $StoragePool | Get-PhysicalDisk

         if ($NodeNbr -lt 5){
                $ReservedDisk  = $NodeNbr
        }
        Else {
            $ReservedDisk = 4
        }


        If (($PhysicalDisks |? Usage -like "Journal").Count -gt 0){
            # Mode cache
            $NodeNbr = (Get-ClusterNode -Cluster $($Cluster + "." + $DomainName) -Credential $Credential).Count
           
            $PhysicalDisks |? Usage -like "Auto-Select" |% {$CapaSize += $_.Size}
            $PhysicalDisks |? Usage -like "Journal" |% {$CacheSize += $_.Size}

        }
        Else {
            # No Cache
             $PhysicalDisks |% {$CapaSize += $_.Size}
        }
    }


    Return $S2DArray
}

#>


##### Settings #####
# ----------------------------------------------------------------

# Specify the consolidation rate
$TxConso     = 4

###### 0 = Disabled; 1 = Enabled
# Enable Host hardware collecting information
$HostHwInformation   = 1

# Enable Host network collecting information
$HostNetInformation  = 0

# Enable Host storage collecting information
$HostStoInformation  = 1

# Enable cluster storage collecting information
$ClustStoInformation = 1

# Enable Cluster Network collecting information
$ClustNetInformation = 0

# Enable Host OS collecting information
$HostOSInformation   = 1

# Enable Cluster configuration collecting information
$ClustConfInfo       = 1

# Enable Virtual Machine collecting information
$VMHostWorkloadInfo  = 1

# Enable Storage Spaces Direct Collecting information
$ClusterS2D          = 1


##### Gather Information #####
# ----------------------------------------------------------------

Clear
Write-Host "Get information from $($ClusterName + "." + $DomainName)..." -ForegroundColor Green -BackgroundColor Black
Try {
    # Get Cluster object
    $Cluster  = Get-Cluster -Name $($ClusterName + "." + $DomainName) -ErrorAction Stop

    # Get Hyper-V nodes in the cluster
    $VMHosts  = Get-ClusterNode -Cluster $($ClusterName + "." + $DomainName) -ErrorAction Stop |? State -Like "Up" | Select Name

    $ComputerName = Get-Content ENV:COMPUTERNAME
    $TestHost     = $VMHosts |? Name -NotLike $ComputerName | Select -First 1
    $TestCim      = New-CimSession -ComputerName $TestHost.Name -ErrorAction Stop | Out-Null
    
}
Catch {
    Write-Error "Can't connect to cluster/Node: $($Error[0].Exception.Message) Exiting"
    Exit
}

# Create the folder if doesn't exist
Try {
    Resolve-Path -Path $Path -ErrorAction Stop | Out-Null
}
Catch {
    Try {
        New-Item -Path $Path -ItemType Directory -ErrorAction Stop | Out-Null
    }
    Catch {
        Write-Error "Can't create the folder $($Path): $($Error[0].Exception.Message). Exiting."
        Exit
    }
}

$Date      = Get-Date -Format yyyy-MM-dd_HH-mm
$FileName  = "Audit-S2D-$ClusterName-$Date.html"
$ExportLog = $Path + "\" + $FileName

## If the module is enabled, run each function to collect information

# If enabled, collect Hyper-V hosts hardware information
if ($HostHwInformation){
    Write-Progress -Activity "Collecting Hyper-V/S2D infrastructure information" -PercentComplete 0
    $VMHostHwInformation  = Get-VMHostHwInformation -VMHosts $VMHosts -DomainName $DomainName 
}

# If enabled, collect Hyper-V Hosts storage information
if ($HostStoInformation){
    Write-Progress -Activity "Collecting Hyper-V/S2D infrastructure information" -PercentComplete 10
    $StorageInformation   = Get-VMHostStorage -VMHosts $VMHosts -DomainName $DomainName 
}

# If enabled, collect cluster storage information
if ($ClustStoInformation){
    Write-Progress -Activity "Collecting Hyper-V/S2D infrastructure information" -PercentComplete 20
    $StoClusterInfo       = Get-ClusterStorage -ClusterName $ClusterName
}

# If enabled, collect Host network configuration
if ($HostNetInformation){
    Write-Progress -Activity "Collecting Hyper-V/S2D infrastructure information" -PercentComplete 30
    $VMHostNicsInfo        = Get-VMHostNetwork -VMHosts $VMHosts -DomainName $DomainName 
    $VMHostvSwitchInfo     = Get-VMHostvSwitch -VMHosts $VMHosts -DomainName $DomainName 
}

# If enabled, collect Cluster network ifnformation
if ($ClustNetInformation){
    Write-Progress -Activity "Collecting Hyper-V/S2D infrastructure information" -PercentComplete 40
    $ClusterNetInformation = Get-ClusterNetInformation -ClusterName $ClusterName 
}

# If enabled, collect Hyper-V hosts OS information
if ($HostOSInformation){
    Write-Progress -Activity "Collecting Hyper-V/S2D infrastructure information" -PercentComplete 50
    $VMHostOSInformation = Get-VMHostOsInformation -VMHosts $VMHosts -DomainName $DomainName 
    $VMHostHyperVInfo    = Get-VMHostHyperVSettings -VMHosts $VMHosts -DomainName $DomainName 
}

# If enabled, collect Cluster configuration information
if ($ClustConfInfo){
    Write-Progress -Activity "Collecting Hyper-V/S2D infrastructure information" -PercentComplete 60
    $ClusterConfInformation = Get-ClusterConfInformation -ClusterName $ClusterName
}

# If enabled, collect Virtual Machines information
if ($VMHostWorkloadInfo){
     Write-Progress -Activity "Collecting Hyper-V/S2D infrastructure information" -PercentComplete 70
    $VMHostsWorkloadInformation = Get-VMHostWorkloads -VMHosts $VMHosts -DomainName $DomainName 
}

# If enabled, collect Storage Spaces Direct information
if ($ClusterS2D){
    Write-Progress -Activity "Collecting Hyper-V/S2D infrastructure information" -PercentComplete 80
    $StoragePoolInformation  = Get-StoragePoolInfo -ClusterName $ClusterName -DomaiName $DomainName 
    $VirtualDiskInformation  = Get-VirtualDiskInfo -ClusterName $ClusterName -DomainName $DomainName 
    $PhysicalDiskInformation = Get-PhysicalDiskInfo -ClusterName $ClusterName -DomainName $DomainName 
    $VMHostSMBMultiChannel   = Get-VMHostSMBMultiChannel -VMHosts $VMHosts -DomainName $DomainName 
}


##### CSS Content #####
# ----------------------------------------------------------------

# these variables define the name of CSS Class ofr each purpose
$TdError       = "td_Error"
$TDOK          = "td_OK"
$TableClass    = "table_main"
$UnitClass     = "span_Unit"
$ValueClass    = "span_Value"
$AdvertMessage = "span_advert"
$MiscValue     = "span_Misc"
$ComputerClass = "td_computer"
$TDNoInfo      = "td_empty"




##### HTML Content #####
# ----------------------------------------------------------------
$Date        = Get-Date
$HTMLIntitle = @"
<html> 
<Head>
<Title>Audit of $ClusterName Hyper-V/S2D infrastructure - Date: $Date</title>
<Style>
body
{
    font-family: arial, verdana;
    color: #333;
    background-color: #DDD;
    padding: 10px;
    font-size: 14px;
}

h2
{
    font-size: 1.7em;
    color: #800;
}
.table_main
{
    border-collapse: collapse;
    background-color: #FFF;
    font-size: 1em;
    width: 100%;
}

.table_main th
{
    border: 1px solid #AAA;
    background-color: #555;
    padding: 10px;
    color: #FFF;
}

.table_main td
{
    border: 1px solid #AAA;
    text-align: center;
    padding: 10px;
}

.td_computer
{
    background-color: #F5F5F5;
    color: #333;
    font-weight: bold;
}

.td_Error
{
    background-color: #F1302A;
    color: #FFF;
}

.td_OK
{
    background-color: #46B810;
    color: #FFF;
}

.td_empty
{
    
}

.span_Value
{
    font-size: 1.6em;
}

.span_Unit
{
    font-size: 1.2em;
}

.span_advert
{
    font-size: 0.8em;
    font-weight: bold;
    color: #888;
}
</style>
<meta charset="utf-8"/>
</Head>
<body>
"@
 
$HTMLEnding = @"
<br><br><br>
<center><span class="$AdvertMessage">Report Generated by Corproate IT</span></center>
</body>
</html>
"@

##### Export #####
# ----------------------------------------------------------------

# Show a Progress Bar
Write-Progress -Activity "HTML file construction" -PercentComplete 0

# Export HTML header (HTML, header and opening body)
Set-Content -Path $ExportLog -Value $HTMLIntitle

# Export Hyper-V hosts hardware information
if ($HostHwInformation){
    Write-Progress -Activity "HTML file construction" -PercentComplete 10 -CurrentOperation "Hardware information gathering"
    Add-Content -Path $ExportLog -Value "<H2>Hyper-V Nodes and Cluster information</H2>"
    Add-Content -Path $ExportLog -Value "<table Class=$TableClass>"
    Add-Content -Path $ExportLog -Value '<tr>'
    Add-Content -Path $ExportLog -Value '<th>Node Name</th>'
    Add-Content -Path $ExportLog -Value '<th>Memory Installed</th>'
    Add-Content -Path $ExportLog -Value '<th>CPU Name</th>'
    Add-Content -Path $ExportLog -Value '<th>CPU deviceID</th>'
    Add-Content -Path $ExportLog -Value '<th># Cores</th>'
    Add-Content -Path $ExportLog -Value '<th># Logical Processors</th>'
    Add-Content -Path $ExportLog -Value '<th>Total Logical Processors</th>'
    Add-Content -Path $ExportLog -Value '<th># Virtual Machines</th>'
    Add-Content -Path $ExportLog -Value '<th>vCPU used</th>'
    Add-Content -Path $ExportLog -Value '<th>Memory used</th>'
    Add-Content -Path $ExportLog -Value '<th>Consolidation rate</th>'
    Add-Content -Path $ExportLog -Value '</tr>'
    Foreach ($Node in $VMHostHwInformation){
        $NodeNbr++

        $CPUColsTemp   = @()
        $ThreadNbr     = 0
        $CPUNbr        = 0
        $NodeTotalCore = 0

        # Add each CPU information in a temporary array
        Foreach ($CPU in $Node.CPU){
            # CPUNbr enables to calculate the RowSpan in the HTML table
            $CPUNbr++
            $NodeTotalCore += $CPU.NumberOfCores
            $TotalPhyCore  += $CPU.NumberOfCores
            $TotalCore     += $CPU.NumberOfLogicalProcessors
            $ThreadNbr     += $CPU.NumberOfLogicalProcessors
            $CPUColsTemp   += "<td>$($CPU.Name)</td>"
            $CPUColsTemp   += "<td>$($CPU.DeviceId)</td>"
            $CPUColsTemp   += "<td><span class=$ValueClass>$($CPU.NumberOfCores)</span><span class=$UnitClass>CORES</span></td>"
            $CPUColsTemp   += "<td><span class=$ValueClass>$($CPU.NumberOfLogicalProcessors)</span><span class=$UnitClass>CORES</span></td>"
        }

        # export HTML content to $ExportLog
        Add-Content -Path $ExportLog -Value '<tr>'
        Add-Content -Path $ExportLog -Value "<td RowSpan=$CPUNbr NOWRAP class=$ComputerClass>$($Node.name)</td>"
        Add-Content -Path $ExportLog -Value "<td RowSpan=$CPUNbr><span class=$ValueClass>$($Node.Memory)</span><span class=$UnitClass>GB</span></td>"    
        Add-Content -Path $ExportLog -Value $CPUColsTemp[0]
        Add-Content -Path $ExportLog -Value $CPUColsTemp[1]
        Add-Content -Path $ExportLog -Value $CPUColsTemp[2]
        Add-Content -Path $ExportLog -Value $CPUColsTemp[3]
        Add-Content -Path $ExportLog -Value "<td RowSpan=$CPUNbr><span class=$ValueClass>$ThreadNbr</span><span class=$UnitClass>THREADS</span></td>"


        # Show the workload of each Hyper-V nodes
        Foreach ($HostWorkload in $Node.Workload){

            # if 85% of the memory is used change the CSS class to erro
            if ($HostWorkload.MemAssigned -gt (85*$Node.Memory)/100){
                $MemClass = $TDError
            }
            Else{
                $MemClass = $TDOK
            }

            # if the consolidation rate is exceeded, change the CSS class to error
            if ($HostWorkload.vCPU -gt ($TxConso*$NodetotalCore)){
                $CPUClass = $TDError
            }
            Else {
                $CPUClass = $TDOK
            }

            $TotalVMs         += $HostWorkload.VMCount
            $TotalvCPU        += $HostWorkload.vCPU
            $TotalMemAssigned += $HostWorkload.MemAssigned
            Add-Content -Path $ExportLog -Value "<td RowSpan=$CPUNbr><span class=$ValueClass>$($HostWorkload.VMCount)</span><span class=$UnitClass>VMs</span></td>"
            Add-Content -Path $ExportLog -Value "<td Class=$CPUClass RowSpan=$CPUNbr><span class=$ValueClass>$($HostWorkload.vCPU)</span><span class=$UnitClass>vCPU</span></td>"
            Add-Content -Path $ExportLog -Value "<td Class=$MemClass RowSpan=$CPUNbr><span class=$ValueClass>$([Math]::Round($HostWorkload.MemAssigned, 0))</span><span class=$UnitClass>GB</span></td>"

            # The consolidation rate is round to 2 décimal
            $ConsoRate = [Math]::Round($HostWorkload.vCPU / $NodeTotalCore, 2)
            if ($ConsoRate -ge 4){
                $Class = $TDError
            }
            Else {
                $Class = $TDOK
            }
            Add-Content -Path $ExportLog -Value "<td RowSpan=$CPUNbr Class=$Class><span class=$ValueClass>$ConsoRate</td>"
        
        }
        Add-Content -Path $ExportLog -Value '</tr>'
        #Add row outside the rowspan
        For ($i = 3; $i -lt (($CPUnbr*4)-1); $i += 4){
                Add-Content -Path $ExportLog -Value '<tr>'
                Add-Content -Path $ExportLog -Value $CPUColsTemp[$i+1]
                Add-Content -Path $ExportLog -Value $CPUColsTemp[$i+2]
                Add-Content -Path $ExportLog -Value $CPUColsTemp[$i+3]
                Add-Content -Path $ExportLog -Value $CPUColsTemp[$i+4]
                Add-Content -Path $ExportLog -Value '</tr>'
        }
        $TotalMem    += $Node.Memory
        $TotalThread += $ThreadNbr

    }

    # all this calcul is made at N-1 (Remove one node resource from calcul to take care incidents)
    $TotalCore     = [Math]::Round(($TotalCore/$NodeNbr)*($NodeNbr-1), 0)
    $TotalMem      = ($TotalMem/$NodeNbr)*($NodeNbr-1)
    $TotalThread   = [Math]::Round(($TotalThread/$NodeNbr)*($NodeNbr-1), 0)
    $vCPUAvailable = [Math]::Round(($TxConso*($TotalPhyCore/$NodeNbr))*($NodeNbr-1), 0)
    $ClusterTxRate = [Math]::Round($TotalvCPU / $TotalPhyCore, 2)

    # export the row for cluster information
    Add-Content -Path $ExportLog -Value '<tr>'
    Add-Content -Path $ExportLog -Value "<td class=$ComputerClass NOWRAP>$ClusterName<br><span class=$AdvertMessage>(N-1 to take care one host down)</span></td>"
    Add-Content -Path $ExportLog -Value "<td><span class=$ValueClass>$TotalMem</span><span class=$UnitClass>GB</span></td>"
    Add-Content -Path $ExportLog -Value "<td colspan=4><span class=$ValueClass>Consolidation rate $($TxConso):1</span></td>"
    Add-Content -Path $ExportLog -Value "<td><span class=$ValueClass>$TotalCore</span><span class=$UnitClass>THREADS</span><br><span class=$ValueClass>$vCPUAvailable</span><span class=$UnitClass>vCPU</span></td>"
    Add-Content -Path $ExportLog -Value "<td><span class=$ValueClass>$TotalVMs</span><span class=$UnitClass>VMs</span></td>"

    # If vCPU allocated is greater than vCPU available, change CSS class to error
    if ($TotalvCPU -ge $vCPUAvailable){
                $Class = $TDError
    }
    Else {
                $Class = $TDOK
    }
    Add-Content -Path $ExportLog -Value "<td Class=$Class><span class=$ValueClass>$TotalvCPU</span><span class=$UnitClass>vCPU</span></td>"

    # if the total memory assigned is greater than memory available,change CSS class to error
    if ($TotalMemAssigned -ge $TotalMem){
                $Class = $TDError
    }
    Else {
                $Class = $TDOK
    }

    Add-Content -Path $ExportLog -Value "<td class=$Class><span class=$ValueClass>$([Math]::Round($TotalMemAssigned, 0))</span><span class=$UnitClass>GB</span></td>"

    # if the cluster rate is greater than expected, change CSS class to error
    if ($ClusterTxRate -ge $TxConso){
                $Class = $TDError
    }
    Else {
                $Class = $TDOK
    }

    Add-Content -Path $ExportLog -Value "<td class=$Class><span class=$ValueClass>$ClusterTxRate</span></td>"
    Add-Content -Path $ExportLog -Value '</table>'
}

# Export Hyper-V hosts network information to HTML
if ($HostNetInformation) {
    Add-Content -Path $ExportLog -Value "<H2>Network information</H2>"
    Foreach ($VMHost in $VMHosts){
        $VMHostNics = $VMHostNicsInfo |? VMHost -like $VMHost.Name

        Add-Content -Path $ExportLog -Value "<H3>Network information on $($VMHost.Name)</H3>"
        Add-Content -Path $ExportLog -Value "<table Class=$TableClass>"
        Add-Content -Path $ExportLog -Value '<tr>'
        Add-Content -Path $ExportLog -Value '<th>NIC Name</th>'
        Add-Content -Path $ExportLog -Value '<th>Description</th>'
        Add-Content -Path $ExportLog -Value '<th>VLAN</th>'
        Add-Content -Path $ExportLog -Value '<th>TCP/IP</th>'
        Add-Content -Path $ExportLog -Value '<th>Link Speed</th>'
        Add-Content -Path $ExportLog -Value '<th>RSS State</th>'
        Add-Content -Path $ExportLog -Value '<th>RSS</th>'
        Add-Content -Path $ExportLog -Value '<th>VMQ State</th>'
        Add-Content -Path $ExportLog -Value '<th>VMQ</th>'
        Add-Content -Path $ExportLog -Value '<th>RDMA State</th>'
        Add-Content -Path $ExportLog -Value '<th>VMMQ State</th>'
        Add-Content -Path $ExportLog -Value '<th>QoS</th>'
        Add-Content -Path $ExportLog -Value '<th>MTU</th>'
        Add-Content -Path $ExportLog -Value '<th>Switch Name</th>'
        Add-Content -Path $ExportLog -Value '<th>Team Mapping</th>'
        Add-Content -Path $ExportLog -Value '</tr>'

        Foreach ($Nic in $VMHostNics){
            Add-Content -Path $ExportLog -Value "<tr>"
            Add-Content -Path $ExportLog -Value "<td class=$ComputerClass>$($Nic.Name)<br><span class=$AdvertMessage>$($Nic.Type)</span></td>"
            Add-Content -Path $ExportLog -Value "<td>$($Nic.Description)</td>"
            Add-Content -Path $ExportLog -Value "<td>$($Nic.Vlan)</td>"
            Add-Content -Path $ExportLog -Value "<td class=$ComputerClass>$($Nic.IPAddress)<br><span class=$AdvertMessage>$($NIC.Gateway)</span><br><span class=$AdvertMessage>$($NIC.DNS)</span><br><span class=$AdvertMessage>$($NIC.DNSRegistration)</span></td>"
            Add-Content -Path $ExportLog -Value "<td>$($Nic.LinkSpeed)</td>"
            Add-Content -Path $ExportLog -Value "<td class=$ValueClass>$($Nic.RSSState)</td>"
            Add-Content -Path $ExportLog -Value "<td>$($Nic.RSS)</td>"
            Add-Content -Path $ExportLog -Value "<td class=$ValueClass>$($Nic.VMQState)</td>"
            Add-Content -Path $ExportLog -Value "<td>$($Nic.VMQ)</td>"
            Add-Content -Path $ExportLog -Value "<td class=$ValueClass>$($Nic.RDMAState)</td>"
            Add-Content -Path $ExportLog -Value "<td class=$ValueClass>$($Nic.VMMQ)</td>"
            Add-Content -Path $ExportLog -Value "<td class=$ValueClass>$($Nic.QoS)</td>"
            Add-Content -Path $ExportLog -Value "<td class=$ValueClass>$($Nic.MTU)</td>"
            Add-Content -Path $ExportLog -Value "<td>$($Nic.SwitchName)</td>"
            Add-Content -Path $ExportLog -Value "<td>$($Nic.TeamMapping)</td>"
            Add-Content -Path $ExportLog -Value "</tr>"
        }
        Add-Content -Path $ExportLog -Value '</table>'

        $VMHostvSwitch = $VMHostvSwitchInfo |? VMHost -like $VMHost.Name

        Add-Content -Path $ExportLog -Value "<H3>vSwitches on $($VMHost.Name)</H3>"
        Add-Content -Path $ExportLog -Value "<table Class=$TableClass>"
        Add-Content -Path $ExportLog -Value '<tr>'
        Add-Content -Path $ExportLog -Value '<th>Switch Name</th>'
        Add-Content -Path $ExportLog -Value '<th>Type</th>'
        Add-Content -Path $ExportLog -Value '<th>Embedded Teaming</th>'
        Add-Content -Path $ExportLog -Value '<th>Packet Direct</th>'
        Add-Content -Path $ExportLog -Value '<th>SRIOV</th>'
        Add-Content -Path $ExportLog -Value '<th>QoS Mode</th>'
        Add-Content -Path $ExportLog -Value '<th>NICs</th>'
        Add-Content -Path $ExportLog -Value '</tr>'

        Foreach ($vSwitch in $VMHostvSwitch){
            $NICsNbr = 0
            $NetColsTemp = @()
            Foreach ($NIC in $vSwitch.NICs){
                $NICsNbr++
                $NetColsTemp += "<td class=$ComputerClass>$NIC</td>"
            }

            Add-Content -Path $ExportLog -Value "<tr>"
            Add-Content -Path $ExportLog -Value "<td class=$ComputerClass RowSpan=$NICsNbr NOWRAP>$($vSwitch.Name)</td>" 
            Add-Content -Path $ExportLog -Value "<td RowSpan=$NICsNbr NOWRAP>$($vSwitch.Type)</td>" 
            Add-Content -Path $ExportLog -Value "<td RowSpan=$NICsNbr NOWRAP>$($vSwitch.EmbeddedTeaming)</td>"  
            Add-Content -Path $ExportLog -Value "<td RowSpan=$NICsNbr NOWRAP>$($vSwitch.PacketDirect)</td>"  
            Add-Content -Path $ExportLog -Value "<td RowSpan=$NICsNbr NOWRAP>$($vSwitch.IOVSupport)</td>"  
            Add-Content -Path $ExportLog -Value "<td RowSpan=$NICsNbr NOWRAP>$($vSwitch.QoSMode)</td>"
            
            Add-Content -Path $ExportLog -Value $NetColsTemp[0]  
            Add-Content -Path $ExportLog -Value "</tr>"
            For ($i = 0; $i -lt ($NICsNbr * 1)-1; $i++){
                Add-Content -Path $ExportLog -Value "<tr>"
                Add-Content -Path $ExportLog -Value $NetColsTemp[$i+1]
                Add-Content -Path $ExportLog -Value "</tr>" 
            }     
        }
        Add-Content -Path $ExportLog -Value '</table>'
    }


}

# Export Hyper-V hosts local storage information to HTML
if ($HostStoInformation){
    # Show progress bar
    Write-Progress -Activity "HTML file construction" -PercentComplete 20 -CurrentOperation "storage information gathering"

    #export Table header and title
    Add-Content -Path $ExportLog -Value "<H2>Storage information</H2>"
    Add-Content -Path $ExportLog -Value "<H3>Host storage information</H3>"
    Add-Content -Path $ExportLog -Value "<table Class=$TableClass>"
    Add-Content -Path $ExportLog -Value '<tr>'
    Add-Content -Path $ExportLog -Value '<th>Node Name</th>'
    Add-Content -Path $ExportLog -Value '<th>Drive Letter</th>'
    Add-Content -Path $ExportLog -Value '<th>File System Label</th>'
    Add-Content -Path $ExportLog -Value '<th>File System</th>'
    Add-Content -Path $ExportLog -Value '<th>Size</th>'
    Add-Content -Path $ExportLog -Value '<th>Size Remaining</th>'
    Add-Content -Path $ExportLog -Value '<th>Percentage free space</th>'
    Add-Content -Path $ExportLog -Value '</tr>'

    # for each Hyper-V nodes, export information
    Foreach ($Node in $StorageInformation){

        $StorageColsTemp = @()
        $StoNbr          = 0

        # for each storage device, export information in a temporary array
        Foreach ($Storage in $Node.StorageInformation){

            # This value enables to know the rowspan for the html table
            $StoNbr++

            # if it's a drive letter, :\ characters are added
            if ($Storage.DriveLetter -match "[A-Z]"){
                $StorageColsTemp += "<td>$($Storage.DriveLetter):\</td>"
            }
            else{
                $StorageColsTemp += "<td class=$TDNoInfo></td>"
            }
            $StorageColsTemp += "<td>$($Storage.FSLabel)</td>"
            $StorageColsTemp += "<td>$($Storage.FileSystem)</td>"
        

            # the value is converted to GB and rounded to 1 decimal
            $StorageColsTemp += "<td><span class=$ValueClass>$([Math]::Round($Storage.Size/1GB, 1))</span><span class=$UnitClass>GB</span></td>"
            $StorageColsTemp += "<td><span class=$ValueClass>$([Math]::Round($Storage.SizeRemaining/1GB, 1))</span><span class=$UnitClass>GB</span></td>"

            # Calculate the free percentage rounded to 2
            $PercentFreeSpace = [Math]::Round(($($Storage.SizeRemaining)*100)/$($Storage.Size), 2)

            # If there is less or equal 15% free space, CSS class is change to error
            if ($PercentFreeSpace -le 15){
                $Class = $TDError
            }
            Else{
                $Class = $TDOK
            }
            $StorageColsTemp += "<td class=$Class><span class=$ValueClass>$PercentFreeSpace</span><span class=$UnitClass>%</span></td>"
        }
        # Export the first line with the HTML rowspan
        Add-Content -Path $ExportLog -Value '<tr>'
        Add-Content -Path $ExportLog -Value "<td class=$ComputerClass rowspan=$StoNbr NOWRAP>$($Node.Name)</td>"
        Add-Content -Path $ExportLog -Value "$($StorageColsTemp[0])"
        Add-Content -Path $ExportLog -Value "$($StorageColsTemp[1])"
        Add-Content -Path $ExportLog -Value "$($StorageColsTemp[2])"
        Add-Content -Path $ExportLog -Value "$($StorageColsTemp[3])"
        Add-Content -Path $ExportLog -Value "$($StorageColsTemp[4])"
        Add-Content -Path $ExportLog -Value "$($StorageColsTemp[5])"
        Add-Content -Path $ExportLog -Value '</tr>'

        # Export other line outside the HTML rowspan
        For ($i = 5; $i -lt (($StoNbr*6)-1); $i += 6){
            Add-Content -Path $ExportLog -Value '<tr>'
            Add-Content -Path $ExportLog -Value "$($StorageColsTemp[$i+1])"
            Add-Content -Path $ExportLog -Value "$($StorageColsTemp[$i+2])"
            Add-Content -Path $ExportLog -Value "$($StorageColsTemp[$i+3])"
            Add-Content -Path $ExportLog -Value "$($StorageColsTemp[$i+4])"
            Add-Content -Path $ExportLog -Value "$($StorageColsTemp[$i+5])"
            Add-Content -Path $ExportLog -Value "$($StorageColsTemp[$i+6])"
            Add-Content -Path $ExportLog -Value '</tr>'
        }
    }
    Add-Content -Path $ExportLog -Value '</table>'
}

# Export Cluster storage information
if ($ClustStoInformation){
    # export the title and the header of the table
    Add-Content -Path $ExportLog -Value "<H3>Cluster storage information</H3>"
    Add-Content -Path $ExportLog -Value "<table Class=$TableClass>"
    Add-Content -Path $ExportLog -Value '<tr>'
    Add-Content -Path $ExportLog -Value '<th>Cluster Name</th>'
    Add-Content -Path $ExportLog -Value '<th>CSV Name</th>'
    Add-Content -Path $ExportLog -Value '<th>State</th>'
    Add-Content -Path $ExportLog -Value '<th>Maintenance Mode</th>'
    Add-Content -Path $ExportLog -Value '<th>Volume Name</th>'
    Add-Content -Path $ExportLog -Value '<th>Size</th>'
    Add-Content -Path $ExportLog -Value '<th>Size Remaining</th>'
    Add-Content -Path $ExportLog -Value '<th>Percentage free space</th>'
    Add-Content -Path $ExportLog -Value '</tr>'

    # For each cluster, exporting HTML information
    Foreach ($HvCluster in $StoClusterInfo){
        $ClustStoColsTemp = @()
        $CSVNbr           = 0

        # For each storage device in the cluster, exporting HTML in a temporary array
        Foreach ($Storage in $HvCluster.StorageInformation){

            # This variable enables to calculate the HTML rowspan
            $CSVNbr++
            $ClustStoColsTemp += "<td>$($Storage.Name)</td>"

            # If the storage device is not online, change the CSS class to error
            If ($Storage.State -notlike "Online"){
                $Class = $TDError
            }
            Else {
                $Class = $TDOK
            }
            $ClustStoColsTemp += "<td class=$Class><span class=$ValueClass>$($Storage.State)</span></td>"

            # if the storage device is in maintenance mode, change the CSS class to error
            If ($Storage.MaintenanceMode -like "True"){
                $Class           = $TDWarn
                $MaintenanceMode = "Enabled"
            }
            Else{
                $Class           = $TDOK
                $MaintenanceMode = "Disabled"
            }

            $ClustStoColsTemp += "<td class=$Class><span class=$ValueClass>$MaintenanceMode</span></td>"
            $ClustStoColsTemp += "<td>$($Storage.FriendlyVolumeName)</td>"
            $ClustStoColsTemp += "<td><span class=$ValueClass>$([math]::round($Storage.Size/1GB, 1))</span><span class=$UnitClass>GB</span></td>"

            # Calculate the free space on storage device
            $SizeRemaining     = $Storage.Size - $Storage.UsedSpace
            $ClustStoColsTemp += "<td><span class=$ValueClass>$([math]::round($SizeRemaining/1GB, 1))</span><span class=$UnitClass>GB</span></td>"
            $PercentFreeSpace  = [math]::round(($SizeRemaining*100)/$Storage.Size, 2)
        
            # if the storage device size is less or equal to 1GB and if there is only 15% or less of free space, change CSS class to error
            if (($Storage.Size/1GB -le 1) -and ($PercentFreeSpace -le 15)){
                $Class = $TDError
            }

            # if the storage device size is greater than 1GB and if there is only 10% or less of free space, change CSS class to error
            Elseif (($Storage.Size/1GB -gt 1) -and ($PercentFreeSpace -le 10)){
                $Class = $TDError
            }
            Else{
                $Class = $TDOK
            }
            $ClustStoColsTemp += "<td class=$Class><span class=$ValueClass>$PercentFreeSpace</span><span class=$UnitClass>%</span></td>"
        }
    }

    # Export the first line of the table with rowspan
    Add-Content -Path $ExportLog -Value '<tr>'
    Add-Content -Path $ExportLog -Value "<td class=$ComputerClass rowspan=$CSVNbr NOWRAP>$($HvCluster.Name)</td>"
    Add-Content -Path $ExportLog -Value "$($ClustStoColsTemp[0])"
    Add-Content -Path $ExportLog -Value "$($ClustStoColsTemp[1])"
    Add-Content -Path $ExportLog -Value "$($ClustStoColsTemp[2])"
    Add-Content -Path $ExportLog -Value "$($ClustStoColsTemp[3])"
    Add-Content -Path $ExportLog -Value "$($ClustStoColsTemp[4])"
    Add-Content -Path $ExportLog -Value "$($ClustStoColsTemp[5])"
    Add-Content -Path $ExportLog -Value "$($ClustStoColsTemp[6])"
    Add-Content -Path $ExportLog -Value '</tr>' 

    #export lines outside the rowspan
    For ($i = 6; $i -lt (($CSVNbr*7)-1); $i += 7){
        Add-Content -Path $ExportLog -Value '<tr>'
        Add-Content -Path $ExportLog -Value "$($ClustStoColsTemp[$i+1])"
        Add-Content -Path $ExportLog -Value "$($ClustStoColsTemp[$i+2])"
        Add-Content -Path $ExportLog -Value "$($ClustStoColsTemp[$i+3])"
        Add-Content -Path $ExportLog -Value "$($ClustStoColsTemp[$i+4])"
        Add-Content -Path $ExportLog -Value "$($ClustStoColsTemp[$i+5])"
        Add-Content -Path $ExportLog -Value "$($ClustStoColsTemp[$i+6])"
        Add-Content -Path $ExportLog -Value "$($ClustStoColsTemp[$i+7])"
        Add-Content -Path $ExportLog -Value '</tr>'
    }
    Add-Content -Path $ExportLog -Value '</table>'
}

# Export Cluster Network Information to HTML
if ($ClustNetInformation){
    # Show a progress bar
    Write-Progress -Activity "HTML file construction" -PercentComplete 40 -CurrentOperation "Cluster Network information gathering"

    # Export title and table header
    Add-Content -Path $ExportLog -Value "<H3>Cluster network Information</H3>"
    Add-Content -Path $ExportLog -Value "<table Class=$TableClass>"
    Add-Content -Path $ExportLog -Value '<tr>'
    Add-Content -Path $ExportLog -Value '<th>Cluster Name</th>'
    Add-Content -Path $ExportLog -Value '<th>Network Name</th>'
    Add-Content -Path $ExportLog -Value '<th>IP Address</th>'
    Add-Content -Path $ExportLog -Value '<th>Address Mask</th>'
    Add-Content -Path $ExportLog -Value '<th>Role</th>'
    Add-Content -Path $ExportLog -Value '<th>State</th>'
    Add-Content -Path $ExportLog -Value '</tr>'

    $ClusterNetColsTemp = @()
    $NetClustNbr      = 0

    # For each network in the cluster, exporting information
    Foreach ($Network in  $ClusterNetInformation){
        # This variable enables to calculate the rowspan of the HTML table
        $NetClustNbr++

        $LMClass =""
        # If the Network is enabled to transmit Live-Migration, verifying if cluster communication are enabled
        if ($Network.LMNet){
            $ClusterNetColsTemp += "<td>$($Network.Name)<br><span class=$AdvertMessage>Live-Migration Network</span></td>"
        }
        Else {
            $ClusterNetColsTemp += "<td>$($Network.Name)</td>"
        }
        $ClusterNetColsTemp += "<td>$($Network.Address)</td>"
        $ClusterNetColsTemp += "<td>$($Network.AddressMask)</td>"
        $ClusterNetColsTemp += "<td class=$LMClass>$($Network.Role)</td>"

        # if the state of the network is UP, export CSS class OK
        if ($Network.State -like "Up"){
            $Class = $TDOK
        }
        Else{
            $Class = $TDError
        }
        $ClusterNetColsTemp += "<td class=$class><span class=$ValueClass>$($Network.State)</span></td>"
    }

    # Exporting the first line of the table with the rowspan
    Add-Content -Path $ExportLog -Value "<tr>"
    Add-Content -Path $ExportLog -Value "<td class=$ComputerClass RowSpan=$NetClustNbr>$ClusterName</td>"
    Add-Content -Path $ExportLog -Value "$($ClusterNetColsTemp[0])"
    Add-Content -Path $ExportLog -Value "$($ClusterNetColsTemp[1])"
    Add-Content -Path $ExportLog -Value "$($ClusterNetColsTemp[2])"
    Add-Content -Path $ExportLog -Value "$($ClusterNetColsTemp[3])"
    Add-Content -Path $ExportLog -Value "$($ClusterNetColsTemp[4])"
    Add-Content -Path $ExportLog -Value "</tr>"

    # exporting other line outside the rowspan
    For ($i = 4; $i -lt ($NetClustNbr*5)-1; $i += 5){
        Add-Content -Path $ExportLog -Value "<tr>"
        Add-Content -Path $ExportLog -Value "$($ClusterNetColsTemp[$i+1])"
        Add-Content -Path $ExportLog -Value "$($ClusterNetColsTemp[$i+2])"
        Add-Content -Path $ExportLog -Value "$($ClusterNetColsTemp[$i+3])"
        Add-Content -Path $ExportLog -Value "$($ClusterNetColsTemp[$i+4])"
        Add-Content -Path $ExportLog -Value "$($ClusterNetColsTemp[$i+5])"
        Add-Content -Path $ExportLog -Value "</tr>"
    }
    Add-Content -Path $ExportLog -Value "</table>"
}

# Exporting Hyper-V Host OS Information to HTML
if ($HostOSInformation){
    # Show a progress bar
    Write-Progress -Activity "HTML file construction" -PercentComplete 50 -CurrentOperation "Host OS information gathering"

    #export to HTML file the title and the table header
    Add-Content -Path $ExportLog -Value "<H2>Host OS Information</H2>"
    Add-Content -Path $ExportLog -Value "<table Class=$TableClass>"
    Add-Content -Path $ExportLog -Value '<tr>'
    Add-Content -Path $ExportLog -Value '<th>Node Name</th>'
    Add-Content -Path $ExportLog -Value '<th>OS Version</th>'
    Add-Content -Path $ExportLog -Value '<th>OS Language</th>'
    Add-Content -Path $ExportLog -Value '<th>Firewall State</th>'
    Add-Content -Path $ExportLog -Value '<th>HotFix installed</th>'
    Add-Content -Path $ExportLog -Value '<th>Minimal Interface</th>'
    Add-Content -Path $ExportLog -Value '</tr>'

    $i           = 0
    $HotFixError = $False

    # for each node in the cluster
    Foreach ($Node in $VMHostOSInformation) {
        # on the first node, add to variable the number of the hotfix
        if ($i -eq 0){
            $i++
            $HotFixNbr = $Node.OSHotfix
        }
        # if it is not the first node ...
        Else {
            # verifying if the number of Hotfix is the same. If not, break the loop and change $hotfixerror variable to $true
            if ($Node.OSHotFix -ne $HotFixNbr){
                $HotFixClass   = $TDError
                  $HotFixError = $True
                  break
            }
        }
            
    }

    #if there is no error with hotfix, CSS class is OK
    if(!$HotFixError){
        $HotFixClass = $TDOK
    }

    #for each node in the cluster, export HTML information
    Foreach ($Node in $VMHostOSInformation){

        $FirewallColsTemp = @()

        # For each Firewall profile, export HTML to a temporary array. Change CSS class related to firewall profile state
        Foreach ($Firewall in $Node.Firewall){

            
            if ($Firewall.State -eq 1){
                $Class = $TDOK
                $FirewallState = "Enabled"
            }
            Else{
                $Class = $TDError
                $FirewallState = "Disabled"
            }
            $FirewallColsTemp += "<td class=$class>$($Firewall.Name): $FirewallState</td>"
        }

        Add-Content -path $ExportLog -Value "<tr>"
        Add-Content -path $ExportLog -Value "<td RowSpan=3 class=$ComputerClass>$($Node.Name)</td>"
        Add-Content -path $ExportLog -Value "<td RowSpan=3>$($Node.OSVersion)</td>"

        # Get the textual OS language by using Get-OSLanguage function
        $OSlanguage = Get-OSLanguage -Language $Node.OSLanguage

        # if the OS language is not En-US, change the CSS Class to Error
        if ($Node.OSLanguage -ne 1033){
            $Class = $TDError
        }
        Else{
            $Class = $TDOK
        }
        Add-Content -path $ExportLog -Value "<td RowSpan=3 class=$Class><span class=$ValueClass>$OSLanguage</span></td>"
        Add-Content -path $ExportLog -Value $FirewallColsTemp[0]
        Add-Content -path $ExportLog -Value "<td RowSpan=3 class=$HotFixClass><span class=$ValueClass>$($Node.OSHotfix)</span></td>"

        # if The node is not in minimal interface, change the CSS class to Error
        If ($Node.GuiInstalled){
            $MinShell = "No"
            $Class    = $TDError
        }
        Else{
            $MinShell = "Yes"
            $Class    = $TDOK
        }

        Add-Content -path $ExportLog -Value "<td RowSpan=3 class=$Class><span class=$ValueClass>$MinShell</span></td>"
        Add-Content -path $ExportLog -Value "</tr>"

        For ($i = 1; $i -le 2; $i++){
           Add-Content -path $ExportLog -Value "<tr>"
           Add-Content -path $ExportLog -Value $FirewallColsTemp[$i]
           Add-Content -path $ExportLog -Value "</tr>"
        }
        
    }
    # Table about Hyper-V settings
    Add-Content -Path $ExportLog -Value "</table>"
    Add-Content -Path $ExportLog -Value "<H2>Hyper-V Information</H2>"
    Add-Content -Path $ExportLog -Value "<table Class=$TableClass>"
    Add-Content -Path $ExportLog -Value '<tr>'
    Add-Content -Path $ExportLog -Value '<th>Node Name</th>'
    Add-Content -Path $ExportLog -Value '<th>VM Path</th>'
    Add-Content -Path $ExportLog -Value '<th>VHD Path</th>'
    Add-Content -Path $ExportLog -Value '<th>Simultaneous Live-Migration</th>'
    Add-Content -Path $ExportLog -Value '<th>Simultaneous Storage Live-Migration</th>'
    Add-Content -Path $ExportLog -Value '<th>Live-Migration Authentication</th>'
    Add-Content -Path $ExportLog -Value '<th>Live-Migration Performance option</th>'
    Add-Content -Path $ExportLog -Value '</tr>'

    # export Hyper-V Settings to the table
    Foreach ($VMHost in $VMHostHyperVInfo){
        Add-Content -Path $ExportLog -Value "<tr>"
        Add-Content -Path $ExportLog -Value "<td class=$ComputerClass>$($VMHost.VMHost)</td>" 
        Add-Content -Path $ExportLog -Value "<td>$($VMHost.VMPath)</td>" 
        Add-Content -Path $ExportLog -Value "<td>$($VMHost.VHDPath)</td>" 
        Add-Content -Path $ExportLog -Value "<td class=$ValueClass>$($VMHost.MaximumLM)</td>" 
        Add-Content -Path $ExportLog -Value "<td class=$ValueClass>$($VMHost.MaximumStoMig)</td>" 
        Add-Content -Path $ExportLog -Value "<td>$($VMHost.LMAuthentication)</td>" 
        Add-Content -Path $ExportLog -Value "<td>$($VMHost.LMPerformanceOption)</td>"
        Add-Content -Path $ExportLog -Value '</tr>'
    }
    Add-Content -Path $ExportLog -Value "</table>"
}

# Exporting cluster configuration information to HTML
if ($ClustConfInfo){

    # Show a progress bar
    Write-Progress -Activity "HTML file construction" -PercentComplete 60 -CurrentOperation "Cluster information gathering"
    
    # Export title and table header
    Add-Content -Path $ExportLog -Value "<H2>Cluster Information</H2>"
    Add-Content -Path $ExportLog -Value "<table Class=$TableClass>"
    Add-Content -Path $ExportLog -Value '<tr>'
    Add-Content -Path $ExportLog -Value '<th>Node Name</th>'
    Add-Content -Path $ExportLog -Value '<th>Node Number</th>'
    Add-Content -Path $ExportLog -Value '<th>Quorum Type</th>'
    Add-Content -Path $ExportLog -Value '<th>Quorum Resource</th>'
    Add-Content -Path $ExportLog -Value '<th>Dynamic Witness</th>'
    Add-Content -Path $ExportLog -Value '<th>Dynamic Quorum</th>'
    Add-Content -Path $ExportLog -Value '<th>Block Cache Size</th>'
    Add-Content -Path $ExportLog -Value '</tr>'

    # Export in HTML cluster information
    Add-Content -Path $ExportLog -Value "<tr>"
    Add-Content -Path $ExportLog -Value "<td class=$ComputerClass>$($ClusterConfInformation.Name)</td>"
    Add-Content -Path $ExportLog -Value "<td>$($ClusterConfInformation.NodeNbr)</td>"
    Add-Content -Path $ExportLog -Value "<td>$($ClusterConfInformation.QuorumType)</td>"
    Add-Content -Path $ExportLog -Value "<td>$($ClusterConfInformation.QuorumResource)</td>"
    Add-Content -Path $ExportLog -Value "<td>$($ClusterConfInformation.WitnessDynamicWeight)</td>"
    Add-Content -Path $ExportLog -Value "<td>$($ClusterConfInformation.DynamicQuorum)</td>"

    # If BLockCacheSize is less than 512MB, export CSS class Error
    if ($ClusterConfInformation.BlockCacheSize -lt 512){
        $Class = $TDError
    }
    Else{
        $Class = $TDOK
    }
    Add-Content -Path $ExportLog -Value "<td class=$Class><span class=$ValueClass>$($ClusterConfInformation.BlockCacheSize)</span><span class=$UnitClass>MB</span></td>"
    Add-Content -Path $ExportLog -Value "</tr>"

    Add-Content -Path $ExportLog -Value "</table>"

}

# Exporting Virtual Machines information to HTML
if ($VMHostWorkloadInfo){
    # Show a progress bar
    Write-Progress -Activity "HTML file construction" -PercentComplete 70 -CurrentOperation "VM Hosts workload gathering"

    # Export title and table header
    Add-Content -Path $ExportLog -Value "<H2>Virtual Machines</H2>"
    Add-Content -Path $ExportLog -Value "<table Class=$TableClass>"
    Add-Content -Path $ExportLog -Value '<tr>'
    Add-Content -Path $ExportLog -Value '<th>VM Name</th>'
    Add-Content -Path $ExportLog -Value '<th>Hyper-V Host</th>'
    Add-Content -Path $ExportLog -Value '<th>State</th>'
    Add-Content -Path $ExportLog -Value '<th>Gen</th>'
    Add-Content -Path $ExportLog -Value '<th>Clustered</th>'
    Add-Content -Path $ExportLog -Value '<th>vCPU count</th>'
    Add-Content -Path $ExportLog -Value '<th>Dynamic Memory</th>'
    Add-Content -Path $ExportLog -Value '<th>Memory Demand</th>'
    Add-Content -Path $ExportLog -Value '<th>Memory Assigned</th>'
    Add-Content -Path $ExportLog -Value '<th>Disk Controller</th>'
    Add-Content -Path $ExportLog -Value '<th>Disk Path</th>'
    Add-Content -Path $ExportLog -Value '<th>Type</th>'
    Add-Content -Path $ExportLog -Value '<th>Size</th>'
    Add-Content -Path $ExportLog -Value '<th>Checkpoint</th>'
    Add-Content -Path $ExportLog -Value '</tr>'

    # For each virtual machines, exporting information
    Foreach ($VM in $VMHostsWorkloadInformation){
        if ($VM.Name -notlike $Null){
            $vDiskColsTemp = @()
            $vDiskNbr      = 0
            $SnapTemp      = $Null

            # For each VHD, export HTML to temporary array
            Foreach ($vDisk in $VM.VMDisks){

                # this variable enables to calculate the HTML rowspan
                $vDiskNbr++
                # If VM is in Gen2 and the VHD controller are not SCSI, export CSS Class error
                if (($VM.Generation -like" 2") -and ($VM.ControllerType -notlike "SCSI")){
                    $Class = $TDError
                }
                Else {
                    $Class = $TDOK
                }
                $vDiskColsTemp += "<td class=$class>$($vDisk.ControllerType)</td>"

                $vDiskName      = Split-Path $vDisk.Path -Leaf

                # If the Virtual Disk is not a VHDX, export CSS Class error
                if ($vDiskName -notlike "*.vhdx"){
                    $Class = $TDError
                }
                Else{
                    $Class = $TDOK
                }
                $vDiskColsTemp += "<td class=$Class>$($vDisk.Path)</td>"
                $vDiskColsTemp += "<td>$($vDisk.VHDType)</td>"
                $vDiskColsTemp += "<td><span class=$ValueClass>$([math]::Round($vDisk.Size/1GB, 1))</span><span class=$UnitClass>GB</span></td>"
            }

            # for each checkpoint, exporting to temporary array
            Foreach ($SnapShot in $VM.CheckPoints){
                $SnapTemp += "$($SNapShot.Name) ($($SnapShot.CreationTime))<br>"
            }
            Add-Content -Path $ExportLog -Value "<tr>"
            Add-Content -Path $ExportLog -Value "<td RowSpan=$vDiskNbr class=$ComputerClass>$($VM.Name)</td>"
            Add-Content -Path $ExportLog -Value "<td RowSpan=$vDiskNbr>$($VM.VMHost)</td>"

            # if the VM is not running, export CSS class error
            If ($VM.State -like "Running"){
                $Class = $TDOK
            }
            Else{
                $Class = $TDError
            }
            Add-Content -Path $ExportLog -Value "<td RowSpan=$vDiskNbr class=$class><span class=$ValueClass>$($VM.State)</span></td>"
            Add-Content -Path $ExportLog -Value "<td RowSpan=$vDiskNbr><span class=$ValueClass>$($VM.Generation)</span></td>"

            # if the VM is not clustered, export CSS class error and change the true/false result by Yes/No
            if ($VM.IsClustered -like "true"){
                $Class = $TDOK
                $IsClustered = "Yes"
            }
            Else{
                $Class = $TDError
                $IsClustered = "No"
            }
            Add-Content -Path $ExportLog -Value "<td RowSpan=$vDiskNbr>$IsClustered</td>"
            Add-Content -Path $ExportLog -Value "<td RowSpan=$vDiskNbr><span class=$ValueClass>$($VM.ProcessorCount)</span><span class=$UnitClass>vCPU</span></td>"

            # Changing the True/False value by Yes/No
            If ($VM.DynamicMemoryEnabled -like "true"){
                $DynamicMemory = "Yes"
            }
            Else {
                $DynamicMemory = "No"
            }

            # Exporting the first line of the row with the RowSpan
            Add-Content -Path $ExportLog -Value "<td RowSpan=$vDiskNbr>$DynamicMemory</td>"
            Add-Content -Path $ExportLog -Value "<td RowSpan=$vDiskNbr><span class=$ValueClass>$([math]::round($VM.MemoryDemand/1GB, 1))</span><span class=$UnitClass>GB</span></td>"
            Add-Content -Path $ExportLog -Value "<td RowSpan=$vDiskNbr><span class=$ValueClass>$([math]::round($VM.MemoryAssigned/1GB, 1))</span><span class=$UnitClass>GB</span></td>"
            Add-Content -Path $ExportLog -Value $vDiskColsTemp[0]
            Add-Content -Path $ExportLog -Value $vDiskColsTemp[1]
            Add-Content -Path $ExportLog -Value $vDiskColsTemp[2]
            Add-Content -Path $ExportLog -Value $vDiskColsTemp[3]
            Add-Content -Path $ExportLog -Value "<td RowSpan=$vDiskNbr>$SnapTemp</td>"
            Add-Content -Path $ExportLog -Value "</tr>"

            # Exporting the other line outside rowspan
            For ($i =3; $i -lt ($vDiskNbr*4)-1; $i += 4){
                Add-Content -Path $ExportLog -Value "<tr>"
                Add-Content -Path $ExportLog -Value $vDiskColsTemp[$i+1]
                Add-Content -Path $ExportLog -Value $vDiskColsTemp[$i+2]
                Add-Content -Path $ExportLog -Value $vDiskColsTemp[$i+3]
                Add-Content -Path $ExportLog -Value $vDiskColsTemp[$i+4]
                Add-Content -Path $ExportLog -Value "</tr>"
            }
        }
    }
    Add-Content -Path $ExportLog -Value "</table>"
}

# Export Storage Spaces Direct information to HTML
if ($ClusterS2D){
    # Show progress bar
    Write-Progress -Activity "HTML file construction" -PercentComplete 70 -CurrentOperation "Storage Spaces Direct information gathering"

    #export Table header and title
    Add-Content -Path $ExportLog -Value "<H2>Storage Spaces Direct</H2>"
    
    # Export title and table header for Storage Pool
    Add-Content -Path $ExportLog -Value "<H3>Storage Pool Information</H3>"
    Add-Content -Path $ExportLog -Value "<table Class=$TableClass>"
    Add-Content -Path $ExportLog -Value '<tr>'
    Add-Content -Path $ExportLog -Value '<th>Friendly Name</th>'
    Add-Content -Path $ExportLog -Value '<th>Health</th>'
    Add-Content -Path $ExportLog -Value '<th>Operational Status</th>'
    Add-Content -Path $ExportLog -Value '<th>Size</th>'
    Add-Content -Path $ExportLog -Value '<th>Allocated Size</th>'
    Add-Content -Path $ExportLog -Value '<th>Free Space</th>'
    Add-Content -Path $ExportLog -Value '</tr>'

    # Add a row for each Storage Pool
    Foreach ($StoragePool in $StoragePoolInformation){

        Add-Content -Path $ExportLog -Value "<tr>"
        Add-Content -Path $ExportLog -Value "<td class=$ComputerClass>$($StoragePool.FriendlyName)</td>"
        
        # change the class depending on healthy or not
        If ($StoragePool.HealthStatus -notlike "Healthy"){
            $Class = $TDError
        }
        Else {
            $Class = $TDOK
        }

        # change the class depending on healthy or not
        Add-Content -Path $ExportLog -Value "<td class=$class>$($StoragePool.HealthStatus)</td>"
        If ($StoragePool.OperationalStatus -notlike "OK"){
            $Class = $TDError
        }
        Else {
            $Class = $TDOK
        }
        # export value formatted for human (yes you !)
        Add-Content -Path $ExportLog -Value "<td class=$class>$($StoragePool.OperationalStatus)</td>"
        Add-Content -Path $ExportLog -Value "<td><span class=$ValueClass>$([math]::round($StoragePool.Size/1TB, 2))</span><span class=$UnitClass>TB</span></td>"
        Add-Content -Path $ExportLog -Value "<td><span class=$ValueClass>$([math]::round($StoragePool.AllocatedSize/1TB, 2))</span><span class=$UnitClass>TB</span></td>"
        Add-Content -Path $ExportLog -Value "<td><span class=$ValueClass>$([math]::round((($StoragePool.Size - $StoragePool.AllocatedSize)/1TB), 2))</span><span class=$UnitClass>TB</span></td>"
        Add-Content -Path $ExportLog -Value "</tr>"
    }

    Add-Content -Path $ExportLog -Value "</table>"

    # export information about virtual disks
    Add-Content -Path $ExportLog -Value "<H3>Virtual disk Information</H3>"
    Add-Content -Path $ExportLog -Value "<table Class=$TableClass>"
    Add-Content -Path $ExportLog -Value '<tr>'
    Add-Content -Path $ExportLog -Value '<th>Friendly Name</th>'
    Add-Content -Path $ExportLog -Value '<th>Health</th>'
    Add-Content -Path $ExportLog -Value '<th>Number of columns</th>'
    Add-Content -Path $ExportLog -Value '<th>Resiliency</th>'
    Add-Content -Path $ExportLog -Value '<th>Size</th>'
    Add-Content -Path $ExportLog -Value '<th>Footprint on pool</th>'
    Add-Content -Path $ExportLog -Value '</tr>'

    # export virtual disks sorted by virtual disk name (ASC)
    Foreach ($VirtualDisk in ($VirtualDiskInformation | sort -Property FriendlyName)){

        Add-Content -Path $ExportLog -Value "<tr>"
        Add-Content -Path $ExportLog -Value "<td class=$ComputerClass>$($VirtualDisk.FriendlyName)</td>"
        If ($VirtualDisk.HealthStatus -notlike "Healthy"){
            $Class = $TDError
        }
        Else {
            $Class = $TDOK
        }
        Add-Content -Path $ExportLog -Value "<td class=$Class>$($VirtualDisk.HealthStatus)</td>"
        Add-Content -Path $ExportLog -Value "<td><span class=$ValueClass>$($VirtualDisk.NumberOfColumns)</span></td>"
       
        # format text for resiliency
        If (($VirtualDisk.ResiliencySettingName -like "Mirror") -and ($VirtualDisk.NumberOfDataCopies -eq 2)){
            $Resiliency = "2-Way Mirroring"
        }
        ElseIf (($VirtualDisk.ResiliencySettingName -like "Mirror") -and ($VirtualDisk.NumberOfDataCopies -eq 3)){
            $Resiliency = "3-Way Mirroring"
        }
        ElseIf (($VirtualDisk.ResiliencySettingName -like "Parity") -and ($VirtualDisk.NumberOfDataCopies -eq 2)){
            $Resiliency = "Simple Parity"
        }
        ElseIf (($VirtualDisk.ResiliencySettingName -like "Parity") -and ($VirtualDisk.NumberOfDataCopies -eq 3)){
            $Resiliency = "Dual Parity"
        }
        Add-Content -Path $ExportLog -Value "<td>$Resiliency</td>"
        Add-Content -Path $ExportLog -Value "<td><span class=$ValueClass>$([math]::round($Virtualdisk.Size/1TB, 2))</span><span class=$UnitClass>TB</span></td>"
        Add-Content -Path $ExportLog -Value "<td><span class=$ValueClass>$([math]::round($Virtualdisk.FootprintOnPool/1TB, 2))</span><span class=$UnitClass>TB</span></td>"
        Add-Content -Path $ExportLog -Value "</tr>"
    }

    Add-Content -Path $ExportLog -Value "</table>"

    # Export physical disk information
    Add-Content -Path $ExportLog -Value "<H3>Physical disk information</H3>"
    Add-Content -Path $ExportLog -Value "<table Class=$TableClass>"
    Add-Content -Path $ExportLog -Value '<tr>'
    Add-Content -Path $ExportLog -Value '<th>Friendly Name</th>'
    Add-Content -Path $ExportLog -Value '<th>Storage Pool</th>'
    Add-Content -Path $ExportLog -Value '<th>Health</th>'
    Add-Content -Path $ExportLog -Value '<th>Operational Status</th>'
    Add-Content -Path $ExportLog -Value '<th>Firmware version</th>'
    Add-Content -Path $ExportLog -Value '<th>Model</th>'
    Add-Content -Path $ExportLog -Value '<th>Serial number</th>'
    Add-Content -Path $ExportLog -Value '<th>Media type</th>'
    Add-Content -Path $ExportLog -Value '<th>Bus type</th>'
    Add-Content -Path $ExportLog -Value '<th>Usage</th>'
    Add-Content -Path $ExportLog -Value '<th>Size</th>'
    Add-Content -Path $ExportLog -Value '<th>Allocated size</th>'
    Add-Content -Path $ExportLog -Value '<th>Free Size</th>'
    Add-Content -Path $ExportLog -Value '</tr>'

    # Physical disk are exported sorted by the storage pool name
    Foreach ($PhysicalDisk in ($PhysicalDiskInformation | sort -Property StoragePoolFriendlyName)){

        Add-Content -Path $ExportLog -Value "<tr>"
        Add-Content -Path $ExportLog -Value "<td class=$ComputerClass>$($PhysicalDisk.FriendlyName)</td>"
        Add-Content -Path $ExportLog -Value "<td class=$ComputerClass>$($PhysicalDisk.StoragePoolFriendlyName)</td>"

        If ($PhysicalDisk.HealthStatus -notlike "Healthy"){
            $Class = $TDError
        }
        Else {
            $Class = $TDOK
        }
        Add-Content -Path $ExportLog -Value "<td class=$Class>$($PhysicalDisk.HealthStatus)</td>"

         If ($PhysicalDisk.OperationalStatus -notlike "OK"){
            $Class = $TDError
        }
        Else {
            $Class = $TDOK
        }

        Add-Content -Path $ExportLog -Value "<td class=$Class>$($PhysicalDisk.OperationalStatus)</td>"
        Add-Content -Path $ExportLog -Value "<td>$($PhysicalDisk.FirmwareVersion)</td>"
        Add-Content -Path $ExportLog -Value "<td>$($PhysicalDisk.Model)</td>"
        Add-Content -Path $ExportLog -Value "<td>$($PhysicalDisk.SerialNumber)</td>"
        Add-Content -Path $ExportLog -Value "<td>$($PhysicalDisk.MediaType)</td>"
        Add-Content -Path $ExportLog -Value "<td>$($PhysicalDisk.BusType)</td>"
        if ($($PhysicalDisk.Usage) -like "Journal"){
            Add-Content -Path $ExportLog -Value "<td>Cache<br><Span class=$AdvertMessage>Journal</Span></td>"   
        }
        Elseif ($($PhysicalDisk.Usage) -like "Auto-Select"){
            Add-Content -Path $ExportLog -Value "<td>Capacity<br><Span class=$AdvertMessage>Auto-Select</Span></td>"  
        }
        Else {
            Add-Content -Path $ExportLog -Value "<td>$($PhysicalDisk.Usage)</td>"  
        }
        
        Add-Content -Path $ExportLog -Value "<td><span class=$ValueClass>$([math]::round($PhysicalDisk.Size/1TB, 2))</span><span class=$UnitClass>TB</span></td>"
        Add-Content -Path $ExportLog -Value "<td><span class=$ValueClass>$([math]::round($PhysicalDisk.AllocatedSize/1TB, 2))</span><span class=$UnitClass>TB</span></td>"
        Add-Content -Path $ExportLog -Value "<td><span class=$ValueClass>$([math]::round(($PhysicalDisk.Size - $PhysicalDisk.AllocatedSize)/1TB, 2))</span><span class=$UnitClass>TB</span></td>"
        Add-Content -Path $ExportLog -Value "</tr>"
    }

    Add-Content -Path $ExportLog -Value "</table>"

    # Export SMB MultiChannel information
    Foreach ($VMHost in $VMHosts){
        $VMHostConnection = $VMHostSMBMultiChannel |? VMHost -like $VMHost.Name
        Add-Content -Path $ExportLog -Value "<H3>SMB MultiChannel SBL connection for $($VMHost.Name)</H3>"
        Add-Content -Path $ExportLog -Value "<table Class=$TableClass>"
        Add-Content -Path $ExportLog -Value '<tr>'
        Add-Content -Path $ExportLog -Value '<th>Client IP Address</th>'
        Add-Content -Path $ExportLog -Value '<th>Client NIC name</th>'
        Add-Content -Path $ExportLog -Value '<th>Client RSS Capable</th>'
        Add-Content -Path $ExportLog -Value '<th>Client RDMA capable</th>'
        Add-Content -Path $ExportLog -Value '<th>Server IP Address</th>'
        Add-Content -Path $ExportLog -Value '<th>Server NIC index</th>'
        Add-Content -Path $ExportLog -Value '<th>Server RSS Capable</th>'
        Add-Content -Path $ExportLog -Value '<th>Server RDMA Capable</th>'
        Add-Content -Path $ExportLog -Value '</tr>'

        Foreach ($SBLConnection in ($VMHostConnection |? ConnectionType -like "SBL")){
            Add-Content -Path $ExportLog -Value "<tr>"
            Add-Content -Path $ExportLog -Value "<td>$($SBLConnection.ClientIP)</td>"
            Add-Content -Path $ExportLog -Value "<td>$($SBLConnection.ClientNIC)</td>"
            Add-Content -Path $ExportLog -Value "<td>$($SBLConnection.ClientRSS)</td>"
            Add-Content -Path $ExportLog -Value "<td>$($SBLConnection.ClientRDMA)</td>"
            Add-Content -Path $ExportLog -Value "<td>$($SBLConnection.ServerIP)</td>"
            Add-Content -Path $ExportLog -Value "<td>$($SBLConnection.ServerNIC)</td>"
            Add-Content -Path $ExportLog -Value "<td>$($SBLConnection.ServerRSS)</td>"
            Add-Content -Path $ExportLog -Value "<td>$($SBLConnection.ServerRDMA)</td>"
            Add-Content -Path $ExportLog -Value "</tr>"  
         
        
        }
        Add-Content -Path $ExportLog -Value "</table>"
        Add-Content -Path $ExportLog -Value "<H3>SMB MultiChannel CSV connection for $($VMHost.Name)</H3>"
        Add-Content -Path $ExportLog -Value "<table Class=$TableClass>"
        Add-Content -Path $ExportLog -Value '<tr>'
        Add-Content -Path $ExportLog -Value '<th>Client IP Address</th>'
        Add-Content -Path $ExportLog -Value '<th>Client NIC name</th>'
        Add-Content -Path $ExportLog -Value '<th>Client RSS Capable</th>'
        Add-Content -Path $ExportLog -Value '<th>Client RDMA capable</th>'
        Add-Content -Path $ExportLog -Value '<th>Server IP Address</th>'
        Add-Content -Path $ExportLog -Value '<th>Server NIC index</th>'
        Add-Content -Path $ExportLog -Value '<th>Server RSS Capable</th>'
        Add-Content -Path $ExportLog -Value '<th>Server RDMA Capable</th>'
        Add-Content -Path $ExportLog -Value '</tr>'
  
        Foreach ($CSVConnection in ($VMHostConnection |? ConnectionType -like "CSV")){
            Add-Content -Path $ExportLog -Value "<tr>"
            Add-Content -Path $ExportLog -Value "<td>$($CSVConnection.ClientIP)</td>"
            Add-Content -Path $ExportLog -Value "<td>$($CSVConnection.ClientNIC)</td>"
            Add-Content -Path $ExportLog -Value "<td>$($CSVConnection.ClientRSS)</td>"
            Add-Content -Path $ExportLog -Value "<td>$($CSVConnection.ClientRDMA)</td>"
            Add-Content -Path $ExportLog -Value "<td>$($CSVConnection.ServerIP)</td>"
            Add-Content -Path $ExportLog -Value "<td>$($CSVConnection.ServerNIC)</td>"
            Add-Content -Path $ExportLog -Value "<td>$($CSVConnection.ServerRSS)</td>"
            Add-Content -Path $ExportLog -Value "<td>$($CSVConnection.ServerRDMA)</td>"
            Add-Content -Path $ExportLog -Value "</tr>"  
         
        
        }
        Add-Content -Path $ExportLog -Value "</table>" 
    }
}

# Add HTML footer (closing body and html)
Add-Content -Path $ExportLog -Value $HTMLEnding

Write-Host "You can find the HTML File here: $ExportLog" -ForegroundColor Green -BackgroundColor Black



#Generate the output file
#Write-Verbose "Writing Output to File $OutPutFile"
#$output | Out-File $OutPutFile -Force
$emailbody = get-content $ExportLog -Raw


                            $Username ="apikey"

                            $Password = ConvertTo-SecureString "<SENDGRIDAPIKEYPASSCODE>" -AsPlainText -Force

                            $credential = New-Object System.Management.Automation.PSCredential $Username, $Password

                            $SMTPServer = "smtp.sendgrid.net"

                            $EmailFrom = "No-Reply-S2D@company.com"

                            #$EmailTo = "helpdesk@company.com"

                            $Subject = "S2D Daily Report $($Clustername)"

                            $EmailTo = @('admin@company.com','admin1@company.com')

                            #Mail the Report
                            #If ($MailTo -and $MailFrom -and $MailServer)
                            #Fore Mail to go with Hard Coded Parameters for now
                              #  Foreach ($Email in $Emailto)
                           # {
                                Send-MailMessage -From $EmailFrom -To $EmailTo -SmtpServer $SMTPServer -Credential $credential -Port 587 -Subject $Subject -Encoding UTF8 -BodyAsHtml -Body $EmailBody

                             #   }