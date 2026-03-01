# UltraSecurityMonitor.ps1
# Kompletny skrypt Ultra Security Monitor – Total Edition
# Uruchom jako Administrator.
# Sekrety (klucze API, hasła) MUSZĄ być skonfigurowane w Windows Credential Manager
# za pomocą SecretsManager.ps1 – żadne klucze nie są przechowywane w tym pliku.

#Requires -Version 5.1

# ── Załaduj moduły pomocnicze ────────────────────────────────────────────────
$PSScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $PSScriptDir "SecretsManager.ps1")
. (Join-Path $PSScriptDir "Send-DiscordAlert.ps1")
. (Join-Path $PSScriptDir "Send-EmailAlert.ps1")
. (Join-Path $PSScriptDir "CollectorAPI.ps1")
. (Join-Path $PSScriptDir "RemediationEngine.ps1")

# ── Flagi runtime ────────────────────────────────────────────────────────────
# Ustaw $true aby uruchomić w trybie testowym (brak faktycznych akcji Stop/Remove/Move).
$DryRun = $false

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

$MaxLogSizeMB = 50

# ── Cache VirusTotal (hash -> wynik, TTL 1 h) ────────────────────────────────
$script:VTCache       = @{}
$script:VTCacheTTLSec = 3600

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

# ── Redakcja danych wrażliwych przed logowaniem / alertami ───────────────────

function Get-RedactedPath {
    param([string]$Path)
    if ([string]::IsNullOrEmpty($Path)) { return "<empty>" }
    # Zachowaj katalog nadrzędny i nazwę pliku, ukryj środkowe segmenty
    try {
        $leaf   = Split-Path $Path -Leaf
        $parent = Split-Path (Split-Path $Path -Parent) -Leaf
        return "<path>\$parent\$leaf"
    } catch { return "<path>" }
}

function Get-RedactedCommandLine {
    param([string]$CommandLine)
    if ([string]::IsNullOrEmpty($CommandLine)) { return "<empty>" }
    # Redaguj ścieżki bezwzględne Windows (C:\..., UNC \\...) w tym ze spacjami
    $out = $CommandLine -replace '(?i)[A-Za-z]:\\[^\s"'']*(?:\s+[^\s"'']*)*', '<path>'
    $out = $out -replace '\\\\[^\s"'']+',            '<unc>'
    # Redaguj ciągi podobne do tokenów/haseł (hex >= 32 znaków, case-insensitive)
    $out = $out -replace '(?i)\b[0-9a-f]{32,}\b',    '<hash>'
    # Ogranicz długość
    if ($out.Length -gt 500) { $out = $out.Substring(0, 497) + "..." }
    return $out
}

# ── Wywołania alertów (delegacja do dedykowanych skryptów) ────────────────────

function Invoke-DiscordAlert {
    param([string]$Message)
    try {
        Send-DiscordAlert -Message $Message -DryRun:$DryRun
    } catch { Write-Log "Invoke-DiscordAlert error: $_" }
}

function Invoke-EmailAlert {
    param([string]$Subject, [string]$Body)
    try {
        Send-EmailAlert -Subject $Subject -Body $Body -DryRun:$DryRun
    } catch { Write-Log "Invoke-EmailAlert error: $_" }
}

# --------- INTEGRACJA VIRUSTOTAL (z cache) ------------------------------------

function Get-VirusTotalReport {
    param([string]$Hash)
    if ([string]::IsNullOrWhiteSpace($Hash)) { return $null }

    # Sprawdź cache
    if ($script:VTCache.ContainsKey($Hash)) {
        $entry = $script:VTCache[$Hash]
        if (((Get-Date) - $entry.Time).TotalSeconds -lt $script:VTCacheTTLSec) {
            return $entry.Result
        }
    }

    $apiKey = Get-StoredSecret -Target "USM_VTApiKey"
    if ([string]::IsNullOrWhiteSpace($apiKey)) { return $null }

    # Wymuszenie TLS 1.2+
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

    try {
        $uri     = "https://www.virustotal.com/api/v3/files/$Hash"
        $headers = @{ "x-apikey" = $apiKey }
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
        $script:VTCache[$Hash] = @{ Result = $result; Time = (Get-Date) }
        return $result
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
    # Deleguj do RemediationEngine który ustawia ACL tylko dla konta usługi
    Backup-WithAcl -FilePath $FilePath -BackupFolder $BackupFolder -DryRun:$DryRun
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
            $safePathForLog = Get-RedactedPath -Path $path
            $msg        = "File ${changeType}: ${safePathForLog}"
            Write-Log $msg
            Backup-FileToStore $path
            Write-SiemEvent -EventType "FileChange" -Severity "Low" -Data @{
                path   = $safePathForLog
                change = $changeType.ToString()
            }
            Invoke-DiscordAlert $msg
            Invoke-EmailAlert "File Change Alert" $msg
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
        $vtResult  = $null   # initialise before conditional use
        $network   = Get-NetworkConnsForPid -Pid $pid

        # Redaguj ścieżki i command-line przed logowaniem
        $safePath = Get-RedactedPath -Path $path
        $safeCmd  = Get-RedactedCommandLine -CommandLine $details.CommandLine

        if (Test-ProcessSuspicious -ProcName $details.Name -FilePath $path) {
            $msg = "⚠️ SUSPECT PROCESS`nName: $($details.Name)`nPID: $pid`nOwner: $($details.Owner)`nPath: $safePath`nSig: $sigStatus`nSHA256: $hash`nCmd: $safeCmd"
            if ($null -ne $network -and $null -ne $network.TCP) {
                $msg += "`nTCP:`n" + ($network.TCP |
                    Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State |
                    Out-String)
            }

            # VirusTotal lookup (z lokalnym cache)
            $vtResult = $null
            if (-not [string]::IsNullOrWhiteSpace($hash)) {
                $vtResult = Get-VirusTotalReport -Hash $hash
                if ($null -ne $vtResult) {
                    $msg += "`nVirusTotal: Malicious=$($vtResult.Malicious) Suspicious=$($vtResult.Suspicious)"
                }
            }

            Write-Log $msg
            Add-Content -Path $ReportPath -Value ("`n`n$(Get-Date -Format o)`n$msg")

            # SIEM – bezpieczne pola (zredagowane ścieżki i cmd)
            Write-SiemEvent -EventType "SuspiciousProcess" -Severity "High" -Data @{
                name        = $details.Name
                pid         = $pid
                path        = $safePath
                hash        = $hash
                sig         = $sigStatus
                commandLine = $safeCmd
                owner       = $details.Owner
            }

            Invoke-DiscordAlert $msg
            Invoke-EmailAlert -Subject "Suspicious Process Alert" -Body $msg

            # Deleguj do Collector/Remediation jeśli VT wykazał zagrożenie
            if ($null -ne $vtResult -and $vtResult.Malicious -gt 0) {
                $telemetry = New-TelemetryPayload -PID $pid `
                    -ProcessName $details.Name -SHA256 $hash
                if (Test-TelemetryPayload -Payload $telemetry) {
                    Invoke-CollectorSandboxOrchestration -FilePath $path `
                        -SHA256 $hash -DryRun:$DryRun
                }
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
Write-Log "Ultra Security Monitor Total Edition started by $($env:USERNAME) [DryRun=$DryRun]"
Write-Host "🎯 Ultra Security Monitor aktywny. [DryRun=$DryRun]"
Write-Host "   Logi:      $LogPath"
Write-Host "   Raporty:   $ReportPath"
Write-Host "   SIEM JSON: $SiemLogPath"
Write-Host "   Dashboard: $DashboardPath"
Write-Host "   Sekrety:   Windows Credential Manager (SecretsManager.ps1)"

# --------- PRZYKŁAD TWORZENIA SCHEDULED TASK (uruchom jako admin) ---------
# $ScriptPath = Join-Path $PSScriptDir "UltraSecurityMonitor.ps1"
# $action     = New-ScheduledTaskAction -Execute "powershell.exe" `
#                   -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""
# $trigger    = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
# Register-ScheduledTask -Action $action -Trigger $trigger `
#     -TaskName "UltraSecurityMonitor" -RunLevel Highest -Force
