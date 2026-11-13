[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$AppPath,
 [Parameter(Mandatory=$true)][string]$SourceRoot,
 [switch]$HostedGuest
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($PSVersionTable.PSEdition -cne 'Desktop'){throw 'R404_REQUIRES_NATIVE_WINDOWS_POWERSHELL_51'}
if($HostedGuest -and ($env:GITHUB_ACTIONS -cne 'true' -or $env:RUNNER_OS -cne 'Windows' -or
  $env:RUNNER_ENVIRONMENT -cne 'github-hosted')){throw 'R404_REQUIRES_DISPOSABLE_GITHUB_WINDOWS'}
$root=(Resolve-Path -LiteralPath $SourceRoot).Path
$app=(Resolve-Path -LiteralPath $AppPath).Path
$expected=Join-Path $root 'build\_out\App\TaskbarMonitorEnhanced.exe'
if(![string]::Equals($app,$expected,[StringComparison]::OrdinalIgnoreCase)){
 throw 'R404_CANDIDATE_NOT_EXACT_MAIN_BUILD'
}
$source=[IO.File]::ReadAllText((Join-Path $root 'src\TaskbarMonitorEnhanced.cs'))
if(!$source.Contains('CanonicalInstallerLaunchPath(path,') -or
   !$source.Contains('psi.FileName=trusted;psi.UseShellExecute=true;') -or
   !$source.Contains('string actual=VerifyInstallerBeforeLaunch(trusted,expectedDigest);')){
 throw 'R404_LAUNCH_PRECHECK_OR_EXACT_TRUSTED_PATH_SOURCE_GUARD_MISSING'
}
$asm=[Reflection.Assembly]::LoadFrom($app)
$t=$asm.GetType('TaskbarMonitorEnhanced.UpdateManager',$true)
$flags=[Reflection.BindingFlags]'Static,NonPublic,Public'
$launch=$t.GetMethod('CanonicalInstallerLaunchPath',$flags)
$verify=$t.GetMethod('VerifyInstallerBeforeLaunch',$flags)
if(!$launch -or $launch.GetParameters().Length -ne 3 -or !$verify){
 throw 'R404_COMPILED_GUARD_METHOD_NOT_FOUND'
}
function Call([Reflection.MethodInfo]$Method,[object[]]$Arguments){
 try{
  $value=$Method.Invoke($null,$Arguments)
  return [pscustomobject]@{Value=$value;Rejected=$false;Exception='';Message=''}
 }catch{
  $e=$_.Exception
  while($e.InnerException){$e=$e.InnerException}
  return [pscustomobject]@{Value=$null;Rejected=$true;Exception=$e.GetType().Name;Message=$e.Message}
 }
}
$ownerLocal=[Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
$ownerProfile=[Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
$ownerUpdate=Join-Path $ownerLocal 'TaskbarMonitorEnhanced\Updates\TaskbarMonitorEnhanced_Setup_1.7.10.exe'
$ownerReadOnly=Call $launch ([object[]]@([string]$ownerUpdate,[string]$ownerLocal,[string]$ownerProfile))
if($ownerReadOnly.Rejected -or
   ![string]::Equals([string]$ownerReadOnly.Value,[IO.Path]::GetFullPath($ownerUpdate),
        [StringComparison]::OrdinalIgnoreCase)){
 throw ('R404_REAL_OWNER_LOCALAPPDATA_CANONICAL_READONLY_REJECTED_'+$ownerReadOnly.Exception)
}
'R404_PASS_REAL_OWNER_INSTALL_ROOT_POLICY_READONLY'
$fixture=Join-Path $env:TEMP ('tbme-r404-executable-launch-'+[Guid]::NewGuid().ToString('N'))
if(Test-Path $fixture){throw 'R404_TEST_COLLISION'}
$profile=Join-Path $fixture 'profile'
$local=Join-Path $profile 'AppData\Local'
$updates=Join-Path $local 'TaskbarMonitorEnhanced\Updates'
$outside=Join-Path $fixture 'outside'
[void][IO.Directory]::CreateDirectory($updates)
[void][IO.Directory]::CreateDirectory($outside)
try{
 $leaf='TaskbarMonitorEnhanced_Setup_1.7.10.exe'
 $target=Join-Path $updates $leaf
 [IO.File]::WriteAllText($target,'R404_HARMLESS_TEST_NOT_EXECUTABLE')
 $rawSha=(Get-FileHash $target -Algorithm SHA256).Hash
 $canary=Join-Path $outside 'OUTSIDE_CANARY.txt'
 [IO.File]::WriteAllText($canary,'R404_MUST_REMAIN_IDENTICAL')
 $canarySha=(Get-FileHash $canary -Algorithm SHA256).Hash
 $good=Call $launch ([object[]]@([string]$target,[string]$local,[string]$profile))
 if($good.Rejected -or ![string]::Equals([string]$good.Value,[IO.Path]::GetFullPath($target),
          [StringComparison]::OrdinalIgnoreCase)){
  throw ('R404_EXACT_OWN_DIRECTORY_SETUP_NOT_ALLOWED_'+$good.Exception+' '+$good.Message)
 }
 $verified=Call $verify ([object[]]@([string]$good.Value,[string]('sha256:'+$rawSha.ToLowerInvariant())))
 if($verified.Rejected -or $verified.Value -cne $rawSha){
  throw 'R404_GENERAL_DIGEST_VERIFIER_REGRESSION'
 }
 'R404_PASS_COMPILED_CANONICAL_UPDATE_SETUP_AND_SHA256'
 $wrongRoot=Join-Path $outside $leaf
 [IO.File]::WriteAllText($wrongRoot,'R404_OUTSIDE_TEST_NO_EXECUTION')
 $positiveVersion='TaskbarMonitorEnhanced_Setup_1.7.11.exe'
 $cases=@(
  [pscustomobject]@{Name='outside-file';Path=$wrongRoot;Local=$local;Profile=$profile},
  [pscustomobject]@{Name='sibling-prefix';Path=(Join-Path $local ('TaskbarMonitorEnhanced\Updates_attacker\'+$leaf));Local=$local;Profile=$profile},
  [pscustomobject]@{Name='non-numeric-release';Path=(Join-Path $updates 'TaskbarMonitorEnhanced_Setup_x.exe');Local=$local;Profile=$profile},
  [pscustomobject]@{Name='noncanonical-leading-zero';Path=(Join-Path $updates 'TaskbarMonitorEnhanced_Setup_1.07.10.exe');Local=$local;Profile=$profile},
  [pscustomobject]@{Name='double-extension';Path=(Join-Path $updates 'TaskbarMonitorEnhanced_Setup_1.7.10.exe.exe');Local=$local;Profile=$profile},
  [pscustomobject]@{Name='alternate-extension';Path=(Join-Path $updates 'TaskbarMonitorEnhanced_Setup_1.7.10.cmd');Local=$local;Profile=$profile},
  [pscustomobject]@{Name='ads-suffix';Path=(Join-Path $updates ($leaf+':DATA'));Local=$local;Profile=$profile},
  [pscustomobject]@{Name='malformed-version-traversal';Path=(Join-Path $updates 'TaskbarMonitorEnhanced_Setup_1.7.10\..\..\outside.exe');Local=$local;Profile=$profile},
  [pscustomobject]@{Name='relative';Path=('.\'+$leaf);Local=$local;Profile=$profile},
  [pscustomobject]@{Name='UNC';Path='\\attacker\share\TaskbarMonitorEnhanced_Setup_1.7.10.exe';Local=$local;Profile=$profile},
  [pscustomobject]@{Name='wrong-profile';Path=$target;Local=$local;Profile=(Join-Path $fixture 'other')},
  [pscustomobject]@{Name='wrong-local';Path=$target;Local=(Join-Path $fixture 'redirected');Profile=$profile}
 )
 foreach($case in $cases){
  $blocked=Call $launch ([object[]]@([string]$case.Path,[string]$case.Local,[string]$case.Profile))
  if(!$blocked.Rejected){throw ('R404_UNTRUSTED_LAUNCH_PATH_ACCEPTED_'+$case.Name)}
 }
 'R404_PASS_TWELVE_MALICIOUS_OR_MISMATCHED_LAUNCH_PATHS_REJECTED'
 $profile2=Join-Path $fixture 'profile2'
 $local2=Join-Path $profile2 'AppData\Local'
 $parent2=Join-Path $local2 'TaskbarMonitorEnhanced'
 $updates2=Join-Path $parent2 'Updates'
 [void][IO.Directory]::CreateDirectory($parent2)
 $junction=$null
 try{
  $junction=New-Item -ItemType Junction -Path $updates2 -Target $outside -ErrorAction Stop
  if((([IO.File]::GetAttributes($updates2) -band [IO.FileAttributes]::ReparsePoint) -eq 0)){
   throw 'R404_JUNCTION_NOT_REAL'
  }
  $through=Call $launch ([object[]]@([string](Join-Path $updates2 $leaf),[string]$local2,[string]$profile2))
  if(!$through.Rejected -or $through.Message -notmatch '(?i)reparse'){
   throw ('R404_LAUNCH_THROUGH_JUNCTION_NOT_REJECTED_'+$through.Exception)
  }
  'R404_PASS_REAL_UPDATES_JUNCTION_REJECTED'
 }finally{
  if(Test-Path $updates2){[IO.Directory]::Delete($updates2)}
 }
 if((Get-FileHash $target -Algorithm SHA256).Hash -cne $rawSha -or
    (Get-FileHash $canary -Algorithm SHA256).Hash -cne $canarySha){
  throw 'R404_TEST_OR_OUTSIDE_CANARY_SHA_CHANGED'
 }
 'R404_PASS_SHA256_FIXTURES_UNCHANGED'
 'R404_PASS_NO_REAL_SETUP_PROCESS_LAUNCHED_OR_OWNER_CONFIGURATION_MODIFIED'
 'R404_RESULT=PASS_COMPILED_OWNER_ONLY_CANONICAL_SETUP_LAUNCH_GUARD'
}finally{
 if(Test-Path $fixture){Remove-Item -LiteralPath $fixture -Force -Recurse}
}
