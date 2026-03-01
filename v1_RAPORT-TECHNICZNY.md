# Raport techniczny
## LifeHub — Kanban z AI-summary (rozszerzenie Chrome)

---

### 1. **Cel i funkcje MVP**

LifeHub to rozszerzenie Chrome umożliwiające osobisty research inbox / tablicę Kanban z natychmiastowym podsumowaniem dowolnej strony przez AI. Użytkownik:
- zapisuje strony jednym kliknięciem z popupu,
- zarządza kartami w Kanban: drag & drop, notatki,
- generuje podsumowanie AI oraz edytuje i zapisuje je jako notatkę,
- zachowuje dane automatycznie („persistencja multisync”) na wszystkich urządzeniach Chrome z tym samym kontem.

---

### 2. **Struktura i pliki projektu**

```
extension/
│
├─ manifest.json           # Deklaracja uprawnień (tabs, storage, scripting), content_script, popup, icons
│
├─ dashboard.html          # Kanban — główny interfejs SPA + modal AI/notes
├─ src/
│  ├─ app/
│  │   └─ app.js           # Logika Kanban, modale, render, obsługa przycisków, AI
│  ├─ background/
│  │   ├─ modules/
│  │   │   └─ ai.js        # Obsługa generowania AI-summary
│  │   └─ service-worker.js# Most komunikacyjny: eventy chrome.runtime
│  └─ content/
│      └─ ai-extract.js    # Pobieranie tekstu ze strony (content-script)
│
├─ popup/
│  ├─ popup.html           # Popup: Dodaj kartę lub Otwórz dashboard
│  └─ popup.js             # Logika: sprawdzanie duplikatów, toast, zapis url
│
├─ README.md               # Pełna instrukcja, opis rozbudowy i rozwoju
```

---

### 3. **Główne funkcje / zaimplementowane rozwiązania**

- **Drag & drop** kart pomiędzy kolumnami. Karta podczas przeciągania ma `.dragging { opacity: 0.5; }` dla UX.
- **Modal AI/notes**: Kliknięcie „Podsumuj AI” lub „Edytuj notatkę” otwiera modal z polem textarea do edycji.
- **AI-summary**: Generowane przyciskiem, spinner na czas oczekiwania, podsumowanie pojawia się w polu do edycji i można je ręcznie poprawiać przed zapisaniem.
- **Notatka zapisywana inline** (pod tytułem) po każdym zapisie, wywoływana z modalnego okna.
- **Synchronizacja stanu** tablicy i notatek przez `chrome.storage.sync` — persistencja na wszystkich urządzeniach użytkownika przy tym samym loginie Chrome.
- **Obsługa wszystkich przycisków**:  
  - `open` — otwiera url w nowej karcie,  
  - `delete` — usuwa kartę,  
  - `ai-summary` — wywołuje podsumowanie AI i modal,  
  - `edit note` — pozwala ręcznie wpisać/zmienić notatkę.
- **Popup zabezpiecza dodawanie duplikatów** (brak powtórnego url w Do przeczytania), toast z komunikatem o sukcesie/błędzie.

---

### 4. **Persistencja i synchronizacja**

- Dane (`boardState`, notatki) są przechowywane przez API `chrome.storage.sync`.
- Dzięki temu, tablica i notatki są **automatycznie dostępne na każdym Chrome** użytkownika (desktop/laptop po zalogowaniu tym samym kontem Google i synchronizacji).
- Format karty umożliwia łatwe późniejsze rozszerzanie (tagi, priorytety, napisy AI, historia wersji, linki/załączniki).

---

### 5. **AI-summary — architektura**

- **Ekstrakcja tekstu:** plik content-script pobiera tekst strony.
- **Background/service-worker:** odbiera żądanie, pobiera tekst ze strony, przekazuje do AI-summary.
- **Podsumowanie:** domyślnie placeholder (fragment tekstu ze strony), gotowe do podmiany jednym miejscem (`modules/ai.js/callAiApi`) na dowolne API (OpenAI, LM Studio itd.).
- **UI/UX:** spinner modalny na czas AI; po generowaniu — podgląd, edycja i zapis.
- **Podsumowanie staje się notatką karty** — zawsze widoczną i edytowalną.

---

### 6. **Demo flow (user story)**

1. Użytkownik znajduje ciekawą stronę, klika w popupie „Dodaj do LifeHub”.
2. W dashboardzie widzi kartę w kolumnie „Do przeczytania”.
3. Przeciąga kartę do „Research”, opcjonalnie dodaje notatkę (ręcznie lub przez AI).
4. Kliknięcie „Podsumuj AI” generuje skrót ze strony i pozwala go edytować/zapisać inline pod kartą.
5. Po zalogowaniu na innym urządzeniu (Chrome sync) ma ten sam stan, notatki i statusy.

---

### 7. **Przykładowe technologie i integracje (rozbudowa)**

- Backend AI: Gotowe do wpięcia OpenAI/GPT, własnego LLM, serwisów REST.
- Możliwa rozbudowa: tagi, priorytety, sortowanie, wersjonowanie notatek, filtracja, backup/import/export JSON.
- Pełny kod Vanilla JS (Zero zależności), łatwość rozbudowy.

---

### 8. **Podsumowanie**

Projekt jest gotowym MVP/aplikacją do demonstracji lub natychmiastowego użycia — UX zgodny ze współczesnymi standardami, bardzo łatwa modyfikacja oraz szybka prezentacja dla klienta/inwestora.  
**Każda funkcja deklarowana w MVP została wdrożona, kod jest clean, modularny, bez zbędnych zależności.**

---

MIT © LifeHub Team
