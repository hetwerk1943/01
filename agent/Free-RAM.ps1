# ==================================================
# Free-RAM.ps1 - Zwalnianie pamięci RAM przez zamykanie procesów
# ==================================================

# Pobranie wszystkich procesów użytkownika (SessionId = 1)
$processes = Get-Process | Where-Object { $_.SessionId -eq 1 }

# Lista procesów, które nie są bezpieczne do zamknięcia
$excluded = @(
    "explorer", "powershell", "cmd", "taskmgr", "conhost"
)

# Filtrujemy procesy do zamknięcia
$toStop = $processes | Where-Object { $excluded -notcontains $_.Name }

# Wyświetlamy co zostanie zamknięte i ile RAM zużywa
$toStop | Select-Object Id, Name, @{Name="RAM(MB)";Expression={[math]::Round($_.WorkingSet/1MB,2)}} |
    Format-Table -AutoSize

# Pytanie do użytkownika: czy zamknąć procesy?
$confirm = Read-Host "Czy chcesz zamknąć powyższe procesy? (T/N)"
if ($confirm -eq "T") {
    $toStop | ForEach-Object {
        try {
            Stop-Process -Id $_.Id -Force
        } catch {
            Write-Host "⚠️ Nie udało się zamknąć procesu $($_.Name) (PID $($_.Id)): $_"
        }
    }
    Write-Host "Procesy zostały zamknięte i RAM zwolniony."
} else {
    Write-Host "Anulowano zamykanie procesów."
}
