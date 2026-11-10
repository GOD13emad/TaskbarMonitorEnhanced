[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][ValidateSet('baseline','candidate')][string]$Variant,
 [Parameter(Mandatory=$true)][string]$SourceRoot,
 [Parameter(Mandatory=$true)][string]$ExpectedSourceCommit,
 [ValidateSet('LOCAL','A','B')][string]$HostLabel='LOCAL',
 [switch]$HostedGuest
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -cne 'Desktop'){throw 'R385_NEEDS_WINDOWS_POWERSHELL_51'}
if($HostedGuest -and ($env:GITHUB_ACTIONS -cne 'true' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or $env:RUNNER_OS -cne 'Windows')){
 throw 'R385_REFUSE_NON_GITHUB_HOSTED_GUEST'
}
$source=(Resolve-Path -LiteralPath $SourceRoot).Path
$setup=Join-Path $source 'installer\TaskbarMonitorEnhanced_Setup.cs'
if(!(Test-Path -LiteralPath $setup -PathType Leaf)){throw 'R385_SETUP_SOURCE_MISSING'}
$sourceCommit=(git -C $source rev-parse HEAD).Trim()
if($sourceCommit -cne $ExpectedSourceCommit){throw 'R385_SOURCE_COMMIT_MISMATCH'}
$baseline='f59e1dcf410b97cf16350bc385b4fcbedbf3b093'
if($Variant -eq 'baseline' -and $sourceCommit -cne $baseline){throw 'R385_BASELINE_NOT_PINNED'}
if($Variant -eq 'candidate' -and $sourceCommit -ceq $baseline){throw 'R385_CANDIDATE_NOT_DISTINCT'}
if($HostedGuest){
 $ownerRoot=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'TaskbarMonitorEnhanced'
 if(Test-Path -LiteralPath $ownerRoot){throw 'R385_EXISTING_OWNER_INSTALL_REFUSED'}
}
$src=[IO.File]::ReadAllText($setup)
$elevatedMatch=[regex]::Match($src,'(?s)    static bool IsCurrentProcessElevated\(\)\r?\n    \{.*?\r?\n    \}')
if(!$elevatedMatch.Success -or [regex]::Matches($src,'static bool IsCurrentProcessElevated\(').Count -ne 1){throw 'R385_ACTUAL_ELEVATION_METHOD_NOT_UNIQUE'}
$uacMatch=[regex]::Match($src,'(?s)    static bool IsUacEnabled\(\)\r?\n    \{.*?\r?\n    \}')
$contextMatch=[regex]::Match($src,'(?s)    static bool IsElevatedUpdateContext\(\)\r?\n    \{.*?\r?\n    \}')
$upgradeMatch=[regex]::Match($src,'(?s)    static SensorOutcome UpgradeExisting\(\)\r?\n    \{(?<body>.*?)\r?\n    \}')
if(!$upgradeMatch.Success){throw 'R385_UPGRADE_METHOD_NOT_UNIQUE'}
$upgradeBody=$upgradeMatch.Groups['body'].Value
$guardPattern='(?s)if\(IsElevatedUpdateContext\(\)\)\s*throw new InvalidOperationException\("In-place upgrades must run without elevation while UAC is enabled; start Setup normally\. Only the protected sensor helper requests elevation\."\);'
$guardMatch=[regex]::Match($upgradeBody,$guardPattern)
$checks=New-Object 'Collections.Generic.List[string]'
function Pass([string]$name){$checks.Add($name);Write-Host ('PASS '+$name)}
$nl=[Environment]::NewLine
$actualFixture='using System;'+$nl+'using System.Security.Principal;'+$nl+'using Microsoft.Win32;'+$nl+'public static class R385ActualHelperFixture {'+$nl+$elevatedMatch.Value+$nl
if($Variant -eq 'candidate'){
 if(!$uacMatch.Success -or !$contextMatch.Success){throw 'R385_CANDIDATE_UAC_HELPERS_MISSING'}
 $actualFixture+=$uacMatch.Value+$nl+$contextMatch.Value+$nl
}else{
 if($uacMatch.Success -or $contextMatch.Success){throw 'R385_BASELINE_CONTAINS_CANDIDATE_HELPERS'}
}
$actualFixture+='public static bool ReadElevated(){return IsCurrentProcessElevated();}'+$nl
if($Variant -eq 'candidate'){
 $actualFixture+='public static bool ReadUac(){return IsUacEnabled();}'+$nl
 $actualFixture+='public static bool ReadBoundary(){return IsElevatedUpdateContext();}'+$nl
}
$actualFixture+='}'
Add-Type -TypeDefinition $actualFixture -ErrorAction Stop

$expectedUac=$true
$baseKey=$null;$systemKey=$null
try{
 $baseKey=[Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,[Microsoft.Win32.RegistryView]::Registry64)
 $systemKey=$baseKey.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System',$false)
 $enableLUA=if($null -eq $systemKey){$null}else{$systemKey.GetValue('EnableLUA',$null)}
 if($null -ne $enableLUA){$expectedUac=([int]$enableLUA -ne 0)}
}catch{$expectedUac=$true}
finally{if($null -ne $systemKey){$systemKey.Dispose()};if($null -ne $baseKey){$baseKey.Dispose()}}
$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
try{
 $principal=New-Object Security.Principal.WindowsPrincipal -ArgumentList $identity
 $expectedElevated=$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}finally{$identity.Dispose()}
$actualElevated=[R385ActualHelperFixture]::ReadElevated()
if($actualElevated -ne $expectedElevated){throw 'R385_ACTUAL_ELEVATION_HELPER_MISMATCH'}
Pass 'ACTUAL_PROCESS_ELEVATION_HELPER_MATCHES_WINDOWS_TOKEN'
if($Variant -eq 'candidate'){
 $actualUac=[R385ActualHelperFixture]::ReadUac()
 if($actualUac -ne $expectedUac){throw 'R385_ACTUAL_UAC_HELPER_MISMATCH'}
 Pass 'ACTUAL_UAC_HELPER_MATCHES_64BIT_HKLM_ENABLELUA'
 $actualBoundary=[R385ActualHelperFixture]::ReadBoundary()
 if($actualBoundary -ne ($expectedUac -and $expectedElevated)){throw 'R385_ACTUAL_COMBINED_BOUNDARY_MISMATCH'}
 Pass 'ACTUAL_COMBINED_BOUNDARY_MATCHES_UAC_AND_ELEVATION'
}

$directoryIndex=$upgradeBody.IndexOf('if(!Directory.Exists(AppRoot)',[StringComparison]::Ordinal)
$checkIndex=$upgradeBody.IndexOf('CheckNoReparse(AppRoot);',[StringComparison]::Ordinal)
$recoverIndex=$upgradeBody.IndexOf('RecoverUpgradeStageIfAny();',[StringComparison]::Ordinal)
if($directoryIndex -lt 0 -or $checkIndex -lt 0 -or $recoverIndex -lt 0){throw 'R385_UPGRADE_PROLOGUE_ANCHORS_MISSING'}
if($Variant -eq 'baseline'){
 if($guardMatch.Success -or $upgradeBody.IndexOf('if(IsElevatedUpdateContext())',[StringComparison]::Ordinal) -ge 0){
  throw 'R385_BASELINE_NEGATIVE_CONTROL_NOT_OLD'
 }
}else{
 if(!$guardMatch.Success -or $guardMatch.Index -ge $directoryIndex -or $guardMatch.Index -ge $checkIndex -or $guardMatch.Index -ge $recoverIndex){
  throw 'R385_CANDIDATE_GUARD_NOT_BEFORE_ANY_STAGE_OR_APPROOT_ACCESS'
 }
}

$contextCode=if($Variant -eq 'candidate'){$contextMatch.Value}else{'static bool IsElevatedUpdateContext(){return false;}'}
$guardCode=if($Variant -eq 'candidate'){$guardMatch.Value}else{''}
$guardFixture='using System;'+$nl+
 'public static class R385GuardFixture {'+$nl+
 'public static bool UacEnabled,Elevated,RecoveryReached;'+$nl+
 'static bool IsUacEnabled(){return UacEnabled;}'+$nl+
 'static bool IsCurrentProcessElevated(){return Elevated;}'+$nl+
 $contextCode+$nl+
 'public static void Reset(bool uac,bool elevated){UacEnabled=uac;Elevated=elevated;RecoveryReached=false;}'+$nl+
 'public static void Run(){'+$nl+
 $guardCode+$nl+
 'RecoveryReached=true;'+$nl+
 '}}'
Add-Type -TypeDefinition $guardFixture -ErrorAction Stop
if($Variant -eq 'baseline'){
 [R385GuardFixture]::Reset($true,$true)
 [R385GuardFixture]::Run()
 if(![R385GuardFixture]::RecoveryReached){throw 'R385_BASELINE_ELEVATED_RECOVERY_NEGATIVE_CONTROL_FAILED'}
 Pass 'BASELINE_ELEVATED_UPDATE_REACHES_STAGE_RECOVERY'
}else{
 [R385GuardFixture]::Reset($true,$true)
 $refused=$false
 try{[R385GuardFixture]::Run()}catch [System.InvalidOperationException]{$refused=$true}
 if(!$refused -or [R385GuardFixture]::RecoveryReached){throw 'R385_CANDIDATE_ELEVATED_UPDATE_NOT_REFUSED_BEFORE_RECOVERY'}
 Pass 'CANDIDATE_UAC_ELEVATED_UPDATE_REFUSED_BEFORE_STAGE_RECOVERY'
 [R385GuardFixture]::Reset($true,$false)
 [R385GuardFixture]::Run()
 if(![R385GuardFixture]::RecoveryReached){throw 'R385_CANDIDATE_MEDIUM_INTEGRITY_UPDATE_BLOCKED'}
 Pass 'CANDIDATE_UAC_MEDIUM_INTEGRITY_UPDATE_ALLOWED'
 [R385GuardFixture]::Reset($false,$true)
 [R385GuardFixture]::Run()
 if(![R385GuardFixture]::RecoveryReached){throw 'R385_CANDIDATE_UAC_DISABLED_ADMIN_COMPATIBILITY_BROKEN'}
 Pass 'CANDIDATE_UAC_DISABLED_ADMIN_COMPATIBILITY_PRESERVED'
}

$receiptRoot=if($HostedGuest){$env:RUNNER_TEMP}else{$env:TEMP}
$dir=Join-Path $receiptRoot ('R385_'+$Variant+'_'+$HostLabel+'_'+[Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($dir)
$result=[ordered]@{
 Revision='R385';Variant=$Variant;Host=$HostLabel
 SourceCommit=$sourceCommit;SourceSHA256=(Get-FileHash $setup -Algorithm SHA256).Hash.ToUpperInvariant()
 ActualUacEnabled=$expectedUac;ActualProcessElevated=$expectedElevated
 Checks=@($checks.ToArray())
 Status=if($Variant -eq 'baseline'){'PASS_ELEVATED_UPDATE_REACHES_STAGE_RECOVERY'}else{'PASS_ELEVATED_UPDATE_BLOCKED_USER_UPDATE_ALLOWED'}
 ChangedOwnerInstall=$false;InvokedActualSetup=$false
 ClaimLimit='Exact production helper/guard source compiled in isolated fixtures; simulated UAC/elevation combinations and actual registry/token helper cross-checks. No real Setup execution, UAC prompt, privilege elevation, or owner installation mutation.'
}
$receipt=Join-Path $dir 'R385_UPGRADE_BOUNDARY.json'
[IO.File]::WriteAllText($receipt,($result|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
$read=Get-Content $receipt -Raw|ConvertFrom-Json
if($read.Checks.Count -ne $checks.Count -or $read.SourceCommit -cne $sourceCommit -or $read.ChangedOwnerInstall -ne $false){throw 'R385_RECEIPT_READBACK_FAILED'}
Write-Host ('R385_STATUS='+$read.Status)
Write-Host ('R385_CHECKS='+$read.Checks.Count)
Write-Host ('R385_RECEIPT='+$receipt)
Write-Host ('R385_RECEIPT_SHA256='+(Get-FileHash $receipt -Algorithm SHA256).Hash.ToUpperInvariant())