# R93 - actual process death after 4 managed file writes; next invocation must recover
# exact old v1.6/Preview1 managed bytes, user state, before a true positive same-root update.
# STRICTLY GitHub-hosted disposable Windows; never run on any user/maintainer PC.
[CmdletBinding()]
param(
 [ValidateSet('v16','preview1')][string]$Baseline='v16',
 [switch]$StaticOnly
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$OldSha=if($Baseline -ceq 'v16'){'F5130BC2F81383E16912454FCC62E307501885A6256E7241E674A9CF10BAC9C5'}else{'9A1B4F81C07CC39E3D5A329E89EFD834A9DFDC3D7BB6CF12812AC7C300E6B104'}
$OldMain=if($Baseline -ceq 'v16'){'05F9E069C4598FDAD327A41BF1CA34A1498D022119DB81E09F4B3B091C9BA377'}else{'63A724981E949BA4C91F8BD44F2659F223BDFE0350A2E229CEE7B05535D4BA70'}
$OldVersion=if($Baseline -ceq 'v16'){'1.6.0'}else{'1.7.0'}
$OldAsset=if($Baseline -ceq 'v16'){'TaskbarMonitorEnhanced_Setup_1.6.0.exe'}else{'TaskbarMonitorEnhanced_Setup_1.7.0_UNSIGNED_PREVIEW.exe'}
$OldUrl=if($Baseline -ceq 'v16'){
 'https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/download/v1.6.0/TaskbarMonitorEnhanced_Setup_1.6.0.exe'
}else{
 'https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/download/v1.7.0-unsigned-preview.1/TaskbarMonitorEnhanced_Setup_1.7.0_UNSIGNED_PREVIEW.exe'
}
$NewMain='63A724981E949BA4C91F8BD44F2659F223BDFE0350A2E229CEE7B05535D4BA70'
$Product=Join-Path $env:LOCALAPPDATA 'TaskbarMonitorEnhanced'
$Main=Join-Path $Product 'TaskbarMonitorEnhanced.exe'
$State=Join-Path $Product 'install_state.json'
$Config=Join-Path $Product 'config.json'
$ConfigBackup=Join-Path $Product 'config.json.bak'
$Backend=Join-Path $Product 'SensorBackend\LibreHardwareMonitor-0.9.6\LibreHardwareMonitorLib.dll'
$Stage=Join-Path $Product '.tbme-upgrade'
$RunKey='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$UninstallKey='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TaskbarMonitorEnhanced'
$CandidateOriginal=Join-Path $PSScriptRoot '_out\Setup\TaskbarMonitorEnhanced_Setup_1.7.0.exe'
$Candidate='' # set only after owned RUNNER_TEMP directory has been created
if($StaticOnly){
 $tokens=$null;$errors=$null
 [void][Management.Automation.Language.Parser]::ParseFile($PSCommandPath,[ref]$tokens,[ref]$errors)
 if(@($errors).Count){throw 'R93 PS7 HARNESS PARSER FAILED'}
 Write-Output ('R93_DISPOSABLE_'+$Baseline+'_STATIC_GUARD_PASS_NO_MUTATION')
 exit 0
}
if($env:GITHUB_ACTIONS -cne 'true' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
 $env:RUNNER_OS -cne 'Windows' -or $env:COMPUTERNAME -ceq 'EMAD-PC-ULTIMAT' -or
 [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)){throw 'R93 REFUSE NONDISPOSABLE WINDOWS'}
if((Test-Path $Product) -or (Test-Path $UninstallKey) -or
 @(Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count -gt 0){throw 'R93 REFUSE EXISTING INSTALL PRESTATE'}
foreach($root in @('C:\Program Files\TaskbarMonitorEnhanced\TaskbarMonitorEnhanced.exe','C:\Program Files (x86)\TaskbarMonitorEnhanced\TaskbarMonitorEnhanced.exe')){
 if(Test-Path -LiteralPath $root -PathType Leaf){throw 'R93 CONFLICTING PROGRAMFILES PRODUCT'}
}
$Temp=Join-Path $env:RUNNER_TEMP ('TBME_R93_ABRUPT_CRASH_'+$Baseline)
if(Test-Path -LiteralPath $Temp){throw 'R93 NO RERUN'}
New-Item -ItemType Directory -Path $Temp -ErrorAction Stop|Out-Null
# R93-F01: the actual production safety guard correctly refused abnormal-exit
# injection when the EXE was executed from the repository checkout, not RUNNER_TEMP.
# Only move exact SHA-verified bytes to a unique disposable RUNNER_TEMP-owned file.
$Candidate=Join-Path $Temp 'R93_CRASH_TEST_SETUP.exe'
if(Test-Path -LiteralPath $Candidate){throw 'R93 F01 OWNED CANDIDATE ALREADY EXISTS'}
if((Get-FileHash -LiteralPath $CandidateOriginal).Hash -cne 'DECF49222E5F5D2C1E246DE16BB00ED266A0550FD781CBC61DA6AB4A8645D903'){
    throw 'R93 F01 ARTIFACT SHA BEFORE OWNED COPY DIFFERENT'
}
Copy-Item -LiteralPath $CandidateOriginal -Destination $Candidate -ErrorAction Stop
if((Get-FileHash -LiteralPath $Candidate).Hash -cne 'DECF49222E5F5D2C1E246DE16BB00ED266A0550FD781CBC61DA6AB4A8645D903'){
    throw 'R93 F01 OWNED RUNNER_TEMP SETUP SHA DIFFERENT'
}
$OldSetup=Join-Path $Temp $OldAsset
$Sentinel=Join-Path $Product 'UserOwnedR93\crash-recovery-sentinel.txt'
$ReceiptPath=Join-Path $Temp 'R93_PROCESS_CRASH_RECOVERY_RECEIPT.json'
$Start=(Get-Date).ToUniversalTime().ToString('o')
$Phase='START';$Status='NOT_TESTED';$Failure=''
$CrashCode=-999;$InjectedFailureCode=-999;$PositiveCode=-999;$NoopCode=-999
$ObservedCrashJournal='NOT_OBSERVED';$OldBytesRecovered='NOT_VERIFIED';$PositiveUpgraded='NOT_RUN'
$ProtectedSHA=@{};$CandidateSha='';$OldManagedCount=0;$OldFilesShaBefore=@{}
$OriginalStartup='';$AfterStartup=''
function SH([string]$Path){
 if(!(Test-Path -LiteralPath $Path -PathType Leaf)){throw ('R93 FILE FOR SHA ABSENT '+$Path)}
 return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}
function ReadStartup{
 $key=Get-ItemProperty $RunKey -ErrorAction SilentlyContinue
 if($null -eq $key){return ''}
 $prop=$key.PSObject.Properties['TaskbarMonitorEnhanced']
 return $(if($null -eq $prop){''}else{[string]$prop.Value})
}
function StartBounded([string]$Exe,[string[]]$ChildArguments,[int]$Timeout){
 if($null -eq $ChildArguments -or $ChildArguments.Count -le 0){throw 'R93 AUTO_ARGS_COLLISION_GUARD'}
 $info=[Diagnostics.ProcessStartInfo]::new()
 $info.FileName=$Exe;$info.UseShellExecute=$false;$info.CreateNoWindow=$true
 foreach($item in $ChildArguments){[void]$info.ArgumentList.Add([string]$item)}
 if($info.ArgumentList.Count -ne $ChildArguments.Count){throw 'R93 ARGUMENT LOSS'}
 $child=$null
 try{
   $child=[Diagnostics.Process]::Start($info)
   if($null -eq $child){throw 'R93 CHILD NOT STARTED'}
   if(!$child.WaitForExit($Timeout)){try{$child.Kill();$child.WaitForExit(2000)}catch{};throw 'R93 BOUNDED CHILD TIMEOUT'}
   return [int]$child.ExitCode
 }finally{if($null -ne $child){$child.Dispose()}}
}
function AssertUserData{
 if((SH $Config) -cne $ProtectedSHA['Config'] -or
    (SH $ConfigBackup) -cne $ProtectedSHA['ConfigBackup'] -or
    (SH $Backend) -cne $ProtectedSHA['Backend'] -or
    (SH $Sentinel) -cne $ProtectedSHA['Sentinel']){
   throw 'R93 USER CONFIG/BACKUP/BACKEND/UNKNOWN FILE CHANGED'
 }
 if((ReadStartup) -cne $OriginalStartup){throw 'R93 STARTUP PREFERENCE MODIFIED'}
}
function AssertOldManaged {
 if(Test-Path -LiteralPath $Stage){throw 'R93 OWNED JOURNAL REMAINS AFTER RECOVERY'}
 foreach($name in $OldFilesShaBefore.Keys){
    $live=Join-Path $Product $name.Replace('/','\')
    if((SH $live) -cne [string]$OldFilesShaBefore[$name]){throw ('R93 OLD MANAGED FILE NOT RECOVERED '+$name)}
 }
 if((SH $State) -cne $ProtectedSHA['State']){throw 'R93 OLD INSTALL STATE NOT RECOVERED'}
 if((SH (Join-Path $Product 'Uninstall.exe')) -cne $OldSha){throw 'R93 OLD UNINSTALLER NOT RECOVERED'}
 if((Get-ItemProperty $UninstallKey).DisplayVersion -cne $OldVersion){throw 'R93 OLD REGISTERED VERSION NOT RECOVERED'}
 AssertUserData
}
try{
 $Phase='CANDIDATE_SUPPLY_CHAIN'
 $CandidateSha=SH $Candidate
 if((Get-AuthenticodeSignature $Candidate).Status -ne 'NotSigned'){throw 'R93 CANDIDATE MUST BE UNSIGNED'}
 $verify=Join-Path $Temp 'SETUP_READONLY_VERIFY.json'
 $rc=StartBounded $Candidate @('/verify',('/verifyfile='+$verify)) 35000
 if($rc -ne 0 -or !(Test-Path -LiteralPath $verify -PathType Leaf)){throw 'R93 CANDIDATE READONLY VERIFY FAILURE'}
 $self=Get-Content -LiteralPath $verify -Raw|ConvertFrom-Json
 if($self.Status -cne 'PASS' -or $self.Resources -ne 25 -or $self.PawnIOBundled -ne $false -or
    $self.EmbeddedMainSHA256 -cne $NewMain){throw 'R93 CANDIDATE MAIN/OSS CONTRACT DRIFT'}
 $Phase='OFFICIAL_BASELINE_DOWNLOAD'
 Invoke-WebRequest -Uri $OldUrl -OutFile $OldSetup -MaximumRedirection 5 -TimeoutSec 120 -ErrorAction Stop
 if((SH $OldSetup) -cne $OldSha){throw 'R93 PUBLISHED_BASELINE_INVALID_SHA'}
 $Phase='REAL_OFFICIAL_BASELINE_INSTALL'
 $rc=StartBounded $OldSetup @('/install','/quiet','/desktop=0','/startup=1') 180000
 if($rc -ne 0 -or (SH $Main) -cne $OldMain -or
    ((Get-Content $State -Raw|ConvertFrom-Json).Version) -cne $OldVersion){throw 'R93 EXACT BASELINE NOT INSTALLED'}
 Start-Sleep -Seconds 2
 Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue|ForEach-Object{
  try{[void]$_.CloseMainWindow();if(!$_.WaitForExit(3000)){$_.Kill();$_.WaitForExit(3000)}}finally{$_.Dispose()}
 }
 if(@(Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count){throw 'R93 BASELINE APP STILL RUNNING IN CI'}
 if(!(Test-Path -LiteralPath $Config -PathType Leaf)){
   [IO.File]::WriteAllText($Config,'{"Theme":"Default","StartWithWindows":true,"ShowCpu":true,"ShowRam":true,"SafePlacement":true}',[Text.UTF8Encoding]::new($false))
 }
 if(!(Test-Path -LiteralPath $ConfigBackup -PathType Leaf)){Copy-Item -LiteralPath $Config -Destination $ConfigBackup -ErrorAction Stop}
 if(!(Test-Path -LiteralPath $Backend -PathType Leaf)){throw 'R93 BASELINE BACKEND DLL MISSING'}
 New-Item -ItemType Directory -Path (Split-Path -Parent $Sentinel) -Force -ErrorAction Stop|Out-Null
 [IO.File]::WriteAllText($Sentinel,('R93 '+$Baseline+' UNTOUCHED CUSTOM USER FILE'),[Text.UTF8Encoding]::new($false))
 $ProtectedSHA=@{
  Config=(SH $Config);ConfigBackup=(SH $ConfigBackup);Backend=(SH $Backend);
  Sentinel=(SH $Sentinel);State=(SH $State)
 }
 $OriginalStartup=ReadStartup
 if(!$OriginalStartup){throw 'R93 ORIGINAL STARTUP=1 NOT REGISTERED'}
 $asm=[Reflection.Assembly]::LoadFrom($Candidate)
 $typ=$asm.GetType('SetupProgram',$true)
 $method=$typ.GetMethod('LegacyExpected',[Reflection.BindingFlags]'NonPublic,Static')
 if($null -eq $method){throw 'R93 TRUSTED PINNED OFFICIAL BASELINE MANIFEST NOT FOUND'}
 $param=[object[]]::new(1);$param[0]=$OldVersion
 $dict=$method.Invoke($null,$param)
 $OldManagedCount=$dict.Count
 if($OldManagedCount -ne $(if($Baseline -ceq 'v16'){21}else{23})){throw 'R93 OLD MANAGED COUNT NOT EXACT'}
 foreach($key in $dict.Keys){
    $file=Join-Path $Product ([string]$key).Replace('/','\')
    $expected=[string]$dict[$key]
    if((SH $file) -cne $expected){throw ('R93 OLD PUBLISHED RESOURCE SHA DIFFERENT '+$key)}
    $OldFilesShaBefore[[string]$key]=$expected
 }
 AssertUserData

 $Phase='ABRUPT_PROCESS_DEATH_DURING_DURABLE_COMMIT'
 $env:TBME_TEST_HARD_CRASH_AFTER_INDEX='4'
 try{$CrashCode=StartBounded $Candidate @('/update','/quiet') 60000}
 finally{Remove-Item Env:\TBME_TEST_HARD_CRASH_AFTER_INDEX -ErrorAction SilentlyContinue}
 if($CrashCode -eq 0 -or $CrashCode -eq 34){throw ('R93 EXPECT PROCESS DEATH, GOT '+$CrashCode)}
 $owner=Join-Path $Stage 'owner.txt'
 $phase=Join-Path $Stage 'phase.txt'
 $journal=Join-Path $Stage 'index.txt'
 $oldVersionFile=Join-Path $Stage 'previous_version.txt'
 foreach($p in @($owner,$phase,$journal,$oldVersionFile)){
  if(!(Test-Path $p -PathType Leaf)){throw ('R93 PROCESS DID NOT DIE DURING DURABLE JOURNAL '+$p)}
 }
 if([IO.File]::ReadAllText($owner) -cne 'TBME_UPGRADE_R92_OWNED_STAGE_V1' -or
    !([IO.File]::ReadAllText($phase).Contains('|COMMITTING')) -or
    [IO.File]::ReadAllText($oldVersionFile) -cne $OldVersion){throw 'R93 JOURNAL PRESTATE NOT TRUSTED COMMITTING'}
 $ObservedCrashJournal='PASS_COMMITTING_ON_DISK_WITH_EXACT_OWNER_AND_OLD_VERSION'
 AssertUserData
 if((Get-ItemProperty $UninstallKey).DisplayVersion -cne $OldVersion){throw 'R93 CRASH UNEXPECTEDLY PROMOTED REGISTRY'}

 $Phase='CRASH_RECOVERY_ON_NEXT_UPDATER_START_WITH_SECOND_FAULT'
 $env:TBME_TEST_FAIL_AFTER_INDEX='1'
 try{$InjectedFailureCode=StartBounded $Candidate @('/update','/quiet') 90000}
 finally{Remove-Item Env:\TBME_TEST_FAIL_AFTER_INDEX -ErrorAction SilentlyContinue}
 if($InjectedFailureCode -ne 34){throw ('R93 NEXT ATTEMPT DID NOT CATCH INJECTED SECOND FAULT CODE='+$InjectedFailureCode)}
 AssertOldManaged
 $OldBytesRecovered='PASS_ALL_OLD_SHA_RECOVERED_AFTER_PROCESS_DEATH_THEN_SECOND_FAULT'

 $Phase='POSITIVE_INPLACE_AFTER_RECOVERY'
 $PositiveCode=StartBounded $Candidate @('/update','/quiet') 90000
 if($PositiveCode -ne 0 -or (SH $Main) -cne $NewMain -or
    ((Get-Content $State -Raw|ConvertFrom-Json).Version) -cne '1.7.0' -or
    (SH (Join-Path $Product 'Uninstall.exe')) -cne $CandidateSha -or
    (Test-Path -LiteralPath $Stage) -or
    (Get-ItemProperty $UninstallKey).DisplayVersion -cne '1.7.0'){throw 'R93 POSITIVE RECOVERED SAME-ROOT UPGRADE FAILED'}
 AssertUserData
 $PositiveUpgraded='PASS_REAL_POSITIVE_AFTER_PROCESS_CRASH_AND_VERIFIED_OLD_RECOVERY'

 $Phase='IDEMPOTENT_RERUN_SINGLE_APP_ROOT'
 $beforeNewState=SH $State
 $NoopCode=StartBounded $Candidate @('/update','/quiet') 30000
 if($NoopCode -ne 0 -or (SH $State) -cne $beforeNewState -or
    (SH $Main) -cne $NewMain -or (Test-Path -LiteralPath $Stage)){throw 'R93 SAME INSTALLER RERUN NOT IDEMPOTENT'}
 AssertUserData
 if(Test-Path 'C:\Program Files\TaskbarMonitorEnhanced\TaskbarMonitorEnhanced.exe'){throw 'R93 DUPLICATE PROGRAMFILES APP'}
 if(@(Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall' -ErrorAction SilentlyContinue|
     Where-Object PSChildName -ceq 'TaskbarMonitorEnhanced').Count -ne 1){throw 'R93 DUPLICATE UNINSTALL REGISTRATION'}
 $AfterStartup=ReadStartup
 if($AfterStartup -cne $OriginalStartup){throw 'R93 PREFERENCE DRIFT AFTER NOOP'}
 $Phase='COMPLETE'
 $Status='PASS_ABRUPT_PROCESS_DEATH_JOURNAL_RECOVERY_INPLACE_AND_USER_DATA'
}catch{
 $Failure=$_.Exception.ToString();$Status='FAIL_CLOSED_R93_PROCESS_CRASH_TEST'
}finally{
 Remove-Item Env:\TBME_TEST_HARD_CRASH_AFTER_INDEX -ErrorAction SilentlyContinue
 Remove-Item Env:\TBME_TEST_FAIL_AFTER_INDEX -ErrorAction SilentlyContinue
 $receipt=[ordered]@{
  Schema=1;Revision='R93';Status=$Status;Phase=$Phase
  Baseline=$Baseline;OriginalVersion=$OldVersion;OldSetupSHA256=$OldSha;OriginalMainSHA256=$OldMain
  CandidateMainSHA256=$NewMain;CandidateSetupSHA256=$CandidateSha
  HostedVM='GITHUB_HOSTED_EPHEMERAL_WINDOWS';TestCommit=$env:GITHUB_SHA
  StartedUTC=$Start;FinishedUTC=(Get-Date).ToUniversalTime().ToString('o')
  AbruptProcessDeathExit=$CrashCode
  SecondFaultExitCode=$InjectedFailureCode;PositiveUpgradeExitCode=$PositiveCode;IdempotenceExitCode=$NoopCode
  DurableCrashJournal=$ObservedCrashJournal;ExactOldRecovery=$OldBytesRecovered
  PositiveSameRootUpgrade=$PositiveUpgraded;OldManagedSHAEntriesChecked=$OldManagedCount
  OriginalUserConfigSHA256=$ProtectedSHA['Config'];OriginalBackupSHA256=$ProtectedSHA['ConfigBackup']
  OriginalBackendSHA256=$ProtectedSHA['Backend'];CustomUserFileSHA256=$ProtectedSHA['Sentinel']
  OriginalStartup=$OriginalStartup;FinalStartup=$AfterStartup
  ExistingProductUninstalledFirst=$false;DuplicateProductInstalled=$false;SignedStableReady=$false
  RealPersonalPCMutated=$false
  AC_PowerLossDurabilityAccepted=$false;ProcessDeathReentryAccepted=($Status -like 'PASS*')
  Error=$Failure
 }
 $receipt|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $ReceiptPath -Encoding utf8
 Write-Output ('R93_CRASH_RAW_RECEIPT='+$ReceiptPath+' STATUS='+$Status+' PHASE='+$Phase)
}
if($Failure){throw ('R93 INDEPENDENT CRASH RECOVERY NOT ACCEPTED '+$Baseline+' '+$Failure)}
Write-Output ('R93_REAL_'+$Baseline+'_ABRUPT_PROCESS_DEATH_REENTRY_AND_SAME_ROOT_UPGRADE_PASS')
exit 0
