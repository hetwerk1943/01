# hooks/pre-commit.ps1
# Ultra Security Monitor – Pre-commit Secret Scanner
#
# PURPOSE: Prevent accidental commit of API keys, passwords, tokens, or
#          webhook URLs into the repository.
#
# INSTALL:
#   Copy (or symlink) this script to .git/hooks/pre-commit and set it executable.
#   On Windows with Git for Windows you can create .git/hooks/pre-commit containing:
#     #!/usr/bin/env pwsh
#     & "$PSScriptRoot/../../hooks/pre-commit.ps1"; exit $LASTEXITCODE
#
# USAGE: Run manually:  pwsh hooks/pre-commit.ps1
#        Or via git hook: git commit  (triggers automatically)

$ErrorActionPreference = "Stop"

# ─── Patterns that must never appear in committed files ──────────────────────
$secretPatterns = [ordered]@{
    "Hardcoded API key assignment"        = '(?i)(api[_-]?key|apikey)\s*=\s*"[A-Za-z0-9/+]{16,}"'
    "Hardcoded Discord webhook URL"       = '(?i)discord(app)?\.com/api/webhooks/\d+/[A-Za-z0-9_-]+'
    "Hardcoded webhook URL assignment"    = '(?i)(webhook[_-]?url|webhookurl)\s*=\s*"https?://[^"]+"'
    "Hardcoded password assignment"       = '(?i)(password|passwd|pwd)\s*=\s*"[^"]{4,}"'
    "Hardcoded secret assignment"         = '(?i)(secret|token)\s*=\s*"[A-Za-z0-9/+=]{8,}"'
    "VirusTotal x-apikey header literal"  = '(?i)"x-apikey"\s*=\s*"[A-Za-z0-9]{16,}"'
    "AWS access key"                      = 'AKIA[0-9A-Z]{16}'
    "Google API key"                      = 'AIza[0-9A-Za-z\-_]{35}'
    "Generic high-entropy bearer token"   = '(?i)bearer\s+[A-Za-z0-9/+_-]{20,}'
}

# ─── File extensions to scan ─────────────────────────────────────────────────
$scanExtensions = @(".ps1", ".py", ".sh", ".js", ".ts", ".json", ".yaml", ".yml",
                    ".env", ".config", ".cfg", ".ini", ".txt", ".md")

# ─── Get staged files ─────────────────────────────────────────────────────────
$stagedFiles = git diff --cached --name-only --diff-filter=ACM 2>&1 |
    Where-Object { $_ -and ($_ -notmatch '^fatal') }

if (-not $stagedFiles) {
    Write-Host "pre-commit: no staged files to scan." -ForegroundColor Gray
    exit 0
}

$violations = @()

foreach ($file in $stagedFiles) {
    $ext = [System.IO.Path]::GetExtension($file).ToLower()
    if ($ext -notin $scanExtensions)       { continue }
    if (-not (Test-Path $file))            { continue }

    # Read the staged content (not the working-tree version)
    $content = git show ":$file" 2>&1
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($content)) { continue }

    $lineNum = 0
    foreach ($line in ($content -split "`n")) {
        $lineNum++
        foreach ($label in $secretPatterns.Keys) {
            if ($line -match $secretPatterns[$label]) {
                $trimmedLine = $line.Trim()
                $violations += [PSCustomObject]@{
                    File    = $file
                    Line    = $lineNum
                    Pattern = $label
                    Snippet = $trimmedLine.Substring(0, [Math]::Min(80, $trimmedLine.Length))
                }
            }
        }
    }
}

if ($violations.Count -eq 0) {
    Write-Host "pre-commit: ✅ No secrets detected in staged files." -ForegroundColor Green
    exit 0
}

Write-Host "`npre-commit: ❌ SECRETS DETECTED – commit BLOCKED`n" -ForegroundColor Red
$violations | Format-Table -AutoSize | Out-String | Write-Host
Write-Host "Remove or move secrets to Windows Credential Manager / environment variables." -ForegroundColor Yellow
Write-Host "To bypass (NOT recommended): git commit --no-verify`n" -ForegroundColor Yellow
exit 1
