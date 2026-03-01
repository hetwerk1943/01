# 🗓 TYDZIEŃ 1 — CEL

**Na koniec tygodnia masz:**
- ✅ Repo na GitHub
- ✅ Działające rozszerzenie w przeglądarce
- ✅ Popup z przyciskiem
- ✅ Dashboard otwierany w nowej karcie

Jeśli to działa → projekt żyje.

---

## 🔥 DZIEŃ 1 — Repo + Struktura

**Krok 1: Utwórz repo**
- Nazwa: `lifehub-extension`
- Publiczne
- Licencja: MIT

**Krok 2: Struktura folderów**

```
lifehub-extension/
│
├── extension/
│   ├── manifest.json
│   ├── popup.html
│   ├── dashboard.html
│   ├── src/
│   │   ├── popup.js
│   │   └── dashboard.js
│   └── assets/
│
├── README.md
└── .gitignore
```

Nie komplikujemy.

---

## 🔥 DZIEŃ 2 — Minimalny manifest

Wklej do `extension/manifest.json`:

```json
{
  "manifest_version": 3,
  "name": "LifeHub",
  "version": "0.1",
  "description": "Inteligentna warstwa produktywności i prywatności.",
  "action": {
    "default_popup": "popup.html"
  },
  "permissions": ["storage", "activeTab", "scripting"],
  "background": {
    "service_worker": "src/background.js"
  }
}
```

Dodaj też plik: `extension/src/background.js`  
Zawartość:

```js
console.log("LifeHub background loaded");
```

(Tylko żeby extension się ładowało poprawnie.)

---

## 🔥 DZIEŃ 3 — Popup

**extension/popup.html**
```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8" />
  <title>LifeHub</title>
</head>
<body>
  <h2>LifeHub</h2>
  <button id="open-dashboard">Otwórz Dashboard</button>
  <script src="src/popup.js"></script>
</body>
</html>
```
