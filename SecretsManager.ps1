# SecretsManager.ps1
# Zarządzanie sekretami przez Windows Credential Manager.
# Żadne klucze API nie są przechowywane w plikach ani w repozytorium.
#
# Użycie:
#   . .\SecretsManager.ps1
#   Set-StoredSecret -Target "USM_VTApiKey"      -Secret "<klucz>"
#   Set-StoredSecret -Target "USM_DiscordWebhook" -Secret "<url>"
#   Set-StoredSecret -Target "USM_SmtpPassword"  -Secret "<hasło>"
#   $key = Get-StoredSecret -Target "USM_VTApiKey"

#Requires -Version 5.1

# ── Natywna integracja z Windows Credential Manager (DPAPI / advapi32) ──────────
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class WinCredManager {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct CREDENTIAL {
        public uint  Flags;
        public uint  Type;
        public string TargetName;
        public string Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public uint  CredentialBlobSize;
        public IntPtr CredentialBlob;
        public uint  Persist;
        public uint  AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias;
        public string UserName;
    }

    [DllImport("advapi32.dll", EntryPoint = "CredReadW",
               CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CredRead(string target, uint type, uint flags,
                                        out IntPtr credential);

    [DllImport("advapi32.dll", EntryPoint = "CredWriteW",
               CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CredWrite(ref CREDENTIAL credential, uint flags);

    [DllImport("advapi32.dll", EntryPoint = "CredDeleteW",
               CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CredDelete(string target, uint type, uint flags);

    [DllImport("advapi32.dll", EntryPoint = "CredFree")]
    private static extern void CredFree(IntPtr credential);

    private const uint CRED_TYPE_GENERIC = 1;
    private const uint CRED_PERSIST_LOCAL_MACHINE = 2;

    /// <summary>Read a secret from Windows Credential Manager.</summary>
    public static string Read(string target) {
        IntPtr ptr;
        if (!CredRead(target, CRED_TYPE_GENERIC, 0, out ptr)) return null;
        try {
            var cred = Marshal.PtrToStructure<CREDENTIAL>(ptr);
            if (cred.CredentialBlobSize == 0 || cred.CredentialBlob == IntPtr.Zero)
                return null;
            byte[] bytes = new byte[cred.CredentialBlobSize];
            Marshal.Copy(cred.CredentialBlob, bytes, 0, (int)cred.CredentialBlobSize);
            return Encoding.Unicode.GetString(bytes);
        } finally { CredFree(ptr); }
    }

    /// <summary>Write a secret to Windows Credential Manager.</summary>
    public static bool Write(string target, string secret) {
        byte[] blob = Encoding.Unicode.GetBytes(secret);
        IntPtr blobPtr = Marshal.AllocHGlobal(blob.Length);
        try {
            Marshal.Copy(blob, 0, blobPtr, blob.Length);
            var cred = new CREDENTIAL {
                Type               = CRED_TYPE_GENERIC,
                TargetName         = target,
                CredentialBlobSize = (uint)blob.Length,
                CredentialBlob     = blobPtr,
                Persist            = CRED_PERSIST_LOCAL_MACHINE,
                UserName           = Environment.UserName
            };
            return CredWrite(ref cred, 0);
        } finally { Marshal.FreeHGlobal(blobPtr); }
    }

    /// <summary>Delete a stored secret.</summary>
    public static bool Delete(string target) {
        return CredDelete(target, CRED_TYPE_GENERIC, 0);
    }
}
'@ -ErrorAction Stop

<#
.SYNOPSIS
    Reads a secret from Windows Credential Manager.
.PARAMETER Target
    The Credential Manager target name (e.g. "USM_VTApiKey").
.OUTPUTS
    Plain-text secret string, or $null if not found.
#>
function Get-StoredSecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Target
    )
    $value = [WinCredManager]::Read($Target)
    if ($null -eq $value) {
        Write-Warning "SecretsManager: sekret '$Target' nie został znaleziony w Credential Manager."
    }
    return $value
}

<#
.SYNOPSIS
    Stores a secret in Windows Credential Manager.
.PARAMETER Target
    The Credential Manager target name.
.PARAMETER Secret
    The plain-text secret to store.  Pass as SecureString to avoid
    the value appearing in shell history – the function converts it.
#>
function Set-StoredSecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)][object]$Secret  # string or SecureString
    )
    $plain = if ($Secret -is [System.Security.SecureString]) {
        [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secret))
    } else { [string]$Secret }

    if ([WinCredManager]::Write($Target, $plain)) {
        Write-Host "SecretsManager: sekret '$Target' zapisany."
    } else {
        Write-Error "SecretsManager: nie udało się zapisać '$Target' (błąd Win32: $([Runtime.InteropServices.Marshal]::GetLastWin32Error()))."
    }
}

<#
.SYNOPSIS
    Removes a secret from Windows Credential Manager.
#>
function Remove-StoredSecret {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Target)
    if ([WinCredManager]::Delete($Target)) {
        Write-Host "SecretsManager: sekret '$Target' usunięty."
    } else {
        Write-Warning "SecretsManager: nie można usunąć '$Target'."
    }
}
