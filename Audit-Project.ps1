# ==================================================
# Ultra Security Monitor - Pełny audyt projektu
# ==================================================
Write-Host "🔎 Rozpoczynam audyt projektu Ultra Security Monitor..." -ForegroundColor Cyan

# 1️⃣ Sprawdzenie wymaganych plików
$requiredFiles = @("README.md", ".github/FUNDING.yml", "UltraSecurityMonitor.ps1", "dashboard.html", "Invoke-ProtectedEndpoint.ps1")
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "  ✅ Plik istnieje: $file"
    } else {
        Write-Host "  ⚠️ Brak pliku: $file"
    }
}

# 2️⃣ Sprawdzenie składni PowerShell dla głównego skryptu
Write-Host "`n🔧 Sprawdzanie składni UltraSecurityMonitor.ps1..."
try {
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        (Resolve-Path "UltraSecurityMonitor.ps1").Path,
        [ref]$null,
        [ref]$parseErrors
    )
    if ($parseErrors.Count -gt 0) {
        Write-Host "  ❌ Błąd składni w UltraSecurityMonitor.ps1"
        $parseErrors | ForEach-Object { Write-Host "    $_" }
    } else {
        Write-Host "  ✅ Składnia PS jest poprawna"
    }
} catch {
    Write-Host "  ❌ Błąd składni w UltraSecurityMonitor.ps1: $($_.Exception.Message)"
}

# 3️⃣ Sprawdzenie repozytorium Git
Write-Host "`n🌳 Sprawdzanie repozytorium Git..."
try {
    $status = git status --short
    if ($status) {
        Write-Host "  ⚠️ Niezatwierdzone zmiany w repozytorium:"
        Write-Host $status
    } else {
        Write-Host "  ✅ Repozytorium jest czyste, wszystkie zmiany zatwierdzone"
    }
    $branch = git branch --show-current
    Write-Host "  ℹ Obecna gałąź: $branch"
} catch {
    Write-Host "  ⚠️ Nie wykryto repozytorium Git lub Git nie jest zainstalowany"
}

# 4️⃣ Sprawdzenie logów i konfiguracji plików
$logFiles = @("security.log", "security-report.txt", "SIEM/siem.json")
Write-Host "`n📄 Sprawdzanie logów i plików konfiguracyjnych..."
foreach ($file in $logFiles) {
    if (Test-Path $file) {
        Write-Host "  ✅ Plik istnieje: $file"
    } else {
        Write-Host "  ⚠️ Brak pliku: $file"
    }
}

# 5️⃣ Test połączenia z VirusTotal API (jeżeli używasz integracji)
# Wymaga ustawienia $VT_API_KEY w skrypcie lub w środowisku
if ($env:VT_API_KEY) {
    Write-Host "`n🛡 Sprawdzanie połączenia z VirusTotal..."
    try {
        Invoke-RestMethod -Uri "https://www.virustotal.com/api/v3/files/0" -Headers @{
            "x-apikey" = $env:VT_API_KEY
        } | Out-Null
        Write-Host "  ✅ Połączenie z VirusTotal działa"
    } catch {
        Write-Host "  ⚠️ Nie udało się połączyć z VirusTotal"
    }
} else {
    Write-Host "  ℹ VT_API_KEY nie ustawiony – pomijam test VirusTotal"
}

Write-Host "`n🎯 Audyt zakończony!"
