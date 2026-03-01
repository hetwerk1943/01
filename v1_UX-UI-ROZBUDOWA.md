# LifeHub Kanban — UX/UI rozbudowa i usprawnienia

---

## 1️⃣ Ciemny motyw + responsywność

**CSS do dashboard.html**  
```css
body {
  font-family: 'Segoe UI', sans-serif;
  background: #121212;
  color: #eee;
  margin: 0; padding: 0;
}

#board {
  display: flex;
  gap: 16px;
  padding: 20px 14px 32px 14px;
  overflow-x: auto;
}

.column {
  min-width: 280px;
  background: #1e1e1e;
  flex: 1;
  padding: 13px 13px 20px 13px;
  border-radius: 12px;
  box-shadow: 0 3px 22px #0004;
  transition: background 0.2s;
  margin-bottom: 22px;
  position: relative;
}
.column.drag-over { background: rgba(255,255,255,0.05); }
.column h3 { text-align: center; color: #ffd60a; margin: 0 0 9px 0; }

@media (max-width: 900px) {
  #board { gap: 8px; }
  .column { min-width: 225px; padding: 9px; }
}
@media (max-width: 670px) {
  #board { padding: 6px; }
  .column { min-width: 165px; padding: 4px; font-size: 0.95em; }
}
@media (max-width: 560px) {
  #board { padding: 2px; }
  .column { min-width: 118px; font-size: 0.89em; }
}

.card {
  background: #23242b;
  margin: 7px 0;
  padding: 12px 10px 11px 10px;
  border-radius: 9px;
  border: 2.5px solid transparent;
  box-shadow: 0 2.5px 12px #0006;
  transition: box-shadow 0.12s, border 0.18s, opacity 0.1s, transform 0.1s;
  cursor: grab;
  position: relative;
  z-index: 1;
}

/* Priorytety na border */
.prio-high    { border-left: 6px solid #ff3b30 !important; }
.prio-medium  { border-left: 6px solid #ffd60a !important; }
.prio-low     { border-left: 6px solid #32d74b !important; }

.card:hover { box-shadow: 0 5px 22px #000c; }

/* Efekt drag */
.card.dragging {
  opacity: 0.5;
  transform: scale(0.98);
  z-index: 99;
  box-shadow: 0 7px 26px #000b;
  pointer-events: none;
}

/* Badge tagów */
.card-badges {
  margin-bottom: 4px;
}
.tag {
  background-color: #ff5722;
  color: #fff;
  padding: 2px 7px;
  border-radius: 4px;
  margin-right: 4px;
  font-size: 0.86em;
  display: inline-block;
}
.prio-label {
  display: inline-block;
  margin-left: 3px;
  font-size: 0.88em;
  font-weight: bold;
  padding: 1px 7px;
  border-radius: 6px;
  color: #fff;
  background: #232248;
}

/* Placeholder na drop */
.drop-placeholder {
  margin: 7px 0;
  background: repeating-linear-gradient(90deg, #343c60 0px, #232248 10px, #4a4e77 40px);
  border: 2px dashed #70f;
  border-radius: 8px;
  min-height: 46px;
}

/* Przycisk pod tytułem */
.card-title {
  font-weight: bold;
  font-size: 1.14em;
  color: #ffd60a;
  cursor: pointer;
  margin-bottom: 2px;
  display: block;
}
.card-url {
  display: block;
  margin: 5px 0 7px 0;
  color: #6dc6e7;
  text-decoration: underline;
  font-size: 0.98em;
  cursor: pointer;
}
.card-url:hover { color: #54C7Fa; }

.card-notes {
  margin-top: 7px;
  font-size: 0.97em;
  word-break: break-word;
  color: #d4e1f7;
}

/* Akcje */
.card-actions button {
  font-size: 1.03em;
  color: #fff;
  background: #384177;
  border: none;
  border-radius: 4px;
  margin-right: 7px; margin-bottom: 3px;
  cursor: pointer;
  padding: 5px 9px;
  transition: background 0.16s;
}
.card-actions button[data-action="delete"] { background: #963843; }
.card-actions button[data-action="edit-note"]::before { content: "📝 "; }
.card-actions button[data-action="ai-summary"]::before { content: "🤖 "; }
.card-actions button[data-action="delete"]::before { content: "❌ "; }
.card-actions button:hover { background: #6372d6; }
.card-actions button[data-action="delete"]:hover { background: #c94343; }

/* Toast powiadomienia */
.toast {
  position: fixed;
  right: 18px;
  bottom: 21px;
  background: rgba(24, 28, 44, 0.91);
  color: #fff;
  font-size: 1.17em;
  padding: 13px 25px;
  border-radius: 11px;
  box-shadow: 0 8px 36px #000f;
  z-index: 3005;
  opacity: 0;
  pointer-events: none;
  transition: opacity .18s;
}
.toast.active { opacity: 1; pointer-events: auto; }
```

---

## 2️⃣ Karty – status, URL, badge/tagi/priorytet i styl akcji

**W renderowaniu karty (app.js):**
```javascript
cardEl.innerHTML = `
  <div class="card-badges">
    ${card.tags ? card.tags.map(tag=>`<span class="tag">#${escapeHTML(tag)}</span>`).join('') : ""}
    <span class="prio-label prio-${card.priority?.toLowerCase()||'medium'}">${card.priority||'Medium'}</span>
  </div>
  <span class="card-title" tabindex="0">${escapeHTML(card.title)}</span>
  <a class="card-url" target="_blank">${escapeHTML(card.url||"")}</a>
  <div class="card-actions">
    <button data-action="edit-note"></button>
    <button data-action="ai-summary"></button>
    <button data-action="delete"></button>
  </div>
  <div class="card-notes" id="notes-${card.id}">${card.notes ? card.notes.replace(/\n/g,"<br>") : ""}</div>
`
// after rendering...
cardEl.querySelector('.card-url').onclick = () => chrome.tabs.create({url: card.url});
cardEl.classList.add(`prio-${card.priority?.toLowerCase()||'medium'}`);
```

---

## 3️⃣ Modale

**AI-summary modal:**
- Spinner, textarea, Save/Cancel (zamknięcie modal na click, ESC, czy X).
**Edit note modal:**
- Identyczny flow, inne pole.

W kodzie:
```javascript
// ...open modal...
function openModal({ initialText, onSave }) {
  summaryText.value = initialText || "";
  modal.classList.remove("hidden");
  saveBtn.onclick = () => {
    onSave(summaryText.value);
    closeModal();
    toast("Notatka zapisana ✅");
  };
}
function closeModal() { modal.classList.add("hidden"); }
closeBtn.onclick = closeModal;
// esc:
window.addEventListener("keydown", e => { if (e.key === "Escape") closeModal(); });
```

---

## 4️⃣ Toast / powiadomienia

**Funkcja dołącz do app.js:**
```javascript
function toast(msg) {
  let t = document.getElementById("lifehub-toast");
  if (!t) {
    t = document.createElement("div"); t.id = "lifehub-toast";
    t.className = "toast"; document.body.appendChild(t);
  }
  t.textContent = msg;
  t.classList.add("active");
  setTimeout(() => t.classList.remove("active"), 1600); // fade-out
}
```
Używaj np. po imporcie, dodaniu:  
`toast("Strona dodana do tablicy ✅");`

---

## 5️⃣ Usprawnienia drag & drop

- Placeholder klasy `.drop-placeholder` do renderowania
- `pointer-events: none;` na `.card.dragging`
- Podświetlenie kolumny:
  ```javascript
  colEl.addEventListener("dragover", e => {
    colEl.classList.add("drag-over");
    // ... rest
  });
  colEl.addEventListener("dragleave", e => { colEl.classList.remove("drag-over"); });
  colEl.addEventListener("drop", e => { colEl.classList.remove("drag-over"); /* ... */ });
  ```
  
---

## 6️⃣ Panel boczny / filtracja

**HTML – np. lewy panel:**
```html
<div id="filters">
  <select id="filt-prio"><option value="">Priorytet</option><option>High</option><option>Medium</option><option>Low</option></select>
  <input id="filt-tags" type="text" placeholder="tag, tag2">
  <select id="filt-col"><option value="">Kolumna</option> ... </select>
  <button id="clearFilters">Wyczyść</button>
</div>
```
**JS – filtruj przed renderem:**
```javascript
function filterCards(cards) {
  // filtrowanie po tags, prio, kolumna
  // zwraca cards które spełniają warunki z #filters
}
```

---

Chcesz pełen *dashboard.html* i *app.js* z tym podziałem (pod UX demo/możesz dalej rozwijać)?  
Daj znać — wygeneruję je w całości, na gotowo!