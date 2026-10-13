# R128 independent exact-binary, read-only state transition contract.
# Invoke compiled private pure method by reflection: NEVER run installer entrypoint.
[CmdletBinding()]
param([string]$SetupPath = "$PSScriptRoot\_out\Setup\TaskbarMonitorEnhanced_Setup_1.7.1.exe")
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$full=[IO.Path]::GetFullPath($SetupPath)
if(!(Test-Path -LiteralPath $full -PathType Leaf) -or
   [IO.Path]::GetFileName($full) -cne 'TaskbarMonitorEnhanced_Setup_1.7.1.exe'){
 throw 'R128_EXACT_PRIVATE_SETUP_MISSING'
}
$sha=(Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
$assembly=[Reflection.Assembly]::LoadFile($full)
$ty=$assembly.GetType('SetupProgram',$true)
$flags=[Reflection.BindingFlags]::Static -bor [Reflection.BindingFlags]::NonPublic
$method=$ty.GetMethod('NewInstallState',$flags)
if($null -eq $method){throw 'R128_SOURCE_METHOD_NOT_EMBEDDED'}
function Convert-WithRealMethod([string]$inputJson){
 try{
  return [string]$method.Invoke($null,[object[]]@($inputJson))
 }catch [Reflection.TargetInvocationException]{
  throw $_.Exception.InnerException
 }
}
$base='{"App":"Taskbar Monitor Enhanced","Version":"1.7.0","PublicVersion":"1.7.0","ProductIdentity":"LOCKED","UserPreference":"Retro Terminal","Sentinel":"keep this literal 1.7.0 unchanged"}'
$base16=$base.Replace('"1.7.0"','"1.6.0"')
$expected=$base.Replace('"Version":"1.7.0"','"Version":"1.7.1"').Replace('"PublicVersion":"1.7.0"','"PublicVersion":"1.7.1"')
$cases=0
foreach($candidate in @($base,$base16)){
 $converted=Convert-WithRealMethod $candidate
 $o=ConvertFrom-Json -InputObject $converted -ErrorAction Stop
 if($o.Version -cne '1.7.1' -or $o.PublicVersion -cne '1.7.1' -or
   $o.ProductIdentity -cne 'LOCKED' -or $o.UserPreference -cne 'Retro Terminal' -or
   $o.Sentinel -cne 'keep this literal 1.7.0 unchanged' -or
   $converted -cne $expected){
  throw ('R128_EXACT_STATE_REPLACEMENT_OR_UNTOUCHED_USER_VALUES_FAIL '+$candidate+' ACTUAL='+$converted)
 }
 $cases++
}
$unchanged=Convert-WithRealMethod $expected
if($unchanged -cne $expected){throw 'R128_SAME_VERSION_NOT_BITWISE_IDEMPOTENT'}
$cases++
$negative=@(
 $base.Replace('"Version":"1.7.0"','"Version":"1.7.2"'),
 $base.Replace('"PublicVersion":"1.7.0"','"PublicVersion":"1.8.0"'),
 $base.Replace('"Version":"1.7.0"','"Version":"1.7.0","Version":"1.7.0"'),
 $base.Replace('"PublicVersion":"1.7.0"','"PublicVersion":"1.7.0","PublicVersion":"1.7.0"'),
 $base.Replace('"Version":"1.7.0"', '"Version":"1.6.0"')
)
foreach($mutant in $negative){
 $rejected=$false
 try{[void](Convert-WithRealMethod $mutant)}
 catch{$rejected=$true}
 if(!$rejected){throw ('R128_HOSTILE_STATE_ACCEPTED '+$mutant)}
 $cases++
}
if($cases -ne 8){throw 'R128_CASE_COUNT_DRIFT'}
Write-Output ('R128_BINARY_STATE_UPGRADE_CONTRACT=PASS CASES='+$cases+' MAIN_UNTOUCHED=YES SETUP_SHA256='+$sha)
exit 0
