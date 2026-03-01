# UltraSecurityMonitor.ps1
# Kompletny skrypt Ultra Security Monitor – Total Edition
# Uruchom jako Administrator. Skonfiguruj klucze API w sekcji KONFIGURACJA.

#Requires -Version 5.1

# --------- KONFIGURACJA ---------
$EnableDryRun      = $true
$EnableRemediation = $false
Import-Module (Join-Path $PSScriptRoot 'SecureHelpers.psm1') -Force
Set-Variable -Name 'EnableDryRun'      -Value $EnableDryRun      -Scope Global
Set-Variable -Name 'EnableRemediation' -Value $EnableRemediation -Scope Global

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
            # NOTE: $path logged here is a file path – consider ACL-restricting the log file.
            $msg        = "File $changeType: $path"
            Write-Log $msg
            Backup-FileToStore $path
            Write-SiemEvent -EventType "FileChange" -Severity "Low" -Data @{ path = $path; change = $changeType.ToString() }
            $fileSummary = Build-AlertSummary -ProcessName 'FileMonitor' -Hash '' `
                -HostName $env:COMPUTERNAME -Owner $env:USERNAME -SigStatus 'N/A' -CmdLine $path
            Send-DiscordAlertSafe -Summary $fileSummary -WebhookUrl $DiscordWebhookUrl
            Send-EmailAlertSafe   -Summary $fileSummary -SmtpServer $SmtpServer `
                                  -From $SmtpFrom -To $SmtpTo -Port $SmtpPort -UseSsl $SmtpUseSsl
            # REMEDIATION NOTE: To quarantine changed files, use Execute-RemediationSafe:
            #   Execute-RemediationSafe -Reason "Quarantine $path" -ActionScriptBlock {
            #       Move-ToEncryptedQuarantine -FilePath $path -QuarantineRoot 'C:\Quarantine'
            #   }
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
            # VirusTotal lookup (cached, no raw key in logs)
            $vtResult = $null
            if (-not [string]::IsNullOrWhiteSpace($hash)) {
                $vtResult = Get-VirusTotalReportCached -Hash $hash
            }

            # Build redacted summary (command line args are hashed, not logged raw)
            $summary = Build-AlertSummary `
                -ProcessName $details.Name `
                -Hash        $hash `
                -HostName    $env:COMPUTERNAME `
                -Owner       $details.Owner `
                -SigStatus   $sigStatus `
                -CmdLine     $details.CommandLine

            $logMsg = "⚠️ SUSPECT PROCESS | Name=$($summary.ProcessName) | PID=$pid | Owner=$($summary.Owner) | Sig=$($summary.SigStatus) | Hash=$($summary.Hash) | Cmd=$($summary.Cmd)"
            if ($null -ne $vtResult) {
                $logMsg += " | VT: Malicious=$($vtResult.Malicious) Suspicious=$($vtResult.Suspicious)"
            }

            # NOTE: Log files should be ACL-restricted (SYSTEM/Admin only) or encrypted at rest.
            Write-Log $logMsg
            Add-Content -Path $ReportPath -Value ("`n`n$(Get-Date -Format o)`n$logMsg")

            Write-SiemEvent -EventType "SuspiciousProcess" -Severity "High" -Data @{
                name        = $summary.ProcessName
                pid         = $pid
                hash        = $summary.Hash
                sig         = $summary.SigStatus
                commandLine = $summary.Cmd   # sanitized – args replaced with hash token
                owner       = $summary.Owner
            }

            Send-DiscordAlertSafe -Summary $summary -WebhookUrl $DiscordWebhookUrl
            Send-EmailAlertSafe   -Summary $summary -SmtpServer $SmtpServer `
                                  -From $SmtpFrom -To $SmtpTo `
                                  -Port $SmtpPort -UseSsl $SmtpUseSsl

            # REMEDIATION NOTE: To stop the process or remove files, wrap calls in
            # Execute-RemediationSafe, e.g.:
            #   Execute-RemediationSafe -Reason "Stop suspect process $pid" -ActionScriptBlock {
            #       Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
            #   }
            # Set $Global:EnableRemediation = $true and $Global:EnableDryRun = $false to activate.
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
