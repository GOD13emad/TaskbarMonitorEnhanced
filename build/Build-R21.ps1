[CmdletBinding()]
param([switch]$NoDownload)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

$Root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Deps=Join-Path $PSScriptRoot '_deps'
$Out=Join-Path $PSScriptRoot '_out'
$Package=Join-Path $PSScriptRoot '_package'
$Artifacts=Join-Path $Root 'artifacts'
$LhmZip=Join-Path $Deps 'LibreHardwareMonitor.zip'
$PawnExe=Join-Path $Deps 'PawnIO_setup.exe'
$LhmDir=Join-Path $Deps 'LHM'

$LhmUrl='https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/releases/download/v0.9.6/LibreHardwareMonitor.zip'
$LhmSha='086D9F1B5A99E643EDC2CFAAAC16051685B551E4C5AC0B32A57C58C0E529C001'
$PawnUrl='https://github.com/namazso/PawnIO.Setup/releases/download/2.2.0/PawnIO_setup.exe'
$PawnSha='1F519A22E47187F70A1379A48CA604981C4FCF694F4E65B734AAA74A9FBA3032'

function Assert-Hash([string]$Path,[string]$Expected){
    if(!(Test-Path -LiteralPath $Path)){throw "Missing dependency: $Path"}
    $actual=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
    if($actual -ne $Expected){throw "SHA256 mismatch for $Path; expected $Expected; actual $actual"}
}
function Build([string]$Project){
    & dotnet build $Project -c Release --nologo -p:RestoreIgnoreFailedSources=true
    if($LASTEXITCODE -ne 0){throw "Build failed: $Project"}
}

New-Item -ItemType Directory -Force -Path $Deps,$Out,$Package,$Artifacts|Out-Null
if(!$NoDownload){
    Invoke-WebRequest -UseBasicParsing -Uri $LhmUrl -OutFile $LhmZip
    Invoke-WebRequest -UseBasicParsing -Uri $PawnUrl -OutFile $PawnExe
}
Assert-Hash $LhmZip $LhmSha
Assert-Hash $PawnExe $PawnSha

Remove-Item -LiteralPath $LhmDir -Recurse -Force -ErrorAction SilentlyContinue
Expand-Archive -LiteralPath $LhmZip -DestinationPath $LhmDir -Force
if(!(Test-Path -LiteralPath (Join-Path $LhmDir 'LibreHardwareMonitorLib.dll'))){throw 'LibreHardwareMonitorLib.dll missing from pinned archive.'}

Remove-Item -LiteralPath $Out,$Package -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $Out,$Package|Out-Null

Build (Join-Path $PSScriptRoot 'TaskbarMonitorEnhanced.csproj')
Build (Join-Path $PSScriptRoot 'TaskbarMonitorSensorBroker.csproj')
Build (Join-Path $PSScriptRoot 'TaskbarMonitorSensorSupervisor.csproj')
Copy-Item (Join-Path $Out 'App\TaskbarMonitorEnhanced.exe') $Package
Copy-Item (Join-Path $Out 'Broker\TaskbarMonitorSensorBroker.exe') $Package
Copy-Item (Join-Path $Out 'Supervisor\TaskbarMonitorSensorSupervisor.exe') $Package

Build (Join-Path $PSScriptRoot 'TaskbarMonitorEnhanced_Setup.csproj')
$Setup=Join-Path $Out 'Setup\TaskbarMonitorEnhanced_Setup_1.1.2-rc2.exe'
if(!(Test-Path -LiteralPath $Setup)){throw 'Setup output missing.'}

$Verify=Join-Path $Out 'setup_verify.json'
Remove-Item -LiteralPath $Verify -Force -ErrorAction SilentlyContinue
$vp=Start-Process -FilePath $Setup -ArgumentList @('/verify',("/verifyfile="+$Verify)) -Wait -PassThru
if($vp.ExitCode -ne 0){throw "Setup /verify failed with exit $($vp.ExitCode)"}
if(!(Test-Path -LiteralPath $Verify)){throw 'Setup /verify did not create its verification file.'}
$v=Get-Content -LiteralPath $Verify -Raw|ConvertFrom-Json
if([string]$v.Status -ne 'PASS' -or [int]$v.Resources -ne 19){throw 'Setup resource verification failed.'}

$Self=Join-Path $Out 'selftest.txt'
& (Join-Path $Package 'TaskbarMonitorEnhanced.exe') --selftest | Set-Content -LiteralPath $Self -Encoding UTF8
if($LASTEXITCODE -ne 0){throw 'Application self-test failed.'}

$manifest=[ordered]@{
    Version='1.1.2-rc2'
    Build='V1_1_2_R21_PRODUCTION_HARDENING_RC2'
    GeneratedUtc=[datetime]::UtcNow.ToString('o')
    Dependencies=[ordered]@{
        LibreHardwareMonitor=[ordered]@{Version='0.9.6';Url=$LhmUrl;SHA256=$LhmSha}
        PawnIO=[ordered]@{Version='2.2.0';Url=$PawnUrl;SHA256=$PawnSha}
    }
    Outputs=@()
}
foreach($f in @((Join-Path $Package 'TaskbarMonitorEnhanced.exe'),(Join-Path $Package 'TaskbarMonitorSensorBroker.exe'),(Join-Path $Package 'TaskbarMonitorSensorSupervisor.exe'),$Setup)){
    $manifest.Outputs += [ordered]@{Name=[IO.Path]::GetFileName($f);Bytes=(Get-Item -LiteralPath $f).Length;SHA256=(Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash.ToUpperInvariant()}
}
$manifest|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $Artifacts 'R21_BUILD_MANIFEST.json') -Encoding UTF8
Copy-Item $Setup (Join-Path $Artifacts ([IO.Path]::GetFileName($Setup))) -Force
Write-Host 'R21_REPRO_BUILD=PASS'
