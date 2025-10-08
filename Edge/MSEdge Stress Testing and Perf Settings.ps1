$regKeys = @(
    # Mandatory Path Only
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "HardwareAccelerationModeEnabled"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "BackgroundModeEnabled"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "SleepingTabsEnabled"; Value = 1 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "SleepingTabsTimeout"; Value = 60 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "RestoreOnStartup"; Value = 5 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "TotalMemoryLimitMb"; Value = 800 },

    # Recommended Path
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended"; Name = "BackgroundModeEnabled"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended"; Name = "SleepingTabsEnabled"; Value = 1 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended"; Name = "SleepingTabsTimeout"; Value = 60 }
)

foreach ($item in $regKeys) {
    # Create the key path if it doesn't exist
    if (-not (Test-Path $item.Path)) {
        New-Item -Path $item.Path -Force | Out-Null
    }

    # Create or update the registry value
    Set-ItemProperty -Path $item.Path -Name $item.Name -Value $item.Value -Type DWord
    Write-Host "Set $($item.Name) = $($item.Value) at $($item.Path)"
}

Write-Host "`nAll Microsoft Edge registry policies have been applied."

Stop-Process -Name msedge* -Force


#####Test the RAM Limit#####
##/////Open Task manager and watch MSEDGE\\\\####
#Pic something from the dialog below like a PDF that will open in your browser#
#Make sure your browser default for this app is set to Edge#
#I have it spawning 80 instances 10 ms apart so you can see it churning#
#If it works memory should hold at the value you are setting#

Add-Type -AssemblyName System.Windows.Forms

# Select any file (*.*)
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Filter = "All Files (*.*)|*.*"
$dialog.Title = "Select a file to open in Microsoft Edge"
$dialog.Multiselect = $false

if ($dialog.ShowDialog() -eq "OK") {
    $filePath = $dialog.FileName
    Write-Host "Selected file: $filePath"
} else {
    Write-Warning "No file selected. Exiting."
    exit
}

# Launch Edge 500 times asynchronously with slight delay
for ($i = 1; $i -le 80; $i++) {
    Start-Process "msedge.exe" -ArgumentList "`"$filePath`""
    Start-Sleep -Milliseconds 100
    Write-Host "Opened instance #$i"
}