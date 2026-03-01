# 0) Wejdź do katalogu rozszerzenia
cd /ścieżka/do/lifehub-extension

# 1) .gitignore (OK)
cat > .gitignore <<'EOL'
node_modules/
dist/
*.log
*.env
.DS_Store
EOL

# 2) Jeśli to katalog już jest repo, zatrzymaj się (żeby nie mieszać)
if [ -d .git ]; then
  echo "UWAGA: .git już istnieje w tym katalogu. Przerwij i sprawdź, czy na pewno chcesz re-init." >&2
  exit 1
fi

# 3) Init + branch main
git init
git checkout -b main 2>/dev/null || git branch -M main

# 4) Commit
git add .
git commit -m "Initial LifeHub PRO code"

# 5) Remote: dodaj albo podmień jeśli już jest
git remote remove origin 2>/dev/null || true
git remote add origin https://github.com/hetwerk1943/LifeHub-PRO.git

# 6) Push
git push -u origin main