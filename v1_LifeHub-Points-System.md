# 💎 LifeHub Points — kompletny plan gamifikacji

---

## 1️⃣ Założenia systemu

- **Cel:** zwiększyć zaangażowanie użytkownika przez nagrody i śledzenie postępów.  
- **Technika:**  
  - Punkty trzymane w `chrome.storage.sync` (działają cross-device).
  - Opcjonalny unikalny `userId` (przyszłościowo dla leaderboardów).
  - Przyznawanie punktów za typowe akcje:
    - Dodanie karty: **+5**
    - Generowanie AI-summary: **+10**
    - Edycja notatki: **+2**
- **Nagrody MVP:**
  - Nowe kolumny Kanbanu (premium)
  - Motywy kolorystyczne
  - Szybsze AI, dłuższe summary
  - Specjalne odznaki / levele

---

## 2️⃣ Struktura danych (przykład)

```json
{
  "points": 120,
  "achievements": ["first_card", "ai_master"],
  "userSettings": {
    "theme": "dark",
    "extraColumnsUnlocked": 1
  },
  "history": [
    {
      "action": "add_card",
      "cardId": "abc123",
      "points": 5,
      "timestamp": 1679990000
    },
    {
      "action": "ai_summary",
      "cardId": "def456",
      "points": 10,
      "timestamp": 1679990500
    }
  ]
}
```
- **`points`** — bieżący licznik punktów użytkownika
- **`achievements`** — lista milestone’ów i odznak
- **`userSettings`** — ustawienia (kolor, unlocki, premium features)
- **`history`** — log wszystkich akcji i zdobytych punktów (audyt, analizy, odznaki itd)

---

## 3️⃣ Flow UX / UI

**a) Dashboard:**
- Pasek z liczbą punktów (ikona 💎 + liczba) w górnym rogu dashboardu.
- Tooltip: np. „120 punktów, 2 odznaki”.

**b) Animacja zdobywania:**
- Toast np. „+5 💎” pojawia się po każdej akcji.
- Jeśli milestone → konfetti animacja + info o zdobytej odznace.

**c) Panel nagród:**
- Modal/lista nagród możliwych do odblokowania.
- Koszt nagrody w punktach, przycisk „Wymień punkty” → unlock, zmiana `userSettings`.

**d) Historia/statystyki:**
- Timeline/tabela — kiedy i za co zdobyto punkty.
- Filtrowanie po typie akcji (AI, add card, edit note).

---

## 4️⃣ Moduły JavaScript

```javascript name=src/points.js
export async function getPoints() {
  const data = await chrome.storage.sync.get(['points']);
  return data.points || 0;
}

export async function addPoints(amount, action, cardId) {
  const data = await chrome.storage.sync.get(['points', 'history']);
  const currentPoints = data.points || 0;
  const newPoints = currentPoints + amount;

  const history = data.history || [];
  history.push({
    action,
    cardId,
    points: amount,
    timestamp: Date.now()
  });

  await chrome.storage.sync.set({ points: newPoints, history });
  return newPoints;
}

export async function redeemPoints(cost, reward) {
  const data = await chrome.storage.sync.get(['points', 'userSettings']);
  if ((data.points || 0) < cost) return false;

  const newPoints = data.points - cost;
  const settings = data.userSettings || {};
  settings[reward] = true;

  await chrome.storage.sync.set({ points: newPoints, userSettings: settings });
  return true;
}
```

**Przykład integracji:**

```javascript
// dashboard.js
async function onAddCard(card) {
  await addPoints(5, 'add_card', card.id);
  showToast("+5 💎 LifeHub Points!");
}

async function onGenerateAISummary(card) {
  await addPoints(10, 'ai_summary', card.id);
  showToast("+10 💎 LifeHub Points!");
}
```

---

## 5️⃣ Rozbudowa / gamifikacja

- **Odznaki i levele:** za liczbę akcji (np. 5 kart → „Beginner”, 50 AI → „AI Master”)
- **Wyzwania tygodniowe/miesięczne:** na podstawie `history` wykrywanie celów
- **Visual upgrade:** animowany licznik, toasty, konfetti
- **Nagrody premium:** kolumny, motywy, AI-boost unlockowane przez punkty

---

## 6️⃣ MVP roadmap

| Tydzień | Element                             |
|---------|-------------------------------------|
| 1       | `points.js`, licznik w dashboardzie, toast po akcji         |
| 2       | Historia punktów, minimalny panel nagród                    |
| 3       | Odznaki, animacje, milestone’y                              |
| 4       | Pełny system nagród, AI premium, dodatkowe motywy/kolumny   |

---

## 7️⃣ Plusy takiego systemu

- Minimalny koszt techniczny — prosto integrowalne z obecnym LifeHub MVP
- Wysokie zaangażowanie, zachęca do korzystania z AI i reasearch
- Naturalny wstęp do PREMIUM/monetyzacji (paywall na niektóre unlocki)
- Blueprint do budowy pełnej ekonomii grywalizacji w LifeHub 😊

---
MIT © LifeHub Team