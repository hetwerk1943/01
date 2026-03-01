# 0. Sprawdzenie czy nie jesteśmy już w repo
test -d .git && echo "To już jest repo git (jest .git). Przerywam." && exit 1

# 1. Stwórz .gitignore przez heredoc (bez interpolacji)
cat > .gitignore <<'EOL'
node_modules/
dist/
*.log
*.env
.DS_Store
EOL

# 2. Inicjalizacja repo i ustawienie gałęzi main
git init
git checkout -b main 2>/dev/null || git branch -M main

# 3. Dodaj wszystkie pliki i pierwszy commit
git add .
git commit -m "Initial LifeHub PRO code"

# 4. Remote + push (bezpieczne nadpisanie starego origin)
git remote remove origin 2>/dev/null || true
git remote add origin https://github.com/hetwerk1943/LifeHub-PRO.git

# jeśli repo jest puste na GitHubie:
git push -u origin main

# jeśli repo ma już README/licencję, zamiast powyższego użyj:
# git pull origin main --rebase
# git push -u origin main