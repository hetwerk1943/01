# LifeHub (MVP) — prywatne notatki + produktywność + AI (rozszerzenie)

LifeHub to **extension‑first** projekt dla przeglądarek Chromium (Chrome/Edge), który łączy:

- **Prywatność**: blokowanie trackerów + czyszczenie linków śledzących, docelowo E2EE i TOR
- **Produktywność**: notatki powiązane z URL, tablice (kanban) jako „zakładki 2.0”
- **AI**: podsumowania treści (w MVP jako stub, do podpięcia pod wybrany backend)

## Uruchomienie (Developer Mode)
1. Zainstaluj Node (opcjonalnie, do skryptów): `node -v`
2. Wejdź w `chrome://extensions` (Chrome/Edge)
3. Włącz **Tryb dewelopera**
4. Kliknij **Załaduj rozpakowane**
5. Wskaż folder: `extension/`

## Co działa w tym szkielecie
- Popup z notatką (zapis do `chrome.storage.local`, **szyfrowany** WebCrypto)
- Dashboard jako placeholder (New Tab)
- Podstawowa reguła DNR (blokowanie przykładowego trackera)
- Moduły: `notes/crypto/ai` (AI na razie stub)

## Dokumentacja
- `docs/ROADMAP.md`
- `docs/PRIVACY.md`
- `docs/AI.md`