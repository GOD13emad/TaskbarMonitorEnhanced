[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$Path,

    [string]$ExpectedThumbprint,

    [switch]$AllowUntrustedDevelopment
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$expected = if ($ExpectedThumbprint) { ($ExpectedThumbprint -replace '\s','').ToUpperInvariant() } else { $null }
$results = @()

foreach ($item in $Path) {
    $resolved = Resolve-Path -LiteralPath $item -ErrorAction Stop
    $sig = Get-AuthenticodeSignature -LiteralPath $resolved.Path

    if ([string]$sig.Status -eq 'NotSigned') {
        throw "File is not Authenticode signed: $($resolved.Path)"
    }
    if ([string]$sig.Status -eq 'HashMismatch') {
        throw "Authenticode hash mismatch: $($resolved.Path)"
    }
    if (-not $sig.SignerCertificate) {
        throw "Signer certificate is missing: $($resolved.Path)"
    }
    if ($expected -and $sig.SignerCertificate.Thumbprint -ne $expected) {
        throw "Unexpected signer thumbprint for $($resolved.Path): $($sig.SignerCertificate.Thumbprint)"
    }

    $trusted = ([string]$sig.Status -eq 'Valid')
    if (-not $trusted -and -not $AllowUntrustedDevelopment) {
        throw "Signature is present but Windows trust validation is not Valid. Status=$($sig.Status); Message=$($sig.StatusMessage)"
    }

    $results += [pscustomobject]@{
        Path = $resolved.Path
        SHA256 = (Get-FileHash -LiteralPath $resolved.Path -Algorithm SHA256).Hash
        SignatureStatus = [string]$sig.Status
        StatusMessage = [string]$sig.StatusMessage
        SignerSubject = $sig.SignerCertificate.Subject
        SignerThumbprint = $sig.SignerCertificate.Thumbprint
        SignerNotBefore = $sig.SignerCertificate.NotBefore.ToString('o')
        SignerNotAfter = $sig.SignerCertificate.NotAfter.ToString('o')
        Timestamped = [bool]$sig.TimeStamperCertificate
        TimestampSigner = if ($sig.TimeStamperCertificate) { $sig.TimeStamperCertificate.Subject } else { $null }
        PubliclyTrustedByWindows = $trusted
        DevelopmentTrustOverrideUsed = (-not $trusted -and $AllowUntrustedDevelopment.IsPresent)
    }
}

$results
