# CollectorAPI.ps1
# Collector API integration module for Ultra Security Monitor.
# Provides Push-CollectorEvent for forwarding structured security events
# to a remote HTTP(S) endpoint (e.g. Splunk HEC, custom SIEM ingestion API).
# Dot-source this file before calling Push-CollectorEvent.

#Requires -Version 5.1

# --------- CONFIGURATION (override before dot-sourcing or pass as parameters) ---------
# $CollectorApiUrl = "https://your-collector/api/events"
# $CollectorApiKey = "your-api-key-or-bearer-token"

# ---------------------------------------------------------------------------
function Push-CollectorEvent {
    <#
    .SYNOPSIS
        Sends a structured security event to a remote collector API endpoint.
    .PARAMETER EventType
        Category label (e.g. SuspiciousProcess, FileChange, LoginAnomaly).
    .PARAMETER Severity
        Severity level (Critical, High, Medium, Low, Info).
    .PARAMETER Data
        Hashtable of event-specific key/value pairs.
    .PARAMETER Url
        HTTP(S) endpoint that accepts a JSON POST body.
    .PARAMETER ApiKey
        Bearer token or API key sent in the Authorization header.
    .PARAMETER TimeoutSec
        HTTP request timeout in seconds (default 10).
    .OUTPUTS
        $true on successful delivery, $false otherwise.
    #>
    param(
        [Parameter(Mandatory)][string]$EventType,
        [Parameter(Mandatory)][string]$Severity,
        [Parameter(Mandatory)][hashtable]$Data,
        [string]$Url        = "",
        [string]$ApiKey     = "",
        [int]$TimeoutSec    = 10
    )

    if ([string]::IsNullOrWhiteSpace($Url)) { return $false }

    $payload = [ordered]@{
        timestamp  = (Get-Date).ToString("o")
        host       = $env:COMPUTERNAME
        user       = $env:USERNAME
        event_type = $EventType
        severity   = $Severity
        data       = $Data
    } | ConvertTo-Json -Compress -Depth 5

    $headers = @{ "Content-Type" = "application/json" }
    if (-not [string]::IsNullOrWhiteSpace($ApiKey)) {
        $headers["Authorization"] = "Bearer $ApiKey"
    }

    try {
        $response = Invoke-RestMethod -Uri $Url -Method Post -Body $payload `
                        -Headers $headers -TimeoutSec $TimeoutSec `
                        -ErrorAction Stop
        return $true
    } catch {
        Write-Warning "CollectorAPI: delivery failed – $_"
        return $false
    }
}

# ---------------------------------------------------------------------------
function Test-CollectorEndpoint {
    <#
    .SYNOPSIS
        Sends a ping/health-check event to verify the collector endpoint is reachable.
    .PARAMETER Url
        HTTP(S) endpoint URL.
    .PARAMETER ApiKey
        Bearer token or API key.
    .OUTPUTS
        $true if the endpoint responded with a success status, $false otherwise.
    #>
    param(
        [Parameter(Mandatory)][string]$Url,
        [string]$ApiKey = ""
    )

    return (Push-CollectorEvent -EventType "HealthCheck" -Severity "Info" `
                -Data @{ status = "ping"; source = $env:COMPUTERNAME } `
                -Url $Url -ApiKey $ApiKey -TimeoutSec 5)
}
