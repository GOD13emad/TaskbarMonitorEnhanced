[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$BrokerPath,
 [Parameter(Mandatory=$true)][string]$SourceRoot,
 [switch]$HostedGuest
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($PSVersionTable.PSEdition -cne 'Desktop'){throw 'R408_REQUIRES_WINDOWS_POWERSHELL_51'}
if($HostedGuest -and ($env:GITHUB_ACTIONS -cne 'true' -or
 $env:RUNNER_OS -cne 'Windows' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted')){
 throw 'R408_HOSTED_MUTATION_ONLY_ON_DISPOSABLE_WINDOWS'
}
$root=(Resolve-Path -LiteralPath $SourceRoot).Path
$broker=(Resolve-Path -LiteralPath $BrokerPath).Path
$expected=[IO.Path]::GetFullPath((Join-Path $root 'build\_out\Broker\TaskbarMonitorSensorBroker.exe'))
if(![string]::Equals($broker,$expected,[StringComparison]::OrdinalIgnoreCase)){
 throw 'R408_COMPILED_BROKER_PATH_MISMATCH'
}
$src=[IO.File]::ReadAllText((Join-Path $root 'src\sensors\TaskbarMonitorSensorBroker.cs'))
$boundary=[IO.File]::ReadAllText((Join-Path $root 'src\sensors\BrokerOutputBoundary.cs'))
foreach($check in @(
 'output=BrokerOutputBoundary.CurrentValidatedOutput(mode,output);',
 'using(BrokerOutputBoundary lease=BrokerOutputBoundary.PinCurrent(BoundOutputMode,path))',
 'lease.RevalidateLeaf(path);',
 'if(args==null||args.Length!=2)return 2;')){
 if(!$src.Contains($check)){throw ('R408_BROKER_SOURCE_BINDING_MISSING_'+$check)}
}
foreach($check in @('case "--run-cpu"','case "--run-gpu"','case "--once-storage"',
 'GetFileInformationByHandleEx','GetFinalPathNameByHandle','GetFileAttributes',
 'heldDirectories.Add(handle)')){
 if(!$boundary.Contains($check)){throw ('R408_BROKER_BOUNDARY_SOURCE_MISSING_'+$check)}
}
$assembly=[Reflection.Assembly]::LoadFrom($broker)
$type=$assembly.GetType('TaskbarMonitorSensorBroker.BrokerOutputBoundary',$true)
$flags=[Reflection.BindingFlags]'Static,NonPublic'
$validate=$type.GetMethod('Validate',$flags)
$acquire=$type.GetMethod('Acquire',$flags)
if(!$validate -or !$acquire -or $validate.GetParameters().Count -ne 4 -or
   $acquire.GetParameters().Count -ne 4){throw 'R408_COMPILED_POLICY_BINDING_MISSING'}
function Invoke-Guard([string]$mode,[string]$output,[string]$profile,[string]$local,[bool]$pin){
 try{
  $method=if($pin){$acquire}else{$validate}
  $result=$method.Invoke($null,[object[]]@([string]$mode,[string]$output,[string]$profile,[string]$local))
  return [pscustomobject]@{Accepted=$true;Lease=if($pin){$result}else{$null};Error='';Value=if($pin){''}else{[string]$result}}
 }catch{
  $e=$_.Exception
  while($e.InnerException){$e=$e.InnerException}
  return [pscustomobject]@{Accepted=$false;Lease=$null;Error=$e.GetType().Name;Value=''}
 }
}
$fixture=[IO.Path]::GetFullPath((Join-Path $env:TEMP ('tbme-r408-output-'+[guid]::NewGuid().ToString('N'))))
if(Test-Path -LiteralPath $fixture){throw 'R408_FIXTURE_COLLISION'}
$profile=Join-Path $fixture 'Profile With Spaces'
$local=Join-Path $profile 'AppData\Local'
$owner=Join-Path $local 'TaskbarMonitorEnhanced'
$outside=Join-Path $fixture 'outside'
[void][IO.Directory]::CreateDirectory($owner)
[void][IO.Directory]::CreateDirectory($outside)
$cpu=Join-Path $owner 'cpu_temp_broker.json'
$gpu=Join-Path $owner 'gpu_temp_broker.json'
$storage=Join-Path $owner 'storage_temp_broker.json'
[IO.File]::WriteAllText($cpu,'{"available":false}')
$canary=Join-Path $outside 'CANARY.txt'
[IO.File]::WriteAllText($canary,'R408_EXTERNAL_CANARY_NEVER_TOUCH')
$canaryHash=(Get-FileHash $canary -Algorithm SHA256).Hash
try{
 $count=0
 foreach($m in @(@('--run-cpu',$cpu),@('--run-gpu',$gpu),@('--once-storage',$storage))){
  $v=Invoke-Guard $m[0] $m[1] $profile $local $true
  if(!$v.Accepted -or !$v.Lease){throw ('R408_VALID_MODE_REJECTED_'+$m[0]+'_'+$v.Error)}
  $v.Lease.Dispose()
  $count++
 }
 if($count -ne 3){throw 'R408_VALID_MODES_NOT_3'}
 'R408_PASS_THREE_EXACT_MODE_AND_OUTPUT_PATHS_PINNED'
 $bad=@(
 @('--run',$cpu,$profile,$local),
 @('--once',$cpu,$profile,$local),
 @('--once-cpu',$cpu,$profile,$local),
 @('--once-gpu',$gpu,$profile,$local),
 @('--run-cpu',$gpu,$profile,$local),
 @('--run-gpu',$storage,$profile,$local),
 @('--once-storage',$cpu,$profile,$local),
 @('--run-cpu',(Join-Path $outside 'evil.json'),$profile,$local),
 @('--run-cpu','.\\cpu_temp_broker.json',$profile,$local),
 @('--run-cpu',($cpu+'" --evil'),$profile,$local),
 @('--run-cpu',($cpu+[char]13+'evil'),$profile,$local),
 @('--run-cpu',$cpu,$profile,(Join-Path $fixture 'ForgedLocal')),
 @('--run-cpu',$cpu,'\\server\share\Users',$local),
 @('--run-cpu',('\\server\share\cpu_temp_broker.json'),$profile,$local)
 )
 $badCount=0
 foreach($candidate in $bad){
  $v=Invoke-Guard ([string]$candidate[0]) ([string]$candidate[1]) ([string]$candidate[2]) ([string]$candidate[3]) $false
  if($v.Accepted){throw ('R408_UNTRUSTED_OUTPUT_MODE_ACCEPTED_'+$badCount)}
  $badCount++
 }
 if($badCount -ne 14){throw 'R408_NEGATIVE_COUNT_NOT_14'}
 'R408_PASS_FOURTEEN_INVALID_MODE_AND_OWNER_OUTPUT_BINDINGS_REFUSED'
 $cpuGuard=Invoke-Guard '--run-cpu' $cpu $profile $local $true
 if(!$cpuGuard.Accepted -or !$cpuGuard.Lease){throw 'R408_DIRECTORY_LEASE_TEST_CANNOT_ACQUIRE'}
 $revalidate=$type.GetMethod('RevalidateLeaf',[Reflection.BindingFlags]'Instance,NonPublic')
 if(!$revalidate){throw 'R408_MISSING_COMPILED_PATH_REVALIDATION'}
 try{
  $changed=$false
  try{[IO.Directory]::Move($owner,($owner+'.swapped'));$changed=$true}catch{}
  if($changed){
   $rejected=$false
   try{
    $revalidate.Invoke($cpuGuard.Lease,[object[]]@([string]$cpu))|Out-Null
   }catch{
    $e=$_.Exception;while($e.InnerException){$e=$e.InnerException}
    if($e -is [IO.IOException] -or $e -is [IO.InvalidDataException]){$rejected=$true}
    else{throw ('R408_UNEXPECTED_PIN_IDENTITY_EXCEPTION_'+$e.GetType().Name)}
   }
   if(!$rejected){throw 'R408_DIRECTORY_MOVED_BUT_PIN_IDENTITY_CHECK_DID_NOT_REJECT'}
   'R408_PASS_OWNER_DIRECTORY_MOVE_DETECTED_FROM_LIVE_NATIVE_HANDLE'
  }else{
   $revalidate.Invoke($cpuGuard.Lease,[object[]]@([string]$cpu))|Out-Null
   'R408_PASS_OWNER_DIRECTORY_RENAME_REFUSED_DURING_PIN'
  }
 }finally{
  $cpuGuard.Lease.Dispose()
  if(Test-Path -LiteralPath ($owner+'.swapped')){[IO.Directory]::Move(($owner+'.swapped'),$owner)}
 }
 [IO.Directory]::Move($owner,($owner+'.renamed'))
 [IO.Directory]::Move(($owner+'.renamed'),$owner)
 'R408_PASS_PIN_RELEASE_AND_DIRECTORY_RENAME_RECOVERY'
 $rename=Join-Path $owner 'alternate.json'
 [IO.File]::WriteAllText($rename,'R408_NOT_OUTPUT')
 $wrong=Invoke-Guard '--run-cpu' $rename $profile $local $false
 if($wrong.Accepted){throw 'R408_WRONG_LOCAL_LEAF_ACCEPTED'}
 if((Get-FileHash $canary -Algorithm SHA256).Hash -cne $canaryHash){
  throw 'R408_EXTERNAL_CANARY_HASH_CHANGED'
 }
 'R408_PASS_EXTERNAL_CANARY_UNCHANGED'
 # The exact built child executable, not just the policy reflection, must
 # fail closed before any hardware startup and before writing an arbitrary file.
 $psi=New-Object Diagnostics.ProcessStartInfo
 $psi.FileName=$broker
 $psi.Arguments='--once-storage "'+$canary+'"'
 $psi.UseShellExecute=$false
 $psi.CreateNoWindow=$true
 $child=[Diagnostics.Process]::Start($psi)
 if(!$child){throw 'R408_DIRECT_EXECUTABLE_NOT_STARTED'}
 try{
  if(!$child.WaitForExit(10000)){try{$child.Kill()}catch{};throw 'R408_INVALID_ARGV_CHILD_TIMEOUT'}
  if($child.ExitCode -ne 2){throw ('R408_DIRECT_INVALID_OUTPUT_NOT_REJECTED_EXIT_'+$child.ExitCode)}
 }finally{$child.Dispose()}
 if((Get-FileHash $canary -Algorithm SHA256).Hash -cne $canaryHash){
  throw 'R408_DIRECT_EXECUTABLE_OVERWROTE_OUTSIDE_CANARY'
 }
 'R408_PASS_REAL_BROKER_EXE_REJECTS_OUTSIDE_OUTPUT_BEFORE_SENSORS'
 if($HostedGuest){
  # Use a freshly created disposable profile fixture, not runner LocalAppData:
  # other CI steps may own that directory. The private compiled write core is
  # invoked with a genuine already-validated native lease for that fixture.
  $storageGuard=Invoke-Guard '--once-storage' $storage $profile $local $true
  if(!$storageGuard.Accepted -or !$storageGuard.Lease){
    throw ('R408_HOSTED_CORE_CANNOT_PIN_DISPOSABLE_ROOT_'+$storageGuard.Error)
  }
  try{
   $writeCore=$assembly.GetType('TaskbarMonitorSensorBroker.Program',$true).GetMethod('AtomicWriteUnderLease',[Reflection.BindingFlags]'Static,NonPublic')
   if(!$writeCore -or $writeCore.GetParameters().Count -ne 3){throw 'R408_COMPILED_ATOMIC_WRITE_CORE_MISSING'}
   foreach($record in @('{"seq":1}', '{"seq":2}')){
    $writeCore.Invoke($null,[object[]]@([string]$storage,[string]$record,$storageGuard.Lease))|Out-Null
   }
   if([IO.File]::ReadAllText($storage) -cne '{"seq":2}'){
    throw 'R408_HOSTED_ATOMIC_WRITE_CORE_NOT_REPLACED'
   }
   'R408_PASS_DISPOSABLE_SYNTHETIC_OWNER_ROOT_ATOMIC_WRITE_CREATE_AND_REPLACE'
  }finally{$storageGuard.Lease.Dispose()}
 }else{
  'R408_PASS_OWNER_LOCAL_NO_OWNER_APP_OR_CONFIG_WRITES'
 }
 'R408_RESULT=PASS_COMPILED_BROKER_INDEPENDENT_OUTPUT_GUARD'
}finally{
 if(Test-Path -LiteralPath $fixture){Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction Stop}
}
