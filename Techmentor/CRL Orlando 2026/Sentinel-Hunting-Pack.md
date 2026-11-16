# Post-exploit threat-hunting pack — Defender XDR + Sentinel

Paste these into **security.microsoft.com → Advanced hunting** (they also run in
Sentinel once the *Microsoft Defender XDR* data connector is on). Each query maps
to one technique the workshop fires from menu 5, plus the cloud control-plane
activity. They are **hunting** queries (what the attack leaves behind), not
detections you have to build — the XDR alerts fire on their own; these let the
room *see the evidence* and pivot.

Scope: `lab.local`, DC01, WIN11 (onboarded) vs WIN11B (stock AV). Narrow the
time window (`ago(1h)`) to the class session.

---

## T-02 — Credential access from LSASS (T1003.001)
Processes opening a handle to `lsass.exe` (Mimikatz-style dumping).
```kql
DeviceEvents
| where Timestamp > ago(1h)
| where ActionType in ("OpenProcessApiCall","ReadProcessMemoryApiCall")
| where FileName =~ "lsass.exe" or InitiatingProcessFileName !in~ ("MsMpEng.exe","wininit.exe")
| project Timestamp, DeviceName, InitiatingProcessFileName, InitiatingProcessCommandLine, AccountName
| sort by Timestamp desc
```
**Look for:** a non-system process (powershell, rundll32, a renamed binary)
touching LSASS on WIN11. On WIN11B (stock AV) you may see nothing in XDR — the
contrast is the lesson.

## T-03 — AD account discovery / BloodHound (T1087)
Burst of LDAP/SAMR enumeration from one host.
```kql
IdentityQueryEvents
| where Timestamp > ago(1h)
| where ActionType in ("SAMR query","LDAP query")
| summarize Queries=count(), Targets=dcount(Query) by DeviceName, AccountDisplayName, bin(Timestamp, 5m)
| where Queries > 20
| sort by Queries desc
```
**Look for:** one account enumerating hundreds of objects in minutes = collection.

## T-04 — Kerberoasting the svc-sql account (T1558.003)
TGS requests for SPN-bearing accounts with weak (RC4) encryption.
```kql
IdentityLogonEvents
| where Timestamp > ago(1h)
| where Protocol == "Kerberos"
| where AdditionalFields has "0x17" or AdditionalFields has "rc4"
| project Timestamp, AccountName, DeviceName, TargetDeviceName, AdditionalFields
| sort by Timestamp desc
```
**Look for:** TGS for `svc-sql` with RC4. Pair with MDI alert *"Suspected
Kerberoasting"*. Also check: `IdentityDirectoryEvents` for the SPN read.

## T-05 — AS-REP roasting (T1558.004)
AS-REQ for accounts with pre-auth disabled.
```kql
IdentityLogonEvents
| where Timestamp > ago(1h)
| where Protocol == "Kerberos" and LogonType == "AS-REP"
| project Timestamp, AccountName, DeviceName, AdditionalFields
| sort by Timestamp desc
```
**Look for:** AS-REP tickets issued without pre-auth (the seeded no-preauth user).

## T-07 — Pass-the-hash lateral movement (T1550.002)
NTLM logons using a hash rather than a password.
```kql
IdentityLogonEvents
| where Timestamp > ago(1h)
| where Protocol == "Ntlm" and LogonType == "Network"
| summarize Hosts=dcount(DeviceName), make_set(DeviceName) by AccountName, bin(Timestamp,10m)
| where Hosts > 1
| sort by Hosts desc
```
**Look for:** one account authenticating to several hosts over NTLM in a short
window. Pair with MDI *"Suspected pass-the-hash."*

## T-09 — DCSync (T1003.006)
Replication (`DRSUAPI`) requested from a host that is **not** a domain controller.
```kql
IdentityDirectoryEvents
| where Timestamp > ago(1h)
| where ActionType == "Directory Services replication"
| project Timestamp, AccountName, DeviceName, DestinationDeviceName, AdditionalFields
| sort by Timestamp desc
```
**Look for:** replication requested by a workstation/non-DC = DCSync. This is the
flagship MDI detection; show *"Suspected DCSync attack."*

## T-11 — Ransomware behaviour, benign (T1486)
Rapid file modification / shadow-copy deletion patterns.
```kql
DeviceProcessEvents
| where Timestamp > ago(1h)
| where FileName in~ ("vssadmin.exe","wbadmin.exe","bcdedit.exe")
     or ProcessCommandLine has_any ("delete shadows","recoveryenabled no","delete catalog")
| project Timestamp, DeviceName, AccountName, FileName, ProcessCommandLine
| sort by Timestamp desc
```
**Look for:** shadow-copy deletion = classic pre-encryption. Controlled Folder
Access (menu 4 → 3) is what blocks the write half.

---

## Post-exploit: registry hive dump (T1003.002)
`reg save HKLM\SYSTEM/SAM` — the SYSTEM/SAM theft Defender now blocks on 2025.
```kql
DeviceProcessEvents
| where Timestamp > ago(1h)
| where FileName =~ "reg.exe" and ProcessCommandLine has "save"
| where ProcessCommandLine has_any ("HKLM\\SYSTEM","HKLM\\SAM","HKLM\\SECURITY")
| project Timestamp, DeviceName, AccountName, ProcessCommandLine
```
**Teaching note:** on Server 2025 / WIN11 with Defender active this is blocked as
`Trojan:Win32/RegistryExfil.*` — show the Protection history, then show the hunt.

## Cloud control-plane: `az vm run-command` as SYSTEM (Module 0)
Anyone with `runCommand` rights gets SYSTEM on a guest without creds — hunt it in
the Azure Activity log (Sentinel).
```kql
AzureActivity
| where TimeGenerated > ago(24h)
| where OperationNameValue has "runCommand"
| project TimeGenerated, Caller, CallerIpAddress, ResourceGroup, Resource, ActivityStatusValue
| sort by TimeGenerated desc
```
**Look for:** a non-automation caller invoking `runCommand` on a DC. Pair with the
Module 0b service-principal backdoor hunt (menu 4 → C → Hunt).

---

*Full technique write-ups and the red↔blue 1:1 catalogue are in the Course Map and
the Training Manual. Queries use the Defender XDR / MDI schema (IdentityLogonEvents,
IdentityDirectoryEvents, DeviceEvents); field names track the current portal.*
