# Development Guide

## Environment setup

```powershell
# Clone and enter the repository
git clone https://github.com/hetwerk1943/01.git
cd 01

# Install dev tools (Pester + PSScriptAnalyzer)
.\scripts\setup.ps1 -InstallDevTools
```

## Module structure

The PowerShell module lives in `src/UltraSecurityMonitor/`.

- **Public/** – exported functions (one per file, verb-noun naming)
- **Private/** – internal helpers (not exported)
- The module root (`UltraSecurityMonitor.psm1`) dot-sources all files

### Adding a new private helper

1. Create `src/UltraSecurityMonitor/Private/Verb-UsmNoun.ps1`
2. Follow the naming convention: `*-Usm*`
3. Access module config via `$script:_config`
4. Write tests in `tests/powershell/`

### Adding a new public function

1. Create `src/UltraSecurityMonitor/Public/Verb-UltraSecurityNoun.ps1`
2. Add the function name to `FunctionsToExport` in `UltraSecurityMonitor.psd1`
3. Write tests

## Running tests locally

```powershell
# Run all Pester tests
Invoke-Pester -Path tests/powershell -Output Detailed

# Run a specific test file
Invoke-Pester -Path tests/powershell/UltraSecurityMonitor.Tests.ps1
```

## Linting

```powershell
# Lint the src/ directory
Invoke-ScriptAnalyzer -Path src -Recurse -Severity Warning
```

Fix any warnings before opening a PR – CI will enforce this.

## Web smoke test

```bash
bash tools/ci/web-smoke.sh
```

## Commit conventions

Use conventional commits:

```
feat: add SMTP retry logic
fix: correct path-safety check on UNC paths
docs: update QUICK_START
chore: bump PSScriptAnalyzer to 1.22
```

## Branch naming

| Type | Pattern |
|---|---|
| Feature | `feat/short-description` |
| Bug fix | `fix/short-description` |
| Docs | `docs/short-description` |
| Chore | `chore/short-description` |

## CI

The `ci.yml` workflow runs on every push and PR to `main`:

1. **PSScriptAnalyzer** – lint PowerShell (`src/`)
2. **Pester** – unit + integration tests (`tests/powershell/`)
3. **Web smoke** – validate HTML entry points exist

Ensure all three jobs pass before requesting review.
