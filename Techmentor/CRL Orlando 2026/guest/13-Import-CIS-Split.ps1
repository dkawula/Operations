<#
    Runs ON DC01 (via az vm run-command, as SYSTEM).
    Imports the split CIS GPO backups made by tools/Split-CisGpo.ps1 as
    "DefXDR CIS L1 <DC|MS|Win11> - <area>" GPOs. Nothing is linked: the
    operator links each GPO where they want it.

    Re-running is safe: Import-GPO overwrites the settings of a GPO that already
    has the same name, so you get the same result each time.
#>
param(
    [Parameter(Mandatory)][string]$ZipPath,          # C:\CIS\cis-split.zip
    [string]$StageDir = 'C:\CIS\Split'
)
$ErrorActionPreference = 'Stop'
Import-Module GroupPolicy

if (-not (Test-Path $ZipPath)) { throw "Split zip not found on DC01: $ZipPath" }
if (Test-Path $StageDir) { Remove-Item $StageDir -Recurse -Force }
Expand-Archive -Path $ZipPath -DestinationPath $StageDir -Force

$index = Join-Path $StageDir 'split-index.csv'
if (-not (Test-Path $index)) { throw "split-index.csv missing from $ZipPath" }
$rows = Import-Csv $index

$ok = 0; $fail = 0
foreach ($r in $rows) {
    $path = Join-Path $StageDir $r.Folder
    # SYSVOL can briefly hold a handle on a GPO folder that was just written
    # (0x80070091 "directory is not empty"), so retry a few times before failing.
    $done = $false; $msg = ''
    for ($try = 1; $try -le 4 -and -not $done; $try++) {
        try {
            Import-GPO -BackupId $r.BackupId -Path $path -TargetName $r.GpoName -CreateIfNeeded -ErrorAction Stop | Out-Null
            $done = $true
        } catch {
            $msg = $_.Exception.Message
            if ($try -lt 4) { Start-Sleep -Seconds (10 * $try) }
        }
    }
    if ($done) {
        "[OK]     {0,-58} {1,4} settings{2}" -f $r.GpoName, $r.Settings, $(if ($try -gt 2) { "  (retry $($try-1))" } else { '' })
        $ok++
    } else {
        "[FAILED] {0} - {1} (after 4 tries)" -f $r.GpoName, $msg
        $fail++
    }
}

# Belt and braces: confirm none of them is linked anywhere (a GPO only gets a
# link if someone added one by hand; an import never links).
$linked = @()
foreach ($r in $rows) {
    $g = Get-GPO -Name $r.GpoName -ErrorAction SilentlyContinue
    if ($g) {
        [xml]$rep = Get-GPOReport -Guid $g.Id -ReportType Xml
        if ($rep.GPO.LinksTo) { $linked += $r.GpoName }
    }
}

""
"RESULT: $ok imported, $fail failed, $($rows.Count) total."
if ($linked) { "NOTE: these already had links (kept as they were): $($linked -join '; ')" }
else         { "All CIS GPOs are UNLINKED. Link them in GPMC where you want them." }
