@{
    # Module metadata
    RootModule        = 'UltraSecurityMonitor.psm1'
    ModuleVersion     = '2.0.0'
    GUID              = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author            = 'Ultra Security Monitor Contributors'
    Description       = 'Windows security monitor: file-system and process surveillance with Discord/Email/SIEM integration.'
    PowerShellVersion = '5.1'

    # Public API
    FunctionsToExport = @('Start-UltraSecurityMonitor')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    # Private data
    PrivateData = @{
        PSData = @{
            Tags         = @('Security','Monitor','Windows','SIEM')
            ProjectUri   = 'https://github.com/hetwerk1943/01'
            ReleaseNotes = 'v2.0: Modular rewrite with config layering, NDJSON logging, and path-safety guardrails.'
        }
    }
}
