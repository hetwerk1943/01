# SecureHelpers.psm1
# Hardening helpers for UltraSecurityMonitor: safe alerting, VT caching,
# secret handling, and gated remediation.

# --------- MODULE GLOBALS ---------
$Global:VT_CacheFile      = Join-Path $PSScriptRoot 'vt_cache.json'
$Global:VT_CacheTTL_Min   = 1440
$Global:EnableDryRun      = $true
$Global:EnableRemediation = $false

# --------- SANITIZE-COMMANDLINE ---------
function Sanitize-CommandLine {
    <#
    .SYNOPSIS
        Returns the executable name and a redacted args marker.
        Raw arguments are never stored; only the first 8 hex chars of
        SHA256(args) are retained for correlation.
    #>
    param([string]$CommandLine)

    if ([string]::IsNullOrWhiteSpace($CommandLine)) { return '[EMPTY_CMD]' }

    # Split exe from args (handles quoted exe paths)
    $exe  = $null
    $args = $null
    if ($CommandLine -match '^"([^"]+)"\s*(.*)$') {
        $exe  = Split-Path -Leaf $Matches[1]
        $args = $Matches[2]
    } elseif ($CommandLine -match '^(\S+)\s*(.*)$') {
        $exe  = Split-Path -Leaf $Matches[1]
        $args = $Matches[2]
    } else {
        $exe  = $CommandLine
        $args = ''
    }

    if ([string]::IsNullOrWhiteSpace($args)) {
        return $exe
    }

    # Hash args – keep only first 8 hex chars
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $bytes  = [System.Text.Encoding]::UTF8.GetBytes($args)
    $hash   = ($sha256.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join ''
    $sha256.Dispose()
    $shortHash = $hash.Substring(0, 8)

    return "$exe [REDACTED_ARGS:$shortHash]"
}

# --------- GET-SECRETSAFE ---------
function Get-SecretSafe {
    <#
    .SYNOPSIS
        Retrieve a secret via Microsoft.PowerShell.SecretManagement,
        falling back to an environment variable.
    #>
    param(
        [string]$Name,
        [string]$EnvVarName
    )

    # Try SecretManagement if available
    if (Get-Command Get-Secret -ErrorAction SilentlyContinue) {
        try {
            $secret = Get-Secret -Name $Name -ErrorAction SilentlyContinue
            if ($null -ne $secret) {
                # SecretManagement returns SecureString or plain object
                if ($secret -is [System.Security.SecureString]) {
                    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
                    try { return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) }
                    finally { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
                }
                return $secret
            }
        } catch {}
    }

    # Fall back to environment variable
    $envVal = [System.Environment]::GetEnvironmentVariable($EnvVarName)
    if (-not [string]::IsNullOrWhiteSpace($envVal)) { return $envVal }

    return $null
}

# --------- GET-VIRUSTOTALREPORTCACHED ---------
function Get-VirusTotalReportCached {
    <#
    .SYNOPSIS
        Query VirusTotal v3 with a local JSON cache.
        Default TTL = 1440 minutes (24 h).
    #>
    param(
        [string]$Hash,
        [int]$CacheTTL_Min = $Global:VT_CacheTTL_Min
    )

    if ([string]::IsNullOrWhiteSpace($Hash)) { return $null }

    # Load or init cache
    $cache = @{}
    if (Test-Path $Global:VT_CacheFile) {
        try {
            $raw   = Get-Content $Global:VT_CacheFile -Raw -ErrorAction SilentlyContinue
            $cache = $raw | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($null -eq $cache) { $cache = @{} }
            # Convert PSCustomObject back to hashtable
            $ht = @{}
            $cache.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }
            $cache = $ht
        } catch { $cache = @{} }
    }

    # Check cache hit
    if ($cache.ContainsKey($Hash)) {
        $entry = $cache[$Hash]
        $ts    = [datetime]::Parse($entry.timestamp)
        if (([datetime]::UtcNow - $ts).TotalMinutes -lt $CacheTTL_Min) {
            return [PSCustomObject]@{
                Malicious  = $entry.Malicious
                Suspicious = $entry.Suspicious
                Undetected = $entry.Undetected
                Harmless   = $entry.Harmless
            }
        }
    }

    # Need API key
    $apiKey = Get-SecretSafe -Name 'VirusTotalApiKey' -EnvVarName 'VT_API_KEY'
    if ([string]::IsNullOrWhiteSpace($apiKey)) { return $null }

    # Query VT with exponential backoff (3 attempts)
    $uri     = "https://www.virustotal.com/api/v3/files/$Hash"
    $headers = @{ 'x-apikey' = $apiKey }
    $result  = $null

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            $resp   = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get `
                          -TimeoutSec 15 -ErrorAction Stop
            $stats  = $resp.data.attributes.last_analysis_stats
            if ($null -ne $stats) {
                $result = [PSCustomObject]@{
                    Malicious  = $stats.malicious
                    Suspicious = $stats.suspicious
                    Undetected = $stats.undetected
                    Harmless   = $stats.harmless
                }
            }
            break
        } catch {
            if ($attempt -lt 3) {
                Start-Sleep -Seconds ([math]::Pow(2, $attempt))
            }
        }
    }

    if ($null -ne $result) {
        # Write cache
        $cache[$Hash] = @{
            timestamp  = [datetime]::UtcNow.ToString('o')
            Malicious  = $result.Malicious
            Suspicious = $result.Suspicious
            Undetected = $result.Undetected
            Harmless   = $result.Harmless
        }
        try { $cache | ConvertTo-Json -Depth 5 | Set-Content $Global:VT_CacheFile -Encoding UTF8 } catch {}
    }

    return $result
}

# --------- BUILD-ALERTSUMMARY ---------
function Build-AlertSummary {
    <#
    .SYNOPSIS
        Build a sanitized alert summary hashtable. Raw command line is never stored.
    #>
    param(
        [string]$ProcessName,
        [string]$Hash,
        [string]$HostName,
        [string]$Owner,
        [string]$SigStatus,
        [string]$CmdLine
    )

    return @{
        timestamp = (Get-Date).ToString('o')
        host      = $HostName
        name      = $ProcessName
        owner     = $Owner
        sig       = $SigStatus
        hash      = $Hash
        cmd       = Sanitize-CommandLine -CommandLine $CmdLine
    }
}

# --------- SEND-DISCORDALERTSAFE ---------
function Send-DiscordAlertSafe {
    <#
    .SYNOPSIS
        Send a redacted Discord alert. Only safe fields are included.
        Message is capped at 2000 chars. Errors are silently handled.
    #>
    param(
        [hashtable]$Summary,
        [string]$WebhookUrl
    )

    if ([string]::IsNullOrWhiteSpace($WebhookUrl)) { return }

    $msg = "⚠️ SUSPICIOUS PROCESS`n" +
           "Time:  $($Summary.timestamp)`n" +
           "Host:  $($Summary.host)`n" +
           "Name:  $($Summary.name)`n" +
           "Owner: $($Summary.owner)`n" +
           "Sig:   $($Summary.sig)`n" +
           "Hash:  $($Summary.hash)`n" +
           "Cmd:   $($Summary.cmd)"

    # Enforce 2000-char limit
    if ($msg.Length -gt 2000) { $msg = $msg.Substring(0, 1997) + '...' }

    $payload = @{ content = $msg } | ConvertTo-Json

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $payload `
                -ContentType 'application/json' -TimeoutSec 10 -ErrorAction Stop
            break
        } catch {
            if ($attempt -lt 3) { Start-Sleep -Seconds ([math]::Pow(2, $attempt)) }
        }
    }
}

# --------- SEND-EMAILALERTSAFE ---------
function Send-EmailAlertSafe {
    <#
    .SYNOPSIS
        Send a redacted email alert with retry/backoff. Errors are silently handled.
    #>
    param(
        [hashtable]$Summary,
        [string]$SmtpServer,
        [string]$From,
        [string]$To,
        [int]$Port    = 587,
        [bool]$UseSsl = $true
    )

    if ([string]::IsNullOrWhiteSpace($SmtpServer) -or
        [string]::IsNullOrWhiteSpace($From) -or
        [string]::IsNullOrWhiteSpace($To)) { return }

    $subject = "Suspicious Process: $($Summary.name) on $($Summary.host)"
    $body    = "Timestamp: $($Summary.timestamp)`n" +
               "Host:      $($Summary.host)`n" +
               "Process:   $($Summary.name)`n" +
               "Owner:     $($Summary.owner)`n" +
               "Signature: $($Summary.sig)`n" +
               "Hash:      $($Summary.hash)`n" +
               "CmdLine:   $($Summary.cmd)"

    $params = @{
        To         = $To
        From       = $From
        Subject    = $subject
        Body       = $body
        SmtpServer = $SmtpServer
        Port       = $Port
        UseSsl     = $UseSsl
    }

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            Send-MailMessage @params -ErrorAction Stop
            break
        } catch {
            if ($attempt -lt 3) { Start-Sleep -Seconds ([math]::Pow(2, $attempt)) }
        }
    }
}

# --------- EXECUTE-REMEDIATIONSAFE ---------
function Execute-RemediationSafe {
    <#
    .SYNOPSIS
        Gate for all remediation actions.
        Returns $false (no action) when DryRun is enabled or Remediation is disabled.
    #>
    param(
        [scriptblock]$ActionScriptBlock,
        [string]$Reason
    )

    if ($Global:EnableDryRun -eq $true -or $Global:EnableRemediation -ne $true) {
        Write-Verbose "[DryRun] Remediation suppressed: $Reason"
        return $false
    }

    try {
        & $ActionScriptBlock
        Write-Verbose "[Remediation] Executed: $Reason"
        return $true
    } catch {
        Write-Verbose "[Remediation] Error for '$Reason': $_"
        return $false
    }
}

# --------- MOVE-TOENCRYPTEDQUARANTINE ---------
function Move-ToEncryptedQuarantine {
    <#
    .SYNOPSIS
        Copy a file to a restricted quarantine folder.
        Should only be called when Execute-RemediationSafe permits.
        EFS encryption is left as an optional step (commented below).
    #>
    param(
        [string]$FilePath,
        [string]$QuarantineRoot
    )

    if (-not (Test-Path $FilePath)) { return $false }

    try {
        $quarantineDir = Join-Path $QuarantineRoot 'Backup\Quarantine'
        if (-not (Test-Path $quarantineDir)) {
            New-Item -Path $quarantineDir -ItemType Directory -Force | Out-Null
        }

        $leaf = [System.IO.Path]::GetFileName($FilePath)
        $dest = Join-Path $quarantineDir ("${leaf}_" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        Copy-Item -Path $FilePath -Destination $dest -Force -ErrorAction Stop

        # Restrict ACL: owner only
        try {
            $acl    = Get-Acl $dest
            $acl.SetAccessRuleProtection($true, $false)  # disable inheritance
            $rule   = New-Object System.Security.AccessControl.FileSystemAccessRule(
                [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
                'FullControl',
                'Allow'
            )
            $acl.SetAccessRule($rule)
            Set-Acl -Path $dest -AclObject $acl
        } catch {}

        # Optional: EFS encrypt the quarantined file
        # [System.IO.File]::Encrypt($dest)

        return $true
    } catch {
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
    'Execute-RemediationSafe',
    'Move-ToEncryptedQuarantine'
)
