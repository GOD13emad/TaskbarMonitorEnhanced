# R107 independent fail-closed, read-only SHA and install-cleanup receipt validator.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ReceiptPath,
      [Parameter(Mandatory=$true)][string]$ExpectedCommit,
      [switch]$SelfTest)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$names=@('startup','hover','hardware','temperature','health','support','start','shell')
if($ExpectedCommit -cnotmatch '^[0-9a-f]{40}$'){throw 'R107 WRONG EXPECTED COMMIT'}
if(!(Test-Path -LiteralPath $ReceiptPath -PathType Leaf)){throw 'R107 RAW CANDIDATE RECEIPT MISSING'}
$receipt=Get-Content -LiteralPath $ReceiptPath -Raw|ConvertFrom-Json
$root=Split-Path ([IO.Path]::GetFullPath($ReceiptPath)) -Parent
function Check-R107($r) {
 $bad=[Collections.Generic.List[string]]::new()
 foreach($field in @('Schema','Revision','EventCommit','HostRole','Status',
     'CandidateMainSHA256','CandidateSetupSHA256','CandidateConfigSHA256',
     'CandidateIsPublicRelease','CandidateAuthenticodeSigned','CanonicalSingleRoot',
     'MainProcessPid','InstalledSensorStatus','StartupRegistryInitiallyAbsent','WallpaperModeBefore',
     'OwnedSetupVerifyExit','OwnedSetupInstallExit','OwnedSetupUninstallExit',
     'DiagnosticAttempts','DiagnosticPasses','DiagnosticResults','Cleanup','CleanupAudit','Failure',
     'FormalG14Accepted','TrustedIndependentLabWitness','PersonalInstallTouched',
     'PublicReleaseModified','SystemRestarted','StartedUTC','FinishedUTC')){
    if($null -eq $r.PSObject.Properties[$field]){$bad.Add('MISSING_'+$field)}
 }
 if($bad.Count){return $bad.ToArray()}
 if($r.Schema -ne 1 -or $r.Revision -cne 'R107' -or
    $r.EventCommit -cne $ExpectedCommit -or
    $r.HostRole -cne 'GITHUB_HOSTED_DISPOSABLE_WINDOWS' -or
    $r.Status -cne 'PASS_PRIVATE_CANDIDATE_INSTALLED_EIGHT_DIAGNOSTICS_CAPTURED'){
    $bad.Add('R107_SOURCE_HOST_STATUS')
 }
 foreach($v in @($r.CandidateMainSHA256,$r.CandidateSetupSHA256,$r.CandidateConfigSHA256)){
   if($v -cnotmatch '^[0-9A-F]{64}$'){$bad.Add('SOURCE_SHA_NOT_PINNED')}
 }
 # R108-F01: a syntactically valid 64-hex digest is NOT evidence that the
 # exact reproducible candidate was installed. Bind all three binary hashes.
 if($r.CandidateMainSHA256 -cne 'FB77754C337441F1A87CD38DCEF45FE8C4DC66A2ACAC3E27CFE388417549CFD9' -or
    $r.CandidateSetupSHA256 -cne '05D17828EBB78D81C0BB84B2ABE14E6081FBDC1E1C21CBCD26E93CEE74963F4F' -or
    $r.CandidateConfigSHA256 -cne 'D2E51872D93F0793C02AD07DCBF8C2802F59708C666548372A4FDDDA5C7C5E4F' -or
    $r.CandidateIsPublicRelease -ne $false -or
    $r.CandidateAuthenticodeSigned -ne $false -or
    $r.FormalG14Accepted -ne $false -or
    $r.TrustedIndependentLabWitness -cne 'MISSING'){
     $bad.Add('R107_FALSE_STABLE_OR_PUBLIC_RELEASE')
 }
 if($r.CanonicalSingleRoot -cnotmatch '\\TaskbarMonitorEnhanced$' -or
    $r.StartupRegistryInitiallyAbsent -ne $true -or
    $r.OwnedSetupVerifyExit -ne 0 -or $r.OwnedSetupInstallExit -ne 0 -or
    $r.OwnedSetupUninstallExit -ne 0 -or
    $r.Cleanup -cne 'PASS_EXACT_OWNED_DISPOSABLE_INSTALL_AND_UNINSTALL' -or
    $r.Failure -cne '' -or $r.PersonalInstallTouched -ne $false -or
    $r.PublicReleaseModified -ne $false -or $r.SystemRestarted -ne $false){
     $bad.Add('R107_INSTALL_CLEANUP_NOT_EXACT')
 }
 if($null -eq $r.CleanupAudit -or
    $r.CleanupAudit.Status -cne 'OBSERVED_AFTER_UNINSTALL' -or
    $r.CleanupAudit.AppRootExists -ne $false -or
    $r.CleanupAudit.UninstallRegistryExists -ne $false -or
    $r.CleanupAudit.StartShortcutExists -ne $false -or
    $r.CleanupAudit.DesktopShortcutExists -ne $false -or
    $r.CleanupAudit.StartupRunValuePresent -ne $false -or
    @($r.CleanupAudit.OwnedRemainingFileNames).Count -ne 0 -or
    $r.CleanupAudit.RemainingMainProcessCount -ne 0){
    $bad.Add('R108_ASYNC_CLEANUP_NOT_INDEPENDENTLY_PROVEN')
 }
 $results=@($r.DiagnosticResults)
 if($r.DiagnosticAttempts -ne 8 -or $results.Count -ne 8 -or
    $r.DiagnosticPasses -lt 0 -or $r.DiagnosticPasses -gt 8){
    $bad.Add('R107_G14_CASE_COUNT_BAD');return $bad.ToArray()
 }
 if((@($results|ForEach-Object Test) -join ',') -cne ($names -join ',')){
    $bad.Add('R107_MISSING_OR_REORDERED_CASE')
 }
 $count=0
 foreach($case in $results){
    if($case.Status -cnotin @('PASS_DIAGNOSTIC','FAIL_DIAGNOSTIC') -or
       $case.StdoutSHA256 -cnotmatch '^[0-9A-F]{64}$' -or
       $case.StderrSHA256 -cnotmatch '^[0-9A-F]{64}$'){
       $bad.Add('R107_INVALID_CASE_'+$case.Test);continue
    }
    if($case.Status -ceq 'PASS_DIAGNOSTIC'){
       $count++
       if($case.ExitCode -ne 0){$bad.Add('R107_FALSE_POSITIVE_EXIT_'+$case.Test)}
    }
    $out=Join-Path $root ('G14-'+$case.Test+'.out')
    $err=Join-Path $root ('G14-'+$case.Test+'.err')
    if(!(Test-Path -LiteralPath $out -PathType Leaf) -or
       !(Test-Path -LiteralPath $err -PathType Leaf) -or
       (Get-FileHash -LiteralPath $out -Algorithm SHA256).Hash -cne $case.StdoutSHA256 -or
       (Get-FileHash -LiteralPath $err -Algorithm SHA256).Hash -cne $case.StderrSHA256){
       $bad.Add('R107_RAW_STDOUT_STDERR_SHA_'+$case.Test)
    }
 }
 if($count -ne $r.DiagnosticPasses){$bad.Add('R107_PASS_COUNT_FALSE')}
 return $bad.ToArray()
}
$errors=@(Check-R107 $receipt)
if($errors.Count){throw ('R107_INDEPENDENT_PRIVATE_CANDIDATE_REFUSED '+($errors -join ','))}
if($SelfTest){
  $original=Get-Content -LiteralPath $ReceiptPath -Raw
  $hostiles=@(
    @{K='FormalG14Accepted';V=$true},
    @{K='CandidateIsPublicRelease';V=$true},
    @{K='CandidateAuthenticodeSigned';V=$true},
    @{K='TrustedIndependentLabWitness';V='FAKE'},
    @{K='HostRole';V='PERSONAL'},
    @{K='CandidateMainSHA256';V=('0'*64)},
    @{K='CandidateSetupSHA256';V=('0'*64)},
    @{K='CandidateConfigSHA256';V=('0'*64)},
    @{K='OwnedSetupInstallExit';V=1},
    @{K='OwnedSetupUninstallExit';V=1},
    @{K='Cleanup';V='UNKNOWN'},
    @{K='DiagnosticPasses';V=9},
    @{K='DiagnosticAttempts';V=7},
    @{K='SystemRestarted';V=$true},
    @{K='PublicReleaseModified';V=$true},
    @{K='EventCommit';V=('0'*40)}
  )
  foreach($h in $hostiles){
    $r=$original|ConvertFrom-Json
    $r.($h.K)=$h.V
    if(@(Check-R107 $r).Count -eq 0){throw ('R107_HOSTILE_FALSE_ACCEPT_'+$h.K)}
  }
  $r=$original|ConvertFrom-Json
  $r.DiagnosticResults[0].StdoutSHA256=('0'*64)
  if(@(Check-R107 $r).Count -eq 0){throw 'R107_FALSE_RAW_SHA_ACCEPTED'}
  $r=$original|ConvertFrom-Json
  $r.CleanupAudit.AppRootExists=$true
  if(@(Check-R107 $r).Count -eq 0){throw 'R108_FALSIFIED_CLEANUP_ACCEPTED'}
  Write-Output 'R108_EIGHTEEN_HOSTILE_VERIFIER_CASES_REJECTED'
}
Write-Output ('R107_CANDIDATE_INSTALLED_INDEPENDENT_EIGHT_ATTEMPTS='+$receipt.DiagnosticPasses+
  '/8 FORMAL_G14_NOT_ACCEPTED RECEIPT_SHA256='+
  (Get-FileHash -LiteralPath $ReceiptPath -Algorithm SHA256).Hash)
exit 0
