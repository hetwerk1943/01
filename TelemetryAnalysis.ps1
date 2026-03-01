# TelemetryAnalysis.ps1
# Telemetry persistence and sandbox analysis orchestration module.
# Requires -Version 5.1

param(
    [hashtable]$Telemetry
)

# --------- KONFIGURACJA ---------
$BaseFolder = Join-Path $env:USERPROFILE "Documents\SecurityMonitor"
$SiemFolder = Join-Path $BaseFolder "SIEM"
$SandboxFolder = Join-Path $BaseFolder "Sandbox"

foreach ($dir in @($BaseFolder, $SiemFolder, $SandboxFolder)) {
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
}

$SiemLogPath    = Join-Path $SiemFolder  "siem.json"
$SandboxLogPath = Join-Path $SandboxFolder "sandbox-results.json"

# Sandbox heuristics (can be extended)
$SandboxSuspiciousPaths     = @("*\AppData\Local\Temp\*", "*\Temp\*", "*\AppData\Roaming\*")
$SandboxHighRiskProcessNames = @("wscript.exe", "cscript.exe", "mshta.exe", "rundll32.exe")

# --------- JWT VALIDATION ---------
function ConvertFrom-Base64Url {
    param([string]$Base64Url)
    # Pad to a multiple of 4 and replace URL-safe characters
    $base64 = $Base64Url -replace '-', '+' -replace '_', '/'
    $pad = 4 - ($base64.Length % 4)
    if ($pad -lt 4) { $base64 += '=' * $pad }
    return [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($base64))
}

function Validate-JWT {
    param([string]$Token)

    if ([string]::IsNullOrWhiteSpace($Token)) {
        Write-Warning "JWT validation failed: token is empty."
        return $false
    }

    $parts = $Token.Split('.')
    if ($parts.Count -ne 3) {
        Write-Warning "JWT validation failed: token does not have 3 parts."
        return $false
    }

    # Decode header and payload
    try {
        $headerJson  = ConvertFrom-Base64Url -Base64Url $parts[0]
        $payloadJson = ConvertFrom-Base64Url -Base64Url $parts[1]
        $header  = $headerJson  | ConvertFrom-Json
        $payload = $payloadJson | ConvertFrom-Json
    } catch {
        Write-Warning "JWT validation failed: could not decode header/payload. $_"
        return $false
    }

    # Verify algorithm is HMAC-SHA256
    if ($header.alg -ne 'HS256') {
        Write-Warning "JWT validation failed: unsupported algorithm '$($header.alg)'."
        return $false
    }

    # Verify expiry
    if ($null -ne $payload.exp) {
        $expiry = [DateTimeOffset]::FromUnixTimeSeconds([long]$payload.exp).UtcDateTime
        if ([datetime]::UtcNow -gt $expiry) {
            Write-Warning "JWT validation failed: token has expired (exp=$($payload.exp))."
            return $false
        }
    }

    # Verify HMAC-SHA256 signature using JWT_SECRET environment variable
    $secret = $env:JWT_SECRET
    if ([string]::IsNullOrWhiteSpace($secret)) {
        Write-Warning "JWT validation failed: JWT_SECRET environment variable is not set."
        return $false
    }

    try {
        $signingInput = "$($parts[0]).$($parts[1])"
        $keyBytes     = [System.Text.Encoding]::UTF8.GetBytes($secret)
        $inputBytes   = [System.Text.Encoding]::UTF8.GetBytes($signingInput)
        $hmac         = New-Object System.Security.Cryptography.HMACSHA256
        $hmac.Key     = $keyBytes
        $computedHash = $hmac.ComputeHash($inputBytes)
        $computedSig  = [Convert]::ToBase64String($computedHash) `
                            -replace '\+', '-' -replace '/', '_' -replace '=', ''
        if ($computedSig -ne $parts[2]) {
            Write-Warning "JWT validation failed: signature mismatch."
            return $false
        }
    } catch {
        Write-Warning "JWT validation failed: signature verification error. $_"
        return $false
    }

    return $true
}

# --------- AUTH GUARD ---------
if (-not (Validate-JWT -Token $env:AUTH_HEADER)) {
    Write-Output "Unauthorized"
    exit 1
}

# --------- TELEMETRY PERSISTENCE ---------
function Save-Telemetry {
    param([hashtable]$Data)

    if ($null -eq $Data -or $Data.Count -eq 0) { return }

    $event = [ordered]@{
        timestamp  = (Get-Date).ToString("o")
        host       = $env:COMPUTERNAME
        user       = $env:USERNAME
        event_type = "Telemetry"
        severity   = "Info"
        data       = $Data
    }
    try {
        Add-Content -Path $SiemLogPath -Value ($event | ConvertTo-Json -Compress)
    } catch {
        Write-Warning "Save-Telemetry: failed to write SIEM log. $_"
    }
}

# --------- SANDBOX ANALYSIS ---------
function Invoke-SandboxAnalysis {
    param([hashtable]$Data)

    # Extract indicators of interest from telemetry
    $fileHash   = $Data['hash']
    $filePath   = $Data['path']
    $processName = $Data['process']

    $result = [ordered]@{
        timestamp   = (Get-Date).ToString("o")
        host        = $env:COMPUTERNAME
        analyzed    = @()
        conclusions = @()
    }

    # File hash analysis
    if (-not [string]::IsNullOrWhiteSpace($fileHash)) {
        $result.analyzed += "hash:$fileHash"

        # Check against known malicious hash patterns (placeholder – integrate with threat intel feed)
        $result.conclusions += "Hash $fileHash submitted for sandbox review."
    }

    # File path analysis
    if (-not [string]::IsNullOrWhiteSpace($filePath)) {
        $result.analyzed += "path:$filePath"

        $suspiciousPaths = $SandboxSuspiciousPaths
        foreach ($pattern in $suspiciousPaths) {
            if ($filePath -like $pattern) {
                $result.conclusions += "File path '$filePath' matches suspicious pattern '$pattern'."
                break
            }
        }

        # Check digital signature
        if (Test-Path $filePath) {
            try {
                $sig = Get-AuthenticodeSignature -FilePath $filePath -ErrorAction SilentlyContinue
                $sigStatus = if ($null -ne $sig) { $sig.Status.ToString() } else { "no-signature" }
                $result.conclusions += "Signature status for '$filePath': $sigStatus"
            } catch {
                $result.conclusions += "Signature check failed for '$filePath'."
            }
        }
    }

    # Process name analysis
    if (-not [string]::IsNullOrWhiteSpace($processName)) {
        $result.analyzed += "process:$processName"
        $knownSuspicious = $SandboxHighRiskProcessNames
        if ($knownSuspicious -contains $processName.ToLower()) {
            $result.conclusions += "Process '$processName' is flagged as high-risk."
        }
    }

    # Persist sandbox results
    try {
        Add-Content -Path $SandboxLogPath -Value ($result | ConvertTo-Json -Compress)
    } catch {
        Write-Warning "Invoke-SandboxAnalysis: failed to write sandbox log. $_"
    }

    return $result
}

# --------- MAIN: PERSIST TELEMETRY + ORCHESTRATE SANDBOX ANALYSIS ---------
Save-Telemetry -Data $Telemetry

$sandboxResult = Invoke-SandboxAnalysis -Data $Telemetry
if ($sandboxResult.conclusions.Count -gt 0) {
    Write-Output "Sandbox analysis conclusions:"
    $sandboxResult.conclusions | ForEach-Object { Write-Output "  - $_" }
} else {
    Write-Output "Sandbox analysis: no suspicious indicators found."
}
