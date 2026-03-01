# UltraSecurityMonitor.ps1
# Ultra Security Monitor – Total Edition (Hardened Agent)
# Uruchom jako Administrator.
# API keys are stored in Windows Credential Manager, NOT in this file.
# Use Set-UltraMonitorCredential to provision secrets before first run.

#Requires -Version 5.1

# --------- KONFIGURACJA ---------
$BaseFolder   = Join-Path $env:USERPROFILE "Documents\SecurityMonitor"
$BackupFolder = Join-Path $BaseFolder "Backup"
$SiemFolder   = Join-Path $BaseFolder "SIEM"

foreach ($dir in @($BaseFolder, $BackupFolder, $SiemFolder)) {
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
}

$LogPath       = Join-Path $BaseFolder "security.log"
$ReportPath    = Join-Path $BaseFolder "security-report.txt"
$DashboardPath = Join-Path $BaseFolder "dashboard.html"
$SiemLogPath   = Join-Path $SiemFolder  "siem.json"

# Collector endpoint (local loopback only)
$CollectorUrl   = "http://127.0.0.1:18443"

# E-mail alerts configuration (server/address set here; password via Credential Manager)
$EmailAlerts  = $false
$SmtpServer   = ""
$SmtpFrom     = ""
$SmtpTo       = ""
$SmtpUseSsl   = $true
$SmtpPort     = 587

# Dry-run mode: when $true no destructive actions (Stop-Process / Remove-Item) are taken.
# Set to $false only after operator review and with VT confirmation.
$DryRun = $true

# Foldery do monitorowania
$MonitoredFolders = @(
    "$env:windir\System32",
    "$env:ProgramFiles",
    "${env:ProgramFiles(x86)}",
    "$env:USERPROFILE\Documents",
    "$env:USERPROFILE\Desktop"
)

# Heurystyka / whitelist
$SuspiciousNames        = @("wscript.exe","cscript.exe","mshta.exe","rundll32.exe","pwsh.exe","cmd.exe")
$SuspiciousPathPatterns = @("*\AppData\Local\Temp\*","*\Temp\*","*\AppData\Roaming\*")
$DefaultWhitelist       = @(
    "$env:windir\*",
    "$env:ProgramFiles\*",
    "${env:ProgramFiles(x86)}\*",
    "*\OneDrive\*",
    "*\Steam\*",
    "*\ProtonVPN\*"
)

$MaxLogSizeMB        = 50
$MaxDiscordMsgLength = 1800   # conservative limit; remainder used for redaction notice

# Log encryption: when $true each log/SIEM entry is AES-256-CBC encrypted.
# Key is auto-generated on first run and stored in Windows Credential Manager (DPAPI).
$EncryptLogs = $true

# VT rate-limit and cache settings
$script:VTCache            = @{}
$script:VTCacheTtlSeconds  = 3600        # 1 hour
$script:VTRateLimitMs      = 15100       # ~4 calls/min (public API limit)
$script:VTLastCallTime     = [datetime]::MinValue
$script:VTDailyCount       = 0
$script:VTDailyLimit       = 450         # conservative guard under 500/day
$script:VTDailyResetDate   = [datetime]::Today.Date

# --------- SECRETS MANAGEMENT (Windows Credential Manager / DPAPI) ---------
function Get-UltraMonitorSecret {
    <#
    .SYNOPSIS  Retrieves a secret from Windows Credential Manager (PasswordVault).
    .NOTES     Secrets are encrypted with DPAPI and bound to the current user account.
    #>
    param([string]$Target)
    try {
        Add-Type -AssemblyName Windows.Security -ErrorAction SilentlyContinue
        $vault = New-Object Windows.Security.Credentials.PasswordVault
        $cred  = $vault.Retrieve($Target, "UltraSecurityMonitor")
        $cred.RetrievePassword()
        return $cred.Password
    } catch { return $null }
}

function Set-UltraMonitorCredential {
    <#
    .SYNOPSIS  Stores a secret in Windows Credential Manager (PasswordVault / DPAPI).
    .EXAMPLE   Set-UltraMonitorCredential -Target "UltraSecurityMonitor/VirusTotal" -Secret "your-api-key"
    #>
    param([string]$Target, [string]$Secret)
    try {
        Add-Type -AssemblyName Windows.Security -ErrorAction SilentlyContinue
        $vault = New-Object Windows.Security.Credentials.PasswordVault
        $cred  = New-Object Windows.Security.Credentials.PasswordCredential($Target, "UltraSecurityMonitor", $Secret)
        $vault.Add($cred)
        Write-Host "Secret '$Target' stored in Credential Manager."
    } catch {
        Write-Warning "Failed to store secret '$Target': $_"
    }
}

# Load API keys at runtime from Credential Manager – never hardcoded in script
$VirusTotalApiKey  = Get-UltraMonitorSecret -Target "UltraSecurityMonitor/VirusTotal"
$DiscordWebhookUrl = Get-UltraMonitorSecret -Target "UltraSecurityMonitor/Discord"
$SmtpPassword      = Get-UltraMonitorSecret -Target "UltraSecurityMonitor/SMTP"
$CollectorHmacKey  = Get-UltraMonitorSecret -Target "UltraSecurityMonitor/CollectorHmac"

# --------- ACL PROTECTION FOR LOG DIRECTORIES ---------
function Set-RestrictedAcl {
    <#
    .SYNOPSIS  Removes inherited permissions and grants FullControl only to Administrators and SYSTEM.
    #>
    param([string]$Path)
    try {
        $acl = Get-Acl -Path $Path -ErrorAction Stop
        $acl.SetAccessRuleProtection($true, $false)  # break inheritance, remove inherited rules
        $adminSid  = New-Object System.Security.Principal.SecurityIdentifier(
            [System.Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid, $null)
        $systemSid = New-Object System.Security.Principal.SecurityIdentifier(
            [System.Security.Principal.WellKnownSidType]::LocalSystemSid, $null)
        $inherit   = [System.Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit'
        $none      = [System.Security.AccessControl.PropagationFlags]::None
        $allow     = [System.Security.AccessControl.AccessControlType]::Allow
        $acl.AddAccessRule(
            (New-Object System.Security.AccessControl.FileSystemAccessRule($adminSid,  "FullControl", $inherit, $none, $allow)))
        $acl.AddAccessRule(
            (New-Object System.Security.AccessControl.FileSystemAccessRule($systemSid, "FullControl", $inherit, $none, $allow)))
        Set-Acl -Path $Path -AclObject $acl -ErrorAction SilentlyContinue
    } catch { Write-Log "Set-RestrictedAcl error for '$Path': $_" }
}

# Apply ACL immediately after directories are confirmed to exist
foreach ($dir in @($BaseFolder, $BackupFolder, $SiemFolder)) { Set-RestrictedAcl -Path $dir }
# Request EFS encryption on all log/backup directories (no-op on non-NTFS or unsupported systems)
# Enable-EfsEncryption is defined below; we defer the call to after function definitions.
$script:ApplyEfsOnStart = $true
# --------- REDACTION ---------
function Invoke-Redact {
    <#
    .SYNOPSIS  Scrubs sensitive tokens from a string before it enters logs or alerts.
               Redacts: IPv4 addresses, UNC paths, full filesystem paths (keeps filename),
               command-line arguments (keeps executable name).
    #>
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return $Text }

    # Redact IPv4 addresses
    $Text = $Text -replace '\b(?:\d{1,3}\.){3}\d{1,3}\b', '[IP-REDACTED]'

    # Redact UNC paths  \\server\share\...
    $Text = $Text -replace '\\\\[^\\/ \t\r\n]+\\[^\s]+', '[UNC-REDACTED]'

    # Redact absolute Windows paths but keep the filename leaf
    # Matches drive-letter paths like C:\Windows\System32\foo.exe → [PATH]\foo.exe
    $Text = $Text -replace '(?i)[A-Za-z]:\\(?:[^\\/:*?"<>|\r\n]+\\)+([^\\/:*?"<>|\r\n\s]+)', '[PATH]\$1'

    # Redact command-line arguments (anything after the first space following the exe name)
    # Pattern: word.exe <anything>  →  word.exe [ARGS-REDACTED]
    $Text = $Text -replace '(?i)([\w.-]+\.exe)\s+[^\r\n]+', '$1 [ARGS-REDACTED]'

    return $Text
}

# --------- RETRY / BACKOFF HELPER ---------
function Invoke-WithRetry {
    <#
    .SYNOPSIS  Executes a scriptblock up to MaxAttempts times with exponential backoff.
    #>
    param(
        [scriptblock]$ScriptBlock,
        [int]$MaxAttempts = 3,
        [int]$BaseDelayMs = 1000
    )
    $attempt = 0
    while ($attempt -lt $MaxAttempts) {
        $attempt++
        try {
            return (& $ScriptBlock)
        } catch {
            if ($attempt -ge $MaxAttempts) { throw }
            $delayMs = [int]($BaseDelayMs * [Math]::Pow(2, $attempt - 1))
            Start-Sleep -Milliseconds $delayMs
        }
    }
}

# --------- HMAC HELPER ---------
function New-HmacSha256 {
    <#
    .SYNOPSIS  Returns a Base64-encoded HMAC-SHA256 signature of $Data using $Key.
    #>
    param([string]$Data, [string]$Key)
    try {
        $keyBytes  = [System.Text.Encoding]::UTF8.GetBytes($Key)
        $dataBytes = [System.Text.Encoding]::UTF8.GetBytes($Data)
        $hmac      = New-Object System.Security.Cryptography.HMACSHA256
        $hmac.Key  = $keyBytes
        return [Convert]::ToBase64String($hmac.ComputeHash($dataBytes))
    } catch { return $null }
}

# --------- ENCRYPTED LOG SUPPORT (AES-256-CBC + optional EFS) ---------
function Get-LogEncryptionKey {
    <#
    .SYNOPSIS  Returns the 32-byte AES key for log encryption.
               Auto-generates and persists a new random key in Credential Manager on first use.
    #>
    $b64 = Get-UltraMonitorSecret -Target "UltraSecurityMonitor/LogKey"
    if ([string]::IsNullOrWhiteSpace($b64)) {
        $keyBytes = New-Object byte[] 32
        [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($keyBytes)
        $b64 = [Convert]::ToBase64String($keyBytes)
        Set-UltraMonitorCredential -Target "UltraSecurityMonitor/LogKey" -Secret $b64
    }
    return [Convert]::FromBase64String($b64)
}

function Write-EncryptedLogEntry {
    <#
    .SYNOPSIS  AES-256-CBC encrypts $Entry and appends "base64(IV):base64(cipher)" to $Path.
               Falls back to plaintext if encryption is unavailable.
    #>
    param([string]$Path, [string]$Entry)
    try {
        $key = Get-LogEncryptionKey
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Key     = $key
        $aes.Mode    = [System.Security.Cryptography.CipherMode]::CBC
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        $aes.GenerateIV()
        $iv        = $aes.IV
        $data      = [System.Text.Encoding]::UTF8.GetBytes($Entry)
        $enc       = $aes.CreateEncryptor()
        $cipher    = $enc.TransformFinalBlock($data, 0, $data.Length)
        $line      = [Convert]::ToBase64String($iv) + ":" + [Convert]::ToBase64String($cipher)
        Add-Content -Path $Path -Value $line
    } catch {
        # Fallback to plaintext so no events are silently dropped
        Add-Content -Path $Path -Value $Entry
    }
}

function Read-EncryptedLog {
    <#
    .SYNOPSIS  Decrypts and returns all entries from an AES-encrypted log file.
    #>
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    $key = Get-LogEncryptionKey
    Get-Content -Path $Path | ForEach-Object {
        $parts = $_ -split ':', 2
        if ($parts.Count -eq 2) {
            try {
                $aes = [System.Security.Cryptography.Aes]::Create()
                $aes.Key     = $key
                $aes.Mode    = [System.Security.Cryptography.CipherMode]::CBC
                $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
                $aes.IV      = [Convert]::FromBase64String($parts[0])
                $dec    = $aes.CreateDecryptor()
                $cipher = [Convert]::FromBase64String($parts[1])
                [System.Text.Encoding]::UTF8.GetString($dec.TransformFinalBlock($cipher, 0, $cipher.Length))
            } catch { $_ }  # return raw line if decryption fails
        } else { $_ }
    }
}

function Enable-EfsEncryption {
    <#
    .SYNOPSIS  Applies Windows EFS encryption to a file or folder using cipher.exe.
               Silently skipped on systems where EFS is unavailable (e.g., non-NTFS).
    #>
    param([string]$Path)
    try {
        $output = & cipher.exe /e /s:"$Path" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "EFS encryption skipped for '$Path' (cipher.exe exit $LASTEXITCODE): $output"
        }
    } catch {
        Write-Log "EFS encryption failed for '$Path': $_"
    }
}


function Write-Log {
    param([string]$msg)
    $ts    = (Get-Date).ToString("o")
    $entry = "$ts`t$(Invoke-Redact $msg)"
    if ($EncryptLogs) {
        Write-EncryptedLogEntry -Path $LogPath -Entry $entry
    } else {
        Add-Content -Path $LogPath -Value $entry
    }
    try {
        $sizeMB = (Get-Item $LogPath -ErrorAction SilentlyContinue).Length / 1MB
        if ($sizeMB -gt $MaxLogSizeMB) {
            $arch = Join-Path $BaseFolder ("security-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
            Move-Item -Path $LogPath -Destination $arch -Force
            Enable-EfsEncryption -Path $arch
            Write-EncryptedLogEntry -Path $LogPath -Entry ("$(Get-Date -Format o)`tLog rotated")
        }
    } catch {}
}

function Write-SiemEvent {
    param([string]$EventType, [string]$Severity, [hashtable]$Data)
    # Redact each string value before persisting
    $safeData = @{}
    foreach ($k in $Data.Keys) {
        $v = $Data[$k]
        $safeData[$k] = if ($v -is [string]) { Invoke-Redact $v } else { $v }
    }
    $event = [ordered]@{
        timestamp  = (Get-Date).ToString("o")
        host       = $env:COMPUTERNAME
        user       = $env:USERNAME
        event_type = $EventType
        severity   = $Severity
        data       = $safeData
    }
    $line = $event | ConvertTo-Json -Compress
    try {
        if ($EncryptLogs) {
            Write-EncryptedLogEntry -Path $SiemLogPath -Entry $line
        } else {
            Add-Content -Path $SiemLogPath -Value $line
        }
    } catch {}
}

function Get-Whitelist {
    $wlFile = Join-Path $BaseFolder "whitelist.json"
    if (Test-Path $wlFile) {
        try { return (Get-Content $wlFile -Raw | ConvertFrom-Json) -as [string[]] }
        catch { return $DefaultWhitelist }
    }
    return $DefaultWhitelist
}

function Test-PathWhitelisted {
    param([string]$FilePath, [string[]]$Whitelist)
    if (-not $FilePath) { return $false }
    foreach ($pattern in $Whitelist) {
        if ($FilePath -like $pattern) { return $true }
    }
    return $false
}

function Test-ProcessSuspicious {
    param([string]$ProcName, [string]$FilePath)
    $wl = Get-Whitelist
    if (Test-PathWhitelisted -FilePath $FilePath -Whitelist $wl) { return $false }
    foreach ($p in $SuspiciousPathPatterns) { if ($FilePath -like $p) { return $true } }
    foreach ($n in $SuspiciousNames) { if ($ProcName -ieq $n) { return $true } }
    if ($FilePath -and
        -not ($FilePath -like "$env:windir\*") -and
        -not ($FilePath -like "$env:ProgramFiles\*") -and
        -not ($FilePath -like "${env:ProgramFiles(x86)}\*")) {
        return $true
    }
    return $false
}

function Send-DiscordAlert {
    param([string]$Message)
    if ([string]::IsNullOrWhiteSpace($DiscordWebhookUrl)) { return }
    # Redact before sending
    $safe = Invoke-Redact $Message
    if ($safe.Length -gt $MaxDiscordMsgLength) {
        $safe = $safe.Substring(0, $MaxDiscordMsgLength - 3) + "..."
    }
    $payload = @{ content = $safe } | ConvertTo-Json
    try {
        Invoke-WithRetry -MaxAttempts 3 -BaseDelayMs 2000 -ScriptBlock {
            Invoke-RestMethod -Uri $DiscordWebhookUrl -Method Post -Body $payload `
                -ContentType "application/json" -TimeoutSec 10 -ErrorAction Stop
        }
    } catch {}
}

function Send-EmailAlert {
    param([string]$Subject, [string]$Body)
    if (-not $EmailAlerts) { return }
    if ([string]::IsNullOrWhiteSpace($SmtpServer) -or
        [string]::IsNullOrWhiteSpace($SmtpFrom)   -or
        [string]::IsNullOrWhiteSpace($SmtpTo)) { return }
    $safeBody    = Invoke-Redact $Body
    $safeSubject = Invoke-Redact $Subject
    try {
        $params = @{
            To         = $SmtpTo
            From       = $SmtpFrom
            Subject    = $safeSubject
            Body       = $safeBody
            SmtpServer = $SmtpServer
            Port       = $SmtpPort
            UseSsl     = $SmtpUseSsl
        }
        if (-not [string]::IsNullOrWhiteSpace($SmtpPassword)) {
            $secPwd  = ConvertTo-SecureString $SmtpPassword -AsPlainText -Force
            $params['Credential'] = New-Object System.Management.Automation.PSCredential($SmtpFrom, $secPwd)
        }
        Invoke-WithRetry -MaxAttempts 3 -BaseDelayMs 2000 -ScriptBlock {
            Send-MailMessage @params -ErrorAction Stop
        }
    } catch {}
}

# --------- COLLECTOR TELEMETRY ---------
function Send-CollectorEvent {
    <#
    .SYNOPSIS  Sends a minimal telemetry event to the local Collector over loopback HTTP.
               The payload is signed with HMAC-SHA256 to authenticate the agent.
    #>
    param([string]$EventType, [string]$Severity, [hashtable]$Data)
    if ([string]::IsNullOrWhiteSpace($CollectorHmacKey)) { return }

    $safeData = @{}
    foreach ($k in $Data.Keys) {
        $v = $Data[$k]
        $safeData[$k] = if ($v -is [string]) { Invoke-Redact $v } else { $v }
    }

    $body = [ordered]@{
        timestamp  = (Get-Date).ToString("o")
        host       = $env:COMPUTERNAME
        event_type = $EventType
        severity   = $Severity
        data       = $safeData
    } | ConvertTo-Json -Compress

    $sig = New-HmacSha256 -Data $body -Key $CollectorHmacKey
    if ($null -eq $sig) { return }

    try {
        Invoke-WithRetry -MaxAttempts 3 -BaseDelayMs 1000 -ScriptBlock {
            Invoke-RestMethod -Uri "$CollectorUrl/event" -Method Post `
                -Body $body -ContentType "application/json" `
                -Headers @{ "X-HMAC-SHA256" = $sig } `
                -TimeoutSec 5 -ErrorAction Stop
        }
    } catch {}
}

# --------- INTEGRACJA VIRUSTOTAL (with TTL cache and rate limiting) ---------
function Get-VirusTotalReport {
    param([string]$Hash)
    if ([string]::IsNullOrWhiteSpace($VirusTotalApiKey) -or [string]::IsNullOrWhiteSpace($Hash)) {
        return $null
    }

    # Input validation: SHA-256 is exactly 64 hex characters
    if ($Hash -notmatch '^[0-9a-fA-F]{64}$') { return $null }

    # Daily quota guard
    if ([datetime]::Today.Date -gt $script:VTDailyResetDate) {
        $script:VTDailyCount     = 0
        $script:VTDailyResetDate = [datetime]::Today.Date
    }
    if ($script:VTDailyCount -ge $script:VTDailyLimit) { return $null }

    # TTL cache lookup
    if ($script:VTCache.ContainsKey($Hash)) {
        $entry = $script:VTCache[$Hash]
        if (((Get-Date) - $entry.CachedAt).TotalSeconds -lt $script:VTCacheTtlSeconds) {
            return $entry.Result
        }
    }

    # Rate limiting: enforce minimum interval between API calls
    $elapsed = ((Get-Date) - $script:VTLastCallTime).TotalMilliseconds
    if ($elapsed -lt $script:VTRateLimitMs) {
        Start-Sleep -Milliseconds ([int]($script:VTRateLimitMs - $elapsed))
    }

    try {
        $uri     = "https://www.virustotal.com/api/v3/files/$Hash"
        $headers = @{ "x-apikey" = $VirusTotalApiKey }
        $resp    = Invoke-WithRetry -MaxAttempts 3 -BaseDelayMs 5000 -ScriptBlock {
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
        return $result
    } catch {
        $script:VTLastCallTime = Get-Date
        return $null
    }
}

# --------- NARZĘDZIA SYSTEMOWE ---------
function Get-ProcDetails {
    param([int]$Pid)
    if ($Pid -le 0) { return $null }
    try {
        $proc = Get-CimInstance Win32_Process -Filter "ProcessId = $Pid" -ErrorAction SilentlyContinue
        if ($null -eq $proc) { return $null }
        $ownerInfo = $null
        try { $ownerInfo = Invoke-CimMethod -InputObject $proc -MethodName GetOwner } catch {}
        return [PSCustomObject]@{
            Name        = $proc.Name
            PID         = $proc.ProcessId
            Path        = $proc.ExecutablePath
            CommandLine = $proc.CommandLine
            ParentPID   = $proc.ParentProcessId
            Owner       = if ($null -ne $ownerInfo) { "$($ownerInfo.Domain)\$($ownerInfo.User)" } else { "unknown" }
        }
    } catch { return $null }
}

function Get-NetworkConnsForPid {
    param([int]$Pid)
    if ($Pid -le 0) { return $null }
    try {
        $tcp = Get-NetTCPConnection -ErrorAction SilentlyContinue | Where-Object { $_.OwningProcess -eq $Pid }
        $udp = Get-NetUDPEndpoint  -ErrorAction SilentlyContinue | Where-Object { $_.OwningProcess -eq $Pid }
        return [PSCustomObject]@{ TCP = $tcp; UDP = $udp }
    } catch { return $null }
}

function Get-FileSignatureStatus {
    param([string]$FilePath)
    if (-not $FilePath -or -not (Test-Path $FilePath)) { return "no-file" }
    try {
        $sig = Get-AuthenticodeSignature -FilePath $FilePath -ErrorAction SilentlyContinue
        if ($null -eq $sig) { return "no-signature" }
        return $sig.Status.ToString()
    } catch { return "sig-check-failed" }
}

function Get-FileHashSafe {
    param([string]$FilePath)
    if ([string]::IsNullOrWhiteSpace($FilePath)) { return $null }
    try {
        if (Test-Path $FilePath) { return (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash }
    } catch {}
    return $null
}

function Backup-FileToStore {
    param([string]$FilePath)
    if ([string]::IsNullOrWhiteSpace($FilePath) -or -not (Test-Path $FilePath)) { return }
    try {
        $leaf = Split-Path $FilePath -Leaf
        $dest = Join-Path $BackupFolder ("${leaf}_" + (Get-Date -Format "yyyyMMdd-HHmmss"))
        Copy-Item -Path $FilePath -Destination $dest -Force -ErrorAction SilentlyContinue
        Set-RestrictedAcl -Path $dest
    } catch {}
}

# --------- MONITOR FOLDERÓW (backup przy zmianie) ---------
function Register-FolderMonitor {
    param([string]$Folder)
    if (-not (Test-Path $Folder)) { return }
    try {
        $fsw = New-Object System.IO.FileSystemWatcher $Folder -Property @{
            IncludeSubdirectories = $true
            NotifyFilter          = [System.IO.NotifyFilters]'FileName, LastWrite'
            Filter                = "*.*"
        }
        $action = {
            $path       = $Event.SourceEventArgs.FullPath
            $changeType = $Event.SourceEventArgs.ChangeType
            # Redact the path in user-visible messages; keep only the leaf name
            $safePath   = Split-Path $path -Leaf
            $msg        = "File $($changeType): $safePath"
            Write-Log $msg
            Backup-FileToStore $path
            Write-SiemEvent -EventType "FileChange" -Severity "Low" -Data @{
                path   = $path   # Write-SiemEvent applies Invoke-Redact internally
                change = $changeType.ToString()
            }
            Send-CollectorEvent -EventType "FileChange" -Severity "Low" -Data @{
                path   = $path
                change = $changeType.ToString()
            }
            Send-DiscordAlert $msg
            Send-EmailAlert "File Change Alert" $msg
        }
        Register-ObjectEvent -InputObject $fsw -EventName Created -Action $action | Out-Null
        Register-ObjectEvent -InputObject $fsw -EventName Changed -Action $action | Out-Null
        Register-ObjectEvent -InputObject $fsw -EventName Renamed -Action $action | Out-Null
        $fsw.EnableRaisingEvents = $true
    } catch { Write-Log "Register-FolderMonitor error: $_" }
}

# --------- HANDLER STARTU PROCESU ---------
$procAction = {
    try {
        $evt    = $Event.SourceEventArgs.NewEvent
        $pid    = [int]$evt.ProcessID
        if ($pid -le 0) { return }
        Start-Sleep -Milliseconds 300
        $details = Get-ProcDetails -Pid $pid
        if ($null -eq $details) {
            Write-Log "Process $($evt.ProcessName) PID $pid (details unavailable)"
            return
        }
        $path      = $details.Path
        $sigStatus = Get-FileSignatureStatus -FilePath $path
        $hash      = Get-FileHashSafe -FilePath $path
        $network   = Get-NetworkConnsForPid -Pid $pid

        if (Test-ProcessSuspicious -ProcName $details.Name -FilePath $path) {
            # Build alert with redacted fields
            $safeCmd  = Invoke-Redact $details.CommandLine
            $safePath = Invoke-Redact $path
            $msg  = "⚠️ SUSPECT PROCESS`nName: $($details.Name)`nPID: $pid`nOwner: $($details.Owner)"
            $msg += "`nPath: $safePath`nSig: $sigStatus`nSHA256: $hash`nCmd: $safeCmd"
            if ($null -ne $network -and $null -ne $network.TCP) {
                # Redact remote addresses
                $tcpSummary = $network.TCP |
                    Select-Object LocalPort, RemotePort, State |
                    Out-String
                $msg += "`nTCP (addresses redacted):`n$tcpSummary"
            }

            # VirusTotal lookup (via Collector if available, else direct with cache)
            $vtResult = $null
            if (-not [string]::IsNullOrWhiteSpace($hash)) {
                $vtResult = Get-VirusTotalReport -Hash $hash
                if ($null -ne $vtResult) {
                    $msg += "`nVirusTotal: Malicious=$($vtResult.Malicious) Suspicious=$($vtResult.Suspicious)"
                }
            }

            Write-Log $msg
            Add-Content -Path $ReportPath -Value ("`n`n$(Get-Date -Format o)`n$msg")
            Write-SiemEvent -EventType "SuspiciousProcess" -Severity "High" -Data @{
                name        = $details.Name
                pid         = $pid
                path        = $path       # redacted inside Write-SiemEvent
                hash        = $hash
                sig         = $sigStatus
                commandLine = $details.CommandLine  # redacted inside Write-SiemEvent
                owner       = $details.Owner
                vtMalicious = if ($null -ne $vtResult) { $vtResult.Malicious } else { $null }
            }

            # Forward to Collector for operator-reviewed remediation decision
            Send-CollectorEvent -EventType "SuspiciousProcess" -Severity "High" -Data @{
                name        = $details.Name
                pid         = $pid
                hash        = $hash
                sig         = $sigStatus
                vtMalicious = if ($null -ne $vtResult) { $vtResult.Malicious } else { $null }
                dryRun      = $DryRun
            }

            Send-DiscordAlert $msg
            Send-EmailAlert -Subject "Suspicious Process Alert" -Body $msg

            # Remediation: only executed when DryRun=$false AND VT confirms malicious AND Collector approves.
            # Direct Stop-Process / Remove-Item is intentionally absent here; the Collector
            # handles approved remediation via the operator-confirmation workflow.
            if (-not $DryRun) {
                Write-Log "DryRun=false: remediation delegated to Collector for PID $pid"
            }
        }
    } catch { Write-Log "procAction error: $_" }
}

# --------- REJESTRACJA ZDARZENIA STARTU PROCESU ---------
$sourceId = "UltraSecurityMonitor-Process"
Get-EventSubscriber -ErrorAction SilentlyContinue |
    Where-Object { $_.SourceIdentifier -eq $sourceId } |
    Unregister-Event -Force -ErrorAction SilentlyContinue
Register-WmiEvent -Class Win32_ProcessStartTrace -SourceIdentifier $sourceId -Action $procAction | Out-Null

# --------- URUCHOM MONITORY FOLDERÓW ---------
foreach ($folder in $MonitoredFolders) { Register-FolderMonitor -Folder $folder }

# --------- PODSTAWOWE INFO I START ---------
# Apply EFS encryption to log directories now that Enable-EfsEncryption is defined
if ($script:ApplyEfsOnStart) {
    foreach ($dir in @($BaseFolder, $BackupFolder, $SiemFolder)) { Enable-EfsEncryption -Path $dir }
}
Write-Log "Ultra Security Monitor Total Edition started (DryRun=$DryRun EncryptLogs=$EncryptLogs)"
Write-Host "🎯 Ultra Security Monitor aktywny. DryRun=$DryRun"
Write-Host "   Logi:      $LogPath"
Write-Host "   Raporty:   $ReportPath"
Write-Host "   SIEM JSON: $SiemLogPath"
Write-Host "   Dashboard: $DashboardPath"
Write-Host "   Collector: $CollectorUrl"
Write-Host ""
Write-Host "ℹ️  To provision secrets run:"
Write-Host "   Set-UltraMonitorCredential -Target 'UltraSecurityMonitor/VirusTotal'      -Secret '<api-key>'"
Write-Host "   Set-UltraMonitorCredential -Target 'UltraSecurityMonitor/Discord'         -Secret '<webhook-url>'"
Write-Host "   Set-UltraMonitorCredential -Target 'UltraSecurityMonitor/SMTP'            -Secret '<password>'"
Write-Host "   Set-UltraMonitorCredential -Target 'UltraSecurityMonitor/CollectorHmac'   -Secret '<shared-hmac-key>'"

# --------- PRZYKŁAD TWORZENIA SCHEDULED TASK (uruchom jako admin) ---------
# $ScriptPath = Join-Path $BaseFolder "UltraSecurityMonitor.ps1"
# $action     = New-ScheduledTaskAction -Execute "powershell.exe" `
#                   -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""
# $trigger    = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
# Register-ScheduledTask -Action $action -Trigger $trigger `
#     -TaskName "UltraSecurityMonitor" -RunLevel Highest -Force
