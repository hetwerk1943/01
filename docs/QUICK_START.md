# Quick Start

## Prerequisites

- Windows 10/11 or Windows Server 2019+
- PowerShell 5.1 or later (or PowerShell 7+)
- Elevated (Administrator) privileges

## 1. Clone the repository

```powershell
git clone https://github.com/hetwerk1943/01.git
cd 01
```

## 2. Run setup

```powershell
pwsh -File scripts\setup.ps1
```

This creates `%USERPROFILE%\Documents\SecurityMonitor\` and copies example config files there.

## 3. Configure secrets via environment variables

**Never paste secrets into files that could be committed.**  
Set environment variables in your session or in a `.env` file that is gitignored:

| Variable | Purpose |
|----------|---------|
| `USM_DISCORD_WEBHOOK_URL` | Discord webhook URL for alerts |
| `USM_VT_API_KEY` | VirusTotal API key |
| `USM_SMTP_SERVER` | SMTP server hostname |
| `USM_SMTP_FROM` | Sender e-mail address |
| `USM_SMTP_TO` | Recipient e-mail address |
| `USM_EMAIL_ALERTS` | Set to `true` to enable e-mail alerts |
| `USM_BASE_FOLDER` | Override the runtime data directory |
| `USM_MAX_LOG_SIZE_MB` | Maximum log size before rotation (default: 50) |

Example (PowerShell):

```powershell
$env:USM_DISCORD_WEBHOOK_URL = 'https://discord.com/api/webhooks/...'
$env:USM_VT_API_KEY          = 'your-virustotal-api-key'
```

## 4. Start the monitor

```powershell
pwsh -File scripts\run-monitor.ps1
```

## 5. View the dashboard

```powershell
npm start          # Serves the web/ directory on http://localhost:8080
```

Open <http://localhost:8080> in your browser.

## Optional: Import the module directly

```powershell
Import-Module .\src\ultra-security-monitor\UltraSecurityMonitor.psd1
Start-UltraSecurityMonitor
```

## Troubleshooting

- **"Access denied" errors**: ensure you run as Administrator.
- **PSScriptAnalyzer failures in CI**: run `Invoke-ScriptAnalyzer -Path . -Recurse -Severity Warning` locally to find issues before pushing.
- **Log file location**: `%USERPROFILE%\Documents\SecurityMonitor\security.log`
