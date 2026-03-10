# UltraSecurityMonitor.psd1
# Module manifest for Ultra Security Monitor

@{
    RootModule        = 'UltraSecurityMonitor.psm1'
    ModuleVersion     = '2.0.0'
    GUID              = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author            = 'hetwerk1943'
    CompanyName       = 'hetwerk1943'
    Copyright         = '(c) hetwerk1943. All rights reserved.'
    Description       = 'Ultra Security Monitor – modular PowerShell security monitoring for Windows.'
    PowerShellVersion = '5.1'

    FunctionsToExport = @(
        'Start-UltraSecurityMonitor'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('Security', 'Monitor', 'Windows', 'SIEM')
            ProjectUri   = 'https://github.com/hetwerk1943/01'
            ReleaseNotes = 'v2.0.0 – Modular rewrite with config loading, safe-path guardrails, NDJSON SIEM output.'
        }
    }
}
