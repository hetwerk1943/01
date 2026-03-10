# Private/Get-UsmWhitelist.ps1
# Whitelist cache loader.

$script:_usmWlCache = $null

function Get-UsmWhitelist {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BaseFolder,

        [string[]]$DefaultWhitelist = @()
    )

    if ($null -ne $script:_usmWlCache) { return $script:_usmWlCache }

    $wlFile = Join-Path $BaseFolder 'whitelist.json'
    if (Test-Path $wlFile) {
        try {
            $script:_usmWlCache = (Get-Content $wlFile -Raw -ErrorAction Stop | ConvertFrom-Json) -as [string[]]
            return $script:_usmWlCache
        } catch {
            Write-Warning "USM: Could not parse whitelist '$wlFile', using defaults."
        }
    }

    $script:_usmWlCache = $DefaultWhitelist
    return $script:_usmWlCache
}

function Clear-UsmWhitelistCache {
    $script:_usmWlCache = $null
}

function Test-UsmPathWhitelisted {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string]$FilePath,
        [string[]]$Whitelist
    )

    if (-not $FilePath) { return $false }
    foreach ($pattern in $Whitelist) {
        if ($FilePath -like $pattern) { return $true }
    }
    return $false
}
