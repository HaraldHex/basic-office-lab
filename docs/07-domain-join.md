# 07 – Joining Clients to the Domain

**Goal:** Install the four Windows 11 clients and join them to `office.lab`.

## Requirements

| Requirement | Why |
|---|---|
| **Windows 11 Pro** (or Enterprise/Education) | **Home edition cannot join a domain** |
| Virtual TPM | Windows 11 requires TPM 2.0. In VMware: VM Settings → Add → Trusted Platform Module (the VM must be encrypted) |
| Network on VMnet2 | Same network as DC01 |
| DNS = 10.10.10.10 | Delivered automatically by DHCP option 006 |

## VM settings

| Setting | Value |
|---|---|
| vCPU / RAM / Disk | 2 / 4 GB / 64 GB |
| Network | VMnet2 |

## Steps (repeat for each client)

### 1. Install Windows 11 Pro
Create a local account during setup.

> 💡 Build one client, take a snapshot, then repeat. Don't clone a VM that's already domain-joined.

### 2. Check networking first
**Why:** If DNS is wrong, the join will fail. Checking first saves time.

```powershell
ipconfig /all                        # IP in .100–.200, DNS 10.10.10.10
nslookup office.lab                  # Should answer 10.10.10.10
```

### 3. Rename and join

```powershell
Rename-Computer -NewName "PC-IT01" -Restart
# After restart:
Add-Computer -DomainName "office.lab" -Credential OFFICE\Administrator -Restart
```

GUI alternative: **Settings** → **System** → **About** → **Domain or workgroup** → **Change** → Domain: `office.lab`.

### 4. Log in as a domain user
At the login screen choose **Other user** and log in as e.g. `OFFICE\ola.nordmann`.

## Verification

On the client:
```powershell
(Get-WmiObject Win32_ComputerSystem).Domain   # office.lab
whoami                                         # office\username
```

On DC01:
```powershell
Get-ADComputer -Filter * | Select-Object Name, DistinguishedName
```

| Client | Joined | Domain login tested |
|---|---|---|
| PC-IT01 | ⬜ | ⬜ |
| PC-FIN01 | ⬜ | ⬜ |
| PC-SALES01 | ⬜ | ⬜ |
| PC-HR01 | ⬜ | ⬜ |

If computers landed in the default `Computers` container, move them to `OFFICE\Computers\Workstations`.

## Screenshots to take

- [ ] `ipconfig /all` showing DNS 10.10.10.10
- [ ] "Welcome to the office.lab domain" message
- [ ] ADUC showing all four computers in the Workstations OU
- [ ] DHCP console with four active leases

## Notes

