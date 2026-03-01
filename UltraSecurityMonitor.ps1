# UltraSecurityMonitor.ps1
# Kompletny skrypt Ultra Security Monitor – Total Edition
# Uruchom jako Administrator. Skonfiguruj klucze API w sekcji KONFIGURACJA.

#Requires -Version 5.1

# Wymuszenie TLS 1.2+ dla wszystkich połączeń HTTPS
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

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

# Discord webhook – odczytaj z env/rejestru (nigdy nie wpisuj na twardo w kodzie!)
$DiscordWebhookUrl = if ($env:USM_DISCORD_WEBHOOK) { $env:USM_DISCORD_WEBHOOK } `
                     else { try { (Get-ItemProperty 'HKCU:\Software\USM' -ErrorAction Stop).DiscordWebhook } catch { "" } }

# VirusTotal API – odczytaj z env/rejestru
$VirusTotalApiKey  = if ($env:USM_VT_KEY) { $env:USM_VT_KEY } `
                     else { try { (Get-ItemProperty 'HKCU:\Software\USM' -ErrorAction Stop).VTKey } catch { "" } }

# E-mail alerty – wartości odczytaj z env/rejestru lub ustaw ręcznie
$EmailAlerts  = $false
$SmtpServer   = if ($env:USM_SMTP_SERVER) { $env:USM_SMTP_SERVER } else { "" }
$SmtpFrom     = if ($env:USM_SMTP_FROM)   { $env:USM_SMTP_FROM   } else { "" }
$SmtpTo       = if ($env:USM_SMTP_TO)     { $env:USM_SMTP_TO     } else { "" }
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
$LogHashFile         = Join-Path $BaseFolder "loghash.txt"
$LicenseFile         = Join-Path $BaseFolder "license.json"
$ScriptFile          = $PSCommandPath

# Klucz publiczny RSA do weryfikacji licencji (DEMO – zastąp własnym za pomocą New-UsmLicense.ps1)
$LicensePublicKeyXml = '<RSAKeyValue><Modulus>zagXS5HQ3EOnyZCsJj7/sZGKbMKf+uGF4BPf/r9FbDkyBe3ByuJv3GKP3YUyp/fAWeMgsaCRhc3JQBFPPDqeZWqlsUTsIbYYKwRcDUj5gSjqXdL3awe51FCJn1T81ljMjAEaPqSEeSbQkPQtP8+8cuHNZ2+Cwcz4Ygg8apdmv65s9h9F2QGBRvOLbMb9p6WPel+xAEvyRJkIoPP433b1QgDDxCW1szPGluIcorosuPFG4HfBvGlHEOfO5ShYa4N1sruoCzhFJFoX0v5/J3rT8twhIb2eyvzJlFMHlzPPQwOAEVZdxKdBdY7NFKathQ5kz77nzbo7MynDQcBhKgJK4w==</Modulus><Exponent>AQAB</Exponent></RSAKeyValue>'

# --------- FUNKCJE LOG I ALERTY ---------
function Update-LogHashChain {
    if (-not (Test-Path $LogPath)) { return }
    try {
        $prevHash  = if (Test-Path $LogHashFile) { (Get-Content $LogHashFile -Raw -ErrorAction SilentlyContinue).Trim() } else { "" }
        $logHash   = (Get-FileHash -Path $LogPath -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash
        if (-not $logHash) { return }
        $stream    = [IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes($prevHash + $logHash))
        $chainHash = (Get-FileHash -InputStream $stream -Algorithm SHA256).Hash
        $stream.Dispose()
        Set-Content -Path $LogHashFile -Value $chainHash -Force
    } catch {
        Add-Content -Path $LogPath -Value ("$(Get-Date -Format o)`tUpdate-LogHashChain error: $_")
    }
}

function Write-Log {
    param([string]$msg)
    $ts    = (Get-Date).ToString("o")
    $entry = "$ts`t$msg"
    Add-Content -Path $LogPath -Value $entry
    Update-LogHashChain
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

# --------- BEZPIECZEŃSTWO SKRYPTU ---------
function Test-ScriptIntegrity {
    $hashFile = Join-Path $BaseFolder "script.hash"
    if (-not $ScriptFile -or -not (Test-Path $ScriptFile)) { return }
    try {
        $currentHash = (Get-FileHash -Path $ScriptFile -Algorithm SHA256).Hash
        if (Test-Path $hashFile) {
            $storedHash = (Get-Content $hashFile -Raw).Trim()
            if ($storedHash -ne $currentHash) {
                $msg = "⚠️ ANTI-TAMPER: Hash skryptu zmienił się! Poprzedni: $storedHash | Aktualny: $currentHash"
                Write-Log $msg
                Write-Warning $msg
                Send-DiscordAlert $msg
                Write-SiemEvent -EventType "ScriptTampered" -Severity "Critical" -Data @{
                    script   = $ScriptFile
                    previous = $storedHash
                    current  = $currentHash
                }
            }
        }
        Set-Content -Path $hashFile -Value $currentHash -Force
    } catch { Write-Log "Test-ScriptIntegrity error: $_" }
}

function Test-UsmLicense {
    if ([string]::IsNullOrWhiteSpace($LicensePublicKeyXml)) {
        Write-Log "LICENCJA: Brak klucza publicznego – weryfikacja pominięta"
        return $true
    }
    if (-not (Test-Path $LicenseFile)) {
        Write-Log "LICENCJA: Brak pliku license.json – tryb ewaluacyjny"
        return $true
    }
    try {
        $lic = Get-Content $LicenseFile -Raw | ConvertFrom-Json
        if ((Get-Date) -gt [datetime]$lic.Expiry) {
            $msg = "⛔ LICENCJA: Licencja wygasła ($($lic.Expiry)) – monitor nie zostanie uruchomiony!"
            Write-Log $msg
            Write-Warning $msg
            return $false
        }
        $rsa          = [System.Security.Cryptography.RSA]::Create()
        $rsa.FromXmlString($LicensePublicKeyXml)
        $payload      = "$($lic.Customer)|$($lic.Expiry)|$($lic.MaxDevices)"
        $payloadBytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
        $sigBytes     = [Convert]::FromBase64String($lic.Signature)
        $valid        = $rsa.VerifyData($payloadBytes, $sigBytes,
                            [System.Security.Cryptography.HashAlgorithmName]::SHA256,
                            [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
        $rsa.Dispose()
        if (-not $valid) {
            $msg = "⛔ LICENCJA: Nieprawidłowy podpis licencji!"
            Write-Log $msg
            Write-Warning $msg
            return $false
        }
        Write-Log "LICENCJA: OK – $($lic.Customer) (ważna do: $($lic.Expiry), urządzenia: $($lic.MaxDevices))"
        return $true
    } catch {
        Write-Log "LICENCJA: Błąd weryfikacji – $_"
        return $false
    }
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
            $msg        = "File $changeType: $path"
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
            $msg = "⚠️ SUSPECT PROCESS`nName: $($details.Name)`nPID: $pid`nOwner: $($details.Owner)`nPath: $path`nSig: $sigStatus`nSHA256: $hash`nCmd: $($details.CommandLine)"
            if ($null -ne $network -and $null -ne $network.TCP) {
                $msg += "`nTCP:`n" + ($network.TCP |
                    Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State |
                    Out-String)
            }

            # VirusTotal lookup
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
                path        = $path
                hash        = $hash
                sig         = $sigStatus
                commandLine = $details.CommandLine
                owner       = $details.Owner
            }
            Send-DiscordAlert $msg
            Send-EmailAlert -Subject "Suspicious Process Alert" -Body $msg
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
Write-Log "SECURITY: PowerShell LanguageMode = $($ExecutionContext.SessionState.LanguageMode)"
Test-ScriptIntegrity
if (-not (Test-UsmLicense)) {
    Write-Host "⛔ Weryfikacja licencji nieudana. Monitor zatrzymany." -ForegroundColor Red
    exit 1
}
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
