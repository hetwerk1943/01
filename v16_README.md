# LifeHub — Personal Research Kanban z AI-summary 🚀

---

## 1. **Wizja i pitch inwestorski**

LifeHub to inteligentne rozszerzenie Chrome, które zmienia sposób pracy z informacją online.  
Dzięki połączeniu klasycznej tablicy Kanban z natychmiastowym podsumowaniem AI:

- Przechwytujesz dowolną stronę jednym kliknięciem,
- Organizujesz swoje zadania w kolumnach **Do przeczytania**, **Research**, **Zrobione**,
- Automatycznie generujesz i edytujesz podsumowania AI,
- Zachowujesz pełną synchronizację między urządzeniami Chrome.

**Pitch:**  
> "Transformujemy chaos internetu w spersonalizowany, inteligentny workflow. MVP działa, UX przewyższa większość konkurencyjnych rozwiązań, a integracja AI pozwala w pełni automatyzować research."  

---

## 2. **Core MVP — funkcje działające już teraz**

- **Kanban drag & drop:**  
  - 3 kolumny, karty przesuwane między nimi
  - Karty zawierają title, URL, notatkę
- **Popup extension:**  
  - Dodawanie bieżącej strony do Kanbanu
  - Otwarcie dashboardu
- **Persistencja:**  
  - Dane zapisują się w `chrome.storage.sync` → dostęp z dowolnego urządzenia
- **AI-summary:**  
  - Ekstrakcja tekstu ze strony
  - Modal z podsumowaniem AI, edytowalne przed zapisaniem
- **Minimalistyczne UX:**  
  - Ciemny, nowoczesny styl, responsywne karty, hover efekty, czytelność

---

## 3. **Architektura projektu / modularność**

```
extension/
│
├─ manifest.json
├─ dashboard.html
├─ src/
│  ├─ app/
│  │   └─ app.js           # Kanban logic, modale, AI, render, event handlers
│  ├─ background/
│  │   ├─ modules/
│  │   │   └─ ai.js        # AI-summary abstraction
│  │   └─ service-worker.js# runtime event bridge
│  └─ content/
│      └─ ai-extract.js    # Extraction script from page content
├─ popup/
│  ├─ popup.html
│  └─ popup.js
├─ README.md
└─ assets/icons/
```

**Zasada:** każdy moduł może być wymieniony lub rozbudowany niezależnie.  
Integracja dowolnego AI wymaga podmiany jednej funkcji (`ai.js / callAiApi`).

---

## 4. **Rozbudowa / power-user features**

1. **AI-driven workflow**  
   - Sugestia kolumn i tagów na podstawie treści strony
   - Automatyczne przypomnienia / deadline
2. **Tagi i priorytety**  
   - Filtrowanie i sortowanie
   - Wizualne oznaczenia kolorami
3. **Wersjonowanie notatek i podsumowań**  
   - Historia zmian, rollback
   - Draft vs final
4. **Współpraca / sharing**  
   - Read-only lub edycja z linkiem
   - Komentarze per karta
5. **Zaawansowane wyszukiwanie i filtry**  
   - Tytuły, URL, notatki, AI-summary, tagi
6. **Analiza i telemetry**  
   - Statystyki kart, domen, czasu spędzonego
   - Wykresy dla power-user dashboard
7. **Integracje**  
   - Eksport do Notion, Google Docs, Slack

---

## 5. **UX & Design Principles**

- Minimalistyczny, ciemny styl z kontrastującymi akcentami  
- Karty podświetlone przy drag & drop (`opacity: 0.5`)  
- Modal zamiast prompt → nie blokuje renderowania, lepsze dla edycji notatek/AI-summary  
- Responsywność dla różnych rozdzielczości, scroll w kolumnach  

---

## 6. **Demo flow (user story)**

1. Znajduję ciekawą stronę → klikam „Dodaj do LifeHub” w popupie.  
2. Karta pojawia się w kolumnie **Do przeczytania**.  
3. Przeciągam kartę do **Research**, dodaję notatkę lub generuję AI-summary.  
4. Notatka i podsumowanie zapisywane inline i synchronizowane w `chrome.storage.sync`.  
5. Po zalogowaniu w innym Chrome → ten sam stan, wszystkie karty i notatki.  

---

## 7. **Technologie / integracje**

- Vanilla JS + Manifest V3  
- Modularne pliki → łatwa integracja AI / backend  
- `chrome.storage.sync` → full cross-device persistency  
- Możliwość podłączenia dowolnego LLM (OpenAI, LM Studio, inne)  
- Minimalne zależności → łatwe deployment i rozwój  

---

## 8. **Dlaczego inwestor / klient powinien się zainteresować**

- MVP działa → demo-ready  
- UX przewyższa większość konkurencyjnych rozwiązań  
- Modularna architektura → szybkie dodanie AI, integracji, współpracy  
- Produkt rośnie naturalnie w **full productivity suite z AI on top**  
- Możliwość monetizacji: premium AI-summary, zaawansowane filtry, współpraca  

---

## 9. **Roadmapa**

| Etap | Funkcje |
|------|---------|
| MVP | Kanban, drag & drop, popup, AI-summary modal, persistencja |
| Power-user | Tagi, priorytety, notatki inline, sortowanie, filtry |
| Advanced | Wersjonowanie, sharing, komentarze, analytics, automatyczne AI suggestions |
| Integracje | Notion, Google Docs, Slack, eksport/import JSON, backup/restore |
| Monetizacja | Premium AI, team plans, cloud sync, advanced analytics |

---

## 🔥 Podsumowanie

LifeHub to gotowy produkt MVP z natychmiastową wartością dla użytkownika.  
**Każda funkcja deklarowana w MVP działa, UX jest czysty, kod modularny i łatwy do rozbudowy.**  
Dalsze funkcje (AI workflow, współpraca, analityka) mogą być dodane w kolejnych sprintach.  

MIT © LifeHub Team