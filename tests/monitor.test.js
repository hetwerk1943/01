// tests/monitor.test.js
// Basic tests for the repoMaturityLevel helper

const assert = require('assert');

function repoMaturityLevel(repoFiles) {
  let score = 0;

  if (repoFiles.includes('Dockerfile')) score += 2;
  if (repoFiles.some(f => f.includes('test'))) score += 2;
  if (repoFiles.includes('.gitignore')) score += 1;
  if (repoFiles.includes('package.json')) score += 1;

  if (score <= 2) return "PROTOTYPE 🚧";
  if (score <= 4) return "STARTUP 🚀";
  if (score <= 5) return "GROWTH 📈";

  return "ENTERPRISE 🏢";
}

// score 0 → PROTOTYPE
assert.strictEqual(repoMaturityLevel([]), "PROTOTYPE 🚧");

// score 1 (.gitignore only) → PROTOTYPE
assert.strictEqual(repoMaturityLevel(['.gitignore']), "PROTOTYPE 🚧");

// score 2 (Dockerfile only) → PROTOTYPE
assert.strictEqual(repoMaturityLevel(['Dockerfile']), "PROTOTYPE 🚧");

// score 3 (Dockerfile + .gitignore) → STARTUP
assert.strictEqual(repoMaturityLevel(['Dockerfile', '.gitignore']), "STARTUP 🚀");

// score 4 (Dockerfile + test file) → STARTUP
assert.strictEqual(repoMaturityLevel(['Dockerfile', 'tests/monitor.test.js']), "STARTUP 🚀");

// score 5 (Dockerfile + test + .gitignore) → GROWTH
assert.strictEqual(repoMaturityLevel(['Dockerfile', 'tests/monitor.test.js', '.gitignore']), "GROWTH 📈");

// score 6 (all four) → ENTERPRISE
assert.strictEqual(
  repoMaturityLevel(['Dockerfile', 'tests/monitor.test.js', '.gitignore', 'package.json']),
  "ENTERPRISE 🏢"
);

console.log("All repoMaturityLevel tests passed.");
