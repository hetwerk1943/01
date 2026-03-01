# LifeHub — Inteligentna, Prywatna, Produktywna (rozszerzenie)

LifeHub to rozszerzenie do przeglądarek Chromium (Chrome/Edge), które łączy:
- **Prywatność**: blokowanie trackerów + czyszczenie linków śledzących, docelowo E2EE i TOR
- **Produktywność**: notatki do stron + dashboard (tablice/kanban jako „zakładki 2.0”)
- **AI**: podsumowania treści (w MVP jako stub do podpięcia pod backend)

## Uruchomienie (Developer Mode)
1. Wejdź w `chrome://extensions`
2. Włącz **Tryb dewelopera**
3. Kliknij **Załaduj rozpakowane**
4. Wskaż folder: `extension/`

## MVP – co działa
- Popup: notatka do aktywnej strony (zapis szyfrowany w `chrome.storage.local`)
- AI: przycisk „Podsumuj” (stub)
- Dashboard: placeholder jako New Tab
- DNR: podstawowa reguła blokowania (przykład)
- URL cleaner: usuwa parametry śledzące z klikanych linków

## Docs
- `docs/ROADMAP.md`
- `docs/PRIVACY.md`
- `docs/AI.md`