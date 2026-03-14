# Private\Get-UsmSystemInfo.ps1
# System-level helpers: process details, network connections, file signatures, hashes, backups.

function Get-UsmProcDetails {
    [CmdletBinding()]
    param([Parameter(Mandatory)][int]$Pid)
    try {
        $proc = Get-CimInstance Win32_Process -Filter "ProcessId = $Pid" -ErrorAction Stop
        $ownerInfo = $null
        try { $ownerInfo = Invoke-CimMethod -InputObject $proc -MethodName GetOwner } catch {}
        return [PSCustomObject]@{
            Name        = $proc.Name
            PID         = $proc.ProcessId
            Path        = $proc.ExecutablePath
            CommandLine = $proc.CommandLine
            ParentPID   = $proc.ParentProcessId
            Owner       = if ($null -ne $ownerInfo) { "$($ownerInfo.Domain)\$($ownerInfo.User)" } else { 'unknown' }
        }
    } catch {
        Write-UsmLog -Message "Get-UsmProcDetails PID $Pid failed: $_" -Level WARN
        return $null
    }
}

function Get-UsmNetworkConnsForPid {
    [CmdletBinding()]
    param([Parameter(Mandatory)][int]$Pid)
    try {
        $tcp = Get-NetTCPConnection -OwningProcess $Pid -ErrorAction SilentlyContinue
        $udp = Get-NetUDPEndpoint   -OwningProcess $Pid -ErrorAction SilentlyContinue
        return [PSCustomObject]@{ TCP = $tcp; UDP = $udp }
    } catch { return $null }
}

function Get-UsmFileSignature {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$FilePath)
    if (-not $FilePath -or -not (Test-Path $FilePath)) { return 'no-file' }
    try {
        $sig = Get-AuthenticodeSignature -FilePath $FilePath -ErrorAction Stop
        return $sig.Status.ToString()
    } catch { return 'sig-check-failed' }
}

function Get-UsmFileHashSafe {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$FilePath)
    try {
        if (Test-Path $FilePath) {
            return (Get-FileHash -Path $FilePath -Algorithm SHA256 -ErrorAction Stop).Hash
        }
    } catch {
        Write-UsmLog -Message "Get-UsmFileHashSafe failed for ${FilePath}: $_" -Level WARN
    }
    return $null
}

function Backup-UsmFile {
    <#
    .SYNOPSIS
        Copies a file into BackupFolder.  Rejects paths outside BaseFolder.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$FilePath)

    $baseFolder   = $script:_config.BaseFolder
    $backupFolder = $script:_config.BackupFolder

    if (-not (Test-Path -Path $FilePath -PathType Leaf)) { return }

    # Only back up files that are under BaseFolder to prevent accidental wide copies
    if (-not (Test-UsmSafePath -Path $FilePath -BaseFolder $baseFolder)) {
        # Files outside BaseFolder (e.g. system files) are intentionally not backed up
        # to prevent unintended data collection from arbitrary system paths.
        return
    }

    try {
        $leaf = Split-Path $FilePath -Leaf
        $dest = Join-Path $backupFolder ("${leaf}_" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        Copy-Item -Path $FilePath -Destination $dest -Force -ErrorAction Stop
    } catch {
        Write-UsmLog -Message "Backup-UsmFile failed for ${FilePath}: $_" -Level WARN
    }
}
