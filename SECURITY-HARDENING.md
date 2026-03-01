# SECURITY-HARDENING.md

This document describes the secure-hardening additions introduced alongside `SecureHelpers.psm1`
and the corresponding changes to `UltraSecurityMonitor.ps1`.

---

## How SecureHelpers works

`SecureHelpers.psm1` provides six exported functions that reduce exfiltration risk and accidental
destructive remediation:

| Function | Purpose |
|---|---|
| `Sanitize-CommandLine` | Replaces argument tokens with a short SHA-256 fingerprint – raw arguments are never stored or sent. |
| `Get-SecretSafe` | Reads a secret from `Microsoft.PowerShell.SecretManagement`; falls back to an environment variable; returns `$null` if neither is available. |
| `Get-VirusTotalReportCached` | Caches VT API results in `vt_cache.json` (default TTL 60 min). Retrieves the API key via `Get-SecretSafe` instead of reading it from script variables. |
| `Build-AlertSummary` | Builds a hashtable with redacted command line, ready to be serialised. |
| `Send-DiscordAlertSafe` | Posts only the redacted summary (≤ 1 900 chars) to Discord. |
| `Send-EmailAlertSafe` | Sends only the redacted summary via SMTP. |
| `Execute-RemediationSafe` | Wraps any destructive action; honours the `$Global:EnableDryRun` / `$Global:EnableRemediation` flags. |

### Global flags (set in `UltraSecurityMonitor.ps1` before `Import-Module`)

| Variable | Default | Meaning |
|---|---|---|
| `$Global:EnableDryRun` | `$true` | When `$true`, `Execute-RemediationSafe` logs the action but does **not** execute it. |
| `$Global:EnableRemediation` | `$false` | Must be `$true` **and** `EnableDryRun` must be `$false` for any remediation to run. |

---

## Testing steps (test VM)

1. **Prepare environment**
   ```powershell
   # Set a real or mock VirusTotal key
   $env:VT_API_KEY = "YOUR_VT_API_KEY_HERE"
   ```

2. **Run with dry-run (default)**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   .\UltraSecurityMonitor.ps1
   ```

3. **Trigger a suspicious-process event** (e.g. launch `mshta.exe` from Temp).  
   Verify that:
   - The Discord / e-mail alert contains `[REDACTED_ARGS:<8hex>]` instead of raw arguments.
   - `vt_cache.json` is created/updated in the script directory.
   - `SIEM\siem.json` `commandLine` field shows only the sanitized value.
   - No raw command-line arguments appear in any outbound message.

4. **Inspect the cache**
   ```powershell
   Get-Content .\vt_cache.json | ConvertFrom-Json
   ```
   Each entry contains `timestamp`, `Malicious`, `Suspicious`, `Undetected`, `Harmless`.  
   A second lookup within the TTL window will return the cached result without a network call.

---

## Supplying the VirusTotal API key

### Option A – Microsoft.PowerShell.SecretManagement (recommended)

```powershell
Install-Module Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore -Scope CurrentUser
Register-SecretVault -Name LocalStore -ModuleName Microsoft.PowerShell.SecretStore
Set-Secret -Name VirusTotalApiKey -Secret "YOUR_VT_API_KEY_HERE" -Vault LocalStore
```

### Option B – Environment variable (simpler, less secure)

```powershell
[System.Environment]::SetEnvironmentVariable('VT_API_KEY', 'YOUR_KEY', 'User')
```

Or set it temporarily in the current session:

```powershell
$env:VT_API_KEY = "YOUR_KEY"
```

---

## Enabling remediation

> ⚠️ Only enable remediation in a controlled test environment after thorough review.

Edit the top of `UltraSecurityMonitor.ps1`:

```powershell
$EnableDryRun      = $false   # change from $true
$EnableRemediation = $true    # change from $false
```

Any code block using `Execute-RemediationSafe` will now execute the supplied `ScriptBlock`.

To test with a non-destructive action:

```powershell
Execute-RemediationSafe -ActionScriptBlock {
    Move-Item "C:\Quarantine\test.exe" "C:\Quarantine\test.exe.bak" -Force
} -Reason "Test quarantine move"
```

---

## Protecting local log files (recommended)

The log files `security.log`, `security-report.txt`, and `SIEM\siem.json` may still contain
sensitive path and process metadata. Harden access:

```powershell
# Restrict ACL so only SYSTEM and the running account can read the log folder
$acl = Get-Acl $BaseFolder
$acl.SetAccessRuleProtection($true, $false)
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $env:USERNAME, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)
Set-Acl $BaseFolder $acl
```

Alternatively, enable EFS on the folder via `cipher /e /s:"$BaseFolder"`.

**Do not forward raw log files outside the designated SIEM Collector.**

---

## Rollback instructions

If you need to revert to the previous behaviour:

1. Remove or comment out the four lines added at the top of the `KONFIGURACJA` section in
   `UltraSecurityMonitor.ps1`:
   ```powershell
   # $EnableDryRun       = $true
   # $EnableRemediation  = $false
   # Import-Module (Join-Path $PSScriptRoot "SecureHelpers.psm1") -Force
   # Set-Variable ...
   ```
2. Restore the original `$procAction` block (use `git revert` or `git checkout`).
3. `SecureHelpers.psm1` can remain in the repository without affecting anything if not imported.

```powershell
# Revert all hardening changes in one command (run from repo root)
git revert HEAD
```
