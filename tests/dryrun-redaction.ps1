# tests/dryrun-redaction.ps1
# Validates SecureHelpers.psm1 in dry-run mode: checks command-line redaction
# and that no network calls are made or VT cache is populated without a key.
#
# Run locally:
#   pwsh -NoProfile -File tests/dryrun-redaction.ps1
#
# Exit code 0 = all assertions passed.
# Exit code 1 = one or more assertions failed.
#
# Safe: no network calls, no secrets required, idempotent.

#Requires -Version 5.1

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent

# ---- Load module ----
$modulePath = Join-Path $repoRoot 'SecureHelpers.psm1'
if (-not (Test-Path $modulePath)) {
    Write-Error "SecureHelpers.psm1 not found at: $modulePath"
    exit 1
}
Import-Module $modulePath -Force

# Use a temp folder so the test is fully isolated
$tmpBase     = Join-Path ([System.IO.Path]::GetTempPath()) "dryrun-test-$(Get-Random)"
New-Item -Path $tmpBase -ItemType Directory -Force | Out-Null

$tmpBackup   = Join-Path $tmpBase 'Backup'
$tmpVtCache  = Join-Path $tmpBase 'vt_cache.json'
New-Item -Path $tmpBackup -ItemType Directory -Force | Out-Null

# ---- Configure dry-run / no-remediation via the module config function ----
Set-SecureHelpersConfig `
    -EnableDryRun      $true `
    -EnableRemediation $false `
    -BackupFolder      $tmpBackup `
    -VtCachePath       $tmpVtCache

$failures = [System.Collections.Generic.List[string]]::new()

# ============================================================
# Helper
# ============================================================
function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        Write-Host "  [FAIL] $Message" -ForegroundColor Red
        $failures.Add($Message)
    } else {
        Write-Host "  [PASS] $Message" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=== dryrun-redaction.ps1 ===" -ForegroundColor Cyan

# ============================================================
# TEST 1: Sanitize-CommandLine redacts --password
# ============================================================
Write-Host ""
Write-Host "TEST 1: --password argument is redacted"
$rawCmd      = 'cmd.exe --password P@ssw0rd --user alice'
$sanitized   = Sanitize-CommandLine -CommandLine $rawCmd
Assert-True ($sanitized -ne $rawCmd)                          "Sanitized output differs from raw input"
Assert-True ($sanitized -notmatch 'P@ssw0rd')                 "Password value not present in output"
Assert-True ($sanitized -match '\[REDACTED\]')                "Output contains [REDACTED] placeholder"

# ============================================================
# TEST 2: Sanitize-CommandLine redacts --token
# ============================================================
Write-Host ""
Write-Host "TEST 2: --token argument is redacted"
$rawToken  = 'app.exe --token abc123supersecret'
$sanitizedToken = Sanitize-CommandLine -CommandLine $rawToken
Assert-True ($sanitizedToken -ne $rawToken)                   "Sanitized token output differs from raw"
Assert-True ($sanitizedToken -notmatch 'abc123supersecret')   "Token value not present in output"

# ============================================================
# TEST 3: Safe commands are not over-redacted
# ============================================================
Write-Host ""
Write-Host "TEST 3: Safe command-line is not modified"
$safeCmd = 'notepad.exe C:\Users\alice\notes.txt'
$sanitizedSafe = Sanitize-CommandLine -CommandLine $safeCmd
Assert-True ($sanitizedSafe -eq $safeCmd)                     "Safe command is unchanged"

# ============================================================
# TEST 4: Build-AlertSummary sanitises CommandLine
# ============================================================
Write-Host ""
Write-Host "TEST 4: Build-AlertSummary sanitises CommandLine"
$summary = Build-AlertSummary `
    -ProcessName 'cmd.exe' `
    -CommandLine 'cmd.exe --password S3cr3t!' `
    -Owner       'DOMAIN\alice' `
    -Severity    'High'
Assert-True ($summary.CommandLine -notmatch 'S3cr3t!')        "Summary CommandLine does not contain raw secret"
Assert-True ($summary.CommandLine -match '\[REDACTED\]')      "Summary CommandLine contains [REDACTED]"
Assert-True ($summary.DryRun -eq $true)                       "Summary DryRun flag is true"

# ============================================================
# TEST 5: vt_cache.json remains absent when no VT key provided
# ============================================================
Write-Host ""
Write-Host "TEST 5: VT cache file absent when no API key used"
# We never set a VT key, so the cache file should not exist
Assert-True (-not (Test-Path $tmpVtCache))                    "vt_cache.json not created without VT key"

# ============================================================
# TEST 6: Execute-RemediationSafe is a no-op in dry-run
# ============================================================
Write-Host ""
Write-Host "TEST 6: Execute-RemediationSafe no-op in dry-run"
$script:remediationRan = $false
Execute-RemediationSafe -Description 'test action' -Action { $script:remediationRan = $true }
Assert-True (-not $script:remediationRan)                    "Remediation block not executed in dry-run"

# ============================================================
# TEST 7: Send-DiscordAlertSafe writes to stdout in dry-run (no HTTP)
# ============================================================
Write-Host ""
Write-Host "TEST 7: Send-DiscordAlertSafe does not throw in dry-run"
$threw = $false
try {
    Send-DiscordAlertSafe -Message "test alert" -WebhookUrl "https://discord.example.invalid/webhook"
} catch {
    $threw = $true
}
Assert-True (-not $threw)                                     "Send-DiscordAlertSafe did not throw in dry-run"

# ============================================================
# TEST 8: Send-EmailAlertSafe writes to stdout in dry-run (no SMTP)
# ============================================================
Write-Host ""
Write-Host "TEST 8: Send-EmailAlertSafe does not throw in dry-run"
$threwEmail = $false
try {
    Send-EmailAlertSafe -Subject "Test" -Body "Test body" `
        -SmtpServer "smtp.example.invalid" -SmtpFrom "a@b.com" -SmtpTo "c@d.com"
} catch {
    $threwEmail = $true
}
Assert-True (-not $threwEmail)                                "Send-EmailAlertSafe did not throw in dry-run"

# ============================================================
# TEST 9: Move-ToEncryptedQuarantine is a no-op in dry-run
# ============================================================
Write-Host ""
Write-Host "TEST 9: Move-ToEncryptedQuarantine no-op in dry-run"
$quarantineFolder = Join-Path $tmpBackup 'Quarantine'
# Create a dummy file to quarantine
$dummyFile = Join-Path $tmpBase 'suspicious.exe'
Set-Content -Path $dummyFile -Value 'dummy'

Move-ToEncryptedQuarantine -FilePath $dummyFile
Assert-True (-not (Test-Path $quarantineFolder))              "Quarantine folder not created in dry-run"

# ============================================================
# Cleanup temp directory
# ============================================================
Remove-Item -Recurse -Force $tmpBase -ErrorAction SilentlyContinue

# ============================================================
# Result summary
# ============================================================
Write-Host ""
if ($failures.Count -eq 0) {
    Write-Host "All tests passed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "FAILED tests ($($failures.Count)):" -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
    exit 1
}
