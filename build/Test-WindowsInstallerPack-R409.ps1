[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$PackageZip,[switch]$ExpectUnsupportedServer)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -cne 'Desktop'){throw 'R409_TEST_REQUIRES_WINDOWS_POWERSHELL_51'}
$zip=(Resolve-Path -LiteralPath $PackageZip).Path
$expected=@('Install.cmd','Install-TaskbarMonitorEnhanced.ps1','README.md',
  'TaskbarMonitorEnhanced_Setup_1.7.10.exe','package-manifest.json')
$testRoot=Join-Path $env:TEMP ('tbme-r409-test-'+[guid]::NewGuid().ToString('N'))
if(Test-Path $testRoot){throw 'R409_TEST_ROOT_ALREADY_EXISTS'}
[void][IO.Directory]::CreateDirectory($testRoot)
$owner=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'TaskbarMonitorEnhanced'
$config=Join-Path $owner 'config.json'
$app=Join-Path $owner 'TaskbarMonitorEnhanced.exe'
$beforeConfig=if(Test-Path $config){(Get-FileHash $config -Algorithm SHA256).Hash}else{'ABSENT'}
$beforeApp=if(Test-Path $app){(Get-FileHash $app -Algorithm SHA256).Hash}else{'ABSENT'}
function Invoke-Preflight([string]$folder) {
  $stdout=Join-Path $testRoot ([guid]::NewGuid().ToString('N')+'.out')
  $stderr=Join-Path $testRoot ([guid]::NewGuid().ToString('N')+'.err')
  $ps=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
  $file=Join-Path $folder 'Install-TaskbarMonitorEnhanced.ps1'
  $args='-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$file+'" -CheckOnly'
  $p=Start-Process -FilePath $ps -ArgumentList $args -PassThru -Wait -RedirectStandardOutput $stdout -RedirectStandardError $stderr
  if(!$p){throw 'R409_TEST_CANNOT_START_PREFLIGHT'}
  return [pscustomobject]@{
    Exit=$p.ExitCode
    Stdout=(Get-Content -LiteralPath $stdout -Raw -ErrorAction SilentlyContinue)
    Stderr=(Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue)
  }
}
try{
  $stage=Join-Path $testRoot 'extracted'
  [void][IO.Directory]::CreateDirectory($stage)
  Expand-Archive -LiteralPath $zip -DestinationPath $stage -ErrorAction Stop
  $all=@(Get-ChildItem -LiteralPath $stage -File |Select-Object -ExpandProperty Name)
  if($all.Count -ne $expected.Count -or @($all|Where-Object {$_ -cnotin $expected}).Count -gt 0){
    throw 'R409_TEST_UNEXPECTED_ZIP_CONTENT'
  }
  $manifest=Get-Content (Join-Path $stage 'package-manifest.json') -Raw|ConvertFrom-Json
  if($manifest.SetupSHA256 -cne (Get-FileHash (Join-Path $stage $manifest.SetupFile) -Algorithm SHA256).Hash){
    throw 'R409_TEST_MANIFEST_SETUP_HASH_INVALID'
  }
  if($ExpectUnsupportedServer){
    $kind=[string](Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\ProductOptions' -Name ProductType).ProductType
    if($kind -ceq 'WinNT'){throw 'R409_HOSTED_TEST_REQUIRES_WINDOWS_SERVER'}
    $server=Invoke-Preflight $stage
    if($server.Exit -eq 0 -or $server.Stdout -notmatch 'R409_WINDOWS_SERVER_NOT_SUPPORTED'){
      throw ('R409_WINDOWS_SERVER_WAS_NOT_REFUSED_'+$server.Stdout)
    }
    'R409_PASS_HOSTED_SERVER_OS_UNSUPPORTED_FAIL_CLOSED'
    'R409_RESULT=PASS_HOSTED_ARCHIVE_MANIFEST_AND_UNSUPPORTED_OS_BOUNDARY'
    return
  }
  $good=Invoke-Preflight $stage
  if($good.Exit -ne 0){throw ('R409_CHECK_ONLY_FAILED_'+$good.Stdout+'_'+$good.Stderr)}
  $check=$good.Stdout|ConvertFrom-Json
  if($check.Status -cne 'CHECK_ONLY' -or !$check.Framework48OrNewer -or
     $check.ExecutedSetup -or $check.ModifiedOwnerSettings){
    throw 'R409_CHECK_ONLY_SEMANTIC_MISMATCH'
  }
  'R409_PASS_REAL_WINDOWS_CHECK_ONLY_NO_INSTALL_NO_ELEVATION'
  $savedSetup=(Join-Path $stage $manifest.SetupFile)
  $touched=[IO.File]::ReadAllBytes($savedSetup)
  try{
    # Mutation of one byte in the private temporary copy only.
    $touched[0]=$touched[0] -bxor 1
    [IO.File]::WriteAllBytes($savedSetup,$touched)
    $bad=Invoke-Preflight $stage
    if($bad.Exit -eq 0 -or $bad.Stdout -notmatch 'R409_SETUP_HASH_MISMATCH'){
      throw ('R409_TAMPERED_SETUP_ACCEPTED_'+$bad.Stdout)
    }
    'R409_PASS_MODIFIED_SETUP_SHA256_REFUSED'
  }finally{
    # Restore from the unmodified archive, never attempt repair of user installation.
    Remove-Item -LiteralPath $savedSetup -Force
    Expand-Archive -LiteralPath $zip -DestinationPath $stage -Force
  }
  $manifestPath=Join-Path $stage 'package-manifest.json'
  $m=Get-Content $manifestPath -Raw|ConvertFrom-Json
  $m.SetupSHA256='0'*64
  [IO.File]::WriteAllText($manifestPath,($m|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
  $tampered=Invoke-Preflight $stage
  if($tampered.Exit -eq 0 -or $tampered.Stdout -notmatch 'R409_SETUP_HASH_MISMATCH'){
    throw ('R409_TAMPERED_MANIFEST_ACCEPTED_'+$tampered.Stdout)
  }
  'R409_PASS_TAMPERED_MANIFEST_REFUSED'
  $afterConfig=if(Test-Path $config){(Get-FileHash $config -Algorithm SHA256).Hash}else{'ABSENT'}
  $afterApp=if(Test-Path $app){(Get-FileHash $app -Algorithm SHA256).Hash}else{'ABSENT'}
  if($beforeConfig -cne $afterConfig -or $beforeApp -cne $afterApp){
    throw 'R409_TEST_OWNER_MAIN_OR_CONFIG_CHANGED'
  }
  'R409_PASS_OWNER_INSTALLATION_AND_CONFIG_SHA_UNCHANGED'
  'R409_RESULT=PASS_WINDOWS_BOOTSTRAP_ARCHIVE_READONLY_AND_TAMPER_SCOPE'
}finally{
  if(Test-Path -LiteralPath $testRoot){Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction Stop}
}
