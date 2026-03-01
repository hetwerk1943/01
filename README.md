# 🛡️ Ultra Security Monitor – Edycja Całkowita (Total Edition)

Ultra Security Monitor to zaawansowany system monitorowania i ochrony systemu Windows w czasie rzeczywistym, zaprojektowany tak, aby działał jak profesjonalny **Endpoint Detection & Response (EDR)**, bez ingerencji w działanie użytkownika (chyba że włączysz opcjonalną reakcję).

Skrypt łączy w sobie funkcje monitoringu procesów, sieci, plików, rejestru, kont użytkowników oraz automatycznej analizy i alertów. Jest kompletnym narzędziem do ochrony przed złośliwym oprogramowaniem, ransomware, keyloggerami, rootkitami oraz podejrzanymi połączeniami sieciowymi.

---

## 🔹 Pliki w repozytorium

| Plik | Opis |
|------|------|
| `UltraSecurityMonitor.ps1` | Główny skrypt PowerShell – silnik monitoringu |
| `New-UsmLicense.ps1` | Narzędzie dostawcy do generowania licencji RSA |
| `dashboard.html` | Dashboard HTML/JS do wizualizacji logów i alertów |
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

## 🔹 Zmienne środowiskowe (bezpieczna konfiguracja)

Zamiast wpisywać klucze API bezpośrednio w pliku skryptu, ustaw je jako zmienne środowiskowe (lub w rejestrze `HKCU:\Software\USM`):

```powershell
# Ustaw zmienne środowiskowe (jednorazowo, jako administrator lub użytkownik)
[System.Environment]::SetEnvironmentVariable("USM_DISCORD_WEBHOOK", "https://discord.com/api/webhooks/...", "User")
[System.Environment]::SetEnvironmentVariable("USM_VT_KEY",          "twój-klucz-virustotal",               "User")
[System.Environment]::SetEnvironmentVariable("USM_SMTP_SERVER",     "smtp.twojadomena.pl",                 "User")
[System.Environment]::SetEnvironmentVariable("USM_SMTP_FROM",       "monitor@twojadomena.pl",              "User")
[System.Environment]::SetEnvironmentVariable("USM_SMTP_TO",         "ty@twojadomena.pl",                   "User")
```

Lub zapisz w rejestrze Windows:

```powershell
$reg = "HKCU:\Software\USM"
if (-not (Test-Path $reg)) { New-Item -Path $reg -Force | Out-Null }
Set-ItemProperty -Path $reg -Name "DiscordWebhook" -Value "https://discord.com/api/webhooks/..."
Set-ItemProperty -Path $reg -Name "VTKey"          -Value "twój-klucz-virustotal"
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
| `loghash.txt` | Łańcuch hashów pliku logu (log integrity) |
| `script.hash` | Hash skryptu głównego (anti-tampering) |
| `license.json` | Plik licencji (opcjonalny – tryb ewaluacyjny bez niego) |

---

## 🔹 System licencjonowania

Ultra Security Monitor obsługuje opcjonalny system licencjonowania oparty na **podpisie RSA-2048**.

### Działanie

1. **Dostawca** generuje plik licencji za pomocą `New-UsmLicense.ps1`.
2. **Klient** otrzymuje plik `license.json` i umieszcza go w `Documents\SecurityMonitor\`.
3. **Skrypt** weryfikuje podpis RSA przy każdym starcie.

### Generowanie licencji (po stronie dostawcy)

```powershell
# Licencja DEMO (klucze testowe wbudowane w skrypt)
.\New-UsmLicense.ps1 -Customer "ACME Corp" -Expiry "2027-12-31" -MaxDevices 10

# Generowanie własnych kluczy produkcyjnych (zalecane przed wdrożeniem!)
.\New-UsmLicense.ps1 -Customer "ACME Corp" -Expiry "2027-12-31" -MaxDevices 10 -GenerateNewKeys
```

Po użyciu `-GenerateNewKeys`:
- `private.key.xml` – klucz prywatny (NIGDY nie commituj ani nie udostępniaj!)
- Klucz publiczny wyświetlony na ekranie – skopiuj do `$LicensePublicKeyXml` w `UltraSecurityMonitor.ps1`

### Format license.json

```json
{
  "Customer":   "ACME Corp",
  "Expiry":     "2027-12-31",
  "MaxDevices": 10,
  "Signature":  "BASE64_RSA_SHA256_SIGNATURE"
}
```

### Tryby pracy

| Stan | Zachowanie |
|------|-----------|
| Brak `license.json` | Tryb ewaluacyjny – skrypt działa normalnie, loguje ostrzeżenie |
| `license.json` z poprawnym podpisem | Pełny tryb licencjonowany |
| `license.json` z błędnym podpisem | Skrypt kończy działanie z kodem 1 |
| Licencja wygasła | Skrypt kończy działanie z kodem 1 |

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
- **Enterprise Hardening** – TLS 1.2+, klucze API z env/rejestru, log integrity, anti-tampering
- **System licencjonowania** – podpis RSA-2048, weryfikacja offline, tryb ewaluacyjny

Dzięki temu systemowi masz w rękach profesjonalne narzędzie bezpieczeństwa, które działa w tle, nie ingerując w codzienną pracę użytkownika, a jednocześnie chroni system w czasie rzeczywistym.
