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
