# R114 second independent upgrade lineage: immutable unsigned Preview1 v1.7.0
# -> corrected same-Main v1.7.0 Setup, WITHOUT uninstall/reinstall/data loss.
[CmdletBinding()]
param([switch]$StaticOnly)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$OldSetupSha='9A1B4F81C07CC39E3D5A329E89EFD834A9DFDC3D7BB6CF12812AC7C300E6B104'
$PublicMainSha='63A724981E949BA4C91F8BD44F2659F223BDFE0350A2E229CEE7B05535D4BA70'
$NewMainSha='B56E322826A86927999A00FB933C17979213798A68C8BB71C2176E68962E30EA'
$Product=Join-Path $env:LOCALAPPDATA 'TaskbarMonitorEnhanced'
$Main=Join-Path $Product 'TaskbarMonitorEnhanced.exe'
$State=Join-Path $Product 'install_state.json'
$Config=Join-Path $Product 'config.json'
$ConfigBackup=Join-Path $Product 'config.json.bak'
$Backend=Join-Path $Product 'SensorBackend\LibreHardwareMonitor-0.9.6\LibreHardwareMonitorLib.dll'
$Reg='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TaskbarMonitorEnhanced'
$RunReg='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$OldRootSource=Join-Path $Product 'TaskbarMonitorEnhanced.cs'
$CurrentDoc=Join-Path $Product 'Docs\RELEASE_NOTES_v1.7.0.md'
$Stage=Join-Path $Product '.tbme-upgrade'
$Sentinel=Join-Path $Product 'UserOwnedR114\my-profile.txt'
$Setup=Join-Path $PSScriptRoot '_out\Setup\TaskbarMonitorEnhanced_Setup_1.7.0.exe'
if($StaticOnly){
 $tokens=$null;$errors=$null
 [void][Management.Automation.Language.Parser]::ParseFile($PSCommandPath,[ref]$tokens,[ref]$errors)
 if($errors.Count){throw 'R114 PREVIEW1 HARNESS PARSER FAILED'}
 Write-Output 'R114_PREVIEW1_STATIC_ONLY_NO_MUTATION_PASS'
 exit 0
}
if($env:GITHUB_ACTIONS -cne 'true' -or $env:RUNNER_OS -cne 'Windows' -or
   $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or $env:COMPUTERNAME -ceq 'EMAD-PC-ULTIMAT' -or
   [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)){throw 'R114 PREVIEW1 REFUSE NONDISPOSABLE HOST'}
if((Test-Path -LiteralPath $Product) -or (Test-Path -LiteralPath $Reg) -or
   @(Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count -ne 0){
   throw 'R114 PREVIEW1 REFUSE EXISTING INSTALLATION AT START'
}
$Root=Join-Path $env:RUNNER_TEMP 'TBME_R114_Preview1Maintenance'
if(Test-Path -LiteralPath $Root){throw 'R114 PREVIEW1 NO UNSAFE RERUN'}
New-Item -ItemType Directory -Path $Root -ErrorAction Stop|Out-Null
$Prev=Join-Path $Root 'TaskbarMonitorEnhanced_Setup_1.7.0_UNSIGNED_PREVIEW.exe'
$Evidence=Join-Path $Root 'R114_PREVIEW1_MAINTENANCE_RECEIPT.json'
$Started=(Get-Date).ToUniversalTime().ToString('o')
$Status='NOT_RUN';$Phase='START';$ErrorMessage=''
$SyntheticUserConfigSeeded=$false
$FaultRollback='NOT_RUN';$MaintUpgrade='NOT_RUN';$Idempotence='NOT_RUN'
$ConfigSHA='';$BackupSHA='';$StateSHA='';$BackendSHA='';$UserSHA='';$RunBefore='';$RunAfter=''
$NewSetupSHA='';$NewInstalledSetupSHA='';$MaintenanceUpdateExit=-999;$MaintenanceFailurePart='NOT_EVALUATED';$MaintPostMainSHA='';$MaintPostUninstallerSHA='';$MaintPostStateVersion='';$MaintStagePresent=$false;$MaintenanceDiagnosticSHA='';$MaintenanceDiagnosticText=''
function FileSha([string]$Path){if(!(Test-Path -LiteralPath $Path -PathType Leaf)){throw ('R114 MISSING HASH INPUT '+$Path)};return (Get-FileHash -LiteralPath $Path).Hash}
function SafeRun([string]$File,[string[]]$ChildArguments,[int]$Timeout){
 if($null -eq $ChildArguments -or $ChildArguments.Count -eq 0){throw 'R114 ARGUMENT COLLISION'}
 $psi=[Diagnostics.ProcessStartInfo]::new()
 $psi.FileName=$File;$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true
 foreach($arg in $ChildArguments){[void]$psi.ArgumentList.Add($arg)}
 if($psi.ArgumentList.Count -ne $ChildArguments.Count){throw 'R114 ARGS NOT FORWARDED'}
 $p=$null
 try{
   $p=[Diagnostics.Process]::Start($psi)
   if(!$p.WaitForExit($Timeout)){try{$p.Kill();$p.WaitForExit(2000)}catch{};throw 'R114 BOUNDED CHILD TIMEOUT'}
   return [int]$p.ExitCode
 }finally{if($p){$p.Dispose()}}
}
function ReadRun{
 $bag=Get-ItemProperty -Path $RunReg -ErrorAction SilentlyContinue
 if($null -eq $bag){return ''}
 $prop=$bag.PSObject.Properties['TaskbarMonitorEnhanced']
 return $(if($null -eq $prop){''}else{[string]$prop.Value})
}
function AssertPreserved{
 if((FileSha $Config) -cne $ConfigSHA -or (FileSha $ConfigBackup) -cne $BackupSHA -or
    (FileSha $Backend) -cne $BackendSHA -or (FileSha $Sentinel) -cne $UserSHA){
    throw 'R114 PREVIEW1 USER CONFIG OR UNKNOWN FILE OR SENSOR BACKEND MODIFIED'
 }
 if((ReadRun) -cne $RunBefore){throw 'R114 PREVIEW1 STARTUP PREFERENCE CHANGED'}
}
function CheckOldRestored{
 if((FileSha $Main) -cne $PublicMainSha -or
    (FileSha (Join-Path $Product 'Uninstall.exe')) -cne $OldSetupSha -or
    (FileSha $State) -cne $StateSHA -or
    !(Test-Path $OldRootSource -PathType Leaf) -or
    (Test-Path $Stage)){throw 'R114 PREVIEW1 OLD MANAGED FILES DID NOT ROLLBACK'}
 AssertPreserved
}
try{
 $Phase='OFFICIAL_PREVIEW1_SETUP_DOWNLOAD'
 $url='https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/download/v1.7.0-unsigned-preview.1/TaskbarMonitorEnhanced_Setup_1.7.0_UNSIGNED_PREVIEW.exe'
 Invoke-WebRequest -Uri $url -OutFile $Prev -MaximumRedirection 5 -TimeoutSec 120 -ErrorAction Stop
 if((FileSha $Prev) -cne $OldSetupSha -or (Get-Item $Prev).Length -ne 8322560){throw 'IMMUTABLE PUBLISHED PREVIEW1 SETUP HASH DRIFT'}
 $NewSetupSHA=FileSha $Setup
 if((Get-AuthenticodeSignature $Setup).Status -ne 'NotSigned'){throw 'UPGRADE CANDIDATE SHOULD BE UNSIGNED FOR PREVIEW'}
 $Phase='REAL_PUBLIC_PREVIEW1_INSTALL'
 $rc=SafeRun $Prev @('/install','/quiet','/desktop=0','/startup=1') 180000
 if($rc -ne 0 -or (FileSha $Main) -cne $PublicMainSha -or
   ((Get-Content $State -Raw|ConvertFrom-Json).Version) -cne '1.7.0'){throw 'R114 PREVIEW1 BASELINE INSTALL NOT EXACT'}
 Start-Sleep -Seconds 2
 Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue |ForEach-Object{
  try{[void]$_.CloseMainWindow();if(!$_.WaitForExit(3000)){$_.Kill();$_.WaitForExit(3000)}}finally{$_.Dispose()}
 }
 if(@(Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count){throw 'R114 PREVIEW1 APP STILL RUNNING'}
 if(!(Test-Path $Config -PathType Leaf)){
   # R114-F02: the signed-off Preview Setup installs binaries but config is created
   # only on a completed normal GUI first-run. Seed test-owned user preferences.
   $fixture='{"Theme":"Default","StartWithWindows":true,"ShowCpu":true,"ShowRam":true,"SafePlacement":true,"AutoCheckUpdates":false}'
   [IO.File]::WriteAllText($Config,$fixture,[Text.UTF8Encoding]::new($false))
   if(!(Test-Path $Config -PathType Leaf) -or
      (Get-Content $Config -Raw|ConvertFrom-Json).StartWithWindows -ne $true){
      throw 'R114 PREVIEW1 TEST-OWNED CONFIG FIXTURE NOT PARSEABLE'
   }
   $SyntheticUserConfigSeeded=$true
 }
 if(!(Test-Path $ConfigBackup -PathType Leaf)){Copy-Item -LiteralPath $Config -Destination $ConfigBackup}
 if(!(Test-Path $Backend -PathType Leaf) -or !(Test-Path $OldRootSource -PathType Leaf) -or
     !(Test-Path $CurrentDoc -PathType Leaf)){throw 'R114 PREVIEW1 MANAGED USER BASELINE INCOMPLETE'}
 New-Item -ItemType Directory -Path (Split-Path -Parent $Sentinel) -Force |Out-Null
 [IO.File]::WriteAllText($Sentinel,'PERSIST USER FILE IN SAME ROOT ACROSS SAME-SEMVER UPGRADE',[Text.UTF8Encoding]::new($false))
 $ConfigSHA=FileSha $Config;$BackupSHA=FileSha $ConfigBackup
 $BackendSHA=FileSha $Backend;$StateSHA=FileSha $State;$UserSHA=FileSha $Sentinel
 $RunBefore=ReadRun
 if(!$RunBefore){throw 'R114 PREVIEW1 ORIGINAL STARTUP=1 ABSENT'}
 if((FileSha (Join-Path $Product 'Uninstall.exe')) -cne $OldSetupSha){throw 'R114 PREVIEW1 MAINTENANCE BASELINE NOT OFFICIAL'}

  $Phase='NEGATIVE_USER_MODIFIED_DOC_FAIL_CLOSED'
  $readme=Join-Path $Product 'Docs\README.md'
  $original=[IO.File]::ReadAllBytes($readme)
  try{
      [IO.File]::AppendAllText($readme,[Environment]::NewLine+'R114 USER EDIT MUST NEVER BE REPLACED',[Text.UTF8Encoding]::new($false))
      $edited=FileSha $readme
      $rc=SafeRun $Setup @('/update','/quiet') 30000
      if($rc -ne 34 -or (FileSha $readme) -cne $edited){throw 'R114 PREVIEW1 FAILED TO REJECT EDITED PROGRAM FILE'}
      CheckOldRestored
  }finally{[IO.File]::WriteAllBytes($readme,$original)}
  $FaultRollback='NOT_RUN_TEST_HOOK_REMOVED; NEGATIVE_EDIT_REJECTION_PASS'

 $Phase='REAL_PREVIEW1_MAINTENANCE_UPDATE'
 # CI-only guarded diagnostic, exact owner RUNNER_TEMP, never any user's AppRoot.
 $diagPath=Join-Path $Root 'R114_UPGRADE_ERROR.txt'
 if(Test-Path -LiteralPath $diagPath){throw 'R114 NO BLIND OVERWRITE OF DIAGNOSTIC'}
 $env:TBME_TEST_UPGRADE_ERROR_PATH=$diagPath
 try{$rc=SafeRun $Setup @('/update','/quiet') 90000}
 finally{Remove-Item Env:\TBME_TEST_UPGRADE_ERROR_PATH -ErrorAction SilentlyContinue}
 if(Test-Path -LiteralPath $diagPath -PathType Leaf){
    $MaintenanceDiagnosticSHA=FileSha $diagPath
    $MaintenanceDiagnosticText=Get-Content -LiteralPath $diagPath -Raw
    if(!$MaintenanceDiagnosticText.StartsWith('R114_CI_ONLY_UPGRADE_FAILURE')){throw 'R114 CI DIAGNOSTIC ORIGIN INVALID'}
 }
 $MaintenanceUpdateExit=$rc
 $MaintPostMainSHA=if(Test-Path -LiteralPath $Main -PathType Leaf){FileSha $Main}else{'MISSING'}
 $maintUninstall=Join-Path $Product 'Uninstall.exe'
 $MaintPostUninstallerSHA=if(Test-Path -LiteralPath $maintUninstall -PathType Leaf){FileSha $maintUninstall}else{'MISSING'}
 $MaintPostStateVersion=if(Test-Path -LiteralPath $State -PathType Leaf){
   [string](Get-Content $State -Raw|ConvertFrom-Json).Version
 }else{'MISSING'}
 $MaintStagePresent=Test-Path -LiteralPath $Stage
 if($rc -ne 0){
   $MaintenanceFailurePart='UPDATER_RETURNED_'+$rc
   $detail=if($MaintenanceDiagnosticText.Length -gt 1900){$MaintenanceDiagnosticText.Substring(0,1900)}else{$MaintenanceDiagnosticText}
   throw ('R114 SAME VERSION UPDATER RETURNED '+$rc+' HOSTED_EXCEPTION: '+$detail)
 }
 if($MaintPostMainSHA -cne $NewMainSha){$MaintenanceFailurePart='INSTALLED_MAIN_SHA';throw 'R114 MAIN HASH DIFFERED AFTER MAINTENANCE'}
 if($MaintPostStateVersion -cne '1.7.0'){$MaintenanceFailurePart='INSTALLED_STATE_VERSION';throw 'R114 STATE VERSION WRONG AFTER MAINTENANCE'}
 if($MaintPostUninstallerSHA -cne $NewSetupSHA){
   $MaintenanceFailurePart='UNINSTALLER_SHA'
   throw ('R114 MAINTENANCE UNINSTALLER NOT SAME CANDIDATE SHA, actual='+$MaintPostUninstallerSHA)
 }
 $MaintenanceFailurePart='NONE'
 if(Test-Path $OldRootSource -PathType Leaf){throw 'R114 DUPLICATE ROOT SOURCE NOT REMOVED'}
 if(Test-Path $Stage){throw 'R114 BACKUP STAGING DID NOT CLEAN'}
 if(!(Test-Path $CurrentDoc -PathType Leaf)){throw 'R114 CURRENT SOURCE DOCUMENTS LOST'}
 AssertPreserved
 $MaintUpgrade='PASS_PREVIEW1_TO_NEW_MAIN_EXACT_SHA_INPLACE_DATA_PRESERVED'
 $NewInstalledSetupSHA=FileSha (Join-Path $Product 'Uninstall.exe')
 $RunAfter=ReadRun

 $Phase='SAME_VERSION_NOOP'
 $preHash=FileSha $State
 $rc=SafeRun $Setup @('/update','/quiet') 30000
 if($rc -ne 0 -or (FileSha $State) -cne $preHash -or
    (FileSha (Join-Path $Product 'Uninstall.exe')) -cne $NewSetupSHA -or
    (Test-Path $Stage)){throw 'R114 RERUN CHANGED SAME VERSION OR LEFT STAGING'}
 AssertPreserved
 $Idempotence='PASS_TRUE_NOOP_ON_SAME_MAINTENANCE_BUILD'
 if(Test-Path (Join-Path $env:ProgramFiles 'TaskbarMonitorEnhanced\TaskbarMonitorEnhanced.exe')){throw 'R114 SECOND PRODUCT MAIN UNDER PROGRAMFILES'}
 if(@(Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall' -ErrorAction SilentlyContinue |Where-Object PSChildName -ceq 'TaskbarMonitorEnhanced').Count -ne 1){throw 'R114 DUPLICATE UNINSTALL REGISTRY'}
 $Phase='COMPLETE'
 $Status='PASS_PREVIEW1_TO_CORRECTED_INSTALLER_SAME_VERSION_IN_PLACE'
}catch{
 $ErrorMessage=$_.Exception.ToString()
 $Status='FAIL_CLOSED_PREVIEW1_MAINTENANCE'
}finally{

 $record=[ordered]@{Schema=1;Revision='R114';Branch='PUBLIC_UNSIGNED_PREVIEW1_SAME_VERSION_MAINTENANCE'
 Status=$Status;Phase=$Phase;Host='GITHUB_HOSTED_EPHEMERAL_WINDOWS'
 TestCommit=$env:GITHUB_SHA;CurrentPublicPreviewSource='eeac48c2ff201326c6a59e7ccc21c72c9a676160'
 OldPreviewInstallerSHA256=$OldSetupSha;NewCandidateInstallerSHA256=$NewSetupSHA
   OldMainSHA256=$PublicMainSha;NewMainSHA256=$NewMainSha;OldConfigSHA256=$ConfigSHA;OldConfigBackupSHA256=$BackupSHA
 SensorBackendSHA256=$BackendSHA;UserFileSHA256=$UserSHA
   SyntheticUserConfigSeededOnlyOnHostedVM=$SyntheticUserConfigSeeded
 FaultRollback=$FaultRollback;RealSameVersionUpgrade=$MaintUpgrade;Idempotence=$Idempotence
 MaintenanceUpdateExitCode=$MaintenanceUpdateExit
 MaintenanceDiagnosticSHA256=$MaintenanceDiagnosticSHA
 MaintenanceDiagnosticText=$MaintenanceDiagnosticText
 MaintenanceFailurePart=$MaintenanceFailurePart
 MainSHAAfterAttempt=$MaintPostMainSHA
 UninstallSHAAfterAttempt=$MaintPostUninstallerSHA
 StateVersionAfterAttempt=$MaintPostStateVersion
 UpgradeJournalPresentAfterAttempt=$MaintStagePresent
 InstalledNewMaintenanceSHA256=$NewInstalledSetupSHA;OldStartup=$RunBefore;NewStartup=$RunAfter
 UninstalledOldVersionFirst=$false;DuplicateProgramRootCreated=$false
 PersonalPCModified=$false;StableReleaseReady=$false
 StartedUtc=$Started;FinishedUtc=(Get-Date).ToUniversalTime().ToString('o');Error=$ErrorMessage}
 $record|ConvertTo-Json -Depth 7|Set-Content -LiteralPath $Evidence -Encoding utf8
 Write-Output ('R114_PREVIEW1_REAL_UPGRADE_RECEIPT='+$Evidence+' STATUS='+$Status)
}
if($ErrorMessage){throw ('R114 PREVIEW1 REAL SAME_VERSION UPGRADE FAILED '+$Phase+' '+$ErrorMessage)}
Write-Output 'R114_PREVIEW1_INPLACE_MAINTENANCE_FAULT_ROLLBACK_DATA_RETENTION_PASS'
exit 0
