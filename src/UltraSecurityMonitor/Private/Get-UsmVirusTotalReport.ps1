# Private\Get-UsmVirusTotalReport.ps1
# VirusTotal v3 API integration.

function Get-UsmVirusTotalReport {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Hash)

    $apiKey = $script:_config.VirusTotalApiKey
    if ([string]::IsNullOrWhiteSpace($apiKey) -or [string]::IsNullOrWhiteSpace($Hash)) {
        return $null
    }

    try {
        $uri     = "https://www.virustotal.com/api/v3/files/$Hash"
        $headers = @{ 'x-apikey' = $apiKey }
        $resp    = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get `
                       -TimeoutSec 15 -ErrorAction Stop
        $stats   = $resp.data.attributes.last_analysis_stats
        if ($null -eq $stats) { return $null }
        return [PSCustomObject]@{
            Malicious  = $stats.malicious
            Suspicious = $stats.suspicious
            Undetected = $stats.undetected
            Harmless   = $stats.harmless
        }
    } catch {
        Write-UsmLog -Message "Get-UsmVirusTotalReport failed for hash ${Hash}: $_" -Level WARN
        return $null
    }
}
