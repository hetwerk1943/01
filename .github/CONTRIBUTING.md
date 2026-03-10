# Contributing to Ultra Security Monitor

Thank you for considering a contribution!

## How to contribute

1. **Fork** the repository and create a feature branch from `main`.
2. Make your changes following the guidelines below.
3. Open a **Pull Request** against `main` and fill in the PR template.

## Code style

- PowerShell: follow [PowerShell Best Practices](https://poshcode.gitbook.io/powershell-practice-and-style/).
- Run `PSScriptAnalyzer` before submitting (`Invoke-ScriptAnalyzer -Path . -Recurse -Severity Warning`).
- JavaScript: keep it minimal and dependency-free where possible.

## Testing

- Add or update Pester tests in `tests/powershell/` for any PowerShell changes.
- Run `node tools/ci/web-smoke.js` to verify web assets.

## Security

- **Never commit secrets**, tokens, API keys, or passwords.
- Always use environment variables (`USM_DISCORD_WEBHOOK_URL`, `USM_VT_API_KEY`, etc.).
- See `docs/QUICK_START.md` for the full list of supported environment variables.

## Reporting security vulnerabilities

Please do **not** open a public issue for security vulnerabilities.  
Instead, follow the process described in [SECURITY.md](../SECURITY.md).
