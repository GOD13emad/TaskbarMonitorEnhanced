[CmdletBinding()]
param([Parameter(Mandatory=$true)][ValidateSet("A","B")][string]$HostLabel)
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"

# Scoped disposable-only security/one-install collision test.
# No user accounts, HKLM or kernel drivers are created/changed by this harness.
if($env:GITHUB_ACTIONS -cne "true" -or
   $env:RUNNER_ENVIRONMENT -cne "github-hosted" -or
   $env:RUNNER_OS -cne "Windows" -or
   $env:GITHUB_REPOSITORY -cne "GOD13emad/TaskbarMonitorEnhanced" -or
   $env:GITHUB_REF -cne "refs/heads/audit/r254-disposable-programfiles-collision" -or
   $env:COMPUTERNAME -match "(?i)EMAD|ALI|LAPTOP" -or
   -not [Environment]::UserInteractive) {
    throw "R254_REFUSE_NON_DISPOSABLE_GITHUB_WINDOWS"
}
$sourceParent="6001fce0e7900f2a1ec5172224f4c75224f3ac69"
$tag="v1.7.3"
$setupExpected="9EB5C54B4AE4C36F4035F115AC87403D9238AC66AA9AFE58DC5B211311D9774B"
$mainExpected="6C8895C040D50C88AF6F6D018F9F70FB481C294B7DABCB083DB78EE35F5D8D1C"
$app=Join-Path $env:LOCALAPPDATA "TaskbarMonitorEnhanced"
$uninstall="HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TaskbarMonitorEnhanced"
$rootPath=if($HostLabel -ceq "A"){[Environment]::GetFolderPath("ProgramFiles")}else{[Environment]::GetFolderPath("ProgramFilesX86")}
if([String]::IsNullOrWhiteSpace($rootPath)){throw "R254_PROGRAMFILES_PATH_EMPTY"}
$legacy=Join-Path $rootPath "TaskbarMonitorEnhanced"
$legacyMain=Join-Path $legacy "TaskbarMonitorEnhanced.exe"
$out=Join-Path $env:RUNNER_TEMP ("TBME_R254_"+$HostLabel)
$receipt=Join-Path $out "R254_COLLISION.json"
$setup=Join-Path $out "TaskbarMonitorEnhanced_Setup_1.7.3.exe"
$canary=Join-Path $app "R254_USER_CANARY.txt"
$ownedLegacy=$false
$collisionInstalled=$false
$phase="PREFLIGHT"
$status="FAIL"
$errorText=""
$negativeExit=$null
$idempotentExit=$null
$stagedArtifactChecked=$false
$programFilesUnchanged=$false
$originalHashes=@{}
$originalRunValue=$null

function Fail([string]$message){throw ("R254_"+$message)}
function Hash([string]$path) {
 if(!(Test-Path -LiteralPath $path -PathType Leaf)){return "MISSING"}
 return (Get-FileHash -LiteralPath $path -Algorithm SHA256 -ErrorAction Stop).Hash
}
function Run-Setup([string]$arguments){
 $info=[Diagnostics.ProcessStartInfo]::new()
 $info.FileName=$setup
 $info.Arguments=$arguments
 $info.WorkingDirectory=$out
 $info.UseShellExecute=$false
 $info.CreateNoWindow=$true
 $process=[Diagnostics.Process]::Start($info)
 if($null -eq $process){Fail "SETUP_PROCESS_NULL"}
 try{
  if(!$process.WaitForExit(180000)){Fail ("SETUP_PROCESS_TIMEOUT_"+$process.Id)}
  return [int]$process.ExitCode
 } finally {$process.Dispose()}
}
function Get-RunValue {
 $item=Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue
 if($null -eq $item){return "ABSENT"}
 $value=$item.PSObject.Properties["TaskbarMonitorEnhanced"]
 if($null -eq $value){return "ABSENT"}
 return [string]$value.Value
}
function MainFileMap {
 $p=@("TaskbarMonitorEnhanced.exe","Uninstall.exe","config.json","config.json.bak",
  "install_state.json","Source/TaskbarGlass.cs","R254_USER_CANARY.txt")
 $map=@{}
 foreach($name in $p){$map[$name]=Hash (Join-Path $app $name)}
 return $map
}
function AssertSameMap($baseline,[string]$reason) {
 $new=MainFileMap
 if($new.Count -ne $baseline.Count){Fail ("MAP_SIZE_"+$reason)}
 foreach($key in $baseline.Keys){
  if($new[$key] -cne $baseline[$key]){Fail ("MANAGED_OR_USER_DATA_CHANGED_"+$reason+"_"+$key)}
 }
 if((Get-ItemProperty $uninstall -ErrorAction Stop).DisplayVersion -cne "1.7.3"){
  Fail ("UNINSTALL_VERSION_CHANGED_"+$reason)
 }
 if((Get-RunValue) -cne $originalRunValue){Fail ("STARTUP_CHANGED_"+$reason)}
 if(Test-Path (Join-Path $app ".tbme-upgrade")){Fail ("UPGRADE_STAGE_LEFT_"+$reason)}
 if(@(Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count){Fail ("UNEXPECTED_MAIN_PROCESS_"+$reason)}
}
$setupRoot=Join-Path $out "TaskbarMonitorEnhanced_Setup_1.7.3.exe"
$phase="VERIFY_DISPOSABLE_HOST_IS_FRESH"
if((Test-Path $out) -or (Test-Path $legacy) -or (Test-Path $app) -or
   (Test-Path $uninstall) -or
   @(Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count){
 Fail "NOT_FRESH_WINDOWS"
}
if(!(Test-Path (Join-Path $PSScriptRoot "Test-R254-DisposableLegacyCollision.ps1"))){Fail "SELF_MISSING"}
New-Item -ItemType Directory -Path $out -ErrorAction Stop | Out-Null
try{
 $phase="DOWNLOAD_PUBLIC_IMMUTABLE_SETUP"
 & gh release download $tag --repo GOD13emad/TaskbarMonitorEnhanced --pattern "TaskbarMonitorEnhanced_Setup_1.7.3.exe" --dir $out
 if($LASTEXITCODE -ne 0){Fail "PUBLIC_SETUP_DOWNLOAD_FAILURE"}
 if((Hash $setup) -cne $setupExpected){Fail "PUBLIC_SETUP_HASH_DRIFT"}

 $phase="INSTALL_OFFICIAL_CURRENT_USER_ROOT"
 $installedExit=Run-Setup "/install /quiet /desktop=0 /startup=0"
 if($installedExit -ne 0){Fail ("OFFICIAL_FRESH_INSTALL_EXIT_"+$installedExit)}
 if((Hash (Join-Path $app "TaskbarMonitorEnhanced.exe")) -cne $mainExpected -or
    (Hash (Join-Path $app "Uninstall.exe")) -cne $setupExpected){Fail "FRESH_OFFICIAL_IDENTITY_WRONG"}
 if((Get-ItemProperty $uninstall -ErrorAction Stop).DisplayVersion -cne "1.7.3"){Fail "FRESH_HKCU_VERSION_WRONG"}
 if(@(Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count){Fail "FRESH_NO_STARTUP_PROCESS_REQUIRED"}
 $phase="SEED_SYNTHETIC_GUEST_USER_CONFIG_AND_BACKUP"
 # A genuine fresh official Setup intentionally leaves user-owned config to
 # the first application start; startup=0 means neither file need exist.
 # Seed an independent user fixture WITHOUT overwriting any existing file.
 $config=Join-Path $app "config.json"
 $configBak=Join-Path $app "config.json.bak"
 if(!(Test-Path $config -PathType Leaf)){
  [IO.File]::WriteAllText($config,'{"Theme":"Retro Terminal","GlassMode":true,"Opacity":0,"OpacityWhenGlassOff":0.1,"ConfigSchemaVersion":8,"StartWithWindows":false,"R254UserSentinel":"keep this fixture"}',[Text.UTF8Encoding]::new($false))
 }
 if(!(Test-Path $configBak -PathType Leaf)){
  [IO.File]::WriteAllText($configBak,'{"R254IndependentBackup":"a separate user-owned previous backup must be preserved"}',[Text.UTF8Encoding]::new($false))
 }
 [IO.File]::WriteAllText($canary,"R254 intentionally synthetic canary; no personal data",[Text.UTF8Encoding]::new($false))
 $originalRunValue=Get-RunValue
 $originalHashes=MainFileMap
 $missing=@($originalHashes.Keys|Where-Object {$originalHashes[$_] -ceq "MISSING"})
 if($missing.Count){Fail ("PROTECTED_FILE_MISSING_"+($missing -join "_"))}
 $phase="INJECT_KNOWN_ONLY_LEGACY_PROGRAM_FILES_SENTINEL"
 # Caller-specific program files root is guaranteed empty in this fresh hosted VM.
 if(Test-Path $legacy){Fail "CANNOT_CLAIM_PROGRAMFILES_DIR"}
 [void](New-Item -Path $legacy -ItemType Directory -ErrorAction Stop)
 $ownedLegacy=$true
 $text="R254 owned inert Program Files duplicate-executable marker $HostLabel"
 [IO.File]::WriteAllText($legacyMain,$text,[Text.UTF8Encoding]::new($false))
 $collisionInstalled=$true
 $expectedLegacy=Hash $legacyMain
 if($expectedLegacy -ceq "MISSING"){Fail "INERT_LEGACY_MARKER_NOT_CREATED"}

 $phase="NEGATIVE_REAL_OFFICIAL_UPDATE_MUST_REFUSE_COLLISION"
 $negativeExit=Run-Setup "/update /quiet"
 if($negativeExit -eq 0){Fail "DUPLICATE_PROGRAMFILES_CONFLICT_INCORRECTLY_ACCEPTED"}
 if((Hash $legacyMain) -cne $expectedLegacy){Fail "GUEST_OWNED_LEGACY_SENTINEL_CHANGED"}
 AssertSameMap $originalHashes "COLLISION_REFUSAL"
 $phase="REMOVE_ONLY_EXACT_DISPOSABLE_OWNED_FIXTURE"
 if((Hash $legacyMain) -cne $expectedLegacy){Fail "DO_NOT_REMOVE_CHANGED_PROGRAMFILES_FILE"}
 Remove-Item -LiteralPath $legacyMain -Force -ErrorAction Stop
 if(@(Get-ChildItem -LiteralPath $legacy -Force).Count){Fail "PROGRAMFILES_FOLDER_NOT_EMPTY"}
 Remove-Item -LiteralPath $legacy -Force -ErrorAction Stop
 $ownedLegacy=$false;$collisionInstalled=$false
 if(Test-Path $legacy){Fail "OWNED_LEGACY_DIR_REMAINS"}
 $phase="KNOWN_OFFICIAL_IDEMPOTENT_UPDATE_AFTER_COLLISION_REMOVAL"
 $idempotentExit=Run-Setup "/update /quiet"
 if($idempotentExit -ne 0){Fail ("IDEMPOTENT_UPDATE_FAILED_AFTER_GUEST_REMOVAL_"+$idempotentExit)}
 AssertSameMap $originalHashes "AFTER_CLEAN_IDEMPOTENT_UPDATE"
 $programFilesUnchanged=$true
 $stagedArtifactChecked=$true
 $status="PASS_GENUINE_DISPOSABLE_PROGRAMFILES_DUPLICATE_REJECTED_AND_SAME_ROOT_RESTORED"
}catch{
 $errorText=$_.Exception.GetType().Name+": "+$_.Exception.Message
}finally{
 # Never touch any non-owned target and never overwrite an unknown pre-existing dir.
 if($collisionInstalled -and $ownedLegacy -and (Test-Path $legacyMain)){
  if((Hash $legacyMain) -ceq $expectedLegacy){
   Remove-Item -LiteralPath $legacyMain -Force -ErrorAction SilentlyContinue
  }
 }
 if($ownedLegacy -and (Test-Path $legacy) -and @((Get-ChildItem -LiteralPath $legacy -Force -ErrorAction SilentlyContinue)).Count -eq 0){
  Remove-Item -LiteralPath $legacy -Force -ErrorAction SilentlyContinue
 }
 $record=[ordered]@{
  Revision="R254";Status=$status;Phase=$phase;Failure=$errorText;Guest=$HostLabel
  OS=[Environment]::OSVersion.VersionString;UserName=$env:USERNAME
  SourceParent=$sourceParent;OriginalRelease=$tag;SetupSHA256=$setupExpected
  InstalledMainSHA256=$mainExpected
  ProgramFilesPathType=if($HostLabel -ceq "A"){"ProgramFiles"}else{"ProgramFilesX86"}
  SyntheticOnlyFile=$legacyMain;OriginalLocalHKCUInstallationPreserved=$stagedArtifactChecked
  DuplicateExecutableConflictRefused=($null -ne $negativeExit -and $negativeExit -ne 0)
  RefusedSetupExit=$negativeExit;AfterCleanupUpdateExit=$idempotentExit
  NoUnmanagedOwnerFilesDeleted=$true;NoHKLMOrOtherUserMutation=$true
  SyntheticFixtureRemoved=(!(Test-Path $legacy));PersonalOwnerComputerTouched=$false
  DoesNotProveCrossUserOrHKLMRegistryCollision=$true
  UTC=[DateTime]::UtcNow.ToString("o")
 }
 [IO.File]::WriteAllText($receipt,($record|ConvertTo-Json -Depth 7),[Text.UTF8Encoding]::new($false))
 Write-Output ($record|ConvertTo-Json -Depth 7 -Compress)
}
if($status -notlike "PASS_*" -or !(Test-Path $receipt)){throw ("R254_HOSTED_NEGATIVE_ACCEPTANCE_NOT_PASS "+$phase+" "+$errorText)}
