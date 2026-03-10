# Private\Assert-UsmSafePath.ps1
# Path safety guardrail – ensures file operations stay inside BaseFolder.

function Assert-UsmSafePath {
    <#
    .SYNOPSIS
        Throws if the resolved path is outside the allowed BaseFolder tree.
    .DESCRIPTION
        Resolves both paths and performs a prefix check so that path-traversal
        sequences (e.g. "..\..\Windows") cannot escape the sandbox.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$BaseFolder
    )

    # Resolve to absolute without requiring the path to exist yet
    $resolvedTarget = [System.IO.Path]::GetFullPath($Path)
    $resolvedBase   = [System.IO.Path]::GetFullPath($BaseFolder).TrimEnd([System.IO.Path]::DirectorySeparatorChar) `
                      + [System.IO.Path]::DirectorySeparatorChar

    if (-not $resolvedTarget.StartsWith($resolvedBase, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path safety violation: '$resolvedTarget' is outside the allowed base folder '$resolvedBase'."
    }
}

function Test-UsmSafePath {
    <#
    .SYNOPSIS
        Returns $true if the path is inside BaseFolder; $false otherwise.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$BaseFolder
    )
    try {
        Assert-UsmSafePath -Path $Path -BaseFolder $BaseFolder
        return $true
    } catch {
        return $false
    }
}
