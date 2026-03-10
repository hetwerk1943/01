#!/usr/bin/env node
// tools/ci/web-smoke.js
// Minimal smoke checks for static web assets.
// Exit code 0 = all checks passed; non-zero = failures detected.

const fs   = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', '..');
let failures = 0;

function check(description, condition) {
  if (condition) {
    console.log(`  ✅  ${description}`);
  } else {
    console.error(`  ❌  FAIL: ${description}`);
    failures++;
  }
}

function fileExists(rel) {
  return fs.existsSync(path.join(ROOT, rel));
}

function fileContains(rel, text) {
  if (!fileExists(rel)) return false;
  return fs.readFileSync(path.join(ROOT, rel), 'utf8').includes(text);
}

console.log('\n🔍 Web smoke checks\n');

// Root HTML files
check('index.html exists',     fileExists('index.html'));
check('dashboard.html exists', fileExists('dashboard.html'));
check('agent.html exists',     fileExists('agent.html'));

// Web mini-apps
check('web/repo-agent/index.html exists',    fileExists('web/repo-agent/index.html'));
check('web/repo-agent/app.js exists',        fileExists('web/repo-agent/app.js'));
check('web/joke-generator/index.html exists', fileExists('web/joke-generator/index.html'));
check('web/joke-generator/app.js exists',    fileExists('web/joke-generator/app.js'));

// No inline secrets (basic heuristic)
const filesToCheck = [
  'web/repo-agent/app.js',
  'web/joke-generator/app.js',
];
const secretPatterns = [
  /ghp_[A-Za-z0-9]{36}/,          // GitHub PAT
  /AAAA[A-Za-z0-9_-]{60,}/,       // Generic long token
  /discord\.com\/api\/webhooks\/\d+\/[A-Za-z0-9_-]{60,}/, // Discord webhook
];
for (const rel of filesToCheck) {
  if (!fileExists(rel)) continue;
  const content = fs.readFileSync(path.join(ROOT, rel), 'utf8');
  for (const pattern of secretPatterns) {
    check(`No hardcoded secret in ${rel} (${pattern.source})`, !pattern.test(content));
  }
}

// Package.json serves web/ not root
if (fileExists('package.json')) {
  const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, 'package.json'), 'utf8'));
  const startScript = (pkg.scripts && pkg.scripts.start) || '';
  check('package.json start script references web/ directory', startScript.includes('web'));
}

console.log(`\n${failures === 0 ? '✅ All checks passed.' : `❌ ${failures} check(s) failed.`}\n`);
process.exit(failures > 0 ? 1 : 0);
