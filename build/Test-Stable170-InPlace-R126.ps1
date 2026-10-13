# R126 official v1.7.0 Stable -> versioned v1.7.1 exact same-root update acceptance.
# EXCLUSIVELY GitHub-hosted disposable Windows, no personal installation.
[CmdletBinding()]
param([switch]$StaticOnly)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($StaticOnly){
 $t=$null;$e=$null
 [void][Management.Automation.Language.Parser]::ParseFile($PSCommandPath,[ref]$t,[ref]$e)
 if(@($e).Count){throw 'R126_SCRIPT_PARSE_FAIL'}
 Write-Output 'R126_STATIC_PASS';exit 0
}
if($env:GITHUB_ACTIONS -cne 'true' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
 $env:RUNNER_OS -cne 'Windows' -or $env:GITHUB_SHA -cnotmatch '^[0-9a-f]{40}$' -or
 $env:COMPUTERNAME -match 'EMAD-PC' -or ![Environment]::UserInteractive){
 throw 'R126_REFUSE_NONDISPOSABLE'
}
$app=Join-Path $env:LOCALAPPDATA 'TaskbarMonitorEnhanced'
$reg='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TaskbarMonitorEnhanced'
$dir=Join-Path $env:RUNNER_TEMP 'TBME_R126_STABLE_UPDATE'
$oldSetup=Join-Path $dir 'TaskbarMonitorEnhanced_Setup_1.7.0.exe'
$newSetup=Join-Path $PSScriptRoot '_out\Setup\TaskbarMonitorEnhanced_Setup_1.7.1.exe'
$newMain=Join-Path $PSScriptRoot '_out\App\TaskbarMonitorEnhanced.exe'
$oldSetupSha='148827212B716238DDB270309F393140EBE3CB935CD0E80D36233220A4BE611E'
$oldMainSha='B56E322826A86927999A00FB933C17979213798A68C8BB71C2176E68962E30EA'
$newMainSha='C79064C6A284F2D6537D28D500D07621BEEF050BDCEA794495DB5B2AAE8A0AC1'
$newSetupSha='24C39688ACD2353D3D23ECBAEA920462629A167CC6D004A3CDB3D8622CE5920F'
$state=Join-Path $app 'install_state.json'
$main=Join-Path $app 'TaskbarMonitorEnhanced.exe'
$config=Join-Path $app 'config.json'
$configBak=Join-Path $app 'config.json.bak'
$doc=Join-Path $app 'Docs\README.md'
$backend=Join-Path $app 'SensorBackend\LibreHardwareMonitor-0.9.6\LibreHardwareMonitorLib.dll'
$sentinel=Join-Path $app 'UserOwnedR126\preferences.txt'
$stage=Join-Path $app '.tbme-upgrade'
$oldNote=Join-Path $app 'Docs\RELEASE_NOTES_v1.7.0.md'
$newNote=Join-Path $app 'Docs\RELEASE_NOTES_v1.7.1.md'
$receipt=Join-Path $dir 'R126_STABLE_UPDATE_RECEIPT.json'
$phase='PREFLIGHT';$status='NOT_RUN';$errorDetail=''
$before=@{};$after=@{}
$negative='NOT_RUN';$upgraded='NOT_RUN';$repeat='NOT_RUN';$downgrade='NOT_RUN'
function SHA([string]$f){if(!(Test-Path $f -PathType Leaf)){throw ('FILE_MISSING '+$f)};return (Get-FileHash $f -Algorithm SHA256).Hash}
function RunExe([string]$exe,[string[]]$a,[int]$max){
 $pInfo=[Diagnostics.ProcessStartInfo]::new()
 $pInfo.FileName=$exe;$pInfo.UseShellExecute=$false;$pInfo.CreateNoWindow=$true
 $pInfo.WorkingDirectory=Split-Path -Parent $exe
 foreach($arg in $a){[void]$pInfo.ArgumentList.Add($arg)}
 $p=[Diagnostics.Process]::Start($pInfo)
 if($null -eq $p){throw 'NO_PROCESS'}
 try{
  if(!$p.WaitForExit($max)){throw 'PROCESS_TIMEOUT'}
  return [int]$p.ExitCode
 }finally{$p.Dispose()}
}
function StartupValue{
 $x=Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'TaskbarMonitorEnhanced' -ErrorAction SilentlyContinue
 if(!$x){return 'ABSENT'};return [string]$x.TaskbarMonitorEnhanced
}
function WallpaperValue{
 $x=Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers' -ErrorAction SilentlyContinue
 if($x -and $null -ne $x.PSObject.Properties['BackgroundType']){return [string]$x.BackgroundType}
 return 'ABSENT'
}
if((Test-Path $dir) -or (Test-Path $app) -or (Test-Path $reg) -or
 @(Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count -ne 0){
 throw 'R126_EXISTING_USER_INSTALL_REFUSED'
}
if((SHA $newMain) -cne $newMainSha -or (SHA $newSetup) -cne $newSetupSha){throw 'R126_CANDIDATE_SHA_MISMATCH'}
New-Item -ItemType Directory -Path $dir -ErrorAction Stop|Out-Null
try{
 $phase='OFFICIAL_DOWNLOAD'
 $url='https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/download/v1.7.0/TaskbarMonitorEnhanced_Setup_1.7.0.exe'
 Invoke-WebRequest -Uri $url -OutFile $oldSetup -TimeoutSec 100 -ErrorAction Stop
 if((SHA $oldSetup) -cne $oldSetupSha -or (Get-Item $oldSetup).Length -ne 8404992){throw 'R126_OFFICIAL_SETUP_DIGEST'}
 $phase='VERIFY_NEW_SETUP'
 $verified=Join-Path $dir 'verify.json'
 if((RunExe $newSetup @('/verify',('/verifyfile='+$verified)) 50000) -ne 0){throw 'R126_NEW_SETUP_VERIFY_EXIT'}
 $v=Get-Content $verified -Raw|ConvertFrom-Json
 if($v.Status -cne 'PASS' -or $v.Resources -ne 25 -or $v.PawnIOBundled -ne $false -or
    $v.EmbeddedMainSHA256 -cne $newMainSha){throw 'R126_NEW_SETUP_VERIFIED_PAYLOAD_WRONG'}
 $phase='REAL_OFFICIAL_FRESH_INSTALL'
 $rc=RunExe $oldSetup @('/install','/quiet','/desktop=0','/startup=0') 190000
 if($rc -ne 0){throw ('R126_OFFICIAL_INSTALL_FAILED '+$rc)}
 if((SHA $main) -cne $oldMainSha -or (SHA (Join-Path $app 'Uninstall.exe')) -cne $oldSetupSha){throw 'R126_OFFICIAL_INSTALLED_BYTES_WRONG'}
 $baseline=Get-Content $state -Raw|ConvertFrom-Json
 if($baseline.Version -cne '1.7.0' -or $baseline.PublicVersion -cne '1.7.0' -or
  $baseline.ProductIdentity -cne 'LOCKED' -or (Get-ItemProperty $reg).DisplayVersion -cne '1.7.0'){
   throw 'R126_PUBLIC_INSTALLED_STATE_WRONG'
 }
 if(@(Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count -ne 0){throw 'R126_AUTOSTART_UNEXPECTED'}
 if(!(Test-Path $config -PathType Leaf)){
  [IO.File]::WriteAllText($config,'{"Theme":"Retro Terminal","Opacity":0.31,"StartWithWindows":false}',[Text.UTF8Encoding]::new($false))
 }
 if(!(Test-Path $configBak -PathType Leaf)){Copy-Item $config $configBak -ErrorAction Stop}
 if(!(Test-Path $backend -PathType Leaf)){throw 'R126_SENSOR_BACKEND_MISSING'}
 New-Item -ItemType Directory -Path (Split-Path $sentinel -Parent) -ErrorAction Stop | Out-Null
 [IO.File]::WriteAllText($sentinel,'R126_USER_FILE_KEEP',[Text.UTF8Encoding]::new($false))
 $before=@{Config=SHA $config;Backup=SHA $configBak;Backend=SHA $backend;Sentinel=SHA $sentinel;Doc=SHA $doc;Main=SHA $main;Uninstaller=SHA (Join-Path $app 'Uninstall.exe');Startup=StartupValue;Wallpaper=WallpaperValue}
 if(!(Test-Path $oldNote) -or (Test-Path $newNote)){throw 'R126_RELEASE_NOTES_BASELINE_WRONG'}
 $phase='NEGATIVE_MODIFIED_MANAGED_DOC'
 $docOriginal=[IO.File]::ReadAllBytes($doc)
 try{
  [IO.File]::AppendAllText($doc,[Environment]::NewLine+'OWNER_EDIT_MUST_SURVIVE',[Text.UTF8Encoding]::new($false))
  $editedSha=SHA $doc
  $env:TBME_UPDATE_DIAGNOSTIC_PHASE='NEGATIVE_USER_EDIT'
  $rc=RunExe $newSetup @('/update','/quiet') 80000
  $env:TBME_UPDATE_DIAGNOSTIC_PHASE=''
  if($rc -ne 34 -or (SHA $doc) -cne $editedSha -or
     (SHA $main) -cne $oldMainSha -or (Test-Path $stage)){
    throw ('R126_USER_EDIT_NOT_REFUSED '+$rc)
  }
  $negative='PASS_REFUSED_EDIT_WITHOUT_OVERWRITE'
 }finally{[IO.File]::WriteAllBytes($doc,$docOriginal)}
 if((SHA $doc) -cne $before.Doc){throw 'R126_MANAGED_DOC_TEST_NOT_RESTORED'}
 $phase='REAL_SAME_ROOT_UPDATE'
 $env:TBME_UPDATE_DIAGNOSTIC_PHASE='POSITIVE_OFFICIAL_STABLE'
 $rc=RunExe $newSetup @('/update','/quiet') 190000
 $env:TBME_UPDATE_DIAGNOSTIC_PHASE=''
 if($rc -ne 0){throw ('R126_UPDATE_FAILED '+$rc)}
 $actual=Get-Content $state -Raw|ConvertFrom-Json
 if($actual.Version -cne '1.7.1' -or $actual.PublicVersion -cne '1.7.1' -or
   $actual.ProductIdentity -cne 'LOCKED' -or (Get-ItemProperty $reg).DisplayVersion -cne '1.7.1' -or
   (SHA $main) -cne $newMainSha -or (SHA (Join-Path $app 'Uninstall.exe')) -cne $newSetupSha -or
   !(Test-Path $newNote -PathType Leaf) -or (Test-Path $oldNote) -or (Test-Path $stage)){
  throw 'R126_AFTER_UPDATE_IDENTITY_OR_NOTES_NOT_CORRECT'
 }
 if((SHA $config) -cne $before.Config -or (SHA $configBak) -cne $before.Backup -or
  (SHA $backend) -cne $before.Backend -or (SHA $sentinel) -cne $before.Sentinel -or
  (StartupValue) -cne $before.Startup -or (WallpaperValue) -cne $before.Wallpaper){
  throw 'R126_USER_DATA_CHANGED'
 }
 $upgraded='PASS_OFFICIAL_V170_TO_V171_SAME_ROOT_EXACT_USER_SHAS'
 $phase='NOOP_IDEMPOTENCE'
 $stateSHA=SHA $state
 $env:TBME_UPDATE_DIAGNOSTIC_PHASE='IDEMPOTENT'
 $rc=RunExe $newSetup @('/update','/quiet') 80000
 $env:TBME_UPDATE_DIAGNOSTIC_PHASE=''
 if($rc -ne 0 -or (SHA $state) -cne $stateSHA -or (SHA $main) -cne $newMainSha -or (Test-Path $stage)){
  throw 'R126_SAME_INSTALL_REPEAT_NOT_NOOP'
 }
 $repeat='PASS_IDEMPOTENT_NO_USER_CHANGE'
 $phase='NO_DOWNGRADE'
 $env:TBME_UPDATE_DIAGNOSTIC_PHASE='DOWNGRADE'
 $rc=RunExe $oldSetup @('/update','/quiet') 80000
 $env:TBME_UPDATE_DIAGNOSTIC_PHASE=''
 if($rc -ne 34 -or (SHA $state) -cne $stateSHA -or (SHA $main) -cne $newMainSha){
  throw ('R126_OLD_SETUP_DOWNGRADE_NOT_REFUSED '+$rc)
 }
 $downgrade='PASS_NO_DOWNGRADE'
 if(@(Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall' |
   Where-Object PSChildName -ceq 'TaskbarMonitorEnhanced').Count -ne 1 -or
   (Get-ItemProperty $reg).InstallLocation -cne $app){
  throw 'R126_DUPLICATE_REGISTRATION_OR_ROOT'
 }
 $after=@{Main=SHA $main;Uninstaller=SHA (Join-Path $app 'Uninstall.exe');State=SHA $state;Config=SHA $config;Backup=SHA $configBak;Backend=SHA $backend;Sentinel=SHA $sentinel;Startup=StartupValue;Wallpaper=WallpaperValue}
 $phase='ACCEPTED'
 $status='PASS_REAL_PUBLIC_STABLE_V170_TO_PATCH_V171_SINGLE_ROOT'
}catch{$status='FAIL_CLOSED';$errorDetail=$_.Exception.ToString()}
finally{
 $out=[ordered]@{
  Schema=1;Revision='R126';EventCommit=$env:GITHUB_SHA
  Host='GITHUB_HOSTED_DISPOSABLE_WINDOWS';Status=$status;Phase=$phase;Failure=$errorDetail
  OfficialMainSHA256=$oldMainSha;OfficialSetupSHA256=$oldSetupSha
  PatchMainSHA256=$newMainSha;PatchSetupSHA256=$newSetupSha
  NegativeEdit=$negative;Upgrade=$upgraded;Idempotence=$repeat;Downgrade=$downgrade
  Before=$before;After=$after;ExternalLabAccepted=$false
  PersonalInstallTouched=$false;NoSecondInstall=$true
 }
 [IO.File]::WriteAllText($receipt,($out|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
 Write-Output ('R126_STABLE_INPLACE='+$status+' PHASE='+$phase+' RECEIPT_SHA256='+(SHA $receipt))
}
if($status -cne 'PASS_REAL_PUBLIC_STABLE_V170_TO_PATCH_V171_SINGLE_ROOT'){
 throw ('R126_FAIL_CLOSED: '+$errorDetail)
}
exit 0
