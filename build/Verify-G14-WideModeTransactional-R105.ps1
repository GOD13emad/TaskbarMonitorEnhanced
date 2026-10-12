# R105 independent read-only verifier of transient Win32 display + real installed G14.
# This is NOT a signed trusted independent G14 acceptance or publication authority.
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$ReceiptPath,
 [Parameter(Mandatory=$true)][string]$ExpectedCommit,
 [switch]$SelfTest
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($ExpectedCommit -cnotmatch '^[0-9a-f]{40}$'){throw 'R105_EXPECTED_COMMIT_INVALID'}
if(!(Test-Path -LiteralPath $ReceiptPath -PathType Leaf)){throw 'R105_RECEIPT_MISSING'}
$receipt=Get-Content -LiteralPath $ReceiptPath -Raw|ConvertFrom-Json
$root=Split-Path -Parent (Split-Path -Parent ([IO.Path]::GetFullPath($ReceiptPath)))
$smoke=Join-Path $root 'TBME_R88_UnsignedPreview_Smoke'
$g14Path=Join-Path $smoke 'R103_INSTALLED_8\R103_INSTALLED_EIGHT_DIAGNOSTIC.json'
$r88Path=Join-Path $smoke 'R88_HOSTED_INSTALL_RECEIPT.json'
$stdout=Join-Path (Split-Path -Parent $ReceiptPath) 'R105_INSTALL_SMOKE_STDOUT.txt'
$stderr=Join-Path (Split-Path -Parent $ReceiptPath) 'R105_INSTALL_SMOKE_STDERR.txt'
function Check-R105($r){
 $bad=[Collections.Generic.List[string]]::new()
 foreach($p in @('Schema','Revision','EventCommit','HostRole','Status','DeviceName','OriginalMode',
  'RequestedMode','ObservedWideMode','FinalMode','OriginalCDSTestCode','TargetCDSTestCode',
  'DisplayChangeFlags','CDSTestFlags','RegistryModePersistence','DisplayChangeAttempted',
  'DisplayChangeReturnCode','DisplayModeApplied','WideModeIndependentlyObserved','RestoreReturnCode',
  'OriginalModeExactRestored','SmokeChildExitCode','SmokeChildError',
  'SmokeChildStdoutSHA256','SmokeChildStderrSHA256','UnderlyingPublicPreviewSmokeStatus',
  'G14DiagnosticStatus','G14Completed','G14Passed','G14FailedCases','G14ReceiptSHA256',
  'G13FormalAccepted','G14FormalAccepted','TrustedIndependentLabWitness',
  'PersonalDesktopTouched','DriverInstalled','SystemRebooted','StartedUTC','FinishedUTC','Failure')){
    if($null -eq $r.PSObject.Properties[$p]){$bad.Add('MISSING_'+$p)}
 }
 if($bad.Count){return $bad.ToArray()}
 if($r.Schema -ne 1 -or $r.Revision -cne 'R105' -or $r.EventCommit -cne $ExpectedCommit -or
    $r.HostRole -cne 'GITHUB_HOSTED_DISPOSABLE_WINDOWS' -or
    $r.Status -cne 'PASS_TEMP_WIDE_MODE_REAL_INSTALLED_DIAGNOSTIC_WITH_EXACT_ROLLBACK'){
    $bad.Add('SOURCE_HOST_OR_STATUS_INVALID')
 }
 if($r.DeviceName -cnotmatch '^\\\\\.\\DISPLAY[1-9][0-9]*$' -or
    $r.DisplayChangeFlags -ne 0 -or $r.CDSTestFlags -ne 2 -or
    $r.RegistryModePersistence -ne $false -or
    $r.DisplayChangeAttempted -ne $true -or
    $r.DisplayModeApplied -ne $true -or
    $r.WideModeIndependentlyObserved -ne $true -or
    $r.OriginalModeExactRestored -ne $true -or
    $r.DisplayChangeReturnCode -ne 0 -or $r.RestoreReturnCode -ne 0 -or
    $r.OriginalCDSTestCode -ne 0 -or $r.TargetCDSTestCode -ne 0){
      $bad.Add('DISPLAY_TRANSACTION_NOT_PROVEN_OR_FORBIDDEN_FLAG')
 }
 if($r.G13FormalAccepted -ne $false -or $r.G14FormalAccepted -ne $false -or
    $r.TrustedIndependentLabWitness -cne 'MISSING' -or
    $r.PersonalDesktopTouched -ne $false -or $r.DriverInstalled -ne $false -or
    $r.SystemRebooted -ne $false){
    $bad.Add('FALSE_STABLE_ACCEPTANCE_OR_USER_MUTATION')
 }
 $b=$r.OriginalMode;$a=$r.FinalMode;$mid=$r.ObservedWideMode
 if($null -eq $mid){$bad.Add('NO_WIDE_OBSERVATION');return $bad.ToArray()}
 if($b.Device -cne $a.Device -or $b.Device -cne $r.DeviceName -or
    $b.Width -ne $a.Width -or $b.Height -ne $a.Height -or
    $b.Bpp -ne $a.Bpp -or $b.Hz -ne $a.Hz -or
    ($b.NativeScreen -join ',') -cne ($a.NativeScreen -join ',') -or
    ($b.WinFormsScreen -join ',') -cne ($a.WinFormsScreen -join ',') -or
    ($b.TaskbarRect -join ',') -cne ($a.TaskbarRect -join ',') -or
    @($b.TaskbarRect).Count -ne 4){
    $bad.Add('ORIGINAL_DISPLAY_OR_TASKBAR_NOT_EXACTLY_RESTORED')
 }
 if($r.RequestedMode.Width -ne 1600 -or $r.RequestedMode.Height -ne 900 -or
    $r.RequestedMode.Bpp -ne 32 -or $r.RequestedMode.Index -lt 0 -or
    $r.RequestedMode.Hz -lt 50 -or $r.RequestedMode.Hz -gt 240 -or
    $mid.Width -ne 1600 -or $mid.Height -ne 900 -or
    $mid.Bpp -ne 32 -or $mid.Hz -ne $r.RequestedMode.Hz -or
    ($mid.NativeScreen -join ',') -cne '1600,900' -or
    @($mid.WinFormsScreen).Count -ne 4 -or
    $mid.WinFormsScreen[2] -ne 1600 -or $mid.WinFormsScreen[3] -ne 900){
    $bad.Add('WIDE_DISPLAY_NOT_EXACT_AND_INDEPENDENTLY_OBSERVED')
 }
 if($r.SmokeChildExitCode -ne 0 -or $r.SmokeChildError -cne '' -or
    $r.UnderlyingPublicPreviewSmokeStatus -cne 'PASS_EPHEMERAL_HEADLESS_INSTALL_UNINSTALL' -or
    $r.G14DiagnosticStatus -cne 'EIGHT_RESULTS_CAPTURED_DIAGNOSTIC_ONLY' -or
    $r.G14Completed -ne 8 -or $r.G14Passed -lt 0 -or $r.G14Passed -gt 8 -or $r.Failure -cne ''){
    $bad.Add('INSTALLED_EIGHT_DIAGNOSTIC_NOT_COMPLETE')
 }
 if(!(Test-Path -LiteralPath $stdout -PathType Leaf) -or
    !(Test-Path -LiteralPath $stderr -PathType Leaf) -or
    (Get-FileHash -LiteralPath $stdout -Algorithm SHA256).Hash -cne $r.SmokeChildStdoutSHA256 -or
    (Get-FileHash -LiteralPath $stderr -Algorithm SHA256).Hash -cne $r.SmokeChildStderrSHA256){
    $bad.Add('CHILD_LOG_SHA_INVALID')
 }
 if(!(Test-Path -LiteralPath $g14Path -PathType Leaf) -or
    !(Test-Path -LiteralPath $r88Path -PathType Leaf)){
     $bad.Add('RAW_R103_OR_R88_RECEIPT_MISSING');return $bad.ToArray()
 }
 $g=Get-Content -LiteralPath $g14Path -Raw|ConvertFrom-Json
 $sm=Get-Content -LiteralPath $r88Path -Raw|ConvertFrom-Json
 $failed=@($g.Results|Where-Object {$_.Status -ceq 'FAIL_DIAGNOSTIC'}|ForEach-Object Test)
 if((Get-FileHash -LiteralPath $g14Path -Algorithm SHA256).Hash -cne $r.G14ReceiptSHA256 -or
    $g.EventCommit -cne $ExpectedCommit -or
    $g.CompletedCases -ne 8 -or $g.PassedCases -ne $r.G14Passed -or
    ($failed -join ',') -cne (@($r.G14FailedCases) -join ',') -or
    $g.FullInteractiveG14SignedAccepted -ne $false){
    $bad.Add('G14_RAW_CASE_OR_SHA_CONTRACT_MISMATCH')
 }
 if($sm.EventCommit -cne $ExpectedCommit -or
    $sm.Status -cne 'PASS_EPHEMERAL_HEADLESS_INSTALL_UNINSTALL' -or
    $sm.RealInteractiveG14EightProbes -cne 'NOT_TESTED' -or
    $sm.FullSignedStableAccepted -ne $false){
    $bad.Add('R88_FORMAL_GATE_FALSE_PROMOTION')
 }
 return $bad.ToArray()
}
$violations=@(Check-R105 $receipt)
if($violations.Count){throw ('R105_WIDESCREEN_RAW_REFUSED '+($violations -join ','))}
if($SelfTest){
 $raw=Get-Content -LiteralPath $ReceiptPath -Raw
 $cases=@(
   @{Field='G14FormalAccepted';Value=$true},
   @{Field='TrustedIndependentLabWitness';Value='SELF_SIGNED'},
   @{Field='HostRole';Value='PERSONAL'},
   @{Field='DisplayChangeFlags';Value=1},
   @{Field='CDSTestFlags';Value=0},
   @{Field='RegistryModePersistence';Value=$true},
   @{Field='OriginalModeExactRestored';Value=$false},
   @{Field='DisplayChangeReturnCode';Value=-1},
   @{Field='RestoreReturnCode';Value=-1},
   @{Field='SmokeChildExitCode';Value=7},
   @{Field='G14Completed';Value=5},
   @{Field='G14Passed';Value=9},
   @{Field='SmokeChildStdoutSHA256';Value=('0'*64)},
   @{Field='PersonalDesktopTouched';Value=$true},
   @{Field='DeviceName';Value='UNKNOWN'},
   @{Field='Status';Value='SIGNED_STABLE'}
 )
 foreach($case in $cases){
   $r=$raw|ConvertFrom-Json
   $r.($case.Field)=$case.Value
   if(@(Check-R105 $r).Count -eq 0){throw ('R105_HOSTILE_FALSE_ACCEPT '+$case.Field)}
 }
 $r=$raw|ConvertFrom-Json
 $r.FinalMode.Width=1234
 if(@(Check-R105 $r).Count -eq 0){throw 'R105_FINAL_DISPLAY_CHANGED_FALSE_ACCEPT'}
 $r=$raw|ConvertFrom-Json
 $r.ObservedWideMode.NativeScreen[0]=1111
 if(@(Check-R105 $r).Count -eq 0){throw 'R105_WIDE_METRIC_FALSE_ACCEPT'}
 Write-Output 'R105_INDEPENDENT_EIGHTEEN_HOSTILE_NEGATIVE_CASES_PASS'
}
Write-Output ('R105_TEMPORARY_WIDE_DISPLAY_EXACT_ROLLBACK_AND_INSTALLED_DIAG_PASS G14='+$receipt.G14Passed+
 '/'+$receipt.G14Completed+' FORMAL_G14=OPEN RECEIPT_SHA256='+
 (Get-FileHash -LiteralPath $ReceiptPath -Algorithm SHA256).Hash)
exit 0
