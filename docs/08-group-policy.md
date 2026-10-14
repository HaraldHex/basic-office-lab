# 08 – Security Hardening & Compliance

**Goal:** Move the lab from "it works" to "it's secure and auditable". Every control is applied centrally with Group Policy or AD settings, verified on a client, and measured with a compliance report.

> All work in this phase was done as `adm.christoffer` (a named admin account), not the built-in Administrator, except the LAPS schema update, which requires Schema Admins.

💾 Snapshot taken before starting: `DC01 – Before hardening`.

## Overview

| # | Control | Applied to | Verified by |
|---|---|---|---|
| 1 | Password & lockout policy | Domain (Default Domain Policy) | Account locked after 5 failed logons |
| 2 | Separate admin accounts + Protected Users | `OU=Admins` | `Get-ADGroupMember "Domain Admins"` |
| 3 | Windows LAPS | `OU=Workstations` | `Get-LapsADPassword` |
| 4 | Workstation hardening GPO | `OU=Workstations` | `gpresult`, RSoP, logon banner |
| 5 | Audit policy | Domain | Event IDs 4720 / 4726 / 4740 |
| 6 | Compliance report | Whole domain | `Get-ComplianceReport.ps1` |

## How Group Policy precedence works

```
Local → Site → Domain → OU (parent → child)     Last applied wins
```

PC-IT01's RSoP showed the order in practice:

| Priority | GPO | Linked to |
|---|---|---|
| 1 (highest) | GPO_Workstations_LAPS | OU=Workstations |
| 2 | GPO_Workstations_Hardening | OU=Workstations |
| 3 | Default Domain Policy | Domain |

---

## 1. Password and lockout policy

**Why:** Weak passwords are the most common way in. Lockout stops brute-force guessing.
**Why at domain level:** Password policy for domain accounts only takes effect from a GPO linked to the **domain**, not an OU.

| Setting | Before (default) | After |
|---|---|---|
| Minimum length | 7 | **12** |
| Complexity | On | On |
| History | 24 | 24 |
| Max password age | 42 days | **90 days** |
| Lockout threshold | **0 (never locks)** | **5 attempts** |
| Lockout duration / window | 10 min | 15 min |

```powershell
Set-ADDefaultDomainPasswordPolicy -Identity "office.lab" -MinPasswordLength 12 -ComplexityEnabled $true `
    -PasswordHistoryCount 24 -MaxPasswordAge "90.00:00:00" -MinPasswordAge "1.00:00:00" `
    -LockoutThreshold 5 -LockoutDuration "00:15:00" -LockoutObservationWindow "00:15:00"
Get-ADDefaultDomainPasswordPolicy
```

**Test:** 5 wrong passwords for `ola.nordmann` on PC-IT01 → *"The referenced account is currently locked out"*. Unlocked on DC01:

```powershell
Search-ADAccount -LockedOut | Select-Object Name, SamAccountName
Unlock-ADAccount -Identity "ola.nordmann"
```

> The default `LockoutThreshold: 0` means an attacker could guess passwords forever. This is one of the most important settings to change on a new domain.

## 2. Separate admin accounts

**Why:** If IT staff browse and read email with a Domain Admin account, any malware they hit gets full control of the domain. Each admin gets a **daily account** and a separate **`adm.` account** used only for administration (least privilege).

```powershell
New-ADOrganizationalUnit -Name "Admins" -Path "OU=OFFICE,DC=office,DC=lab"
New-ADUser -Name "ADM Christoffer" -SamAccountName "adm.christoffer" -UserPrincipalName "adm.christoffer@office.lab" `
    -Description "Admin account - Christoffer" -Path "OU=Admins,OU=OFFICE,DC=office,DC=lab" `
    -AccountPassword (Read-Host "Password" -AsSecureString) -Enabled $true
Add-ADGroupMember -Identity "Domain Admins"   -Members "adm.christoffer"
Add-ADGroupMember -Identity "Protected Users" -Members "adm.christoffer"
```

**Protected Users** blocks NTLM, unconstrained delegation and credential caching for its members, which makes admin credentials much harder to steal.

Result: Domain Admins contains only **Administrator** and **adm.christoffer**.

## 3. Windows LAPS

**Problem:** If every PC shares the same local administrator password, one compromised PC gives access to all of them (lateral movement).
**Solution:** Windows LAPS (built into Server 2025 and Windows 11) gives every PC a **unique, random password** that **rotates automatically** and is stored in AD, readable only by admins.

```powershell
# As Administrator (Schema Admins)
Update-LapsADSchema -Verbose
Set-LapsADComputerSelfPermission -Identity "OU=Workstations,OU=Computers,OU=OFFICE,DC=office,DC=lab"

# As adm.christoffer
$key = "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\LAPS"
New-GPO -Name "GPO_Workstations_LAPS" | New-GPLink -Target "OU=Workstations,OU=Computers,OU=OFFICE,DC=office,DC=lab"
Set-GPRegistryValue -Name "GPO_Workstations_LAPS" -Key $key -ValueName "BackupDirectory"    -Type DWord -Value 2
Set-GPRegistryValue -Name "GPO_Workstations_LAPS" -Key $key -ValueName "PasswordLength"     -Type DWord -Value 16
Set-GPRegistryValue -Name "GPO_Workstations_LAPS" -Key $key -ValueName "PasswordComplexity" -Type DWord -Value 4
Set-GPRegistryValue -Name "GPO_Workstations_LAPS" -Key $key -ValueName "PasswordAgeDays"    -Type DWord -Value 30
```

| Setting | Value | Meaning |
|---|---|---|
| BackupDirectory | 2 | Store the password in Active Directory |
| PasswordLength | 16 | 16 characters |
| PasswordComplexity | 4 | Upper, lower, numbers and special characters |
| PasswordAgeDays | 30 | Rotated every 30 days |

**On each client:** `gpupdate /force` and `Invoke-LapsPolicyProcessing`
**Verify on DC01:**

```powershell
"PC-IT01","PC-FIN01","PC-SALES01","PC-HR01" | ForEach-Object { Get-LapsADPassword -Identity $_ -AsPlainText } |
    Select-Object ComputerName, Password, ExpirationTimestamp
```

The first attempt failed with *"the machine has not been granted permission in Active Directory"*. See [Troubleshooting #9](10-troubleshooting-log.md).

## 4. Workstation hardening GPO

| Control | Why |
|---|---|
| Screen lock after 10 min | An unlocked, unattended PC is open to anyone walking past |
| Firewall forced on (all profiles) | Users or malware can't switch it off |
| Removable storage blocked | Prevents data theft and malware from USB sticks |
| LLMNR disabled | Legacy name resolution abused to capture password hashes (e.g. Responder) |
| Hide last signed-in user | Attackers don't get usernames for free |
| Logon banner | Legal notice that the system is monitored (typical compliance requirement) |

```powershell
$gpo = "GPO_Workstations_Hardening"
New-GPO -Name $gpo | New-GPLink -Target "OU=Workstations,OU=Computers,OU=OFFICE,DC=office,DC=lab"
$sys = "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System"
Set-GPRegistryValue -Name $gpo -Key $sys -ValueName "InactivityTimeoutSecs"   -Type DWord  -Value 600
Set-GPRegistryValue -Name $gpo -Key $sys -ValueName "DontDisplayLastUserName" -Type DWord  -Value 1
Set-GPRegistryValue -Name $gpo -Key $sys -ValueName "LegalNoticeCaption"      -Type String -Value "Office Lab - Authorized use only"
Set-GPRegistryValue -Name $gpo -Key $sys -ValueName "LegalNoticeText"         -Type String -Value "This system is for authorized Office Lab employees only. All activity is monitored and logged."
foreach ($p in "DomainProfile","StandardProfile","PublicProfile") {
    Set-GPRegistryValue -Name $gpo -Key "HKLM\Software\Policies\Microsoft\WindowsFirewall\$p" -ValueName "EnableFirewall" -Type DWord -Value 1
}
Set-GPRegistryValue -Name $gpo -Key "HKLM\Software\Policies\Microsoft\Windows\RemovableStorageDevices" -ValueName "Deny_All" -Type DWord -Value 1
Set-GPRegistryValue -Name $gpo -Key "HKLM\Software\Policies\Microsoft\Windows NT\DNSClient" -ValueName "EnableMulticast" -Type DWord -Value 0
```

**Verify on a client** (Terminal **as Administrator**, using `/` switches):

```powershell
gpupdate /force
gpresult /r /scope computer      # Applied GPOs: LAPS + Hardening + Default Domain Policy
```

RSoP (`rsop.msc`) on PC-IT01 confirmed the settings under *Administrative Templates → System → Removable Storage Access*, *Network → DNS Client* and *System → LAPS*. SMBv1 was confirmed disabled: `Get-SmbServerConfiguration` → `EnableSMB1Protocol: False`.

## 5. Audit policy

**Why:** Security is also about **detecting** attacks. Frameworks like ISO 27001 and NSM's grunnprinsipper require being able to answer: *who logged on, who failed, who created or changed an account?*

`GPO_Audit_Baseline` (linked to the domain) → *Computer Configuration → Policies → Windows Settings → Security Settings → Advanced Audit Policy Configuration*:

| Category | Subcategory | Success | Failure |
|---|---|---|---|
| Account Logon | Credential Validation | ✅ | ✅ |
| Account Management | User Account Management | ✅ | ✅ |
| Account Management | Security Group Management | ✅ | |
| Logon/Logoff | Logon | ✅ | ✅ |
| Logon/Logoff | Account Lockout | | ✅ |
| Policy Change | Audit Policy Change | ✅ | |
| DS Access | Directory Service Changes | ✅ | |

**Evidence collected** on DC01:

| Event ID | Meaning | Captured |
|---|---|---|
| 4740 | Account locked out | `ola.nordmann` after the lockout test |
| 4720 | User account created | Creation of `adm.christoffer` (who and when) |
| 4726 | User account deleted | Deletion of test user `test.audit` |

```powershell
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4720} -MaxEvents 1 | Format-List TimeCreated, Message
```

> ⚠️ **Open remediation item:** DC01 logs *Success* but not *Failure* for User Account Management. `gpresult /h` showed no *Advanced Audit Configuration* section, which means the settings were not saved in `GPO_Audit_Baseline` and the Default Domain Controllers Policy is still the effective source. **Fix:** configure the subcategories in the GPO and link it to `OU=Domain Controllers` with link order 1. See [Troubleshooting #10](10-troubleshooting-log.md).

## 6. Compliance report

[`Get-ComplianceReport.ps1`](../scripts/Get-ComplianceReport.ps1) is a **read-only** script that checks the domain against this baseline and writes an HTML report with PASS / WARN / FAIL.

| Area | Checks |
|---|---|
| Password policy | Length, complexity, history, lockout, reversible encryption |
| Privileged access | Members of Domain/Enterprise/Schema Admins, admins in Protected Users, built-in Administrator usage |
| Users | Password never expires / not required, inactive, never logged on, old passwords, accounts outside managed OUs |
| Computers | Correct OU, inactive computers, LAPS password present per PC |
| Group Policy | Security GPOs linked and enabled |
| Domain controller | SMBv1 disabled, auditing of account management |

```powershell
cd C:\Scripts
Set-ExecutionPolicy -Scope Process Bypass -Force
.\Get-ComplianceReport.ps1        # Saves to C:\Reports and opens in the browser
```

### First run: 68 % (19 PASS, 2 WARN, 7 FAIL)

| Finding | Status | Root cause | Remediation |
|---|---|---|---|
| `Christoffer` – password not required | FAIL | Local setup account carried into the domain with weak flags | Account **disabled** (kept for audit trail) |
| `Christoffer` in default Users container | WARN | Same legacy account | Resolved by disabling |
| `Administrator` – password never expires | FAIL | Default on the built-in account | `PasswordNeverExpires` set to false |
| LAPS missing on all 4 PCs | FAIL | Computers lacked self-permission on the OU | `Set-LapsADComputerSelfPermission` + `Invoke-LapsPolicyProcessing` |
| User Account Management auditing | FAIL | Audit settings not in the effective GPO | Open item (see section 5) |
| Built-in Administrator used recently | WARN | Used during setup | Daily admin work moved to `adm.christoffer` |

This is the real compliance cycle: **measure → find → remediate → measure again**.

## Screenshots

- [ ] `Get-ADDefaultDomainPasswordPolicy` before and after
- [ ] "Account is locked out" on PC-IT01
- [ ] Event 4740 / 4720 / 4726 in the Security log
- [ ] Domain Admins with only two members
- [ ] `Get-LapsADPassword` for all four PCs
- [ ] RSoP showing applied GPOs on PC-IT01
- [ ] Logon banner at boot
- [ ] Compliance report – first run (68 %)
- [ ] Compliance report – after remediation

## Next steps

- [ ] Close the audit remediation item
- [ ] Mapped drives and company wallpaper (user GPOs)
- [ ] Compare against the Microsoft Security Compliance Toolkit baseline
- [ ] Schedule the compliance report weekly with Task Scheduler
