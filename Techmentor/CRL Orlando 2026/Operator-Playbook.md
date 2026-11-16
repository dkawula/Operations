# Operator Playbook — Red & Blue Teaming with Microsoft Defender XDR

### The lab walkthrough, the telemetry each step throws, and the detection to show

*Companion to **DefXDRLabKit**. Authorized lab use only, inside a range you own. The operator is 100% responsible for executing every command.*

---

## How to use this

Read it alongside the demo; it gives the **why**, the **target**, and — the whole point — the **Defender / MDI / Sentinel detection and hardening** for each step.

- **Detection and hardening content is written out in full here** — that's the course.
- **Offensive commands are not reproduced in this document.** Each offensive step cites the public source it comes from (see the **Sources** appendix); the operator takes it from there and runs it on KALI. This keeps the course sourced to the authoritative docs — the right call for a workshop you record and share.

The rhythm for **every** step: **run it → flip to the Defender portal → show the detection → contrast WIN11 (onboarded) vs WIN11B (stock AV) → harden → re-run.**

**Range map:** DC01 (`192.168.57.10`, lab.local DC + MDI sensor) · WIN11 (`.20`, onboarded to Defender XDR) · WIN11B (`.21`, stock AV, the "defended twin") · KALI (`.5`, attacker box, plain base image) · SRV01 (`.30`, optional).

---

## Module 0 — Cloud control-plane abuse (defender module)

**The threat model to open with:** an attacker does not always need to phish a workstation. A **low-privilege cloud identity holding the wrong Azure RBAC role** can reach every VM in a subscription through the Azure control plane — no guest credentials, no open ports, NSG bypassed. This module teaches the mechanism, then spends its time where the course lives: **detecting and preventing it.**

### 0.1 The mechanism (teach this concept)

- `az vm run-command` is **not** a connection to the guest OS. It travels the **Azure control plane** (Azure Resource Manager over HTTPS), so it **bypasses the NSG** entirely — there is no port to block.
- ARM hands a goal-state to the **Azure VM Guest Agent** inside the VM (`WindowsAzureGuestAgent` on Windows, `waagent` on Linux). The agent pulls the Run Command extension from the host **WireServer** (`168.63.129.16`) and runs it locally; the host↔guest channel underneath is the Hyper-V **VMBus**.
- It executes as **SYSTEM** (Windows) / **root** (Linux). On a **domain controller**, SYSTEM is effectively Domain Admin, because the DC is the identity authority.
- The unlocking RBAC action is `Microsoft.Compute/virtualMachines/runCommand/action`, included in **Virtual Machine Contributor, Contributor, and Owner**. The teaching nuance: it is not "the CLI equals DA," it is "a *subscription RBAC role* → code execution as SYSTEM on the guest → DA **when that guest is a DC**."

The offensive demonstration of this (running code on a DC via Run Command and extracting directory data) is performed by the operator from the cited sources — this document does not reproduce those commands. What follows is what the course is actually about: seeing it and stopping it.

### 0.2 Detection — what the blue team sees

Every Run Command invocation is logged on the control plane with the **caller identity**, independent of anything on the guest. That is the detection goldmine.

**Azure Activity Log / Microsoft Sentinel (Log Analytics `AzureActivity`):**

```kusto
AzureActivity
| where OperationNameValue has "runCommand"
    or OperationNameValue has "RUNCOMMAND"
| project TimeGenerated, Caller, CallerIpAddress, ResourceGroup,
          _ResourceId, ActivityStatusValue, OperationNameValue
| order by TimeGenerated desc
```

Hunt refinements to teach:
- Flag Run Command against **tier-0 assets** (DCs) specifically: filter `_ResourceId` for your DC VMs — any `runCommand` there is high-signal.
- Flag callers **outside an approved set** (break-glass / automation service principals): `| where Caller !in (<approved identities>)`.
- Correlate `CallerIpAddress` against known-good admin egress.

**Microsoft Defender for Cloud / Defender for Servers:** raises alerts on suspicious Run Command / extension execution on VMs; make sure **Defender for Servers Plan 2** is enabled on every VM in the lab so the room sees the alert.

**Microsoft Defender for Endpoint (on the targeted VM):** because the payload runs *on* the guest as SYSTEM, MDE sees the resulting on-box process activity (unusual child processes under the guest-agent extension host) in the **device timeline** and `DeviceProcessEvents`. Contrast WIN11 (onboarded, full visibility) vs WIN11B (stock AV, little/none).

**Microsoft Defender for Identity (DC01 sensor):** if the control-plane foothold is used to touch directory services, MDI raises the identity-side alerts (reconnaissance, replication/DCSync) — the on-prem half of a cloud-origin attack.

**The teaching punchline:** the control-plane action (Activity Log) and the on-host effect (MDE/MDI) are two independent witnesses. A mature SOC catches it in **either**, and correlates **both** in Sentinel.

### 0.3 Hardening — how to prevent it (blue-team actions, authored)

Audit over-privileged assignments (a legitimate defender command — run it to find the risk):

```bash
# Who holds runCommand-capable roles at subscription scope?
az role assignment list --all \
  --query "[?roleDefinitionName=='Contributor' || roleDefinitionName=='Owner' || roleDefinitionName=='Virtual Machine Contributor'].{principal:principalName, role:roleDefinitionName, scope:scope}" \
  -o table
```

Then:

1. **Least-privilege RBAC.** Don't grant **Contributor/Owner at subscription scope** to people. Scope roles to the smallest resource group, and use **custom roles** that exclude `Microsoft.Compute/virtualMachines/runCommand/action` for day-to-day operators.
2. **PIM (Privileged Identity Management).** Make VM Contributor/Owner **just-in-time, time-boxed, and approval-gated** — not standing access.
3. **Conditional Access on the Azure management plane.** Require MFA + a compliant/managed device for the *Microsoft Azure Management* app, so a stolen password alone can't drive ARM.
4. **Azure Policy guardrails.** Audit or deny the VM Run Command extension where it isn't needed; alert on its use everywhere else.
5. **Tier-0 isolation.** Put domain controllers in a dedicated management group / subscription with its own tight RBAC and separate admins, so a contributor on an app subscription can never reach them.
6. **Wire the detection to action.** Turn the `AzureActivity` hunt above into a **Sentinel analytics rule** that pages on Run Command against tier-0 or from an unapproved caller.

> **Twin contrast for the room:** show the Activity Log entry fire regardless of endpoint tooling (it's control-plane), then show MDE's on-host view present on WIN11 and absent on WIN11B. The lesson: cloud-plane logging catches what endpoint tooling alone cannot.

---

## Module 0b — Cloud persistence: the service-principal backdoor (defender module)

**The scenario (tell the room):** a contractor is brought in to help manage the Azure environment. Rather than a broad **Contributor** grant, they request a narrow "VM maintenance" role on *just the lab resource group*, tied to an **app registration** (service principal). It looks reasonable and gets approved. The engagement ends; the app's **client secret is still valid, still scoped to the RG, still able to run code as SYSTEM on every VM in it.** That is the backdoor: a **non-human credential, no MFA, survives user password resets**, and scoped tightly enough to slip past a casual review.

**Lab scope guardrail:** everything in this module is scoped to **`rg-defxdr-lab` only — never the subscription.** The scenario is seeded, hunted, and removed inside that one resource group, so blast radius is zero. This is detection training on a range you own.

### What makes it sneaky (teaching points)

- **Non-human, persistent credential.** A service principal authenticates with a client secret or certificate. It isn't a user, so it typically has no MFA, isn't captured by user password resets, and blends into "automation."
- **Consent ≠ RBAC (the nuance most people miss).** A user *consenting* to an app ("people click Accept without reading") grants **Microsoft Graph / delegated API permissions** — a *different plane* from **Azure RBAC on a subscription or RG**. Consent-phishing yields data/Graph access; the *resource* backdoor needs a separate **RBAC role assignment** to the service principal (an ARM action). Teach both and the distinction.
- **Minimum rights hide the intent.** The least-privilege role that still enables script execution is a **custom role carrying only `Microsoft.Compute/virtualMachines/runCommand/action` (+ read)** — which reads like a benign "VM maintenance" role, not Contributor. Yet it is **code execution as SYSTEM on every VM in scope.** The defensive lesson: *any* custom role containing `runCommand` is effectively tier-0.
- **Managed identity is the sibling route.** A user-assigned managed identity assigned a role and bound to an attacker-controlled resource achieves the same, with no secret to steal.

### Seed → Hunt → Remediate (kit wiring, Weaken-AD style, all in `rg-defxdr-lab`)

1. **Seed** — create the scoped app registration + minimal custom role in the lab RG as a clearly-labeled lab artifact (reversible).
2. **Hunt** — surface it from the blue side (below).
3. **Remediate** — remove the role assignment + the app's credentials, and add an access review. The kit's Harden step cleans it up, exactly like Harden-AD.

### Detect it (blue)

- **Entra ID audit logs:** *Add service principal*, *Add app role assignment to service principal*, *Add/Update application – Certificates and secrets* (a new SP credential maps to MITRE **T1098.001**), *Consent to application*.
- **Azure Activity Log / Sentinel (`AzureActivity`):** `Microsoft.Authorization/roleAssignments/write` where the principal is a **service principal**, and `Microsoft.Authorization/roleDefinitions/write` (a **custom role** created or edited — inspect its `Actions` for `runCommand`).

```kusto
AzureActivity
| where OperationNameValue has "roleAssignments/write"
    or OperationNameValue has "roleDefinitions/write"
| project TimeGenerated, Caller, CallerIpAddress, ResourceGroup,
          OperationNameValue, ActivityStatusValue
| order by TimeGenerated desc
```

- **Microsoft Defender for Cloud Apps app governance / Defender XDR:** over-privileged or newly-consented OAuth apps, anomalous service-principal sign-ins.
- **Microsoft Entra ID Protection:** risky workload identities.
- **Sentinel analytics:** new credential added to an SP; privileged role assigned to an SP; first-seen SP sign-in IP.

### Harden it (blue — authored)

- **Restrict user consent** (admin-consent workflow) and set **Users can register applications = No**.
- **PIM** for Owner / User Access Administrator; alert on any role assignment to a service principal.
- Prefer **short-lived certificates over secrets**; monitor secret additions; consider an **app instance property lock**.
- **Access reviews** of service principals and managed identities that hold Azure roles; strip standing RBAC.
- **Workload Identity Conditional Access** (restrict service-principal sign-in by IP).
- **Treat any custom role containing `runCommand` as tier-0-sensitive** and alert on its creation or assignment.

> The offensive demonstration (creating and operating the backdoor) is performed by the operator from cited sources; this document and the kit own the **seed-as-lab-artifact, hunt, and remediate** sides — the defender content, which is the course.

---

## Modules 1–7 — attack → detect

SSH into KALI from kit menu 3 and set up your C2 (Sliver) from its official docs below. Run each technique (kit menu 5), then hunt it with the `queries\` pack (menu 4 → H / K) and `Sentinel-Hunting-Pack.md`. Narrate each one as attack → signal → hunt → fix.

---

## Sources appendix (for attendees to review)

Public, authoritative references for the C2 setup and the cloud/identity detections. Offensive command syntax is sourced here rather than reproduced in the kit.

**Sliver (Bishop Fox)**
- Official docs: <https://sliver.sh/docs/> · Wiki: <https://github.com/BishopFox/sliver/wiki>
- A How-To Guide for Using Sliver: <https://bishopfox.com/blog/sliver>
- Pwning the Domain with Sliver: <https://bishopfox.com/resources/pwning-the-domain-with-sliver-framework>
- Sliver Workshop Pt.2 — Staging & Automation: <https://bishopfox.com/resources/sliver-workshop-part-2-staging-automation>
- HTB Academy — Intro to C2 Operations with Sliver: <https://academy.hackthebox.com/course/preview/intro-to-c2-operations-with-sliver>
- rootsecdev — Hacking Active Directory with Sliver C2: <https://rootsecdev.medium.com/hacking-active-directory-with-sliver-c2-19d7ceabbf13>

**Azure control-plane / Run Command / identity defense (Module 0)**
- Azure VM Run Command (how it works): <https://learn.microsoft.com/azure/virtual-machines/run-command-overview>
- Azure VM Guest Agent & extensions: <https://learn.microsoft.com/azure/virtual-machines/extensions/agent-windows>
- Azure built-in roles (what Contributor/Owner/VM Contributor grant): <https://learn.microsoft.com/azure/role-based-access-control/built-in-roles>
- Microsoft Defender for Cloud / Defender for Servers: <https://learn.microsoft.com/azure/defender-for-cloud/defender-for-servers-introduction>
- Privileged Identity Management (PIM): <https://learn.microsoft.com/entra/id-governance/privileged-identity-management/pim-configure>
- Conditional Access for Azure management: <https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-cloud-apps>

---

*Detection and hardening in this document are authored for defensive teaching. Offensive command syntax is cited to the public sources above and executed by the operator, on a range they own.*
