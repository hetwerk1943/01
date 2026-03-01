# SecureHelpers.psm1
# ULTRAMASTER APOCALYPSE hardening helpers.
# Import this module in UltraSecurityMonitor.ps1 and any related scripts.

#Requires -Version 5.1

# --------- GLOBALS ---------
$Global:VT_CacheFile      = Join-Path $PSScriptRoot 'vt_cache.json'
$Global:VT_CacheTTL_Min   = 1440
$Global:EnableDryRun      = $true
$Global:EnableRemediation = $false

# --------- SANITIZE-COMMANDLINE ---------
function Sanitize-CommandLine {
    <#
    .SYNOPSIS
        Returns the executable name with arguments replaced by a short hash token.
    #>
    param([string]$CommandLine)
    if ([string]::IsNullOrWhiteSpace($CommandLine)) { return '' }

    # Split exe from args (handles quoted paths)
    if ($CommandLine -match '^("(?:[^"]+)")\s*(.*)$') {
        $exe  = $Matches[1]
        $args = $Matches[2]
    } elseif ($CommandLine -match '^(\S+)\s+(.+)$') {
        $exe  = $Matches[1]
        $args = $Matches[2]
    } else {
        # No arguments
        return $CommandLine
    }

    if ([string]::IsNullOrWhiteSpace($args)) { return $exe }

    $bytes  = [System.Text.Encoding]::UTF8.GetBytes($args)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $hash   = ($sha256.ComputeHash($bytes) | ForEach-Object { '{0:x2}' -f $_ }) -join ''
    $short  = $hash.Substring(0, 8)

    return "$exe [REDACTED_ARGS:$short]"
}

# --------- GET-SECRETSAFE ---------
function Get-SecretSafe {
    <#
    .SYNOPSIS
        Retrieves a secret via Microsoft.PowerShell.SecretManagement if available,
        falling back to an environment variable.
    #>
    param(
        [string]$Name,
        [string]$EnvVarName
    )
    try {
        if (Get-Command Get-Secret -ErrorAction SilentlyContinue) {
            $secret = Get-Secret -Name $Name -AsPlainText -ErrorAction Stop
            if ($null -ne $secret) { return $secret }
        }
    } catch {}

    # Fall back to environment variable
    $envVal = [System.Environment]::GetEnvironmentVariable($EnvVarName)
    return $envVal
}

# --------- GET-VIRUSTOTALREPORTCACHED ---------
function Get-VirusTotalReportCached {
    <#
    .SYNOPSIS
        Queries VirusTotal API v3 for a file hash with local JSON cache and exponential backoff.
    #>
    param(
        [string]$Hash,
        [int]$CacheTTL_Min = $Global:VT_CacheTTL_Min
    )

    $apiKey = Get-SecretSafe -Name 'VT_API_KEY' -EnvVarName 'VT_API_KEY'
    if ([string]::IsNullOrWhiteSpace($apiKey) -or [string]::IsNullOrWhiteSpace($Hash)) {
        return $null
    }

    # Load cache
    $cache = @{}
    if (Test-Path $Global:VT_CacheFile) {
        try {
            $raw = Get-Content $Global:VT_CacheFile -Raw -ErrorAction SilentlyContinue
            if ($raw) { $cache = $raw | ConvertFrom-Json -AsHashtable -ErrorAction SilentlyContinue }
            if ($null -eq $cache) { $cache = @{} }
        } catch { $cache = @{} }
    }

    # Check TTL
    if ($cache.ContainsKey($Hash)) {
        $entry = $cache[$Hash]
        $cachedAt = [datetime]::Parse($entry.CachedAt)
        if ((Get-Date) -lt $cachedAt.AddMinutes($CacheTTL_Min)) {
            return [PSCustomObject]@{
                Malicious  = $entry.Malicious
                Suspicious = $entry.Suspicious
                Undetected = $entry.Undetected
                Harmless   = $entry.Harmless
            }
        }
    }

    # Fetch from VT with exponential backoff
    $uri     = "https://www.virustotal.com/api/v3/files/$Hash"
    $headers = @{ 'x-apikey' = $apiKey }
    $maxAttempts = 3
    $result  = $null

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            $resp  = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get `
                         -TimeoutSec 15 -ErrorAction Stop
            $stats = $resp.data.attributes.last_analysis_stats
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
            if ($attempt -lt $maxAttempts) {
                $delay = [math]::Pow(2, $attempt)
                Start-Sleep -Seconds $delay
            }
        }
    }

    if ($null -ne $result) {
        # Store in cache
        $cache[$Hash] = @{
            Malicious  = $result.Malicious
            Suspicious = $result.Suspicious
            Undetected = $result.Undetected
            Harmless   = $result.Harmless
            CachedAt   = (Get-Date).ToString('o')
        }
        try {
            $cache | ConvertTo-Json -Depth 5 | Set-Content -Path $Global:VT_CacheFile -Encoding UTF8
        } catch {}
    }

    return $result
}

# --------- BUILD-ALERTSUMMARY ---------
function Build-AlertSummary {
    <#
    .SYNOPSIS
        Builds a standardised alert hashtable with a sanitized command line.
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
        Timestamp   = (Get-Date).ToString('o')
        Host        = $HostName
        ProcessName = $ProcessName
        Owner       = $Owner
        SigStatus   = $SigStatus
        Hash        = $Hash
        Cmd         = (Sanitize-CommandLine -CommandLine $CmdLine)
    }
}

# --------- SEND-DISCORDALERTSAFE ---------
function Send-DiscordAlertSafe {
    <#
    .SYNOPSIS
        Sends a redacted Discord webhook alert. Silent on failure. Enforces TLS 1.2+.
    #>
    param(
        [hashtable]$Summary,
        [string]$WebhookUrl
    )
    if ([string]::IsNullOrWhiteSpace($WebhookUrl)) { return }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $msg = "⚠️ SECURITY ALERT`n" +
           "Process : $($Summary.ProcessName)`n" +
           "Hash    : $($Summary.Hash)`n" +
           "Host    : $($Summary.Host)`n" +
           "Time    : $($Summary.Timestamp)`n" +
           "Owner   : $($Summary.Owner)`n" +
           "Sig     : $($Summary.SigStatus)`n" +
           "Cmd     : $($Summary.Cmd)"

    if ($msg.Length -gt 2000) { $msg = $msg.Substring(0, 1997) + '...' }

    $payload = @{ content = $msg } | ConvertTo-Json
    $maxAttempts = 3

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $payload `
                -ContentType 'application/json' -TimeoutSec 10 -ErrorAction Stop
            break
        } catch {
            if ($attempt -lt $maxAttempts) {
                Start-Sleep -Seconds ([math]::Pow(2, $attempt))
            }
        }
    }
}

# --------- SEND-EMAILALERTSAFE ---------
function Send-EmailAlertSafe {
    <#
    .SYNOPSIS
        Sends a redacted email alert. Silent on failure. Enforces TLS.
    #>
    param(
        [hashtable]$Summary,
        [string]$SmtpServer,
        [string]$From,
        [string]$To,
        [int]$Port     = 587,
        [bool]$UseSsl  = $true
    )
    if ([string]::IsNullOrWhiteSpace($SmtpServer) -or
        [string]::IsNullOrWhiteSpace($From)       -or
        [string]::IsNullOrWhiteSpace($To)) { return }

    $subject = "Security Alert: $($Summary.ProcessName) on $($Summary.Host)"
    $body    = "SECURITY ALERT`n`n" +
               "Process  : $($Summary.ProcessName)`n" +
               "Hash     : $($Summary.Hash)`n" +
               "Host     : $($Summary.Host)`n" +
               "Time     : $($Summary.Timestamp)`n" +
               "Owner    : $($Summary.Owner)`n" +
               "Sig      : $($Summary.SigStatus)`n" +
               "Cmd      : $($Summary.Cmd)"

    $maxAttempts = 3
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
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
            break
        } catch {
            if ($attempt -lt $maxAttempts) {
                Start-Sleep -Seconds ([math]::Pow(2, $attempt))
            }
        }
    }
}

# --------- EXECUTE-REMEDIATIONSAFE ---------
function Execute-RemediationSafe {
    <#
    .SYNOPSIS
        Executes a remediation ScriptBlock only when remediation is enabled and dry-run is off.
        Returns $true on success, $false otherwise.
    #>
    param(
        [scriptblock]$ActionScriptBlock,
        [string]$Reason
    )
    if ($Global:EnableDryRun -or -not $Global:EnableRemediation) {
        Write-Verbose "REMEDIATION SKIPPED (DryRun=$Global:EnableDryRun, EnableRemediation=$Global:EnableRemediation): $Reason"
        return $false
    }
    try {
        & $ActionScriptBlock
        Write-Verbose "REMEDIATION EXECUTED: $Reason"
        return $true
    } catch {
        Write-Verbose "REMEDIATION FAILED: $Reason - $_"
        return $false
    }
}

# --------- MOVE-TOENCRYPTEDQUARANTINE ---------
function Move-ToEncryptedQuarantine {
    <#
    .SYNOPSIS
        Copies a file to a quarantine directory and applies restrictive ACLs.
        Must be called via Execute-RemediationSafe.
    .EXAMPLE
        Execute-RemediationSafe -Reason "Quarantine malicious file" -ActionScriptBlock {
            Move-ToEncryptedQuarantine -FilePath 'C:\bad.exe' -QuarantineRoot 'C:\Quarantine'
        }
    #>
    param(
        [string]$FilePath,
        [string]$QuarantineRoot
    )
    if (-not (Test-Path $FilePath)) { return }
    if (-not (Test-Path $QuarantineRoot)) {
        New-Item -Path $QuarantineRoot -ItemType Directory -Force | Out-Null
    }

    $leaf = Split-Path $FilePath -Leaf
    $dest = Join-Path $QuarantineRoot ("${leaf}_" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.quarantine')
    Copy-Item -Path $FilePath -Destination $dest -Force -ErrorAction SilentlyContinue

    # Apply restrictive ACL: remove inherited permissions, grant only SYSTEM
    try {
        $acl = Get-Acl -Path $dest
        $acl.SetAccessRuleProtection($true, $false)  # disable inheritance, remove inherited
        $acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) | Out-Null }
        $systemSid  = New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::LocalSystemSid, $null)
        $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $systemSid,
            [System.Security.AccessControl.FileSystemRights]::FullControl,
            [System.Security.AccessControl.AccessControlType]::Allow
        )
        $acl.AddAccessRule($systemRule)
        Set-Acl -Path $dest -AclObject $acl -ErrorAction SilentlyContinue
    } catch {}

    # NOTE: For EFS encryption, enable EFS on the quarantine folder and ensure the
    # SYSTEM account has an EFS certificate configured on this host.
}

Export-ModuleMember -Function `
    Sanitize-CommandLine, `
    Get-SecretSafe, `
    Get-VirusTotalReportCached, `
    Build-AlertSummary, `
    Send-DiscordAlertSafe, `
    Send-EmailAlertSafe, `
    Execute-RemediationSafe, `
    Move-ToEncryptedQuarantine
