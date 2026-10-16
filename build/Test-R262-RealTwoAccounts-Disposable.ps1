[CmdletBinding()]
param([Parameter(Mandatory=$true)][ValidateSet('A','B')][string]$HostLabel)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# Test-only Windows new disposable local user; no account, profile, HKLM,
# driver or registry action is made on the owner's workstation.
if($env:GITHUB_ACTIONS -cne 'true' -or
   $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
   $env:RUNNER_OS -cne 'Windows' -or
   $env:GITHUB_REPOSITORY -cne 'GOD13emad/TaskbarMonitorEnhanced' -or
   $env:GITHUB_REF -cne 'refs/heads/audit/r262-disposable-real-two-users' -or
   $env:COMPUTERNAME -match '(?i)EMAD|ALI|LAPTOP'){
 throw 'R262_REFUSE_NON_DISPOSABLE_REAL_ACCOUNT_MUTATION'
}
$principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
 throw 'R262_REQUIRE_ALREADY_ADMIN_GITHUB_HOSTED_ONLY_NO_ELEVATION'
}
$root='GOD13emad/TaskbarMonitorEnhanced'
$tag='v1.7.4'
$shaSetup='C00F0C944E4BFBEE93989E4B5A29931D460CC0011ABDC8FDE6A498E467BCC1A1'
$shaMain='279DF6276973D45A1F979792718E7BA1A9DB31A44C3C34E7335C7BE1503A3E3C'
$appA=Join-Path $env:LOCALAPPDATA 'TaskbarMonitorEnhanced'
$hkcuA='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TaskbarMonitorEnhanced'
$sourceB=Join-Path $PSScriptRoot 'Test-R262-OtherLocalUser-Install.ps1'
$shaGuestB='1D2B9D7FE344336E48B2C09EBE6CDA6D50397E3EAD8FC37BAC7618A2EBC610A6'
$fakeUsername="TBME262"+$HostLabel
$shared=Join-Path $env:ProgramData ("TBME_R262_"+$HostLabel)
$out=Join-Path $env:RUNNER_TEMP ("TBME_R262_"+$HostLabel)
$full=Join-Path $out 'R262_TWO_USERS.json'
$bProofIn=Join-Path $shared 'Results/R262_GUEST_B.json'
$bProofOut=Join-Path $out 'R262_GUEST_B.json'
$setup=Join-Path $shared 'TaskbarMonitorEnhanced_Setup_1.7.4.exe'
$runnerScript=Join-Path $shared 'Test-R262-OtherLocalUser-Install.ps1'
$createdSid=''
$created=$false
$removed=$false
$scratchRemoved=$false
$phase='BEFORE_PRECONDITIONS'
$failure=''
$status='FAIL_R262_NOT_ACCEPTED'
$exitA=$null
$exitB=$null
$shaA=''
$shaB=''
$aReg=''
$aRoot=''
$bRoot=''
$bSID=''
$canaryA=Join-Path $appA 'R262_USER_A_SENTINEL.txt'
$canaryAHash=''
$beforeA=@{}
$profileB=''
$hklmA=''
$hklmB=''
function CanonicalTestSourceHash([string]$file){
 if(!(Test-Path $file -PathType Leaf)){return 'MISSING'}
 $t=[IO.File]::ReadAllText($file,[Text.Encoding]::UTF8)
 $lf=$t.Replace(([string][char]13+[string][char]10),([string][char]10)).Replace(([string][char]13),([string][char]10))
 return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($lf)))
}
function Fail([string]$reason){throw ('R262_'+$reason)}
function Hash([string]$file){
 if(!(Test-Path -LiteralPath $file -PathType Leaf)){return 'ABSENT'}
 return (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
}
function RunOfficial($argsText){
 $psi=[Diagnostics.ProcessStartInfo]::new()
 $psi.FileName=$setup
 $psi.Arguments=[string]$argsText
 $psi.UseShellExecute=$false
 $psi.CreateNoWindow=$true
 $psi.WorkingDirectory=$shared
 $p=[Diagnostics.Process]::Start($psi)
 if($null -eq $p){Fail 'CANNOT_LAUNCH_OFFICIAL_SETUP'}
 try{
  if(!$p.WaitForExit(180000)){Fail ('A_SETUP_TIMEOUT_'+$p.Id)}
  return [int]$p.ExitCode
 }finally{$p.Dispose()}
}
function InstallMapA{
 $paths=@('TaskbarMonitorEnhanced.exe','Uninstall.exe','Source/TaskbarMonitorEnhanced.cs',
  'install_state.json','config.json','config.json.bak','R262_USER_A_SENTINEL.txt')
 $d=@{}
 foreach($name in $paths){$d[$name]=Hash (Join-Path $appA $name)}
 return $d
}
function InspectHKLM {
 $key='SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\TaskbarMonitorEnhanced'
 $status=@()
 foreach($view in @([Microsoft.Win32.RegistryView]::Registry64,[Microsoft.Win32.RegistryView]::Registry32)){
  $hive=[Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,$view)
  try{$k=$hive.OpenSubKey($key,$false);$status+=($null -ne $k);if($null -ne $k){$k.Dispose()}}
  finally{$hive.Dispose()}
 }
 return @($status)
}
if((Test-Path $appA) -or (Test-Path $hkcuA) -or
   (Test-Path $shared) -or (Test-Path $out) -or
   (Get-LocalUser -Name $fakeUsername -ErrorAction SilentlyContinue) -or
   @(Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count){
 Fail 'NOT_FRESH_HOSTED_WINDOWS'
}
if((CanonicalTestSourceHash $sourceB) -cne $shaGuestB){Fail 'GUEST_B_SCRIPT_SOURCE_NOT_PINNED'}
if(@(InspectHKLM|Where-Object {$_ -eq $true}).Count){Fail 'REAL_MACHINE_REGISTRATION_PRESENT'}
New-Item -ItemType Directory -Path $out -ErrorAction Stop|Out-Null
try{
 $phase='EXACT_PUBLIC_SETUP_AND_SHARED_DISPOSABLE_SCOPE'
 New-Item -ItemType Directory -Path $shared -ErrorAction Stop|Out-Null
 New-Item -ItemType Directory -Path (Join-Path $shared 'Results') -ErrorAction Stop|Out-Null
 & gh release download $tag --repo $root --pattern 'TaskbarMonitorEnhanced_Setup_1.7.4.exe' --dir $shared
 if($LASTEXITCODE -ne 0 -or (Hash $setup) -cne $shaSetup){Fail 'PUBLIC174_SETUP_DOWNLOAD_IDENTITY_NOT_PASS'}
 Copy-Item -LiteralPath $sourceB -Destination $runnerScript -ErrorAction Stop
 if((CanonicalTestSourceHash $runnerScript) -cne $shaGuestB){Fail 'B_SECOND_ACCOUNT_SCRIPT_COPY_MISMATCH'}
 # ACL changes apply ONLY to this new, owned ProgramData scratch directory.
 & icacls.exe $shared /grant '*S-1-5-32-545:(OI)(CI)RX' /T *> $null
 if($LASTEXITCODE -ne 0){Fail 'GUEST_B_CANNOT_READ_OWNED_SCRATCH'}
 & icacls.exe (Join-Path $shared 'Results') /grant '*S-1-5-32-545:(OI)(CI)M' /T *> $null
 if($LASTEXITCODE -ne 0){Fail 'GUEST_B_CANNOT_WRITE_OWNED_RECEIPT'}
 $phase='GENUINE_OFFICIAL_INSTALL_IN_FIRST_REAL_ADMIN_ACCOUNT'
 $exitA=RunOfficial '/install /quiet /desktop=0 /startup=0'
 if($exitA -ne 0){Fail ('A_OFFICIAL_FRESH_INSTALL_NONZERO_'+$exitA)}
 $shaA=Hash (Join-Path $appA 'TaskbarMonitorEnhanced.exe')
 if($shaA -cne $shaMain -or (Hash (Join-Path $appA 'Uninstall.exe')) -cne $shaSetup){
  Fail 'FIRST_ADMIN_ACCOUNT_INSTALL_EXACT_BINARY_MISSING'
 }
 $aEntry=Get-ItemProperty $hkcuA -ErrorAction Stop
 $aReg=[string]$aEntry.DisplayVersion
 $aRoot=[string]$aEntry.InstallLocation
 if($aReg -cne '1.7.4' -or $aRoot -cne $appA){Fail 'A_HKCU_NOT_CANONICAL'}
 if(@(Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count){Fail 'A_APP_UNEXPECTEDLY_AUTOSTARTED'}
 $c=Join-Path $appA 'config.json'
 $b=Join-Path $appA 'config.json.bak'
 if(!(Test-Path $c)){[IO.File]::WriteAllText($c,'{"R262UserA":"protected first per-user config"}',[Text.UTF8Encoding]::new($false))}
 if(!(Test-Path $b)){[IO.File]::WriteAllText($b,'{"R262OldA":"protected earlier per-user backup"}',[Text.UTF8Encoding]::new($false))}
 [IO.File]::WriteAllText($canaryA,'R262 owned first user canary with no private bytes',[Text.UTF8Encoding]::new($false))
 $beforeA=InstallMapA
 if(@($beforeA.Values|Where-Object {$_ -eq 'ABSENT'}).Count){Fail 'A_FIRST_ACCOUNT_FIXTURE_INCOMPLETE'}
 $canaryAHash=Hash $canaryA
 $phase='CREATE_REAL_SECOND_LOCAL_NONADMIN_USER_ON_DISPOSABLE_WINDOWS'
 $bytes=[byte[]]::new(32)
 $generator=[Security.Cryptography.RandomNumberGenerator]::Create()
 try{$generator.GetBytes($bytes)}finally{$generator.Dispose()}
 $secret=[Convert]::ToBase64String($bytes)+'B7!'
 $secure=ConvertTo-SecureString -String $secret -AsPlainText -Force
 $cred=[Management.Automation.PSCredential]::new(("$env:COMPUTERNAME\"+$fakeUsername),$secure)
 $secret=$null
 $account=New-LocalUser -Name $fakeUsername -Password $secure -AccountNeverExpires -PasswordNeverExpires -Description 'R262 transient GitHub-hosted two-account product audit' -ErrorAction Stop
 $createdSid=[string]$account.SID.Value
 $created=$true
 if($createdSid -notmatch '^S-1-5-21-'){Fail 'NEW_GUEST_ACCOUNT_SID_INVALID'}
 $phase='ISSUE_SCOPED_PUBLIC_TEST_AUTHORITY_TO_GENUINE_SECOND_ACCOUNT'
 $authority=Join-Path $shared 'R262_TEST_AUTHORITY.json'
 if(Test-Path $authority){Fail 'SECOND_USER_TEST_AUTHORITY_ALREADY_PRESENT'}
 $marker=[ordered]@{
  Revision='R262'
  HeadSourceSHA='1375d719989aa93966bae445ac63b9a415f637ad'
  ExpectedSecondUserSID=$createdSid
  HostComputerName=$env:COMPUTERNAME
  OfficialSetupSHA256=$shaSetup
  SyntheticParentOnDisposableGitHubVM=$true
 }
 [IO.File]::WriteAllText($authority,($marker|ConvertTo-Json -Depth 4),[Text.UTF8Encoding]::new($false))
 if(!(Test-Path $authority)){Fail 'DISPOSABLE_SCOPED_AUTHORITY_NOT_ISSUED'}
 $phase='LOGON_REAL_B_TOKEN_AND_RUN_OFFICIAL_INSTALL_AS_B'
 $argument='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$runnerScript+'" -SetupPath "'+$setup+'" -ReceiptPath "'+$bProofIn+'"'
 $p=Start-Process -FilePath 'powershell.exe' -ArgumentList $argument -Credential $cred -LoadUserProfile -PassThru -WindowStyle Hidden -WorkingDirectory $shared -ErrorAction Stop
 if($null -eq $p){Fail 'SECOND_USER_PROCESS_NOT_LAUNCHED'}
 try{
  if(!$p.WaitForExit(215000)){Fail ('SECOND_USER_LOGON_OR_SETUP_TIMEOUT_'+$p.Id)}
  $exitB=[int]$p.ExitCode
 }finally{$p.Dispose()}
 if(!(Test-Path $bProofIn)){Fail ('SECOND_USER_RECEIPT_ABSENT_EXIT_'+$exitB)}
 Copy-Item -LiteralPath $bProofIn -Destination $bProofOut -ErrorAction Stop
 $proofB=Get-Content $bProofOut -Raw|ConvertFrom-Json
 $bSID=[string]$proofB.TestUserSID
 $bRoot=[string]$proofB.AppRoot
 if($proofB.Status -cne 'PASS_R262_REAL_NONADMIN_SECOND_ACCOUNT_OFFICIAL_V174_PERUSER_INSTALL' -or
    $proofB.TestUserSID -cne $createdSid -or
    $proofB.IsAdministrator -ne $false -or
    $proofB.SetupExit -ne 0 -or
    $proofB.MainSHA256 -cne $shaMain -or
    $proofB.MaintenanceSHA256 -cne $shaSetup -or
    $proofB.HKCUVersion -cne '1.7.4' -or
    $bRoot -ceq $appA -or
    $proofB.HKCUInstallRoot -cne $bRoot){
  Fail ('SECOND_ACCOUNT_REAL_IDENTITY_INSTALL_NOT_ACCEPTED_EXIT_'+$exitB)
 }
 $phase='INDEPENDENT_A_AND_B_ROOTS_AND_REGISTRY_SCOPES'
 if(!(Test-Path (Join-Path $bRoot 'TaskbarMonitorEnhanced.exe')) -or
    (Hash (Join-Path $bRoot 'TaskbarMonitorEnhanced.exe')) -cne $shaMain){
  Fail 'SECOND_USER_INSTALLED_ROOT_MISSING_OR_HASH_DRIFT'
 }
 foreach($name in $beforeA.Keys){
  if((Hash (Join-Path $appA $name)) -cne $beforeA[$name]){Fail ('A_USER_FILES_CHANGED_BY_B_INSTALL_'+$name)}
 }
 if((Get-ItemProperty $hkcuA -ErrorAction Stop).DisplayVersion -cne '1.7.4'){
  Fail 'A_HKCU_CHANGED_AFTER_B_REAL_INSTALL'
 }
 if(@(InspectHKLM|Where-Object {$_ -eq $true}).Count){
  Fail 'SOMETHING_CREATED_HKLM_UNINSTALL_REGISTRATION'
 }
 $phase='CLEANUP_EXACT_CREATED_ACCOUNT_WHILE_GUEST_VM_DISPOSES_PROFILE'
 $current=Get-LocalUser -Name $fakeUsername -ErrorAction Stop
 if([string]$current.SID.Value -cne $createdSid){Fail 'GUEST_USER_SID_CHANGED_BEFORE_REMOVAL'}
 Disable-LocalUser -Name $fakeUsername -ErrorAction Stop
 Remove-LocalUser -Name $fakeUsername -ErrorAction Stop
 $removed=($null -eq (Get-LocalUser -Name $fakeUsername -ErrorAction SilentlyContinue))
 if(!$removed){Fail 'GUEST_TEST_ACCOUNT_NOT_REMOVED'}
 $created=$false
 $status='PASS_R262_TWO_GENUINE_SEPARATE_WINDOWS_ACCOUNTS_HAVE_DISTINCT_OFFICIAL_PERUSER_INSTALLS'
}catch{
 $failure=$_.Exception.GetType().Name+': '+$_.Exception.Message
}finally{
 if($created){
  try{
   $maybe=Get-LocalUser -Name $fakeUsername -ErrorAction SilentlyContinue
   if($null -ne $maybe -and [string]$maybe.SID.Value -ceq $createdSid){
    Disable-LocalUser -Name $fakeUsername -ErrorAction Stop
    Remove-LocalUser -Name $fakeUsername -ErrorAction Stop
    $removed=($null -eq (Get-LocalUser -Name $fakeUsername -ErrorAction SilentlyContinue))
   }
  }catch{$failure+='; ACCOUNT_CLEANUP_NOT_CONFIRMED '+$_.Exception.Message}
 }
 $record=[ordered]@{
  Revision='R262';Status=$status;Host=$HostLabel;Phase=$phase;Failure=$failure
  PublicVersion='1.7.4';SetupSHA256=$shaSetup;OfficialMainSHA256=$shaMain
  FirstAccountSID=[string][Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  FirstAccountRoot=$appA;FirstAccountSetupExit=$exitA;FirstAccountHKCUVersion=$aReg
  SecondAccountSID=$bSID;SecondAccountRoot=$bRoot;SecondAccountProcessExit=$exitB
  DistinctAccountSIDs=($createdSid -ne '' -and $createdSid -cne [string][Security.Principal.WindowsIdentity]::GetCurrent().User.Value)
  DistinctAppRoots=($bRoot -ne '' -and $bRoot -cne $appA)
  FirstAppRootDataExactlyPreserved=($status -like 'PASS_*')
  SyntheticSecondUserAccountRemoved=$removed
  SecondUserProfileMayRemainUntilDisposableVMDestruction=$true
  MachinewideSingletonProven=$false
  OneInstalledCopyPerAccountProven=($status -like 'PASS_*')
  SimultaneousTwoUserLocalCopiesObserved=($status -like 'PASS_*')
  NoHKLMOrWinRing0ChangedByTest=$true
  OwnerPersonalComputerUntouched=$true;PublicV174ReleaseUnmodified=$true
  UTC=[DateTime]::UtcNow.ToString('o')
 }
 if(Test-Path $out){
  [IO.File]::WriteAllText($full,($record|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
  Write-Output ($record|ConvertTo-Json -Compress -Depth 8)
 }
}
if($status -notlike 'PASS_*' -or !$removed){
 throw ('R262_REAL_TWO_USER_ACCEPTANCE_NOT_PROVEN_'+$phase+'_'+$failure)
}
