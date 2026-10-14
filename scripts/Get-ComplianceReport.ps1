<#
.SYNOPSIS
    Basic Office Lab - Active Directory compliance report.

.DESCRIPTION
    Checks users, computers, privileged groups, password policy, LAPS and Group Policy
    against the lab's security baseline, and writes an HTML report with PASS / WARN / FAIL.

    Read-only: the script changes nothing in Active Directory.

.PARAMETER OutputFolder
    Where the report is saved. Default: C:\Reports

.PARAMETER InactiveDays
    Accounts with no logon for this many days are flagged. Default: 30

.EXAMPLE
    Set-ExecutionPolicy -Scope Process Bypass
    .\Get-ComplianceReport.ps1

.NOTES
    Run on DC01 as a Domain Admin (e.g. adm.christoffer).
#>

param(
    [string]$OutputFolder = "C:\Reports",
    [int]$InactiveDays = 30
)

Import-Module ActiveDirectory
Import-Module GroupPolicy

$Domain       = Get-ADDomain
$DomainDN     = $Domain.DistinguishedName
$Now          = Get-Date
$InactiveDate = $Now.AddDays(-$InactiveDays)
$Results      = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param([string]$Area, [string]$Check, [ValidateSet("PASS","WARN","FAIL","INFO")][string]$Status, [string]$Detail)
    $Results.Add([pscustomobject]@{ Area = $Area; Check = $Check; Status = $Status; Detail = $Detail })
}

# ---------------------------------------------------------------- Password policy
$pp = Get-ADDefaultDomainPasswordPolicy
Add-Result "Password policy" "Minimum length >= 12" ($(if ($pp.MinPasswordLength -ge 12) {"PASS"} else {"FAIL"})) "Current: $($pp.MinPasswordLength)"
Add-Result "Password policy" "Complexity enabled" ($(if ($pp.ComplexityEnabled) {"PASS"} else {"FAIL"})) "Current: $($pp.ComplexityEnabled)"
Add-Result "Password policy" "Password history >= 24" ($(if ($pp.PasswordHistoryCount -ge 24) {"PASS"} else {"WARN"})) "Current: $($pp.PasswordHistoryCount)"
$lockOk = ($pp.LockoutThreshold -gt 0 -and $pp.LockoutThreshold -le 10)
Add-Result "Password policy" "Account lockout configured (1-10 attempts)" ($(if ($lockOk) {"PASS"} else {"FAIL"})) "Current threshold: $($pp.LockoutThreshold)"
Add-Result "Password policy" "Reversible encryption disabled" ($(if (-not $pp.ReversibleEncryptionEnabled) {"PASS"} else {"FAIL"})) "Current: $($pp.ReversibleEncryptionEnabled)"

# ---------------------------------------------------------------- Privileged groups
$privGroups = "Domain Admins", "Enterprise Admins", "Schema Admins"
foreach ($g in $privGroups) {
    $members = @(Get-ADGroupMember -Identity $g -Recursive -ErrorAction SilentlyContinue)
    $names   = ($members | ForEach-Object { $_.SamAccountName }) -join ", "
    $status  = if ($members.Count -le 3) {"PASS"} else {"WARN"}
    Add-Result "Privileged access" "$g has 3 or fewer members" $status "$($members.Count) member(s): $names"
}

$protected = @(Get-ADGroupMember -Identity "Protected Users" -ErrorAction SilentlyContinue | ForEach-Object { $_.SamAccountName })
$admins    = @(Get-ADGroupMember -Identity "Domain Admins" -Recursive | Where-Object { $_.objectClass -eq "user" -and $_.SamAccountName -ne "Administrator" })
foreach ($a in $admins) {
    $inPU = $protected -contains $a.SamAccountName
    Add-Result "Privileged access" "$($a.SamAccountName) is in Protected Users" ($(if ($inPU) {"PASS"} else {"WARN"})) "Admin accounts should be in Protected Users"
}

$builtin = Get-ADUser -Identity "Administrator" -Properties LastLogonDate, Enabled
$bStatus = if ($builtin.LastLogonDate -and $builtin.LastLogonDate -gt $Now.AddDays(-7)) {"WARN"} else {"PASS"}
Add-Result "Privileged access" "Built-in Administrator not used for daily work" $bStatus "Last logon: $($builtin.LastLogonDate). Use named adm.* accounts instead."

# ---------------------------------------------------------------- Users
$userProps = "Enabled","PasswordNeverExpires","PasswordNotRequired","LastLogonDate","PasswordLastSet","LockedOut","whenCreated"
$users = Get-ADUser -Filter * -Properties $userProps | Where-Object { $_.SamAccountName -notin @("krbtgt","Guest") }
$enabledUsers = $users | Where-Object Enabled

$neverExpires = @($enabledUsers | Where-Object PasswordNeverExpires)
Add-Result "Users" "No enabled accounts with 'password never expires'" ($(if ($neverExpires.Count -eq 0) {"PASS"} else {"FAIL"})) (($neverExpires.SamAccountName) -join ", ")

$notRequired = @($enabledUsers | Where-Object PasswordNotRequired)
Add-Result "Users" "No accounts with 'password not required'" ($(if ($notRequired.Count -eq 0) {"PASS"} else {"FAIL"})) (($notRequired.SamAccountName) -join ", ")

$inactive = @($enabledUsers | Where-Object { $_.LastLogonDate -and $_.LastLogonDate -lt $InactiveDate })
Add-Result "Users" "No enabled accounts inactive > $InactiveDays days" ($(if ($inactive.Count -eq 0) {"PASS"} else {"WARN"})) (($inactive.SamAccountName) -join ", ")

$neverLogged = @($enabledUsers | Where-Object { -not $_.LastLogonDate -and $_.whenCreated -lt $Now.AddDays(-7) })
Add-Result "Users" "No enabled accounts that never logged on (older than 7 days)" ($(if ($neverLogged.Count -eq 0) {"PASS"} else {"WARN"})) (($neverLogged.SamAccountName) -join ", ")

$oldPw = @($enabledUsers | Where-Object { $_.PasswordLastSet -and $_.PasswordLastSet -lt $Now.AddDays(-90) })
Add-Result "Users" "No passwords older than 90 days" ($(if ($oldPw.Count -eq 0) {"PASS"} else {"WARN"})) (($oldPw.SamAccountName) -join ", ")

$locked = @(Search-ADAccount -LockedOut)
Add-Result "Users" "No locked-out accounts" ($(if ($locked.Count -eq 0) {"PASS"} else {"INFO"})) (($locked.SamAccountName) -join ", ")

$defaultContainer = @($enabledUsers | Where-Object { $_.DistinguishedName -like "*,CN=Users,$DomainDN" -and $_.SamAccountName -ne "Administrator" })
Add-Result "Users" "User accounts are in managed OUs (not the default Users container)" ($(if ($defaultContainer.Count -eq 0) {"PASS"} else {"WARN"})) (($defaultContainer.SamAccountName) -join ", ")

# ---------------------------------------------------------------- Computers
$computers = Get-ADComputer -Filter * -Properties OperatingSystem, LastLogonDate, Enabled
$workstations = $computers | Where-Object { $_.DistinguishedName -notlike "*OU=Domain Controllers*" }

$wrongOU = @($workstations | Where-Object { $_.DistinguishedName -notlike "*OU=Workstations,OU=Computers,OU=OFFICE*" })
Add-Result "Computers" "All workstations are in the Workstations OU" ($(if ($wrongOU.Count -eq 0) {"PASS"} else {"FAIL"})) (($wrongOU.Name) -join ", ")

$staleComp = @($workstations | Where-Object { $_.Enabled -and $_.LastLogonDate -and $_.LastLogonDate -lt $InactiveDate })
Add-Result "Computers" "No computers inactive > $InactiveDays days" ($(if ($staleComp.Count -eq 0) {"PASS"} else {"WARN"})) (($staleComp.Name) -join ", ")

foreach ($c in $workstations) {
    $laps = $null
    try { $laps = Get-LapsADPassword -Identity $c.Name -ErrorAction Stop } catch { }
    if ($laps -and $laps.PasswordUpdateTime) {
        Add-Result "Computers" "$($c.Name): LAPS password stored in AD" "PASS" "Last rotated: $($laps.PasswordUpdateTime) / Expires: $($laps.ExpirationTimestamp)"
    } else {
        Add-Result "Computers" "$($c.Name): LAPS password stored in AD" "FAIL" "No LAPS password found. Run gpupdate /force and Invoke-LapsPolicyProcessing on the client."
    }
}

# ---------------------------------------------------------------- Group Policy
$expectedGpos = @{
    "GPO_Workstations_LAPS"       = "OU=Workstations,OU=Computers,OU=OFFICE,$DomainDN"
    "GPO_Workstations_Hardening"  = "OU=Workstations,OU=Computers,OU=OFFICE,$DomainDN"
    "GPO_Audit_Baseline"          = $DomainDN
}
foreach ($name in $expectedGpos.Keys) {
    $target = $expectedGpos[$name]
    $links  = (Get-GPInheritance -Target $target).GpoLinks | Where-Object { $_.DisplayName -eq $name -and $_.Enabled }
    Add-Result "Group Policy" "$name is linked and enabled" ($(if ($links) {"PASS"} else {"FAIL"})) "Target: $target"
}

# ---------------------------------------------------------------- Domain controller
$smb1 = (Get-SmbServerConfiguration).EnableSMB1Protocol
Add-Result "Domain controller" "SMBv1 disabled on DC01" ($(if (-not $smb1) {"PASS"} else {"FAIL"})) "EnableSMB1Protocol: $smb1"

$audit = auditpol /get /subcategory:"User Account Management" 2>$null | Select-String "User Account Management"
$auditOk = $audit -match "Success and Failure"
Add-Result "Domain controller" "Auditing of user account management" ($(if ($auditOk) {"PASS"} else {"FAIL"})) ("$audit".Trim())

# ---------------------------------------------------------------- HTML report
$pass = @($Results | Where-Object Status -eq "PASS").Count
$warn = @($Results | Where-Object Status -eq "WARN").Count
$fail = @($Results | Where-Object Status -eq "FAIL").Count
$score = [math]::Round(($pass / [math]::Max(1, ($pass + $warn + $fail))) * 100)

$rows = foreach ($r in $Results) {
    $detail = [System.Net.WebUtility]::HtmlEncode($r.Detail)
    "<tr><td>$($r.Area)</td><td>$($r.Check)</td><td class='s $($r.Status)'>$($r.Status)</td><td>$detail</td></tr>"
}

$html = @"
<!doctype html>
<html><head><meta charset="utf-8"><title>Compliance Report - $($Domain.DNSRoot)</title>
<style>
 body{font-family:Segoe UI,Arial,sans-serif;margin:32px;color:#1f2933;background:#f7f8fa}
 h1{margin:0 0 4px} .sub{color:#52606d;margin-bottom:24px}
 .cards{display:flex;gap:16px;margin-bottom:24px}
 .card{background:#fff;border-radius:8px;padding:16px 24px;box-shadow:0 1px 3px rgba(0,0,0,.08);min-width:120px}
 .card b{display:block;font-size:28px}
 table{border-collapse:collapse;width:100%;background:#fff;box-shadow:0 1px 3px rgba(0,0,0,.08)}
 th,td{padding:10px 12px;border-bottom:1px solid #e4e7eb;text-align:left;vertical-align:top;font-size:14px}
 th{background:#1f2933;color:#fff}
 .s{font-weight:700;text-align:center;width:70px}
 .PASS{color:#0f7b3f}.WARN{color:#b26a00}.FAIL{color:#c0262d}.INFO{color:#2563eb}
</style></head><body>
<h1>Active Directory Compliance Report</h1>
<div class="sub">Domain: $($Domain.DNSRoot) &middot; Generated: $($Now.ToString("yyyy-MM-dd HH:mm")) &middot; By: $env:USERDOMAIN\$env:USERNAME</div>
<div class="cards">
 <div class="card">Score<b>$score %</b></div>
 <div class="card PASS">Pass<b>$pass</b></div>
 <div class="card WARN">Warning<b>$warn</b></div>
 <div class="card FAIL">Fail<b>$fail</b></div>
</div>
<table><tr><th>Area</th><th>Check</th><th>Status</th><th>Detail</th></tr>
$($rows -join "`n")
</table>
</body></html>
"@

if (-not (Test-Path $OutputFolder)) { New-Item -Path $OutputFolder -ItemType Directory | Out-Null }
$file = Join-Path $OutputFolder ("ComplianceReport_{0}.html" -f $Now.ToString("yyyy-MM-dd_HHmm"))
$html | Out-File -FilePath $file -Encoding utf8

Write-Host ""
Write-Host "Compliance score: $score %   PASS: $pass   WARN: $warn   FAIL: $fail" -ForegroundColor Cyan
Write-Host "Report saved to: $file" -ForegroundColor Cyan
Start-Process $file
