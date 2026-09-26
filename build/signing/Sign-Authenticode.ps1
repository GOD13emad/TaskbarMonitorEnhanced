[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Thumbprint,

    [string]$TimestampUrl
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$thumb = ($Thumbprint -replace '\s','').ToUpperInvariant()
$certPath = "Cert:\CurrentUser\My\$thumb"
$cert = Get-Item -LiteralPath $certPath -ErrorAction Stop

if (-not $cert.HasPrivateKey) {
    throw "The selected certificate has no private key: $thumb"
}

$ekuText = @($cert.EnhancedKeyUsageList | ForEach-Object { $_.ToString() })
if (@($ekuText | Where-Object { $_ -match '1\.3\.6\.1\.5\.5\.7\.3\.3|Code Signing' }).Count -eq 0) {
    throw "The selected certificate is not a Code Signing certificate: $thumb"
}

$pf86 = [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86)
$kitBin = Join-Path $pf86 'Windows Kits\10\bin'
$signtool = Get-ChildItem -LiteralPath $kitBin -Filter signtool.exe -Recurse -File -ErrorAction Stop |
    Where-Object { $_.FullName -match '\\x64\\signtool\.exe$' } |
    Sort-Object FullName -Descending |
    Select-Object -First 1

if (-not $signtool) {
    throw "x64 signtool.exe was not found under $kitBin"
}

$results = @()
foreach ($item in $Path) {
    $resolved = Resolve-Path -LiteralPath $item -ErrorAction Stop
    $before = (Get-FileHash -LiteralPath $resolved.Path -Algorithm SHA256).Hash

    $args = @('sign','/s','My','/sha1',$thumb,'/fd','SHA256')
    if ($TimestampUrl) {
        $args += @('/tr',$TimestampUrl,'/td','SHA256')
    }
    $args += @('/v',$resolved.Path)

    & $signtool.FullName @args
    if ($LASTEXITCODE -ne 0) {
        throw "signtool sign failed for $($resolved.Path) with exit code $LASTEXITCODE"
    }

    $after = (Get-FileHash -LiteralPath $resolved.Path -Algorithm SHA256).Hash
    $sig = Get-AuthenticodeSignature -LiteralPath $resolved.Path

    if (-not $sig.SignerCertificate) {
        throw "No Authenticode signer certificate was found after signing: $($resolved.Path)"
    }
    if ($sig.SignerCertificate.Thumbprint -ne $thumb) {
        throw "Unexpected signer thumbprint after signing: $($sig.SignerCertificate.Thumbprint)"
    }

    $results += [pscustomobject]@{
        Path = $resolved.Path
        BeforeSHA256 = $before
        AfterSHA256 = $after
        SignerSubject = $sig.SignerCertificate.Subject
        SignerThumbprint = $sig.SignerCertificate.Thumbprint
        Status = [string]$sig.Status
        StatusMessage = [string]$sig.StatusMessage
        Timestamped = [bool]$sig.TimeStamperCertificate
        TimestampSigner = if ($sig.TimeStamperCertificate) { $sig.TimeStamperCertificate.Subject } else { $null }
        Tool = $signtool.FullName
    }
}

$results
