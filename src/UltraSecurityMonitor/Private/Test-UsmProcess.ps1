# Private\Test-UsmProcess.ps1
# Whitelist management and process suspicion heuristics.

function Get-UsmWhitelist {
    [CmdletBinding()]
    param()

    if ($null -ne $script:_wlCache) { return $script:_wlCache }

    $wlFile = $script:_config.WhitelistPath
    if (Test-Path $wlFile) {
        try {
            $loaded = (Get-Content $wlFile -Raw -ErrorAction Stop | ConvertFrom-Json) -as [string[]]
            $script:_wlCache = $loaded
            return $script:_wlCache
        } catch {
            Write-UsmLog -Message "Get-UsmWhitelist: failed to parse $wlFile – $_" -Level WARN
        }
    }

    $script:_wlCache = $script:_config.DefaultWhitelist
    return $script:_wlCache
}

function Test-UsmPathWhitelisted {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$Whitelist
    )
    if (-not $FilePath) { return $false }
    foreach ($pattern in $Whitelist) {
        if ($FilePath -like $pattern) { return $true }
    }
    return $false
}

function Test-UsmProcessSuspicious {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProcName,
        [string]$FilePath
    )

    $cfg = $script:_config
    $wl  = Get-UsmWhitelist

    if (Test-UsmPathWhitelisted -FilePath $FilePath -Whitelist $wl) { return $false }

    foreach ($p in $cfg.SuspiciousPathPatterns) {
        if ($FilePath -like $p) { return $true }
    }
    foreach ($n in $cfg.SuspiciousNames) {
        if ($ProcName -ieq $n) { return $true }
    }

    if ($FilePath -and
        -not ($FilePath -like "$env:windir\*") -and
        -not ($FilePath -like "$env:ProgramFiles\*") -and
        -not ($FilePath -like "${env:ProgramFiles(x86)}\*")) {
        return $true
    }

    return $false
}
