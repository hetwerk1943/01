# Write-SecureLog.ps1
# Moduł bezpiecznego, odpornego na manipulacje dziennika zdarzeń.
# Każdy wpis jest opatrzony znacznikiem czasu, numerem sekwencyjnym oraz skrótem HMAC-SHA256
# obliczonym z poprzedniego skrótu (łańcuch hashów), co umożliwia wykrycie ingerencji.
# Dołącz ten plik za pomocą: . .\Write-SecureLog.ps1

#Requires -Version 5.1

# --------- KONFIGURACJA ---------
$script:SecureLogPath    = Join-Path $env:TEMP "secure.log"
$script:SecureLogKeyFile = Join-Path $env:TEMP "secure.log.key"
$script:SecureLogSeq     = 0
$script:SecureLogPrevHash = "0" * 64   # genesis hash

function Initialize-SecureLog {
    <#
    .SYNOPSIS
        Inicjalizuje moduł bezpiecznego dziennika.
    .PARAMETER LogPath
        Ścieżka do pliku dziennika.
    .PARAMETER KeyFile
        Ścieżka do pliku z kluczem HMAC (tworzony automatycznie, jeśli nie istnieje).
    #>
    param(
        [string]$LogPath = (Join-Path $env:TEMP "secure.log"),
        [string]$KeyFile = (Join-Path $env:TEMP "secure.log.key")
    )
    $script:SecureLogPath    = $LogPath
    $script:SecureLogKeyFile = $KeyFile
    $script:SecureLogSeq     = 0
    $script:SecureLogPrevHash = "0" * 64

    # Utwórz folder jeśli nie istnieje
    $dir = Split-Path $LogPath -Parent
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }

    # Wygeneruj klucz HMAC (256-bit) jeśli plik nie istnieje
    if (-not (Test-Path $KeyFile)) {
        $keyBytes = New-Object byte[] 32
        [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($keyBytes)
        [System.IO.File]::WriteAllBytes($KeyFile, $keyBytes)
    }
}

function Get-SecureLogKey {
    <#
    .SYNOPSIS
        Odczytuje klucz HMAC z pliku.
    #>
    if (-not (Test-Path $script:SecureLogKeyFile)) {
        Initialize-SecureLog -LogPath $script:SecureLogPath -KeyFile $script:SecureLogKeyFile
    }
    return [System.IO.File]::ReadAllBytes($script:SecureLogKeyFile)
}

function Compute-HmacSHA256 {
    <#
    .SYNOPSIS
        Oblicza HMAC-SHA256 dla podanego ciągu znaków i klucza.
    #>
    param([string]$Data, [byte[]]$Key)
    $hmac   = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key = $Key
    $bytes  = [System.Text.Encoding]::UTF8.GetBytes($Data)
    $hash   = $hmac.ComputeHash($bytes)
    $hmac.Dispose()
    return ([System.BitConverter]::ToString($hash) -replace '-','').ToLowerInvariant()
}

function Write-SecureLog {
    <#
    .SYNOPSIS
        Zapisuje wpis do bezpiecznego dziennika z HMAC-SHA256 i numerem sekwencyjnym.
    .PARAMETER Message
        Treść wpisu dziennika.
    .PARAMETER Severity
        Poziom ważności: Info | Warning | Error | Critical. Domyślnie: Info.
    #>
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet("Info","Warning","Error","Critical")][string]$Severity = "Info"
    )

    if ([string]::IsNullOrWhiteSpace($script:SecureLogPath)) {
        Initialize-SecureLog
    }

    $script:SecureLogSeq++
    $ts      = (Get-Date).ToString("o")
    $rawLine = "$ts`t$($script:SecureLogSeq)`t$Severity`t$Message"

    try {
        $key      = Get-SecureLogKey
        $dataForHmac = "$($script:SecureLogPrevHash)|$rawLine"
        $hmac     = Compute-HmacSHA256 -Data $dataForHmac -Key $key
        $script:SecureLogPrevHash = $hmac
        $logLine  = "$rawLine`t$hmac"
        Add-Content -Path $script:SecureLogPath -Value $logLine
    } catch {
        # Fallback: zapis bez HMAC jeśli coś pójdzie nie tak
        Add-Content -Path $script:SecureLogPath -Value "$rawLine`tHMAC-ERROR"
    }
}

function Test-SecureLogIntegrity {
    <#
    .SYNOPSIS
        Weryfikuje integralność pliku dziennika, sprawdzając łańcuch HMAC.
    .PARAMETER LogPath
        Ścieżka do pliku dziennika (domyślnie: bieżąco skonfigurowana).
    .OUTPUTS
        PSCustomObject z polami: IsValid (bool), TamperedLines (int[]), TotalLines (int)
    #>
    param([string]$LogPath = "")
    if ([string]::IsNullOrWhiteSpace($LogPath)) { $LogPath = $script:SecureLogPath }
    if (-not (Test-Path $LogPath)) {
        return [PSCustomObject]@{ IsValid = $true; TamperedLines = @(); TotalLines = 0 }
    }

    $key          = Get-SecureLogKey
    $prevHash     = "0" * 64
    $lineNum      = 0
    $tamperedLines = @()

    Get-Content -Path $LogPath -ErrorAction SilentlyContinue | ForEach-Object {
        $lineNum++
        $parts = $_ -split "`t"
        if ($parts.Count -lt 5) { $tamperedLines += $lineNum; return }
        $storedHmac = $parts[-1]
        $rawLine    = ($parts[0..($parts.Count - 2)] -join "`t")
        $dataForHmac = "$prevHash|$rawLine"
        $expectedHmac = Compute-HmacSHA256 -Data $dataForHmac -Key $key
        if ($storedHmac -ne $expectedHmac) { $tamperedLines += $lineNum }
        $prevHash = $storedHmac
    }

    return [PSCustomObject]@{
        IsValid       = ($tamperedLines.Count -eq 0)
        TamperedLines = $tamperedLines
        TotalLines    = $lineNum
    }
}
