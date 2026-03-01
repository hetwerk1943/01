# tests/dryrun-redaction.ps1
# Validates Sanitize-CommandLine redaction and that vt_cache.json is not created
# without a VT API key.
# Exit 0 on success, non-zero on any failure.
# Idempotent – safe to run multiple times.

#Requires -Version 5.1

$ErrorActionPreference = 'Stop'
$failures = 0

$modulePath = Join-Path $PSScriptRoot '..' 'SecureHelpers.psm1'
Import-Module (Resolve-Path $modulePath) -Force

# ---- Helper ----
function Assert-True {
    param([bool]$Condition, [string]$TestName)
    if ($Condition) {
        Write-Host "  PASS: $TestName"
    } else {
        Write-Host "  FAIL: $TestName"
        $script:failures++
    }
}

Write-Host '=== Sanitize-CommandLine tests ==='

# 1. Arguments are replaced by redacted token
$result1 = Sanitize-CommandLine -CommandLine 'cmd.exe /c whoami'
Assert-True ($result1 -match '\[REDACTED_ARGS:[0-9a-f]{8}\]') 'Args replaced with redacted token'
Assert-True ($result1 -notmatch 'whoami') 'Raw args not present in output'

# 2. Quoted executable path preserved
$result2 = Sanitize-CommandLine -CommandLine '"C:\Windows\System32\cmd.exe" /c echo hello'
Assert-True ($result2 -match '^"C:\\Windows\\System32\\cmd\.exe"') 'Quoted exe preserved'
Assert-True ($result2 -match '\[REDACTED_ARGS:[0-9a-f]{8}\]') 'Quoted exe: args redacted'

# 3. No arguments – returned unchanged
$result3 = Sanitize-CommandLine -CommandLine 'notepad.exe'
Assert-True ($result3 -eq 'notepad.exe') 'No-arg command returned unchanged'

# 4. Empty string – returned empty
$result4 = Sanitize-CommandLine -CommandLine ''
Assert-True ($result4 -eq '') 'Empty string returns empty'

# 5. Different args produce different tokens
$resultA = Sanitize-CommandLine -CommandLine 'cmd.exe /c whoami'
$resultB = Sanitize-CommandLine -CommandLine 'cmd.exe /c dir'
$tokenA  = if ($resultA -match '\[REDACTED_ARGS:([0-9a-f]{8})\]') { $Matches[1] } else { '' }
$tokenB  = if ($resultB -match '\[REDACTED_ARGS:([0-9a-f]{8})\]') { $Matches[1] } else { '' }
Assert-True ($tokenA -ne $tokenB) 'Different args produce different tokens'

# 6. Same args always produce the same token (deterministic)
$resultC = Sanitize-CommandLine -CommandLine 'cmd.exe /c whoami'
$tokenC  = if ($resultC -match '\[REDACTED_ARGS:([0-9a-f]{8})\]') { $Matches[1] } else { '' }
Assert-True ($tokenA -eq $tokenC) 'Same args always produce the same token'

Write-Host ''
Write-Host '=== VT cache not created without API key ==='

# Ensure no stale VT_API_KEY in environment
$savedKey = $env:VT_API_KEY
$env:VT_API_KEY = ''

# Override the cache file path to a temp location so we don't pollute the repo
$tempCache = Join-Path ([System.IO.Path]::GetTempPath()) ('vt_cache_test_{0}.json' -f [System.Guid]::NewGuid().ToString('N'))
$Global:VT_CacheFile = $tempCache

$vtResult = Get-VirusTotalReportCached -Hash 'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd'
Assert-True ($null -eq $vtResult) 'Returns $null when no API key'
Assert-True (-not (Test-Path $tempCache)) 'vt_cache.json NOT created without API key'

# Restore
$env:VT_API_KEY = $savedKey
if (Test-Path $tempCache) { Remove-Item $tempCache -Force }

Write-Host ''
if ($failures -eq 0) {
    Write-Host "All tests passed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "$failures test(s) FAILED." -ForegroundColor Red
    exit 1
}
