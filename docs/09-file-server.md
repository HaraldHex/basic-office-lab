# 09 – File Server and Permissions

**Goal:** Create department shares where each department can only access its own data.

> **Lab note:** File shares run on DC01 to save resources. In production, file services belong on a separate member server. Domain controllers should do as little as possible.

## Share and NTFS permissions

Windows checks **both** permission layers. The **most restrictive** wins.

| Layer | Applies when | Lab approach |
|---|---|---|
| Share permissions | Accessing over the network | Broad: Authenticated Users = Change |
| NTFS permissions | Always (network and local) | Precise: only the department group |

**Why this approach:** Managing access in one place (NTFS) avoids confusing conflicts between the two layers. It's the common best practice.

## Shares

| Share | Folder | NTFS: Modify | Mapped as |
|---|---|---|---|
| Common | `C:\Shares\Common` | GG_AllStaff | S: |
| IT | `C:\Shares\IT` | GG_IT | – |
| Finance | `C:\Shares\Finance` | GG_Finance | F: |
| Sales | `C:\Shares\Sales` | GG_Sales | – |
| HR | `C:\Shares\HR` | GG_HR | H: |

## Steps (example: Finance)

```powershell
New-Item -Path "C:\Shares\Finance" -ItemType Directory

# Share: broad access, NTFS controls the rest
New-SmbShare -Name "Finance" -Path "C:\Shares\Finance" `
    -ChangeAccess "Authenticated Users" -FullAccess "Administrators" `
    -FolderEnumerationMode AccessBased
```

**NTFS** (folder → Properties → Security → Advanced):
1. **Disable inheritance** → convert inherited permissions.
2. Remove **Users**.
3. Keep **SYSTEM** and **Administrators** (Full control).
4. Add **GG_Finance** → **Modify**.

**Why remove Users:** The inherited `Users` entry would let every domain user read the folder.

**Why Access-Based Enumeration:** Users only see folders they have access to. Less clutter, fewer questions.

## Verification

| Test | Expected |
|---|---|
| Finance user opens `\\DC01\Finance` | ✅ Access, can create files |
| Sales user opens `\\DC01\Finance` | ❌ Access denied |
| HR user browses `\\DC01` | Finance folder not visible (ABE) |

```powershell
Get-SmbShare
Get-Acl C:\Shares\Finance | Format-List
```

## Screenshots to take

- [ ] Advanced Security Settings for one share
- [ ] Successful access from the correct department
- [ ] "Access denied" from another department

## Notes

