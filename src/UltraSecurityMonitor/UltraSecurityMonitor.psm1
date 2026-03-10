# UltraSecurityMonitor.psm1
# Module root – dot-sources all Private then Public function files.

#Requires -Version 5.1

$ErrorActionPreference = 'Stop'

# Module-scope state consumed by private helpers
$script:_config        = $null
$script:_logWriteCount = 0
$script:_wlCache       = $null

# Dot-source private functions first
Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' |
    ForEach-Object { . $_.FullName }

# Dot-source public functions
Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' |
    ForEach-Object { . $_.FullName }

Export-ModuleMember -Function 'Start-UltraSecurityMonitor'
