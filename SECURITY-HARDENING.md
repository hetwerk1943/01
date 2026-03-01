# SECURITY-HARDENING.md

Security hardening documentation for **Ultra Security Monitor – Total Edition**.

> ⚠️ **Reminder for reviewers**: All remediations are **disabled by default**.
> Enable them only after testing in an isolated VM and completing a manual review.

---

## Overview

`SecureHelpers.psm1` is a PowerShell module that wraps alert sending, command-line
sanitisation, and remediation execution in safe, auditable helpers. Key design
principles:

* **Dry-run by default** – `$EnableDryRun = $true` prevents any destructive or
  network action until you explicitly opt in.
* **Remediation disabled by default** – `$EnableRemediation = $false` means no
  file operations are triggered automatically.
* **No hardcoded secrets** – webhook URLs and SMTP credentials must be supplied
  at runtime; they are never committed to source control.

---

## Functions

### `Sanitize-CommandLine`

Redacts sensitive-looking arguments (passwords, tokens, API keys, bearer tokens,
and URL credentials) from a command-line string using regex substitution.

```powershell
$clean = Sanitize-CommandLine -CommandLine 'cmd.exe --password P@ssw0rd'
# $clean => 'cmd.exe --password [REDACTED]'
```

Redaction patterns cover common argument styles:

| Pattern | Example input | Redacted output |
|---------|--------------|-----------------|
| `--password VALUE` | `--password S3cr3t` | `--password [REDACTED]` |
| `/password:VALUE` | `/password:abc` | `/password:[REDACTED]` |
| `--token VALUE` | `--token xyz123` | `--token [REDACTED]` |
| `--key=VALUE` | `--key=abc` | `--key=[REDACTED]` |
| `bearer TOKEN` | `bearer eyJ...` | `bearer [REDACTED]` |
| `user:pass@host` in URLs | `https://u:p@host` | `https://[REDACTED]@host` |

---

### `Build-AlertSummary`

Builds a sanitised alert summary hashtable. The `CommandLine` field is
automatically passed through `Sanitize-CommandLine`.

```powershell
$summary = Build-AlertSummary `
    -ProcessName 'cmd.exe' `
    -CommandLine 'cmd.exe --password P@ssw0rd' `
    -Owner       'DOMAIN\alice' `
    -Severity    'High'
# $summary.CommandLine => 'cmd.exe --password [REDACTED]'
```

---

### `Execute-RemediationSafe`

Executes a remediation `ScriptBlock` only when **both** conditions are true:

1. `$EnableDryRun` is `$false`
2. `$EnableRemediation` is `$true`

In all other cases the action is logged to stdout and skipped.

```powershell
Execute-RemediationSafe -Description "Quarantine $file" -Action {
    Move-ToEncryptedQuarantine -FilePath $file
}
```

> **STOP – read before enabling**: Set `$EnableRemediation = $true` only after:
> 1. Testing in an isolated VM with representative suspicious files.
> 2. Confirming the quarantine path is on an encrypted volume (BitLocker/EFS).
> 3. Verifying the service account ACL is applied correctly.

---

### `Send-DiscordAlertSafe` / `Send-EmailAlertSafe`

Safe wrappers around Discord and SMTP alerts. In dry-run mode they write the
message to stdout instead of making network calls, making them safe to use in CI.

```powershell
Send-DiscordAlertSafe -Message $summary.CommandLine -WebhookUrl $env:DISCORD_WEBHOOK
Send-EmailAlertSafe   -Subject "Alert" -Body $summary.CommandLine `
    -SmtpServer $env:SMTP_SERVER -SmtpFrom $env:SMTP_FROM -SmtpTo $env:SMTP_TO
```

---

## Example Remediation Function: `Move-ToEncryptedQuarantine`

`Move-ToEncryptedQuarantine` demonstrates a safe remediation pattern. It:

1. **Copies** (never deletes) a suspicious file into `$BackupFolder\Quarantine`.
2. Sets a restrictive ACL so only the service account can access the file.
3. Logs the quarantine action to `security.log`.
4. Is **always** gated by `Execute-RemediationSafe` – it will not run while
   `$EnableDryRun = $true` or `$EnableRemediation = $false`.

### Example usage

```powershell
# Load the module
Import-Module ./SecureHelpers.psm1

# WARNING: Only set these after VM testing and manual review!
# $Script:EnableDryRun      = $false
# $Script:EnableRemediation = $true

Execute-RemediationSafe -Description "Quarantine suspicious file" -Action {
    Move-ToEncryptedQuarantine -FilePath "C:\Temp\suspicious.exe" `
                               -ServiceAccount "DOMAIN\SecuritySvc"
}
```

### Step-by-step enablement checklist

- [ ] Spin up an isolated Windows VM with BitLocker enabled on the target volume.
- [ ] Set `$Script:BackupFolder` to a path on the encrypted volume.
- [ ] Run `tests/dryrun-redaction.ps1` with `$EnableDryRun = $true` – all tests
      should pass.
- [ ] Set `$EnableDryRun = $false` and `$EnableRemediation = $true` in the VM.
- [ ] Drop a benign dummy file and run `Execute-RemediationSafe` manually.
- [ ] Confirm the file appears in `$BackupFolder\Quarantine` and the ACL is
      restricted.
- [ ] Review `security.log` for the quarantine log entry.
- [ ] Only after successful VM validation should you enable remediation in
      production.

---

## CI Dry-Run Validation

### Workflow: `.github/workflows/hardening-dryrun-test.yml`

The `Hardening Dry-Run Test` workflow runs automatically on:

* Every pull request targeting `secure/hardening-safe-alerts`.
* Manual trigger via `workflow_dispatch`.

**What it does:**

1. Checks out the repository.
2. Invokes `tests/dryrun-redaction.ps1` with PowerShell (`pwsh`).
3. The test script loads `SecureHelpers.psm1`, sets dry-run and remediation flags
   to their safe defaults, and runs 9 assertions.
4. The workflow fails (non-zero exit) if any assertion fails.

**What the CI job does NOT do:**

* It makes **no** external network calls.
* It does **not** require any repository secrets.
* It does **not** modify any files on disk (it cleans up its temp folder).

### Running the test locally

```powershell
# From the repository root:
pwsh -NoProfile -File tests/dryrun-redaction.ps1
```

Expected output when all assertions pass:

```
=== dryrun-redaction.ps1 ===

TEST 1: --password argument is redacted
  [PASS] Sanitized output differs from raw input
  [PASS] Password value not present in output
  [PASS] Output contains [REDACTED] placeholder
...
All tests passed.
```

Exit code `0` means all tests passed. Exit code `1` means one or more assertions
failed – check the `[FAIL]` lines in the output for details.

---

## Security Notes

* **No real secrets** are stored in this repository. All sensitive values
  (webhook URLs, SMTP credentials, API keys) must be injected at runtime via
  environment variables or secure secret management.
* Remediation is disabled by default; enabling it without VM testing could cause
  unintended file operations.
* Reviewers must verify that the quarantine volume is encrypted before enabling
  `Move-ToEncryptedQuarantine` in production.
