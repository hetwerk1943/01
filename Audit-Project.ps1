# Audit-Project.ps1
# Backward-compatibility shim.
# Deprecation notice: migrate to .\scripts\audit.ps1

#Requires -Version 5.1

Write-Warning "Audit-Project.ps1: this root-level shim is deprecated. Use .\scripts\audit.ps1 instead."

& (Join-Path $PSScriptRoot 'scripts' 'audit.ps1') @args
