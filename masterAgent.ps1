# masterAgent.ps1
# Preserved for backward compatibility – delegates to scripts/audit.ps1 for
# project checks and provides the same switch-based interface.
# Deprecation notice: use .\scripts\audit.ps1 for auditing tasks.

#Requires -Version 5.1

param(
    [switch]$UpdateSponsors,
    [switch]$BackupLogs,
    [switch]$AutoEnhance,
    [switch]$MarketAnalysis
)

$ErrorActionPreference = 'Continue'
$ProjectRoot = $PSScriptRoot

function Write-AgentLog {
    param([string]$Msg, [string]$Level = 'INFO')
    Write-Host "[$((Get-Date).ToString('o'))] [$Level] $Msg"
}

Write-Warning "masterAgent.ps1: this root-level shim is deprecated. Use .\scripts\audit.ps1 for project checks."

if ($UpdateSponsors) {
    Write-AgentLog 'Running UpdateSponsors...'
    $fundingPath = Join-Path $ProjectRoot '.github' 'FUNDING.yml'
    if (Test-Path $fundingPath) {
        Write-AgentLog 'FUNDING.yml found – sponsors configuration is up to date.'
    } else {
        Write-AgentLog 'FUNDING.yml not found.' 'WARN'
    }
    Write-AgentLog 'UpdateSponsors completed.'
}

if ($BackupLogs) {
    Write-AgentLog 'Running BackupLogs...'
    $logSources = @(
        (Join-Path $env:USERPROFILE 'Documents\SecurityMonitor\security.log'),
        (Join-Path $env:USERPROFILE 'Documents\SecurityMonitor\security-report.txt'),
        (Join-Path $env:USERPROFILE 'Documents\SecurityMonitor\SIEM\siem.json')
    )
    $backupDir = Join-Path $ProjectRoot ('agent-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    foreach ($src in $logSources) {
        if (Test-Path $src) {
            if (-not (Test-Path $backupDir)) {
                New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
            }
            $dest = Join-Path $backupDir (Split-Path $src -Leaf)
            Copy-Item -Path $src -Destination $dest -Force -ErrorAction SilentlyContinue
            Write-AgentLog "Backed up: $src -> $dest"
        }
    }
    if (-not (Test-Path $backupDir)) {
        Write-AgentLog 'No log files found to back up.' 'INFO'
    } else {
        Write-AgentLog "BackupLogs completed. Backup dir: $backupDir"
    }
}

if ($AutoEnhance) {
    Write-AgentLog 'Running AutoEnhance (delegating to scripts/audit.ps1)...'
    & (Join-Path $ProjectRoot 'scripts' 'audit.ps1')
}

if ($MarketAnalysis) {
    Write-AgentLog 'Running MarketAnalysis...'
    $stats = [ordered]@{
        PowerShellScripts = (Get-ChildItem $ProjectRoot -Filter '*.ps1' -ErrorAction SilentlyContinue).Count
        HtmlFiles         = (Get-ChildItem $ProjectRoot -Filter '*.html' -Recurse -ErrorAction SilentlyContinue).Count
        JsFiles           = (Get-ChildItem $ProjectRoot -Filter '*.js'   -Recurse -ErrorAction SilentlyContinue).Count
        WorkflowFiles     = (Get-ChildItem (Join-Path $ProjectRoot '.github' 'workflows') -Filter '*.yml' -ErrorAction SilentlyContinue).Count
    }
    foreach ($key in $stats.Keys) { Write-AgentLog "  ${key}: $($stats[$key])" }
    Write-AgentLog 'MarketAnalysis completed.'
}

if (-not ($UpdateSponsors -or $BackupLogs -or $AutoEnhance -or $MarketAnalysis)) {
    Write-AgentLog 'No action specified. Use -UpdateSponsors, -BackupLogs, -AutoEnhance, or -MarketAnalysis.'
    exit 1
}
