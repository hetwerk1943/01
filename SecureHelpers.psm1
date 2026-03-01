# SecureHelpers.psm1 - ULTRAMASTER APOCALYPSE hardening helpers
# Safe alert helpers: redaction, VT cache, alert dispatch, remediation guard.

#Requires -Version 5.1

# --------- MODULE GLOBALS ---------
$Global:VT_CacheFile      = Join-Path $PSScriptRoot 'vt_cache.json'
$Global:VT_CacheTTL_Min   = 1440
$Global:EnableDryRun      = $true
$Global:EnableRemediation = $false

# --------- SANITIZE COMMAND LINE ---------
function Sanitize-CommandLine {
    <#
    .SYNOPSIS
        Returns exe name with a redacted args marker. Raw args are never stored.
    .PARAMETER CommandLine
        The full command line string to sanitize.
    #>
    param([string]$CommandLine)
    if ([string]::IsNullOrWhiteSpace($CommandLine)) { return '[empty]' }
    try {
        # Split on first space to separate executable from arguments
        $parts   = $CommandLine -split '\s+', 2
        $exePart = $parts[0].Trim('"').Trim("'")
        $exeName = Split-Path $exePart -Leaf
        if ($exeName -eq '') { $exeName = $exePart }

        if ($parts.Count -gt 1 -and -not [string]::IsNullOrWhiteSpace($parts[1])) {
            $args = $parts[1]
            # Hash the raw args; expose only first 8 hex chars
            $sha  = [System.Security.Cryptography.SHA256]::Create()
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($args)
            $hashBytes = $sha.ComputeHash($bytes)
            $sha.Dispose()
            $hex8 = ($hashBytes | ForEach-Object { $_.ToString('x2') }) -join ''
            $hex8 = $hex8.Substring(0, 8)
            return "$exeName [REDACTED_ARGS:$hex8]"
        }
        return $exeName
    } catch {
        return '[sanitize-error]'
    }
}

# --------- SECRET RETRIEVAL ---------
function Get-SecretSafe {
    <#
    .SYNOPSIS
        Retrieves a secret via SecretManagement or falls back to an environment variable.
    .PARAMETER Name
        SecretManagement secret name.
    .PARAMETER EnvVarName
        Environment variable name used as fallback.
    #>
    param(
        [string]$Name,
        [string]$EnvVarName
    )
    # Try Microsoft.PowerShell.SecretManagement
    try {
        $secret = Get-Secret -Name $Name -ErrorAction Stop
        if ($null -ne $secret) { return $secret }
    } catch {}
    # Fall back to environment variable
    $envVal = [System.Environment]::GetEnvironmentVariable($EnvVarName)
    if (-not [string]::IsNullOrWhiteSpace($envVal)) { return $envVal }
    return $null
}

# --------- VIRUSTOTAL CACHED LOOKUP ---------
function Get-VirusTotalReportCached {
    <#
    .SYNOPSIS
        Returns VirusTotal last_analysis_stats for a hash, using a local JSON cache.
    .PARAMETER Hash
        SHA-256 hash to query.
    .PARAMETER CacheTTL_Min
        Cache TTL in minutes (default 1440 = 24 h).
    #>
    param(
        [string]$Hash,
        [int]$CacheTTL_Min = 1440
    )
    if ([string]::IsNullOrWhiteSpace($Hash)) { return $null }

    # Load cache
    $cache = @{}
    if (Test-Path $Global:VT_CacheFile) {
        try { $cache = Get-Content $Global:VT_CacheFile -Raw | ConvertFrom-Json -ErrorAction Stop }
        catch { $cache = @{} }
        # ConvertFrom-Json returns PSCustomObject; convert to hashtable for consistent access
        if ($cache -isnot [hashtable]) {
            $ht = @{}
            foreach ($prop in $cache.PSObject.Properties) { $ht[$prop.Name] = $prop.Value }
            $cache = $ht
        }
    }

    # Cache hit?
    if ($cache.ContainsKey($Hash)) {
        $entry = $cache[$Hash]
        $cached = $null
        if ($entry -is [hashtable]) { $cached = $entry }
        elseif ($null -ne $entry) {
            $cached = @{}
            foreach ($prop in $entry.PSObject.Properties) { $cached[$prop.Name] = $prop.Value }
        }
        if ($null -ne $cached -and $null -ne $cached['ts']) {
            $age = (Get-Date) - [datetime]$cached['ts']
            if ($age.TotalMinutes -lt $CacheTTL_Min) {
                $r = $cached['result']
                if ($r -isnot [hashtable]) {
                    $ht2 = @{}
                    foreach ($p in $r.PSObject.Properties) { $ht2[$p.Name] = $p.Value }
                    $r = $ht2
                }
                return [PSCustomObject]@{
                    Malicious  = $r['Malicious']
                    Suspicious = $r['Suspicious']
                    Undetected = $r['Undetected']
                    Harmless   = $r['Harmless']
                }
            }
        }
    }

    # Need VT API key
    $apiKey = Get-SecretSafe -Name 'VirusTotalApiKey' -EnvVarName 'VT_API_KEY'
    if ($null -eq $apiKey -or [string]::IsNullOrWhiteSpace($apiKey.ToString())) { return $null }

    # Query VirusTotal with exponential backoff
    $uri     = "https://www.virustotal.com/api/v3/files/$Hash"
    $headers = @{ "x-apikey" = $apiKey.ToString() }
    $result  = $null
    $maxAttempts = 3
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
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
            if ($attempt -lt $maxAttempts) {
                Start-Sleep -Seconds ([Math]::Pow(2, $attempt))
            }
        }
    }

    if ($null -eq $result) { return $null }

    # Store in cache
    try {
        $cache[$Hash] = @{
            ts     = (Get-Date).ToString('o')
            result = @{
                Malicious  = $result.Malicious
                Suspicious = $result.Suspicious
                Undetected = $result.Undetected
                Harmless   = $result.Harmless
            }
        }
        $cache | ConvertTo-Json -Depth 5 | Set-Content -Path $Global:VT_CacheFile -Encoding UTF8
    } catch {}

    return $result
}

# --------- BUILD ALERT SUMMARY ---------
function Build-AlertSummary {
    <#
    .SYNOPSIS
        Constructs a sanitized alert summary hashtable.
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
        timestamp   = (Get-Date).ToString('o')
        host        = $HostName
        name        = $ProcessName
        owner       = $Owner
        sig         = $SigStatus
        hash        = $Hash
        cmd         = (Sanitize-CommandLine -CommandLine $CmdLine)
    }
}

# --------- SEND DISCORD ALERT (SAFE) ---------
function Send-DiscordAlertSafe {
    <#
    .SYNOPSIS
        Sends a redacted Discord alert. Only allowed fields are included.
        Enforces 2000 char limit and uses TLS with retry/backoff.
    #>
    param(
        [hashtable]$Summary,
        [string]$WebhookUrl
    )
    if ([string]::IsNullOrWhiteSpace($WebhookUrl)) { return }
    try {
        # Only include allowed (non-sensitive) fields
        $msg = "⚠️ SUSPECT PROCESS`n" +
               "Name:      $($Summary['name'])`n" +
               "Host:      $($Summary['host'])`n" +
               "Owner:     $($Summary['owner'])`n" +
               "Sig:       $($Summary['sig'])`n" +
               "SHA256:    $($Summary['hash'])`n" +
               "Timestamp: $($Summary['timestamp'])"
        if ($msg.Length -gt 2000) { $msg = $msg.Substring(0, 1997) + '...' }
        $payload = @{ content = $msg } | ConvertTo-Json
        $maxAttempts = 3
        for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
            try {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $payload `
                    -ContentType 'application/json' -TimeoutSec 10 -ErrorAction Stop
                break
            } catch {
                if ($attempt -lt $maxAttempts) { Start-Sleep -Seconds ([Math]::Pow(2, $attempt)) }
            }
        }
    } catch {}
}

# --------- SEND EMAIL ALERT (SAFE) ---------
function Send-EmailAlertSafe {
    <#
    .SYNOPSIS
        Sends a redacted email alert with TLS enforcement and retry/backoff.
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
    try {
        $subject = "Suspicious Process Alert: $($Summary['name']) on $($Summary['host'])"
        $body    = "Timestamp: $($Summary['timestamp'])`n" +
                   "Host:      $($Summary['host'])`n" +
                   "Process:   $($Summary['name'])`n" +
                   "Owner:     $($Summary['owner'])`n" +
                   "Sig:       $($Summary['sig'])`n" +
                   "SHA256:    $($Summary['hash'])"
        $params = @{
            To         = $To
            From       = $From
            Subject    = $subject
            Body       = $body
            SmtpServer = $SmtpServer
            Port       = $Port
            UseSsl     = $UseSsl
        }
        $maxAttempts = 3
        for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
            try {
                Send-MailMessage @params -ErrorAction Stop
                break
            } catch {
                if ($attempt -lt $maxAttempts) { Start-Sleep -Seconds ([Math]::Pow(2, $attempt)) }
            }
        }
    } catch {}
}

# --------- SAFE REMEDIATION GATE ---------
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
    if ($Global:EnableDryRun -eq $true -or $Global:EnableRemediation -eq $false) {
        Write-Host "[DRY-RUN] Suppressed remediation: $Reason"
        return $false
    }
    try {
        & $ActionScriptBlock
        Write-Host "[REMEDIATION] Executed: $Reason"
        return $true
    } catch {
        Write-Host "[REMEDIATION-ERROR] $Reason : $_"
        return $false
    }
}

# --------- ENCRYPTED QUARANTINE ---------
function Move-ToEncryptedQuarantine {
    <#
    .SYNOPSIS
        Copies a file to a quarantine folder and applies restrictive ACL.
        Optional EFS encryption where available.
        Must only be called when Execute-RemediationSafe permits.
    #>
    param(
        [string]$FilePath,
        [string]$QuarantineRoot
    )
    if (-not (Test-Path $FilePath)) { return $false }
    try {
        if (-not (Test-Path $QuarantineRoot)) {
            New-Item -Path $QuarantineRoot -ItemType Directory -Force | Out-Null
        }
        $leaf = Split-Path $FilePath -Leaf
        $dest = Join-Path $QuarantineRoot ("${leaf}_" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        Copy-Item -Path $FilePath -Destination $dest -Force -ErrorAction Stop

        # Restrict ACL – owner/Administrators only
        try {
            $acl = Get-Acl -Path $dest
            $acl.SetAccessRuleProtection($true, $false)
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
                'FullControl', 'Allow')
            $acl.SetAccessRule($rule)
            Set-Acl -Path $dest -AclObject $acl
        } catch {}

        # Optional EFS encryption (Windows only, best-effort)
        # cipher /e "$dest" | Out-Null
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
