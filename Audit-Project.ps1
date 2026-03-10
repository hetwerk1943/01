# Audit-Project.ps1
# Compatibility shim – delegates to scripts/audit.ps1.

#Requires -Version 5.1

$script = Join-Path $PSScriptRoot 'scripts\audit.ps1'
& $script @args
