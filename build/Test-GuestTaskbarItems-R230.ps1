[CmdletBinding()]
param([Parameter(Mandatory=$true)][ValidateSet('A')][string]$Machine)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# Only a *fresh GitHub-hosted Windows VM*, not any owner interactive desktop.
if($env:GITHUB_ACTIONS -cne 'true' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
   $env:RUNNER_OS -cne 'Windows' -or
   $env:GITHUB_REPOSITORY -cne 'GOD13emad/TaskbarMonitorEnhanced' -or
   $env:GITHUB_REF -cne 'refs/heads/audit/r230-guest-taskbar-space' -or
   $env:GITHUB_SHA -cnotmatch '^[0-9a-f]{40}$' -or
   $env:COMPUTERNAME -match '(?i)EMAD|ALI|LAPTOP'){
  throw 'R230_REFUSE_PERSONAL_OR_NON_HOSTED_DESKTOP'
}
$work=Join-Path $env:RUNNER_TEMP ('TBME_R230_SHELL_'+$Machine)
$receipt=Join-Path $work 'R230_SPARSE_TASKBAR_ACCEPTANCE.json'
$original=Join-Path $work 'R230_EXACT_HKCU_TASKBAR_PRESTATE.json'
$root=[Microsoft.Win32.Registry]::CurrentUser
$settings=@(
 @{Path='Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Name='ShowTaskViewButton'},
 @{Path='Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Name='TaskbarDa'},
 @{Path='Software\Microsoft\Windows\CurrentVersion\Search';Name='SearchboxTaskbarMode'}
)
$status='FAIL';$phase='GUEST_PREFLIGHT';$failure='';$runnerSucceeded=$false
$changed=$false;$restored=$false;$originalValues=@();$cleanupFailure=''
function Fail([string]$reason){throw ('R230_'+$reason)}
function SessionExplorer {
 $session=(Get-Process -Id $PID -ErrorAction Stop).SessionId
 return @(Get-Process explorer -ErrorAction SilentlyContinue|Where-Object {$_.SessionId -eq $session})
}
function Restart-DisposableExplorer {
 if($env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or $env:GITHUB_ACTIONS -cne 'true'){
   Fail 'EXPLORER_RESTART_NOT_GITHUB_HOSTED'
 }
 $old=@(SessionExplorer)
 if($old.Count -ne 1){Fail ('EXPLORER_NOT_ONE_BEFORE_RESTART_'+$old.Count)}
 $id=[int]$old[0].Id
 Stop-Process -Id $id -Force -ErrorAction Stop
 Start-Sleep -Seconds 2
 $current=@(SessionExplorer)
 if($current.Count -eq 0){
   Start-Process -FilePath (Join-Path $env:SystemRoot 'explorer.exe') -ErrorAction Stop
   Start-Sleep -Seconds 3
   $current=@(SessionExplorer)
 }
 if($current.Count -ne 1){Fail ('EXPLORER_NOT_RECOVERED_'+$current.Count)}
 Start-Sleep -Seconds 2
}
function Restore-GuestPreferences {
 if(!$changed){return}
 foreach($entry in $originalValues){
   $k=$root.CreateSubKey([string]$entry.Path,$true)
   if($null -eq $k){Fail 'CANNOT_OPEN_REGISTRY_TO_RESTORE'}
   try{
     if($entry.Present){
       $kind=[Enum]::Parse([Microsoft.Win32.RegistryValueKind],[string]$entry.Kind)
       $k.SetValue([string]$entry.Name,$entry.Value,$kind)
     }else{$k.DeleteValue([string]$entry.Name,$false)}
     $k.Flush()
   }finally{$k.Dispose()}
 }
 foreach($entry in $originalValues){
   $k=$root.OpenSubKey([string]$entry.Path,$false)
   try{
     $exists=$null -ne $k -and @($k.GetValueNames()) -ccontains [string]$entry.Name
     if($exists -ne [bool]$entry.Present){Fail 'RESTORE_HKCU_VALUE_PRESENCE_DIFF'}
     if($exists){
        if([string]$k.GetValueKind([string]$entry.Name) -cne [string]$entry.Kind -or
           [string]$k.GetValue([string]$entry.Name) -cne [string]$entry.Value){
           Fail 'RESTORE_HKCU_VALUE_OR_TYPE_DIFF'
        }
     }
   }finally{if($null -ne $k){$k.Dispose()}}
 }
 Restart-DisposableExplorer
 $script:restored=$true
}
try{
 if(Test-Path $work){Fail 'WORKDIR_PREEXISTS'}
 if((Test-Path (Join-Path $env:LOCALAPPDATA 'TaskbarMonitorEnhanced')) -or
    @(Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count -ne 0){
    Fail 'DISPOSABLE_USER_HAS_EXISTING_APP'
 }
 if(@(SessionExplorer).Count -ne 1){Fail 'NO_SINGLE_INTERACTIVE_GUEST_EXPLORER'}
 New-Item -ItemType Directory -Path $work -ErrorAction Stop | Out-Null
 $phase='FULL_GUEST_CURRENT_USER_REGISTRY_PRESTATE'
 foreach($entry in $settings){
   $key=$root.OpenSubKey([string]$entry.Path,$false)
   $exists=$false;$kind='DWord';$value=$null
   try{
     if($null -ne $key){
       $exists=@($key.GetValueNames()) -ccontains [string]$entry.Name
       if($exists){
         $kind=[string]$key.GetValueKind([string]$entry.Name)
         $value=$key.GetValue([string]$entry.Name)
       }
     }
   }finally{if($null -ne $key){$key.Dispose()}}
   if($kind -cnotin @('DWord','String','ExpandString')){Fail 'UNSUPPORTED_PRESTATE_TYPE'}
   $originalValues+=([ordered]@{Path=$entry.Path;Name=$entry.Name;
                  Present=$exists;Kind=$kind;Value=$value})
 }
 if($originalValues.Count -ne 3){Fail 'EXACT_THREE_ITEMS_PRESTATE_REQUIRED'}
 [IO.File]::WriteAllText($original,($originalValues|ConvertTo-Json -Depth 7),
       [Text.UTF8Encoding]::new($false))
 if(!(Test-Path $original)){Fail 'PRESTATE_FILE_MISSING'}
 $phase='APPLY_SUPPORTED_GUEST_ONLY_TASKBAR_VISIBILITY'
 $changed=$true
 foreach($entry in $originalValues){
    $k=$root.CreateSubKey([string]$entry.Path,$true)
    if($null -eq $k){Fail 'CURRENT_USER_REGISTRY_WRITE_FAILED'}
    try{$k.SetValue([string]$entry.Name,[int]0,[Microsoft.Win32.RegistryValueKind]::DWord)
        $k.Flush()
    }finally{$k.Dispose()}
 }
 Restart-DisposableExplorer
 $phase='EXACT_R223_GLASS_START_ON_GUEST_LEFT'
 & ./build/Test-HostedStartPinned-R230.ps1 -Machine $Machine
 if($LASTEXITCODE -ne 0){Fail 'R230_INNER_NATIVE_START_SCRIPT_EXIT_FAILED'}
 $native=Join-Path $env:RUNNER_TEMP ('TBME_R230_START_'+$Machine+'\R230_REAL_NATIVE_START_GUEST.json')
 if(!(Test-Path -LiteralPath $native -PathType Leaf)){Fail 'NATIVE_START_RESULT_FILE_MISSING'}
 $inner=Get-Content -LiteralPath $native -Raw|ConvertFrom-Json
 if($inner.Status -cne 'PASS_REAL_DISPOSABLE_OPTIMIZED_GLASS_START_STAYS_PINNED_AND_INK_RECOVERS' -or
    $inner.NativeSourceResult -cne 'PASS' -or
    $inner.GuestOwnerOriginalMainConfigBackupRestored -ne $true -or
    $inner.GuestPosition -cne 'Left'){
    Fail 'R230_GUEST_NATIVE_SOURCE_OR_BASELINE_RESTORE_UNACCEPTED'
 }
 $runnerSucceeded=$true
 $phase='ACCEPTED'
 $status='PASS_REAL_GUEST_NATIVE_START_PINNED_WITH_SUPPORTED_SPARSE_TASKBAR'
}catch{
 $failure=$_.Exception.GetType().Name+': '+$_.Exception.Message
}finally{
 try{Restore-GuestPreferences}catch{$cleanupFailure=$_.Exception.Message;$status='FAIL'}
 if(Test-Path $work){
   $report=[ordered]@{
      Revision='R230';Machine=$Machine;Status=$status;Phase=$phase;Failure=$failure
      CleanupFailure=$cleanupFailure;GithubCommit=$env:GITHUB_SHA
      NoOwnerPersonalDesktopInput=$true;NoOwnerRegistryOrProductChange=$true
      OriginalTaskbarSettings=@($originalValues)
      OnlyGuestCurrentUserTaskbarPreferencesTouched=$changed
      AllOriginalGuestTaskbarPreferencesRestored=$restored
      ExactNativeMainStillR223TestOnly=$true
      RealPinnedStartSourceAndScreensAccepted=$runnerSucceeded
      GuestUTC=[DateTime]::UtcNow.ToString('o')
   }
   [IO.File]::WriteAllText($receipt,($report|ConvertTo-Json -Depth 8),
          [Text.UTF8Encoding]::new($false))
   Write-Output ($report|ConvertTo-Json -Depth 8 -Compress)
 }
}
if($status -cne 'PASS_REAL_GUEST_NATIVE_START_PINNED_WITH_SUPPORTED_SPARSE_TASKBAR' -or
   !$restored){throw ('R230_DISPOSABLE_GUEST_NATIVE_NOT_ACCEPTED '+$phase+' '+$failure+' '+$cleanupFailure)}
