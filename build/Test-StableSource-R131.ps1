# R131 read-only real private .NET Setup contract, no installer execution.
[CmdletBinding()]
param([string]$SetupPath="$PSScriptRoot\_out\Setup\TaskbarMonitorEnhanced_Setup_1.7.1.exe")
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$f=[IO.Path]::GetFullPath($SetupPath)
$want='C03B09B7D740F5BFFAE3CF586DB0BD37384307629ABB3B29A0F564F1901732CF'
if(!(Test-Path -LiteralPath $f -PathType Leaf) -or
   (Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash -cne $want -or
   [IO.Path]::GetFileName($f) -cne 'TaskbarMonitorEnhanced_Setup_1.7.1.exe'){
 throw 'R131_EXACT_PRIVATE_VERIFIED_SETUP_REQUIRED'
}
$a=[Reflection.Assembly]::LoadFile($f)
$t=$a.GetType('SetupProgram',$true)
$flags=[Reflection.BindingFlags]::NonPublic -bor [Reflection.BindingFlags]::Static
$lookup=$t.GetMethod('LegacyExpected',$flags)
$optional=$t.GetMethod('IsOptionalStableLegacyRoot',$flags)
if($null -eq $lookup -or $null -eq $optional) {throw 'R131_COMPILED_STAGE_PREDICATES_MISSING'}
$published='B65606629A6EA1363B387064933FEED3027ED7CD5007FFDDE76BE938009267E1'
$stable=[Collections.IDictionary]$lookup.Invoke($null,[object[]]@('1.7.0','OFFICIAL_STABLE_V170'))
if($stable.Count -ne 23 -or $stable['TaskbarMonitorEnhanced.cs'] -cne $published -or
   $stable['Source/TaskbarMonitorEnhanced.cs'] -cne $published -or
   $stable['Uninstall.exe'] -cne '148827212B716238DDB270309F393140EBE3CB935CD0E80D36233220A4BE611E'){
 throw 'R131_OFFICIAL_STABLE_SOURCE_SHA_ROOT_IDENTITY_MISMATCH'
}
$cases=@(
 @('TaskbarMonitorEnhanced.cs','OFFICIAL_STABLE_V170',$true),
 @('Source/TaskbarMonitorEnhanced.cs','OFFICIAL_STABLE_V170',$false),
 @('TaskbarMonitorEnhanced.cs','PREVIEW1',$false),
 @('TaskbarMonitorEnhanced.cs','OFFICIAL_V16',$false),
 @('TaskbarMonitorEnhanced.cs','UNKNOWN',$false),
 @('TaskbarMonitorEnhanced.CS','OFFICIAL_STABLE_V170',$false),
 @('TaskbarMonitorEnhanced.cs.old','OFFICIAL_STABLE_V170',$false),
 @('Docs/README.md','OFFICIAL_STABLE_V170',$false),
 @('Uninstall.exe','OFFICIAL_STABLE_V170',$false),
 @('../TaskbarMonitorEnhanced.cs','OFFICIAL_STABLE_V170',$false)
)
$index=0
foreach($case in $cases){
 $result=[bool]$optional.Invoke($null,[object[]]@([string]$case[0],[string]$case[1]))
 if($result -ne [bool]$case[2]){throw ('R131_HOSTILE_OPTIONALITY_PREDICATE_ACCEPTED case='+$index)}
 $index++
}
$preview=[Collections.IDictionary]$lookup.Invoke($null,[object[]]@('1.7.0','PREVIEW1'))
$legacy=[Collections.IDictionary]$lookup.Invoke($null,[object[]]@('1.6.0','OFFICIAL_V16'))
if($preview.Count -ne 23 -or $legacy.Count -ne 21){
 throw 'R131_OLDER_RELEASE_INVENTORIES_CHANGED'
}
Write-Output ('R131_OFFICIAL_ROOT_POLICY_COMPILED_PASS CASES='+$index+
 ' STABLE_ROWS='+$stable.Count+' PREVIEW_ROWS='+$preview.Count+
 ' V16_ROWS='+$legacy.Count+' SETUP_SHA256='+$want)
exit 0
