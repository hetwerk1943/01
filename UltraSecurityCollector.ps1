# UltraSecurityCollector.ps1
# Ultra Security Monitor – Collector / Remediation Engine
#
# Responsibilities:
#   • Receives signed telemetry from the Agent over loopback HTTP (HMAC-SHA256 auth)
#   • Orchestrates VirusTotal checks (TTL cache + rate-limiting)
#   • Dispatches sanitized alerts to Discord / Email
#   • Manages operator-approval queue for remediation (Stop-Process / quarantine)
#   • Maintains a full, ACL-restricted audit trail
#   • Supports rollback of accidental block / quarantine actions
#
# Prerequisites:
#   • Run as Administrator (or dedicated service account)
#   • Provision secrets with Set-UltraCollectorCredential before first run
#   • TLS termination / mTLS handled at the transport layer (e.g., stunnel or IIS ARR)
#     when exposing outside loopback. Loopback-only by default.
#
# Usage:
#   .\UltraSecurityCollector.ps1 [-DryRun] [-Port 18443] [-VerboseLog]

#Requires -Version 5.1

param(
    [switch]$DryRun,
    [int]$Port          = 18443,
    [switch]$VerboseLog
)

# --------- PATHS ---------
$BaseFolder     = Join-Path $env:USERPROFILE "Documents\SecurityMonitor\Collector"
$AuditLogPath   = Join-Path $BaseFolder "collector-audit.log"
$SiemLogPath    = Join-Path $BaseFolder "collector-siem.json"
$QueuePath      = Join-Path $BaseFolder "remediation-queue.json"
$RollbackPath   = Join-Path $BaseFolder "rollback-log.json"
$VTCacheFile    = Join-Path $BaseFolder "vt-cache.json"

foreach ($dir in @($BaseFolder)) {
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
}

# --------- CONSTANTS ---------
$MaxDiscordMsgLength = 2000
$VTCacheTtlSeconds   = 3600      # 1 hour
$VTRateLimitMs       = 15100     # ~4 req/min
$VTDailyLimit        = 450
$RetryMaxAttempts    = 3
$RetryBaseDelayMs    = 2000

# --------- RUNTIME STATE ---------
$script:VTCache          = @{}
$script:VTLastCallTime   = [datetime]::MinValue
$script:VTDailyCount     = 0
$script:VTDailyResetDate = [datetime]::Today.Date
$script:RemediationQueue = [System.Collections.Generic.List[hashtable]]::new()
$script:RollbackLog      = [System.Collections.Generic.List[hashtable]]::new()
$script:Listener         = $null

# --------- SECRETS MANAGEMENT ---------
function Get-UltraCollectorSecret {
    <#
    .SYNOPSIS  Retrieves a secret from Windows Credential Manager (PasswordVault / DPAPI).
    #>
    param([string]$Target)
    try {
        Add-Type -AssemblyName Windows.Security -ErrorAction SilentlyContinue
        $vault = New-Object Windows.Security.Credentials.PasswordVault
        $cred  = $vault.Retrieve($Target, "UltraSecurityCollector")
        $cred.RetrievePassword()
        return $cred.Password
    } catch { return $null }
}

function Set-UltraCollectorCredential {
    <#
    .SYNOPSIS  Stores a secret in Windows Credential Manager (PasswordVault / DPAPI).
    .EXAMPLE   Set-UltraCollectorCredential -Target "UltraSecurityCollector/VirusTotal" -Secret "key"
    #>
    param([string]$Target, [string]$Secret)
    try {
        Add-Type -AssemblyName Windows.Security -ErrorAction SilentlyContinue
        $vault = New-Object Windows.Security.Credentials.PasswordVault
        $cred  = New-Object Windows.Security.Credentials.PasswordCredential($Target, "UltraSecurityCollector", $Secret)
        $vault.Add($cred)
        Write-Host "Secret '$Target' stored."
    } catch { Write-Warning "Failed to store '$Target': $_" }
}

# Load secrets at runtime
$VirusTotalApiKey  = Get-UltraCollectorSecret -Target "UltraSecurityCollector/VirusTotal"
$DiscordWebhookUrl = Get-UltraCollectorSecret -Target "UltraSecurityCollector/Discord"
$SmtpPassword      = Get-UltraCollectorSecret -Target "UltraSecurityCollector/SMTP"
$CollectorHmacKey  = Get-UltraCollectorSecret -Target "UltraSecurityCollector/CollectorHmac"

# SMTP settings (non-secret config)
$EmailAlerts = $false
$SmtpServer  = ""
$SmtpFrom    = ""
$SmtpTo      = ""
$SmtpUseSsl  = $true
$SmtpPort    = 587

# --------- ACL PROTECTION ---------
function Set-RestrictedAcl {
    param([string]$Path)
    try {
        $acl = Get-Acl -Path $Path -ErrorAction Stop
        $acl.SetAccessRuleProtection($true, $false)
        $adminSid  = New-Object System.Security.Principal.SecurityIdentifier(
            [System.Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid, $null)
        $systemSid = New-Object System.Security.Principal.SecurityIdentifier(
            [System.Security.Principal.WellKnownSidType]::LocalSystemSid, $null)
        $inherit = [System.Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit'
        $none    = [System.Security.AccessControl.PropagationFlags]::None
        $allow   = [System.Security.AccessControl.AccessControlType]::Allow
        $acl.AddAccessRule(
            (New-Object System.Security.AccessControl.FileSystemAccessRule($adminSid,  "FullControl", $inherit, $none, $allow)))
        $acl.AddAccessRule(
            (New-Object System.Security.AccessControl.FileSystemAccessRule($systemSid, "FullControl", $inherit, $none, $allow)))
        Set-Acl -Path $Path -AclObject $acl -ErrorAction SilentlyContinue
    } catch { Write-AuditLog "Set-RestrictedAcl error for '$Path': $_" }
}

Set-RestrictedAcl -Path $BaseFolder

# --------- AUDIT LOG ---------
function Write-AuditLog {
    param([string]$Msg, [string]$Level = "INFO")
    $entry = "$(Get-Date -Format o)`t[$Level]`t$(Invoke-Redact $Msg)"
    Add-Content -Path $AuditLogPath -Value $entry -ErrorAction SilentlyContinue
    if ($VerboseLog) { Write-Host $entry }
}

function Write-SiemEvent {
    param([string]$EventType, [string]$Severity, [hashtable]$Data)
    $safeData = @{}
    foreach ($k in $Data.Keys) {
        $v = $Data[$k]
        $safeData[$k] = if ($v -is [string]) { Invoke-Redact $v } else { $v }
    }
    $event = [ordered]@{
        timestamp  = (Get-Date).ToString("o")
        host       = $env:COMPUTERNAME
        event_type = $EventType
        severity   = $Severity
        data       = $safeData
    }
    try { Add-Content -Path $SiemLogPath -Value ($event | ConvertTo-Json -Compress) } catch {}
}

# --------- REDACTION ---------
function Invoke-Redact {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    $Text = $Text -replace '\b(?:\d{1,3}\.){3}\d{1,3}\b', '[IP-REDACTED]'
    $Text = $Text -replace '\\\\[^\\/ \t\r\n]+\\[^\s]+', '[UNC-REDACTED]'
    $Text = $Text -replace '(?i)[A-Za-z]:\\(?:[^\\/:*?"<>|\r\n]+\\)+([^\\/:*?"<>|\r\n\s]+)', '[PATH]\$1'
    $Text = $Text -replace '(?i)([\w.-]+\.exe)\s+[^\r\n]+', '$1 [ARGS-REDACTED]'
    return $Text
}

# --------- HMAC VALIDATION ---------
function Test-HmacSignature {
    <#
    .SYNOPSIS  Returns $true if the X-HMAC-SHA256 header matches HMAC-SHA256(body, key).
    #>
    param([string]$Body, [string]$ProvidedSig, [string]$Key)
    if ([string]::IsNullOrWhiteSpace($Key) -or [string]::IsNullOrWhiteSpace($ProvidedSig)) {
        return $false
    }
    try {
        $keyBytes  = [System.Text.Encoding]::UTF8.GetBytes($Key)
        $dataBytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
        $hmac      = New-Object System.Security.Cryptography.HMACSHA256
        $hmac.Key  = $keyBytes
        $expected  = [Convert]::ToBase64String($hmac.ComputeHash($dataBytes))
        # Constant-time comparison to prevent timing attacks
        if ($expected.Length -ne $ProvidedSig.Length) { return $false }
        $xorAccumulator = 0
        for ($i = 0; $i -lt $expected.Length; $i++) {
            $xorAccumulator = $xorAccumulator -bor ([int][char]$expected[$i] -bxor [int][char]$ProvidedSig[$i])
        }
        return ($xorAccumulator -eq 0)
    } catch { return $false }
}

# --------- RETRY / BACKOFF ---------
function Invoke-WithRetry {
    param(
        [scriptblock]$ScriptBlock,
        [int]$MaxAttempts = $RetryMaxAttempts,
        [int]$BaseDelayMs = $RetryBaseDelayMs
    )
    $attempt = 0
    while ($attempt -lt $MaxAttempts) {
        $attempt++
        try { return (& $ScriptBlock) }
        catch {
            if ($attempt -ge $MaxAttempts) { throw }
            $delayMs = [int]($BaseDelayMs * [Math]::Pow(2, $attempt - 1))
            Start-Sleep -Milliseconds $delayMs
        }
    }
}

# --------- VIRUSTOTAL (Collector-side: cache + rate-limit) ---------
function Get-VirusTotalReport {
    param([string]$Hash)
    if ([string]::IsNullOrWhiteSpace($VirusTotalApiKey) -or [string]::IsNullOrWhiteSpace($Hash)) {
        return $null
    }
    # Input validation: SHA-256 = exactly 64 hex chars
    if ($Hash -notmatch '^[0-9a-fA-F]{64}$') {
        Write-AuditLog "VT: invalid hash format rejected" "WARN"
        return $null
    }
    # Daily quota reset
    if ([datetime]::Today.Date -gt $script:VTDailyResetDate) {
        $script:VTDailyCount     = 0
        $script:VTDailyResetDate = [datetime]::Today.Date
    }
    if ($script:VTDailyCount -ge $VTDailyLimit) {
        Write-AuditLog "VT: daily quota reached ($($script:VTDailyCount))" "WARN"
        return $null
    }
    # TTL cache
    if ($script:VTCache.ContainsKey($Hash)) {
        $entry = $script:VTCache[$Hash]
        if (((Get-Date) - $entry.CachedAt).TotalSeconds -lt $VTCacheTtlSeconds) {
            Write-AuditLog "VT: cache hit for [HASH-REDACTED]"
            return $entry.Result
        }
    }
    # Rate limiting
    $elapsed = ((Get-Date) - $script:VTLastCallTime).TotalMilliseconds
    if ($elapsed -lt $VTRateLimitMs) {
        Start-Sleep -Milliseconds ([int]($VTRateLimitMs - $elapsed))
    }
    try {
        $uri     = "https://www.virustotal.com/api/v3/files/$Hash"
        $headers = @{ "x-apikey" = $VirusTotalApiKey }
        $resp    = Invoke-WithRetry -ScriptBlock {
            Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -TimeoutSec 15 -ErrorAction Stop
        }
        $script:VTLastCallTime = Get-Date
        $script:VTDailyCount++
        $stats = $resp.data.attributes.last_analysis_stats
        if ($null -eq $stats) { return $null }
        $result = [PSCustomObject]@{
            Malicious  = $stats.malicious
            Suspicious = $stats.suspicious
            Undetected = $stats.undetected
            Harmless   = $stats.harmless
        }
        $script:VTCache[$Hash] = @{ Result = $result; CachedAt = Get-Date }
        Write-AuditLog "VT: checked [HASH-REDACTED], Malicious=$($result.Malicious)"
        return $result
    } catch {
        $script:VTLastCallTime = Get-Date
        Write-AuditLog "VT: lookup failed: $_" "WARN"
        return $null
    }
}

# --------- ALERTS ---------
function Send-DiscordAlert {
    param([string]$Message)
    if ([string]::IsNullOrWhiteSpace($DiscordWebhookUrl)) { return }
    $safe = Invoke-Redact $Message
    if ($safe.Length -gt $MaxDiscordMsgLength) { $safe = $safe.Substring(0, $MaxDiscordMsgLength - 3) + "..." }
    $payload = @{ content = $safe } | ConvertTo-Json
    try {
        Invoke-WithRetry -ScriptBlock {
            Invoke-RestMethod -Uri $DiscordWebhookUrl -Method Post -Body $payload `
                -ContentType "application/json" -TimeoutSec 10 -ErrorAction Stop
        }
    } catch { Write-AuditLog "Discord alert failed: $_" "WARN" }
}

function Send-EmailAlert {
    param([string]$Subject, [string]$Body)
    if (-not $EmailAlerts -or [string]::IsNullOrWhiteSpace($SmtpServer) -or
        [string]::IsNullOrWhiteSpace($SmtpFrom) -or [string]::IsNullOrWhiteSpace($SmtpTo)) { return }
    $params = @{
        To         = $SmtpTo
        From       = $SmtpFrom
        Subject    = Invoke-Redact $Subject
        Body       = Invoke-Redact $Body
        SmtpServer = $SmtpServer
        Port       = $SmtpPort
        UseSsl     = $SmtpUseSsl
    }
    if (-not [string]::IsNullOrWhiteSpace($SmtpPassword)) {
        $secPwd = ConvertTo-SecureString $SmtpPassword -AsPlainText -Force
        $params['Credential'] = New-Object System.Management.Automation.PSCredential($SmtpFrom, $secPwd)
    }
    try {
        Invoke-WithRetry -ScriptBlock { Send-MailMessage @params -ErrorAction Stop }
    } catch { Write-AuditLog "Email alert failed: $_" "WARN" }
}

# --------- MULTI-SIGNAL CONFIDENCE ENGINE ---------
function Get-ThreatConfidence {
    <#
    .SYNOPSIS  Returns a confidence score 0-100 based on multiple signals.
               Score >= 80 may trigger operator-approved remediation.
    #>
    param(
        [int]$VTMalicious   = 0,
        [int]$VTSuspicious  = 0,
        [string]$SigStatus  = "Unknown",
        [bool]$InSuspiciousPath = $false,
        [bool]$SandboxVerdict   = $false
    )
    $score = 0
    if ($VTMalicious -ge 5)  { $score += 40 }
    elseif ($VTMalicious -ge 1) { $score += 20 }
    if ($VTSuspicious -ge 3) { $score += 15 }
    if ($SigStatus -in @("NotSigned","UnknownError","HashMismatch")) { $score += 20 }
    if ($InSuspiciousPath) { $score += 15 }
    if ($SandboxVerdict)   { $score += 30 }
    return [Math]::Min($score, 100)
}

# --------- REMEDIATION QUEUE ---------
function Add-RemediationRequest {
    <#
    .SYNOPSIS  Enqueues a remediation request; execution requires operator approval.
    #>
    param(
        [string]$Action,       # "StopProcess" | "QuarantineFile"
        [string]$Target,       # PID or file path (will be redacted in log)
        [int]$Confidence,
        [hashtable]$Context
    )
    $requestId = [guid]::NewGuid().ToString()
    $req = @{
        RequestId  = $requestId
        Action     = $Action
        Target     = $Target
        Confidence = $Confidence
        Context    = $Context
        Status     = "Pending"
        CreatedAt  = (Get-Date).ToString("o")
        ApprovedBy = $null
        ExecutedAt = $null
    }
    $script:RemediationQueue.Add($req)
    # Persist queue
    try { $script:RemediationQueue | ConvertTo-Json -Depth 5 | Set-Content -Path $QueuePath -Force } catch {}
    Write-AuditLog "Remediation queued: Action=$Action Confidence=$Confidence RequestId=$requestId"
    Write-SiemEvent -EventType "RemediationQueued" -Severity "High" -Data @{
        requestId  = $requestId
        action     = $Action
        confidence = $Confidence
    }
    $alertMsg = "⚙️ REMEDIATION REQUESTED`nAction: $Action`nConfidence: $Confidence%`nRequestId: $requestId`nAwating operator approval."
    Send-DiscordAlert $alertMsg
    Send-EmailAlert -Subject "Remediation Approval Required" -Body $alertMsg
    return $requestId
}

function Approve-RemediationRequest {
    <#
    .SYNOPSIS  Operator approves a pending remediation request by ID.
               Executes only when DryRun=$false.
    #>
    param([string]$RequestId, [string]$ApprovedBy = "Operator")
    $req = $script:RemediationQueue | Where-Object { $_.RequestId -eq $RequestId -and $_.Status -eq "Pending" }
    if ($null -eq $req) {
        Write-AuditLog "Approve-RemediationRequest: RequestId $RequestId not found or not Pending" "WARN"
        return
    }
    $req.Status     = "Approved"
    $req.ApprovedBy = $ApprovedBy
    Write-AuditLog "Remediation approved: RequestId=$RequestId ApprovedBy=$ApprovedBy"
    if ($DryRun) {
        Write-AuditLog "DryRun=true: skipping execution of $($req.Action) on $($req.Target)"
        $req.Status = "DryRunSkipped"
        return
    }
    Invoke-RemediationAction -Request $req
}

function Invoke-RemediationAction {
    param([hashtable]$Request)
    $rollbackEntry = @{
        RequestId   = $Request.RequestId
        Action      = $Request.Action
        Target      = $Request.Target
        ExecutedAt  = (Get-Date).ToString("o")
        RolledBack  = $false
        RollbackAt  = $null
    }
    try {
        switch ($Request.Action) {
            "StopProcess" {
                $pid = [int]$Request.Target
                if ($pid -gt 0) {
                    Stop-Process -Id $pid -Force -ErrorAction Stop
                    Write-AuditLog "StopProcess executed: PID=$pid"
                }
            }
            "QuarantineFile" {
                $src  = $Request.Target
                $dest = Join-Path $BaseFolder ("Quarantine\" + (Split-Path $src -Leaf) + "_" + (Get-Date -Format "yyyyMMdd-HHmmss"))
                if (-not (Test-Path (Join-Path $BaseFolder "Quarantine"))) {
                    New-Item -Path (Join-Path $BaseFolder "Quarantine") -ItemType Directory -Force | Out-Null
                    Set-RestrictedAcl -Path (Join-Path $BaseFolder "Quarantine")
                }
                Move-Item -Path $src -Destination $dest -Force -ErrorAction Stop
                Set-RestrictedAcl -Path $dest
                $rollbackEntry['QuarantineDestination'] = $dest
                Write-AuditLog "QuarantineFile executed: [PATH]\$(Split-Path $src -Leaf) -> quarantine"
            }
            default { Write-AuditLog "Unknown remediation action: $($Request.Action)" "WARN"; return }
        }
        $Request.Status     = "Executed"
        $Request.ExecutedAt = (Get-Date).ToString("o")
        $script:RollbackLog.Add($rollbackEntry)
        try { $script:RollbackLog | ConvertTo-Json -Depth 5 | Set-Content -Path $RollbackPath -Force } catch {}
        Write-SiemEvent -EventType "RemediationExecuted" -Severity "High" -Data @{
            requestId = $Request.RequestId
            action    = $Request.Action
        }
    } catch {
        $Request.Status = "Failed"
        Write-AuditLog "Remediation execution failed: $($Request.RequestId) - $_" "ERROR"
    }
    try { $script:RemediationQueue | ConvertTo-Json -Depth 5 | Set-Content -Path $QueuePath -Force } catch {}
}

function Invoke-RollbackAction {
    <#
    .SYNOPSIS  Rolls back a previously executed remediation (e.g. restores quarantined file).
    #>
    param([string]$RequestId)
    $entry = $script:RollbackLog | Where-Object { $_.RequestId -eq $RequestId -and -not $_.RolledBack }
    if ($null -eq $entry) {
        Write-AuditLog "Rollback: RequestId $RequestId not found or already rolled back" "WARN"
        return
    }
    try {
        switch ($entry.Action) {
            "QuarantineFile" {
                if ($entry.QuarantineDestination -and (Test-Path $entry.QuarantineDestination)) {
                    $orig = Join-Path (Split-Path $entry.Target -Parent) (Split-Path $entry.Target -Leaf)
                    Move-Item -Path $entry.QuarantineDestination -Destination $orig -Force -ErrorAction Stop
                    Write-AuditLog "Rollback: file restored from quarantine: [PATH]\$(Split-Path $orig -Leaf)"
                }
            }
            "StopProcess" {
                Write-AuditLog "Rollback: StopProcess cannot be rolled back (process cannot be restarted safely)"
            }
        }
        $entry.RolledBack = $true
        $entry.RollbackAt = (Get-Date).ToString("o")
        try { $script:RollbackLog | ConvertTo-Json -Depth 5 | Set-Content -Path $RollbackPath -Force } catch {}
        Write-SiemEvent -EventType "RemediationRolledBack" -Severity "Medium" -Data @{ requestId = $RequestId }
    } catch {
        Write-AuditLog "Rollback failed: $RequestId - $_" "ERROR"
    }
}

# --------- TELEMETRY EVENT HANDLER ---------
function Invoke-TelemetryEvent {
    <#
    .SYNOPSIS  Processes a validated telemetry event received from the Agent.
    #>
    param([hashtable]$Event)
    $eventType = $Event.event_type
    $severity  = $Event.severity
    $data      = $Event.data

    Write-AuditLog "Event received: $eventType Severity=$severity"
    Write-SiemEvent -EventType $eventType -Severity $severity -Data $data

    switch ($eventType) {
        "SuspiciousProcess" {
            $hash        = $data.hash
            $procName    = $data.name
            $sigStatus   = $data.sig
            $vtMalicious = if ($null -ne $data.vtMalicious) { [int]$data.vtMalicious } else { 0 }

            # Run VT check on Collector side (agent sends hash, not raw file)
            $vtResult = $null
            if (-not [string]::IsNullOrWhiteSpace($hash)) {
                $vtResult = Get-VirusTotalReport -Hash $hash
                if ($null -ne $vtResult) { $vtMalicious = [int]$vtResult.Malicious }
            }

            $confidence = Get-ThreatConfidence `
                -VTMalicious   $vtMalicious `
                -VTSuspicious  (if ($null -ne $vtResult) { [int]$vtResult.Suspicious } else { 0 }) `
                -SigStatus     $sigStatus `
                -InSuspiciousPath ($severity -eq "High")

            $alertMsg = "⚠️ SUSPICIOUS PROCESS`nName: $procName`nSig: $sigStatus`nVT Malicious: $vtMalicious`nConfidence: $confidence%"
            Send-DiscordAlert $alertMsg
            Send-EmailAlert -Subject "Suspicious Process – Collector Alert" -Body $alertMsg

            # Queue remediation if confidence is high enough and agent isn't in dry-run
            if ($confidence -ge 80 -and $data.dryRun -eq $false) {
                $pid = if ($null -ne $data.pid) { [int]$data.pid } else { 0 }
                if ($pid -gt 0) {
                    Add-RemediationRequest -Action "StopProcess" -Target "$pid" `
                        -Confidence $confidence -Context $data
                }
            }
        }
        "FileChange" {
            $leaf = Split-Path ($data.path -replace '\[PATH\]\\', '') -Leaf
            Write-AuditLog "FileChange: $($data.change) on $leaf"
        }
    }
}

# --------- HTTP LISTENER (loopback only) ---------
function Start-CollectorListener {
    Write-AuditLog "Starting Collector listener on 127.0.0.1:$Port"
    $script:Listener = [System.Net.HttpListener]::new()
    $script:Listener.Prefixes.Add("http://127.0.0.1:$Port/")
    $script:Listener.Start()
    Write-Host "🔒 Collector listening on http://127.0.0.1:$Port/"

    while ($script:Listener.IsListening) {
        try {
            $ctx      = $script:Listener.GetContext()
            $req      = $ctx.Request
            $resp     = $ctx.Response
            $urlPath  = $req.Url.AbsolutePath

            # --- /health endpoint ---
            if ($urlPath -eq "/health" -and $req.HttpMethod -eq "GET") {
                $body   = [System.Text.Encoding]::UTF8.GetBytes('{"status":"ok"}')
                $resp.StatusCode        = 200
                $resp.ContentType       = "application/json"
                $resp.ContentLength64   = $body.Length
                $resp.OutputStream.Write($body, 0, $body.Length)
                $resp.OutputStream.Close()
                continue
            }

            # --- /event endpoint (POST, HMAC-authenticated) ---
            if ($urlPath -eq "/event" -and $req.HttpMethod -eq "POST") {
                $reader  = New-Object System.IO.StreamReader($req.InputStream, [System.Text.Encoding]::UTF8)
                $rawBody = $reader.ReadToEnd()
                $reader.Dispose()

                $providedSig = $req.Headers["X-HMAC-SHA256"]

                if (-not (Test-HmacSignature -Body $rawBody -ProvidedSig $providedSig -Key $CollectorHmacKey)) {
                    Write-AuditLog "HMAC validation failed for /event" "WARN"
                    $resp.StatusCode = 401
                    $resp.OutputStream.Close()
                    continue
                }

                # Validate & deserialize JSON
                try {
                    $eventObj = $rawBody | ConvertFrom-Json -ErrorAction Stop
                } catch {
                    Write-AuditLog "Invalid JSON on /event: $_" "WARN"
                    $resp.StatusCode = 400
                    $resp.OutputStream.Close()
                    continue
                }

                # Convert PSCustomObject to hashtable for handler
                $eventHash = @{}
                $eventObj.PSObject.Properties | ForEach-Object { $eventHash[$_.Name] = $_.Value }
                if ($eventHash.data -is [System.Management.Automation.PSCustomObject]) {
                    $dataHash = @{}
                    $eventHash.data.PSObject.Properties | ForEach-Object { $dataHash[$_.Name] = $_.Value }
                    $eventHash.data = $dataHash
                }

                Invoke-TelemetryEvent -Event $eventHash

                $ok   = [System.Text.Encoding]::UTF8.GetBytes('{"accepted":true}')
                $resp.StatusCode        = 200
                $resp.ContentType       = "application/json"
                $resp.ContentLength64   = $ok.Length
                $resp.OutputStream.Write($ok, 0, $ok.Length)
                $resp.OutputStream.Close()
                continue
            }

            # --- /approve endpoint (POST, HMAC-authenticated) ---
            if ($urlPath -eq "/approve" -and $req.HttpMethod -eq "POST") {
                $reader  = New-Object System.IO.StreamReader($req.InputStream, [System.Text.Encoding]::UTF8)
                $rawBody = $reader.ReadToEnd()
                $reader.Dispose()

                $providedSig = $req.Headers["X-HMAC-SHA256"]
                if (-not (Test-HmacSignature -Body $rawBody -ProvidedSig $providedSig -Key $CollectorHmacKey)) {
                    Write-AuditLog "HMAC validation failed for /approve" "WARN"
                    $resp.StatusCode = 401
                    $resp.OutputStream.Close()
                    continue
                }

                try {
                    $approveReq = $rawBody | ConvertFrom-Json -ErrorAction Stop
                } catch {
                    $resp.StatusCode = 400; $resp.OutputStream.Close(); continue
                }

                $rid        = [string]$approveReq.requestId
                $approvedBy = if ($approveReq.approvedBy) { [string]$approveReq.approvedBy } else { "Operator" }
                # Strict RFC 4122 GUID format validation
                if ($rid -notmatch '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
                    $resp.StatusCode = 400; $resp.OutputStream.Close(); continue
                }
                Approve-RemediationRequest -RequestId $rid -ApprovedBy $approvedBy

                $ok = [System.Text.Encoding]::UTF8.GetBytes('{"approved":true}')
                $resp.StatusCode        = 200
                $resp.ContentType       = "application/json"
                $resp.ContentLength64   = $ok.Length
                $resp.OutputStream.Write($ok, 0, $ok.Length)
                $resp.OutputStream.Close()
                continue
            }

            # --- /rollback endpoint (POST, HMAC-authenticated) ---
            if ($urlPath -eq "/rollback" -and $req.HttpMethod -eq "POST") {
                $reader  = New-Object System.IO.StreamReader($req.InputStream, [System.Text.Encoding]::UTF8)
                $rawBody = $reader.ReadToEnd()
                $reader.Dispose()

                $providedSig = $req.Headers["X-HMAC-SHA256"]
                if (-not (Test-HmacSignature -Body $rawBody -ProvidedSig $providedSig -Key $CollectorHmacKey)) {
                    $resp.StatusCode = 401; $resp.OutputStream.Close(); continue
                }
                try {
                    $rollbackReq = $rawBody | ConvertFrom-Json -ErrorAction Stop
                } catch {
                    $resp.StatusCode = 400; $resp.OutputStream.Close(); continue
                }
                $rid = [string]$rollbackReq.requestId
                # Strict RFC 4122 GUID format validation
                if ($rid -notmatch '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
                    $resp.StatusCode = 400; $resp.OutputStream.Close(); continue
                }
                Invoke-RollbackAction -RequestId $rid

                $ok = [System.Text.Encoding]::UTF8.GetBytes('{"rolledBack":true}')
                $resp.StatusCode        = 200
                $resp.ContentType       = "application/json"
                $resp.ContentLength64   = $ok.Length
                $resp.OutputStream.Write($ok, 0, $ok.Length)
                $resp.OutputStream.Close()
                continue
            }

            # --- /queue endpoint (GET, HMAC-authenticated via query param or header) ---
            if ($urlPath -eq "/queue" -and $req.HttpMethod -eq "GET") {
                $providedSig = $req.Headers["X-HMAC-SHA256"]
                if (-not (Test-HmacSignature -Body "/queue" -ProvidedSig $providedSig -Key $CollectorHmacKey)) {
                    $resp.StatusCode = 401; $resp.OutputStream.Close(); continue
                }
                $queueJson = ($script:RemediationQueue | ConvertTo-Json -Depth 5 -Compress)
                if ([string]::IsNullOrEmpty($queueJson)) { $queueJson = "[]" }
                $body = [System.Text.Encoding]::UTF8.GetBytes($queueJson)
                $resp.StatusCode        = 200
                $resp.ContentType       = "application/json"
                $resp.ContentLength64   = $body.Length
                $resp.OutputStream.Write($body, 0, $body.Length)
                $resp.OutputStream.Close()
                continue
            }

            # Default: 404
            $resp.StatusCode = 404
            $resp.OutputStream.Close()

        } catch [System.Net.HttpListenerException] {
            # Listener was stopped
            break
        } catch {
            Write-AuditLog "Listener error: $_" "ERROR"
        }
    }
}

# --------- GRACEFUL STOP ---------
$null = Register-EngineEvent -SourceIdentifier "PowerShell.Exiting" -Action {
    if ($null -ne $script:Listener -and $script:Listener.IsListening) {
        $script:Listener.Stop()
        Write-AuditLog "Collector listener stopped"
    }
}

# --------- START ---------
Write-AuditLog "UltraSecurityCollector started (DryRun=$DryRun Port=$Port)"
Write-Host "🔒 Ultra Security Collector starting…"
Write-Host "   Audit log: $AuditLogPath"
Write-Host "   SIEM log:  $SiemLogPath"
Write-Host "   Queue:     $QueuePath"
Write-Host "   Rollback:  $RollbackPath"
Write-Host ""
Write-Host "ℹ️  To provision secrets run:"
Write-Host "   Set-UltraCollectorCredential -Target 'UltraSecurityCollector/VirusTotal'   -Secret '<api-key>'"
Write-Host "   Set-UltraCollectorCredential -Target 'UltraSecurityCollector/Discord'      -Secret '<webhook-url>'"
Write-Host "   Set-UltraCollectorCredential -Target 'UltraSecurityCollector/SMTP'         -Secret '<password>'"
Write-Host "   Set-UltraCollectorCredential -Target 'UltraSecurityCollector/CollectorHmac' -Secret '<shared-hmac-key>'"
Write-Host ""
Write-Host "   Approve remediation:  POST /approve  {requestId, approvedBy}"
Write-Host "   Rollback remediation: POST /rollback {requestId}"
Write-Host "   View queue:           GET  /queue"

Start-CollectorListener
