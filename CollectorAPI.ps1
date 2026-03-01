# CollectorAPI.ps1
# Szkielet Collector API – odbiera minimalną telemetrię procesów,
# obsługuje weryfikację VT, sandbox orchestration i potwierdzenie operatora.
#
# Wymagania: mTLS (certyfikat klienta + CA), JWT/HMAC podpisywanie wiadomości.
# Uruchom jako Administrator w sesji z załadowanym SecretsManager.ps1.

#Requires -Version 5.1

# ── Konfiguracja ─────────────────────────────────────────────────────────────
$CollectorListenPrefix = "https://localhost:8443/collector/"
$CollectorCertThumb    = ""   # Odcisk palca certyfikatu TLS serwera (P/Invoke)
$CollectorJwtIssuer    = "USM-Collector"

# ── Schemat telemetrii ────────────────────────────────────────────────────────
# Minimalne pola akceptowane przez Collector:
#   PID          (int)     – identyfikator procesu
#   ProcessName  (string)  – nazwa procesu
#   SHA256       (string)  – hash SHA-256 pliku wykonywalnego
#   HostID       (string)  – GUID/identyfikator hosta
#   Timestamp    (string)  – ISO-8601
#   HmacSig      (string)  – podpis HMAC-SHA256 nad payload JSON

function Test-TelemetryPayload {
    <#
    .SYNOPSIS
        Waliduje minimalne pola telemetrii.
    .OUTPUTS
        $true jeśli payload jest kompletny i prawidłowy, $false w przeciwnym razie.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Payload)

    $required = @('PID','ProcessName','SHA256','HostID','Timestamp','HmacSig')
    foreach ($field in $required) {
        if (-not $Payload.ContainsKey($field) -or
            [string]::IsNullOrWhiteSpace($Payload[$field])) {
            Write-Warning "CollectorAPI: brak wymaganego pola '$field'."
            return $false
        }
    }
    # Weryfikacja podpisu HMAC
    $hmacSecret = Get-StoredSecret -Target "USM_HmacSecret"
    if (-not [string]::IsNullOrWhiteSpace($hmacSecret)) {
        $copy = [ordered]@{}
        foreach ($k in ($Payload.Keys | Where-Object { $_ -ne 'HmacSig' } | Sort-Object)) {
            $copy[$k] = $Payload[$k]
        }
        $canonical = $copy | ConvertTo-Json -Compress
        $expected  = Get-CollectorHmac -Text $canonical -Secret $hmacSecret
        if ($Payload['HmacSig'] -ne $expected) {
            Write-Warning "CollectorAPI: nieprawidłowy podpis HMAC."
            return $false
        }
    }
    return $true
}

function New-TelemetryPayload {
    <#
    .SYNOPSIS
        Buduje i podpisuje payload telemetrii gotowy do wysłania do Collector.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]   $PID,
        [Parameter(Mandatory)][string]$ProcessName,
        [Parameter(Mandatory)][string]$SHA256,
        [string]$HostID = $env:COMPUTERNAME
    )
    $ts = (Get-Date).ToString("o")
    $payload = [ordered]@{
        HostID      = $HostID
        PID         = $PID
        ProcessName = $ProcessName
        SHA256      = $SHA256
        Timestamp   = $ts
    }
    $hmacSecret = Get-StoredSecret -Target "USM_HmacSecret"
    $sig        = if ($hmacSecret) {
        $canonical = $payload | ConvertTo-Json -Compress
        Get-CollectorHmac -Text $canonical -Secret $hmacSecret
    } else { "" }
    $payload['HmacSig'] = $sig
    return $payload
}

function Invoke-CollectorVTCheck {
    <#
    .SYNOPSIS
        Zleca sprawdzenie hasha SHA256 w VirusTotal i zwraca wynik.
    .NOTES
        Wrapper – właściwa logika VT w UltraSecurityMonitor.ps1 / RemediationEngine.ps1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SHA256,
        [hashtable]$VTCache,
        [int]$CacheTTLSeconds = 3600
    )
    # Sprawdź lokalny cache
    if ($null -ne $VTCache -and $VTCache.ContainsKey($SHA256)) {
        $entry = $VTCache[$SHA256]
        if (((Get-Date) - $entry.Time).TotalSeconds -lt $CacheTTLSeconds) {
            return $entry.Result
        }
    }
    # Odpytaj VT
    $apiKey = Get-StoredSecret -Target "USM_VTApiKey"
    if ([string]::IsNullOrWhiteSpace($apiKey)) { return $null }

    try {
        $uri  = "https://www.virustotal.com/api/v3/files/$SHA256"
        $resp = Invoke-RestMethod -Uri $uri -Headers @{ "x-apikey" = $apiKey } `
                    -Method Get -TimeoutSec 15 -ErrorAction Stop
        $stats = $resp.data.attributes.last_analysis_stats
        if ($null -eq $stats) { return $null }
        $result = [PSCustomObject]@{
            Malicious  = $stats.malicious
            Suspicious = $stats.suspicious
            Undetected = $stats.undetected
            Harmless   = $stats.harmless
        }
        if ($null -ne $VTCache) {
            $VTCache[$SHA256] = @{ Result = $result; Time = (Get-Date) }
        }
        return $result
    } catch { return $null }
}

function Request-OperatorApproval {
    <#
    .SYNOPSIS
        Wysyła żądanie potwierdzenia do operatora (Discord/e-mail) i czeka na odpowiedź.
    .PARAMETER Action
        Opis proponowanej akcji naprawczej.
    .PARAMETER TimeoutSeconds
        Czas oczekiwania na odpowiedź operatora (domyślnie 120 s).
    .OUTPUTS
        $true gdy operator zatwierdził, $false gdy odrzucił lub timeout.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Action,
        [int]$TimeoutSeconds = 120,
        [switch]$DryRun
    )
    $msg = "🔔 OPERATOR APPROVAL REQUIRED`nAkcja: $Action`nZatwierdź lub odrzuć w ciągu $TimeoutSeconds s."
    Send-DiscordAlert -Message $msg -DryRun:$DryRun
    Send-EmailAlert   -Subject "Operator Approval Required" -Body $msg -DryRun:$DryRun

    Write-Host $msg
    Write-Host "Wpisz 'yes' aby zatwierdzić lub cokolwiek innego aby odrzucić (timeout ${TimeoutSeconds}s):"

    # Prosty mechanizm timeoutu przez Job
    $job = Start-Job -ScriptBlock { Read-Host }
    $done = Wait-Job $job -Timeout $TimeoutSeconds
    if ($null -eq $done) {
        Stop-Job  $job
        Remove-Job $job -Force
        Write-Warning "CollectorAPI: timeout zatwierdzenia operatora."
        return $false
    }
    $answer = Receive-Job $job
    Remove-Job $job -Force
    return ($answer -eq 'yes')
}

function Invoke-CollectorSandboxOrchestration {
    <#
    .SYNOPSIS
        Zleca analizę pliku wykonywalnego w izolowanym środowisku (szkielet).
    .NOTES
        Implementacja sandbox deleguje do RemediationEngine.ps1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string]$SHA256,
        [switch]$DryRun
    )
    Write-Warning "CollectorAPI: sandbox orchestration – wywołanie RemediationEngine."
    # Importuj silnik naprawczy (jeśli nie załadowany)
    $enginePath = Join-Path $PSScriptRoot "RemediationEngine.ps1"
    if (Test-Path $enginePath) {
        . $enginePath
        Invoke-SandboxAnalysis -FilePath $FilePath -SHA256 $SHA256 -DryRun:$DryRun
    } else {
        Write-Warning "CollectorAPI: brak RemediationEngine.ps1."
    }
}

# ── JWT (minimalny HS256) ─────────────────────────────────────────────────────

function New-CollectorJwt {
    <#
    .SYNOPSIS
        Generuje minimalny token JWT (HS256) do uwierzytelniania żądań Collector.
    #>
    [CmdletBinding()]
    param([string]$Subject = $env:COMPUTERNAME)

    $hmacSecret = Get-StoredSecret -Target "USM_HmacSecret"
    if ([string]::IsNullOrWhiteSpace($hmacSecret)) {
        Write-Warning "CollectorAPI: brak klucza HMAC – JWT nie może być wygenerowany."
        return $null
    }

    $header  = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(
                   '{"alg":"HS256","typ":"JWT"}')) -replace '=+$','' -replace '\+','-' -replace '/','_'
    $now     = [int]((Get-Date).ToUniversalTime() - [datetime]'1970-01-01T00:00:00Z').TotalSeconds
    $claims  = [ordered]@{ iss = $CollectorJwtIssuer; sub = $Subject; iat = $now; exp = $now + 300 }
    $payload = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(
                   ($claims | ConvertTo-Json -Compress))) -replace '=+$','' -replace '\+','-' -replace '/','_'
    $unsigned = "$header.$payload"
    $sig     = Get-CollectorHmac -Text $unsigned -Secret $hmacSecret -Raw
    $sigB64  = [Convert]::ToBase64String($sig) -replace '=+$','' -replace '\+','-' -replace '/','_'
    return "$unsigned.$sigB64"
}

# ── HMAC helper (wewnętrzny) ─────────────────────────────────────────────────

function Get-CollectorHmac {
    param([string]$Text, [string]$Secret, [switch]$Raw)
    $enc  = [Text.Encoding]::UTF8
    $hmac = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key = $enc.GetBytes($Secret)
    $bytes    = $hmac.ComputeHash($enc.GetBytes($Text))
    if ($Raw) { return $bytes }
    return ([BitConverter]::ToString($bytes) -replace '-').ToLower()
}
