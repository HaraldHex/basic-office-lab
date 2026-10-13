# 02 – Server Installation

**Goal:** Install Windows Server, give it a fixed identity (name and static IP) and prepare it to become a domain controller.

## VM settings

| Setting | Value |
|---|---|
| Name | DC01 |
| OS | Windows Server 2025 Datacenter Evaluation (Desktop Experience) |
| vCPU / RAM / Disk | 8 / 4 GB / 60 GB |
| Network | NAT (VMnet8) |

**Why Desktop Experience:** It includes the GUI tools (Server Manager, ADUC, GPMC), which makes the lab easier to document with screenshots.

## Steps

All commands run in **PowerShell as administrator** (right-click Start → **Terminal (Admin)**). The title bar must say *Administrator*; otherwise network changes fail with *Access is denied*.

### 1. Rename the server
**Why:** The computer name is written into Active Directory during promotion. Renaming afterwards is messy.

```powershell
Rename-Computer -NewName "DC01" -Restart
```

### 2. Set a static IP
**Why:** Clients get DC01's address from DHCP as their DNS server. If the server's own address changed, the whole network would break.

```powershell
$nic = (Get-NetAdapter | Where-Object Status -eq "Up" | Select-Object -First 1).Name
New-NetIPAddress -InterfaceAlias $nic -IPAddress 10.10.10.10 -PrefixLength 24 -DefaultGateway 10.10.10.2
Set-DnsClientServerAddress -InterfaceAlias $nic -ServerAddresses 10.10.10.10
Get-NetIPConfiguration
```

DNS points to **itself**. The DNS role doesn't exist yet, but it will after phase 03.

> `AddressState : Tentative` right after setting the IP is normal. Windows checks for duplicate addresses for a few seconds.

### 3. Enable the built-in Administrator account
**Why:** When the server is promoted, **only the built-in Administrator** becomes the domain administrator (`OFFICE\Administrator`) with full rights. Other local accounts become ordinary domain users.

```powershell
net user Administrator /active:yes
net user Administrator *
```

The password must meet complexity requirements (length, upper/lower case, numbers).

### 4. Verify connectivity

```powershell
ping 10.10.10.2
```

> 📸 **VMware snapshot:** `Before AD DS`

## Verification

- [x] Hostname is DC01
- [x] IP 10.10.10.10, gateway 10.10.10.2, DNS 10.10.10.10
- [x] Gateway responds to ping
- [x] Administrator account enabled with a known password

## Screenshots

- [ ] `Get-NetIPConfiguration` output
- [ ] Settings → System → About showing DC01 and Windows Server 2025
- [ ] Successful ping to the gateway

## Notes

The first attempt to set the IP failed with *Access is denied* because PowerShell wasn't running as administrator.
