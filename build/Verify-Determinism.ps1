[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$PrimaryManifest=Join-Path $Root 'artifacts\R21_BUILD_MANIFEST.json'
if(!(Test-Path -LiteralPath $PrimaryManifest)){throw 'Run Build-R21.ps1 before Verify-Determinism.ps1.'}

$Temp=Join-Path ([IO.Path]::GetTempPath()) ('tbme_r21_det_'+[Guid]::NewGuid().ToString('N'))
$Clone=Join-Path $Temp 'repo'
try{
    New-Item -ItemType Directory -Force -Path $Temp|Out-Null
    & git clone --no-local --quiet $Root $Clone
    if($LASTEXITCODE -ne 0){throw 'Determinism clone failed.'}

    $PrimaryDeps=Join-Path $PSScriptRoot '_deps'
    $CloneDeps=Join-Path $Clone 'build\_deps'
    if(!(Test-Path -LiteralPath $PrimaryDeps)){throw 'Primary dependency cache is missing.'}
    New-Item -ItemType Directory -Force -Path $CloneDeps|Out-Null
    Copy-Item -Path (Join-Path $PrimaryDeps '*') -Destination $CloneDeps -Recurse -Force

    & (Join-Path $Clone 'build\Build-R21.ps1') -NoDownload
    if($LASTEXITCODE -ne 0){throw 'Clean-clone build failed.'}

    $a=Get-Content -LiteralPath $PrimaryManifest -Raw|ConvertFrom-Json
    $b=Get-Content -LiteralPath (Join-Path $Clone 'artifacts\R21_BUILD_MANIFEST.json') -Raw|ConvertFrom-Json
    $am=@{};$bm=@{}
    foreach($x in $a.Outputs){$am[[string]$x.Name]=([string]$x.SHA256).ToUpperInvariant()}
    foreach($x in $b.Outputs){$bm[[string]$x.Name]=([string]$x.SHA256).ToUpperInvariant()}
    if($am.Count -ne $bm.Count){throw 'Output count differs between primary and clean-clone builds.'}
    foreach($k in $am.Keys){
        if(!$bm.ContainsKey($k) -or $am[$k] -ne $bm[$k]){
            throw "Determinism mismatch for $k primary=$($am[$k]) clone=$($bm[$k])"
        }
    }
    Write-Host 'R21_DETERMINISM=PASS'
}finally{
    Remove-Item -LiteralPath $Temp -Recurse -Force -ErrorAction SilentlyContinue
}
