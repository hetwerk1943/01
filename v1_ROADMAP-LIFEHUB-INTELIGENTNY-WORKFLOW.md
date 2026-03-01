# LifeHub — Roadmap: Inteligentny workflow, wersjonowanie, współpraca, zaawansowane filtry i monitoring

---

## 6️⃣ Inteligentne workflow

- **Automatyczne kategoryzowanie kart przez AI:**  
  Przy dodawaniu karty (lub generowaniu AI-summary) model AI sugeruje odpowiednią kolumnę ("Do przeczytania", "Research", "Zrobione") na podstawie zawartości strony lub tekstu (np. "Detected: tutorial → Research; news → Do przeczytania; how-to → Zrobione").

- **Deadline / przypomnienia:**  
  Możliwość ustawienia daty przy karcie (pole typu deadline/kalendarz). Extension uruchamia `chrome.notifications` lub lokalny reminder; dashboard pokazuje badge z terminem i ostrzeżenie jeśli przekroczony.

- **Automatyczne tagowanie domen:**  
  Extension samodzielnie przypisuje domyślne tagi na podstawie adresu domeny (np. *.github.com = #Tech, *.bloomberg.com = #Finance), a także ułatwia szybkie filtrowanie.

---

## 7️⃣ Wersjonowanie kart i notatek

- **Historia notatek / AI-summary:**  
  Każda karta przechowuje listę rewizji (np. `notesHistory`, `summaryHistory`). Możliwość rollbacku do dowolnej wcześniejszej wersji ("Przywróć", "Porównaj").
  
- **Status wersji:**  
  Każda wersja notatki/summmary oznaczana jako "draft" / "final". Użytkownik decyduje, którą wersję uznaje za wiodącą, inne pozostają w historii.

- **Porównywanie / porównania stylów AI:**  
  Przy wielu AI-summary z różnymi promptami można podglądać i porównać wersje.

---

## 8️⃣ Współpraca / sharing

- **Udostępnienie board:**  
  Link read-only (publiczny snapshot na backendzie) lub „zaproś do edycji” (współdzielone boardy, np. przez Firebase/auth, custom backend).  
  Współpraca może być online (live sync) lub poprzez pliki.

- **Komentarze pod kartą:**  
  Per-card thread, mini-chat (np. do wyłapywania feedbacku w zespole lub pytań do danego researchu).

- **Integracje (Google Docs, Notion, Slack):**  
  Eksportuj podsumowanie, notatkę lub całą kolumnę jednym kliknięciem przez webhook/plugin.

---

## 9️⃣ Zaawansowane filtry i wyszukiwanie

- **Wyszukiwanie pełnotekstowe:**  
  Szybki search po tytułach, URL, tagach, notatkach, AI-summary — pole search w dashboard.

- **Filtry złożone/dynamiczne:**  
  Kombinowanie warunków (np. high-priority AND AI-summary IS NOT NULL; przegląd po deadline/priorities/tags).

- **Sortowanie:**  
  Karty sortowane wg: tytułu, daty dodania, deadline, tagów, kolumny.

---

## 🔟 Monitoring, dashboard, telemetry (opcjonalnie/pitch extension)

- **Aktywność użytkownika:**  
  - Liczba kart, liczba AI-summary (ogółem/tydzień).
  - Najczęściej odwiedzane/wklejane domeny.
  - Statystyki „czas w Research”, produktywność tygodniowa, heatmapa aktywności.

- **Privacy-first:**  
  Monitoring zawsze z monitem privacy, opcja wyłączenia (tylko lokalnie lub w trybie team).

---

## 💡 Strategia (MVP → produkt/scale → power-user/integracja)

- MVP: Kanban, notesy, AI-summary — już gotowe.
- Rozbudowa: tagi, prio, sortowanie, historia, podsumowania, deadline.
- Power-user: analytics, AI suggestions, współpraca/comms, przypomnienia.
- Integracje: Notion, Google Docs, Slack, REST API do automatyzacji.
- **Każdy krok rozwojowy = gotowy fragment do pokazania inwestorowi lub klientowi.**

MIT © LifeHub Team