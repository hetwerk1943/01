# scripts/setup.ps1
# First-time setup for Ultra Security Monitor.
# Creates the runtime data directory and generates an example config file.

#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$BaseFolder = (Join-Path $env:USERPROFILE 'Documents\SecurityMonitor')
)

$ErrorActionPreference = 'Stop'

Write-Host '🔧 Ultra Security Monitor – Setup' -ForegroundColor Cyan

# Create runtime directories
foreach ($dir in @($BaseFolder, (Join-Path $BaseFolder 'Backup'), (Join-Path $BaseFolder 'SIEM'))) {
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
        Write-Host "  Created: $dir"
    } else {
        Write-Host "  Exists:  $dir"
    }
}

# Copy example config if no config exists yet
$configDest = Join-Path $BaseFolder 'monitor.config.json'
if (-not (Test-Path $configDest)) {
    $configSrc = Join-Path $PSScriptRoot '..\configs\monitor.config.example.json'
    if (Test-Path $configSrc) {
        Copy-Item -Path $configSrc -Destination $configDest -Force
        Write-Host "  Config created at: $configDest"
        Write-Host "  ⚠️  Edit $configDest and set values (or use environment variables)."
    }
}

# Copy example whitelist if absent
$wlDest = Join-Path $BaseFolder 'whitelist.json'
if (-not (Test-Path $wlDest)) {
    $wlSrc = Join-Path $PSScriptRoot '..\configs\whitelist.example.json'
    if (Test-Path $wlSrc) {
        Copy-Item -Path $wlSrc -Destination $wlDest -Force
        Write-Host "  Whitelist created at: $wlDest"
    }
}

Write-Host ''
Write-Host '✅ Setup complete.' -ForegroundColor Green
Write-Host "   To start monitoring run: pwsh -File scripts\run-monitor.ps1"
Write-Host "   Secrets must be provided via environment variables – see docs/QUICK_START.md"
