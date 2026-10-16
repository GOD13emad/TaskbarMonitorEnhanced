[CmdletBinding()]
param([Parameter(Mandatory=$true)][ValidateSet('A','B')][string]$HostLabel)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# One scoped negative experiment on a fresh, disposable GitHub-hosted Windows VM.
# Only creates and removes a PREVIOUSLY-ABSENT, synthetic HKLM uninstall subkey
# in one specified registry view. No real other-account, device driver or owner PC edits.
if($env:GITHUB_ACTIONS -cne 'true' -or
   $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
   $env:RUNNER_OS -cne 'Windows' -or
   $env:GITHUB_REPOSITORY -cne 'GOD13emad/TaskbarMonitorEnhanced' -or
   $env:GITHUB_REF -cne 'refs/heads/audit/r261-machinewide-hklm-collision' -or
   $env:COMPUTERNAME -match '(?i)EMAD|ALI|LAPTOP'){
  throw 'R261_REFUSE_OWNER_OR_NON_DISPOSABLE_GITHUB_VM'
}
$admin=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if(-not $admin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
  throw 'R261_GUEST_REQUIRES_GENUINE_ADMIN_RIGHTS_NO_ELEVATION_ATTEMPT'
}
$repo='GOD13emad/TaskbarMonitorEnhanced'
$version='1.7.4'
$expectedSetup='C00F0C944E4BFBEE93989E4B5A29931D460CC0011ABDC8FDE6A498E467BCC1A1'
$expectedMain='279DF6276973D45A1F979792718E7BA1A9DB31A44C3C34E7335C7BE1503A3E3C'
$registryPath='SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\TaskbarMonitorEnhanced'
$registryView=if($HostLabel -ceq 'A'){[Microsoft.Win32.RegistryView]::Registry64}else{[Microsoft.Win32.RegistryView]::Registry32}
$otherView=if($HostLabel -ceq 'A'){[Microsoft.Win32.RegistryView]::Registry32}else{[Microsoft.Win32.RegistryView]::Registry64}
$app=Join-Path $env:LOCALAPPDATA 'TaskbarMonitorEnhanced'
$uninstall='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TaskbarMonitorEnhanced'
$out=Join-Path $env:RUNNER_TEMP ('TBME_R261_'+$HostLabel)
$receipt=Join-Path $out 'R261_HKLM_DIAGNOSTIC.json'
$setup=Join-Path $out 'TaskbarMonitorEnhanced_Setup_1.7.4.exe'
$canary=Join-Path $app 'R261_GUEST_USER_SENTINEL.txt'
$status='FAIL_NOT_ACCEPTED'
$phase='PREFLIGHT'
$failure=''
$injected=$false
$cleaned=$false
$baseline=@{}
$setupExit=$null
$updateExit=$null
$hklmKeyNames=@()
$viewKey=$null
$hive=$null
$otherHive=$null
$machineMarker='R261 SYNTHETIC machinewide registration ONLY; no executable or other user exists'
$values=[ordered]@{
 DisplayName='Taskbar Monitor Enhanced'
 DisplayVersion='1.7.4'
 InstallLocation='C:\R261_SYNTHETIC_OTHER_MACHINE_ROOT'
 R261Ownership=$machineMarker
}
function Deny([string]$reason){throw ('R261_'+$reason)}
function SHA([string]$f){
 if(-not (Test-Path -LiteralPath $f -PathType Leaf)){return 'ABSENT'}
 return (Get-FileHash -LiteralPath $f -Algorithm SHA256 -ErrorAction Stop).Hash
}
function RealSetup([string]$args){
 $psi=[Diagnostics.ProcessStartInfo]::new()
 $psi.FileName=$setup
 $psi.Arguments=$args
 $psi.WorkingDirectory=$out
 $psi.UseShellExecute=$false
 $psi.CreateNoWindow=$true
 $proc=[Diagnostics.Process]::Start($psi)
 if($null -eq $proc){Deny 'INSTALLER_PROCESS_FAILED_TO_START'}
 try{
  if(-not $proc.WaitForExit(180000)){Deny ('SETUP_TIMEOUT_'+$proc.Id)}
  return [int]$proc.ExitCode
 }finally{$proc.Dispose()}
}
function Snapshot {
 $paths=@('TaskbarMonitorEnhanced.exe','Uninstall.exe',
  'Source/TaskbarMonitorEnhanced.cs','install_state.json','config.json',
  'config.json.bak','R261_GUEST_USER_SENTINEL.txt')
 $snap=@{}
 foreach($item in $paths){$snap[$item]=SHA (Join-Path $app $item)}
 return $snap
}
function AssertSame($old,[string]$phaseName){
 $new=Snapshot
 foreach($name in $old.Keys){
  if($old[$name] -cne $new[$name]){Deny ('USER_DATA_OR_MANAGED_CHANGE_'+$phaseName+'_'+$name)}
 }
 if((Get-ItemProperty $uninstall -ErrorAction Stop).DisplayVersion -cne $version){Deny 'HKCU_VERSION_CHANGED'}
}
function CheckSyntheticKey {
 $k=$hive.OpenSubKey($registryPath,$false)
 if($null -eq $k){Deny 'OWNED_HKLM_REGISTRATION_MISSING'}
 try{
  if(@($k.GetSubKeyNames()).Count -ne 0){Deny 'OTHER_SUBKEY_ADDED_UNDER_SYNTHETIC_REG'}
  $keyNames=@($k.GetValueNames())
  if($keyNames.Count -ne $values.Count -or @($keyNames|Where-Object {$_ -notin $values.Keys}).Count){
    Deny 'UNKNOWN_VALUE_ADDED_UNDER_SYNTHETIC_REG'
  }
  foreach($name in $values.Keys){
   if([string]$k.GetValue($name) -cne [string]$values[$name] -or
      $k.GetValueKind($name) -ne [Microsoft.Win32.RegistryValueKind]::String){
    Deny ('OWNED_HKLM_VALUE_CHANGED_'+$name)
   }
  }
 }finally{$k.Dispose()}
}
if((Test-Path $out) -or (Test-Path $app) -or
   (Test-Path $uninstall) -or
   @(Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count){
 Deny 'DISPOSABLE_HOST_NOT_FRESH'
}
$hive=[Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,$registryView)
$otherHive=[Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,$otherView)
try{
 if($null -ne $hive.OpenSubKey($registryPath,$false) -or
    $null -ne $otherHive.OpenSubKey($registryPath,$false)){
  Deny 'REAL_OR_EXISTING_HKLM_PRODUCT_REGISTRATION_MUST_NEVER_BE_OVERWRITTEN'
 }
 $phase='DOWNLOAD_PINNED_IMMUTABLE_OFFICIAL_174'
 [void](New-Item $out -ItemType Directory -ErrorAction Stop)
 & gh release download 'v1.7.4' --repo $repo --pattern 'TaskbarMonitorEnhanced_Setup_1.7.4.exe' --dir $out
 if($LASTEXITCODE -ne 0 -or (SHA $setup) -cne $expectedSetup){Deny 'PUBLISHED_SETUP_DIGEST_OR_DOWNLOAD_INVALID'}
 $phase='WRITE_ONLY_OWNED_HKLM_VIEW_MARKER'
 $viewKey=$hive.CreateSubKey($registryPath,[Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree)
 if($null -eq $viewKey){Deny 'CANNOT_CREATE_SYNTHETIC_HKLM_KEY'}
 $injected=$true
 foreach($name in $values.Keys){
  $viewKey.SetValue($name,[string]$values[$name],[Microsoft.Win32.RegistryValueKind]::String)
 }
 $viewKey.Flush()
 $viewKey.Dispose()
 $viewKey=$null
 CheckSyntheticKey
 if($null -ne $otherHive.OpenSubKey($registryPath,$false)){Deny 'OTHER_HKLM_VIEW_UNEXPECTEDLY_AFFECTED'}
 $phase='TRY_REAL_OFFICIAL_FRESH_PER_USER_WITH_HKLM_REG_PRESENT'
 $setupExit=RealSetup '/install /quiet /desktop=0 /startup=0'
 # The current accepted public installer is per-user and checks HKCU on fresh
 # installation. This records actual behavior; an HKLM synthetic registration is
 # NOT proof that a real second program executable was installed.
 if($setupExit -ne 0 -and $setupExit -ne 34){
  Deny ('UNEXPECTED_REAL_FRESH_INSTALL_EXIT_'+$setupExit)
 }
 if($setupExit -eq 0){
  if((SHA (Join-Path $app 'TaskbarMonitorEnhanced.exe')) -cne $expectedMain -or
     (SHA (Join-Path $app 'Uninstall.exe')) -cne $expectedSetup){
    Deny 'NEW_PERUSER_INSTALL_PRODUCT_BYTES_NOT_OFFICIAL'
  }
  if((Get-ItemProperty $uninstall -ErrorAction Stop).DisplayVersion -cne $version){
    Deny 'NEW_PERUSER_REGISTER_NOT_OFFICIAL'
  }
  if(Test-Path (Join-Path $app 'TaskbarMonitorEnhanced.cs')){
    Deny 'NEW_INSTALL_RECREATED_REDUNDANT_ROOT_SOURCE'
  }
  $cfg=Join-Path $app 'config.json'
  $oldCfg=Join-Path $app 'config.json.bak'
  if(-not (Test-Path $cfg)){
   [IO.File]::WriteAllText($cfg,'{"GlassMode":true,"Opacity":0,"OpacityWhenGlassOff":0.1,"R261Fixture":"own current settings"}',[Text.UTF8Encoding]::new($false))
  }
  if(-not (Test-Path $oldCfg)){
   [IO.File]::WriteAllText($oldCfg,'{"R261OldConfigBackup":"retain exact previous bytes"}',[Text.UTF8Encoding]::new($false))
  }
  [IO.File]::WriteAllText($canary,'R261 guest user-owned canary; no owner personal data',[Text.UTF8Encoding]::new($false))
  $baseline=Snapshot
  if(@($baseline.Values|Where-Object {$_ -ceq 'ABSENT'}).Count){Deny 'USER_FIXTURE_INCOMPLETE'}
  CheckSyntheticKey
  $phase='VERIFY_EXISTING_UPDATE_WITH_HKLM_REG_PRESENT'
  $updateExit=RealSetup '/update /quiet'
  if($updateExit -ne 0 -and $updateExit -ne 34){Deny ('UNEXPECTED_UPDATE_EXIT_WITH_HKLM_REG_'+$updateExit)}
  AssertSame $baseline 'WHILE_HKLM_MARKER_EXISTS'
 }
 $phase='REMOVE_OWNED_HKLM_MARKER_ONLY'
 CheckSyntheticKey
 $hive.DeleteSubKey($registryPath,$true)
 $injected=$false
 if($null -ne $hive.OpenSubKey($registryPath,$false)){Deny 'REGISTRY_OWNED_KEY_REMAINS'}
 $cleaned=$true
 if($setupExit -eq 0){
  $phase='RETRY_IDEMPOTENT_USER_UPDATE_AFTER_HKLM_MARKER_REMOVED'
  $after=RealSetup '/update /quiet'
  if($after -ne 0){Deny ('POST_FIXTURE_SAME_VERSION_UPDATE_FAILED_'+$after)}
  AssertSame $baseline 'AFTER_HKLM_MARKER_REMOVED'
 }
 $status=if($setupExit -eq 0){
  'PASS_DIAGNOSTIC_OFFICIAL_FRESH_INSTALL_ACCEPTS_SYNTHETIC_HKLM_OTHER_VIEW_REGISTRATION'
 }else{
  'PASS_DIAGNOSTIC_OFFICIAL_FRESH_INSTALL_REFUSES_SYNTHETIC_HKLM_REGISTRATION'
 }
}catch{
 $failure=$_.Exception.GetType().Name+': '+$_.Exception.Message
}finally{
 try{
  if($null -ne $viewKey){$viewKey.Dispose();$viewKey=$null}
  if($injected){
   # Don't delete an owned synthetic key if any unknown content has been added.
   CheckSyntheticKey
   $hive.DeleteSubKey($registryPath,$true)
   $cleaned=($null -eq $hive.OpenSubKey($registryPath,$false))
  }
 }catch{
  $failure += ' | CLEANUP_NOT_POSSIBLE_WITHOUT_DESTROYING_UNTRUSTED_DATA '+$_.Exception.Message
  $status='FAIL_CLEANUP_UNCERTAIN'
 }
 if($null -ne $hive){$hive.Dispose()}
 if($null -ne $otherHive){$otherHive.Dispose()}
 if(Test-Path $out){
  $rec=[ordered]@{Revision='R261';Status=$status;Host=$HostLabel
   RegistryView=[string]$registryView;OtherView=[string]$otherView
   Phase=$phase;Failure=$failure;OfficialTag='v1.7.4'
   SetupSHA256=$expectedSetup;MainSHA256=$expectedMain
   SyntheticHKLMUninstallOnly=$true;DifferentRealUserAccountTested=$false
   OtherMachineExePresent=$false;RegistryOnlyDoesNotProveSecondActualInstall=$true
   ActualFreshSetupExit=$setupExit;ActualSameVersionUpdateWithHKLM=$updateExit
   SyntheticRegistryMarkerCleaned=$cleaned
   UserOwnedCanaryAndBackupPreserved=($status -like 'PASS_*' -and $setupExit -eq 0)
   PublicReleaseChanged=$false;OwnerPersonalPCChanged=$false
   ActualMultiuserHKLMUniquenessGateAccepted=$false
   UTC=[DateTime]::UtcNow.ToString('o')
  }
  [IO.File]::WriteAllText($receipt,($rec|ConvertTo-Json -Depth 7),[Text.UTF8Encoding]::new($false))
  Write-Output ($rec|ConvertTo-Json -Compress -Depth 7)
 }
}
if($status -notlike 'PASS_*' -or -not $cleaned){
 throw ('R261_GUEST_HKLM_DIAGNOSTIC_NOT_ACCEPTED_'+$phase+'_'+$failure)
}
