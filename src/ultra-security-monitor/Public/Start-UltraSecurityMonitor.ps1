# Public/Start-UltraSecurityMonitor.ps1
# Main public entrypoint for the Ultra Security Monitor module.

function Start-UltraSecurityMonitor {
    [CmdletBinding()]
    param(
        [string]$ConfigPath,
        [string]$BaseFolder
    )

    # ---- Load configuration ----
    $cfg = Get-UsmConfig -ConfigPath $ConfigPath -BaseFolder $BaseFolder

    # Resolve runtime paths
    $baseDir    = $cfg.BaseFolder
    $backupDir  = Join-Path $baseDir 'Backup'
    $siemDir    = Join-Path $baseDir 'SIEM'
    $logPath    = Join-Path $baseDir 'security.log'
    $reportPath = Join-Path $baseDir 'security-report.txt'
    $siemPath   = Join-Path $siemDir 'siem.ndjson'

    # Ensure runtime directories exist
    foreach ($dir in @($baseDir, $backupDir, $siemDir)) {
        if (-not (Test-Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
        }
    }

    # ---- Helpers scoped to this invocation ----
    function _log { param([string]$m, [string]$l='INFO')
        Write-UsmLog -Message $m -Level $l -LogPath $logPath -BaseFolder $baseDir -MaxLogSizeMB $cfg.MaxLogSizeMB
    }

    function _siem { param([string]$et, [string]$sv, [hashtable]$d)
        Write-UsmNdjson -NdjsonPath $siemPath -EventType $et -Severity $sv -Data $d
    }

    function _discord { param([string]$msg)
        if ([string]::IsNullOrWhiteSpace($cfg.DiscordWebhookUrl)) { return }
        $trimmed = if ($msg.Length -gt $cfg.MaxDiscordMsgLength) { $msg.Substring(0, $cfg.MaxDiscordMsgLength - 3) + '...' } else { $msg }
        $payload = @{ content = $trimmed } | ConvertTo-Json
        try {
            Invoke-RestMethod -Uri $cfg.DiscordWebhookUrl -Method Post -Body $payload `
                -ContentType 'application/json' -TimeoutSec 10 -ErrorAction SilentlyContinue
        } catch {}
    }

    function _email { param([string]$subj, [string]$body)
        if (-not $cfg.EmailAlerts) { return }
        if ([string]::IsNullOrWhiteSpace($cfg.SmtpServer) -or
            [string]::IsNullOrWhiteSpace($cfg.SmtpFrom)   -or
            [string]::IsNullOrWhiteSpace($cfg.SmtpTo)) { return }
        try {
            Send-MailMessage -To $cfg.SmtpTo -From $cfg.SmtpFrom -Subject $subj -Body $body `
                -SmtpServer $cfg.SmtpServer -Port $cfg.SmtpPort -UseSsl:$cfg.SmtpUseSsl `
                -ErrorAction SilentlyContinue
        } catch {}
    }

    # ---- Register folder monitors ----
    foreach ($folder in $cfg.MonitoredFolders) {
        if (-not (Test-Path $folder)) { continue }
        try {
            $fsw = New-Object System.IO.FileSystemWatcher $folder -Property @{
                IncludeSubdirectories = $true
                NotifyFilter          = [System.IO.NotifyFilters]'FileName, LastWrite'
                Filter                = '*.*'
            }
            $fswAction = {
                $path       = $Event.SourceEventArgs.FullPath
                $changeType = $Event.SourceEventArgs.ChangeType
                $msg        = "File ${changeType}: $path"
                _log $msg
                # Only back up files safely within backupDir
                if (Test-Path $path -PathType Leaf) {
                    $leaf = Split-Path $path -Leaf
                    $dest = Join-Path $backupDir ("${leaf}_$(Get-Date -Format 'yyyyMMdd-HHmmss')")
                    try { Copy-Item -Path $path -Destination $dest -Force -ErrorAction SilentlyContinue } catch {}
                }
                _siem 'FileChange' 'Low' @{ path = $path; change = $changeType.ToString() }
                _discord $msg
                _email 'File Change Alert' $msg
            }.GetNewClosure()
            Register-ObjectEvent -InputObject $fsw -EventName Created -Action $fswAction | Out-Null
            Register-ObjectEvent -InputObject $fsw -EventName Changed -Action $fswAction | Out-Null
            Register-ObjectEvent -InputObject $fsw -EventName Renamed -Action $fswAction | Out-Null
            $fsw.EnableRaisingEvents = $true
        } catch {
            _log "Register-FolderMonitor error for '$folder': $_" 'ERROR'
        }
    }

    # ---- Register process-start event ----
    $sourceId = 'UltraSecurityMonitor-Process'
    Get-EventSubscriber -ErrorAction SilentlyContinue |
        Where-Object { $_.SourceIdentifier -eq $sourceId } |
        Unregister-Event -Force -ErrorAction SilentlyContinue

    $procAction = {
        try {
            $evt     = $Event.SourceEventArgs.NewEvent
            $pid_val = [int]$evt.ProcessID
            Start-Sleep -Milliseconds 300

            $proc = Get-CimInstance Win32_Process -Filter "ProcessId = $pid_val" -ErrorAction SilentlyContinue
            if ($null -eq $proc) {
                _log "Process $($evt.ProcessName) PID $pid_val (details unavailable)"
                return
            }
            $ownerInfo = $null
            try { $ownerInfo = Invoke-CimMethod -InputObject $proc -MethodName GetOwner } catch {}
            $owner = if ($null -ne $ownerInfo) { "$($ownerInfo.Domain)\$($ownerInfo.User)" } else { 'unknown' }
            $path  = $proc.ExecutablePath
            $name  = $proc.Name

            $sigStatus = 'no-file'
            if ($path -and (Test-Path $path)) {
                try {
                    $sig       = Get-AuthenticodeSignature -FilePath $path -ErrorAction SilentlyContinue
                    $sigStatus = if ($null -ne $sig) { $sig.Status.ToString() } else { 'no-signature' }
                } catch { $sigStatus = 'sig-check-failed' }
            }

            $hash = $null
            try { if ($path -and (Test-Path $path)) { $hash = (Get-FileHash -Path $path -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash } } catch {}

            # Suspicious check
            $wl         = Get-UsmWhitelist -BaseFolder $baseDir -DefaultWhitelist $cfg.DefaultWhitelist
            $isSuspect  = $false
            if (-not (Test-UsmPathWhitelisted -FilePath $path -Whitelist $wl)) {
                foreach ($p in $cfg.SuspiciousPathPatterns) { if ($path -like $p) { $isSuspect = $true; break } }
                if (-not $isSuspect) {
                    foreach ($n in $cfg.SuspiciousNames) { if ($name -ieq $n) { $isSuspect = $true; break } }
                }
                if (-not $isSuspect -and $path -and
                    -not ($path -like "$env:windir\*") -and
                    -not ($path -like "$env:ProgramFiles\*") -and
                    -not ($path -like "${env:ProgramFiles(x86)}\*")) {
                    $isSuspect = $true
                }
            }

            if ($isSuspect) {
                $msg = "SUSPECT PROCESS`nName: $name`nPID: $pid_val`nOwner: $owner`nPath: $path`nSig: $sigStatus`nSHA256: $hash`nCmd: $($proc.CommandLine)"

                # Network connections
                try {
                    $tcp = Get-NetTCPConnection -OwningProcess $pid_val -ErrorAction SilentlyContinue
                    if ($null -ne $tcp) {
                        $msg += "`nTCP:`n" + ($tcp | Select-Object LocalAddress,LocalPort,RemoteAddress,RemotePort,State | Out-String)
                    }
                } catch {}

                # VirusTotal lookup
                if (-not [string]::IsNullOrWhiteSpace($cfg.VirusTotalApiKey) -and -not [string]::IsNullOrWhiteSpace($hash)) {
                    try {
                        $uri     = "https://www.virustotal.com/api/v3/files/$hash"
                        $headers = @{ 'x-apikey' = $cfg.VirusTotalApiKey }
                        $resp    = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get `
                                       -TimeoutSec 15 -ErrorAction SilentlyContinue
                        $stats   = $resp.data.attributes.last_analysis_stats
                        if ($null -ne $stats) {
                            $msg += "`nVirusTotal: Malicious=$($stats.malicious) Suspicious=$($stats.suspicious)"
                        }
                    } catch {}
                }

                _log $msg 'WARN'
                Add-Content -Path $reportPath -Value ("`n`n$(Get-Date -Format o)`n$msg") -ErrorAction SilentlyContinue
                _siem 'SuspiciousProcess' 'High' @{
                    name        = $name
                    pid         = $pid_val
                    path        = $path
                    hash        = $hash
                    sig         = $sigStatus
                    commandLine = $proc.CommandLine
                    owner       = $owner
                }
                _discord "⚠️ $msg"
                _email 'Suspicious Process Alert' $msg
            }
        } catch {
            _log "procAction error: $_" 'ERROR'
        }
    }.GetNewClosure()

    try {
        Register-WmiEvent -Class Win32_ProcessStartTrace -SourceIdentifier $sourceId -Action $procAction | Out-Null
    } catch {
        _log "Register-WmiEvent failed (requires elevated privileges): $_" 'WARN'
    }

    _log "Ultra Security Monitor started by $($env:USERNAME)"
    Write-Host '🎯 Ultra Security Monitor active.'
    Write-Host "   Logs:      $logPath"
    Write-Host "   Reports:   $reportPath"
    Write-Host "   SIEM NDJSON: $siemPath"
    Write-Host "   Base:      $baseDir"
}
