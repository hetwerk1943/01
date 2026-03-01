# UltraSecurityMonitor.ps1
# Kompletny skrypt Ultra Security Monitor – Total Edition
# Uruchom jako Administrator. Skonfiguruj klucze API w sekcji KONFIGURACJA.

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

# Discord webhook (opcjonalnie – wklej URL lub pozostaw pusty)
$DiscordWebhookUrl = ""

# VirusTotal API (opcjonalnie – wklej klucz lub pozostaw pusty)
$VirusTotalApiKey = ""

# E-mail alerty (ustaw $true i skonfiguruj poniższe zmienne)
$EmailAlerts  = $false
$SmtpServer   = ""
$SmtpFrom     = ""
$SmtpTo       = ""
$SmtpUseSsl   = $true
$SmtpPort     = 587

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
$MaxDiscordMsgLength = 2000

# --------- FUNKCJE LOG I ALERTY ---------
function Write-Log {
    param([string]$msg)
    $ts    = (Get-Date).ToString("o")
    $entry = "$ts`t$msg"
    Add-Content -Path $LogPath -Value $entry
    try {
        $sizeMB = (Get-Item $LogPath -ErrorAction SilentlyContinue).Length / 1MB
        if ($sizeMB -gt $MaxLogSizeMB) {
            $arch = Join-Path $BaseFolder ("security-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
            Move-Item -Path $LogPath -Destination $arch -Force
            Add-Content -Path $LogPath -Value ("$(Get-Date -Format o)`tLog rotated -> $arch")
        }
    } catch {}
}

function Write-SiemEvent {
    param([string]$EventType, [string]$Severity, [hashtable]$Data)
    $event = [ordered]@{
        timestamp  = (Get-Date).ToString("o")
        host       = $env:COMPUTERNAME
        user       = $env:USERNAME
        event_type = $EventType
        severity   = $Severity
        data       = $Data
    }
    try {
        Add-Content -Path $SiemLogPath -Value ($event | ConvertTo-Json -Compress)
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
    # Skróć wiadomość do limitu Discord (2000 znaków)
    if ($Message.Length -gt $MaxDiscordMsgLength) {
        $Message = $Message.Substring(0, $MaxDiscordMsgLength - 3) + "..."
    }
    $payload = @{ content = $Message } | ConvertTo-Json
    try {
        Invoke-RestMethod -Uri $DiscordWebhookUrl -Method Post -Body $payload `
            -ContentType "application/json" -TimeoutSec 10 -ErrorAction SilentlyContinue
    } catch {}
}

function Send-EmailAlert {
    param([string]$Subject, [string]$Body)
    if (-not $EmailAlerts) { return }
    if ([string]::IsNullOrWhiteSpace($SmtpServer) -or
        [string]::IsNullOrWhiteSpace($SmtpFrom)   -or
        [string]::IsNullOrWhiteSpace($SmtpTo)) { return }
    try {
        $params = @{
            To         = $SmtpTo
            From       = $SmtpFrom
            Subject    = $Subject
            Body       = $Body
            SmtpServer = $SmtpServer
            Port       = $SmtpPort
            UseSsl     = $SmtpUseSsl
        }
        Send-MailMessage @params -ErrorAction SilentlyContinue
    } catch {}
}

# --------- INTEGRACJA VIRUSTOTAL ---------
function Get-VirusTotalReport {
    param([string]$Hash)
    if ([string]::IsNullOrWhiteSpace($VirusTotalApiKey) -or [string]::IsNullOrWhiteSpace($Hash)) {
        return $null
    }
    try {
        $uri     = "https://www.virustotal.com/api/v3/files/$Hash"
        $headers = @{ "x-apikey" = $VirusTotalApiKey }
        $resp    = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get `
                       -TimeoutSec 15 -ErrorAction SilentlyContinue
        $stats   = $resp.data.attributes.last_analysis_stats
        if ($null -eq $stats) { return $null }
        return [PSCustomObject]@{
            Malicious  = $stats.malicious
            Suspicious = $stats.suspicious
            Undetected = $stats.undetected
            Harmless   = $stats.harmless
        }
    } catch { return $null }
}

# --------- NARZĘDZIA SYSTEMOWE ---------
function Get-ProcDetails {
    param([int]$Pid)
    try {
        $proc = Get-CimInstance Win32_Process -Filter "ProcessId = $Pid" -ErrorAction SilentlyContinue
        if ($null -eq $proc) { return $null }
        $ownerInfo = $null
        try { $ownerInfo = Invoke-CimMethod -InputObject $proc -MethodName GetOwner } catch {}
        return [PSCustomObject]@{
            Name           = $proc.Name
            PID            = $proc.ProcessId
            ExecutablePath = $proc.ExecutablePath
            CommandLine    = $proc.CommandLine
            ParentPID      = $proc.ParentProcessId
            Owner          = if ($null -ne $ownerInfo) { "$($ownerInfo.Domain)\$($ownerInfo.User)" } else { "unknown" }
        }
    } catch { return $null }
}

function Get-NetworkConnsForPid {
    param([int]$Pid)
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
    try {
        if (Test-Path $FilePath) { return (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash }
    } catch {}
    return $null
}

function Write-SecureLog {
    param([string]$msg)
    # Strip potential log-injection characters before writing
    $safe = $msg -replace "[\r\n\t]", " "
    Write-Log $safe
}

function Get-VT-Cache {
    param([string]$Hash, [string]$CacheFile)
    if ([string]::IsNullOrWhiteSpace($Hash) -or -not (Test-Path $CacheFile)) { return $null }
    try {
        $cache = Get-Content $CacheFile -Raw | ConvertFrom-Json
        if ($null -ne $cache.$Hash) { return $cache.$Hash }
    } catch {}
    return $null
}

function Update-VT-Cache {
    param([string]$Hash, [object]$Result, [string]$CacheFile)
    if ([string]::IsNullOrWhiteSpace($Hash) -or $null -eq $Result) { return }
    try {
        $cache = if (Test-Path $CacheFile) {
            Get-Content $CacheFile -Raw | ConvertFrom-Json
        } else {
            [PSCustomObject]@{}
        }
        $cache | Add-Member -NotePropertyName $Hash -NotePropertyValue $Result -Force
        $cache | ConvertTo-Json -Compress | Set-Content -Path $CacheFile -Force
    } catch {}
}

# Collector endpoint (optional – set URL or leave empty)
$CollectorUrl = ""

function Send-CollectorAlert {
    param([hashtable]$Payload)
    try {
        Write-SiemEvent -EventType "ProcessAlert" -Severity "High" -Data $Payload
    } catch {}
    if ([string]::IsNullOrWhiteSpace($CollectorUrl)) { return }
    try {
        $body = $Payload | ConvertTo-Json -Compress
        Invoke-RestMethod -Uri $CollectorUrl -Method Post -Body $body `
            -ContentType "application/json" -TimeoutSec 10 -ErrorAction SilentlyContinue
    } catch {}
}

function Backup-FileToStore {
    param([string]$FilePath)
    if (-not (Test-Path $FilePath)) { return }
    try {
        $leaf = Split-Path $FilePath -Leaf
        $dest = Join-Path $BackupFolder ("${leaf}_" + (Get-Date -Format "yyyyMMdd-HHmmss"))
        Copy-Item -Path $FilePath -Destination $dest -Force -ErrorAction SilentlyContinue
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
            $msg        = "File ${changeType}: $path"
            Write-Log $msg
            Backup-FileToStore $path
            Write-SiemEvent -EventType "FileChange" -Severity "Low" -Data @{ path = $path; change = $changeType.ToString() }
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
        $evt       = $Event.SourceEventArgs.NewEvent
        $processId = $evt.ProcessId
        $details   = Get-ProcDetails -Pid $processId
        if ($null -eq $details) { return }

        # Safe fields only
        $hash = Get-FileHashSafe -FilePath $details.ExecutablePath
        $safeMsg = @{
            ProcessName = $details.Name
            Hash        = $hash
            Host        = $env:COMPUTERNAME
            Timestamp   = (Get-Date).ToString("o")
        }

        # Local VT cache lookup
        $vtCacheFile = "$env:TEMP\vt_cache.json"
        $vtResult = Get-VT-Cache -Hash $hash -CacheFile $vtCacheFile
        if (-not $vtResult) {
            $vtResult = Get-VirusTotalReport -Hash $hash
            if ($null -ne $vtResult) {
                Update-VT-Cache -Hash $hash -Result $vtResult -CacheFile $vtCacheFile
            }
        }
        $safeMsg['VirusTotal'] = $vtResult

        # Secure logging
        Write-SecureLog ($safeMsg | ConvertTo-Json -Compress)

        # Send to central collector
        Send-CollectorAlert -Payload $safeMsg

    } catch {
        Write-SecureLog "procAction error: $_"
    }
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
Write-Log "Ultra Security Monitor Total Edition started by $($env:USERNAME)"
Write-Host "🎯 Ultra Security Monitor aktywny."
Write-Host "   Logi:      $LogPath"
Write-Host "   Raporty:   $ReportPath"
Write-Host "   SIEM JSON: $SiemLogPath"
Write-Host "   Dashboard: $DashboardPath"

# --------- PRZYKŁAD TWORZENIA SCHEDULED TASK (uruchom jako admin) ---------
# $ScriptPath = Join-Path $BaseFolder "UltraSecurityMonitor.ps1"
# $action     = New-ScheduledTaskAction -Execute "powershell.exe" `
#                   -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""
# $trigger    = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
# Register-ScheduledTask -Action $action -Trigger $trigger `
#     -TaskName "UltraSecurityMonitor" -RunLevel Highest -Force
