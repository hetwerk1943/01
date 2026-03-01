// Lifestyle & Motivation Assessment
// Scores map to four motivation styles based on McClelland's Human Motivation Theory
// extended with an Autonomy dimension.

// =========================
// QUIZ DATA
// =========================
const QUESTIONS = [
  {
    text: "What gives you the most satisfaction?",
    options: [
      { label: "Achieving a difficult goal",           key: "achievement" },
      { label: "Building strong relationships",         key: "affiliation" },
      { label: "Leading others and making an impact",  key: "power"       },
      { label: "Working on your own terms",            key: "autonomy"    },
    ],
  },
  {
    text: "How do you prefer to spend your free time?",
    options: [
      { label: "Learning new skills or competing",      key: "achievement" },
      { label: "Spending quality time with people",     key: "affiliation" },
      { label: "Organising events or mentoring others", key: "power"       },
      { label: "Pursuing a personal passion project",   key: "autonomy"    },
    ],
  },
  {
    text: "What motivates you most in your work or studies?",
    options: [
      { label: "Challenging tasks and measurable results", key: "achievement" },
      { label: "Teamwork, trust, and collaboration",        key: "affiliation" },
      { label: "Responsibility and decision-making power",  key: "power"       },
      { label: "Flexible schedule and creative freedom",    key: "autonomy"    },
    ],
  },
  {
    text: "When you face a problem, your first instinct is to:",
    options: [
      { label: "Set a plan and tackle it step by step",     key: "achievement" },
      { label: "Talk it over with trusted friends/family",  key: "affiliation" },
      { label: "Take charge and direct the solution",       key: "power"       },
      { label: "Find your own unconventional approach",     key: "autonomy"    },
    ],
  },
  {
    text: "Which phrase resonates with you most?",
    options: [
      { label: "\"Work hard, aim high, win.\"",            key: "achievement" },
      { label: "\"Together we go further.\"",              key: "affiliation" },
      { label: "\"Be the change you want to see.\"",       key: "power"       },
      { label: "\"Live life on your own terms.\"",         key: "autonomy"    },
    ],
  },
];

const RESULTS = {
  achievement: {
    title: "Achievement-Driven",
    emoji: "🏆",
    description:
      "You are motivated by setting and surpassing challenging goals. " +
      "Competition, measurable success, and continuous self-improvement fuel your energy. " +
      "You thrive in environments where excellence is recognised and progress is visible.",
    tips: [
      "Set SMART goals (Specific, Measurable, Achievable, Relevant, Time-bound).",
      "Track your progress regularly to stay motivated.",
      "Celebrate small wins – they build momentum toward bigger ones.",
      "Find a friendly competitor or accountability partner.",
      "Balance ambition with rest to avoid burnout.",
    ],
  },
  affiliation: {
    title: "Affiliation-Driven",
    emoji: "🤝",
    description:
      "You are energised by meaningful relationships and a sense of belonging. " +
      "Collaboration, empathy, and community are the cornerstones of your lifestyle. " +
      "You perform best when you feel connected, trusted, and valued by those around you.",
    tips: [
      "Invest time in nurturing your closest relationships.",
      "Join communities or clubs that share your values.",
      "Practice active listening to deepen your connections.",
      "Volunteer or mentor others – giving strengthens bonds.",
      "Set healthy boundaries to protect your emotional energy.",
    ],
  },
  power: {
    title: "Influence-Driven",
    emoji: "🌟",
    description:
      "You are motivated by making an impact and inspiring others. " +
      "Leadership, responsibility, and the ability to shape outcomes define your lifestyle. " +
      "You are at your best when you can guide projects, champion ideas, and drive real change.",
    tips: [
      "Seek leadership roles or mentoring opportunities.",
      "Focus on empowering others, not just directing them.",
      "Develop your emotional intelligence alongside your authority.",
      "Build a personal vision statement to guide your decisions.",
      "Stay mindful of power dynamics and lead with integrity.",
    ],
  },
  autonomy: {
    title: "Autonomy-Driven",
    emoji: "🦅",
    description:
      "You are motivated by freedom, creativity, and self-direction. " +
      "Independence, originality, and the ability to chart your own course define your lifestyle. " +
      "You flourish when you have the space to think differently and act on your own initiative.",
    tips: [
      "Design environments that minimise unnecessary constraints.",
      "Explore freelance, entrepreneurial, or project-based work.",
      "Protect dedicated time for creative exploration each week.",
      "Build self-discipline routines so freedom does not become drift.",
      "Connect with like-minded free-thinkers for fresh inspiration.",
    ],
  },
};

// =========================
// STATE
// =========================
let currentQuestion = 0;
const scores = { achievement: 0, affiliation: 0, power: 0, autonomy: 0 };

// =========================
// DOM REFERENCES
// =========================
const quizSection     = document.getElementById("quiz-section");
const resultSection   = document.getElementById("result-section");
const questionCounter = document.getElementById("question-counter");
const questionText    = document.getElementById("question-text");
const optionsEl       = document.getElementById("options");
const progressBar     = document.getElementById("progress-bar");
const resultTitle     = document.getElementById("result-title");
const resultEmoji     = document.getElementById("result-emoji");
const resultDesc      = document.getElementById("result-description");
const resultTips      = document.getElementById("result-tips");
const restartBtn      = document.getElementById("restartBtn");

// =========================
// RENDER QUESTION
// =========================
function renderQuestion() {
  const q = QUESTIONS[currentQuestion];
  const total = QUESTIONS.length;

  questionCounter.textContent = `Question ${currentQuestion + 1} of ${total}`;
  progressBar.style.width = `${((currentQuestion + 1) / total) * 100}%`;
  questionText.textContent = q.text;

  optionsEl.innerHTML = "";
  q.options.forEach(opt => {
    const btn = document.createElement("button");
    btn.className = "option-btn";
    btn.textContent = opt.label;
    btn.addEventListener("click", () => handleAnswer(opt.key));
    optionsEl.appendChild(btn);
  });
}

// =========================
// HANDLE ANSWER
// =========================
function handleAnswer(key) {
  scores[key] += 1;
  currentQuestion += 1;

  if (currentQuestion < QUESTIONS.length) {
    renderQuestion();
  } else {
    showResult();
  }
}

// =========================
// SHOW RESULT
// =========================
function showResult() {
  progressBar.style.width = "100%";

  // Find dominant motivation style; priority order resolves ties deterministically
  const PRIORITY = ["achievement", "affiliation", "power", "autonomy"];
  const dominant = PRIORITY.reduce(
    (best, key) => (scores[key] > scores[best] ? key : best),
    PRIORITY[0]
  );

  const result = RESULTS[dominant];

  resultTitle.textContent = result.title;
  resultEmoji.textContent = result.emoji;
  resultDesc.textContent  = result.description;

  resultTips.innerHTML = "";
  result.tips.forEach(tip => {
    const li = document.createElement("li");
    li.textContent = tip;
    resultTips.appendChild(li);
  });

  quizSection.hidden  = true;
  resultSection.hidden = false;
}

// =========================
// RESTART
// =========================
function restart() {
  currentQuestion = 0;
  Object.keys(scores).forEach(k => (scores[k] = 0));

  quizSection.hidden   = false;
  resultSection.hidden = true;

  renderQuestion();
}

// =========================
// INIT
// =========================
restartBtn.addEventListener("click", restart);
renderQuestion();
