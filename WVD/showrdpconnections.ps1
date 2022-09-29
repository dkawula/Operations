$properties = @(
@{n='TimeStamp';e={$_.TimeCreated}}
@{n='LocalUser';e={$_.UserID}}
@{n='Target RDP host';e={$_.Properties[1].Value}}
)
Get-WinEvent -FilterHashTable @{LogName='Microsoft-Windows-TerminalServices-RDPClient/Operational';ID='1102'} | Select-Object $properties