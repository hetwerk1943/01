# Private\Write-UsmLog.ps1
# Structured (NDJSON) log writer with automatic rotation.

function Write-UsmLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','WARN','ERROR','DEBUG')][string]$Level = 'INFO',
        [hashtable]$Fields
    )

    $logPath    = $script:_config.LogPath
    $maxSizeMB  = $script:_config.MaxLogSizeMB
    $baseFolder = $script:_config.BaseFolder

    $entry = [ordered]@{
        ts      = (Get-Date).ToString('o')
        level   = $Level
        host    = $env:COMPUTERNAME
        user    = $env:USERNAME
        message = $Message
    }
    if ($Fields) { foreach ($k in $Fields.Keys) { $entry[$k] = $Fields[$k] } }

    $line = $entry | ConvertTo-Json -Compress

    try {
        Add-Content -Path $logPath -Value $line -ErrorAction Stop
    } catch {
        Write-Warning "Write-UsmLog: could not write to $logPath – $_"
        return
    }

    # Check log size every 50 writes to balance responsiveness with file I/O overhead.
    # Checking on every write would add unnecessary file-stat overhead in high-event environments.
    $script:_logWriteCount = ($script:_logWriteCount + 1) % 50
    if ($script:_logWriteCount -eq 0) {
        Invoke-UsmLogRotation -LogPath $logPath -MaxSizeMB $maxSizeMB -BaseFolder $baseFolder
    }
}

function Invoke-UsmLogRotation {
    [CmdletBinding()]
    param(
        [string]$LogPath,
        [double]$MaxSizeMB,
        [string]$BaseFolder
    )
    try {
        $item = Get-Item $LogPath -ErrorAction SilentlyContinue
        if ($null -eq $item) { return }
        if (($item.Length / 1MB) -gt $MaxSizeMB) {
            $arch = Join-Path $BaseFolder ("security-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
            Move-Item -Path $LogPath -Destination $arch -Force -ErrorAction Stop
            $rotEntry = [ordered]@{
                ts      = (Get-Date).ToString('o')
                level   = 'INFO'
                message = "Log rotated to $arch"
            } | ConvertTo-Json -Compress
            Add-Content -Path $LogPath -Value $rotEntry
        }
    } catch {
        Write-Warning "Invoke-UsmLogRotation: $_"
    }
}
