# Contributing to Ultra Security Monitor

Thank you for your interest in contributing!

## Getting started

1. Fork and clone the repository.
2. Run the setup script to install development tools:
   ```powershell
   .\scripts\setup.ps1 -InstallDevTools
   ```
3. Create a feature branch: `git checkout -b feat/my-feature`.

## Code style

- PowerShell code must pass **PSScriptAnalyzer** with no `Warning` or `Error` level findings.
- Use `CmdletBinding()` and named parameters for all functions.
- Write NDJSON-structured log entries via `Write-UsmLog`.
- Never hard-code credentials; use the config layer or environment variables.

## Testing

Run Pester tests locally before opening a PR:

```powershell
Invoke-Pester -Path tests/powershell -Output Detailed
```

## Security

- Do **not** commit API keys, webhook URLs, passwords, or tokens.
- If you discover a security vulnerability, please report it privately via the [Security tab](../../security) rather than opening a public issue.

## Submitting a PR

- Fill in the pull request template completely.
- Ensure CI passes before requesting review.
- Keep PRs focused – one feature/fix per PR.

## Code of Conduct

Be respectful and constructive. We follow the standard [Contributor Covenant](https://www.contributor-covenant.org/).
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
