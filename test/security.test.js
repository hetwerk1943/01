// Unit tests for Ultra Security Monitor dashboard utilities
// Run with: node --test test/

const { test } = require('node:test');
const assert = require('node:assert/strict');

// ---- escHtml ----
function escHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

test('escHtml escapes ampersand', () => {
  assert.equal(escHtml('a & b'), 'a &amp; b');
});

test('escHtml escapes less-than', () => {
  assert.equal(escHtml('<script>'), '&lt;script&gt;');
});

test('escHtml escapes greater-than', () => {
  assert.equal(escHtml('x > 0'), 'x &gt; 0');
});

test('escHtml passes plain text unchanged', () => {
  assert.equal(escHtml('hello world'), 'hello world');
});

// ---- deepRepoScan ----
function deepRepoScan(repoFiles) {
  const findings = [];

  const requiredFiles = ['.gitignore', '.env', 'package.json', '.eslintrc'];
  requiredFiles.forEach(file => {
    if (!repoFiles.includes(file)) {
      findings.push(`Brak pliku: ${file}`);
    }
  });

  const hasCI = repoFiles.some(f =>
    f.includes('.github/workflows') || f.includes('gitlab-ci')
  );
  if (!hasCI) findings.push('Brak CI/CD pipeline');

  const hasTests = repoFiles.some(f => f.includes('test'));
  if (!hasTests) findings.push('Brak testów jednostkowych');

  return findings;
}

test('deepRepoScan returns no findings for a complete repo', () => {
  const files = [
    '.gitignore',
    '.env',
    'package.json',
    '.eslintrc',
    '.github/workflows/ci.yml',
    'test/security.test.js',
  ];
  assert.deepEqual(deepRepoScan(files), []);
});

test('deepRepoScan reports missing required files', () => {
  const files = ['.github/workflows/ci.yml', 'test/security.test.js'];
  const findings = deepRepoScan(files);
  assert.ok(findings.includes('Brak pliku: .gitignore'));
  assert.ok(findings.includes('Brak pliku: .env'));
  assert.ok(findings.includes('Brak pliku: package.json'));
  assert.ok(findings.includes('Brak pliku: .eslintrc'));
});

test('deepRepoScan reports missing CI/CD', () => {
  const files = ['.gitignore', '.env', 'package.json', '.eslintrc', 'test/a.test.js'];
  const findings = deepRepoScan(files);
  assert.ok(findings.includes('Brak CI/CD pipeline'));
});

test('deepRepoScan reports missing tests', () => {
  const files = ['.gitignore', '.env', 'package.json', '.eslintrc', '.github/workflows/ci.yml'];
  const findings = deepRepoScan(files);
  assert.ok(findings.includes('Brak testów jednostkowych'));
});
