# ==================================================
# Master Agent v2.0 - Audyt, backup, ulepszanie funkcji
# ==================================================

Write-Host "🌙 Uruchamiam Master Agent v2.0..." -ForegroundColor Cyan

# 1️⃣ Aktualizacja FUNDING.yml i README.md
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

$fundingFile = Join-Path $githubFolder "FUNDING.yml"
Set-Content -Path $fundingFile -Value $fundingYaml -Force

$readmeFile = "README.md"
$readmeSection = @"
## 🔹 Support Ultra Security Monitor
- [GitHub Sponsors](https://github.com/sponsors/DominikOpalko)
- [Patreon](https://www.patreon.com/UltraSecPatreon)
- [Ko-fi](https://ko-fi.com/dominik-opalko)
- [Buy Me a Coffee](https://www.buymeacoffee.com/dominik-opalko)
- [Donate via PayPal](https://paypal.me/dominikopalko)
"@
if (Test-Path $readmeFile) {
    $content = Get-Content $readmeFile -Raw
    if ($content -notmatch "Support Ultra Security Monitor") {
        Add-Content -Path $readmeFile -Value $readmeSection
    }
} else {
    Set-Content -Path $readmeFile -Value $readmeSection
}

# 2️⃣ Audyt projektu
Write-Host "🔎 Audyt projektu..."
$requiredFiles = @("README.md", ".github/FUNDING.yml", "agent/UltraSecurityMonitor.ps1", "dashboard/dashboard.html")
foreach ($file in $requiredFiles) {
    if (Test-Path $file) { Write-Host "✅ Plik istnieje: $file" }
    else { Write-Host "⚠️ Brak pliku: $file" }
}

# 3️⃣ Backup logów
$logFiles = @("security.log", "security-report.txt", "SIEM/siem.json")
$backupFolder = "backup_logs"
if (-not (Test-Path $backupFolder)) { New-Item -ItemType Directory -Path $backupFolder }

foreach ($file in $logFiles) {
    if (Test-Path $file) {
        Copy-Item -Path $file -Destination $backupFolder -Force
        Write-Host "✅ Backup pliku: $file"
    }
}

# 4️⃣ Sprawdzenie i ulepszanie agent/UltraSecurityMonitor.ps1
$mainScript = "agent/UltraSecurityMonitor.ps1"
if (Test-Path $mainScript) {
    Write-Host "🛠 Analiza i ulepszanie $mainScript..."
    $scriptContent = Get-Content $mainScript -Raw

    # Poprawienie notacji $changeType w event log
    if ($scriptContent -match 'File \$changeType:') {
        $scriptContent = $scriptContent -replace 'File \$changeType:', 'File ${changeType}:'
        Set-Content -Path $mainScript -Value $scriptContent
        Write-Host "✅ Poprawiono notację zmiennej `$changeType"
    }

    # Wykrywanie brakujących modułów (prosty wzór)
    $expectedModules = @("ProcessMonitoring", "NetworkMonitoring", "FileMonitoring", "SIEMExport", "DiscordAlerts", "EmailAlerts")
    foreach ($module in $expectedModules) {
        if ($scriptContent -notmatch $module) {
            Write-Host "⚠️ Brak modułu: $module – dodanie placeholdera"
            Add-Content -Path $mainScript -Value "`n# TODO: Implement module $module"
        } else { Write-Host "✅ Moduł istnieje: $module" }
    }
} else { Write-Host "⚠️ Brak pliku: $mainScript" }

# 5️⃣ Test API VirusTotal (opcjonalnie)
if ($env:VT_API_KEY) {
    try {
        Invoke-RestMethod -Uri "https://www.virustotal.com/api/v3/files/0" -Headers @{ "x-apikey" = $env:VT_API_KEY } | Out-Null
        Write-Host "✅ Połączenie z VirusTotal OK"
    } catch {
        Write-Host "⚠️ Problem z połączeniem VirusTotal"
    }
}

# 6️⃣ Git commit & push (pomijane gdy uruchamiany w GitHub Actions)
if ($env:GITHUB_ACTIONS) {
    Write-Host "ℹ Wykryto środowisko GitHub Actions – git commit obsługuje workflow"
} else {
    try {
        git add .github/FUNDING.yml README.md backup_logs/ agent/UltraSecurityMonitor.ps1
        git commit -m "Nightly update v2.0: sponsors, audit, backup, improvements"
        git push origin main
        Write-Host "✅ Zmiany wypchnięte do repozytorium"
    } catch {
        Write-Host "⚠️ Nie udało się pushować zmian Git"
    }
}

# 7️⃣ Powiadomienie Slack
if ($env:SLACK_WEBHOOK_URL) {
    $payload = @{ text = "Master Agent v2.0: ✅ Nocny update zakończony. Backup, audyt i ulepszenia wykonane." } | ConvertTo-Json
    try {
        Invoke-RestMethod -Uri $env:SLACK_WEBHOOK_URL -Method POST -Body $payload -ContentType "application/json"
        Write-Host "✅ Powiadomienie Slack wysłane"
    } catch { Write-Host "⚠️ Nie udało się wysłać powiadomienia Slack: $_" }
}

Write-Host "🌟 Master Agent v2.0 zakończył pracę!"
