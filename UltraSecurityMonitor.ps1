# UltraSecurityMonitor.ps1
# Compatibility shim – delegates to the UltraSecurityMonitor module.
# Run as Administrator. Configure secrets via environment variables (see docs/QUICK_START.md).

#Requires -Version 5.1

$modulePath = Join-Path $PSScriptRoot 'src\ultra-security-monitor\UltraSecurityMonitor.psd1'
Import-Module $modulePath -Force -ErrorAction Stop

Start-UltraSecurityMonitor
