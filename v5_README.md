## 3. Instalacja i uruchomienie jako rozszerzenie

1. Skopiuj repozytorium lokalnie:

```bash
git clone https://github.com/hetwerk1943/LifeHub-PRO.git
cd LifeHub-PRO/lifehub-extension
```

2. Otwórz stronę rozszerzeń w Chrome:
   - `chrome://extensions/`

3. Włącz **Tryb deweloperski** (Developer mode).

4. Kliknij **Load unpacked** i wskaż folder:
   - `lifehub-extension/`

5. Ikona **LifeHub** pojawi się na pasku rozszerzeń (możesz ją przypiąć).

### Szybki start (MVP)

- **Dodaj notatkę** → zapis do URL aktywnej karty (active tab URL)
- **Podsumuj stronę** → placeholder AI
- **Dashboard kanban** → nowa karta (New Tab) pokazuje dashboard kanban

---

## 4. Struktura katalogu

```text
lifehub-extension/
├─ popup.html
├─ popup.js
├─ dashboard.html
├─ dashboard.js
├─ dashboard.css
├─ manifest.json
├─ modules/
│  ├─ notes.js
│  ├─ ai.js
│  └─ encoding.js
├─ content/
│  └─ content.js
├─ rules/
│  └─ tracking-basic.json
├─ package.json
└─ scripts/
   └─ placeholder.mjs
```