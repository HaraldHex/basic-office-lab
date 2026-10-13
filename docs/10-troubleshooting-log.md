# 10 – Troubleshooting Log

**Goal:** Record every problem, its cause and the fix. This is often the most valuable part of a lab for employers, because it shows how you think when something breaks.

## How to log a problem

Use this template for each issue:

```markdown
### Issue #X: Short description
- **Phase:** e.g. 07 – Domain join
- **Symptom:** What happened? Exact error message?
- **Investigation:** What did I check, and in what order?
- **Root cause:** Why did it happen?
- **Fix:** What solved it?
- **Lesson learned:** What will I do differently?
```

---

## My issues

### Issue #1: 
- **Phase:** 
- **Symptom:** 
- **Investigation:** 
- **Root cause:** 
- **Fix:** 
- **Lesson learned:** 

---

## Common pitfalls (reference)

| Symptom | Likely cause | Check / fix |
|---|---|---|
| "An Active Directory Domain Controller could not be contacted" | Client DNS isn't 10.10.10.10 | `ipconfig /all`; check DHCP option 006 |
| Client gets 169.254.x.x address | DHCP not authorized, scope inactive or VM on wrong VMnet | DHCP console; VM network adapter |
| VMs have no internet | Missing DNS forwarders or wrong gateway | `Resolve-DnsName microsoft.com`; option 003 = 10.10.10.2 |
| Can't join domain at all | Windows 11 **Home** edition | Upgrade to Pro |
| Login fails with time/clock error | Clock difference > 5 min (Kerberos) | `w32tm /query /status` |
| GPO not applied | GPO linked to wrong OU, or computer/user object in default container | `gpresult /r`; check object location in ADUC |
| Password policy not working | Policy linked to an OU instead of the domain | Use Default Domain Policy |
| User can't open share | NTFS or share permission missing, or user not in group | Effective Access tab; log off/on after group change |
| Duplicate SID / trust errors after cloning | VM cloned without sysprep | Use fresh installs or run `sysprep /generalize` |

## Useful commands

```powershell
ipconfig /all
nslookup -type=SRV _ldap._tcp.dc._msdcs.office.lab
dcdiag /v
Test-ComputerSecureChannel -Verbose      # On a client: is the domain trust OK?
gpresult /h C:\gp-report.html
Get-WinEvent -LogName System -MaxEvents 20
```
