# 08 – Group Policy

**Goal:** Manage all clients centrally instead of configuring each PC by hand.

## How Group Policy is applied

Policies apply in this order, and the last one wins on conflict:

```
Local → Site → Domain → OU (parent → child)
```

A GPO only affects objects in the OU it's linked to (and child OUs). That's why the OU structure from phase 06 matters.

## Policies in this lab

| GPO | Linked to | Type | What it does |
|---|---|---|---|
| Default Domain Policy | `office.lab` | Computer | Password and lockout policy |
| GPO_AllStaff_Wallpaper | `OFFICE\Users` | User | Company desktop wallpaper |
| GPO_AllStaff_DriveMaps | `OFFICE\Users` | User | Maps department and common drives |

## 1. Password and lockout policy

**Why the Default Domain Policy:** Domain account password policy is only applied from a GPO linked at the **domain level**. Linked to an OU, it has no effect on domain accounts.

**Path:** Computer Configuration → Policies → Windows Settings → Security Settings → Account Policies

| Setting | Value |
|---|---|
| Minimum password length | 12 |
| Password must meet complexity requirements | Enabled |
| Account lockout threshold | 5 invalid attempts |
| Account lockout duration | 15 minutes |

## 2. Desktop wallpaper

1. Put the image in a share everyone can read, e.g. `\\DC01\Common\wallpaper.jpg`.
2. **GPMC** → right-click `OFFICE\Users` → **Create a GPO and link it here** → `GPO_AllStaff_Wallpaper`.
3. **Path:** User Configuration → Policies → Administrative Templates → Desktop → Desktop → **Desktop Wallpaper**
4. Enabled, name: `\\DC01\Common\wallpaper.jpg`, style: Fill.

**Why a UNC path:** The client reads the file over the network. A local path like `C:\` would point to the client's own disk.

## 3. Mapped drives

**Path:** User Configuration → Preferences → Windows Settings → **Drive Maps**

| Drive | Path | Item-level targeting |
|---|---|---|
| S: | `\\DC01\Common` | None (everyone) |
| F: | `\\DC01\Finance` | Security group = GG_Finance |
| H: | `\\DC01\HR` | Security group = GG_HR |

**Why item-level targeting:** One GPO maps the right drive to the right department, instead of one GPO per department.

## Verification

On a client:
```powershell
gpupdate /force
gpresult /r          # Lists applied GPOs
```

- [ ] `gpresult /r` lists the new GPOs
- [ ] Wallpaper appears after login
- [ ] Finance user sees F:, HR user sees H:, everyone sees S:
- [ ] Weak password is rejected

## Screenshots to take

- [ ] GPMC showing the GPOs and where they're linked
- [ ] Drive Maps with item-level targeting
- [ ] `gpresult /r` output
- [ ] Client desktop with wallpaper and drives in File Explorer

## Notes

