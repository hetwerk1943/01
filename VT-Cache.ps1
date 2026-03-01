# VT-Cache.ps1
# Moduł cache wyników VirusTotal – redukuje liczbę zapytań API (limit: 4/min na planie bezpłatnym).
# Dołącz ten plik za pomocą: . .\VT-Cache.ps1
# Następnie wywołaj: Get-VTReportCached -Hash <SHA256> -ApiKey <klucz>

#Requires -Version 5.1

# --------- KONFIGURACJA CACHE ---------
$VTCacheFile    = Join-Path $env:TEMP "vt-cache.json"
$VTCacheTTLHours = 24   # jak długo przechowywać wyniki (w godzinach)

# --------- WEWNĘTRZNA PAMIĘĆ PODRĘCZNA (słownik w pamięci RAM) ---------
$script:VTMemCache = @{}

function Import-VTDiskCache {
    <#
    .SYNOPSIS
        Wczytuje cache z dysku do pamięci RAM.
    #>
    if (Test-Path $VTCacheFile) {
        try {
            $raw = Get-Content -Path $VTCacheFile -Raw -ErrorAction Stop
            $obj = $raw | ConvertFrom-Json -ErrorAction Stop
            foreach ($prop in $obj.PSObject.Properties) {
                $script:VTMemCache[$prop.Name] = $prop.Value
            }
        } catch {}
    }
}

function Export-VTDiskCache {
    <#
    .SYNOPSIS
        Zapisuje pamięć podręczną RAM na dysk.
    #>
    try {
        $script:VTMemCache | ConvertTo-Json -Depth 4 | Set-Content -Path $VTCacheFile -Encoding UTF8 -Force
    } catch {}
}

function Clear-VTExpiredEntries {
    <#
    .SYNOPSIS
        Usuwa przeterminowane wpisy z cache.
    #>
    $cutoff = (Get-Date).AddHours(-$VTCacheTTLHours)
    $toRemove = @()
    foreach ($key in $script:VTMemCache.Keys) {
        $entry = $script:VTMemCache[$key]
        if ($null -ne $entry.CachedAt) {
            $cachedAt = [datetime]::Parse($entry.CachedAt)
            if ($cachedAt -lt $cutoff) { $toRemove += $key }
        }
    }
    foreach ($key in $toRemove) { $script:VTMemCache.Remove($key) }
}

function Get-VTReportCached {
    <#
    .SYNOPSIS
        Zwraca wynik z VirusTotal dla podanego skrótu SHA-256.
        Używa cache (RAM + dysk) przed wysłaniem zapytania do API.
    .PARAMETER Hash
        Skrót SHA-256 pliku do sprawdzenia.
    .PARAMETER ApiKey
        Klucz API VirusTotal v3.
    .OUTPUTS
        PSCustomObject z polami: Malicious, Suspicious, Undetected, Harmless, FromCache
        lub $null w przypadku błędu / braku klucza API.
    #>
    param(
        [Parameter(Mandatory)][string]$Hash,
        [Parameter(Mandatory)][string]$ApiKey
    )

    if ([string]::IsNullOrWhiteSpace($Hash) -or [string]::IsNullOrWhiteSpace($ApiKey)) {
        return $null
    }

    $hashUpper = $Hash.ToUpperInvariant()

    # Inicjalizuj cache z dysku przy pierwszym wywołaniu
    if ($script:VTMemCache.Count -eq 0) { Import-VTDiskCache }

    # Sprawdź RAM cache
    if ($script:VTMemCache.ContainsKey($hashUpper)) {
        $cached = $script:VTMemCache[$hashUpper]
        $cachedAt = [datetime]::Parse($cached.CachedAt)
        if ($cachedAt -gt (Get-Date).AddHours(-$VTCacheTTLHours)) {
            return [PSCustomObject]@{
                Malicious  = [int]$cached.Malicious
                Suspicious = [int]$cached.Suspicious
                Undetected = [int]$cached.Undetected
                Harmless   = [int]$cached.Harmless
                FromCache  = $true
            }
        }
    }

    # Wyślij zapytanie do VirusTotal API v3
    try {
        $uri     = "https://www.virustotal.com/api/v3/files/$hashUpper"
        $headers = @{ "x-apikey" = $ApiKey }
        $resp    = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get `
                       -TimeoutSec 15 -ErrorAction Stop
        $stats   = $resp.data.attributes.last_analysis_stats
        if ($null -eq $stats) { return $null }

        $result = [PSCustomObject]@{
            Malicious  = [int]$stats.malicious
            Suspicious = [int]$stats.suspicious
            Undetected = [int]$stats.undetected
            Harmless   = [int]$stats.harmless
            FromCache  = $false
        }

        # Zapisz do cache RAM i dysk
        $script:VTMemCache[$hashUpper] = @{
            Malicious  = $result.Malicious
            Suspicious = $result.Suspicious
            Undetected = $result.Undetected
            Harmless   = $result.Harmless
            CachedAt   = (Get-Date).ToString("o")
        }
        Clear-VTExpiredEntries
        Export-VTDiskCache

        return $result
    } catch { return $null }
}

function Remove-VTCacheEntry {
    <#
    .SYNOPSIS
        Ręcznie usuwa wpis z cache dla podanego skrótu SHA-256.
    #>
    param([Parameter(Mandatory)][string]$Hash)
    $hashUpper = $Hash.ToUpperInvariant()
    if ($script:VTMemCache.ContainsKey($hashUpper)) {
        $script:VTMemCache.Remove($hashUpper)
        Export-VTDiskCache
    }
}

function Clear-VTCache {
    <#
    .SYNOPSIS
        Czyści cały cache (RAM i dysk).
    #>
    $script:VTMemCache.Clear()
    if (Test-Path $VTCacheFile) { Remove-Item -Path $VTCacheFile -Force -ErrorAction SilentlyContinue }
}
