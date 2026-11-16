# KQL Threat-Hunting Runner — Query Guide

Run a folder of KQL hunts against **Microsoft Defender XDR advanced hunting**
and a **Sentinel / Log Analytics** workspace from the command line — no portal
round-trips. Part of the DefXDRLabKit blue-team toolkit.

## Run it

```powershell
# everything, results shown here
.\Invoke-KqlHunt.ps1 -Path .\queries

# blue-team regression check: PASS / EMPTY / FAIL per query, plus evidence export
.\Invoke-KqlHunt.ps1 -Path .\queries -Test -Export .\hunt-results

# just the Sentinel ones
.\Invoke-KqlHunt.ps1 -Path .\queries -Only '6*'

# see what would run, where, without running it
.\Invoke-KqlHunt.ps1 -Path .\queries -List
```

From the kit: **menu 4 → K** ("Run my KQL folder"). Headless: `-Action KqlFolder`.

## How a query picks its back-end

Each `.kql` file's header comment decides where it runs. Two back-ends:

| Back-end | Tables | How it runs |
|----------|--------|-------------|
| **XDR** | `Device*`, `Identity*`, `Alert*` | Microsoft Graph `runHuntingQuery` — via the `Microsoft.Graph.Authentication` module if present (one-time sign-in, kit menu 4 → G), else `az rest` |
| **Sentinel** | `SecurityEvent`, `AzureActivity`, `AuditLogs`, … | `az monitor log-analytics query` against the lab workspace |

Auto-detection reads the marker line this pack already uses
(`// DEFENDER XDR ADVANCED HUNTING` → XDR, `// OPTIONAL SENTINEL / SECURITYEVENT`
→ Sentinel). Override per file with `// source: XDR|Sentinel`, or force the
whole run with `-Source XDR|Sentinel`.

## Header directives (optional)

Put these as comment lines at the top of a `.kql` file:

```
// name: Friendly name shown in the summary
// source: XDR | Sentinel
// expect: rows | empty | >=N | ==N | >N | <N     (used by -Test; default: rows)
```

`-Test` turns `// expect:` into a verdict: **PASS** (expectation met),
**EMPTY** (ran fine, no rows — often just means that technique wasn't run in the
window), **FAIL** (ran but violated the expectation), or **ERROR** (query/tenant
problem). Exit code is 1 if any query FAILs, so this drops straight into CI.

## The replay window

Every query in this pack is self-contained: it sets its own
`let StartUtc` / `let EndUtc` to the lab replay window
(2026-11-11 15:00Z → 2026-11-13 00:00Z; the two twin-marker queries narrow to
22:00–22:20Z). To re-point at a fresh run, edit those two lines at the top of
the file. The runner does not inject a window — what's in the file is what runs.

## Note on the queries as delivered

The query files arrived with every backslash stripped (a copy/paste escaping
artifact): `C:\tools` had become `C:` + a tab, `Control\Lsa` → `ControlLsa`,
`Microsoft\Protect` → `MicrosoftProtect`, and so on. Those filters would have run
without error but matched nothing — a silent false negative. The backslashes
were reconstructed in 5 files (36, 37, 39, 52, 64) before shipping. If you
regenerate these from the same source, re-check for stripped backslashes.

## The pack (31 queries)

- **00–04** coverage & inventory: device/sensor health, MDE table coverage, MDI
  table coverage, DeviceEvents action-name discovery, alerts tied to lab entities.
- **10–12** recon: network activity with Kali, LDAP/RPC directory recon (MDI),
  Windows discovery child processes.
- **20–22** Kerberos/auth (MDI): Kerberos from the lab, AS-REP target timeline,
  multi-account auth bursts.
- **30–39** execution & credential access (MDE): logons from Kali, WinRM/WMI exec,
  directory changes, registry hive export, LSASS dump candidates, dump/hive file
  artifacts, DPAPI/browser-store effects, LSA/Defender/RemoteRegistry changes,
  security-control events, scheduled-task/SYSTEM follow-up.
- **50–54** operator correlation & the defended twin: endpoint→Kali connections,
  children of processes that contacted Kali, file delivery/tool-dir activity,
  the known-good twin process marker, and the explicit-zero-rows twin comparison.
- **60–64** optional Sentinel / `SecurityEvent` (needs Windows Security log
  collection + the right audit policy): raw event availability, TGS (4769)
  Kerberoasting, TGT (4768) for the pre-auth-disabled account, DS replication
  rights (4662), SMB access to browser/DPAPI material (5145).

All queries are **read-only**. The runner never writes to the tenant.
