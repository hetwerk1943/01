# UltraSecurityMonitor.psm1
# Module root – canonical implementation that dot-sources local Public/ and Private/ scripts.

#Requires -Version 5.1

$ErrorActionPreference = 'Stop'

# Load private helper functions first
$privateFolder = Join-Path -Path $PSScriptRoot -ChildPath 'Private'
if (Test-Path -Path $privateFolder) {
    Get-ChildItem -Path $privateFolder -Filter '*.ps1' -ErrorAction SilentlyContinue | ForEach-Object {
        . $_.FullName
    }
}

# Load public functions
$publicFolder = Join-Path -Path $PSScriptRoot -ChildPath 'Public'
$publicScripts = @()
if (Test-Path -Path $publicFolder) {
    $publicScripts = Get-ChildItem -Path $publicFolder -Filter '*.ps1' -ErrorAction SilentlyContinue
    $publicScripts | ForEach-Object {
        . $_.FullName
    }
}

# Export public functions whose names match the public script basenames
if ($publicScripts) {
    $functionNames = $publicScripts |
        ForEach-Object { $_.BaseName } |
        Where-Object {
            Get-Command -Name $_ -CommandType Function -ErrorAction SilentlyContinue
        }

    if ($functionNames) {
        Export-ModuleMember -Function $functionNames
    }
}
