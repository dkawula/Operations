$startIP = 31
$endIP = 67
$startStudentNumber = 24

for ($i = $startIP; $i -le $endIP; $i++) {
    if ($i -eq 57) { continue }  # Skip IP 192.168.200.57

    $ip = "192.168.200.$i"
    $newComputerName = "Student$startStudentNumber"

    Invoke-Command -ComputerName $ip -ScriptBlock {
        param ($newName)
        Rename-Computer -NewName $newName -Restart -Force -Verbose
    } -ArgumentList $newComputerName

    # Increment the student number for the next iteration
    $startStudentNumber++
}