# SecureHelpers.psm1
# Secure helper functions for UltraSecurityMonitor.
# Provides sanitization, secret retrieval, VT caching, safe alerting and safe remediation.

# --------- MODULE GLOBALS ---------
if (-not (Get-Variable -Name VT_CacheFile -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:VT_CacheFile    = Join-Path $PSScriptRoot 'vt_cache.json'
}
if (-not (Get-Variable -Name VT_CacheTTL_Min -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:VT_CacheTTL_Min = 60
}
if (-not (Get-Variable -Name EnableDryRun -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:EnableDryRun    = $true
}
if (-not (Get-Variable -Name EnableRemediation -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:EnableRemediation = $false
}

# --------- SANITIZE-COMMANDLINE ---------
function Sanitize-CommandLine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()][AllowEmptyString()]
        [string]$CommandLine
    )
    if ([string]::IsNullOrWhiteSpace($CommandLine)) {
        return '[EMPTY]'
    }
    # Split on first whitespace to separate executable from arguments
    $firstSpace = $CommandLine.IndexOf(' ')
    if ($firstSpace -lt 0) {
        # No arguments present
        return $CommandLine
    }
    $exe  = $CommandLine.Substring(0, $firstSpace)
    $args = $CommandLine.Substring($firstSpace + 1)
    # Hash the args without storing them
    $sha256  = [System.Security.Cryptography.SHA256]::Create()
    $bytes   = [System.Text.Encoding]::UTF8.GetBytes($args)
    $hashBytes = $sha256.ComputeHash($bytes)
    $sha256.Dispose()
    $hexHash = ($hashBytes | ForEach-Object { $_.ToString('x2') }) -join ''
    $short   = $hexHash.Substring(0, [Math]::Min(8, $hexHash.Length))
    return "$exe [REDACTED_ARGS:$short]"
}

# --------- GET-SECRETSAFE ---------
function Get-SecretSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$EnvVarName
    )
    # Try Microsoft.PowerShell.SecretManagement first
    try {
        $secret = Get-Secret -Name $Name -ErrorAction Stop
        if ($null -ne $secret) {
            # SecretManagement may return a SecureString; convert to plain text
            if ($secret -is [System.Security.SecureString]) {
                $ptr    = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
                $plain  = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
                return $plain
            }
            return $secret.ToString()
        }
    } catch {}
    # Fall back to environment variable
    $envVal = [System.Environment]::GetEnvironmentVariable($EnvVarName)
    if (-not [string]::IsNullOrWhiteSpace($envVal)) {
        return $envVal
    }
    return $null
}

# --------- GET-VIRUSTOTALREPORTCACHED ---------
function Get-VirusTotalReportCached {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Hash,
        [int]$CacheTTL_Min = $Global:VT_CacheTTL_Min
    )
    if ([string]::IsNullOrWhiteSpace($Hash)) { return $null }

    $cacheFile = $Global:VT_CacheFile
    $cache     = @{}

    # Load existing cache
    if (Test-Path $cacheFile) {
        try {
            $raw = Get-Content -Path $cacheFile -Raw -ErrorAction Stop
            $loaded = $raw | ConvertFrom-Json -ErrorAction Stop
            # Convert PSCustomObject to hashtable
            $loaded.PSObject.Properties | ForEach-Object { $cache[$_.Name] = $_.Value }
        } catch {}
    }

    $now = Get-Date

    # Return cached entry if still within TTL
    if ($cache.ContainsKey($Hash)) {
        try {
            $entry     = $cache[$Hash]
            $cached_ts = [datetime]$entry.timestamp
            if (($now - $cached_ts).TotalMinutes -lt $CacheTTL_Min) {
                return [PSCustomObject]@{
                    Malicious  = $entry.Malicious
                    Suspicious = $entry.Suspicious
                    Undetected = $entry.Undetected
                    Harmless   = $entry.Harmless
                }
            }
        } catch {}
    }

    # Retrieve API key
    $apiKey = Get-SecretSafe -Name 'VirusTotalApiKey' -EnvVarName 'VT_API_KEY'
    if ([string]::IsNullOrWhiteSpace($apiKey)) { return $null }

    # Query VirusTotal API v3
    try {
        $uri     = "https://www.virustotal.com/api/v3/files/$Hash"
        $headers = @{ 'x-apikey' = $apiKey }
        $resp    = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get `
                       -TimeoutSec 15 -ErrorAction Stop
        $stats   = $resp.data.attributes.last_analysis_stats
        if ($null -eq $stats) { return $null }

        $result = [PSCustomObject]@{
            Malicious  = $stats.malicious
            Suspicious = $stats.suspicious
            Undetected = $stats.undetected
            Harmless   = $stats.harmless
        }

        # Update cache
        $cache[$Hash] = @{
            timestamp  = $now.ToString('o')
            Malicious  = $result.Malicious
            Suspicious = $result.Suspicious
            Undetected = $result.Undetected
            Harmless   = $result.Harmless
        }
        try {
            $cache | ConvertTo-Json -Depth 5 | Set-Content -Path $cacheFile -Encoding UTF8 -ErrorAction Stop
        } catch {}

        return $result
    } catch { return $null }
}

# --------- BUILD-ALERTSUMMARY ---------
function Build-AlertSummary {
    [CmdletBinding()]
    param(
        [string]$ProcessName,
        [string]$Hash,
        [string]$HostName,
        [string]$Owner,
        [string]$SigStatus,
        [AllowNull()][AllowEmptyString()]
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
    [CmdletBinding()]
    param(
        [hashtable]$Summary,
        [string]$WebhookUrl
    )
    if ([string]::IsNullOrWhiteSpace($WebhookUrl)) { return }
    try {
        $msg = "⚠️ SUSPICIOUS PROCESS`n" +
               "Host:  $($Summary.host)`n" +
               "Name:  $($Summary.name)`n" +
               "Owner: $($Summary.owner)`n" +
               "Sig:   $($Summary.sig)`n" +
               "Hash:  $($Summary.hash)`n" +
               "Cmd:   $($Summary.cmd)`n" +
               "Time:  $($Summary.timestamp)"
        if ($Summary.ContainsKey('vt_malicious')) {
            $msg += "`nVT:    Malicious=$($Summary.vt_malicious) Suspicious=$($Summary.vt_suspicious)"
        }
        # Limit to ~1900 chars
        if ($msg.Length -gt 1900) { $msg = $msg.Substring(0, 1897) + '...' }
        $payload = @{ content = $msg } | ConvertTo-Json
        Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $payload `
            -ContentType 'application/json' -TimeoutSec 10 -ErrorAction Stop
    } catch {}
}

# --------- SEND-EMAILALERTSAFE ---------
function Send-EmailAlertSafe {
    [CmdletBinding()]
    param(
        [hashtable]$Summary,
        [string]$SmtpServer,
        [string]$From,
        [string]$To,
        [int]$Port       = 587,
        [bool]$UseSsl    = $true
    )
    if ([string]::IsNullOrWhiteSpace($SmtpServer) -or
        [string]::IsNullOrWhiteSpace($From)        -or
        [string]::IsNullOrWhiteSpace($To)) { return }
    try {
        $subject = "Suspicious Process Alert: $($Summary.name) on $($Summary.host)"
        $body    = "Time:  $($Summary.timestamp)`n" +
                   "Host:  $($Summary.host)`n" +
                   "Name:  $($Summary.name)`n" +
                   "Owner: $($Summary.owner)`n" +
                   "Sig:   $($Summary.sig)`n" +
                   "Hash:  $($Summary.hash)`n" +
                   "Cmd:   $($Summary.cmd)"
        if ($Summary.ContainsKey('vt_malicious')) {
            $body += "`nVT:    Malicious=$($Summary.vt_malicious) Suspicious=$($Summary.vt_suspicious)"
        }
        $params = @{
            To         = $To
            From       = $From
            Subject    = $subject
            Body       = $body
            SmtpServer = $SmtpServer
            Port       = $Port
            UseSsl     = $UseSsl
        }
        Send-MailMessage @params -ErrorAction Stop
    } catch {}
}

# --------- EXECUTE-REMEDIATIONSAFE ---------
function Execute-RemediationSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ActionScriptBlock,
        [string]$Reason = ''
    )
    if ($Global:EnableDryRun -or (-not $Global:EnableRemediation)) {
        $logMsg = "Execute-RemediationSafe: DRY-RUN (no action taken). Reason: $Reason"
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log $logMsg
        } else {
            Write-Host $logMsg
        }
        return $false
    }
    try {
        & $ActionScriptBlock
        $logMsg = "Execute-RemediationSafe: Action executed. Reason: $Reason"
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log $logMsg
        } else {
            Write-Host $logMsg
        }
        return $true
    } catch {
        $errMsg = "Execute-RemediationSafe: Action failed. Reason: $Reason. Error: $_"
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log $errMsg
        } else {
            Write-Host $errMsg
        }
        return $false
    }
}

Export-ModuleMember -Function Sanitize-CommandLine, Get-SecretSafe, Get-VirusTotalReportCached,
                               Build-AlertSummary, Send-DiscordAlertSafe, Send-EmailAlertSafe,
                               Execute-RemediationSafe
