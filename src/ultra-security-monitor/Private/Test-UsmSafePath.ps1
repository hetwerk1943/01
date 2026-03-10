# Private/Test-UsmSafePath.ps1
# Safe-path guardrails: ensure file operations stay within an allowed base folder.

function Test-UsmSafePath {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$BaseFolder
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }

    # Resolve both paths to their full absolute forms, normalising case on Windows
    try {
        $resolvedBase = [System.IO.Path]::GetFullPath($BaseFolder).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
        $resolvedPath = [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    } catch {
        return $false
    }

    # Case-insensitive comparison on Windows
    $comparison = if ($IsWindows -or -not $IsLinux) {
        [System.StringComparison]::OrdinalIgnoreCase
    } else {
        [System.StringComparison]::Ordinal
    }

    return $resolvedPath.StartsWith($resolvedBase + [System.IO.Path]::DirectorySeparatorChar, $comparison) `
        -or $resolvedPath.Equals($resolvedBase, $comparison)
}

function Assert-UsmSafePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$BaseFolder
    )

    if (-not (Test-UsmSafePath -Path $Path -BaseFolder $BaseFolder)) {
        throw "USM: Path '$Path' is outside the allowed base folder '$BaseFolder'. Operation blocked."
    }
}
