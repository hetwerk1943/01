# Invoke-ProtectedEndpoint.ps1
# mTLS + JWT protected endpoint – Ultra Security Monitor
# Uruchom z parametrami: -Payload, -JwtToken, -ClientCertificate
# Wymaga zmiennej środowiskowej USM_HMAC_SECRET.

#Requires -Version 5.1

param(
    [Parameter(Mandatory)][hashtable]$Payload,
    [Parameter(Mandatory)][string]$JwtToken,
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$ClientCertificate,
    [switch]$NonInteractive
)

# --------- KONFIGURACJA ---------
$BaseFolder  = Join-Path $env:USERPROFILE "Documents\SecurityMonitor"
$SiemFolder  = Join-Path $BaseFolder "SIEM"
$SiemLogPath = Join-Path $SiemFolder "siem.json"

# HMAC secret – ustaw zmienną środowiskową USM_HMAC_SECRET (nigdy nie przechowuj w kodzie)
$HmacSecret = $env:USM_HMAC_SECRET
if ([string]::IsNullOrWhiteSpace($HmacSecret)) {
    Write-Error "Zmienna środowiskowa USM_HMAC_SECRET nie jest ustawiona."
    exit 1
}

# Oczekiwany odcisk certyfikatu klienta (opcjonalnie – ustaw USM_CLIENT_CERT_THUMBPRINT)
$ExpectedThumbprint = $env:USM_CLIENT_CERT_THUMBPRINT

# --------- FUNKCJA POMOCNICZA: BASE64URL ---------
function ConvertFrom-Base64Url {
    param([string]$Value)
    $padded = $Value.Replace('-', '+').Replace('_', '/')
    switch ($padded.Length % 4) {
        2 { $padded += '==' }
        3 { $padded += '=' }
    }
    return [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($padded))
}

# --------- WALIDACJA JWT + HMAC ---------
function Test-JwtToken {
    param([string]$Token, [string]$Secret)
    if ([string]::IsNullOrWhiteSpace($Token)) { return $false }
    $parts = $Token -split '\.'
    if ($parts.Count -ne 3) { return $false }
    try {
        $header = ConvertFrom-Base64Url $parts[0] | ConvertFrom-Json
        $claims = ConvertFrom-Base64Url $parts[1] | ConvertFrom-Json
        # Akceptuj wyłącznie HMAC-SHA256
        if ($header.alg -ne 'HS256') { return $false }
        # Sprawdź datę wygaśnięcia tokenu
        $now = [long]([datetime]::UtcNow - [datetime]'1970-01-01T00:00:00Z').TotalSeconds
        if ($null -ne $claims.exp -and [long]$claims.exp -lt $now) { return $false }
        # Weryfikacja podpisu HMAC-SHA256
        $signingInput = "$($parts[0]).$($parts[1])"
        $hmac = New-Object System.Security.Cryptography.HMACSHA256
        $hmac.Key = [System.Text.Encoding]::UTF8.GetBytes($Secret)
        $computed = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($signingInput))
        $hmac.Dispose()
        $sig = [Convert]::ToBase64String($computed).Replace('+', '-').Replace('/', '_').TrimEnd('=')
        return ($sig -ceq $parts[2])
    } catch { return $false }
}

# --------- WALIDACJA mTLS (certyfikat klienta) ---------
function Test-ClientCertificate {
    param(
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Cert,
        [string]$ExpectedThumb
    )
    if ($null -eq $Cert) { return $false }
    if (-not $Cert.Verify()) { return $false }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedThumb)) {
        return ($Cert.Thumbprint -ieq ($ExpectedThumb -replace '\s', ''))
    }
    return $true
}

# --------- ZAPIS DO CENTRALNEJ BAZY ZDARZEŃ ---------
function Write-EventToSiem {
    param([string]$EventType, [string]$Severity, [hashtable]$Data)
    $event = [ordered]@{
        timestamp  = (Get-Date).ToString("o")
        host       = $env:COMPUTERNAME
        user       = $env:USERNAME
        event_type = $EventType
        severity   = $Severity
        data       = $Data
    }
    try {
        if (-not (Test-Path $SiemFolder)) {
            New-Item -Path $SiemFolder -ItemType Directory -Force | Out-Null
        }
        Add-Content -Path $SiemLogPath -Value ($event | ConvertTo-Json -Compress)
    } catch { Write-Warning "Write-EventToSiem error: $_" }
}

# --------- SANDBOX ORCHESTRATION ---------
function Invoke-Sandboxed {
    param([hashtable]$Payload)
    # Uruchom przetwarzanie payload w izolowanym zadaniu PowerShell (sandbox)
    $job = Start-Job -ScriptBlock {
        param($p)
        $allowedKeys = @('action', 'target', 'parameters')
        $safe = @{}
        foreach ($k in $p.Keys) {
            if ($allowedKeys -contains $k) { $safe[$k] = $p[$k] }
        }
        return $safe
    } -ArgumentList $Payload
    $result = $job | Wait-Job | Receive-Job
    Remove-Job -Job $job -Force
    return $result
}

# --------- OPERATOR CONFIRMATION ---------
function Confirm-OperatorAction {
    param([hashtable]$Payload, [bool]$Auto)
    if ($Auto) { return $true }
    $summary = ($Payload.Keys | ForEach-Object { "$_=$($Payload[$_])" }) -join '; '
    Write-Host "⚠️  Wymagane potwierdzenie operatora dla: { $summary }" -ForegroundColor Yellow
    $answer = Read-Host "Kontynuować? [y/N]"
    return ($answer -ieq 'y')
}

# --------- GŁÓWNA LOGIKA ENDPOINT ---------

# 1. Walidacja mTLS
if (-not (Test-ClientCertificate -Cert $ClientCertificate -ExpectedThumb $ExpectedThumbprint)) {
    Write-EventToSiem -EventType "EndpointAuth" -Severity "Critical" `
        -Data @{ result = "mTLS_failed"; host = $env:COMPUTERNAME }
    Write-Error "Walidacja mTLS nieudana: brak lub nieprawidłowy certyfikat klienta."
    exit 1
}

# 2. Walidacja JWT + HMAC
if (-not (Test-JwtToken -Token $JwtToken -Secret $HmacSecret)) {
    Write-EventToSiem -EventType "EndpointAuth" -Severity "Critical" `
        -Data @{ result = "JWT_failed"; host = $env:COMPUTERNAME }
    Write-Error "Walidacja JWT nieudana: nieprawidłowy token lub podpis HMAC."
    exit 1
}

# 3. Zapis do centralnej bazy zdarzeń
Write-EventToSiem -EventType "EndpointAccess" -Severity "Info" `
    -Data @{ result = "auth_ok"; payloadKeys = ($Payload.Keys -join ',') }

# 4. Operator confirmation
if (-not (Confirm-OperatorAction -Payload $Payload -Auto $NonInteractive.IsPresent)) {
    Write-EventToSiem -EventType "EndpointAccess" -Severity "Info" `
        -Data @{ result = "operator_rejected" }
    Write-Host "Operacja anulowana przez operatora." -ForegroundColor Cyan
    exit 0
}

# 5. Sandbox orchestration
$result = Invoke-Sandboxed -Payload $Payload

Write-EventToSiem -EventType "EndpointExecution" -Severity "Info" `
    -Data @{ result = "executed"; output = ($result | ConvertTo-Json -Compress) }

Write-Host "✅ Endpoint wykonany pomyślnie." -ForegroundColor Green
return $result
