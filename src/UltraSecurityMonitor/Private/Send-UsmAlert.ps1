# Private\Send-UsmAlert.ps1
# Discord and e-mail alert helpers.

function Send-UsmDiscordAlert {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Message)

    $webhookUrl = $script:_config.DiscordWebhookUrl
    if ([string]::IsNullOrWhiteSpace($webhookUrl)) { return }

    $maxLen = $script:_config.MaxDiscordMsgLength
    if ($Message.Length -gt $maxLen) {
        $Message = $Message.Substring(0, $maxLen - 3) + '...'
    }

    $payload = @{ content = $Message } | ConvertTo-Json
    try {
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload `
            -ContentType 'application/json' -TimeoutSec 10 -ErrorAction Stop
    } catch {
        Write-UsmLog -Message "Send-UsmDiscordAlert failed: $_" -Level WARN
    }
}

function Send-UsmEmailAlert {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Subject,
        [Parameter(Mandatory)][string]$Body
    )

    $cfg = $script:_config
    if (-not $cfg.EmailAlerts) { return }
    if ([string]::IsNullOrWhiteSpace($cfg.SmtpServer) -or
        [string]::IsNullOrWhiteSpace($cfg.SmtpFrom)   -or
        [string]::IsNullOrWhiteSpace($cfg.SmtpTo)) { return }

    try {
        $params = @{
            To         = $cfg.SmtpTo
            From       = $cfg.SmtpFrom
            Subject    = $Subject
            Body       = $Body
            SmtpServer = $cfg.SmtpServer
            Port       = $cfg.SmtpPort
            UseSsl     = $cfg.SmtpUseSsl
        }
        Send-MailMessage @params -ErrorAction Stop
    } catch {
        Write-UsmLog -Message "Send-UsmEmailAlert failed: $_" -Level WARN
    }
}
