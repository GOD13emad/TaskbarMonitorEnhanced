[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][ValidateSet('A','B')][string]$HostLabel,
 [Parameter(Mandatory=$true)][string]$SourceRoot
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# This is a disposable hosted native LEASE class test, not a full Helper replay.
if($PSVersionTable.PSEdition -cne 'Desktop' -or
   $env:GITHUB_ACTIONS -cne 'true' -or
   $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
   $env:RUNNER_OS -cne 'Windows' -or
   $env:GITHUB_REPOSITORY -cne 'GOD13emad/TaskbarMonitorEnhanced' -or
   $env:GITHUB_REF -cne 'refs/heads/audit/r357-native-protected-leaf-reparse-swap' -or
   $env:COMPUTERNAME -match '(?i)EMAD-PC|ALIEMAD|SAEID|LAPTOP' -or
   $env:GITHUB_RUN_ID -cnotmatch '^[0-9]{5,20}$' -or
   $env:GITHUB_SHA -cnotmatch '^[0-9a-f]{40}$' -or
   (git -C $SourceRoot rev-parse HEAD).Trim() -cne $env:GITHUB_SHA){
 throw 'R357_NON_DISPOSABLE_RUNNER_OR_SHA_REFUSED'
}
$admin=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if(!$admin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
 throw 'R357_ALREADY_ADMIN_HOSTED_WINDOWS_REQUIRED'
}
$pf=[Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles)
$protected=Join-Path $pf 'TaskbarMonitorEnhanced'
$broker=Join-Path $protected 'SensorBroker'
$supervisor=Join-Path $broker 'TaskbarMonitorSensorSupervisor.exe'
$control=Join-Path $broker 'R357_CONTROL_VICTIM.txt'
$trusted='R357_TRUSTED_SUPERVISOR_'+$env:GITHUB_RUN_ID+'_'+$HostLabel
$root=Join-Path $env:RUNNER_TEMP ('R357_'+$HostLabel+'_'+$env:GITHUB_RUN_ID)
$canary=Join-Path $root 'R357_EXTERNAL_CANARY.txt'
$authPath=Join-Path $root 'R357_AUTHORITY.json'
$receipt=Join-Path $root 'R357_PROTECTED_SUPERVISOR_REPARSE_NATIVE.json'
$actorScript=Join-Path $SourceRoot 'build\Test-R357-ReparseMoveActor-Native.ps1'
$setup=Join-Path $SourceRoot 'build\_out\Setup\TaskbarMonitorEnhanced_Setup_1.7.8.exe'
$original=Join-Path $SourceRoot 'installer\TBME_Setup_Elevated_Helper.ps1'
$native=Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe'
$checks=[Collections.Generic.List[string]]::new()
$cleanup=$false;$sourceExact=$false;$lease=$null;$failure='';$phase='PRECHECK'
$created=$false;$sha='';$canarySha='';$pids=@();$observedDenied=$false;$observedError=-1
function Check([string]$label){[void]$script:checks.Add($label);Write-Output ('PASS '+$label)}
function Hash-R357([string]$path){return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash}
function Invoke-Swap([string]$mode){
 $file=Join-Path $root ('R357_ACTOR_'+$mode.ToUpperInvariant()+'.json')
 if([IO.File]::Exists($file)){throw 'R357_DUPLICATE_ACTOR_RECEIPT'}
 $psi=[Diagnostics.ProcessStartInfo]::new()
 $psi.FileName=$native
 $psi.Arguments='-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$actorScript+'" -AuthorityPath "'+$authPath+'" -ReceiptPath "'+$file+'" -Phase '+$mode
 $psi.UseShellExecute=$false;$psi.CreateNoWindow=$true
 $proc=[Diagnostics.Process]::Start($psi)
 if(!$proc){throw ('R357_ACTOR_NOT_STARTED_'+$mode)}
 try{
  $procId=$proc.Id
  if($procId -le 0 -or $procId -eq $PID){throw 'R357_ACTOR_NOT_DIFFERENT_NATIVE_PID'}
  if(!$proc.WaitForExit(27000)){
    if(!$proc.HasExited){$proc.Kill();[void]$proc.WaitForExit(5000)}
    throw ('R357_ACTOR_TIMEOUT_'+$mode)
  }
  if($proc.ExitCode -ne 0 -or ![IO.File]::Exists($file)){
    throw ('R357_ACTOR_NATIVE_PROCESS_FAILED_'+$mode+'_'+$proc.ExitCode)
  }
  $j=Get-Content -LiteralPath $file -Raw|ConvertFrom-Json
  if($j.Schema -ne 1 -or $j.Revision -cne 'R357' -or
     $j.Status -cne ('PASS_EXACT_NATIVE_REPARSE_MOVEEX_'+$mode.ToUpperInvariant()) -or
     $j.Host -cne $HostLabel -or $j.ParentPid -ne $PID -or
     $j.ActorPid -ne $procId -or $j.SourceCommit -cne $env:GITHUB_SHA -or
     $j.RealSymlinkCreated -ne $true -or $j.ExternalCanaryUnchanged -ne $true -or
     $j.OwnerComputerTouched -ne $false -or
     ![string]::IsNullOrEmpty([string]$j.Failure)){
    throw ('R357_ACTOR_TYPED_FIELDS_NOT_VERIFIED_'+$mode)
  }
  if($mode -ceq 'During'){
    if($j.NativeMoveAllowed -ne $false -or $j.NativeWin32MoveExResult -notin @(5,32) -or
       $j.SymlinkSourceIntactWhenDenied -ne $true){
      throw 'R357_NOT_GENUINE_SHARING_VIOLATION_32'
    }
  }elseif($j.NativeMoveAllowed -ne $true -or $j.NativeWin32MoveExResult -ne 0 -or
          $j.TrustedVictimRestoredAfterAllowed -ne $true){
    throw ('R357_PREPOST_CONTROL_MOVE_NOT_ALLOWED_'+$mode)
  }
  $script:pids+= $procId
  return $j
 }finally{$proc.Dispose()}
}
try{
 $phase='FRESH_DISPOSABLE_GUEST'
 if([IO.Directory]::Exists($protected) -or [IO.Directory]::Exists($root) -or
    @(Get-Process TaskbarMonitorEnhanced,TaskbarMonitorSensorBroker,TaskbarMonitorSensorSupervisor -ErrorAction SilentlyContinue).Count){
    throw 'R357_GUEST_PREEXISTING_PRODUCT_OR_FIXTURE'
 }
 foreach($f in @($setup,$original,$actorScript,$native)){
  if(![IO.File]::Exists($f)){throw ('R357_PRODUCT_TEST_SOURCE_MISSING_'+$f)}
 }
 $phase='EXACT_EMBEDDED_SOURCE_AND_NATIVE_CLASS'
 $assembly=[Reflection.Assembly]::LoadFrom((Resolve-Path $setup).Path)
 $res=$assembly.GetManifestResourceStream('Payload.TBME_Setup_Elevated_Helper.ps1')
 if(!$res){throw 'R357_ORIGINAL_SETUP_HELPER_RESOURCE_NOT_FOUND'}
 $reader=[IO.StreamReader]::new($res,[Text.Encoding]::UTF8)
 try{$embedded=$reader.ReadToEnd()}finally{$reader.Dispose()}
 $normalize={param([string]$value) $value.Replace(([string][char]13+[string][char]10),[string][char]10).TrimStart([char]0xFEFF).TrimEnd()}
 if((& $normalize $embedded) -cne (& $normalize ([IO.File]::ReadAllText($original)))){
  throw 'R357_PE_RESOURCE_NOT_EXACT_LOCAL_PRODUCTION_HELPER'
 }
 $at=$embedded.IndexOf('public sealed class TBMEProtectedBrokerLease',[StringComparison]::Ordinal)
 $header=$embedded.LastIndexOf("Add-Type -TypeDefinition @'",$at,[StringComparison]::Ordinal)
 $first=$embedded.IndexOf([string][char]10,$header,[StringComparison]::Ordinal)
 $last=$embedded.IndexOf(([string][char]10+"'@"),$at,[StringComparison]::Ordinal)
 if($at -lt 0 -or $header -lt 0 -or $first -lt 0 -or $last -le $at -or $last-$first -gt 22000){
  throw 'R357_NATIVE_ORIGINAL_CSHARP_EXTRACTION_NOT_BOUNDED'
 }
 Add-Type -TypeDefinition $embedded.Substring($first+1,$last-$first-1) -ErrorAction Stop
 if($null -eq ('TBMEProtectedBrokerLease' -as [type])){throw 'R357_ORIGINAL_NATIVE_CLASS_NOT_COMPILED'}
 $sourceExact=$true
 Check 'REAL_SETUP_PE_EMBEDS_IDENTICAL_NATIVE_PROTECTED_LEAF_LEASE_CLASS'
 $phase='PREPARE_ADMIN_OWNED_PRODUCT_PATH_AND_EXTERNAL_CANARY'
 [void][IO.Directory]::CreateDirectory($root)
 [IO.File]::WriteAllText($canary,'R357_CANARY_OUTSIDE_PROTECTED_BROKER',[Text.UTF8Encoding]::new($false))
 $canarySha=Hash-R357 $canary
 $admins=[Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
 $system=[Security.Principal.SecurityIdentifier]::new('S-1-5-18')
 $users=[Security.Principal.SecurityIdentifier]::new('S-1-5-32-545')
 $acl=[Security.AccessControl.DirectorySecurity]::new()
 $acl.SetOwner($admins);$acl.SetAccessRuleProtection($true,$false)
 foreach($sid in @($admins,$system,$users)){
  $rights=if($sid -eq $users){[Security.AccessControl.FileSystemRights]::ReadAndExecute}else{[Security.AccessControl.FileSystemRights]::FullControl}
  [void]$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
    $sid,$rights,[Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit',
    [Security.AccessControl.PropagationFlags]::None,[Security.AccessControl.AccessControlType]::Allow))
 }
 [void][IO.Directory]::CreateDirectory($protected,$acl)
 $created=$true
 [void][IO.Directory]::CreateDirectory($broker)
 [IO.File]::WriteAllText($supervisor,$trusted,[Text.UTF8Encoding]::new($false))
 [IO.File]::WriteAllText($control,'R357_CONTROL_CONTENT',[Text.UTF8Encoding]::new($false))
 $sha=Hash-R357 $supervisor
 if((Get-Acl $protected).Owner -notmatch '(?i)Administrators'){
  throw 'R357_PROTECTED_ROOT_NOT_OWNED_BY_ADMIN'
 }
 Check 'DISPOSABLE_ADMIN_OWNED_FIXED_SUPERVISOR_LEAF_AND_OUTSIDE_SHA_CREATED'
 [IO.File]::WriteAllText($authPath,([ordered]@{
  Schema=1;Revision='R357';SourceCommit=$env:GITHUB_SHA
  Guest=$env:COMPUTERNAME;Host=$HostLabel;ParentPid=$PID
  ProtectedLeaf=$supervisor;ControlLeaf=$control
  TrustedSupervisorBytes=$trusted
  ExternalCanary=$canary;CanarySHA256=$canarySha
 }|ConvertTo-Json -Depth 7),[Text.UTF8Encoding]::new($false))
 $phase='PREPIN_SWAP_CONTROL'
 $before=Invoke-Swap 'Before'
 if([IO.File]::ReadAllText($control) -cne 'R357_CONTROL_CONTENT'){
  throw 'R357_PREPIN_CONTROL_RESTORED_WRONG_SHA'
 }
 Check 'SEPARATE_ADMIN_SYMLINK_MOVEFILEEX_ALLOWED_BEFORE_LEAF_PIN'
 $phase='REAL_NATIVE_LEASE_PIN_EXACT_SUPERVISOR'
 $lease=[TBMEProtectedBrokerLease]::new($broker)
 $current=[Text.Encoding]::UTF8.GetString([byte[]]$lease.ReadReplayLeaf('TaskbarMonitorSensorSupervisor.exe'))
 if(!$lease.IsPinned -or $current -cne $trusted){throw 'R357_REAL_PRODUCTION_LEAF_NOT_EXACTLY_PINNED'}
 Check 'REAL_PRODUCTION_HELPER_CLASS_PINS_FIXED_SUPERVISOR_BYTES'
 $phase='CONCURRENT_SYMLINK_MOVEFILEEX_PROBE_DURING_LEASE'
 $during=Invoke-Swap 'During'
 $observedDenied=$true;$observedError=[int]$during.NativeWin32MoveExResult
 $bytes=[Text.Encoding]::UTF8.GetString([byte[]]$lease.ReadReplayLeaf('TaskbarMonitorSensorSupervisor.exe'))
 if($bytes -cne $trusted -or !$lease.IsPinned -or
    ([IO.File]::GetAttributes($supervisor) -band [IO.FileAttributes]::ReparsePoint) -ne 0){
  throw 'R357_PROTECTED_SUPERVISOR_CHANGED_DURING_SYMLINK_PROBE'
 }
 Check 'OTHER_ADMIN_REPARSE_REPLACEMENT_DENIED_WIN32_5_OR_32_WHILE_SUPERVISOR_PINNED'
 $phase='RELEASE_AND_REMOVE_DENIED_ATTACK_LINK'
 $lease.Dispose();$lease=$null
 $deniedSource=Join-Path $broker 'R357_During_prepared_symlink.txt'
 if(![IO.File]::Exists($deniedSource) -or
    ([IO.File]::GetAttributes($deniedSource) -band [IO.FileAttributes]::ReparsePoint) -eq 0){
  throw 'R357_DENIED_SOURCE_SYMLINK_NOT_PRESERVED'
 }
 [IO.File]::Delete($deniedSource)
 if([IO.File]::Exists($deniedSource) -or (Hash-R357 $canary) -cne $canarySha){
  throw 'R357_DENIED_SYMLINK_CLEANUP_CHANGED_EXTERNAL_TARGET'
 }
 Check 'DENIED_REPARSE_LINK_REMOVED_BY_NAME_WITH_OUTSIDE_CANARY_INTACT'
 $phase='POSTLEASE_POSITIVE_NATIVE_SWAP_THEN_TRUSTED_BYTES_RECOVERY'
 $after=Invoke-Swap 'After'
 if((Hash-R357 $supervisor) -cne $sha -or
    ([IO.File]::GetAttributes($supervisor) -band [IO.FileAttributes]::ReparsePoint) -ne 0){
  throw 'R357_SUPERVISOR_SHA_NOT_RESTORED_AFTER_UNPINNED_SYMLINK_TEST'
 }
 Check 'REPARSE_SWAP_ALLOWED_ONLY_AFTER_LEASE_RELEASE_AND_TRUSTED_BYTES_RESTORED'
 $phase='FINAL_IDENTITY_AND_EXTERNAL_CANARY'
 if(@($pids).Count -ne 3 -or @($pids|Sort-Object -Unique).Count -ne 3 -or
    $PID -in $pids -or
    (Hash-R357 $canary) -cne $canarySha -or
    [IO.File]::ReadAllText($control) -cne 'R357_CONTROL_CONTENT'){
  throw 'R357_DISTINCT_PIDS_OR_FILE_IDENTITY_NOT_VERIFIED'
 }
 Check 'THREE_DISTINCT_ALREADY_ADMIN_NATIVE_ACTOR_PIDS_AND_OUTSIDE_SHA'
}catch{
 $failure=$_.Exception.GetType().Name+': '+$_.Exception.Message+' PHASE='+$phase
}finally{
 if($null -ne $lease){try{$lease.Dispose()}catch{$failure+=' LEASE_DISPOSE_FAILED'}}
 if($created -and [IO.Directory]::Exists($protected)){
  try{
   if(([IO.File]::GetAttributes($protected) -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
      ![IO.Directory]::Exists($broker) -or
      ([IO.File]::GetAttributes($broker) -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
      @([IO.Directory]::GetFileSystemEntries($protected)).Count -ne 1 -or
      @([IO.Directory]::GetFileSystemEntries($broker)).Count -ne 2 -or
      (Hash-R357 $supervisor) -cne $sha -or
      [IO.File]::ReadAllText($control) -cne 'R357_CONTROL_CONTENT' -or
      (Hash-R357 $canary) -cne $canarySha){
     throw 'R357_PROTECTED_GUEST_FIXTURE_NOT_VERIFIED_FOR_CLEANUP'
   }
   [IO.File]::Delete($control)
   [IO.File]::Delete($supervisor)
   [IO.Directory]::Delete($broker,$false)
   [IO.Directory]::Delete($protected,$false)
   $cleanup=(![IO.Directory]::Exists($protected))
  }catch{$failure+=' R357_GUEST_CLEANUP_REFUSED_'+$_.Exception.Message}
 }
 if($cleanup){Check 'EXACT_GUEST_ONLY_PROTECTED_BROKER_FIXTURE_REMOVED'}
 $status=if(!$failure -and $sourceExact -and $observedDenied -and $observedError -in @(5,32) -and $cleanup -and
    $checks.Count -eq 9 -and @($pids).Count -eq 3){
  'PASS_R357_NATIVE_REAL_PE_SUPERVISOR_SYMLINK_MOVEEX_DENIED_WHILE_PINNED'
 }else{'FAIL_R357_NATIVE_REPARSE_SWAP_NOT_ACCEPTED'}
 if([IO.Directory]::Exists($root)){
  $raw=[ordered]@{
    Schema=1;Revision='R357';SourceCommit=$env:GITHUB_SHA;Host=$HostLabel
    Status=$status;RealOriginalSetupPEEmbeddedNativeClassExact=$sourceExact
    ExactProtectedSupervisorPath=$supervisor
    TrustedSupervisorSHA256=$sha;OutsideCanarySHA256=$canarySha
    ThreeIndependentAdministratorActorPids=@($pids)
    PrepinActualNativeMoveExAllowed=(@($pids).Count -ge 1)
    DuringPinNativeWin32Error=$observedError
    DuringPinRealNativeRenameOrReplacementDenied=$observedDenied
    PostReleaseNativeReparseSubstitutionAndTrustedRestore=(@($pids).Count -eq 3)
    ProtectedSupervisorBytesIntactAfterDeniedAttack=$observedDenied
    NativeOriginalHelperFullReplayExecuted=$false
    RealNativeInteractiveUacConsentWitnessed=$false
    AllNTFSRaceAttacksEliminated=$false
    ExternalCanaryUnchanged=$(if([IO.File]::Exists($canary)){(Hash-R357 $canary) -ceq $canarySha}else{$false})
    OwnerMachineTouched=$false
    GuestOwnedProtectedFixtureCleaned=$cleanup
    Checks=@($checks);Failure=$failure
  }
  [IO.File]::WriteAllText($receipt,($raw|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
  Write-Output ('R357_NATIVE_STATUS='+$status+' CHECKS='+$checks.Count+' ERROR='+$failure)
 }
}
if($failure){throw ('R357_NATIVE_PROTECTED_SUPERVISOR_ATTACK_FAIL '+$failure)}
