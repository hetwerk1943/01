# tests/dryrun-redaction.ps1
# Dry-run / redaction validation tests for SecureHelpers.psm1.
# Idempotent. Exits with code 0 on success, 1 on failure.
# No network calls and no secrets are required.

$ErrorActionPreference = 'Stop'
$failed = $false

function Assert-True {
    param([bool]$Condition, [string]$TestName)
    if ($Condition) {
        Write-Host "[PASS] $TestName"
    } else {
        Write-Host "[FAIL] $TestName"
        $script:failed = $true
    }
}

# ---------- Load module ----------
$modulePath = Join-Path $PSScriptRoot '..\SecureHelpers.psm1'
if (-not (Test-Path $modulePath)) {
    Write-Host "[FAIL] SecureHelpers.psm1 not found at: $modulePath"
    exit 1
}
Import-Module $modulePath -Force

# ---------- Test 1: Sanitize-CommandLine redacts args ----------
$rawCmd     = '"C:\Windows\System32\cmd.exe" /c whoami & net user'
$sanitized  = Sanitize-CommandLine -CommandLine $rawCmd

Assert-True ($sanitized -ne $rawCmd)                      'Sanitize-CommandLine: output differs from raw input'
Assert-True ($sanitized -like 'cmd.exe *')                'Sanitize-CommandLine: starts with exe name'
Assert-True ($sanitized -like '*[REDACTED_ARGS:*]*')      'Sanitize-CommandLine: contains REDACTED_ARGS marker'
Assert-True ($sanitized -notlike '*whoami*')              'Sanitize-CommandLine: does not contain raw args'

# ---------- Test 2: Sanitize-CommandLine – no args ----------
$noArgCmd  = 'notepad.exe'
$noArgOut  = Sanitize-CommandLine -CommandLine $noArgCmd
Assert-True ($noArgOut -eq 'notepad.exe')                 'Sanitize-CommandLine: no-args path returns exe name only'

# ---------- Test 3: Sanitize-CommandLine – empty ----------
$emptyOut  = Sanitize-CommandLine -CommandLine ''
Assert-True ($emptyOut -eq '[EMPTY_CMD]')                 'Sanitize-CommandLine: empty string returns [EMPTY_CMD]'

# ---------- Test 4: VT cache file NOT created without API key ----------
# Ensure VT_API_KEY is absent and SecretManagement is not providing the key
$env:VT_API_KEY = $null
[System.Environment]::SetEnvironmentVariable('VT_API_KEY', $null, 'Process')

$cacheFile = $Global:VT_CacheFile
# Remove any pre-existing cache so the test is deterministic
if (Test-Path $cacheFile) { Remove-Item $cacheFile -Force }

$vtResult = Get-VirusTotalReportCached -Hash 'aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899'

Assert-True ($null -eq $vtResult)             'Get-VirusTotalReportCached: returns $null without API key'
Assert-True (-not (Test-Path $cacheFile))     'Get-VirusTotalReportCached: does not create cache file without API key'

# ---------- Test 5: Execute-RemediationSafe is suppressed by default ----------
$Global:EnableDryRun      = $true
$Global:EnableRemediation = $false

$executed = $false
$result   = Execute-RemediationSafe -Reason 'test suppression' -ActionScriptBlock { $script:executed = $true }

Assert-True ($result -eq $false)    'Execute-RemediationSafe: returns $false in dry-run mode'
Assert-True ($executed -eq $false)  'Execute-RemediationSafe: action block not executed in dry-run mode'

# ---------- Test 6: Build-AlertSummary sanitizes cmd ----------
$summary = Build-AlertSummary -ProcessName 'evil.exe' -Hash 'deadbeef' `
    -HostName 'TESTHOST' -Owner 'DOMAIN\user' -SigStatus 'NotSigned' `
    -CmdLine '"evil.exe" --flag1 --flag2 http://example.test'

Assert-True ($summary.cmd -notlike '*--flag1*')             'Build-AlertSummary: cmd does not contain raw args'
Assert-True ($summary.cmd -like '*[REDACTED_ARGS:*]*')     'Build-AlertSummary: cmd contains REDACTED_ARGS'
Assert-True ($summary.name -eq 'evil.exe')                 'Build-AlertSummary: name preserved'
Assert-True ($summary.host -eq 'TESTHOST')                 'Build-AlertSummary: host preserved'

# ---------- Results ----------
if ($failed) {
    Write-Host "`nSome tests FAILED." -ForegroundColor Red
    exit 1
} else {
    Write-Host "`nAll tests PASSED." -ForegroundColor Green
    exit 0
}
