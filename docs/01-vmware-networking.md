# 01 – VMware Networking

**Goal:** Give the lab its own network (10.10.10.0/24) with internet access, separated from the home network.

## Why NAT (and not bridged)

| Option | Result |
|---|---|
| Bridged | VMs sit directly on the home network. DC01's DHCP would hand out addresses to home devices and compete with the router. ❌ |
| Host-only | Isolated, but no internet. ❌ |
| **NAT (VMnet8), VMware DHCP off** | Own subnet, internet through the host, DC01 is the only DHCP server. ✅ |

> **Plan vs reality:** The original plan used a custom VMnet2. VMware Workstation only allows one NAT network, which is VMnet8, so the lab uses VMnet8 instead.

## Steps

1. VMware → **Edit → Virtual Network Editor**
2. Click **Change Settings** (requires admin). Before this, all settings are greyed out.
3. Select **VMnet8** (type NAT).
4. **Uncheck** *Use local DHCP service to distribute IP address to VMs*
   - *Why:* DC01 will run DHCP. Two DHCP servers on one network give unpredictable results.
5. Set **Subnet IP** `10.10.10.0`, **Subnet mask** `255.255.255.0`
6. **NAT Settings…** → confirm **Gateway IP** `10.10.10.2`
7. **Apply → OK**

## Assigning VMs to the network

For every VM: **VM → Settings → Network Adapter** → **NAT** (or *Custom: VMnet8 (NAT)*, which is the same).

## Verification

From DC01 (after phase 02):

```powershell
ping 10.10.10.2     # Reply from 10.10.10.2 = gateway reachable
ping 1.1.1.1        # Replies = internet works through NAT
```

- [x] VMnet8: NAT, subnet 10.10.10.0, DHCP disabled
- [x] Gateway 10.10.10.2 reachable from DC01

## Screenshots

- [ ] Virtual Network Editor with VMnet8 selected
- [ ] NAT Settings showing gateway 10.10.10.2
- [ ] VM Network Adapter set to NAT
- [ ] Successful `ping 10.10.10.2`

## Notes

VMnet8 originally used VMware's default subnet (192.168.59.0). This caused *Destination host unreachable* when DC01 pinged its gateway. See [Troubleshooting #1](10-troubleshooting-log.md).
