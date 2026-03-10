# tests/powershell/UltraSecurityMonitor.Tests.ps1
# Pester v5 tests for the UltraSecurityMonitor module.

#Requires -Version 5.1

BeforeAll {
    $moduleRoot = Join-Path $PSScriptRoot '..\..\src\UltraSecurityMonitor'
    Import-Module $moduleRoot -Force
}

# ────────────────────────────────────────────────────────────────
# Config loading tests
# ────────────────────────────────────────────────────────────────
Describe 'Get-UsmConfig' {

    Context 'Default values' {
        It 'Returns a PSCustomObject' {
            $cfg = Get-UsmConfig
            $cfg | Should -BeOfType [PSCustomObject]
        }

        It 'Has required keys' {
            $cfg = Get-UsmConfig
            $cfg.PSObject.Properties.Name | Should -Contain 'BaseFolder'
            $cfg.PSObject.Properties.Name | Should -Contain 'MaxLogSizeMB'
            $cfg.PSObject.Properties.Name | Should -Contain 'MonitoredFolders'
        }

        It 'Derives runtime paths from BaseFolder' {
            $cfg = Get-UsmConfig -Overrides @{ BaseFolder = 'C:\TestBase' }
            $cfg.LogPath     | Should -Be 'C:\TestBase\security.log'
            $cfg.SiemLogPath | Should -BeLike 'C:\TestBase\SIEM\*'
        }
    }

    Context 'CLI overrides' {
        It 'Applies overrides over defaults' {
            $cfg = Get-UsmConfig -Overrides @{ MaxLogSizeMB = 99; DiscordWebhookUrl = 'https://example.com' }
            $cfg.MaxLogSizeMB      | Should -Be 99
            $cfg.DiscordWebhookUrl | Should -Be 'https://example.com'
        }

        It 'Ignores unknown keys' {
            { Get-UsmConfig -Overrides @{ NonExistentKey = 'value' } } | Should -Not -Throw
        }
    }

    Context 'JSON config file' {
        It 'Loads values from a JSON file' {
            $tmpDir    = Join-Path $TestDrive 'usm-cfg-test'
            $null      = New-Item $tmpDir -ItemType Directory -Force
            $cfgFile   = Join-Path $tmpDir 'monitor.config.json'
            @{ MaxLogSizeMB = 77; DiscordWebhookUrl = 'https://hook.example' } |
                ConvertTo-Json | Set-Content $cfgFile

            $cfg = Get-UsmConfig -ConfigPath $cfgFile
            $cfg.MaxLogSizeMB      | Should -Be 77
            $cfg.DiscordWebhookUrl | Should -Be 'https://hook.example'
        }

        It 'Falls back to defaults for keys not in JSON file' {
            $tmpDir  = Join-Path $TestDrive 'usm-cfg-test2'
            $null    = New-Item $tmpDir -ItemType Directory -Force
            $cfgFile = Join-Path $tmpDir 'monitor.config.json'
            @{ MaxLogSizeMB = 10 } | ConvertTo-Json | Set-Content $cfgFile

            $cfg = Get-UsmConfig -ConfigPath $cfgFile
            $cfg.SmtpPort | Should -Be 587
        }
    }
}

# ────────────────────────────────────────────────────────────────
# Path safety tests
# ────────────────────────────────────────────────────────────────
Describe 'Assert-UsmSafePath / Test-UsmSafePath' {

    It 'Accepts path inside BaseFolder' {
        $base   = 'C:\Users\TestUser\Documents\SecurityMonitor'
        $target = 'C:\Users\TestUser\Documents\SecurityMonitor\Backup\file.txt'
        Test-UsmSafePath -Path $target -BaseFolder $base | Should -BeTrue
    }

    It 'Rejects path outside BaseFolder' {
        $base   = 'C:\Users\TestUser\Documents\SecurityMonitor'
        $target = 'C:\Windows\System32\evil.exe'
        Test-UsmSafePath -Path $target -BaseFolder $base | Should -BeFalse
    }

    It 'Rejects path traversal attempt' {
        $base   = 'C:\Users\TestUser\Documents\SecurityMonitor'
        $target = 'C:\Users\TestUser\Documents\SecurityMonitor\..\..\..\Windows\evil.exe'
        Test-UsmSafePath -Path $target -BaseFolder $base | Should -BeFalse
    }

    It 'Assert-UsmSafePath throws for unsafe path' {
        { Assert-UsmSafePath -Path 'C:\Windows\notepad.exe' -BaseFolder 'C:\SafeBase' } |
            Should -Throw
    }

    It 'Assert-UsmSafePath does not throw for safe path' {
        { Assert-UsmSafePath -Path 'C:\SafeBase\subdir\file.txt' -BaseFolder 'C:\SafeBase' } |
            Should -Not -Throw
    }
}

# ────────────────────────────────────────────────────────────────
# Whitelist / process suspicion tests
# ────────────────────────────────────────────────────────────────
Describe 'Test-UsmPathWhitelisted' {

    It 'Matches wildcard pattern' {
        $wl = @("$env:windir\*", "$env:ProgramFiles\*")
        Test-UsmPathWhitelisted -FilePath "$env:windir\System32\notepad.exe" -Whitelist $wl |
            Should -BeTrue
    }

    It 'Returns false for non-matching path' {
        $wl = @("$env:windir\*")
        Test-UsmPathWhitelisted -FilePath 'C:\Users\Public\malware.exe' -Whitelist $wl |
            Should -BeFalse
    }

    It 'Returns false for empty FilePath' {
        Test-UsmPathWhitelisted -FilePath '' -Whitelist @('*') | Should -BeFalse
    }
}

# ────────────────────────────────────────────────────────────────
# Log rotation tests
# ────────────────────────────────────────────────────────────────
Describe 'Invoke-UsmLogRotation' {

    It 'Rotates log when size exceeds threshold' {
        $tmpDir  = Join-Path $TestDrive 'rotation-test'
        $null    = New-Item $tmpDir -ItemType Directory -Force
        $logFile = Join-Path $tmpDir 'security.log'

        # Write ~2 MB of data to trigger rotation at 1 MB threshold
        $bigLine = 'X' * 1024
        1..2048 | ForEach-Object { Add-Content $logFile $bigLine }

        Invoke-UsmLogRotation -LogPath $logFile -MaxSizeMB 1 -BaseFolder $tmpDir

        # After rotation, the original log should be small (just the rotation notice)
        (Get-Item $logFile -ErrorAction SilentlyContinue).Length | Should -BeLessThan (10 * 1024)

        # An archive file should exist
        $archives = Get-ChildItem $tmpDir -Filter 'security-*.log'
        $archives.Count | Should -BeGreaterThan 0
    }

    It 'Does not rotate when size is below threshold' {
        $tmpDir  = Join-Path $TestDrive 'no-rotation-test'
        $null    = New-Item $tmpDir -ItemType Directory -Force
        $logFile = Join-Path $tmpDir 'security.log'

        Add-Content $logFile 'small entry'
        $sizeBefore = (Get-Item $logFile).Length

        Invoke-UsmLogRotation -LogPath $logFile -MaxSizeMB 50 -BaseFolder $tmpDir

        (Get-Item $logFile).Length | Should -Be $sizeBefore
    }
}
