# UltraSecurityMonitor.ps1
# ULTRAMASTER APOCALYPSE HARDENED VERSION
# Kompletny skrypt Ultra Security Monitor – Total Edition (modular build)
# Uruchom jako Administrator. Skonfiguruj klucze API w sekcji KONFIGURACJA.

#Requires -Version 5.1

# --------- LOAD MODULES ---------
. "$PSScriptRoot\Write-SecureLog.ps1"
. "$PSScriptRoot\VT-Cache.ps1"
. "$PSScriptRoot\Send-CollectorAlert.ps1"
. "$PSScriptRoot\CollectorAPI.ps1"

# --------- KONFIGURACJA ---------
$BaseFolder   = Join-Path $env:USERPROFILE "Documents\SecurityMonitor"
$BackupFolder = Join-Path $BaseFolder "Backup"

foreach ($dir in @($BaseFolder, $BackupFolder)) {
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
}

$ReportPath    = Join-Path $BaseFolder "security-report.txt"
$DashboardPath = Join-Path $BaseFolder "dashboard.html"

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

# Collector API (opcjonalnie – wklej URL i klucz lub pozostaw puste)
$CollectorApiUrl = ""
$CollectorApiKey = ""

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

# --------- WHITELIST HELPERS ---------
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

# --------- HELPER: dispatch alert through all channels ---------
function _Dispatch-Alert {
    param([string]$Subject, [string]$Message)
    Send-CollectorAlert -Subject $Subject -Message $Message `
        -DiscordWebhookUrl $DiscordWebhookUrl `
        -EmailAlerts $EmailAlerts -SmtpServer $SmtpServer `
        -SmtpFrom $SmtpFrom -SmtpTo $SmtpTo `
        -SmtpPort $SmtpPort -SmtpUseSsl $SmtpUseSsl `
        -CollectorApiUrl $CollectorApiUrl -CollectorApiKey $CollectorApiKey
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
            $msg        = "File $changeType: $path"
            Write-SecureLog $msg
            Backup-FileToStore $path
            Write-SiemEvent -EventType "FileChange" -Severity "Low" -Data @{ path = $path; change = $changeType.ToString() }
            _Dispatch-Alert -Subject "File Change Alert" -Message $msg
        }
        Register-ObjectEvent -InputObject $fsw -EventName Created -Action $action | Out-Null
        Register-ObjectEvent -InputObject $fsw -EventName Changed -Action $action | Out-Null
        Register-ObjectEvent -InputObject $fsw -EventName Renamed -Action $action | Out-Null
        $fsw.EnableRaisingEvents = $true
    } catch { Write-SecureLog "Register-FolderMonitor error: $_" }
}

# --------- HANDLER STARTU PROCESU ---------
$procAction = {
    try {
        $evt     = $Event.SourceEventArgs.NewEvent
        $pid     = [int]$evt.ProcessID
        Start-Sleep -Milliseconds 300
        $details = Get-ProcDetails -Pid $pid
        if ($null -eq $details) {
            Write-SecureLog "Process $($evt.ProcessName) PID $pid (details unavailable)"
            return
        }
        $path      = $details.Path
        $sigStatus = Get-FileSignatureStatus -FilePath $path
        $hash      = Get-FileHashSafe -FilePath $path
        $network   = Get-NetworkConnsForPid -Pid $pid

        if (Test-ProcessSuspicious -ProcName $details.Name -FilePath $path) {
            $msg = "⚠️ SUSPECT PROCESS`nName: $($details.Name)`nPID: $pid`nOwner: $($details.Owner)`nPath: $path`nSig: $sigStatus`nSHA256: $hash`nCmd: $($details.CommandLine)"
            if ($null -ne $network -and $null -ne $network.TCP) {
                $msg += "`nTCP:`n" + ($network.TCP |
                    Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State |
                    Out-String)
            }

            # VirusTotal lookup (via cache)
            if (-not [string]::IsNullOrWhiteSpace($hash)) {
                $vtResult = Get-VTCachedReport -Hash $hash -ApiKey $VirusTotalApiKey
                if ($null -ne $vtResult) {
                    $msg += "`nVirusTotal: Malicious=$($vtResult.Malicious) Suspicious=$($vtResult.Suspicious)"
                }
            }

            Write-SecureLog $msg
            Add-Content -Path $ReportPath -Value ("`n`n$(Get-Date -Format o)`n$msg")
            Write-SiemEvent -EventType "SuspiciousProcess" -Severity "High" -Data @{
                name        = $details.Name
                pid         = $pid
                path        = $path
                hash        = $hash
                sig         = $sigStatus
                commandLine = $details.CommandLine
                owner       = $details.Owner
            }
            Push-CollectorEvent -EventType "SuspiciousProcess" -Severity "High" `
                -Data @{ name = $details.Name; pid = $pid; path = $path; hash = $hash } `
                -Url $CollectorApiUrl -ApiKey $CollectorApiKey
            _Dispatch-Alert -Subject "Suspicious Process Alert" -Message $msg
        }
    } catch { Write-SecureLog "procAction error: $_" }
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
Write-SecureLog "Ultra Security Monitor Hardened Edition started by $($env:USERNAME)"
Write-Host "🎯 Ultra Security Monitor (Hardened) aktywny."
Write-Host "   Logi:      $($script:LogFile)"
Write-Host "   SIEM JSON: $($script:SiemFile)"
Write-Host "   Raporty:   $ReportPath"
Write-Host "   Dashboard: $DashboardPath"

# --------- PRZYKŁAD TWORZENIA SCHEDULED TASK (uruchom jako admin) ---------
# $ScriptPath = Join-Path $PSScriptRoot "UltraSecurityMonitor.ps1"
# $action     = New-ScheduledTaskAction -Execute "powershell.exe" `
#                   -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""
# $trigger    = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
# Register-ScheduledTask -Action $action -Trigger $trigger `
#     -TaskName "UltraSecurityMonitor" -RunLevel Highest -Force
