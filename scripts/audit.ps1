# scripts/audit.ps1
# Project health and syntax audit script.

#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Continue'

Write-Host '🔎 Ultra Security Monitor – Project Audit' -ForegroundColor Cyan

# ── 1. Required files ────────────────────────────────────────────────────────
Write-Host "`n📄 Checking required files..."
$required = @(
    'README.md',
    'src/UltraSecurityMonitor/UltraSecurityMonitor.psm1',
    'src/UltraSecurityMonitor/UltraSecurityMonitor.psd1',
    'configs/monitor.config.example.json',
    'scripts/run-monitor.ps1',
    '.github/workflows/ci.yml'
)
$missing = 0
foreach ($rel in $required) {
    $path = Join-Path $ProjectRoot $rel
    if (Test-Path $path) {
        Write-Host "  ✅ $rel"
    } else {
        Write-Host "  ❌ MISSING: $rel" -ForegroundColor Red
        $missing++
    }
}

# ── 2. PowerShell syntax check ───────────────────────────────────────────────
Write-Host "`n🔧 PowerShell syntax check..."
$psFiles = Get-ChildItem -Path $ProjectRoot -Filter '*.ps1' -Recurse `
    -Exclude 'node_modules' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '(node_modules|saas-app)' }

$syntaxErrors = 0
foreach ($file in $psFiles) {
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName, [ref]$null, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
        Write-Host "  ❌ $($file.Name): $($errors.Count) parse error(s)" -ForegroundColor Red
        $errors | ForEach-Object { Write-Host "     $_" }
        $syntaxErrors++
    } else {
        Write-Host "  ✅ $($file.Name)"
    }
}

# ── 3. Git status ────────────────────────────────────────────────────────────
Write-Host "`n🌳 Git status..."
try {
    $status = git -C $ProjectRoot status --short 2>&1
    if ($status) {
        Write-Host "  ⚠️  Uncommitted changes:" -ForegroundColor Yellow
        $status | ForEach-Object { Write-Host "     $_" }
    } else {
        Write-Host '  ✅ Working tree is clean'
    }
    $branch = git -C $ProjectRoot branch --show-current 2>&1
    Write-Host "  ℹ️  Branch: $branch"
} catch {
    Write-Warning 'Git not available or not a git repository.'
}

# ── 4. PSScriptAnalyzer (if available) ──────────────────────────────────────
if (Get-Module -ListAvailable -Name PSScriptAnalyzer) {
    Write-Host "`n🔍 PSScriptAnalyzer..."
    $srcPath = Join-Path $ProjectRoot 'src'
    $issues = Invoke-ScriptAnalyzer -Path $srcPath -Recurse -Severity Warning `
        -ErrorAction SilentlyContinue
    if ($issues) {
        $issues | Select-Object ScriptName, Line, Severity, RuleName, Message |
            Format-Table -AutoSize
        Write-Host "  ⚠️  $($issues.Count) issue(s) found" -ForegroundColor Yellow
    } else {
        Write-Host '  ✅ No warnings'
    }
} else {
    Write-Host "`n  ℹ️  PSScriptAnalyzer not installed – skipping (run: scripts/setup.ps1 -InstallDevTools)"
}

# ── Summary ──────────────────────────────────────────────────────────────────
Write-Host "`n🎯 Audit complete."
if ($missing -gt 0 -or $syntaxErrors -gt 0) {
    Write-Host "  ❌ Issues found: $missing missing file(s), $syntaxErrors script(s) with parse errors." -ForegroundColor Red
    exit 1
} else {
    Write-Host '  ✅ All checks passed.' -ForegroundColor Green
}
