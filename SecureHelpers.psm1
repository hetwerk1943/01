# SecureHelpers.psm1
# Helper module for UltraSecurityMonitor – hardened alert, sanitisation, and safe remediation.
#
# IMPORTANT: Remediation is DISABLED by default. Do NOT enable remediation
#            without first testing in an isolated VM and completing a manual review.
#            All changes must be validated via dry-run mode before production use.

#Requires -Version 5.1

# ---- Module-level configuration ----
# Use Set-SecureHelpersConfig to change these from outside the module:
#   Set-SecureHelpersConfig -EnableDryRun $false -EnableRemediation $true
$Script:EnableDryRun      = $true   # dry-run by default – no destructive actions
$Script:EnableRemediation = $false  # remediation disabled by default

# Cross-platform home directory fallback (Linux uses $env:HOME; Windows $env:USERPROFILE)
$Script:_HomeDir     = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }
$Script:BackupFolder = Join-Path $Script:_HomeDir "Documents/SecurityMonitor/Backup"
$Script:VtCachePath  = Join-Path $Script:_HomeDir "Documents/SecurityMonitor/vt_cache.json"

# ---- Redaction patterns ----
# Patterns that might indicate sensitive data in command-line strings.
$Script:RedactPatterns = @(
    # --password / -p / /password followed by a value
    '(?i)(--?password\s+)\S+',
    '(?i)(/password[: =])\S+',
    # --token / --secret / --key followed by a value
    '(?i)(--?(token|secret|key|apikey|api[-_]?key)\s+)\S+',
    '(?i)(--?(token|secret|key|apikey|api[-_]?key)[=:])\S+',
    # Basic Auth-style user:password@host
    '(?i)://[^:@/\s]+:[^@/\s]+@',
    # Base64-looking long strings that are often credentials (>=20 chars of b64 chars)
    '(?i)(bearer\s+)[A-Za-z0-9+/=]{20,}'
)

# ---- Sanitize-CommandLine ----
# Redacts sensitive-looking arguments from a command-line string.
# Returns the redacted string. Original value is never modified.
function Sanitize-CommandLine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandLine
    )
    $sanitized = $CommandLine
    foreach ($pattern in $Script:RedactPatterns) {
        $sanitized = [regex]::Replace($sanitized, $pattern, {
            param($m)
            # Keep the flag/prefix, replace the value with [REDACTED]
            $full  = $m.Value
            $inner = $m.Groups[1].Value
            if ($inner) { return "$inner[REDACTED]" }
            # For URL patterns replace credentials segment
            return $full -replace '://[^:@/\s]+:[^@/\s]+@', '://[REDACTED]@'
        })
    }
    return $sanitized
}

# ---- Build-AlertSummary ----
# Builds a sanitised alert summary hashtable from process details.
function Build-AlertSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProcessName,
        [string]$FilePath    = '',
        [string]$CommandLine = '',
        [string]$Owner       = '',
        [string]$Hash        = '',
        [string]$SigStatus   = '',
        [string]$Severity    = 'High'
    )
    return [ordered]@{
        ProcessName = $ProcessName
        FilePath    = $FilePath
        CommandLine = Sanitize-CommandLine -CommandLine $CommandLine
        Owner       = $Owner
        Hash        = $Hash
        SigStatus   = $SigStatus
        Severity    = $Severity
        Timestamp   = (Get-Date).ToString('o')
        DryRun      = $Script:EnableDryRun
    }
}

# ---- Execute-RemediationSafe ----
# Executes a remediation ScriptBlock only when remediation is enabled AND
# dry-run mode is disabled.  Logs the action regardless.
#
# USAGE EXAMPLE (do NOT use in production without VM testing):
#   Execute-RemediationSafe -Description "Quarantine malware" -Action {
#       Move-ToEncryptedQuarantine -FilePath $suspiciousPath
#   }
function Execute-RemediationSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Description,
        [Parameter(Mandatory)]
        [scriptblock]$Action
    )
    if ($Script:EnableDryRun) {
        Write-Host "[DRY-RUN] Remediation skipped: $Description"
        return
    }
    if (-not $Script:EnableRemediation) {
        Write-Host "[REMEDIATION DISABLED] Skipped: $Description"
        return
    }
    Write-Host "[REMEDIATION] Executing: $Description"
    try {
        & $Action
    } catch {
        Write-Warning "[REMEDIATION ERROR] $Description : $_"
    }
}

# ---- Send-DiscordAlertSafe ----
# Sends a Discord webhook alert only when a webhook URL is configured AND
# dry-run mode is disabled.  In dry-run the message is written to stdout.
function Send-DiscordAlertSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [string]$WebhookUrl = ''
    )
    $truncated = if ($Message.Length -gt 2000) { $Message.Substring(0, 1997) + '...' } else { $Message }
    if ($Script:EnableDryRun) {
        Write-Host "[DRY-RUN] Discord alert (not sent): $truncated"
        return
    }
    if ([string]::IsNullOrWhiteSpace($WebhookUrl)) {
        Write-Verbose 'Discord webhook URL not configured – alert suppressed.'
        return
    }
    $payload = @{ content = $truncated } | ConvertTo-Json
    try {
        Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $payload `
            -ContentType 'application/json' -TimeoutSec 10 -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "Discord alert failed: $_"
    }
}

# ---- Send-EmailAlertSafe ----
# Sends an e-mail alert only when SMTP is configured AND dry-run is disabled.
# In dry-run the subject/body are written to stdout.
function Send-EmailAlertSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Subject,
        [Parameter(Mandatory)]
        [string]$Body,
        [string]$SmtpServer = '',
        [string]$SmtpFrom   = '',
        [string]$SmtpTo     = '',
        [int]$SmtpPort      = 587,
        [bool]$SmtpUseSsl   = $true
    )
    if ($Script:EnableDryRun) {
        Write-Host "[DRY-RUN] Email alert (not sent): Subject=$Subject"
        Write-Host "[DRY-RUN] Body: $Body"
        return
    }
    if ([string]::IsNullOrWhiteSpace($SmtpServer) -or
        [string]::IsNullOrWhiteSpace($SmtpFrom)   -or
        [string]::IsNullOrWhiteSpace($SmtpTo)) {
        Write-Verbose 'SMTP not configured – email alert suppressed.'
        return
    }
    try {
        Send-MailMessage -To $SmtpTo -From $SmtpFrom -Subject $Subject -Body $Body `
            -SmtpServer $SmtpServer -Port $SmtpPort -UseSsl:$SmtpUseSsl `
            -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "Email alert failed: $_"
    }
}

# ===========================================================================
# EXAMPLE SAFE REMEDIATION FUNCTION
# ===========================================================================
# Move-ToEncryptedQuarantine
# ---------------------------
# Moves a suspicious file to an encrypted quarantine folder under
# $BackupFolder\Quarantine.  The file is COPIED (not deleted) so the original
# can be reviewed.  Access is restricted to the service account via ACL.
#
# INSTRUCTIONS BEFORE ENABLING:
#   1. Test in an isolated VM with EnableDryRun = $false and EnableRemediation = $true.
#   2. Confirm the quarantine folder is on an encrypted volume (BitLocker/EFS).
#   3. Replace <SERVICE_ACCOUNT> with the actual account running the monitor.
#   4. Only wrap calls to this function inside Execute-RemediationSafe.
#
# EXAMPLE CALL (do NOT run in production without manual review and VM testing):
#
#   Execute-RemediationSafe -Description "Quarantine $suspiciousFile" -Action {
#       Move-ToEncryptedQuarantine -FilePath $suspiciousFile
#   }
# ===========================================================================
function Move-ToEncryptedQuarantine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        # Service account that should have exclusive access to the quarantine folder.
        # Defaults to the current user for testing; override for production.
        [string]$ServiceAccount = $env:USERNAME
    )

    # --- Dry-run / safety gate ---
    if ($Script:EnableDryRun) {
        Write-Host "[DRY-RUN] Move-ToEncryptedQuarantine: would quarantine '$FilePath'"
        return
    }
    if (-not $Script:EnableRemediation) {
        Write-Host "[REMEDIATION DISABLED] Quarantine skipped for '$FilePath'"
        return
    }

    # --- Validate source file ---
    if (-not (Test-Path -LiteralPath $FilePath)) {
        Write-Warning "Move-ToEncryptedQuarantine: source file not found: $FilePath"
        return
    }

    # --- Ensure quarantine folder exists ---
    $quarantineFolder = Join-Path $Script:BackupFolder 'Quarantine'
    if (-not (Test-Path $quarantineFolder)) {
        New-Item -Path $quarantineFolder -ItemType Directory -Force | Out-Null
        Write-Host "[QUARANTINE] Created quarantine folder: $quarantineFolder"
    }

    # --- Copy file to quarantine (never Delete the original directly) ---
    $leafName = Split-Path $FilePath -Leaf
    $destName = "${leafName}_$(Get-Date -Format 'yyyyMMdd-HHmmss').quarantine"
    $destPath = Join-Path $quarantineFolder $destName

    try {
        Copy-Item -LiteralPath $FilePath -Destination $destPath -Force -ErrorAction Stop
        Write-Host "[QUARANTINE] Copied '$FilePath' -> '$destPath'"
    } catch {
        Write-Warning "[QUARANTINE ERROR] Copy failed for '$FilePath': $_"
        return
    }

    # --- Restrict ACL: grant access only to service account ---
    try {
        $acl        = New-Object System.Security.AccessControl.FileSecurity
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $ServiceAccount,
            [System.Security.AccessControl.FileSystemRights]::FullControl,
            [System.Security.AccessControl.InheritanceFlags]::None,
            [System.Security.AccessControl.PropagationFlags]::None,
            [System.Security.AccessControl.AccessControlType]::Allow
        )
        $acl.SetAccessRuleProtection($true, $false)   # disable inheritance, remove inherited
        $acl.AddAccessRule($accessRule)
        Set-Acl -LiteralPath $destPath -AclObject $acl -ErrorAction SilentlyContinue
        Write-Host "[QUARANTINE] ACL restricted to '$ServiceAccount' on '$destPath'"
    } catch {
        Write-Warning "[QUARANTINE ACL ERROR] Could not set ACL on '$destPath': $_"
    }

    # --- Log the action ---
    $logMsg = "$(Get-Date -Format 'o')`tQUARANTINED '$FilePath' -> '$destPath' (ServiceAccount=$ServiceAccount)"
    $logPath = Join-Path $Script:BackupFolder 'quarantine.log'
    try {
        Add-Content -Path $logPath -Value $logMsg -ErrorAction SilentlyContinue
    } catch {}
    Write-Host "[QUARANTINE] $logMsg"
}

# ---- Set-SecureHelpersConfig ----
# Call this after Import-Module to override module-level settings.
# Especially useful in tests and CI pipelines.
function Set-SecureHelpersConfig {
    [CmdletBinding()]
    param(
        [System.Nullable[bool]]$EnableDryRun,
        [System.Nullable[bool]]$EnableRemediation,
        [string]$BackupFolder,
        [string]$VtCachePath
    )
    if ($null -ne $EnableDryRun)      { $Script:EnableDryRun      = $EnableDryRun }
    if ($null -ne $EnableRemediation) { $Script:EnableRemediation = $EnableRemediation }
    if ($BackupFolder)                { $Script:BackupFolder       = $BackupFolder }
    if ($VtCachePath)                 { $Script:VtCachePath        = $VtCachePath }
}

Export-ModuleMember -Function @(
    'Set-SecureHelpersConfig',
    'Sanitize-CommandLine',
    'Build-AlertSummary',
    'Execute-RemediationSafe',
    'Send-DiscordAlertSafe',
    'Send-EmailAlertSafe',
    'Move-ToEncryptedQuarantine'
)
