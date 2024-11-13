# Install the Microsoft Graph PowerShell module if not already installed
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
    Install-Module Microsoft.Graph -Scope CurrentUser -Force
}

# Connect to Microsoft Graph with Application.ReadWrite.All permission to retrieve and delete applications
Connect-MgGraph -Scopes "Application.ReadWrite.All"


# Retrieve all application registrations that match the display name "windowsadmin*"
$applications = Get-MgApplication -All | Where-Object { $_.DisplayName -like "windowsadmin*" }
$applications

# Display applications found for confirmation
if ($applications) {
    Write-Output "Found applications with display names matching 'windowsadmin*':"
    $applications | ForEach-Object { Write-Output "Name: $($_.DisplayName), App ID: $($_.AppId), Object ID: $($_.Id)" }
    
    # Confirm deletion
    $confirmation = Read-Host "Do you want to delete these applications? Type 'Y' to confirm"

    if ($confirmation -eq 'Y') {
        # Remove each application that matches the filter
        foreach ($app in $applications) {
            Write-Output "Removing application: $($app.DisplayName)"
            Remove-MgApplication -ApplicationId $app.Id -Verbose
        }
    } else {
        Write-Output "Deletion canceled."
    }
} else {
    Write-Output "No applications found with display names matching 'windowsadmin*'."
}

# Disconnect from Microsoft Graph
Disconnect-MgGraph
