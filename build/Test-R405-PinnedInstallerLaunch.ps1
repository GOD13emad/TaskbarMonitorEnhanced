[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$AppPath,
 [Parameter(Mandatory=$true)][string]$SourceRoot,
 [switch]$HostedGuest
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($PSVersionTable.PSEdition -cne 'Desktop'){throw 'R405_REQUIRES_NET48_WINDOWS_POWERSHELL51'}
if($HostedGuest -and ($env:GITHUB_ACTIONS -cne 'true' -or
    $env:RUNNER_OS -cne 'Windows' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted')){
 throw 'R405_REQUIRES_DISPOSABLE_GITHUB_HOST'
}
$root=(Resolve-Path -LiteralPath $SourceRoot).Path
$app=(Resolve-Path -LiteralPath $AppPath).Path
if(![string]::Equals($app,(Join-Path $root 'build\_out\App\TaskbarMonitorEnhanced.exe'),
   [StringComparison]::OrdinalIgnoreCase)){throw 'R405_EXPECTS_EXACT_LOCAL_MAIN_BUILD'}
$source=[IO.File]::ReadAllText((Join-Path $root 'src\TaskbarMonitorEnhanced.cs'))
foreach($required in @(
 'VerifiedInstallerLaunchLease.Acquire(trusted,expectedDigest,local,profile)',
 'pinned.VerifiedSHA256',
 'psi.FileName=trusted;psi.UseShellExecute=true;',
 'FileShare.Read,65536,FileOptions.SequentialScan',
 'ShareReadWrite=3,OpenExisting=3',
 'GetFileInformationByHandleEx(',
 'GetFinalPathNameByHandleW'
)){
 if(!$source.Contains($required)){throw ('R405_SOURCE_PIN_GUARD_MISSING_'+$required)}
}
$assembly=[Reflection.Assembly]::LoadFrom($app)
$parent=$assembly.GetType('TaskbarMonitorEnhanced.UpdateManager',$true)
$t=$parent.GetNestedType('VerifiedInstallerLaunchLease',
 [Reflection.BindingFlags]'Public,NonPublic')
if(!$t){throw 'R405_PINNED_COMPILED_TYPE_NOT_FOUND'}
$flags=[Reflection.BindingFlags]'Static,NonPublic,Public'
$instanceFlags=[Reflection.BindingFlags]'Instance,NonPublic,Public'
$acquire=$t.GetMethod('Acquire',$flags)
$pathField=$t.GetProperty('CanonicalPath',$instanceFlags)
$hashField=$t.GetProperty('VerifiedSHA256',$instanceFlags)
if(!$acquire -or !$pathField -or !$hashField -or $acquire.GetParameters().Length -ne 4){
 throw 'R405_COMPILED_PINNED_ENTRYPOINTS_NOT_FOUND'
}
function Acquire([string]$Setup,[string]$Digest,[string]$Local,[string]$Profile){
 try{
  $lease=$acquire.Invoke($null,[object[]]@($Setup,$Digest,$Local,$Profile))
  return [pscustomobject]@{Lease=$lease;Error='';Message=''}
 }catch{
  $e=$_.Exception
  while($e.InnerException){$e=$e.InnerException}
  return [pscustomobject]@{Lease=$null;Error=$e.GetType().Name;Message=$e.Message}
 }
}
$testRoot=Join-Path $env:TEMP ('tbme-r405-pinned-launch-'+[Guid]::NewGuid().ToString('N'))
if(Test-Path $testRoot){throw 'R405_TEMP_COLLISION'}
$profile=Join-Path $testRoot 'profile'
$local=Join-Path $profile 'AppData\Local'
$appDir=Join-Path $local 'TaskbarMonitorEnhanced'
$updates=Join-Path $appDir 'Updates'
$setup=Join-Path $updates 'TaskbarMonitorEnhanced_Setup_1.7.10.exe'
$outside=Join-Path $testRoot 'outside'
[void][IO.Directory]::CreateDirectory($updates)
[void][IO.Directory]::CreateDirectory($outside)
$active=$null
try{
 if($HostedGuest){
  # Harmless locally generated test executable, NEVER the official Setup.
  $fixtureSource=@'
using System;
public class R405HarmlessSetupFixture {
 public static int Main(string[] args) { return 0; }
}
'@
  Add-Type -TypeDefinition $fixtureSource -OutputAssembly $setup -OutputType ConsoleApplication -ErrorAction Stop
 }else{
  [IO.File]::WriteAllText($setup,'R405_HARMLESS_TEXT_NOT_EXECUTED')
 }
 $sha=(Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash
 $badSha='A'*64
 if($sha -ceq $badSha){throw 'R405_TEST_BAD_DIGEST_COLLISION'}
 $marker=Join-Path $outside 'OUTSIDE_CANARY.txt'
 [IO.File]::WriteAllText($marker,'R405_OUTSIDE_CANARY_MUST_REMAIN_IDENTICAL')
 $markerSha=(Get-FileHash $marker -Algorithm SHA256).Hash

 $bad=Acquire $setup ('sha256:'+$badSha) $local $profile
 if(!$bad.Error -or $bad.Lease){throw 'R405_WRONG_SHA256_ACCEPTED'}
 'R405_PASS_BAD_SHA_REJECTED_WITHOUT_STALE_PINS'

 $valid=Acquire $setup ('sha256:'+$sha.ToLowerInvariant()) $local $profile
 if($valid.Error -or !$valid.Lease){throw ('R405_VALID_PINNED_SETUP_REJECTED '+$valid.Error+' '+$valid.Message)}
 $active=$valid.Lease
 $pinnedPath=[string]$pathField.GetValue($active,$null)
 $pinnedSha=[string]$hashField.GetValue($active,$null)
 if(![string]::Equals($pinnedPath,[IO.Path]::GetFullPath($setup),[StringComparison]::OrdinalIgnoreCase) -or
    $pinnedSha -cne $sha){throw 'R405_LOCKED_FILE_IDENTITY_OR_SHA_MISMATCH'}
 'R405_PASS_REAL_NET48_HANDLE_IDENTITY_AND_SHA'

 $rejected=0
 foreach($kind in @('write-file','rename-file','rename-updates','rename-app','rename-local','rename-appdata','rename-profile')){
  $blocked=$false
  try{
   switch($kind){
    'write-file' {[IO.File]::WriteAllText($setup,'MALICIOUS')}
    'rename-file' {[IO.File]::Move($setup,($setup+'.renamed'))}
    'rename-updates' {[IO.Directory]::Move($updates,($updates+'.renamed'))}
    'rename-app' {[IO.Directory]::Move($appDir,($appDir+'.renamed'))}
    'rename-local' {[IO.Directory]::Move($local,($local+'.renamed'))}
    'rename-appdata' {[IO.Directory]::Move((Join-Path $profile 'AppData'),(Join-Path $profile 'AppData.renamed'))}
    'rename-profile' {[IO.Directory]::Move($profile,($profile+'.renamed'))}
   }
  }catch{
   $blocked=$true
   $e=$_.Exception
   while($e.InnerException){$e=$e.InnerException}
   if($e -isnot [IO.IOException] -and $e -isnot [UnauthorizedAccessException]){
    throw ('R405_REJECTION_NOT_SHARING_ACCESS_'+$kind+'_'+$e.GetType().Name)
   }
  }
  if(!$blocked){throw ('R405_UNTRUSTED_PATH_SWAP_SUCCEEDED_WHILE_PINNED_'+$kind)}
  $rejected++
 }
 if($rejected -ne 7){throw 'R405_SWAP_TEST_COUNT_INVALID'}
 'R405_PASS_SEVEN_FILE_AND_ALL_OWNER_ANCESTOR_MUTATIONS_REJECTED'

 if($HostedGuest){
  $psi=[Diagnostics.ProcessStartInfo]::new()
  $psi.FileName=$pinnedPath
  $psi.UseShellExecute=$true
  $psi.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
  $proc=[Diagnostics.Process]::Start($psi)
  if(!$proc){throw 'R405_HOSTED_BENIGN_PROCESS_START_NULL'}
  try{
   if(!$proc.WaitForExit(10000) -or $proc.ExitCode -ne 0){
     throw 'R405_HOSTED_BENIGN_PROCESS_START_EXIT_FAILED'
   }
  }finally{$proc.Dispose()}
  'R405_PASS_REAL_HOSTED_SHELLEXECUTE_WHILE_SAME_EXE_AND_ANCESTORS_PINNED'
 }else{
  'R405_PASS_OWNER_LOCAL_READONLY_COMPILED_GUARD_NO_EXECUTABLE_STARTED'
 }

 if((Get-FileHash $setup -Algorithm SHA256).Hash -cne $sha -or
    (Get-FileHash $marker -Algorithm SHA256).Hash -cne $markerSha){
  throw 'R405_FIXTURE_OR_OUTSIDE_CANARY_MODIFIED'
 }
 'R405_PASS_PINNED_SETUP_AND_OUTSIDE_CANARY_SHA256_UNCHANGED'
 $active.Dispose();$active=$null
 [IO.File]::Move($setup,($setup+'.after-pin'))
 [IO.File]::Move(($setup+'.after-pin'),$setup)
 if((Get-FileHash $setup -Algorithm SHA256).Hash -cne $sha){throw 'R405_RELEASE_CHANGED_VERIFIED_CONTENT'}
 'R405_PASS_PIN_RELEASE_ALLOWS_NORMAL_FILE_MANAGEMENT'
 'R405_RESULT=PASS_COMPILED_PINNED_FILE_AND_ANCESTOR_LAUNCH_BOUNDARY'
}finally{
 if($active){$active.Dispose()}
 if(Test-Path $testRoot){Remove-Item -LiteralPath $testRoot -Recurse -Force}
}
