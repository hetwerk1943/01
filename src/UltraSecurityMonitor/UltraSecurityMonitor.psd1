@{
    # Module metadata
    RootModule        = 'UltraSecurityMonitor.psm1'
    ModuleVersion     = '2.0.1'
    GUID              = 'f3c9d1b2-4e7a-4a55-9d2b-224c6e1a9f23'
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
