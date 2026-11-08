[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][ValidateSet('A','B')][string]$HostLabel,
 [Parameter(Mandatory=$true)][string]$SourceRoot
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -cne 'Desktop' -or
 $env:GITHUB_ACTIONS -cne 'true' -or
 $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
 $env:RUNNER_OS -cne 'Windows' -or
 $env:GITHUB_REPOSITORY -cne 'GOD13emad/TaskbarMonitorEnhanced' -or
 $env:GITHUB_REF -cne 'refs/heads/security/r347-r349-helper-hardening-v1710' -or
 $env:COMPUTERNAME -match '(?i)EMAD-PC|ALIEMAD|SAEID|LAPTOP' -or
 $env:GITHUB_RUN_ID -cnotmatch '^[0-9]{5,20}$' -or
 $env:GITHUB_SHA -cnotmatch '^[0-9a-f]{40}$' -or
 (git -C $SourceRoot rev-parse HEAD).Trim() -cne $env:GITHUB_SHA){
 throw 'R350_REFUSE_NONDISPOSABLE_OR_WRONG_GIT_SOURCE'
}
$admin=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if(!$admin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
 throw 'R350_GUEST_ALREADY_ADMIN_REQUIRED_NO_ELEVATION'
}
Import-Module ScheduledTasks -ErrorAction Stop
$programFiles=[Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles)
$product=Join-Path $programFiles 'TaskbarMonitorEnhanced'
$broker=Join-Path $product 'SensorBroker'
$root=Join-Path $env:RUNNER_TEMP ('R350_'+$HostLabel+'_'+$env:GITHUB_RUN_ID)
$receipt=Join-Path $root 'R350_PRIVILEGED_TREE_DELETE_NATIVE.json'
$canaryDir=Join-Path $root 'outside'
$canary=Join-Path $canaryDir 'OUTSIDE_CANARY.txt'
$source=Join-Path $SourceRoot 'installer\TBME_Setup_Elevated_Helper.ps1'
$setup=Join-Path $SourceRoot 'build\_out\Setup\TaskbarMonitorEnhanced_Setup_1.7.10.exe'
$native=Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe'
$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$otherSid='S-1-5-21-1111111111-2222222222-3333333333-4444'
$checks=[Collections.Generic.List[string]]::new()
$failure=''
$createdProduct=$false
$brokerFixtureCreated=$false
$cleanupOk=$false
$expectedJunction=$null
$beforeCanary='';$afterCanary=''
$removedEntries=0;$validRemovedEntries=0;$markerlessRemovedEntries=0
function Check([string]$name){$script:checks.Add($name);Write-Output ('PASS '+$name)}
function Hash([string]$file){(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash}
function Cause([Exception]$error){
 while($error.InnerException -and
  ($error -is [Management.Automation.MethodInvocationException] -or
   $error -is [Reflection.TargetInvocationException])){$error=$error.InnerException}
 return $error
}
function New-TreeFixture([object]$markerSid){
 if([IO.Directory]::Exists($broker)){throw 'R350_FIXTURE_BROKER_ALREADY_EXISTS'}
 [void][IO.Directory]::CreateDirectory($broker);$script:brokerFixtureCreated=$true
 if($null -ne $markerSid){
  [IO.File]::WriteAllText((Join-Path $broker '.tbme-owner.sid'),$markerSid,[Text.Encoding]::ASCII)
 }
 [void][IO.Directory]::CreateDirectory((Join-Path $broker 'nested\deep'))
 [IO.File]::WriteAllText((Join-Path $broker 'TaskbarMonitorSensorBroker.exe'),'R350_BROKER_FIXTURE')
 [IO.File]::WriteAllText((Join-Path $broker 'nested\deep\probe.bin'),'R350_NESTED_FIXTURE')
}
function Invoke-TreeDelete([string]$expectedSid,[bool]$allowMissing){
 $lease=[TBMEProtectedBrokerTreeLease]::new($broker)
 try{
  if(!$lease.IsPinned){throw 'R350_NATIVE_TREE_LEASE_NOT_PINNED'}
  $removed=$lease.DeleteOwnedTree($expectedSid,$allowMissing)
  if(-not [IO.Directory]::Exists($broker)){$script:brokerFixtureCreated=$false}
  return $removed
 }finally{$lease.Dispose()}
}
function ExpectFailure([scriptblock]$Action,[string]$ExpectedMessage,[string]$Name){
 $failed=$false;$message=''
 try{& $Action|Out-Null}catch{$failed=$true;$message=(Cause $_.Exception).Message}
 if(!$failed -or $message -cne $ExpectedMessage){
  throw ($Name+'_EXPECTED_'+$ExpectedMessage+'_GOT_'+$message)
 }
 Check $Name
}
function Remove-OwnedBrokerFixture {
 if(-not $script:brokerFixtureCreated){
  if([IO.Directory]::Exists($broker)){
   $attrs=[IO.File]::GetAttributes($broker)
   if($expectedJunction -ceq $broker -and ($attrs -band [IO.FileAttributes]::ReparsePoint) -ne 0 -and ($attrs -band [IO.FileAttributes]::Directory) -ne 0){
    [IO.Directory]::Delete($broker,$false);$script:expectedJunction=$null
    return
   }
   throw 'R350_CLEANUP_REFUSES_UNOWNED_BROKER_ROOT'
  }
  return
 }
 if(-not [IO.Directory]::Exists($broker)){$script:brokerFixtureCreated=$false;return}
 $stack=[Collections.Generic.Stack[string]]::new()
 $post=[Collections.Generic.List[string]]::new()
 $stack.Push($broker)
 while($stack.Count){
  $dir=$stack.Pop();$post.Add($dir)
  foreach($entry in [IO.Directory]::GetFileSystemEntries($dir)){
   $attrs=[IO.File]::GetAttributes($entry)
   if(($attrs -band [IO.FileAttributes]::ReparsePoint) -ne 0){
    if($entry -ceq $expectedJunction -and ($attrs -band [IO.FileAttributes]::Directory)){
     [IO.Directory]::Delete($entry,$false)
     continue
    }
    throw 'R350_CLEANUP_UNEXPECTED_REPARSE_MEMBER'
   }
   if(($attrs -band [IO.FileAttributes]::Directory) -ne 0){$stack.Push($entry)}
   else{[IO.File]::Delete($entry)}
  }
 }
 for($i=$post.Count-1;$i -ge 0;$i--){
  if([IO.Directory]::Exists($post[$i])){[IO.Directory]::Delete($post[$i],$false)}
 }
 $script:brokerFixtureCreated=$false
}
try{
 if([IO.Directory]::Exists($product) -or [IO.Directory]::Exists($root) -or
    @(Get-Process TaskbarMonitorEnhanced,TaskbarMonitorSensorBroker,TaskbarMonitorSensorSupervisor -ErrorAction SilentlyContinue).Count -or
    @(Get-ScheduledTask -TaskPath '\' -TaskName 'TaskbarMonitorEnhanced Sensor Broker' -ErrorAction SilentlyContinue | Where-Object {$null -ne $_}).Count){
  throw 'R350_PREEXISTING_PRODUCT_OR_FIXTURE_COLLISION'
 }
 foreach($f in @($source,$setup,$native)){if(-not [IO.File]::Exists($f)){throw 'R350_SOURCE_PREREQUISITE_MISSING'}}
 $asm=[Reflection.Assembly]::LoadFrom((Resolve-Path $setup).Path)
 $stream=$asm.GetManifestResourceStream('Payload.TBME_Setup_Elevated_Helper.ps1')
 if(!$stream){throw 'R350_REAL_SETUP_EMBEDDED_HELPER_MISSING'}
 $reader=[IO.StreamReader]::new($stream,[Text.Encoding]::UTF8)
 try{$embedded=$reader.ReadToEnd()}finally{$reader.Dispose()}
 $normalize={param($x) $x.Replace(([string][char]13+[string][char]10),[string][char]10).TrimStart([char]0xFEFF).TrimEnd()}
 $helperSource=[IO.File]::ReadAllText($source)
 if((& $normalize $embedded) -cne (& $normalize $helperSource)){
  throw 'R350_REAL_PE_EMBEDDED_HELPER_AND_SOURCE_DIFFER'
 }
  $deleteCallCount=([regex]::Matches($helperSource,'\$treeLease\.DeleteOwnedTree\(')).Count
 if($helperSource.Contains('Remove-Item -LiteralPath $BrokerRoot -Recurse') -or $deleteCallCount -ne 2 -or
    -not $helperSource.Contains('$treeLease.DeleteOwnedTree($validatedSensorSid,$false)') -or
    -not $helperSource.Contains('$treeLease.DeleteOwnedTree($expectedUserSid,[bool]$trustedPartialUninstall)')){
  throw 'R350_PRODUCTION_DELETE_CALLERS_NOT_HANDLE_BOUND'
 }
  $trueCount=([regex]::Matches($helperSource,'(?m)^\s*\$trustedPartialUninstall\s*=\s*\$true\s*$')).Count
 $proofStart=$helperSource.IndexOf('$trustedPartialUninstall=$false',[StringComparison]::Ordinal)
 $proofEnd=$helperSource.IndexOf('if(-not $trustedPartialUninstall)', $proofStart,[StringComparison]::Ordinal)
 if($trueCount -ne 1 -or $proofStart -lt 0 -or $proofEnd -le $proofStart){throw 'R350_MARKERLESS_CALLER_PROOF_BOUNDARY_MISSING'}
 $proof=$helperSource.Substring($proofStart,$proofEnd-$proofStart)
 foreach($required in @('Assert-SensorDurableJournal','Get-SensorJournalTerminal','PREPARED','Assert-SensorJournalTrustedAcl','$expectedUserSid','pending.OldRootPresent','newList.Count -eq 0','ownerRecords.Count -eq 1','Assert-SensorJournalTrustedAcl $savedMarker $false','[IO.File]::ReadAllText($savedMarker,[Text.Encoding]::ASCII).Trim()')){
  if(-not $proof.Contains($required)){throw ('R350_MARKERLESS_CALLER_PROOF_MISSING_'+$required)}
 }
 Check 'PRODUCTION_UNINSTALL_AND_ROLLBACK_CALLERS_HANDLE_BOUND_AND_MARKERLESS_JOURNAL_GATED'
  $classAt=$embedded.IndexOf('public sealed class TBMEProtectedBrokerTreeLease',[StringComparison]::Ordinal)
  $header=$embedded.LastIndexOf("Add-Type -TypeDefinition @'",$classAt,[StringComparison]::Ordinal)
  $first=$embedded.IndexOf([string][char]10,$header,[StringComparison]::Ordinal)
  $last=$embedded.IndexOf(([string][char]10+ "'@"),$classAt,[StringComparison]::Ordinal)
  if($classAt -lt 0 -or $header -lt 0 -or $first -lt 0 -or $last -le $classAt -or $last-$first -gt 24000){
   throw 'R350_EXACT_REAL_CSHARP_EXTRACTION_REFUSED'
  }
  Add-Type -TypeDefinition $embedded.Substring($first+1,$last-$first-1) -ErrorAction Stop
  if($null -eq ('TBMEProtectedBrokerTreeLease' -as [type])){throw 'R350_REAL_TREE_DELETE_CLASS_NOT_COMPILED'}
  $moveProbeSource=@(
   'using System;',
   'using System.Runtime.InteropServices;',
   'public static class TBMER350NativeMoveProbe {',
   ' [DllImport("kernel32.dll",EntryPoint="MoveFileExW",CharSet=CharSet.Unicode,SetLastError=true)]',
   ' static extern bool MoveFileEx(string source,string target,uint flags);',
   ' public static int TryMove(string source,string target){return MoveFileEx(source,target,0)?0:Marshal.GetLastWin32Error();}',
   '}') -join [string][char]10
  Add-Type -TypeDefinition $moveProbeSource -ErrorAction Stop
  Check 'EXACT_ORIGINAL_SETUP_PE_EMBEDS_COMPILED_NATIVE_TREE_DELETE_CLASS'
  $treeType='TBMEProtectedBrokerTreeLease' -as [type]
  $dispositionType=$treeType.GetNestedType('FILE_DISPOSITION_INFO',[Reflection.BindingFlags]'NonPublic,Public')
  $dispositionField=$dispositionType.GetField('DeleteFile',[Reflection.BindingFlags]'Public,Instance')
  if($null -eq $dispositionField -or $dispositionField.FieldType -ne [byte] -or -not $dispositionType.IsLayoutSequential -or
     -not $helperSource.Contains('struct FILE_DISPOSITION_INFO { public byte DeleteFile; }') -or
     -not $helperSource.Contains('d.DeleteFile=1;')){
   throw 'R350_FILE_DISPOSITION_NATIVE_BOOLEAN_LAYOUT_REFUSED'
  }
  Check 'FILE_DISPOSITION_INFO_ONE_BYTE_NATIVE_BOOLEAN'
  $drive=[IO.DriveInfo]::new([IO.Path]::GetPathRoot($programFiles))
  if($drive.DriveType -ne [IO.DriveType]::Fixed -or $drive.DriveFormat -cne 'NTFS' -or
     -not $helperSource.Contains('GetDriveType(root)!=3') -or
     -not $helperSource.Contains('String.Equals(fs.ToString(),"NTFS",StringComparison.OrdinalIgnoreCase)') -or
     -not $helperSource.Contains('baseAddress.ToInt64()&7') -or
     -not $helperSource.Contains('(next&7)!=0')){
   throw 'R350_NTFS_FILE_ID_SCOPE_NOT_ENFORCED'
  }
  Check 'LOCAL_FIXED_NTFS_AND_DIRECTORY_INFO_LAYOUT_GUARDS'
 [void][IO.Directory]::CreateDirectory($root)
 [void][IO.Directory]::CreateDirectory($canaryDir)
 [IO.File]::WriteAllText($canary,'R350_OUTSIDE_CANARY',[Text.UTF8Encoding]::new($false))
 $beforeCanary=Hash $canary
 [void][IO.Directory]::CreateDirectory($product);$createdProduct=$true
 [IO.File]::WriteAllText((Join-Path $product 'keep.txt'),'R350_PRODUCT_SIBLING')
 Check 'FRESH_ADMIN_PROGRAMFILES_FIXTURE_AND_OUTSIDE_CANARY_CREATED'
 # Valid owner tree: root marker, two files, two nested directories.
 New-TreeFixture $sid
 $removedEntries=Invoke-TreeDelete $sid $false
  $validRemovedEntries=$removedEntries
 if([IO.Directory]::Exists($broker)){throw 'R350_VALID_BROKER_ROOT_REMAINS'}
 if([IO.File]::ReadAllText((Join-Path $product 'keep.txt')) -cne 'R350_PRODUCT_SIBLING' -or (Hash $canary) -cne $beforeCanary){
  throw 'R350_VALID_DELETE_ESCAPED_OWNED_BROKER_ROOT'
 }
 if($validRemovedEntries -ne 5){throw ('R350_VALID_ENTRY_COUNT_'+$validRemovedEntries)}
 Check 'VALID_NESTED_TREE_DELETED_BY_FILE_ID_HANDLES_ONLY'
  New-TreeFixture $sid
  $lease=[TBMEProtectedBrokerTreeLease]::new($broker)
  try{
   if(!$lease.IsPinned){throw 'R350_RENAME_LEASE_NOT_PINNED'}
   $rootMove=[TBMER350NativeMoveProbe]::TryMove($broker,$broker+'.rename-probe')
   $productMove=[TBMER350NativeMoveProbe]::TryMove($product,$product+'.rename-probe')
   if($rootMove -ne 32 -or $productMove -ne 32 -or -not [IO.Directory]::Exists($broker) -or -not [IO.Directory]::Exists($product)){
    throw ('R350_RENAME_PIN_FAILED_ROOT_'+$rootMove+'_PRODUCT_'+$productMove)
   }
   Check 'BROKER_ROOT_RENAME_BLOCKED_WIN32_32'
   Check 'PRODUCT_PARENT_RENAME_BLOCKED_WIN32_32'
  }finally{$lease.Dispose()}
  Remove-OwnedBrokerFixture
 # A different SID marker must fail before any deletion.
 New-TreeFixture $otherSid
  $lease=[TBMEProtectedBrokerTreeLease]::new($broker)
  try{
   ExpectFailure {$lease.DeleteOwnedTree($sid,$false)} 'SENSOR_BROKER_TREE_OWNER_MARKER_SID_MISMATCH' 'OWNER_SID_MISMATCH_FAIL_CLOSED'
   ExpectFailure {$lease.DeleteOwnedTree($sid,$false)} 'SENSOR_BROKER_TREE_DELETE_ATTEMPT_ALREADY_USED' 'FAILED_LEASE_SINGLE_USE'
  }finally{$lease.Dispose()}
 if(-not [IO.File]::Exists((Join-Path $broker 'TaskbarMonitorSensorBroker.exe'))){throw 'R350_WRONG_OWNER_PARTIAL_DELETE'}
 Remove-OwnedBrokerFixture
 # Missing marker is refused unless the caller has already validated the
 # exact same-owner PREPARED markerless-uninstall journal.
 New-TreeFixture $null
 ExpectFailure {Invoke-TreeDelete $sid $false} 'SENSOR_BROKER_TREE_OWNER_MARKER_MISSING' 'MISSING_MARKER_FAIL_CLOSED'
 if(-not [IO.File]::Exists((Join-Path $broker 'TaskbarMonitorSensorBroker.exe'))){throw 'R350_MISSING_MARKER_PARTIAL_DELETE'}
 Remove-OwnedBrokerFixture
 New-TreeFixture $null
 $removedEntries=Invoke-TreeDelete $sid $true
  $markerlessRemovedEntries=$removedEntries
 if([IO.Directory]::Exists($broker) -or $markerlessRemovedEntries -ne 4){throw 'R350_MARKERLESS_AUTHORIZED_BRANCH_FAILED'}
 Check 'JOURNAL_AUTHORIZED_MARKERLESS_API_BRANCH'
 # A reparse member is detected during a full preflight, before any file is
 # marked for deletion. The external canary and all ordinary members survive.
 New-TreeFixture $sid
 $junction=Join-Path $broker 'external'
  $expectedJunction=$junction
 & cmd.exe /c ('mklink /J "'+$junction+'" "'+$canaryDir+'"') | Out-Null
 if($LASTEXITCODE -ne 0 -or -not [IO.Directory]::Exists($junction)){throw 'R350_TEST_JUNCTION_CREATE_FAILED'}

 ExpectFailure {Invoke-TreeDelete $sid $false} 'SENSOR_BROKER_TREE_REPARSE_REFUSED_external' 'JUNCTION_REFUSED_BEFORE_ANY_DELETE'
 if(-not [IO.File]::Exists((Join-Path $broker 'TaskbarMonitorSensorBroker.exe')) -or (Hash $canary) -cne $beforeCanary){
  throw 'R350_REPARSE_PARTIAL_OR_EXTERNAL_DELETE'
 }
 Check 'JUNCTION_AND_OUTSIDE_CANARY_UNCHANGED'
 Remove-OwnedBrokerFixture;$expectedJunction=$null
  New-TreeFixture $sid
  Remove-OwnedBrokerFixture
  $expectedJunction=$broker
  & cmd.exe /c ('mklink /J "'+$broker+'" "'+$canaryDir+'"') | Out-Null
  if($LASTEXITCODE -ne 0 -or -not [IO.Directory]::Exists($broker)){throw 'R350_BROKER_ROOT_JUNCTION_CREATE_FAILED'}
  ExpectFailure {[TBMEProtectedBrokerTreeLease]::new($broker)} 'SENSOR_BROKER_TREE_DIRECTORY_REPARSE_OR_TYPE_REFUSED' 'BROKER_ROOT_JUNCTION_REFUSED'
  if((Hash $canary) -cne $beforeCanary){throw 'R350_BROKER_ROOT_JUNCTION_CANARY_CHANGED'}
  Remove-OwnedBrokerFixture
  Check 'BROKER_ROOT_JUNCTION_REFUSED_WITHOUT_CANARY_ACCESS'
 # A hardlink to an outside file is refused before any deletion.
 New-TreeFixture $sid
 $hardlink=Join-Path $broker 'outside-link.txt'
 & cmd.exe /c ('mklink /H "'+$hardlink+'" "'+$canary+'"') | Out-Null
 if($LASTEXITCODE -ne 0 -or -not [IO.File]::Exists($hardlink)){throw 'R350_TEST_HARDLINK_CREATE_FAILED'}
 ExpectFailure {Invoke-TreeDelete $sid $false} 'SENSOR_BROKER_TREE_HARDLINK_REFUSED' 'HARDLINK_REFUSED_BEFORE_ANY_DELETE'
 if((Hash $canary) -cne $beforeCanary -or -not [IO.File]::Exists($hardlink) -or
    -not [IO.File]::Exists((Join-Path $broker 'TaskbarMonitorSensorBroker.exe'))){
  throw 'R350_HARDLINK_EXTERNAL_CANARY_CHANGED'
 }
 Check 'HARDLINK_AND_OUTSIDE_CANARY_UNCHANGED'
 Remove-OwnedBrokerFixture
 # Depth cap is fail-closed and two-phase: no ordinary member is deleted.
 New-TreeFixture $sid
 $deep=$broker
 for($i=0;$i -lt 10;$i++){$deep=Join-Path $deep ('d'+$i);[void][IO.Directory]::CreateDirectory($deep)}
 [IO.File]::WriteAllText((Join-Path $deep 'deep.bin'),'R350_DEEP_FIXTURE')
 ExpectFailure {Invoke-TreeDelete $sid $false} 'SENSOR_BROKER_TREE_DEPTH_LIMIT' 'DEPTH_LIMIT_FAIL_CLOSED'
 if(-not [IO.File]::Exists((Join-Path $broker 'TaskbarMonitorSensorBroker.exe'))){throw 'R350_DEPTH_PARTIAL_DELETE'}
 Check 'DEPTH_LIMIT_REJECTS_WITHOUT_PARTIAL_DELETE'
 Remove-OwnedBrokerFixture
 # The constructor rejects any path other than the exact ProgramFiles root.
 New-TreeFixture $sid
 ExpectFailure {[TBMEProtectedBrokerTreeLease]::new($broker+'_other')} 'SENSOR_BROKER_TREE_NOT_EXACT_SYSTEM_PROGRAMFILES' 'EXACT_ROOT_PATH_REQUIRED'
 Remove-OwnedBrokerFixture
 # A junction at the product parent itself is rejected before opening the
 # Broker tree. The owner-created target remains unchanged.
 $parentTarget=Join-Path $root 'parent-target'
 [void][IO.Directory]::CreateDirectory($parentTarget)
 [IO.File]::WriteAllText((Join-Path $parentTarget 'outside.txt'),'parent-canary')
 [IO.File]::Delete((Join-Path $product 'keep.txt'))
 [IO.Directory]::Delete($product,$false)
  $expectedJunction=$product
 & cmd.exe /c ('mklink /J "'+$product+'" "'+$parentTarget+'"') | Out-Null
 if($LASTEXITCODE -ne 0 -or -not [IO.Directory]::Exists($product)){throw 'R350_PRODUCT_PARENT_JUNCTION_CREATE_FAILED'}

 ExpectFailure {[TBMEProtectedBrokerTreeLease]::new($broker)} 'SENSOR_BROKER_TREE_DIRECTORY_REPARSE_OR_TYPE_REFUSED' 'PRODUCT_PARENT_JUNCTION_REFUSED'
 if([IO.File]::ReadAllText((Join-Path $parentTarget 'outside.txt')) -cne 'parent-canary'){throw 'R350_PARENT_JUNCTION_TARGET_CHANGED'}
 [IO.Directory]::Delete($product,$false);$expectedJunction=$null
 [void][IO.Directory]::CreateDirectory($product)
 [IO.File]::WriteAllText((Join-Path $product 'keep.txt'),'R350_PRODUCT_SIBLING')
 Check 'PRODUCT_PARENT_JUNCTION_REFUSED_WITHOUT_TARGET_ACCESS'
 if((Hash $canary) -cne $beforeCanary){throw 'R350_OUTSIDE_CANARY_FINAL_MISMATCH'}
 $afterCanary=Hash $canary
 Check 'OUTSIDE_CANARY_FINAL_HASH_UNCHANGED'
}catch{
 $failure=$_.Exception.ToString()
}finally{
 try{
  if($createdProduct){
   if([IO.Directory]::Exists($broker)){Remove-OwnedBrokerFixture}
   if([IO.Directory]::Exists($product) -and
      (([IO.File]::GetAttributes($product) -band [IO.FileAttributes]::ReparsePoint) -ne 0)){
    if($expectedJunction -cne $product){throw 'R350_PRODUCT_CLEANUP_UNEXPECTED_REPARSE'}
    [IO.Directory]::Delete($product,$false);$expectedJunction=$null
    [void][IO.Directory]::CreateDirectory($product)
    [IO.File]::WriteAllText((Join-Path $product 'keep.txt'),'R350_PRODUCT_SIBLING')
   }
   if([IO.Directory]::Exists($product)){
    $entries=@([IO.Directory]::GetFileSystemEntries($product))
    if($entries.Count -ne 1 -or $entries[0] -cne (Join-Path $product 'keep.txt')){
     throw 'R350_PRODUCT_CLEANUP_UNEXPECTED_MEMBER'
    }
    [IO.File]::Delete((Join-Path $product 'keep.txt'))
    [IO.Directory]::Delete($product,$false)
   }
   $cleanupOk=-not [IO.Directory]::Exists($product)
  }
 }catch{$failure+=' R350_CLEANUP_REFUSED '+$_.Exception.ToString()}
 if([IO.Directory]::Exists($root)){
  [IO.File]::WriteAllText($receipt,([ordered]@{
   Schema=1;Revision='R350';Status=$(if(!$failure -and $checks.Count -eq 24 -and $cleanupOk -and $validRemovedEntries -eq 5 -and $markerlessRemovedEntries -eq 4){'PASS_R350_PRIVILEGED_HANDLE_BOUND_TREE_DELETE'}else{'FAIL_R350_PRIVILEGED_HANDLE_BOUND_TREE_DELETE'})
   Host=$HostLabel;SourceCommit=$env:GITHUB_SHA;SetupSHA256=$(if([IO.File]::Exists($setup)){Hash $setup}else{''})
   ExactSetupEmbeddedHelper=$true;NativeClassCompiledByWindowsPowerShell51=$true
   RealProgramFilesDisposableFixture=$true;OwnerSidMarkerMatched=$true
   BrokerTreeHandlesNoWriteOrDeleteSharing=$true;ParentDirectoryHandlesNoDeleteSharing=$true;FileDispositionInfoByteSized=$true;DirectoryInfoBuffer8ByteAligned=$true
   FileIdVolumeFinalPathAndSingleHardlinkChecked=$true;ReparseAndHardlinkNegativeCasesTested=$true
   MarkerlessApiBranchTested=$true;ProductionMarkerlessCallerStaticProof=$true;FileSystemName='NTFS';LocalFixedVolumeOnly=$true
   OriginalFullHelperExecuted=$false;RealUninstallEntrypointExecuted=$false
   ActualUserInstallationChanged=$false;SecurityEntireProductAccepted=$false
   ValidRemovedEntries=$validRemovedEntries;MarkerlessRemovedEntries=$markerlessRemovedEntries;RemovedEntries=$removedEntries;Checks=@($checks);OutsideCanarySHA256Before=$beforeCanary
   OutsideCanarySHA256After=$afterCanary;CleanupOwnedProgramFilesFixture=$cleanupOk;Failure=$failure
  }|ConvertTo-Json -Depth 7),[Text.UTF8Encoding]::new($false))
  Write-Output ('R350_NATIVE_RECEIPT='+$receipt)
 }
 $status=if(!$failure -and $checks.Count -eq 24 -and $cleanupOk -and $validRemovedEntries -eq 5 -and $markerlessRemovedEntries -eq 4){'PASS_R350_PRIVILEGED_HANDLE_BOUND_TREE_DELETE'}else{'FAIL_R350_PRIVILEGED_HANDLE_BOUND_TREE_DELETE'}
 Write-Output ('R350_NATIVE_STATUS='+$status+' CHECKS='+$checks.Count)
}
if($failure){throw ('R350_NATIVE_TREE_DELETE_NOT_ACCEPTED '+$failure)}
