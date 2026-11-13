[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$SupervisorPath,
 [Parameter(Mandatory=$true)][string]$SourceRoot,
 [switch]$HostedGuest
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($PSVersionTable.PSEdition -cne 'Desktop'){throw 'R407_REQUIRES_WINDOWS_POWERSHELL_51'}
if($HostedGuest -and ($env:GITHUB_ACTIONS -cne 'true' -or
    $env:RUNNER_OS -cne 'Windows' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted')){
 throw 'R407_REQUIRES_DISPOSABLE_WINDOWS_HOST'
}
$root=(Resolve-Path -LiteralPath $SourceRoot).Path
$binary=(Resolve-Path -LiteralPath $SupervisorPath).Path
$expected=Join-Path $root 'build\_out\Supervisor\TaskbarMonitorSensorSupervisor.exe'
if(![string]::Equals($binary,[IO.Path]::GetFullPath($expected),
     [StringComparison]::OrdinalIgnoreCase)){throw 'R407_WRONG_COMPILED_SUPERVISOR'}
$source=[IO.File]::ReadAllText((Join-Path $root 'src\sensors\TaskbarMonitorSensorSupervisor.cs'))
foreach($required in @(
 'using(BrokerLaunchLease pinned=PinCurrentBrokerLaunch(w.Mode,w.Output))',
 'using(BrokerLaunchLease pinned=PinCurrentBrokerLaunch("--once-storage",StorageOutput))',
 'BrokerLaunchLease.Acquire(BrokerPath,mode,output,',
 'Process p=Process.Start(psi);',
 'ShareReadWrite=3,OpenExisting=3',
 'GenericRead=0x80000000',
 'isDirectory?ReadAttributes:GenericRead',
 'GetFinalPathNameByHandle(',
 'GetFileInformationByHandleEx(')){
 if(!$source.Contains($required)){throw ('R407_LAUNCH_LEASE_SOURCE_GUARD_MISSING_'+$required)}
}
$asm=[Reflection.Assembly]::LoadFrom($binary)
$type=$asm.GetType('TaskbarMonitorSensorSupervisor+BrokerLaunchLease',$true)
$method=$type.GetMethod('Acquire',[Reflection.BindingFlags]'Static,NonPublic')
if(!$method -or $method.GetParameters().Length -ne 6){throw 'R407_COMPILED_LEASE_API_MISSING'}
function Acquire([string]$broker,[string]$mode,[string]$output,[string]$program,
                 [string]$profile,[string]$local){
 try{
  $lease=$method.Invoke($null,[object[]]@($broker,$mode,$output,$program,$profile,$local))
  return [pscustomobject]@{Lease=$lease;Rejected=$false;Error=''}
 }catch{
  $e=$_.Exception
  while($e.InnerException){$e=$e.InnerException}
  return [pscustomobject]@{Lease=$null;Rejected=$true;Error=$e.GetType().Name}
 }
}
$testRoot=[IO.Path]::GetFullPath((Join-Path $env:TEMP ('tbme-r407-broker-'+[guid]::NewGuid().ToString('N'))))
if(Test-Path -LiteralPath $testRoot){throw 'R407_TEST_ROOT_COLLISION'}
$program=Join-Path $testRoot 'Program Files'
$brokerDir=Join-Path $program 'TaskbarMonitorEnhanced\SensorBroker'
$broker=Join-Path $brokerDir 'TaskbarMonitorSensorBroker.exe'
$profile=Join-Path $testRoot 'Profile With Spaces'
$local=Join-Path $profile 'AppData\Local'
$owner=Join-Path $local 'TaskbarMonitorEnhanced'
$cpu=Join-Path $owner 'cpu_temp_broker.json'
$storage=Join-Path $owner 'storage_temp_broker.json'
$outside=Join-Path $testRoot 'outside'
[void][IO.Directory]::CreateDirectory($brokerDir)
[void][IO.Directory]::CreateDirectory($owner)
[void][IO.Directory]::CreateDirectory($outside)
$active=$null
try{
 if($HostedGuest){
  $fixtureSource=@'
using System;
public class R407HarmlessBroker {
 public static int Main(string[] args) { return 0; }
}
'@
  Add-Type -TypeDefinition $fixtureSource -OutputAssembly $broker -OutputType ConsoleApplication -ErrorAction Stop
 }else{
  [IO.File]::WriteAllText($broker,'HARMLESS_R407_NOT_EXECUTABLE')
 }
 [IO.File]::WriteAllText($cpu,'{"available":false}')
 $brokerSha=(Get-FileHash $broker -Algorithm SHA256).Hash
 $cpuSha=(Get-FileHash $cpu -Algorithm SHA256).Hash
 $canary=Join-Path $outside 'CANARY.txt'
 [IO.File]::WriteAllText($canary,'R407_NEVER_MODIFY')
 $canarySha=(Get-FileHash $canary -Algorithm SHA256).Hash

 $valid=Acquire $broker '--run-cpu' $cpu $program $profile $local
 if($valid.Rejected -or !$valid.Lease){throw ('R407_CANONICAL_LEASE_REJECTED_'+$valid.Error)}
 $active=$valid.Lease
 'R407_PASS_COMPILED_NATIVE_FILE_AND_ANCESTOR_HANDLES_ACQUIRED'

 $count=0
 foreach($kind in @('write-broker','rename-broker','rename-program',
                      'rename-protected-app','rename-broker-directory',
                      'rename-profile','rename-appdata','rename-local',
                      'rename-owner','rename-output')){
  $blocked=$false
  try{
   switch($kind){
    'write-broker' {[IO.File]::WriteAllText($broker,'UNTRUSTED_WRITE')}
    'rename-broker' {[IO.File]::Move($broker,($broker+'.swap'))}
    'rename-program' {[IO.Directory]::Move($program,($program+'.swap'))}
    'rename-protected-app' {[IO.Directory]::Move((Join-Path $program 'TaskbarMonitorEnhanced'),(Join-Path $program 'TaskbarMonitorEnhanced.swap'))}
    'rename-broker-directory' {[IO.Directory]::Move($brokerDir,($brokerDir+'.swap'))}
    'rename-profile' {[IO.Directory]::Move($profile,($profile+'.swap'))}
    'rename-appdata' {[IO.Directory]::Move((Join-Path $profile 'AppData'),(Join-Path $profile 'AppData.swap'))}
    'rename-local' {[IO.Directory]::Move($local,($local+'.swap'))}
    'rename-owner' {[IO.Directory]::Move($owner,($owner+'.swap'))}
    'rename-output' {[IO.File]::Move($cpu,($cpu+'.swap'))}
   }
  }catch{
   $blocked=$true
   $e=$_.Exception
   while($e.InnerException){$e=$e.InnerException}
   if($e -isnot [IO.IOException] -and $e -isnot [UnauthorizedAccessException]){
    throw ('R407_WRONG_REJECTION_TYPE_'+$kind+'_'+$e.GetType().Name)
   }
  }
  if(!$blocked){throw ('R407_PATH_SWAP_OR_WRITE_SUCCEEDED_WHILE_PINNED_'+$kind)}
  $count++
 }
 if($count -ne 10){throw 'R407_ATTACK_MATRIX_COUNT_MISMATCH'}
 'R407_PASS_TEN_NATIVE_BROKER_OUTPUT_AND_ANCESTOR_MUTATIONS_REFUSED'

 if($HostedGuest){
  $psi=New-Object Diagnostics.ProcessStartInfo
  $psi.FileName=$broker
  $psi.Arguments='--run-cpu "'+$cpu+'"'
  $psi.UseShellExecute=$false
  $psi.CreateNoWindow=$true
  $process=[Diagnostics.Process]::Start($psi)
  if(!$process){throw 'R407_PROCESS_START_NULL_WHILE_PINNED'}
  try{
   if(!$process.WaitForExit(10000) -or $process.ExitCode -ne 0){
     throw 'R407_PROCESS_START_NONZERO_WHILE_PINNED'
   }
  }finally{$process.Dispose()}
  'R407_PASS_REAL_HOSTED_CREATEPROCESS_WHILE_BROKER_AND_ANCESTORS_PINNED'
 }else{
  'R407_PASS_OWNER_LOCAL_NO_REAL_PROCESS_STARTED'
 }
 $active.Dispose();$active=$null

 $store=Acquire $broker '--once-storage' $storage $program $profile $local
 if($store.Rejected -or !$store.Lease){throw ('R407_STORAGE_LEASE_REJECTED_'+$store.Error)}
 $store.Lease.Dispose()
 'R407_PASS_STORAGE_MISSING_LEAF_AND_CANONICAL_RECOVERY'
 $bad=Acquire $broker '--extra-command' $cpu $program $profile $local
 if(!$bad.Rejected -or $bad.Lease){throw 'R407_INVALID_MODE_NOT_REFUSED'}
 'R407_PASS_INVALID_MODE_REJECTED_BEFORE_LAUNCH'

 [IO.File]::Move($broker,($broker+'.after'))
 [IO.File]::Move(($broker+'.after'),$broker)
 if((Get-FileHash $broker -Algorithm SHA256).Hash -cne $brokerSha -or
    (Get-FileHash $cpu -Algorithm SHA256).Hash -cne $cpuSha -or
    (Get-FileHash $canary -Algorithm SHA256).Hash -cne $canarySha){
  throw 'R407_MUTATED_FIXTURE_OR_EXTERNAL_CANARY'
 }
 'R407_PASS_HANDLE_DISPOSAL_RELEASES_FILES_AND_OUTSIDE_SHA_UNCHANGED'
 'R407_RESULT=PASS_COMPILED_ATOMIC_BROKER_LAUNCH_LEASE_SCOPE'
}finally{
 if($active){$active.Dispose()}
 if(Test-Path -LiteralPath $testRoot){Remove-Item -LiteralPath $testRoot -Recurse -Force}
}
