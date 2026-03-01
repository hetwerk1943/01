# VT-Cache.ps1
# VirusTotal result caching module for Ultra Security Monitor.
# Caches API responses by SHA-256 hash to avoid hitting rate limits.
# Dot-source this file before calling Get-VTCachedReport.

#Requires -Version 5.1

# --------- CONFIGURATION ---------
$script:VTCacheFile = Join-Path (Split-Path $PSScriptRoot -Parent) (Join-Path "logs" "vt-cache.json")
# Default TTL: 24 hours (results rarely change within a day)
$script:VTCacheTTLHours = 24

# In-memory cache loaded once per session for fast lookups.
$script:VTMemCache = $null

# ---------------------------------------------------------------------------
function _Load-VTCache {
    if ($null -ne $script:VTMemCache) { return }
    if (Test-Path $script:VTCacheFile) {
        try {
            $raw = Get-Content $script:VTCacheFile -Raw -ErrorAction Stop
            $script:VTMemCache = $raw | ConvertFrom-Json -ErrorAction Stop
        } catch {
            $script:VTMemCache = [PSCustomObject]@{}
        }
    } else {
        $script:VTMemCache = [PSCustomObject]@{}
    }
}

function _Save-VTCache {
    try {
        $script:VTMemCache | ConvertTo-Json -Depth 5 |
            Set-Content -Path $script:VTCacheFile -Force -ErrorAction Stop
    } catch {
        Write-Warning "VT-Cache: unable to persist cache – $_"
    }
}

# ---------------------------------------------------------------------------
function Get-VTCachedReport {
    <#
    .SYNOPSIS
        Returns a cached VirusTotal report for the given SHA-256 hash, or
        queries the API and stores the result when the cache is stale/missing.
    .PARAMETER Hash
        SHA-256 hash of the file to look up.
    .PARAMETER ApiKey
        VirusTotal API v3 key.
    .OUTPUTS
        PSCustomObject with Malicious, Suspicious, Undetected, Harmless counts,
        or $null when the lookup fails or the API key is absent.
    #>
    param(
        [Parameter(Mandatory)][string]$Hash,
        [string]$ApiKey = ""
    )

    if ([string]::IsNullOrWhiteSpace($Hash)) { return $null }

    _Load-VTCache

    # --- cache hit? ---
    $entry = $script:VTMemCache.PSObject.Properties[$Hash]
    if ($null -ne $entry) {
        $cached = $entry.Value
        $age    = (Get-Date) - [datetime]$cached.CachedAt
        if ($age.TotalHours -lt $script:VTCacheTTLHours) {
            return [PSCustomObject]@{
                Malicious  = $cached.Malicious
                Suspicious = $cached.Suspicious
                Undetected = $cached.Undetected
                Harmless   = $cached.Harmless
            }
        }
    }

    # --- cache miss / stale – call the API ---
    if ([string]::IsNullOrWhiteSpace($ApiKey)) { return $null }

    try {
        $uri     = "https://www.virustotal.com/api/v3/files/$Hash"
        $headers = @{ "x-apikey" = $ApiKey }
        $resp    = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get `
                       -TimeoutSec 15 -ErrorAction SilentlyContinue
        $stats   = $resp.data.attributes.last_analysis_stats
        if ($null -eq $stats) { return $null }

        $result = [PSCustomObject]@{
            Malicious  = $stats.malicious
            Suspicious = $stats.suspicious
            Undetected = $stats.undetected
            Harmless   = $stats.harmless
        }

        # Persist to cache
        $script:VTMemCache | Add-Member -Force -MemberType NoteProperty -Name $Hash -Value @{
            Malicious  = $result.Malicious
            Suspicious = $result.Suspicious
            Undetected = $result.Undetected
            Harmless   = $result.Harmless
            CachedAt   = (Get-Date).ToString("o")
        }
        _Save-VTCache

        return $result
    } catch {
        return $null
    }
}

# ---------------------------------------------------------------------------
function Clear-VTCache {
    <#
    .SYNOPSIS
        Removes all cached VirusTotal entries (both in-memory and on disk).
    #>
    $script:VTMemCache = [PSCustomObject]@{}
    _Save-VTCache
}
