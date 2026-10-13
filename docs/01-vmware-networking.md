# 01 – VMware Networking

**Goal:** Create an isolated virtual network for the lab that still has internet access.

## Why a dedicated VMnet

| Option | Problem / benefit |
|---|---|
| Bridged | Lab DHCP would hand out addresses on the home network. ❌ |
| Default NAT (VMnet8) | VMware's own DHCP would compete with the lab's DHCP server. ❌ |
| **Custom VMnet2, NAT, VMware DHCP off** | Isolated, internet via NAT, DC01 is the only DHCP server. ✅ |

## Steps

1. Open **VMware Workstation** → **Edit** → **Virtual Network Editor**.
2. Click **Change Settings** (requires admin).
3. Click **Add Network…** → select **VMnet2** → **OK**.
4. With VMnet2 selected:
   - Select **NAT (shared host's IP address with VMs)**
   - **Uncheck** *Use local DHCP service to distribute IP address to VMs*
   - Subnet IP: `10.10.10.0`
   - Subnet mask: `255.255.255.0`
5. Click **NAT Settings…** and confirm the gateway IP is **10.10.10.2**.
6. Click **Apply** → **OK**.

> Only one NAT network may be available depending on your VMware version. If VMnet2 can't be set to NAT, use VMnet8 and disable its DHCP instead.

## Assigning VMs to the network

For every VM: **VM Settings** → **Network Adapter** → **Custom: Specific virtual network** → **VMnet2**.

## Verification

- [ ] VMnet2 shows type **NAT**, subnet **10.10.10.0**, DHCP **disabled**
- [ ] NAT gateway is **10.10.10.2**

## Screenshots to take

- [ ] Virtual Network Editor with VMnet2 selected (DHCP unchecked visible)
- [ ] NAT Settings window showing the gateway
- [ ] VM network adapter set to VMnet2

## Notes

*Anything unexpected?*
