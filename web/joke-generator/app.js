const JOKE_API = "https://official-joke-api.appspot.com/random_joke";

async function fetchJoke() {
  const jokeEl = document.getElementById("joke");
  jokeEl.textContent = "Loading…";
  try {
    const response = await fetch(JOKE_API);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const data = await response.json();
    jokeEl.textContent = `${data.setup} — ${data.punchline}`;
  } catch (err) {
    jokeEl.textContent = "Could not load a joke. Please try again.";
  }
}

document.getElementById("jokeBtn").addEventListener("click", fetchJoke);
