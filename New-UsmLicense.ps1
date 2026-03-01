# New-UsmLicense.ps1
# Narzędzie dostawcy do generowania podpisanych licencji Ultra Security Monitor.
# Uruchamiaj wyłącznie po stronie DOSTAWCY – NIGDY na urządzeniu klienta!

#Requires -Version 5.1

<#
.SYNOPSIS
    Generuje podpisaną licencję RSA dla Ultra Security Monitor.

.DESCRIPTION
    Tworzy plik license.json podpisany kluczem prywatnym RSA.
    Klient umieszcza plik w Documents\SecurityMonitor\license.json.
    Skrypt weryfikuje podpis przy każdym starcie za pomocą wbudowanego klucza publicznego.

    UWAGA: Klucze DEMO służą wyłącznie do testów.
    Przed wdrożeniem produkcyjnym uruchom z parametrem -GenerateNewKeys,
    a następnie zaktualizuj $LicensePublicKeyXml w UltraSecurityMonitor.ps1.

.PARAMETER Customer
    Nazwa klienta (np. "ACME Corp").

.PARAMETER Expiry
    Data ważności licencji w formacie RRRR-MM-DD (np. "2027-12-31").

.PARAMETER MaxDevices
    Maksymalna liczba urządzeń objętych licencją.

.PARAMETER OutputPath
    Katalog docelowy pliku license.json (domyślnie: bieżący katalog).

.PARAMETER GenerateNewKeys
    Wygeneruj nową parę kluczy RSA 2048-bit zamiast kluczy DEMO.
    Klucz prywatny zostanie zapisany do private.key.xml (KEEP SECRET!).
    Klucz publiczny wyświetlony na ekranie – skopiuj go do $LicensePublicKeyXml
    w UltraSecurityMonitor.ps1.

.EXAMPLE
    .\New-UsmLicense.ps1 -Customer "ACME Corp" -Expiry "2027-12-31" -MaxDevices 10

.EXAMPLE
    .\New-UsmLicense.ps1 -Customer "ACME Corp" -Expiry "2027-12-31" -MaxDevices 10 -GenerateNewKeys
#>
param(
    [Parameter(Mandatory)]
    [string]$Customer,

    [Parameter(Mandatory)]
    [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
    [string]$Expiry,

    [Parameter(Mandatory)]
    [int]$MaxDevices,

    [string]$OutputPath = ".",

    [switch]$GenerateNewKeys
)

# DEMO klucz prywatny – pasuje do klucza publicznego wbudowanego w UltraSecurityMonitor.ps1.
# ZASTĄP WŁASNYM KLUCZEM przed wdrożeniem produkcyjnym (uruchom z -GenerateNewKeys).
$DemoPrivateKeyXml = '<RSAKeyValue><Modulus>zagXS5HQ3EOnyZCsJj7/sZGKbMKf+uGF4BPf/r9FbDkyBe3ByuJv3GKP3YUyp/fAWeMgsaCRhc3JQBFPPDqeZWqlsUTsIbYYKwRcDUj5gSjqXdL3awe51FCJn1T81ljMjAEaPqSEeSbQkPQtP8+8cuHNZ2+Cwcz4Ygg8apdmv65s9h9F2QGBRvOLbMb9p6WPel+xAEvyRJkIoPP433b1QgDDxCW1szPGluIcorosuPFG4HfBvGlHEOfO5ShYa4N1sruoCzhFJFoX0v5/J3rT8twhIb2eyvzJlFMHlzPPQwOAEVZdxKdBdY7NFKathQ5kz77nzbo7MynDQcBhKgJK4w==</Modulus><Exponent>AQAB</Exponent><P>7L3E2d8EYPEREdmIy4ProjRm8Hjkq+OTmqePBVSJEioJO93/fZnzCs6SIboMxeJQoS9/X2xnHHrrRhaXAFcR+F3pQvAMLmxVtUljXDkrsBtBCrwFCN1Fr4LtCEnrlpamslbTvzKMBPthLTn7+EBFHmqbhmHOm1RZbvWsjYt+Uv0=</P><Q>3mL4peu8v2G3QeaUqe/rhQOtzu798Wd1rv12tTRW8ddelN1P/BIHuiEncUsD1IdnoMiAfkf5brVw8xt2biuA5IBBk2NX4U1vYGWoxDYhrxFUTj0ZTyhWUD2uClhMxokhHifMcQmV9ZcyGD7U/k+lglFiuUoRjuxdx/ke8BBFK18=</Q><DP>HwxIS9aOyXP0LCYeZap4db5vnawNOWnQSuEcxbMvgt1Wdq6Hul49XLZ4vcmbsTwcHPeQueAKqdaJEpkV1qqUpcETPX8j6da1auAkEs1AqIj6f8Dm3CHA6OK/2W1wY0CAvjTa8mFbsa+SMA9Bt24eYn3Sxc3//akTTZUUuz+HIrU=</DP><DQ>NGtv4OxoWVRXNhl8AXKkOX5cgeKjyTtx6gWk7aGgvPDfQofISsqVN7KI8ZOVG4uvSZ75asrcaNQsA6H9kIqAn1v8GRnZpSnzju1nkpiP6AxVqvuL87S2Y8OmOpoFvuaj/8+xyRNRXcp97GkjG676fHVip/plmSLuGC0Itd2f8FE=</DQ><InverseQ>Ro8aru4DoF+Unqofvthr5PG9jxOeOfBqSTP4q+P6riAM2OIdkwXFMhZ9zYihnSNd/gQAaUJI7NorKnh7NIEVoz8nN+6AnhoUlOEnFV7+3VYR8xpi8lPLorCsC44z3GqTlMkovM6DqtbyZCn5OMZLKVUs9UyurxsFbX5sCnFx+mw=</InverseQ><D>B4mboPdtMkWAhtC4noY8lOOCsU3I00ckwvu3f/y+rKLEBJecPLVj6C3sm+/f1WwtLp42eowqCT9rmt+HieuUFp98By1BglLMO/di8FG2Y1d+j4XF77ROyUtSX/abdbe3d4Iq1hTtjgswJb/tUKNqgsNn5dyebD/48o7euAFokKnhHJMC0U7mvsw+tCNajJuKErPweueRZ7wvAcjPnBjYKsfwUGiZtqIOP3Qq5w5qAGFUnriWMP0w9Z/oErJv1EvNLi1IonYypv9jHrIpapKv7vx1JZgA3gcYHpxla/0zR7tOShBHRvOrj3IsnDePBxkSfK7Y+rSlXl14aynylSoUEQ==</D></RSAKeyValue>'

# Walidacja daty ważności
if ((Get-Date) -gt [datetime]$Expiry) {
    Write-Error "Data ważności '$Expiry' już minęła."
    exit 1
}

$rsa = $null
if ($GenerateNewKeys) {
    Write-Host "🔑 Generowanie nowej pary kluczy RSA 2048-bit..."
    $rsa           = [System.Security.Cryptography.RSA]::Create(2048)
    $privateKeyXml = $rsa.ToXmlString($true)
    $publicKeyXml  = $rsa.ToXmlString($false)
    $privFile      = Join-Path $OutputPath "private.key.xml"
    Set-Content -Path $privFile -Value $privateKeyXml -Force
    Write-Host ""
    Write-Host "⚠️  Klucz prywatny zapisany: $privFile"
    Write-Host "    NIGDY nie udostępniaj ani nie commituj tego pliku!"
    Write-Host ""
    Write-Host "📋 Zaktualizuj `$LicensePublicKeyXml w UltraSecurityMonitor.ps1:"
    Write-Host $publicKeyXml
    Write-Host ""
} else {
    Write-Host "ℹ️  Używam kluczy DEMO. Uruchom z -GenerateNewKeys dla kluczy produkcyjnych."
    $rsa = [System.Security.Cryptography.RSA]::Create()
    $rsa.FromXmlString($DemoPrivateKeyXml)
}

# Podpisz licencję
$payload      = "$Customer|$Expiry|$MaxDevices"
$payloadBytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
$sigBytes     = $rsa.SignData($payloadBytes,
                    [System.Security.Cryptography.HashAlgorithmName]::SHA256,
                    [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
$rsa.Dispose()
$sig64 = [Convert]::ToBase64String($sigBytes)

$license = [ordered]@{
    Customer   = $Customer
    Expiry     = $Expiry
    MaxDevices = $MaxDevices
    Signature  = $sig64
}

if (-not (Test-Path $OutputPath)) { New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null }
$licFile = Join-Path $OutputPath "license.json"
$license | ConvertTo-Json | Set-Content -Path $licFile -Force -Encoding UTF8

Write-Host ""
Write-Host "✅ Licencja zapisana: $licFile"
Write-Host "   Klient:          $Customer"
Write-Host "   Data ważności:   $Expiry"
Write-Host "   Max. urządzenia: $MaxDevices"
Write-Host ""
Write-Host "📦 Prześlij plik license.json do klienta."
Write-Host "   Klient umieszcza go w: Documents\SecurityMonitor\license.json"
