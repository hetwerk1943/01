## Przykład CSS dla nowoczesnych kart LifeHub

```css
.card {
    background-color: #1e1e1e;
    color: #f0f0f0;
    border-radius: 8px;
    padding: 12px;
    margin-bottom: 12px;
    box-shadow: 0 2px 6px rgba(0,0,0,0.3);
    transition: transform 0.1s, box-shadow 0.1s;
    border-left: 4px solid transparent;
    position: relative;
}
.card.dragging {
    opacity: 0.5;
    transform: scale(0.98);
    z-index: 100;
}
.tag {
    display: inline-block;
    font-size: 12px;
    background-color: #ff5722;
    color: white;
    padding: 2px 6px;
    border-radius: 4px;
    margin-right: 4px;
}
.priority-high { border-left: 4px solid #ff3b30; }
.priority-medium { border-left: 4px solid #ffd60a; }
.priority-low { border-left: 4px solid #32d74b; }

/* Dodatkowo: styl przycisków akcji (rekomendacja) */
.card-actions button {
    background: #384177;
    color: #fff;
    border: none;
    border-radius: 4px;
    margin-right: 7px; margin-bottom: 4px;
    padding: 5px 10px;
    font-size: 1.02em;
    cursor: pointer;
    transition: background 0.18s;
}
.card-actions button[data-action="delete"] { background: #963843; }
.card-actions button:hover { background: #6372d6; }
.card-actions button[data-action="delete"]:hover { background: #c94343; }
```

---

## Rekomendowany UX workflow LifeHub

1. **Dodaj stronę:**  
   – Kliknij „Dodaj stronę” w popupie.  
   – Strona **automatycznie pojawia się w „Do przeczytania”** jako nowa karta.

2. **Przenoszenie i research:**  
   – Przeciągnij kartę do kolumny „Research”.  
   – Kliknij **AI** na karcie.  
   – Otwiera się **modalne okno, AI generuje podsumowanie**.  
   – Możesz edytować i zapisać notatkę.

3. **Tagi i priorytety:**  
   – W oknie dodawania/edycji karty przypisujesz tagi (np. #UX, #AI, #Research) oraz priorytet (High/Medium/Low).  
   – Priorytet widoczny jako kolorowy pasek, tagi jako badge.

4. **Notatki i podsumowania:**  
   – Każda zmiana notatki lub podsumowania **trwale zapisuje się w `chrome.storage.sync`** (masz je na wszystkich urządzeniach Chrome).

5. **Filtracja:**  
   – Możesz filtrować karty po tagach lub priorytecie z panelu bocznego lub filtrów nad tablicą.

6. **Backup/Import (JSON):**  
   – W dowolnej chwili eksportujesz cały board jako JSON (do backupu/archiwum).  
   – Możesz też **importować** plik i natychmiast przenieść swoje dane między komputerami lub po resecie przeglądarki.

---

**Dzięki temu masz spójny, profesjonalny UX:**
- Szybkie dodawanie/procesowanie informacji
- Osadzony workflow z AI, tagami i priorytetami
- Mobilność i bezpieczeństwo przez storage.sync i eksport/import

---

**Podsumowanie**:  
Taki styl i workflow pozwala Ci konkurować z profesjonalnymi narzędziami typu Trello, KanbanFlow czy Notion — a do tego masz AI summary i pełną prywatność!