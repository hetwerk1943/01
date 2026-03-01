# Setup-Logs.ps1
# Creates the .\logs folder and applies a hardened ACL (SYSTEM + Administrators only).
# Must be run once as Administrator before starting Ultra Security Monitor.

#Requires -Version 5.1
#Requires -RunAsAdministrator

$logsPath = Join-Path $PSScriptRoot "logs"

# 1. Create the directory if it does not already exist.
if (-not (Test-Path $logsPath)) {
    New-Item -Path $logsPath -ItemType Directory -Force | Out-Null
    Write-Host "Created: $logsPath"
} else {
    Write-Host "Exists:  $logsPath"
}

# 2. Remove inherited permissions so only explicit entries apply.
icacls $logsPath /inheritance:r | Out-Null

# 3. Grant full control exclusively to SYSTEM and Administrators.
icacls $logsPath /grant:r "SYSTEM:(OI)(CI)F" | Out-Null
icacls $logsPath /grant:r "Administrators:(OI)(CI)F" | Out-Null

Write-Host "ACL applied to $logsPath – inherited permissions removed."
Write-Host "Only SYSTEM and Administrators have access."

# 4. Display the resulting ACL for verification.
icacls $logsPath
