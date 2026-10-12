# R114 contract: real public v1.6.0 -> same-root v1.7.0 transaction, NO uninstall/reinstall.
# Only disposable GitHub-hosted Windows; never modify user PCs, Wallpaper, security settings.
[CmdletBinding()]
param([switch]$StaticOnly)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$OldTag='v1.6.0'
$OldAsset='TaskbarMonitorEnhanced_Setup_1.6.0.exe'
$OldSetupSha='F5130BC2F81383E16912454FCC62E307501885A6256E7241E674A9CF10BAC9C5'
$OldMainSha='05F9E069C4598FDAD327A41BF1CA34A1498D022119DB81E09F4B3B091C9BA377'
$NewMainSha='B56E322826A86927999A00FB933C17979213798A68C8BB71C2176E68962E30EA'
$ProductDir=Join-Path $env:LOCALAPPDATA 'TaskbarMonitorEnhanced'
$UninstallKey='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TaskbarMonitorEnhanced'
$StartKey='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$AppExe=Join-Path $ProductDir 'TaskbarMonitorEnhanced.exe'
$State=Join-Path $ProductDir 'install_state.json'
$Config=Join-Path $ProductDir 'config.json'
$ConfigBak=Join-Path $ProductDir 'config.json.bak'
$UpgradeStage=Join-Path $ProductDir '.tbme-upgrade'
$Backend=Join-Path $ProductDir 'SensorBackend\LibreHardwareMonitor-0.9.6\LibreHardwareMonitorLib.dll'
$OldManagedNote=Join-Path $ProductDir 'Docs\RELEASE_NOTES_v1.6.0.md'
$NewManagedNote=Join-Path $ProductDir 'Docs\RELEASE_NOTES_v1.7.0.md'
$OldRootSource=Join-Path $ProductDir 'TaskbarMonitorEnhanced.cs'
$TestSentinel=Join-Path $ProductDir 'UserOwnedR114\preferences.txt'
$Candidate=Join-Path $PSScriptRoot '_out\Setup\TaskbarMonitorEnhanced_Setup_1.7.0.exe'
if($StaticOnly){
  $tokens=$null;$parseErrors=$null
  [void][Management.Automation.Language.Parser]::ParseFile($PSCommandPath,[ref]$tokens,[ref]$parseErrors)
  if($parseErrors.Count -ne 0){throw 'R114 SCRIPT PARSER FAILED'}
  $functions=@(Get-Command -Name Test-Path,Get-FileHash -ErrorAction Stop)
  if($functions.Count -ne 2){throw 'R114 MISSING EXACT HOST VERIFIER TOOLS'}
  Write-Output 'R114_INPLACE_UPGRADE_STATIC_ONLY_NO_FILESYSTEM_OR_USER_MUTATION_PASS'
  exit 0
}
if($env:GITHUB_ACTIONS -cne 'true' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
   $env:RUNNER_OS -cne 'Windows' -or $env:COMPUTERNAME -ceq 'EMAD-PC-ULTIMAT' -or
   [string]::IsNullOrEmpty($env:RUNNER_TEMP)){throw 'R114 REFUSE: NOT DISPOSABLE GITHUB WINDOWS'}
$Work=Join-Path $env:RUNNER_TEMP 'TBME_R114_InPlaceUpgrade'
if(Test-Path -LiteralPath $Work){throw 'R114 NO RERUN OR PREEXISTING WORK'}
if((Test-Path -LiteralPath $ProductDir) -or (Test-Path -LiteralPath $UninstallKey) -or
   @(Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count -ne 0){throw 'R114 NO CLEAN TEST HOST - DO NOT TOUCH EXISTING USER DATA'}
foreach($path in @('C:\Program Files\TaskbarMonitorEnhanced\TaskbarMonitorEnhanced.exe','C:\Program Files (x86)\TaskbarMonitorEnhanced\TaskbarMonitorEnhanced.exe')){
  if(Test-Path -LiteralPath $path){throw 'R114 CONFLICTING PROGRAM FILES INSTALL BEFORE TEST'}
}
if((Get-FileHash -LiteralPath $Candidate).Hash -cne 'E32556D8179F8D778FECBF0B0507B4E5BBCD0A6045048F99FC501109027F8EFE'){throw 'R114 EXACT CANDIDATE SETUP SHA MISMATCH'}
$StartUtc=(Get-Date).ToUniversalTime().ToString('o')
New-Item -ItemType Directory -Path $Work -ErrorAction Stop|Out-Null
$ReceiptPath=Join-Path $Work 'R114_INPLACE_UPGRADE_RECEIPT.json'
$OldSetup=Join-Path $Work $OldAsset
$Status='NOT_TESTED';$Step='BEGIN';$Failure=''
$SyntheticUserConfigSeeded=$false
$OldConfigHash='';$OldBackupHash='';$OldMainLive='';$OldStateHash='';$OldBackendSHA=''
$NewMainInstalled='';$OldStartup=$null;$NewStartup=$null
$FaultRollback='NOT_RUN';$UserModifiedFileGuard='NOT_RUN';$SuccessfulUpgrade='NOT_RUN'
$Idempotent='NOT_RUN';$NoDuplicate='NOT_RUN';$UpgradeLog='';$OwnedFileSHA=''
function R114-WallpaperMode {
    $p=Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers' -ErrorAction SilentlyContinue
    if($null -eq $p -or $null -eq $p.PSObject.Properties['BackgroundType']){return 'ABSENT'}
    return [string]$p.BackgroundType
}
$WallpaperModeAtHostStart=R114-WallpaperMode
$WallpaperBefore=$WallpaperModeAtHostStart
function Read-StartupRegistration {
   $reg=Get-ItemProperty -Path $StartKey -ErrorAction SilentlyContinue
   if($null -eq $reg){return $null}
   $found=$reg.PSObject.Properties['TaskbarMonitorEnhanced']
   return $(if($null -eq $found){$null}else{[string]$found.Value})
}
function Run-Bounded([string]$File,[string[]]$ChildArguments,[int]$MaxMs){
  if($null -eq $ChildArguments -or $ChildArguments.Count -eq 0){throw 'R114-VALIDATOR AUTOMATIC ARGS COLLISION GUARD'}
  $psi=[Diagnostics.ProcessStartInfo]::new()
  $psi.FileName=$File
  $psi.UseShellExecute=$false;$psi.CreateNoWindow=$true
  foreach($item in $ChildArguments){[void]$psi.ArgumentList.Add([string]$item)}
  if($psi.ArgumentList.Count -ne $ChildArguments.Count){throw 'R114 ARGUMENT FORWARDING LOST'}
  $p=$null
  try{
    $p=[Diagnostics.Process]::Start($psi)
    if($null -eq $p){throw 'R114 CHILD PROCESS NOT STARTED'}
    if(!$p.WaitForExit($MaxMs)){
      try{$p.Kill();$p.WaitForExit(3000)}catch{}
      throw ('R114 BOUNDED EXECUTION TIMEOUT '+$File+' MAX='+$MaxMs)
    }
    return [int]$p.ExitCode
  }finally{if($p){$p.Dispose()}}
}
function SHA([string]$Path){
  if(!(Test-Path -LiteralPath $Path -PathType Leaf)){throw ('R114 SHA FILE MISSING '+$Path)}
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}
function Assert-UserCanaries{
  if((SHA $Config) -cne $OldConfigHash -or
     (SHA $ConfigBak) -cne $OldBackupHash -or
     (SHA $Backend) -cne $OldBackendSHA -or
     (SHA $TestSentinel) -cne $OwnedFileSHA){throw 'R114 USER-OWNED DATA OR SENSOR BACKEND CHANGED'}
}
function Expect-OldVersion {
  if((SHA $AppExe) -cne $OldMainSha){throw 'R114 OLD MAIN SHA NOT PRESERVED'}
  if((SHA $State) -cne $OldStateHash){throw 'R114 OLD INSTALL STATE NOT RESTORED'}
  if(!(Test-Path -LiteralPath $OldManagedNote -PathType Leaf) -or
     !(Test-Path -LiteralPath $OldRootSource -PathType Leaf)){throw 'R114 OLD MANAGED FILE REMOVED ON FAILURE'}
  if(Test-Path -LiteralPath $UpgradeStage){throw 'R114 UPGRADE STAGING LEFT AFTER ROLLBACK'}
  Assert-UserCanaries
}
try{
  $Step='PUBLIC_V16_DOWNLOAD'
  $oldReleaseUrl='https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/download/v1.6.0/TaskbarMonitorEnhanced_Setup_1.6.0.exe'
  Invoke-WebRequest -Uri $oldReleaseUrl -OutFile $OldSetup -MaximumRedirection 5 -TimeoutSec 120 -ErrorAction Stop
  if((SHA $OldSetup) -cne $OldSetupSha -or
     (Get-Item $OldSetup).Length -ne 11447808){throw 'R114 OFFICIAL_V16_PUBLIC_BYTES_MISMATCH'}
  if((Get-AuthenticodeSignature -LiteralPath $Candidate).Status -ne 'NotSigned'){throw 'R114 CANDIDATE SIGNATURE DIFFERENT FROM UNSIGNED PREVIEW'}
  $verify=Join-Path $Work 'new-setup-selfverify.json'
  $code=Run-Bounded $Candidate @('/verify',('/verifyfile='+$verify)) 25000
  if($code -ne 0 -or !(Test-Path -LiteralPath $verify)){throw 'R114 NEW SETUP VERIFY FAILED'}
  $v=Get-Content $verify -Raw|ConvertFrom-Json
  if($v.Status -cne 'PASS' -or $v.PawnIOBundled -ne $false -or $v.Resources -ne 25 -or
    $v.EmbeddedMainSHA256 -cne $NewMainSha){throw 'R114 NEW MAIN EMBEDDED CONTRACT'}

  $Step='ACTUAL_PUBLIC_V16_FRESH_INSTALL_EPHEMERAL'
  $code=Run-Bounded $OldSetup @('/install','/quiet','/desktop=0','/startup=1') 180000
  if($code -ne 0){throw ('R114 OFFICIAL v1.6 BASELINE INSTALL FAILED EXIT '+$code)}
  if(!(Test-Path -LiteralPath $AppExe -PathType Leaf) -or
     !(Test-Path -LiteralPath $State -PathType Leaf)){throw 'R114 OFFICIAL V16 BASELINE APP/STATE NOT INSTALLED'}
  if((SHA $AppExe) -cne $OldMainSha -or
     ((Get-Content $State -Raw|ConvertFrom-Json).Version) -cne '1.6.0'){throw 'R114 INSTALLED v1.6 SOURCE NOT EXACT'}
  # Explicitly terminate only the test app on this disposable VM so that the
  # *upgrader* itself is exercised without force-killing a user's unsaved state.
  Start-Sleep -Seconds 2
  Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue|ForEach-Object {
    try{[void]$_.CloseMainWindow(); if(!$_.WaitForExit(3000)){$_.Kill();$_.WaitForExit(3000)}}finally{$_.Dispose()}
  }
  if(@(Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count -ne 0){throw 'R114 CANNOT QUIESCE EPHEMERAL OLD APP'}
  if(!(Test-Path $Config -PathType Leaf)){
    # R114-F02: official Setup does not create user config before first full GUI startup.
    # Seed an explicit synthetic *user-owned* fixture only inside disposable CI;
    # its SHA must survive injected failure, success and idempotent update.
    $fixture='{"Theme":"Default","StartWithWindows":true,"ShowCpu":true,"ShowRam":true,"SafePlacement":true,"AutoCheckUpdates":false}'
    [IO.File]::WriteAllText($Config,$fixture,[Text.UTF8Encoding]::new($false))
    if(!(Test-Path $Config -PathType Leaf) -or
       (Get-Content $Config -Raw|ConvertFrom-Json).StartWithWindows -ne $true){
       throw 'R114 SYNTHETIC USER CONFIG FIXTURE INVALID'
    }
    $SyntheticUserConfigSeeded=$true
  }
  if(!(Test-Path $ConfigBak -PathType Leaf)){Copy-Item -LiteralPath $Config -Destination $ConfigBak}
  if(!(Test-Path $Backend -PathType Leaf)){throw 'R114 OLD SENSOR BACKEND NOT PRESENT'}
  $OldConfigHash=SHA $Config;$OldBackupHash=SHA $ConfigBak
  $OldBackendSHA=SHA $Backend
  $OldMainLive=SHA $AppExe;$OldStateHash=SHA $State
     $OldStartup=(Read-StartupRegistration)
   $WallpaperBefore=R114-WallpaperMode
  if(!$OldStartup){throw 'R114 OFFICIAL V16 STARTUP=1 NOT HONORED'}
  if(!(Test-Path -LiteralPath $OldManagedNote -PathType Leaf) -or
     !(Test-Path -LiteralPath $OldRootSource -PathType Leaf)){throw 'R114 OLD MANAGED DOCUMENTS NOT PRESENT'}
  New-Item -ItemType Directory -Path (Split-Path -Parent $TestSentinel) -Force|Out-Null
  [IO.File]::WriteAllText($TestSentinel,'R114 unique user-data sentinel retained over failed/successful upgrade',[Text.UTF8Encoding]::new($false))
  $OwnedFileSHA=SHA $TestSentinel
  $regItem=Get-ItemProperty $UninstallKey
  if($regItem.DisplayVersion -cne '1.6.0' -or $regItem.InstallLocation -cne $ProductDir){throw 'R114 CANONICAL V16 UNINSTALL REGISTRY NOT PRESENT'}

  $Step='NEGATIVE_USER_EDIT_PROTECTED'
  $doc=Join-Path $ProductDir 'Docs\README.md'
  $originalDoc=[IO.File]::ReadAllBytes($doc)
  try{
     [IO.File]::AppendAllText($doc,[Environment]::NewLine+'USER MODIFICATION MUST NEVER BE LOST',[Text.UTF8Encoding]::new($false))
     $editedSha=SHA $doc
     if($editedSha -ceq ( [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($originalDoc)).Replace('-','') )){throw 'R114 CONTROLLED EDIT FAILED'}
     $code=Run-Bounded $Candidate @('/update','/quiet') 30000
     if($code -ne 34){throw ('R114 REFUSED-TO-PRESERVE-USER-EDIT FAILED CODE='+$code)}
     if((SHA $doc) -cne $editedSha){throw 'R114 UPGRADE OVERWROTE USER MODIFIED FILE'}
     Expect-OldVersion
  }finally{[IO.File]::WriteAllBytes($doc,$originalDoc)}
  $UserModifiedFileGuard='PASS_REFUSED_UNAUTHORIZED_EDIT_WITH_NO_APP_MUTATION'

   $FaultRollback='NOT_RUN_TEST_HOOK_NOT_INCLUDED_IN_PRODUCTION'

  $Step='POSITIVE_SAME_ROOT_INPLACE_UPGRADE'
  $code=Run-Bounded $Candidate @('/update','/quiet') 90000
  if($code -ne 0){throw ('R114 TRUE INPLACE UPGRADE FAILED CODE='+$code)}
  if((SHA $AppExe) -cne $NewMainSha){throw 'R114 NEW INSTALLED MAIN NOT EXACT PUBLIC 1.7 SHA'}
  if((Get-Content $State -Raw|ConvertFrom-Json).Version -cne '1.7.0'){throw 'R114 STATE NOT UPDATED TO 1.7.0'}
  if((Get-ItemProperty $UninstallKey).DisplayVersion -cne '1.7.0'){throw 'R114 REGISTERED PRODUCT VERSION NOT UPDATED'}
  if(Test-Path -LiteralPath $OldRootSource -PathType Leaf){throw 'R114 LEGACY DUPLICATE ROOT SOURCE REMAINS'}
  if(Test-Path -LiteralPath $OldManagedNote -PathType Leaf){throw 'R114 SUPERSEDED OLD RELEASE DOC REMAINS'}
  if(!(Test-Path -LiteralPath $NewManagedNote -PathType Leaf)){throw 'R114 CURRENT DOCUMENTATION MISSING'}
  if(Test-Path -LiteralPath $UpgradeStage){throw 'R114 TRANSACTION BACKUPS NOT CLEANED AFTER ACCEPTANCE'}
  $NewMainInstalled=SHA $AppExe
  Assert-UserCanaries
  $NewStartup=(Read-StartupRegistration)
  if($NewStartup -cne $OldStartup){throw 'R114 USER STARTUP PREFERENCE CHANGED'}
   if((R114-WallpaperMode) -cne $WallpaperBefore){throw 'R114 WALLPAPER MODE OR ABSENT REGISTRY KEY CHANGED'}
  if((Get-FileHash (Join-Path $ProductDir 'Uninstall.exe')).Hash -cne (SHA $Candidate)){throw 'R114 MAINTENANCE UNINSTALLER STILL OLD SETUP'}
  $SuccessfulUpgrade='PASS_ONE_CANONICAL_ROOT_16_TO_17_WITH_EXACT_USER_DATA_SHA'
  $Step='POSITIVE_IDEMPOTENCE_NO_OVERWRITE'
  $stateHash=SHA $State;$mainHash=SHA $AppExe
  $code=Run-Bounded $Candidate @('/update','/quiet') 30000
  if($code -ne 0 -or (SHA $State) -cne $stateHash -or
     (SHA $AppExe) -cne $mainHash -or (Test-Path $UpgradeStage)){throw 'R114 SAME VERSION RUN WAS NOT BITWISE IDEMPOTENT'}
  Assert-UserCanaries
  $Idempotent='PASS_SAME_VERSION_NOOP_WITHOUT_USER_WRITES'

  $Step='NO_DUPLICATE_OR_ORPHAN_CHECK'
  if(!(Test-Path -LiteralPath $AppExe -PathType Leaf) -or
     (Test-Path -LiteralPath (Join-Path $env:ProgramFiles 'TaskbarMonitorEnhanced\TaskbarMonitorEnhanced.exe')) -or
     @(Get-ChildItem -LiteralPath $ProductDir -Directory -ErrorAction SilentlyContinue|Where-Object Name -match '^\.tbme-upgrade').Count -ne 0 -or
     @(Get-ChildItem -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall' -ErrorAction SilentlyContinue|Where-Object PSChildName -ceq 'TaskbarMonitorEnhanced').Count -ne 1){throw 'R114 DUPLICATE INSTALL OR OLD STAGING LEFTOVER'}
  $NoDuplicate='PASS_SINGLE_LOCALAPPDATA_ROOT_AND_ONE_UNINSTALL_REGISTRATION'
  $Status='PASS_REAL_V16_TO_V17_IN_PLACE_DATA_PRESERVATION_IDEMPOTENCE_NO_FAULT_HOOK'
  $Step='COMPLETE'
}catch{
  $Failure=$_.Exception.ToString()
  $Status='FAIL_CLOSED_NO_USER_HOST_MUTATION'
}finally{

  $receipt=[ordered]@{
   Schema=1;Revision='R114';Status=$Status;Phase=$Step
   TestHost='GITHUB_HOSTED_EPHEMERAL_WINDOWS'
   EventCommit=$env:GITHUB_SHA;CurrentPublic='v1.6.0'
   BaselineMainSHA256=$OldMainSha;NewCandidateMainSHA256=$NewMainSha
   PublishedPublicV17Source='eeac48c2ff201326c6a59e7ccc21c72c9a676160'
   OldConfigSHA256=$OldConfigHash;OldConfigBackupSHA256=$OldBackupHash
   OldSensorBackendSHA256=$OldBackendSHA
   AddedUserCanarySHA256=$OwnedFileSHA
   SyntheticUserConfigSeededOnlyOnHostedVM=$SyntheticUserConfigSeeded
   ExistingProcessTermination='TEST_RUNNER_ONLY_NOT_UPDATER'
   UserModifiedFileGuard=$UserModifiedFileGuard;InjectedFailureRollback=$FaultRollback
   SuccessfulUpgrade=$SuccessfulUpgrade;IdempotentSameVersion=$Idempotent
   NoDuplicateFinal=$NoDuplicate;ActualNewMainSHA256=$NewMainInstalled
   OriginalStartup=$OldStartup;PostUpdateStartup=$NewStartup
       WallpaperModeBefore=$WallpaperBefore;WallpaperModeAfter=(R114-WallpaperMode)
UninstallOldVersionInvoked=$false;NewFullInstallInsteadOfUpdate=$false
   PersonalMachineTouched=$false;FormalStableAccepted=$false
   StartedUtc=$StartUtc;FinishedUtc=(Get-Date).ToUniversalTime().ToString('o')
   Error=$Failure
  }
  $receipt|ConvertTo-Json -Depth 7 |Set-Content -LiteralPath $ReceiptPath -Encoding utf8
  Write-Output ('R114_UPGRADE_RAW_RECEIPT='+$ReceiptPath)
  Write-Output ('R114_UPGRADE_STATUS='+$Status+' PHASE='+$Step)
}
if($Failure){throw ('R114 IN_PLACE_UPGRADE_TEST_FAILED '+$Step+' '+$Failure)}
Write-Output 'R114_REAL_HOSTED_INPLACE_UPGRADE_ROLLBACK_DATA_IDEMPOTENCE_PASS'
exit 0
