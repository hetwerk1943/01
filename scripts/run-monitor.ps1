# scripts/run-monitor.ps1
# Convenience launcher for the Ultra Security Monitor module.

#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$BaseFolder,
    [string]$ConfigPath,
    [string[]]$MonitoredFolders,
    [string]$DiscordWebhookUrl,
    [string]$VirusTotalApiKey
)

$ErrorActionPreference = 'Stop'

# ── Import the module ────────────────────────────────────────────────────────
$moduleRoot = Join-Path $PSScriptRoot '..' 'src' 'UltraSecurityMonitor'
Import-Module $moduleRoot -Force

# ── Build parameter splat from non-empty arguments ──────────────────────────
$params = @{}
if ($PSBoundParameters.ContainsKey('BaseFolder'))        { $params['BaseFolder']        = $BaseFolder }
if ($PSBoundParameters.ContainsKey('ConfigPath'))        { $params['ConfigPath']        = $ConfigPath }
if ($PSBoundParameters.ContainsKey('MonitoredFolders'))  { $params['MonitoredFolders']  = $MonitoredFolders }
if ($PSBoundParameters.ContainsKey('DiscordWebhookUrl')) { $params['DiscordWebhookUrl'] = $DiscordWebhookUrl }
if ($PSBoundParameters.ContainsKey('VirusTotalApiKey'))  { $params['VirusTotalApiKey']  = $VirusTotalApiKey }

Start-UltraSecurityMonitor @params

# Keep the process alive so event subscribers remain active
Write-Host 'Press Ctrl+C to stop.' -ForegroundColor DarkGray
while ($true) { Start-Sleep -Seconds 60 }
