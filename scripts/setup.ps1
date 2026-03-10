# scripts/setup.ps1
# One-time setup script: creates the runtime directory, copies an example config,
# and optionally installs Pester + PSScriptAnalyzer for development.

#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$BaseFolder = (Join-Path $env:USERPROFILE 'Documents\SecurityMonitor'),
    [switch]$InstallDevTools
)

$ErrorActionPreference = 'Stop'

Write-Host '🔧 Ultra Security Monitor – Setup' -ForegroundColor Cyan

# ── Create runtime directories ───────────────────────────────────────────────
foreach ($sub in @('', 'Backup', 'SIEM')) {
    $dir = if ($sub) { Join-Path $BaseFolder $sub } else { $BaseFolder }
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
        Write-Host "  Created: $dir"
    } else {
        Write-Host "  Exists:  $dir"
    }
}

# ── Copy example config if no config present ────────────────────────────────
$configDest = Join-Path $BaseFolder 'monitor.config.json'
$configSrc  = Join-Path $PSScriptRoot '..' 'configs' 'monitor.config.example.json'
if (-not (Test-Path $configDest)) {
    if (Test-Path $configSrc) {
        Copy-Item -Path $configSrc -Destination $configDest
        Write-Host "  Config created: $configDest"
        Write-Host "  ⚠️  Edit $configDest to add API keys and customise settings." -ForegroundColor Yellow
    } else {
        Write-Warning "Example config not found at $configSrc – skipping."
    }
} else {
    Write-Host "  Config exists: $configDest"
}

# ── Copy example whitelist if no whitelist present ───────────────────────────
$wlDest = Join-Path $BaseFolder 'whitelist.json'
$wlSrc  = Join-Path $PSScriptRoot '..' 'configs' 'whitelist.example.json'
if (-not (Test-Path $wlDest)) {
    if (Test-Path $wlSrc) {
        Copy-Item -Path $wlSrc -Destination $wlDest
        Write-Host "  Whitelist created: $wlDest"
    }
}

# ── Install dev tools (optional) ─────────────────────────────────────────────
if ($InstallDevTools) {
    Write-Host "`n📦 Installing development tools..." -ForegroundColor Cyan
    foreach ($mod in @('Pester', 'PSScriptAnalyzer')) {
        if (-not (Get-Module -ListAvailable -Name $mod)) {
            Install-Module -Name $mod -Force -Scope CurrentUser
            Write-Host "  Installed: $mod"
        } else {
            Write-Host "  Already installed: $mod"
        }
    }
}

Write-Host "`n✅ Setup complete." -ForegroundColor Green
Write-Host "   Run: .\scripts\run-monitor.ps1 (as Administrator)"
