# SECURITY-HARDENING.md – ULTRAMASTER APOCALYPSE

## Overview

This document describes the security hardening changes introduced in the
`secure/hardening-safe-alerts` branch and the `SecureHelpers.psm1` module.

---

## Features

| Feature | Description |
|---------|-------------|
| **Command-line redaction** | `Sanitize-CommandLine` strips raw arguments and replaces them with `[REDACTED_ARGS:<8hex>]` where the 8-char prefix is derived from SHA-256 of the arguments. Raw args are never stored or transmitted. |
| **VT result caching** | `Get-VirusTotalReportCached` stores VirusTotal results in `vt_cache.json` for up to 24 hours, reducing API call frequency and avoiding accidental key exposure in logs. |
| **Secret retrieval** | `Get-SecretSafe` tries `Microsoft.PowerShell.SecretManagement` first, then falls back to an environment variable. API keys are never hard-coded. |
| **Sanitized alerts** | `Send-DiscordAlertSafe` / `Send-EmailAlertSafe` compose messages from an allow-listed set of fields only (Name, Host, Owner, Sig, Hash, Timestamp). Paths, network data, and command lines are excluded. |
| **Remediation gate** | `Execute-RemediationSafe` checks `$Global:EnableDryRun` and `$Global:EnableRemediation` before executing any remediation action. Defaults prevent accidental changes. |
| **Encrypted quarantine** | `Move-ToEncryptedQuarantine` copies files to a restricted-ACL quarantine folder (EFS encryption optional). Must be called via `Execute-RemediationSafe`. |

---

## Testing Steps (VM)

1. Clone the repository inside a Windows VM with PowerShell 5.1+.
2. Run the dry-run tests:
   ```powershell
   .\tests\dryrun-redaction.ps1
   ```
   All tests should pass with exit code 0.
3. Verify that no `vt_cache.json` is created during the test run (when `VT_API_KEY` is unset).
4. Confirm `Sanitize-CommandLine` output never contains raw arguments.

---

## Enabling Remediation

Remediation is **disabled by default** (`$EnableRemediation = $false`, `$EnableDryRun = $true`).

To enable, edit the top of `UltraSecurityMonitor.ps1`:
```powershell
$EnableDryRun      = $false
$EnableRemediation = $true
```

> ⚠️ **Only enable remediation in a controlled, tested environment.**
> Test all remediation code paths in dry-run mode first.

---

## Secret Handling

- **Never** commit API keys or secrets to the repository.
- Store secrets using `Microsoft.PowerShell.SecretManagement`:
  ```powershell
  Install-Module Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore
  Set-Secret -Name VirusTotalApiKey -Secret '<your-key>'
  ```
- Alternatively, export the secret as an environment variable:
  ```powershell
  $env:VT_API_KEY = '<your-key>'
  ```
- The `Get-SecretSafe` function tries SecretManagement first, then falls back to `$env:VT_API_KEY`.

---

## Architecture

```
Agent (UltraSecurityMonitor.ps1)
  │
  ├─ Process start event ──► Get-ProcDetails
  │                          Get-FileHashSafe
  │                          Get-FileSignatureStatus
  │                          Get-VirusTotalReportCached ──► vt_cache.json
  │                          Build-AlertSummary (sanitized)
  │                          ├─ Write-Log (sanitized)
  │                          ├─ Write-SiemEvent (sanitized)
  │                          ├─ Send-DiscordAlertSafe
  │                          └─ Send-EmailAlertSafe
  │
  └─ File change event ────► Write-Log / Backup-FileToStore / Write-SiemEvent

Remediation (future):
  Execute-RemediationSafe ──► (dry-run gate) ──► Action or suppression
  Move-ToEncryptedQuarantine (via Execute-RemediationSafe only)
```

---

## ExecutionPolicy & Signing Recommendations

- Run with `-ExecutionPolicy RemoteSigned` or stricter.
- Sign `UltraSecurityMonitor.ps1` and `SecureHelpers.psm1` with a trusted code-signing certificate.
- Restrict script execution to signed scripts in production:
  ```powershell
  Set-ExecutionPolicy AllSigned -Scope LocalMachine
  ```

---

## Log Protection

- Encrypt `security.log`, `security-report.txt`, and `SIEM\siem.json` with EFS:
  ```cmd
  cipher /e /s:"$env:USERPROFILE\Documents\SecurityMonitor"
  ```
- Restrict ACL so only the service account and Administrators can read the log directory.

---

## Rollback Instructions

1. Revert `UltraSecurityMonitor.ps1` to the previous version via git:
   ```powershell
   git checkout main -- UltraSecurityMonitor.ps1
   ```
2. Remove `SecureHelpers.psm1` if desired:
   ```powershell
   Remove-Item SecureHelpers.psm1
   ```
3. The original `Get-VirusTotalReport`, `Send-DiscordAlert`, and `Send-EmailAlert` functions
   remain intact in the codebase history and can be restored from git.
