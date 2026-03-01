# CollectorAPI.ps1
# Prosty kolektor REST API oparty na HttpListener – przyjmuje zdarzenia SIEM (JSON)
# od wielu hostów i zapisuje je do centralnego pliku NDJSON.
# Uruchom jako Administrator (wymagane przez HttpListener na Windows).
# Dołącz i uruchom: . .\CollectorAPI.ps1; Start-CollectorAPI

#Requires -Version 5.1

# --------- KONFIGURACJA ---------
$script:CollectorPort    = 8765
$script:CollectorLogPath = Join-Path $env:TEMP "collector-events.json"
$script:CollectorApiKey  = ""          # Opcjonalny klucz Bearer; pusty = brak autoryzacji
$script:CollectorRunning = $false
$script:CollectorListener = $null

function Set-CollectorAPIConfig {
    <#
    .SYNOPSIS
        Konfiguruje parametry kolektora przed uruchomieniem.
    .PARAMETER Port
        Numer portu TCP, na którym kolektor nasłuchuje. Domyślnie: 8765.
    .PARAMETER LogPath
        Ścieżka do pliku NDJSON z zebranymi zdarzeniami.
    .PARAMETER ApiKey
        Klucz Bearer API (pusty = brak uwierzytelniania).
    #>
    param(
        [int]   $Port    = 8765,
        [string]$LogPath = (Join-Path $env:TEMP "collector-events.json"),
        [string]$ApiKey  = ""
    )
    $script:CollectorPort    = $Port
    $script:CollectorLogPath = $LogPath
    $script:CollectorApiKey  = $ApiKey
}

function Start-CollectorAPI {
    <#
    .SYNOPSIS
        Uruchamia kolektor API w bieżącym wątku (blokujące).
        Aby uruchomić w tle: Start-Job { . .\CollectorAPI.ps1; Start-CollectorAPI }
    .PARAMETER Port
        Nadpisuje skonfigurowany port (opcjonalnie).
    #>
    param([int]$Port = 0)
    if ($Port -gt 0) { $script:CollectorPort = $Port }

    $prefix = "http://+:$($script:CollectorPort)/collector/"
    $script:CollectorListener = New-Object System.Net.HttpListener
    $script:CollectorListener.Prefixes.Add($prefix)
    try {
        $script:CollectorListener.Start()
    } catch {
        Write-Warning "CollectorAPI: Nie można uruchomić na porcie $($script:CollectorPort). Sprawdź uprawnienia Administratora i czy port nie jest zajęty. Błąd: $_"
        return
    }
    $script:CollectorRunning = $true
    Write-Host "CollectorAPI nasłuchuje na $prefix (Ctrl+C lub Stop-CollectorAPI aby zatrzymać)"

    while ($script:CollectorRunning) {
        try {
            $ctx = $script:CollectorListener.GetContext()
            Invoke-CollectorRequest -Context $ctx
        } catch [System.Net.HttpListenerException] {
            # Kolektor zatrzymany
            break
        } catch {
            Write-Warning "CollectorAPI błąd: $_"
        }
    }
}

function Stop-CollectorAPI {
    <#
    .SYNOPSIS
        Zatrzymuje kolektor API.
    #>
    $script:CollectorRunning = $false
    if ($null -ne $script:CollectorListener -and $script:CollectorListener.IsListening) {
        try { $script:CollectorListener.Stop() } catch {}
    }
}

function Invoke-CollectorRequest {
    <#
    .SYNOPSIS
        Obsługuje pojedyncze żądanie HTTP do kolektora.
    #>
    param([System.Net.HttpListenerContext]$Context)
    $req  = $Context.Request
    $resp = $Context.Response

    # Obsługa tylko POST /collector/event
    if ($req.HttpMethod -ne "POST" -or $req.Url.AbsolutePath -notmatch '/collector/event') {
        $resp.StatusCode = 404
        $resp.Close()
        return
    }

    # Weryfikacja klucza Bearer (jeśli skonfigurowany)
    if (-not [string]::IsNullOrWhiteSpace($script:CollectorApiKey)) {
        $auth = $req.Headers["Authorization"]
        if ($auth -ne "Bearer $($script:CollectorApiKey)") {
            $resp.StatusCode = 401
            $resp.Close()
            return
        }
    }

    # Odczyt ciała żądania (JSON)
    try {
        $reader = New-Object System.IO.StreamReader($req.InputStream, $req.ContentEncoding)
        $body   = $reader.ReadToEnd()
        $reader.Close()

        # Walidacja JSON
        $parsed = $body | ConvertFrom-Json -ErrorAction Stop

        # Wzbogać o datę odbioru i adres źródłowy
        $enriched = [ordered]@{
            received_at  = (Get-Date).ToString("o")
            source_ip    = $req.RemoteEndPoint.Address.ToString()
        }
        foreach ($prop in $parsed.PSObject.Properties) {
            $enriched[$prop.Name] = $prop.Value
        }

        Add-Content -Path $script:CollectorLogPath -Value ($enriched | ConvertTo-Json -Compress)

        $resp.StatusCode = 200
        $responseBytes   = [System.Text.Encoding]::UTF8.GetBytes('{"status":"ok"}')
        $resp.ContentType   = "application/json"
        $resp.ContentLength64 = $responseBytes.Length
        $resp.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
    } catch {
        $resp.StatusCode = 400
        $errorBytes = [System.Text.Encoding]::UTF8.GetBytes('{"status":"error","message":"invalid json"}')
        $resp.ContentType     = "application/json"
        $resp.ContentLength64 = $errorBytes.Length
        $resp.OutputStream.Write($errorBytes, 0, $errorBytes.Length)
    } finally {
        $resp.OutputStream.Close()
        $resp.Close()
    }
}

function Send-EventToCollector {
    <#
    .SYNOPSIS
        Wysyła zdarzenie SIEM (hashtable) do zdalnego kolektora REST.
    .PARAMETER CollectorUrl
        URL kolektora, np. "http://192.168.1.10:8765/collector/event".
    .PARAMETER EventData
        Hashtable ze zdarzeniem (powinna zawierać co najmniej: event_type, severity).
    .PARAMETER ApiKey
        Opcjonalny klucz Bearer.
    #>
    param(
        [Parameter(Mandatory)][string]$CollectorUrl,
        [Parameter(Mandatory)][hashtable]$EventData,
        [string]$ApiKey = ""
    )
    try {
        $body    = $EventData | ConvertTo-Json -Compress
        $headers = @{ "Content-Type" = "application/json" }
        if (-not [string]::IsNullOrWhiteSpace($ApiKey)) {
            $headers["Authorization"] = "Bearer $ApiKey"
        }
        Invoke-RestMethod -Uri $CollectorUrl -Method Post -Body $body -Headers $headers `
            -TimeoutSec 10 -ErrorAction SilentlyContinue
    } catch {}
}
