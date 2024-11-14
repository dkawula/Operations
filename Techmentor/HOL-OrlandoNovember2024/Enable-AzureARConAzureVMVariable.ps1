#Enable Azure Arc Install Variable on Azure Lab VM's
#This script will prime the lab VM's so that students can possibly install Azure Arc
#Dave Kawula -MVP


for ($i = 11; $i -le 67; $i++) {
    $ip = "192.168.200.$i"
    Invoke-Command -ComputerName $ip -ScriptBlock {
        [System.Environment]::SetEnvironmentVariable("MSFT_ARC_TEST", 'true', [System.EnvironmentVariableTarget]::Machine)
    }
}