# scripts/audit.ps1
# Project audit – verifies required files, checks PowerShell syntax, and reports Git status.

#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$ProjectRoot = Split-Path $PSScriptRoot -Parent

Write-Host '🔎 Starting Ultra Security Monitor project audit...' -ForegroundColor Cyan

# 1. Required files
Write-Host "`n📁 Checking required files..."
$requiredFiles = @(
    'README.md',
    '.github/FUNDING.yml',
    'UltraSecurityMonitor.ps1',
    'dashboard.html',
    'src/ultra-security-monitor/UltraSecurityMonitor.psd1',
    'src/ultra-security-monitor/UltraSecurityMonitor.psm1'
)
foreach ($file in $requiredFiles) {
    $fp = Join-Path $ProjectRoot $file
    if (Test-Path $fp) {
        Write-Host "  ✅ $file"
    } else {
        Write-Host "  ⚠️  Missing: $file" -ForegroundColor Yellow
    }
}

# 2. PowerShell syntax check (module files + scripts)
Write-Host "`n🔧 Checking PowerShell syntax..."
$psFiles = Get-ChildItem -Path $ProjectRoot -Include '*.ps1','*.psm1','*.psd1' -Recurse `
    -Exclude 'node_modules' -ErrorAction SilentlyContinue

foreach ($psFile in $psFiles) {
    try {
        $parseErrors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            $psFile.FullName, [ref]$null, [ref]$parseErrors
        ) | Out-Null
        if ($parseErrors.Count -gt 0) {
            Write-Host "  ❌ Parse errors in $($psFile.Name):" -ForegroundColor Red
            $parseErrors | ForEach-Object { Write-Host "    $_" }
        } else {
            Write-Host "  ✅ $($psFile.Name)"
        }
    } catch {
        Write-Host "  ❌ $($psFile.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 3. Git status
Write-Host "`n🌳 Checking Git repository..."
try {
    $status = & git -C $ProjectRoot status --short 2>&1
    if ($status) {
        Write-Host '  ⚠️  Uncommitted changes:' -ForegroundColor Yellow
        Write-Host $status
    } else {
        Write-Host '  ✅ Repository clean – all changes committed.'
    }
    $branch = & git -C $ProjectRoot branch --show-current 2>&1
    Write-Host "  ℹ️  Current branch: $branch"
} catch {
    Write-Host '  ⚠️  Git not available or not a repository.' -ForegroundColor Yellow
}

Write-Host "`n✅ Audit complete." -ForegroundColor Green
