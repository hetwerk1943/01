# 💎 LifeHub Points — system gamifikacji dla LifeHub Kanban + AI

---

## 🚀 Opis  
**LifeHub Points** to w pełni funkcjonalny system punktów i nagród:
- Punkty za każdą akcję (dodanie karty, AI-summary, edycja notatki…)
- Licznik w dashboardzie + toasty i animacje
- Historia aktywności, odznaki/milestones
- Panel nagród (premium/motywy/odblokowania)
- Prosta rozbudowa o wyzwania, leaderboard czy weekly goals

Integracja z LifeHub Kanban (dashboard, popup, backend) — **punkty synchronizują się między urządzeniami**.

---

## 📂 Struktura projektu

```
lifehub-extension/
│
├─ manifest.json
├─ dashboard.html
├─ dashboard.js
├─ src/
│  ├─ points/
│  │  └─ points.js         # Logika punktów, nagród, historia
│  └─ app/
│     └─ app.js            # Integracja: dashboard AI + Kanban
├─ styles/
│  ├─ dashboard.css
│  └─ popup.css
└─ README-LIFEHUB-POINTS.md
```

---

## 🗄️ Struktura danych (storage.sync)

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
- **points** — bieżący licznik
- **achievements** — zdobyte odznaki
- **userSettings** — odblokowane nagrody
- **history** — log wszystkich aktywności

---

## ⚙️ Funkcje (moduł `points.js`)

```javascript name=src/points/points.js
/**
 * Pobierz aktualny stan punktów
 */
export async function getPoints() {
  const data = await chrome.storage.sync.get(['points']);
  return data.points || 0;
}

/**
 * Dodaj punkty za akcję (loguje w historii)
 * @param {number} amount Liczba punktów
 * @param {string} action Np. 'add_card', 'ai_summary'
 * @param {string} cardId Identyfikator karty (opcjonalnie)
 * @returns {number} Nowy stan punktów
 */
export async function addPoints(amount, action, cardId = null) {
  const data = await chrome.storage.sync.get(['points', 'history', 'achievements']);
  const currentPoints = data.points || 0;
  const history = data.history || [];
  const achievements = data.achievements || [];

  const newPoints = currentPoints + amount;
  history.push({
    action,
    cardId,
    points: amount,
    timestamp: Date.now()
  });

  // Przykład: milestone - dodano 5 kart = odznaka "Beginner"
  if (action === "add_card") {
    const addCount = history.filter(ev => ev.action === "add_card").length;
    if (addCount === 5 && !achievements.includes("beginner")) {
      achievements.push("beginner");
      // Możesz tutaj dodać toast/animację!
    }
  }
  await chrome.storage.sync.set({ points: newPoints, history, achievements });
  return newPoints;
}

/**
 * Wymiana punktów na nagrodę (np. motyw, kolumna, premium)
 * @param {number} cost koszt punktów
 * @param {string} reward nazwa nagrody (np. 'theme_light')
 * @returns {boolean} true jeśli sukces
 */
export async function redeemPoints(cost, reward) {
  const data = await chrome.storage.sync.get(['points', 'userSettings']);
  if ((data.points ?? 0) < cost) return false;
  const newPoints = data.points - cost;
  const settings = data.userSettings || {};
  settings[reward] = true;
  await chrome.storage.sync.set({ points: newPoints, userSettings: settings });
  return true;
}

/**
 * Pobierz całą historię logów
 */
export async function getHistory() {
  const data = await chrome.storage.sync.get(['history']);
  return data.history || [];
}

/**
 * Pobierz/zmień ustawienia użytkownika (theme, unlocki)
 */
export async function getUserSettings() {
  const data = await chrome.storage.sync.get(['userSettings']);
  return data.userSettings || {};
}
export async function setUserSetting(key, value) {
  const data = await chrome.storage.sync.get(['userSettings']);
  const settings = data.userSettings || {};
  settings[key] = value;
  await chrome.storage.sync.set({ userSettings: settings });
}
```

---

## 🖼️ Integracja w dashboardzie LifeHub

```html name=dashboard.html (fragment)
/* w sekcji header/dashboard */
<div id="points-bar" class="points-bar" title="Twoje LifeHub Points">
  💎 <span id="points-count">0</span> punktów
</div>
<button id="rewards-btn">Nagrody</button>
```

```javascript name=dashboard.js (fragment)
import { getPoints, addPoints, redeemPoints } from './src/points/points.js';

async function updatePointsUI() {
  const points = await getPoints();
  document.getElementById('points-count').textContent = points;
}

async function onAddCard(card) {
  await addPoints(5, 'add_card', card.id);
  showToast("+5 💎 LifeHub Points!");
  updatePointsUI();
}

async function onGenerateAISummary(card) {
  await addPoints(10, 'ai_summary', card.id);
  showToast("+10 💎 LifeHub Points!");
  updatePointsUI();
}
```

---

## 🎁 Panel nagród (przykład MVP)

```html name=dashboard.html (fragment)
<div id="rewards-modal" class="modal hidden">
  <h2>Wymień punkty na nagrody</h2>
  <ul>
    <li>
      <button class="redeem-btn" data-cost="50" data-reward="extraColumnsUnlocked">
        Dodatkowa kolumna — 50 💎
      </button>
    </li>
    <li>
      <button class="redeem-btn" data-cost="30" data-reward="theme_light">
        Motyw jasny — 30 💎
      </button>
    </li>
  </ul>
  <button id="close-rewards">Zamknij</button>
</div>
```

```javascript name=dashboard.js (fragment)
import { redeemPoints } from './src/points/points.js';

document.getElementById('rewards-btn').onclick = () => {
  document.getElementById('rewards-modal').classList.remove('hidden');
};
document.getElementById('close-rewards').onclick = () => {
  document.getElementById('rewards-modal').classList.add('hidden');
};
document.querySelectorAll('.redeem-btn').forEach(btn => {
  btn.onclick = async () => {
    const cost = parseInt(btn.dataset.cost);
    const reward = btn.dataset.reward;
    const success = await redeemPoints(cost, reward);
    if (success) showToast(`🎉 Odblokowano: ${reward}`);
    else showToast(`❌ Za mało punktów!`);
    updatePointsUI();
  }
});
```

---

## ✨ Minimalny CSS

```css name=styles/dashboard.css
.points-bar {
  position: absolute;
  top: 15px; right: 36px;
  background: #23293a;
  color: #ffd60a;
  padding: 7px 18px;
  font-size: 1.10em;
  border-radius: 15px;
  box-shadow: 0 2px 16px #0003;
  font-weight: 700;
  z-index: 102;
  cursor: pointer;
  transition: box-shadow 0.12s;
}
.points-bar:hover { box-shadow: 0 3px 28px #0007; }
.toast {
  position: fixed; right: 19px; bottom: 34px;
  background: rgba(33,33,55,.93);
  color: #ffe46d; padding: 13px 32px;
  border-radius: 12px; font-size: 1.12em; z-index: 3332;
  opacity: 0; pointer-events: none; transition: opacity .2s;
}
.toast.active { opacity: 1; pointer-events: auto; }
.modal { /* ...style modal... */ }
```

---

## 🏆 Rozbudowa/gamifikacja (propozycje)

- **Odznaki i levele:** milestone’y (np. 10 kart → "Beginner", 25 AI summary → "AI PRO", dashboard pokazuje odznaki)
- **Wyzwania (daily/weekly):** licz na podstawie history
- **Animowany licznik, konfetti, level-bar**
- **Leaderboard (globalne userId, anonimizowane)**
- **Statystyki: ranking akcji, najlepiej punktujące tygodnie**
- **Backup do JSON, import/eksport własnego progresu**


---

## 🛤️ Roadmapa wdrożenia

| Tydzień | Element                                                |
|---------|--------------------------------------------------------|
| 1       | Podstawowy licznik, toast po akcji, punkty za karty    |
| 2       | Panel nagród, redeem punkty, unlock premium features   |
| 3       | Historia, odznaki, milestone toast/animacja            |
| 4       | Backup, wyzwania, statystyki, panel powiadomień        |
| 5+      | Leaderboard, multi-user, global analytics              |

---

MIT © LifeHub Team