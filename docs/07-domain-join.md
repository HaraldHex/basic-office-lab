# 07 – Joining Clients to the Domain

**Goal:** Install the Windows 11 clients, join them to `office.lab` and log in as domain users.

## Requirements

| Requirement | Why |
|---|---|
| Windows 11 **Pro, Enterprise or Education** | **Home edition cannot join a domain.** This lab uses Windows 11 Enterprise Evaluation. |
| Virtual TPM | Windows 11 requires TPM 2.0 (VM Settings → Add → Trusted Platform Module) |
| Network adapter on NAT (VMnet8) | Same network as DC01 |
| VMware Tools | Enables copy/paste between host and VM |

## VM settings

| Setting | Value |
|---|---|
| vCPU / RAM / Disk | 8 / 4 GB / 64 GB |
| Network | NAT (VMnet8) |

## Steps

### 1. Install Windows 11
During setup, on *Let's set things up for your work or school*, choose **Domain join instead**. Despite the name, this only creates a **local account** so setup can finish. The actual join happens afterwards.

### 2. Check networking first
**Why:** If DNS is wrong, the join fails. Checking first saves time.

```powershell
ipconfig /release
ipconfig /renew
ipconfig /all          # IP 10.10.10.1xx, gateway 10.10.10.2, DNS 10.10.10.10
nslookup office.lab    # Answered by DC01.office.lab
```

Result on PC-IT01: **10.10.10.100**, gateway **10.10.10.2**, DNS suffix **office.lab**. This proves DC01's DHCP is working.

> **Name the local account something generic** (e.g. `localadmin`). Don't give it the same name as the computer (`PC-SALES01`): a user and a computer with the same name cause conflicts when renaming and joining. See [Troubleshooting #6](10-troubleshooting-log.md).

### 3. Rename and join the domain (GUI)

1. **Windows key + R** → `sysdm.cpl` → **Enter**
2. **Computer Name** tab → **Change…**
3. **Computer name:** `PC-IT01`
4. **Member of:** select **Domain** → `office.lab` → **OK**
5. Credentials: username `Administrator` and the domain password
6. *"Welcome to the office.lab domain"* → **OK** → restart

**PowerShell alternative** (once VMware Tools is installed, so the line can be pasted):

```powershell
Add-Computer -DomainName "office.lab" -NewName "PC-HR01" -Credential "OFFICE\Administrator" -Restart
```

**Why the GUI first:** The PowerShell alternative (`Add-Computer -Credential OFFICE\Administrator`) needs `\` or `@`, which require AltGr on a Norwegian keyboard. VMware intercepts AltGr (see [Troubleshooting #3](10-troubleshooting-log.md)).

### 4. Log in as a domain user
At the login screen: **Other user**. Check that it says **Sign in to: OFFICE**, then type the username without a prefix, e.g. `ola.nordmann`.

## Verification

On the client:
```powershell
Get-CimInstance Win32_ComputerSystem   # Domain column: office.lab
whoami                                 # office\ola.nordmann
```

On DC01:
```powershell
Get-ADComputer -Filter * | Select-Object Name, DistinguishedName
```

| Client | User | Joined | Domain login tested |
|---|---|---|---|
| PC-IT01 | ola.nordmann | ✅ | ✅ |
| PC-FIN01 | per.johansen | ✅ | ✅ |
| PC-SALES01 | lars.larsen | ✅ | ✅ |
| PC-HR01 | emma.berg | ✅ | ✅ |

All four clients landed in `OU=Workstations` automatically thanks to `redircmp` (phase 06). Only PC-IT01 had to be moved by hand, because it joined before the redirect was set.

```text
Name       DistinguishedName
----       -----------------
DC01       CN=DC01,OU=Domain Controllers,DC=office,DC=lab
PC-IT01    CN=PC-IT01,OU=Workstations,OU=Computers,OU=OFFICE,DC=office,DC=lab
PC-FIN01   CN=PC-FIN01,OU=Workstations,OU=Computers,OU=OFFICE,DC=office,DC=lab
PC-SALES01 CN=PC-SALES01,OU=Workstations,OU=Computers,OU=OFFICE,DC=office,DC=lab
PC-HR01    CN=PC-HR01,OU=Workstations,OU=Computers,OU=OFFICE,DC=office,DC=lab
```

## Least privilege

When Ola Nordmann opens PowerShell, the title bar says just *Windows PowerShell*, not *Administrator*. Ordinary users have **no local admin rights**. Only IT administrators (Domain Admins) can install software or change system settings. This limits the damage from mistakes and malware.

## Screenshots

- [ ] `ipconfig /renew` showing 10.10.10.100 from DHCP
- [ ] "Welcome to the office.lab domain"
- [ ] `Get-CimInstance Win32_ComputerSystem` showing Domain office.lab
- [ ] Start menu / `whoami` showing **office\ola.nordmann**
- [ ] `Get-ADComputer` on DC01 showing all four clients in the Workstations OU
- [ ] ADUC showing the Workstations OU with four computers

## Notes

The first login attempt with `OFFICE/Administrator` failed with *wrong password*. The forward slash `/` is invalid. Windows needs a backslash `\` (see [Troubleshooting #4](10-troubleshooting-log.md)).
