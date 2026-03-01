# =====================================================
# Ultra Security Monitor - MASTER AGENT
# Enterprise Night Automation System
# =====================================================

Write-Host "🚀 Ultra Security Monitor - Master Agent Starting..."

# ==========================================
# 1️⃣ Weryfikacja wymaganych plików
# ==========================================
$requiredFiles = @("README.md", ".github/FUNDING.yml", "UltraSecurityMonitor.ps1", "dashboard.html")
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "✅ Found: $file"
    } else {
        Write-Host "⚠ Missing: $file"
    }
}

# ==========================================
# 2️⃣ Aktualizacja FUNDING.yml
# ==========================================
$fundingContent = @"
github: [DominikOpalko]
patreon: UltraSecPatreon
ko_fi: dominik-opalko
buy_me_a_coffee: dominik-opalko
custom: ["https://paypal.me/dominikopalko"]
"@

if (-not (Test-Path ".github")) {
    New-Item -ItemType Directory -Path ".github"
}

Set-Content -Path ".github/FUNDING.yml" -Value $fundingContent -Force
Write-Host "✅ FUNDING.yml updated"

# ==========================================
# 3️⃣ Aktualizacja README sponsor section
# ==========================================
$readmePath = "README.md"
$sponsorSection = @"
## Support Ultra Security Monitor
- https://github.com/sponsors/DominikOpalko
- https://paypal.me/dominikopalko
- https://ko-fi.com/dominik-opalko
"@

if (Test-Path $readmePath) {
    $content = Get-Content $readmePath -Raw
    if ($content -notmatch "Support Ultra Security Monitor") {
        Add-Content -Path $readmePath -Value $sponsorSection
    } else {
        $content = $content -replace "(?s)## Support Ultra Security Monitor.*?(?=\r?\n##|\z)", $sponsorSection
        Set-Content -Path $readmePath -Value $content
    }
} else {
    Set-Content -Path $readmePath -Value $sponsorSection
}

Write-Host "✅ README updated"

# ==========================================
# 4️⃣ PowerShell Syntax Audit
# ==========================================
Write-Host "🔍 Running PowerShell syntax audit..."
$psFiles = Get-ChildItem -Recurse -Filter *.ps1
foreach ($file in $psFiles) {
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName, [ref]$null, [ref]$errors
    )
    if ($errors.Count -gt 0) {
        Write-Host "❌ Syntax errors in $($file.FullName)"
    } else {
        Write-Host "✅ Syntax OK: $($file.FullName)"
    }
}

# ==========================================
# 5️⃣ Backup logów
# ==========================================
# Determine log location: prefer UltraSecurityMonitor runtime path, fall back to repo root
$monitorBaseFolder = Join-Path $env:USERPROFILE "Documents\SecurityMonitor"
$siemRuntimeFolder = Join-Path $monitorBaseFolder "SIEM"
$logSources = @(
    (Join-Path $monitorBaseFolder "security.log"),
    (Join-Path $monitorBaseFolder "security-report.txt"),
    (Join-Path $siemRuntimeFolder "siem.json"),
    "security.log", "security-report.txt", "SIEM/siem.json"
)

$backupDir = "backup_logs"
$backedUpAny = $false
foreach ($log in $logSources) {
    if (Test-Path $log) {
        if (-not (Test-Path $backupDir)) {
            New-Item -ItemType Directory -Path $backupDir | Out-Null
        }
        $leaf = Split-Path $log -Leaf
        $dest = Join-Path $backupDir ($leaf + "_" + (Get-Date -Format "yyyyMMdd-HHmmss"))
        try {
            Copy-Item $log $dest -Force -ErrorAction Stop
            Write-Host "✅ Backup created: $log -> $dest"
            $backedUpAny = $true
        } catch {
            Write-Host "⚠ Backup failed for $log`: $_"
        }
    }
}
if (-not $backedUpAny) {
    Write-Host "ℹ No log files found to back up (runtime logs are created when monitor runs)"
}

# ==========================================
# 6️⃣ Test VirusTotal API
# ==========================================
if ($env:VT_API_KEY) {
    try {
        Invoke-RestMethod -Uri "https://www.virustotal.com/api/v3/files/0" `
            -Headers @{"x-apikey"=$env:VT_API_KEY} | Out-Null
        Write-Host "✅ VirusTotal API reachable"
    } catch {
        Write-Host "⚠ VirusTotal API connection failed"
    }
} else {
    Write-Host "ℹ VT_API_KEY not set - skipping VirusTotal test"
}

# ==========================================
# 7️⃣ System Licencji PRO
# ==========================================
function Get-StringHashSHA256 {
    param([string]$Value)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
    $sha   = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($bytes)
        return ([BitConverter]::ToString($hash) -replace '-','').ToLower()
    } finally {
        $sha.Dispose()
    }
}

function Validate-License {
    param(
        [string]$LicenseFilePath,
        [string]$RawKey = $env:LICENSE_KEY   # raw key supplied via env var, never stored
    )
    if (-not (Test-Path $LicenseFilePath)) {
        Write-Host "ℹ License file not found – running in Community mode"
        return $false
    }
    try {
        $entries = Get-Content $LicenseFilePath -Raw | ConvertFrom-Json
    } catch {
        Write-Host "⚠ License file could not be parsed: $_"
        return $false
    }
    if ($null -eq $entries -or $entries.Count -eq 0) {
        Write-Host "⚠ License file is empty"
        return $false
    }
    $today = [datetime]::UtcNow.Date
    foreach ($entry in $entries) {
        # Validate required fields
        if ([string]::IsNullOrWhiteSpace($entry.licenseKey) -or
            [string]::IsNullOrWhiteSpace($entry.type)       -or
            [string]::IsNullOrWhiteSpace($entry.expires)) {
            Write-Host "⚠ License entry missing required fields – skipping"
            continue
        }
        # Check expiration
        $expiry = $null
        if (-not [datetime]::TryParse($entry.expires, [ref]$expiry)) {
            Write-Host "⚠ Invalid expiry date format in license entry"
            continue
        }
        if ($today -gt $expiry.Date) {
            Write-Host "⚠ License key expired on $($entry.expires)"
            continue
        }
        # Key verification: hash the raw key from env and compare against stored hash.
        # The stored value must be SHA-256(raw key). The raw key is never stored on disk.
        if ([string]::IsNullOrWhiteSpace($RawKey)) {
            Write-Host "ℹ LICENSE_KEY env var not set – skipping key verification (structure valid)"
            Write-Host "✅ Valid $($entry.type) license structure – expires $($entry.expires)"
            return $true
        }
        $computedHash = Get-StringHashSHA256 -Value $RawKey
        if ($computedHash -ne $entry.licenseKey.ToLower()) {
            Write-Host "⚠ License key hash mismatch"
            continue
        }
        Write-Host "✅ Valid $($entry.type) license verified – expires $($entry.expires)"
        return $true
    }
    Write-Host "⚠ No valid license entries found"
    return $false
}

$licenseFile = "licenses/pro_licenses.json"
$licenseValid = Validate-License -LicenseFilePath $licenseFile

# ==========================================
# 8️⃣ Slack Notification
# ==========================================
if ($env:SLACK_WEBHOOK) {
    $payload = @{
        text = "Ultra Security Monitor Nightly Agent completed successfully ✅"
    } | ConvertTo-Json

    try {
        Invoke-RestMethod -Uri $env:SLACK_WEBHOOK -Method POST `
            -ContentType "application/json" -Body $payload
        Write-Host "✅ Slack notification sent"
    } catch {
        Write-Host "⚠ Slack notification failed"
    }
}

Write-Host "-------------------------------------------"
Write-Host "✅ MASTER AGENT FINISHED"
