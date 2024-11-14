#Rename Lab Computers
#This script will renname the lab computers and help with the Azure Hybrid and Azure Arc Labs
#Dave Kawula - MVP

# Define the starting IP and starting student number
$startIP = "192.168.200.11"
$endIP = "192.168.200.67"
$startStudentNumber = 1

# Convert IP address to an array of integers
function Convert-IPToArray($ipAddress) {
    return $ipAddress.Split(".") | ForEach-Object { [int]$_ }
}

# Convert array of integers back to IP address string
function Convert-ArrayToIP($ipArray) {
    return ($ipArray -join ".")
}

# Increment an IP address by 1
function Increment-IP($ipArray) {
    for ($i = 3; $i -ge 0; $i--) {
        if ($ipArray[$i] -lt 255) {
            $ipArray[$i]++
            break
        } else {
            $ipArray[$i] = 0
        }
    }
    return $ipArray
}

# Convert starting and ending IPs
$currentIPArray = Convert-IPToArray $startIP
$endIPArray = Convert-IPToArray $endIP

# Loop through each IP from start to end
$currentStudentNumber = $startStudentNumber

while ($true) {
    $currentIP = Convert-ArrayToIP $currentIPArray
    $newComputerName = "Student{0:D2}" -f $currentStudentNumber

    # Rename the computer
    Rename-Computer -ComputerName $currentIP -NewName $newComputerName -Restart -Force -verbose

    # Increment IP and student number
    $currentIPArray = Increment-IP $currentIPArray
    $currentStudentNumber++

    # Stop if we've reached the end IP
    if ($currentIPArray -eq $endIPArray) { break }
}
