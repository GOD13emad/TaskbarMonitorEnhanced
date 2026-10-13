[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$CandidateDir,[Parameter(Mandatory=$true)][ValidateSet('A','B')][string]$HostLabel)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# Genuine product install/update is permitted ONLY on a fresh disposable hosted VM.
if($PSVersionTable.PSEdition -eq 'Core' -or $env:GITHUB_ACTIONS -cne 'true' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or $env:RUNNER_OS -cne 'Windows' -or $env:COMPUTERNAME -match 'EMAD-PC' -or ![Environment]::UserInteractive){throw 'R155_REFUSE_PERSONAL_OR_NONINTERACTIVE_HOST'}
Add-Type -AssemblyName System.Windows.Forms
$repo='GOD13emad/TaskbarMonitorEnhanced'
$app=Join-Path $env:LOCALAPPDATA 'TaskbarMonitorEnhanced'
$reg='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TaskbarMonitorEnhanced'
$out=Join-Path $env:RUNNER_TEMP ('TBME_R155_UPGRADE_'+$HostLabel)
if((Test-Path $out) -or (Test-Path $app) -or (Test-Path $reg) -or @(Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count){throw 'R155_NOT_FRESH_DISPOSABLE_HOST'}
$manifest=Get-Content (Join-Path $CandidateDir 'CANDIDATE.json') -Raw|ConvertFrom-Json
$setup=Join-Path $CandidateDir 'Setup\TaskbarMonitorEnhanced_Setup_1.7.2.exe'
if($manifest.Commit -cne $env:GITHUB_SHA -or $manifest.Version -cne '1.7.2' -or $manifest.Private -ne $true -or (Get-FileHash $setup -Algorithm SHA256).Hash -cne $manifest.SetupSHA256){throw 'R155_NOT_EXACT_VERSIONED_CANDIDATE'}
New-Item -ItemType Directory -Path $out|Out-Null
$phase='SOURCE_DOWNLOAD';$status='FAIL';$errorText='';$negative=0;$rollback=$false;$preserved=$false;$idempotent=$false;$downgrade=$false;$chain=@();$beforeProtected=@{};$evidence=@()
function Hash([string]$p){if(Test-Path -LiteralPath $p -PathType Leaf){return (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash};return 'MISSING'}
function Run-Exact([string]$path,[string]$Arguments,[int]$timeout=190000){
 $si=New-Object Diagnostics.ProcessStartInfo
 $si.FileName=$path;$si.Arguments=$Arguments;$si.UseShellExecute=$false;$si.WorkingDirectory=(Split-Path $path -Parent)
 $p=[Diagnostics.Process]::Start($si)
 if($null -eq $p){throw 'R155_SETUP_PROCESS_NOT_CREATED'}
 try{if(!$p.WaitForExit($timeout)){throw ('R155_SETUP_PROCESS_TIMEOUT PID='+$p.Id)};return [int]$p.ExitCode}finally{$p.Dispose()}
}
function StartupValue(){
 $k=Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue
 if($null -eq $k){return 'MISSING'};$p=$k.PSObject.Properties['TaskbarMonitorEnhanced'];if($null -eq $p){return 'MISSING'};return [string]$p.Value
}
function Snapshot(){
 $map=@{}
 $inventory=Get-Content (Join-Path $PSScriptRoot 'official-v171-managed.json') -Raw|ConvertFrom-Json
 $paths=@($inventory.Rows|ForEach-Object Path)+@('Docs/RELEASE_NOTES_v1.7.2.md','install_state.json','config.json','config.json.bak','R155_USER_OWNED.txt','SensorBackend/LibreHardwareMonitor-0.9.6/LibreHardwareMonitorLib.dll')
 # Exclude volatile sensor telemetry/log files, not owned by installer and free to change independently.
 foreach($rel in @($paths|Select-Object -Unique)){$map[$rel]=Hash (Join-Path $app $rel)}
 $map['@RegistryVersion']=[string](Get-ItemProperty $reg).DisplayVersion
 $map['@Startup']=StartupValue
 return $map
}
function Equal-Snapshot($a,$b,[string]$reason){
 if($a.Count -ne $b.Count){throw ('R155_SNAPSHOT_COUNT_CHANGED '+$reason)}
 foreach($k in $a.Keys){if(!$b.ContainsKey($k) -or $a[$k] -cne $b[$k]){throw ('R155_SNAPSHOT_CHANGED '+$reason+' '+$k)}}
}
try{
 & gh release download v1.7.1 --repo $repo --pattern TaskbarMonitorEnhanced_Setup_1.7.1.exe --dir $out
 if($LASTEXITCODE -ne 0){throw 'R155_OFFICIAL171_DOWNLOAD'}
 $priorSetup=Join-Path $out 'TaskbarMonitorEnhanced_Setup_1.7.1.exe'
 if((Hash $priorSetup) -cne 'ABD106630F7BAB3471CAF3F5BD4313DFCF2D61DDE1DF79E72EFE91933C8F2F89'){throw 'R155_PRIOR_SETUP_NOT_OFFICIAL_BYTES'}
 $phase='CREATE_GENUINE_171_PREDECESSOR'
 if($HostLabel -ceq 'B'){
  & gh release download v1.7.0 --repo $repo --pattern TaskbarMonitorEnhanced_Setup_1.7.0.exe --dir $out
  if($LASTEXITCODE -ne 0){throw 'R155_OFFICIAL170_DOWNLOAD'}
  $older=Join-Path $out 'TaskbarMonitorEnhanced_Setup_1.7.0.exe'
  if((Hash $older) -cne '148827212B716238DDB270309F393140EBE3CB935CD0E80D36233220A4BE611E'){throw 'R155_SOURCE170_WRONG_HASH'}
  if((Run-Exact $older '/install /quiet /desktop=0 /startup=0') -ne 0){throw 'R155_GENUINE170_INSTALL_FAILED'}
  if((Run-Exact $priorSetup '/update /quiet') -ne 0){throw 'R155_GENUINE170_TO_171_FAILED'}
  $chain=@('1.7.0','1.7.1')
 }else{
  if((Run-Exact $priorSetup '/install /quiet /desktop=0 /startup=0') -ne 0){throw 'R155_GENUINE171_INSTALL_FAILED'}
  $chain=@('1.7.1')
 }
 if((Hash (Join-Path $app 'TaskbarMonitorEnhanced.exe')) -cne 'D50A9D03190719B8385AB2F7F7DBB3129EC7EC1C77ECBD8EF7F29832AEC26420' -or (Get-ItemProperty $reg).DisplayVersion -cne '1.7.1'){throw 'R155_INSTALLED_171_IDENTITY_NOT_PROVEN'}
 $phase='KNOWN_USER_DATA_FIXTURE'
 $config=Join-Path $app 'config.json';$backup=Join-Path $app 'config.json.bak';$state=Join-Path $app 'install_state.json'
 $fixture='{"Theme":"Retro Terminal","Opacity":0.10,"GlassMode":false,"OpacityWhenGlassOff":0.10,"ConfigSchemaVersion":8,"StartWithWindows":false,"UpdateIntervalMs":1000,"ShowSparklines":true,"AutoCheckUpdates":false,"R155OwnerSentinel":"preserve user literal 1.7.1"}'
 [IO.File]::WriteAllText($config,$fixture,[Text.UTF8Encoding]::new($false))
 [IO.File]::WriteAllText($backup,'{"independent":"prior backup must not be overwritten"}',[Text.UTF8Encoding]::new($false))
 $userFile=Join-Path $app 'R155_USER_OWNED.txt';[IO.File]::WriteAllText($userFile,'User data, not installer-managed.',[Text.UTF8Encoding]::new($false))
 $sourceText=[IO.File]::ReadAllText($state)
 $expectedState=$sourceText.Replace('"Version": "1.7.1"','"Version": "1.7.2"').Replace('"PublicVersion": "1.7.1"','"PublicVersion": "1.7.2"')
 if($expectedState -ceq $sourceText){throw 'R155_ACTUAL_STATE_FORMAT_NOT_RECOGNIZED'}
 foreach($path in @($config,$backup,$userFile,(Join-Path $app 'SensorBackend\LibreHardwareMonitor-0.9.6\LibreHardwareMonitorLib.dll'))){if((Hash $path) -ceq 'MISSING'){throw ('R155_PROTECTED_INPUT_MISSING '+$path)};$beforeProtected[$path]=Hash $path}
 $startupBefore=StartupValue
 $phase='REJECT_EDITED_MANAGED_SOURCE'
 $managed=Join-Path $app 'Source\TaskbarGlass.cs';$original=[IO.File]::ReadAllBytes($managed)
 $changed=[byte[]]($original+[Text.Encoding]::UTF8.GetBytes("`n// deliberate owner edit: updater must refuse`n"))
 [IO.File]::WriteAllBytes($managed,$changed);$editedHash=Hash $managed
 $snap=Snapshot
 $code=Run-Exact $setup '/update /quiet'
 if($code -eq 0){throw 'R155_EDITED_SOURCE_ACCEPTED'}
 Equal-Snapshot $snap (Snapshot) 'EDITED_SOURCE_REFUSAL'
 if(Test-Path (Join-Path $app '.tbme-upgrade')){throw 'R155_REFUSAL_LEFT_STAGE'}
 if((Hash $managed) -cne $editedHash){throw 'R155_CONCURRENT_EDIT_CANNOT_RESTORE_FIXTURE'}
 [IO.File]::WriteAllBytes($managed,$original);$negative++
 $phase='REJECT_UNKNOWN_INSTALLED_VERSION'
 [IO.File]::WriteAllText($state,$sourceText.Replace('1.7.1','9.9.9'),[Text.UTF8Encoding]::new($false))
 $snap=Snapshot;$code=Run-Exact $setup '/update /quiet'
 if($code -eq 0){throw 'R155_UNKNOWN_VERSION_ACCEPTED'}
 Equal-Snapshot $snap (Snapshot) 'UNKNOWN_VERSION_REFUSAL'
 [IO.File]::WriteAllText($state,$sourceText,[Text.UTF8Encoding]::new($false));$negative++
 $phase='REAL_ROLLBACK_ENGINE_AFTER_SIMULATED_PARTIAL_COMMIT'
 # Exercise production journal and rollback code, without adding failure hooks to shipped binaries.
 # This is explicit simulated interruption, not a physical outage or real process-kill witness.
 $a=[Reflection.Assembly]::LoadFile([IO.Path]::GetFullPath($setup));$t=$a.GetType('SetupProgram',$true);$f=[Reflection.BindingFlags]'Static,NonPublic,Public'
 $legacy=$t.GetMethod('LegacyExpected',$f).Invoke($null,[object[]]@('1.7.1','OFFICIAL_STABLE_V171'))
 $fresh=$t.GetMethod('PrepareNewBytes',$f).Invoke($null,[object[]]@($sourceText))
 # Reflection host is PowerShell, so explicitly substitute EXACT verified Setup bytes for @SELF.
 $fresh['Uninstall.exe']=[IO.File]::ReadAllBytes($setup)
 $beforeRollback=Snapshot
 [void]$t.GetMethod('StageNewManaged',$f).Invoke($null,[object[]]@($fresh,$legacy,$sourceText,'1.7.1','OFFICIAL_STABLE_V171'))
 $stage=Join-Path $app '.tbme-upgrade'
 [void]$t.GetMethod('WritePhase',$f).Invoke($null,[object[]]@('COMMITTING'))
 foreach($rel in @('TaskbarMonitorEnhanced.exe','Source/TaskbarGlass.cs')){
  $staged=Join-Path (Join-Path $stage 'new') $rel;$live=Join-Path $app $rel
  [IO.File]::Replace($staged,$live,$null)
 }
 if((Hash (Join-Path $app 'TaskbarMonitorEnhanced.exe')) -cne $manifest.MainSHA256){throw 'R155_PARTIAL_COMMIT_NOT_REAL'}
 [void]$t.GetMethod('RecoverUpgradeStageIfAny',$f).Invoke($null,[object[]]@())
 if(Test-Path $stage){throw 'R155_ROLLBACK_STAGE_NOT_CLEARED'}
 Equal-Snapshot $beforeRollback (Snapshot) 'REAL_ROLLBACK_RESTORATION';$rollback=$true
 $phase='REAL_CLI_171_TO_172'
 $code=Run-Exact $setup '/update /quiet'
 if($code -ne 0){throw ('R155_REAL_UPGRADE_FAILED EXIT='+$code)}
 if((Hash (Join-Path $app 'TaskbarMonitorEnhanced.exe')) -cne $manifest.MainSHA256 -or (Hash (Join-Path $app 'Uninstall.exe')) -cne $manifest.SetupSHA256){throw 'R155_FINAL_BINARY_HASH_MISMATCH'}
 if((Get-ItemProperty $reg).DisplayVersion -cne '1.7.2' -or [IO.File]::ReadAllText($state) -cne $expectedState){throw 'R155_STATE_OR_REGISTRY_NOT_EXACT_172'}
 foreach($path in $beforeProtected.Keys){if((Hash $path) -cne $beforeProtected[$path]){throw ('R155_USER_DATA_CHANGED '+$path)}}
 if((StartupValue) -cne $startupBefore){throw 'R155_STARTUP_PREFERENCE_CHANGED'}
 if(Test-Path $stage){throw 'R155_STAGE_LEFT_AFTER_SUCCESS'}
 if(!(Test-Path (Join-Path $app 'Docs\RELEASE_NOTES_v1.7.2.md')) -or (Test-Path (Join-Path $app 'Docs\RELEASE_NOTES_v1.7.1.md'))){throw 'R155_RELEASE_NOTES_NOT_MIGRATED'}
 $registrations=@(Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'|Where-Object PSChildName -ceq 'TaskbarMonitorEnhanced')
 if($registrations.Count -ne 1 -or (Get-ItemProperty $reg).InstallLocation -cne $app){throw 'R155_DUPLICATE_OR_WRONG_ROOT'}
 $preserved=$true;$chain+=@('1.7.2')
 $phase='IDEMPOTENCE_AND_DOWNGRADE_REFUSAL'
 $after=Snapshot
 if((Run-Exact $setup '/update /quiet') -ne 0){throw 'R155_REPEATED_IDENTICAL_UPGRADE_FAILED'}
 Equal-Snapshot $after (Snapshot) 'IDENTICAL_REINSTALL';$idempotent=$true
 if((Run-Exact $priorSetup '/update /quiet') -eq 0){throw 'R155_OLD_INSTALLER_DOWNGRADE_ACCEPTED'}
 Equal-Snapshot $after (Snapshot) 'DOWNGRADE_REFUSAL';$downgrade=$true
 $status='PASS_GENUINE_171_TO_172_SINGLE_ROOT_PRESERVATION_ROLLBACK_IDEMPOTENCE'
}catch{$errorText=$_.Exception.ToString()}
finally{
 $r=[ordered]@{Revision='R155';Status=$status;Phase=$phase;Failure=$errorText;Host=$HostLabel;Commit=$env:GITHUB_SHA;SourceChain=$chain;MainSHA256=$manifest.MainSHA256;SetupSHA256=$manifest.SetupSHA256;RejectedUnsafeUpdates=$negative;RealProductionRollbackAfterSimulatedPartialCommit=$rollback;PhysicalPowerCutClaimed=$false;RealProcessKillClaimed=$false;ProtectedUserFilesPreserved=$preserved;IdenticalSetupIdempotent=$idempotent;DowngradeRefused=$downgrade;PersonalComputerTouched=$false;ProtectedSHA256=$beforeProtected}
 [IO.File]::WriteAllText((Join-Path $out 'R155_UPGRADE.json'),($r|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
 Write-Output ($r|ConvertTo-Json -Depth 8 -Compress)
}
if($status -notlike 'PASS_*'){throw ('R155_UPGRADE_ACCEPTANCE_FAILED '+$phase+' '+$errorText)}
