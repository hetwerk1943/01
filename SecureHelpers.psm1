# SecureHelpers.psm1
# Secure helper functions for UltraSecurityMonitor.
# Import this module from UltraSecurityMonitor.ps1 before using any of the functions below.

#Requires -Version 5.1

# --------- MODULE-LEVEL GLOBALS ---------
$Global:VT_CacheFile      = Join-Path $PSScriptRoot "vt_cache.json"
$Global:VT_CacheTTL_Min   = 60
$Global:EnableDryRun      = $true
$Global:EnableRemediation = $false

# Discord messages must stay under 2000 chars; use 1900 to leave headroom.
$Script:MaxDiscordMsgLength = 1900

# --------- INTERNAL HELPER ---------
function Write-Log {
    # Forward to the host session's Write-Log if available; otherwise Write-Verbose.
    param([string]$msg)
    if (Get-Command 'Write-Log' -CommandType Function -ErrorAction SilentlyContinue) {
        & (Get-Command 'Write-Log' -CommandType Function) $msg
    } else {
        Write-Verbose "[SecureHelpers] $msg"
    }
}

# --------- EXPORTED FUNCTIONS ---------

function Sanitize-CommandLine {
    <#
    .SYNOPSIS
        Returns the executable name plus a redacted args marker with an 8-char hash.
    .DESCRIPTION
        Prevents raw arguments (which may contain passwords, PII, etc.) from appearing
        in external alert messages while still allowing correlation via the short hash.
    #>
    [CmdletBinding()]
    param(
        [string]$CommandLine
    )

    if ([string]::IsNullOrWhiteSpace($CommandLine)) { return "<empty>" }

    # Split off the executable token (handles quoted paths)
    if ($CommandLine -match '^"([^"]+)"(.*)$') {
        $exe  = [System.IO.Path]::GetFileName($Matches[1])
        $args = $Matches[2].Trim()
    } elseif ($CommandLine -match '^(\S+)(.*)$') {
        $exe  = [System.IO.Path]::GetFileName($Matches[1])
        $args = $Matches[2].Trim()
    } else {
        $exe  = $CommandLine
        $args = ""
    }

    if ([string]::IsNullOrWhiteSpace($args)) {
        return $exe
    }

    # 8-character correlation hash derived from the full command line
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($CommandLine)
    $sha   = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashHex = ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join ""
    } finally {
        $sha.Dispose()
    }
    $short = $hashHex.Substring(0, 8)

    return "$exe [args redacted, corr=$short]"
}

function Get-SecretSafe {
    <#
    .SYNOPSIS
        Retrieves a secret from Microsoft.PowerShell.SecretManagement or an env variable.
    .PARAMETER Name
        Name of the secret in the vault.
    .PARAMETER EnvVarName
        Fallback environment variable name.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$EnvVarName
    )

    # Try SecretManagement first
    if (Get-Module -ListAvailable -Name "Microsoft.PowerShell.SecretManagement" -ErrorAction SilentlyContinue) {
        try {
            Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction SilentlyContinue
            $secret = Get-Secret -Name $Name -AsPlainText -ErrorAction SilentlyContinue
            if (-not [string]::IsNullOrWhiteSpace($secret)) { return $secret }
        } catch {}
    }

    # Fallback: environment variable
    $envVal = [System.Environment]::GetEnvironmentVariable($EnvVarName)
    if (-not [string]::IsNullOrWhiteSpace($envVal)) { return $envVal }

    return $null
}

function Get-VirusTotalReportCached {
    <#
    .SYNOPSIS
        Queries VirusTotal for a file hash, using a local JSON cache to avoid repeat lookups.
    .PARAMETER Hash
        SHA-256 hash of the file.
    .PARAMETER CacheTTL_Min
        Cache time-to-live in minutes (default: $Global:VT_CacheTTL_Min).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Hash,
        [int]$CacheTTL_Min = 0
    )

    if ([string]::IsNullOrWhiteSpace($Hash)) { return $null }

    $ttl = if ($CacheTTL_Min -gt 0) { $CacheTTL_Min } else { $Global:VT_CacheTTL_Min }

    # Load existing cache
    $cache = @{}
    if (Test-Path $Global:VT_CacheFile) {
        try {
            $raw = Get-Content $Global:VT_CacheFile -Raw -ErrorAction SilentlyContinue
            if (-not [string]::IsNullOrWhiteSpace($raw)) {
                $loaded = $raw | ConvertFrom-Json
                # ConvertFrom-Json returns PSCustomObject; convert to hashtable
                $loaded.PSObject.Properties | ForEach-Object { $cache[$_.Name] = $_.Value }
            }
        } catch {}
    }

    # Check cache hit
    if ($cache.ContainsKey($Hash)) {
        $entry = $cache[$Hash]
        try {
            $cachedAt = [datetime]$entry.cachedAt
            if ((Get-Date) -lt $cachedAt.AddMinutes($ttl)) {
                return [PSCustomObject]@{
                    Malicious  = $entry.Malicious
                    Suspicious = $entry.Suspicious
                    Undetected = $entry.Undetected
                    Harmless   = $entry.Harmless
                }
            }
        } catch {}
    }

    # Fetch from VirusTotal
    $apiKey = Get-SecretSafe -Name "VirusTotalApiKey" -EnvVarName "VT_API_KEY"
    if ([string]::IsNullOrWhiteSpace($apiKey)) { return $null }

    try {
        $uri     = "https://www.virustotal.com/api/v3/files/$Hash"
        $headers = @{ "x-apikey" = $apiKey }
        $resp    = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get `
                       -TimeoutSec 15 -ErrorAction SilentlyContinue
        $stats   = $resp.data.attributes.last_analysis_stats
        if ($null -eq $stats) { return $null }

        $result = [PSCustomObject]@{
            Malicious  = $stats.malicious
            Suspicious = $stats.suspicious
            Undetected = $stats.undetected
            Harmless   = $stats.harmless
        }

        # Store in cache
        $cache[$Hash] = @{
            cachedAt   = (Get-Date).ToString("o")
            Malicious  = $result.Malicious
            Suspicious = $result.Suspicious
            Undetected = $result.Undetected
            Harmless   = $result.Harmless
        }
        try {
            $cache | ConvertTo-Json -Depth 5 | Set-Content -Path $Global:VT_CacheFile -Encoding UTF8 -Force
            # Restrict cache file ACLs to prevent unauthorized access to hash/detection data.
            # See SECURITY-HARDENING.md for ACL guidance.
        } catch {}

        return $result
    } catch { return $null }
}

function Build-AlertSummary {
    <#
    .SYNOPSIS
        Builds a hashtable summary for a suspicious process, sanitizing the command line.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Owner,
        [string]$Sig,
        [string]$Hash,
        [string]$CommandLine
    )

    return @{
        timestamp = (Get-Date).ToString("o")
        host      = $env:COMPUTERNAME
        name      = $Name
        owner     = $Owner
        sig       = $Sig
        hash      = $Hash
        cmd       = Sanitize-CommandLine -CommandLine $CommandLine
    }
}

function Send-DiscordAlertSafe {
    <#
    .SYNOPSIS
        Sends a redacted summary to a Discord webhook.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Summary,
        [Parameter(Mandatory)][AllowEmptyString()][string]$WebhookUrl
    )

    if ([string]::IsNullOrWhiteSpace($WebhookUrl)) { return }

    $msg = @"
⚠️ SUSPECT PROCESS
Host:  $($Summary.host)
Name:  $($Summary.name)
Owner: $($Summary.owner)
Sig:   $($Summary.sig)
SHA256: $($Summary.hash)
Cmd:   $($Summary.cmd)
Time:  $($Summary.timestamp)
"@

    # Cap at $Script:MaxDiscordMsgLength chars to stay safely under Discord's 2000-char limit
    if ($msg.Length -gt $Script:MaxDiscordMsgLength) { $msg = $msg.Substring(0, $Script:MaxDiscordMsgLength - 3) + "..." }

    $payload = @{ content = $msg } | ConvertTo-Json
    try {
        Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $payload `
            -ContentType "application/json" -TimeoutSec 10 -ErrorAction SilentlyContinue
    } catch {}
}

function Send-EmailAlertSafe {
    <#
    .SYNOPSIS
        Sends a redacted summary via SMTP. The body contains the sanitized command, not raw args.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Summary,
        [Parameter(Mandatory)][string]$SmtpServer,
        [Parameter(Mandatory)][string]$From,
        [Parameter(Mandatory)][string]$To,
        [int]$Port    = 587,
        [bool]$UseSsl = $true
    )

    if ([string]::IsNullOrWhiteSpace($SmtpServer) -or
        [string]::IsNullOrWhiteSpace($From)       -or
        [string]::IsNullOrWhiteSpace($To)) { return }

    $body = @"
Suspicious Process Detected

Host:   $($Summary.host)
Name:   $($Summary.name)
Owner:  $($Summary.owner)
Sig:    $($Summary.sig)
SHA256: $($Summary.hash)
Cmd:    $($Summary.cmd)
Time:   $($Summary.timestamp)
"@

    try {
        $params = @{
            To         = $To
            From       = $From
            Subject    = "Suspicious Process Alert: $($Summary.name) on $($Summary.host)"
            Body       = $body
            SmtpServer = $SmtpServer
            Port       = $Port
            UseSsl     = $UseSsl
        }
        Send-MailMessage @params -ErrorAction SilentlyContinue
    } catch {}
}

function Execute-RemediationSafe {
    <#
    .SYNOPSIS
        Executes a remediation ScriptBlock only when dry-run is off and remediation is enabled.
    .PARAMETER Action
        The ScriptBlock to execute.
    .PARAMETER Reason
        Human-readable description logged to the audit trail.
    .OUTPUTS
        [bool] $true on successful execution, $false otherwise.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][scriptblock]$Action,
        [Parameter(Mandatory)][string]$Reason
    )

    if ($Global:EnableDryRun) {
        Write-Log "[DRY-RUN] Remediation skipped (EnableDryRun=true): $Reason"
        return $false
    }

    if (-not $Global:EnableRemediation) {
        Write-Log "[REMEDIATION DISABLED] Skipped: $Reason"
        return $false
    }

    try {
        & $Action
        Write-Log "[AUDIT] Remediation executed: $Reason"
        return $true
    } catch {
        Write-Log "[AUDIT] Remediation failed: $Reason — $_"
        return $false
    }
}

Export-ModuleMember -Function @(
    'Sanitize-CommandLine',
    'Get-SecretSafe',
    'Get-VirusTotalReportCached',
    'Build-AlertSummary',
    'Send-DiscordAlertSafe',
    'Send-EmailAlertSafe',
    'Execute-RemediationSafe'
)
