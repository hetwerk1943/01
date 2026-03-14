# UltraSecurityMonitor.psm1
# Module root – shim that delegates to the canonical implementation under src/ultra-security-monitor.

#Requires -Version 5.1

$ErrorActionPreference = 'Stop'

# Compute the path to the canonical module implementation (src/ultra-security-monitor/UltraSecurityMonitor.psm1)
$repositoryRoot       = Split-Path -Path $PSScriptRoot -Parent
$legacyModuleFolder   = Join-Path -Path $repositoryRoot -ChildPath 'ultra-security-monitor'
$legacyModulePath     = Join-Path -Path $legacyModuleFolder -ChildPath 'UltraSecurityMonitor.psm1'

if (Test-Path -Path $legacyModulePath) {
    Import-Module -Name $legacyModulePath -Force
} else {
    Write-Warning "UltraSecurityMonitor shim could not locate canonical module at path '$legacyModulePath'."
}

# Rely on the exports from the canonical module (including Start-UltraSecurityMonitor).


