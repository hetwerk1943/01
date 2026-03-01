// =========================
// CONSTANTS
// =========================
const ISSUE_PENALTY = 7;   // confidence reduction per detected issue (%)
const MIN_CONFIDENCE = 40; // floor for AI confidence score (%)

// =========================
// GLOBAL STATE
// =========================
let repoFiles = [];
let securityIssues = [];
let refactorSuggestions = [];
let agentHistory = JSON.parse(localStorage.getItem("agentHistory") || "[]");
let scoreHistory = JSON.parse(localStorage.getItem("scoreHistory") || "[]");
let agentMode = "calm";
let currentRisk = { level: "LOW", score: 0 };
let chartInstance = null;

// =========================
// GITHUB FETCH
// =========================
async function loadRepo() {
  const url = document.getElementById("repoUrl").value.trim();
  if (!url.startsWith("https://github.com/")) {
    alert("Please enter a valid GitHub repository URL.");
    return;
  }
  const parts = url.replace("https://github.com/", "").split("/").filter(Boolean);
  if (parts.length < 2) {
    alert("URL must include both owner and repository name, e.g. https://github.com/user/repo");
    return;
  }
  const owner = encodeURIComponent(parts[0]);
  const repo = encodeURIComponent(parts[1]);
  try {
    const response = await fetch(`https://api.github.com/repos/${owner}/${repo}/contents`);
    const remaining = response.headers.get("X-RateLimit-Remaining");
    if (remaining !== null && Number(remaining) === 0) {
      const reset = response.headers.get("X-RateLimit-Reset");
      const resetTime = reset ? new Date(Number(reset) * 1000).toLocaleTimeString() : "soon";
      alert(`GitHub API rate limit reached. Resets at ${resetTime}.`);
      return;
    }
    if (!response.ok) {
      alert(`GitHub API error: ${response.status} ${response.statusText}`);
      return;
    }
    const data = await response.json();
    if (Array.isArray(data)) {
      repoFiles = data.map(f => f.name);
      // Flag committed .env files as a security risk
      securityIssues = repoFiles
        .filter(f => f === ".env" || f.endsWith(".env"))
        .map(f => `Sensitive file committed: ${f}`);
      refactorSuggestions = [];
      alert("Repo loaded \u2705 \u2013 now click Run Analysis.");
    } else {
      alert("Could not read repo contents.");
    }
  } catch (err) {
    alert("Connection error: " + err.message);
  }
}

// =========================
// DEEP SCAN
// =========================
function deepRepoScan() {
  const findings = [];
  const recommended = [".gitignore", "package.json", ".eslintrc"];
  recommended.forEach(f => {
    if (!repoFiles.includes(f)) findings.push(`Missing file: ${f}`);
  });
  if (!repoFiles.some(f => f.toLowerCase().includes("test"))) findings.push("No tests found");
  if (!repoFiles.includes("Dockerfile")) findings.push("No Dockerfile");
  return findings;
}

// =========================
// SECURITY ENGINE
// =========================
function securityRiskEngine() {
  let risk = securityIssues.length * 2; // securityIssues contains committed .env files etc.
  if (!repoFiles.includes(".gitignore")) risk += 1;
  if (risk >= 6) return { level: "HIGH", score: risk };
  if (risk >= 3) return { level: "MEDIUM", score: risk };
  return { level: "LOW", score: risk };
}

// =========================
// MATURITY
// =========================
function repoMaturityLevel() {
  let score = 0;
  if (repoFiles.includes("Dockerfile")) score += 2;
  if (repoFiles.some(f => f.toLowerCase().includes("test"))) score += 2;
  if (repoFiles.includes(".gitignore")) score += 1;
  if (repoFiles.includes("package.json")) score += 1;
  if (score <= 2) return "PROTOTYPE 🚧";
  if (score <= 4) return "STARTUP 🚀";
  if (score <= 5) return "GROWTH 📈";
  return "ENTERPRISE 🏢";
}

// =========================
// CONFIDENCE
// =========================
function aiConfidence() {
  const issues = securityIssues.length + deepRepoScan().length;
  return Math.max(100 - issues * ISSUE_PENALTY, MIN_CONFIDENCE);
}

// =========================
// ROADMAP
// =========================
function generateDynamicRoadmap() {
  const steps = [];
  if (securityIssues.length > 0) steps.push("Fix security issues");
  deepRepoScan().forEach(f => steps.push(`Resolve: ${f}`));
  if (refactorSuggestions.length > 0) steps.push("Refactor: " + refactorSuggestions.join(", "));
  if (steps.length === 0) steps.push("Add CI/CD pipeline and automated tests");
  return steps;
}

// =========================
// ANALYSIS
// =========================
function runAnalysis() {
  if (repoFiles.length === 0) {
    alert("Load a repository first.");
    return;
  }
  let output = "📂 Repo Files:\n";
  repoFiles.forEach(f => (output += `  - ${f}\n`));

  const findings = deepRepoScan();
  output += "\n🧠 Deep Scan:\n";
  if (findings.length === 0) {
    output += "  ✅ No issues found\n";
  } else {
    findings.forEach(f => (output += `  ⚠️ ${f}\n`));
  }

  currentRisk = securityRiskEngine();
  output += `\n🔐 Security Risk: ${currentRisk.level} (score: ${currentRisk.score})\n`;
  output += `\n🏢 Maturity: ${repoMaturityLevel()}\n`;
  output += `\n🧠 AI Confidence: ${aiConfidence()}%\n`;

  const productionReady =
    repoFiles.includes("Dockerfile") &&
    repoFiles.some(f => f.toLowerCase().includes("test")) &&
    securityIssues.length === 0;
  output += `\n🚀 Production Status: ${productionReady ? "READY ✅" : "NOT READY ❌"}\n`;

  output += "\n🗺 Roadmap:\n";
  generateDynamicRoadmap().forEach((r, i) => (output += `  ${i + 1}. ${r}\n`));

  document.getElementById("analysisOutput").textContent = output;
  saveScoreTrend(aiConfidence());
  drawChart();
  runDecisionMaking();
}

// =========================
// DECISION ENGINE
// =========================
function runDecisionMaking() {
  let recommendation;
  if (currentRisk.level === "HIGH") recommendation = "Fix SECURITY ISSUES IMMEDIATELY";
  else if (refactorSuggestions.length > 0) recommendation = "Perform refactoring";
  else recommendation = "Add CI/CD and tests";

  if (agentMode === "aggressive") recommendation = "⚠️ PRIORITY: " + recommendation.toUpperCase();

  agentHistory.push(recommendation);
  if (agentHistory.length > 20) agentHistory.shift(); // keep last 20 entries
  localStorage.setItem("agentHistory", JSON.stringify(agentHistory));

  document.getElementById("decisionOutput").textContent =
    `🤖 ${recommendation}\n\n📜 History:\n` +
    agentHistory.map((h, i) => `  ${i + 1}. ${h}`).join("\n");
}

// =========================
// PR GENERATOR
// =========================
function generatePullRequest() {
  let pr = "### 🤖 AI Repo Improvements\n\n";
  generateDynamicRoadmap().forEach(s => (pr += `- ${s}\n`));
  pr += `\nConfidence: ${aiConfidence()}%`;
  return pr;
}

function showPR() {
  if (repoFiles.length === 0) {
    alert("Load and analyze a repository first.");
    return;
  }
  alert(generatePullRequest());
}

// =========================
// MODE TOGGLE
// =========================
function toggleMode() {
  agentMode = agentMode === "calm" ? "aggressive" : "calm";
  document.getElementById("modeBtn").textContent = `Mode: ${agentMode.charAt(0).toUpperCase() + agentMode.slice(1)}`;
}

// =========================
// TREND & CHART
// =========================
function saveScoreTrend(score) {
  scoreHistory.push(score);
  if (scoreHistory.length > 20) scoreHistory.shift();
  localStorage.setItem("scoreHistory", JSON.stringify(scoreHistory));
}

function drawChart() {
  const ctx = document.getElementById("scoreChart").getContext("2d");
  if (chartInstance) chartInstance.destroy();
  const labels = scoreHistory.map((_, i) => `Run ${i + 1}`);
  chartInstance = new Chart(ctx, {
    type: "line",
    data: {
      labels,
      datasets: [
        {
          label: "AI Confidence (%)",
          data: scoreHistory,
          borderColor: "#0366d6",
          backgroundColor: "rgba(3,102,214,0.1)",
          tension: 0.3,
          fill: true,
        },
      ],
    },
    options: {
      scales: {
        y: { min: 0, max: 100, title: { display: true, text: "Confidence %" } },
      },
      plugins: { legend: { display: true } },
    },
  });
}

// Draw chart on page load if history exists
if (scoreHistory.length > 0) drawChart();

// =========================
// EVENT LISTENERS
// =========================
// Script is placed at end of <body>, so DOM is already available here.
document.getElementById("loadRepoBtn").addEventListener("click", loadRepo);
document.getElementById("modeBtn").addEventListener("click", toggleMode);
document.getElementById("analyzeBtn").addEventListener("click", runAnalysis);
document.getElementById("prBtn").addEventListener("click", showPR);
