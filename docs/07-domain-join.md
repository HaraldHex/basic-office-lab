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

### 3. Rename and join the domain (GUI)

1. **Windows key + R** → `sysdm.cpl` → **Enter**
2. **Computer Name** tab → **Change…**
3. **Computer name:** `PC-IT01`
4. **Member of:** select **Domain** → `office.lab` → **OK**
5. Credentials: username `Administrator` and the domain password
6. *"Welcome to the office.lab domain"* → **OK** → restart

**Why the GUI here:** The PowerShell alternative (`Add-Computer -Credential OFFICE\Administrator`) needs `\` or `@`, which require AltGr on a Norwegian keyboard. VMware intercepts AltGr (see [Troubleshooting #3](10-troubleshooting-log.md)).

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
| PC-FIN01 | per.johansen | ⬜ | ⬜ |
| PC-SALES01 | lars.larsen | ⬜ | ⬜ |
| PC-HR01 | emma.berg | ⬜ | ⬜ |

## Least privilege

When Ola Nordmann opens PowerShell, the title bar says just *Windows PowerShell*, not *Administrator*. Ordinary users have **no local admin rights**. Only IT administrators (Domain Admins) can install software or change system settings. This limits the damage from mistakes and malware.

## Screenshots

- [ ] `ipconfig /renew` showing 10.10.10.100 from DHCP
- [ ] "Welcome to the office.lab domain"
- [ ] `Get-CimInstance Win32_ComputerSystem` showing Domain office.lab
- [ ] Start menu / `whoami` showing **office\ola.nordmann**
- [ ] ADUC showing PC-IT01 in the Workstations OU

## Notes

The first login attempt with `OFFICE/Administrator` failed with *wrong password*. The forward slash `/` is invalid. Windows needs a backslash `\` (see [Troubleshooting #4](10-troubleshooting-log.md)).
