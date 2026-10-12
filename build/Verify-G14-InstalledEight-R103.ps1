# R103 independent read-only validation of 8 actual installed Main diagnostic case receipts.
# Never upgrades/installs and NEVER accepts G14 without external approved signed witness.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ReceiptPath,
      [Parameter(Mandatory=$true)][string]$ExpectedCommit,
      [switch]$SelfTest)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($ExpectedCommit -cnotmatch '^[a-f0-9]{40}$'){throw 'R103 EXPECTED SOURCE COMMIT BAD'}
if(!(Test-Path -LiteralPath $ReceiptPath -PathType Leaf)){throw 'R103 RECEIPT NOT FOUND'}
$receipt=Get-Content -LiteralPath $ReceiptPath -Raw|ConvertFrom-Json
$root=Split-Path -Parent ([IO.Path]::GetFullPath($ReceiptPath))
$names=@('startup','hover','hardware','temperature','health','support','start','shell')
$mainSHA='63A724981E949BA4C91F8BD44F2659F223BDFE0350A2E229CEE7B05535D4BA70'
$configSHA='D2E51872D93F0793C02AD07DCBF8C2802F59708C666548372A4FDDDA5C7C5E4F'
function Verify-R103Record([psobject]$r) {
 $errors=[Collections.Generic.List[string]]::new()
 foreach($name in @('Schema','Revision','EventCommit','Purpose','Status',
  'ExactInstalledMainSHA256','InstalledConfigSHA256','HostRole','ExplorerSameSession',
  'UserInteractive','HostSessionId','OriginalPublicTag','ResidentStarted','ResidentProcessId',
  'ResidentPath','ResidentMainSHA256','EighthCaseNames','Results','CompletedCases','PassedCases',
  'FullInteractiveG14SignedAccepted','TrustedIndependentLabWitness','SensorLayerStatus',
  'SystemRestarted','DriverInstallPerformed','PersonalInstallTouched','PersonalWallpaperTouched',
  'Cleanup','Failure','StartedUTC','FinishedUTC')) {
     if($null -eq $r.PSObject.Properties[$name]){$errors.Add('MISSING_'+$name)}
 }
 if($errors.Count -ne 0){return $errors.ToArray()}
 if($r.Schema -ne 1 -or $r.Revision -cne 'R103' -or
    $r.EventCommit -cne $ExpectedCommit -or
    $r.Purpose -cne 'DISPOSABLE_INSTALLED_G14_EIGHT_DIAGNOSTIC_NO_FORMAL_ACCEPTANCE' -or
    $r.Status -cne 'EIGHT_RESULTS_CAPTURED_DIAGNOSTIC_ONLY' -or
    $r.HostRole -cne 'GITHUB_HOSTED_DISPOSABLE_WINDOWS'){
    $errors.Add('SOURCE_STATUS_HOST_IDENTITY')
 }
 if($r.ExactInstalledMainSHA256 -cne $mainSHA -or $r.InstalledConfigSHA256 -cne $configSHA -or
    $r.ResidentMainSHA256 -cne $mainSHA -or $r.OriginalPublicTag -cne 'v1.7.0-unsigned-preview.1' -or
    $r.UserInteractive -ne $true -or $r.ExplorerSameSession -lt 1 -or
    $r.HostSessionId -lt 1 -or $r.ResidentStarted -ne $true -or $r.ResidentProcessId -lt 1 -or
    $r.ResidentPath -cnotmatch 'TaskbarMonitorEnhanced.exe$'){$errors.Add('NOT_INSTALLED_LIVE_REAL_EIGHT_PROBE')}
 if($r.FullInteractiveG14SignedAccepted -ne $false -or
    $r.TrustedIndependentLabWitness -cne 'MISSING' -or
    $r.PersonalInstallTouched -ne $false -or $r.PersonalWallpaperTouched -ne $false -or
    $r.SystemRestarted -ne $false -or $r.DriverInstallPerformed -ne $false){
    $errors.Add('FALSE_G14_INDEPENDENT_LAB_OR_HOST_MODIFICATION')
 }
 if($r.Cleanup -cne 'PASS_EXACT_STARTED_RESIDENT_EXITED' -or
    $r.Failure -cne ''){$errors.Add('RESIDENT_NOT_RECOVERED')}
 $all=@($r.Results)
 if($all.Count -ne 8 -or $r.CompletedCases -ne 8 -or $r.PassedCases -lt 0 -or $r.PassedCases -gt 8 -or
    @($r.EighthCaseNames).Count -ne 8){
    $errors.Add('EIGHT_CASES_NOT_COMPLETE');return $errors.ToArray()
 }
 $observed=@($all|ForEach-Object Test)
 if((@($observed|Select-Object -Unique).Count -ne 8) -or
    ((($observed -join ',') -cne ($names -join ','))) -or
    ((@($r.EighthCaseNames) -join ',') -cne ($names -join ','))){
    $errors.Add('EIGHT_CASE_ORDER_OR_INVENTORY_WRONG')
 }
 $passCount=0
 foreach($a in $all){
   if($a.Status -cnotin @('PASS_DIAGNOSTIC','FAIL_DIAGNOSTIC') -or
      $a.Switch -cnotmatch '^--[a-z-]+$' -or
      $a.TimeoutMs -lt 1000 -or $a.TimeoutMs -gt 90000){
        $errors.Add('CASE_INVALID_'+$a.Test);continue
   }
   $outPath=Join-Path $root ([string]$a.Test+'.out')
   $errPath=Join-Path $root ([string]$a.Test+'.err')
   foreach($check in @(@($outPath,[string]$a.StdoutSHA256),@($errPath,[string]$a.StderrSHA256))){
      if(!(Test-Path -LiteralPath $check[0] -PathType Leaf) -or
         (Get-FileHash -LiteralPath $check[0] -Algorithm SHA256).Hash -cne $check[1]) {
         $errors.Add('RAW_CASE_HASH_FAILED_'+$a.Test)
      }
   }
   if($a.Status -ceq 'PASS_DIAGNOSTIC'){
      $passCount++
      if($a.ExitCode -ne 0 -or $a.TargetExists -ne $true -or $a.Error -cne ''){
         $errors.Add('FALSE_CASE_PASS_'+$a.Test)
      }
   }
 }
 if($passCount -ne $r.PassedCases){$errors.Add('PASS_COUNT_FALSE')}
 return $errors.ToArray()
}
$issues=@(Verify-R103Record $receipt)
if($issues.Count -ne 0){throw ('R103_G14_INDEPENDENT_FAIL_CLOSED '+($issues -join ','))}
if($SelfTest){
 $raw=Get-Content -LiteralPath $ReceiptPath -Raw
 $cases=@(
  @{Test='FALSE_SIGNED_G14';Obj='receipt';Field='FullInteractiveG14SignedAccepted';Value=$true},
  @{Test='FALSE_WITNESS';Obj='receipt';Field='TrustedIndependentLabWitness';Value='SELF'},
  @{Test='DISPOSABLE_VIOLATION';Obj='receipt';Field='HostRole';Value='PERSONAL'},
  @{Test='INSUFFICIENT_CASES';Obj='receipt';Field='CompletedCases';Value=5},
  @{Test='FALSE_SENSOR_INDEPENDENCE';Obj='receipt';Field='DriverInstallPerformed';Value=$true},
  @{Test='WRONG_EXE_SHA';Obj='receipt';Field='ExactInstalledMainSHA256';Value=('0'*64)},
  @{Test='WRONG_CONFIG_SHA';Obj='receipt';Field='InstalledConfigSHA256';Value=('0'*64)},
  @{Test='WRONG_RESTART';Obj='receipt';Field='SystemRestarted';Value=$true},
  @{Test='UNCLEAN_RESIDENT';Obj='receipt';Field='Cleanup';Value='NOT_DONE'},
  @{Test='FALSE_PASS_COUNT';Obj='receipt';Field='PassedCases';Value=9},
  @{Test='FRAUDULENT_CASE_STATUS';Obj='result';Field='Status';Value='PRODUCTION_G14_PASS'},
  @{Test='EXIT_NONZERO_PASS';Obj='result';Field='ExitCode';Value=777}
 )
 foreach($case in $cases){
    $r=$raw|ConvertFrom-Json
    if($case.Obj -ceq 'receipt'){$r.($case.Field)=$case.Value}
    else{$r.Results[0].($case.Field)=$case.Value}
    if(@(Verify-R103Record $r).Count -eq 0){
       throw ('R103_HOSTILE_MUTATION_FALSE_ACCEPT '+$case.Test)
    }
 }
 Write-Output 'R103_G14_DIAGNOSTIC_VERIFIER_TWELVE_HOSTILE_CASES_REJECTED'
}
Write-Output ('R103_G14_EIGHT_ACTUAL_INSTALLED_CASES_VERIFIED_ATTEMPTS='+$receipt.CompletedCases+
 ' PASS='+$receipt.PassedCases+' SIGNED_INDEPENDENT_G14=MISSING RECEIPT_SHA256='+
 (Get-FileHash -LiteralPath $ReceiptPath -Algorithm SHA256).Hash)
exit 0
