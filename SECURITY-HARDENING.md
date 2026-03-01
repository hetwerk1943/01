# SECURITY-HARDENING.md
# Ultra Security Monitor – ULTRAMASTER APOCALYPSE Hardening Guide

## Overview

This document describes the security-hardening changes introduced by the
`SecureHelpers.psm1` module and the corresponding updates to `UltraSecurityMonitor.ps1`.

---

## Features

### 1. Command-Line Sanitization (`Sanitize-CommandLine`)

Raw process command lines are **never logged or transmitted**.  
The function returns only:

```
<exe_name> [REDACTED_ARGS:<8-hex-chars>]
```

The 8-hex-char suffix is the first 8 characters of `SHA256(raw_args)`, enabling
correlation without exposing sensitive arguments (credentials, tokens, URLs, etc.).

---

### 2. Secret Handling (`Get-SecretSafe`)

API keys and credentials are retrieved via:

1. **Microsoft.PowerShell.SecretManagement** (`Get-Secret`) when the module is
   installed (recommended).
2. **Environment variable** fallback (e.g. `VT_API_KEY`).

Secrets are **never hard-coded** in scripts. Use placeholders only in committed files.

---

### 3. VirusTotal Caching (`Get-VirusTotalReportCached`)

| Parameter | Default | Description |
|-----------|---------|-------------|
| `CacheTTL_Min` | 1440 (24 h) | Cache time-to-live |
| Cache file | `vt_cache.json` | Stored next to the module |

- No network call is made when the API key is absent.
- Exponential backoff: 3 attempts with `2^n` second delays between retries.
- The cache file is **not created** until a successful VT response is received.

---

### 4. Safe Alerting

| Function | Description |
|----------|-------------|
| `Build-AlertSummary` | Assembles a sanitized hashtable (raw cmd redacted). |
| `Send-DiscordAlertSafe` | Sends only allowed fields, enforces 2000-char limit, TLS 1.2, retry. |
| `Send-EmailAlertSafe` | Redacted subject/body, TLS, retry+backoff, silent error handling. |

---

### 5. Gated Remediation (`Execute-RemediationSafe`)

Remediation is **disabled by default**:

```powershell
$Global:EnableDryRun      = $true   # dry-run: log but never act
$Global:EnableRemediation = $false  # master kill-switch for all actions
```

Any action passed as a `ScriptBlock` is **silently suppressed** unless both
`EnableDryRun = $false` AND `EnableRemediation = $true`.

`Move-ToEncryptedQuarantine` is a helper that copies a file to a restricted ACL
quarantine folder. It must be called only inside a scriptblock passed to
`Execute-RemediationSafe`.

---

## Architecture

```
Agent (UltraSecurityMonitor.ps1)
  │
  ├─► SecureHelpers.psm1   ← sanitize, cache, gate
  │
  ├─► Collector (SIEM JSON / security.log)   ← sanitized cmd only
  │
  └─► Sandbox / Alerting (Discord, Email)    ← redacted fields only
```

---

## Testing

### Automated CI

The workflow `.github/workflows/hardening-dryrun-test.yml` runs on every PR
targeting `secure/hardening-safe-alerts` and on `workflow_dispatch`.  
**No secrets or network access are required.**

```
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/dryrun-redaction.ps1
```

Tests validate:

- `Sanitize-CommandLine` returns a redacted result (not equal to raw input).
- `Get-VirusTotalReportCached` does not create `vt_cache.json` when no API key
  is present.
- `Execute-RemediationSafe` is suppressed in dry-run mode.
- `Build-AlertSummary` sanitizes the command line.

### Manual test

```powershell
Import-Module .\SecureHelpers.psm1 -Force
Sanitize-CommandLine -CommandLine '"cmd.exe" /c whoami'
# Expected: cmd.exe [REDACTED_ARGS:xxxxxxxx]
```

---

## Enabling Remediation

> ⚠️ **Production change – review carefully before enabling.**

1. Set `$EnableDryRun = $false` and `$EnableRemediation = $true` in
   `UltraSecurityMonitor.ps1`.
2. Wrap every `Stop-Process`, `Remove-Item`, or `Move-Item` call with
   `Execute-RemediationSafe`.
3. Test in a staging environment first.
4. Restrict script ACLs and sign the script with a code-signing certificate.

---

## Secret Handling in Production

| Method | Setup |
|--------|-------|
| SecretManagement | `Install-Module Microsoft.PowerShell.SecretManagement`; register a vault and `Set-Secret -Name VirusTotalApiKey -Secret '<key>'` |
| Environment variable | `$env:VT_API_KEY = '<key>'` (CI secret or system environment) |

**Never commit real API keys.**

---

## ExecutionPolicy & Script Signing Recommendations

- Sign `UltraSecurityMonitor.ps1` and `SecureHelpers.psm1` with a trusted
  code-signing certificate.
- Set `ExecutionPolicy AllSigned` or `RemoteSigned` on monitored hosts.
- Restrict the script directory ACL so only `SYSTEM` and administrators can
  write to it.
- Consider enabling EFS on `$LogPath` and `$SiemLogPath` for at-rest encryption.

---

## Rollback

1. Remove the `Import-Module` block and `$EnableDryRun`/`$EnableRemediation`
   lines from `UltraSecurityMonitor.ps1`.
2. Revert the `procAction` block to the previous version (uses `Get-VirusTotalReport`,
   `Send-DiscordAlert`, `Send-EmailAlert`, and raw `$msg`).
3. Delete `SecureHelpers.psm1` if no longer needed.

The `vt_cache.json` file can be deleted safely at any time – it will be
re-created on the next successful VT query.
