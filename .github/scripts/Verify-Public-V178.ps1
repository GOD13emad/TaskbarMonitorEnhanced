# Read-only verification of the exact, already published Taskbar Monitor Enhanced v1.7.8 installer.
# No download, install, launch, signing request or machine-configuration change.
# Requires GitHub CLI >= 2.102.0 (GHSA-wjmr-j3rp-mh2g fix) and accessible Sigstore trust roots.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InstallerPath,
    [Parameter(Mandatory = $false)][string]$GhPath
)

$ErrorActionPreference = 'Stop'
$expectedDigest = '4db3c03ac7ab70b3d3123a365c156e71370f0338991b399b99169a4b5b5f8b75'
$expectedLength = 8565760
$expectedSource = '9960a06dba606d1c93b8ca2b84e0e3e25ca4f68d'

$resolved = (Resolve-Path -LiteralPath $InstallerPath -ErrorAction Stop).ProviderPath
if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
    throw 'PUBLIC_V178_NOT_A_LOCAL_FILE'
}
$length = (Get-Item -LiteralPath $resolved).Length
if ($length -ne $expectedLength) {
    throw "PUBLIC_V178_INVALID_SIZE:expected=${expectedLength}:actual=$length"
}
$actualDigest = (Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualDigest -cne $expectedDigest) {
    throw "PUBLIC_V178_DIGEST_MISMATCH:expected=${expectedDigest}:actual=$actualDigest"
}
Write-Output 'PUBLIC_V178_LOCAL_SHA256_PASS'

# Authenticode is a separate publisher trust mechanism, NOT proof of SLSA provenance.
if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
    $signatureStatus = (Get-AuthenticodeSignature -LiteralPath $resolved).Status.ToString()
    if ($signatureStatus -cne 'NotSigned') {
        throw "PUBLIC_V178_UNEXPECTED_AUTHENTICODE_STATE:$signatureStatus"
    }
    Write-Output 'PUBLIC_V178_WINDOWS_AUTHENTICODE_NOT_SIGNED'
}

if ($GhPath) {
    $ghExecutable = (Resolve-Path -LiteralPath $GhPath -ErrorAction Stop).ProviderPath
    if (-not (Test-Path -LiteralPath $ghExecutable -PathType Leaf)) {
        throw 'GH_PATH_IS_NOT_A_FILE'
    }
} else {
    $command = Get-Command gh -CommandType Application -ErrorAction SilentlyContinue
    if (-not $command) {
        throw 'GH_CLI_MISSING:requires v2.102.0 or later'
    }
    $ghExecutable = $command.Source
}
$versionLine = [string]((& $ghExecutable --version | Select-Object -First 1))
if ($LASTEXITCODE -ne 0) { throw 'GH_CLI_VERSION_QUERY_FAILED' }
$match = [regex]::Match($versionLine, '^gh version (\d+\.\d+\.\d+)')
if (-not $match.Success) { throw "GH_VERSION_UNRECOGNIZED:$versionLine" }
$version = [version]$match.Groups[1].Value
if ($version -lt [version]'2.102.0') {
    throw "GH_CLI_VULNERABLE_VERSION:${version}:requires>=2.102.0"
}
Write-Output "PUBLIC_V178_GH_VERSION_PASS:$version"

# Fail closed on any API, trust-root, identity, source-policy or signature-verification error.
$arguments = @(
    'attestation', 'verify', $resolved,
    '--repo', 'GOD13emad/TaskbarMonitorEnhanced',
    '--signer-workflow', 'GOD13emad/TaskbarMonitorEnhanced/.github/workflows/ci.yml',
    '--source-ref', 'refs/heads/main',
    '--source-digest', $expectedSource,
    '--deny-self-hosted-runners',
    '--predicate-type', 'https://slsa.dev/provenance/v1'
)
& $ghExecutable @arguments
if ($LASTEXITCODE -ne 0) {
    throw "PUBLIC_V178_SLSA_UNVERIFIED:gh_exit=$LASTEXITCODE"
}
Write-Output 'PUBLIC_V178_EXACT_SLSA_PROVENANCE_VERIFIED'
