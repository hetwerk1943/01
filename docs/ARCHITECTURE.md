# Architecture

## Repository layout

```
01/
├─ src/
│  └─ UltraSecurityMonitor/        # PowerShell module (primary product)
│     ├─ UltraSecurityMonitor.psd1 # Module manifest
│     ├─ UltraSecurityMonitor.psm1 # Module root (dot-sources Public/Private)
│     ├─ Public/
│     │  └─ Start-UltraSecurityMonitor.ps1
│     └─ Private/
│        ├─ Assert-UsmSafePath.ps1
│        ├─ Get-UsmConfig.ps1
│        ├─ Get-UsmSystemInfo.ps1
│        ├─ Get-UsmVirusTotalReport.ps1
│        ├─ Send-UsmAlert.ps1
│        ├─ Test-UsmProcess.ps1
│        ├─ Write-UsmLog.ps1
│        └─ Write-UsmSiemEvent.ps1
├─ scripts/
│  ├─ setup.ps1          # One-time environment setup
│  ├─ run-monitor.ps1    # Convenience launcher
│  └─ audit.ps1          # Project health check
├─ configs/
│  ├─ monitor.config.example.json
│  └─ whitelist.example.json
├─ tests/
│  └─ powershell/
│     └─ UltraSecurityMonitor.Tests.ps1  # Pester v5 tests
├─ tools/
│  └─ ci/
│     └─ web-smoke.sh    # Web asset validation
├─ web/
│  ├─ repo-agent/        # Static web mini-app
│  └─ joke-generator/    # Static web mini-app
├─ saas-app/             # Independent SaaS scaffold (React + Node + Prisma)
├─ docs/
│  ├─ QUICK_START.md
│  ├─ ARCHITECTURE.md    # ← you are here
│  ├─ DEVELOPMENT_GUIDE.md
│  └─ OPERATIONS.md
└─ .github/
   ├─ workflows/
   │  ├─ ci.yml           # Lint + Pester + web smoke
   │  ├─ codeql.yml       # GitHub CodeQL SAST
   │  └─ fortify.yml      # Fortify on Demand (optional)
   ├─ ISSUE_TEMPLATE/
   ├─ PULL_REQUEST_TEMPLATE.md
   └─ CONTRIBUTING.md
```

Backward-compatible root-level shim scripts (`UltraSecurityMonitor.ps1`,
`masterAgent.ps1`, `Audit-Project.ps1`) delegate to the module and scripts
above.

---

## Ultra Security Monitor – component overview

```
 ┌─────────────────────────────────────────────────────┐
 │          Start-UltraSecurityMonitor (Public)         │
 │                                                      │
 │  ┌──────────────┐    ┌──────────────┐               │
 │  │ Config layer │    │  Dir init    │               │
 │  │ Get-UsmConfig│    │  (BaseFolder)│               │
 │  └──────────────┘    └──────────────┘               │
 │                                                      │
 │  ┌─────────────────────┐  ┌───────────────────────┐ │
 │  │ FileSystemWatcher   │  │ WMI ProcessStartTrace │ │
 │  │ Register-UsmFolder  │  │ (process monitoring)  │ │
 │  │ Monitor             │  │                       │ │
 │  └──────────┬──────────┘  └───────────┬───────────┘ │
 └─────────────┼──────────────────────────┼─────────────┘
               │ events                   │ events
               ▼                          ▼
 ┌─────────────────────────────────────────────────────┐
 │                  Private helpers                     │
 │                                                      │
 │  Write-UsmLog        → NDJSON to security.log        │
 │  Write-UsmSiemEvent  → NDJSON to SIEM/siem.json      │
 │  Backup-UsmFile      → BaseFolder/Backup/ (safe)     │
 │  Send-UsmDiscordAlert→ Discord webhook               │
 │  Send-UsmEmailAlert  → SMTP                          │
 │  Get-UsmVirusTotalReport → VT API v3                 │
 │  Test-UsmProcessSuspicious → heuristics + whitelist  │
 │  Assert-UsmSafePath  → path-traversal guard          │
 └─────────────────────────────────────────────────────┘
```

---

## Configuration layering

Settings are resolved in this order (later layers win):

1. Hard-coded defaults (in `Get-UsmConfig`)
2. `monitor.config.json` in `BaseFolder`
3. Environment variables (`USM_*`)
4. CLI parameters passed to `Start-UltraSecurityMonitor`

---

## Log format

All log entries are **NDJSON** (one JSON object per line):

```json
{"ts":"2024-01-15T10:30:00.000Z","level":"WARN","host":"PC01","user":"alice","message":"SUSPECT PROCESS | ...","event":"SuspiciousProcess","pid":1234,"path":"C:\\Temp\\evil.exe"}
```

SIEM events in `SIEM/siem.json` use a similar schema with `event_type` and `severity` fields.

---

## Security design

| Concern | Mitigation |
|---|---|
| Path traversal | `Assert-UsmSafePath` rejects destinations outside `BaseFolder` |
| Credential leakage | No secrets in source; config + env vars only |
| Privilege escalation | Monitor is read-only except within `BaseFolder` |
| API key exposure | Keys only in `monitor.config.json` (gitignored) or env vars |
