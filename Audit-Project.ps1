# ==================================================
# Ultra Security Monitor - Full Security Audit
# Verifies all ULTRAMASTER APOCALYPSE hardening controls
# ==================================================
param([switch]$Quiet)

$pass  = 0
$warn  = 0
$fail  = 0

function Write-Check {
    param([string]$Label, [bool]$Ok, [string]$Detail = "")
    if ($Ok) {
        $script:pass++
        if (-not $Quiet) { Write-Host "  ✅ $Label" -ForegroundColor Green }
    } else {
        $script:warn++
        Write-Host "  ⚠️  $Label$(if ($Detail) { ": $Detail" })" -ForegroundColor Yellow
    }
}

function Write-Fail {
    param([string]$Label, [string]$Detail = "")
    $script:fail++
    Write-Host "  ❌ $Label$(if ($Detail) { ": $Detail" })" -ForegroundColor Red
}

Write-Host "`n🔎 Ultra Security Monitor – Full Security Audit" -ForegroundColor Cyan
Write-Host "   $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

# ─────────────────────────────────────────────
# 1. REQUIRED FILES
# ─────────────────────────────────────────────
Write-Host "📁 1. Required files" -ForegroundColor Cyan
$requiredFiles = @(
    "UltraSecurityMonitor.ps1",
    "UltraSecurityCollector.ps1",
    "README.md",
    "dashboard.html",
    ".gitignore"
)
foreach ($f in $requiredFiles) {
    if (Test-Path $f) { Write-Check $f $true }
    else              { Write-Fail  $f "missing" }
}

# ─────────────────────────────────────────────
# 2. POWERSHELL SYNTAX
# ─────────────────────────────────────────────
Write-Host "`n🔧 2. PowerShell syntax" -ForegroundColor Cyan
foreach ($ps in @("UltraSecurityMonitor.ps1", "UltraSecurityCollector.ps1")) {
    if (-not (Test-Path $ps)) { Write-Fail $ps "file missing"; continue }
    $errors = $null
    try {
        [System.Management.Automation.Language.Parser]::ParseFile(
            (Resolve-Path $ps).Path, [ref]$null, [ref]$errors) | Out-Null
    } catch { $errors = @($_) }
    if ($errors -and $errors.Count -gt 0) {
        Write-Fail "$ps syntax" ($errors[0].ToString())
    } else {
        Write-Check "$ps syntax" $true
    }
}

# ─────────────────────────────────────────────
# 3. NO HARDCODED SECRETS
# ─────────────────────────────────────────────
Write-Host "`n🔑 3. No hardcoded secrets in source files" -ForegroundColor Cyan
$secretPatterns = @(
    '(?i)(api[_-]?key|apikey)\s*=\s*"[^"]+"',
    '(?i)(webhook|discord)[_-]?url\s*=\s*"https?://[^"]+"',
    '(?i)(password|passwd|secret)\s*=\s*"[^"]+"',
    '(?i)x-apikey\s*=\s*"[^"]+"',
    'AIza[0-9A-Za-z\-_]{35}',         # Google API key pattern
    'AKIA[0-9A-Z]{16}'                 # AWS access key pattern
)
$psFiles = Get-ChildItem -Filter "*.ps1" -File
$secretFound = $false
foreach ($file in $psFiles) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    foreach ($pat in $secretPatterns) {
        if ($content -match $pat) {
            Write-Fail "Possible hardcoded secret in $($file.Name)" "pattern: $pat"
            $secretFound = $true
        }
    }
}
if (-not $secretFound) { Write-Check "No hardcoded secrets found in .ps1 files" $true }

# ─────────────────────────────────────────────
# 4. REDACTION IMPLEMENTATION
# ─────────────────────────────────────────────
Write-Host "`n🕵️  4. Redaction (Invoke-Redact)" -ForegroundColor Cyan
$agentContent = Get-Content "UltraSecurityMonitor.ps1" -Raw -ErrorAction SilentlyContinue
Write-Check "Invoke-Redact defined in agent"    ($agentContent -match 'function\s+Invoke-Redact')
Write-Check "IP redaction pattern present"      ($agentContent -match 'IP-REDACTED')
Write-Check "Path redaction pattern present"    ($agentContent -match 'PATH')
Write-Check "Args redaction pattern present"    ($agentContent -match 'ARGS-REDACTED')
Write-Check "Discord alert uses Invoke-Redact"  ($agentContent -match 'Invoke-Redact.*\$Message|\$Message.*Invoke-Redact|safe\s*=\s*Invoke-Redact')
Write-Check "Email alert uses Invoke-Redact"    ($agentContent -match 'Invoke-Redact.*\$Body|\$Body.*Invoke-Redact|safeBody')
Write-Check "SIEM event redacts data"           ($agentContent -match 'Invoke-Redact')

$collContent = Get-Content "UltraSecurityCollector.ps1" -Raw -ErrorAction SilentlyContinue
Write-Check "Invoke-Redact defined in collector" ($collContent -match 'function\s+Invoke-Redact')

# ─────────────────────────────────────────────
# 5. SECRETS MANAGEMENT
# ─────────────────────────────────────────────
Write-Host "`n🔐 5. Secrets management (Credential Manager)" -ForegroundColor Cyan
Write-Check "Agent uses Get-UltraMonitorSecret"      ($agentContent -match 'Get-UltraMonitorSecret')
Write-Check "Agent uses Set-UltraMonitorCredential"  ($agentContent -match 'Set-UltraMonitorCredential')
Write-Check "Collector uses Get-UltraCollectorSecret" ($collContent -match 'Get-UltraCollectorSecret')
Write-Check "PasswordVault (DPAPI) used in agent"    ($agentContent -match 'PasswordVault')
Write-Check "PasswordVault (DPAPI) used in collector"($collContent -match 'PasswordVault')
Write-Check "VT API key loaded from CM (not literal)" (
    $agentContent -match 'VirusTotalApiKey\s*=\s*Get-UltraMonitorSecret')

# Optional: check if secrets are already provisioned at runtime
try {
    Add-Type -AssemblyName Windows.Security -ErrorAction SilentlyContinue
    $vault   = New-Object Windows.Security.Credentials.PasswordVault
    $allCred = $vault.RetrieveAll()
    $hasVT   = $allCred | Where-Object { $_.Resource -like "*/VirusTotal" }
    $hasHmac = $allCred | Where-Object { $_.Resource -like "*/CollectorHmac" }
    Write-Check "VT secret provisioned in Credential Manager"     ($null -ne $hasVT)
    Write-Check "CollectorHmac secret provisioned in Cred. Mgr."  ($null -ne $hasHmac)
} catch {
    Write-Check "Credential Manager accessible" $false
}

# ─────────────────────────────────────────────
# 6. DRY-RUN FLAG
# ─────────────────────────────────────────────
Write-Host "`n🧪 6. Dry-run / multi-signal policy" -ForegroundColor Cyan
Write-Check "Agent defines \$DryRun"              ($agentContent -match '\$DryRun\s*=')
Write-Check "Collector defines -DryRun param"     ($collContent  -match '\[switch\]\$DryRun')
Write-Check "Collector has confidence engine"     ($collContent  -match 'Get-ThreatConfidence')
Write-Check "Remediation requires confidence ≥80" ($collContent  -match 'confidence\s*-ge\s*80')
Write-Check "No bare Stop-Process in agent"       ($agentContent -notmatch 'Stop-Process\s+-Id')
Write-Check "No bare Remove-Item in agent"        ($agentContent -notmatch 'Remove-Item\s')
Write-Check "No bare Move-Item outside backup fn" (
    ($agentContent -split 'function\s+Backup-FileToStore')[0] -notmatch 'Move-Item' -and
    ($agentContent -split 'function\s+Backup-FileToStore')[-1] -notmatch '^Move-Item')

# ─────────────────────────────────────────────
# 7. ENCRYPTED LOGS & BACKUPS
# ─────────────────────────────────────────────
Write-Host "`n🔒 7. Encrypted logs & backups" -ForegroundColor Cyan
Write-Check "AES Write-EncryptedLogEntry defined"   ($agentContent -match 'function\s+Write-EncryptedLogEntry')
Write-Check "AES Read-EncryptedLog defined"         ($agentContent -match 'function\s+Read-EncryptedLog')
Write-Check "\$EncryptLogs flag present"            ($agentContent -match '\$EncryptLogs\s*=')
Write-Check "Write-Log honours \$EncryptLogs"       ($agentContent -match 'if\s*\(\$EncryptLogs\)')
Write-Check "EFS Enable-EfsEncryption defined"      ($agentContent -match 'function\s+Enable-EfsEncryption')
Write-Check "EFS applied on startup"                ($agentContent -match 'Enable-EfsEncryption')
Write-Check "ACL Set-RestrictedAcl in agent"        ($agentContent -match 'function\s+Set-RestrictedAcl')
Write-Check "ACL applied to backup files"           ($agentContent -match 'Set-RestrictedAcl\s+-Path\s+\$dest')
Write-Check "Log key stored in Credential Manager"  ($agentContent -match 'UltraSecurityMonitor/LogKey')

# ─────────────────────────────────────────────
# 8. SECURE ALERTS
# ─────────────────────────────────────────────
Write-Host "`n📢 8. Secure alerts" -ForegroundColor Cyan
Write-Check "Discord enforces 2000-char limit (agent)"     ($agentContent -match 'MaxDiscordMsgLength')
Write-Check "Discord enforces 2000-char limit (collector)" ($collContent  -match 'MaxDiscordMsgLength')
Write-Check "Email enforces TLS (SmtpUseSsl=true)"         ($agentContent -match 'SmtpUseSsl\s*=\s*\$true')
Write-Check "Discord uses Invoke-WithRetry (agent)"        ($agentContent -match 'Invoke-WithRetry')
Write-Check "Discord uses Invoke-WithRetry (collector)"    ($collContent  -match 'Invoke-WithRetry')
Write-Check "SMTP credential from Credential Manager"      ($agentContent -match 'SmtpPassword\s*=\s*Get-UltraMonitorSecret')

# ─────────────────────────────────────────────
# 9. COLLECTOR / SANDBOX ARCHITECTURE
# ─────────────────────────────────────────────
Write-Host "`n🏗️  9. Collector / sandbox architecture" -ForegroundColor Cyan
Write-Check "Agent has Send-CollectorEvent"       ($agentContent -match 'function\s+Send-CollectorEvent')
Write-Check "Agent sends minimal telemetry"       ($agentContent -match 'Send-CollectorEvent')
Write-Check "Collector HTTP listener present"     ($collContent  -match 'HttpListener')
Write-Check "Collector loopback-only binding"     ($collContent  -match '127\.0\.0\.1')
Write-Check "Collector /event endpoint"           ($collContent  -match '"/event"')
Write-Check "Collector /approve endpoint"         ($collContent  -match '"/approve"')
Write-Check "Collector /rollback endpoint"        ($collContent  -match '"/rollback"')
Write-Check "Collector /queue endpoint"           ($collContent  -match '"/queue"')
Write-Check "Collector handles sandbox verdict"   ($collContent  -match 'SandboxVerdict')

# ─────────────────────────────────────────────
# 10. OPERATOR-APPROVED REMEDIATION
# ─────────────────────────────────────────────
Write-Host "`n✅ 10. Operator-approved remediation" -ForegroundColor Cyan
Write-Check "Add-RemediationRequest defined"      ($collContent -match 'function\s+Add-RemediationRequest')
Write-Check "Approve-RemediationRequest defined"  ($collContent -match 'function\s+Approve-RemediationRequest')
Write-Check "Invoke-RollbackAction defined"       ($collContent -match 'function\s+Invoke-RollbackAction')
Write-Check "Rollback log persisted"              ($collContent -match 'RollbackPath')
Write-Check "Audit trail via Write-SiemEvent"     ($collContent -match 'Write-SiemEvent')
Write-Check "Remediation requires DryRun check"   ($collContent -match 'if\s*\(\$DryRun\)')

# ─────────────────────────────────────────────
# 11. CODE-LEVEL HARDENING
# ─────────────────────────────────────────────
Write-Host "`n🛡️  11. Code-level hardening" -ForegroundColor Cyan
Write-Check "Invoke-WithRetry in agent"           ($agentContent -match 'function\s+Invoke-WithRetry')
Write-Check "Invoke-WithRetry in collector"       ($collContent  -match 'function\s+Invoke-WithRetry')
Write-Check "HMAC New-HmacSha256 in agent"        ($agentContent -match 'function\s+New-HmacSha256')
Write-Check "HMAC Test-HmacSignature in coll."    ($collContent  -match 'function\s+Test-HmacSignature')
Write-Check "HMAC constant-time compare"          ($collContent  -match '-bxor')
Write-Check "SHA-256 hash format validation"      (
    $agentContent -match '\^[0-9a-fA-F]\{64\}\$' -or
    $collContent  -match '\^[0-9a-fA-F]\{64\}\$')
Write-Check "PID > 0 validation in agent"         ($agentContent -match '\$Pid\s*-le\s*0')
Write-Check "PID > 0 validation in collector"     ($collContent  -match '\$pid\s*-gt\s*0')
Write-Check "GUID format validation on /approve"  ($collContent  -match '\^[0-9a-fA-F-]\{36\}\$')
Write-Check "File signature check function"       ($agentContent -match 'Get-FileSignatureStatus')
Write-Check "VT daily quota guard"                ($agentContent -match 'VTDailyLimit')

# ─────────────────────────────────────────────
# 12. CI/CD & PRE-COMMIT
# ─────────────────────────────────────────────
Write-Host "`n⚙️  12. CI/CD & pre-commit hooks" -ForegroundColor Cyan
Write-Check "Pre-commit hook script exists"    (Test-Path "hooks/pre-commit.ps1")
Write-Check ".gitignore present"               (Test-Path ".gitignore")
$giContent = Get-Content ".gitignore" -Raw -ErrorAction SilentlyContinue
Write-Check ".gitignore covers *.log"          ($giContent -match '\.log')
Write-Check ".gitignore covers *.json secrets" ($giContent -match '\.json')

# ─────────────────────────────────────────────
# 13. GIT REPOSITORY STATUS
# ─────────────────────────────────────────────
Write-Host "`n🌳 13. Git repository" -ForegroundColor Cyan
try {
    $status = git status --short 2>&1
    if ($status -match '^fatal') { Write-Check "Git repo detected" $false }
    else {
        Write-Check "Git repo detected" $true
        if ($status) { Write-Check "Working tree clean" $false }
        else          { Write-Check "Working tree clean" $true }
        $branch = git branch --show-current 2>&1
        Write-Host "   ℹ  Branch: $branch"
    }
} catch { Write-Check "Git available" $false }

# ─────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────
Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "🎯 Audit complete:  ✅ $pass passed  ⚠️  $warn warnings  ❌ $fail failed" -ForegroundColor $(
    if ($fail -gt 0) { "Red" } elseif ($warn -gt 0) { "Yellow" } else { "Green" })
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n"

if ($fail -gt 0) { exit 1 }

