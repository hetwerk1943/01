---
name: Custom issue templLifeHub Taskate
about: '"Tworzy nowe zadanie z LifeHub Kanban lub AI podsumowaniem. Automatycznie
  nadaje etykiety, milestone i LifeHub Points."'
title: 'name: LifeHub Task description: "Tworzy nowe zadanie powiązane z LifeHub Kanban
  i AI. Automatycznie ustawia etykiety, tytuł i pola dodatkowe." title: "[LifeHub]
  Nowe zadanie: " assignees: [] labels: ["LifeHub", "To Do"] body:   - type: markdown     attributes:       value:
  |         ### Opis zadania         Wpisz szczegóły zadania związane z kartą LifeHub.          **Kontekst
  LifeHub:**           - Kolumna: `Do przeczytania / Research / Zrobione`           -
  Link do strony/karty: [wklej URL]           - Notatka/Podsumowanie AI: [wklej podsumowanie]    -
  type: input     id: priority     attributes:       label: "Priorytet"       description:
  "Wpisz priorytet zadania: Wysoki / Średni / Niski"       placeholder: "Średni"    -
  type: dropdown     id: category     attributes:       label: "Kategoria LifeHub"       description:
  "Wybierz kolumnę LifeHub"       options:         - Do przeczytania         - Research         -
  Zrobione    - type: textarea     id: additional_notes     attributes:       label:
  "Dodatkowe uwagi"       description: "Opcjonalne notatki, które trafią do Issue
  i LifeHub Points"       placeholder: "Tutaj możesz dodać dodatkowe informacje"'
labels: ''
assignees: ''

---

name: LifeHub Task
description: "Tworzy nowe zadanie z LifeHub Kanban lub AI podsumowaniem. Automatycznie nadaje etykiety, milestone i LifeHub Points."
title: "[LifeHub] Nowe zadanie: "
assignees: []
labels: ["LifeHub", "To Do"]
body:
  - type: markdown
    attributes:
      value: |
        ### Opis zadania
        Opisz tutaj, czego dotyczy karta z LifeHub.
        
        **Kontekst LifeHub:**  
        - Kolumna: `Do przeczytania / Research / Zrobione`  
        - Link do strony/karty: [wklej URL]  
        - Notatka/Podsumowanie AI: [wklej podsumowanie]

  - type: input
    id: priority
    attributes:
      label: "Priorytet"
      description: "Wpisz priorytet zadania: Wysoki / Średni / Niski"
      placeholder: "Średni"

  - type: dropdown
    id: category
    attributes:
      label: "Kategoria"
      description: "Wybierz kategorię LifeHub"
      options:
        - Do przeczytania
        - Research
        - Zrobione

  - type: textarea
    id: additional_notes
    attributes:
      label: "Dodatkowe uwagi"
      description: "Opcjonalne notatki, które trafią do Issue i LifeHub Points"
