# R108 independent read-only disposable Windows 1600→1024 exact rollback receipt verifier.
# Formal signed G14 acceptance remains forbidden without an external approved witness.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ReceiptPath,
      [Parameter(Mandatory=$true)][string]$ExpectedCommit,
      [switch]$SelfTest)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($ExpectedCommit -cnotmatch '^[0-9a-f]{40}$'){throw 'R108 INVALID EXPECTED SOURCE COMMIT'}
if(!(Test-Path -LiteralPath $ReceiptPath -PathType Leaf)){throw 'R108 WRAPPER RECEIPT MISSING'}
$receipt=Get-Content -LiteralPath $ReceiptPath -Raw|ConvertFrom-Json
$dir=[IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($ReceiptPath))
$runnerArea=[IO.Path]::GetDirectoryName($dir)
$child=Join-Path $runnerArea 'TBME_R107_PRIVATE_CANDIDATE\R107_PRIVATE_CANDIDATE_RECEIPT.json'
$stdout=Join-Path $dir 'R108_INSTALL_SMOKE_STDOUT.txt'
$stderr=Join-Path $dir 'R108_INSTALL_SMOKE_STDERR.txt'
function Validate-R108($r){
 $bad=[Collections.Generic.List[string]]::new()
 foreach($key in @('Schema','Revision','EventCommit','HostRole','Status','DeviceName',
 'OriginalMode','RequestedMode','ObservedWideMode','FinalMode',
 'OriginalCDSTestCode','TargetCDSTestCode','DisplayChangeFlags','CDSTestFlags',
 'RegistryModePersistence','DisplayChangeAttempted','DisplayChangeReturnCode',
 'DisplayModeApplied','WideModeIndependentlyObserved','RestoreReturnCode',
 'OriginalModeExactRestored','SmokeChildExitCode','SmokeChildError',
 'SmokeChildStdoutSHA256','SmokeChildStderrSHA256','PrivateCandidateInstallStatus',
 'G14DiagnosticStatus','G14Completed','G14Passed','G14FailedCases','G14ReceiptSHA256',
 'G13FormalAccepted','G14FormalAccepted','TrustedIndependentLabWitness',
 'PersonalDesktopTouched','DriverInstalled','SystemRebooted','StartedUTC','FinishedUTC','Failure')){
  if($null -eq $r.PSObject.Properties[$key]){$bad.Add('MISSING_'+$key)}
 }
 if($bad.Count){return $bad.ToArray()}
 if($r.Schema -ne 1 -or $r.Revision -cne 'R108' -or
    $r.EventCommit -cne $ExpectedCommit -or $r.HostRole -cne 'GITHUB_HOSTED_DISPOSABLE_WINDOWS' -or
    $r.Status -cne 'PASS_PRIVATE_CANDIDATE_1600_AND_EXACT_RESTORE'){
  $bad.Add('R108_EXACT_AUTHORITY_SOURCE_STATUS')
 }
 if($r.DeviceName -cnotmatch '^\\\\\.\\DISPLAY[1-9][0-9]*$' -or
    $r.DisplayChangeFlags -ne 0 -or $r.CDSTestFlags -ne 2 -or
    $r.RegistryModePersistence -ne $false -or
    $r.DisplayChangeAttempted -ne $true -or $r.DisplayModeApplied -ne $true -or
    $r.WideModeIndependentlyObserved -ne $true -or
    $r.OriginalModeExactRestored -ne $true -or
    $r.OriginalCDSTestCode -ne 0 -or $r.TargetCDSTestCode -ne 0 -or
    $r.DisplayChangeReturnCode -ne 0 -or $r.RestoreReturnCode -ne 0){
  $bad.Add('R108_DISPLAY_APPLY_TEST_OR_EXACT_ROLLBACK_UNPROVEN')
 }
 if($r.G13FormalAccepted -ne $false -or $r.G14FormalAccepted -ne $false -or
    $r.TrustedIndependentLabWitness -cne 'MISSING' -or $r.PersonalDesktopTouched -ne $false -or
    $r.DriverInstalled -ne $false -or $r.SystemRebooted -ne $false){
    $bad.Add('FALSE_FORMAL_LAB_ACCEPTANCE_OR_PROTECTED_HOST_MUTATION')
 }
 $before=$r.OriginalMode;$end=$r.FinalMode;$middle=$r.ObservedWideMode
 if($null -eq $before -or $null -eq $end -or $null -eq $middle){
    $bad.Add('DISPLAY_SNAPSHOTS_MISSING');return $bad.ToArray()
 }
 if($before.Device -cne $end.Device -or $before.Device -cne $r.DeviceName -or
    $before.Width -ne $end.Width -or $before.Height -ne $end.Height -or
    $before.Bpp -ne $end.Bpp -or $before.Hz -ne $end.Hz -or
    ($before.NativeScreen -join ',') -cne ($end.NativeScreen -join ',') -or
    ($before.WinFormsScreen -join ',') -cne ($end.WinFormsScreen -join ',') -or
    ($before.TaskbarRect -join ',') -cne ($end.TaskbarRect -join ',') -or
    @($before.TaskbarRect).Count -ne 4){
    $bad.Add('ORIGINAL_DISPLAY_OR_TASKBAR_GEOMETRY_NOT_RESTORED')
 }
 if($r.RequestedMode.Width -ne 1600 -or $r.RequestedMode.Height -ne 900 -or
    $r.RequestedMode.Bpp -ne 32 -or $r.RequestedMode.Index -lt 0 -or
    $middle.Width -ne 1600 -or $middle.Height -ne 900 -or $middle.Bpp -ne 32 -or
    $middle.Hz -ne $r.RequestedMode.Hz -or
    ($middle.NativeScreen -join ',') -cne '1600,900' -or
    $middle.WinFormsScreen[2] -ne 1600 -or $middle.WinFormsScreen[3] -ne 900){
    $bad.Add('WIDE_MODE_NOT_TRULY_1600_BY_MULTIPLE_WIN32_APIS')
 }
 if($r.SmokeChildExitCode -ne 0 -or $r.SmokeChildError -cne '' -or
    $r.PrivateCandidateInstallStatus -cne 'PASS_PRIVATE_CANDIDATE_INSTALLED_EIGHT_DIAGNOSTICS_CAPTURED' -or
    $r.G14DiagnosticStatus -cne 'PASS_PRIVATE_CANDIDATE_INSTALLED_EIGHT_DIAGNOSTICS_CAPTURED' -or
    $r.G14Completed -ne 8 -or $r.G14Passed -lt 0 -or $r.G14Passed -gt 8 -or
    $r.Failure -cne ''){
    $bad.Add('INSTALLED_PRIVATE_CANDIDATE_EIGHT_CASES_NOT_COMPLETE')
 }
 foreach($pair in @(@($stdout,[string]$r.SmokeChildStdoutSHA256),
                    @($stderr,[string]$r.SmokeChildStderrSHA256))){
    if(!(Test-Path -LiteralPath $pair[0] -PathType Leaf) -or
       (Get-FileHash -LiteralPath $pair[0] -Algorithm SHA256).Hash -cne $pair[1]){
        $bad.Add('BOUND_REAL_CHILD_LOG_HASH')
    }
 }
 if(!(Test-Path -LiteralPath $child -PathType Leaf)){
    $bad.Add('REAL_CANDIDATE_INSTALL_RECEIPT_MISSING')
    return $bad.ToArray()
 }
 $installed=Get-Content -LiteralPath $child -Raw|ConvertFrom-Json
 if($installed.EventCommit -cne $ExpectedCommit -or
    $installed.CandidateIsPublicRelease -ne $false -or
    $installed.CandidateMainSHA256 -cne 'B56E322826A86927999A00FB933C17979213798A68C8BB71C2176E68962E30EA' -or
    $installed.DiagnosticAttempts -ne 8 -or $installed.DiagnosticPasses -ne $r.G14Passed -or
    $installed.FormalG14Accepted -ne $false -or
    (Get-FileHash -LiteralPath $child -Algorithm SHA256).Hash -cne $r.G14ReceiptSHA256){
    $bad.Add('INSTALLED_RAW_SHA_BINARY_OR_G14_COUNTS_CONTRADICT')
 }
 if((@($installed.DiagnosticResults|Where-Object {$_.Status -cne 'PASS_DIAGNOSTIC'}|ForEach-Object Test) -join ',') -cne
    (@($r.G14FailedCases) -join ',')){
    $bad.Add('FAILED_CASES_FALSIFIED')
 }
 return $bad.ToArray()
}
$issues=@(Validate-R108 $receipt)
if($issues.Count){throw ('R108_INDEPENDENT_PRIVATE_WIDE_REFUSED '+($issues -join ','))}
if($SelfTest){
 $raw=Get-Content -LiteralPath $ReceiptPath -Raw
 $mutations=@(
   @{Name='FAKE_G14_SIGNED';Field='G14FormalAccepted';Value=$true},
   @{Name='FAKE_G13_SIGNED';Field='G13FormalAccepted';Value=$true},
   @{Name='FAKE_WITNESS';Field='TrustedIndependentLabWitness';Value='SELF'},
   @{Name='WRONG_HOST';Field='HostRole';Value='PERSONAL'},
   @{Name='REGISTRY_CHANGE';Field='RegistryModePersistence';Value=$true},
   @{Name='REBOOTED';Field='SystemRebooted';Value=$true},
   @{Name='DISPLAY_APPLIED_FALSE';Field='DisplayModeApplied';Value=$false},
   @{Name='DISPLAY_RESTORE_FALSE';Field='OriginalModeExactRestored';Value=$false},
   @{Name='RESTORE_CODE_BAD';Field='RestoreReturnCode';Value=1},
   @{Name='BAD_APPLY_FLAG';Field='DisplayChangeFlags';Value=1},
   @{Name='BAD_TEST_FLAG';Field='CDSTestFlags';Value=0},
   @{Name='WRONG_RESULT_COUNT';Field='G14Completed';Value=7},
   @{Name='FAKE_COMPLETE_G14';Field='G14Passed';Value=9},
   @{Name='CHILD_FAILED';Field='SmokeChildExitCode';Value=9},
   @{Name='CHILD_SHA_WRONG';Field='SmokeChildStdoutSHA256';Value=('0'*64)},
   @{Name='FALSE_SOURCE';Field='EventCommit';Value=('0'*40)}
 )
 foreach($mut in $mutations){
    $r=$raw|ConvertFrom-Json
    $r.($mut.Field)=$mut.Value
    if(@(Validate-R108 $r).Count -eq 0){throw ('R108_MUTATED_RECEIPT_FALSE_ACCEPT '+$mut.Name)}
 }
 $r=$raw|ConvertFrom-Json;$r.FinalMode.Width=999
 if(@(Validate-R108 $r).Count -eq 0){throw 'R108_FALSE_DISPLAY_ROLLBACK_ACCEPT'}
 Write-Output 'R108_INDEPENDENT_SEVENTEEN_HOSTILE_NEGATIVES_REJECTED'
}
Write-Output ('R108_INSTALLED_PRIVATE_G14_DIAGNOSTIC_VERIFIED '+$receipt.G14Passed+
 '/8; TEMP_DISPLAY_EXACT_RESTORED; FORMAL_G14_OPEN; RAW_SHA256='+
 (Get-FileHash -LiteralPath $ReceiptPath -Algorithm SHA256).Hash)
exit 0
