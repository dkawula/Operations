# Fix  NPCAP errors in Defender Identity during reinstallation
#First Stop the Azure Identity sensor servucies and updater
#First Uninstall NCPAP

Stop-Service -Name AATPSensorUpdater -Force; Stop-Service -Name AATPSensor -Force
set-location -Path 'C:\post-install\Azure ATP Sensor Setup\NPCAP'
cmd /c "npcap-1.00-oem.exe /loopback_support=no /winpcap_mode=yes /admin_only=no"

#Can use this for silent install
cmd /c "npcap-1.00-oem.exe /loopback_support=no /winpcap_mode=yes /admin_only=no /S"



Start-Service -Name AATPSensorUpdater; Start-Service -Name AATPSensor