[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$AuthorityPath,
 [Parameter(Mandatory=$true)][string]$ReadyPath,
 [Parameter(Mandatory=$true)][string]$SignalPath,
 [Parameter(Mandatory=$true)][string]$ReceiptPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# Test-only already-admin child on fresh GitHub-hosted Windows.
# Runs native CreateFileW sharing probe then exact MoveFileExW symlink replacement.
# Never writes user or production bytes; all victims are synthetic disposable guest files.
$phase='PRECHECK';$failure='';$sourceCommit=$env:GITHUB_SHA
$nonce='';$swapSource='';$control='';$canary='';$expectedLeaf='';$expectedJournal=''
$actorBeforeSuccess=$false;$probeBeforeAllowed=$false;$linkReady=$false
$helperPid=0;$attempts=0;$probeCode=-1;$moveCode=-1;$moved=$false;$denied=$false
$helperAlive=$false;$journalReady=$false;$canaryIntact=$false;$sourceIntact=$false
$authority=$null
function H([string]$path){return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash}
try {
 if($PSVersionTable.PSEdition -cne 'Desktop' -or
    $env:GITHUB_ACTIONS -cne 'true' -or
    $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
    $env:RUNNER_OS -cne 'Windows' -or
    $env:GITHUB_REPOSITORY -cne 'GOD13emad/TaskbarMonitorEnhanced' -or
    $env:GITHUB_REF -cne 'refs/heads/audit/r358-original-helper-concurrent-reparse' -or
    $env:COMPUTERNAME -match '(?i)EMAD-PC|ALIEMAD|SAEID|LAPTOP' -or
    $sourceCommit -cnotmatch '^[0-9a-f]{40}$'){
  throw 'R358_DISPOSABLE_GUEST_ONLY'
 }
 $token=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
 if(!$token.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
  throw 'R358_ALREADY_ADMIN_GUEST_REQUIRED'
 }
 $guestTemp=[IO.Path]::GetFullPath($env:RUNNER_TEMP).TrimEnd('\')+'\'
 foreach($path in @($AuthorityPath,$ReadyPath,$SignalPath,$ReceiptPath)){
   if(-not [IO.Path]::GetFullPath($path).StartsWith($guestTemp,[StringComparison]::OrdinalIgnoreCase)){
     throw 'R358_UNTRUSTED_CONTROL_PATH_OUTSIDE_HOSTED_TEMP'
   }
 }
 foreach($path in @($ReadyPath,$SignalPath,$ReceiptPath)){
   if([IO.File]::Exists($path)){throw 'R358_PREEXISTING_CONTROL_FILE'}
 }
 $authority=Get-Content -LiteralPath $AuthorityPath -Raw|ConvertFrom-Json
 $expectedLeaf=Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles)) 'TaskbarMonitorEnhanced\SensorBroker\TaskbarMonitorSensorSupervisor.exe'
 $expectedJournal=Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles)) 'TaskbarMonitorEnhanced\.tbme-sensor-rollback'
 $canary=[IO.Path]::GetFullPath([string]$authority.OutsideCanary)
 if($authority.Schema -ne 1 -or $authority.Revision -cne 'R358' -or
    $authority.SourceCommit -cne $sourceCommit -or $authority.Host -cnotmatch '^[AB]$' -or
    $authority.HostedComputer -cne $env:COMPUTERNAME -or
    $authority.ExpectedLeaf -cne $expectedLeaf -or
    $authority.ExpectedJournal -cne $expectedJournal -or
    $authority.Nonce -cnotmatch '^[0-9a-f]{32}$' -or
    $authority.ParentPid -le 0 -or
    -not $canary.StartsWith($guestTemp,[StringComparison]::OrdinalIgnoreCase) -or
    $authority.OutsideSHA256 -cnotmatch '^[0-9A-F]{64}$' -or
    -not [IO.File]::Exists($canary) -or
    (H $canary) -cne $authority.OutsideSHA256){
  throw 'R358_AUTHORITY_OR_CANARY_NOT_EXACT'
 }
 $nonce=[string]$authority.Nonce
 if(-not [IO.File]::Exists($expectedLeaf) -or
    -not [IO.File]::Exists((Join-Path $expectedJournal 'READY'))){
  throw 'R358_EXPECTED_REAL_PREPARED_JOURNAL_OR_PROTECTED_LEAF_MISSING'
 }
 $local=[Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
 $actorTemp=Join-Path $local 'Temp'
 if(-not [IO.Directory]::Exists($actorTemp) -or
    -not [string]::Equals([IO.Path]::GetPathRoot($actorTemp),[IO.Path]::GetPathRoot($expectedLeaf),[StringComparison]::OrdinalIgnoreCase)){
  throw 'R358_MOVEFILEEX_CROSS_VOLUME_OR_MISSING_LOCAL_TEMP'
 }
 $swapSource=Join-Path $actorTemp ('R358_SYMLINK_SWAP_'+$nonce+'.lnk')
 $control=Join-Path $actorTemp ('R358_TEST_CONTROL_'+$nonce+'.bin')
 if([IO.File]::Exists($swapSource) -or [IO.File]::Exists($control)){
  throw 'R358_LOCAL_SYMLINK_OR_CONTROL_ALREADY_EXISTS'
 }
 Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class R358NativeProbeMove {
 const uint GEN_WRITE=0x40000000,SHARE_ALL=7,EXISTING=3,NOFOLLOW=0x00200000;
 [DllImport("kernel32.dll",EntryPoint="CreateFileW",CharSet=CharSet.Unicode,SetLastError=true)]
 static extern SafeFileHandle Open(string path,uint access,uint share,IntPtr sec,uint mode,uint flags,IntPtr template);
 [DllImport("kernel32.dll",EntryPoint="CreateSymbolicLinkW",CharSet=CharSet.Unicode,SetLastError=true)]
 static extern bool Sym(string link,string target,uint flags);
 [DllImport("kernel32.dll",EntryPoint="MoveFileExW",CharSet=CharSet.Unicode,SetLastError=true)]
 static extern bool Move(string path,string destination,uint flags);
 public static int Probe(string path){
  using(SafeFileHandle h=Open(path,GEN_WRITE,SHARE_ALL,IntPtr.Zero,EXISTING,NOFOLLOW,IntPtr.Zero)){
   if(h.IsInvalid)return Marshal.GetLastWin32Error();
   return 0;
  }
 }
 public static int Link(string link,string target){
  if(Sym(link,target,0))return 0;
  return Marshal.GetLastWin32Error();
 }
 public static int Replace(string path,string destination){
  if(Move(path,destination,1))return 0;
  return Marshal.GetLastWin32Error();
 }
}
'@
 $phase='BEFORE_HELPER_POSITIVE_CAPABILITY'
 $probeCode=[R358NativeProbeMove]::Probe($expectedLeaf)
 if($probeCode -ne 0){throw ('R358_WRITE_ACCESS_PREHELPER_NOT_ALLOWED_'+$probeCode)}
 $probeBeforeAllowed=$true
 [IO.File]::WriteAllText($control,'R358_TRUSTED_CONTROL',[Text.UTF8Encoding]::new($false))
 $controlLink=$control+'_symlink'
 if([R358NativeProbeMove]::Link($controlLink,$canary) -ne 0){throw 'R358_CONTROL_CREATE_SYMLINK_FAILED'}
 if([R358NativeProbeMove]::Replace($controlLink,$control) -ne 0 -or
    ([IO.File]::GetAttributes($control) -band [IO.FileAttributes]::ReparsePoint) -eq 0){
  throw 'R358_CONTROL_REPLACE_SYMLINK_NOT_ALLOWED'
 }
 [IO.File]::Delete($control)
 [IO.File]::WriteAllText($control,'R358_TRUSTED_CONTROL',[Text.UTF8Encoding]::new($false))
 $actorBeforeSuccess=$true
 $phase='CREATE_SYMLINK_SOURCE_OUTSIDE_PROTECTED_JOURNAL_TREE'
 $code=[R358NativeProbeMove]::Link($swapSource,$canary)
 if($code -ne 0 -or
    ([IO.File]::GetAttributes($swapSource) -band [IO.FileAttributes]::ReparsePoint) -eq 0){
  throw ('R358_REAL_SYMLINK_PREPARE_FAILED_'+$code)
 }
 $linkReady=$true
 [IO.File]::WriteAllText($ReadyPath,'R358_ADMIN_SYMLINK_ACTOR_READY_'+$nonce,[Text.UTF8Encoding]::new($false))
 $phase='WAIT_FOR_ACTUAL_HELPER_PID'
 $timer=[Diagnostics.Stopwatch]::StartNew()
 while(-not [IO.File]::Exists($SignalPath) -and $timer.ElapsedMilliseconds -lt 20000){
  Start-Sleep -Milliseconds 2
 }
 if(-not [IO.File]::Exists($SignalPath)){throw 'R358_ORIGINAL_HELPER_PID_SIGNAL_TIMEOUT'}
 $signal=Get-Content -LiteralPath $SignalPath -Raw|ConvertFrom-Json
 if($signal.Nonce -cne $nonce -or $signal.SourceCommit -cne $sourceCommit -or
    [int]$signal.HelperPid -le 0 -or [int]$signal.HelperPid -in @($PID,[int]$authority.ParentPid)){
  throw 'R358_UNTRUSTED_SIGNAL_HELPER_PID'
 }
 $helperPid=[int]$signal.HelperPid
 $phase='REAL_ORIGINAL_HELPER_PREPARED_REPLAY_NATIVE_REPARSE_SWAP_RACE'
 $timer.Restart()
 while($timer.ElapsedMilliseconds -lt 28000){
  $attempts++
  $code=[R358NativeProbeMove]::Probe($expectedLeaf)
  if($code -eq 32){
    $proc=Get-Process -Id $helperPid -ErrorAction SilentlyContinue
    $helperAlive=($null -ne $proc -and !$proc.HasExited)
    $journalReady=[IO.File]::Exists((Join-Path $expectedJournal 'READY'))
    if($helperAlive -and $journalReady){
      $moveCode=[R358NativeProbeMove]::Replace($swapSource,$expectedLeaf)
      $moved=($moveCode -eq 0)
      if($moved){throw 'R358_SECURITY_FAILURE_NATIVE_SYMLINK_REPLACE_SUCCEEDED_WHILE_HELPER_LIVE'}
      if($moveCode -notin @(5,32)){throw ('R358_UNEXPECTED_MOVEFILEEX_WIN32_'+$moveCode)}
      $sourceIntact=[IO.File]::Exists($swapSource) -and
        (([IO.File]::GetAttributes($swapSource) -band [IO.FileAttributes]::ReparsePoint) -ne 0)
      $helperAlive=($null -ne (Get-Process -Id $helperPid -ErrorAction SilentlyContinue))
      $journalReady=[IO.File]::Exists((Join-Path $expectedJournal 'READY'))
      if($sourceIntact -and $helperAlive -and $journalReady){
        $denied=$true
        break
      }
      throw 'R358_HELPER_OR_JOURNAL_NOT_ALIVE_AFTER_ACTUAL_MOVEFILEEX_PROBE'
    }
  }elseif($code -ne 0){
    throw ('R358_NATIVE_WRITE_PROBE_UNEXPECTED_WIN32_'+$code)
  }
  if(($attempts % 20) -eq 0 -and
     $null -eq (Get-Process -Id $helperPid -ErrorAction SilentlyContinue)){break}
  Start-Sleep -Milliseconds 1
 }
 if(!$denied){throw ('R358_NO_ACTUAL_NATIVE_SYMLINK_SWAP_DENIAL_DURING_HELPER_REPLAY_'+$attempts)}
 $phase='CLEAN_KNOWN_ACTOR_SOURCE_AND_VERIFY_CANARY'
 if(-not [IO.File]::Exists($swapSource) -or
    ([IO.File]::GetAttributes($swapSource) -band [IO.FileAttributes]::ReparsePoint) -eq 0){
  throw 'R358_SYMLINK_SOURCE_IDENTITY_MISSING'
 }
 [IO.File]::Delete($swapSource)
 if([IO.File]::Exists($swapSource)){throw 'R358_SOURCE_SYMLINK_NOT_UNLINKED'}
 $linkReady=$false
 $canaryIntact=((H $canary) -ceq $authority.OutsideSHA256)
 if(!$canaryIntact){throw 'R358_EXTERNAL_CANARY_CHANGED'}
}catch{
 $failure=$_.Exception.GetType().Name+': '+$_.Exception.Message+' PHASE='+$phase
}finally{
 try{
  if($control -and [IO.File]::Exists($control) -and
     [IO.File]::ReadAllText($control) -ceq 'R358_TRUSTED_CONTROL'){
    [IO.File]::Delete($control)
  }
  if($linkReady -and -not $moved -and $swapSource -and [IO.File]::Exists($swapSource) -and
     ([IO.File]::GetAttributes($swapSource) -band [IO.FileAttributes]::ReparsePoint) -ne 0){
    [IO.File]::Delete($swapSource)
  }
 }catch{$failure+=' R358_ACTOR_SAFETY_CLEANUP_REFUSED'}
 $status=if(!$failure -and $denied -and $actorBeforeSuccess -and $probeBeforeAllowed -and
    $linkReady -eq $false -and $sourceIntact -and $helperAlive -and $journalReady -and
    $moveCode -in @(5,32) -and $attempts -gt 0 -and $canaryIntact){
   'PASS_REAL_ORIGINAL_HELPER_CONCURRENT_ADMIN_NATIVE_REPARSE_SWAP_DENIED'
 }else{'FAIL_R358_NATIVE_REPARSE_RACE_NOT_ACCEPTED'}
 $result=[ordered]@{
  Schema=1;Revision='R358';SourceCommit=$sourceCommit
  Host=[string]$(if($null -ne $authority){$authority.Host}else{'UNKNOWN'})
  Status=$status;ActorPid=$PID;HelperPid=$helperPid;AlreadyAdmin=$true
  DifferentAdminProcess=$true;NativePreHelperWriteOpenAllowed=$probeBeforeAllowed
  NativePositiveControlSymlinkReplacedBeforeHelper=$actorBeforeSuccess
  ExactProtectedSupervisorFixedPath=$expectedLeaf
  BoundedAttempts=$attempts;InitialNativePreProbeWin32=$probeCode
  NativeMoveFileExWin32=$moveCode;NativeMoveFileExAttempted=($moveCode -ne -1)
  NativeSymlinkReplacementAllowed=$moved
  NativeSymlinkReplacementDeniedDuringLiveHelper=$denied
  NativeSourceSymlinkRetainedOnDenial=$sourceIntact
  OriginalHelperStillAliveAtNativeSwap=$helperAlive
  TrustedPreparedJournalReadyAtNativeSwap=$journalReady
  OutsideCanarySHA256=$(if($null -ne $authority){[string]$authority.OutsideSHA256}else{''})
  OutsideCanaryUnchanged=$canaryIntact
  ActualOriginalHelperPREPAREDReplayObserved=$denied
  RealInteractiveUacDialogObserved=$false
  OwnerComputerTouched=$false;Failure=$failure
 }
 try{[IO.File]::WriteAllText($ReceiptPath,($result|ConvertTo-Json -Depth 8),
   [Text.UTF8Encoding]::new($false))}catch{Write-Output ('R358_RECEIPT_NOT_WRITTEN '+$_.Exception.Message)}
 Write-Output ('R358_ACTOR_STATUS='+$status+' ATTEMPTS='+$attempts+' MOVE_WIN32='+$moveCode)
}
if($failure){throw ('R358_NATIVE_ACTOR_REJECTED '+$failure)}
