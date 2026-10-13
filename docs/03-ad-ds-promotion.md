# 03 – AD DS and Domain Controller Promotion

**Goal:** Install Active Directory Domain Services and create the `office.lab` forest with DC01 as its first domain controller.

## Key concepts

| Term | Meaning |
|---|---|
| **Forest** | The top-level security boundary. This lab has one forest. |
| **Domain** | `office.lab`, containing users, computers and groups. |
| **Domain Controller** | The server that stores the AD database and authenticates logins. |
| **DSRM password** | Directory Services Restore Mode, used to recover AD if it breaks. Store it safely. |

## Steps (GUI)

1. **Server Manager** → **Manage** → **Add Roles and Features**.
2. Select **Active Directory Domain Services** → add required features → **Install**.
3. Click the yellow flag → **Promote this server to a domain controller**.
4. Select **Add a new forest** → Root domain name: `office.lab`.
5. Functional levels: leave at the highest available. Keep **DNS server** and **Global Catalog** checked.
6. Set the **DSRM password**.
7. Ignore the DNS delegation warning (expected, there's no parent zone).
8. NetBIOS name: `OFFICE`.
9. Leave default paths → **Install**. The server restarts.

## Steps (PowerShell alternative)

```powershell
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

Install-ADDSForest `
    -DomainName "office.lab" `
    -DomainNetbiosName "OFFICE" `
    -InstallDns `
    -Force
# You'll be prompted for the DSRM password.
```

## Why DNS is installed with AD DS

AD stores the location of domain controllers as **SRV records** in DNS. Installing DNS on the DC means these records are created and maintained automatically.

## Verification

After restart, log in as `OFFICE\Administrator` (the first restart can take 5–10 minutes).

> **Important:** Use `OFFICE\Administrator` for all further server work. A local account created during installation (in this lab, *Christoffer*) becomes an ordinary domain user after promotion. It can log in, but it is **not** a member of *Enterprise Admins* and cannot authorize DHCP (see [Troubleshooting #2](10-troubleshooting-log.md)).

```powershell
Get-ADDomain | Select-Object DNSRoot, NetBIOSName, PDCEmulator
Get-ADDomainController | Select-Object Name, IPv4Address, IsGlobalCatalog
dcdiag /q          # No output = no errors
```

- [x] Promotion reported *Operation completed successfully* (the two yellow DNS delegation warnings are expected)
- [x] Login as `OFFICE\Administrator` works
- [x] Server Manager shows Domain: `office.lab`
- [ ] `dcdiag /q` reports no errors

> 📸 **Take a VMware snapshot:** `DC01 – domain controller`

## Screenshots to take

- [ ] "Add a new forest" with `office.lab`
- [ ] Prerequisites check passed
- [ ] Login screen showing `OFFICE\`
- [ ] Active Directory Users and Computers showing the domain

## Notes

