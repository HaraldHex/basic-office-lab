# 10 – Troubleshooting Log

**Goal:** Record every problem, its cause and the fix. This is often the most valuable part of a lab for employers, because it shows how you think when something breaks.

## How to log a problem

Use this template for each issue:

```markdown
### Issue #X: Short description
- **Phase:** e.g. 07 – Domain join
- **Symptom:** What happened? Exact error message?
- **Investigation:** What did I check, and in what order?
- **Root cause:** Why did it happen?
- **Fix:** What solved it?
- **Lesson learned:** What will I do differently?
```

---

## My issues

### Issue #1: DC01 could not reach its gateway
- **Phase:** 01 – VMware networking / 02 – Server installation
- **Symptom:** `ping 10.10.10.2` returned *Reply from 10.10.10.10: Destination host unreachable*.
- **Investigation:** The server's IP settings were correct (`Get-NetIPConfiguration`). The reply came from DC01 itself, which means it couldn't find the gateway on the local network at all. Checked the VM's network adapter (NAT = VMnet8), then the Virtual Network Editor.
- **Root cause:** VMnet8 used VMware's default subnet **192.168.59.0**, not the lab's 10.10.10.0. The gateway 10.10.10.2 didn't exist on that network.
- **Fix:** Virtual Network Editor → Change Settings → VMnet8 → subnet `10.10.10.0`, VMware DHCP off, NAT gateway `10.10.10.2`.
- **Lesson learned:** Configure and verify the virtual network **before** setting static IPs. "Destination host unreachable" from your own IP points to layer 2 (wrong network), not routing.

### Issue #2: DHCP authorization failed
- **Phase:** 05 – DHCP
- **Symptom:** `Add-DhcpServerInDC` failed with *Failed to initialize directory service resources … PermissionDenied (WIN32 5)*. The rest of the DHCP setup succeeded.
- **Investigation:** `whoami` returned `office\christoffer`.
- **Root cause:** The local account created during server installation became an ordinary domain user after promotion. Authorizing DHCP requires **Enterprise Admins**, which only `OFFICE\Administrator` is a member of.
- **Fix:** Signed out, logged in as `OFFICE\Administrator` and re-ran the authorization.
- **Lesson learned:** Check `whoami` before running privileged commands. Use the domain Administrator account for infrastructure changes.

### Issue #3: Couldn't type `@`, `\` or `$` inside the VMs
- **Phase:** 07 – Domain join
- **Symptom:** Characters requiring **AltGr** on a Norwegian keyboard didn't reach the VM.
- **Root cause:** VMware uses **Ctrl+Alt** as a hotkey. On Windows, AltGr is sent as Ctrl+Alt, so VMware intercepts it.
- **Fix:** Joined the domain through the GUI (`sysdm.cpl`), which only needs the username `Administrator`. Installed **VMware Tools** to paste commands from the host. Permanent fix: VMware → Edit → Preferences → Hot Keys → change to Ctrl+Shift+Alt.
- **Lesson learned:** Install VMware Tools right after the OS. It enables copy/paste and avoids keyboard-layout issues.

### Issue #4: "Wrong password" for the domain administrator
- **Phase:** 07 – Domain join
- **Symptom:** Logging in to PC-IT01 as `OFFICE/Administrator` gave *The user name or password is incorrect*, even with the right password.
- **Root cause:** A forward slash `/` was used instead of a backslash `\`. `OFFICE/Administrator` isn't a valid username, so Windows reports a wrong password.
- **Fix:** Used `OFFICE\Administrator` via the on-screen keyboard, or simply `Administrator` when the login screen shows *Sign in to: OFFICE*.
- **Lesson learned:** Windows logon format is `DOMAIN\user` or `user@domain`. Error messages don't always point to the real cause.

### Issue #5: Red "already exists" errors when creating OUs, groups and users
- **Phase:** 06 – OUs, users and groups
- **Symptom:** Commands returned *An attempt was made to add an object to the directory with a name that is already in use*.
- **Root cause:** The command block was pasted twice (right-click **and** Ctrl+V). The first run created the objects; the second run tried again.
- **Fix:** None needed. Verified with `Get-ADOrganizationalUnit`, `Get-ADGroup` and `Get-ADUser` that everything existed once.
- **Lesson learned:** In PowerShell, right-click alone pastes. Always verify state after running commands instead of assuming from the output.

### Issue #6: Local account had the same name as the computer
- **Phase:** 07 – Domain join (PC-SALES01)
- **Symptom:** After installing Windows, the Start menu showed the local user as **PC-SALES01**, the same name the computer was about to get.
- **Root cause:** During setup the local account was named after the computer. Windows treats user and computer names in the same namespace, so a rename/join to `PC-SALES01` can fail.
- **Fix:** Renamed the local user before joining: `Rename-LocalUser -Name "PC-SALES01" -NewName "sales01"`.
- **Lesson learned:** Give the setup account a generic name like `localadmin`.

### Issue #7: "The specified username is invalid" when joining PC-HR01
- **Phase:** 07 – Domain join (PC-HR01)
- **Symptom:** `sysdm.cpl` returned *The following error occurred attempting to join the domain "office.lab": The specified username is invalid.*
- **Investigation:** `nslookup office.lab` was answered by DC01.office.lab, so DNS and network were fine. The problem had to be the credentials typed into the dialog.
- **Root cause:** The username was not entered in a form Windows accepted (typing error / keyboard layout in the VM).
- **Fix:** Joined with PowerShell instead, pasting the command from the host so the backslash came through correctly: `Add-Computer -DomainName "office.lab" -NewName "PC-HR01" -Credential "OFFICE\Administrator" -Restart`.
- **Lesson learned:** Rule out the network first (`nslookup`). If DNS works, a join error is almost always about credentials or naming.

### Issue #8: Pasted commands arrived with the wrong characters
- **Phase:** 08 – Security hardening
- **Symptom:** Pasted commands arrived as `Invoke+LapsPolicyProcessing`, `"` became `Æ`, `|` became `*`, and `gpupdate /force` printed the help text.
- **Root cause:** The client had no VMware Tools, so VMware typed the clipboard as **US** keystrokes into a VM using a **Norwegian** layout. Every symbol landed on the wrong key.
- **Fix:** Switched the VM to English (US) with **Win + Space** before pasting. Permanent fix: install VMware Tools on every client.
- **Lesson learned:** When output looks "almost right", compare characters. A consistent substitution pattern points to a keyboard-layout mismatch.

### Issue #9: LAPS – "machine has not been granted permission"
- **Phase:** 08 – Security hardening (LAPS)
- **Symptom:** `Invoke-LapsPolicyProcessing` on the clients: *The request failed because the machine has not been granted permission in Active Directory to backup the managed account password.* The compliance report showed LAPS FAIL for all four PCs.
- **Root cause:** Computers in `OU=Workstations` had no permission to write their own LAPS password attributes. `Set-LapsADComputerSelfPermission` had not taken effect.
- **Fix:** Ran `Set-LapsADComputerSelfPermission -Identity "OU=Workstations,OU=Computers,OU=OFFICE,DC=office,DC=lab"` on DC01, then `Invoke-LapsPolicyProcessing` on each client.
- **Lesson learned:** LAPS needs three parts: schema, OU permission and GPO. The compliance report caught the missing permission that a manual check had missed.

### Issue #10: Audit policy only logs Success on DC01 (open)
- **Phase:** 08 – Security hardening (auditing)
- **Symptom:** The compliance report flagged *User Account Management: Success* (Failure missing).
- **Investigation:** `gpresult /h` on DC01 listed only *Security Settings* and no *Advanced Audit Configuration* section. The effective audit settings came from the Default Domain Controllers Policy.
- **Root cause:** (1) The advanced audit subcategories were not saved in `GPO_Audit_Baseline`. (2) GPO precedence (**LSDOU**): DC01 is in `OU=Domain Controllers`, and an OU-linked GPO overrides a domain-linked one.
- **Planned fix:** Configure the subcategories in `GPO_Audit_Baseline`, link it to `OU=Domain Controllers` with `-Order 1`, then verify with `auditpol /get /subcategory:"User Account Management"`.
- **Lesson learned:** "My GPO doesn't work" is usually about precedence or an empty GPO. `gpresult /h` shows the **winning GPO** for each setting.

### Issue #11: Commands run in the wrong context
- **Phase:** 08 – Security hardening
- **Symptoms:** AD cmdlets "not recognized" (run on the physical host `HEX`); *Insufficient access rights* (logged in as `office\christoffer`); *Access Denied* from `gpresult` (window not elevated); `gpresult` showing no workstation GPOs (run on DC01 instead of PC-IT01).
- **Fix:** Check context before running anything: `hostname`, `whoami`, and that the window title starts with **Administrator:**.
- **Lesson learned:** Three questions before every admin command: *which machine, which account, elevated or not?*

---

## Common pitfalls (reference)

| Symptom | Likely cause | Check / fix |
|---|---|---|
| "An Active Directory Domain Controller could not be contacted" | Client DNS isn't 10.10.10.10 | `ipconfig /all`; check DHCP option 006 |
| Client gets 169.254.x.x address | DHCP not authorized, scope inactive or VM on wrong VMnet | DHCP console; VM network adapter |
| VMs have no internet | Missing DNS forwarders or wrong gateway | `Resolve-DnsName microsoft.com`; option 003 = 10.10.10.2 |
| Can't join domain at all | Windows 11 **Home** edition | Upgrade to Pro |
| Login fails with time/clock error | Clock difference > 5 min (Kerberos) | `w32tm /query /status` |
| GPO not applied | GPO linked to wrong OU, or computer/user object in default container | `gpresult /r`; check object location in ADUC |
| Password policy not working | Policy linked to an OU instead of the domain | Use Default Domain Policy |
| User can't open share | NTFS or share permission missing, or user not in group | Effective Access tab; log off/on after group change |
| Duplicate SID / trust errors after cloning | VM cloned without sysprep | Use fresh installs or run `sysprep /generalize` |

## Useful commands

```powershell
ipconfig /all
nslookup -type=SRV _ldap._tcp.dc._msdcs.office.lab
dcdiag /v
Test-ComputerSecureChannel -Verbose      # On a client: is the domain trust OK?
gpresult /h C:\gp-report.html
Get-WinEvent -LogName System -MaxEvents 20
```
