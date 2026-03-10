# UltraSecurityMonitor.ps1
# Backward-compatibility shim.
# This root-level script is preserved so existing usage continues to work.
# New usage: .\scripts\run-monitor.ps1
#
# Deprecation notice: Direct use of this shim may be removed in a future major
# release. Migrate to `.\scripts\run-monitor.ps1` or import the module:
#   Import-Module .\src\UltraSecurityMonitor

#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string]$BaseFolder,
    [string[]]$MonitoredFolders,
    [string]$DiscordWebhookUrl,
    [string]$VirusTotalApiKey
)

Write-Warning "UltraSecurityMonitor.ps1: this root-level shim is deprecated. Use .\scripts\run-monitor.ps1 instead."

$shimParams = @{}
foreach ($key in $PSBoundParameters.Keys) { $shimParams[$key] = $PSBoundParameters[$key] }

& (Join-Path $PSScriptRoot 'scripts' 'run-monitor.ps1') @shimParams
