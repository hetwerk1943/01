# Private/Write-UsmLog.ps1
# Structured logging with automatic log rotation.

$script:_usmLogWriteCount = 0

function Write-UsmLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO',

        [Parameter(Mandatory)]
        [string]$LogPath,

        [Parameter(Mandatory)]
        [string]$BaseFolder,

        [int]$MaxLogSizeMB = 50
    )

    $ts    = (Get-Date).ToString('o')
    $entry = "$ts`t[$Level]`t$Message"
    try {
        Add-Content -Path $LogPath -Value $entry -ErrorAction SilentlyContinue
    } catch {}

    $script:_usmLogWriteCount = ($script:_usmLogWriteCount + 1) % 50
    if ($script:_usmLogWriteCount -eq 0) {
        Invoke-UsmLogRotation -LogPath $LogPath -BaseFolder $BaseFolder -MaxLogSizeMB $MaxLogSizeMB
    }
}

function Write-UsmNdjson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$NdjsonPath,

        [Parameter(Mandatory)]
        [string]$EventType,

        [Parameter(Mandatory)]
        [string]$Severity,

        [hashtable]$Data = @{}
    )

    $event = [ordered]@{
        timestamp  = (Get-Date).ToString('o')
        host       = $env:COMPUTERNAME
        user       = $env:USERNAME
        event_type = $EventType
        severity   = $Severity
        data       = $Data
    }
    try {
        Add-Content -Path $NdjsonPath -Value ($event | ConvertTo-Json -Compress) -ErrorAction SilentlyContinue
    } catch {}
}

function Invoke-UsmLogRotation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LogPath,

        [Parameter(Mandatory)]
        [string]$BaseFolder,

        [int]$MaxLogSizeMB = 50
    )

    if (-not (Test-Path $LogPath)) { return }
    try {
        $sizeMB = (Get-Item $LogPath -ErrorAction SilentlyContinue).Length / 1MB
        if ($sizeMB -gt $MaxLogSizeMB) {
            $arch = Join-Path $BaseFolder ("security-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
            Move-Item -Path $LogPath -Destination $arch -Force -ErrorAction SilentlyContinue
            Add-Content -Path $LogPath -Value ("$(Get-Date -Format o)`t[INFO]`tLog rotated -> $arch") -ErrorAction SilentlyContinue
        }
    } catch {}
}
