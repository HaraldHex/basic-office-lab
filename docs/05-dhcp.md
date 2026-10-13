# 05 – DHCP

**Goal:** Let DC01 hand out IP addresses to the clients, and make sure every client receives DC01 as its DNS server.

## Why DHCP options matter

The IP address alone isn't enough. The **options** tell clients where everything is:

| Option | Name | Value | Why |
|---|---|---|---|
| 003 | Router | 10.10.10.2 | Path to the internet (VMware NAT) |
| 006 | DNS Servers | **10.10.10.10** | **Critical:** clients must use DC01 to find the domain |
| 015 | DNS Domain Name | office.lab | Lets clients resolve short names like `dc01` |

## Steps

### 1. Install the role

```powershell
Install-WindowsFeature DHCP -IncludeManagementTools
```

### 2. Authorize DHCP in Active Directory
**Why:** A domain-joined DHCP server won't hand out addresses until it's authorized. This prevents rogue DHCP servers on the network.

> **Requires Enterprise Admins.** Run this as `OFFICE\Administrator`. Running it as an ordinary admin account fails with *PermissionDenied* (see [Troubleshooting #2](10-troubleshooting-log.md)). Check with `whoami` first.

```powershell
Add-DhcpServerInDC -DnsName "dc01.office.lab" -IPAddress 10.10.10.10

# Create the DHCP security groups and restart the service
netsh dhcp add securitygroups
Restart-Service dhcpserver

# Clear the "complete DHCP configuration" warning in Server Manager
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\ServerManager\Roles\12 -Name ConfigurationState -Value 2
```

### 3. Create the scope

```powershell
Add-DhcpServerv4Scope -Name "Office LAN" `
    -StartRange 10.10.10.100 -EndRange 10.10.10.200 `
    -SubnetMask 255.255.255.0 -LeaseDuration 8.00:00:00 -State Active
```

**Why 8 days:** Standard for desktop networks where devices rarely move. Shorter leases suit guest or Wi-Fi networks.

### 4. Set the scope options

```powershell
Set-DhcpServerv4OptionValue -ScopeId 10.10.10.0 `
    -Router 10.10.10.2 -DnsServer 10.10.10.10 -DnsDomain "office.lab"
```

## Verification

```powershell
Get-DhcpServerInDC
Get-DhcpServerv4Scope
Get-DhcpServerv4OptionValue -ScopeId 10.10.10.0
```

On a client (once installed): `ipconfig /all` should show an address in the .100–.200 range and **DNS Servers: 10.10.10.10**.

- [x] `Get-DhcpServerInDC` lists `10.10.10.10  dc01.office.lab`
- [x] Scope *Office LAN* is Active (10.10.10.100 – 10.10.10.200, 8-day lease)
- [x] Options 003, 006 and 015 set
- [x] First client (PC-IT01) received 10.10.10.100, gateway 10.10.10.2, DNS suffix office.lab

## Screenshots to take

- [ ] DHCP console with the scope and green IPv4 icon
- [ ] Scope Options view
- [ ] `Address Leases` once clients are online

## Notes

