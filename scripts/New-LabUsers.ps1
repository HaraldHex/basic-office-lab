<#
.SYNOPSIS
    Bulk-creates lab users from users.csv and adds them to their department group.

.DESCRIPTION
    Reads FirstName, LastName, Department and Title from a CSV file.
    Each user is created in OU=<Department>,OU=Users,OU=OFFICE and added to GG_<Department>.
    Username format: firstname.lastname (lowercase, max 20 characters).
    Users must change their password at first logon.

    The initial password is entered at runtime and is never stored in the script or the repo.

.PARAMETER CsvPath
    Path to the CSV file. Defaults to users.csv in the same folder as the script.

.EXAMPLE
    .\New-LabUsers.ps1
    .\New-LabUsers.ps1 -CsvPath .\more-users.csv

.NOTES
    Run New-LabOUs.ps1 first. Run on DC01 in PowerShell as Administrator.
#>

param(
    [string]$CsvPath = (Join-Path $PSScriptRoot "users.csv")
)

Import-Module ActiveDirectory

$Domain    = Get-ADDomain
$DomainDN  = $Domain.DistinguishedName
$UPNSuffix = $Domain.DNSRoot                       # office.lab

if (-not (Test-Path $CsvPath)) {
    Write-Error "CSV file not found: $CsvPath"
    exit 1
}

$InitialPassword = Read-Host "Enter initial password for all new users" -AsSecureString
$Users = Import-Csv $CsvPath

foreach ($u in $Users) {
    $sam = ("{0}.{1}" -f $u.FirstName, $u.LastName).ToLower()
    if ($sam.Length -gt 20) { $sam = $sam.Substring(0, 20) }   # sAMAccountName limit

    $ouPath = "OU=$($u.Department),OU=Users,OU=OFFICE,$DomainDN"
    $group  = "GG_$($u.Department)"

    if (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue) {
        Write-Host "Exists:  $sam" -ForegroundColor DarkGray
        continue
    }

    try {
        New-ADUser `
            -Name              "$($u.FirstName) $($u.LastName)" `
            -GivenName         $u.FirstName `
            -Surname           $u.LastName `
            -DisplayName       "$($u.FirstName) $($u.LastName)" `
            -SamAccountName    $sam `
            -UserPrincipalName "$sam@$UPNSuffix" `
            -Title             $u.Title `
            -Department        $u.Department `
            -Path              $ouPath `
            -AccountPassword   $InitialPassword `
            -ChangePasswordAtLogon $true `
            -Enabled           $true

        Add-ADGroupMember -Identity $group -Members $sam
        Write-Host "Created: $sam  ->  $($u.Department)  ($group)" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed:  $sam  -  $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nDone." -ForegroundColor Cyan
