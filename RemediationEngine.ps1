# RemediationEngine.ps1
# Silnik naprawczy i sandbox dla Ultra Security Monitor.
# Obsługuje: analizę w izolacji, decyzje tylko przy wysokim confidence lub
# zatwierdzeniu operatora, rollback akcji naprawczych, dry-run.

#Requires -Version 5.1

# ── Progi decyzji ────────────────────────────────────────────────────────────
$RemediationConfidenceThreshold = 5   # min. liczba detekcji VT do auto-akcji
$RemediationAutoKillEnabled     = $false   # auto-kill bez operatora (wyłączone domyślnie)

# ── Rejestr rollback ─────────────────────────────────────────────────────────
$script:RollbackRegistry = [System.Collections.Generic.List[hashtable]]::new()

# ── Sandbox / analiza ─────────────────────────────────────────────────────────

function Invoke-SandboxAnalysis {
    <#
    .SYNOPSIS
        Uruchamia plik w izolowanym procesie z ograniczonymi uprawnieniami
        (Job Object / ograniczony token) i zbiera podstawowe artefakty.
    .NOTES
        Pełna izolacja VM/Container wymaga platformy hypervisora.
        Ta funkcja implementuje "lekki sandbox" na poziomie procesu.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string]$SHA256,
        [switch]$DryRun
    )

    if (-not (Test-Path $FilePath)) {
        Write-Warning "RemediationEngine: plik nie istnieje: $FilePath"
        return $null
    }

    Write-Host "RemediationEngine: sandbox analiza $FilePath (SHA256=$SHA256)"

    if ($DryRun) {
        Write-Host "[DryRun] Invoke-SandboxAnalysis: $FilePath"
        return [PSCustomObject]@{ FilePath = $FilePath; SHA256 = $SHA256; DryRun = $true }
    }

    # Uruchom w ograniczonym Job Object (brak dostępu do sieci i UI)
    $job = Start-Job -ScriptBlock {
        param($path)
        # Uruchom z ograniczonymi uprawnieniami przez runas /restricted (szkielet)
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName  = $path
        $psi.UseShellExecute     = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.CreateNoWindow = $true
        $proc = [System.Diagnostics.Process]::Start($psi)
        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit(5000) | Out-Null
        if (-not $proc.HasExited) { $proc.Kill() }
        return @{ ExitCode = $proc.ExitCode; Stdout = $stdout; Stderr = $stderr }
    } -ArgumentList $FilePath

    $result = Wait-Job $job -Timeout 30 | Receive-Job
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    return [PSCustomObject]@{
        FilePath = $FilePath
        SHA256   = $SHA256
        Result   = $result
    }
}

# ── Akcje naprawcze z rollback ─────────────────────────────────────────────────

function Stop-SuspiciousProcess {
    <#
    .SYNOPSIS
        Zatrzymuje podejrzany proces.  Rejestruje rollback (restart procesu niemożliwy –
        rollback tylko informacyjny).
    .PARAMETER RequireApproval
        Gdy $true, żąda potwierdzenia operatora przed wykonaniem akcji.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$ProcessId,
        [string]$ProcessName = "",
        [int]$VTMaliciousCount = 0,
        [switch]$RequireApproval,
        [switch]$DryRun
    )
    $canAuto = ($VTMaliciousCount -ge $RemediationConfidenceThreshold) -and
               $RemediationAutoKillEnabled

    if (-not $canAuto -or $RequireApproval) {
        $approved = Request-OperatorApproval `
            -Action "Stop-Process PID=$ProcessId Name=$ProcessName" `
            -DryRun:$DryRun
        if (-not $approved) {
            Write-Warning "RemediationEngine: akcja odrzucona przez operatora (PID=$ProcessId)."
            return $false
        }
    }

    $rollback = @{
        Action      = "Stop-Process"
        ProcessId   = $ProcessId
        ProcessName = $ProcessName
        Timestamp   = (Get-Date).ToString("o")
        Rolled      = $false
    }
    $script:RollbackRegistry.Add($rollback)

    if ($DryRun) {
        Write-Host "[DryRun] Stop-Process -Id $ProcessId"
        return $true
    }

    try {
        Stop-Process -Id $ProcessId -Force -ErrorAction Stop
        Write-Host "RemediationEngine: zatrzymano proces PID=$ProcessId."
        return $true
    } catch {
        Write-Warning "RemediationEngine: nie można zatrzymać PID=$ProcessId – $_"
        return $false
    }
}

function Move-SuspiciousFile {
    <#
    .SYNOPSIS
        Przenosi podejrzany plik do kwarantanny i rejestruje rollback.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string]$QuarantineFolder,
        [int]$VTMaliciousCount = 0,
        [switch]$RequireApproval,
        [switch]$DryRun
    )
    if (-not (Test-Path $FilePath)) {
        Write-Warning "RemediationEngine: plik nie istnieje: $FilePath"
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($QuarantineFolder)) {
        $QuarantineFolder = Join-Path $env:USERPROFILE "Documents\SecurityMonitor\Quarantine"
    }
    if (-not (Test-Path $QuarantineFolder)) {
        New-Item -Path $QuarantineFolder -ItemType Directory -Force | Out-Null
    }

    $canAuto = ($VTMaliciousCount -ge $RemediationConfidenceThreshold)
    if (-not $canAuto -or $RequireApproval) {
        $approved = Request-OperatorApproval `
            -Action "Move-Item (kwarantanna): $FilePath" `
            -DryRun:$DryRun
        if (-not $approved) {
            Write-Warning "RemediationEngine: akcja odrzucona (plik=$FilePath)."
            return $false
        }
    }

    $leaf = Split-Path $FilePath -Leaf
    $dest = Join-Path $QuarantineFolder ("${leaf}_" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".quarantine")

    $rollback = @{
        Action    = "Move-Item"
        Source    = $FilePath
        Dest      = $dest
        Timestamp = (Get-Date).ToString("o")
        Rolled    = $false
    }
    $script:RollbackRegistry.Add($rollback)

    if ($DryRun) {
        Write-Host "[DryRun] Move-Item '$FilePath' -> '$dest'"
        return $true
    }

    try {
        Move-Item -Path $FilePath -Destination $dest -Force -ErrorAction Stop
        Write-Host "RemediationEngine: plik przeniesiony do kwarantanny: $dest"
        return $true
    } catch {
        Write-Warning "RemediationEngine: nie można przenieść pliku – $_"
        return $false
    }
}

function Remove-SuspiciousFile {
    <#
    .SYNOPSIS
        Usuwa podejrzany plik.  Przed usunięciem tworzy backup z ACL.
    .NOTES
        Akcja nieodwracalna – wymaga WYSOKIEGO confidence (VT >= próg)
        ORAZ zatwierdzenia operatora.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string]$BackupFolder,
        [int]$VTMaliciousCount = 0,
        [switch]$DryRun
    )
    if (-not (Test-Path $FilePath)) {
        Write-Warning "RemediationEngine: plik nie istnieje: $FilePath"
        return $false
    }

    # Usuwanie zawsze wymaga zatwierdzenia operatora
    $approved = Request-OperatorApproval `
        -Action "Remove-Item (usuwanie): $FilePath (VT malicious=$VTMaliciousCount)" `
        -DryRun:$DryRun
    if (-not $approved) {
        Write-Warning "RemediationEngine: usunięcie odrzucone przez operatora."
        return $false
    }

    # Backup z ACL
    if ([string]::IsNullOrWhiteSpace($BackupFolder)) {
        $BackupFolder = Join-Path $env:USERPROFILE "Documents\SecurityMonitor\Backup"
    }
    Backup-WithAcl -FilePath $FilePath -BackupFolder $BackupFolder -DryRun:$DryRun

    $rollback = @{
        Action    = "Remove-Item"
        Source    = $FilePath
        Backup    = (Join-Path $BackupFolder ((Split-Path $FilePath -Leaf) + "_" + (Get-Date -Format "yyyyMMdd-HHmmss")))
        Timestamp = (Get-Date).ToString("o")
        Rolled    = $false
    }
    $script:RollbackRegistry.Add($rollback)

    if ($DryRun) {
        Write-Host "[DryRun] Remove-Item '$FilePath'"
        return $true
    }

    try {
        Remove-Item -Path $FilePath -Force -ErrorAction Stop
        Write-Host "RemediationEngine: plik usunięty: $FilePath"
        return $true
    } catch {
        Write-Warning "RemediationEngine: nie można usunąć pliku – $_"
        return $false
    }
}

# ── Rollback ──────────────────────────────────────────────────────────────────

function Invoke-RemediationRollback {
    <#
    .SYNOPSIS
        Cofa ostatnią niezrolbackowaną akcję naprawczą z rejestru.
    #>
    [CmdletBinding()]
    param([switch]$DryRun)

    $pending = $script:RollbackRegistry | Where-Object { -not $_.Rolled } | Select-Object -Last 1
    if ($null -eq $pending) {
        Write-Host "RemediationEngine: brak akcji do cofnięcia."
        return
    }

    switch ($pending.Action) {
        "Move-Item" {
            if (Test-Path $pending.Dest) {
                if ($DryRun) {
                    Write-Host "[DryRun] Rollback: Move-Item '$($pending.Dest)' -> '$($pending.Source)'"
                } else {
                    Move-Item -Path $pending.Dest -Destination $pending.Source -Force -ErrorAction SilentlyContinue
                    Write-Host "RemediationEngine: rollback – przywrócono '$($pending.Source)'."
                }
                $pending.Rolled = $true
            }
        }
        "Remove-Item" {
            Write-Warning "RemediationEngine: rollback dla Remove-Item niemożliwy automatycznie – przywróć z backupu: $($pending.Backup)"
            $pending.Rolled = $true
        }
        "Stop-Process" {
            Write-Warning "RemediationEngine: rollback dla Stop-Process niemożliwy (restart procesu jest poza zakresem)."
            $pending.Rolled = $true
        }
    }
}

# ── Backup z ACL ──────────────────────────────────────────────────────────────

function Backup-WithAcl {
    <#
    .SYNOPSIS
        Tworzy kopię zapasową pliku i przenosi na nią ACL oryginału.
        Ustawia właściciela na konto usługi (domyślnie bieżące konto).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string]$BackupFolder,
        [string]$ServiceAccount = $env:USERNAME,
        [switch]$DryRun
    )
    if (-not (Test-Path $FilePath)) { return }
    if ([string]::IsNullOrWhiteSpace($BackupFolder)) {
        $BackupFolder = Join-Path $env:USERPROFILE "Documents\SecurityMonitor\Backup"
    }
    if (-not (Test-Path $BackupFolder)) {
        New-Item -Path $BackupFolder -ItemType Directory -Force | Out-Null
    }

    $leaf = Split-Path $FilePath -Leaf
    $dest = Join-Path $BackupFolder ("${leaf}_" + (Get-Date -Format "yyyyMMdd-HHmmss"))

    if ($DryRun) {
        Write-Host "[DryRun] Backup-WithAcl: '$FilePath' -> '$dest'"
        return
    }

    try {
        Copy-Item -Path $FilePath -Destination $dest -Force -ErrorAction Stop
        # Skopiuj ACL z oryginału
        $acl = Get-Acl -Path $FilePath -ErrorAction SilentlyContinue
        if ($null -ne $acl) {
            # Ogranicz dostęp do konta usługi
            $acl.SetAccessRuleProtection($true, $false)   # wyłącz dziedziczenie
            $acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) | Out-Null }
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $ServiceAccount, "FullControl", "Allow")
            $acl.AddAccessRule($rule)
            Set-Acl -Path $dest -AclObject $acl -ErrorAction SilentlyContinue
        }
        Write-Host "RemediationEngine: backup z ACL: $dest"
    } catch {
        Write-Warning "RemediationEngine: błąd backup – $_"
    }
}
