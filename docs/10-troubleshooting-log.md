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
