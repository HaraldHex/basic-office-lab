<#
.SYNOPSIS
    Creates the OU structure and department security groups for the Basic Office Lab.

.DESCRIPTION
    Builds:
      OFFICE
        Users\IT, Users\Finance, Users\Sales, Users\HR
        Computers\Workstations
        Groups
    and the global security groups GG_IT, GG_Finance, GG_Sales, GG_HR, GG_AllStaff.
    Safe to run more than once: existing objects are skipped.

.NOTES
    Run on DC01 in PowerShell as Administrator.
#>

Import-Module ActiveDirectory

$DomainDN    = (Get-ADDomain).DistinguishedName      # DC=office,DC=lab
$Departments = @("IT", "Finance", "Sales", "HR")

function New-OUIfMissing {
    param([string]$Name, [string]$Path)
    $dn = "OU=$Name,$Path"
    if (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$dn'" -ErrorAction SilentlyContinue) {
        Write-Host "Exists:  $dn" -ForegroundColor DarkGray
    } else {
        New-ADOrganizationalUnit -Name $Name -Path $Path -ProtectedFromAccidentalDeletion $true
        Write-Host "Created: $dn" -ForegroundColor Green
    }
    return $dn
}

# Top-level OU
$OfficeOU    = New-OUIfMissing -Name "OFFICE"    -Path $DomainDN
$UsersOU     = New-OUIfMissing -Name "Users"     -Path $OfficeOU
$ComputersOU = New-OUIfMissing -Name "Computers" -Path $OfficeOU
$GroupsOU    = New-OUIfMissing -Name "Groups"    -Path $OfficeOU
New-OUIfMissing -Name "Workstations" -Path $ComputersOU | Out-Null

# Department OUs
foreach ($dept in $Departments) {
    New-OUIfMissing -Name $dept -Path $UsersOU | Out-Null
}

# Security groups
$Groups = ($Departments | ForEach-Object { "GG_$_" }) + "GG_AllStaff"
foreach ($group in $Groups) {
    if (Get-ADGroup -Filter "Name -eq '$group'" -ErrorAction SilentlyContinue) {
        Write-Host "Exists:  $group" -ForegroundColor DarkGray
    } else {
        New-ADGroup -Name $group -GroupScope Global -GroupCategory Security -Path $GroupsOU `
            -Description "Basic Office Lab - $group"
        Write-Host "Created: $group" -ForegroundColor Green
    }
}

# Department groups are members of GG_AllStaff
foreach ($dept in $Departments) {
    Add-ADGroupMember -Identity "GG_AllStaff" -Members "GG_$dept" -ErrorAction SilentlyContinue
}

Write-Host "`nDone. OU structure and groups are ready." -ForegroundColor Cyan
