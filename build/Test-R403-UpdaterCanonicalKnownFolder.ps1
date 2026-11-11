[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$AppPath,
 [Parameter(Mandatory=$true)][string]$SourceRoot,
 [switch]$HostedGuest
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($PSVersionTable.PSEdition -cne 'Desktop'){throw 'R403_PS51_REQUIRED'}
if($HostedGuest -and ($env:GITHUB_ACTIONS -cne 'true' -or $env:RUNNER_OS -cne 'Windows' -or
    $env:RUNNER_ENVIRONMENT -cne 'github-hosted')){throw 'R403_NOT_HOSTED'}
$root=(Resolve-Path -LiteralPath $SourceRoot).Path
$app=(Resolve-Path -LiteralPath $AppPath).Path
if(![string]::Equals($app,(Join-Path $root 'build\_out\App\TaskbarMonitorEnhanced.exe'),[StringComparison]::OrdinalIgnoreCase)){
 throw 'R403_APP_NOT_EXACT_BUILD_OUTPUT'
}
$source=[IO.File]::ReadAllText((Join-Path $root 'src\TaskbarMonitorEnhanced.cs'))
foreach($guard in @('CanonicalPerUserUpdatesDirectory(', 'Path.Combine(trustedUpdates,expectedName)',
    'Release version is not a canonical numeric token.','RejectUpdateReparseAncestors(updates);')){
 if(!$source.Contains($guard)){throw ('R403_MISSING_SOURCE_GUARD_'+$guard)}
}
$asm=[Reflection.Assembly]::LoadFrom($app)
$t=$asm.GetType('TaskbarMonitorEnhanced.UpdateManager',$true)
$paths=$asm.GetType('TaskbarMonitorEnhanced.AppPaths',$true)
$flags=[Reflection.BindingFlags]'Static,NonPublic,Public'
$canonical=$t.GetMethod('CanonicalPerUserUpdatesDirectory',$flags)
$asset=$t.GetMethod('ExpectedSetupAssetName',$flags)
if(!$canonical -or !$asset -or $canonical.GetParameters().Length -ne 2 -or
 $asset.GetParameters().Length -ne 1){throw 'R403_COMPILED_GUARD_METHODS_MISSING'}
function Call([Reflection.MethodInfo]$Method,[object[]]$Arguments){
 try{return [pscustomobject]@{Value=$Method.Invoke($null,$Arguments);Error='';Message=''}}
 catch{
  $e=$_.Exception
  while($e.InnerException){$e=$e.InnerException}
  return [pscustomobject]@{Value=$null;Error=$e.GetType().Name;Message=$e.Message}
 }
}
$good=Call $asset ([object[]]@('1.7.10'))
if($good.Error -or $good.Value -cne 'TaskbarMonitorEnhanced_Setup_1.7.10.exe'){
 throw 'R403_OFFICIAL_ASSET_NOT_ACCEPTED'
}
'R403_PASS_COMPILED_OFFICIAL_NUMERIC_SETUP_ASSET'
foreach($v in @('', '1.07.10', '1.7.010', '1.7.10/../../x',
 '..\..\x', ('1.7.10'+[char]34+' -EncodedCommand'), ('1.7.10'+[char]10),
 '2147483648.1.0','1.7.10.1','1.7.-1')){
 $bad=Call $asset ([object[]]@([string]$v))
 if($bad.Error -cne 'InvalidDataException'){throw ('R403_MALICIOUS_VERSION_ACCEPTED_'+$v)}
}
'R403_PASS_MALFORMED_VERSIONS_AND_TRAVERSAL_REJECTED'
$localOwner=[Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
$profileOwner=[Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
$owner=Call $canonical ([object[]]@([string]$localOwner,[string]$profileOwner))
$ownerUpdates=$paths.GetField('Updates',$flags)
if(!$ownerUpdates -or $owner.Error -or
 ![string]::Equals([string]$owner.Value,[string]$ownerUpdates.GetValue($null),[StringComparison]::OrdinalIgnoreCase)){
 throw ('R403_OWNER_INSTALLED_KNOWN_FOLDER_MISMATCH_'+$owner.Error)
}
'R403_PASS_OWNER_KNOWN_FOLDER_MATCHES_EXISTING_APP_READONLY'
$fixture=Join-Path $env:TEMP ('tbme-r403-updates-root-'+[Guid]::NewGuid().ToString('N'))
if(Test-Path $fixture){throw 'R403_TEMP_COLLISION'}
$profile=Join-Path $fixture 'profile'
$local=Join-Path $profile 'AppData\Local'
$outside=Join-Path $fixture 'outside'
$link=Join-Path $local 'TaskbarMonitorEnhanced'
[void][IO.Directory]::CreateDirectory($local)
[void][IO.Directory]::CreateDirectory($outside)
try{
 $canary=Join-Path $outside 'CANARY.txt'
 [IO.File]::WriteAllText($canary,'R403_CANARY_UNCHANGED')
 $canarySha=(Get-FileHash $canary -Algorithm SHA256).Hash
 $positive=Call $canonical ([object[]]@([string]$local,[string]$profile))
 if($positive.Error -or ![string]::Equals([string]$positive.Value,
   (Join-Path $local 'TaskbarMonitorEnhanced\Updates'),[StringComparison]::OrdinalIgnoreCase)){
  throw ('R403_LOCAL_CANONICAL_PROFILE_REJECTED_'+$positive.Error)
 }
 'R403_PASS_CANONICAL_OWNER_LOCAL_APPDATA_ACCEPTED'
 $tests=@(
  @((Join-Path $fixture 'redirected\Local'),[string]$profile),
  @([string]'\\attacker\share',[string]$profile),
  @([string]([IO.Path]::GetPathRoot($profile)),[string]$profile),
  @([string]$local,[string]'\\attacker\share'),
  @([string]'relative\AppData\Local',[string]$profile),
  @([string]$local,[string]'relative'),
  @([string]'',[string]$profile)
 )
 foreach($pair in $tests){
  $blocked=Call $canonical ([object[]]@([string]$pair[0],[string]$pair[1]))
  if($blocked.Error -cne 'InvalidDataException'){
   throw ('R403_NONCANONICAL_PATH_NOT_REJECTED_'+$pair[0])
  }
 }
 'R403_PASS_REDIRECT_UNC_RELATIVE_ROOT_ONLY_PATHS_REJECTED'
 $junction=New-Item -ItemType Junction -Path $link -Target $outside -ErrorAction Stop
 if(!(Test-Path $link) -or
   (([IO.File]::GetAttributes($link) -band [IO.FileAttributes]::ReparsePoint) -eq 0)){
  throw 'R403_REAL_JUNCTION_FIXTURE_NOT_PROVEN'
 }
 $reparse=Call $canonical ([object[]]@([string]$local,[string]$profile))
 if($reparse.Error -cne 'InvalidDataException' -or $reparse.Message -notmatch '(?i)reparse'){
  throw 'R403_PARENT_JUNCTION_NOT_REJECTED'
 }
 'R403_PASS_COMPILED_UPDATES_PARENT_JUNCTION_REJECTED'
 if((Get-FileHash $canary -Algorithm SHA256).Hash -cne $canarySha){
  throw 'R403_OUTSIDE_CANARY_CHANGED'
 }
 'R403_PASS_OUTSIDE_CANARY_BYTE_IDENTICAL'
 'R403_PASS_NO_NETWORK_INSTALLER_OR_OWNER_MUTATION'
 'R403_RESULT=PASS_COMPILED_CANONICAL_OWNER_UPDATES_AND_NUMERIC_ASSET'
}finally{
 if(Test-Path $link){[IO.Directory]::Delete($link)}
 if(Test-Path $fixture){Remove-Item $fixture -Recurse -Force}
}
