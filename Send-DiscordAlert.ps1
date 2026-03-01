# Send-DiscordAlert.ps1
# Wysyła alerty bezpieczeństwa do Discord Webhook.
# Wymagania: TLS 1.2+, retry/backoff, HMAC-SHA256 podpis, sanityzacja payloadu.
# Klucz HMAC i URL webhooka ładowane są z Windows Credential Manager (SecretsManager.ps1).

#Requires -Version 5.1

<#
.SYNOPSIS
    Wyślij zaszyfrowany alert do Discord z podpisem HMAC-SHA256.
.PARAMETER Message
    Treść wiadomości (zostanie skrócona do $MaxLength znaków).
.PARAMETER WebhookUrl
    URL webhooka Discord. Jeśli pominięty, odczytywany z Credential Manager
    (target: "USM_DiscordWebhook").
.PARAMETER HmacSecret
    Sekret HMAC do podpisywania payloadu. Jeśli pominięty, odczytywany
    z Credential Manager (target: "USM_HmacSecret").
.PARAMETER MaxLength
    Maksymalna długość wiadomości (domyślnie 1900 – z marginesem na prefiks).
.PARAMETER MaxRetries
    Liczba prób ponownego wysłania po błędzie (domyślnie 3).
.PARAMETER DryRun
    Gdy $true – nie wysyła żadnych żądań, tylko loguje na ekran.
#>
function Send-DiscordAlert {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [string]$WebhookUrl,
        [string]$HmacSecret,
        [int]$MaxLength   = 1900,
        [int]$MaxRetries  = 3,
        [switch]$DryRun
    )

    # ── Wymuszenie TLS 1.2+ ─────────────────────────────────────────────────
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

    # ── Załaduj sekrety z Credential Manager (jeśli nie podane explicite) ───
    if ([string]::IsNullOrWhiteSpace($WebhookUrl)) {
        $WebhookUrl = Get-StoredSecret -Target "USM_DiscordWebhook"
    }
    if ([string]::IsNullOrWhiteSpace($WebhookUrl)) { return }   # brak konfiguracji

    if ([string]::IsNullOrWhiteSpace($HmacSecret)) {
        $HmacSecret = Get-StoredSecret -Target "USM_HmacSecret"
    }

    # ── Sanityzacja: usuń ścieżki bezwzględne i dane wrażliwe ───────────────
    $sanitized = Invoke-PayloadSanitize -Text $Message -MaxLength $MaxLength

    # ── Oblicz podpis HMAC-SHA256 ────────────────────────────────────────────
    $signature = if (-not [string]::IsNullOrWhiteSpace($HmacSecret)) {
        Get-HmacSignature -Text $sanitized -Secret $HmacSecret
    } else { "" }

    $payload = @{ content = $sanitized } | ConvertTo-Json -Compress
    $headers = @{ "Content-Type" = "application/json" }
    if ($signature) { $headers["X-USM-Signature"] = "sha256=$signature" }

    if ($DryRun) {
        Write-Host "[DryRun] Send-DiscordAlert payload: $payload"
        return
    }

    # ── Retry / exponential backoff ──────────────────────────────────────────
    $delay = 2
    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $payload `
                -Headers $headers -TimeoutSec 15 -ErrorAction Stop | Out-Null
            return   # sukces
        } catch {
            if ($i -lt $MaxRetries) {
                Start-Sleep -Seconds $delay
                $delay *= 2
            }
        }
    }
}

# ── Helpers ──────────────────────────────────────────────────────────────────

function Invoke-PayloadSanitize {
    param([string]$Text, [int]$MaxLength = 1900)
    if ([string]::IsNullOrEmpty($Text)) { return "" }
    # Redaguj ścieżki bezwzględne Windows (C:\..., UNC \\...)
    $out = $Text -replace '(?i)[A-Za-z]:\\[^\s`n"'']+', '<path>'
    $out = $out  -replace '\\\\[^\s`n]+',                '<unc>'
    $out = $out  -replace '(?i)\b[0-9a-f]{32,}\b',      '<hash>'
    # Skróć do limitu
    if ($out.Length -gt $MaxLength) {
        $out = $out.Substring(0, $MaxLength - 3) + "..."
    }
    return $out
}

function Get-HmacSignature {
    param([string]$Text, [string]$Secret)
    $enc    = [Text.Encoding]::UTF8
    $hmac   = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key = $enc.GetBytes($Secret)
    $bytes  = $hmac.ComputeHash($enc.GetBytes($Text))
    return ([BitConverter]::ToString($bytes) -replace '-').ToLower()
}
