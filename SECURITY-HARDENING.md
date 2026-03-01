# SECURITY HARDENING – ULTRAMASTER APOCALYPSE

This document describes the security hardening features introduced in the
`secure/hardening-safe-alerts` branch.

---

## Features

### 1. SecureHelpers.psm1 module

A reusable PowerShell module exposing the following functions:

| Function | Description |
|---|---|
| `Sanitize-CommandLine` | Replaces command-line arguments with `[REDACTED_ARGS:<8hexchars>]` (first 8 chars of SHA-256 of the original args). The executable name is preserved. |
| `Get-SecretSafe` | Retrieves a secret from Microsoft.PowerShell.SecretManagement (if installed), falling back to an environment variable. Never hard-codes credentials. |
| `Get-VirusTotalReportCached` | Queries VT API v3 with a local JSON cache (`vt_cache.json`, TTL 1440 min) and exponential-backoff retries (3 attempts). Returns `$null` when no API key is set or on errors. |
| `Build-AlertSummary` | Returns a standardised hashtable (Timestamp, Host, ProcessName, Owner, SigStatus, Hash, Cmd). The `Cmd` field is always sanitized via `Sanitize-CommandLine`. |
| `Send-DiscordAlertSafe` | Sends a redacted Discord webhook message. Enforces TLS 1.2, limits to 2000 chars, retries with backoff, silent on failure. |
| `Send-EmailAlertSafe` | Sends a redacted email via SMTP. Enforces TLS, retries with backoff, silent on failure. |
| `Execute-RemediationSafe` | Executes a `ScriptBlock` only when `$Global:EnableRemediation = $true` **and** `$Global:EnableDryRun = $false`. Logs and returns `$false` otherwise. |
| `Move-ToEncryptedQuarantine` | Copies a file to a quarantine directory, removes inherited ACLs, and grants only `SYSTEM` full control. Invoke via `Execute-RemediationSafe`. |

### 2. Alert sanitization

- Process command-line arguments are **never** written to logs, SIEM events, or alerts in raw form.
- Arguments are replaced with `[REDACTED_ARGS:<token>]` where the token is the first 8 hex characters of SHA-256 of the original argument string.
- File paths are still included in file-change log entries (local log only). The log file ACLs should be restricted to SYSTEM/Administrators (see note in `Register-FolderMonitor`).

### 3. VT cache

- Successful VT results are stored in `vt_cache.json` next to `SecureHelpers.psm1`.
- Default TTL: **1440 minutes (24 hours)**.
- The cache file is **not created** when no API key is configured, preventing noisy writes.

### 4. Safe remediation (dry-run by default)

Remediation is **disabled by default** (`$Global:EnableDryRun = $true`, `$Global:EnableRemediation = $false`).

---

## Testing Steps

```powershell
# Run the dry-run redaction tests (no network, no secrets needed)
.\tests\dryrun-redaction.ps1
```

Expected output: `All tests passed.`

### CI

The workflow `.github/workflows/hardening-dryrun-test.yml` runs these tests automatically on every PR targeting `secure/hardening-safe-alerts` and on `workflow_dispatch`. No network access or secrets are required.

---

## Enabling Remediation

> ⚠️ Only enable remediation after thorough testing in an isolated environment.

1. Set `$EnableDryRun = $false` and `$EnableRemediation = $true` near the top of `UltraSecurityMonitor.ps1`.
2. Uncomment the `Execute-RemediationSafe` blocks in the `$procAction` handler and `Register-FolderMonitor`.
3. Review each remediation action before enabling.

---

## Secret Handling

- **Never** commit API keys, webhook URLs, or SMTP credentials to source control.
- Use environment variables (`VT_API_KEY`, etc.) or a secrets manager compatible with `Microsoft.PowerShell.SecretManagement`.
- The `Get-SecretSafe` function transparently handles both methods.
- All placeholder values in `UltraSecurityMonitor.ps1` are empty strings by default.

---

## Architecture

```
Agent (UltraSecurityMonitor.ps1)
  │
  ├─► Collector (Write-SiemEvent → siem.json)
  │     └── Sanitized fields only (commandLine = redacted token)
  │
  ├─► Sandbox (VT cache + Get-VirusTotalReportCached)
  │     └── Local JSON cache, no raw keys in logs
  │
  ├─► Alert channels (Send-DiscordAlertSafe / Send-EmailAlertSafe)
  │     └── Redacted summaries, TLS enforced, retry/backoff
  │
  └─► Remediation (Execute-RemediationSafe)
        └── Disabled by default (dry-run mode)
```

---

## Log File Security

Log files (`security.log`, `security-report.txt`, `siem.json`) are written to
`%USERPROFILE%\Documents\SecurityMonitor\`. Administrators should:

1. Restrict ACLs on this folder to `SYSTEM` and the monitoring service account only.
2. Consider enabling EFS or BitLocker on the containing volume.
3. Rotate and archive logs regularly (the monitor auto-rotates at 50 MB).
