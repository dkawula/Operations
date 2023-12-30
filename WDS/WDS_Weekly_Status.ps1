# Report information
$companyName = "Corporate IT"
$reportAuthor = "Dave Kawula-MVP"

#Import AD Module
Import-Module ActiveDirectory
# Function to check WDS status on a remote server
function Get-WDSStatus {
    param (
        [string]$computerName
    )

    $wdsStatus = Get-Service -ComputerName $computerName -Name "WDSServer" -ErrorAction SilentlyContinue

    if ($wdsStatus -ne $null) {
        return $wdsStatus.Status
    } else {
        return "Not Installed"
    }
}

# Query Active Directory for a list of servers
$servers = Get-ADComputer -Filter {OperatingSystem -like "Windows Server*"} | Select-Object -ExpandProperty Name
$Servers

# Create an array to store the results
$results = @()

# Iterate through each server and check WDS status
foreach ($server in $servers) {
    $wdsStatus = Get-WDSStatus -computerName $server
    $result = [PSCustomObject]@{
        ServerName = $server
        WDSStatus = $wdsStatus
    }
    $results += $result
}

# Display the results
$results | Format-Table -AutoSize

# Export the results to a CSV file
#$results | Export-Csv -Path "WDS_Status_Report.csv" -NoTypeInformation


# Generate HTML content
$htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <style>
        body {
            background-color: #f2f2f2; /* Light Grey */
        }
        table {
            border-collapse: collapse;
            width: 50%;
        }
        th, td {
            border: 1px solid black;
            padding: 8px;
            text-align: left;
        }
        th {
            background-color: #3498db; /* Blue */
            color: white;
        }
        .Running {
            color: red;
        }
        .Stopped {
            color: black;
        }
        .NotInstalled {
            color: green;
        }
    </style>
</head>
<body>
    <h2>Windows Deployment Services (WDS) Status Report</h2>
    <p>Company Name: $companyName</p>
    <p>Report Author: $reportAuthor</p>
    <p>Generated on: $(Get-Date)</p>
    <table>
        <tr>
            <th>Server Name</th>
            <th>WDS Status</th>
        </tr>
"@

foreach ($result in $results) {
    $statusColor = switch ($result.WDSStatus) {
        "Running" { "Running" }
        "Stopped" { "Stopped" }
        "Not Installed" { "NotInstalled" }
        default { "" }
    }

    $htmlContent += @"
        <tr>
            <td>$($result.ServerName)</td>
            <td class="$statusColor">$($result.WDSStatus)</td>
        </tr>
"@
}

$htmlContent += @"
    </table>
</body>
</html>
"@

# Save the HTML content to a file
$htmlFile = "C:\Post-Install\093-WDSWeeklyReport\WDS_Status_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
$htmlContent | Out-File -FilePath $htmlFile


#Generate the output file
#Write-Verbose "Writing Output to File $OutPutFile"
#$output | Out-File $OutPutFile -Force
$emailbody = get-content $htmlfile -Raw


                            $Username ="<USERNAME>"

                            $Password = "<Password>"

                            $credential = New-Object System.Management.Automation.PSCredential $Username, $Password

                            $SMTPServer = "smtp.sendgrid.net"

                            $EmailFrom = "no_reply@blah.com"

                           
                            $Subject = "Weekly WDS Status Report "

                            $EmailTo = @('blah@blah.com','blahblah@blah.com')

                            #Mail the Report
                            #If ($MailTo -and $MailFrom -and $MailServer)
                            #Fore Mail to go with Hard Coded Parameters for now
                              #  Foreach ($Email in $Emailto)
                           # {
                                Send-MailMessage -From $EmailFrom -To $EmailTo -SmtpServer $SMTPServer -Credential $credential -Port 587 -Subject $Subject -Encoding UTF8 -BodyAsHtml -Body $EmailBody

                             #   }
