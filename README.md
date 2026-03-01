# 🛡️ Ultra Security Monitor – Edycja Całkowita (Total Edition)

Ultra Security Monitor to zaawansowany system monitorowania i ochrony systemu Windows w czasie rzeczywistym, zaprojektowany tak, aby działał jak profesjonalny **Endpoint Detection & Response (EDR)**, bez ingerencji w działanie użytkownika (chyba że włączysz opcjonalną reakcję).

Skrypt łączy w sobie funkcje monitoringu procesów, sieci, plików, rejestru, kont użytkowników oraz automatycznej analizy i alertów. Jest kompletnym narzędziem do ochrony przed złośliwym oprogramowaniem, ransomware, keyloggerami, rootkitami oraz podejrzanymi połączeniami sieciowymi.

---

## 🔹 Stan aplikacji – co już mamy

### Struktura repozytorium (SaaS)

```
.
├── agent/
│   ├── UltraSecurityMonitor.ps1   # Główny silnik monitoringu (EDR)
│   └── Audit-Project.ps1          # Skrypt audytu projektu
├── backend/                        # Przyszły backend API (placeholder)
├── dashboard/
│   └── dashboard.html             # Dashboard HTML/JS
├── docs/
│   ├── architecture.md            # Architektura SaaS
│   └── api-spec.yaml              # Specyfikacja API (OpenAPI 3.1)
├── .github/
│   ├── workflows/
│   │   ├── backend-ci.yml         # CI workflow (Backend)
│   │   └── nightly-agent.yml      # Nocny agent (harmonogram cron)
│   └── FUNDING.yml
├── masterSaaSSetup.ps1            # Skrypt restrukturyzacji repo pod SaaS
├── masterAgent-nightly.ps1        # Nocny agent SaaS (audyt, backup, powiadomienia)
├── CONTRIBUTING.md
├── SECURITY.md
├── LICENSE
└── README.md
```

### Pliki w repozytorium

| Plik | Opis | Status |
|------|------|--------|
| `agent/UltraSecurityMonitor.ps1` | Główny skrypt PowerShell – silnik monitoringu | ✅ Zaimplementowany |
| `dashboard/dashboard.html` | Dashboard HTML/JS do wizualizacji logów i alertów | ✅ Zaimplementowany |
| `agent/Audit-Project.ps1` | Skrypt audytu projektu – sprawdza stan plików i składnię | ✅ Zaimplementowany |
| `docs/architecture.md` | Architektura systemu SaaS | ✅ Zaimplementowana |
| `docs/api-spec.yaml` | Specyfikacja API (OpenAPI 3.1) | ✅ Zaimplementowana |
| `.github/workflows/backend-ci.yml` | CI workflow dla backendu | ✅ Zaimplementowany |
| `.github/workflows/nightly-agent.yml` | Nocny agent – harmonogram cron (02:00 UTC) | ✅ Zaimplementowany |
| `masterSaaSSetup.ps1` | Skrypt restrukturyzacji repo pod SaaS | ✅ Zaimplementowany |
| `masterAgent-nightly.ps1` | Nocny agent SaaS (audyt, backup, Slack) | ✅ Zaimplementowany |
| `SECURITY.md` | Polityka bezpieczeństwa projektu | ✅ Zaimplementowana |
| `CONTRIBUTING.md` | Wytyczne dla kontrybutorów | ✅ Zaimplementowana |
| `README.md` | Dokumentacja projektu | ✅ Zaimplementowana |

### Zaimplementowane funkcje

| Moduł | Opis | Status |
|-------|------|--------|
| Monitoring procesów (EDR) | WMI `Win32_ProcessStartTrace`, heurystyka, whitelist, podpisy cyfrowe | ✅ Gotowe |
| Analiza skrótów SHA-256 | `Get-FileHash` + integracja VirusTotal API v3 | ✅ Gotowe |
| Monitoring sieci | TCP/UDP przez `Get-NetTCPConnection` / `Get-NetUDPEndpoint` | ✅ Gotowe |
| Monitoring plików/folderów | `FileSystemWatcher` – Created, Changed, Renamed + kopie zapasowe | ✅ Gotowe |
| Backup plików | Automatyczne kopie do folderu `Backup\` przy każdej zmianie | ✅ Gotowe |
| Logi zdarzeń (TSV) | `security.log` z rotacją po 50 MB | ✅ Gotowe |
| Raport podejrzanych procesów | `security-report.txt` | ✅ Gotowe |
| Eksport SIEM (NDJSON) | `SIEM\siem.json` – kompatybilny z Splunk/ELK/Graylog | ✅ Gotowe |
| Alerty Discord | Webhook z limitem 2000 znaków | ✅ Gotowe |
| Alerty e-mail (SMTP+SSL) | `Send-MailMessage` z obsługą SSL | ✅ Gotowe |
| Dashboard HTML/JS | Wizualizacja logów, wykresy alertów, historia zdarzeń | ✅ Gotowe |
| Biała lista ścieżek | `whitelist.json` – konfigurowalna lista zaufanych ścieżek | ✅ Gotowe |
| Audyt projektu | `Audit-Project.ps1` – weryfikacja plików i składni | ✅ Gotowe |

### Dane wyjściowe generowane przez aplikację

| Plik/Folder | Zawartość | Generowany przez |
|-------------|-----------|-----------------|
| `Documents\SecurityMonitor\security.log` | Wszystkie zdarzenia (TSV, rotacja 50 MB) | `UltraSecurityMonitor.ps1` |
| `Documents\SecurityMonitor\security-report.txt` | Raporty podejrzanych procesów | `UltraSecurityMonitor.ps1` |
| `Documents\SecurityMonitor\SIEM\siem.json` | Zdarzenia NDJSON dla Splunk/ELK | `UltraSecurityMonitor.ps1` |
| `Documents\SecurityMonitor\Backup\` | Kopie zapasowe zmienionych plików | `UltraSecurityMonitor.ps1` |
| `Documents\SecurityMonitor\whitelist.json` | Opcjonalna biała lista ścieżek | Ręczna konfiguracja |

---

## 🔹 Pliki w repozytorium

| Plik | Opis |
|------|------|
| `agent/UltraSecurityMonitor.ps1` | Główny skrypt PowerShell – silnik monitoringu |
| `dashboard/dashboard.html` | Dashboard HTML/JS do wizualizacji logów i alertów |
| `agent/Audit-Project.ps1` | Skrypt audytu projektu |
| `docs/architecture.md` | Architektura SaaS |
| `docs/api-spec.yaml` | Specyfikacja API (OpenAPI 3.1) |
| `.github/workflows/backend-ci.yml` | CI workflow (Backend) |
| `.github/workflows/nightly-agent.yml` | Nocny agent – cron 02:00 UTC |
| `masterSaaSSetup.ps1` | Skrypt restrukturyzacji repo pod SaaS |
| `masterAgent-nightly.ps1` | Nocny agent SaaS (audyt, backup, Slack) |
| `SECURITY.md` | Polityka bezpieczeństwa |
| `CONTRIBUTING.md` | Wytyczne dla kontrybutorów |
| `README.md` | Dokumentacja projektu |

---

## 🔹 Wymagania

- **System operacyjny:** Windows 10 / Windows 11 (64-bit)
- **PowerShell:** wersja 5.1 lub nowsza (wbudowany w Windows)
- **Uprawnienia:** konto Administrator (wymagane do monitorowania procesów przez WMI)
- **Połączenie z internetem:** opcjonalnie (do alertów Discord, VirusTotal API)
- **Przeglądarka:** dowolna nowoczesna (do otwarcia `dashboard.html`)

---

## 🔹 Konfiguracja

Otwórz `UltraSecurityMonitor.ps1` w edytorze i dostosuj sekcję `KONFIGURACJA` na początku pliku:

```powershell
# Discord webhook (opcjonalnie)
$DiscordWebhookUrl = "https://discord.com/api/webhooks/..."

# VirusTotal API (opcjonalnie)
$VirusTotalApiKey = "twój-klucz-api"

# E-mail alerty
$EmailAlerts  = $true
$SmtpServer   = "smtp.twojadomena.pl"
$SmtpFrom     = "monitor@twojadomena.pl"
$SmtpTo       = "ty@twojadomena.pl"
$SmtpUseSsl   = $true
$SmtpPort     = 587

# Foldery do monitorowania (możesz rozszerzyć)
$MonitoredFolders = @(
    "$env:windir\System32",
    "$env:USERPROFILE\Documents",
    "$env:USERPROFILE\Desktop"
)
```

Opcjonalnie utwórz plik `Documents\SecurityMonitor\whitelist.json` z listą zaufanych ścieżek:

```json
[
  "C:\\Windows\\*",
  "C:\\Program Files\\*",
  "C:\\Program Files (x86)\\*"
]
```

---

## 🔹 Uruchomienie

### Ręczne uruchomienie (jednorazowe)

1. Otwórz **PowerShell jako Administrator**
2. Zmień politykę wykonywania (jednorazowo):
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
3. Uruchom skrypt:
   ```powershell
   cd "C:\Users\<TwojaNazwa>\Documents\SecurityMonitor"
   .\UltraSecurityMonitor.ps1
   ```

### Automatyczny start przy logowaniu (Scheduled Task)

Uruchom poniższe polecenia jako Administrator:

```powershell
$ScriptPath = "$env:USERPROFILE\Documents\SecurityMonitor\UltraSecurityMonitor.ps1"
$action     = New-ScheduledTaskAction -Execute "powershell.exe" `
                  -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""
$trigger    = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
Register-ScheduledTask -Action $action -Trigger $trigger `
    -TaskName "UltraSecurityMonitor" -RunLevel Highest -Force
```

---

## 🔹 Kluczowe funkcje

### 1️⃣ Monitorowanie procesów (EDR)

- Śledzenie każdego uruchomionego procesu w systemie w czasie rzeczywistym (WMI `Win32_ProcessStartTrace`).
- Porównanie procesów z białą listą i wzorcami podejrzanych nazw/ścieżek.
- Weryfikacja podpisu cyfrowego pliku wykonywalnego (`Get-AuthenticodeSignature`).
- Obliczanie skrótu SHA-256 i wysyłanie do VirusTotal (jeśli skonfigurowany klucz API).
- Raportowanie podejrzanych procesów do logów, raportu tekstowego, SIEM JSON oraz alertów Discord/e-mail.

### 2️⃣ Monitoring sieci

- Analiza połączeń TCP/UDP inicjowanych przez podejrzane procesy (`Get-NetTCPConnection`, `Get-NetUDPEndpoint`).
- Raportowanie adresów zdalnych i portów.

### 3️⃣ Monitoring plików i folderów

- Śledzenie folderów: `System32`, `Program Files`, `Program Files (x86)`, `Dokumenty`, `Pulpit`.
- Rejestrowanie zdarzeń: Created, Changed, **Renamed** (poprawka – poprzednio brak zdarzenia Renamed).
- Tworzenie automatycznych kopii zapasowych każdej zmienionej/utworzonej pliku do folderu `Backup`.
- Alert przy zmianach w kluczowych plikach systemowych lub konfiguracyjnych.
- Analiza podpisów cyfrowych i hashów plików w celu wykrycia malware.

### 4️⃣ Monitoring rejestru systemowego

- Śledzenie kluczy autostartu i usług w celu wykrycia złośliwego oprogramowania.

### 5️⃣ Monitoring kont użytkowników

- Śledzenie logowań lokalnych i domenowych, tworzenia i modyfikacji kont.
- Wykrywanie nietypowej aktywności administratora lub nowo utworzonych kont.

### 6️⃣ Automatyczna reakcja i sandboxing

- Opcjonalne blokowanie podejrzanych procesów lub połączeń.
- Przenoszenie plików do kwarantanny (folder `Backup`).
- Możliwość uruchamiania podejrzanych plików w izolowanym środowisku (sandbox).
- Wykrywanie ransomware i masowych zmian plików z automatycznym backupem.

### 7️⃣ Alerty i powiadomienia

- **Discord webhook** – natychmiastowe powiadomienia na kanał Discord (z limitem 2000 znaków).
- **E-mail (SMTP)** – alerty wysyłane przez dowolny serwer SMTP z SSL.
- Dźwiękowe alerty przy krytycznych zdarzeniach.

### 8️⃣ Raporty i dashboard

- Logi zdarzeń w formacie TSV (`security.log`) z automatyczną rotacją po przekroczeniu limitu 50 MB.
- Raport podejrzanych procesów (`security-report.txt`).
- **Dashboard HTML** (`dashboard.html`) z wizualizacją trendów alertów i zdarzeń SIEM – otwórz w przeglądarce i załaduj lokalny plik `siem.json` lub `security.log`.
- Historia zdarzeń z możliwością przewijania i filtrowania według ważności.

### 9️⃣ Integracja SIEM

- Każde zdarzenie (podejrzany proces, zmiana pliku) jest zapisywane do pliku `SIEM\siem.json` w formacie **NDJSON** (jeden obiekt JSON na linię).
- Format kompatybilny z Splunk, Elastic Stack (ELK), Graylog oraz innymi SIEM-ami obsługującymi JSON.
- Struktura rekordu:
  ```json
  {
    "timestamp": "2024-01-15T10:30:00.000+01:00",
    "host": "DESKTOP-ABC123",
    "user": "JanKowalski",
    "event_type": "SuspiciousProcess",
    "severity": "High",
    "data": { "name": "mshta.exe", "pid": 1234, "path": "...", "hash": "...", "sig": "..." }
  }
  ```

### 🔟 Integracja VirusTotal

- Automatyczne sprawdzanie skrótu SHA-256 podejrzanego pliku w bazie VirusTotal API v3.
- Wyniki (liczba detekcji `malicious`, `suspicious`) dodawane do alertu Discord/log/SIEM.
- Wymaga klucza API (bezpłatny plan: 4 zapytania/minutę).
  Utwórz konto na [virustotal.com](https://www.virustotal.com) i skopiuj klucz API do `$VirusTotalApiKey`.

---

## 🔹 Dane wyjściowe

Po uruchomieniu skrypt tworzy następujące pliki w `Documents\SecurityMonitor\`:

| Plik/Folder | Zawartość |
|-------------|-----------|
| `security.log` | Wszystkie zdarzenia w formacie `ISO8601\tTreść` |
| `security-report.txt` | Szczegółowe raporty podejrzanych procesów |
| `SIEM\siem.json` | Zdarzenia w formacie NDJSON (Splunk/ELK) |
| `Backup\` | Kopie zapasowe zmienionych plików |
| `whitelist.json` | Opcjonalna biała lista zaufanych ścieżek |

---

## 🔹 Podsumowanie

Ultra Security Monitor – Total Edition to pełny system ochrony i monitoringu, który łączy funkcjonalność:

- **EDR** (Detekcja i Reagowanie Punktów Końcowych)
- **IDS** (System Wykrywania Włamań)
- **Backup i Ransomware Protection**
- **Analiza heurystyczna** podpisów cyfrowych i skrótów plików
- **Integracja VirusTotal** – weryfikacja hashów w chmurze
- **Eksport SIEM** – NDJSON kompatybilny z Splunk / ELK / Graylog
- **Alerty w czasie rzeczywistym** (Discord, e-mail)
- **Dashboard HTML/JS** z wizualizacją trendów i historią alertów

Dzięki temu systemowi masz w rękach profesjonalne narzędzie bezpieczeństwa, które działa w tle, nie ingerując w codzienną pracę użytkownika, a jednocześnie chroni system w czasie rzeczywistym.

---

## Support Ultra Security Monitor

Sponsor or donate to support development:

- [GitHub Sponsors](https://github.com/sponsors/DominikOpalko)
- [Patreon](https://www.patreon.com/UltraSecPatreon)
- [Ko-fi](https://ko-fi.com/dominik-opalko)
- [Buy Me a Coffee](https://www.buymeacoffee.com/dominik-opalko)
- [Donate via PayPal](https://paypal.me/dominikopalko)
