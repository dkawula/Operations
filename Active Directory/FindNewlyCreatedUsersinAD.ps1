# Define the number of days to search for newly created users
$daysBack = 30 # Change this to the number of days you want to search for

# Get the current date and subtract the number of days to find new users
$startDate = (Get-Date).AddDays(-$daysBack)

# Import Active Directory module (if needed)
Import-Module ActiveDirectory

# Search for users created in the last X days
$newUsers = Get-ADUser -Filter {WhenCreated -gt $startDate} -Properties WhenCreated, DisplayName | 
    Select-Object DisplayName, SamAccountName, WhenCreated

# Display the results
$newUsers | Format-Table -AutoSize
$newusers