# masterAgent.ps1
# Compatibility shim – delegates to scripts/run-monitor.ps1 master-agent functions.
# Use -UpdateSponsors, -BackupLogs, -AutoEnhance, -MarketAnalysis switches.

#Requires -Version 5.1

param(
    [switch]$UpdateSponsors,
    [switch]$BackupLogs,
    [switch]$AutoEnhance,
    [switch]$MarketAnalysis
)

$script = Join-Path $PSScriptRoot 'scripts\run-monitor.ps1'
& $script -MasterAgent `
    -UpdateSponsors:$UpdateSponsors `
    -BackupLogs:$BackupLogs `
    -AutoEnhance:$AutoEnhance `
    -MarketAnalysis:$MarketAnalysis
