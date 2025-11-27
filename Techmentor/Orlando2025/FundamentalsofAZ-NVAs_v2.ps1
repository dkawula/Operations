<#
.SYNOPSIS
    Azure vWAN + FortiGate Design Wizard, Teaching Mode, and Troubleshooting Game

.DESCRIPTION
    Interactive PowerShell script that:
    - Collects Azure vWAN + VNet + NVA design inputs
    - Generates an ASCII architecture diagram
    - Builds suggested UDR mappings
    - Outputs a Fortinet policy skeleton
    - Produces design notes / assumptions
    - Teaching Mode: step-by-step build guide
    - Game Mode: gamified troubleshooting simulator
      * Basic Mode (Beginner)
      * Advanced Mode
      * PowerShell-only (no web UI)

.NOTES
    Run with PowerShell 7+ (pwsh)
#>

#region Helper Functions

function Read-NonEmpty {
    param(
        [Parameter(Mandatory=$true)][string]$Prompt
    )
    while ($true) {
        $value = Read-Host $Prompt
        if (-not [string]::IsNullOrWhiteSpace($value)) { return $value }
        Write-Host "  Value cannot be empty." -ForegroundColor Yellow
    }
}

function Read-YesNo {
    param(
        [Parameter(Mandatory=$true)][string]$Prompt,
        [bool]$Default = $false
    )

    $suffix = if ($Default) { "[Y/n]" } else { "[y/N]" }

    while ($true) {
        $input = Read-Host "$Prompt $suffix"
        if ([string]::IsNullOrWhiteSpace($input)) { return $Default }
        switch -Regex ($input.Trim()) {
            '^(y|yes)$' { return $true }
            '^(n|no)$'  { return $false }
            default     { Write-Host "  Please answer y or n." -ForegroundColor Yellow }
        }
    }
}

function Read-Choice {
    param(
        [Parameter(Mandatory=$true)][string]$Prompt,
        [Parameter(Mandatory=$true)][string[]]$Choices
    )

    Write-Host ""
    Write-Host $Prompt -ForegroundColor Cyan
    for ($i = 0; $i -lt $Choices.Count; $i++) {
        Write-Host ("  [{0}] {1}" -f ($i+1), $Choices[$i])
    }

    while ($true) {
        $raw = Read-Host ("Select option (1-{0})" -f $Choices.Count)
        if ([int]::TryParse($raw, [ref]$null)) {
            $idx = [int]$raw - 1
            if ($idx -ge 0 -and $idx -lt $Choices.Count) {
                return $Choices[$idx]
            }
        }
        Write-Host "  Invalid choice. Try again." -ForegroundColor Yellow
    }
}

function Draw-Separator {
    param([string]$Title = "")
    Write-Host ""
    Write-Host ("".PadLeft(80,'='))
    if ($Title) {
        Write-Host ("= {0}" -f $Title) -ForegroundColor Green
        Write-Host ("".PadLeft(80,'='))
    }
}

#endregion Helper Functions

#region Teaching Mode

function Invoke-TeachingMode {
    param(
        [Parameter(Mandatory)]
        $Design
    )

    Draw-Separator "Teaching Mode - Step-by-Step Build Guide"

    $steps = New-Object System.Collections.Generic.List[object]

    $steps.Add([pscustomobject]@{
        Step  = 1
        Title = 'Understand the High-Level Architecture'
        Body  = @"
vWAN hub provides the routing/control plane, Workload VNet hosts your apps,
and the FortiGate NVA is the inspection point for flows you select:
- VNet ↔ On-Prem
- VNet ↔ Internet
- VNet ↔ other VNets (if enabled)

The rest of the steps build this architecture in a controlled, auditable way.
"@
    })

    $steps.Add([pscustomobject]@{
        Step  = 2
        Title = 'Create and Connect the vWAN Hub'
        Body  = @"
1. Create vWAN hub '$($Design.VwanHubName)' in region '$($Design.Region)' with address space $($Design.VwanHubAddress).
2. Connect your ExpressRoute/VPN to this hub and make sure On-Prem prefixes
   ($(if($Design.OnPremPrefixes){$Design.OnPremPrefixes -join ', '}else{'<none specified>'})) are learned via BGP.
3. Validate effective routes in the hub to confirm On-Prem routes are present.
"@
    })

    $steps.Add([pscustomobject]@{
        Step  = 3
        Title = 'Create and Attach the Workload VNet'
        Body  = @"
1. Create Workload VNet '$($Design.WorkloadVnetName)' with address space $($Design.WorkloadVnetAddress).
2. Create subnets:
   - Apps: $($Design.WorkloadSubnetApp)
   - APIs: $($Design.WorkloadSubnetApi)
   - Data: $($Design.WorkloadSubnetData)
3. Create a VNet connection between this VNet and the vWAN hub.
4. Validate that a VM in Apps sees On-Prem prefixes via the hub.
"@
    })

    if ($Design.NvaPlacement -eq 'TransitVNet') {
        $steps.Add([pscustomobject]@{
            Step  = 4
            Title = 'Create Transit VNet and Deploy FortiGate'
            Body  = @"
1. Create Transit VNet '$($Design.TransitVnetName)' with $($Design.TransitVnetAddress).
2. Create Trusted, Untrusted and Mgmt subnets.
3. Deploy FortiGate with:
   - Trusted IP: $($Design.NvaTrustedIp)
   - Untrusted IP: $($Design.NvaUntrustedIp)
   - Mgmt IP: $($Design.NvaMgmtIp)
4. Place an internal Load Balancer with frontend IP $($Design.NvaLbIp) on the trusted side.
5. Connect the Transit VNet to the vWAN hub.
"@
        })

        $steps.Add([pscustomobject]@{
            Step  = 5
            Title = 'Peer Workload VNet with Transit VNet and Add UDRs'
            Body  = @"
1. Peer Workload VNet '$($Design.WorkloadVnetName)' with Transit VNet '$($Design.TransitVnetName)',
   enabling 'Allow forwarded traffic' on both sides and 'Use remote gateway'/'Allow gateway transit'
   as appropriate.
2. Create a Route Table (e.g., '$($Design.WorkloadVnetName)-UDR-Workload') and associate to Apps/APIs/Data.
3. Add routes for On-Prem prefixes and optionally 0.0.0.0/0 pointing to $($Design.NvaLbIp) as VirtualAppliance.
"@
        })
    }
    elseif ($Design.NvaPlacement -eq 'WorkloadVNet') {
        $steps.Add([pscustomobject]@{
            Step  = 4
            Title = 'Deploy FortiGate Inside Workload VNet and Add UDRs'
            Body  = @"
1. Create NVA subnet $($Design.NvaSubnetCidr) in '$($Design.WorkloadVnetName)'.
2. Deploy FortiGate with trusted IP $($Design.NvaTrustedIp) and untrusted IP $($Design.NvaUntrustedIp).
3. Place internal LB with frontend IP $($Design.NvaLbIp).
4. Apply UDRs on Apps/APIs/Data for On-Prem and/or 0.0.0.0/0 → $($Design.NvaLbIp).
"@
        })
    }
    else {
        $steps.Add([pscustomobject]@{
            Step  = 4
            Title = 'Configure vWAN Hub Integrated NVA and Routing Intent'
            Body  = @"
1. Deploy Fortinet NVA as a vWAN Hub integrated security solution.
2. Use routing intent to steer Internet, On-Prem, and/or inter-VNet flows through the NVA.
3. Attach '$($Design.WorkloadVnetName)' to the hub; no UDRs are required for N-S flows.
"@
        })
    }

    foreach ($s in $steps) {
        Draw-Separator ("Step {0}: {1}" -f $s.Step, $s.Title)
        Write-Host $s.Body
        Write-Host ""
        [void](Read-Host "Press ENTER to continue to the next step")
    }

    Write-Host ""
    Write-Host "Teaching Mode complete. You can scroll back through the steps as needed." -ForegroundColor Green
    Write-Host ""
}

#endregion Teaching Mode

#region Game Mode – Troubleshooting Simulator (Basic + Advanced)

function Invoke-VwanTroubleshootingGame {
    param(
        [Parameter(Mandatory)]
        $Design
    )

    Write-Host ""
    Write-Host "==============================================================" -ForegroundColor Yellow
    Write-Host "           Azure vWAN + NVA Troubleshooting Simulator"
    Write-Host "==============================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "You will be given a series of real-world troubleshooting missions." -ForegroundColor White
    Write-Host "Each mission is based on YOUR design choices (NVA placement, flows, etc.)." -ForegroundColor White
    Write-Host ""

    $modeChoice = Read-Choice -Prompt "Select Game Mode" -Choices @(
        "Basic (Beginner – core scenarios)",
        "Advanced (Deep-dive scenarios)"
    )

    $selectedMode = if ($modeChoice -like "Basic*") { "Basic" } else { "Advanced" }

    Write-Host ""
    Write-Host "Game Mode: $selectedMode" -ForegroundColor Cyan
    [void](Read-Host "Press ENTER to start the missions")

    # -----------------------------
    # Define all scenarios
    # -----------------------------
    $allScenarios = New-Object System.Collections.Generic.List[object]

    # Helper to add scenarios
    function Add-Scenario {
        param(
            [int]$Id,
            [string]$Title,
            [string[]]$AppliesTo,
            [string]$Mode,        # "Basic", "Advanced", or "Both"
            [string]$Problem,
            [string]$Question,
            [string[]]$Choices,
            [int]$Correct,
            [string]$Explanation
        )
        $allScenarios.Add([pscustomobject]@{
            Id          = $Id
            Title       = $Title
            AppliesTo   = $AppliesTo
            Mode        = $Mode
            Problem     = $Problem
            Question    = $Question
            Choices     = $Choices
            Correct     = $Correct
            Explanation = $Explanation
        })
    }

    # ========== BASIC SCENARIOS ==========

    Add-Scenario `
        -Id 1 `
        -Title "On-Prem cannot reach VM in Apps Subnet" `
        -AppliesTo @("TransitVNet","WorkloadVNet") `
        -Mode "Basic" `
        -Problem "HQ users cannot reach workloads in Apps subnet $($Design.WorkloadSubnetApp)." `
        -Question "What is the MOST likely cause, given your inline NVA design?" `
        -Choices @(
            "Missing UDR on Apps subnet for On-Prem prefixes → NVA LB",
            "Peering 'AllowForwardedTraffic' disabled, causing NVA to drop forwarded packets",
            "Asymmetric routing: On-Prem → Hub → Workload VNet bypasses NVA on return path",
            "FortiGate IPS signature blocking the traffic unexpectedly"
        ) `
        -Correct 3 `
        -Explanation @"
This is a classic asymmetric routing case.

Outbound:
  Apps → UDR → NVA → vWAN Hub → On-Prem

Inbound (broken):
  On-Prem → vWAN Hub → Workload VNet (direct, bypassing NVA)

Fix:
  - Ensure vWAN hub route tables or BGP on-prem side send return traffic via the NVA
  - Make NVA the effective next hop for VNet prefixes, not the direct hub→VNet path
"@

    Add-Scenario `
        -Id 2 `
        -Title "Apps VM cannot reach Internet" `
        -AppliesTo @("TransitVNet","WorkloadVNet") `
        -Mode "Basic" `
        -Problem "VMs in Apps subnet cannot browse the Internet or reach public endpoints." `
        -Question "What is the MOST likely first thing to check?" `
        -Choices @(
            "UDR for 0.0.0.0/0 on Apps subnet pointing to NVA LB IP",
            "Whether DNS is configured correctly on the VM NIC",
            "Whether Azure Firewall rules permit outbound HTTPS",
            "Whether the VM has a public IP"
        ) `
        -Correct 1 `
        -Explanation @"
In this pattern, outbound Internet should be steered to the NVA via UDR.

Fix:
  - Create/verify a UDR on Apps subnet:
      Prefix: 0.0.0.0/0
      Next hop type: VirtualAppliance
      Next hop IP: $($Design.NvaLbIp)
  - Then verify FortiGate default route + NAT for Internet.
"@

    Add-Scenario `
        -Id 3 `
        -Title "Traffic reaches NVA but not On-Prem" `
        -AppliesTo @("TransitVNet") `
        -Mode "Basic" `
        -Problem "Packets from Apps subnet reach the NVA in Transit VNet but never reach On-Prem." `
        -Question "What configuration is MOST likely missing?" `
        -Choices @(
            "Peering 'AllowForwardedTraffic' between Workload VNet and Transit VNet",
            "Peering 'UseRemoteGateway' between Workload VNet and Transit VNet",
            "NSG allowing SSH to FortiGate management interface",
            "UDR for On-Prem prefixes on the NVA subnet"
        ) `
        -Correct 1 `
        -Explanation @"
When AllowForwardedTraffic is disabled on peering, NVA can receive traffic but cannot forward it.

Fix:
  - On BOTH directions of peering:
      * Enable 'Allow forwarded traffic'
  - Re-test with traceroute / effective routes.
"@

    Add-Scenario `
        -Id 4 `
        -Title "DNS and Azure Storage suddenly stop working" `
        -AppliesTo @("TransitVNet","WorkloadVNet") `
        -Mode "Basic" `
        -Problem "After adding 0.0.0.0/0 UDRs, VMs cannot resolve DNS or access storage accounts." `
        -Question "What is the MOST likely cause?" `
        -Choices @(
            "UDR is hijacking Azure platform IP 168.63.129.16 and service traffic to NVA",
            "FortiGate SSL inspection is breaking TLS",
            "Subnet NSG denies outbound 443",
            "vWAN hub has lost BGP connectivity to On-Prem"
        ) `
        -Correct 1 `
        -Explanation @"
A default route to NVA can accidentally catch Azure platform traffic.

Fix:
  - Create specific UDRs for 168.63.129.16 and/or service tags (AzureStorage, AzureMonitor)
    pointing to 'Internet' or 'None' so they follow platform/system routing.
  - Ensure NVA allows DNS/HTTPS if you DO intentionally inspect these flows.
"@

    Add-Scenario `
        -Id 5 `
        -Title "Traffic bypasses Hub-integrated NVA" `
        -AppliesTo @("VwanHub") `
        -Mode "Basic" `
        -Problem "You expected traffic from '$($Design.WorkloadVnetName)' to be inspected, but FortiGate logs show no hits." `
        -Question "Where should you look first?" `
        -Choices @(
            "UDRs on the workload subnets",
            "vWAN routing intent configuration",
            "NSGs on the workload subnets",
            "Local hosts file on the VM"
        ) `
        -Correct 2 `
        -Explanation @"
With hub-integrated NVA, core steering is handled by routing intent.

Fix:
  - Ensure routing intent is enabled for the relevant category:
    * Internet, Private, or VNet-to-VNet
  - Ensure '$($Design.WorkloadVnetName)' is associated with the route table that uses this intent.
"@

    Add-Scenario `
        -Id 6 `
        -Title "LB backends Unhealthy → intermittent failures" `
        -AppliesTo @("TransitVNet","WorkloadVNet") `
        -Mode "Basic" `
        -Problem "Sometimes traffic passes, sometimes it fails. Load Balancer shows NVA backend as Unhealthy." `
        -Question "What is the MOST likely root cause?" `
        -Choices @(
            "NSG is blocking health probe from AzureLoadBalancer",
            "FortiGate CPU is at 100%",
            "vWAN hub changed its BGP ASN",
            "On-Prem firewall is blocking IPsec"
        ) `
        -Correct 1 `
        -Explanation @"
If NSG blocks probe, LB marks backend unhealthy and stops sending traffic.

Fix:
  - On the NVA subnet NSG, allow inbound from 'AzureLoadBalancer' service tag on the probe port.
"@

    Add-Scenario `
        -Id 7 `
        -Title "Apps cannot reach APIs subnet (internal east-west issue)" `
        -AppliesTo @("TransitVNet","WorkloadVNet") `
        -Mode "Basic" `
        -Problem "VMs in Apps subnet $($Design.WorkloadSubnetApp) cannot reach APIs subnet $($Design.WorkloadSubnetApi)." `
        -Question "What is the MOST likely cause?" `
        -Choices @(
            "Overly broad UDR like 10.0.0.0/8 → NVA catching intra-VNet traffic",
            "DNS record missing for API hostname",
            "vWAN route table not associated to the right connection",
            "FortiGate policy requires explicit object for APIs subnet"
        ) `
        -Correct 1 `
        -Explanation @"
UDRs should be scoped to On-Prem + Internet, not broad RFC1918 ranges.

Fix:
  - Remove overly broad UDRs.
  - Use precise On-Prem prefixes and 0.0.0.0/0 if inspecting Internet.
"@

    Add-Scenario `
        -Id 8 `
        -Title "On-Prem traffic not inspected as designed" `
        -AppliesTo @("TransitVNet","WorkloadVNet","VwanHub") `
        -Mode "Basic" `
        -Problem "You expected On-Prem ↔ VNet flows to traverse NVA, but there are no NVA logs." `
        -Question "What is a key design variable to check?" `
        -Choices @(
            "InspectOnPrem flag in design and corresponding UDRs / routing intent",
            "DNS suffix on workloads",
            "VM SKU size",
            "NSG default outbound rules"
        ) `
        -Correct 1 `
        -Explanation @"
If InspectOnPrem = $($Design.InspectOnPrem), the design may or may not steer On-Prem flows via NVA.

Fix:
  - Verify your own design choice (InspectOnPrem) matches implementation:
    * UDRs for On-Prem prefixes in Transit/Workload model
    * Routing intent config in hub-integrated model
"@

    Add-Scenario `
        -Id 9 `
        -Title "VNet cannot see On-Prem routes" `
        -AppliesTo @("TransitVNet","WorkloadVNet","VwanHub") `
        -Mode "Basic" `
        -Problem "Effective routes on a VM NIC in Apps subnet do not show On-Prem prefixes." `
        -Question "Where do you start troubleshooting?" `
        -Choices @(
            "Check vWAN hub route tables for proper propagate/associate settings",
            "Check DNS configuration on the VM",
            "Check local Windows firewall rules",
            "Check FortiGate IPS signatures"
        ) `
        -Correct 1 `
        -Explanation @"
All VNet spokes learn On-Prem prefixes via vWAN route tables.

Fix:
  - Validate that:
    * On-Prem connections propagate into the hub route table
    * The VNet connection is associated to that route table
"@

    Add-Scenario `
        -Id 10 `
        -Title "VM cannot reach NVA at all" `
        -AppliesTo @("TransitVNet","WorkloadVNet") `
        -Mode "Basic" `
        -Problem "Ping/traceroute from Apps VM never even reaches NVA trusted IP." `
        -Question "What is the MOST likely cause?" `
        -Choices @(
            "NSG on NVA/trusted subnet blocking inbound from workload subnets",
            "FortiGate default route missing",
            "Hub routing intent misconfigured",
            "Wrong region for vWAN hub"
        ) `
        -Correct 1 `
        -Explanation @"
First hop from VM to NVA is still VNet-local.

Fix:
  - Check NSGs on Apps subnet and NVA subnet:
    * Allow required ports from workload subnet to NVA trusted IP.
"@

    # ========== ADVANCED SCENARIOS ==========

    Add-Scenario `
        -Id 101 `
        -Title "Inter-VNET traffic bypasses NVA" `
        -AppliesTo @("TransitVNet","VwanHub") `
        -Mode "Advanced" `
        -Problem "Traffic between two spokes (VNet A and VNet B) is not logged on NVA, despite 'InspectInterVnet' being True." `
        -Question "What is the MOST likely cause?" `
        -Choices @(
            "vWAN route table used for VNet connections does not use the security/routing intent",
            "NSG on NVA denies spoke-to-spoke flows",
            "VMSS health probes targeting wrong port",
            "FortiGate license expired"
        ) `
        -Correct 1 `
        -Explanation @"
In vWAN, inter-VNET inspection is controlled by which route table is associated
and whether routing intent is configured for VNet-to-VNet.

Fix:
  - Confirm both spokes use the route table that directs inter-VNET traffic via NVA.
"@

    Add-Scenario `
        -Id 102 `
        -Title "BGP routes to On-Prem not visible in Hub" `
        -AppliesTo @("TransitVNet","WorkloadVNet","VwanHub") `
        -Mode "Advanced" `
        -Problem "On-Prem prefixes do not appear in the hub effective routes. BGP session is down." `
        -Question "Which troubleshooting step is MOST appropriate first?" `
        -Choices @(
            "Check IPsec/ER circuit status and BGP peer config",
            "Check VM DNS server settings",
            "Check FortiGate IPS logs",
            "Check NSG on Apps subnet"
        ) `
        -Correct 1 `
        -Explanation @"
If the hub doesn't see routes, the BGP session or underlying tunnel is likely down.

Fix:
  - Verify IPsec or ExpressRoute connectivity and BGP neighbor status on both ends.
"@

    Add-Scenario `
        -Id 103 `
        -Title "SNAT exhaustion on NVA for Internet flows" `
        -AppliesTo @("TransitVNet","WorkloadVNet") `
        -Mode "Advanced" `
        -Problem "Internet connections randomly fail; FortiGate shows many sessions stuck in half-open state." `
        -Question "What is the MOST likely root cause?" `
        -Choices @(
            "SNAT port exhaustion due to too few public/outbound IPs",
            "vWAN hub BGP misconfiguration",
            "Route table on Apps subnet missing default route",
            "DNS misconfiguration on On-Prem DCs"
        ) `
        -Correct 1 `
        -Explanation @"
When too many sessions share a single SNAT IP, ports run out and new connections fail.

Fix:
  - Add more outbound IPs / SNAT pools
  - Reduce long-lived idle sessions
"@

    Add-Scenario `
        -Id 104 `
        -Title "HA failover causes prolonged outage" `
        -AppliesTo @("TransitVNet","WorkloadVNet") `
        -Mode "Advanced" `
        -Problem "During FortiGate HA failover, traffic is blackholed for several minutes." `
        -Question "What configuration is MOST likely missing or incorrect?" `
        -Choices @(
            "LB health probes not tuned for fast failover",
            "vWAN hub using wrong ASN",
            "Peering between Transit and Workload VNets is not Global",
            "VMs do not have public IPs"
        ) `
        -Correct 1 `
        -Explanation @"
Fast failover depends on how quickly the LB marks one node unhealthy and shifts traffic.

Fix:
  - Tune health probe intervals and thresholds to achieve appropriate failover times.
"@

    Add-Scenario `
        -Id 105 `
        -Title "Platform agents cannot send logs to Azure Monitor" `
        -AppliesTo @("TransitVNet","WorkloadVNet") `
        -Mode "Advanced" `
        -Problem "Log Analytics / Defender agents on VMs cannot send telemetry after NVA enforcement." `
        -Question "What is the MOST likely cause?" `
        -Choices @(
            "UDRs are sending Azure Monitor endpoints through NVA without proper allow rules",
            "DNS suffix is wrong",
            "vWAN hub erred during provisioning",
            "On-Prem firewall blocked port 3389"
        ) `
        -Correct 1 `
        -Explanation @"
Azure Monitor endpoints may require specific outbound ports and domains.

Fix:
  - Add explicit NVA rules allowing outbound to Azure Monitor service tags/FQDNs
  - Or bypass those endpoints from NVA using service tag–based UDRs.
"@

    # -----------------------------
    # Filter scenarios by design + mode
    # -----------------------------
    $placement = $Design.NvaPlacement

    $filtered = $allScenarios |
        Where-Object {
            $_.AppliesTo -contains $placement -and
            ( $_.Mode -eq $selectedMode -or $_.Mode -eq 'Both' )
        }

    if (-not $filtered -or $filtered.Count -eq 0) {
        Write-Host ""
        Write-Host "No scenarios available for this combination of NVA placement and game mode." -ForegroundColor Yellow
        return
    }

    $maxMissions = if ($selectedMode -eq 'Basic') { 7 } else { 10 }
    $missionCount = [Math]::Min($maxMissions, $filtered.Count)
    $selectedScenarios = $filtered | Get-Random -Count $missionCount

    $score = 0
    $missionNumber = 1

    foreach ($scenario in $selectedScenarios) {
        Write-Host ""
        Write-Host "--------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host " Mission ${missionNumber}: $($scenario.Title)" -ForegroundColor Green
        Write-Host "--------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host ""
        Write-Host $scenario.Problem -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Question: $($scenario.Question)"
        Write-Host ""

        if (-not $scenario.Choices -or $scenario.Choices.Count -eq 0) {
            Write-Host "Scenario is misconfigured (no choices). Skipping..." -ForegroundColor Red
            continue
        }

        for ($i=0; $i -lt $scenario.Choices.Count; $i++) {
            Write-Host "  [$($i+1)] $($scenario.Choices[$i])"
        }

        Write-Host ""
        $answer = Read-Host "Your answer (1-$($scenario.Choices.Count))"
        $intAnswer = 0
        [void][int]::TryParse($answer, [ref]$intAnswer)

        if ($intAnswer -eq $scenario.Correct) {
            Write-Host ""
            Write-Host "✔ Correct!" -ForegroundColor Green
            $score++
        } else {
            Write-Host ""
            Write-Host "✘ Incorrect." -ForegroundColor Red
            Write-Host "Correct answer: $($scenario.Correct) → $($scenario.Choices[$scenario.Correct-1])"
        }

        Write-Host ""
        Write-Host "Explanation:" -ForegroundColor White
        Write-Host $scenario.Explanation -ForegroundColor DarkCyan

        $missionNumber++
        [void](Read-Host "Press ENTER for next mission")
    }

    Write-Host ""
    Write-Host "==============================================================" -ForegroundColor Yellow
    Write-Host "                        GAME OVER"
    Write-Host "==============================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Your Score: $score / $($missionCount)" -ForegroundColor White
    Write-Host ""

    if ($score -eq $missionCount) {
        Write-Host "Perfect Score! You mastered this vWAN design!" -ForegroundColor Green
    } elseif ($score -ge ($missionCount * 0.7)) {
        Write-Host "Great job — solid understanding!" -ForegroundColor Green
    } else {
        Write-Host "Keep practicing — re-run Teaching Mode for deeper understanding." -ForegroundColor Yellow
    }

    Write-Host ""
}

#endregion Game Mode

#region Main Script – Design Wizard

Draw-Separator "Azure vWAN + NVA ASCII Design Wizard"

$design = [ordered]@{}

$design.EnvironmentName = Read-NonEmpty "Environment name (e.g., Prod-HQ, BF-Primary)"
$design.Region          = Read-NonEmpty "Azure region (e.g., canadacentral, eastus2)"

$TeachingModeEnabled    = Read-YesNo "Enable Teaching Mode (step-by-step explanations)?" $true

Draw-Separator "Virtual WAN Hub"

$design.VwanHubName     = Read-NonEmpty "vWAN Hub name"
$design.VwanHubAddress  = Read-NonEmpty "vWAN Hub address space (CIDR, e.g., 10.100.0.0/23)"

$design.VwanHasER       = Read-YesNo "Is the vWAN hub connected to ExpressRoute/On-Prem via BGP?" $true
$design.VwanHasBranches = Read-YesNo "Does the vWAN hub connect to branches/SD-WAN devices?" $true

Draw-Separator "Workload VNet (Primary)"

$design.WorkloadVnetName       = Read-NonEmpty "Primary workload VNet name (e.g., Prod-VNet1)"
$design.WorkloadVnetAddress    = Read-NonEmpty "VNet address space (CIDR, e.g., 10.10.0.0/16)"
$design.WorkloadSubnetApp      = Read-NonEmpty "Workload subnet (Apps) CIDR (e.g., 10.10.1.0/24)"
$design.WorkloadSubnetApi      = Read-NonEmpty "Workload subnet (APIs) CIDR (e.g., 10.10.2.0/24)"
$design.WorkloadSubnetData     = Read-NonEmpty "Workload subnet (Data) CIDR (e.g., 10.10.3.0/24)"

Draw-Separator "NVA Placement"

$nvaPlacementChoice = Read-Choice -Prompt "Where will the Fortinet NVA live?" -Choices @(
    "Transit VNet (recommended hub/spoke security)",
    "Inside existing workload VNet (Prod-VNet1)",
    "Directly in Azure vWAN Hub (integrated NVA)"
)

switch ($nvaPlacementChoice) {
    "Transit VNet (recommended hub/spoke security)" {
        $design.NvaPlacement = "TransitVNet"
        
        Draw-Separator "Transit VNet Details"

        $design.TransitVnetName       = Read-NonEmpty "Transit VNet name (e.g., Transit-Security-VNet)"
        $design.TransitVnetAddress    = Read-NonEmpty "Transit VNet address space (e.g., 10.20.0.0/24)"
        $design.TransitSubnetTrust    = Read-NonEmpty "Trusted subnet CIDR (e.g., 10.20.0.0/27)"
        $design.TransitSubnetUntrust  = Read-NonEmpty "Untrusted subnet CIDR (e.g., 10.20.0.32/27)"
        $design.TransitSubnetMgmt     = Read-NonEmpty "Mgmt subnet CIDR (e.g., 10.20.0.64/27)"
        $design.NvaTrustedIp          = Read-NonEmpty "FortiGate trusted NIC IP (inside Transit Trusted subnet, e.g., 10.20.0.4)"
        $design.NvaUntrustedIp        = Read-NonEmpty "FortiGate untrusted NIC IP (e.g., to vWAN, 10.20.0.36)"
        $design.NvaMgmtIp             = Read-NonEmpty "FortiGate management IP (e.g., 10.20.0.68)"
        $design.NvaLbIp               = Read-NonEmpty "Azure Load Balancer frontend IP for NVA (trusted side, used as UDR next hop)"
    }
    "Inside existing workload VNet (Prod-VNet1)" {
        $design.NvaPlacement = "WorkloadVNet"

        Draw-Separator "NVA Inside Workload VNet Details"

        $design.NvaSubnetCidr = Read-NonEmpty "NVA subnet CIDR inside workload VNet (e.g., 10.10.10.0/27)"
        $design.NvaTrustedIp  = Read-NonEmpty "FortiGate trusted NIC IP (workload side)"
        $design.NvaUntrustedIp= Read-NonEmpty "FortiGate untrusted NIC IP (towards hub/ER)"
        $design.NvaMgmtIp     = Read-NonEmpty "FortiGate management IP (e.g., 10.10.10.10)"
        $design.NvaLbIp       = Read-NonEmpty "Azure Load Balancer frontend IP for NVA (UDR next hop)"
    }
    "Directly in Azure vWAN Hub (integrated NVA)" {
        $design.NvaPlacement = "VwanHub"

        Draw-Separator "NVA Inside vWAN Hub Details"

        $design.NvaHubName   = Read-NonEmpty "FortiGate Hub NVA instance name (logical)"
        $design.NvaHubSubnet = "Managed by vWAN Hub (no direct VNet CIDR)"
        $design.NvaMgmtIp    = "Managed / internal to vWAN hub"
        $design.NvaLbIp      = "Managed / abstracted by vWAN routing intent"
    }
}

Draw-Separator "Traffic Flows to Inspect via NVA"

$design.InspectInternet   = Read-YesNo "Should traffic to Internet be inspected by NVA?" $true
$design.InspectOnPrem     = Read-YesNo "Should traffic to On-Prem/HQ be inspected by NVA?" $true
$design.InspectInterVnet  = Read-YesNo "Should traffic between VNets (spoke-to-spoke via hub) be inspected?" $false

$design.OnPremPrefixes = @()
if ($design.InspectOnPrem) {
    Write-Host ""
    Write-Host "Enter On-Prem/HQ CIDR prefixes that should flow through the NVA." -ForegroundColor Cyan
    Write-Host "  Example: 10.0.0.0/8, 172.16.0.0/12. Leave blank when done." -ForegroundColor DarkGray
    while ($true) {
        $pfx = Read-Host "Add On-Prem prefix (or press ENTER to finish)"
        if ([string]::IsNullOrWhiteSpace($pfx)) { break }
        $design.OnPremPrefixes += $pfx
    }
}

#endregion Main input collection

#region Build UDR Recommendations

$udrList = New-Object System.Collections.Generic.List[object]

function Add-UdrEntry {
    param(
        [string]$RouteTable,
        [string]$Subnet,
        [string]$Prefix,
        [string]$NextHopType,
        [string]$NextHop
    )
    $obj = [pscustomobject]@{
        RouteTable   = $RouteTable
        Subnet       = $Subnet
        Prefix       = $Prefix
        NextHopType  = $NextHopType
        NextHop      = $NextHop
    }
    $script:udrList.Add($obj)
}

$appSubnetName = "Apps"
$apiSubnetName = "APIs"
$dataSubnetName = "Data"

$routeTableName = "{0}-UDR-Workload" -f $design.WorkloadVnetName

if ($design.NvaPlacement -ne "VwanHub") {
    $workloadSubnets = @(
        @{ Name = $appSubnetName; Cidr = $design.WorkloadSubnetApp  },
        @{ Name = $apiSubnetName; Cidr = $design.WorkloadSubnetApi  },
        @{ Name = $dataSubnetName; Cidr = $design.WorkloadSubnetData }
    )

    foreach ($ws in $workloadSubnets) {
        $subName = $ws.Name

        if ($design.InspectOnPrem -and $design.OnPremPrefixes.Count -gt 0) {
            foreach ($pfx in $design.OnPremPrefixes) {
                Add-UdrEntry -RouteTable $routeTableName `
                    -Subnet $subName `
                    -Prefix $pfx `
                    -NextHopType "VirtualAppliance" `
                    -NextHop $design.NvaLbIp
            }
        }

        if ($design.InspectInternet) {
            Add-UdrEntry -RouteTable $routeTableName `
                -Subnet $subName `
                -Prefix "0.0.0.0/0" `
                -NextHopType "VirtualAppliance" `
                -NextHop $design.NvaLbIp
        }
    }
}

#endregion Build UDR Recommendations

#region ASCII Diagram

function Render-AsciiDiagram {
    param($design)

    Draw-Separator "ASCII Architecture Diagram"

    $onPremTxt = if($design.OnPremPrefixes.Count){$design.OnPremPrefixes -join ", "}else{"<none specified>"}

    if ($design.NvaPlacement -eq "TransitVNet") {

@"
Environment: $($design.EnvironmentName)  |  Region: $($design.Region)

On-Prem / HQ
  CIDRs: $onPremTxt
  (ExpressRoute/VPN, BGP into vWAN Hub)
  
         ┌───────────────────────────────────────────────┐
         │              On-Prem / HQ                     │
         └───────────────────────────────────────────────┘
                          ▲
                          │ BGP
                          │
       ┌──────────────────────────────────────────────────────────┐
       │                 Azure vWAN Hub: $($design.VwanHubName)             │
       │   Address Space: $($design.VwanHubAddress)                         │
       │   - ER/VPN: $($design.VwanHasER)                                   │
       │   - Branches: $($design.VwanHasBranches)                           │
       └───────────────▲───────────────────────────────▲───────────────────┘
                       │                               │
                       │                               │ (Future spokes)
                       │
       ┌──────────────────────────────────────────────────────────┐
       │                Transit VNet: $($design.TransitVnetName)             │
       │   Address Space: $($design.TransitVnetAddress)                      │
       │                                                                      │
       │   ┌────────────────────────────────────────────────┐                 │
       │   │           FortiGate NVA (HA via LB)           │                 │
       │   │   Trusted Subnet : $($design.TransitSubnetTrust)                │
       │   │      - NVA Trust IP : $($design.NvaTrustedIp)                    │
       │   │      - LB Frontend  : $($design.NvaLbIp) (UDR next hop)         │
       │   │   Untrusted Subnet: $($design.TransitSubnetUntrust)             │
       │   │      - NVA Untrust IP: $($design.NvaUntrustedIp)                 │
       │   │   Mgmt Subnet    : $($design.TransitSubnetMgmt)                 │
       │   │      - NVA Mgmt IP : $($design.NvaMgmtIp)                        │
       │   └────────────────────────────────────────────────┘                 │
       └───────────────────▲──────────────────────────────────────────────────┘
                           │
                           │ Peering (Use Remote GW, Allow Forwarded Traffic)
                           │
       ┌──────────────────────────────────────────────────────────┐
       │              Workload VNet: $($design.WorkloadVnetName)             │
       │   Address Space: $($design.WorkloadVnetAddress)                     │
       │                                                                      │
       │   Subnet: Apps  ($($design.WorkloadSubnetApp))                      │
       │   Subnet: APIs  ($($design.WorkloadSubnetApi))                      │
       │   Subnet: Data  ($($design.WorkloadSubnetData))                     │
       └──────────────────────────────────────────────────────────┘
"@

    } elseif ($design.NvaPlacement -eq "WorkloadVNet") {

@"
Environment: $($design.EnvironmentName)  |  Region: $($design.Region)

NVA Placement: Inside Workload VNet ($($design.WorkloadVnetName))

         ┌───────────────────────────────────────────────┐
         │              On-Prem / HQ                     │
         └───────────────────────────────────────────────┘
                          ▲
                          │ BGP
                          │
       ┌──────────────────────────────────────────────────────────┐
       │                 Azure vWAN Hub: $($design.VwanHubName)             │
       │   Address Space: $($design.VwanHubAddress)                         │
       └───────────────▲──────────────────────────────────────────┘
                       │
                       │ VNet connection (Workload VNet)
                       │
       ┌──────────────────────────────────────────────────────────┐
       │              Workload VNet: $($design.WorkloadVnetName)             │
       │   Address Space: $($design.WorkloadVnetAddress)                     │
       │                                                                      │
       │   Subnet: NVA   ($($design.NvaSubnetCidr))                           │
       │       - NVA Trust IP : $($design.NvaTrustedIp)                       │
       │       - NVA Untrust IP: $($design.NvaUntrustedIp)                    │
       │       - LB Frontend  : $($design.NvaLbIp) (UDR next hop)            │
       │                                                                      │
       │   Subnet: Apps  ($($design.WorkloadSubnetApp))                      │
       │   Subnet: APIs  ($($design.WorkloadSubnetApi))                      │
       │   Subnet: Data  ($($design.WorkloadSubnetData))                     │
       └──────────────────────────────────────────────────────────┘
"@

    } else {

@"
Environment: $($design.EnvironmentName)  |  Region: $($design.Region)

NVA Placement: Inside Azure vWAN Hub (Integrated NVA)

         ┌──────────────────────────────────────────────────┐
         │            On-Prem / HQ / Branches               │
         └──────────────────────────────────────────────────┘
                            ▲
                            │ BGP / SD-WAN
                            │
       ┌──────────────────────────────────────────────────────────┐
       │                 Azure vWAN Hub: $($design.VwanHubName)             │
       │   Address Space: $($design.VwanHubAddress)                         │
       │   [Integrated Fortinet NVA via Routing Intent]                     │
       └───────────────▲──────────────────────────────────────────┘
                       │
                       │ VNet connection
                       │
       ┌──────────────────────────────────────────────────────────┐
       │              Workload VNet: $($design.WorkloadVnetName)             │
       │   Address Space: $($design.WorkloadVnetAddress)                     │
       │                                                                      │
       │   Subnet: Apps  ($($design.WorkloadSubnetApp))                      │
       │   Subnet: APIs  ($($design.WorkloadSubnetApi))                      │
       │   Subnet: Data  ($($design.WorkloadSubnetData))                     │
       └──────────────────────────────────────────────────────────┘
"@
    }
}

Render-AsciiDiagram -design $design

#endregion ASCII Diagram

#region UDR Table

if ($udrList.Count -gt 0) {
    Draw-Separator "Suggested UDRs (Per Subnet)"
    $udrList | Sort-Object RouteTable, Subnet, Prefix | Format-Table -AutoSize
} else {
    Draw-Separator "UDRs"
    Write-Host "No explicit UDRs generated (vWAN hub NVA / routing intent model)." -ForegroundColor DarkCyan
}

#endregion UDR Table

#region Fortinet Policy Skeleton

Draw-Separator "Fortinet NVA Policy Skeleton (High-Level)"

$flows = @()
if ($design.InspectOnPrem) { $flows += "VNet ↔ On-Prem" }
if ($design.InspectInternet) { $flows += "VNet ↔ Internet" }
if ($design.InspectInterVnet) { $flows += "VNet ↔ Other VNets (Spokes)" }

if ($flows.Count -eq 0) {
    Write-Host "No flows marked for inspection; Fortinet policies not required in this model." -ForegroundColor DarkCyan
} else {
    Write-Host "Flows to inspect via NVA:" -ForegroundColor Cyan
    $flows | ForEach-Object { Write-Host ("  - {0}" -f $_) }

@"
Example Fortinet Policy Groups (pseudo):

1. OUTBOUND - Workload to On-Prem
   - Src:  $($design.WorkloadVnetAddress) (or specific subnets)
   - Dst:  $(( $design.OnPremPrefixes -join ", " )) 
   - Service: AD, DNS, SQL, RDP, HTTP(S), etc.
   - NAT:   Disabled (usually) for private RFC1918 over ER/VPN
   - Log:   Enabled

2. INBOUND - On-Prem to Workload (App Publishing)
   - Src:   On-Prem DMZ / specific subnets
   - Dst:   App subnet: $($design.WorkloadSubnetApp)
   - Service: HTTP(S)/custom app ports
   - NAT:   As required (VIPs / SNAT)
   - Log:   Enabled

3. OUTBOUND - Workload to Internet
   - Src:   $($design.WorkloadVnetAddress)
   - Dst:   0.0.0.0/0
   - Service: Web, updates, package repos, etc.
   - NAT:   Enabled (SNAT to NVA Untrust IP or LB IP)
   - Log:   Enabled

4. MANAGEMENT
   - Src:   Admin subnets / jump hosts
   - Dst:   NVA Mgmt IP: $($design.NvaMgmtIp)
   - Service: HTTPS/SSH
   - NAT:   As per security policy
   - Log:   Enabled

Additional:
   - Security Profiles: IPS, Web Filtering, AV, SSL Inspection
   - Logging: Forward to Azure Log Analytics / FortiAnalyzer / Syslog
   - HA: Ensure LB probes + FortiGate health-check policies are defined
"@
}

#endregion Fortinet Policy Skeleton

#region Design Notes

Draw-Separator "Design Notes & Assumptions (Generated)"

@"
1. vWAN is the primary control-plane for routing to On-Prem and branches.
2. UDRs applied to workload subnets override BGP routes for matching prefixes.
3. Peering between Transit VNet and Workload VNet requires:
   - Use Remote Gateway (on Workload VNet where appropriate)
   - Allow Gateway Transit (on Transit VNet when acting as gateway)
   - Allow Forwarded Traffic (both sides)
4. FortiGate is assumed to be behind an Azure Load Balancer; all UDRs use
   the LB frontend IP as the VirtualAppliance next hop (except hub-integrated).
5. Azure platform traffic (e.g., 168.63.129.16, service tags) may require
   additional UDR exceptions to avoid breaking platform services.
6. For vWAN Hub NVA mode, routing intent replaces many manual UDRs, while
   still ensuring north-south traffic inspection.
7. This wizard is a learning aid; refine IP plans, naming, and security
   controls to comply with your org's standards and change process.
"@

#endregion Design Notes

#region Teaching Mode + Game Mode Entry

$designObj = [pscustomobject]$design

if ($TeachingModeEnabled) {
    Invoke-TeachingMode -Design $designObj
}

$playGame = Read-YesNo "Would you like to enter Troubleshooting Game Mode?" $true

if ($playGame) {
    Invoke-VwanTroubleshootingGame -Design $designObj
}

Write-Host ""
Write-Host "Wizard complete." -ForegroundColor Green
Write-Host ""

#endregion
