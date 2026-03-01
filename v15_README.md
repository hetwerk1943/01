# 🌐 LifeHub — Inteligentny Kanban Browser Extension z AI

---

## O projekcie

**LifeHub**: Kanban do zarządzania research-em, notatkami i stronami WWW z natywnym wsparciem AI. Wszystko zintegrowane w bezpiecznym, prywatnym rozszerzeniu do Chrome/Edge z synchronizacją danych i możliwością backupu/importu.

---

## Funkcjonalności

- Dodawanie obecnej strony jednym kliknięciem (popup)
- Kanban 3-kolumnowy z drag&drop, reorderingiem, filtrami, responsywny (desktop/mobile)
- Inline tagi, priorytety, badge na kartach
- Edytowalne notatki (modal), AI-summary (modal z podsumowaniem strony przez API)
- Edytowane inline tytuły kart (double click + blur/enter)
- Rozbudowane UX/UI: ciemny motyw, kolory, efekty drag&drop, toast powiadomienia
- Eksport/Import (JSON) z walidacją, backup i przenoszenie danych
- Pełna synchronizacja przez `chrome.storage.sync`
- **Backend AI-ready**: gotowe podpięcie własnego endpointu (OpenAI, Llama, LM Studio itd.)

---

## Struktura katalogów

```
extension/
  ├── manifest.json
  ├── dashboard.html
  ├── src/
  │   ├── app/
  │   │   └── app.js
  │   ├── background/
  │   │   ├── service-worker.js
  │   │   └── modules/
  │   │       └── ai.js
  │   └── content/
  │       └── ai-extract.js
  ├── popup/
  │   ├── popup.html
  │   └── popup.js
  ├── icon-*.png
  └── README.md
```

---

## Jak działa AI-summary?

1. **Klikasz "Podsumuj AI"** ⇒ uruchamiamy content-script i zbieramy tekst (z `<article>`, `<main>`, `<body>`)
2. Tekst leci do background, potem do funkcji AI (domyślnie placeholder, można podpiąć realny LLM po API)
3. Odpowiedź API jest prezentowana w modalnym oknie jako notatka (możesz edytować i zapisać)
4. Notatki automatycznie zapisują się i synchronizują
5. Cały flow jest asynchroniczny, z UX feedbackiem (spinnery, toast, disabled btn)

---

## Instalacja

1. Skopiuj katalog `extension` na dysk
2. Wejdź w `chrome://extensions`, włącz „Tryb deweloperski”
3. Kliknij „Wczytaj rozpakowany” i wskaż katalog `extension/`
4. Ikona pojawi się przy pasku rozszerzeń, otwórz dashboard lub popup

---

## Przykładowy workflow

1. Dodaj stronę → automatycznie pojawia się w „Do przeczytania”
2. Przeciągnij do „Research”, kliknij AI — wygeneruj podsumowanie, edytuj notatkę
3. Dodaj tagi/prio w modalnym oknie
4. Dashboard filtruje po tagach/prio, eksportujesz board do JSON
5. Notatki, summary i status persistują między wszystkimi Twoimi urządzeniami

---

## Jak podpiąć własne AI?

Otwórz `src/background/modules/ai.js` i podmień placeholder na wywołanie np. OpenAI:

```js
export async function callAiApi(text) {
    const response = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer TWÓJ_OPENAI_KEY"
        },
        body: JSON.stringify({
            model: "gpt-3.5-turbo",
            messages: [
                { role: "system", content: "Streszczaj tekst użytkownika w 3-5 zdaniach po polsku." },
                { role: "user", content: text }
            ]
        })
    });
    const data = await response.json();
    return data.choices?.[0]?.message?.content || "Brak odpowiedzi AI";
}
```

---

## Rekomendowane UX

- Drag & drop z podświetlaniem miejsca dropu, skala .98, placeholder dokładnie w miejscu upuszczenia
- Badge tagów na górze karty (pomarańczowe), kolorowa krawędź priorytetu
- Edycja tytułu przez podwójny klik — inline input
- Toast w prawym dolnym rogu przy dodaniu/notatce/duplikacie
- Responsive: automatyczna szerokość kolumn, poziomy scroll na mobile!

---

MIT © LifeHub Team