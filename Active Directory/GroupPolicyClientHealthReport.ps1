function Get-ClientGPOReport {

param(
    [string] $computer = "localhost",
    [int]    $hours    = 5
    
)

#Get date relative to the number of hours you want to review
$hours = '5'
$computer = 'localhost'
$date = (Get-Date).Addhours(-$($hours))


#load the name of the Winevent log corresponding to Group Policy
$loggpo= "Microsoft-Windows-GroupPolicy/Operational"

$GroupPolicyClientEvents = Get-WinEvent -FilterHashtable @{ LogName = $loggpo ; StartTime = $date } -ComputerName $computer -Oldest
$GroupPolicyClientEvents
   }


Install-Module -Name PSWriteHTML -AllowClobber -Force

Get-ClientGPOReport -hours 5 | Out-HtmlView