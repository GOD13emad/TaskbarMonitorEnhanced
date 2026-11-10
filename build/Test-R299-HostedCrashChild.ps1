[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$CandidateSetup,
 [Parameter(Mandatory=$true)][string]$App,
 [Parameter(Mandatory=$true)][string]$Signal,
 [Parameter(Mandatory=$true)][string]$ExpectedSetupSha,
 [Parameter(Mandatory=$true)][string]$ExpectedPriorSetupSha,
 [Parameter(Mandatory=$true)][string]$ExpectedPriorMainSha,
 [Parameter(Mandatory=$true)][string]$ExpectedNewMainSha
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# Child is launched and terminated by its parent ONLY on a new GitHub-hosted
# Windows runner. This script NEVER tries to clean up or install drivers.
# Resolve the exact Git checkout HEAD in-process. The R394 Windows GUI
# PowerShell runspace must not start a console-subsystem git.exe, whose missing
# stdout caused a null-value .Trim() during hosted preflight. Supports detached
# checkout and loose or packed branch refs; invalid formats fail closed.
function Get-R299CheckoutHead {
 param([Parameter(Mandatory=$true)][string]$Repository)
 $gitDir=Join-Path $Repository '.git'
 if(!(Test-Path -LiteralPath $gitDir -PathType Container)){
  throw 'R299_CRASH_CHILD_GIT_DIRECTORY_MISSING'
 }
 $headFile=Join-Path $gitDir 'HEAD'
 if(!(Test-Path -LiteralPath $headFile -PathType Leaf)){
  throw 'R299_CRASH_CHILD_GIT_HEAD_MISSING'
 }
 $head=[IO.File]::ReadAllText($headFile).Trim()
 if($head -cmatch '^[a-f0-9]{40}$'){return $head}
 if($head -cnotmatch '^ref: (refs/heads/[A-Za-z0-9._/-]+)$'){
  throw 'R299_CRASH_CHILD_GIT_HEAD_FORMAT_UNTRUSTED'
 }
 $ref=[string]$Matches[1]
 if($ref.Contains('..') -or $ref.Contains('//') -or
    $ref.Contains('/.') -or $ref.EndsWith('/') -or $ref.EndsWith('.lock')){
  throw 'R299_CRASH_CHILD_GIT_REF_FORMAT_UNTRUSTED'
 }
 $loose=Join-Path $gitDir ($ref.Replace('/',[IO.Path]::DirectorySeparatorChar))
 $sha=$null
 if(Test-Path -LiteralPath $loose -PathType Leaf){
  $sha=[IO.File]::ReadAllText($loose).Trim()
 }else{
  $packed=Join-Path $gitDir 'packed-refs'
  if(!(Test-Path -LiteralPath $packed -PathType Leaf)){
   throw 'R299_CRASH_CHILD_GIT_REF_UNRESOLVED'
  }
  $matches=@([IO.File]::ReadAllLines($packed)|Where-Object {
   $_ -cmatch ('^[a-f0-9]{40} '+[regex]::Escape($ref)+'$')
  })
  if($matches.Count -ne 1){throw 'R299_CRASH_CHILD_GIT_PACKED_REF_NOT_UNIQUE'}
  $sha=[string]$matches[0].Substring(0,40)
 }
 if($sha -cnotmatch '^[a-f0-9]{40}$'){
  throw 'R299_CRASH_CHILD_GIT_RESOLVED_SHA_INVALID'
 }
 return $sha
}
# In-process SHA256 avoids importing Get-FileHash/PowerShell.Utility inside
# a restricted-Medium GUI runspace while preserving exact hash comparisons.
function Get-R299InProcessSHA256 {
 param([Parameter(Mandatory=$true)][string]$Path)
 if(-not [IO.Path]::IsPathRooted($Path)){throw 'R299_SHA_PATH_MUST_BE_ABSOLUTE'}
 $full=[IO.Path]::GetFullPath($Path)
 $algorithm=[Security.Cryptography.SHA256]::Create()
 try{
  $stream=[IO.File]::OpenRead($full)
  try{return [BitConverter]::ToString($algorithm.ComputeHash($stream)).Replace('-','')}
  finally{$stream.Dispose()}
 }finally{$algorithm.Dispose()}
}
try{
 if($PSVersionTable.PSEdition -cne 'Desktop' -or
    $env:GITHUB_ACTIONS -cne 'true' -or
    $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
    $env:RUNNER_OS -cne 'Windows' -or
    $env:GITHUB_REPOSITORY -cne 'GOD13emad/TaskbarMonitorEnhanced' -or
    $env:GITHUB_RUN_ID -cnotmatch '^[0-9]{5,20}$' -or
    $env:GITHUB_SHA -cnotmatch '^[a-f0-9]{40}$' -or
    $env:COMPUTERNAME -match '(?i)EMAD|ALIEMAD|LAPTOP|SAEID'){
  throw 'R299_CRASH_CHILD_REFUSES_ANY_NONDISPOSABLE_WINDOWS'
 }
 $expectedSignal=Join-Path $env:RUNNER_TEMP ('R299_ABRUPT_COMMITTING_ARMED_'+$env:GITHUB_RUN_ID+'.json')
 if(-not [string]::Equals([IO.Path]::GetFullPath($Signal),
      [IO.Path]::GetFullPath($expectedSignal),[StringComparison]::OrdinalIgnoreCase)){
  throw 'R299_CRASH_CHILD_REQUIRES_EXACT_RUNNER_TEMP_SIGNAL'
 }
 $entryPath=$Signal+'.entered.txt'
 if(Test-Path $entryPath){throw 'R299_CRASH_CHILD_ENTRY_SIGNAL_PREEXISTS'}
 $entryReceipt=[ordered]@{Pid=$PID;Phase='HOSTED_IDENTITY_VERIFIED';GitSha=$env:GITHUB_SHA;RunId=$env:GITHUB_RUN_ID}
 [IO.File]::WriteAllText($entryPath,($entryReceipt|ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false))
 # Single overwritten, per-run diagnostic inside RUNNER_TEMP. It starts only
 # AFTER exact hosted identity and runner-scoped signal path have been verified.
 # It is not an acceptance marker or a production file.
 $checkpointPath=$Signal+'.checkpoint.json'
 function Write-R299CrashCheckpoint {
  param([Parameter(Mandatory=$true)][string]$Phase)
  $checkpoint=[ordered]@{
   Pid=$PID;GitSha=$env:GITHUB_SHA;RunId=$env:GITHUB_RUN_ID
   Phase=$Phase;Utc=[DateTime]::UtcNow.ToString('o')
  }
  [IO.File]::WriteAllText($checkpointPath,($checkpoint|ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false))
 }
 Write-R299CrashCheckpoint 'BEFORE_REPO_RESOLVE'
 $repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
 Write-R299CrashCheckpoint 'BEFORE_INPROCESS_HEAD_READ'
 $head=(Get-R299CheckoutHead -Repository $repo)
 Write-R299CrashCheckpoint 'AFTER_INPROCESS_HEAD_READ'
 if($head -cne $env:GITHUB_SHA){
  throw 'R299_CRASH_CHILD_SOURCE_COMMIT_CHANGED'
 }
 $canonical=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'TaskbarMonitorEnhanced'
 if(-not [string]::Equals([IO.Path]::GetFullPath($App),
  [IO.Path]::GetFullPath($canonical),[StringComparison]::OrdinalIgnoreCase)){
  throw 'R299_CRASH_CHILD_REQUIRES_EXACT_TEST_ROOT'
 }
 Write-R299CrashCheckpoint 'CANONICAL_APP_VALIDATED'
 $main=Join-Path $App 'TaskbarMonitorEnhanced.exe'
 $priorSetup=Join-Path $App 'Uninstall.exe'
 $stage=Join-Path $App '.tbme-upgrade'
 if(Test-Path $stage){throw 'R299_CRASH_CHILD_STAGE_PREEXISTS'}
 Write-R299CrashCheckpoint 'BEFORE_BINARY_PINS'
 $pinIndex=0
 foreach($probe in @(
  @{p=$CandidateSetup;sha=$ExpectedSetupSha},
  @{p=$priorSetup;sha=$ExpectedPriorSetupSha},
  @{p=$main;sha=$ExpectedPriorMainSha}
 )){
  $pinIndex++
  if((Get-R299InProcessSHA256 -Path $probe.p) -cne $probe.sha){
   throw ('R299_CRASH_CHILD_BINARY_SHA_UNEXPECTED_'+$probe.p)
  }
  Write-R299CrashCheckpoint ('BINARY_PIN_'+$pinIndex+'_VALIDATED')
 }
 Write-R299CrashCheckpoint 'BINARY_PINS_VALIDATED'
 Write-R299CrashCheckpoint 'BEFORE_PROCESS_CHECK'
 if(@(Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count){throw 'R299_CRASH_CHILD_MAIN_RUNNING'}
 Write-R299CrashCheckpoint 'PROCESS_ABSENCE_VALIDATED'
 $oldState=Get-Content (Join-Path $App 'install_state.json') -Raw
 if($oldState -cnotmatch '"Version"\s*:\s*"1.7.9"'){throw 'R299_CRASH_CHILD_PRIOR_VERSION_CHANGED'}
 Write-R299CrashCheckpoint 'ALL_PREFLIGHT_PINS_VALIDATED'
 # Use original candidate Setup PE's unmodified private stage and journal
 # factories; reflect the exact same code used by real /update.
}catch{
 $preflightError=$_.Exception.ToString()
 if($env:GITHUB_ACTIONS -ceq 'true' -and
    $env:RUNNER_ENVIRONMENT -ceq 'github-hosted' -and
    $env:RUNNER_OS -ceq 'Windows' -and
    $env:COMPUTERNAME -notmatch '(?i)EMAD|ALIEMAD|LAPTOP|SAEID'){
  try{
   $preflightReceipt=[ordered]@{
    Marker='R299_CRASH_CHILD_PREFLIGHT_FAILURE'
    PSEdition=[string]$PSVersionTable.PSEdition
    Repository=[string]$env:GITHUB_REPOSITORY
    RunId=[string]$env:GITHUB_RUN_ID
    GitSha=[string]$env:GITHUB_SHA
    ComputerName=[string]$env:COMPUTERNAME
    Error=$preflightError
   }
   [IO.File]::WriteAllText($Signal+'.error.txt',($preflightReceipt|ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false))
  }catch{}
 }
 throw
}
$startupPath=$Signal+'.started.txt'
if(Test-Path $startupPath){throw 'R299_CRASH_CHILD_STARTUP_SIGNAL_ALREADY_EXISTS'}
$startupReceipt=[ordered]@{Pid=$PID;Phase='PREFLIGHT_PASSED';GitSha=$env:GITHUB_SHA;RunId=$env:GITHUB_RUN_ID;ComputerName=$env:COMPUTERNAME}
[IO.File]::WriteAllText($startupPath,($startupReceipt|ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false))
Write-R299CrashCheckpoint 'SETUP_REFLECTION_BEGIN'

try{
 $assembly=[Reflection.Assembly]::LoadFrom([IO.Path]::GetFullPath($CandidateSetup))
 $t=$assembly.GetType('SetupProgram',$true)
 $f=[Reflection.BindingFlags]'Static,NonPublic'
 $lex=$t.GetMethod('LegacyExpected',$f)
 $pre=$t.GetMethod('PrepareNewBytes',$f)
 $stageMethod=$t.GetMethod('StageNewManaged',$f)
 $write=$t.GetMethod('WritePhase',$f)
 if(!$lex -or !$pre -or !$stageMethod -or !$write){throw 'R299_CRASH_CHILD_PRIVATE_FACTORY_MISSING'}
 $v=[object[]]::new(2);$v[0]=[string]'1.7.9';$v[1]=[string]'OFFICIAL_STABLE_V179'
 $legacy=$lex.Invoke($null,$v)
 $s=[object[]]::new(1);$s[0]=[string]$oldState
 $newData=$pre.Invoke($null,$s)
 # Reflection runs under PowerShell; explicitly replace its unrelated @SELF
 # with exact current compiled candidate Setup bytes before staging.
 $newData['Uninstall.exe']=[IO.File]::ReadAllBytes($CandidateSetup)
 $a=[object[]]::new(5)
 $a[0]=$newData;$a[1]=$legacy;$a[2]=[string]$oldState
 $a[3]=[string]'1.7.9';$a[4]=[string]'OFFICIAL_STABLE_V179'
 [void]$stageMethod.Invoke($null,$a)
 Write-R299CrashCheckpoint 'MANAGED_STAGE_CREATED'
 $phase=[object[]]::new(1);$phase[0]=[string]'COMMITTING'
 [void]$write.Invoke($null,$phase)
 Write-R299CrashCheckpoint 'COMMITTING_JOURNAL_WRITTEN'
 # Two genuine replacements, still no registry/version commit.
 # Resolve the pre-existing .NET File.Replace overload without Add-Type/csc.exe,
 # which would start another restricted console-subsystem process. Reflection
 # preserves a true null backup argument; PowerShell's direct method binder
 # can turn that null into an invalid empty backup path.
 $replaceMethod=[IO.File].GetMethod('Replace',[type[]]@([string],[string],[string]))
 if(!$replaceMethod){throw 'R299_CRASH_CHILD_FILE_REPLACE_OVERLOAD_MISSING'}
 foreach($rel in @('TaskbarMonitorEnhanced.exe','Source/TaskbarMonitorEnhanced.cs')){
  $source=Join-Path (Join-Path $stage 'new') $rel
  $live=Join-Path $App $rel
  if(!(Test-Path $source) -or !(Test-Path $live)){throw ('R299_CRASH_CHILD_STAGED_PATH_MISSING_'+$rel)}
  $replaceArgs=[object[]]::new(3)
  $replaceArgs[0]=[string]$source
  $replaceArgs[1]=[string]$live
  $replaceArgs[2]=$null
  [void]$replaceMethod.Invoke($null,$replaceArgs)
 }
 if((Get-R299InProcessSHA256 -Path $main) -cne $ExpectedNewMainSha){
  throw 'R299_CRASH_CHILD_TWO_FILE_PARTIAL_MAIN_SHA_BAD'
 }
 if((Get-R299InProcessSHA256 -Path $priorSetup) -cne $ExpectedPriorSetupSha){
  throw 'R299_CRASH_CHILD_CHANGED_UNINSTALL_BEFORE_KILL'
 }
 if((Get-Content (Join-Path $stage 'phase.txt') -Raw) -cnotmatch '\|COMMITTING$'){
  throw 'R299_CRASH_CHILD_NOT_IN_COMMITTING_PHASE'
 }
 Write-R299CrashCheckpoint 'TWO_FILE_PARTIAL_COMMIT_VALIDATED'
 $ack=[ordered]@{Pid=$PID;Phase='COMMITTING';ChangedFiles=2;GitSha=$env:GITHUB_SHA;Utc=[DateTime]::UtcNow.ToString('o')}
 if(Test-Path $Signal){throw 'R299_CRASH_CHILD_SIGNAL_ALREADY_EXISTS'}
 [IO.File]::WriteAllText($Signal,($ack|ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false))
 # Parent will forcibly terminate exactly this one child process. Never exit
 # voluntarily or clean the stage: the real PE must replay its recovery.
 while($true){Start-Sleep -Seconds 2}
}catch{
 try{[IO.File]::WriteAllText($Signal+'.error.txt',$_.Exception.ToString(),[Text.UTF8Encoding]::new($false))}catch{}
 throw
}
