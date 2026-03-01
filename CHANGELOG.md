# Changelog

All notable changes to **Ultra Security Monitor** are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

### Added
- Unit tests for `web/repo-agent/app.js` logic (`test/agent.test.js`) covering
  `deepRepoScan`, `securityRiskEngine`, `repoMaturityLevel`, and `aiConfidence`.
- `jest` dev-dependency and `npm test` script in `package.json`.
- Project CI workflow (`.github/workflows/jekyll-docker.yml` replaced) – validates
  required files and runs the test suite on every push/PR to `main`.

### Changed
- Upgraded `actions/checkout` from `@v3` → `@v4` in `main.yml` and `master-agent.yml`.
- Upgraded `actions/setup-node` from `@v3` → `@v4` in `main.yml`.
- CI renamed from "Jekyll site CI" (which was incompatible with this project) to "Project CI".

---

## [1.0.0] – Initial Release

### Added
- `UltraSecurityMonitor.ps1` – real-time Windows EDR/IDS engine using WMI
  (`Win32_ProcessStartTrace`), file-system watchers, VirusTotal API v3,
  Discord/e-mail alerts, SHA-256 hashing, authenticode signature checks,
  log rotation, and SIEM NDJSON export.
- `masterAgent.ps1` – nightly automation: sponsor check, log backup,
  project file verification, PowerShell syntax audit, market-statistics report.
- `Audit-Project.ps1` – lightweight project audit: required-file checks,
  PS1 syntax validation, Git status, VirusTotal connectivity test.
- `dashboard.html` – dark-mode HTML/JS dashboard for visualising `siem.json`
  and `security.log` locally (no backend required).
- `agent.html` / `web/repo-agent/` – AI Repo Agent: loads any public GitHub
  repository via the REST API, performs deep scan, security-risk rating,
  maturity scoring, roadmap generation, and confidence-trend chart (Chart.js).
- `web/joke-generator/` – simple random-joke mini-app (JokeAPI v2).
- GitHub Actions: CodeQL scanning, nightly master-agent run, stale-issue bot.
- `package.json` with `http-server` for local static serving.
