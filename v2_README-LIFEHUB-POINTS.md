# 💎 LifeHub Points — System gamifikacji dla LifeHub Kanban + AI

---

## 🚀 Opis i kluczowe zalety

LifeHub Points to przenośny, bezpieczny i szybki system nagród i punktów dla rozbudowanego Kanbanu (z AI-summary):
- Punkty, odznaki, historia w `chrome.storage.sync` (cross-device)
- Pasek punktów, toasty, panel nagród z redeem, animacje milestone
- Rozbudowalny schemat odchodzący w stronę wyzwań, leaderboardów i backupów
- Gotowy do integracji w React/Plain JS/Vite lub innych frameworkach

---

## 📂 Struktura projektu (przykład MVP)

```
lifehub-extension/
│
├─ manifest.json
├─ dashboard.html
├─ dashboard.js
├─ src/
│  ├─ points/
│  │  └─ points.js         # Logika, testy, historia, odznaki, backup
│  └─ app/
│     └─ app.js            # Dashboard + integracja
├─ styles/
│  ├─ dashboard.css
│  └─ popup.css
└─ README-LIFEHUB-POINTS.md
```

---

## 🗄️ Struktura danych (przykład storage.sync)

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

---

## ⚙️ Moduł punktów: src/points/points.js

```javascript name=src/points/points.js
// LifeHub Points — pełny moduł
export async function getPoints() {
  const d = await chrome.storage.sync.get(['points']);
  return d.points || 0;
}
export async function getAchievements() {
  const d = await chrome.storage.sync.get(['achievements']);
  return d.achievements || [];
}
export async function addPoints(amount, action, cardId = null) {
  const d = await chrome.storage.sync.get(['points','history','achievements']);
  const currentPoints = d.points || 0, history = d.history || [], achievements = d.achievements || [];
  const newPoints = currentPoints + amount;
  history.push({action,cardId,points:amount,timestamp:Date.now()});
  // Odznaka za 5 kart:
  if (action==="add_card") {
    const addCount = history.filter(ev=>ev.action==='add_card').length;
    if (addCount===5 && !achievements.includes("beginner")) {
      achievements.push("beginner");
      showToast("🎉 Odznaka: Beginner!");
      confetti();
    }
  }
  await chrome.storage.sync.set({points:newPoints,history,achievements});
  return newPoints;
}
export async function redeemPoints(cost, reward) {
  const d = await chrome.storage.sync.get(['points', 'userSettings']);
  if ((d.points??0) < cost) return false;
  const newPoints = d.points-cost;
  const settings = d.userSettings||{};
  settings[reward]=true;
  await chrome.storage.sync.set({points:newPoints,userSettings:settings});
  return true;
}
export async function getHistory() {
  const d = await chrome.storage.sync.get(['history']);
  return d.history || [];
}
export async function getUserSettings() {
  const d = await chrome.storage.sync.get(['userSettings']);
  return d.userSettings||{};
}
export async function setUserSetting(key, val) {
  const d = await chrome.storage.sync.get(['userSettings']);
  const s = d.userSettings||{};
  s[key]=val;
  await chrome.storage.sync.set({userSettings:s});
}
// --- Dla testów/rozwoju: backup/export/import ---
export async function exportPointsState() {
  const d = await chrome.storage.sync.get(['points','achievements','userSettings','history']);
  return JSON.stringify(d, null, 2);
}
export async function importPointsState(jsonStr) {
  let data; try { data=JSON.parse(jsonStr); } catch { return false; }
  if (!('points' in data && 'history' in data)) return false;
  await chrome.storage.sync.set(data); return true;
}
// --- Mini-konfetti (HTML/CSS czysty) ---
export function confetti() {
  for(let i=0;i<18;i++){
    const d=document.createElement('div');
    d.className="lhcft";
    d.style.top=(25+Math.random()*25)+"%";
    d.style.left=(12+Math.random()*75)+"%";
    d.style.background=`hsl(${~~(Math.random()*360)},88%,62%)`;
    d.style.animation=`lhcft-f 1.6s cubic-bezier(.4,.98,.58,1.02)`;
    document.body.appendChild(d);
    setTimeout(()=>d.remove(),1400);
  }
}
// toast (w razie użycia standalone)
export function showToast(msg) {
  let t=document.getElementById("lifehub-toast");
  if(!t){t=document.createElement("div");
    t.id="lifehub-toast";t.className="toast";
    document.body.appendChild(t);}
  t.textContent=msg;t.classList.add("active");
  setTimeout(()=>t.classList.remove("active"),1800);
}
```

---

## 🖼️ Integracja w dashboardzie

```html name=dashboard.html
<!-- Pasek punktów + przycisk nagród -->
<div id="points-bar" class="points-bar" title="Twoje LifeHub Points 💎">
  💎 <span id="points-count">0</span> punktów
</div>
<button id="rewards-btn">Nagrody</button>
```
```javascript name=dashboard.js
import { getPoints, addPoints, redeemPoints } from './src/points/points.js';
async function updatePointsUI() {
  document.getElementById('points-count').textContent = await getPoints();
}
async function onAddCard(card) {
  await addPoints(5,'add_card',card.id); showToast("+5 💎"); updatePointsUI();
}
async function onGenerateAISummary(card) {
  await addPoints(10,'ai_summary',card.id); showToast("+10 💎"); updatePointsUI();
}
updatePointsUI();
```

---

## 🎁 Panel nagród + modal

```html name=dashboard.html
<div id="rewards-modal" class="modal hidden">
  <h2>Wymień punkty na nagrody 🎁</h2>
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
```javascript name=dashboard.js
import { redeemPoints } from './src/points/points.js';
document.getElementById('rewards-btn').onclick=()=>{
  document.getElementById('rewards-modal').classList.remove('hidden');
};
document.getElementById('close-rewards').onclick=()=>{
  document.getElementById('rewards-modal').classList.add('hidden');
};
document.querySelectorAll('.redeem-btn').forEach(b=>{
  b.onclick=async()=>{
    const c=parseInt(b.dataset.cost),r=b.dataset.reward;
    if(await redeemPoints(c,r))
      showToast(`🎉 Odblokowano: ${r}`);
    else showToast(`❌ Za mało punktów!`);
    updatePointsUI();
  }
});
```

---

## ✨ CSS (minimally stylized)

```css name=styles/dashboard.css
.points-bar {
  position: absolute; top: 15px; right: 36px;
  background: #23293a; color: #ffd60a; padding: 7px 18px;
  font-size: 1.10em; border-radius: 15px;
  box-shadow: 0 2px 16px #0003; font-weight: 700;
  z-index: 102; cursor: pointer; transition: box-shadow 0.12s;
}
.points-bar:hover { box-shadow: 0 3px 28px #0007; }
.toast {
  position: fixed; right: 19px; bottom: 34px; background: rgba(33,33,55,.93);
  color: #ffe46d; padding: 13px 32px; border-radius: 12px; font-size: 1.12em; z-index: 3332;
  opacity: 0; pointer-events: none; transition: opacity .2s;
}
.toast.active { opacity: 1; pointer-events: auto; }
.modal { 
  position:fixed;z-index:1112;top:0;left:0;width:100vw;height:100vh;
  background:rgba(12,13,18,.82);display:flex;align-items:center;justify-content:center;
}
.modal > * { background:#192048;border-radius:16px;padding:38px 60px; }
.modal.hidden { display: none; }
.lhcft { position:fixed;width:13px;height:13px; border-radius:99px;
  z-index:999; pointer-events:none;}
@keyframes lhcft-f { to { transform: translateY(82vh) scale(.9); opacity:0;}}
```

---

## 🕹️ Backup, historia, testy

```javascript name=test/points.test.js
import * as points from '../src/points/points.js';

async function testAddAndRedeem() {
  await points.addPoints(10,'test','card123');
  let pts = await points.getPoints();
  if (pts<10) throw "No points after add";
  await points.redeemPoints(5,'unlocked_theme');
  pts = await points.getPoints();
  if (pts!==5) throw "Redeem error";
  const hist = await points.getHistory();
  if (!hist.find(x=>x.action==='test')) throw "History missing!";
  console.log('OK!');
}
testAddAndRedeem();
```
---
## 🏆 Leaderboard (prosty local/prototyp)

```javascript name=extras/leaderboard.js
// Leaderboard: local, userId z chrome.storage.sync (global: api)
export async function getLeaderboard() {
  // prototypowo: wyciąga top userId z localStorage lub fake API
  // w wersji produkcyjnej podłącz własny API endpoint
}
```

---

## 📋 Panel historii i backup/import

```javascript name=dashboard.js
import { getHistory, exportPointsState, importPointsState } from './src/points/points.js';

async function showHistoryPanel() {
  const hist = await getHistory();
  // Render tabela / timeline
}
async function backupPoints() {
  const blob = new Blob([await exportPointsState()], {type:'application/json'});
  const a = document.createElement("a"); a.href=URL.createObjectURL(blob);
  a.download="lifehub-points-backup.json";a.click();
}
async function importPoints(evt) {
  const file = evt.target.files[0]; if (!file) return;
  let json = await file.text();
  if(await importPointsState(json)) showToast("Backup przywrócony!");
  else showToast("Błąd pliku backup.");
}
```

---

## 🪄 Porady pod dalszą rozbudowę

- Komponenty można wyizolować (np. conta LifeHubPointsContext w React)
- Testy jednostkowe: polecam Vitest albo czysty Node z Mocks (wszystkie metody asynchroniczne)
- Pełny backup/restore (włącznie z userSettings, achievementami)
- Panel historii/progress-bar/motyw leaderboard/newsfeed → gotowy blueprint
- Multi-user & team: globalny userId w storage, komunikacja backend API, podpięcie sharingu boardu do punkto-leadera

---

MIT © LifeHub Team