# R106 independent read-only raw HWND/PID/window class verifier, not signed G14 acceptance.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ReceiptPath,
      [Parameter(Mandatory=$true)][string]$ExpectedCommit,
      [Parameter(Mandatory=$true)][string]$InstalledReceiptPath,
      [switch]$SelfTest)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($ExpectedCommit -cnotmatch '^[0-9a-f]{40}$'){throw 'R106 EXPECTED HEAD BAD'}
if(!(Test-Path -LiteralPath $ReceiptPath -PathType Leaf) -or
   !(Test-Path -LiteralPath $InstalledReceiptPath -PathType Leaf)){throw 'R106 RAW RECEIPT MISSING'}
$raw=Get-Content -LiteralPath $ReceiptPath -Raw|ConvertFrom-Json
$diag=Get-Content -LiteralPath $InstalledReceiptPath -Raw|ConvertFrom-Json
$sha=(Get-FileHash -LiteralPath $ReceiptPath -Algorithm SHA256).Hash
function Check-R106($r,$installed){
 $errors=[Collections.Generic.List[string]]::new()
 foreach($field in @('Schema','Revision','EventCommit','HostRole','Status','ExactSourceExeSHA256',
      'ExactProductPid','ExactProductPath','ExactSessionId','ProbeSessionId','MainProcessAlive',
      'MainWindowHandle','TaskbarPresent','TaskbarRect','Screen','WindowsCount',
      'VisibleWindowsCount','CandidateNativePopupCount','EnumeratedProductWindows',
      'Meaning','FormalG14Accepted','SignedIndependentLabWitness','RegistryMutated',
      'WindowMutated','PersonalHostTouched','Utc')){
  if($null -eq $r.PSObject.Properties[$field]){$errors.Add('MISSING_'+$field)}
 }
 if($errors.Count){return $errors.ToArray()}
 if($r.Schema -ne 1 -or $r.Revision -cne 'R106' -or
    $r.EventCommit -cne $ExpectedCommit -or
    $r.HostRole -cne 'GITHUB_HOSTED_DISPOSABLE_WINDOWS' -or
    $r.Status -cne 'PASS_READONLY_PID_WINDOW_ENUMERATION'){
      $errors.Add('SOURCE_OR_HOST_STATUS_INVALID')
 }
 if($r.ExactSourceExeSHA256 -cne '63A724981E949BA4C91F8BD44F2659F223BDFE0350A2E229CEE7B05535D4BA70' -or
    $r.ExactProductPid -lt 1 -or
    $r.ExactProductPath -cnotmatch 'TaskbarMonitorEnhanced\.exe$' -or
    $r.ExactSessionId -lt 1 -or
    $r.ExactSessionId -ne $r.ProbeSessionId -or
    $r.MainProcessAlive -ne $true){
      $errors.Add('REAL_MAIN_SESSION_IDENTITY_INVALID')
 }
 if($r.Meaning -cne 'READONLY_NATIVE_WINDOW_DIAGNOSTIC_NOT_FORMAL_G14_ACCEPTANCE' -or
    $r.FormalG14Accepted -ne $false -or $r.SignedIndependentLabWitness -cne 'MISSING' -or
    $r.RegistryMutated -ne $false -or $r.WindowMutated -ne $false -or $r.PersonalHostTouched -ne $false){
      $errors.Add('FALSE_ACCEPTANCE_OR_UI_MUTATION')
 }
 if($r.TaskbarPresent -ne $true -or @($r.TaskbarRect).Count -ne 4 -or
    $r.Screen.Width -lt 1100 -or $r.Screen.Height -lt 800){
      $errors.Add('REAL_WIDE_SCREEN_OR_TRAY_UNPROVEN')
 }
 $windows=@($r.EnumeratedProductWindows)
 if($windows.Count -ne $r.WindowsCount -or $windows.Count -gt 512 -or $r.VisibleWindowsCount -gt $r.WindowsCount -or
    $r.CandidateNativePopupCount -gt $r.WindowsCount){
      $errors.Add('WINDOW_COUNTS_FALSE')
 }
 $visible=0;$matches=0
 $seen=@{}
 foreach($x in $windows){
   if($x.PID -ne $r.ExactProductPid -or
      $null -eq $x.HWND -or $null -eq $x.Class -or
      $x.Visible -notin @($true,$false) -or
      $x.Width -lt 0 -or $x.Height -lt 0){
       $errors.Add('UNTRUSTED_PID_OR_WIN32_ENTRY')
       continue
   }
   $key=[string]$x.HWND
   if($seen.ContainsKey($key)){$errors.Add('DUPLICATE_HWNDS')}
   $seen[$key]=$true
   if($x.Visible){$visible++}
   if($x.MatchesNative1100x48Signature){
      $matches++
      if($x.Width -ne 1100 -or $x.Height -ne 48 -or
         !$x.Visible -or !$x.IsLayered -or !$x.IsNoActivate -or
         !$x.IsPopup -or $x.IsChild -or !$x.RectKnown){
           $errors.Add('NATIVE_POPUP_SIGNATURE_WRONG')
      }
   }
 }
 if($visible -ne $r.VisibleWindowsCount -or $matches -ne $r.CandidateNativePopupCount){
   $errors.Add('WINDOW_VISIBILITY_OR_NATIVE_COUNT_FALSE')
 }
 if($installed.EventCommit -cne $ExpectedCommit -or
    $installed.ResidentProcessId -ne $r.ExactProductPid -or
    $installed.ResidentMainSHA256 -cne $r.ExactSourceExeSHA256 -or
    $installed.R106NativeWindowReport -cne 'R106_NATIVE_WINDOWS.json' -or
    $installed.R106NativeWindowSHA256 -cne $sha -or
    $installed.FullInteractiveG14SignedAccepted -ne $false){
    $errors.Add('INSTALLED_EIGHT_RECEIPT_NOT_BOUND_TO_NATIVE_WINDOW_SHA')
 }
 return $errors.ToArray()
}
$errors=@(Check-R106 $raw $diag)
if($errors.Count){throw ('R106_READONLY_INDEPENDENT_REFUSED '+($errors -join ','))}
if($SelfTest){
 $text=Get-Content -LiteralPath $ReceiptPath -Raw
 $hostile=@(
  @{Name='FALSE_FORMAL';Field='FormalG14Accepted';Value=$true},
  @{Name='FAKE_WITNESS';Field='SignedIndependentLabWitness';Value='FAKE'},
  @{Name='PID_DRIFT';Field='ExactProductPid';Value=-22},
  @{Name='WRONG_PROCESS_SHA';Field='ExactSourceExeSHA256';Value=('0'*64)},
  @{Name='FALSE_SOURCE';Field='EventCommit';Value=('0'*40)},
  @{Name='REGISTRY_WRITE';Field='RegistryMutated';Value=$true},
  @{Name='WINDOW_MUTATION';Field='WindowMutated';Value=$true},
  @{Name='BAD_SESSION';Field='ExactSessionId';Value=-1},
  @{Name='FALSE_TRAY';Field='TaskbarPresent';Value=$false},
  @{Name='NOT_WIDE';Field='Status';Value='G14_PASS'},
  @{Name='FALSE_POPUP_COUNT';Field='CandidateNativePopupCount';Value=999},
  @{Name='FALSE_VISIBLE_COUNT';Field='VisibleWindowsCount';Value=999}
 )
 foreach($h in $hostile){
  $v=$text|ConvertFrom-Json
  $v.($h.Field)=$h.Value
  if(@(Check-R106 $v $diag).Count -eq 0){throw ('R106_HOSTILE_FALSE_ACCEPT '+$h.Name)}
 }
 $oldSha=$diag.R106NativeWindowSHA256
 $diag.R106NativeWindowSHA256=('0'*64)
 if(@(Check-R106 $raw $diag).Count -eq 0){throw 'R106_INSTALLED_SHA_BINDING_FALSE_ACCEPT'}
 $diag.R106NativeWindowSHA256=$oldSha
 Write-Output 'R106_NATIVE_WINDOW_13_HOSTILE_NEGATIVES_REJECTED'
}
Write-Output ('R106_NATIVE_WINDOWS_INDEPENDENT_VALIDATED COUNT='+$raw.WindowsCount+
 ' VISIBLE='+$raw.VisibleWindowsCount+' POPUP='+$raw.CandidateNativePopupCount+
 ' G14_FORMAL_OPEN RAW_SHA256='+$sha)
exit 0
