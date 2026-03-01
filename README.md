# 🛡️ Ultra Security Monitor – Total Edition (Hardened)

Ultra Security Monitor is an advanced real-time Windows endpoint detection and response (EDR) system.  
This release implements the **ULTRAMASTER APOCALYPSE** security hardening blueprint.

---

## 🔐 Security Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Agent (UltraSecurityMonitor.ps1)          – minimal privileges │
│  • WMI Win32_ProcessStartTrace                                   │
│  • FileSystemWatcher                                             │
│  • Computes SHA-256 locally                                      │
│  • Sends HMAC-signed minimal telemetry to Collector             │
│  • NO direct Stop-Process / Remove-Item (DryRun=true default)   │
└──────────────────────────┬──────────────────────────────────────┘
                           │ HMAC-SHA256  http://127.0.0.1:18443
┌──────────────────────────▼──────────────────────────────────────┐
│  Collector (UltraSecurityCollector.ps1)                          │
│  • Validates HMAC on every inbound request                       │
│  • VirusTotal (TTL cache + rate-limiting + daily quota)          │
│  • Multi-signal confidence engine                                │
│  • Operator-approval queue  →  /approve  →  execute             │
│  • Rollback support  →  /rollback                               │
│  • Sanitized Discord / Email alerts (Invoke-Redact)             │
│  • ACL-restricted audit log + SIEM JSON                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📁 Repository files

| File | Description |
|------|-------------|
| `UltraSecurityMonitor.ps1`  | Hardened Agent – WMI/FS watcher, local hash, encrypted logs |
| `UltraSecurityCollector.ps1`| Collector – HTTP API, VT, confidence engine, remediation queue |
| `Audit-Project.ps1`         | Full security audit – verifies all 13 control categories |
| `hooks/pre-commit.ps1`      | Pre-commit secret scanner (blocks hardcoded credentials) |
| `dashboard.html`            | HTML/JS dashboard for SIEM log visualisation |

---

## ⚙️ Requirements

- Windows 10 / 11 (64-bit), PowerShell 5.1+
- Run as **Administrator**
- Internet access optional (Discord / Email / VirusTotal)

---

## 🔑 Secrets provisioning (REQUIRED before first run)

**API keys and passwords must NOT appear in any file.**  
Store them in Windows Credential Manager (DPAPI-protected):

```powershell
# Dot-source the agent to get helper functions
. .\UltraSecurityMonitor.ps1   # or load functions separately

Set-UltraMonitorCredential -Target 'UltraSecurityMonitor/VirusTotal'    -Secret '<vt-api-key>'
Set-UltraMonitorCredential -Target 'UltraSecurityMonitor/Discord'       -Secret '<discord-webhook-url>'
Set-UltraMonitorCredential -Target 'UltraSecurityMonitor/SMTP'          -Secret '<smtp-password>'
Set-UltraMonitorCredential -Target 'UltraSecurityMonitor/CollectorHmac' -Secret '<shared-hmac-key>'
# LogKey is auto-generated on first run (AES-256)

# Collector side (run once on Collector host):
. .\UltraSecurityCollector.ps1
Set-UltraCollectorCredential -Target 'UltraSecurityCollector/VirusTotal'    -Secret '<vt-api-key>'
Set-UltraCollectorCredential -Target 'UltraSecurityCollector/Discord'       -Secret '<discord-webhook-url>'
Set-UltraCollectorCredential -Target 'UltraSecurityCollector/SMTP'          -Secret '<smtp-password>'
Set-UltraCollectorCredential -Target 'UltraSecurityCollector/CollectorHmac' -Secret '<shared-hmac-key>'
```

> In CI/CD pipelines, inject secrets via **environment variables** or  
> **Azure Key Vault / HashiCorp Vault** – never commit them.

---

## 🚀 Running

### 1. Start the Collector (always first)

```powershell
# Default: DryRun mode, port 18443
pwsh -NoProfile -ExecutionPolicy RemoteSigned `
     -File .\UltraSecurityCollector.ps1 -DryRun -VerboseLog

# With operator-approved live remediation:
pwsh -NoProfile -ExecutionPolicy RemoteSigned `
     -File .\UltraSecurityCollector.ps1 -Port 18443
```

### 2. Start the Agent

```powershell
# As Administrator:
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\UltraSecurityMonitor.ps1
```

### 3. Operator remediation workflow

```powershell
# View pending remediation requests:
$sig = New-HmacSha256 -Data "/queue" -Key "<hmac-key>"
Invoke-RestMethod http://127.0.0.1:18443/queue -Headers @{"X-HMAC-SHA256"=$sig}

# Approve a request:
$body = '{"requestId":"<guid>","approvedBy":"Alice"}'
$sig  = New-HmacSha256 -Data $body -Key "<hmac-key>"
Invoke-RestMethod http://127.0.0.1:18443/approve -Method Post -Body $body `
    -ContentType application/json -Headers @{"X-HMAC-SHA256"=$sig}

# Roll back:
$body = '{"requestId":"<guid>"}'
$sig  = New-HmacSha256 -Data $body -Key "<hmac-key>"
Invoke-RestMethod http://127.0.0.1:18443/rollback -Method Post -Body $body `
    -ContentType application/json -Headers @{"X-HMAC-SHA256"=$sig}
```

---

## 🔒 Security controls summary

| # | Control | Implementation |
|---|---------|----------------|
| 1 | **Redaction** | `Invoke-Redact` masks IPs, full paths, cmd-line args in all logs/alerts |
| 2 | **VT hardening** | Agent hashes locally; Collector queries VT with TTL cache + rate-limit |
| 3 | **Secrets mgmt** | Windows Credential Manager (DPAPI); zero hardcoded keys in repo |
| 4 | **Dry-run policy** | `$DryRun=$true` default; remediation needs confidence ≥80 + operator OK |
| 5 | **Encrypted logs** | AES-256-CBC per entry + EFS on log directories + ACL to Admins/SYSTEM |
| 6 | **Secure alerts** | Redacted payload, 2000-char Discord limit, TLS email, retry/backoff |
| 7 | **Collector arch** | Agent → HMAC-signed telemetry → Collector → VT / alerts / remediation |
| 8 | **Remediation** | Operator-approved via `/approve`; rollback via `/rollback`; audit trail |
| 9 | **Code hardening** | HMAC auth, input validation, signature check, retry/backoff everywhere |
| 10| **Pre-commit** | `hooks/pre-commit.ps1` blocks secrets; `.gitignore` excludes logs/keys |

---

## 🗂️ Output files (excluded from git, ACL-restricted)

| Path | Contents |
|------|----------|
| `Documents\SecurityMonitor\security.log` | AES-encrypted agent events |
| `Documents\SecurityMonitor\security-report.txt` | Suspicious process reports |
| `Documents\SecurityMonitor\SIEM\siem.json` | AES-encrypted NDJSON (Splunk/ELK) |
| `Documents\SecurityMonitor\Backup\` | ACL-restricted file backups |
| `Documents\SecurityMonitor\Collector\collector-audit.log` | Collector audit trail |
| `Documents\SecurityMonitor\Collector\remediation-queue.json` | Pending/executed remediation |
| `Documents\SecurityMonitor\Collector\rollback-log.json` | Rollback history |

---

## 🧪 Running the audit

```powershell
cd <repo-root>
pwsh .\Audit-Project.ps1
```

Exits 0 (all checks pass) or 1 (failures detected).

---

## 🪝 Installing the pre-commit hook

```powershell
# Windows (Git for Windows)
@"
#!/usr/bin/env pwsh
& "`$PSScriptRoot/../../hooks/pre-commit.ps1"
exit `$LASTEXITCODE
"@ | Set-Content .git\hooks\pre-commit -Encoding utf8
```

---

## 📜 Decrypting logs

```powershell
. .\UltraSecurityMonitor.ps1   # loads Read-EncryptedLog function
Read-EncryptedLog -Path "$env:USERPROFILE\Documents\SecurityMonitor\security.log"
```

