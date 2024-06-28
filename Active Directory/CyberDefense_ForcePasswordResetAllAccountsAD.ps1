# Import the Active Directory module
Import-Module ActiveDirectory

# Define the new password
$newPassword = "<BLAH>"

# Search for all users in the domain
$users = Get-ADUser -Filter * -Properties SamAccountName

# Loop through each user and reset their password
foreach ($user in $users) {
    try {
        # Reset the password
        Set-ADAccountPassword -Identity $user.SamAccountName -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $newPassword -Force)
        Write-Host "Password reset for user: $($user.SamAccountName)" -ForegroundColor Green
    } catch {
        Write-Host "Failed to reset password for user: $($user.SamAccountName). Error: $_" -ForegroundColor Red
    }
}
