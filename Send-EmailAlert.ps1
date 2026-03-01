# Send-EmailAlert.ps1
# Wysyła alerty bezpieczeństwa przez SMTP z TLS 1.2+, retry/backoff i HMAC-SHA256.
# Klucze SMTP ładowane z Windows Credential Manager (SecretsManager.ps1).

#Requires -Version 5.1

<#
.SYNOPSIS
    Wyślij alert e-mail z podpisem HMAC w nagłówku X-USM-Signature.
.PARAMETER Subject
    Temat wiadomości.
.PARAMETER Body
    Treść wiadomości (zostanie sanityzowana).
.PARAMETER SmtpServer
    Adres serwera SMTP. Jeśli pominięty – z Credential Manager "USM_SmtpServer".
.PARAMETER SmtpPort
    Port SMTP (domyślnie 587).
.PARAMETER SmtpFrom
    Adres nadawcy. Jeśli pominięty – z Credential Manager "USM_SmtpFrom".
.PARAMETER SmtpTo
    Adres odbiorcy. Jeśli pominięty – z Credential Manager "USM_SmtpTo".
.PARAMETER HmacSecret
    Sekret HMAC. Jeśli pominięty – z Credential Manager "USM_HmacSecret".
.PARAMETER MaxRetries
    Liczba prób wysłania (domyślnie 3).
.PARAMETER DryRun
    Gdy $true – tylko loguje na ekran, nie wysyła.
#>
function Send-EmailAlert {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Subject,
        [Parameter(Mandatory)][string]$Body,
        [string]$SmtpServer,
        [int]$SmtpPort      = 587,
        [string]$SmtpFrom,
        [string]$SmtpTo,
        [string]$HmacSecret,
        [int]$MaxRetries    = 3,
        [switch]$DryRun
    )

    # ── Wymuszenie TLS 1.2+ ─────────────────────────────────────────────────
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

    # ── Załaduj konfigurację z Credential Manager ────────────────────────────
    if ([string]::IsNullOrWhiteSpace($SmtpServer)) {
        $SmtpServer = Get-StoredSecret -Target "USM_SmtpServer"
    }
    if ([string]::IsNullOrWhiteSpace($SmtpFrom)) {
        $SmtpFrom   = Get-StoredSecret -Target "USM_SmtpFrom"
    }
    if ([string]::IsNullOrWhiteSpace($SmtpTo)) {
        $SmtpTo     = Get-StoredSecret -Target "USM_SmtpTo"
    }

    # Jeśli brakuje konfiguracji – cicho wyjdź
    if ([string]::IsNullOrWhiteSpace($SmtpServer) -or
        [string]::IsNullOrWhiteSpace($SmtpFrom)   -or
        [string]::IsNullOrWhiteSpace($SmtpTo)) { return }

    if ([string]::IsNullOrWhiteSpace($HmacSecret)) {
        $HmacSecret = Get-StoredSecret -Target "USM_HmacSecret"
    }

    # ── Sanityzacja treści ───────────────────────────────────────────────────
    $safeBody = Invoke-EmailPayloadSanitize -Text $Body

    # ── Podpis HMAC-SHA256 jako dodatkowy nagłówek w treści ──────────────────
    $signature = if (-not [string]::IsNullOrWhiteSpace($HmacSecret)) {
        Get-EmailHmacSignature -Text $safeBody -Secret $HmacSecret
    } else { "" }
    if ($signature) {
        $safeBody = "X-USM-Signature: sha256=$signature`r`n`r`n$safeBody"
    }

    # ── Pobierz dane uwierzytelniające SMTP ──────────────────────────────────
    $smtpPass   = Get-StoredSecret -Target "USM_SmtpPassword"
    $credential = if (-not [string]::IsNullOrWhiteSpace($smtpPass)) {
        New-Object System.Management.Automation.PSCredential(
            $SmtpFrom,
            (ConvertTo-SecureString $smtpPass -AsPlainText -Force))
    } else { $null }

    if ($DryRun) {
        Write-Host "[DryRun] Send-EmailAlert To=$SmtpTo Subject=$Subject"
        return
    }

    # ── Retry / exponential backoff ──────────────────────────────────────────
    $delay = 2
    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            $params = @{
                To         = $SmtpTo
                From       = $SmtpFrom
                Subject    = $Subject
                Body       = $safeBody
                SmtpServer = $SmtpServer
                Port       = $SmtpPort
                UseSsl     = $true
                ErrorAction = 'Stop'
            }
            if ($null -ne $credential) { $params['Credential'] = $credential }
            Send-MailMessage @params
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

function Invoke-EmailPayloadSanitize {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return "" }
    $out = $Text -replace '(?i)[A-Za-z]:\\[^\s\r\n"'']+', '<path>'
    $out = $out  -replace '\\\\[^\s\r\n]+',                '<unc>'
    $out = $out  -replace '(?i)\b[0-9a-f]{32,}\b',         '<hash>'
    return $out
}

function Get-EmailHmacSignature {
    param([string]$Text, [string]$Secret)
    $enc  = [Text.Encoding]::UTF8
    $hmac = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key = $enc.GetBytes($Secret)
    $bytes    = $hmac.ComputeHash($enc.GetBytes($Text))
    return ([BitConverter]::ToString($bytes) -replace '-').ToLower()
}
