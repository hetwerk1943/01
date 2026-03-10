const jokeBtn = document.getElementById("jokeBtn");
const copyBtn = document.getElementById("copyBtn");
const jokeEl = document.getElementById("joke");
const statusEl = document.getElementById("status");
const categoryEl = document.getElementById("category");
const safeModeEl = document.getElementById("safeMode");

let lastJoke = "";

function setStatus(msg) {
  statusEl.textContent = msg || "";
}

function buildJokeApiUrl() {
  const category = (categoryEl && categoryEl.value) || "Any";
  const safeMode = !!(safeModeEl && safeModeEl.checked);

  const url = new URL(`https://v2.jokeapi.dev/joke/${encodeURIComponent(category)}`);
  url.searchParams.set("type", "single");
  url.searchParams.set("format", "json");

  // Keep it safe by default; allow turning off safe mode.
  // When safeMode=false we just don't apply blacklistFlags.
  if (safeMode) {
    url.searchParams.set("blacklistFlags", "nsfw,racist,sexist,explicit");
  }

  return url.toString();
}

async function fetchJoke() {
  jokeBtn.disabled = true;
  copyBtn.disabled = true;
  jokeEl.textContent = "Loading…";
  setStatus("");

  try {
    const res = await fetch(buildJokeApiUrl(), {
      headers: { Accept: "application/json" },
    });

    if (!res.ok) throw new Error(`Network response was not ok (${res.status})`);

    const data = await res.json();

    // JokeAPI can return an error payload
    if (data && data.error) {
      throw new Error(data.message || "API returned an error");
    }

    lastJoke = (data && data.joke) || "";
    jokeEl.textContent = lastJoke || "Could not load a joke. Try again!";
    copyBtn.disabled = !lastJoke;
  } catch (err) {
    lastJoke = "";
    jokeEl.textContent = "Failed to fetch a joke. Check your connection and try again.";
    setStatus(err && err.message ? `Details: ${err.message}` : "");
  } finally {
    jokeBtn.disabled = false;
  }
}

async function copyJoke() {
  if (!lastJoke) return;

  try {
    await navigator.clipboard.writeText(lastJoke);
    setStatus("Copied to clipboard.");
    setTimeout(() => setStatus(""), 1400);
  } catch {
    // Fallback for older browsers / blocked permissions
    try {
      const ta = document.createElement("textarea");
      ta.value = lastJoke;
      ta.setAttribute("readonly", "");
      ta.style.position = "absolute";
      ta.style.left = "-9999px";
      document.body.appendChild(ta);
      ta.select();
      document.execCommand("copy");
      document.body.removeChild(ta);
      setStatus("Copied to clipboard.");
      setTimeout(() => setStatus(""), 1400);
    } catch {
      setStatus("Copy failed. Select the text and copy manually.");
    }
  }
}

jokeBtn.addEventListener("click", fetchJoke);
copyBtn.addEventListener("click", copyJoke);

// Optional: load a joke immediately on first visit
fetchJoke();