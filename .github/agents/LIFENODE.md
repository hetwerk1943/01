/* ================================
   LIFEHUB INTELLIGENCE BOT (PRO)
   Single-file AI Agent
================================ */

const LIFEHUB_AI_CONFIG = {
  model: "gpt-4o-mini",
  endpoint: "https://api.openai.com/v1/chat/completions",
  apiKey: "YOUR_OPENAI_API_KEY", // ← podmień
  highPriorityReward: 15
};

/* ===== MAIN BOT FUNCTION ===== */

async function runLifeHubBot(card) {
  try {
    showBotSpinner();

    const structured = await analyzeCardWithAI(card);

    applyBotResults(card, structured);

    await saveBoardState();

    awardBotPoints(structured);

    updateUI();

    hideBotSpinner();

    showToast("🤖 AI analysis complete");
  } catch (err) {
    console.error("Bot error:", err);
    hideBotSpinner();
    showToast("⚠️ AI analysis failed");
  }
}

/* ===== AI ANALYSIS ===== */

async function analyzeCardWithAI(card) {
  const prompt = buildBotPrompt(card);

  const response = await fetch(LIFEHUB_AI_CONFIG.endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${LIFEHUB_AI_CONFIG.apiKey}`
    },
    body: JSON.stringify({
      model: LIFEHUB_AI_CONFIG.model,
      messages: [
        { role: "system", content: "You are an elite productivity AI." },
        { role: "user", content: prompt }
      ],
      temperature: 0.3
    })
  });

  const data = await response.json();

  const content = data.choices?.[0]?.message?.content;

  return safeJSONParse(content);
}

/* ===== PROMPT BUILDER ===== */

function buildBotPrompt(card) {
  return `
Analyze this content and return ONLY valid JSON.

TITLE:
${card.title}

CONTENT:
${card.extractedText || card.notes || ""}

Return:

{
  "summary": "",
  "insights": [],
  "suggestedAction": "",
  "priority": "low|medium|high",
  "suggestedColumn": "Do przeczytania|Research|Zrobione",
  "tags": []
}
`;
}

/* ===== APPLY RESULTS ===== */

function applyBotResults(card, result) {
  card.notes = result.summary || card.notes;
  card.priority = result.priority || "medium";
  card.tags = result.tags || [];

  if (result.suggestedColumn) {
    moveCardToColumn(card.id, result.suggestedColumn);
  }
}

/* ===== POINTS LOGIC ===== */

async function awardBotPoints(result) {
  if (result.priority === "high") {
    await addPoints(LIFEHUB_AI_CONFIG.highPriorityReward, "high_priority_detected", null);
    showToast(`🔥 +${LIFEHUB_AI_CONFIG.highPriorityReward} Points (High Priority)`);
  }
}

/* ===== SAFE JSON ===== */

function safeJSONParse(text) {
  try {
    return JSON.parse(text);
  } catch {
    return {
      summary: text,
      insights: [],
      suggestedAction: "",
      priority: "medium",
      suggestedColumn: "Research",
      tags: []
    };
  }
}

/* ===== UI HELPERS ===== */

function showBotSpinner() {
  const spinner = document.getElementById("bot-spinner");
  if (spinner) spinner.style.display = "block";
}

function hideBotSpinner() {
  const spinner = document.getElementById("bot-spinner");
  if (spinner) spinner.style.display = "none";
}

function showToast(message) {
  const toast = document.createElement("div");
  toast.className = "lifehub-toast";
  toast.innerText = message;
  document.body.appendChild(toast);

  setTimeout(() => toast.remove(), 3000);
}

/* ===== HOOK BUTTON ===== */

document.addEventListener("click", function (e) {
  if (e.target.dataset.action === "ai-bot") {
    const cardId = e.target.closest(".card").dataset.id;
    const card = findCardById(cardId);
    if (card) runLifeHubBot(card);
  }
});
