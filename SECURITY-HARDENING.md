# Security Hardening Guide

This document describes how to securely configure and operate **Ultra Security Monitor** with the `SecureHelpers` module.

---

## Secrets management

### Option A — Microsoft.PowerShell.SecretManagement (recommended)

```powershell
# Install once
Install-Module Microsoft.PowerShell.SecretManagement -Scope CurrentUser
Install-Module Microsoft.PowerShell.SecretStore      -Scope CurrentUser

# Register a vault (run as the service account that runs the monitor)
Register-SecretVault -Name LocalStore -ModuleName Microsoft.PowerShell.SecretStore

# Store the VirusTotal API key
Set-Secret -Vault LocalStore -Name VirusTotalApiKey -Secret "your-vt-api-key"

# (Optional) Store SMTP password
Set-Secret -Vault LocalStore -Name SmtpPassword -Secret "your-smtp-password"
```

`Get-SecretSafe` will automatically read from this vault at runtime.

### Option B — Environment variables (fallback)

```powershell
# Set per-user (survives reboots)
[System.Environment]::SetEnvironmentVariable("VT_API_KEY", "your-vt-api-key", "User")
```

> **Never commit secrets to source control.** Add `vt_cache.json` and any credential files to `.gitignore`.

---

## Testing with dry-run enabled (safe default)

1. Open PowerShell **as Administrator** in the repository directory.
2. Verify defaults in `UltraSecurityMonitor.ps1`:
   ```powershell
   $EnableDryRun      = $true   # ← must be true for safe testing
   $EnableRemediation = $false  # ← must be false for safe testing
   ```
3. Run the monitor:
   ```powershell
   .\UltraSecurityMonitor.ps1
   ```
4. Start a test process that matches the suspicious heuristics. Use a script that sleeps briefly so the WMI event fires before the process exits:
   ```powershell
   # Create a harmless test script and run it via wscript.exe
   "WScript.Sleep(5000)" | Set-Content "$env:TEMP\test_alert.vbs"
   Start-Process wscript.exe -ArgumentList "$env:TEMP\test_alert.vbs"
   ```
5. Verify:
   - Discord / e-mail messages contain **`[args redacted, corr=XXXXXXXX]`** — no raw arguments.
   - `SIEM\siem.json` `commandLine` field shows the sanitized value.
   - `security.log` and `security-report.txt` retain full local detail (restrict ACLs, see below).
   - `vt_cache.json` is created in the script directory after the first successful VirusTotal lookup.
   - Console shows `[DRY-RUN] Remediation skipped` if any remediation path is triggered.

### Inspect the VirusTotal cache

```powershell
Get-Content .\vt_cache.json | ConvertFrom-Json
```

Each entry is keyed by SHA-256 hash and includes `cachedAt`, `Malicious`, `Suspicious`, `Undetected`, and `Harmless`. The default TTL is 60 minutes (`$Global:VT_CacheTTL_Min`).

---

## Enabling remediation in a controlled environment

> ⚠️ Only enable remediation after reviewing every remediation `ScriptBlock` and testing thoroughly in a non-production VM.

1. Edit `UltraSecurityMonitor.ps1`:
   ```powershell
   $EnableDryRun      = $false  # Allow remediation actions to run
   $EnableRemediation = $true   # Gates every Execute-RemediationSafe call
   ```
2. Add a non-destructive test ScriptBlock, for example moving a file to an encrypted quarantine folder:
   ```powershell
   Execute-RemediationSafe -Reason "Quarantine $path" -Action {
       $dest = Join-Path $BackupFolder ("quarantine_" + [System.IO.Path]::GetFileName($path))
       Move-Item -Path $path -Destination $dest -Force
   }
   ```
3. Verify the audit entry appears in `security.log` prefixed with `[AUDIT] Remediation executed`.
4. **Roll back**: set `$EnableDryRun = $true` and `$EnableRemediation = $false` to instantly disable all remediation.

---

## Protecting local log files

Local logs (`security.log`, `security-report.txt`) may still contain full command-line details for forensic purposes. Restrict access:

```powershell
# Restrict ACL to Administrators and SYSTEM only
$acl  = Get-Acl $LogPath
$acl.SetAccessRuleProtection($true, $false)
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "BUILTIN\Administrators", "FullControl", "Allow")
$acl.AddAccessRule($rule)
Set-Acl -Path $LogPath -AclObject $acl
```

Alternatively, store logs on an EFS-encrypted volume or forward them to a SIEM over TLS.

---

## Service account best practices

- Run the monitor under a **dedicated service account** with least-privilege (no interactive logon, no admin rights beyond what WMI monitoring requires).
- Do **not** run under a personal administrator account.
- Rotate the VirusTotal API key periodically and update it in the vault.
- Review `vt_cache.json` permissions — it should not be world-readable.

---

## Rollback instructions

1. Revert `UltraSecurityMonitor.ps1` to the previous commit:
   ```powershell
   git checkout HEAD~1 -- UltraSecurityMonitor.ps1
   ```
2. Remove (or do not import) `SecureHelpers.psm1`.
3. The original `Get-VirusTotalReport`, `Send-DiscordAlert`, and `Send-EmailAlert` functions are preserved in `UltraSecurityMonitor.ps1` and will continue to work without the module.
