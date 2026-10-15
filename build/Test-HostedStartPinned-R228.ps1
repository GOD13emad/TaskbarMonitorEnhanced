[CmdletBinding()]
param([Parameter(Mandatory=$true)][ValidateSet('A','B')][string]$Machine)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# REAL keyboard Start key, window observation and screenshots ONLY in fresh disposable hosted Windows.
if($env:GITHUB_ACTIONS -cne 'true' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
   $env:RUNNER_OS -cne 'Windows' -or $env:GITHUB_REPOSITORY -cne 'GOD13emad/TaskbarMonitorEnhanced' -or
   $env:GITHUB_REF -cne 'refs/heads/audit/r228-start-glass-pinned-real' -or
   $env:GITHUB_SHA -cnotmatch '^[0-9a-f]{40}$' -or
   [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP) -or $env:COMPUTERNAME -match '(?i)EMAD|ALI|LAPTOP'){
    throw 'R228_DISPOSABLE_WINDOWS_ONLY_NO_OWNER_DESKTOP'
}
$mainSha='5A44490034EB8A8B846FB11E7BD6954EED741F92DB53FC7A568DCCA358A5BCE2'
$officialSha='84D5DBF6F2E6D1D2E2B3E6D9C9DA523E564A7F5240C08D34A456D934026B829F'
$setupSha='225BCC259C392DA04F3E0157CAF22F96C4052282AAF02555E6F6E777F4CB8AF4'
$repo='GOD13emad/TaskbarMonitorEnhanced'
$app=Join-Path $env:LOCALAPPDATA 'TaskbarMonitorEnhanced'
$installedMain=Join-Path $app 'TaskbarMonitorEnhanced.exe'
$config=Join-Path $app 'config.json'
$backup=Join-Path $app 'config.json.bak'
$work=Join-Path $env:RUNNER_TEMP ('TBME_R228_START_'+$Machine)
$native=Join-Path $work 'start'
$proof=Join-Path $native 'START_PINNED_PROOF.json'
$receipt=Join-Path $work 'R228_REAL_NATIVE_START_GUEST.json'
$status='FAIL';$stage='PREFLIGHT';$failure=''
$nativeResult='UNPROVEN';$nativeVerifier='UNPROVEN';$nativeExit=-1
$mainOriginalBytes=$null;$configOriginalBytes=$null;$backupOriginalBytes=$null
$installed=$false;$glassSet=$false;$restored=$false;$owned=$null
$sourcePid=0;$guestAppRootOriginalHasConfig=$false
function Fail([string]$s){throw ('R228_'+$s)}
function Hash([string]$file){
  if(!(Test-Path -LiteralPath $file -PathType Leaf)){return 'MISSING'}
  return (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
}
function AppProcesses{
  return @(Get-Process -Name TaskbarMonitorEnhanced -ErrorAction SilentlyContinue)
}
function Child([string]$exe,[string[]]$arglist,[int]$maxMillis,[string]$label){
    $si=[Diagnostics.ProcessStartInfo]::new()
    $si.FileName=$exe
    $si.WorkingDirectory=Split-Path $exe -Parent
    $si.UseShellExecute=$false
    $si.CreateNoWindow=$true
    foreach($arg in $arglist){[void]$si.ArgumentList.Add([string]$arg)}
    $proc=[Diagnostics.Process]::Start($si)
    if(!$proc){Fail ('PROCESS_START_NULL_'+$label)}
    try{
        if(!$proc.WaitForExit($maxMillis)){
           try{$proc.Kill($true);$proc.WaitForExit(7000)|Out-Null}catch{}
           Fail ('PROCESS_TIMEOUT_'+$label)
        }
        return [int]$proc.ExitCode
    }finally{$proc.Dispose()}
}
function RestoreGuest(){
   # No personal user content is ever touched; this cleanup operates ONLY on the
   # exact new disposable guest files created by the official installer.
   if($null -ne $owned){
      try{
         $owned.Refresh()
         if(!$owned.HasExited){
             if($owned.Id -ne $sourcePid -or
                (Get-Process -Id $sourcePid -ErrorAction SilentlyContinue).Path -cne $installedMain){
                 Fail 'OWNED_RESIDENT_IDENTITY_NOT_EXACT'
             }
             $owned.Kill($true)
             $owned.WaitForExit(9000)|Out-Null
         }
      }finally{$owned.Dispose()}
   }
   if(!$installed){return}
   if(@(AppProcesses).Count -ne 0){Fail 'GUEST_APP_PROCESS_NOT_QUIESCENT_AFTER_STOP'}
   if($null -eq $mainOriginalBytes){Fail 'BASE_MAIN_BACKUP_NEVER_READ'}
   [IO.File]::WriteAllBytes($installedMain,$mainOriginalBytes)
   if((Hash $installedMain) -cne $officialSha){Fail 'OFFICIAL_MAIN_RESTORE_SHA_DIFF'}
   if($null -ne $configOriginalBytes){[IO.File]::WriteAllBytes($config,$configOriginalBytes)}
   elseif(Test-Path $config){Remove-Item -LiteralPath $config -Force}
   if($null -ne $backupOriginalBytes){[IO.File]::WriteAllBytes($backup,$backupOriginalBytes)}
   elseif(Test-Path $backup){Remove-Item -LiteralPath $backup -Force}
   if($null -ne $configOriginalBytes -and
      ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($config))) -cne
       [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($configOriginalBytes)))){
       Fail 'GUEST_CONFIG_ORIGINAL_NOT_RESTORED'
   }
   $script:restored=$true
}
try{
   if(Test-Path $work){Fail 'RUN_DIRECTORY_ALREADY_EXISTS'}
   if((Test-Path $app) -or @(AppProcesses).Count -ne 0 -or
      (Test-Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TaskbarMonitorEnhanced')){
      Fail 'GUEST_WINDOWS_NOT_FRESH_OR_USER_ROOT_PREEXISTS'
   }
   if(@(Get-Process explorer -ErrorAction SilentlyContinue|Where-Object {$_.SessionId -eq (Get-Process -Id $PID).SessionId}).Count -lt 1){
      Fail 'NO_REAL_EXPLORER_IN_INTERACTIVE_HOSTED_DESKTOP'
   }
   $stage='OFFICIAL_V172_GUEST_INSTALL'
   New-Item -ItemType Directory -Path $work -ErrorAction Stop|Out-Null
   & gh release download v1.7.2 --repo $repo --pattern TaskbarMonitorEnhanced_Setup_1.7.2.exe --dir $work
   if($LASTEXITCODE -ne 0){Fail 'PUBLIC_OFFICIAL_INSTALLER_UNAVAILABLE'}
   $setup=Join-Path $work 'TaskbarMonitorEnhanced_Setup_1.7.2.exe'
   if((Hash $setup) -cne $setupSha){Fail 'OFFICIAL_SETUP_SHA_DIFFERENT'}
   $rc=Child $setup @('/install','/quiet','/desktop=0','/startup=0') 190000 'OFFICIAL_SETUP'
   if($rc -ne 0){Fail ('OFFICIAL_INSTALLER_RETURNED_'+$rc)}
   if((Hash $installedMain) -cne $officialSha -or @(AppProcesses).Count -ne 0){
      Fail 'GUEST_OFFICIAL_MAIN_NOT_INSTALLED_QUIESCENT'
   }
   $mainOriginalBytes=[IO.File]::ReadAllBytes($installedMain)
   $installed=$true
   if(Test-Path $config){$configOriginalBytes=[IO.File]::ReadAllBytes($config);$guestAppRootOriginalHasConfig=$true}
   if(Test-Path $backup){$backupOriginalBytes=[IO.File]::ReadAllBytes($backup)}
   $stage='ENABLE_EXACT_DISPOSABLE_ALPHA_GLASS_START_PINNED'
   Copy-Item -LiteralPath './build/_out/App/TaskbarMonitorEnhanced.exe' -Destination $installedMain -Force
   if((Hash $installedMain) -cne $mainSha){Fail 'EXACT_OPTIMIZED_BINARY_NOT_INSTALLED_ON_GUEST'}
   $fixture=@{
      Theme='Retro Terminal'
      ConfigSchemaVersion=8
      Opacity=0.0
      GlassMode=$true
      OpacityWhenGlassOff=0.10
      FloatAboveStartMenu=$false
      StartWithWindows=$false
      UpdateIntervalMs=1000
      ShowSparklines=$true
      AutoCheckUpdates=$false
      ShowCpu=$true
      ShowRam=$true
      ShowDisk=$true
      ShowGpu=$true
      ShowNetwork=$true
      ShowTemperatures=$false
      SafePlacement=$true
      MinWidthLogicalPx=1100
   }|ConvertTo-Json -Compress
   [IO.File]::WriteAllText($config,$fixture,[Text.UTF8Encoding]::new($false))
   [IO.File]::WriteAllText($backup,$fixture,[Text.UTF8Encoding]::new($false))
   if((Hash $config) -cne (Hash $backup)){Fail 'GLASS_CONFIG_AND_BACKUP_NOT_IDENTICAL'}
   $glassSet=$true
   $stage='LAUNCH_REAL_HOSTED_RESIDENT'
   $si=[Diagnostics.ProcessStartInfo]::new()
   $si.FileName=$installedMain
   $si.WorkingDirectory=$app
   $si.UseShellExecute=$false
   $si.CreateNoWindow=$true
   $owned=[Diagnostics.Process]::Start($si)
   if(!$owned){Fail 'GUEST_RESIDENT_NOT_LAUNCHED'}
   $sourcePid=[int]$owned.Id
   Start-Sleep -Seconds 8
   $owned.Refresh()
   if($owned.HasExited -or @(AppProcesses).Count -ne 1 -or (Get-Process -Id $sourcePid).Path -cne $installedMain){
       Fail 'EXACT_SINGLE_GUEST_RESIDENT_NOT_VISIBLE'
   }
   $stage='REAL_START_KEY_24_SAMPLE_NATIVE_SCREEN_PROOF'
   if(Test-Path $native){Fail 'SACRIFICIAL_NATIVE_OUTPUT_PREEXISTS'}
   $rc=Child $installedMain @('--startpinnedprobe',$native) 105000 'ACTUAL_WIN_KEY_START_PROOF'
   $nativeExit=$rc
   if(!(Test-Path $proof -PathType Leaf)){Fail 'ACTUAL_NATIVE_START_SOURCE_MANIFEST_MISSING'}
   $source=Get-Content $proof -Raw|ConvertFrom-Json
   $nativeResult=[string]$source.Status
   if($rc -ne 0 -or $source.Status -cne 'PASS'){
      Fail ('NATIVE_START_REAL_PHYSICAL_SOURCE_NOT_PASS_EXIT_'+$rc+'_SOURCE_'+$nativeResult)
   }
   $stage='INDEPENDENT_FOURTEEN_HOSTILE_AND_FIVE_ACTUAL_BITMAPS'
   $pre=[ordered]@{
       Revision='R228';Host=$Machine;GitHubTestCommit=$env:GITHUB_SHA
       CandidateMainSHA256=$mainSha;OfficialMainSHA256=$officialSha;OfficialSetupSHA256=$setupSha
       ResidentProcessId=$sourcePid;HostedGlassAndPinnedConfigured=$glassSet
       NoOwnerComputerTouched=$true;NativeSourceResult=$nativeResult
   }
   [IO.File]::WriteAllText($receipt,($pre|ConvertTo-Json -Depth 7),[Text.UTF8Encoding]::new($false))
   & ./build/Verify-StartPinned-R228.ps1 -ManifestPath $proof -CandidateReceiptPath $receipt -ExpectedCommit $env:GITHUB_SHA -SelfTest
   if($LASTEXITCODE -ne 0){Fail 'INDEPENDENT_NATIVE_PINNED_AND_SCREEN_PIXEL_VERIFIER_NOT_ACCEPTED'}
   $nativeVerifier='PASS_24_PINNED_SAMPLES_AND_14_HOSTILE_AND_FIVE_BITMAPS'
   $stage='ACCEPTED'
   $status='PASS_REAL_DISPOSABLE_OPTIMIZED_GLASS_START_STAYS_PINNED_AND_INK_RECOVERS'
}catch{
   $failure=$_.Exception.GetType().Name+': '+$_.Exception.Message
}finally{
   try{RestoreGuest}catch{$failure+='; CLEANUP='+$_.Exception.Message;$status='FAIL'}
   if(Test-Path $work){
      $receiptValue=[ordered]@{
         Revision='R228';Host=$Machine;Status=$status;Phase=$stage;Failure=$failure
         GitHubTestCommit=$env:GITHUB_SHA
         CandidateMainSHA256=$mainSha;OfficialMainSHA256=$officialSha;OfficialSetupSHA256=$setupSha
         RealOfficialV172FreshGuestInstall=$installed
         ResidentProcessId=$sourcePid;HostedGlassAndPinnedConfigured=$glassSet
         GlassAlphaZeroAndNonGlassOpacityTenPercent=$glassSet
         PinnedStartProofExitCode=$nativeExit
         NativeSourceResult=$nativeResult;IndependentVerifier=$nativeVerifier
         GuestOwnerOriginalMainConfigBackupRestored=$restored
         NoOwnerComputerTouched=$true;NoPublicReleaseMutation=$true
         FormalPhysicalLabAccepted=$false
         GuestUtc=[DateTime]::UtcNow.ToString('o')
      }
      [IO.File]::WriteAllText($receipt,($receiptValue|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
      Write-Output ($receiptValue|ConvertTo-Json -Depth 8 -Compress)
   }
}
if($status -cne 'PASS_REAL_DISPOSABLE_OPTIMIZED_GLASS_START_STAYS_PINNED_AND_INK_RECOVERS' -or !$restored){
   throw ('R228_REAL_GUEST_START_NOT_ACCEPTED_'+$stage+' '+$failure)
}
