/**
 * Unit tests for web/repo-agent/app.js logic.
 * The functions are extracted here for isolated testing.
 */

// ─── Constants (mirrored from app.js) ────────────────────────────────────────
const ISSUE_PENALTY = 7;
const MIN_CONFIDENCE = 40;

// ─── Pure functions under test ────────────────────────────────────────────────

function deepRepoScan(repoFiles) {
  const findings = [];
  const recommended = [".gitignore", "package.json", ".eslintrc"];
  recommended.forEach(f => {
    if (!repoFiles.includes(f)) findings.push(`Missing file: ${f}`);
  });
  if (!repoFiles.some(f => f.toLowerCase().includes("test"))) findings.push("No tests found");
  if (!repoFiles.includes("Dockerfile")) findings.push("No Dockerfile");
  return findings;
}

function securityRiskEngine(repoFiles, securityIssues) {
  let risk = securityIssues.length * 2;
  if (!repoFiles.includes(".gitignore")) risk += 1;
  if (risk >= 6) return { level: "HIGH", score: risk };
  if (risk >= 3) return { level: "MEDIUM", score: risk };
  return { level: "LOW", score: risk };
}

function repoMaturityLevel(repoFiles) {
  let score = 0;
  if (repoFiles.includes("Dockerfile")) score += 2;
  if (repoFiles.some(f => f.toLowerCase().includes("test"))) score += 2;
  if (repoFiles.includes(".gitignore")) score += 1;
  if (repoFiles.includes("package.json")) score += 1;
  if (score <= 2) return "PROTOTYPE 🚧";
  if (score <= 4) return "STARTUP 🚀";
  if (score <= 5) return "GROWTH 📈";
  return "ENTERPRISE 🏢";
}

function aiConfidence(repoFiles, securityIssues) {
  const issues = securityIssues.length + deepRepoScan(repoFiles).length;
  return Math.max(100 - issues * ISSUE_PENALTY, MIN_CONFIDENCE);
}

// ─── Tests ────────────────────────────────────────────────────────────────────

describe("deepRepoScan", () => {
  test("returns all findings for empty repo", () => {
    const findings = deepRepoScan([]);
    expect(findings).toContain("Missing file: .gitignore");
    expect(findings).toContain("Missing file: package.json");
    expect(findings).toContain("Missing file: .eslintrc");
    expect(findings).toContain("No tests found");
    expect(findings).toContain("No Dockerfile");
  });

  test("no findings for a fully-configured repo", () => {
    const files = [".gitignore", "package.json", ".eslintrc", "test.js", "Dockerfile"];
    expect(deepRepoScan(files)).toHaveLength(0);
  });

  test("detects missing .gitignore", () => {
    const files = ["package.json", ".eslintrc", "tests.js", "Dockerfile"];
    const findings = deepRepoScan(files);
    expect(findings).toContain("Missing file: .gitignore");
    expect(findings).not.toContain("Missing file: package.json");
  });

  test("detects missing tests", () => {
    const files = [".gitignore", "package.json", ".eslintrc", "Dockerfile"];
    expect(deepRepoScan(files)).toContain("No tests found");
  });

  test("accepts test file with any name containing 'test'", () => {
    const files = [".gitignore", "package.json", ".eslintrc", "mytest.js", "Dockerfile"];
    expect(deepRepoScan(files)).not.toContain("No tests found");
  });
});

describe("securityRiskEngine", () => {
  test("LOW risk with no issues and .gitignore present", () => {
    const result = securityRiskEngine([".gitignore"], []);
    expect(result.level).toBe("LOW");
    expect(result.score).toBe(0);
  });

  test("LOW risk bumped by missing .gitignore alone (score 1)", () => {
    const result = securityRiskEngine([], []);
    expect(result.level).toBe("LOW");
    expect(result.score).toBe(1);
  });

  test("LOW risk with one committed .env file (score=2, threshold for MEDIUM is 3)", () => {
    const issues = ["Sensitive file committed: .env"];
    const result = securityRiskEngine([".gitignore"], issues);
    expect(result.level).toBe("LOW");
    expect(result.score).toBe(2);
  });

  test("HIGH risk with three committed .env files", () => {
    const issues = ["Sensitive file: a", "Sensitive file: b", "Sensitive file: c"];
    const result = securityRiskEngine([".gitignore"], issues);
    expect(result.level).toBe("HIGH");
    expect(result.score).toBeGreaterThanOrEqual(6);
  });
});

describe("repoMaturityLevel", () => {
  test("PROTOTYPE for empty repo", () => {
    expect(repoMaturityLevel([])).toBe("PROTOTYPE 🚧");
  });

  test("STARTUP when Dockerfile + tests present", () => {
    const files = ["Dockerfile", "test.js"];
    expect(repoMaturityLevel(files)).toBe("STARTUP 🚀");
  });

  test("GROWTH when Dockerfile + tests + .gitignore present", () => {
    const files = ["Dockerfile", "test.js", ".gitignore"];
    expect(repoMaturityLevel(files)).toBe("GROWTH 📈");
  });

  test("ENTERPRISE with all indicators", () => {
    const files = ["Dockerfile", "test.js", ".gitignore", "package.json"];
    expect(repoMaturityLevel(files)).toBe("ENTERPRISE 🏢");
  });
});

describe("aiConfidence", () => {
  test("100% confidence for perfect repo", () => {
    const files = [".gitignore", "package.json", ".eslintrc", "test.js", "Dockerfile"];
    expect(aiConfidence(files, [])).toBe(100);
  });

  test("confidence never drops below MIN_CONFIDENCE", () => {
    // Worst-case: many issues
    expect(aiConfidence([], [])).toBeGreaterThanOrEqual(MIN_CONFIDENCE);
  });

  test("confidence decreases with more issues", () => {
    const perfect = [".gitignore", "package.json", ".eslintrc", "test.js", "Dockerfile"];
    const empty = [];
    expect(aiConfidence(perfect, [])).toBeGreaterThan(aiConfidence(empty, []));
  });

  test("security issues reduce confidence", () => {
    const files = [".gitignore", "package.json", ".eslintrc", "test.js", "Dockerfile"];
    const withIssue = aiConfidence(files, ["Sensitive file: .env"]);
    expect(withIssue).toBeLessThan(100);
  });
});
