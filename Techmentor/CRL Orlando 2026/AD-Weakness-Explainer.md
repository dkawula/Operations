# Why We Break Active Directory on Purpose

### A teach-through for the DefXDRLabKit "weaken → attack → detect → harden" lab

*Red and Blue Teaming with Microsoft Defender XDR — companion chapter*

---

## Read this first: why deliberately weaken a domain you built clean?

A brand-new Active Directory forest, promoted this morning on Windows Server
2025, is actually quite hard to attack. Modern defaults are good: Kerberos
pre-authentication is on, SMB signing is required, LAPS is a checkbox away,
there are no stray replication rights, and nobody has left a password in a
Description field. If you point BloodHound, PingCastle, or a Kerberoast
collector at that pristine lab, you get almost nothing — and students
conclude "this attack doesn't really work."

**That is the wrong lesson.** The attacks absolutely work — they work every
single week, in real organizations, against real domains. They work because
real domains are not promoted this morning. They are fifteen years old. They
were born on Server 2003, in-place upgraded through 2008, 2012, 2016, and
2019, carrying every shortcut, every "we'll fix it later," and every
help-desk habit the whole way. The service account somebody made in 2011 with
password `Summer2011!` still has its SPN and still works. The "temporary"
GenericAll grant from a migration project is still there. Pre-authentication
was never turned back on for that one app that needed it in 2014.

So in the lab we fast-forward through fifteen years of entropy in about
ninety seconds. `guest/11-Weaken-AD.ps1 -Action Weaken` seeds the exact
conditions an aged domain accumulates, so that:

1. the **traditional tooling actually lights up** — students see real
   findings, not an empty graph;
2. **Defender for Identity and Defender XDR have genuine signal to raise** —
   you watch the alert fire in the portal, not a screenshot;
3. and then `-Action Harden` (and the CIS L1 GPO in menu 8) **closes every
   one of them, 1:1**, so students see not just the hole but the fix, and how
   the detection changes once it's closed.

> **This is a defensive exercise on a domain you own.** The script only
> *sets and removes AD conditions*. It contains no exploitation code. Every
> weakness has a matching Harden step, and `-Action Report` shows the
> before/after. Never run it anywhere you do not own and are not authorized
> to test.

The category list mirrors the well-known **safebuffer / wazehell
`vulnerable-AD`** project (MIT licensed,
<https://github.com/safebuffer/vulnerable-AD>). We wrote our own seeding code
rather than running theirs, so it is fully auditable, idempotent, and exactly
reversible — but full credit to that project for cataloguing the conditions.

Each section below follows the same five beats, which is also how you should
teach it on stage:

- **What we set** — the exact condition the script creates.
- **Why it's in real domains** — the legacy story, so students believe it.
- **What the attacker does with it** — the technique, at a conceptual level.
- **How you catch it** — the Defender XDR / MDI / Sentinel signal.
- **How you close it** — the quick-win Harden step *and* the CIS L1 control
  that enforces it domain-wide.

---

## 1. Kerberoasting — service accounts with SPNs and weak passwords

**What we set.** Beyond `svc-sql` (seeded during DC configure), we create
`svc-web`, `svc-backup`, and `svc-app`, register a Service Principal Name on
each, and give each a **distinct** password with **graduated crack
difficulty**: `svc-web` is a top-of-the-wordlist password that falls
instantly, `svc-backup` needs a wordlist plus mangling rules and a minute or
two, and `svc-app` is a realistic passphrase that may well survive the class.
That's deliberate — if every target shared one weak password the roast would
be a single trivial win and students would learn the wrong thing. Real
domains have a *spread*, and the lesson is that it only takes **one** weak
service account to matter.

**Why it's in real domains.** Any account that runs a service — SQL, IIS app
pools, backup agents, line-of-business apps — tends to get an SPN so Kerberos
can work. For twenty years the standard operating procedure was: make a
normal user account, set a password a human typed, tick "password never
expires," and move on. Those accounts are everywhere, they rarely get
rotated, and the password is usually something a person could remember in
2012. Managed service accounts (gMSA) fix this, but adoption is still patchy,
especially for third-party apps that "don't support gMSA."

**What the attacker does with it.** Any authenticated domain user — not an
admin, just *any* user — can ask the KDC for a service ticket for an account
that has an SPN. Part of that ticket is encrypted with a key derived from the
service account's password. The attacker takes it offline and grinds a
wordlist against it at their own pace, with zero further traffic to the
domain. A weak password falls in seconds to minutes. Now they have the
service account's cleartext — and service accounts are usually
over-privileged.

**How you catch it.** Defender for Identity raises **"Suspected
Kerberoasting"** when it sees an account enumerate SPNs and pull service
tickets with weak/RC4 encryption. In Defender XDR this surfaces as an
identity alert tied to the requesting account and device. Sentinel's
`SecurityEvent` 4769 (Kerberos service-ticket request) with
`TicketEncryptionType 0x17` (RC4) from an unusual principal is the classic
hunting query.

**How you close it.**
- *Quick win (Harden):* replace each service account's password with a long
  random string, so the offline crack can't win even if the SPN remains.
- *Do it right:* migrate service accounts to **group Managed Service Accounts
  (gMSA)** — 120-character machine-managed passwords that rotate
  automatically and are never Kerberoastable in practice.
- *CIS L1:* enforces **"Network security: Configure encryption types allowed
  for Kerberos"** to drop RC4, and account-password-policy settings that make
  short passwords impossible to set in the first place.

---

## 2. AS-REP Roasting — accounts with Kerberos pre-authentication disabled

**What we set.** A user `jsmith.preauth` with the account flag **"Do not
require Kerberos pre-authentication."**

**Why it's in real domains.** Pre-authentication is on by default, but it gets
turned *off* for specific accounts to make some old or non-Windows
application work — a Unix/Linux Kerberos client, a legacy appliance, an
integration that broke until someone flipped this flag. Like most "temporary"
fixes, it is never flipped back, and nobody remembers it is set.

**What the attacker does with it.** With pre-auth off, the attacker can ask
the KDC for authentication data for that user *without proving who they are
first*. The KDC returns a blob encrypted with the user's password hash. Same
story as Kerberoasting: crack it offline, at leisure. No credentials needed
to start.

**How you catch it.** MDI flags the anomalous AS-REP request pattern; in
Sentinel, event **4768** (AS-REQ) with pre-authentication type `0` is the
tell. XDR correlates it with the account and the source.

**How you close it.**
- *Quick win (Harden):* re-enable pre-authentication on the account
  (`Set-ADAccountControl -DoesNotRequirePreAuth $false`).
- *Do it right:* audit the whole domain for the flag
  (`Get-ADUser -LDAPFilter '(userAccountControl:1.2.840.113556.1.4.803:=4194304)'`)
  and fix the underlying app so it doesn't need pre-auth off.
- *CIS L1:* doesn't directly toggle the per-account flag, but its auditing
  baseline ensures 4768/4769 events are logged so this is detectable, and its
  Kerberos encryption settings shrink the attack.

---

## 3. Password in the object Description (and other attributes)

**What we set.** We write `Temp login - password is Changeme123! - please
change` into a user's **Description** field.

**Why it's in real domains.** This is pure human behaviour. A help-desk tech
resets an account, needs somewhere to jot the temporary password so the next
person knows it, and the Description field is right there in Active Directory
Users and Computers. It feels harmless — "it's just an internal note." The
problem: **every authenticated user can read almost every attribute of every
object in the directory.** The Description field is world-readable.

**What the attacker does with it.** One LDAP query for all users where
Description contains "pass" (or "pwd", or a season, or "temp"). It takes one
line and no privilege. Attackers do this first, every time, because it is so
often a free win.

**How you catch it.** This one is quieter — it's a read, not an auth event.
Sentinel/UEBA can flag anomalous bulk LDAP enumeration, and MDI raises
**"Security principal reconnaissance (LDAP)"** when it sees a host sweep the
directory. The real control is prevention plus a periodic audit query.

**How you close it.**
- *Quick win (Harden):* clear the Description, rotate the password, force
  change-at-logon.
- *Do it right:* ban the practice; run a scheduled audit that greps all
  user/computer attributes for password-looking strings; use a proper
  password-handoff tool for temporary credentials.
- *CIS L1:* reinforces least-privilege and auditing so bulk reads are logged;
  the cultural fix (don't store secrets in AD) is policy, not a registry key.

---

## 4. Default password reuse — everyone starts with `Changeme123!`

**What we set.** A batch of users (`alice.hr`, `bob.finance`, …) all created
with the same default password, with change-at-logon *not* enforced.

**Why it's in real domains.** New-hire and bulk-provisioning workflows almost
always start everyone on a known default. That's fine *if* change-at-next-logon
is enforced and actually happens. In practice, service-ish accounts, shared
mailboxes, test accounts, and contractors get provisioned and then never log
in interactively to trigger the change — so the default sticks around for
months or years on a predictable set of accounts.

**What the attacker does with it.** Once they learn the org's default
(from the Description note above, from a wiki, from one cracked account),
they try it against every account. The ones that never changed it hand over
access instantly — no brute force, no noise beyond a few logons that look
legitimate.

**How you catch it.** A successful logon on a long-dormant account, or the
same password working across many accounts, is a UEBA anomaly in XDR and a
Sentinel sign-in query. MDI flags unusual authentication patterns.

**How you close it.**
- *Quick win (Harden):* rotate the passwords and force change-at-logon on all
  of them.
- *CIS L1:* **minimum password length, complexity, and maximum password age**
  make weak defaults unsettable and force rotation. Combined with **account
  lockout** (next section) it also kills the "try it everywhere" step.

---

## 5. Password spraying — weak seasonal passwords and no lockout

**What we set.** A few accounts given a classic seasonal password
(`Autumn2026!`) — complex *enough* to pass a naive policy, but exactly what a
human picks when forced to "add a number and a symbol."

**Why it's in real domains.** Complexity rules backfire: told to use upper,
lower, number, and symbol, users converge on `Season+Year+!`. Across a few
thousand users, a handful always land on this quarter's variant. And many
domains still run with **no account-lockout policy**, or a very loose one,
because lockouts generate help-desk tickets.

**What the attacker does with it.** Instead of many passwords against one
account (which triggers lockout), they try *one* password against *every*
account — a "spray." `Autumn2026!` against 3,000 users will hit several. With
no lockout, they can spray slowly and indefinitely.

**How you catch it.** This is one of the clearest XDR/MDI wins. Defender for
Identity raises a **brute-force / password-spray** alert on the pattern of one
source attempting many accounts. Sentinel: many 4625 (failed logon) across
distinct accounts from one source, followed by a 4624 success.

**How you close it.**
- *Quick win (Harden):* rotate the sprayable passwords.
- *CIS L1 (the big one):* enforces an **account-lockout threshold, duration,
  and reset window**, plus longer minimum length. Once CIS is applied, the
  spray trips a lockout and *fails* — and this is the single most satisfying
  before/after to demo: spray succeeds pre-CIS, spray locks out post-CIS.
- *Do it right:* Microsoft Entra **Password Protection** (banned-password
  lists) extends this to on-prem AD and kills the seasonal pattern at the
  source.

---

## 6. Dangerous ACLs / ACEs — GenericAll where it doesn't belong

**What we set.** We grant the low-privilege user `labuser` **GenericAll** over
a `Help Desk` group.

**Why it's in real domains.** Delegation sprawl. Over years, admins grant
rights to make something work — let the help desk reset passwords, let an app
manage a group, let a team own an OU — and those grants are additive, rarely
reviewed, and often far broader than needed (full control instead of a single
specific right). Migrations and "temporary" troubleshooting grants pile on.
The result is a web of rights that nobody has mapped — until an attacker maps
it for them.

**What the attacker does with it.** This is what **BloodHound** exists to
find. It ingests every ACL in the domain and computes the shortest path from
"the account I just compromised" to "Domain Admin" through abusable rights.
GenericAll over a group means the attacker can add themselves to it;
GenericAll over a user means they can reset its password or set an SPN.
Each edge is a step; BloodHound stitches them into a path.

**How you catch it.** MDI raises **"Suspicious additions to sensitive
groups"** and tracks sensitive-group membership changes; XDR correlates the
ACL abuse with the identity. Directory-change auditing (event 5136) in
Sentinel catches the modification. BloodHound/PingCastle on *your own* side is
the proactive control — run it before the attacker does.

**How you close it.**
- *Quick win (Harden):* remove the excess ACE.
- *Do it right:* run **PingCastle** and **BloodHound** as a blue-team audit;
  remove or tighten every unexpected grant to least privilege; adopt a
  tiered-admin model so help-desk rights can't reach Tier 0.
- *CIS L1:* enforces auditing of directory-service changes and
  least-privilege user-rights assignments, so new dangerous ACEs are logged
  and far fewer principals can be abused as a pivot.

---

## 7. DnsAdmins abuse — a low-priv user in a surprisingly powerful group

**What we set.** `labuser` added to the built-in **DnsAdmins** group.

**Why it's in real domains.** DnsAdmins sounds boring and narrow — "they just
manage DNS" — so membership gets handed out liberally to network and
application teams. Historically, because the DNS service runs as SYSTEM on a
domain controller and could be told to load an arbitrary plugin DLL, being in
DnsAdmins was effectively a path to running code as SYSTEM *on the DC*. The
specific DLL vector has been mitigated over time, but the group is still far
more powerful than its name implies and is a textbook privilege-escalation
target.

**What the attacker does with it.** From a DnsAdmins account, they influence
the DNS service on the DC to execute their code in the DC's SYSTEM context —
one short hop from "ordinary user who happens to be in DnsAdmins" to "code
execution on a domain controller."

**How you catch it.** MDI alerts on sensitive-group membership changes and on
suspicious service behaviour on a DC. Sentinel: 4732/4728 (added to a
security group) for DnsAdmins, and anomalous DNS-service restarts or plugin
loads on the DC.

**How you close it.**
- *Quick win (Harden):* remove the user from DnsAdmins.
- *Do it right:* treat DnsAdmins as a **Tier 0 / DC-admin-equivalent** group;
  keep its membership empty or tightly controlled; ensure the DNS server
  disallows unsigned plugin DLLs; patch DCs.
- *CIS L1:* audits sensitive-group changes and hardens DC configuration so
  the escalation path is both narrower and louder.

---

## 8. DCSync rights — replication rights for a non-admin

**What we set.** A non-admin account `svc-report` granted the two replication
extended rights on the domain head: **DS-Replication-Get-Changes** and
**DS-Replication-Get-Changes-All**.

**Why it's in real domains.** These rights are legitimate — domain
controllers need them, and so do tools like Entra Connect / Azure AD Connect,
some backup products, and certain migration utilities. The mistake is
granting them to a *service or user* account (because an install wizard asked
for it, or someone followed a blog) and then never removing them. Now a
non-DC principal can impersonate a domain controller's replication.

**What the attacker does with it.** With these rights, the attacker asks a
real DC to "replicate" account data to them — including the password hashes
of *any* account, up to and including `krbtgt` and Domain Admins. This is
**DCSync**. Getting the `krbtgt` hash is the key to the whole kingdom (see
below). No malware dropped on the DC, no event on the DC's own security log in
the obvious place — it looks like legitimate replication.

**How you catch it.** This is a flagship **Defender for Identity** detection:
**"Suspected DCSync attack (replication of directory services)"** fires when a
non-DC host requests replication. It's one of the most reliable XDR identity
alerts and a must-demo. Sentinel can corroborate with directory-service
access events, but MDI is the primary signal.

**How you close it.**
- *Quick win (Harden):* strip the replication ACEs from the account.
- *Do it right:* audit who holds Get-Changes/Get-Changes-All on the domain
  object; it should be *only* DCs and the explicitly required sync accounts,
  and those should be tightly protected; rotate `krbtgt` twice if you suspect
  prior exposure.
- *CIS L1:* enforces least-privilege and the auditing that makes MDI's
  detection trustworthy.

---

## 9. SMB signing not required

**What we set.** We turn **off** the "require SMB signing" setting on DC01
(reversible registry toggle).

**Why it's in real domains.** SMB signing prevents tampering and relay, but it
was historically off-by-default on many roles and carried a (now negligible)
performance worry, so plenty of older environments never required it —
especially on member servers and workstations. Modern Windows requires it far
more by default, but mixed estates with legacy hosts routinely have signing
*not required* somewhere.

**What the attacker does with it.** Without required signing, an attacker who
can coerce a machine to authenticate to them (there are several coercion
techniques) can **relay** that authentication to another host and act as that
machine — no password cracking at all. Unsigned SMB is the enabler for the
whole NTLM-relay family.

**How you catch it.** MDI detects NTLM-relay and coercion patterns and
identity-based lateral movement; Sentinel can hunt for anomalous
machine-account authentications and the coercion RPC calls. XDR ties the
relayed auth to the source and destination.

**How you close it.**
- *Quick win (Harden):* re-require SMB signing on the DC.
- *Do it right:* require SMB signing **everywhere** (DCs, servers,
  workstations) via GPO; disable NTLM where possible; enable Extended
  Protection for Authentication (EPA/channel binding) on LDAP and web
  services.
- *CIS L1:* **requires SMB signing (client and server)** as a baseline
  control — this is exactly the kind of setting the CIS benchmark enforces
  domain-wide, which is why the 4-way matrix (menu 8) shows relay-style paths
  closing the moment CIS L1 lands.

---

## The three "downstream" techniques: Golden Ticket, Silver Ticket, Pass-the-Hash / Pass-the-Ticket

These four are on the vulnerable-AD list, but there is nothing *separate* to
seed for them — they are what the attacker *does next*, once the conditions
above have handed over the right secret. We teach them as the payoff, not as a
checkbox.

- **Pass-the-Hash (PtH).** Kerberos and NTLM don't always need your cleartext
  password — the *hash* is often enough to authenticate. Once an attacker has
  a hash (from Kerberoasting cracked offline, from DCSync, from a local SAM on
  a box with reused local-admin passwords), they "pass" it to move laterally
  as that user without ever knowing the password. **Root causes to close:**
  reused local-admin passwords (deploy **LAPS/Windows LAPS** so every machine
  has a unique one), over-privileged accounts, and no tiered-admin model. MDI
  detects PtH lateral movement.

- **Pass-the-Ticket (PtT).** Same idea, one layer up: steal or forge a
  Kerberos *ticket* (TGT or service ticket) and present it. Protect against it
  by protecting the machines where tickets live (credential theft protection,
  Credential Guard), short ticket lifetimes, and MDI's PtT detection.

- **Silver Ticket.** If the attacker has a *service account's* key (e.g. from
  Kerberoasting), they can **forge a service ticket** for that one service
  directly, bypassing the DC entirely — quiet, because the DC never sees the
  request. Closing the Kerberoasting gap (strong service-account keys / gMSA) removes the key
  that makes a silver ticket possible.

- **Golden Ticket.** If the attacker has the **`krbtgt`** account's key (e.g.
  from DCSync), they can forge a TGT for *anyone, any group, with any
  lifetime* — effectively a skeleton key to the whole domain. This is why
  DCSync is the crown-jewels detection, and why incident response for a
  suspected DC compromise includes **rotating `krbtgt` twice**. MDI raises
  **"Suspected Golden Ticket usage"** on the anomalous ticket characteristics.

The teaching point lands here: **you don't defend these four by chasing the
tickets — you defend them by closing the nine weaknesses above so the attacker never gets the key
in the first place, and by instrumenting MDI so that if they do, the forged
ticket's own oddities give them away.**

---

## How to run the arc in class (instructor spine)

1. **Promote + seed clean** (menu 2 → 1). Point BloodHound/PingCastle at it.
   *Almost nothing.* Say the line: "Modern defaults are good. Real domains
   aren't modern."
2. **Weaken** (menu 2 → 4) and **Report** (menu 2 → 6). Project the report —
   this is your before-state.
3. Point the same tools at it again. *Now the graph lights up.* Walk the
   BloodHound path to Domain Admin.
4. Run each technique (menu 5) and **flip to the Defender XDR
   portal** to show the matching MDI/XDR alert fire. This is the whole point:
   the attack is real, and *the blue side sees it*.
5. Layer **Sentinel** (menu 7) and show the same events as hunting queries.
6. **Harden** (menu 2 → 5), then **Report** again — the weaknesses are gone.
7. Apply **CIS L1** (menu 8) and run the **4-way matrix** on one technique:
   no-XDR / XDR / XDR+CIS / CIS-only. This proves, side by side, what CIS
   stops *structurally* (the spray that now locks out, the relay that now
   fails) versus what XDR *catches* (the DCSync it can't prevent but always
   sees).

The message students leave with: **CIS benchmarks remove the conditions;
Defender XDR catches what's left. You need both, and now you've watched each
one do its job.**

---

*Category list credited to safebuffer / wazehell `vulnerable-AD` (MIT). The
seeding and remediation code in `guest/11-Weaken-AD.ps1` is original,
reversible, and auditable. For authorized lab use only, on a domain you own.*
