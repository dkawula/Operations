asnp "VeeamPSSnapIn" -ErrorAction SilentlyContinue

$vbwans = Get-VBRWANAccelerator
$vbwans1 = $vbwans.name
$vbwans1

Foreach ($VBWAN in $vbwans1) {

TRY{
invoke-command -ComputerName $VBWAN {
Write-Host "Starting Veeam Services on:"$VBWAN
Get-Service -Name Veeam* | Start-Service -verbose

}
}

Catch {

"Error Contacting Server: $VBWAN"


}

}