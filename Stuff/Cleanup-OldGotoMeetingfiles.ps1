#Remove Scrap Goto Meeting Files

Remove-Item –path C:\users\DKTCLAPTOP\Documents\original\ -include *.g2m –recurse

#Remove all of the older installer files that Goto Meeting Leaves Behind 60 days or older

Get-Childitem "C:\users\DKTCLAPTOP\AppData\local\GoToMeeting" | Where {$_.CreationTime -lt (get-date).adddays(-45)} | Remove-Item -Recurse