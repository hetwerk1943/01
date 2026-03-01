# Changelog

All notable changes to Ultra Security Monitor are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

### Added
- Unit tests for pure business-logic functions (`tests/logic.test.mjs`) using the
  Node.js built-in test runner (no extra dependencies required).
- `npm test` script in `package.json` that runs the test suite.
- `Content-Security-Policy` meta header to `dashboard.html`, `agent.html`, and
  `web/repo-agent/index.html` to reduce XSS attack surface.
- `CHANGELOG.md` (this file) to track project history.

### Changed
- Upgraded `actions/checkout` from v3 → v4 in `main.yml` and `master-agent.yml`.
- Upgraded `actions/setup-node` from v3 → v4 in `main.yml`.
- `main.yml` now installs dependencies and runs `npm test` before serving the agent.
- `master-agent.yml` Slack notification step now skips gracefully when the
  `SLACK_WEBHOOK` secret is not configured, preventing unnecessary run failures.
- Bumped `package.json` version to 1.1.0.

---

## [1.0.0] – 2025-01-01

### Added
- `UltraSecurityMonitor.ps1` – full Windows EDR/IDS monitoring engine.
- `dashboard.html` – dark-mode HTML dashboard with file-based SIEM log viewer.
- `agent.html` – GitHub repository AI analysis agent with Chart.js confidence trend.
- `web/repo-agent/` – modular version of the AI agent (separate HTML / JS / CSS).
- `web/joke-generator/` – lightweight random joke generator mini-app.
- `masterAgent.ps1` – nightly automation: sponsors update, log backup, syntax check,
  project stats.
- `Audit-Project.ps1` – standalone project audit script.
- `master-agent.yml` – nightly GitHub Actions workflow for the master agent.
- `main.yml` – CI workflow: serves the static app and verifies `agent.html` exists.
- `codeql.yml` – CodeQL security scanning workflow.
- Log rotation in `UltraSecurityMonitor.ps1` (auto-archive when log exceeds 50 MB).
- VirusTotal API v3 integration for SHA-256 hash lookups.
- Discord webhook and SMTP e-mail alerting.
- SIEM NDJSON export compatible with Splunk / ELK / Graylog.
- Whitelist support via `whitelist.json`.
