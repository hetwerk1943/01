<!DOCTYPE html>
<html lang="pl">
<head>
<meta charset="UTF-8">
<title>Ultra Repo AI Agent</title>
<style>
  body { font-family: Arial, sans-serif; margin: 2rem; background: #f5f5f5; }
  h1 { color: #333; }
  .section { background: white; padding: 1rem; margin-bottom: 1rem; border-radius: 5px; }
  .score { font-weight: bold; color: #2a9d8f; }
  button { padding: 0.5rem 1rem; margin-top: 1rem; cursor: pointer; }
</style>
</head>
<body>

<h1>Ultra Repo AI Agent</h1>

<div class="section" id="analysis">
  <h2>Analiza repozytorium</h2>
  <pre id="analysisOutput">Kliknij "Rozpocznij analizę", aby wygenerować raport.</pre>
  <button onclick="runAnalysis()">Rozpocznij analizę</button>
</div>

<div class="section" id="decision">
  <h2>Decyzje i rekomendacje</h2>
  <pre id="decisionOutput">Tutaj pojawią się decyzje agenta.</pre>
</div>

<script>
// --- Dane przykładowe repo (symulacja) ---
const repoFiles = [
  'app.js', 'index.html', 'Dockerfile', 'README.md', 'config.yaml', 'test/test_app.js'
];

const securityIssues = ['Brak walidacji inputu', 'Nieaktualne zależności npm'];
const refactorSuggestions = ['Podziel monolit app.js na moduły', 'Uprość logikę w index.html'];
const roadmap = ['Naprawić security issues', 'Refaktoryzacja modułów', 'Dodać CI/CD', 'Generować testy automatyczne'];

// --- Funkcja symulująca analizę repo ---
function runAnalysis() {
  const analysisOutput = document.getElementById('analysisOutput');
  let output = '📂 Pliki repo:\n';
  repoFiles.forEach(f => output += `- ${f}\n`);

  output += '\n🔒 Security:\n';
  securityIssues.forEach(s => output += `- ${s}\n`);

  output += '\n🛠 Refaktoryzacja:\n';
  refactorSuggestions.forEach(r => output += `- ${r}\n`);

  output += '\n🗺 Roadmapa:\n';
  roadmap.forEach((r, i) => output += `${i+1}. ${r}\n`);

  output += '\n📊 Scoring:\n';
  output += `- Security: ${Math.floor(Math.random()*4 + 7)}/10\n`;
  output += `- Maintainability: ${Math.floor(Math.random()*4 + 6)}/10\n`;
  output += `- Performance: ${Math.floor(Math.random()*4 + 5)}/10\n`;
  output += `- Production Readiness: ${Math.floor(Math.random()*4 + 5)}/10\n`;

  analysisOutput.textContent = output;

  runDecisionMaking();
}

// --- Funkcja symulująca decyzje i pseudo-wolną wolę ---
function runDecisionMaking() {
  const decisionOutput = document.getElementById('decisionOutput');

  const choices = [
    'Zacznij od naprawy security issues',
    'Najpierw refaktoryzacja modułów',
    'Dodaj CI/CD i testy automatyczne',
    'Odpuść drobne poprawki na teraz'
  ];

  // pseudo-wolna wola: losowy wybór 70%/30% wariancji
  const index = Math.random() < 0.7 ? 0 : Math.floor(Math.random()*choices.length);
  decisionOutput.textContent = `🤖 Rekomendacja agenta: ${choices[index]}`;
}
</script>

</body>
</html>
