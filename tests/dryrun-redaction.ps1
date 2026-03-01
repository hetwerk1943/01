# tests/dryrun-redaction.ps1
# Validates SecureHelpers module dry-run behavior.
# Idempotent. Exits non-zero on any failure.
# No network calls; no secrets required.

#Requires -Version 5.1

$ErrorActionPreference = 'Stop'
$failed = $false

# Resolve module path relative to this test file's location
$repoRoot  = Split-Path $PSScriptRoot -Parent
$modulePath = Join-Path $repoRoot 'SecureHelpers.psm1'

if (-not (Test-Path $modulePath)) {
    Write-Error "SecureHelpers.psm1 not found at: $modulePath"
    exit 1
}

Import-Module $modulePath -Force

# ---- Test 1: Sanitize-CommandLine returns a redacted command ----
Write-Host "Test 1: Sanitize-CommandLine redacts arguments..."
$raw       = 'powershell.exe -EncodedCommand dQBlAHIAbgBhAG0AZQA='
$sanitized = Sanitize-CommandLine -CommandLine $raw

if ($sanitized -notmatch '^powershell\.exe \[REDACTED_ARGS:[0-9a-f]{8}\]$') {
    Write-Host "  FAIL: Got '$sanitized'"
    $failed = $true
} else {
    Write-Host "  PASS: $sanitized"
}

# Ensure the raw arguments do NOT appear in the output
if ($sanitized -match 'dQBlAHIAbgBhAG0AZQA=') {
    Write-Host "  FAIL: Raw args leaked into sanitized output"
    $failed = $true
} else {
    Write-Host "  PASS: Raw args not present in sanitized output"
}

# Verify hex suffix is exactly 8 hex characters
if ($sanitized -match '\[REDACTED_ARGS:([0-9a-f]{8})\]') {
    Write-Host "  PASS: 8-hex token present: $($Matches[1])"
} else {
    Write-Host "  FAIL: Expected 8-hex token in '$sanitized'"
    $failed = $true
}

# ---- Test 2: Sanitize-CommandLine with no args returns exe name only ----
Write-Host "Test 2: Sanitize-CommandLine with no arguments..."
$noArgs = Sanitize-CommandLine -CommandLine 'notepad.exe'
if ($noArgs -eq 'notepad.exe') {
    Write-Host "  PASS: $noArgs"
} else {
    Write-Host "  FAIL: Expected 'notepad.exe', got '$noArgs'"
    $failed = $true
}

# ---- Test 3: Get-VirusTotalReportCached does NOT create cache file when no key ----
Write-Host "Test 3: Get-VirusTotalReportCached returns null and skips cache when no key..."

# Make sure no VT key is available
$env:VT_API_KEY = ''
# Override the global cache file to a temp path so we never touch real state
$tmpCacheDir  = Join-Path ([System.IO.Path]::GetTempPath()) ('vt_test_' + [System.IO.Path]::GetRandomFileName())
New-Item -Path $tmpCacheDir -ItemType Directory -Force | Out-Null
$Global:VT_CacheFile = Join-Path $tmpCacheDir 'vt_cache.json'

try {
    $testHash = 'a' * 64  # fake hash
    $result   = Get-VirusTotalReportCached -Hash $testHash

    if ($null -ne $result) {
        Write-Host "  FAIL: Expected null without API key, got: $result"
        $failed = $true
    } else {
        Write-Host "  PASS: Result is null (no API key)"
    }

    if (Test-Path $Global:VT_CacheFile) {
        Write-Host "  FAIL: vt_cache.json was created despite no API key"
        $failed = $true
    } else {
        Write-Host "  PASS: vt_cache.json was NOT created"
    }
} finally {
    # Always clean up temp dir
    Remove-Item -Path $tmpCacheDir -Recurse -Force -ErrorAction SilentlyContinue
}

# ---- Test 4: Execute-RemediationSafe is suppressed when EnableDryRun=$true ----
Write-Host "Test 4: Execute-RemediationSafe suppressed in dry-run mode..."
$Global:EnableDryRun      = $true
$Global:EnableRemediation = $true
$actionRan = $false
$result4 = Execute-RemediationSafe -Reason 'test-dry-run' -ActionScriptBlock { $actionRan = $true }

if ($result4 -eq $false -and $actionRan -eq $false) {
    Write-Host "  PASS: Action suppressed in dry-run mode"
} else {
    Write-Host "  FAIL: Dry-run should have suppressed the action"
    $failed = $true
}

# ---- Test 5: Execute-RemediationSafe is suppressed when EnableRemediation=$false ----
Write-Host "Test 5: Execute-RemediationSafe suppressed when remediation disabled..."
$Global:EnableDryRun      = $false
$Global:EnableRemediation = $false
$actionRan2 = $false
$result5 = Execute-RemediationSafe -Reason 'test-remediation-off' -ActionScriptBlock { $actionRan2 = $true }

if ($result5 -eq $false -and $actionRan2 -eq $false) {
    Write-Host "  PASS: Action suppressed when remediation is disabled"
} else {
    Write-Host "  FAIL: Remediation-disabled should have suppressed the action"
    $failed = $true
}

# ---- Final result ----
if ($failed) {
    Write-Host "`nONE OR MORE TESTS FAILED"
    exit 1
} else {
    Write-Host "`nAll tests passed."
    exit 0
}
