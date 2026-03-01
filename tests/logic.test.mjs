/**
 * Unit tests for the pure business-logic functions used by
 * web/repo-agent/app.js and agent.html.
 *
 * These functions are reproduced here as pure utilities (no DOM / browser
 * APIs required) so they can be executed with the built-in Node.js test
 * runner:  node --test tests/
 */

import { test } from 'node:test';
import assert from 'node:assert/strict';

// ─── Constants (kept in sync with app.js) ────────────────────────────────────
const ISSUE_PENALTY  = 7;
const MIN_CONFIDENCE = 40;

// ─── Pure helpers (mirror of app.js functions, DOM-free) ─────────────────────
function deepRepoScan(repoFiles) {
  const findings = [];
  const recommended = ['.gitignore', 'package.json', '.eslintrc'];
  recommended.forEach(f => {
    if (!repoFiles.includes(f)) findings.push(`Missing file: ${f}`);
  });
  if (!repoFiles.some(f => f.toLowerCase().includes('test'))) findings.push('No tests found');
  if (!repoFiles.includes('Dockerfile')) findings.push('No Dockerfile');
  return findings;
}

function securityRiskEngine(securityIssues, repoFiles) {
  let risk = securityIssues.length * 2;
  if (!repoFiles.includes('.gitignore')) risk += 1;
  if (risk >= 6) return { level: 'HIGH', score: risk };
  if (risk >= 3) return { level: 'MEDIUM', score: risk };
  return { level: 'LOW', score: risk };
}

function repoMaturityLevel(repoFiles) {
  let score = 0;
  if (repoFiles.includes('Dockerfile'))                              score += 2;
  if (repoFiles.some(f => f.toLowerCase().includes('test')))        score += 2;
  if (repoFiles.includes('.gitignore'))                              score += 1;
  if (repoFiles.includes('package.json'))                            score += 1;
  if (score <= 2) return 'PROTOTYPE \uD83D\uDEA7';
  if (score <= 4) return 'STARTUP \uD83D\uDE80';
  if (score <= 5) return 'GROWTH \uD83D\uDCC8';
  return 'ENTERPRISE \uD83C\uDFE2';
}

function aiConfidence(securityIssues, repoFiles) {
  const issues = securityIssues.length + deepRepoScan(repoFiles).length;
  return Math.max(100 - issues * ISSUE_PENALTY, MIN_CONFIDENCE);
}

function generateDynamicRoadmap(securityIssues, repoFiles, refactorSuggestions) {
  const steps = [];
  if (securityIssues.length > 0) steps.push('Fix security issues');
  deepRepoScan(repoFiles).forEach(f => steps.push(`Resolve: ${f}`));
  if (refactorSuggestions.length > 0) steps.push('Refactor: ' + refactorSuggestions.join(', '));
  if (steps.length === 0) steps.push('Add CI/CD pipeline and automated tests');
  return steps;
}

// ─── deepRepoScan ────────────────────────────────────────────────────────────
test('deepRepoScan – empty repo flags all expected missing items', () => {
  const findings = deepRepoScan([]);
  assert.ok(findings.includes('Missing file: .gitignore'));
  assert.ok(findings.includes('Missing file: package.json'));
  assert.ok(findings.includes('Missing file: .eslintrc'));
  assert.ok(findings.includes('No tests found'));
  assert.ok(findings.includes('No Dockerfile'));
});

test('deepRepoScan – fully equipped repo has no findings', () => {
  const files = ['.gitignore', 'package.json', '.eslintrc', 'Dockerfile', 'tests.spec.js'];
  const findings = deepRepoScan(files);
  assert.strictEqual(findings.length, 0);
});

test('deepRepoScan – file named "tests" satisfies the test requirement', () => {
  const findings = deepRepoScan(['.gitignore', 'package.json', '.eslintrc', 'Dockerfile', 'tests']);
  assert.ok(!findings.includes('No tests found'));
});

// ─── securityRiskEngine ───────────────────────────────────────────────────────
test('securityRiskEngine – LOW risk: no issues, gitignore present', () => {
  const result = securityRiskEngine([], ['.gitignore']);
  assert.strictEqual(result.level, 'LOW');
  assert.strictEqual(result.score, 0);
});

test('securityRiskEngine – adds 1 to risk when .gitignore is absent', () => {
  const result = securityRiskEngine([], []);
  assert.strictEqual(result.score, 1);
  assert.strictEqual(result.level, 'LOW');
});

test('securityRiskEngine – MEDIUM risk: two .env files committed, gitignore present', () => {
  // score = 2 issues * 2 = 4, but need >= 3 for MEDIUM → use gitignore absent + two issues
  const issues = ['Sensitive file committed: .env', 'Sensitive file committed: .env.local'];
  const result = securityRiskEngine(issues, ['.gitignore']);
  // score = 4 → HIGH threshold is 6, MEDIUM threshold is 3 → 4 >= 3 → MEDIUM
  assert.strictEqual(result.level, 'MEDIUM');
});

test('securityRiskEngine – HIGH risk: three .env files committed', () => {
  const issues = ['.env', '.env.local', '.env.production'].map(f => `Sensitive: ${f}`);
  const result = securityRiskEngine(issues, ['.gitignore']);
  assert.strictEqual(result.level, 'HIGH');
});

// ─── repoMaturityLevel ────────────────────────────────────────────────────────
test('repoMaturityLevel – empty repo is PROTOTYPE', () => {
  assert.ok(repoMaturityLevel([]).startsWith('PROTOTYPE'));
});

test('repoMaturityLevel – repo with .gitignore, package.json and Dockerfile is STARTUP', () => {
  // score = 1 (.gitignore) + 1 (package.json) + 2 (Dockerfile) = 4 → STARTUP
  assert.ok(repoMaturityLevel(['.gitignore', 'package.json', 'Dockerfile']).startsWith('STARTUP'));
});

test('repoMaturityLevel – repo with .gitignore, Dockerfile and tests is GROWTH', () => {
  // score = 1 (.gitignore) + 2 (Dockerfile) + 2 (test) = 5 → GROWTH
  assert.ok(repoMaturityLevel(['.gitignore', 'Dockerfile', 'tests.spec.js']).startsWith('GROWTH'));
});

test('repoMaturityLevel – fully equipped repo is ENTERPRISE', () => {
  const files = ['.gitignore', 'package.json', 'Dockerfile', 'app.test.js'];
  assert.ok(repoMaturityLevel(files).startsWith('ENTERPRISE'));
});

// ─── aiConfidence ─────────────────────────────────────────────────────────────
test('aiConfidence – perfect repo scores 100', () => {
  const files = ['.gitignore', 'package.json', '.eslintrc', 'Dockerfile', 'app.test.js'];
  assert.strictEqual(aiConfidence([], files), 100);
});

test('aiConfidence – never drops below MIN_CONFIDENCE floor', () => {
  const manyIssues = Array.from({ length: 20 }, (_, i) => `issue-${i}`);
  assert.ok(aiConfidence(manyIssues, []) >= MIN_CONFIDENCE);
});

test('aiConfidence – each issue reduces confidence by ISSUE_PENALTY', () => {
  const base = aiConfidence([], ['.gitignore', 'package.json', '.eslintrc', 'Dockerfile', 'test.js']);
  const withIssue = aiConfidence(['env leak'], ['.gitignore', 'package.json', '.eslintrc', 'Dockerfile', 'test.js']);
  assert.strictEqual(base - withIssue, ISSUE_PENALTY);
});

// ─── generateDynamicRoadmap ───────────────────────────────────────────────────
test('generateDynamicRoadmap – clean repo returns default CI/CD step', () => {
  const steps = generateDynamicRoadmap(
    [],
    ['.gitignore', 'package.json', '.eslintrc', 'Dockerfile', 'tests.js'],
    []
  );
  assert.strictEqual(steps.length, 1);
  assert.ok(steps[0].includes('CI/CD'));
});

test('generateDynamicRoadmap – security issues appear first', () => {
  const steps = generateDynamicRoadmap(['env leak'], ['.gitignore'], []);
  assert.strictEqual(steps[0], 'Fix security issues');
});

test('generateDynamicRoadmap – refactor suggestions are included', () => {
  const files = ['.gitignore', 'package.json', '.eslintrc', 'Dockerfile', 'tests.js'];
  const steps = generateDynamicRoadmap([], files, ['utils.js', 'helpers.js']);
  assert.ok(steps.some(s => s.startsWith('Refactor:')));
});
