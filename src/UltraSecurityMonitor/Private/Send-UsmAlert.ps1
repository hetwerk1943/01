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
        $mailMessage = [System.Net.Mail.MailMessage]::new(
            $cfg.SmtpFrom,
            $cfg.SmtpTo,
            $Subject,
            $Body
        )

        $smtpClient = [System.Net.Mail.SmtpClient]::new(
            $cfg.SmtpServer,
            [int]$cfg.SmtpPort
        )

        $smtpClient.EnableSsl = [bool]$cfg.SmtpUseSsl

        $smtpClient.Send($mailMessage)

        $mailMessage.Dispose()
        $smtpClient.Dispose()
    } catch {
        Write-UsmLog -Message "Send-UsmEmailAlert failed: $_" -Level WARN
    }
}
