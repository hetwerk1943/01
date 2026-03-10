# Private/Get-UsmConfig.ps1
# Configuration loader: JSON file + environment variable overrides.

function Get-UsmConfig {
    [CmdletBinding()]
    param(
        [string]$ConfigPath,
        [string]$BaseFolder
    )

    # Start with defaults
    $cfg = [ordered]@{
        BaseFolder          = if ($BaseFolder) { $BaseFolder } else { Join-Path $env:USERPROFILE 'Documents\SecurityMonitor' }
        MaxLogSizeMB        = 50
        MaxDiscordMsgLength = 2000
        SmtpUseSsl          = $true
        SmtpPort            = 587
        EmailAlerts         = $false
        MonitoredFolders    = @(
            "$env:windir\System32",
            "$env:ProgramFiles",
            "${env:ProgramFiles(x86)}",
            "$env:USERPROFILE\Documents",
            "$env:USERPROFILE\Desktop"
        )
        SuspiciousNames        = @('wscript.exe','cscript.exe','mshta.exe','rundll32.exe','pwsh.exe','cmd.exe')
        SuspiciousPathPatterns = @('*\AppData\Local\Temp\*','*\Temp\*','*\AppData\Roaming\*')
        DefaultWhitelist       = @(
            "$env:windir\*",
            "$env:ProgramFiles\*",
            "${env:ProgramFiles(x86)}\*",
            '*\OneDrive\*',
            '*\Steam\*',
            '*\ProtonVPN\*'
        )
        # Secrets – always loaded from env vars, never hard-coded
        DiscordWebhookUrl = ''
        VirusTotalApiKey  = ''
        SmtpServer        = ''
        SmtpFrom          = ''
        SmtpTo            = ''
    }

    # Load JSON config if present
    if (-not $ConfigPath) {
        $ConfigPath = Join-Path $cfg.BaseFolder 'monitor.config.json'
    }
    if (Test-Path $ConfigPath) {
        try {
            $json = Get-Content $ConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json
            foreach ($prop in $json.PSObject.Properties) {
                $cfg[$prop.Name] = $prop.Value
            }
        } catch {
            Write-Warning "USM: Could not parse config file '$ConfigPath': $_"
        }
    }

    # Environment variable overrides (highest priority, never committed)
    $envMap = @{
        USM_BASE_FOLDER         = 'BaseFolder'
        USM_DISCORD_WEBHOOK_URL = 'DiscordWebhookUrl'
        USM_VT_API_KEY          = 'VirusTotalApiKey'
        USM_SMTP_SERVER         = 'SmtpServer'
        USM_SMTP_FROM           = 'SmtpFrom'
        USM_SMTP_TO             = 'SmtpTo'
        USM_EMAIL_ALERTS        = 'EmailAlerts'
        USM_MAX_LOG_SIZE_MB     = 'MaxLogSizeMB'
    }
    foreach ($envKey in $envMap.Keys) {
        $val = [System.Environment]::GetEnvironmentVariable($envKey)
        if (-not [string]::IsNullOrWhiteSpace($val)) {
            $cfgKey = $envMap[$envKey]
            # Type-coerce booleans and integers
            if ($cfgKey -in @('EmailAlerts')) {
                $cfg[$cfgKey] = [bool]::Parse($val)
            } elseif ($cfgKey -in @('MaxLogSizeMB', 'SmtpPort')) {
                $cfg[$cfgKey] = [int]$val
            } else {
                $cfg[$cfgKey] = $val
            }
        }
    }

    return [PSCustomObject]$cfg
}
