$altNames = @("TMPRINT01","TMPRINT01.Techmentor.com")
$hostName = hostname
New-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\Lsa -Name DisableLoopbackCheck -PropertyType DWord -Value 1
New-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0 -Name BackConnectionHostNames -PropertyType MultiString -Value $altNames
New-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\lanmanserver\parameters -Name OptionalNames -PropertyType MultiString -Value $altNames[0]
New-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\lanmanserver\parameters -Name DisableStrictNameChecking -PropertyType DWord -Value 1
New-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\lanmanserver\parameters -Name DnsOnWire -PropertyType DWord -Value 1
setspn -A host/$altNames[0] $hostname