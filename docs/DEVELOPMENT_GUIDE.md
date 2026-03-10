# Development Guide

## Prerequisites

- PowerShell 5.1+ (`$PSVersionTable.PSVersion`)
- [Pester 5](https://pester.dev/docs/introduction/installation) (`Install-Module Pester -Scope CurrentUser`)
- [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) (`Install-Module PSScriptAnalyzer -Scope CurrentUser`)
- Node.js 18+ (for web smoke tests and dashboard serving)

## Repository setup

```powershell
git clone https://github.com/hetwerk1943/01.git
cd 01
npm install              # installs http-server (dev dependency)
```

## Running tests locally

### PowerShell tests (Pester)

```powershell
Invoke-Pester -Path tests/powershell -Output Detailed
```

### Web smoke checks

```bash
node tools/ci/web-smoke.js
```

### Lint (PSScriptAnalyzer)

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Warning
```

## Module structure

The PowerShell module lives in `src/ultra-security-monitor/`.

- **Private/** – internal helpers, not exported.
- **Public/** – exported functions, one file per function.
- `UltraSecurityMonitor.psm1` – dot-sources everything in the correct order.
- `UltraSecurityMonitor.psd1` – manifest, declares `FunctionsToExport`.

### Adding a new public function

1. Create `src/ultra-security-monitor/Public/Verb-UsmNoun.ps1`.
2. Add `'Verb-UsmNoun'` to the `FunctionsToExport` list in `UltraSecurityMonitor.psd1`.
3. Add tests in `tests/powershell/UltraSecurityMonitor.Tests.ps1`.

### Adding a new private helper

1. Create `src/ultra-security-monitor/Private/HelperName.ps1`.
2. The module root picks it up automatically via glob.

## Coding conventions

- Use `[CmdletBinding()]` on all functions.
- Use `[OutputType([TypeName])]` when the return type is known.
- Prefer named parameters over positional ones.
- Use `Write-UsmLog` instead of bare `Add-Content` for log output.
- Secrets: always read from config or environment variables; never hard-code.
- Path safety: call `Assert-UsmSafePath` before any file write to runtime directories.

## CI

See `.github/workflows/ci.yml`.  
The workflow runs:
1. `PSScriptAnalyzer` on all `.ps1`, `.psm1`, `.psd1` files.
2. `Pester` on `tests/powershell/`.
3. `node tools/ci/web-smoke.js` for web assets.

All checks must pass before a PR can be merged.

## Branching strategy

- `main` – stable, protected branch.
- Feature branches: `feature/<short-description>`.
- Bug fixes: `fix/<short-description>`.
- Open a PR against `main` and fill in the PR template.
