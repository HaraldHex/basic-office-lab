# 06 – OUs, Users and Groups

**Goal:** Organize Active Directory like a real company, with a structure that Group Policies and permissions can build on.

## Why not use the default containers

The built-in `Users` and `Computers` folders are **containers**, not OUs. You **can't link Group Policies to them**. Your own OUs make per-department management possible.

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

**Why a top-level `OFFICE` OU:** It separates the company's objects from built-in ones and gives one place to apply company-wide policies.

## Groups

| Group | Members | Used for |
|---|---|---|
| GG_IT | Ola Nordmann | IT share, admin tools |
| GG_Finance | Per Johansen | Finance share |
| GG_Sales | Lars Larsen | Sales share |
| GG_HR | Emma Berg | HR share |
| GG_AllStaff | GG_IT, GG_Finance, GG_Sales, GG_HR | Common share |

**Why groups, not individual users:** Permissions are given to groups. When someone joins or leaves, only group membership changes.

`GG_` = Global Group. A prefix makes the group type clear at a glance. **GG_AllStaff** contains the department groups (group nesting), so everyone gets common access without being added twice.

## Users

| Name | Username | Department | Title |
|---|---|---|---|
| Ola Nordmann | ola.nordmann | IT | IT Administrator |
| Per Johansen | per.johansen | Finance | Accountant |
| Lars Larsen | lars.larsen | Sales | Sales Representative |
| Emma Berg | emma.berg | HR | HR Advisor |

## Commands used

Run on DC01 as `OFFICE\Administrator`.

```powershell
# OUs
New-ADOrganizationalUnit -Name "OFFICE" -Path "DC=office,DC=lab"
New-ADOrganizationalUnit -Name "Users" -Path "OU=OFFICE,DC=office,DC=lab"
New-ADOrganizationalUnit -Name "Computers" -Path "OU=OFFICE,DC=office,DC=lab"
New-ADOrganizationalUnit -Name "Groups" -Path "OU=OFFICE,DC=office,DC=lab"
New-ADOrganizationalUnit -Name "Workstations" -Path "OU=Computers,OU=OFFICE,DC=office,DC=lab"
New-ADOrganizationalUnit -Name "IT" -Path "OU=Users,OU=OFFICE,DC=office,DC=lab"
New-ADOrganizationalUnit -Name "Finance" -Path "OU=Users,OU=OFFICE,DC=office,DC=lab"
New-ADOrganizationalUnit -Name "Sales" -Path "OU=Users,OU=OFFICE,DC=office,DC=lab"
New-ADOrganizationalUnit -Name "HR" -Path "OU=Users,OU=OFFICE,DC=office,DC=lab"

# Groups
New-ADGroup -Name "GG_IT" -GroupScope Global -GroupCategory Security -Path "OU=Groups,OU=OFFICE,DC=office,DC=lab"
New-ADGroup -Name "GG_Finance" -GroupScope Global -GroupCategory Security -Path "OU=Groups,OU=OFFICE,DC=office,DC=lab"
New-ADGroup -Name "GG_Sales" -GroupScope Global -GroupCategory Security -Path "OU=Groups,OU=OFFICE,DC=office,DC=lab"
New-ADGroup -Name "GG_HR" -GroupScope Global -GroupCategory Security -Path "OU=Groups,OU=OFFICE,DC=office,DC=lab"
New-ADGroup -Name "GG_AllStaff" -GroupScope Global -GroupCategory Security -Path "OU=Groups,OU=OFFICE,DC=office,DC=lab"
Add-ADGroupMember -Identity "GG_AllStaff" -Members "GG_IT","GG_Finance","GG_Sales","GG_HR"

# Users (example; repeated for each user)
New-ADUser -Name "Ola Nordmann" -GivenName "Ola" -Surname "Nordmann" -SamAccountName "ola.nordmann" `
    -Department "IT" -Title "IT Administrator" `
    -Path "OU=IT,OU=Users,OU=OFFICE,DC=office,DC=lab" `
    -AccountPassword (Read-Host "Password" -AsSecureString) -Enabled 1
Add-ADGroupMember -Identity "GG_IT" -Members "ola.nordmann"

# Move the first client and redirect future computers to the Workstations OU
Move-ADObject -Identity "CN=PC-IT01,CN=Computers,DC=office,DC=lab" -TargetPath "OU=Workstations,OU=Computers,OU=OFFICE,DC=office,DC=lab"
redircmp "OU=Workstations,OU=Computers,OU=OFFICE,DC=office,DC=lab"
```

**Why `redircmp`:** New computers that join the domain land in the default `Computers` container, where no GPOs apply. Redirecting them to `Workstations` means every new PC is managed from the moment it joins.

> For bulk creation, see [`New-LabOUs.ps1`](../scripts/New-LabOUs.ps1) and [`New-LabUsers.ps1`](../scripts/New-LabUsers.ps1).

## Verification

```powershell
Get-ADOrganizationalUnit -Filter * | Select-Object Name
Get-ADUser -Filter * -SearchBase "OU=Users,OU=OFFICE,DC=office,DC=lab" | Select-Object Name, SamAccountName
Get-ADGroupMember -Identity "GG_AllStaff" | Select-Object Name
```

- [x] OU structure created
- [x] 4 users in their department OUs
- [x] Users are members of their department group
- [x] PC-IT01 moved to Workstations, `redircmp` reported *Redirection was successful*

## Screenshots

- [ ] ADUC showing the full OU tree
- [ ] `Get-ADUser` output listing the 4 users
- [ ] A user's **Member Of** tab

## Notes

Pasting a command block twice gives red *already exists* errors. They're harmless: the objects were created on the first run.
