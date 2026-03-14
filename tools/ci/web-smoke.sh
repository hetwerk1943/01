#!/usr/bin/env bash
# tools/ci/web-smoke.sh
# Thin wrapper to run the canonical Node-based web smoke checks used in CI.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

cd "$REPO_ROOT"

# Delegate to the Node implementation so there is a single source of truth.
exec node tools/ci/web-smoke.js "$@"
