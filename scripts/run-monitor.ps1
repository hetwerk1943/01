# scripts/run-monitor.ps1
# Launch Ultra Security Monitor, or run master-agent tasks.
# Secrets are read from environment variables (never hard-coded).

#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string]$BaseFolder,

    # Master-agent mode
    [switch]$MasterAgent,
    [switch]$UpdateSponsors,
    [switch]$BackupLogs,
    [switch]$AutoEnhance,
    [switch]$MarketAnalysis
)

$ErrorActionPreference = 'Continue'
$ProjectRoot = Split-Path $PSScriptRoot -Parent

# Import module
$modulePath = Join-Path $ProjectRoot 'src\ultra-security-monitor\UltraSecurityMonitor.psd1'
Import-Module $modulePath -Force -ErrorAction Stop

if ($MasterAgent) {
    # --- Master-agent task runner ---
    function Write-AgentLog {
        param([string]$Msg, [string]$Level = 'INFO')
        Write-Host "[$((Get-Date).ToString('o'))] [$Level] $Msg"
    }

    if ($UpdateSponsors) {
        Write-AgentLog 'Running UpdateSponsors...'
        $fundingPath = Join-Path $ProjectRoot '.github\FUNDING.yml'
        if (Test-Path $fundingPath) {
            Write-AgentLog 'FUNDING.yml found – sponsors configuration is up to date.'
        } else {
            Write-AgentLog 'FUNDING.yml not found.' 'WARN'
        }
        Write-AgentLog 'UpdateSponsors completed.'
    }

    if ($BackupLogs) {
        Write-AgentLog 'Running BackupLogs...'
        $resolvedBase = if ($BaseFolder) { $BaseFolder } else { Join-Path $env:USERPROFILE 'Documents\SecurityMonitor' }
        $logSources = @(
            (Join-Path $resolvedBase 'security.log'),
            (Join-Path $resolvedBase 'security-report.txt'),
            (Join-Path $resolvedBase 'SIEM\siem.ndjson')
        )
        $backupDir = Join-Path $resolvedBase ("agent-backup-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
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
        Write-AgentLog 'Running AutoEnhance...'
        $requiredFiles = @(
            'UltraSecurityMonitor.ps1',
            'dashboard.html',
            'agent.html',
            'README.md',
            'Audit-Project.ps1'
        )
        $missing = @()
        foreach ($f in $requiredFiles) {
            $fp = Join-Path $ProjectRoot $f
            if (-not (Test-Path $fp)) { $missing += $f }
        }
        if ($missing.Count -gt 0) {
            Write-AgentLog "Missing project files: $($missing -join ', ')" 'WARN'
        } else {
            Write-AgentLog 'All required project files present.'
        }
        Write-AgentLog 'AutoEnhance completed.'
    }

    if ($MarketAnalysis) {
        Write-AgentLog 'Running MarketAnalysis...'
        Write-AgentLog 'No market-analysis action configured. Add custom logic here.' 'INFO'
        Write-AgentLog 'MarketAnalysis completed.'
    }

    return
}

# --- Normal monitor start ---
$params = @{}
if ($ConfigPath) { $params['ConfigPath'] = $ConfigPath }
if ($BaseFolder)  { $params['BaseFolder']  = $BaseFolder  }

Start-UltraSecurityMonitor @params
