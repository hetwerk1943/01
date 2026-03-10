# Public\Start-UltraSecurityMonitor.ps1
# Entry point for the Ultra Security Monitor module.

function Start-UltraSecurityMonitor {
    <#
    .SYNOPSIS
        Starts the Ultra Security Monitor.

    .DESCRIPTION
        Loads configuration (defaults → JSON file → env vars → CLI overrides),
        initialises runtime directories, registers FileSystemWatcher events for
        monitored folders, and subscribes to Win32_ProcessStartTrace to detect
        suspicious process launches.

        Requires PowerShell 5.1+ and must be run as Administrator for full
        functionality (WMI process monitoring, system folder watching).

    .PARAMETER BaseFolder
        Override the base data folder (default: %USERPROFILE%\Documents\SecurityMonitor).

    .PARAMETER ConfigPath
        Path to a JSON configuration file. If omitted the monitor looks for
        monitor.config.json inside BaseFolder.

    .PARAMETER MonitoredFolders
        Override the list of folders to watch.

    .PARAMETER DiscordWebhookUrl
        Override the Discord webhook URL (prefer env var USM_DISCORD_WEBHOOK).

    .PARAMETER VirusTotalApiKey
        Override the VirusTotal API key (prefer env var USM_VT_API_KEY).

    .EXAMPLE
        Start-UltraSecurityMonitor

    .EXAMPLE
        Start-UltraSecurityMonitor -ConfigPath 'C:\configs\usm.json'
    #>
    [CmdletBinding()]
    param(
        [string]$BaseFolder,
        [string]$ConfigPath,
        [string[]]$MonitoredFolders,
        [string]$DiscordWebhookUrl,
        [string]$VirusTotalApiKey
    )

    # Build overrides hashtable from non-null CLI parameters
    $overrides = @{}
    if ($PSBoundParameters.ContainsKey('BaseFolder'))        { $overrides['BaseFolder']        = $BaseFolder }
    if ($PSBoundParameters.ContainsKey('MonitoredFolders'))  { $overrides['MonitoredFolders']  = $MonitoredFolders }
    if ($PSBoundParameters.ContainsKey('DiscordWebhookUrl')) { $overrides['DiscordWebhookUrl'] = $DiscordWebhookUrl }
    if ($PSBoundParameters.ContainsKey('VirusTotalApiKey'))  { $overrides['VirusTotalApiKey']  = $VirusTotalApiKey }

    # Store config in module-scope variable consumed by private functions
    $script:_config        = Get-UsmConfig -ConfigPath $ConfigPath -Overrides $overrides
    $script:_logWriteCount = 0
    $script:_wlCache       = $null

    $cfg = $script:_config

    # ── Create runtime directories ───────────────────────────────────────────
    foreach ($dir in @($cfg.BaseFolder, $cfg.BackupFolder, $cfg.SiemFolder)) {
        if (-not (Test-Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
        }
    }

    Write-UsmLog -Message "Ultra Security Monitor started by $($env:USERNAME)"

    # ── Register folder monitors ─────────────────────────────────────────────
    foreach ($folder in $cfg.MonitoredFolders) {
        Register-UsmFolderMonitor -Folder $folder
    }

    # ── Register process-start WMI event ────────────────────────────────────
    $sourceId = 'UltraSecurityMonitor-Process'
    Get-EventSubscriber -ErrorAction SilentlyContinue |
        Where-Object { $_.SourceIdentifier -eq $sourceId } |
        Unregister-Event -Force -ErrorAction SilentlyContinue

    $procAction = {
        try {
            $evt     = $Event.SourceEventArgs.NewEvent
            $eventPid = [int]$evt.ProcessID
            Start-Sleep -Milliseconds 300
            $details = Get-UsmProcDetails -Pid $eventPid
            if ($null -eq $details) {
                Write-UsmLog -Message "Process $($evt.ProcessName) PID $eventPid (details unavailable)"
                return
            }

            $path      = $details.Path
            $sigStatus = Get-UsmFileSignature -FilePath $path
            $hash      = Get-UsmFileHashSafe  -FilePath $path
            $network   = Get-UsmNetworkConnsForPid -Pid $eventPid

            if (Test-UsmProcessSuspicious -ProcName $details.Name -FilePath $path) {
                $msg = "SUSPECT PROCESS | Name: $($details.Name) | PID: $eventPid | Owner: $($details.Owner) | Path: $path | Sig: $sigStatus | SHA256: $hash | Cmd: $($details.CommandLine)"
                if ($null -ne $network -and $null -ne $network.TCP) {
                    $tcpSummary = ($network.TCP |
                        Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State |
                        Out-String).Trim()
                    $msg += " | TCP: $tcpSummary"
                }

                if (-not [string]::IsNullOrWhiteSpace($hash)) {
                    $vtResult = Get-UsmVirusTotalReport -Hash $hash
                    if ($null -ne $vtResult) {
                        $msg += " | VT Malicious=$($vtResult.Malicious) Suspicious=$($vtResult.Suspicious)"
                    }
                }

                Write-UsmLog -Message $msg -Level WARN -Fields @{ event = 'SuspiciousProcess'; pid = $eventPid; path = $path }
                Add-Content -Path $script:_config.ReportPath `
                    -Value ("`n`n$(Get-Date -Format o)`n$msg")
                Write-UsmSiemEvent -EventType 'SuspiciousProcess' -Severity 'High' -Data @{
                    name        = $details.Name
                    pid         = $pid_
                    path        = $path
                    hash        = $hash
                    sig         = $sigStatus
                    commandLine = $details.CommandLine
                    owner       = $details.Owner
                }
                Send-UsmDiscordAlert -Message $msg
                Send-UsmEmailAlert   -Subject 'Suspicious Process Alert' -Body $msg
            }
        } catch {
            Write-UsmLog -Message "procAction error: $_" -Level ERROR
        }
    }

    Register-WmiEvent -Class Win32_ProcessStartTrace `
        -SourceIdentifier $sourceId -Action $procAction | Out-Null

    # ── Summary ──────────────────────────────────────────────────────────────
    Write-Host '🎯 Ultra Security Monitor active.'
    Write-Host "   Base:    $($cfg.BaseFolder)"
    Write-Host "   Log:     $($cfg.LogPath)"
    Write-Host "   Report:  $($cfg.ReportPath)"
    Write-Host "   SIEM:    $($cfg.SiemLogPath)"
}

# ── Internal folder-monitor helper (called from public function) ─────────────
function Register-UsmFolderMonitor {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Folder)

    if (-not (Test-Path $Folder)) { return }

    try {
        $fsw = New-Object System.IO.FileSystemWatcher $Folder -Property @{
            IncludeSubdirectories = $true
            NotifyFilter          = [System.IO.NotifyFilters]'FileName, LastWrite'
            Filter                = '*.*'
        }

        $action = {
            $path       = $Event.SourceEventArgs.FullPath
            $changeType = $Event.SourceEventArgs.ChangeType
            $msg        = "File ${changeType}: $path"

            Write-UsmLog -Message $msg -Fields @{ event = 'FileChange'; path = $path }
            Backup-UsmFile -FilePath $path
            Write-UsmSiemEvent -EventType 'FileChange' -Severity 'Low' -Data @{
                path   = $path
                change = $changeType.ToString()
            }
            Send-UsmDiscordAlert -Message $msg
            Send-UsmEmailAlert   -Subject 'File Change Alert' -Body $msg
        }

        Register-ObjectEvent -InputObject $fsw -EventName Created -Action $action | Out-Null
        Register-ObjectEvent -InputObject $fsw -EventName Changed -Action $action | Out-Null
        Register-ObjectEvent -InputObject $fsw -EventName Renamed -Action $action | Out-Null
        $fsw.EnableRaisingEvents = $true
    } catch {
        Write-UsmLog -Message "Register-UsmFolderMonitor error for ${Folder}: $_" -Level ERROR
    }
}
