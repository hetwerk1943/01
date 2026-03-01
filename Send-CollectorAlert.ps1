# Send-CollectorAlert.ps1
# Zunifikowany moduł wysyłania alertów – obsługuje Discord, e-mail oraz lokalny dziennik SIEM.
# Dołącz ten plik za pomocą: . .\Send-CollectorAlert.ps1

#Requires -Version 5.1

# --------- DOMYŚLNA KONFIGURACJA (nadpisz przed wywołaniem funkcji) ---------
$script:CollectorConfig = @{
    DiscordWebhookUrl  = ""
    EmailEnabled       = $false
    SmtpServer         = ""
    SmtpFrom           = ""
    SmtpTo             = ""
    SmtpUseSsl         = $true
    SmtpPort           = 587
    SiemLogPath        = Join-Path $env:TEMP "collector-siem.json"
    MaxDiscordLength   = 2000
}

function Set-CollectorConfig {
    <#
    .SYNOPSIS
        Nadpisuje konfigurację modułu alertów.
    .PARAMETER Config
        Hashtable z kluczami zgodnymi z $script:CollectorConfig.
    #>
    param([Parameter(Mandatory)][hashtable]$Config)
    foreach ($key in $Config.Keys) {
        $script:CollectorConfig[$key] = $Config[$key]
    }
}

function Send-CollectorAlert {
    <#
    .SYNOPSIS
        Wysyła alert przez wszystkie skonfigurowane kanały (Discord, e-mail, SIEM JSON).
    .PARAMETER Subject
        Tytuł / temat alertu (używany w e-mail i SIEM).
    .PARAMETER Message
        Treść alertu.
    .PARAMETER Severity
        Poziom ważności: Low | Medium | High | Critical. Domyślnie: High.
    .PARAMETER EventType
        Typ zdarzenia (dla SIEM). Domyślnie: GenericAlert.
    .PARAMETER Data
        Opcjonalna hashtable z dodatkowymi danymi (dla SIEM).
    #>
    param(
        [Parameter(Mandatory)][string]$Subject,
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet("Low","Medium","High","Critical")][string]$Severity  = "High",
        [string]$EventType = "GenericAlert",
        [hashtable]$Data   = @{}
    )

    Send-CollectorDiscord  -Message "[$Severity] $Subject`n$Message"
    Send-CollectorEmail    -Subject "[$Severity] $Subject" -Body $Message
    Write-CollectorSiem    -EventType $EventType -Severity $Severity -Subject $Subject `
                           -Message $Message -Data $Data
}

# --------- KANAŁ: DISCORD ---------
function Send-CollectorDiscord {
    param([Parameter(Mandatory)][string]$Message)
    $url = $script:CollectorConfig.DiscordWebhookUrl
    if ([string]::IsNullOrWhiteSpace($url)) { return }

    $maxLen = [int]$script:CollectorConfig.MaxDiscordLength
    if ($Message.Length -gt $maxLen) {
        $Message = $Message.Substring(0, $maxLen - 3) + "..."
    }
    $payload = @{ content = $Message } | ConvertTo-Json
    try {
        Invoke-RestMethod -Uri $url -Method Post -Body $payload `
            -ContentType "application/json" -TimeoutSec 10 -ErrorAction SilentlyContinue
    } catch {}
}

# --------- KANAŁ: E-MAIL ---------
function Send-CollectorEmail {
    param(
        [Parameter(Mandatory)][string]$Subject,
        [Parameter(Mandatory)][string]$Body
    )
    $cfg = $script:CollectorConfig
    if (-not $cfg.EmailEnabled) { return }
    if ([string]::IsNullOrWhiteSpace($cfg.SmtpServer) -or
        [string]::IsNullOrWhiteSpace($cfg.SmtpFrom)   -or
        [string]::IsNullOrWhiteSpace($cfg.SmtpTo))    { return }
    try {
        Send-MailMessage -To $cfg.SmtpTo -From $cfg.SmtpFrom -Subject $Subject -Body $Body `
            -SmtpServer $cfg.SmtpServer -Port ([int]$cfg.SmtpPort) -UseSsl:$cfg.SmtpUseSsl `
            -ErrorAction SilentlyContinue
    } catch {}
}

# --------- KANAŁ: SIEM JSON (NDJSON) ---------
function Write-CollectorSiem {
    param(
        [string]$EventType = "GenericAlert",
        [string]$Severity  = "High",
        [string]$Subject   = "",
        [string]$Message   = "",
        [hashtable]$Data   = @{}
    )
    $siemPath = $script:CollectorConfig.SiemLogPath
    if ([string]::IsNullOrWhiteSpace($siemPath)) { return }
    $event = [ordered]@{
        timestamp  = (Get-Date).ToString("o")
        host       = $env:COMPUTERNAME
        user       = $env:USERNAME
        event_type = $EventType
        severity   = $Severity
        subject    = $Subject
        message    = $Message
        data       = $Data
    }
    try {
        Add-Content -Path $siemPath -Value ($event | ConvertTo-Json -Compress)
    } catch {}
}
