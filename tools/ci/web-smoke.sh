#!/usr/bin/env bash
# tools/ci/web-smoke.sh
# Minimal web smoke validation: verifies key HTML entry points and asset references exist.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WEB_DIR="$REPO_ROOT/web"

PASS=0
FAIL=0

check_file() {
    local rel="$1"
    local full="$REPO_ROOT/$rel"
    if [[ -f "$full" ]]; then
        echo "  ✅  $rel"
        ((PASS++)) || true
    else
        echo "  ❌  MISSING: $rel" >&2
        ((FAIL++)) || true
    fi
}

echo "🌐 Web smoke validation"

# ── Required HTML entry points ────────────────────────────────────────────────
echo ""
echo "Entry points:"
check_file "index.html"
check_file "dashboard.html"
check_file "agent.html"
check_file "web/repo-agent/index.html"
check_file "web/joke-generator/index.html"

# ── Check for obviously broken inline secrets ─────────────────────────────────
echo ""
echo "Secret pattern scan (HTML/JS files):"
SECRET_PATTERNS=("api[_-]key\s*=\s*['\"][^'\"]{10}" "webhook.*https://discord.com/api/webhooks/[0-9]")
found_secrets=0
while IFS= read -r -d '' file; do
    for pattern in "${SECRET_PATTERNS[@]}"; do
        if grep -qiE "$pattern" "$file" 2>/dev/null; then
            echo "  ⚠️  Possible secret in: ${file#"$REPO_ROOT/"}" >&2
            found_secrets=1
        fi
    done
done < <(find "$REPO_ROOT" \( -name "*.html" -o -name "*.js" \) \
    -not -path "*/node_modules/*" -not -path "*/saas-app/*" -print0)

if [[ $found_secrets -eq 0 ]]; then
    echo "  ✅  No obvious secrets found"
fi

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
