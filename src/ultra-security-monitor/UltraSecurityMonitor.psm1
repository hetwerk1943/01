# UltraSecurityMonitor.psm1
# Module root – dot-sources Private helpers then Public functions.

#Requires -Version 5.1

$Private = Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue
$Public  = Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1"  -ErrorAction SilentlyContinue

foreach ($file in @($Private) + @($Public)) {
    try {
        . $file.FullName
    } catch {
        Write-Error "Failed to dot-source '$($file.FullName)': $_"
    }
}

Export-ModuleMember -Function $Public.BaseName
