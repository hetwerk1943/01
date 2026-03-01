# Send-CollectorAlert.ps1
# Centralized alert-dispatch module for Ultra Security Monitor.
# Supports Discord webhook, SMTP e-mail, and CollectorAPI endpoint.
# Dot-source this file before calling Send-CollectorAlert.

#Requires -Version 5.1

# ---------------------------------------------------------------------------
function Send-CollectorAlert {
    <#
    .SYNOPSIS
        Dispatches a security alert through all configured channels.
    .PARAMETER Subject
        Short title used as the e-mail subject and embedded in Discord message.
    .PARAMETER Message
        Full alert body text.
    .PARAMETER DiscordWebhookUrl
        Discord Incoming Webhook URL. Leave empty to skip Discord delivery.
    .PARAMETER EmailAlerts
        Set to $true to enable SMTP delivery.
    .PARAMETER SmtpServer
        Hostname or IP of the SMTP relay.
    .PARAMETER SmtpFrom
        Sender e-mail address.
    .PARAMETER SmtpTo
        Recipient e-mail address.
    .PARAMETER SmtpPort
        SMTP port (default 587).
    .PARAMETER SmtpUseSsl
        Enable STARTTLS/SSL on the SMTP connection (default $true).
    .PARAMETER CollectorApiUrl
        Optional HTTP(S) endpoint that accepts a JSON POST body.
        Leave empty to skip.
    .PARAMETER CollectorApiKey
        Bearer token or API key for the CollectorAPI endpoint.
    #>
    param(
        [Parameter(Mandatory)][string]$Subject,
        [Parameter(Mandatory)][string]$Message,

        # Discord
        [string]$DiscordWebhookUrl = "",

        # E-mail
        [bool]$EmailAlerts     = $false,
        [string]$SmtpServer    = "",
        [string]$SmtpFrom      = "",
        [string]$SmtpTo        = "",
        [int]$SmtpPort         = 587,
        [bool]$SmtpUseSsl      = $true,

        # Collector API
        [string]$CollectorApiUrl = "",
        [string]$CollectorApiKey = ""
    )

    _Send-Discord   -Subject $Subject -Message $Message -WebhookUrl $DiscordWebhookUrl
    _Send-Email     -Subject $Subject -Message $Message -Enabled $EmailAlerts `
                    -Server $SmtpServer -From $SmtpFrom -To $SmtpTo `
                    -Port $SmtpPort -UseSsl $SmtpUseSsl
    _Send-Collector -Subject $Subject -Message $Message `
                    -Url $CollectorApiUrl -ApiKey $CollectorApiKey
}

# ---------------------------------------------------------------------------
# Internal helpers – not exported (private by naming convention)
# ---------------------------------------------------------------------------
function _Send-Discord {
    param([string]$Subject, [string]$Message, [string]$WebhookUrl)

    if ([string]::IsNullOrWhiteSpace($WebhookUrl)) { return }

    $maxLen  = 2000
    $content = if ($Subject) { "**$Subject**`n$Message" } else { $Message }
    if ($content.Length -gt $maxLen) {
        $content = $content.Substring(0, $maxLen - 3) + "..."
    }

    $payload = @{ content = $content } | ConvertTo-Json
    try {
        Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $payload `
            -ContentType "application/json" -TimeoutSec 10 -ErrorAction SilentlyContinue
    } catch {}
}

function _Send-Email {
    param(
        [string]$Subject, [string]$Message,
        [bool]$Enabled,
        [string]$Server, [string]$From, [string]$To,
        [int]$Port, [bool]$UseSsl
    )

    if (-not $Enabled) { return }
    if ([string]::IsNullOrWhiteSpace($Server) -or
        [string]::IsNullOrWhiteSpace($From)   -or
        [string]::IsNullOrWhiteSpace($To))     { return }

    try {
        Send-MailMessage -To $To -From $From -Subject $Subject -Body $Message `
            -SmtpServer $Server -Port $Port -UseSsl:$UseSsl -ErrorAction SilentlyContinue
    } catch {}
}

function _Send-Collector {
    param([string]$Subject, [string]$Message, [string]$Url, [string]$ApiKey)

    if ([string]::IsNullOrWhiteSpace($Url)) { return }

    $body = @{
        subject   = $Subject
        message   = $Message
        host      = $env:COMPUTERNAME
        timestamp = (Get-Date).ToString("o")
    } | ConvertTo-Json

    $headers = @{ "Content-Type" = "application/json" }
    if (-not [string]::IsNullOrWhiteSpace($ApiKey)) {
        $headers["Authorization"] = "Bearer $ApiKey"
    }

    try {
        Invoke-RestMethod -Uri $Url -Method Post -Body $body -Headers $headers `
            -TimeoutSec 10 -ErrorAction SilentlyContinue
    } catch {}
}
