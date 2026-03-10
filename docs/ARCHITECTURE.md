# Architecture

## Repository layout

```
.
├─ src/
│  └─ ultra-security-monitor/      PowerShell module
│     ├─ UltraSecurityMonitor.psd1  Module manifest
│     ├─ UltraSecurityMonitor.psm1  Module root (dot-sources Public + Private)
│     ├─ Public/
│     │  └─ Start-UltraSecurityMonitor.ps1
│     └─ Private/
│        ├─ Get-UsmConfig.ps1       Config loader (JSON + env overrides)
│        ├─ Get-UsmWhitelist.ps1    Whitelist cache
│        ├─ Test-UsmSafePath.ps1    Path-traversal guardrails
│        └─ Write-UsmLog.ps1        Structured logging + rotation
│
├─ scripts/
│  ├─ setup.ps1         First-time setup
│  ├─ run-monitor.ps1   Start monitor / master-agent tasks
│  └─ audit.ps1         Project audit (syntax, files, git)
│
├─ tests/
│  └─ powershell/
│     └─ UltraSecurityMonitor.Tests.ps1   Pester 5 test suite
│
├─ tools/
│  └─ ci/
│     └─ web-smoke.js   Node.js web asset smoke checks
│
├─ configs/
│  ├─ monitor.config.example.json   Example runtime config (safe to commit)
│  └─ whitelist.example.json        Example process whitelist
│
├─ web/
│  ├─ repo-agent/       HTML/JS/CSS mini-app
│  └─ joke-generator/   HTML/JS/CSS mini-app
│
├─ saas-app/            Independent SaaS scaffold (React + Node + Prisma)
│
├─ .github/
│  ├─ workflows/
│  │  ├─ ci.yml         Unified CI (PSScriptAnalyzer + Pester + web smoke)
│  │  └─ fortify.yml    Fortify AST scan (optional, requires secrets)
│  ├─ ISSUE_TEMPLATE/
│  ├─ PULL_REQUEST_TEMPLATE.md
│  └─ CONTRIBUTING.md
│
├─ docs/                Documentation
├─ UltraSecurityMonitor.ps1   Compatibility shim → module
├─ masterAgent.ps1            Compatibility shim → scripts/run-monitor.ps1
└─ Audit-Project.ps1          Compatibility shim → scripts/audit.ps1
```

## Component: Ultra Security Monitor

### Event flow

```
Windows Events (WMI Win32_ProcessStartTrace)
        │
        ▼
  procAction handler
        │
        ├─ Get-CimInstance (process details)
        ├─ Get-AuthenticodeSignature (signature)
        ├─ Get-FileHash (SHA256)
        ├─ Test-UsmPathWhitelisted (whitelist check)
        └─ Test-ProcessSuspicious (heuristics)
              │
              ├─ Write-UsmLog  →  security.log
              ├─ Write-UsmNdjson  →  SIEM/siem.ndjson
              ├─ Send-DiscordAlert  →  Discord webhook
              ├─ Send-MailMessage  →  SMTP
              └─ VirusTotal API lookup (optional)

FileSystemWatcher (monitored folders)
        │
        ▼
  fswAction handler
        │
        ├─ Write-UsmLog
        ├─ File backup → Backup/
        ├─ Write-UsmNdjson
        ├─ Send-DiscordAlert
        └─ Send-MailMessage
```

### Configuration priority (highest wins)

1. Environment variables (`USM_*`)
2. `monitor.config.json` in BaseFolder
3. Module defaults

### Log formats

**security.log** – tab-separated human-readable:
```
2024-01-15T10:23:45.123+00:00	[INFO]	Ultra Security Monitor started by ADMIN
```

**SIEM/siem.ndjson** – newline-delimited JSON (one JSON object per line):
```json
{"timestamp":"2024-01-15T10:23:45.123+00:00","host":"PC01","user":"ADMIN","event_type":"SuspiciousProcess","severity":"High","data":{...}}
```

## Component: Web dashboard

Static HTML/JS served by `http-server ./web`.

## Component: saas-app

Independent React + Node + Prisma scaffold in `saas-app/`.  
It has its own CI in `saas-app/.github/workflows/`.
