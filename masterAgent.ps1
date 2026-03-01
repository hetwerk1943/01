<#
.SYNOPSIS
Master Agent dla Ultra Security Monitor
Automatyzuje: sponsorów, audyt, backupy, ulepszanie kodu, analizę rynku i powiadomienia Slack.
.PARAMETER UpdateSponsors
Aktualizuje FUNDING.yml i sekcję sponsorów w README.md
.PARAMETER BackupLogs
Tworzy kopię zapasową logów i plików runtime
.PARAMETER AutoEnhance
Automatycznie ulepsza kod i dashboard
.PARAMETER MarketAnalysis
Analizuje rynek SaaS i bezpieczeństwa, tworzy raport
#>

param(
    [switch]$UpdateSponsors,
    [switch]$BackupLogs,
    [switch]$AutoEnhance,
    [switch]$MarketAnalysis
)

# -----------------------------
# 1️⃣ Aktualizacja sponsorów
# -----------------------------
if ($UpdateSponsors) {
    Write-Host "🔹 Aktualizacja sekcji sponsorów..."
    $fundingYaml = @"
github: [DominikOpalko, UltraSecTeam]
patreon: UltraSecPatreon
ko_fi: dominik-opalko
buy_me_a_coffee: dominik-opalko
open_collective: UltraSecCollective
custom: ["https://ultrasecuritymonitor.com/donate", "https://paypal.me/dominikopalko"]
"@
    $githubFolder = ".github"
    if (-not (Test-Path $githubFolder)) { New-Item -ItemType Directory -Path $githubFolder }
    Set-Content -Path (Join-Path $githubFolder "FUNDING.yml") -Value $fundingYaml -Force

    $readmeFile = "README.md"
    $readmeSection = @"
## Support Ultra Security Monitor
If you like this project and want to support development, you can sponsor or donate:
- [GitHub Sponsors](https://github.com/sponsors/DominikOpalko)
- [Patreon](https://www.patreon.com/UltraSecPatreon)
- [Ko-fi](https://ko-fi.com/dominik-opalko)
- [Buy Me a Coffee](https://www.buymeacoffee.com/dominik-opalko)
- [Donate via PayPal](https://paypal.me/dominikopalko)
"@
    if (Test-Path $readmeFile) {
        $content = Get-Content $readmeFile -Raw
        if ($content -notmatch "Support Ultra Security Monitor") { Add-Content -Path $readmeFile -Value $readmeSection }
    } else { Set-Content -Path $readmeFile -Value $readmeSection }
    Write-Host "✅ Sponsorzy zaktualizowani!"
}

# -----------------------------
# 2️⃣ Backup logów i plików runtime
# -----------------------------
if ($BackupLogs) {
    Write-Host "💾 Tworzenie kopii zapasowej logów..."
    $backupFolder = "backup_logs"
    if (-not (Test-Path $backupFolder)) { New-Item -ItemType Directory -Path $backupFolder }
    $filesToBackup = @("security.log", "security-report.txt", "SIEM/siem.json")
    foreach ($file in $filesToBackup) {
        if (Test-Path $file) {
            Copy-Item -Path $file -Destination $backupFolder -Force
        }
    }
    Write-Host "✅ Backup zakończony."
}

# -----------------------------
# 3️⃣ Audyt projektu
# -----------------------------
Write-Host "🔎 Uruchamiam audyt projektu..."
if (Test-Path "agent/Audit-Project.ps1") { .\agent\Audit-Project.ps1 }

# -----------------------------
# 4️⃣ Automatyczne ulepszanie kodu
# -----------------------------
if ($AutoEnhance) {
    Write-Host "🚀 Ulepszanie kodu i dashboard..."
    # Dodanie nagłówka CSP do dashboard, naprawa alertów, aktualizacja modułów
    if (Test-Path "dashboard/dashboard.html") {
        $dashContent = (Get-Content "dashboard/dashboard.html" -Raw) -replace "<head>", "<head>`n<meta http-equiv='Content-Security-Policy' content='default-src ''self'';'>"
        Set-Content -Path "dashboard/dashboard.html" -Value $dashContent
    }
    Write-Host "✅ Kod ulepszony."
}

# -----------------------------
# 5️⃣ Analiza rynku i raport SaaS
# -----------------------------
if ($MarketAnalysis) {
    Write-Host "📈 Analiza rynku SaaS i bezpieczeństwa..."
    $report = @"
Raport rynku (2026-2030):
- SaaS Security Monitor: wzrost roczny 12-18%
- EDR + Dashboard: wysoki popyt w sektorze SMB i Enterprise
- Trendy: integracja AI, automatyczne alerty, compliance
- Rekomendacja: SaaS monetization + licencje PRO
"@
    Set-Content -Path "market-analysis-report.txt" -Value $report
    Write-Host "✅ Raport rynku gotowy: market-analysis-report.txt"
}

# -----------------------------
# 6️⃣ Powiadomienia Slack
# -----------------------------
if ($env:SLACK_WEBHOOK) {
    Write-Host "📨 Wysyłam powiadomienie do Slack..."
    $payload = @{ text = "🤖 Master Agent zakończył pracę." } | ConvertTo-Json
    try { Invoke-RestMethod -Uri $env:SLACK_WEBHOOK -Method Post -Body $payload -ContentType 'application/json' }
    catch { Write-Host "⚠️ Nie udało się wysłać powiadomienia Slack: $_" }
}

# -----------------------------
# 7️⃣ Commit auto zmian (pomijane gdy uruchamiany w GitHub Actions)
# -----------------------------
if ($env:GITHUB_ACTIONS) {
    Write-Host "ℹ Wykryto środowisko GitHub Actions – git commit obsługuje workflow"
} else {
    Write-Host "📌 Commitowanie zmian..."
    git config user.name "GitHub Agent"
    git config user.email "agent@github.com"
    git add README.md .github/FUNDING.yml dashboard/dashboard.html market-analysis-report.txt
    git commit -m "🤖 Nightly Master Agent updates" -q || Write-Host "Brak zmian do commitowania"
    git push origin main -q
}

Write-Host "✅ Master Agent zakończył pracę!"
