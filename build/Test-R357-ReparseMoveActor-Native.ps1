[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$AuthorityPath,
 [Parameter(Mandatory=$true)][string]$ReceiptPath,
 [Parameter(Mandatory=$true)][ValidateSet('Before','During','After')][string]$Phase
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -cne 'Desktop' -or $env:GITHUB_ACTIONS -cne 'true' -or
 $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or $env:RUNNER_OS -cne 'Windows' -or
 $env:GITHUB_REPOSITORY -cne 'GOD13emad/TaskbarMonitorEnhanced' -or
 $env:GITHUB_REF -cne 'refs/heads/audit/r357-native-protected-leaf-reparse-swap' -or
 $env:GITHUB_SHA -cnotmatch '^[0-9a-f]{40}$' -or
 $env:COMPUTERNAME -match '(?i)EMAD-PC|ALIEMAD|SAEID|LAPTOP'){
 throw 'R357_ONLY_DISPOSABLE_WINDOWS_ADMIN_GUEST'
}
$p=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if(!$p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'R357_ACTOR_ADMIN_REQUIRED'}
$top=[IO.Path]::GetFullPath($env:RUNNER_TEMP).TrimEnd('\')+'\'
foreach($f in @($AuthorityPath,$ReceiptPath)){
 if(![IO.Path]::GetFullPath($f).StartsWith($top,[StringComparison]::OrdinalIgnoreCase)){
  throw 'R357_ACTOR_CONTROL_OUTSIDE_GUEST_TEMP'
 }
}
if([IO.File]::Exists($ReceiptPath)){throw 'R357_ACTOR_RECEIPT_ALREADY_EXISTS'}
$a=Get-Content -LiteralPath $AuthorityPath -Raw|ConvertFrom-Json
$fixedRoot=Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles)) 'TaskbarMonitorEnhanced\SensorBroker'
$leaf=Join-Path $fixedRoot 'TaskbarMonitorSensorSupervisor.exe'
$control=Join-Path $fixedRoot 'R357_CONTROL_VICTIM.txt'
$canary=[IO.Path]::GetFullPath([string]$a.ExternalCanary)
if($a.Schema -ne 1 -or $a.Revision -cne 'R357' -or
 $a.SourceCommit -cne $env:GITHUB_SHA -or $a.Guest -cne $env:COMPUTERNAME -or
 $a.ParentPid -le 0 -or $a.ProtectedLeaf -cne $leaf -or
 $a.ControlLeaf -cne $control -or
 $a.TrustedSupervisorBytes -cnotmatch '^R357_TRUSTED_SUPERVISOR_[0-9]+_[AB]$' -or
 $a.CanarySHA256 -cnotmatch '^[0-9A-F]{64}$' -or
 -not $canary.StartsWith($top,[StringComparison]::OrdinalIgnoreCase) -or
 -not [IO.File]::Exists($canary) -or
 (Get-FileHash -LiteralPath $canary -Algorithm SHA256).Hash -cne $a.CanarySHA256){
 throw 'R357_ACTOR_UNTRUSTED_AUTHORITY_OR_EXTERNAL_CANARY'
}
$source=Join-Path $fixedRoot ('R357_'+$Phase+'_prepared_symlink.txt')
$destination=if($Phase -ceq 'Before'){$control}else{$leaf}
if([IO.File]::Exists($source) -or [IO.Directory]::Exists($source) -or
 -not [IO.File]::Exists($destination)){
 throw 'R357_ACTOR_SOURCE_COLLISION_OR_DESTINATION_MISSING'
}
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class R357RealMoveEx {
 [DllImport("kernel32.dll",EntryPoint="CreateSymbolicLinkW",CharSet=CharSet.Unicode,SetLastError=true)]
 static extern bool Sym(string link,string target,uint flags);
 [DllImport("kernel32.dll",EntryPoint="MoveFileExW",CharSet=CharSet.Unicode,SetLastError=true)]
 static extern bool Move(string source,string destination,uint flags);
 public static int CreateSym(string link,string target){
   if(Sym(link,target,0))return 0;
   return Marshal.GetLastWin32Error();
 }
 public static int Replace(string source,string target){
   if(Move(source,target,1))return 0;
   return Marshal.GetLastWin32Error();
 }
}
'@
$fail='';$phaseIndex='PREPARE';$sourceCreated=$false;$allowed=$false;$errCode=-1;$restored=$false
$sourceLeft=$false
try{
 $code=[R357RealMoveEx]::CreateSym($source,$canary)
 if($code -ne 0){throw ('R357_CREATE_SYMLINK_WIN32_'+$code)}
 $sourceCreated=$true
 if(([IO.File]::GetAttributes($source) -band [IO.FileAttributes]::ReparsePoint) -eq 0){
  throw 'R357_ACTOR_SYMLINK_NOT_REAL_REPARSE'
 }
 $phaseIndex='ATTEMPT_REAL_NATIVE_REPLACE'
 $errCode=[R357RealMoveEx]::Replace($source,$destination)
 $allowed=($errCode -eq 0)
 if($Phase -ceq 'During'){
  if($allowed -or $errCode -ne 32 -or
    ![IO.File]::Exists($source) -or
    ([IO.File]::GetAttributes($source) -band [IO.FileAttributes]::ReparsePoint) -eq 0){
     throw ('R357_PROTECTED_LEAF_SWAP_NOT_DENIED_BY_SHARING_'+$errCode)
  }
  $sourceLeft=$true
 }else{
  if(!$allowed -or $errCode -ne 0){throw ('R357_UNPINNED_SWAP_NOT_ALLOWED_'+$errCode)}
  if(![IO.File]::Exists($destination) -or
    ([IO.File]::GetAttributes($destination) -band [IO.FileAttributes]::ReparsePoint) -eq 0){
    throw 'R357_ACTUAL_SYMLINK_REPLACEMENT_NOT_OBSERVED'
  }
  # Only the named link is deleted: its outside target must not be followed.
  [IO.File]::Delete($destination)
  if([IO.File]::Exists($destination)){throw 'R357_SYMLINK_DEST_NOT_UNLINKED'}
  $trusted=if($Phase -ceq 'Before'){'R357_CONTROL_CONTENT'}else{[string]$a.TrustedSupervisorBytes}
  [IO.File]::WriteAllText($destination,$trusted,[Text.UTF8Encoding]::new($false))
  if([IO.File]::ReadAllText($destination) -cne $trusted -or
     ([IO.File]::GetAttributes($destination) -band [IO.FileAttributes]::ReparsePoint) -ne 0){
    throw 'R357_UNPINNED_TRUSTED_BYTES_NOT_RESTORED'
  }
  $restored=$true
 }
 if((Get-FileHash $canary -Algorithm SHA256).Hash -cne $a.CanarySHA256){
  throw 'R357_ACTOR_EXTERNAL_CANARY_TOUCHED'
 }
}catch{
 $fail=$_.Exception.GetType().Name+': '+$_.Exception.Message+' PHASE='+$phaseIndex
}
$status=if(!$fail -and (($Phase -ceq 'During' -and !$allowed -and $errCode -eq 32 -and $sourceLeft) -or
 ($Phase -cne 'During' -and $allowed -and $restored))){
 'PASS_EXACT_NATIVE_REPARSE_MOVEEX_'+$Phase.ToUpperInvariant()
}else{'FAIL_R357_ACTOR_NOT_WITNESSED'}
$record=[ordered]@{
 Schema=1;Revision='R357';Status=$status;Host=[string]$a.Host
 SourceCommit=$env:GITHUB_SHA;Guest=$env:COMPUTERNAME
 ActorPid=$PID;ParentPid=[int]$a.ParentPid;Phase=$Phase
 AlreadyAdmin=$true;RealSymlinkCreated=$sourceCreated
 NativeWin32MoveExResult=$errCode;NativeMoveAllowed=$allowed
 SymlinkSourceIntactWhenDenied=$sourceLeft
 TrustedVictimRestoredAfterAllowed=$restored
 ExternalCanaryUnchanged=((Get-FileHash $canary -Algorithm SHA256).Hash -ceq $a.CanarySHA256)
 OwnerComputerTouched=$false;Failure=$fail
}
[IO.File]::WriteAllText($ReceiptPath,($record|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
Write-Output ('R357_NATIVE_ACTOR='+$Phase+' STATUS='+$status+' WIN32='+$errCode)
if($fail){throw ('R357_NATIVE_ACTOR_FAILURE '+$fail)}
