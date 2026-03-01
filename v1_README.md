# 🌐 LifeHub – Inteligentna, Prywatna, Produktywna „Przeglądarka” (rozszerzenie)

**LifeHub** to projekt, który buduje „warstwę” na przeglądarkę (startowo jako **rozszerzenie do Chrome/Edge**) łącząc:
- **prywatność** (blokowanie trackerów, czyszczenie linków),
- **produktywność** (tablice zakładek, notatki, zadania),
- **AI** (podsumowania i wsparcie researchu),
- oraz docelowo **współpracę** (grupy, współdzielenie, co-browsing) i **synchronizację**.

Celem LifeHub jest dać w jednym narzędziu to, co ludzie cenią w Chrome/Brave/Firefox/Edge/Safari — ale z naciskiem na **prywatność + organizację pracy + AI**.

---

## 🚀 Funkcje (wizja produktu)

### 1) Prywatność i bezpieczeństwo
- Blokowanie trackerów / reklam (reguły + listy filtrów)
- Oczyszczanie linków śledzących (np. parametry typu `utm_*`, `fbclid`)
- Docelowo: szyfrowanie danych użytkownika po stronie klienta (E2EE)
- Docelowo: tryb anonimowy z TOR (jak Brave)

> Uwaga: TOR i „absolutna prywatność” to funkcje wysokiego ryzyka/utrzymania — planowane po walidacji MVP.

### 2) Produktywność
- **Tablice zakładek w stylu kanban** (zakładki 2.0)
- **Notatnik powiązany ze stronami** (notatka per URL/domena)
- Zadania/przypomnienia powiązane z treściami (docelowo)

### 3) Wbudowane AI
- Podsumowywanie artykułów (MVP), docelowo także dokumentów/PDF
- Wsparcie researchu (wyciąganie kluczowych punktów, checklist, decyzji)
- Docelowo: kontekstowe podpowiedzi (formularze, zakupy, research)

### 4) Społeczność i współpraca (docelowo)
- Prywatne grupy tematyczne
- Współdzielenie zakładek/notatek
- Mini „co-browsing” w czasie rzeczywistym

### 5) Cross‑platform (docelowo)
- Synchronizacja danych między urządzeniami
- Wersja mobilna (lekka, energooszczędna)

---

## ✅ MVP (2–3 miesiące) — zakres startowy (realistyczny jako rozszerzenie)
**Cel MVP:** wypuścić betę i zdobyć pierwszych 5–10 tys. użytkowników.

Wersja MVP (proponowany minimalny zakres):
1. Prywatność:
   - blokowanie trackerów (podstawowe)
   - czyszczenie linków śledzących (URL cleaner)
2. Produktywność:
   - tablice zakładek (kanban)
   - notatki do stron + szybkie dodawanie cytatów z zaznaczenia
3. AI:
   - podsumowanie artykułów HTML (przycisk „Podsumuj”)
   - zapis podsumowania do notatki / dodanie jako karta do tablicy

---

## 🧩 Instalacja (tryb deweloperski — Chrome/Edge)
> To jest instrukcja dla rozszerzenia. Nie wymaga forka Chromium.

1. Sklonuj repozytorium:
   ```bash
   git clone https://github.com/TWOJ_USER/LifeHub.git
   cd LifeHub
   ```

2. (Opcjonalnie) Zainstaluj zależności (jeśli projekt używa bundlera):
   ```bash
   npm install
   ```

3. Zbuduj wersję developerską (jeśli jest skrypt build):
   ```bash
   npm run build
   ```

4. Włącz rozszerzenie w przeglądarce:
   - Chrome/Edge: wejdź w `chrome://extensions`
   - włącz **Tryb dewelopera**
   - kliknij **Załaduj rozpakowane (Load unpacked)**
   - wskaż katalog z rozszerzeniem (np. `dist/` albo `extension/` – zależnie od projektu)

---

## 🛠 Roadmap

### Faza 1 — MVP (beta)
- Blokowanie trackerów + URL cleaner
- Tablice zakładek (kanban)
- Notatnik do stron + cytaty z zaznaczenia
- AI podsumowania artykułów

### Faza 2 — Premium i współpraca
- Prywatne grupy i współdzielenie
- Zaawansowane AI (podpowiedzi, rekomendacje)
- Subskrypcje premium + funkcje dla zespołów

### Faza 3 — Rozwój i integracje
- Integracje (np. Google Docs, Office 365)
- Marketplace rozszerzeń/modułów LifeHub
- AI dla automatyzacji researchu i pracy (bardziej „agentowe”)

---

## 🔒 Prywatność (założenia)
- Nie przechowuj w cache/logach żadnych sekretów.
- Docelowo: dane użytkownika (notatki/tablice/historia) szyfrowane lokalnie (E2EE).
- Projekt ma dążyć do modelu, w którym serwer (jeśli jest) przechowuje tylko zaszyfrowane dane („zero‑knowledge”).

---

## 🤖 AI i dane (założenia)
- MVP: AI może działać w trybie chmurowym (szybciej), ale:
  - użytkownik ma jasną informację, co jest wysyłane,
  - preferowane jest wysyłanie tylko wyekstrahowanego tekstu artykułu, a nie całej strony.
- Docelowo: tryb „privacy strict” oraz opcje lokalnego przetwarzania.

---

## 💳 Monetyzacja (kierunek)
- Subskrypcja premium: dodatkowe AI + grupy współpracy
- Opcjonalnie: model darmowy bez śledzenia (jeśli kiedykolwiek reklamy — tylko nieinwazyjne i bez tracking)

---

## 🤝 Współpraca
- Zgłaszaj pomysły i błędy w zakładce **Issues**
- PR-y mile widziane (opisuj problem, zakres i testy)

---

## 📄 Licencja
MIT (szczegóły w pliku `LICENSE`).

---

## 📬 Kontakt
- Issues: `https://github.com/TWOJ_USER/LifeHub/issues`
- (Tu dodaj e-mail/Discord, jeśli chcesz)

---
**LifeHub** – prywatność, produktywność i AI w jednym miejscu.