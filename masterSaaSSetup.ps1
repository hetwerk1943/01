# 🔹 masterSaaSSetup.ps1
Write-Host "🚀 Rozpoczynam restrukturyzację repo pod SaaS..." -ForegroundColor Cyan

# 1️⃣ Tworzenie struktury katalogów
$folders = @("agent", "backend", "dashboard", "docs", ".github/workflows")
foreach ($f in $folders) {
    if (-not (Test-Path $f)) { New-Item -ItemType Directory -Path $f | Out-Null; Write-Host "✅ Utworzono folder $f" }
}

# 2️⃣ Przeniesienie istniejących plików
Move-Item "UltraSecurityMonitor.ps1" "agent/" -Force
Move-Item "Audit-Project.ps1" "agent/" -Force
Move-Item "masterAgent.ps1" "agent/" -Force
Move-Item "dashboard.html" "dashboard/" -Force
Write-Host "📁 Pliki przeniesione do nowych folderów"

# 3️⃣ Tworzenie plików dokumentacji SaaS
$archFile = "docs/architecture.md"
@"
# SaaS Architecture

- Agent → API → Dashboard
- Multi-tenant design
- License & Billing system
- Security & logging
"@ | Set-Content $archFile
Write-Host "📄 Utworzono docs/architecture.md"

$apiFile = "docs/api-spec.yaml"
@"
openapi: 3.1.0
info:
  title: Ultra Security Monitor API
  version: 1.0.0
paths:
  /alerts:
    get:
      summary: Pobiera alerty z agenta
      responses:
        '200':
          description: Lista alertów
  /license:
    post:
      summary: Weryfikacja licencji enterprise
      responses:
        '200':
          description: Status licencji
"@ | Set-Content $apiFile
Write-Host "📄 Utworzono docs/api-spec.yaml"

# 4️⃣ Dodanie workflow CI placeholder
$ciFile = ".github/workflows/backend-ci.yml"
@"
name: Backend CI
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Placeholder build step
        run: echo 'Build backend (future)'
"@ | Set-Content $ciFile
Write-Host "⚙️ Utworzono placeholder workflow CI"

# 5️⃣ Dodanie podstawowych plików enterprise
@"
# SECURITY.md
Project Security Policy
- Secrets must use environment variables
- Logs sanitized before commit
"@ | Set-Content "SECURITY.md"

@"
# CONTRIBUTING.md
Guidelines for contributing
"@ | Set-Content "CONTRIBUTING.md"

# Only create LICENSE if one doesn't already exist
if (-not (Test-Path "LICENSE")) {
    @"
# LICENSE
MIT License
"@ | Set-Content "LICENSE"
}
Write-Host "📄 Utworzono SECURITY.md, CONTRIBUTING.md, LICENSE"

# 6️⃣ Commit & push changes
try {
    git add .
    git commit -m "Restructure repo for SaaS: folders, docs, CI, enterprise hygiene"
    git push origin main
    Write-Host "✅ Zmiany wypchnięte do GitHub"
} catch {
    Write-Host "⚠️ Nie udało się zrobić git push. Sprawdź konfigurację Git"
}

Write-Host "---------------------------------------------"
Write-Host "✅ Repo przygotowane pod SaaS (fundamenty gotowe)"
