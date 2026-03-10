# Private\Write-UsmSiemEvent.ps1
# SIEM NDJSON writer.

function Write-UsmSiemEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$EventType,
        [Parameter(Mandatory)][ValidateSet('Low','Medium','High','Critical')][string]$Severity,
        [Parameter(Mandatory)][hashtable]$Data
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
        Add-Content -Path $script:_config.SiemLogPath `
            -Value ($event | ConvertTo-Json -Compress) -ErrorAction Stop
    } catch {
        Write-UsmLog -Message "Write-UsmSiemEvent failed: $_" -Level WARN
    }
}
