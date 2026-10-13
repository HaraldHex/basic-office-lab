# 02 – Server Installation

**Goal:** Install Windows Server, give it a fixed identity (name and static IP) and prepare it to become a domain controller.

## VM settings

| Setting | Value |
|---|---|
| Name | DC01 |
| vCPU / RAM / Disk | 2 / 4 GB / 60 GB |
| Network | VMnet2 |
| Edition | Windows Server Standard **(Desktop Experience)** |

**Why Desktop Experience:** It provides the GUI tools (Server Manager, ADUC, GPMC), which makes the lab easier to document with screenshots. Server Core is a good later challenge.

## Steps

### 1. Install Windows Server
Install from ISO, choose the Desktop Experience edition, set a strong local Administrator password.

> 📸 **Take a VMware snapshot:** `DC01 – clean install`

### 2. Rename the server
**Why:** The computer name is written into Active Directory during promotion. Renaming afterwards is possible but messy.

```powershell
Rename-Computer -NewName "DC01" -Restart
```

### 3. Set a static IP
**Why:** DHCP and DNS clients point to this address. If it changed, the whole network would break.

```powershell
# Find the interface name (usually Ethernet0)
Get-NetAdapter

New-NetIPAddress -InterfaceAlias "Ethernet0" -IPAddress 10.10.10.10 -PrefixLength 24 -DefaultGateway 10.10.10.2
Set-DnsClientServerAddress -InterfaceAlias "Ethernet0" -ServerAddresses 10.10.10.10
```

> DNS points to **itself**. The DNS role doesn't exist yet, so internet name resolution won't work until phase 03. That's expected.

### 4. Set time zone and install updates
Correct time matters: Kerberos authentication fails if clocks differ by more than 5 minutes.

```powershell
Set-TimeZone -Id "W. Europe Standard Time"
```

## Verification

```powershell
hostname                 # DC01
Get-NetIPConfiguration   # 10.10.10.10, gateway 10.10.10.2, DNS 10.10.10.10
ping 10.10.10.2          # Gateway reachable
```

- [ ] Hostname is DC01
- [ ] Static IP, gateway and DNS are correct

> 📸 **Take a VMware snapshot:** `DC01 – before AD DS`

## Screenshots to take

- [ ] Edition selection (Desktop Experience)
- [ ] `Get-NetIPConfiguration` output
- [ ] System properties showing the name DC01

## Notes

