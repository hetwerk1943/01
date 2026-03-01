# 🛡️ Ultra Security Monitor – Edycja Całkowita (Total Edition)

Ultra Security Monitor to zaawansowany, modularny system bezpieczeństwa dla Windows:
- wykrywa złośliwe procesy (EDR)
- chroni system plików i autostart
- integruje alerty Discord/email/SIEM/VirusTotal
- zapewnia HTML-dashboard, web-agentów demo i przykładowy generator żartów

---

## 📁 Struktura repozytorium

```text
.
├─ UltraSecurityMonitor.ps1    # główny monitor security (PowerShell)
├─ masterAgent.ps1             # agent nocny/batch/test/backup/statystyki
├─ Audit-Project.ps1           # audyt spójności, kodu, backupów, API
├─ dashboard.html              # HTML-dashboard logów/security
├─ agent.html                  # Web AI Repo Agent (samodzielny panel)
├─ web/
│  ├─ repo-agent/
│  │   ├─ index.html           # nowoczesny AI Repo Agent + scoring + MCP
│  │   ├─ app.js
│  │   └─ style.css
│  └─ joke-generator/
│      ├─ index.html           # webowy losowy generator żartów
│      ├─ app.js
│      └─ style.css
├─ .github/
│  ├─ agents/                  # dodatkowe mikro-agenty/wersje demo (HTML)
│  ├─ workflows/               # GitHub Actions CI/workflows
│  └─ ISSUE_TEMPLATE/
├─ package.json
├─ .gitignore
├─ LICENSE
├─ README.md (to właśnie ten)
└─ SECURITY.md
```

---

## 🔑 Kluczowe komponenty i funkcje

- **UltraSecurityMonitor.ps1** — pełny system monitoringu (EDR, IDS, alerty, backup, integracja SIEM/VirusTotal)
- **Dashboard HTML (`dashboard.html`)** — przegląd alertów/logów, wykresy, raporty
- **agent.html & web/repo-agent** — AI Repo Agent (analiza repo, scoring, roadmapa, API MCP)
- **web/joke-generator** — prosta webowa aplikacja do generowania losowych żartów (demo JS/API)
- **masterAgent.ps1, Audit-Project.ps1** — batch nocny, automatyka backupów, audyt
- **.github/agents** — zestaw prostych agentów/mini-app (HTML), pokazujących różne opcje interfejsu i symulacje AI analyz/raportów

---

## 🚀 Szybki start (tryb local/demo)

**1. Dashboard oraz demo-agentów lokalnie:**
```powershell
npm install -g http-server
http-server . -p 8080
# lub inna metoda na serwer lokalny
```
Otwórz w przeglądarce:

- http://localhost:8080/dashboard.html      — dashboard alertów bezpieczeństwa
- http://localhost:8080/web/repo-agent/     — AI Repo Agent (scoring repozytorium)
- http://localhost:8080/web/joke-generator/ — losowy żart (demo fetch API)
- http://localhost:8080/agent.html          — uproszczony repo agent (wersja standalone)

**2. UltraSecurityMonitor.ps1 — uruchomienie audytora (w PowerShell jako admin):**
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
cd "C:\Users\<TwojaNazwa>\Documents\SecurityMonitor"
.\UltraSecurityMonitor.ps1
```
Edytuj sekcję `KONFIGURACJA` w pliku, aby dodać własne API/alerty/mail.

---

## 🔬 Wybrane funkcje bezpieczeństwa

- Procesy: wykrywanie, analiza hashów, whitelist, alerty do Discord/email
- Pliki: monitoring, automatyczny backup, analiza hash/podpisu, ochrona przed ransomware
- Sieć: aktywność TCP/UDP podejrzanych procesów
- Rejestr: zmiany autostartu/usług, podejrzane wpisy
- Alerty: zintegrowane, real-time (Discord, email, Sound, dashboard HTML)
- SIEM: eksport do NDJSON (kompatybilny Splunk/ELK/Graylog)
- VirusTotal: automatyczny lookup hashów na bazie API
- Dashboard: widok na alerty, wykresy, filtrowanie, logi, status systemu

---

## 🤖 Web agent / demo-apps

### **web/repo-agent/** (AI Repo Agent — scoring, roadmap, confidence)

- Wklej url repozytorium GitHub (np. `https://github.com/hetwerk1943/01`)
- Kliknij „Load Repo” → „Run Analysis”
- Oceniany jest poziom bezpieczeństwa, obecność plików kluczowych, scoring confidence, roadmapa działania
- Wypróbuj tryby „Calm/Aggressive”, generuj treść przykładowego PR z roadmapy
- Zobacz wykres scoringu na przestrzeni analiz

### **web/joke-generator/**

- Losowy żart z [JokeAPI](https://jokeapi.dev) (tylko bezpieczne, family-friendly)
- Kliknij „Get a Joke”, zabaw się web fetch API

### **.github/agents/**

- Mikro-przykłady innych agentów, wariacje AI/decision, scoring, demo interfejsów (pliki HTML)
- Do testów lub inspiracji dla dalszych integracji

---

## ⚡️ CI / workflow

- `.github/workflows/main.yml` — uruchamia web serwer agenta (np. do testów E2E)
- `.github/workflows/codeql.yml` — analiza bezpieczeństwa kodu (CodeQL), różne języki
- `.github/workflows/master-agent.yml` — backupy, backup logów, audyty, update sponsors itd.
- `.github/workflows/stale.yml` — automatyczne zamykanie starych issue/PR

---

## 🔐 SECURITY

Patrz plik `SECURITY.md` — polityka, wsparcie, zgłaszanie podatności  
Repozytorium: [hetwerk1943/01](https://github.com/hetwerk1943/01)

---

## ℹ️ Licencja

Projekt objęty licencją Mozilla Public License 2.0 (plik LICENSE).

---

**Masz pytania, chcesz coś dodać, poprawić lub stworzyć nowy microskrypt/agent? Otwórz Issue lub PR!**
