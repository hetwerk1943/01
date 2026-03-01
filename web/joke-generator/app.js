const jokes = [
    "Why do programmers prefer dark mode? Because light attracts bugs.",
    "How many programmers does it take to change a light bulb? None – that's a hardware problem.",
    "Why do Java developers wear glasses? Because they don't C#.",
    "A SQL query walks into a bar, walks up to two tables and asks: 'Can I join you?'",
    "Why was the JavaScript developer sad? Because he didn't Node how to Express himself.",
    "What do you call a group of 8 Hobbits? A Hobbyte.",
    "I asked my computer for a joke. It said: 'Error 404: Humor not found.'",
    "Why did the developer go broke? Because he used up all his cache.",
    "Two bytes meet. The first byte asks: 'Are you ill?' The second byte replies: 'No, just feeling a bit off.'",
    "Why did the programmer quit his job? Because he didn't get arrays."
];

function getRandomJoke() {
    const idx = Math.floor(Math.random() * jokes.length);
    return jokes[idx];
}

document.getElementById('jokeBtn').addEventListener('click', function () {
    document.getElementById('joke').textContent = getRandomJoke();
});
