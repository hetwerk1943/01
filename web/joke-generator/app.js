const jokeBtn = document.getElementById("jokeBtn");
const jokeEl  = document.getElementById("joke");

async function fetchJoke() {
  jokeBtn.disabled = true;
  jokeEl.textContent = "Loading…";
  try {
    const res  = await fetch(
      "https://v2.jokeapi.dev/joke/Any?blacklistFlags=nsfw,racist,sexist&type=single",
      { headers: { Accept: "application/json" } }
    );
    if (!res.ok) throw new Error("Network response was not ok");
    const data = await res.json();
    jokeEl.textContent = data.joke || "Could not load a joke. Try again!";
  } catch {
    jokeEl.textContent = "Failed to fetch a joke. Check your connection and try again.";
  } finally {
    jokeBtn.disabled = false;
  }
}

jokeBtn.addEventListener("click", fetchJoke);
