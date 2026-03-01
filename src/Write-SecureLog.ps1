# Write-SecureLog.ps1
# Hardened secure logging module for Ultra Security Monitor.
# Writes timestamped entries to a restricted logs\ folder.
# Dot-source this file before calling Write-SecureLog or Write-SiemEvent.

#Requires -Version 5.1

# --------- CONFIGURATION ---------
# Resolved relative to the project root (parent of .\src)
$script:LogsRoot  = Join-Path (Split-Path $PSScriptRoot -Parent) "logs"
$script:LogFile   = Join-Path $script:LogsRoot "security.log"
$script:SiemFile  = Join-Path $script:LogsRoot "siem.json"
$script:MaxLogMB  = 50

# Ensure the logs directory exists.
if (-not (Test-Path $script:LogsRoot)) {
    New-Item -Path $script:LogsRoot -ItemType Directory -Force | Out-Null
}

# ---------------------------------------------------------------------------
function Write-SecureLog {
    <#
    .SYNOPSIS
        Appends a timestamped TSV entry to the secure log file.
    .PARAMETER Message
        The log message to record.
    #>
    param(
        [Parameter(Mandatory)][string]$Message
    )

    $ts    = (Get-Date).ToString("o")
    $entry = "$ts`t$Message"

    try {
        Add-Content -Path $script:LogFile -Value $entry -ErrorAction Stop
    } catch {
        # Fallback: write to host so the caller is not silently broken.
        Write-Warning "Write-SecureLog: unable to write log – $_"
    }

    # Log rotation
    try {
        $logItem = Get-Item $script:LogFile -ErrorAction SilentlyContinue
        $sizeMB  = if ($null -ne $logItem) { $logItem.Length / 1MB } else { 0 }
        if ($sizeMB -gt $script:MaxLogMB) {
            $arch = Join-Path $script:LogsRoot ("security-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
            Move-Item -Path $script:LogFile -Destination $arch -Force
            Add-Content -Path $script:LogFile -Value ("$(Get-Date -Format o)`tLog rotated -> $arch")
        }
    } catch {}
}

# ---------------------------------------------------------------------------
function Write-SiemEvent {
    <#
    .SYNOPSIS
        Appends a compressed JSON record to the SIEM NDJSON log.
    .PARAMETER EventType
        Category label (e.g. SuspiciousProcess, FileChange).
    .PARAMETER Severity
        Severity level string (e.g. High, Medium, Low).
    .PARAMETER Data
        Hashtable of event-specific key/value pairs.
    #>
    param(
        [Parameter(Mandatory)][string]$EventType,
        [Parameter(Mandatory)][string]$Severity,
        [Parameter(Mandatory)][hashtable]$Data
    )

    $record = [ordered]@{
        timestamp  = (Get-Date).ToString("o")
        host       = $env:COMPUTERNAME
        user       = $env:USERNAME
        event_type = $EventType
        severity   = $Severity
        data       = $Data
    }

    try {
        Add-Content -Path $script:SiemFile -Value ($record | ConvertTo-Json -Compress)
    } catch {
        Write-Warning "Write-SiemEvent: unable to write SIEM log – $_"
    }
}
