# 🛡️ Ultra Security Monitor – ULTRAMASTER Edition

Kompletna dokumentacja pakietu **Ultra Security Monitor – Full Suite**, obejmująca wszystkie moduły wchodzące w skład edycji ULTRAMASTER.

---

## 📦 Pliki w pakiecie ULTRAMASTER

| Plik | Opis |
|------|------|
| `UltraSecurityMonitor.ps1` | Główny silnik EDR – monitorowanie procesów, plików, sieci i rejestru w czasie rzeczywistym |
| `VT-Cache.ps1` | Moduł cache wyników VirusTotal (RAM + dysk) – redukuje zużycie limitu API |
| `Send-CollectorAlert.ps1` | Zunifikowany moduł alertów – Discord, e-mail, SIEM JSON w jednym wywołaniu |
| `Write-SecureLog.ps1` | Bezpieczny dziennik z łańcuchem HMAC-SHA256 – odporny na manipulacje |
| `CollectorAPI.ps1` | Centralny kolektor REST (HttpListener) – odbiera zdarzenia SIEM z wielu hostów |
| `dashboard.html` | Dashboard HTML/JS – wizualizacja logów i alertów SIEM w przeglądarce |
| `Audit-Project.ps1` | Skrypt audytu projektu – weryfikuje pliki, składnię i stan repozytorium |
| `README.md` | Główna dokumentacja projektu (edycja Total Edition) |
| `README_ULTRAMASTER.md` | Niniejsza dokumentacja – edycja ULTRAMASTER Full Suite |

---

## 🔹 Wymagania

- **System operacyjny:** Windows 10 / Windows 11 (64-bit)
- **PowerShell:** wersja 5.1 lub nowsza
- **Uprawnienia:** Administrator (wymagane przez WMI, HttpListener i FileSystemWatcher)
- **Połączenie z internetem:** opcjonalnie (Discord, VirusTotal, e-mail)

---

## 🔹 Szybki start

### 1. Sklonuj lub pobierz repozytorium

```powershell
git clone https://github.com/hetwerk1943/-Ultra-Security-Monitor-Wersja-Totalna-Full-Suite-.git
cd "-Ultra-Security-Monitor-Wersja-Totalna-Full-Suite-"
```

### 2. Skonfiguruj główny skrypt

Otwórz `UltraSecurityMonitor.ps1` i wypełnij sekcję `KONFIGURACJA`:

```powershell
$DiscordWebhookUrl = "https://discord.com/api/webhooks/..."
$VirusTotalApiKey  = "twój-klucz-api"
$EmailAlerts       = $true
$SmtpServer        = "smtp.twojadomena.pl"
$SmtpFrom          = "monitor@twojadomena.pl"
$SmtpTo            = "ty@twojadomena.pl"
```

### 3. Uruchom jako Administrator

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
.\UltraSecurityMonitor.ps1
```

---

## 🔹 Moduły ULTRAMASTER – opis szczegółowy

### 📁 VT-Cache.ps1

Moduł buforowania wyników VirusTotal ogranicza liczbę wywołań API (bezpłatny plan: 4/min).

**Funkcje:**

| Funkcja | Opis |
|---------|------|
| `Get-VTReportCached` | Zwraca wynik VT dla skrótu SHA-256; używa cache przed zapytaniem do API |
| `Remove-VTCacheEntry` | Usuwa pojedynczy wpis z cache |
| `Clear-VTCache` | Czyści cały cache (RAM i plik dyskowy) |

**Przykład użycia:**

```powershell
. .\VT-Cache.ps1
$result = Get-VTReportCached -Hash "abc123..." -ApiKey $VirusTotalApiKey
if ($result.Malicious -gt 0) { Write-Warning "Plik jest złośliwy!" }
Write-Host "Z cache: $($result.FromCache)"
```

**Cache:**
- Domyślny czas życia wpisu: **24 godziny** (`$VTCacheTTLHours`)
- Plik cache: `%TEMP%\vt-cache.json`
- Przeterminowane wpisy są automatycznie usuwane przy każdym zapisie

---

### 📣 Send-CollectorAlert.ps1

Zunifikowany moduł alertów – jedno wywołanie `Send-CollectorAlert` dostarcza powiadomienie przez wszystkie skonfigurowane kanały.

**Funkcje:**

| Funkcja | Opis |
|---------|------|
| `Set-CollectorConfig` | Ustawia konfigurację (Discord URL, SMTP, ścieżka SIEM) |
| `Send-CollectorAlert` | Główna funkcja – Discord + e-mail + SIEM JSON |
| `Send-CollectorDiscord` | Wysyła wiadomość tylko na Discord |
| `Send-CollectorEmail` | Wysyła alert tylko e-mailem |
| `Write-CollectorSiem` | Zapisuje zdarzenie do pliku NDJSON (SIEM) |

**Przykład użycia:**

```powershell
. .\Send-CollectorAlert.ps1

Set-CollectorConfig @{
    DiscordWebhookUrl = "https://discord.com/api/webhooks/..."
    EmailEnabled      = $true
    SmtpServer        = "smtp.gmail.com"
    SmtpFrom          = "monitor@example.com"
    SmtpTo            = "admin@example.com"
    SiemLogPath       = "C:\SecurityMonitor\SIEM\siem.json"
}

Send-CollectorAlert -Subject "Podejrzany proces" -Message "mshta.exe uruchomiony z Temp" `
    -Severity "High" -EventType "SuspiciousProcess" `
    -Data @{ pid = 1234; path = "C:\Users\user\AppData\Local\Temp\mshta.exe" }
```

---

### 🔐 Write-SecureLog.ps1

Bezpieczny dziennik oparty na łańcuchu HMAC-SHA256 (podobnie do Blockchain) – każdy wpis jest kryptograficznie powiązany z poprzednim, co umożliwia wykrycie ingerencji.

**Funkcje:**

| Funkcja | Opis |
|---------|------|
| `Initialize-SecureLog` | Inicjalizuje moduł, tworzy klucz HMAC (jeśli brak) |
| `Write-SecureLog` | Zapisuje wpis z HMAC, numerem sekwencyjnym i znacznikiem czasu |
| `Test-SecureLogIntegrity` | Weryfikuje integralność pliku dziennika |

**Format wpisu:**

```
2024-01-15T10:30:00.000+01:00	42	Warning	Podejrzany proces PID 1234	<hmac-sha256>
```

**Przykład użycia:**

```powershell
. .\Write-SecureLog.ps1

Initialize-SecureLog -LogPath "C:\SecurityMonitor\secure.log" `
                     -KeyFile  "C:\SecurityMonitor\secure.log.key"

Write-SecureLog -Message "Monitor uruchomiony" -Severity "Info"
Write-SecureLog -Message "Podejrzany plik wykryty: C:\Temp\bad.exe" -Severity "Critical"

$integrity = Test-SecureLogIntegrity
if ($integrity.IsValid) {
    Write-Host "✅ Dziennik nie był modyfikowany ($($integrity.TotalLines) wpisów)"
} else {
    Write-Warning "❌ Wykryto ingerencję w liniach: $($integrity.TamperedLines -join ', ')"
}
```

> ⚠️ **Ważne:** Plik klucza (`secure.log.key`) musi być chroniony przed nieautoryzowanym dostępem. Bez niego weryfikacja integralności jest niemożliwa.

---

### 🌐 CollectorAPI.ps1

Centralny kolektor REST oparty na `System.Net.HttpListener`. Odbiera zdarzenia SIEM (JSON) od wielu hostów i zapisuje je do centralnego pliku NDJSON.

**Endpoint:**

```
POST http://<host>:<port>/collector/event
Content-Type: application/json
Authorization: Bearer <ApiKey>  (opcjonalnie)
```

**Funkcje:**

| Funkcja | Opis |
|---------|------|
| `Set-CollectorAPIConfig` | Konfiguruje port, ścieżkę logu i klucz API |
| `Start-CollectorAPI` | Uruchamia kolektor (blokujące) |
| `Stop-CollectorAPI` | Zatrzymuje kolektor |
| `Send-EventToCollector` | Wysyła zdarzenie z agenta do zdalnego kolektora |

**Przykład – uruchomienie serwera (centralny host):**

```powershell
. .\CollectorAPI.ps1

Set-CollectorAPIConfig -Port 8765 `
    -LogPath "C:\SecurityMonitor\SIEM\collector-events.json" `
    -ApiKey  "mój-tajny-klucz"

Start-CollectorAPI   # blokujące – uruchom w osobnym oknie lub jako Job
```

**Przykład – wysyłanie zdarzeń z agentów (hosty monitorowane):**

```powershell
. .\CollectorAPI.ps1

Send-EventToCollector -CollectorUrl "http://192.168.1.10:8765/collector/event" `
    -ApiKey "mój-tajny-klucz" `
    -EventData @{
        timestamp  = (Get-Date).ToString("o")
        host       = $env:COMPUTERNAME
        event_type = "SuspiciousProcess"
        severity   = "High"
        data       = @{ name = "mshta.exe"; pid = 1234 }
    }
```

---

## 🔹 Architektura ULTRAMASTER

```
┌─────────────────────────────────────────────────────┐
│              Hosty monitorowane (agenci)             │
│                                                     │
│  UltraSecurityMonitor.ps1                           │
│   ├── VT-Cache.ps1        (cache VT API)            │
│   ├── Send-CollectorAlert.ps1  (Discord/e-mail)     │
│   ├── Write-SecureLog.ps1 (bezpieczny log lokalny)  │
│   └── CollectorAPI.ps1 → Send-EventToCollector()   │
│             │                                       │
└─────────────┼───────────────────────────────────────┘
              │  HTTP POST /collector/event
              ▼
┌─────────────────────────────────────────────────────┐
│          Centralny Kolektor (CollectorAPI.ps1)       │
│   Start-CollectorAPI  → collector-events.json       │
│   (NDJSON – Splunk / ELK / Graylog)                 │
└─────────────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────┐
│               Dashboard (dashboard.html)             │
│   Wczytaj plik NDJSON i wizualizuj alerty           │
└─────────────────────────────────────────────────────┘
```

---

## 🔹 Integracja z istniejącym UltraSecurityMonitor.ps1

Aby włączyć moduły ULTRAMASTER do istniejącego skryptu, dodaj na początku `UltraSecurityMonitor.ps1`:

```powershell
. (Join-Path $PSScriptRoot "VT-Cache.ps1")
. (Join-Path $PSScriptRoot "Send-CollectorAlert.ps1")
. (Join-Path $PSScriptRoot "Write-SecureLog.ps1")
```

Następnie zastąp wywołania `Get-VirusTotalReport` na `Get-VTReportCached` oraz `Write-Log` na `Write-SecureLog`.

---

## 🔹 Bezpieczeństwo

| Zalecenie | Opis |
|-----------|------|
| Klucz HMAC | Plik `secure.log.key` – ogranicz dostęp ACL do konta Administratora |
| Klucz API kolektora | Przekazuj przez zmienną środowiskową lub Credential Manager, nie na stałe w kodzie |
| HTTPS dla kolektora | W środowiskach produkcyjnych umieść `CollectorAPI.ps1` za reverse proxy (nginx/IIS) z TLS |
| Klucz VirusTotal | Przechowuj w `$env:VT_API_KEY` lub Windows Credential Manager |

---

## 🔹 Licencja

MIT License – szczegóły w pliku `LICENSE`.
