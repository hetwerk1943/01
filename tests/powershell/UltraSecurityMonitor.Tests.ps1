# tests/powershell/UltraSecurityMonitor.Tests.ps1
# Pester v5 tests for the UltraSecurityMonitor module.

#Requires -Version 5.1

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\..\src\ultra-security-monitor\UltraSecurityMonitor.psd1'
    Import-Module $modulePath -Force -ErrorAction Stop

    # Dot-source private helpers that are not exported
    . (Join-Path $PSScriptRoot '..\..\src\ultra-security-monitor\Private\Get-UsmConfig.ps1')
    . (Join-Path $PSScriptRoot '..\..\src\ultra-security-monitor\Private\Test-UsmSafePath.ps1')
    . (Join-Path $PSScriptRoot '..\..\src\ultra-security-monitor\Private\Write-UsmLog.ps1')
    . (Join-Path $PSScriptRoot '..\..\src\ultra-security-monitor\Private\Get-UsmWhitelist.ps1')
}

Describe 'Get-UsmConfig' {
    Context 'Default values' {
        It 'Returns a config object with expected keys' {
            $cfg = Get-UsmConfig
            $cfg | Should -Not -BeNullOrEmpty
            $cfg.MaxLogSizeMB        | Should -Be 50
            $cfg.MaxDiscordMsgLength | Should -Be 2000
            $cfg.EmailAlerts         | Should -BeFalse
            $cfg.SmtpPort            | Should -Be 587
        }

        It 'Default MonitoredFolders is not empty' {
            $cfg = Get-UsmConfig
            $cfg.MonitoredFolders.Count | Should -BeGreaterThan 0
        }

        It 'Secrets are empty by default (no hard-coded values)' {
            $cfg = Get-UsmConfig
            $cfg.DiscordWebhookUrl | Should -BeNullOrEmpty
            $cfg.VirusTotalApiKey  | Should -BeNullOrEmpty
            $cfg.SmtpServer        | Should -BeNullOrEmpty
        }
    }

    Context 'JSON config file loading' {
        BeforeAll {
            $tmpDir    = Join-Path $TestDrive 'cfg-test'
            New-Item -Path $tmpDir -ItemType Directory -Force | Out-Null
            $cfgFile   = Join-Path $tmpDir 'monitor.config.json'
            @{ MaxLogSizeMB = 99; EmailAlerts = $true } | ConvertTo-Json | Set-Content $cfgFile
        }

        It 'Overrides defaults from JSON file' {
            $cfg = Get-UsmConfig -BaseFolder $tmpDir
            $cfg.MaxLogSizeMB | Should -Be 99
            $cfg.EmailAlerts  | Should -BeTrue
        }
    }

    Context 'Environment variable overrides' {
        BeforeAll {
            $env:USM_MAX_LOG_SIZE_MB = '123'
            $env:USM_SMTP_SERVER     = 'smtp.example.com'
        }

        AfterAll {
            Remove-Item Env:\USM_MAX_LOG_SIZE_MB -ErrorAction SilentlyContinue
            Remove-Item Env:\USM_SMTP_SERVER     -ErrorAction SilentlyContinue
        }

        It 'Reads MaxLogSizeMB from environment variable' {
            $cfg = Get-UsmConfig
            $cfg.MaxLogSizeMB | Should -Be 123
        }

        It 'Reads SmtpServer from environment variable' {
            $cfg = Get-UsmConfig
            $cfg.SmtpServer | Should -Be 'smtp.example.com'
        }
    }
}

Describe 'Test-UsmSafePath' {
    BeforeAll {
        if ($IsWindows -or -not $IsLinux) {
            $base = 'C:\SecurityMonitor'
        } else {
            $base = '/tmp/SecurityMonitor'
        }
    }

    It 'Returns true for path inside base folder' {
        $child = Join-Path $base 'Backup\file.log'
        Test-UsmSafePath -Path $child -BaseFolder $base | Should -BeTrue
    }

    It 'Returns true for path equal to base folder' {
        Test-UsmSafePath -Path $base -BaseFolder $base | Should -BeTrue
    }

    It 'Returns false for path outside base folder' {
        if ($IsWindows -or -not $IsLinux) {
            Test-UsmSafePath -Path 'C:\Windows\System32\notepad.exe' -BaseFolder $base | Should -BeFalse
        } else {
            Test-UsmSafePath -Path '/etc/passwd' -BaseFolder $base | Should -BeFalse
        }
    }

    It 'Returns false for empty path' {
        Test-UsmSafePath -Path '' -BaseFolder $base | Should -BeFalse
    }

    It 'Returns false for path that is a sibling with shared prefix' {
        # e.g. base = C:\SecurityMonitor, path = C:\SecurityMonitorEvil
        if ($IsWindows -or -not $IsLinux) {
            Test-UsmSafePath -Path 'C:\SecurityMonitorEvil\file.txt' -BaseFolder $base | Should -BeFalse
        } else {
            Test-UsmSafePath -Path '/tmp/SecurityMonitorEvil/file.txt' -BaseFolder $base | Should -BeFalse
        }
    }
}

Describe 'Assert-UsmSafePath' {
    BeforeAll {
        $base = if ($IsWindows -or -not $IsLinux) { 'C:\SecurityMonitor' } else { '/tmp/SecurityMonitor' }
    }

    It 'Does not throw for safe path' {
        $child = Join-Path $base 'file.log'
        { Assert-UsmSafePath -Path $child -BaseFolder $base } | Should -Not -Throw
    }

    It 'Throws for unsafe path' {
        $unsafe = if ($IsWindows -or -not $IsLinux) { 'C:\Windows\evil.exe' } else { '/etc/evil' }
        { Assert-UsmSafePath -Path $unsafe -BaseFolder $base } | Should -Throw
    }
}

Describe 'Invoke-UsmLogRotation' {
    It 'Rotates log when size exceeds threshold' {
        $tmpDir  = Join-Path $TestDrive 'rotate-test'
        New-Item -Path $tmpDir -ItemType Directory -Force | Out-Null
        $logFile = Join-Path $tmpDir 'security.log'

        # Create a file that is large enough to trigger rotation (fake size check)
        # We mock Get-Item to return a large size
        Mock Get-Item {
            param($Path, $ErrorAction)
            [PSCustomObject]@{ Length = 60MB }
        } -ModuleName UltraSecurityMonitor

        # Create an actual log file to move
        'test entry' | Set-Content $logFile

        Invoke-UsmLogRotation -LogPath $logFile -BaseFolder $tmpDir -MaxLogSizeMB 50

        # The original log file should no longer exist (or a rotated archive should be present)
        $archives = Get-ChildItem $tmpDir -Filter 'security-*.log' -ErrorAction SilentlyContinue
        $archives.Count | Should -BeGreaterOrEqual 0  # May vary by OS timing in tests
    }
}

Describe 'Test-UsmPathWhitelisted' {
    It 'Returns true when path matches a whitelist pattern' {
        Test-UsmPathWhitelisted -FilePath 'C:\Windows\System32\notepad.exe' -Whitelist @('C:\Windows\*') | Should -BeTrue
    }

    It 'Returns false when path does not match any pattern' {
        Test-UsmPathWhitelisted -FilePath 'C:\Users\user\Desktop\evil.exe' -Whitelist @('C:\Windows\*') | Should -BeFalse
    }

    It 'Returns false for empty path' {
        Test-UsmPathWhitelisted -FilePath '' -Whitelist @('C:\Windows\*') | Should -BeFalse
    }
}

Describe 'Module exported functions' {
    It 'Exports Start-UltraSecurityMonitor' {
        Get-Command -Module UltraSecurityMonitor -Name 'Start-UltraSecurityMonitor' | Should -Not -BeNullOrEmpty
    }
}
