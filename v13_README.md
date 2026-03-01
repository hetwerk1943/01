---

## 🧱 Fundament rozwoju – ETAP 1 (Dzień 1–3)

Zanim powstanie cokolwiek w kodzie musimy odpowiedzieć jasno:

> ❓ **Czy LifeHub to…**
> - (A) rozszerzenie (extension-first)  
> - (B) pełna przeglądarka (Chromium fork)  
> - (C) narzędzie AI-produktywności z warstwą prywatności

**Decyzja:**  
👉 Startujemy jako **extension na Chromium/Browzarach wspierających MV3**.

**Dlaczego?**
- 100x szybciej dostarczysz MVP
- 0 kosztów własnego silnika
- od razu dostęp do bazy użytkowników (Chrome/Edge)
- Szybkie testy i pivot, bez zapętlenia się w architekturze

**Pełna przeglądarka to etap, kiedy projekt ma już pierwszych użytkowników i trakcję!**

---

## ✨ ETAP 2 — DEFINICJA MVP (Nie wszystko naraz!)

Największy wróg: za duży MVP.  
**LifeHub 0.1 = tylko 3 rzeczy:**

1️⃣ **Blokowanie trackerów**  
   Prosty poziom, jedna reguła — “działa” to wszystko  
2️⃣ **Tablica zakładek (kanban)**  
   3 kolumny: `Do przeczytania` / `Research` / `Zrobione`  
3️⃣ **AI „Podsumuj tę stronę”**  
   Przycisk → wyciąga tekst → wysyła do modelu (np. OpenAI/LLM) → zapisuje jako notatkę

**Brak w MVP:**
- grupy, społeczności
- reputacja
- TOR
- wersja mobilna
- marketplace
- zespoły, integracje  
*Te rzeczy planuj dopiero po sprawdzeniu rynku i pierwszych użytkownikach.*

---

## 🧑‍💻 ETAP 3 — Twoja pierwsza decyzja (ważna!)

**Jaka jest dostępność i poziom:**
- JavaScript
- React
- Node
- Solo founder, zespół?

> Od tego zależy architektura MVP!  
> (Przykład: nie ma React? Piszesz vanilla albo Preact; nie ma Node? build lokalny.)

---

## 🎯 ETAP 4 — Mentalna zmiana (mindshift founderów)

LifeHub **NIE jest „przeglądarką”**.  
**LifeHub to OS dla wiedzy.**

> Nie próbuj wygrać z Chrome jako “przeglądarka” — przegrasz.
> Wygraj, budując AI-produkt do produktywności z prywatnością — wygrasz niszę.

---

## 📆 ETAP 5 — Plan na pierwsze 30 dni

**Tydzień 1:**  
- Repozytorium, CI
- Szkielet extension
- Popup działa, dashboard działa

**Tydzień 2:**  
- Tablice kanban (3 kolumny)
- Zapisywanie w storage
- Minimum UX, ale czytelność

**Tydzień 3:**  
- Integracja AI (LLM, OpenAI lub własna backend)
- Ekstrakcja tekstu ze strony
- Zapisywanie podsumowań

**Tydzień 4:**  
- Prosty landing page
- Waitlista (newsletter, early-access)
- Pierwsi testerzy

---

**Buduj "małe działające kawałki", nie całość na raz.**  
**First user, NOT first PRIZE!**
