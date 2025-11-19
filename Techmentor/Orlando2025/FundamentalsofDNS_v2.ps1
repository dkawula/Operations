<#
   DNS-BBS.ps1
   Techmentor
   Retro DNS Training Simulator + Games
#>

# ============================================================
# UTILITIES — CRT typing + animations
# ============================================================

function Write-CRT {
    param(
        [string]$Text,
        [int]$Delay = 7,
        [ConsoleColor]$Color = [ConsoleColor]::Green
    )

    foreach ($char in $Text.ToCharArray()) {
        Write-Host -NoNewline $char -ForegroundColor $Color
        Start-Sleep -Milliseconds $Delay
    }
    Write-Host ""
}

function Animate-Step {
    param([string]$Text)
    Write-CRT "→ $Text" 7 'Yellow'
    Start-Sleep -Milliseconds 450
}

function Animate-Packet {
    param(
        [string]$From,
        [string]$To
    )
    Write-CRT "[$From] ---· · · ---> [$To]" 5 'Green'
    Start-Sleep -Milliseconds 320
}

function pause {
    Write-Host "`nPress ENTER..." -ForegroundColor DarkGray
    Read-Host | Out-Null
}

# ============================================================
# ASCII MOTD BANNERS
# ============================================================

function Show-DNS {
@"
██████╗ ███╗   ██╗███████╗
██╔══██╗████╗  ██║██╔════╝
██║  ██║██╔██╗ ██║███████╗
██║  ██║██║╚██╗██║╚════██║
██████╔╝██║ ╚████║███████║
╚═════╝ ╚═╝  ╚═══╝╚══════╝
  


                 IT WAS DNS
"@ | Write-Host -ForegroundColor Cyan
}

function Show-AlwaysDNS {
@"
██████╗ ███╗   ██╗███████╗
██╔══██╗████╗  ██║██╔════╝
██║  ██║██╔██╗ ██║███████╗
██║  ██║██║╚██╗██║╚════██║
██████╔╝██║ ╚████║███████║
╚═════╝ ╚═╝  ╚═══╝╚══════╝

               IT IS ALWAYS DNS
"@ | Write-Host -ForegroundColor Cyan
}

function Show-Firewall {
@"
███████╗██╗██████╗ ███████╗██╗    ██╗ █████╗ ██╗     ██╗     
██╔════╝██║██╔══██╗██╔════╝██║    ██║██╔══██╗██║     ██║     
█████╗  ██║██████╔╝█████╗  ██║ █╗ ██║███████║██║     ██║     
██╔══╝  ██║██╔══██╗██╔══╝  ██║███╗██║██╔══██║██║     ██║     
██║     ██║██║  ██║███████╗╚███╔███╔╝██║  ██║███████╗███████╗
╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝ ╚══╝╚══╝ ╚═╝  ╚═╝╚══════╝╚══════╝
 

                     IT WAS THE FIREWALL
"@ | Write-Host -ForegroundColor Red
}

function Show-Emile {
@"
 _____ __  __ ___ _      _____ 
| ____|  \/  |_ _| |    | ____|
|  _| | |\/| || || |    |  _|  
| |___| |  | || || |___ | |___ 
|_____|_|  |_|___|_____| |____|

                IT WAS EMILE
"@ | Write-Host -ForegroundColor Magenta
}

# ============================================================
# DNS FLOW VISUALIZER — ASCII WHITEBOARD + REAL LOOKUPS
# ============================================================

function Show-DNSFlow {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Domain
    )

    Clear-Host
    Write-Host "=== DNS FLOW VISUALIZER (ASCII WHITEBOARD MODE) ===" -ForegroundColor Cyan
    Write-Host "Resolving: $Domain" -ForegroundColor Yellow
    Write-Host ""

    $labels = $Domain.Split('.')
    $tld = $labels[-1]

    Animate-Step "Checking HOSTS file..."
    Animate-Packet "CLIENT" "HOSTS"

    Animate-Step "Checking local DNS cache..."
    Animate-Packet "CLIENT" "DNS CACHE"

    Animate-Step "Sending query to Primary DNS Server..."
    Animate-Packet "CLIENT" "LOCAL DNS"

@"
╔══════════════════════════════════════════════════════════════╗
║                  DNS QUERY TRAVERSAL (ASCII MAP)             ║
╚══════════════════════════════════════════════════════════════╝


 CLIENT
   |
   v
┌───────────┐
│ HOSTS FILE│
└─────┬─────┘
      |
      v
┌───────────┐
│DNS  CACHE │
└─────┬─────┘
      |
      v
┌─────────────────────┐
│ LOCAL DNS SERVER    │  (Recursive Resolver)
└──────────┬──────────┘
           |
           v
     (Cache Miss)
           |
           v
     ┌──────────────┐
     │   ROOT HINTS │     (".")
     └───────┬──────┘
             |
             v
     ┌────────────────────────────┐
     │  ROOT DNS SERVERS          │  (.) - Starting point
     └───────────┬────────────────┘
                 |
                 v
        ┌────────────────────────┐
        │   TLD SERVERS          │   (.${tld})
        └──────────┬─────────────┘
                   |
                   v
       ┌───────────────────────────────┐
       │ AUTHORITATIVE NAME SERVERS    │  (${Domain})
       └──────────────┬────────────────┘
                      |
                      v
                 ANSWER RETURNED
                      |
                      v
           ┌───────────────────────────┐
           │  LOCAL DNS SERVER CACHE   │
           └──────────────┬────────────┘
                          |
                          v
                        CLIENT

"@ | Write-Host -ForegroundColor Green

    Write-Host "`nDOMAIN HIERARCHY:" -ForegroundColor Cyan
    $levels = @()
    for ($i = $labels.Length-1; $i -ge 0; $i--) {
        $part = ($labels[$i..($labels.Length-1)] -join '.')
        $levels += $part
    }

    Write-Host "  ." -ForegroundColor Green
    for ($i = 0; $i -lt $levels.Count; $i++) {
        $prefix = "  "
        for ($j = 0; $j -lt $i; $j++) { $prefix += "   " }
        if ($i -eq $levels.Count-1) {
            Write-Host ("{0}└── {1}" -f $prefix, $levels[$i]) -ForegroundColor Green
        } else {
            Write-Host ("{0}├── {1}" -f $prefix, $levels[$i]) -ForegroundColor Green
        }
    }

    Write-Host "`n=== REAL DNS LOOKUP STAGES ===" -ForegroundColor Cyan

    Animate-Step "Querying Root Servers..."
    $roots = Resolve-DnsName -Name . -Type NS -ErrorAction SilentlyContinue

    if ($roots) {
        foreach ($r in ($roots | Select-Object -First 3)) {
            Write-Host "[ . ]  →  ROOT SERVER: $($r.NameHost)" -ForegroundColor Green
            Start-Sleep -Milliseconds 250
        }
    } else {
        Write-Host "Unable to query root servers (.)" -ForegroundColor Red
    }

    Animate-Step "Querying TLD Servers for .$tld ..."
    $tldNs = Resolve-DnsName -Name $tld -Type NS -ErrorAction SilentlyContinue

    if ($tldNs) {
        foreach ($ns in ($tldNs | Select-Object -First 3)) {
            Write-Host "[ .$tld ] → TLD SERVER: $($ns.NameHost)" -ForegroundColor Yellow
            Start-Sleep -Milliseconds 250
        }
    } else {
        Write-Host "Unable to query TLD servers for .$tld" -ForegroundColor Red
    }

    Animate-Step "Querying authoritative (SOA) server…"
    $soa = Resolve-DnsName -Name $Domain -Type SOA -ErrorAction SilentlyContinue

    if ($soa) {
        Write-Host "[AUTH] → $($soa.PrimaryServer)" -ForegroundColor Magenta
    } else {
        Write-Host "[AUTH] No SOA record found" -ForegroundColor DarkYellow
    }

    Animate-Step "Querying final A record..."
    $final = Resolve-DnsName -Name $Domain -Type A -ErrorAction SilentlyContinue

@"
────────────────────────────────────────────────────────
                 FINAL ANSWER                         
────────────────────────────────────────────────────────
"@ | Write-Host -ForegroundColor Cyan

    if ($final) {
        $final | Format-Table Name,IPAddress
    } else {
        Write-Host "❌ No A record found." -ForegroundColor Red
    }

    Write-Host ""
    Write-CRT "DNS FLOW COMPLETE." 10
    pause
}

# ============================================================
# ASCII NETWORK MAP MODES (Teaching / Animated / Live)
# ============================================================

function Show-NetworkMapTeaching {

    $steps = @(
        "CLIENT → Check HOSTS file",
        "CLIENT → Check DNS cache",
        "CLIENT → Primary DNS Server",
        "DNS Server → Check its own cache",
        "DNS Server → ROOT Hints",
        "DNS Server → Root Servers (.)",
        "DNS Server → TLD Servers (.com/.net/.ca)",
        "DNS Server → Authoritative Server",
        "Authoritative Server → DNS Server (Answer)",
        "DNS Server → Cache answer",
        "DNS Server → CLIENT (Final Answer)"
    )

    Clear-Host
    Write-Host "ASCII NETWORK MAP — TEACHING MODE" -ForegroundColor Cyan
    Write-Host "Press ENTER after each step…" -ForegroundColor Yellow
    Write-Host ""

    foreach ($s in $steps) {
        Write-Host ""
        Write-Host "→ $s" -ForegroundColor Green
        Read-Host "Press ENTER for next hop" | Out-Null
    }

    Write-Host ""
    Write-Host "Teaching mode complete." -ForegroundColor Cyan
    pause
}

function Show-NetworkMapAnimated {

    Clear-Host
    Write-Host "ASCII NETWORK MAP — ANIMATED MODE" -ForegroundColor Cyan
    Write-Host ""

    $hops = @(
        "CLIENT",
        "HOSTS FILE",
        "DNS CACHE",
        "PRIMARY DNS",
        "ROOT HINTS",
        "ROOT SERVERS",
        "TLD SERVERS",
        "AUTH SERVER",
        "DNS SERVER (cache)",
        "CLIENT (final)"
    )

    for ($i = 0; $i -lt $hops.Count - 1; $i++) {
        $from = $hops[$i]
        $to   = $hops[$i+1]

        Write-Host ""
        Write-Host "[$from] ----· · · ----> [$to]" -ForegroundColor Green
        Start-Sleep -Milliseconds 600
    }

    Write-Host ""
    Write-Host "Animated route complete." -ForegroundColor Cyan
    pause
}

function Show-NetworkMapLive {
    param([string]$Domain)

    Clear-Host
    Write-Host "ASCII NETWORK MAP — LIVE LOOKUP MODE" -ForegroundColor Cyan
    Write-Host "Performing recursion chain for: $Domain" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "Querying Root Servers…" -ForegroundColor Green
    $roots = Resolve-DnsName -Name . -Type NS -ErrorAction SilentlyContinue
    if ($roots) {
        $roots | Select-Object -First 5 | ForEach-Object {
            Write-Host "[CLIENT] ---> ROOT SERVER: $($_.NameHost)" -ForegroundColor Green
            Start-Sleep -Milliseconds 300
        }
    } else {
        Write-Host "Unable to query root servers." -ForegroundColor Red
    }

    $tld = $Domain.Split('.')[-1]
    Write-Host "`nQuerying TLD Servers for .$tld…" -ForegroundColor Green
    $tldNs = Resolve-DnsName -Name $tld -Type NS -ErrorAction SilentlyContinue

    if ($tldNs) {
        $tldNs | Select-Object -First 5 | ForEach-Object {
            Write-Host "[ROOT] ---> TLD SERVER: $($_.NameHost)" -ForegroundColor Yellow
            Start-Sleep -Milliseconds 300
        }
    } else {
        Write-Host "No TLD servers found for .$tld" -ForegroundColor Red
    }

    Write-Host "`nQuerying authoritative DNS…" -ForegroundColor Green
    $soa = Resolve-DnsName -Name $Domain -Type SOA -ErrorAction SilentlyContinue
    if ($soa) {
        Write-Host "[TLD] ---> AUTH SERVER: $($soa.PrimaryServer)" -ForegroundColor Magenta
        Start-Sleep -Milliseconds 500
    } else {
        Write-Host "No SOA record found." -ForegroundColor DarkYellow
    }

    $final = Resolve-DnsName -Name $Domain -Type A -ErrorAction SilentlyContinue

    Write-Host "`nAuthoritative Answer:" -ForegroundColor Cyan
    if ($final) {
        $final | Format-Table Name,IPAddress
    } else {
        Write-Host "❌ No A record found"
    }

    Write-Host ""
    Write-Host "Recursion complete." -ForegroundColor Cyan
    pause
}

function Show-NetworkMapMenu {
    do {
        Clear-Host
        Write-Host "=== ASCII NETWORK MAP MODES ===" -ForegroundColor Cyan

@"
[1] Teaching Mode (step-by-step)
[2] Animated Mode (auto-sequence)
[3] Live Lookup Mode (recursive root → TLD → auth)
[Q] Back to main menu
"@ | Write-Host -ForegroundColor Green

        $opt = Read-Host "Choose mode"

        switch ($opt) {
            "1" { Clear-Host; Show-NetworkMapTeaching }
            "2" { Clear-Host; Show-NetworkMapAnimated }
            "3" { 
                $domain = Read-Host "Enter domain (example: microsoft.com)"
                Clear-Host
                Show-NetworkMapLive -Domain $domain
            }
            "Q" { return }
            "q" { return }
        }
    } while ($true)
}

# ============================================================
# SPLIT-BRAIN DNS — INTERNAL vs EXTERNAL (conceptual)
# ============================================================

function Show-SplitBrainDNS {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Domain
    )

    Clear-Host
    Write-Host "=== SPLIT-BRAIN DNS VISUALIZER ===" -ForegroundColor Cyan
    Write-Host "Domain: $Domain" -ForegroundColor Yellow
    Write-Host ""

    $internalServer = $null
    try {
        $internalServer = (Get-DnsClientServerAddress -AddressFamily IPv4 |
            Where-Object { $_.ServerAddresses } |
            Select-Object -First 1).ServerAddresses[0]
    } catch {}

    if (-not $internalServer) {
        $internalServer = "192.168.0.10"
    }

    $externalServer = "8.8.8.8"

@"
CLIENT
  |
  +-- INTERNAL PATH -->  $internalServer  (CORPORATE DNS)
  |
  +-- EXTERNAL PATH -->  $externalServer  (PUBLIC DNS)

Use this to explain how corp DNS can give 'inside' answers while public DNS
gives 'outside' answers (split-brain DNS).
"@ | Write-Host -ForegroundColor Green

    pause
}

# ============================================================
# DNSSEC CHAIN-OF-TRUST VISUALIZER
# ============================================================

function Show-DNSSECChain {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Domain
    )

    Clear-Host
    Write-Host "=== DNSSEC CHAIN OF TRUST VISUALIZER ===" -ForegroundColor Cyan
    Write-Host "Domain: $Domain" -ForegroundColor Yellow
    Write-Host ""

@"
CHAIN OF TRUST (Conceptual):

   ROOT (.)  --signed-->  TLD (.tld)  --signed-->  ZONE ($Domain)  --signed-->  RECORDS
      |                      |                         |
     KSK                    KSK                       KSK
     ZSK                    ZSK                       ZSK
"@ | Write-Host -ForegroundColor Green

    $tld = $Domain.Split('.')[-1]

    Animate-Step "Querying ROOT with DNSSEC OK flag..."
    $rootDnssec = Resolve-DnsName -Name . -Type NS -DnssecOk -ErrorAction SilentlyContinue

    if ($rootDnssec) {
        Write-Host "[.] Root responded with DNSSEC-capable data (conceptual trust anchor)." -ForegroundColor Green
    } else {
        Write-Host "Could not confirm DNSSEC at root (non-validating client or blocked)." -ForegroundColor DarkYellow
    }

    Animate-Step "Querying TLD DNSKEY for .$tld (if available)..."
    $tldDnskey = Resolve-DnsName -Name $tld -Type DNSKEY -DnssecOk -ErrorAction SilentlyContinue

    if ($tldDnskey) {
        Write-Host "TLD .$tld has DNSKEY records — DNSSEC likely enabled." -ForegroundColor Green
    } else {
        Write-Host "No DNSKEY for .$tld retrieved." -ForegroundColor DarkYellow
    }

    Animate-Step "Querying ZONE DNSKEY for $Domain (if available)..."
    $zoneDnskey = Resolve-DnsName -Name $Domain -Type DNSKEY -DnssecOk -ErrorAction SilentlyContinue

    if ($zoneDnskey) {
        Write-Host "ZONE $Domain has DNSKEY records — DNSSEC likely enabled." -ForegroundColor Green
    } else {
        Write-Host "No DNSKEY for $Domain retrieved." -ForegroundColor DarkYellow
    }

    Animate-Step "Querying A record with DNSSEC OK..."
    $answer = Resolve-DnsName -Name $Domain -Type A -DnssecOk -ErrorAction SilentlyContinue

    if ($answer) {
        $answer | Format-Table Name,IPAddress,Type,Section
        $rrsig = $answer | Where-Object { $_.Type -eq "RRSIG" }
        if ($rrsig) {
            Write-Host "`nRRSIG records present — response is signed." -ForegroundColor Green
        } else {
            Write-Host "`nNo RRSIG in visible answer — either not signed or not validating here." -ForegroundColor DarkYellow
        }
    } else {
        Write-Host "No DNSSEC-aware answer returned." -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "Use this to explain DNSSEC even if the live zone isn't fully signed/validating." -ForegroundColor DarkGray
    pause
}

# ============================================================
# ROOT HINTS FAILURE DEMO (Conceptual)
# ============================================================

function Show-RootHintsFailure {
    Clear-Host
    Write-Host "=== ROOT HINTS FAILURE DEMO ===" -ForegroundColor Cyan
@"
SCENARIO: Your recursive DNS server has LOST its root hints
          and has NO FORWARDERS configured.

ASCII FLOW:

 CLIENT
   |
   v
┌─────────────┐
│  LOCAL DNS  │
└──────┬──────┘
       |
       v
   (Needs ROOT)
       |
       X   ← Root hints missing
       |
   ┌─────────────┐
   │  TIMEOUT    │
   └─────────────┘

RESULT: Client sees failures like:
  - 'DNS name does not exist'
  - 'Server failed'
  - Web pages timing out

HOW TO FIX (CONCEPTUALLY):

 1. Restore ROOT HINTS on the DNS server.
 2. OR Configure FORWARDERS to a known good DNS (ISP, public, etc.).
 3. Ensure FIREWALL allows outbound UDP/TCP 53 to roots/forwarders.
"@ | Write-Host -ForegroundColor Green

    pause
}

# ============================================================
# "FIX EMILE'S DNS" MINI-GAME
# ============================================================

function Play-FixEmilesDNS {

    Clear-Host
    Write-Host "=== MINI-GAME: FIX EMILE'S DNS ===" -ForegroundColor Cyan

@"
BACKSTORY:
  Emile was 'optimizing' DNS and:

   - Deleted ROOT HINTS
   - Removed all FORWARDERS
   - Left FIREWALL blocking outbound DNS
   - Now nobody can resolve external names.

Your job: Pick fixes in a sensible order and restore DNS.

"@ | Write-Host -ForegroundColor Yellow

    $fixedRoot = $false
    $fixedFw   = $false
    $fixedFwd  = $false

    do {
        Write-Host ""
        Write-Host "Current Status:" -ForegroundColor Cyan
        Write-Host ("  Root Hints restored : {0}" -f $fixedRoot)
        Write-Host ("  Forwarders set      : {0}" -f $fixedFwd)
        Write-Host ("  Firewall open       : {0}" -f $fixedFw)

@"
What do you want to do?

[1] Restore ROOT HINTS
[2] Configure DNS FORWARDERS
[3] Open FIREWALL for UDP/TCP 53
[4] Test external name resolution
[Q] Give up and blame the firewall
"@ | Write-Host -ForegroundColor Green

        $choice = Read-Host "Choose action"

        switch ($choice) {
            "1" {
                if (-not $fixedRoot) {
                    Write-CRT "Restoring root hints (conceptually)..." 5 'Green'
                    $fixedRoot = $true
                } else {
                    Write-Host "Root hints already restored." -ForegroundColor DarkGray
                }
            }
            "2" {
                if (-not $fixedFwd) {
                    Write-CRT "Adding forwarders to known good DNS resolvers..." 5 'Green'
                    $fixedFwd = $true
                } else {
                    Write-Host "Forwarders already configured." -ForegroundColor DarkGray
                }
            }
            "3" {
                if (-not $fixedFw) {
                    Write-CRT "Opening firewall for DNS traffic (UDP/TCP 53)..." 5 'Green'
                    $fixedFw = $true
                } else {
                    Write-Host "Firewall already open (for DNS)." -ForegroundColor DarkGray
                }
            }
            "4" {
                Write-Host ""
                if ($fixedRoot -or $fixedFwd) {
                    if ($fixedFw) {
                        Write-Host "Test: Client can now resolve external names. 🎉" -ForegroundColor Green
                        Write-Host "You successfully fixed Emile's DNS mess!" -ForegroundColor Cyan
                        pause
                        return
                    } else {
                        Write-Host "Test: DNS server can resolve, but firewall still blocking client/egress." -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "Test: Still failing — recursive server has nowhere to go (no roots/forwarders)." -ForegroundColor Red
                }
            }
            "Q" {
                Write-Host "You gave up and blamed the firewall. Emile wins this round. 😈" -ForegroundColor Red
                pause
                return
            }
            "q" {
                Write-Host "You gave up and blamed the firewall. Emile wins this round. 😈" -ForegroundColor Red
                pause
                return
            }
        }

    } while ($true)
}

# ============================================================
# PING QUEST – THE DNS CHRONICLES
# ============================================================

function Play-PingQuest {

    Clear-Host
    Write-Host "=== PING QUEST: THE DNS CHRONICLES ===" -ForegroundColor Cyan

@"
You are the on-call DNS hero.

Pings are failing all over the environment. Your job:
  - Read the scenario
  - Look at the ASCII whiteboard
  - Pick the correct conceptual fix

Stages:
  1. File server (A record)
  2. Internal website (CNAME)
  3. Mail server (MX)
  4. AD logons (SRV records)
  5. External site (roots/forwarders)

"@ | Write-Host -ForegroundColor Yellow

    function Invoke-Stage {
        param(
            [string]$Title,
            [string]$Scenario,
            [string]$AsciiMap,
            [string[]]$Options,
            [int]$CorrectIndex
        )

        Clear-Host
        Write-Host "=== PING QUEST STAGE: $Title ===" -ForegroundColor Cyan
        Write-Host ""
        Write-Host $Scenario -ForegroundColor White
        Write-Host ""
        Write-Host $AsciiMap -ForegroundColor Green

        do {
            Write-Host ""
            for ($i = 0; $i -lt $Options.Count; $i++) {
                Write-Host ("[{0}] {1}" -f ($i+1), $Options[$i]) -ForegroundColor Green
            }
            Write-Host "[Q] Quit this game" -ForegroundColor DarkGray

            $ans = Read-Host "Choose your fix"

            if ($ans -eq 'Q' -or $ans -eq 'q') {
                Write-Host "You bail out of PING QUEST. The helpdesk tickets multiply. 📉" -ForegroundColor Red
                pause
                return $false
            }

            if ($ans -match '^\d+$') {
                $num = [int]$ans
                if ($num -eq $CorrectIndex) {
                    Write-Host "`n✅ Correct! DNS justice +10." -ForegroundColor Green
                    Start-Sleep -Milliseconds 700
                    return $true
                } else {
                    Write-Host "`n❌ Not quite. That doesn't fix the name resolution issue. Try again." -ForegroundColor Red
                }
            } else {
                Write-Host "Enter a valid option." -ForegroundColor DarkYellow
            }
        } while ($true)
    }

    $ok = Invoke-Stage `
        -Title "FILESERVER01 – A record missing" `
        -Scenario @"
PING:  ping FILESERVER01

Result:
  Ping request could not find host FILESERVER01. Please check the name and try again.

Background:
  This is your main file server: FILESERVER01.corp.local
  Users can still access it by IP: 10.10.10.50
"@ `
        -AsciiMap @"
CLIENT 'ping FILESERVER01'
        |
        v
┌───────────────────┐
│  corp.local zone  │
└─────────┬─────────┘
          |
          v
   (NO A RECORD)
          |
          v
    NAME NOT FOUND
"@ `
        -Options @(
            "Create an A record: FILESERVER01 → 10.10.10.50 in the corp.local zone",
            "Change the client's default gateway to 10.10.10.1",
            "Restart the print spooler service on FILESERVER01"
        ) `
        -CorrectIndex 1

    if (-not $ok) { return }

    $ok = Invoke-Stage `
        -Title "INTRANET – CNAME alias missing" `
        -Scenario @"
PING:  ping intranet

Result:
  Ping request could not find host intranet. Please check the name and try again.

Background:
  Intranet used to be a CNAME:
    intranet.corp.local  →  webportal01.corp.local
"@ `
        -AsciiMap @"
CLIENT 'ping intranet'
        |
        v
┌───────────────────┐          ┌────────────────────┐
│  corp.local zone  │   X      │ webportal01 A 10.10.20.40 │
└─────────┬─────────┘          └────────────────────┘
          |
          v
   (NO CNAME intranet)
          |
          v
    NAME NOT FOUND
"@ `
        -Options @(
            "Create/restore a CNAME: intranet → webportal01.corp.local",
            "Add a static route on the client for 10.10.20.0/24",
            "Change DHCP scope to hand out a new DNS suffix"
        ) `
        -CorrectIndex 1

    if (-not $ok) { return }

    $ok = Invoke-Stage `
        -Title "MAIL FLOW – MX records missing" `
        -Scenario @"
SYMPTOM:
  External senders get NDRs like:
    'Host or domain name not found. Name service error for name=corp.local type=MX'

Background:
  Corp mail should be:
    MX 10 mail.corp.local
    A record: mail.corp.local → 10.10.30.25
"@ `
        -AsciiMap @"
INTERNET SMTP SERVER
        |
        |  MX lookup for corp.local
        v
┌──────────────────────┐
│   corp.local DNS     │
└────────────┬─────────┘
             |
             v
       (NO MX RECORDS)
             |
             v
    'NO SUCH DOMAIN / MX'
"@ `
        -Options @(
            "Create MX record: corp.local → mail.corp.local (priority 10)",
            "Change SPF record only",
            "Restart Outlook on user machines"
        ) `
        -CorrectIndex 1

    if (-not $ok) { return }

    $ok = Invoke-Stage `
        -Title "AD LOGONS – SRV records missing" `
        -Scenario @"
SYMPTOM:
  - Users cannot log on
  - Domain join fails
  - Error: 'The domain controller for the domain cannot be contacted'

Background:
  AD requires SRV records such as:
    _ldap._tcp.dc._msdcs.corp.local
"@ `
        -AsciiMap @"
CLIENT 'Locate DC'
        |
        v
┌──────────────────────────┐
│  _ldap._tcp.dc._msdcs    │  SRV lookup
│        .corp.local       │
└────────────┬─────────────┘
             |
             v
      (NO SRV RECORDS)
             |
             v
     CANNOT FIND DOMAIN
"@ `
        -Options @(
            "Repair/re-register AD-integrated SRV records (ipconfig /registerdns or restart Netlogon on DCs)",
            "Change user's UPN suffix only",
            "Reboot the file server"
        ) `
        -CorrectIndex 1

    if (-not $ok) { return }

    $ok = Invoke-Stage `
        -Title "EXTERNAL SITE – Root/forwarder issue" `
        -Scenario @"
PING:  ping www.outsideworld.com

Result:
  Ping request could not find host www.outsideworld.com.

Background:
  - Internal names resolve fine.
  - Only external names fail.
"@ `
        -AsciiMap @"
CLIENT 'ping www.outsideworld.com'
        |
        v
┌───────────────────┐
│  LOCAL DNS SERVER │
└─────────┬─────────┘
          |
          v
   Needs external recursion
          |
          X   (NO ROOT HINTS / FORWARDERS)
          |
         TIMEOUT
"@ `
        -Options @(
            "Configure valid DNS forwarders or restore root hints on the internal DNS server",
            "Change users' time zone",
            "Disable IPv6 on client NICs only"
        ) `
        -CorrectIndex 1

    if (-not $ok) { return }

    Clear-Host
    Write-Host "🎉 CONGRATULATIONS! You completed PING QUEST." -ForegroundColor Green
    Write-Host "You are now an honorary DNS Grandmaster of Techmentor." -ForegroundColor Cyan
    pause
}

# ============================================================
# NEW: EXTERNAL DNS & DOMAIN REGISTRATION TRAINER
# ============================================================

function Show-ExternalDNSTeaching {

    Clear-Host
    Write-Host "=== EXTERNAL DNS & DOMAIN REGISTRATION – TEACHING MODE ===" -ForegroundColor Cyan

@"
SCENARIO:
  You want to buy:   dave.com
  You go to a registrar (GoDaddy, Namecheap, etc.)
  Behind the scenes:
    - They talk to the REGISTRY for .com
    - The REGISTRY updates the TLD NS records
    - You configure DNS HOSTING for your zone
    - You add TXT (for M365), MX, CNAME, etc.

ASCII WHITEBOARD:

                           ┌──────────────────────┐
                           │      INTERNET        │
                           └──────────┬───────────┘
                                      │
                                      ▼
                                ┌─────────────┐
                                │ ROOT SERVERS│
                                │     (.)     │
                                └───────┬─────┘
                                        │
                                        ▼

                     ┌─────────────┐   ┌─────────────┐   ┌──────────────┐
                     │ TLD SERVERS │   │ TLD SERVERS │   │  TLD SERVERS │
                     │    (.NET)   │   │    (.COM)   │   │   (.NINJA)   │
                     └───────┬─────┘   └──────┬──────┘   └──────┬───────┘
                             │               │                 │
                             ▼               ▼                 ▼

                     (YOU CHOOSE .COM → Registry updates zone for .COM)

"@ | Write-Host -ForegroundColor Green

    Read-Host "Step 1: Press ENTER to continue (Buying a domain at a registrar)" | Out-Null

@"
NEXT:

When you BUY dave.com at a registrar:

- REGISTRAR:
    - Retail front-end
    - Takes your money
    - Lets you manage contacts/NS records

- REGISTRY (for .COM):
    - Authoritative for the TLD (.COM)
    - Stores:
        dave.com  NS  ns1.your-dns-host.com
                  NS  ns2.your-dns-host.com

This means:
  ROOT (.) → .COM TLD → NS for dave.com (your DNS host)
"@ | Write-Host -ForegroundColor Green

    Read-Host "Step 2: Press ENTER to continue (DNS hosting)" | Out-Null

@"
DNS HOSTING:

At your DNS host (could be same as registrar, or Cloudflare, Azure DNS, etc.)

You create the ZONE:  dave.com

Inside that zone you create RECORDS:

  @        TXT   'MS=msXXXXXXXX'        ← M365 verification TXT
  @        MX    0 dave-com.mail.protection.outlook.com
  @        CNAME autodiscover → autodiscover.outlook.com
  www      A     203.0.113.10           ← your web server
  vpn      A     203.0.113.20           ← your VPN endpoint

ASCII:

 ROOT (.)
    |
    v
 .COM  (Registry)
    |
    v
 NS for dave.com  (your DNS host)
    |
    v
┌───────────────────────────┐
│        ZONE: dave.com     │
│  A, CNAME, TXT, MX, etc.  │
└───────────────────────────┘
"@ | Write-Host -ForegroundColor Green

    Read-Host "Step 3: Press ENTER to continue (M365 TXT verification)" | Out-Null

@"
M365 VERIFICATION FLOW (Conceptual):

1. In Microsoft 365 admin:
     - 'Add domain: dave.com'

2. Microsoft says:
     - 'Add this TXT record at your DNS host:'
         @ TXT   MS=ms123456789

3. You add the TXT at your DNS host.

4. Microsoft checks:
     - Query: TXT for dave.com
     - Path:
           ROOT → .COM → NS for dave.com → ZONE dave.com → TXT MS=...

5. Once TXT is seen → Domain is verified.

Then you add MX/CNAME/SRV records for Exchange Online, etc.
"@ | Write-Host -ForegroundColor Green

    Read-Host "Step 4: Press ENTER to return to menu" | Out-Null
}

function Show-ExternalDNSAnimated {

    Clear-Host
    Write-Host "=== EXTERNAL DNS & DOMAIN REGISTRATION – ANIMATED MODE ===" -ForegroundColor Cyan
    Write-Host ""

    Animate-Step "You decide you want: dave.com"
    Animate-Step "You go to a REGISTRAR (e.g. GoDaddy)"
    Animate-Step "Registrar talks to the .COM REGISTRY"
    Animate-Step "Registry adds NS records for dave.com to the .COM TLD zone"

@"
                           ┌──────────────────────┐
                           │      INTERNET        │
                           └──────────┬───────────┘
                                      │
                                      ▼
                                ┌─────────────┐
                                │ ROOT SERVERS│
                                │     (.)     │
                                └───────┬─────┘
                                        │
                                        ▼
                                ┌─────────────┐
                                │ TLD (.COM)  │  ← Registry
                                └───────┬─────┘
                                        │
                                        ▼
                          NS records for dave.com
                            ns1.yourhost.com
                            ns2.yourhost.com

"@ | Write-Host -ForegroundColor Green

    Start-Sleep -Seconds 2
    Animate-Step "Now you log into your DNS HOST (the NS you just pointed at)"

@"
┌───────────────────────────┐
│        ZONE: dave.com     │
│                           │
│  @    TXT   MS=ms12345    │  ← M365 verification
│  @    MX    0 dave-com.mail.protection.outlook.com
│  www  A     203.0.113.10  │  ← Website
│  vpn  A     203.0.113.20  │  ← VPN
└───────────────────────────┘
"@ | Write-Host -ForegroundColor Green

    Start-Sleep -Seconds 2
    Animate-Step "Microsoft 365 checks TXT for dave.com via public DNS"
    Animate-Packet "M365" "ROOT (.)"
    Animate-Packet "ROOT (.)" ".COM TLD"
    Animate-Packet ".COM TLD" "NS for dave.com"
    Animate-Packet "NS for dave.com" "ZONE: dave.com (TXT)"

    Animate-Step "TXT record found → Domain verified"
    Animate-Step "Now MX points mail to Exchange Online"
    Animate-Step "Clients use public DNS to find your web, mail, VPN, etc."

    pause
}

function Show-ExternalDNSDomainDemo {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Domain
    )

    Clear-Host
    Write-Host "=== EXTERNAL DNS – LIVE DOMAIN WALKTHROUGH ===" -ForegroundColor Cyan
    Write-Host "Domain: $Domain" -ForegroundColor Yellow
    Write-Host ""

    $labels = $Domain.Split('.')
    $tld = $labels[-1]

@"
ROOT (.)
  |
  v
TLD: .$tld
  |
  v
ZONE: $Domain
  |
  v
RECORDS: A / MX / TXT / CNAME / NS / SOA
"@ | Write-Host -ForegroundColor Green

    Animate-Step "Querying TLD ($tld) NS set..."
    $tldNs = Resolve-DnsName -Name $tld -Type NS -ErrorAction SilentlyContinue
    if ($tldNs) {
        Write-Host "`nTLD NS for .$tld (sample):" -ForegroundColor Cyan
        $tldNs | Select-Object -First 5 | Format-Table Name,NameHost
    } else {
        Write-Host "Could not retrieve TLD NS (may be blocked from this environment)." -ForegroundColor DarkYellow
    }

    Animate-Step "Querying NS for $Domain..."
    $ns = Resolve-DnsName -Name $Domain -Type NS -ErrorAction SilentlyContinue
    if ($ns) {
        Write-Host "`nAuthoritative NS for ${Domain}:" -ForegroundColor Cyan
        $ns | Format-Table Name,NameHost
    } else {
        Write-Host "No NS records seen for $Domain from here." -ForegroundColor DarkYellow
    }

    Animate-Step "Querying SOA for $Domain..."
    $soa = Resolve-DnsName -Name $Domain -Type SOA -ErrorAction SilentlyContinue
    if ($soa) {
        Write-Host "`nSOA for ${Domain}:" -ForegroundColor Cyan
        $soa | Format-Table Name,PrimaryServer,Responsibility
    } else {
        Write-Host "No SOA visible for $Domain from here." -ForegroundColor DarkYellow
    }

    Animate-Step "Querying MX for $Domain..."
    $mx = Resolve-DnsName -Name $Domain -Type MX -ErrorAction SilentlyContinue
    if ($mx) {
        Write-Host "`nMX records (mail flow) for ${Domain}:" -ForegroundColor Cyan
        $mx | Sort-Object Preference | Format-Table Name,Exchange,Preference
    } else {
        Write-Host "No MX records found for $Domain (may not accept email)." -ForegroundColor DarkYellow
    }

    Animate-Step "Querying TXT for $Domain..."
    $txt = Resolve-DnsName -Name $Domain -Type TXT -ErrorAction SilentlyContinue
    if ($txt) {
        Write-Host "`nTXT records for ${Domain}:" -ForegroundColor Cyan
        $txt | Format-Table Name,Strings

        $m365 = $txt | Where-Object { $_.Strings -match "MS=" }
        if ($m365) {
            Write-Host "`nPossible Microsoft 365 verification TXT found:" -ForegroundColor Green
            $m365 | Format-Table Name,Strings
        }
    } else {
        Write-Host "No TXT records visible for $Domain." -ForegroundColor DarkYellow
    }

    Write-Host ""
    pause
}


<#
   DNS-TrainingSuite.ps1
   Techmentor
   Modular DNS Training Suite for DNS-BBS
#>

# ============================================================
# GLOBAL SETTINGS
# ============================================================

if (-not $Global:Theme) { $Global:Theme = "Green" }
if (-not $Global:InstructorMode) { $Global:InstructorMode = $false }

# Helper for instructor mode pacing
function Instructor-Sleep {
    if ($Global:InstructorMode) {
        Start-Sleep -Milliseconds 1400
    } else {
        Start-Sleep -Milliseconds 300
    }
}

# ============================================================
# UTILITY FUNCTIONS (Used by suite only)
# ============================================================

function TS-Write {
    param(
        [string]$Text,
        [string]$Color = "Green"
    )
    Write-Host $Text -ForegroundColor $Color
}

# ============================================================
# DNS 101 – TOP 25 TERMS
# ============================================================

$Global:DNS_Terms = @(

# ------------------------------------------------------------
# 1. DNS
# ------------------------------------------------------------
@{
Term="DNS";
Desc="The Domain Name System (DNS) is the global, distributed service that translates human-readable names (like www.microsoft.com) into machine-usable IP addresses. Without DNS, nothing on the internet or inside Active Directory can be located.";
Analogy="DNS is the 'Internet Phonebook' — you say someone's name, DNS finds the phone number.";
ASCII=@"
┌──────────────────────────────┐
│          DNS SYSTEM          │
│ (Names → IP Addresses)       │
└──────────────────────────────┘
CLIENT → DNS SERVER → IP
"@;
Why="Everything in networking — websites, email, AD, cloud apps — relies on DNS. If DNS breaks, EVERYTHING breaks.";
Example="Resolve-DnsName www.microsoft.com";
},

# ------------------------------------------------------------
# 2. FQDN
# ------------------------------------------------------------
@{
Term="FQDN (Fully Qualified Domain Name)";
Desc="The complete DNS name of a host including hostname, domain, and TLD. Always ends with a trailing dot (.).";
Analogy="An FQDN is like a person’s full legal name including first name, last name, and suffix.";
ASCII=@"
┌──────────────────────────────┐
│            FQDN              │
└──────────────────────────────┘
server01.corp.local.
   │        │       │
   │        │       └── TLD
   │        └────────── Domain
   └──────────────────── Hostname
"@;
Why="Kerberos, AD, Certificates, Browsers, Email — all depend on FQDNs.";
Example="(Windows) hostname /f";
},

# ------------------------------------------------------------
# 3. Root Servers
# ------------------------------------------------------------
@{
Term="Root Servers (.)";
Desc="The root of the entire DNS hierarchy. These 13 logical root servers (hundreds of real servers) know where all top-level domains (.com, .net, .org, etc.) live.";
Analogy="The 'master index' for the entire world’s phonebooks.";
ASCII=@"
                 ┌──────────────┐
                 │    ROOT (.)   │
                 └───────┬──────┘
                         │
          ┌──────────────┼───────────────┐
          ▼              ▼               ▼
      .COM TLD       .NET TLD         .ORG TLD
"@;
Why="Recursive DNS CANNOT function without the root servers.";
Example="Resolve-DnsName . -Type NS";
},

# ------------------------------------------------------------
# 4. TLD
# ------------------------------------------------------------
@{
Term="TLD (Top-Level Domain)";
Desc="The highest level of DNS under the root. Examples: .com, .net, .org, .ca, .io. TLD servers know which authoritative servers host domains beneath them.";
Analogy="The country/region part of a postal address.";
ASCII=@"
ROOT (.)
   │
   ├─ .COM
   ├─ .NET
   ├─ .ORG
   └─ .CA
"@;
Why="Every domain you buy lives under a TLD. All recursion goes through TLD servers.";
Example="Resolve-DnsName com -Type NS";
},

# ------------------------------------------------------------
# 5. Authoritative Server
# ------------------------------------------------------------
@{
Term="Authoritative DNS Server";
Desc="A DNS server that holds the actual zone file and can give the final answer for a domain.";
Analogy="The 'official government record office' for a domain.";
ASCII=@"
┌──────────────────────────────┐
│  AUTHORITATIVE DNS SERVER    │
│   Holds zone: dave.com       │
└──────────────────────────────┘
       │   │   │
       A   MX  TXT   ← Records live HERE
"@;
Why="All DNS answers ultimately come from authoritative servers.";
Example="Resolve-DnsName microsoft.com -Type SOA";
},

# ------------------------------------------------------------
# 6. Recursive Resolver
# ------------------------------------------------------------
@{
Term="Recursive Resolver (Local DNS Server)";
Desc="Your workstation’s DNS server — does all the heavy lifting by contacting the root, TLD, and authoritative servers on your behalf.";
Analogy="A librarian who goes and finds the right book for you instead of you searching the whole library.";
ASCII=@"
CLIENT 
  │
  ▼
┌────────────────────┐
│  RECURSIVE DNS     │
└────────────────────┘
  │    │    │
Root → TLD → Authoritative
"@;
Why="Your device almost never contacts the internet directly — this server does it.";
Example="Get-DnsClientServerAddress";
},

# ------------------------------------------------------------
# 7. Zone
# ------------------------------------------------------------
@{
Term="Zone";
Desc="A DNS administrative boundary that stores the DNS records for a domain (dave.com, corp.local, etc.)";
Analogy="A filing cabinet drawer for one specific domain.";
ASCII=@"
┌──────────────────────────────┐
│          DNS SERVER          │
│   ┌──────────────────────┐   │
│   │     ZONE: corp.local │   │
│   └──────────────────────┘   │
└──────────────────────────────┘
"@;
Why="Every domain or subdomain that needs management has its own zone.";
Example="Get-DnsServerZone";
},

# ------------------------------------------------------------
# 8. Zone File
# ------------------------------------------------------------
@{
Term="Zone File";
Desc="The actual file that stores all DNS records for a zone.";
Analogy="The literal phonebook inside the filing cabinet.";
ASCII=@"
┌──────────────────────────────┐
│          DNS SERVER          │
│  ┌────────────────────────┐  │
│  │    ZONE FILE:          │  │
│  │   corp.local.db        │  │
│  │ ─────────────────────  │  │
│  │ A Records              │  │
│  │ CNAME Records          │  │
│  │ MX Records             │  │
│  └────────────────────────┘  │
└──────────────────────────────┘
"@;
Why="All DNS answers ultimately come from zone files.";
Example="Linux: /var/named/db.corp.local";
},

# ------------------------------------------------------------
# 9. Forward Lookup Zone
# ------------------------------------------------------------
@{
Term="Forward Lookup Zone";
Desc="Resolves hostnames → IP addresses.";
Analogy="'Dave → 555-1234' in a phonebook.";
ASCII=@"
www.checkyourlogs.net  →  203.0.113.10
"@;
Why="Most DNS traffic on Earth is forward lookups.";
Example="Resolve-DnsName www.microsoft.com -Type A";
},

# ------------------------------------------------------------
# 10. Reverse Lookup Zone
# ------------------------------------------------------------
@{
Term="Reverse Lookup Zone";
Desc="Resolves IP address → hostname. Uses in-addr.arpa or ip6.arpa zones.";
Analogy="Phone number → person's name.";
ASCII=@"
203.0.113.10 → www.checkyourlogs.net
"@;
Why="Used heavily in security logs, email servers, reverse lookups.";
Example="Resolve-DnsName 8.8.8.8";
},

# ------------------------------------------------------------
# 11. SOA
# ------------------------------------------------------------
@{
Term="SOA (Start of Authority)";
Desc="The first record in every DNS zone. Identifies the zone owner, contact, primary nameserver, and zone serial used for replication.";
Analogy="The cover page of a book with version number.";
ASCII=@"
┌────────── SOA RECORD ─────────┐
│ Primary NS: ns1.corp.local    │
│ Serial    : 2025010101        │
│ Refresh   : 900               │
└───────────────────────────────┘
"@;
Why="Critical for zone replication, AD, and DNS integrity.";
Example="Resolve-DnsName corp.local -Type SOA";
},

# ------------------------------------------------------------
# 12. NS
# ------------------------------------------------------------
@{
Term="NS (Name Server Record)";
Desc="Lists which servers are authoritative for the zone.";
Analogy="Which office holds the official records.";
ASCII=@"
corp.local
   │
   ├─ NS → ns1.corp.local
   └─ NS → ns2.corp.local
"@;
Why="Used for delegation and authoritative resolution.";
Example="Resolve-DnsName corp.local -Type NS";
},

# ------------------------------------------------------------
# 13. A Record
# ------------------------------------------------------------
@{
Term="A Record";
Desc="Maps hostname → IPv4 address.";
Analogy="Person → phone number.";
ASCII=@"
┌─────────────────────┐
│  www                │
└────────┬────────────┘
         ▼
  203.0.113.10
"@;
Why="Most common DNS record in existence.";
Example="Resolve-DnsName www.microsoft.com -Type A";
},

# ------------------------------------------------------------
# 14. AAAA Record
# ------------------------------------------------------------
@{
Term="AAAA Record";
Desc="Maps hostname → IPv6 address.";
Analogy="Same phonebook, new number format.";
ASCII=@"
www
  ↓
2606:2800:220:1:248:1893:25c8:1946
"@;
Why="IPv6 is widely used even if admins aren't aware of it.";
Example="Resolve-DnsName google.com -Type AAAA";
},

# ------------------------------------------------------------
# 15. CNAME
# ------------------------------------------------------------
@{
Term="CNAME (Alias)";
Desc="Alias of another hostname — points to a canonical name.";
Analogy="A nickname pointing to a real name.";
ASCII=@"
intranet
   │
   ▼
web01.corp.local
"@;
Why="Used for SaaS, load balancers, flexible naming.";
Example="Resolve-DnsName intranet.corp.local";
},

# ------------------------------------------------------------
# 16. MX
# ------------------------------------------------------------
@{
Term="MX (Mail Exchanger)";
Desc="Specifies the mail server(s) responsible for accepting email for a domain.";
Analogy="Central mail sorting depot.";
ASCII=@"
checkyourlogs.net
  MX → mail.protection.outlook.com
"@;
Why="Break MX = break email.";
Example="Resolve-DnsName checkyourlogs.net -Type MX";
},

# ------------------------------------------------------------
# 17. SRV
# ------------------------------------------------------------
@{
Term="SRV Record";
Desc="Service locator record — maps services to hosts/ports.";
Analogy="Yellow Pages for services.";
ASCII=@"
_ldap._tcp.dc._msdcs.corp.local
 → dc01.corp.local:389
"@;
Why="Absolutely required for Active Directory.";
Example="Resolve-DnsName _ldap._tcp.dc._msdcs.corp.local -Type SRV";
},

# ------------------------------------------------------------
# 18. PTR
# ------------------------------------------------------------
@{
Term="PTR (Reverse Lookup)";
Desc="IP to hostname lookup.";
Analogy="Reverse phone lookup.";
ASCII=@"
10.10.10.50 → fileserver01.corp.local
"@;
Why="Email reputation, SIEM logs, firewalls rely on it.";
Example="Resolve-DnsName 10.10.10.50 -Type PTR";
},

# ------------------------------------------------------------
# 19. TXT
# ------------------------------------------------------------
@{
Term="TXT Record";
Desc="Flexible text record. Used for SPF, DKIM, DMARC, Google/M365 verification.";
Analogy="Sticky notes left inside the phonebook.";
ASCII=@"
checkyourlogs.net TXT "MS=ms1234567"
"@;
Why="Used everywhere in cloud identity/email world.";
Example="Resolve-DnsName checkyourlogs.net -Type TXT";
},

# ------------------------------------------------------------
# 20. DNS Cache
# ------------------------------------------------------------
@{
Term="DNS Cache";
Desc="Temporary local and server-side storage of DNS answers.";
Analogy="Memory of recently dialed phone numbers.";
ASCII=@"
CLIENT
  └─ DNS CACHE (speeds up repeat lookups)
"@;
Why="Improves performance but causes stale records sometimes.";
Example="ipconfig /displaydns";
},

# ------------------------------------------------------------
# 21. Root Hints
# ------------------------------------------------------------
@{
Term="Root Hints";
Desc="List of root servers used by recursive resolvers to find TLDs.";
Analogy="GPS coordinates of the internet.";
ASCII=@"
LOCAL DNS
   ↓
(ROOT HINTS)
   ↓
ROOT SERVERS
"@;
Why="If root hints are corrupt → no external DNS resolution.";
Example="Get-DnsServerRootHint";
},

# ------------------------------------------------------------
# 22. Forwarder
# ------------------------------------------------------------
@{
Term="Forwarder";
Desc="DNS server your recursive resolver forwards unanswered queries to.";
Analogy="Your librarian asks another librarian for harder questions.";
ASCII=@"
CLIENT → LOCAL DNS → ISP DNS → INTERNET
"@;
Why="Controls traffic paths in enterprise networking.";
Example="Get-DnsServerForwarder";
},

# ------------------------------------------------------------
# 23. Conditional Forwarder
# ------------------------------------------------------------
@{
Term="Conditional Forwarder";
Desc="Forward only specific domains to specific DNS servers.";
Analogy="Ask THIS librarian only about THIS topic.";
ASCII=@"
partner.com → 10.20.30.40
"@;
Why="Used for mergers, multi-cloud, hybrid, cross-org setups.";
Example="Add-DnsServerConditionalForwarderZone -Name partner.com -MasterServers 10.20.30.40";
},

# ------------------------------------------------------------
# 24. DNSSEC
# ------------------------------------------------------------
@{
Term="DNSSEC";
Desc="Cryptographic signing of DNS records to ensure integrity and prevent spoofing.";
Analogy="Tamper-proof seals on official documents.";
ASCII=@"
Record + Signature (RRSIG)
   │
   ▼
Client validates with DNSKEY
"@;
Why="Protects against MITM attacks and cache poisoning.";
Example="Resolve-DnsName cloudflare.com -DnssecOk";
},

# ------------------------------------------------------------
# 25. TTL
# ------------------------------------------------------------
@{
Term="TTL (Time To Live)";
Desc="How long a DNS record stays in cache before it must be refreshed.";
Analogy="Expiration date on milk.";
ASCII=@"
Record:
  A=203.0.113.10
  TTL=3600 seconds (1 hour)
"@;
Why="Controls propagation time and caching efficiency.";
Example="(Resolve-DnsName checkyourlogs.net).TTL";
}

)


function Show-DNSTermsTeaching {
    foreach ($t in $Global:DNS_Terms) {
        Clear-Host
        Write-Host "=== DNS 101 TERM: $($t.Term) ===" -ForegroundColor Cyan
        Write-Host "`nDefinition: $($t.Desc)" -ForegroundColor Green
        Write-Host "`nAnalogy: $($t.Analogy)" -ForegroundColor Yellow
        Write-Host "`nASCII Diagram:" -ForegroundColor Cyan
        Write-Host $t.ASCII -ForegroundColor White
        Write-Host "`nWhy it matters: $($t.Why)" -ForegroundColor Green
        Write-Host "`nExample:" -ForegroundColor Yellow
        Write-Host "  $($t.Example)"
        Read-Host "`nPress ENTER to continue"
        Instructor-Sleep
    }
    pause
}

function Show-DNSTermsQuick {
    Clear-Host
    Write-Host "=== DNS 101 QUICK REFERENCE ===" -ForegroundColor Cyan
    foreach ($t in $Global:DNS_Terms) {
        Write-Host ("{0,-18} : {1}" -f $t.Term, $t.Desc) -ForegroundColor Green
    }
    pause
}

function Show-DNSTermsQuiz {
    $items = $Global:DNS_Terms | Sort-Object {Get-Random}
    foreach ($q in $items) {
        Clear-Host
        Write-Host "Definition: $($q.Desc)" -ForegroundColor Yellow
        $opts = $Global:DNS_Terms | Sort-Object {Get-Random} | Select-Object -First 3
        if ($opts -notcontains $q) { $opts += $q }
        $opts = $opts | Sort-Object {Get-Random}
        for ($i=0; $i -lt $opts.Count; $i++) {
            Write-Host "[$($i+1)] $($opts[$i].Term)" -ForegroundColor Green
        }
        $ans = Read-Host "Your Answer"
        if ($opts[[int]$ans-1].Term -eq $q.Term) {
            Write-Host "Correct!" -ForegroundColor Green
        } else {
            Write-Host "Incorrect — correct: $($q.Term)" -ForegroundColor Red
        }
        Instructor-Sleep
    }
    pause
}

function Show-DNSTermsMenu {
    do {
        Clear-Host
        Write-Host "=== DNS 101 – TOP 25 TERMS ===" -ForegroundColor Cyan

@"
[1] Teaching Mode
[2] Quick Reference
[3] Quiz Mode
[Q] Back
"@ | Write-Host -ForegroundColor Green

        switch (Read-Host "Choose") {
            "1" { Show-DNSTermsTeaching }
            "2" { Show-DNSTermsQuick }
            "3" { Show-DNSTermsQuiz }
            "Q" { return }
        }
    } while ($true)
}






# ============================================================
# DNS 201 – Intermediate Concepts
# ============================================================

$Global:DNS201_Terms = @(

# ====================================================================
# 1. GLUE RECORD
# ====================================================================
@{
Term="Glue Record";
Desc="A glue record is an A/AAAA record placed in the parent zone (checkyourlogs.net) that provides the IP address of a child zone’s nameservers (ns1.sub.checkyourlogs.net). Without glue, resolvers enter a circular dependency and cannot reach the delegated child zone.";
Analogy="Imagine a city's phonebook listing a branch office in another city — but you need that office’s address before you can request their book. Glue is the little note in the parent directory giving you the branch office’s address.";
ASCII=@"
DELEGATION WITHOUT GLUE = LOOP

Parent Zone (checkyourlogs.net)
   NS → ns1.sub.checkyourlogs.net
   NS → ns2.sub.checkyourlogs.net

Need IP for ns1.sub…
  → Must query sub.checkyourlogs.net
But to query sub.checkyourlogs.net…
  → Need IP for ns1.sub!

DELEGATION WITH GLUE (WORKS)

Parent Zone:
   ns1.sub.checkyourlogs.net A 203.0.113.10
   ns2.sub.checkyourlogs.net A 203.0.113.20

Child Zone reachable via glue.
"@;
Why="Without glue, DNS cannot resolve subdomains whose NS records live inside themselves.";
Example="Resolve-DnsName ns1.sub.checkyourlogs.net";
},

# ====================================================================
# 2. DELEGATION
# ====================================================================
@{
Term="Delegation";
Desc="Delegation occurs when a parent zone assigns responsibility for a subdomain to another set of nameservers. The parent holds only NS + Glue, while the child zone hosts its full DNS data.";
Analogy="Like a parent company giving a regional office the authority to manage everything in their area — the parent only provides directions, not the actual records.";
ASCII=@"
┌──────────────────────────┐
│  PARENT: checkyourlogs.net      │
│   NS → ns1.sub.example    │
│   NS → ns2.sub.example    │
└──────────────┬───────────┘
               │ Delegation
               ▼
┌──────────────────────────┐
│  CHILD: sub.checkyourlogs.net   │
│   A / MX / SRV / TXT ...  │
└──────────────────────────┘
"@;
Why="Delegation allows DNS to scale globally by distributing zones.";
Example="Resolve-DnsName sub.checkyourlogs.net -Type NS";
},

# ====================================================================
# 3. EDNS
# ====================================================================
@{
Term="EDNS (Extension Mechanisms for DNS)";
Desc="Upgrades DNS beyond its 1980s limits by allowing larger messages (over 512 bytes), attaching extra metadata via OPT records, and enabling DNSSEC.";
Analogy="DNS originally spoke in tiny sticky notes. EDNS is like giving DNS a full-sized notepad and the ability to attach post-it tabs.";
ASCII=@"
Classic DNS: 512-byte UDP limit

EDNS:
  + Larger UDP packets (~4096 bytes)
  + OPT pseudo-record
  + Needed for DNSSEC

┌─────────────┐
│ DNS HEADER   │
│ + OPT(EDNS)  │
└─────────────┘
"@;
Why="Modern DNS breaks without EDNS — DNSSEC replies would overflow.";
Example="Resolve-DnsName cloudflare.com -EDnsSecOk";
},

# ====================================================================
# 4. NEGATIVE CACHING
# ====================================================================
@{
Term="Negative Caching";
Desc="DNS temporarily caches failed lookups. Responses like NXDOMAIN are stored for a TTL to avoid flooding servers with the same bad query.";
Analogy="You call a restaurant and they say: 'We’re closed today.' For a while you trust that answer before trying again.";
ASCII=@"
Query: no-such-host
Response: NXDOMAIN
Cache: 'Does NOT exist' for TTL seconds
"@;
Why="Speeds failures but delays recognizing newly added hosts.";
Example="ipconfig /displaydns";
},

# ====================================================================
# 5. STUB ZONE
# ====================================================================
@{
Term="Stub Zone";
Desc="A zone containing ONLY NS (and glue) records for another zone. It is not a full copy; rather, a reference pointer.";
Analogy="A table of contents entry pointing you to another book — but not containing any chapters.";
ASCII=@"
DNS SERVER
┌────────────────────────────┐
│   STUB ZONE: partner.com   │
│     NS → ns1.partner.com   │
│     NS → ns2.partner.com   │
└────────────────────────────┘

(Real records live at partner's DNS)
"@;
Why="Useful in AD multi-domain/forest setups where cross-lookup is needed.";
Example="Add-DnsServerStubZone -Name partner.com -MasterServers 10.20.30.40";
},

# ====================================================================
# 6. FORWARD-ONLY RESOLVER
# ====================================================================
@{
Term="Forward-Only Resolver";
Desc="A DNS server configured to never perform recursion — instead it forwards all requests to designated forwarders.";
Analogy="A librarian who refuses to search shelves and instead calls a central hotline for every question.";
ASCII=@"
Client → Local DNS
           │
           ▼
     Forwarders Only
"@;
Why="Centralizes recursion and reduces attack surface on branch DNS servers.";
Example="Set-DnsServerRecursion -Enable $false";
},

# ====================================================================
# 7. DNS OVER HTTPS (DoH)
# ====================================================================
@{
Term="DNS over HTTPS (DoH)";
Desc="Encapsulates DNS queries inside regular HTTPS traffic, hiding them from inspection and giving privacy.";
Analogy="Whispering DNS questions inside a private encrypted chat instead of shouting across a room.";
ASCII=@"
Client
  │
  ▼
HTTPS 443
  │
  ▼
DNS Query Inside TLS
"@;
Why="Prevents ISP snooping but bypasses enterprise DNS filtering.";
Example="Firefox: Enable DoH in settings";
},

# ====================================================================
# 8. DNS OVER TLS (DoT)
# ====================================================================
@{
Term="DNS over TLS (DoT)";
Desc="DNS encrypted using TLS over port 853. Unlike DoH, the traffic is identifiable as DNS.";
Analogy="A secure private phone line dedicated to DNS communication.";
ASCII=@"
Client → TLS/853 → DNS Resolver
"@;
Why="Balances privacy with enterprise visibility.";
Example="dig +tls=generic checkyourlogs.net";
},

# ====================================================================
# 9. DNS OVER QUIC (DoQ)
# ====================================================================
@{
Term="DNS over QUIC (DoQ)";
Desc="A modern DNS transport over QUIC (HTTP/3), improving latency and reliability.";
Analogy="DNS delivered by high-speed express courier instead of postal mail.";
ASCII=@"
Client → QUIC(H3) → Resolver
"@;
Why="Emerging standard for fast, encrypted DNS.";
Example="dig +http3 checkyourlogs.net";
},

# ====================================================================
# 10. AXFR (FULL ZONE TRANSFER)
# ====================================================================
@{
Term="AXFR (Full Zone Transfer)";
Desc="Replicates an entire DNS zone from primary to secondary server.";
Analogy="Photocopying an entire book and mailing it to another office.";
ASCII=@"
PRIMARY DNS
   │
   │ AXFR (FULL COPY)
   ▼
SECONDARY DNS
"@;
Why="Needed for redundancy; must be locked down to prevent zone leaks.";
Example="dig AXFR checkyourlogs.net @ns1.checkyourlogs.net";
},

# ====================================================================
# 11. IXFR (INCREMENTAL ZONE TRANSFER)
# ====================================================================
@{
Term="IXFR (Incremental Zone Transfer)";
Desc="Transfers only changed DNS records since the last zone transfer.";
Analogy="Sending only updated pages of a book instead of printing the entire thing again.";
ASCII=@"
PRIMARY DNS
   │
   │ IXFR (CHANGES ONLY)
   ▼
SECONDARY DNS
"@;
Why="Critical for large Active Directory-integrated DNS zones.";
Example="dnscmd /zoneupdatefromds checkyourlogs.net";
},

# ====================================================================
# 12. ANYCAST DNS
# ====================================================================
@{
Term="Anycast DNS";
Desc="Multiple DNS servers share a single IP; routing automatically sends users to the geographically closest server.";
Analogy="Calling one customer support number but always reaching the nearest office.";
ASCII=@"
             Same IP
     ┌────────┬────────┬────────┐
     ▼        ▼        ▼        ▼
 EU Server  US Server  APAC     LATAM
"@;
Why="Huge latency improvements and global resilience. Used by Cloudflare, Google, Quad9.";
Example="nslookup 1.1.1.1";
},

# ====================================================================
# 13. GEODNS
# ====================================================================
@{
Term="GeoDNS";
Desc="DNS provides different answers based on requester location.";
Analogy="MacDonalds routing you to the nearest restaurant based on your city.";
ASCII=@"
EU → eu-web.checkyourlogs.net
US → us-web.checkyourlogs.net
AS → asia-web.checkyourlogs.net
"@;
Why="Used by CDNs for distributing load and optimizing user experience.";
Example="Resolve-DnsName cdn.cloudflare.net";
},

# ====================================================================
# 14. DNS AMPLIFICATION ATTACK
# ====================================================================
@{
Term="DNS Amplification Attack";
Desc="A DDoS attack using spoofed-source queries to open resolvers, causing large DNS responses to flood a victim.";
Analogy="Sending a tiny whisper into a stadium loudspeaker pointed at someone else.";
ASCII=@"
Attacker → Open Resolver
              │
              ▼
        HUGE RESPONSE → Victim
"@;
Why="Extremely destructive; recursive DNS must be locked down.";
Example="Use external open resolver scanners (e.g. internet.nl)";
},

# ====================================================================
# 15. DNS POISONING
# ====================================================================
@{
Term="DNS Poisoning";
Desc="Maliciously injecting false DNS data into caches so users are redirected to attacker-controlled IPs.";
Analogy="Someone swapping phonebook pages so you dial a scammer instead of the real business.";
ASCII=@"
Original : bank.com → 203.0.113.10
Poisoned : bank.com → 6.6.6.6
"@;
Why="Enables phishing, malware, and man-in-the-middle attacks.";
Example="Monitor for sudden, unauthorized DNS changes.";
},

# ====================================================================
# 16. DNS TUNNELING
# ====================================================================
@{
Term="DNS Tunneling";
Desc="Technique for covertly smuggling data inside DNS queries, often to bypass firewalls.";
Analogy="Hiding secret letters inside envelopes that appear to be normal mail.";
ASCII=@"
Malware → TXT query:
   aGVsbG8uaGFja2VyLmNvbQ==
"@;
Why="Used by APTs, malware, and red teams; must be detectable.";
Example="Hunt for long TXT queries in DNS logs.";
},

# ====================================================================
# 17. CAA RECORD
# ====================================================================
@{
Term="CAA Record";
Desc="Defines which Certificate Authorities (CAs) are allowed to issue certificates for the domain.";
Analogy="House rules specifying which locksmith is allowed to make keys to your house.";
ASCII=@"
checkyourlogs.net CAA 0 issue ""letsencrypt.org""
"@;
Why="Prevents unauthorized certificate issuance.";
Example="Resolve-DnsName checkyourlogs.net -Type CAA";
},

# ====================================================================
# 18. SPF
# ====================================================================
@{
Term="SPF (Sender Policy Framework)";
Desc="TXT record listing which hosts/IPs are allowed to send email for a domain.";
Analogy="A bouncer’s guest list — if you're not on it, you’re not getting in.";
ASCII=@"
checkyourlogs.net TXT:
  ""v=spf1 include:spf.protection.outlook.com -all""
"@;
Why="Prevents sender address spoofing.";
Example="Resolve-DnsName checkyourlogs.net -Type TXT | Select-String spf";
},

# ====================================================================
# 19. DKIM
# ====================================================================
@{
Term="DKIM";
Desc="Digitally signs outbound email using a private key; public key is stored in DNS for verification.";
Analogy="Applying a tamper-proof wax seal to outgoing letters.";
ASCII=@"
selector1._domainkey.checkyourlogs.net TXT (public key)
"@;
Why="Ensures email authenticity and message integrity.";
Example="Resolve-DnsName selector1._domainkey.checkyourlogs.net -Type TXT";
},

# ====================================================================
# 20. DMARC
# ====================================================================
@{
Term="DMARC";
Desc="Specifies what to do when SPF/DKIM validation fails and provides reporting about domain abuse.";
Analogy="Instructions to bouncers about what to do with fake IDs, plus sending daily incident reports.";
ASCII=@"
_dmarc.checkyourlogs.net TXT:
  ""v=DMARC1; p=quarantine; rua=mailto:reports@checkyourlogs.net""
"@;
Why="Adds policy + reporting to email authentication. Critical for phishing defense.";
Example="Resolve-DnsName _dmarc.checkyourlogs.net -Type TXT";
}

)



function Show-DNS201Teaching {
    foreach ($t in $Global:DNS201_Terms) {
        Clear-Host
        Write-Host "=== DNS 201 TERM: $($t.Term) ===" -ForegroundColor Cyan
        Write-Host "`nDefinition: $($t.Desc)" -ForegroundColor Green
        Write-Host "`nASCII Diagram:" -ForegroundColor Yellow
        Write-Host $t.ASCII -ForegroundColor White
        Write-Host "`nWhy it matters: $($t.Why)" -ForegroundColor Green
        Read-Host "`nPress ENTER for next term"
        Instructor-Sleep
    }
    pause
}

function Show-DNS201Quick {
    Clear-Host
    Write-Host "=== DNS 201 QUICK REFERENCE ===" -ForegroundColor Cyan
    foreach ($t in $Global:DNS201_Terms) {
        Write-Host ("{0,-20} : {1}" -f $t.Term, $t.Desc) -ForegroundColor Green
    }
    pause
}

function Show-DNS201Quiz {
    $items = $Global:DNS201_Terms | Sort-Object {Get-Random}
    foreach ($q in $items) {
        Clear-Host
        Write-Host "Definition: $($q.Desc)" -ForegroundColor Yellow
        $opts = $Global:DNS201_Terms | Sort-Object {Get-Random} | Select-Object -First 3
        if ($opts -notcontains $q) { $opts += $q }
        $opts = $opts | Sort-Object {Get-Random}
        Write-Host ""
        for ($i=0; $i -lt $opts.Count; $i++) {
            Write-Host "[$($i+1)] $($opts[$i].Term)" -ForegroundColor Green
        }
        $ans = Read-Host "Your Answer"
        if ($ans -match '^\d+$' -and $opts[[int]$ans-1].Term -eq $q.Term) {
            Write-Host "Correct!" -ForegroundColor Green
        } else {
            Write-Host "Wrong — correct: $($q.Term)" -ForegroundColor Red
        }
        Instructor-Sleep
    }
    pause
}

function Show-DNS201Menu {
    do {
        Clear-Host
        Write-Host "=== DNS 201 – Intermediate Concepts ===" -ForegroundColor Cyan

@"
[1] Teaching Mode
[2] Quick Reference
[3] Quiz Mode
[Q] Back
"@ | Write-Host -ForegroundColor Green

        $opt = Read-Host "Choose"

        switch ($opt) {
            "1" { Show-DNS201Teaching }
            "2" { Show-DNS201Quick }
            "3" { Show-DNS201Quiz }
            "Q" { return }
            "q" { return }
        }
    } while ($true)
}

# ============================================================
# Instructor Mode Toggle
# ============================================================

function Toggle-InstructorMode {
    $Global:InstructorMode = -not $Global:InstructorMode
    if ($Global:InstructorMode) {
        Write-Host "Instructor Mode ENABLED – slower pacing, better for teaching." -ForegroundColor Cyan
    } else {
        Write-Host "Instructor Mode DISABLED." -ForegroundColor Green
    }
    pause
}

# ============================================================
# Cheat Sheet Exporter
# ============================================================

function Export-DNSCheatSheets {

    $path101 = Join-Path $env:TEMP "DNS101-CheatSheet.txt"
    $path201 = Join-Path $env:TEMP "DNS201-CheatSheet.txt"

    "DNS 101 – Top 25 Terms`r`n" | Out-File $path101 -Encoding UTF8
    foreach ($t in $Global:DNS_Terms) {
        "$($t.Term): $($t.Desc)" | Out-File $path101 -Append -Encoding UTF8
    }

    "DNS 201 – Intermediate Terms`r`n" | Out-File $path201 -Encoding UTF8
    foreach ($t in $Global:DNS201_Terms) {
        "$($t.Term): $($t.Desc)" | Out-File $path201 -Append -Encoding UTF8
    }

    Write-Host "Exported cheat sheets:" -ForegroundColor Cyan
    Write-Host "  $path101" -ForegroundColor Green
    Write-Host "  $path201" -ForegroundColor Green

    pause
}

# ============================================================
# DNS Labs Generator
# ============================================================

function Show-DNSLabsGenerator {
    Clear-Host
    Write-Host "=== DNS LABS GENERATOR ===" -ForegroundColor Cyan

    $labs = @(
        "Lab 1: Resolve a domain and identify its TLD using Resolve-DnsName.",
        "Lab 2: Find NS and SOA for your favorite public domain.",
        "Lab 3: Conceptually add a TXT record for M365 verification and explain the flow.",
        "Lab 4: Conceptually create a CNAME chain and explain resolution.",
        "Lab 5: Look at TTL values and discuss propagation impact.",
        "Lab 6: Query PTR for an IP and interpret the result.",
        "Lab 7: Draw an ASCII diagram of zone delegation.",
        "Lab 8: Compare a recursive resolver and an authoritative resolver output.",
        "Lab 9: Inspect DNSSEC data (DNSKEY/RRSIG) for a known signed domain.",
        "Lab 10: Whiteboard the full DNS path for logging into M365 using a custom domain."
    )

    foreach ($lab in $labs) {
        Write-Host $lab -ForegroundColor Green
    }

    pause
}

# ============================================================
# DNS Quiz Master (Beginner / Intermediate / Expert)
# ============================================================

function Show-DNSQuizMaster {
    do {
        Clear-Host
        Write-Host "=== DNS QUIZ MASTER ===" -ForegroundColor Cyan

@"
[1] Beginner (DNS 101)
[2] Intermediate (DNS 201)
[3] Expert (Mixed, timed)
[Q] Back
"@ | Write-Host -ForegroundColor Green

        $opt = Read-Host "Choose difficulty"

        switch ($opt) {
            "1" { Show-DNSTermsQuiz }
            "2" { Show-DNS201Quiz }
            "3" { Show-DNSQuizExpert }
            "Q" { return }
            "q" { return }
        }
    } while ($true)
}

function Show-DNSQuizExpert {
    Clear-Host
    Write-Host "=== EXPERT DNS QUIZ ===" -ForegroundColor Red

    $all = $Global:DNS_Terms + $Global:DNS201_Terms
    $questions = $all | Sort-Object {Get-Random}

    $score = 0
    $max = 10

    foreach ($t in ($questions | Select-Object -First $max)) {
        Clear-Host
        Write-Host "Timed Question:" -ForegroundColor Yellow
        Write-Host "Definition: $($t.Desc)"
        Write-Host ""

        $opts = $all | Sort-Object {Get-Random} | Select-Object -First 3
        if ($opts -notcontains $t) { $opts += $t }
        $opts = $opts | Sort-Object {Get-Random}

        for ($i=0; $i -lt $opts.Count; $i++) {
            Write-Host "[$($i+1)] $($opts[$i].Term)" -ForegroundColor Green
        }

        $start = Get-Date
        $ans = Read-Host "Your answer (10 seconds)"
        $elapsed = ((Get-Date) - $start).TotalSeconds

        if ($elapsed -gt 10) {
            Write-Host "❌ Too slow — time exceeded." -ForegroundColor Red
        } elseif ($ans -match '^\d+$' -and $opts[[int]$ans-1].Term -eq $t.Term) {
            Write-Host "Correct!" -ForegroundColor Green
            $score++
        } else {
            Write-Host "Wrong — correct answer: $($t.Term)" -ForegroundColor Red
        }

        Start-Sleep -Milliseconds 900
    }

    Write-Host "`nFinal Score: $score / $max" -ForegroundColor Cyan
    pause
}

# ============================================================
# Theme Selector (basic)
# ============================================================

function Show-DNSThemeSelector {
    do {
        Clear-Host
        Write-Host "=== DNS THEME SELECTOR ===" -ForegroundColor Cyan

@"
Current Theme: $($Global:Theme)

[1] Matrix Green
[2] Amber CRT
[3] Ice Blue
[Q] Back
"@ | Write-Host -ForegroundColor Green

        $opt = Read-Host "Choose theme"

        switch ($opt) {
            "1" { $Global:Theme="Green"; Write-Host "Theme set to Matrix Green." -ForegroundColor Green }
            "2" { $Global:Theme="Amber"; Write-Host "Theme set to Amber CRT." -ForegroundColor Yellow }
            "3" { $Global:Theme="Blue";  Write-Host "Theme set to Ice Blue." -ForegroundColor Cyan }
            "Q" { return }
            "q" { return }
        }

        pause
    } while ($true)
}

# ============================================================
# DNS HANDS-ON LAB GENERATOR (CLIENT-ONLY + INSTRUCTOR MODE)
# ============================================================

function Show-DNSLabsMenu {
    do {
        Clear-Host
        Write-Host "=== DNS HANDS-ON LAB GENERATOR ===" -ForegroundColor Cyan

@"
[1] Student Mode (View labs & follow manually)
[2] Instructor Mode (Auto-walkthrough with talking points)
[Q] Back to Training Suite
"@ | Write-Host -ForegroundColor Green

        $c = Read-Host "Choose"

        switch ($c) {
            "1" { Show-DNSLabsStudent }
            "2" { Show-DNSLabsInstructor }
            "Q" { return }
            "q" { return }
        }

    } while ($true)
}

# ============================================================
# STUDENT MODE MODULE
# ============================================================

function Show-DNSLabsStudent {

    $labs = Get-DNSLabDefinitions

    foreach ($lab in $labs) {
        Clear-Host
        Write-Host $lab.Title -ForegroundColor Cyan
        Write-Host "`nOverview:" -ForegroundColor Yellow
        Write-Host "  $($lab.Overview)"
        Write-Host "`nObjectives:" -ForegroundColor Yellow
        $lab.Objectives | ForEach-Object { Write-Host "  - $_" }
        Write-Host "`nSteps:" -ForegroundColor Yellow
        $lab.Steps | ForEach-Object { Write-Host "  $_" }
        Write-Host "`nASCII Diagram:" -ForegroundColor Yellow
        Write-Host $lab.ASCII -ForegroundColor White
        Write-Host "`nExpected Output:" -ForegroundColor Yellow
        $lab.Expected | ForEach-Object { Write-Host "  $_" }
        pause
    }

    pause
}

# ============================================================
# INSTRUCTOR MODE MODULE
# ============================================================

function Show-DNSLabsInstructor {

    $labs = Get-DNSLabDefinitions

    foreach ($lab in $labs) {

        Clear-Host
        Write-Host "=== INSTRUCTOR WALKTHROUGH ===" -ForegroundColor Cyan
        Write-Host $lab.Title -ForegroundColor Yellow
        Instructor-Sleep

        # TALKING POINTS
        Write-Host "`n=== TALKING POINTS ===" -ForegroundColor Magenta
        foreach ($tp in $lab.TalkingPoints) {
            Write-Host ("  🗣  " + $tp) -ForegroundColor White
            Instructor-Sleep
        }

        # COMMAND EXECUTION
        Write-Host "`n=== RUNNING LAB COMMANDS ===" -ForegroundColor Cyan

        foreach ($cmd in $lab.Commands) {

            Write-Host ""
            Write-Host ("▶ Running: " + $cmd) -ForegroundColor Green
            Instructor-Sleep

            # Safety check – block destructive commands
            if ($cmd -match '^(Add-|Set-|Remove-|Restart-|New-|Clear-|Disable-|Enable-|Start-|Stop)') {
                Write-Host "⚠ Command blocked for safety in Instructor Mode." -ForegroundColor Red
                Write-Host "(Teaching display only – not executed.)" -ForegroundColor DarkGray
                Instructor-Sleep
                continue
            }

            try {

                # Execute safe commands and capture output
                $output = Invoke-Expression $cmd 2>&1

                Write-Host "`n--- OUTPUT START ---" -ForegroundColor DarkCyan
                if ($output) {
                    $output | Out-String | Write-Host -ForegroundColor White
                } else {
                    Write-Host "(No output returned)" -ForegroundColor DarkGray
                }
                Write-Host "--- OUTPUT END ---`n" -ForegroundColor DarkCyan

            } catch {
                Write-Host "❌ Error executing command:" -ForegroundColor Red
                Write-Host $_.Exception.Message -ForegroundColor DarkRed
            }

            Instructor-Sleep
            Write-Host "Press ENTER to continue…" -ForegroundColor Yellow
            Read-Host | Out-Null
        }

        # ASCII DIAGRAM
        Write-Host "`n=== ASCII DIAGRAM ===" -ForegroundColor Yellow
        Write-Host $lab.ASCII -ForegroundColor White

        Write-Host "`nPress ENTER for next lab…" -ForegroundColor Cyan
        Read-Host | Out-Null
    }

    pause
}


# ============================================================
# LAB DEFINITIONS (CLIENT-SIDE SAFE)
# ============================================================

function Get-DNSLabDefinitions {

    return @(

@{
Title="LAB 1 — DNS Resolution Path (Root → TLD → Authoritative)";
Overview="Learn how DNS recursion flows from your client to the root, TLD, and authoritative servers.";
Objectives=@(
    "Understand recursive resolution",
    "Identify NS and SOA records",
    "Interpret Resolve-DnsName output"
);
Steps=@(
    "1. Run: Resolve-DnsName microsoft.com -Debug",
    "2. Identify the Root → TLD → Auth chain",
    "3. Find the SOA and NS",
    "4. Draw the resolution flow"
);
ASCII=@"
CLIENT
  │
  ▼
LOCAL DNS
  │
  ▼
ROOT (.)
  │
  ▼
TLD (.com)
  │
  ▼
AUTHORITATIVE SERVER
  │
  ▼
ANSWER
"@;
Expected=@(
    "You can explain each hop of recursive resolution.",
    "You can identify which server is authoritative."
);
TalkingPoints=@(
    "Recursion is done by your DNS server, not the client.",
    "Root servers never give final answers — only referrals.",
    "Authoritative servers own the zone file."
);
Commands=@(
    "Resolve-DnsName microsoft.com -Debug",
    "Resolve-DnsName microsoft.com -Type SOA",
    "Resolve-DnsName microsoft.com -Type NS"
);
},

# --------------------------------------------------------------------
@{
Title="LAB 2 — Explore Real DNS Records for a Domain";
Overview="Identify all critical DNS records (A, NX, TXT, CAA, SOA).";
Objectives=@(
    "Navigate DNS record types",
    "Interpret TXT for cloud services",
    "Understand zone structure"
);
Steps=@(
    "1. Choose any real domain",
    "2. Query A / MX / TXT / CAA / SOA",
    "3. Identify cloud service indicators",
    "4. Draw the zone file layout"
);
ASCII=@"
┌─────────────────────────────┐
│   AUTHORITATIVE DNS SERVER  │
└─────────────────────────────┘
          │
          ▼
┌─────────────────────────────┐
│  A   AAAA   CNAME   MX      │
│  TXT  CAA   NS      SOA     │
└─────────────────────────────┘
"@;
Expected=@(
    "Student recognizes M365 TXT verification.",
    "Student identifies MX record priorities.",
    "Student explains SOA serial role."
);
TalkingPoints=@(
    "TXT records are critical for M365, DKIM, DMARC.",
    "SPF is just a TXT record — nothing special.",
    "SOA shows zone versioning for replication."
);
Commands=@(
    "Resolve-DnsName checkyourlogs.net -Type MX",
    "Resolve-DnsName checkyourlogs.net -Type TXT",
    "Resolve-DnsName checkyourlogs.net -Type SOA"
);
},

# --------------------------------------------------------------------
@{
Title="LAB 3 — Reverse DNS (PTR)";
Overview="Understand the purpose of reverse lookups and PTR mapping.";
Objectives=@(
    "Learn how reverse zones work",
    "Map IP → hostname",
    "Interpret PTR values in logs"
);
Steps=@(
    "1. Run: Resolve-DnsName 8.8.8.8",
    "2. Observe PTR mapping",
    "3. Draw reverse lookup flow"
);
ASCII=@"
IP Address
   │
   ▼
Reverse Lookup Zone (in-addr.arpa)
   │
   ▼
PTR Record → Hostname
"@;
Expected=@(
    "Student can explain why email servers require PTR.",
    "Student understands in-addr.arpa naming."
);
TalkingPoints=@(
    "PTR is essential for email reputation.",
    "Reverse DNS is NOT always required internally."
);
Commands=@(
    "Resolve-DnsName 8.8.8.8",
    "Resolve-DnsName 1.1.1.1"
);
},

# --------------------------------------------------------------------
@{
Title="LAB 4 — Delegation Walkthrough (Conceptual)";
Overview="See how parent → child zone delegation works, including NS + glue.";
Objectives=@(
    "Understand relationship between parent/child zones",
    "Explain why NS + A (glue) must exist at parent",
    "Read delegation output"
);
Steps=@(
    "1. Query NS for a delegated domain",
    "2. Identify glue records",
    "3. Draw delegation model"
);
ASCII=@"
checkyourlogs.net (parent)
   │
   ├── NS → ns1.dev.checkyourlogs.net
   │         A → 203.0.113.10 (Glue)
   ▼
dev.checkyourlogs.net (child)
"@;
Expected=@(
    "Student explains why glue prevents recursion loops."
);
TalkingPoints=@(
    "Delegation splits administrative responsibility.",
    "Glue lives ONLY in the parent zone."
);
Commands=@(
    "Resolve-DnsName dev.checkyourlogs.net -Type NS",
    "Resolve-DnsName ns1.dev.checkyourlogs.net -Type A"
);
},

# --------------------------------------------------------------------
@{
Title="LAB 5 — DNS Security Concepts (DNSSEC / Poisoning)";
Overview="Conceptual exploration of DNS security risks.";
Objectives=@(
    "Understand DNSSEC chain of trust",
    "Identify poisoning scenarios",
    "Interpret RRSIG/DNSKEY"
);
Steps=@(
    "1. Run: Resolve-DnsName cloudflare.com -DnssecOk",
    "2. Identify RRSIG",
    "3. Identify DNSKEY",
    "4. Explain what an unsigned zone means"
);
ASCII=@"
Root (.) → DS
   │
   ▼
TLD (.com) → DS
   │
   ▼
Zone → DNSKEY + RRSIG
"@;
Expected=@(
    "Student explains DNSSEC validation flow"
);
TalkingPoints=@(
    "DNSSEC prevents tampering, not encryption.",
    "Poisoning is prevented by signed answers."
);
Commands=@(
    "Resolve-DnsName cloudflare.com -Type DNSKEY -DnssecOk",
    "Resolve-DnsName cloudflare.com -Type A -DnssecOk"
);
}

    ) # end labs array
}

# ============================================================
# DNS CACHING & PROPAGATION TRAINER
# ============================================================

function Show-DNSCacheTrainer {

    Clear-Host
    Write-Host "=== DNS CACHING & PROPAGATION TRAINER ===" -ForegroundColor Cyan
    Write-Host "This automated lab demonstrates DNS caching, TTL, propagation delay," -ForegroundColor Yellow
    Write-Host "and why DNS updates on the internet never apply instantly." -ForegroundColor Yellow
    Instructor-Sleep

    # STEP 1: Introduce Concepts
    Write-Host "`nSTEP 1: Understanding DNS Cache Layers" -ForegroundColor Cyan
    Instructor-Sleep

@"
┌─────────────────────────────────────────────────────────────┐
│                   DNS CACHE LAYERS                          │
└─────────────────────────────────────────────────────────────┘

CLIENT (ipconfig /displaydns)
       │
       ▼
LOCAL DNS SERVER CACHE (Microsoft DNS)
       │
       ▼
UPSTREAM / ISP RESOLVER CACHE
       │
       ▼
AUTHORITATIVE DNS SERVER (Final Answer)
"@ | Write-Host -ForegroundColor Green

    Instructor-Sleep

    Write-Host "`nTalking Points:" -ForegroundColor Magenta
    Write-Host " 🗣 Client devices cache answers until TTL expires" -ForegroundColor White
    Write-Host " 🗣 Microsoft DNS servers ALSO cache answers (default 1 hour)" -ForegroundColor White
    Write-Host " 🗣 ISP caches make DNS changes take time to propagate" -ForegroundColor White
    Write-Host " 🗣 TTL controls how long DNS answers live globally" -ForegroundColor White
    Instructor-Sleep

    # STEP 2: Demonstrate local client DNS cache
    Write-Host "`nSTEP 2: Viewing Local Client DNS Cache" -ForegroundColor Cyan
    Instructor-Sleep

    Write-Host "`nRunning: ipconfig /displaydns | more" -ForegroundColor Green
    Start-Sleep -Milliseconds 800

    try {
        $clientCache = ipconfig /displaydns 2>&1
        Write-Host "`n--- CLIENT DNS CACHE START ---" -ForegroundColor DarkCyan
        $clientCache | Out-String | Write-Host -ForegroundColor White
        Write-Host "--- CLIENT DNS CACHE END ---`n" -ForegroundColor DarkCyan
    }
    catch {
        Write-Host "Unable to retrieve client DNS cache." -ForegroundColor Red
    }

    Instructor-Sleep

    # STEP 3: Query a site repeatedly to show caching effect
    $TestDomain = Read-Host "`nEnter a domain to test caching (e.g. microsoft.com)"
    if (-not $TestDomain) { $TestDomain = "microsoft.com" }

    Write-Host "`nSTEP 3: Demonstrating Cached vs Non-Cached Lookup Behavior" -ForegroundColor Cyan
    Instructor-Sleep

@"
ASCII MODEL OF CACHED LOOKUPS

        First Query
CLIENT ──────────────> LOCAL DNS
                        (Cache Miss)
                           │
                           ▼
                      INTERNET ROOT/TLD/AUTH

        Subsequent Queries
CLIENT ──────────────> LOCAL DNS
                        (Cache Hit)
                           │
                           ▼
                     Instant Response
"@ | Write-Host -ForegroundColor Green

    Instructor-Sleep

    Write-Host "`nRunning 3 DNS queries..." -ForegroundColor Yellow
    Instructor-Sleep

    for ($i=1; $i -le 3; $i++) {
        Write-Host "`n[$i] Resolve-DnsName $TestDomain" -ForegroundColor Green
        $result = Resolve-DnsName $TestDomain 2>&1
        $result | Out-String | Write-Host -ForegroundColor White
        Instructor-Sleep
    }

    Write-Host "`nTalking Point:" -ForegroundColor Magenta
    Write-Host " 🗣 Notice how the first query takes longer. The next ones hit cache." -ForegroundColor White
    Instructor-Sleep

    # STEP 4: ASCII explanation of propagation delays
    Write-Host "`nSTEP 4: Why DNS Changes Take Time To Apply" -ForegroundColor Cyan
    Instructor-Sleep

@"
┌─────────────────────────────────────────────────────────────┐
│                TTL & PROPAGATION MODEL                      │
└─────────────────────────────────────────────────────────────┘

        ┌───────────────┐
        │ AUTHORITATIVE │
        │   TTL = 3600  │
        └───────────────┘
               │
               ▼
    ┌───────────────────────┐
    │ ISP / Upstream Cache  │  ← Holds old record for TTL
    └───────────────────────┘
               │
               ▼
    ┌───────────────────────┐
    │ Local DNS Cache       │  ← Stores old or new answer
    └───────────────────────┘
               │
               ▼
    ┌──────────────────────┐
    │ Client Cache (you)   │  ← Holds record the longest
    └──────────────────────┘

    RESULT: DNS CHANGE DELAYS
      - MX record changes: 15–60 minutes
      - TXT changes (M365/Google): 5–30 minutes
      - A record changes: typically 5 min – 1 hour
"@ | Write-Host -ForegroundColor Green

    Instructor-Sleep

    Write-Host "`nTalking Points:" -ForegroundColor Magenta
    Write-Host " 🗣 DNS does NOT push updates — caches expire passively over time" -ForegroundColor White
    Write-Host " 🗣 The longest TTL in the chain determines how fast changes apply" -ForegroundColor White
    Write-Host " 🗣 MX records often cached heavily by upstream resolvers" -ForegroundColor White
    Write-Host " 🗣 Client cache can be flushed: ipconfig /flushdns" -ForegroundColor White
    Instructor-Sleep

    # STEP 5: Show TTL for the chosen record
    Write-Host "`nSTEP 5: Viewing TTL for $TestDomain" -ForegroundColor Cyan
    Instructor-Sleep

    try {
        Write-Host "`nResolve-DnsName $TestDomain | Select-Object Name,TTL" -ForegroundColor Green
        $ttlinfo = Resolve-DnsName $TestDomain | Select-Object Name,TTL
        $ttlinfo | Format-Table | Out-String | Write-Host -ForegroundColor White
    }
    catch {
        Write-Host "Unable to pull TTL info." -ForegroundColor Red
    }

    Instructor-Sleep

    Write-Host "`nDNS Caching Trainer Complete." -ForegroundColor Cyan
    pause
}


# ============================================================
# DNS TRAINING SUITE MASTER MENU
# ============================================================

function Show-DNSTrainingSuiteMenu {
    do {
        Clear-Host
        Write-Host "=== DNS TRAINING SUITE ===" -ForegroundColor Cyan

@"
[1] DNS 101 – Top 25 Terms (Teaching / Quick / Quiz)
[2] DNS 201 – Intermediate Concepts
[3] Instructor Mode (Toggle On/Off)
[4] DNS Cheat Sheet Exporter
[5] DNS Hands-On Lab Generator
[6] DNS Quiz Master (Beginner / Intermediate / Expert)
[7] Theme Selector (Matrix / Amber CRT / Ice Blue)
[8] How DNS Caching works
[Q] Back to Main Menu
"@ | Write-Host -ForegroundColor Green

        $opt = Read-Host "Choose mode"

        switch ($opt) {
            "1" { Show-DNSTermsMenu }
            "2" { Show-DNS201Menu }
            "3" { Toggle-InstructorMode }
            "4" { Export-DNSCheatSheets }
            "5" { Show-DNSLabsMenu }
            "6" { Show-DNSQuizMaster }
            "7" { Show-DNSThemeSelector }
            "8" { Show-DNSCacheTrainer}
            "Q" { return }
            "q" { return }
        }
    } while ($true)
}










function Show-ExternalDNSMenu {
    do {
        Clear-Host
        Write-Host "=== EXTERNAL DNS & DOMAIN REGISTRATION TRAINER ===" -ForegroundColor Cyan

@"
[1] Teaching Mode (step-by-step)
[2] Animated Mode (auto-run)
[3] Live Domain Walkthrough (root → TLD → zone → records)
[Q] Back to main menu
"@ | Write-Host -ForegroundColor Green

        $opt = Read-Host "Choose mode"

        switch ($opt) {
            "1" { Show-ExternalDNSTeaching }
            "2" { Show-ExternalDNSAnimated }
            "3" {
                $domain = Read-Host "Enter a real domain (e.g., dave.com)"
                if ($domain) {
                    Show-ExternalDNSDomainDemo -Domain $domain
                }
            }
            "Q" { return }
            "q" { return }
        }
    } while ($true)
}

# ============================================================
# MAIN MENU
# ============================================================

function Load-Menu {

    do {
        Clear-Host
        Write-CRT "=== Techmentor DNS BBS ===" 4 'Green'

@"
[1]  IT WAS DNS
[2]  IT IS ALWAYS DNS
[3]  IT WAS THE FIREWALL
[4]  IT WAS EMILE
[5]  DNS FLOW VISUALIZER (Whiteboard)
[6]  ASCII NETWORK MAPS
[7]  Split-Brain DNS (Internal vs External) [Conceptual]
[8]  DNSSEC Chain of Trust Visualizer
[9]  Root Hints Failure Demo
[10] 'Fix Emile's DNS' Mini-Game
[11] PING QUEST – The DNS Chronicles
[12] External DNS & Domain Registration Trainer
[13] DNS TRAINING 101 and 201
[Q]  Quit
"@ | Write-Host -ForegroundColor Green

        $choice = Read-Host "Select an option"

        switch ($choice) {
            "1"  { Clear-Host; Show-DNS;        pause }
            "2"  { Clear-Host; Show-AlwaysDNS;  pause }
            "3"  { Clear-Host; Show-Firewall;   pause }
            "4"  { Clear-Host; Show-Emile;      pause }
            "5"  {
                $domain = Read-Host "Enter domain (e.g., microsoft.com)"
                Clear-Host
                Show-DNSFlow -Domain $domain
            }
            "6"  { Clear-Host; Show-NetworkMapMenu }
            "7"  {
                $domain = Read-Host "Enter domain (e.g., corp.local or checkyourlogs.net)"
                Clear-Host
                Show-SplitBrainDNS -Domain $domain
            }
            "8"  {
                $domain = Read-Host "Enter domain for DNSSEC demo (e.g., cloudflare.com)"
                Clear-Host
                Show-DNSSECChain -Domain $domain
            }
            "9"  { Clear-Host; Show-RootHintsFailure }
            "10" { Clear-Host; Play-FixEmilesDNS }
            "11" { Clear-Host; Play-PingQuest }
            "12" { Clear-Host; Show-ExternalDNSMenu }
            "13" { Clear-Host; Show-DNSTrainingSuiteMenu }
            "Q"  { return }
            "q"  { return }
        }

    } while ($true)
}
