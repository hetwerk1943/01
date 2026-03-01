# 🌐 LifeHub — Inteligentna, Prywatna, Produktywna Przeglądarka (Extension MVP)

**Cel projektu:**  
LifeHub to innowacyjne rozszerzenie Chrome, które łączy **produktywność**, **AI** i **pełną prywatność** w jednej tablicy Kanban dla researchu i zarządzania stronami.

---

## 🔹 MVP w działaniu

- **Dodawanie stron jednym kliknięciem** z popupu
- **Kanban z drag & drop**: 3 kolumny — Do przeczytania, Research, Zrobione
- **Notatki i AI-summary**: każde podsumowanie strony trafia do notatki karty, edytowalne inline
- **Persistencja i synchronizacja**: `chrome.storage.sync`, dostęp do danych na wszystkich urządzeniach z tym samym Chrome
- **UX/UI:** nowoczesny ciemny motyw, intuicyjny dashboard, responsywny i minimalistyczny

---

## 🔹 Dlaczego LifeHub wyróżnia się na rynku

| Funkcja          | Konkurencja        | LifeHub                     |
|------------------|-------------------|-----------------------------|
| Prywatność       | incognito/AdBlock | Szyfrowanie + sync + anonimizacja linków |
| Produktywność    | brak/tryb czytania| Kanban + notatki + AI-summary |
| AI               | brak              | Podsumowania stron w czasie rzeczywistym |
| Społeczność      | brak              | Prywatne grupy (planowane)  |
| Cross-platform   | sync przeglądarki | Chrome sync + mobilne plany |

✅ Łączy wszystkie braki konkurencji w **jednym, spójnym narzędziu**

---

## 🔹 Demo flow (user story)

1. Użytkownik znajduje stronę → „Dodaj do LifeHub”  
2. Karta trafia do kolumny „Do przeczytania”  
3. Drag & drop do „Research”, dodaje notatkę lub AI-summary  
4. Notatki i statusy są widoczne na każdym urządzeniu po synchronizacji  

---

## 🔹 Architektura MVP

- **Extension Chrome / Manifest V3**  
- **Popup**: dodawanie kart, otwieranie dashboardu  
- **Dashboard SPA**: kanban, notatki, AI-summary  
- **Background / Service Worker**: komunikacja między popup, dashboard i content-script  
- **Content-script**: ekstrakcja tekstu do AI  
- **Storage**: `chrome.storage.sync` dla persistencji multisync  

---

## 🔹 Kolejne kroki / rozbudowa

- Integracja live z API AI (OpenAI / własny LLM)  
- Prywatne grupy i współpraca (co-browsing, sharing)  
- Tagowanie, priorytety, reorder wewnątrz kolumn  
- Backup / Import / Export JSON  
- Rozszerzenie UX: inline edit tytułów, podgląd kart, powiadomienia  

---

## 🔹 Wnioski / Potencjał

LifeHub to **niszowa przeglądarka dla produktywnych i prywatnych użytkowników**, która łączy:  

- Pełną prywatność  
- Inteligentne AI podsumowania  
- Nowoczesny, czytelny Kanban UX  
- Synchronizację danych między urządzeniami  

💡 MVP jest gotowe do prezentacji i testów, pokazuje **wartość produktu**, UX i możliwości skalowania.

---

MIT © LifeHub Team