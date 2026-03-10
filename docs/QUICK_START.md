# Quick Start

Get the Ultra Security Monitor running in under five minutes.

## Prerequisites

| Requirement | Version |
|---|---|
| Windows | 10 / 11 / Server 2019+ |
| PowerShell | 5.1 or 7.x |
| Privileges | Administrator |

## 1 – Clone or download

```powershell
git clone https://github.com/hetwerk1943/01.git
cd 01
```

## 2 – Run setup

```powershell
.\scripts\setup.ps1
```

This creates `%USERPROFILE%\Documents\SecurityMonitor\` and copies example
configuration files.

To also install development tools (Pester, PSScriptAnalyzer):

```powershell
.\scripts\setup.ps1 -InstallDevTools
```

## 3 – Configure (optional)

Edit `%USERPROFILE%\Documents\SecurityMonitor\monitor.config.json`:

```json
{
  "DiscordWebhookUrl": "https://discord.com/api/webhooks/...",
  "VirusTotalApiKey": "",
  "EmailAlerts": false
}
```

Sensitive values can also be provided via environment variables (they take
precedence over the JSON file):

| Variable | Purpose |
|---|---|
| `USM_DISCORD_WEBHOOK` | Discord webhook URL |
| `USM_VT_API_KEY` | VirusTotal API key |
| `USM_BASE_FOLDER` | Override base folder |

## 4 – Start the monitor

```powershell
# As Administrator
.\scripts\run-monitor.ps1
```

Press **Ctrl+C** to stop.

## 5 – View logs

```powershell
# Live tail (NDJSON, one event per line)
Get-Content "$env:USERPROFILE\Documents\SecurityMonitor\security.log" -Wait
```

Open `dashboard.html` in your browser for a graphical view.

---

## Next steps

- See [docs/ARCHITECTURE.md](ARCHITECTURE.md) for a component overview.
- See [docs/OPERATIONS.md](OPERATIONS.md) for scheduled tasks and alerting.
