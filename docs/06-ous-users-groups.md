# 06 – OUs, Users and Groups

**Goal:** Organize Active Directory like a real company, with a clear structure that Group Policies and permissions can build on.

## Why not use the default containers

The built-in `Users` and `Computers` folders are **containers**, not OUs. You **can't link Group Policies to them**. Creating your own OUs is what makes per-department management possible.

## OU structure

```
office.lab
└── OFFICE
    ├── Users
    │   ├── IT
    │   ├── Finance
    │   ├── Sales
    │   └── HR
    ├── Computers
    │   └── Workstations
    └── Groups
```

**Why a top-level `OFFICE` OU:** It separates your objects from built-in ones and gives one place to apply company-wide policies.

## Groups

| Group | Members | Used for |
|---|---|---|
| GG_IT | IT users | IT share, admin tools |
| GG_Finance | Finance users | Finance share |
| GG_Sales | Sales users | Sales share |
| GG_HR | HR users | HR share |
| GG_AllStaff | All of the above | Common share |

**Why groups, not individual users:** Permissions are given to groups. When someone joins or leaves, you change group membership, not every folder.

`GG_` = Global Group. A clear prefix makes the group type obvious at a glance.

## Steps

Run the scripts from the `scripts/` folder on DC01 (PowerShell as Administrator):

```powershell
.\New-LabOUs.ps1      # Creates OUs and groups
.\New-LabUsers.ps1    # Creates users from users.csv and adds them to groups
```

Optional: send newly joined computers straight to the Workstations OU:

```powershell
redircmp "OU=Workstations,OU=Computers,OU=OFFICE,DC=office,DC=lab"
```

## Verification

```powershell
Get-ADOrganizationalUnit -Filter * | Select-Object DistinguishedName
Get-ADUser -Filter * -SearchBase "OU=Users,OU=OFFICE,DC=office,DC=lab" | Select-Object Name, SamAccountName
Get-ADGroupMember GG_Finance
```

- [ ] OU structure created
- [ ] Users in correct department OUs
- [ ] Users are members of the correct groups

## Screenshots to take

- [ ] ADUC showing the full OU tree
- [ ] A user's **Member Of** tab
- [ ] PowerShell output from the user script

## Notes

