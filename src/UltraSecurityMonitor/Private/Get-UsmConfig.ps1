# Private\Get-UsmConfig.ps1
# Configuration loader: defaults → JSON file → environment variables → CLI overrides.

function Get-UsmConfig {
    [CmdletBinding()]
    param(
        [string]$ConfigPath,
        [hashtable]$Overrides = @{}
    )

    # ── 1. Hard-coded defaults ──────────────────────────────────────────────
    $cfg = [ordered]@{
        BaseFolder            = Join-Path $env:USERPROFILE 'Documents\SecurityMonitor'
        MaxLogSizeMB          = 50
        MaxDiscordMsgLength   = 2000
        DiscordWebhookUrl     = ''
        VirusTotalApiKey      = ''
        EmailAlerts           = $false
        SmtpServer            = ''
        SmtpFrom              = ''
        SmtpTo                = ''
        SmtpUseSsl            = $true
        SmtpPort              = 587
        MonitoredFolders      = @(
            "$env:windir\System32",
            "$env:ProgramFiles",
            "${env:ProgramFiles(x86)}",
            "$env:USERPROFILE\Documents",
            "$env:USERPROFILE\Desktop"
        )
        SuspiciousNames       = @(
            'wscript.exe','cscript.exe','mshta.exe','rundll32.exe','pwsh.exe','cmd.exe'
        )
        SuspiciousPathPatterns = @(
            '*\AppData\Local\Temp\*','*\Temp\*','*\AppData\Roaming\*'
        )
        DefaultWhitelist      = @(
            "$env:windir\*",
            "$env:ProgramFiles\*",
            "${env:ProgramFiles(x86)}\*",
            '*\OneDrive\*','*\Steam\*','*\ProtonVPN\*'
        )
    }

    # ── 2. JSON config file ─────────────────────────────────────────────────
    $resolvedConfig = if ($ConfigPath) {
        $ConfigPath
    } else {
        Join-Path $cfg.BaseFolder 'monitor.config.json'
    }

    if (Test-Path $resolvedConfig) {
        try {
            $json = Get-Content $resolvedConfig -Raw -ErrorAction Stop | ConvertFrom-Json
            foreach ($key in $json.PSObject.Properties.Name) {
                if ($cfg.ContainsKey($key)) {
                    $cfg[$key] = $json.$key
                }
            }
        } catch {
            Write-Warning "Get-UsmConfig: could not parse $resolvedConfig – $_"
        }
    }

    # ── 3. Environment variables ────────────────────────────────────────────
    $envMap = @{
        USM_BASE_FOLDER        = 'BaseFolder'
        USM_DISCORD_WEBHOOK    = 'DiscordWebhookUrl'
        USM_VT_API_KEY         = 'VirusTotalApiKey'
        USM_EMAIL_ALERTS       = 'EmailAlerts'
        USM_SMTP_SERVER        = 'SmtpServer'
        USM_SMTP_FROM          = 'SmtpFrom'
        USM_SMTP_TO            = 'SmtpTo'
        USM_MAX_LOG_SIZE_MB    = 'MaxLogSizeMB'
    }
    foreach ($envKey in $envMap.Keys) {
        $val = [System.Environment]::GetEnvironmentVariable($envKey)
        if (-not [string]::IsNullOrEmpty($val)) {
            $cfgKey = $envMap[$envKey]
            # Type coercion for known numeric / boolean keys
            switch ($cfgKey) {
                'MaxLogSizeMB' {
                    $parsed = 0.0
                    if ([double]::TryParse($val, [ref]$parsed)) {
                        $cfg[$cfgKey] = $parsed
                    } else {
                        Write-Warning "Get-UsmConfig: environment variable $envKey='$val' is not a valid number for $cfgKey; keeping default value '$($cfg[$cfgKey])'."
                    }
                }
                'EmailAlerts'  { $cfg[$cfgKey] = $val -in @('1','true','yes') }
                'SmtpPort'     {
                    $parsedPort = 0
                    if ([int]::TryParse($val, [ref]$parsedPort)) {
                        $cfg[$cfgKey] = $parsedPort
                    } else {
                        Write-Warning "Get-UsmConfig: environment variable $envKey='$val' is not a valid integer for $cfgKey; keeping default value '$($cfg[$cfgKey])'."
                    }
                }
                default        { $cfg[$cfgKey] = $val }
            }
        }
    }

    # ── 4. CLI overrides (explicit parameters) ──────────────────────────────
    foreach ($key in $Overrides.Keys) {
        if ($cfg.ContainsKey($key)) { $cfg[$key] = $Overrides[$key] }
    }

    # ── 5. Derive runtime paths from BaseFolder ─────────────────────────────
    $cfg.BackupFolder = Join-Path $cfg.BaseFolder 'Backup'
    $cfg.SiemFolder   = Join-Path $cfg.BaseFolder 'SIEM'
    $cfg.LogPath      = Join-Path $cfg.BaseFolder 'security.log'
    $cfg.ReportPath   = Join-Path $cfg.BaseFolder 'security-report.txt'
    $cfg.SiemLogPath  = Join-Path $cfg.SiemFolder  'siem.json'
    $cfg.WhitelistPath = Join-Path $cfg.BaseFolder 'whitelist.json'

    return [PSCustomObject]$cfg
}
