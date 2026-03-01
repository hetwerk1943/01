# LifeHub Extension – MVP

![LifeHub Logo](assets/logo.png)

## 1. Wizja LifeHub

LifeHub to przeglądarkowe centrum produktywności i prywatności, oparte na 5 filarach:

1. **Notatki kontekstowe** – zapisuj szybkie notatki do dowolnej strony, dostępne w dashboardzie.  
2. **Task Management (Kanban)** – zarządzaj zadaniami w prostym systemie do/doing/done.  
3. **Czysty Internet** – automatyczne usuwanie parametrów śledzących z URL oraz blokada trackerów (DNR).  
4. **AI wspomagające** – podsumowania stron, sugestie i analizy (placeholder dla MVP).  
5. **Prywatność & bezpieczeństwo** – zero-knowledge storage, przyszłościowo E2EE.

---

## 2. Zakres MVP (2–3 miesiące)

- **Dashboard kanban**: 3 kolumny (todo/progress/done), wyświetlanie kart z local storage.  
- **Popup przeglądarki**: dodawanie notatek do aktualnej strony, podsumowanie strony (AI placeholder).  
- **Content script**: czyszczenie UTM / fbclid / gclid, obsługa SPA w przyszłości.  
- **Deklaratywne reguły blokady trackerów**: np. doubleclick.net.  
- **Minimalne moduły JS**: notes.js, ai.js, encoding.js (UTF-8 safe base64).  
- **Manifest MV3**: minimalne uprawnienia (storage + tabs + declarativeNetRequest).  
- **Podstawowe narzędzia developerskie**: lint, test, build (placeholder).  
- **CI**: cache npm + build na push/PR.

---

## 3. Instalacja i uruchomienie rozszerzenia

1. **Sklonuj repozytorium:**
    ```bash
    git clone https://github.com/hetwerk1943/LifeHub-PRO.git
    cd LifeHub-PRO/lifehub-extension
    ```

2. **Włącz Tryb deweloperski w Chrome:**
    - Otwórz `chrome://extensions/`
    - Przestaw suwak **Tryb deweloperski** (prawy górny róg)

3. **Załaduj rozszerzenie:**
    - Kliknij **Load unpacked** (Wczytaj rozpakowane)
    - Wskaż folder `lifehub-extension/`

4. **Upewnij się, że:**
    - Ikona LifeHub widnieje na pasku rozszerzeń (możesz ją przypiąć)

### Szybki start (MVP)

- **Dodaj notatkę** → notatka do URL aktywnej karty (zapisywana lokalnie)
- **Podsumuj stronę** → placeholder AI (na razie fikcyjny prompt)
- **Dashboard kanban** → nowa karta (`New Tab`) pokazuje tablicę kanban  
  *(Jeśli masz `chrome_url_overrides.newtab`, działa automatycznie. W innym przypadku: otwórz `dashboard.html` ręcznie).*

---

## 4. Struktura katalogu

```text
lifehub-extension/
├─ popup.html
├─ popup.js
├─ dashboard.html
├─ dashboard.js
├─ dashboard.css
├─ manifest.json
├─ modules/
│  ├─ notes.js
│  ├─ ai.js
│  └─ encoding.js
├─ content/
│  └─ content.js
├─ rules/
│  └─ tracking-basic.json
├─ package.json
└─ scripts/
   └─ placeholder.mjs
```

---

## 5. Roadmapa

**Faza 1 – MVP (0–3 miesiące)**
- Podstawowy dashboard i popup
- Content script do czyszczenia URL
- Blokada trackera (DNR)
- Placeholder AI / notes module

**Faza 2 – Rozszerzenie funkcji (3–6 miesięcy)**
- Drag & drop tasków
- Rozszerzona blokada trackerów / reguły regex
- Prawdziwe podsumowania AI (integracja API)
- Podstawowe szyfrowanie notatek (E2EE)

**Faza 3 – Zaawansowane funkcje (6–12 miesięcy)**
- Kompletny E2EE dla notatek
- Rozbudowana AI z historią / kontekstem
- Integracje z kalendarzem / Trello / Notion
- Monetyzacja i marketplace szablonów

---

## 6. Prywatność

**MVP**
- Notatki w `chrome.storage.local`
- Brak synchronizacji między urządzeniami
- Minimalne uprawnienia w `manifest.json`

**Docelowo**
- E2EE dla notatek i tasków
- Zero-knowledge cloud sync (opcjonalne)
- Brak śledzenia użytkownika przez AI

---

## 7. AI

- Tryb strict – tylko lokalny kontekst strony wysyłany do AI API
- Placeholdery w `popup.js` i `modules/ai.js`
- Docelowo: podsumowania, sugestie, klasyfikacja treści, bez wycieku danych

---

## 8. Monetyzacja

- **Freemium** – podstawowy kanban + notatki za darmo
- **Subskrypcja PRO** – history AI, E2EE, integracje
- **Marketplace szablonów / AI prompts** – płatne dodatki
- **Sponsorowane reguły blokady** – np. premium tracking filters

---

## 9. Developer tips

- Wszystkie moduły JS jako ESM (`<script type="module" src="popup.js"></script>`)
- Notatki zapisane pod `note:<url>` (normalizacja/czyszczenie param.)
- Content script SPA-safe: hook na `pushState`/`replaceState` + `popstate`
- Minimalizuj permissions w `manifest.json`
- Testy placeholder w `tests/*.test.js`, skrypty w `scripts/*.mjs`

---

## 10. Kontakt / wsparcie

- Repozytorium: **LifeHub-PRO**
- Issues / Pull Requests: mile widziane!
- Prywatność i bezpieczeństwo priorytetem – zachęcamy do testów E2EE i zgłaszania sugestii
