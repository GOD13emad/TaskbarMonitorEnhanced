[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$SupervisorPath,
 [Parameter(Mandatory=$true)][string]$SourceRoot,
 [switch]$HostedGuest
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($PSVersionTable.PSEdition -cne 'Desktop'){throw 'R406_PS51_REQUIRED'}
if($HostedGuest -and ($env:GITHUB_ACTIONS -cne 'true' -or $env:RUNNER_OS -cne 'Windows' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted')){throw 'R406_HOSTED_ONLY'}
$root=(Resolve-Path -LiteralPath $SourceRoot).Path
$binary=(Resolve-Path -LiteralPath $SupervisorPath).Path
if(![string]::Equals($binary,(Join-Path $root 'build\_out\Supervisor\TaskbarMonitorSensorSupervisor.exe'),
   [StringComparison]::OrdinalIgnoreCase)){throw 'R406_WRONG_COMPILED_SUPERVISOR'}
$code=[IO.File]::ReadAllText((Join-Path $root 'src\sensors\TaskbarMonitorSensorSupervisor.cs'))
foreach($part in @('CurrentTrustedBrokerLaunchArguments(w.Mode,w.Output)',
                  'CurrentTrustedBrokerLaunchArguments("--once-storage",StorageOutput)',
                  'psi.Arguments=checkedArguments;','Process p=Process.Start(psi);')){
 if(!$code.Contains($part)){throw ('R406_RUNTIME_PREPROCESS_BINDING_MISSING_'+$part)}
}
$asm=[Reflection.Assembly]::LoadFrom($binary)
$type=$asm.GetType('TaskbarMonitorSensorSupervisor',$true)
$method=$type.GetMethod('TrustedBrokerLaunchArguments',[Reflection.BindingFlags]'NonPublic,Static')
if(!$method -or $method.GetParameters().Length -ne 6){throw 'R406_COMPILED_VALIDATION_METHOD_MISSING'}
function Invoke-Bind([string]$exe,[string]$mode,[string]$output,[string]$program,[string]$profile,[string]$local){
 try{
  $v=$method.Invoke($null,[object[]]@($exe,$mode,$output,$program,$profile,$local))
  return [pscustomobject]@{Value=[string]$v;Rejected=$false;Exception=''}
 }catch{
  $e=$_.Exception
  while($e.InnerException){$e=$e.InnerException}
  return [pscustomobject]@{Value='';Rejected=$true;Exception=$e.GetType().Name}
 }
}
$fixture=[IO.Path]::GetFullPath((Join-Path $env:TEMP ('tbme-r406-rebind-'+[guid]::NewGuid().ToString('N'))))
if(Test-Path -LiteralPath $fixture){throw 'R406_COLLISION'}
$program=Join-Path $fixture 'Program Files'
$brokerDir=Join-Path $program 'TaskbarMonitorEnhanced\SensorBroker'
$broker=Join-Path $brokerDir 'TaskbarMonitorSensorBroker.exe'
$profile=Join-Path $fixture 'Profile With Spaces'
$local=Join-Path $profile 'AppData\Local'
$ownerDir=Join-Path $local 'TaskbarMonitorEnhanced'
$cpu=Join-Path $ownerDir 'cpu_temp_broker.json'
$gpu=Join-Path $ownerDir 'gpu_temp_broker.json'
$storage=Join-Path $ownerDir 'storage_temp_broker.json'
$outside=Join-Path $fixture 'foreign'
[void][IO.Directory]::CreateDirectory($brokerDir)
[void][IO.Directory]::CreateDirectory($ownerDir)
[void][IO.Directory]::CreateDirectory($outside)
[IO.File]::WriteAllText($broker,'NOT_EXECUTABLE')
$canary=Join-Path $outside 'CANARY.txt'
[IO.File]::WriteAllText($canary,'R406_NEVER_EXECUTED')
$canarySHA=(Get-FileHash $canary -Algorithm SHA256).Hash
try{
 $good=@(
  [pscustomobject]@{Mode='--run-cpu';Output=$cpu},
  [pscustomobject]@{Mode='--run-gpu';Output=$gpu},
  [pscustomobject]@{Mode='--once-storage';Output=$storage}
 )
 foreach($g in $good){
  $v=Invoke-Bind $broker $g.Mode $g.Output $program $profile $local
  if($v.Rejected -or $v.Value -cne ($g.Mode+' "'+$g.Output+'"')){
   throw ('R406_VALID_CANONICAL_MODE_REJECTED_'+$g.Mode+' error='+$v.Exception+' actual='+$v.Value+' expected='+($g.Mode+' "'+$g.Output+'"'))
  }
 }
 'R406_PASS_THREE_CANONICAL_MODES_AND_SPACES_REAL_COMPILED'
 $cases=@(
  @((Join-Path $outside 'evil.exe'),'--run-cpu',$cpu,$program,$profile,$local),
  @($broker,'--run-cpu',(Join-Path $outside 'rogue.json'),$program,$profile,$local),
  @($broker,'--evil',$cpu,$program,$profile,$local),
  @($broker,'--run-cpu --evil',$cpu,$program,$profile,$local),
  @($broker,'--run-cpu',$gpu,$program,$profile,$local),
  @($broker,'--once-storage',$cpu,$program,$profile,$local),
  @($broker,'--run-cpu',($cpu+'" --evil'),$program,$profile,$local),
  @($broker,'--run-cpu',($cpu+[char]13+[char]10+'--evil'),$program,$profile,$local),
  @($broker,'--run-cpu','.\cpu_temp_broker.json',$program,$profile,$local),
  @($broker,'--run-cpu','\\evil\share\cpu_temp_broker.json',$program,$profile,$local),
  @($broker,'--run-cpu',$cpu,$program,'\\attacker\share\Profile',$local),
  @($broker,'--run-cpu',$cpu,$program,$profile,(Join-Path $fixture 'badlocal')),
  @((Join-Path $brokerDir 'notfound.exe'),'--run-cpu',$cpu,$program,$profile,$local)
 )
 foreach($case in $cases){
  $v=Invoke-Bind $case[0] $case[1] $case[2] $case[3] $case[4] $case[5]
  if(!$v.Rejected){throw ('R406_MALICIOUS_ARG_ACCEPTED_'+($case -join '|'))}
 }
 'R406_PASS_THIRTEEN_UNTRUSTED_EXECUTABLE_MODE_OUTPUT_AND_PROFILE_CASES'
 $target=Join-Path $outside 'target'
 [void][IO.Directory]::CreateDirectory($target)
 $oldOwner=$ownerDir+'.trusted'
 [IO.Directory]::Move($ownerDir,$oldOwner)
 try{
  New-Item -ItemType Junction -Path $ownerDir -Target $target -ErrorAction Stop|Out-Null
  if(([IO.File]::GetAttributes($ownerDir) -band [IO.FileAttributes]::ReparsePoint) -eq 0){
   throw 'R406_OWNER_JUNCTION_INVALID'
  }
  $v=Invoke-Bind $broker '--run-cpu' $cpu $program $profile $local
  if(!$v.Rejected){throw 'R406_RESTART_ACCEPTED_NEW_OUTPUT_JUNCTION'}
  'R406_PASS_RESTART_REJECTS_NEW_OWNER_OUTPUT_JUNCTION'
 }finally{
  if([IO.Directory]::Exists($ownerDir)){
   if(([IO.File]::GetAttributes($ownerDir) -band [IO.FileAttributes]::ReparsePoint) -eq 0){throw 'R406_OWNER_JUNCTION_CHANGED'}
   [IO.Directory]::Delete($ownerDir,$false)
  }
  [IO.Directory]::Move($oldOwner,$ownerDir)
 }
 $oldBroker=$brokerDir+'.trusted'
 [IO.Directory]::Move($brokerDir,$oldBroker)
 try{
  New-Item -ItemType Junction -Path $brokerDir -Target $target -ErrorAction Stop|Out-Null
  if(([IO.File]::GetAttributes($brokerDir) -band [IO.FileAttributes]::ReparsePoint) -eq 0){
   throw 'R406_BROKER_JUNCTION_INVALID'
  }
  $v=Invoke-Bind $broker '--run-cpu' $cpu $program $profile $local
  if(!$v.Rejected){throw 'R406_RESTART_ACCEPTED_NEW_BROKER_JUNCTION'}
  'R406_PASS_RESTART_REJECTS_NEW_PROTECTED_BROKER_JUNCTION'
 }finally{
  if([IO.Directory]::Exists($brokerDir)){
   if(([IO.File]::GetAttributes($brokerDir) -band [IO.FileAttributes]::ReparsePoint) -eq 0){throw 'R406_BROKER_JUNCTION_CHANGED'}
   [IO.Directory]::Delete($brokerDir,$false)
  }
  [IO.Directory]::Move($oldBroker,$brokerDir)
 }
 foreach($g in $good){
  $v=Invoke-Bind $broker $g.Mode $g.Output $program $profile $local
  if($v.Rejected){throw 'R406_NORMAL_OWNER_RECOVERY_FAILED'}
 }
 'R406_PASS_CANONICAL_RECOVERS_AFTER_BOTH_JUNCTION_REMOVALS'
 if((Get-FileHash $canary -Algorithm SHA256).Hash -cne $canarySHA){throw 'R406_OUTSIDE_CANARY_CHANGED'}
 'R406_PASS_OUTSIDE_CANARY_UNCHANGED_NO_REAL_BROKER_EXECUTED'
 'R406_RESULT=PASS_COMPILED_SUPERVISOR_LAUNCH_TIME_REBIND'
}finally{
 if(Test-Path -LiteralPath $fixture){Remove-Item -LiteralPath $fixture -Recurse -Force}
}
