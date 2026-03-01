# SecureEndpoint.ps1
# mTLS + JWT protected endpoint for Ultra Security Monitor
# Requires -Version 5.1

param([hashtable]$Payload)

# --------- KONFIGURACJA ---------
$BaseFolder  = Join-Path $env:USERPROFILE "Documents\SecurityMonitor"
$SiemFolder  = Join-Path $BaseFolder "SIEM"
$SiemLogPath = Join-Path $SiemFolder "siem.json"

# HMAC-SHA256 secret shared between server and authorised callers.
# The SECURE_ENDPOINT_HMAC_SECRET environment variable MUST be set before launching this script.
if (-not $env:SECURE_ENDPOINT_HMAC_SECRET) {
    throw "SECURE_ENDPOINT_HMAC_SECRET environment variable is not set. Aborting to prevent authentication bypass."
}
$HmacSecret = $env:SECURE_ENDPOINT_HMAC_SECRET

# --------- SHARED SIEM WRITER ---------
function Write-SiemEvent {
    param([string]$EventType, [string]$Severity, [hashtable]$Data)
    if (-not (Test-Path $SiemFolder)) {
        New-Item -Path $SiemFolder -ItemType Directory -Force | Out-Null
    }
    $event = [ordered]@{
        timestamp  = (Get-Date).ToString("o")
        host       = $env:COMPUTERNAME
        user       = $env:USERNAME
        event_type = $EventType
        severity   = $Severity
        data       = $Data
    }
    try {
        Add-Content -Path $SiemLogPath -Value ($event | ConvertTo-Json -Compress)
    } catch {
        # Surface SIEM write failures so operators are aware the audit trail is incomplete.
        Write-Warning "SIEM write failed for event '$EventType': $_"
    }}

# --------- mTLS VALIDATION ---------
function Test-ClientCertificate {
    <#
    .SYNOPSIS
        Validates a client X.509 certificate for mTLS.
    .PARAMETER Certificate
        The X509Certificate2 presented by the client.
    .PARAMETER TrustedThumbprints
        Array of SHA-1 thumbprints (hex, no spaces) that are authorised.
    #>
    param(
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,
        [string[]]$TrustedThumbprints
    )

    if ($null -eq $Certificate) {
        Write-SiemEvent -EventType "mTLS_Rejected" -Severity "High" `
            -Data @{ reason = "no_client_certificate" }
        return $false
    }

    # Verify the certificate has not expired
    $now = Get-Date
    if ($now -lt $Certificate.NotBefore -or $now -gt $Certificate.NotAfter) {
        Write-SiemEvent -EventType "mTLS_Rejected" -Severity "High" `
            -Data @{ reason = "certificate_expired"; thumbprint = $Certificate.Thumbprint }
        return $false
    }

    # Verify chain.
    # RevocationMode is set to NoCheck because this endpoint may run without internet access
    # and CRL/OCSP endpoints may not be reachable; operators should compensate by keeping the
    # TrustedThumbprints allow-list current and revoking certificates by removing their thumbprints.
    $chain = New-Object System.Security.Cryptography.X509Certificates.X509Chain
    $chain.ChainPolicy.RevocationMode = [System.Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
    $chainValid = $chain.Build($Certificate)
    if (-not $chainValid) {
        Write-SiemEvent -EventType "mTLS_Rejected" -Severity "High" `
            -Data @{ reason = "chain_invalid"; thumbprint = $Certificate.Thumbprint }
        return $false
    }

    # Verify thumbprint against allow-list
    $thumb = $Certificate.Thumbprint.ToUpper() -replace '\s', ''
    $allowed = $TrustedThumbprints | ForEach-Object { $_.ToUpper() -replace '\s', '' }
    if ($thumb -notin $allowed) {
        Write-SiemEvent -EventType "mTLS_Rejected" -Severity "High" `
            -Data @{ reason = "thumbprint_not_trusted"; thumbprint = $thumb }
        return $false
    }

    Write-SiemEvent -EventType "mTLS_Accepted" -Severity "Info" `
        -Data @{ thumbprint = $thumb; subject = $Certificate.Subject }
    return $true
}

# --------- JWT + HMAC VALIDATION ---------
function ConvertFrom-Base64Url {
    param([string]$Encoded)
    $padded = $Encoded.Replace('-', '+').Replace('_', '/')
    switch ($padded.Length % 4) {
        2 { $padded += '==' }
        3 { $padded += '=' }
    }
    return [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($padded))
}

function Test-JwtToken {
    <#
    .SYNOPSIS
        Validates a JWT (HS256) token using HMAC-SHA256.
    .PARAMETER Token
        The raw JWT string (header.payload.signature).
    .PARAMETER Secret
        The HMAC-SHA256 shared secret.
    .OUTPUTS
        [hashtable] with keys: Valid (bool), Claims (hashtable).
    #>
    param(
        [string]$Token,
        [string]$Secret
    )

    $result = @{ Valid = $false; Claims = $null }

    if ([string]::IsNullOrWhiteSpace($Token)) {
        Write-SiemEvent -EventType "JWT_Rejected" -Severity "High" `
            -Data @{ reason = "empty_token" }
        return $result
    }

    $parts = $Token.Split('.')
    if ($parts.Count -ne 3) {
        Write-SiemEvent -EventType "JWT_Rejected" -Severity "High" `
            -Data @{ reason = "malformed_token" }
        return $result
    }

    # Parse header
    try {
        $header = ConvertFrom-Base64Url $parts[0] | ConvertFrom-Json
    } catch {
        Write-SiemEvent -EventType "JWT_Rejected" -Severity "High" `
            -Data @{ reason = "header_parse_error" }
        return $result
    }

    if ($header.alg -ne 'HS256') {
        Write-SiemEvent -EventType "JWT_Rejected" -Severity "High" `
            -Data @{ reason = "unsupported_algorithm"; alg = $header.alg }
        return $result
    }

    # Verify HMAC-SHA256 signature
    $signingInput = "$($parts[0]).$($parts[1])"
    $keyBytes     = [System.Text.Encoding]::UTF8.GetBytes($Secret)
    $msgBytes     = [System.Text.Encoding]::UTF8.GetBytes($signingInput)
    $hmac         = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key     = $keyBytes
    $computedSig  = [Convert]::ToBase64String($hmac.ComputeHash($msgBytes))
    $computedSig  = $computedSig.TrimEnd('=').Replace('+', '-').Replace('/', '_')

    if ($computedSig -ne $parts[2]) {
        Write-SiemEvent -EventType "JWT_Rejected" -Severity "High" `
            -Data @{ reason = "signature_mismatch" }
        return $result
    }

    # Parse claims
    try {
        $claims = ConvertFrom-Base64Url $parts[1] | ConvertFrom-Json
    } catch {
        Write-SiemEvent -EventType "JWT_Rejected" -Severity "High" `
            -Data @{ reason = "claims_parse_error" }
        return $result
    }

    # Verify expiry (exp claim, Unix timestamp)
    $unixNow = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if ($null -ne $claims.exp -and $claims.exp -lt $unixNow) {
        Write-SiemEvent -EventType "JWT_Rejected" -Severity "High" `
            -Data @{ reason = "token_expired"; exp = $claims.exp }
        return $result
    }

    # Verify not-before (nbf claim)
    if ($null -ne $claims.nbf -and $claims.nbf -gt $unixNow) {
        Write-SiemEvent -EventType "JWT_Rejected" -Severity "High" `
            -Data @{ reason = "token_not_yet_valid"; nbf = $claims.nbf }
        return $result
    }

    Write-SiemEvent -EventType "JWT_Accepted" -Severity "Info" `
        -Data @{ sub = $claims.sub; jti = $claims.jti }

    $result.Valid  = $true
    $result.Claims = $claims
    return $result
}

# --------- OPERATOR CONFIRMATION ---------
function Confirm-OperatorAction {
    <#
    .SYNOPSIS
        Prompts the operator for explicit confirmation before executing a payload.
    .PARAMETER Description
        Short human-readable description of the action to be confirmed.
    #>
    param([string]$Description)

    Write-Host ""
    Write-Host "⚠️  OPERATOR CONFIRMATION REQUIRED" -ForegroundColor Yellow
    Write-Host "   Action : $Description" -ForegroundColor Yellow
    Write-Host "   Type 'YES' (all caps) to proceed, anything else to abort:" -ForegroundColor Yellow
    $answer = Read-Host "Confirm"
    return ($answer -ceq 'YES')
}

# --------- SANDBOX ORCHESTRATION ---------
function Invoke-SandboxedPayload {
    <#
    .SYNOPSIS
        Executes a payload hashtable inside a constrained PowerShell runspace
        (no file-system or network access) and returns its output.
    .PARAMETER Payload
        Hashtable describing the action to execute. Must contain key 'ScriptBlock'
        with the script text to run.
    .PARAMETER Claims
        The validated JWT claims hashtable, forwarded to the sandbox as read-only.
    #>
    param(
        [hashtable]$Payload,
        [object]$Claims
    )

    if (-not $Payload.ContainsKey('ScriptBlock')) {
        Write-SiemEvent -EventType "Sandbox_InvalidPayload" -Severity "High" `
            -Data @{ reason = "missing_ScriptBlock_key" }
        throw "Payload must contain a 'ScriptBlock' key."
    }

    # Build a constrained runspace using the RemoteServer capability.
    # This profile restricts the available command set to a safe subset:
    # core language elements and a limited selection of safe cmdlets are allowed;
    # direct file-system providers, network cmdlets, and external process execution
    # are not available in this session state.
    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateRestricted(
        [System.Management.Automation.SessionCapabilities]::RemoteServer
    )
    $rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($iss)
    $rs.Open()

    try {
        $ps = [System.Management.Automation.PowerShell]::Create()
        $ps.Runspace = $rs

        # Inject validated claims as a read-only variable
        $ps.AddScript('param($Claims, $PayloadData)') | Out-Null
        $ps.AddScript($Payload.ScriptBlock) | Out-Null
        $ps.AddParameter('Claims',      $Claims)  | Out-Null
        $ps.AddParameter('PayloadData', $Payload) | Out-Null

        $output = $ps.Invoke()

        if ($ps.HadErrors) {
            $errs = $ps.Streams.Error | ForEach-Object { $_.ToString() }
            Write-SiemEvent -EventType "Sandbox_Error" -Severity "Medium" `
                -Data @{ errors = ($errs -join '; ') }
            throw "Sandbox execution errors: $($errs -join '; ')"
        }

        Write-SiemEvent -EventType "Sandbox_Success" -Severity "Info" `
            -Data @{ sub = $Claims.sub; action = $Payload.Action }

        return $output
    } finally {
        $rs.Close()
    }
}

# --------- MAIN ENTRY POINT ---------
function Invoke-SecureEndpoint {
    <#
    .SYNOPSIS
        Main protected endpoint: validates mTLS cert + JWT, confirms with operator,
        then executes the payload inside a sandbox and records every step to SIEM.
    .PARAMETER Payload
        Hashtable containing:
          JwtToken          - raw JWT string
          ClientCertificate - X509Certificate2 used for mTLS
          TrustedThumbprints- string[] of allowed cert thumbprints
          ScriptBlock       - PowerShell script text to run in sandbox
          Action            - (optional) human-readable description of the action
          [any other keys]  - forwarded to sandbox as PayloadData
    #>
    param([hashtable]$Payload)

    if ($null -eq $Payload) {
        Write-SiemEvent -EventType "Endpoint_Error" -Severity "High" `
            -Data @{ reason = "null_payload" }
        throw "Payload cannot be null."
    }

    # --- 1. mTLS validation ---
    $cert        = $Payload['ClientCertificate']
    $thumbprints = $Payload['TrustedThumbprints']
    if (-not (Test-ClientCertificate -Certificate $cert -TrustedThumbprints $thumbprints)) {
        throw "mTLS validation failed."
    }

    # --- 2. JWT + HMAC validation ---
    $jwtToken = $Payload['JwtToken']
    $jwtResult = Test-JwtToken -Token $jwtToken -Secret $HmacSecret
    if (-not $jwtResult.Valid) {
        throw "JWT validation failed."
    }

    # --- 3. Record validated request to central event database (SIEM) ---
    Write-SiemEvent -EventType "Endpoint_RequestReceived" -Severity "Info" `
        -Data @{
            sub    = $jwtResult.Claims.sub
            action = if ($Payload['Action']) { $Payload['Action'] } else { "unspecified" }
            thumb  = $cert.Thumbprint
        }

    # --- 4. Operator confirmation ---
    $actionDesc = if ($Payload['Action']) { $Payload['Action'] } else { "Execute sandboxed payload" }
    $confirmed  = Confirm-OperatorAction -Description $actionDesc
    if (-not $confirmed) {
        Write-SiemEvent -EventType "Endpoint_Aborted" -Severity "Medium" `
            -Data @{ reason = "operator_denied"; action = $actionDesc }
        throw "Operator confirmation denied."
    }

    # --- 5. Sandbox orchestration ---
    $output = Invoke-SandboxedPayload -Payload $Payload -Claims $jwtResult.Claims

    Write-SiemEvent -EventType "Endpoint_Completed" -Severity "Info" `
        -Data @{ action = $actionDesc; sub = $jwtResult.Claims.sub }

    return $output
}

# Run if a Payload was supplied directly (e.g. when dot-sourced with -Payload argument)
if ($PSBoundParameters.ContainsKey('Payload') -and $null -ne $Payload) {
    Invoke-SecureEndpoint -Payload $Payload
}
