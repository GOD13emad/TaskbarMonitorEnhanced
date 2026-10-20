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
$externalHardlinkTarget='';$externalHardlinkSHA='';$externalHardlinkRestored=$false;$nativeHardlinkCountTwo=$false
$authority=$null
function Hash-R360File([string]$path){return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash}
try {
 if($PSVersionTable.PSEdition -cne 'Desktop' -or
    $env:GITHUB_ACTIONS -cne 'true' -or
    $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
    $env:RUNNER_OS -cne 'Windows' -or
    $env:GITHUB_REPOSITORY -cne 'GOD13emad/TaskbarMonitorEnhanced' -or
    $env:GITHUB_REF -cne 'refs/heads/audit/r360-original-helper-concurrent-hardlink' -or
    $env:COMPUTERNAME -match '(?i)EMAD-PC|ALIEMAD|SAEID|LAPTOP' -or
    $sourceCommit -cnotmatch '^[0-9a-f]{40}$'){
  throw 'R360_DISPOSABLE_GUEST_ONLY'
 }
 $token=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
 if(!$token.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
  throw 'R360_ALREADY_ADMIN_GUEST_REQUIRED'
 }
 $guestTemp=[IO.Path]::GetFullPath($env:RUNNER_TEMP).TrimEnd('\')+'\'
 foreach($path in @($AuthorityPath,$ReadyPath,$SignalPath,$ReceiptPath)){
   if(-not [IO.Path]::GetFullPath($path).StartsWith($guestTemp,[StringComparison]::OrdinalIgnoreCase)){
     throw 'R360_UNTRUSTED_CONTROL_PATH_OUTSIDE_HOSTED_TEMP'
   }
 }
 foreach($path in @($ReadyPath,$SignalPath,$ReceiptPath)){
   if([IO.File]::Exists($path)){throw 'R360_PREEXISTING_CONTROL_FILE'}
 }
 $authority=Get-Content -LiteralPath $AuthorityPath -Raw|ConvertFrom-Json
 $expectedLeaf=Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles)) 'TaskbarMonitorEnhanced\SensorBroker\TaskbarMonitorSensorSupervisor.exe'
 $expectedJournal=Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles)) 'TaskbarMonitorEnhanced\.tbme-sensor-rollback'
 $canary=[IO.Path]::GetFullPath([string]$authority.OutsideCanary)
 if($authority.Schema -ne 1 -or $authority.Revision -cne 'R360' -or
    $authority.SourceCommit -cne $sourceCommit -or $authority.Host -cnotmatch '^[AB]$' -or
    $authority.HostedComputer -cne $env:COMPUTERNAME -or
    $authority.ExpectedLeaf -cne $expectedLeaf -or
    $authority.ExpectedJournal -cne $expectedJournal -or
    $authority.Nonce -cnotmatch '^[0-9a-f]{32}$' -or
    $authority.ParentPid -le 0 -or
    -not $canary.StartsWith($guestTemp,[StringComparison]::OrdinalIgnoreCase) -or
    $authority.OutsideSHA256 -cnotmatch '^[0-9A-F]{64}$' -or
    -not [IO.File]::Exists($canary) -or
    (Hash-R360File $canary) -cne $authority.OutsideSHA256){
  throw 'R360_AUTHORITY_OR_CANARY_NOT_EXACT'
 }
 $nonce=[string]$authority.Nonce
 if(-not [IO.File]::Exists($expectedLeaf) -or
    -not [IO.File]::Exists((Join-Path $expectedJournal 'READY'))){
  throw 'R360_EXPECTED_REAL_PREPARED_JOURNAL_OR_PROTECTED_LEAF_MISSING'
 }
 $local=[Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
 $actorTemp=Join-Path $local 'Temp'
 if(-not [IO.Directory]::Exists($actorTemp) -or
    -not [string]::Equals([IO.Path]::GetPathRoot($actorTemp),[IO.Path]::GetPathRoot($expectedLeaf),[StringComparison]::OrdinalIgnoreCase)){
  throw 'R360_MOVEFILEEX_CROSS_VOLUME_OR_MISSING_LOCAL_TEMP'
 }
 $swapSource=Join-Path $actorTemp ('R360_HARDLINK_SWAP_'+$nonce+'.bin')
 $control=Join-Path $actorTemp ('R360_TEST_CONTROL_'+$nonce+'.bin')
 $externalHardlinkTarget=Join-Path (Split-Path $expectedJournal -Parent) ('R360_OUTSIDE_HARDLINK_TARGET_'+$nonce+'.bin')
 $expectedExternalParent=[IO.Path]::GetFullPath((Split-Path $expectedJournal -Parent)).TrimEnd('\')
 if(-not [string]::Equals([IO.Path]::GetDirectoryName($externalHardlinkTarget),
       $expectedExternalParent,[StringComparison]::OrdinalIgnoreCase) -or
    -not [string]::Equals([IO.Path]::GetPathRoot($externalHardlinkTarget),
         [IO.Path]::GetPathRoot($expectedLeaf),[StringComparison]::OrdinalIgnoreCase) -or
    [IO.File]::Exists($externalHardlinkTarget) -or
    [IO.File]::Exists($swapSource) -or [IO.File]::Exists($control)){
  throw 'R360_HARDLINK_NATIVE_SINGLE_VOLUME_OR_EXACT_PROTECTED_ROOT_PRECONDITION'
 }
 # Only this one new disposable guest test file, sibling to SensorBroker and Journal.
 [IO.File]::WriteAllText($externalHardlinkTarget,
   ('R360_KNOWN_NATIVE_HARDLINK_TARGET_'+$nonce),[Text.UTF8Encoding]::new($false))
 $externalHardlinkSHA=Hash-R360File $externalHardlinkTarget
 Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class R360NativeProbeMove {
 const uint GEN_WRITE=0x40000000,SHARE_ALL=7,EXISTING=3,NOFOLLOW=0x00200000;
 [DllImport("kernel32.dll",EntryPoint="CreateFileW",CharSet=CharSet.Unicode,SetLastError=true)]
 static extern SafeFileHandle Open(string path,uint access,uint share,IntPtr sec,uint mode,uint flags,IntPtr template);
 [DllImport("kernel32.dll",EntryPoint="CreateHardLinkW",CharSet=CharSet.Unicode,SetLastError=true)]
 static extern bool Hard(string link,string target,IntPtr reserved);
 [StructLayout(LayoutKind.Sequential)] struct FILE_TIME {public uint Low,High;}
 [StructLayout(LayoutKind.Sequential)] struct FILE_INFO {
  public uint Attributes;public FILE_TIME Created,Accessed,Modified;
  public uint Volume,SizeHigh,SizeLow,Links,IndexHigh,IndexLow;
 }
 [DllImport("kernel32.dll",SetLastError=true)]
 static extern bool GetFileInformationByHandle(SafeFileHandle h,out FILE_INFO info);
 [DllImport("kernel32.dll",EntryPoint="MoveFileExW",CharSet=CharSet.Unicode,SetLastError=true)]
 static extern bool Move(string path,string destination,uint flags);
 public static int Probe(string path){
  using(SafeFileHandle h=Open(path,GEN_WRITE,SHARE_ALL,IntPtr.Zero,EXISTING,NOFOLLOW,IntPtr.Zero)){
   if(h.IsInvalid)return Marshal.GetLastWin32Error();
   return 0;
  }
 }
 public static int Link(string link,string target){
  if(Hard(link,target,IntPtr.Zero))return 0;
  return Marshal.GetLastWin32Error();
 }
 public static uint LinkCount(string path){
  using(SafeFileHandle h=Open(path,0x80000000,SHARE_ALL,IntPtr.Zero,EXISTING,NOFOLLOW,IntPtr.Zero)){
   if(h.IsInvalid)throw new IOException("R360_LINK_COUNT_OPEN_WIN32_"+Marshal.GetLastWin32Error());
   FILE_INFO info;
   if(!GetFileInformationByHandle(h,out info))throw new IOException("R360_LINK_COUNT_INFO_WIN32_"+Marshal.GetLastWin32Error());
   return info.Links;
  }
 }
 public static int Replace(string path,string destination){
  if(Move(path,destination,1))return 0;
  return Marshal.GetLastWin32Error();
 }
}
'@
 $phase='BEFORE_HELPER_POSITIVE_NATIVE_HARDLINK_CAPABILITY'
 $probeCode=[R360NativeProbeMove]::Probe($expectedLeaf)
 if($probeCode -ne 0){throw ('R360_WRITE_ACCESS_PREHELPER_NOT_ALLOWED_'+$probeCode)}
 $probeBeforeAllowed=$true
 [IO.File]::WriteAllText($control,'R360_TRUSTED_CONTROL',[Text.UTF8Encoding]::new($false))
 $controlLink=$control+'_hardlink'
 if([R360NativeProbeMove]::Link($controlLink,$externalHardlinkTarget) -ne 0 -or
    [R360NativeProbeMove]::LinkCount($controlLink) -ne 2){
   throw 'R360_NATIVE_CONTROL_REAL_HARDLINK_NOT_TWO_LINKS'
 }
 if([R360NativeProbeMove]::Replace($controlLink,$control) -ne 0 -or
    [R360NativeProbeMove]::LinkCount($control) -ne 2 -or
    (Hash-R360File $control) -cne $externalHardlinkSHA){
  throw 'R360_CONTROL_REPLACE_WITH_REAL_HARDLINK_NOT_ALLOWED'
 }
 # Removing a hardlink removes only that directory entry, never target contents.
 [IO.File]::Delete($control)
 if([R360NativeProbeMove]::LinkCount($externalHardlinkTarget) -ne 1 -or
    (Hash-R360File $externalHardlinkTarget) -cne $externalHardlinkSHA){
  throw 'R360_CONTROL_CLEANUP_NOT_PRESERVING_EXTERNAL_TARGET'
 }
 [IO.File]::WriteAllText($control,'R360_TRUSTED_CONTROL',[Text.UTF8Encoding]::new($false))
 $actorBeforeSuccess=$true
 $phase='PREPARE_REAL_HARDLINK_SOURCE_IN_SEPARATE_TEMP_TREE'
 $code=[R360NativeProbeMove]::Link($swapSource,$externalHardlinkTarget)
 if($code -ne 0 -or
    [R360NativeProbeMove]::LinkCount($swapSource) -ne 2 -or
    [R360NativeProbeMove]::LinkCount($externalHardlinkTarget) -ne 2 -or
    ([IO.File]::GetAttributes($swapSource) -band [IO.FileAttributes]::ReparsePoint) -ne 0){
  throw ('R360_REAL_HARDLINK_PREPARE_FAILED_'+$code)
 }
 $linkReady=$true
 [IO.File]::WriteAllText($ReadyPath,'R360_ADMIN_HARDLINK_ACTOR_READY_'+$nonce,[Text.UTF8Encoding]::new($false))
 $phase='WAIT_FOR_ACTUAL_HELPER_PID'
 $timer=[Diagnostics.Stopwatch]::StartNew()
 while(-not [IO.File]::Exists($SignalPath) -and $timer.ElapsedMilliseconds -lt 20000){
  Start-Sleep -Milliseconds 2
 }
 if(-not [IO.File]::Exists($SignalPath)){throw 'R360_ORIGINAL_HELPER_PID_SIGNAL_TIMEOUT'}
 $signal=Get-Content -LiteralPath $SignalPath -Raw|ConvertFrom-Json
 if($signal.Nonce -cne $nonce -or $signal.SourceCommit -cne $sourceCommit -or
    [int]$signal.HelperPid -le 0 -or [int]$signal.HelperPid -in @($PID,[int]$authority.ParentPid)){
  throw 'R360_UNTRUSTED_SIGNAL_HELPER_PID'
 }
 $helperPid=[int]$signal.HelperPid
 $phase='REAL_ORIGINAL_HELPER_PREPARED_REPLAY_NATIVE_REPARSE_SWAP_RACE'
 $timer.Restart()
 while($timer.ElapsedMilliseconds -lt 28000){
  $attempts++
  $code=[R360NativeProbeMove]::Probe($expectedLeaf)
  if($code -eq 32){
    $proc=Get-Process -Id $helperPid -ErrorAction SilentlyContinue
    $helperAlive=($null -ne $proc -and !$proc.HasExited)
    $journalReady=[IO.File]::Exists((Join-Path $expectedJournal 'READY'))
    if($helperAlive -and $journalReady){
      $moveCode=[R360NativeProbeMove]::Replace($swapSource,$expectedLeaf)
      $moved=($moveCode -eq 0)
      if($moved){throw 'R360_SECURITY_FAILURE_NATIVE_HARDLINK_REPLACE_SUCCEEDED_WHILE_HELPER_LIVE'}
      if($moveCode -notin @(5,32)){throw ('R360_UNEXPECTED_MOVEFILEEX_WIN32_'+$moveCode)}
      $sourceIntact=[IO.File]::Exists($swapSource) -and
        (([IO.File]::GetAttributes($swapSource) -band [IO.FileAttributes]::ReparsePoint) -eq 0) -and
        ([R360NativeProbeMove]::LinkCount($swapSource) -eq 2) -and
        ([R360NativeProbeMove]::LinkCount($externalHardlinkTarget) -eq 2) -and
        ((Hash-R360File $externalHardlinkTarget) -ceq $externalHardlinkSHA)
      $nativeHardlinkCountTwo=$sourceIntact
      $helperAlive=($null -ne (Get-Process -Id $helperPid -ErrorAction SilentlyContinue))
      $journalReady=[IO.File]::Exists((Join-Path $expectedJournal 'READY'))
      if($sourceIntact -and $helperAlive -and $journalReady){
        $denied=$true
        break
      }
      throw 'R360_HELPER_OR_JOURNAL_NOT_ALIVE_AFTER_ACTUAL_MOVEFILEEX_PROBE'
    }
  }elseif($code -ne 0){
    throw ('R360_NATIVE_WRITE_PROBE_UNEXPECTED_WIN32_'+$code)
  }
  if(($attempts % 20) -eq 0 -and
     $null -eq (Get-Process -Id $helperPid -ErrorAction SilentlyContinue)){break}
  Start-Sleep -Milliseconds 1
 }
 if(!$denied){throw ('R360_NO_ACTUAL_NATIVE_HARDLINK_SWAP_DENIAL_DURING_HELPER_REPLAY_'+$attempts)}
 $phase='UNLINK_DENIED_HARDLINK_AND_VERIFY_EXTERNAL_TARGET_IDENTITY'
 if(-not [IO.File]::Exists($swapSource) -or
    [R360NativeProbeMove]::LinkCount($swapSource) -ne 2 -or
    [R360NativeProbeMove]::LinkCount($externalHardlinkTarget) -ne 2 -or
    (Hash-R360File $externalHardlinkTarget) -cne $externalHardlinkSHA){
  throw 'R360_HARDLINK_SOURCE_OR_TARGET_IDENTITY_CHANGED'
 }
 [IO.File]::Delete($swapSource)
 if([IO.File]::Exists($swapSource) -or
    [R360NativeProbeMove]::LinkCount($externalHardlinkTarget) -ne 1 -or
    (Hash-R360File $externalHardlinkTarget) -cne $externalHardlinkSHA){
  throw 'R360_HARDLINK_UNLINK_LEFT_EXTERNAL_TARGET_MISMATCH'
 }
 $linkReady=$false
 $canaryIntact=((Hash-R360File $canary) -ceq $authority.OutsideSHA256)
 if(!$canaryIntact){throw 'R360_EXTERNAL_CANARY_CHANGED'}
 [IO.File]::Delete($externalHardlinkTarget)
 $externalHardlinkRestored=![IO.File]::Exists($externalHardlinkTarget)
 if(!$externalHardlinkRestored){throw 'R360_EXTERNAL_HARDLINK_TARGET_NOT_REMOVED'}
}catch{
 $failure=$_.Exception.GetType().Name+': '+$_.Exception.Message+' PHASE='+$phase
}finally{
 try{
  if($control -and [IO.File]::Exists($control) -and
     [IO.File]::ReadAllText($control) -ceq 'R360_TRUSTED_CONTROL'){
    [IO.File]::Delete($control)
  }
  if($linkReady -and -not $moved -and $swapSource -and [IO.File]::Exists($swapSource) -and
     $externalHardlinkTarget -and [IO.File]::Exists($externalHardlinkTarget) -and
     [R360NativeProbeMove]::LinkCount($swapSource) -eq 2 -and
     (Hash-R360File $externalHardlinkTarget) -ceq $externalHardlinkSHA){
    [IO.File]::Delete($swapSource)
  }
  if($externalHardlinkTarget -and [IO.File]::Exists($externalHardlinkTarget) -and
     !$moved -and $externalHardlinkSHA -and
     [R360NativeProbeMove]::LinkCount($externalHardlinkTarget) -eq 1 -and
     (Hash-R360File $externalHardlinkTarget) -ceq $externalHardlinkSHA){
      [IO.File]::Delete($externalHardlinkTarget)
      $externalHardlinkRestored=![IO.File]::Exists($externalHardlinkTarget)
  }
 }catch{$failure+=' R360_ACTOR_SAFETY_CLEANUP_REFUSED'}
 $status=if(!$failure -and $denied -and $actorBeforeSuccess -and $probeBeforeAllowed -and
    $linkReady -eq $false -and $sourceIntact -and $helperAlive -and $journalReady -and
    $moveCode -in @(5,32) -and $attempts -gt 0 -and $canaryIntact -and $nativeHardlinkCountTwo -and $externalHardlinkRestored){
   'PASS_REAL_ORIGINAL_HELPER_CONCURRENT_ADMIN_NATIVE_HARDLINK_SWAP_DENIED'
 }else{'FAIL_R360_NATIVE_REPARSE_RACE_NOT_ACCEPTED'}
 $result=[ordered]@{
  Schema=1;Revision='R360';SourceCommit=$sourceCommit
  Host=[string]$(if($null -ne $authority){$authority.Host}else{'UNKNOWN'})
  Status=$status;ActorPid=$PID;HelperPid=$helperPid;AlreadyAdmin=$true
  DifferentAdminProcess=$true;NativePreHelperWriteOpenAllowed=$probeBeforeAllowed
  NativePositiveControlHardlinkReplacedBeforeHelper=$actorBeforeSuccess
  ExactProtectedSupervisorFixedPath=$expectedLeaf
  BoundedAttempts=$attempts;InitialNativePreProbeWin32=$probeCode
  NativeMoveFileExWin32=$moveCode;NativeMoveFileExAttempted=($moveCode -ne -1)
  NativeHardlinkReplacementAllowed=$moved
  NativeHardlinkReplacementDeniedDuringLiveHelper=$denied
  NativeSourceHardlinkRetainedOnDenial=$sourceIntact
  OriginalHelperStillAliveAtNativeSwap=$helperAlive
  TrustedPreparedJournalReadyAtNativeSwap=$journalReady
  OutsideCanarySHA256=$(if($null -ne $authority){[string]$authority.OutsideSHA256}else{''})
  OutsideCanaryUnchanged=$canaryIntact
  ActualOriginalHelperPREPAREDReplayObserved=$denied
  NativeHardlinkSourceCountTwoAtDenial=$nativeHardlinkCountTwo
  ExternalHardlinkTargetRestoredAndRemoved=$externalHardlinkRestored
  ExternalHardlinkTargetOriginalSHA256=$externalHardlinkSHA
  RealInteractiveUacDialogObserved=$false
  OwnerComputerTouched=$false;Failure=$failure
 }
 try{[IO.File]::WriteAllText($ReceiptPath,($result|ConvertTo-Json -Depth 8),
   [Text.UTF8Encoding]::new($false))}catch{Write-Output ('R360_RECEIPT_NOT_WRITTEN '+$_.Exception.Message)}
 Write-Output ('R360_ACTOR_STATUS='+$status+' ATTEMPTS='+$attempts+' MOVE_WIN32='+$moveCode)
}
if($failure){throw ('R360_NATIVE_ACTOR_REJECTED '+$failure)}
