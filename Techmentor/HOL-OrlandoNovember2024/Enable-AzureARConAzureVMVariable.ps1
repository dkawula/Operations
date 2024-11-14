#Enable Azure Arc Install Variable on Azure Lab VM's
#This script will prime the lab VM's so that students can possibly install Azure Arc
#Dave Kawula -MVP


# Define the range of student names
$studentNames = 1..60 | ForEach-Object { "Student{0:D2}" -f $_ }

# Loop through each student name and set the environment variable
foreach ($student in $studentNames) {
    Invoke-Command -ComputerName $student -ScriptBlock {
        [System.Environment]::SetEnvironmentVariable("MSFT_ARC_TEST", 'true', [System.EnvironmentVariableTarget]::Machine)
    } 
}