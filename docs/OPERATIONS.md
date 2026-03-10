# Operations Guide

## Starting the monitor

```powershell
# As Administrator
.\scripts\run-monitor.ps1
```

### With custom config

```powershell
.\scripts\run-monitor.ps1 -ConfigPath 'D:\configs\usm-prod.json'
```

### With environment variable overrides

```powershell
$env:USM_DISCORD_WEBHOOK = 'https://discord.com/api/webhooks/...'
$env:USM_VT_API_KEY      = 'your-vt-key'
.\scripts\run-monitor.ps1
```

---

## Scheduled Task (auto-start on login)

Run the following as **Administrator**:

```powershell
$scriptPath = (Resolve-Path '.\scripts\run-monitor.ps1').Path
$action  = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
Register-ScheduledTask -Action $action -Trigger $trigger `
    -TaskName 'UltraSecurityMonitor' -RunLevel Highest -Force
```

Remove the scheduled task:

```powershell
Unregister-ScheduledTask -TaskName 'UltraSecurityMonitor' -Confirm:$false
```

---

## Log files

| File | Location | Format |
|---|---|---|
| Main log | `BaseFolder\security.log` | NDJSON |
| SIEM events | `BaseFolder\SIEM\siem.json` | NDJSON |
| Suspect report | `BaseFolder\security-report.txt` | Plain text |
| Archived logs | `BaseFolder\security-YYYYMMDD-HHmmss.log` | NDJSON |

### Tailing logs

```powershell
Get-Content "$env:USERPROFILE\Documents\SecurityMonitor\security.log" -Wait
```

### Parsing NDJSON logs in PowerShell

```powershell
Get-Content "$env:USERPROFILE\Documents\SecurityMonitor\security.log" |
    ForEach-Object { $_ | ConvertFrom-Json } |
    Where-Object { $_.level -eq 'WARN' }
```

---

## Log rotation

Rotation is automatic: when `security.log` exceeds `MaxLogSizeMB` (default 50 MB),
it is archived as `security-YYYYMMDD-HHmmss.log`. A new `security.log` starts fresh.

To change the threshold, set `MaxLogSizeMB` in `monitor.config.json` or
`$env:USM_MAX_LOG_SIZE_MB`.

---

## Alerting

### Discord

Set `DiscordWebhookUrl` in config or `$env:USM_DISCORD_WEBHOOK`.

### E-mail

Set `EmailAlerts: true` and configure SMTP settings in `monitor.config.json`.

### VirusTotal

Set `VirusTotalApiKey` in config or `$env:USM_VT_API_KEY`.
Free tier: 4 requests/minute; consider upgrading for high-traffic environments.

---

## Troubleshooting

| Symptom | Likely cause | Resolution |
|---|---|---|
| "Access denied" on folder watch | Not running as Administrator | Re-launch as Administrator |
| WMI subscription fails | WMI service stopped | `Start-Service winmgmt` |
| No Discord alerts | Empty webhook URL | Set `DiscordWebhookUrl` in config |
| Log file not created | BaseFolder doesn't exist | Run `.\scripts\setup.ps1` |
| AV flags the script | Heuristic match | Add script path to AV whitelist |
| Script execution blocked | Execution policy | `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` |
