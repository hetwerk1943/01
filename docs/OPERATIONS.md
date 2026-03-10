# Operations Guide

## Starting the monitor

```powershell
# Recommended: use the script wrapper
pwsh -File scripts\run-monitor.ps1

# Or: import the module directly
Import-Module .\src\ultra-security-monitor\UltraSecurityMonitor.psd1
Start-UltraSecurityMonitor
```

Both methods read configuration from `%USERPROFILE%\Documents\SecurityMonitor\monitor.config.json`  
and then from environment variables (env vars override the file).

## Runtime data directory

Default: `%USERPROFILE%\Documents\SecurityMonitor\`

| Path | Purpose |
|------|---------|
| `security.log` | Human-readable event log |
| `security-report.txt` | Summary of suspicious events |
| `SIEM/siem.ndjson` | Newline-delimited JSON (SIEM ingest) |
| `Backup/` | File backups triggered by change events |
| `monitor.config.json` | Runtime configuration (never commit secrets) |
| `whitelist.json` | Process/path whitelist |

## Log rotation

Rotation is checked every 50 log writes.  
When `security.log` exceeds `MaxLogSizeMB` (default 50 MB), it is renamed to  
`security-YYYYMMDD-HHmmss.log` and a new empty `security.log` is created.

## Viewing the dashboard

```powershell
npm start   # serves web/ on http://localhost:8080
```

## Master-agent tasks

```powershell
# Back up current logs
pwsh -File scripts\run-monitor.ps1 -MasterAgent -BackupLogs

# Check required files
pwsh -File scripts\run-monitor.ps1 -MasterAgent -AutoEnhance

# Update sponsor configuration check
pwsh -File scripts\run-monitor.ps1 -MasterAgent -UpdateSponsors
```

## Scheduled task (optional)

Run as Administrator in PowerShell:

```powershell
$action  = New-ScheduledTaskAction -Execute 'pwsh.exe' `
               -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PWD\scripts\run-monitor.ps1`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
Register-ScheduledTask -Action $action -Trigger $trigger `
    -TaskName 'UltraSecurityMonitor' -RunLevel Highest -Force
```

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `Register-WmiEvent failed` | Not running as Administrator | Re-run as Administrator |
| Discord alerts not sent | `USM_DISCORD_WEBHOOK_URL` not set or URL is wrong | Verify env var / webhook URL |
| Log file not created | BaseFolder not writable | Check directory permissions |
| VirusTotal returns `null` | API key missing or quota exceeded | Set `USM_VT_API_KEY`; check VT dashboard |
| PSScriptAnalyzer warnings in CI | Code quality issue | Run linter locally and fix |

## Security notes

- Never store secrets in `monitor.config.json` if the file could be committed.
- The runtime data directory (`Documents\SecurityMonitor`) is gitignored.
- Use `USM_*` environment variables for all secrets.
- The safe-path guardrail (`Test-UsmSafePath`) prevents file operations outside `BaseFolder`.
