[CmdletBinding()]
param([ValidateSet('A')][string]$HostLabel='A')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# Disposable-host-only, one diagnostic installer execution, not a product update.
$base='2d23b6d0d4a6a9fb44ef52eaeae1fbecaa94048f'
$setupSHA='ABD106630F7BAB3471CAF3F5BD4313DFCF2D61DDE1DF79E72EFE91933C8F2F89'
if($PSVersionTable.PSEdition -cne 'Desktop' -or $env:GITHUB_ACTIONS -cne 'true' -or
  $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or $env:RUNNER_OS -cne 'Windows' -or
  $env:GITHUB_REPOSITORY -cne 'GOD13emad/TaskbarMonitorEnhanced' -or
  $env:GITHUB_REF -cne 'refs/heads/audit/r206-installer-prestate-observe' -or
  ![Environment]::UserInteractive -or $env:COMPUTERNAME -match 'EMAD|ALI|PERSONAL'){
  throw 'R206_REFUSE_NON_DISPOSABLE_OR_PERSONAL'
}
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
& git -C $repo merge-base --is-ancestor $base HEAD
if($LASTEXITCODE -ne 0 -or (& git -C $repo rev-parse HEAD).Trim() -cne $env:GITHUB_SHA){throw 'R206_REPO_SOURCE_NOT_PINNED'}
$changed=@(& git -C $repo diff --name-only $base HEAD)
$allowed=@('.github/workflows/diagnose-installer-r206.yml','build/Diagnose-HostedSetup-R206.ps1')
if($changed.Count -ne 2 -or @($changed|Where-Object {$_ -cnotin $allowed}).Count){throw 'R206_ONLY_TEST_FILES_ALLOWED'}
$app=Join-Path $env:LOCALAPPDATA 'TaskbarMonitorEnhanced'
$reg='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TaskbarMonitorEnhanced'
$out=Join-Path $env:RUNNER_TEMP ('TBME_R206_'+$HostLabel)
if((Test-Path $out) -or (Test-Path $app) -or (Test-Path $reg) -or
  @(Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count){
  throw 'R206_REQUIRES_FRESH_HOST'
}
New-Item -ItemType Directory -Path $out -ErrorAction Stop|Out-Null
$setup=Join-Path $out 'TaskbarMonitorEnhanced_Setup_1.7.1.exe'
$receipt=Join-Path $out 'R206_INSTALL_OBSERVE.json'
function SHA([string]$f){if(Test-Path -LiteralPath $f -PathType Leaf){return (Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash};return 'MISSING'}
$record=[ordered]@{
  Revision='R206';Objective='Observe exact installer and child process phase on a fresh independent Windows host'
  Status='FAIL_NO_EVIDENCE';Host=$HostLabel;GitCommit=$env:GITHUB_SHA
  BaselineCommit=$base;Official171SetupSHA256=$setupSHA
  OwnerComputerTouched=$false;ProductSourceUnmodified=$true;ReleaseMutation=$false
  StartedUTC=[DateTime]::UtcNow.ToString('o');ImageOS=$env:ImageOS;ImageVersion=$env:ImageVersion
  RunnerVersion=$env:RUNNER_VERSION;WindowsVersion=[Environment]::OSVersion.Version.ToString()
  EnableLUA=$null;ConsentPromptBehaviorAdmin=$null;InstallerPID=$null
  InstallerExited=$false;ExitCode=$null;TimedOut=$false;Samples=@()
  SensorHelperObserved=$false;PhaseEvidence='UNKNOWN';Failure='';FinishedUTC=$null
}
try{$pol=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -ErrorAction Stop;
  $record.EnableLUA=[int]$pol.EnableLUA;$record.ConsentPromptBehaviorAdmin=[int]$pol.ConsentPromptBehaviorAdmin}catch{}
$child=$null
function Sample([int]$elapsed){
  $all=@();$err=''
  try{$all=@(Get-CimInstance Win32_Process -ErrorAction Stop)}catch{$err=$_.Exception.GetType().Name}
  $set=New-Object 'System.Collections.Generic.HashSet[int]'
  [void]$set.Add([int]$script:child.Id)
  for($depth=0;$depth -lt 5;$depth++){
    $kids=@($all | Where-Object {$set.Contains([int]$_.ParentProcessId) -and !$set.Contains([int]$_.ProcessId)})
    if(!$kids.Count){break}
    foreach($k in $kids){[void]$set.Add([int]$k.ProcessId)}
  }
  $related=@()
  foreach($q in @($all|Where-Object {$set.Contains([int]$_.ProcessId)})){
    $related+=([ordered]@{
      Name=[string]$q.Name;PID=[int]$q.ProcessId;ParentPID=[int]$q.ParentProcessId
      Session=[int]$q.SessionId;Threads=[int]$q.ThreadCount
      UserTicks=[string]$q.UserModeTime;KernelTicks=[string]$q.KernelModeTime
      IsProtectedSensorHelper=[bool]([string]$q.CommandLine -match 'TBME_Setup_Elevated_Helper[.]ps1')
    })
  }
  # A UAC-elevated child may be parented by AppInfo rather than by Setup;
  # collect only well-known ephemeral helper names independent of ancestry.
  $watchNames=@('consent.exe','powershell.exe','pwsh.exe','conhost.exe','TaskbarMonitorSensorBroker.exe','TaskbarMonitorSensorSupervisor.exe')
  $observed=@()
  foreach($v in @($all|Where-Object {$_.Name -in $watchNames})){
    $observed+=([ordered]@{
      Name=[string]$v.Name;PID=[int]$v.ProcessId;ParentPID=[int]$v.ParentProcessId
      SessionId=[int]$v.SessionId
      IsProtectedHelper=[bool]([string]$v.CommandLine -match 'TBME_Setup_Elevated_Helper[.]ps1')
    })
  }
  $script:child.Refresh()
  $rootExists=[bool](Test-Path $app)
  $sensorResult=Join-Path $app 'Logs\sensor_install_result.json'
  $sensorLog=Join-Path $app 'Logs\sensor_install.log'
  $payloads=@(Get-ChildItem $env:TEMP -Directory -Filter 'tbme_setup_*' -ErrorAction SilentlyContinue)
  return [ordered]@{
    ElapsedMs=$elapsed;ProcessAlive=(!$script:child.HasExited);Related=$related;CimError=$err
    RelatedByProcessName=$observed;AppRoot=$rootExists;MainExists=[bool](Test-Path (Join-Path $app 'TaskbarMonitorEnhanced.exe'))
    StateExists=[bool](Test-Path (Join-Path $app 'install_state.json'))
    Registered=[bool](Test-Path $reg);SensorResultSHA=(SHA $sensorResult)
    SensorLogSHA=(SHA $sensorLog)
    SensorLogBytes=if(Test-Path $sensorLog){[long](Get-Item $sensorLog).Length}else{0}
    SensorPayloadDirectoryCount=[int]$payloads.Count
  }
}
try{
  # ONE controlled contrast against successful R204:
  # R205 materialized a SHA-pinned compiled candidate in RUNNER_TEMP before official installer.
  $candidateDir=Join-Path $env:RUNNER_TEMP 'TBME_R201_CANDIDATE'
  if(Test-Path $candidateDir){throw 'R206_CANDIDATE_DIR_NOT_FRESH'}
  New-Item -ItemType Directory -Path $candidateDir -ErrorAction Stop|Out-Null
  & gh run download 38638445612 --repo GOD13emad/TaskbarMonitorEnhanced --name R201-only-candidate-main --dir $candidateDir
  if($LASTEXITCODE -ne 0){throw 'R206_R205_CANDIDATE_SOURCE_MISSING'}
  $candidate=Join-Path $candidateDir 'TaskbarMonitorEnhanced.exe'
  $expectedCandidate='3448552CA6711D861BAD3739BEA77FC04626477DF64D5E30227BC95AF00771AF'
  if((SHA $candidate) -cne $expectedCandidate){throw 'R206_CANDIDATE_HASH_DRIFT'}
  $record.ContrastR205PrestateCandidateSHA256=(SHA $candidate)
  $record.ContrastArtifactSourceRun=38638445612
  & gh release download v1.7.1 --repo 'GOD13emad/TaskbarMonitorEnhanced' --pattern 'TaskbarMonitorEnhanced_Setup_1.7.1.exe' --dir $out
  if($LASTEXITCODE -ne 0 -or (SHA $setup) -cne $setupSHA){throw 'R206_NOT_PINNED_OFFICIAL_SETUP'}
  if((Test-Path $app) -or (Test-Path $reg)){throw 'R206_PRE_INSTALL_CONTAMINATION'}
  $si=New-Object Diagnostics.ProcessStartInfo
  $si.FileName=$setup;$si.Arguments='/install /quiet /desktop=0 /startup=0'
  $si.UseShellExecute=$false;$si.WorkingDirectory=$out
  $child=[Diagnostics.Process]::Start($si)
  if($null -eq $child){throw 'R206_START_RETURNED_NULL'}
  $record.InstallerPID=[int]$child.Id
  $watch=[Diagnostics.Stopwatch]::StartNew()
  $s=New-Object 'System.Collections.Generic.List[object]'
  $s.Add((Sample ([int]$watch.ElapsedMilliseconds)))
  for($i=0;$i -lt 28;$i++){
    $done=$child.WaitForExit(5000)
    $s.Add((Sample ([int]$watch.ElapsedMilliseconds)))
    if($done){break}
  }
  $watch.Stop()
  $record.Samples=@($s.ToArray())
  $record.InstallerExited=[bool]$child.HasExited
  $record.TimedOut=(!$record.InstallerExited)
  if($record.InstallerExited){$record.ExitCode=[int]$child.ExitCode}
  $helpers=@($record.Samples|ForEach-Object {$_.Related}|Where-Object IsProtectedSensorHelper)
  $record.SensorHelperObserved=($helpers.Count -gt 0)
  $record.NonDescendantHelperObserved=[bool](@($record.Samples|ForEach-Object {$_.RelatedByProcessName}|Where-Object IsProtectedHelper).Count)
  $sensorFiles=@($record.Samples|Where-Object {$_.SensorPayloadDirectoryCount -gt 0 -or $_.SensorLogBytes -gt 0})
  if($record.SensorHelperObserved){$record.PhaseEvidence='PROTECTED_HELPER_CHILD_OBSERVED'}
  elseif($sensorFiles.Count){$record.PhaseEvidence='SENSOR_STAGE_FILES_OBSERVED'}
  elseif(@($record.Samples|Where-Object MainExists).Count){$record.PhaseEvidence='MAIN_EXTRACTED_NOT_FURTHER_RESOLVED'}
  else{$record.PhaseEvidence='UNKNOWN_BEFORE_MAIN_EXTRACTION'}
  $record.Status=if($record.TimedOut){'PASS_DIAGNOSTIC_TIMEOUT_CAPTURED'}
    elseif($record.ExitCode -eq 0){'PASS_DIAGNOSTIC_COMPLETED'}
    else{'PASS_DIAGNOSTIC_EXIT_NONZERO'}
}catch{
  $record.Failure=$_.Exception.GetType().Name+': '+$_.Exception.Message
  $record.Status='FAIL_DIAGNOSTIC_CAPTURE'
}finally{
  if($null -ne $child){$child.Dispose()}
  $record.FinishedUTC=[DateTime]::UtcNow.ToString('o')
  [IO.File]::WriteAllText($receipt,($record|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
  Write-Output ($record|ConvertTo-Json -Depth 12 -Compress)
}
if($record.Status -notlike 'PASS_DIAGNOSTIC_*'){throw ('R206_DIAGNOSTIC_NOT_ACCEPTED '+$record.Failure)}
# A diagnostic PASS is NOT an installer release or product CPU acceptance.
