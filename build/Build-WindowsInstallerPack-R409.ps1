[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$SetupPath,
    [string]$DestinationDirectory='',
    [string]$RuntimePath=''
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$source=Join-Path $root 'packaging\windows'
$expected='TaskbarMonitorEnhanced_Setup_1.7.10.exe'
$setup=(Resolve-Path -LiteralPath $SetupPath -ErrorAction Stop).Path
if([IO.Path]::GetFileName($setup) -cne $expected){
    throw 'R409_SETUP_BASENAME_NOT_EXPECTED'
}
$version=[Diagnostics.FileVersionInfo]::GetVersionInfo($setup)
if(!$version.ProductVersion -or $version.ProductVersion -notlike '1.7.10*'){
    throw ('R409_UNEXPECTED_SETUP_PRODUCT_VERSION_'+$version.ProductVersion)
}
$sha=(Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash
$runtimeName='NDP48-x86-x64-AllOS-ENU.exe'
$runtimeHash='68C9986A8DCC0214D909AA1F31BEE9FB5461BB839EDCA996A75B08DDFFC1483F'
$offline=![string]::IsNullOrWhiteSpace($RuntimePath)
$runtimeSource=$null
if($offline){
    $runtimeSource=(Resolve-Path -LiteralPath $RuntimePath -ErrorAction Stop).Path
    if([IO.Path]::GetFileName($runtimeSource) -cne $runtimeName){throw 'R410_OFFLINE_FRAMEWORK_FILE_NAME_UNEXPECTED'}
    if((Get-FileHash -LiteralPath $runtimeSource -Algorithm SHA256).Hash -cne $runtimeHash){throw 'R410_OFFLINE_FRAMEWORK_SHA256_MISMATCH'}
    $signature=Get-AuthenticodeSignature -LiteralPath $runtimeSource
    if($signature.Status -ne 'Valid' -or !$signature.SignerCertificate -or
        $signature.SignerCertificate.Subject -notmatch '(^|,\s*)CN=Microsoft Corporation(,|$)'){
        throw 'R410_OFFLINE_FRAMEWORK_MICROSOFT_SIGNATURE_INVALID'
    }
}
if(!$DestinationDirectory){
    $DestinationDirectory=Join-Path $root 'build\_out\InstallerPacks'
}
$destination=[IO.Path]::GetFullPath($DestinationDirectory)
[void][IO.Directory]::CreateDirectory($destination)
$packName=if($offline){'TaskbarMonitorEnhanced-Windows10-11-x64-v1.7.10-Offline.zip'}else{'TaskbarMonitorEnhanced-Windows10-11-x64-v1.7.10.zip'}
$target=Join-Path $destination $packName
if(Test-Path -LiteralPath $target){throw 'R409_PACKAGE_ALREADY_EXISTS_PRESERVE_OR_VERIFY_BEFORE_REBUILD'}
$stage=Join-Path $destination ('r409-stage-'+[Guid]::NewGuid().ToString('N'))
if(Test-Path $stage){throw 'R409_STAGING_COLLISION'}
[void][IO.Directory]::CreateDirectory($stage)
$partial=Join-Path $destination ('r409-partial-'+[Guid]::NewGuid().ToString('N')+'.zip')
try{
    foreach($name in @('Install-TaskbarMonitorEnhanced.ps1','Install.cmd','README.md')){
        $p=Join-Path $source $name
        if(!(Test-Path -LiteralPath $p -PathType Leaf)){throw ('R409_PACKAGE_SOURCE_MISSING_'+$name)}
        Copy-Item -LiteralPath $p -Destination (Join-Path $stage $name) -ErrorAction Stop
    }
    Copy-Item -LiteralPath $setup -Destination (Join-Path $stage $expected) -ErrorAction Stop
    if($offline){
        Copy-Item -LiteralPath $runtimeSource -Destination (Join-Path $stage $runtimeName) -ErrorAction Stop
        if((Get-FileHash -LiteralPath (Join-Path $stage $runtimeName) -Algorithm SHA256).Hash -cne $runtimeHash){
            throw 'R410_STAGED_OFFLINE_FRAMEWORK_SHA256_MISMATCH'
        }
    }
    if((Get-FileHash -LiteralPath (Join-Path $stage $expected) -Algorithm SHA256).Hash -cne $sha){
        throw 'R409_EMBEDDED_SETUP_SHA256_CHANGED'
    }
    $manifest=[ordered]@{
        Schema=1
        Product='TaskbarMonitorEnhanced'
        Version='1.7.10'
        SupportedOS='Windows10/11-x64'
        SetupFile=$expected
        SetupSHA256=$sha
        RequiredFrameworkRelease=528040
        OfficialRuntimeUrl='https://download.visualstudio.microsoft.com/download/pr/2d6bb6b2-226a-4baa-bdec-798822606ff1/8494001c276a4b96804cde7829c04d7f/ndp48-x86-x64-allos-enu.exe'
        OfficialRuntimeSHA256=$runtimeHash
        OfficialRuntimeBundled=$offline
        PackageKind='NOT_YET_PUBLISHED_CANDIDATE'
        Note='Installer is OS-aware; no admin-wide product install; preserve existing settings on the guarded in-place route.'
    }
    [IO.File]::WriteAllText((Join-Path $stage 'package-manifest.json'),($manifest|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $partial -CompressionLevel Optimal -ErrorAction Stop
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip=[IO.Compression.ZipFile]::OpenRead($partial)
    try{
        $names=@($zip.Entries | ForEach-Object FullName)
        $expectedEntries=@('Install-TaskbarMonitorEnhanced.ps1','Install.cmd','README.md',$expected,'package-manifest.json')
        if($offline){$expectedEntries+= $runtimeName}
        foreach($name in $expectedEntries){
            if($names -cnotcontains $name){throw ('R409_ZIP_ENTRY_MISSING_'+$name)}
        }
        if($names.Count -ne $expectedEntries.Count){throw 'R410_ZIP_HAS_UNEXPECTED_ENTRIES'}
    }finally{$zip.Dispose()}
    Move-Item -LiteralPath $partial -Destination $target -ErrorAction Stop
    $out=[ordered]@{
        Status='PASS_PACKAGE_CREATED'
        Pack=$target
        PackSHA256=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
        PackBytes=(Get-Item -LiteralPath $target).Length
        SetupSHA256=$sha
        RuntimeBundled=$offline
        VerifiedRuntimeSHA256=if($offline){$runtimeHash}else{'NOT_BUNDLED'}
        ReleasePublished=$false
        ProductInstalled=$false
    }
    $out|ConvertTo-Json -Compress
}finally{
    if(Test-Path -LiteralPath $partial){Remove-Item -LiteralPath $partial -Force}
    if(Test-Path -LiteralPath $stage){Remove-Item -LiteralPath $stage -Recurse -Force}
}
