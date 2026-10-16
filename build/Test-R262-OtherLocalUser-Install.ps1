[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$SetupPath,
 [Parameter(Mandatory=$true)][string]$ReceiptPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# Runs ONLY as a non-admin disposable local user created by the parent GH VM.
# Do not invoke under owner or current administrator, never write another HKCU.
# CreateProcessWithLogonW builds the new user's own environment and might
# intentionally omit the original GitHub runner's GITHUB_ACTIONS variables.
# The parent already strictly checks the hosted runner before creating this user.
# The child requires a receipt tied to its exact SID and scoped ProgramData root.
if($env:COMPUTERNAME -match '(?i)EMAD|ALI|LAPTOP'){
 throw 'R262_OTHER_USER_REFUSE_OWNER_COMPUTER'
}
$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
$principal=[Security.Principal.WindowsPrincipal]::new($identity)
if($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
 throw 'R262_SECOND_USER_MUST_NOT_BE_ADMIN'
}
$sid=[string]$identity.User.Value
$user=[string]$identity.Name
if($sid -notmatch '^S-1-5-21-' -or $user -notmatch '(?i)\\TBME262[AB]$'){
 throw 'R262_SECOND_USER_IDENTITY_NOT_CREATED_GUEST'
}
$expectedShared=$null
foreach($label in @('A','B')){
 $dir=Join-Path $env:ProgramData ('TBME_R262_'+$label)
 $testSetup=Join-Path $dir 'TaskbarMonitorEnhanced_Setup_1.7.4.exe'
 $testReceipt=Join-Path $dir 'Results/R262_GUEST_B.json'
 if([String]::Equals([IO.Path]::GetFullPath($SetupPath),[IO.Path]::GetFullPath($testSetup),[StringComparison]::OrdinalIgnoreCase) -and
    [String]::Equals([IO.Path]::GetFullPath($ReceiptPath),[IO.Path]::GetFullPath($testReceipt),[StringComparison]::OrdinalIgnoreCase)){
  $expectedShared=$dir
  break
 }
}
if([String]::IsNullOrWhiteSpace($expectedShared)){throw 'R262_CHILD_SETUP_OR_RECEIPT_OUTSIDE_OWNED_PROGRAMDATA'}
$authority=Join-Path $expectedShared 'R262_TEST_AUTHORITY.json'
if(!(Test-Path $authority -PathType Leaf)){throw 'R262_CHILD_DISPOSABLE_PARENT_AUTHORITY_MISSING'}
$test=Get-Content -LiteralPath $authority -Raw|ConvertFrom-Json -ErrorAction Stop
if($test.Revision -cne 'R262' -or
   $test.HeadSourceSHA -cne '1375d719989aa93966bae445ac63b9a415f637ad' -or
   $test.ExpectedSecondUserSID -cne $sid -or
   $test.HostComputerName -cne $env:COMPUTERNAME -or
   $test.OfficialSetupSHA256 -cne 'C00F0C944E4BFBEE93989E4B5A29931D460CC0011ABDC8FDE6A498E467BCC1A1' -or
   $test.SyntheticParentOnDisposableGitHubVM -ne $true){
 throw 'R262_CHILD_CANNOT_PROVE_SCOPED_PARENT_ACCOUNT_AND_SETUP'
}
$targetRoot=Join-Path $env:LOCALAPPDATA 'TaskbarMonitorEnhanced'
$reg='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TaskbarMonitorEnhanced'
$setup=[IO.Path]::GetFullPath($SetupPath)
$out=[IO.Path]::GetFullPath($ReceiptPath)
$state='FAIL'
$failure=''
$setupExit=$null
$mainHash='ABSENT'
$uninstallHash='ABSENT'
$regVersion=''
$regRoot=''
$phase='BEFORE'
$expectedMain='279DF6276973D45A1F979792718E7BA1A9DB31A44C3C34E7335C7BE1503A3E3C'
$expectedSetup='C00F0C944E4BFBEE93989E4B5A29931D460CC0011ABDC8FDE6A498E467BCC1A1'
function Deny([string]$reason){throw ('R262_B_'+$reason)}
function SHA([string]$p){
 if(!(Test-Path -LiteralPath $p -PathType Leaf)){return 'ABSENT'}
 return (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash
}
try{
 if((Test-Path $out) -or (Test-Path $targetRoot) -or (Test-Path $reg)){
  Deny 'NEW_USER_HAS_PREEXISTING_TARGET_ROOT_OR_RECEIPT'
 }
 if((SHA $setup) -cne $expectedSetup){Deny 'SHARED_PUBLIC_SETUP_SHA_MISMATCH'}
 $phase='RUN_REAL_UNPRIVILEGED_FRESH_SETUP'
 $psi=[Diagnostics.ProcessStartInfo]::new()
 $psi.FileName=$setup
 $psi.Arguments='/install /quiet /desktop=0 /startup=0'
 $psi.WorkingDirectory=[IO.Path]::GetDirectoryName($setup)
 $psi.UseShellExecute=$false
 $psi.CreateNoWindow=$true
 $p=[Diagnostics.Process]::Start($psi)
 if($null -eq $p){Deny 'REAL_SETUP_NOT_STARTED'}
 try{
  if(!$p.WaitForExit(145000)){Deny ('REAL_SECOND_USER_SETUP_TIMEOUT_'+$p.Id)}
  $setupExit=[int]$p.ExitCode
 }finally{$p.Dispose()}
 if($setupExit -ne 0){Deny ('SECOND_USER_SETUP_NONZERO_'+$setupExit)}
 $phase='VERIFY_B_OWN_HKCU_AND_ROOT'
 $mainHash=SHA (Join-Path $targetRoot 'TaskbarMonitorEnhanced.exe')
 $uninstallHash=SHA (Join-Path $targetRoot 'Uninstall.exe')
 if($mainHash -cne $expectedMain -or $uninstallHash -cne $expectedSetup){
  Deny 'SECOND_USER_PRODUCT_BYTES_NOT_OFFICIAL'
 }
 if(Test-Path (Join-Path $targetRoot 'TaskbarMonitorEnhanced.cs')){
  Deny 'SECOND_USER_REDUNDANT_ROOT_SOURCE'
 }
 $entry=Get-ItemProperty $reg -ErrorAction Stop
 $regVersion=[string]$entry.DisplayVersion
 $regRoot=[string]$entry.InstallLocation
 if($regVersion -cne '1.7.4' -or $regRoot -cne $targetRoot){
  Deny 'SECOND_USER_HKCU_REGISTRATION_INVALID'
 }
 if((SHA (Join-Path $targetRoot 'Source/TaskbarMonitorEnhanced.cs')) -ceq 'ABSENT'){
  Deny 'CANONICAL_SOURCE_MISSING'
 }
 $state='PASS_R262_REAL_NONADMIN_SECOND_ACCOUNT_OFFICIAL_V174_PERUSER_INSTALL'
}catch{$failure=$_.Exception.GetType().Name+': '+$_.Exception.Message}
finally{
 $record=[ordered]@{
  Revision='R262';Status=$state;Phase=$phase;Failure=$failure
  TestUser=$user;TestUserSID=$sid;IsAdministrator=$false
  OtherUserReallyLoggedOnAsDifferentSID=$true
  AppRoot=$targetRoot;HKCUVersion=$regVersion;HKCUInstallRoot=$regRoot
  SetupExit=$setupExit;MainSHA256=$mainHash;MaintenanceSHA256=$uninstallHash
  SetupSHA256=$expectedSetup
  NoHKLMModificationByChild=$true;NoOtherUserFilesInspected=$true
  PublicVersionUnchanged=$true;NoOwnerPersonalPCUsed=$true
  UTC=[DateTime]::UtcNow.ToString('o')
 }
 [IO.File]::WriteAllText($out,($record|ConvertTo-Json -Depth 7),[Text.UTF8Encoding]::new($false))
}
if($state -notlike 'PASS_*'){throw ('R262_OTHER_USER_REAL_SETUP_FAILED '+$phase+' '+$failure)}
