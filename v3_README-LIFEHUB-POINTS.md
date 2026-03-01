# LifeHub Points — system gamifikacji (README)

**LifeHub Points** to system nagród dla użytkowników LifeHub Kanban/AI:
- Punkty za akcje, unlocki, motywy, milestone toast/konfetti
- Synchronizacja przez chrome.storage.sync
- Historia, backup/import, panel nagród
- Modularność (łatwo rozwinąć o odznaki, wyzwania i ranking)

## Główne funkcje
- Punkty: za dodanie karty, AI-summary, notatkę (prosto skonfigurować)
- Licznik i panel nagród w dashboardzie
- Toast/confetti po milestone!
- Backup i import punktów z panelu ustawień

## Użycie (integracja)
- Importujesz `addPoints`, `getPoints` w dashboard.js i wywołujesz po każdej akcji użytkownika
- Modal nagród obsługujesz przez `redeemPoints` i zapis do `userSettings`
- Konfiguracja jest modularna, rozbudowa na React/Next otwarta

## Przykładowy flow
1. Użytkownik dodaje kartę: toast +5 💎, punkty rosną, unlock motywu/kolumny możliwy w panelu nagród
2. Po 5 kartach — toast z odznaką; po 50 AI-summary — toast AI master
3. Punkty, historia i unlocki synchronizują się automatycznie na Chrome

MIT © LifeHub Team