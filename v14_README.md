# LifeHub — Kanban Extension z AI podsumowaniem stron [MVP]

**LifeHub** to prosty Kanban na Chrome, który pozwala zapisywać strony z przeglądarki, zarządzać nimi na tablicy oraz generować automatyczne podsumowania AI dla dowolnej strony — prosto z dashboardu. Idealny na „research inbox” lub osobisty czytnik z notatkami i AI.

---

## Funkcjonalności MVP

- **Dodawanie strony 1 kliknięciem** (z popupu) do tablicy Kanban.
- **Kanban board** z trzema kolumnami: Do przeczytania, Research, Zrobione.
- **Drag & drop** kart między kolumnami.
- **Notatki dla każdej karty** (edycja + podgląd).
- **AI podsumowanie**:
  - Przycisk „Podsumuj AI” przy każdej karcie otwiera modal z automatycznie wygenerowanym skrótem ze strony (na start - placeholder, potem OpenAI, LM Studio itd.).
- **Zawsze aktualny stan** (chrome.storage.sync) — gotowy na synchronizację między urządzeniami.
- **Przejrzysty darkmode, responsywny UI**.
- **Popup**: szybkie dodanie bieżącej strony lub otwarcie dashboardu jednym kliknięciem.

---

## Struktura plików

```
├── extension/
│   ├── popup/
│   │   ├── popup.html
│   │   └── popup.js
│   ├── src/
│   │   ├── app/
│   │   │   └── app.js         # logika dashboardu, modal, AI-integration
│   │   └── content/
│   │       └── ai-extract.js  # extraction tekstu ze strony do AI
│   │   └── background/
│   │       ├── modules/
│   │       │   └── ai.js      # podsumowanie AI + zapis
│   │       └── service-worker.js
│   ├── dashboard.html         # główny widok Kanban + modal
│   └── manifest.json          # manifest Extension (v3, permissions itd)
│
└── README.md
```

---

## Działanie (flow MVP)

1. **Dodajesz stronę** z popupu (lub ręcznie) do „Do przeczytania”.
2. **Przeglądasz dashboard:**  
   - Drag&drop, notatki, odczyt URL, edycja karty.
3. **Chcesz AI-summary?**  
   - Klikasz „Podsumuj AI” przy karcie.
   - Otwiera się modal — widzisz spinner, po chwili skrót/summary ze strony (na start placeholder, łatwo podmienić na realny API call).
   - Możesz notatkę edytować/zapisać.
4. **Status i notatka** zawsze zapisane pod daną kartą.
5. **Stale działa drag&drop, łatwe usuwanie, kopia notatki i stanu** (przechowywane przez chrome.storage.sync).

---

## Instalacja

1. Rozpakuj całość (`extension/`) na dysku.
2. W Chrome: `chrome://extensions` → tryb deweloperski → „Wczytaj rozpakowany” i wskaż `extension/`.
3. Gotowe! W prawym górnym rogu pojawi się ikonka popupu + działa dashboard.

---

## Rozwój, MVP/DEMO

- Podstawowe AI-summary to wycinek tekstu ze strony!  
  Podmień funkcję `callAiApi` w `background/modules/ai.js` na fetch do własnego silnika, OpenAI, LM Studio itp.
- Plugin jest zbudowany na czystym JS — zero bundlerów.
- Dashboard (dashboard.html) to „SPA” bez frameworków.

**Całość: Łatwo rozbudować o tagi, szybkie zakładki, filtrację, a AI-summary jest „API-ready”.**

---

## Jak podmienić AI Summary na realne API (OpenAI, LM Studio itd.)

1. W pliku `extension/src/background/modules/ai.js` zamień placeholder w funkcji `callAiApi` na fetch do swojego API.
   Przykład (OpenAI):

   ```js
   async function callAiApi(text) {
     const res = await fetch("https://api.openai.com/v1/chat/completions", {
       method: "POST",
       headers: {
         "Content-Type": "application/json",
         "Authorization": "Bearer TWÓJ_OPENAI_KEY"
       },
       body: JSON.stringify({
         model: "gpt-3.5-turbo",
         messages: [{ role: "system", content: "Streszczaj tekst po polsku w 3-6 zdaniach." }, { role: "user", content: text }]
       })
     });
     const json = await res.json();
     return json.choices?.[0]?.message?.content || "Brak odpowiedzi AI";
   }
   ```

2. To wszystko — przepływ zostaje taki sam!

---

**Masz pytania, chcesz rozbudować kanban, dodać tagi, własne AI?**  
Projekt jest gotowy na demo, MVP lub inwestora.

---

MIT © LifeHub Team