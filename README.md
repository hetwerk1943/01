# 🛡️ Ultra Security Monitor – Monorepo

[![CI](https://github.com/hetwerk1943/01/actions/workflows/ci.yml/badge.svg)](https://github.com/hetwerk1943/01/actions/workflows/ci.yml)

A production-grade Windows endpoint security monitor and web dashboard, organized as a maintainable monorepo.

---

## 📁 Repository map

| Path | Description |
|------|-------------|
| [`src/ultra-security-monitor/`](src/ultra-security-monitor/) | PowerShell module (core engine) |
| [`scripts/`](scripts/) | Automation scripts (setup, run, audit) |
| [`tests/powershell/`](tests/powershell/) | Pester 5 test suite |
| [`configs/`](configs/) | Example configuration files |
| [`docs/`](docs/) | Project documentation |
| [`tools/ci/`](tools/ci/) | CI helper scripts |
| [`web/`](web/) | Static HTML/JS mini-apps (served by `npm start`) |
| [`saas-app/`](saas-app/) | Independent SaaS scaffold (React + Node + Prisma) |
| `UltraSecurityMonitor.ps1` | Compatibility shim → module |
| `masterAgent.ps1` | Compatibility shim → `scripts/run-monitor.ps1` |
| `Audit-Project.ps1` | Compatibility shim → `scripts/audit.ps1` |

---

## 🚀 Quick start

```powershell
# 1. Clone and set up
git clone https://github.com/hetwerk1943/01.git
cd 01
pwsh -File scripts\setup.ps1

# 2. Set secrets via environment variables (never commit secrets!)
$env:USM_DISCORD_WEBHOOK_URL = 'https://discord.com/api/webhooks/...'
$env:USM_VT_API_KEY          = 'your-virustotal-api-key'

# 3. Start the monitor (requires Administrator)
pwsh -File scripts\run-monitor.ps1

# 4. Serve the dashboard
npm install && npm start   # http://localhost:8080
```

See [docs/QUICK_START.md](docs/QUICK_START.md) for the full guide.

---

## 🔑 Supported environment variables

| Variable | Purpose |
|----------|---------|
| `USM_DISCORD_WEBHOOK_URL` | Discord webhook for alerts |
| `USM_VT_API_KEY` | VirusTotal API key |
| `USM_SMTP_SERVER` | SMTP server hostname |
| `USM_SMTP_FROM` | Sender e-mail |
| `USM_SMTP_TO` | Recipient e-mail |
| `USM_EMAIL_ALERTS` | `true` to enable e-mail alerts |
| `USM_BASE_FOLDER` | Override runtime data directory |

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [docs/QUICK_START.md](docs/QUICK_START.md) | Installation and first run |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Component overview and data flow |
| [docs/DEVELOPMENT_GUIDE.md](docs/DEVELOPMENT_GUIDE.md) | Contributing and coding conventions |
| [docs/OPERATIONS.md](docs/OPERATIONS.md) | Running in production, log rotation, troubleshooting |

---

## ✅ Requirements

- Windows 10/11 or Windows Server 2019+
- PowerShell 5.1+
- Administrator privileges (for WMI process monitoring)
- Node.js 18+ (optional, for dashboard and CI smoke tests)

---

## 🔒 Security

- **Never commit secrets.** Use `USM_*` environment variables.
- See [SECURITY.md](SECURITY.md) for vulnerability reporting.
- See [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md) for contribution guidelines.
