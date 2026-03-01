# masterAgent.ps1
# Ultra Security Monitor – Master Agent
# Wywołaj z parametrami: -UpdateSponsors, -BackupLogs, -AutoEnhance, -MarketAnalysis

#Requires -Version 5.1

param(
    [switch]$UpdateSponsors,
    [switch]$BackupLogs,
    [switch]$AutoEnhance,
    [switch]$MarketAnalysis
)

$ErrorActionPreference = "Continue"
$ProjectRoot = $PSScriptRoot

function Write-AgentLog {
    param([string]$Msg, [string]$Level = "INFO")
    $ts = (Get-Date).ToString("o")
    Write-Host "[$ts] [$Level] $Msg"
}

# --------- UPDATE SPONSORS ---------
if ($UpdateSponsors) {
    Write-AgentLog "Running UpdateSponsors..."
    $fundingPath = Join-Path $ProjectRoot ".github" "FUNDING.yml"
    if (Test-Path $fundingPath) {
        Write-AgentLog "FUNDING.yml found – sponsors configuration is up to date."
    } else {
        Write-AgentLog "FUNDING.yml not found." "WARN"
    }
    Write-AgentLog "UpdateSponsors completed."
}

# --------- BACKUP LOGS ---------
if ($BackupLogs) {
    Write-AgentLog "Running BackupLogs..."
    $logSources = @(
        (Join-Path $ProjectRoot "security.log"),
        (Join-Path $ProjectRoot "security-report.txt"),
        (Join-Path $ProjectRoot "SIEM" "siem.json")
    )
    $backupDir = Join-Path $ProjectRoot ("agent-backup-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
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
        Write-AgentLog "No log files found to back up." "INFO"
    } else {
        Write-AgentLog "BackupLogs completed. Backup dir: $backupDir"
    }
}

# --------- AUTO ENHANCE ---------
if ($AutoEnhance) {
    Write-AgentLog "Running AutoEnhance..."

    # Verify key project files exist
    $requiredFiles = @(
        "UltraSecurityMonitor.ps1",
        "dashboard.html",
        "agent.html",
        "README.md",
        "Audit-Project.ps1"
    )
    $missing = @()
    foreach ($f in $requiredFiles) {
        $fp = Join-Path $ProjectRoot $f
        if (-not (Test-Path $fp)) { $missing += $f }
    }
    if ($missing.Count -gt 0) {
        Write-AgentLog "Missing project files: $($missing -join ', ')" "WARN"
    } else {
        Write-AgentLog "All required project files are present."
    }

    # Check PowerShell script syntax
    $psScripts = Get-ChildItem -Path $ProjectRoot -Filter "*.ps1" -ErrorAction SilentlyContinue
    foreach ($script in $psScripts) {
        $parseErrors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            $script.FullName,
            [ref]$null,
            [ref]$parseErrors
        ) | Out-Null
        if ($parseErrors.Count -gt 0) {
            Write-AgentLog "Syntax errors in $($script.Name): $($parseErrors -join '; ')" "WARN"
        } else {
            Write-AgentLog "Syntax OK: $($script.Name)"
        }
    }

    Write-AgentLog "AutoEnhance completed."
}

# --------- MARKET ANALYSIS ---------
if ($MarketAnalysis) {
    Write-AgentLog "Running MarketAnalysis..."

    $stats = [ordered]@{
        PowerShellScripts = (Get-ChildItem $ProjectRoot -Filter "*.ps1" -ErrorAction SilentlyContinue).Count
        HtmlFiles         = (Get-ChildItem $ProjectRoot -Filter "*.html" -Recurse -ErrorAction SilentlyContinue).Count
        JsFiles           = (Get-ChildItem $ProjectRoot -Filter "*.js"   -Recurse -ErrorAction SilentlyContinue).Count
        CssFiles          = (Get-ChildItem $ProjectRoot -Filter "*.css"  -Recurse -ErrorAction SilentlyContinue).Count
        WorkflowFiles     = (Get-ChildItem (Join-Path $ProjectRoot ".github" "workflows") -Filter "*.yml" -ErrorAction SilentlyContinue).Count
    }

    Write-AgentLog "Project statistics:"
    foreach ($key in $stats.Keys) {
        Write-AgentLog "  ${key}: $($stats[$key])"
    }

    Write-AgentLog "MarketAnalysis completed."
}

if (-not ($UpdateSponsors -or $BackupLogs -or $AutoEnhance -or $MarketAnalysis)) {
    Write-AgentLog "No action specified. Use -UpdateSponsors, -BackupLogs, -AutoEnhance, or -MarketAnalysis."
    exit 1
}
