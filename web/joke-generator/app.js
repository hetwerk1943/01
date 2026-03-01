const btn = document.getElementById('jokeBtn');
const jokeEl = document.getElementById('joke');

async function fetchJoke() {
    btn.disabled = true;
    jokeEl.textContent = 'Loading…';
    try {
        const res = await fetch('https://official-joke-api.appspot.com/random_joke');
        if (!res.ok) throw new Error('Network response was not ok');
        const data = await res.json();
        jokeEl.textContent = data.setup + ' — ' + data.punchline;
    } catch (err) {
        console.error('Failed to fetch joke:', err);
        jokeEl.textContent = 'Could not load a joke right now. Please try again.';
    } finally {
        btn.disabled = false;
    }
}

btn.addEventListener('click', fetchJoke);
