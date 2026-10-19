[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$AuthorityPath,
  [Parameter(Mandatory=$true)][string]$ReadyPath,
  [Parameter(Mandatory=$true)][string]$SignalPath,
  [Parameter(Mandatory=$true)][string]$ReceiptPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# Test-only: a distinct already-admin process repeatedly attempts a WRITE-ACCESS
# OPEN on the real pinned protected leaf. It never writes or changes file bytes.
$failure='';$phase='PRECHECK';$attempts=0;$allowedBefore=$false;$denied=$false
$helperPid=0;$errorCode=-1;$helperWasAlive=$false;$journalReady=$false
$sourceCommit=$env:GITHUB_SHA;$leaf='';$nonce='';$authority=$null
try{
 if($PSVersionTable.PSEdition -cne 'Desktop' -or
    $env:GITHUB_ACTIONS -cne 'true' -or
    $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
    $env:RUNNER_OS -cne 'Windows' -or
    $env:GITHUB_REPOSITORY -cne 'GOD13emad/TaskbarMonitorEnhanced' -or
    $env:GITHUB_REF -cne 'refs/heads/audit/r350-original-helper-preopened-delete-recovery' -or
    $env:COMPUTERNAME -match '(?i)EMAD-PC|ALIEMAD|SAEID|LAPTOP' -or
    $sourceCommit -cnotmatch '^[0-9a-f]{40}$'){
   throw 'R351_ACTOR_REFUSE_NONDISPOSABLE_OR_INVALID_SOURCE'
 }
 $who=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
 if(!$who.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
   throw 'R351_ACTOR_ALREADY_ADMIN_TOKEN_REQUIRED'
 }
 $temp=[IO.Path]::GetFullPath($env:RUNNER_TEMP).TrimEnd('\')+'\'
 foreach($p in @($AuthorityPath,$ReadyPath,$SignalPath,$ReceiptPath)){
   $full=[IO.Path]::GetFullPath($p)
   if(!$full.StartsWith($temp,[StringComparison]::OrdinalIgnoreCase)){
     throw 'R351_ACTOR_CONTROL_PATH_OUTSIDE_HOSTED_TEMP'
   }
 }
 if([IO.File]::Exists($ReadyPath) -or [IO.File]::Exists($SignalPath) -or
    [IO.File]::Exists($ReceiptPath)){throw 'R351_ACTOR_OLD_CONTROL_FILE_REFUSED'}
 $authority=Get-Content -LiteralPath $AuthorityPath -Raw|ConvertFrom-Json
 $expectedLeaf=Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles)) 'TaskbarMonitorEnhanced\SensorBroker\TaskbarMonitorSensorSupervisor.exe'
 $expectedJournal=Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles)) 'TaskbarMonitorEnhanced\.tbme-sensor-rollback'
 if($authority.Schema -ne 1 -or $authority.Revision -cne 'R351' -or
    $authority.SourceCommit -cne $sourceCommit -or
    $authority.Host -cnotmatch '^[AB]$' -or
    $authority.HostedComputer -cne $env:COMPUTERNAME -or
    $authority.ExpectedLeaf -cne $expectedLeaf -or
    $authority.ExpectedJournal -cne $expectedJournal -or
    $authority.Nonce -cnotmatch '^[0-9a-f]{32}$' -or
    [int]$authority.ParentPid -le 0){
   throw 'R351_ACTOR_AUTHORITY_INCOMPLETE_OR_UNTRUSTED'
 }
 $nonce=[string]$authority.Nonce;$leaf=$expectedLeaf
 if(![IO.File]::Exists($leaf) -or
    ![IO.File]::Exists((Join-Path $expectedJournal 'READY'))){
   throw 'R351_ACTOR_REAL_PROTECTED_REPLAY_PREREQUISITE_MISSING'
 }
 Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class R351AccessOnlyOpen {
 const uint GENERIC_WRITE=0x40000000, SHARE_ALL=7, OPEN_EXISTING=3, REPARSE_FLAG=0x00200000;
 [DllImport("kernel32.dll",EntryPoint="CreateFileW",CharSet=CharSet.Unicode,SetLastError=true)]
 static extern SafeFileHandle Open(string path,uint access,uint share,IntPtr sec,uint mode,uint flags,IntPtr template);
 public static int Probe(string path){
  using(SafeFileHandle h=Open(path,GENERIC_WRITE,SHARE_ALL,IntPtr.Zero,OPEN_EXISTING,REPARSE_FLAG,IntPtr.Zero)){
   if(h.IsInvalid)return Marshal.GetLastWin32Error();
   return 0;
  }
 }
}
'@
 $phase='VERIFY_REAL_WRITE_ACCESS_AVAILABLE_BEFORE_HELPER'
 $code=[R351AccessOnlyOpen]::Probe($leaf)
 if($code -ne 0){throw ('R351_ACTOR_PRE_HELPER_OPEN_NOT_AVAILABLE_WIN32_'+$code)}
 $allowedBefore=$true
 [IO.File]::WriteAllText($ReadyPath,'R351_ADMIN_ACTOR_READY_'+$nonce,[Text.UTF8Encoding]::new($false))
 $phase='WAIT_FOR_EXACT_ORIGINAL_HELPER_PID'
 $clock=[Diagnostics.Stopwatch]::StartNew()
 while(![IO.File]::Exists($SignalPath) -and $clock.ElapsedMilliseconds -lt 20000){
   Start-Sleep -Milliseconds 2
 }
 if(![IO.File]::Exists($SignalPath)){throw 'R351_ACTOR_HELPER_START_SIGNAL_TIMEOUT'}
 $signal=Get-Content -LiteralPath $SignalPath -Raw|ConvertFrom-Json
 if($signal.Nonce -cne $nonce -or $signal.SourceCommit -cne $sourceCommit -or
    $signal.HelperPid -le 0 -or $signal.HelperPid -eq $PID -or
    $signal.HelperPid -eq $authority.ParentPid){
   throw 'R351_ACTOR_UNTRUSTED_HELPER_START_SIGNAL'
 }
 $helperPid=[int]$signal.HelperPid
 $phase='REAL_HELPER_PREPARED_REPLAY_NATIVE_WRITE_OPEN_RACE'
 $clock.Restart()
 while($clock.ElapsedMilliseconds -lt 28000){
   $attempts++
   $code=[R351AccessOnlyOpen]::Probe($leaf)
   if($code -eq 32){
     $proc=Get-Process -Id $helperPid -ErrorAction SilentlyContinue
     $helperWasAlive=($null -ne $proc -and !$proc.HasExited)
     $journalReady=[IO.File]::Exists((Join-Path $expectedJournal 'READY'))
     if($helperWasAlive -and $journalReady){
       $denied=$true;$errorCode=$code
       break
     }
   }elseif($code -ne 0){
     throw ('R351_ACTOR_UNEXPECTED_WIN32_'+$code)
   }
   if(($attempts % 20) -eq 0 -and
      $null -eq (Get-Process -Id $helperPid -ErrorAction SilentlyContinue)){
     break
   }
   Start-Sleep -Milliseconds 2
 }
 if(!$denied){throw ('R351_ACTOR_NO_SHARING_DENIAL_DURING_LIVE_ORIGINAL_REPLAY attempts='+$attempts)}
}catch{
 $failure=$_.Exception.GetType().Name+': '+$_.Exception.Message+' PHASE='+$phase
}finally{
 $status=if(!$failure -and $denied -and $allowedBefore -and
   $helperWasAlive -and $journalReady -and $attempts -gt 0){
   'PASS_REAL_ORIGINAL_HELPER_CONCURRENT_ADMIN_WRITE_OPEN_DENIED'
 }else{'FAIL_R351_ACTIVE_WRITER_NOT_WITNESSED'}
 $receiptObj=[ordered]@{
   Schema=1;Revision='R351';Status=$status;SourceCommit=$sourceCommit
   Host=[string]$(if($null -ne $authority){$authority.Host}else{'UNKNOWN'})
   ActorPid=$PID;HelperPid=$helperPid
   DifferentAdminProcess=$true;AlreadyAdmin=$true
   OriginalLeafPathIsFixedSystemProtectedPath=($leaf -like '*\TaskbarMonitorEnhanced\SensorBroker\TaskbarMonitorSensorSupervisor.exe')
   AllowedWriteAccessOpenBeforeHelper=$allowedBefore
   BoundedAttempts=$attempts;SharingViolationWin32=$errorCode
   ExactHelperStillAliveAtDenial=$helperWasAlive
   TrustedPreparedJournalReadyAtDenial=$journalReady
   OriginalHelperLiveReplaySharingDenied=$denied
   OpenOnlyNoWriteEverPerformed=$true
   OwnerMachineTouched=$false;Failure=$failure
 }
 try{[IO.File]::WriteAllText($ReceiptPath,($receiptObj|ConvertTo-Json -Depth 8),
      [Text.UTF8Encoding]::new($false))}catch{Write-Output ('R351_ACTOR_RECEIPT_FAILED '+$_.Exception.Message)}
 Write-Output ('R351_ACTOR_STATUS='+$status+' ATTEMPTS='+$attempts)
}
if($failure){throw ('R351_ACTOR_NOT_ACCEPTED '+$failure)}
