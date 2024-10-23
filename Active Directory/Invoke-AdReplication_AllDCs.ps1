# Function to replicate and converge Active Directory replication across all domain controllers
function Invoke-ADReplication {
    # Get all Domain Controllers from the "Domain Controllers" OU
    $domainControllers = Get-ADDomainController -Filter * | Select-Object -ExpandProperty HostName

    foreach ($dc in $domainControllers) {
        try {
            Write-Host "Running Replication on $dc..." -ForegroundColor Yellow
            
            # Run the repadmin commands remotely via Invoke-Command
            Invoke-Command -ComputerName $dc -ScriptBlock {
                repadmin /kcc
                repadmin /syncall
                repadmin /syncall /e
                repadmin /syncall /e /P
            }

            Write-Host "Replication completed for $dc" -ForegroundColor Green
        } catch {
            Write-Host "Failed to run replication on $dc. Error: $_" -ForegroundColor Red
        }
    }
}

# Run the function
Invoke-ADReplication
