# 🛡️ Ultra Security Monitor

> Real-time Windows security monitoring: process surveillance, file-system watching,
> SIEM/NDJSON logging, Discord/Email/VirusTotal integration.

[![CI](https://github.com/hetwerk1943/01/actions/workflows/ci.yml/badge.svg)](https://github.com/hetwerk1943/01/actions/workflows/ci.yml)

---

## Repository map

| Path | Description |
|---|---|
| [`src/UltraSecurityMonitor/`](src/UltraSecurityMonitor/) | PowerShell module – primary product |
| [`scripts/`](scripts/) | Setup, launch and audit helpers |
| [`configs/`](configs/) | Example configuration files |
| [`tests/powershell/`](tests/powershell/) | Pester unit + integration tests |
| [`tools/ci/`](tools/ci/) | CI helpers (web smoke test) |
| [`web/`](web/) | Static web mini-apps (repo-agent, joke-generator) |
| [`saas-app/`](saas-app/) | Independent SaaS scaffold (React + Node + Prisma) |
| [`docs/`](docs/) | Full documentation |
| [`.github/workflows/`](.github/workflows/) | GitHub Actions (CI, CodeQL, Fortify) |

---

## Quick start

```powershell
# 1. Clone
git clone https://github.com/hetwerk1943/01.git && cd 01

# 2. Set up runtime directories and copy example config
.\scripts\setup.ps1

# 3. (Optional) edit config
notepad "$env:USERPROFILE\Documents\SecurityMonitor\monitor.config.json"

# 4. Run (as Administrator)
.\scripts\run-monitor.ps1
```

→ Full guide: [docs/QUICK_START.md](docs/QUICK_START.md)

---

## Configuration

Sensitive values are **never stored in source code**. Provide them via:

| Method | Example |
|---|---|
| `monitor.config.json` | `"DiscordWebhookUrl": "https://..."` |
| Environment variable | `$env:USM_DISCORD_WEBHOOK = "https://..."` |

See [`configs/monitor.config.example.json`](configs/monitor.config.example.json) for all options.

| Environment variable | Purpose |
|---|---|
| `USM_DISCORD_WEBHOOK` | Discord webhook URL |
| `USM_VT_API_KEY` | VirusTotal API key |
| `USM_BASE_FOLDER` | Override base folder |
| `USM_MAX_LOG_SIZE_MB` | Log rotation threshold |

---

## Documentation

| Document | Description |
|---|---|
| [docs/QUICK_START.md](docs/QUICK_START.md) | Install and run in 5 minutes |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Component overview, data flow, log format |
| [docs/DEVELOPMENT_GUIDE.md](docs/DEVELOPMENT_GUIDE.md) | Contributing, testing, linting |
| [docs/OPERATIONS.md](docs/OPERATIONS.md) | Scheduled tasks, log rotation, alerting, troubleshooting |

---

## Backward compatibility

The root-level scripts (`UltraSecurityMonitor.ps1`, `masterAgent.ps1`,
`Audit-Project.ps1`) are preserved as shims that delegate to the new module and
scripts. Existing usage documented in older versions continues to work.

---

## Development

```powershell
# Install dev tools
.\scripts\setup.ps1 -InstallDevTools

# Lint
Invoke-ScriptAnalyzer -Path src -Recurse -Severity Warning

# Test
Invoke-Pester -Path tests/powershell -Output Detailed
```

See [docs/DEVELOPMENT_GUIDE.md](docs/DEVELOPMENT_GUIDE.md) and [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md).

---

## Sub-projects

### `saas-app/`

An independent fullstack SaaS scaffold (React/Vite client + Node/Express API +
Prisma/PostgreSQL). It has its own CI, README, and Docker Compose file.
See [`saas-app/README.md`](saas-app/README.md).

### `web/`

Static HTML/JS mini-apps served locally:
- `web/repo-agent/` – AI-powered repository agent UI
- `web/joke-generator/` – Random joke generator

Serve locally:
```bash
npm start   # serves ./web on port 8080
```

---

## Security

See [SECURITY.md](SECURITY.md) for the vulnerability disclosure policy.
