# R419: disposable argv probe for already-validated Broker command boundaries.
# This test never starts the real broker or writes to an installed owner profile.
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$SupervisorPath,
 [Parameter(Mandatory=$true)][string]$SourceRoot
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -cne 'Desktop'){throw 'R419_REQUIRES_NATIVE_WINPS51'}
$root=(Resolve-Path -LiteralPath $SourceRoot).Path
$binary=(Resolve-Path -LiteralPath $SupervisorPath).Path
$expected=Join-Path $root 'build\_out\Supervisor\TaskbarMonitorSensorSupervisor.exe'
if(![string]::Equals($binary,[IO.Path]::GetFullPath($expected),
 [StringComparison]::OrdinalIgnoreCase)){throw 'R419_WRONG_COMPILED_SUPERVISOR'}
$source=[IO.File]::ReadAllText((Join-Path $root 'src\sensors\TaskbarMonitorSensorSupervisor.cs'))
foreach($guard in @('BrokerLaunchLease.Acquire(BrokerPath,mode,output,',
 'string checkedArguments=CurrentTrustedBrokerLaunchArguments(w.Mode,w.Output);',
 'string checkedArguments=CurrentTrustedBrokerLaunchArguments("--once-storage",StorageOutput);',
 'psi.UseShellExecute=false;',
 'psi.Arguments=checkedArguments;')){
 if(!$source.Contains($guard)){throw ('R419_LAUNCH_SOURCE_GUARD_CHANGED_'+$guard)}
}
$asm=[Reflection.Assembly]::LoadFrom($binary)
$type=$asm.GetType('TaskbarMonitorSensorSupervisor',$true)
$validate=$type.GetMethod('TrustedBrokerLaunchArguments',
 [Reflection.BindingFlags]'NonPublic,Static')
if(!$validate -or $validate.GetParameters().Length -ne 6){throw 'R419_COMPILED_VALIDATOR_NOT_FOUND'}
$fixture=[IO.Path]::GetFullPath((Join-Path $env:TEMP ('tbme-r419-argv-'+[guid]::NewGuid().ToString('N'))))
if(Test-Path -LiteralPath $fixture){throw 'R419_FRESH_TEST_COLLISION'}
$program=Join-Path $fixture 'Program Files'
$profile=Join-Path $fixture 'Profile With & ^ % ! ( )'
$local=Join-Path $profile 'AppData\Local'
$owner=Join-Path $local 'TaskbarMonitorEnhanced'
$brokerDir=Join-Path $program 'TaskbarMonitorEnhanced\SensorBroker'
$broker=Join-Path $brokerDir 'TaskbarMonitorSensorBroker.exe'
$outside=Join-Path $fixture 'outside'
[void][IO.Directory]::CreateDirectory($brokerDir)
[void][IO.Directory]::CreateDirectory($owner)
[void][IO.Directory]::CreateDirectory($outside)
$canary=Join-Path $outside 'canary.txt'
[IO.File]::WriteAllText($canary,'R419_TEST_EXTERNAL_CANARY',[Text.UTF8Encoding]::new($false))
$canaryHash=(Get-FileHash $canary -Algorithm SHA256).Hash
$probe=Join-Path $fixture 'HarmlessArgvProbe.exe'
$stub=@'
using System;
using System.Text;
public sealed class R419HarmlessArgvProbe {
 public static int Main(string[] args) {
  Console.WriteLine("R419_ARGC="+args.Length);
  foreach(string arg in args)
   Console.WriteLine("R419_ARG="+Convert.ToBase64String(Encoding.UTF8.GetBytes(arg)));
  return 0;
 }
}
'@
try{
 Add-Type -TypeDefinition $stub -OutputAssembly $probe -OutputType ConsoleApplication -ErrorAction Stop
 if(!(Test-Path -LiteralPath $probe)){throw 'R419_HARMLESS_EXECUTABLE_NOT_BUILT'}
 [IO.File]::Copy($probe,$broker)
 $probeHash=(Get-FileHash $broker -Algorithm SHA256).Hash
 $modes=@(
   [pscustomobject]@{Mode='--run-cpu';Leaf='cpu_temp_broker.json'},
   [pscustomobject]@{Mode='--run-gpu';Leaf='gpu_temp_broker.json'},
   [pscustomobject]@{Mode='--once-storage';Leaf='storage_temp_broker.json'}
 )
 foreach($mode in $modes){
  $output=Join-Path $owner $mode.Leaf
  $argv=[string]$validate.Invoke($null,[object[]]@(
   [string]$broker,[string]$mode.Mode,[string]$output,
   [string]$program,[string]$profile,[string]$local))
  if($argv -cne ($mode.Mode+' "'+$output+'"')){
    throw ('R419_UNEXPECTED_COMPILED_TRUSTED_ARGV_'+$mode.Mode)
  }
  $psi=[Diagnostics.ProcessStartInfo]::new()
  $psi.FileName=$broker
  $psi.Arguments=$argv
  $psi.UseShellExecute=$false
  $psi.CreateNoWindow=$true
  $psi.RedirectStandardOutput=$true
  $psi.RedirectStandardError=$true
  $process=[Diagnostics.Process]::Start($psi)
  if(!$process){throw 'R419_HARMLESS_PROCESS_START_NULL'}
  try{
   $out=$process.StandardOutput.ReadToEnd()
   $err=$process.StandardError.ReadToEnd()
   if(!$process.WaitForExit(10000) -or $process.ExitCode -ne 0 -or $err){
      throw ('R419_PROBE_PROCESS_FAILURE_'+$mode.Mode)
   }
  }finally{$process.Dispose()}
  $lines=@($out -split '\r?\n' | Where-Object {$_ -ne ''})
  if($lines.Count -ne 3 -or $lines[0] -cne 'R419_ARGC=2'){
   throw ('R419_PROCESS_ARGC_SPLIT_OR_INJECTED_'+$mode.Mode)
  }
  $decoded=@($lines|Select-Object -Skip 1|ForEach-Object {
    if(!$_ -or !$_.StartsWith('R419_ARG=')){throw 'R419_PROBE_OUTPUT_INVALID'}
    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_.Substring(9)))
  })
  if($decoded.Count -ne 2 -or $decoded[0] -cne $mode.Mode -or
     $decoded[1] -cne $output){
    throw ('R419_COMPILED_ARGUMENT_QUOTING_ROUNDTRIP_FAILED_'+$mode.Mode)
  }
  'R419_PASS_REAL_CREATEPROCESS_EXACT_TWO_ARGV_'+$mode.Mode
 }
 $bad=@(
    [pscustomobject]@{Mode='--run-cpu & echo injected';Output=(Join-Path $owner 'cpu_temp_broker.json')},
    [pscustomobject]@{Mode='--run-cpu';Output=(Join-Path $outside 'rogue.json')},
    [pscustomobject]@{Mode='--run-cpu';Output=((Join-Path $owner 'cpu_temp_broker.json')+'" --extra')},
    [pscustomobject]@{Mode='--run-cpu';Output=((Join-Path $owner 'cpu_temp_broker.json')+[char]10+'extra')}
 )
 $rejected=0
 foreach($v in $bad){
  $fail=$false
  try{$null=$validate.Invoke($null,[object[]]@(
    [string]$broker,[string]$v.Mode,[string]$v.Output,
    [string]$program,[string]$profile,[string]$local))}catch{$fail=$true}
  if(!$fail){throw 'R419_ATTACKER_CONTROLLED_MODE_OR_OUTPUT_ACCEPTED'}
  $rejected++
 }
 if($rejected -ne 4){throw 'R419_NEGATIVE_CASE_COUNT_WRONG'}
 'R419_PASS_FOUR_ADVERSARIAL_MODE_AND_OUTPUT_CASES_REJECTED'
 if((Get-FileHash $canary -Algorithm SHA256).Hash -cne $canaryHash -or
    (Get-FileHash $broker -Algorithm SHA256).Hash -cne $probeHash){
   throw 'R419_OUTSIDE_CANARY_OR_HARMLESS_PROBE_CHANGED'
 }
 'R419_PASS_OUTSIDE_CANARY_UNCHANGED'
 'R419_PASS_ONLY_HARMLESS_COMPILED_PROBE_EXECUTED'
 'R419_RESULT=PASS_REAL_NET48_NO_SHELL_ARGV_META_CHARACTERS_EXACT'
}finally{
 if((Test-Path -LiteralPath $fixture) -and
    $fixture.StartsWith([IO.Path]::GetFullPath($env:TEMP),
       [StringComparison]::OrdinalIgnoreCase) -and
    [IO.Path]::GetFileName($fixture).StartsWith('tbme-r419-argv-',
       [StringComparison]::Ordinal)){
  Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction Stop
 }
}
