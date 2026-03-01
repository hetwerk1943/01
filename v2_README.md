# 🌐 LifeHub — Inteligentna, Prywatna, Produktywna „Przeglądarka” (Extension‑First)

**LifeHub** to projekt „przeglądarki” budowanej **najpierw jako rozszerzenie do Chromium (Chrome/Edge)**, które łączy w jednym miejscu:
- **Prywatność absolutną** (blokowanie trackerów, czyszczenie linków, docelowo TOR i E2EE),
- **Produktywność** (tablice zakładek kanban, notatki do stron, zadania i przypomnienia),
- **AI** (podsumowania, wsparcie researchu i pracy),
- **Współpracę** (grupy, współdzielenie, co-browsing),
- **Cross‑platform** (sync desktop ↔ mobile).

> Cel: narzędzie, które „łączy najlepsze elementy” przeglądarek typu Chrome/Brave/Firefox/Edge/Safari, ale dodaje brakujące warstwy: **produktywność + AI + współpraca**.

---

## ✅ MVP (2–3 miesiące) — realistyczny start jako rozszerzenie
**MVP = efekt „wow” + wykonalność**:

### Prywatność (MVP)
- Blokowanie trackerów (podstawowe listy/reguły)
- Czyszczenie linków śledzących (np. `utm_*`, `fbclid`, `gclid`)

### Produktywność (MVP)
- **Tablice zakładek (kanban)**: kolumny + karty (linki)
- **Notatki do stron**: notatka per URL / domena
- „Zaznacz tekst na stronie → dodaj jako cytat do notatki”

### AI (MVP)
- Podsumowanie artykułu (HTML) → zapis do notatki / karta na tablicy

### Sync (MVP-lite)
- Scaffolding (przygotowane miejsce w kodzie)
- Realny sync w kolejnych iteracjach (bezpieczny, E2EE)

---

## 🚀 Funkcje (pełna wizja)
### 1) Prywatność absolutna
- Pełne szyfrowanie danych użytkownika po stronie klienta (docelowo: historia/hasła/notatki/tablice)
- Blokowanie trackerów, reklam i ukrytych linków śledzących
- TOR (docelowo)

### 2) Produktywność i zarządzanie informacją
- Tablice zakładek kanban + oznaczenia + przypomnienia
- Notatnik powiązany z każdą stroną
- Zadania i przypomnienia powiązane z treściami

### 3) Wbudowane AI
- Podsumowania artykułów/dokumentów/PDF w czasie rzeczywistym
- Podpowiedzi kontekstowe (formularze, zakupy, research)
- Inteligentne rekomendacje treści

### 4) Społeczność i współpraca
- Prywatne grupy, dzielenie się treściami
- Co‑browsing realtime
- System reputacji/punktów

### 5) Cross‑platform
- Sync desktop ↔ mobile
- Lekka wersja mobilna

---

## 🧩 Instalacja / uruchomienie (developer mode)
### Wymagania
- Node.js (zalecane 18+)
- Chrome lub Edge

### Kroki
1. Instalacja zależności:
   ```bash
   npm install
   ```

2. Build:
   ```bash
   npm run build
   ```

3. Załaduj rozszerzenie:
   - Chrome/Edge: `chrome://extensions`
   - włącz **Tryb dewelopera**
   - **Załaduj rozpakowane (Load unpacked)**
   - wskaż folder: `extension/`

> Na start build jest „placeholder”. Rozszerzenie działa bez bundlera — można je rozwijać od razu.

---

## 🛣 Roadmap
Zobacz: `docs/ROADMAP.md`

---

## 🔒 Prywatność i AI
- Prywatność: `docs/PRIVACY.md`
- AI i dane: `docs/AI.md`

---

## 📄 Licencja
MIT — plik `LICENSE` (dodaj w repo).

---

## 🤝 Współpraca
Dodawaj pomysły i błędy w GitHub Issues.