# R95: Fresh install must refuse any competing root, orphaned profile or existing shortcut.
# ONLY a clean disposable Windows hosted CI; self-owned fixtures are SHA-verified before removal.
[CmdletBinding()]
param([switch]$StaticOnly)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$NewSetupSHA='63B811A5343C4FD066F39927F428C1F49CF2581A9348FF281B3260E0C860A5ED'
$NewMainSHA='63A724981E949BA4C91F8BD44F2659F223BDFE0350A2E229CEE7B05535D4BA70'
$AppRoot=Join-Path $env:LOCALAPPDATA 'TaskbarMonitorEnhanced'
$AppExe=Join-Path $AppRoot 'TaskbarMonitorEnhanced.exe'
$UninstallKey='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TaskbarMonitorEnhanced'
$ProgramFilesRoot=Join-Path $env:ProgramFiles 'TaskbarMonitorEnhanced'
$ProgramFilesExe=Join-Path $ProgramFilesRoot 'TaskbarMonitorEnhanced.exe'
$StartMenuLink=Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::Programs)) 'Taskbar Monitor Enhanced.lnk'
$Setup=Join-Path $PSScriptRoot '_out\Setup\TaskbarMonitorEnhanced_Setup_1.7.0.exe'
if($StaticOnly){
    $tok=$null;$errors=$null
    [void][System.Management.Automation.Language.Parser]::ParseFile($PSCommandPath,[ref]$tok,[ref]$errors)
    if($errors.Count -gt 0){throw 'R95 STATIC PARSER FAILURE'}
    Write-Output 'R95_FRESH_INSTALL_NO_DUPLICATE_GUARD_STATIC_NO_MUTATION_PASS'
    exit 0
}
if($env:GITHUB_ACTIONS -cne 'true' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
   $env:RUNNER_OS -cne 'Windows' -or $env:COMPUTERNAME -ceq 'EMAD-PC-ULTIMAT' -or
   [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)){throw 'R95 REFUSE NONDISPOSABLE HOST'}
$Root=Join-Path $env:RUNNER_TEMP 'TBME_R95_NoDuplicate'
if(Test-Path -LiteralPath $Root){throw 'R95 NO UNSAFE RERUN/OVERWRITE'}
if((Test-Path -LiteralPath $AppRoot) -or (Test-Path $UninstallKey) -or
   (Test-Path -LiteralPath $StartMenuLink) -or
   (Test-Path -LiteralPath $ProgramFilesRoot) -or
   @(Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count -gt 0){
   throw 'R95 REFUSE PREEXISTING INSTALL OR USER DATA ON HOST'
}
if(!(Test-Path -LiteralPath $Setup -PathType Leaf) -or
  (Get-FileHash $Setup).Hash -cne $NewSetupSHA -or
  (Get-AuthenticodeSignature $Setup).Status -ne 'NotSigned'){
  throw 'R95 EXACT UNSIGNED CANDIDATE PRESTATE NOT VALID'
}
New-Item -ItemType Directory -Path $Root -ErrorAction Stop|Out-Null
$ReceiptPath=Join-Path $Root 'R95_NO_DUPLICATE_RECEIPT.json'
$Started=(Get-Date).ToUniversalTime().ToString('o')
$Status='NOT_TESTED';$Phase='PRESTATE';$Failure=''
$OrphanRefused=$false;$ProgramFilesRefused=$false;$ShortcutRefused=$false;$FreshPass=$false;$Idempotent=$false
$NoUnknownDeleted=$true;$OrphanHash='';$MachineConflictHash='';$ShortcutHash='';$SetupSelfcheck=''
function HashFile([string]$Path){
 if(!(Test-Path -LiteralPath $Path -PathType Leaf)){throw ('R95 HASH_INPUT_MISSING '+$Path)}
 return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}
function StartBounded([string]$File,[string[]]$ChildArguments,[int]$TimeoutMs){
 if($null -eq $ChildArguments -or $ChildArguments.Count -lt 1){throw 'R95 ARGUMENT_ARRAY_NOT_FORWARDED'}
 $psi=[Diagnostics.ProcessStartInfo]::new()
 $psi.FileName=$File;$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true
 foreach($arg in $ChildArguments){[void]$psi.ArgumentList.Add($arg)}
 if($psi.ArgumentList.Count -ne $ChildArguments.Count){throw 'R95 CHILD_ARG_COUNT_DIFFERENT'}
 $p=$null
 try{
   $p=[Diagnostics.Process]::Start($psi)
   if($null -eq $p){throw 'R95 CANNOT_START_CHILD'}
   if(!$p.WaitForExit($TimeoutMs)){
      try{$p.Kill();$p.WaitForExit(2000)}catch{}
      throw ('R95 CI-ONLY CHILD TIMEOUT '+$File)
   }
   return [int]$p.ExitCode
 }finally{if($p){$p.Dispose()}}
}
function AssertNoApp {
 $runBag=Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue
 $runValue=if($null -ne $runBag){$runBag.PSObject.Properties['TaskbarMonitorEnhanced']}else{$null}
 if((Test-Path -LiteralPath $AppExe -PathType Leaf) -or (Test-Path $UninstallKey) -or
    $null -ne $runValue){
   throw 'R95 NEGATIVE FRESH TEST LEFT APP/REGISTRATION/STARTUP'
 }
}
try{
 $Phase='SETUP_READONLY_VERIFY'
 $verify=Join-Path $Root 'SETUP_VERIFY.json'
 $result=StartBounded $Setup @('/verify',('/verifyfile='+$verify)) 30000
 if($result -ne 0 -or !(Test-Path -LiteralPath $verify -PathType Leaf)){throw 'R95 SETUP_SELF_VERIFY_MISSING'}
 $v=Get-Content -LiteralPath $verify -Raw|ConvertFrom-Json
 if($v.Status -cne 'PASS' -or $v.Resources -ne 25 -or $v.PawnIOBundled -ne $false -or
    $v.EmbeddedMainSHA256 -cne $NewMainSHA){throw 'R95 EXACT EMBEDDED MAIN AND 25 RESOURCES NOT ACCEPTED'}
 $SetupSelfcheck=HashFile $verify

 $Phase='REFUSE_ORPHANED_PERUSER_PROFILE_WITH_USER_FILE'
 New-Item -ItemType Directory -Path $AppRoot -ErrorAction Stop|Out-Null
 $owned=Join-Path $AppRoot 'R95_CI_ONLY_EXISTING_USER_PREFS.txt'
 [IO.File]::WriteAllText($owned,'R95_ORPHAN_DO_NOT_OVERWRITE_THESE_USER_BYTES',[Text.UTF8Encoding]::new($false))
 $OrphanHash=HashFile $owned
 $return=StartBounded $Setup @('/install','/quiet','/desktop=0','/startup=0') 30000
 if($return -ne 30 -or (HashFile $owned) -cne $OrphanHash){throw ('R95 ORPHAN REFUSAL OR BYTE PRESERVATION FAILED EXIT '+$return)}
 AssertNoApp
 $OrphanRefused=$true
 # Remove ONLY the exact synthetic CI fixture that this test created.
 $objects=@(Get-ChildItem -LiteralPath $AppRoot -Force)
 if($objects.Count -ne 1 -or $objects[0].FullName -cne $owned -or (HashFile $owned) -cne $OrphanHash){throw 'R95 CI-ONLY ORPHAN DATA CHANGED - DO NOT CLEAN'}
 Remove-Item -LiteralPath $owned -ErrorAction Stop
 Remove-Item -LiteralPath $AppRoot -ErrorAction Stop
 if(Test-Path -LiteralPath $AppRoot){throw 'R95 TEST-ONLY APPROOT STILL EXISTS'}

 $Phase='REFUSE_CONFLICTING_PROGRAMFILES_PRODUCT'
 New-Item -ItemType Directory -Path $ProgramFilesRoot -ErrorAction Stop|Out-Null
 [IO.File]::WriteAllText($ProgramFilesExe,'R95_CI_ONLY_EXISTING_MACHINE_WIDE_PRODUCT_DO_NOT_TOUCH',[Text.UTF8Encoding]::new($false))
 $MachineConflictHash=HashFile $ProgramFilesExe
 $return=StartBounded $Setup @('/install','/quiet','/desktop=0','/startup=0') 30000
 if($return -ne 30 -or (HashFile $ProgramFilesExe) -cne $MachineConflictHash){throw ('R95 MACHINE-WIDE REFUSAL FAILED CODE '+$return)}
 AssertNoApp
 if(Test-Path -LiteralPath $AppRoot){throw 'R95 CREATED SECOND APPROOT NEXT TO PROGRAMFILES'}
 $ProgramFilesRefused=$true
 $other=@(Get-ChildItem -LiteralPath $ProgramFilesRoot -Force)
 if($other.Count -ne 1 -or $other[0].FullName -cne $ProgramFilesExe -or
    (HashFile $ProgramFilesExe) -cne $MachineConflictHash){throw 'R95 OWNED PROGRAMFILES FIXTURE CHANGED - DO NOT TOUCH'}
 Remove-Item -LiteralPath $ProgramFilesExe -ErrorAction Stop
 Remove-Item -LiteralPath $ProgramFilesRoot -ErrorAction Stop
 if(Test-Path -LiteralPath $ProgramFilesRoot){throw 'R95 OWNED MACHINE FIXTURE NOT CLEAN'}

 $Phase='REFUSE_EXISTING_STARTMENU_PRODUCT_SHORTCUT'
 if(Test-Path -LiteralPath $StartMenuLink){throw 'R95 STARTMENU PREEXISTS UNEXPECTEDLY'}
 [IO.File]::WriteAllText($StartMenuLink,'R95_CI_OWNED_EXISTING_SHORTCUT_DO_NOT_OVERWRITE',[Text.UTF8Encoding]::new($false))
 $ShortcutHash=HashFile $StartMenuLink
 $return=StartBounded $Setup @('/install','/quiet','/desktop=0','/startup=0') 30000
 if($return -ne 30 -or (HashFile $StartMenuLink) -cne $ShortcutHash){throw ('R95 SHORTCUT CONFLICT REFUSAL FAILED EXIT '+$return)}
 AssertNoApp
 if(Test-Path -LiteralPath $AppRoot){throw 'R95 SHORTCUT CONFLICT GENERATED APPROOT'}
 $ShortcutRefused=$true
 if((HashFile $StartMenuLink) -cne $ShortcutHash){throw 'R95 SHORTCUT FIXTURE CHANGED BEFORE OWNED CLEANUP'}
 Remove-Item -LiteralPath $StartMenuLink -ErrorAction Stop

 $Phase='SINGLE_CANONICAL_FRESH_INSTALL_POSITIVE'
 $return=StartBounded $Setup @('/install','/quiet','/desktop=0','/startup=0') 180000
 if($return -ne 0 -or (HashFile $AppExe) -cne $NewMainSHA -or
    (Get-ItemProperty $UninstallKey).DisplayVersion -cne '1.7.0'){throw 'R95 NO-COLLISION FRESH INSTALL FAILED'}
 if((HashFile (Join-Path $AppRoot 'Uninstall.exe')) -cne $NewSetupSHA){throw 'R95 EXACT CURRENT MAINTENANCE FILE NOT INSTALLED'}
 $links=@(Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall' -ErrorAction SilentlyContinue|Where-Object PSChildName -ceq 'TaskbarMonitorEnhanced')
 if($links.Count -ne 1 -or (Test-Path -LiteralPath $ProgramFilesExe)){throw 'R95 FRESH INSTALLED SECOND ROOT'}
 $FreshPass=$true

 $Phase='INPLACE_NOOP_REINSTALL_SAME_SEMVER'
 $state=Join-Path $AppRoot 'install_state.json'
 $shaState=HashFile $state
 $return=StartBounded $Setup @('/install','/quiet','/desktop=0','/startup=0') 30000
 if($return -ne 0 -or (HashFile $AppExe) -cne $NewMainSHA -or
    (HashFile $state) -cne $shaState -or
    (Get-ItemProperty $UninstallKey).DisplayVersion -cne '1.7.0' -or
    (Test-Path -LiteralPath (Join-Path $AppRoot '.tbme-upgrade'))){throw 'R95 EXISTING APP RECEIVED DUPLICATE OR REINSTALL'}
 $Idempotent=$true
 $Status='PASS_THREE_NEGATIVE_DUPLICATE_CONFLICTS_ONE_POSITIVE_FRESH_AND_IDEMPOTENT'
 $Phase='COMPLETE'
}catch{
 $Failure=$_.Exception.ToString();$Status='FAIL_CLOSED_R95_FRESH_INSTALL_CONFLICT'
}finally{
 $receipt=[ordered]@{
   Schema=1;Revision='R95';Status=$Status;Phase=$Phase
   TestSourceSHA=$env:GITHUB_SHA;Host='GITHUB_HOSTED_EPHEMERAL_WINDOWS'
   ExactCandidateSHA256=$NewSetupSHA;EmbeddedMainSHA256=$NewMainSHA
   OrphanedUserDataRefused=$OrphanRefused;CompetingProgramFilesRefused=$ProgramFilesRefused
   ExistingShortcutRefused=$ShortcutRefused;FreshUniqueRootInstalled=$FreshPass
   InPlaceSameVersionNoop=$Idempotent
   SetupVerifySHA256=$SetupSelfcheck
   OrphanSentinelSHA256=$OrphanHash;MachineConflictSentinelSHA256=$MachineConflictHash
   ShortcutSentinelSHA256=$ShortcutHash;UnknownPersonalDataDeleted=$false
   TestOwnedSyntheticFixturesCleaned=($Status -like 'PASS*');OtherHostsInstalledOrDeleted=$false
   FormalStableG13G14G16Accepted=$false
   StartedUTC=$Started;FinishedUTC=(Get-Date).ToUniversalTime().ToString('o');Error=$Failure
 }
 $receipt|ConvertTo-Json -Depth 7|Set-Content -LiteralPath $ReceiptPath -Encoding utf8
 Write-Output ('R95_RAW_DUPLICATE_GUARD_RECEIPT='+$ReceiptPath+' STATUS='+$Status+' PHASE='+$Phase)
}
if($Failure){throw ('R95 FRESH NO-DUPLICATE WITNESS FAILED '+$Phase+' '+$Failure)}
Write-Output 'R95_ACTUAL_EPHEMERAL_FRESH_INSTALL_CONFLICT_GUARD_AND_SINGLE_ROOT_PASS'
exit 0
