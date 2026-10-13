# 04 – DNS

**Goal:** Make DC01 resolve both internal names (`office.lab`) and internet names, and confirm clients can find the domain.

## How it works

```
Client asks DC01: "Where is pc-it01.office.lab?"   → DC01 answers from its own zone
Client asks DC01: "Where is microsoft.com?"         → DC01 forwards to 1.1.1.1 / 8.8.8.8
Client asks DC01: "Where is a domain controller?"   → DC01 answers with SRV records
```

## Steps

### 1. Add forwarders
**Why:** DC01 only knows `office.lab`. Forwarders send every other query to public DNS so VMs can reach the internet.

GUI: **DNS Manager** → right-click **DC01** → **Properties** → **Forwarders** → add `1.1.1.1` and `8.8.8.8`.

```powershell
Add-DnsServerForwarder -IPAddress 1.1.1.1, 8.8.8.8
```

### 2. Create a reverse lookup zone
**Why:** Allows IP → name lookups (`nslookup 10.10.10.10` returns `DC01`). Many tools and logs rely on this.

```powershell
Add-DnsServerPrimaryZone -NetworkId "10.10.10.0/24" -ReplicationScope Domain
# Register DC01's own PTR record
ipconfig /registerdns
```

### 3. Check the SRV records
These records are how clients find the domain controller.

```powershell
nslookup -type=SRV _ldap._tcp.dc._msdcs.office.lab
```

Expected answer: `dc01.office.lab`, port 389.

## Verification

```powershell
Resolve-DnsName dc01.office.lab     # 10.10.10.10
Resolve-DnsName microsoft.com       # Public IP → forwarders work
nslookup 10.10.10.10                # dc01.office.lab → reverse zone works
```

- [x] Forwarders configured
- [x] Reverse zone exists
- [x] SRV record found: `svr hostname = dc01.office.lab`, port 389
- [x] Internet names resolve (`microsoft.com` returned A and AAAA records)

## Screenshots to take

- [ ] DNS Manager showing forward zone, `_msdcs` and reverse zone
- [ ] Forwarders tab
- [ ] `nslookup` SRV output

## Notes

