# ==================================================
# Ultra Security Monitor - Pełny audyt projektu
# ==================================================
Write-Host "🔎 Rozpoczynam audyt projektu Ultra Security Monitor..." -ForegroundColor Cyan

# 1️⃣ Sprawdzenie wymaganych plików repozytorium
Write-Host "`n📁 1. Pliki repozytorium:" -ForegroundColor Yellow
$requiredFiles = @(
    @{ Path = "UltraSecurityMonitor.ps1";              Desc = "Główny skrypt monitoringu (PowerShell)" },
    @{ Path = "../dashboard/dashboard.html";            Desc = "Dashboard HTML/JS" },
    @{ Path = "Audit-Project.ps1";                     Desc = "Skrypt audytu projektu" },
    @{ Path = "../README.md";                           Desc = "Dokumentacja projektu" },
    @{ Path = "../.github/FUNDING.yml";                Desc = "Konfiguracja sponsorowania GitHub" },
    @{ Path = "../docs/architecture.md";               Desc = "Architektura SaaS" },
    @{ Path = "../docs/api-spec.yaml";                 Desc = "Specyfikacja API (OpenAPI)" },
    @{ Path = "../.github/workflows/backend-ci.yml";   Desc = "CI workflow (Backend)" },
    @{ Path = "../SECURITY.md";                        Desc = "Polityka bezpieczeństwa" },
    @{ Path = "../CONTRIBUTING.md";                    Desc = "Wytyczne dla kontrybutorów" }
)
foreach ($entry in $requiredFiles) {
    if (Test-Path $entry.Path) {
        $size = (Get-Item $entry.Path).Length
        Write-Host ("  ✅ {0,-35} – {1}  ({2} B)" -f $entry.Path, $entry.Desc, $size)
    } else {
        Write-Host ("  ⚠️  {0,-35} – BRAK" -f $entry.Path) -ForegroundColor DarkYellow
    }
}

# 2️⃣ Inwentarz zaimplementowanych funkcji (analiza skryptu)
Write-Host "`n🔍 2. Zaimplementowane funkcje w UltraSecurityMonitor.ps1:" -ForegroundColor Yellow
$mainScript = "UltraSecurityMonitor.ps1"
if (Test-Path $mainScript) {
    $content = Get-Content $mainScript -Raw

    $features = @(
        @{ Pattern = "Win32_ProcessStartTrace";    Name = "Monitoring procesów (EDR / WMI)" },
        @{ Pattern = "Get-FileHash";               Name = "Obliczanie skrótów SHA-256" },
        @{ Pattern = "Get-VirusTotalReport";       Name = "Integracja VirusTotal API v3" },
        @{ Pattern = "Get-NetTCPConnection";       Name = "Monitoring połączeń TCP" },
        @{ Pattern = "Get-NetUDPEndpoint";         Name = "Monitoring punktów końcowych UDP" },
        @{ Pattern = "FileSystemWatcher";          Name = "Monitoring plików/folderów (FileSystemWatcher)" },
        @{ Pattern = "Backup-FileToStore";         Name = "Automatyczne kopie zapasowe plików" },
        @{ Pattern = "Write-SiemEvent";            Name = "Eksport zdarzeń SIEM (NDJSON)" },
        @{ Pattern = "Send-DiscordAlert";          Name = "Alerty Discord (webhook)" },
        @{ Pattern = "Send-EmailAlert";            Name = "Alerty e-mail (SMTP/SSL)" },
        @{ Pattern = "Get-AuthenticodeSignature";  Name = "Weryfikacja podpisów cyfrowych Authenticode" },
        @{ Pattern = "Write-Log";                  Name = "Logowanie zdarzeń do pliku (TSV)" },
        @{ Pattern = "MaxLogSizeMB";               Name = "Rotacja logów (limit 50 MB)" },
        @{ Pattern = "whitelist.json";             Name = "Obsługa białej listy ścieżek (whitelist.json)" },
        @{ Pattern = "Register-WmiEvent";          Name = "Rejestracja zdarzeń WMI" },
        @{ Pattern = "Test-ProcessSuspicious";     Name = "Heurystyczna analiza podejrzanych procesów" }
    )

    foreach ($f in $features) {
        if ($content -match [regex]::Escape($f.Pattern)) {
            Write-Host ("  ✅ {0}" -f $f.Name)
        } else {
            Write-Host ("  ❌ {0}  – NIE ZNALEZIONO" -f $f.Name) -ForegroundColor Red
        }
    }
} else {
    Write-Host "  ❌ Nie można sprawdzić funkcji – brak UltraSecurityMonitor.ps1" -ForegroundColor Red
}

# 3️⃣ Sprawdzenie składni PowerShell dla głównego skryptu
Write-Host "`n🔧 3. Sprawdzanie składni UltraSecurityMonitor.ps1..." -ForegroundColor Yellow
if (Test-Path $mainScript) {
    try {
        $parseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile(
            (Resolve-Path $mainScript).Path,
            [ref]$null,
            [ref]$parseErrors
        )
        if ($parseErrors.Count -gt 0) {
            Write-Host "  ❌ Błąd składni:" -ForegroundColor Red
            $parseErrors | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
        } else {
            Write-Host "  ✅ Składnia PowerShell jest poprawna"
        }
    } catch {
        Write-Host "  ❌ Błąd sprawdzania składni: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "  ⚠️  Plik $mainScript nie istnieje – pomijam" -ForegroundColor DarkYellow
}

# 4️⃣ Sprawdzenie repozytorium Git
Write-Host "`n🌳 4. Repozytorium Git:" -ForegroundColor Yellow
try {
    $status = git status --short 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Git zwrócił błąd" }
    if ($status) {
        Write-Host "  ⚠️  Niezatwierdzone zmiany:" -ForegroundColor DarkYellow
        $status | ForEach-Object { Write-Host "    $_" }
    } else {
        Write-Host "  ✅ Repozytorium jest czyste"
    }
    $branch = git branch --show-current 2>&1
    Write-Host "  ℹ  Gałąź: $branch"
    $lastCommit = git log -1 --format="%h %s (%ar)" 2>&1
    Write-Host "  ℹ  Ostatni commit: $lastCommit"
} catch {
    Write-Host "  ⚠️  Git nie jest dostępny lub brak repozytorium" -ForegroundColor DarkYellow
}

# 5️⃣ Sprawdzenie plików runtime (generowanych przez skrypt)
$baseFolder = Join-Path $env:USERPROFILE "Documents\SecurityMonitor"
Write-Host "`n📄 5. Pliki runtime w $baseFolder :" -ForegroundColor Yellow
$runtimeFiles = @(
    @{ Path = Join-Path $baseFolder "security.log";        Desc = "Dziennik zdarzeń (TSV)" },
    @{ Path = Join-Path $baseFolder "security-report.txt"; Desc = "Raport podejrzanych procesów" },
    @{ Path = Join-Path $baseFolder "SIEM\siem.json";      Desc = "Zdarzenia SIEM (NDJSON)" },
    @{ Path = Join-Path $baseFolder "Backup";              Desc = "Folder kopii zapasowych" },
    @{ Path = Join-Path $baseFolder "whitelist.json";      Desc = "Biała lista ścieżek (opcjonalna)" }
)
foreach ($entry in $runtimeFiles) {
    if (Test-Path $entry.Path) {
        Write-Host ("  ✅ {0}" -f $entry.Desc)
    } else {
        Write-Host ("  –  {0}  (zostanie utworzony przy pierwszym uruchomieniu)" -f $entry.Desc) -ForegroundColor DarkGray
    }
}

# 6️⃣ Test połączenia z VirusTotal API
if ($env:VT_API_KEY) {
    Write-Host "`n🛡  6. Sprawdzanie połączenia z VirusTotal..." -ForegroundColor Yellow
    try {
        Invoke-RestMethod -Uri "https://www.virustotal.com/api/v3/files/0" -Headers @{
            "x-apikey" = $env:VT_API_KEY
        } -ErrorAction SilentlyContinue | Out-Null
        Write-Host "  ✅ Połączenie z VirusTotal działa"
    } catch {
        Write-Host "  ⚠️  Nie udało się połączyć z VirusTotal" -ForegroundColor DarkYellow
    }
} else {
    Write-Host "`n🛡  6. VirusTotal: VT_API_KEY nie ustawiony – pomijam test" -ForegroundColor DarkGray
}

Write-Host "`n🎯 Audyt zakończony!" -ForegroundColor Cyan
