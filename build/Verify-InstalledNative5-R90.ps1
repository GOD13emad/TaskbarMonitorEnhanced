# R90 independent native five-suite acceptance of ACTUALLY INSTALLED public unsigned Main
# on a disposable GitHub-hosted Windows. Read-only post-uninstall; never GUI/wallpaper mutation.
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$ReceiptPath,
  [Parameter(Mandatory=$true)][string]$SummaryPath,
  [Parameter(Mandatory=$true)][string]$GuiCapabilityPath,
  [Parameter(Mandatory=$true)][string]$ExpectedTestCommit,
  [switch]$SelfTest
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$ExpectedMainSha='63A724981E949BA4C91F8BD44F2659F223BDFE0350A2E229CEE7B05535D4BA70'
$ExpectedNames=@('startup','hover','hardware','temperature','support')
$ExpectedTag='v1.7.0-unsigned-preview.1'
if($ExpectedTestCommit -cnotmatch '^[0-9a-f]{40}$'){throw 'R90 EXACT TEST COMMIT INVALID'}
foreach($file in @($ReceiptPath,$SummaryPath,$GuiCapabilityPath)){
  if(!(Test-Path -LiteralPath $file -PathType Leaf)){throw ('R90 MISSING ACTUAL EVIDENCE FILE '+$file)}
}
$receipt=Get-Content -LiteralPath $ReceiptPath -Raw|ConvertFrom-Json
$summary=Get-Content -LiteralPath $SummaryPath -Raw|ConvertFrom-Json
$gui=Get-Content -LiteralPath $GuiCapabilityPath -Raw|ConvertFrom-Json
function Validate-Controls([psobject]$R,[psobject]$S,[psobject]$G,[string]$Commit){
  $errors=[Collections.Generic.List[string]]::new()
  $requiredReceipt=@('InstalledNativeFiveStatus','InstalledNativeFiveCases','InstalledNativeFiveSummarySHA256',
  'GuiSessionCapabilityReport','Status','PublicTag','EventCommit','ReleasedSource','InstalledMainSHA256',
  'InstallExitCode','UninstallExitCode','HeadlessSubsetOnly','FullSignedStableAccepted','RealInteractiveG14EightProbes')
  foreach($key in $requiredReceipt){if($null -eq $R.PSObject.Properties[$key]){$errors.Add('MISSING_RECEIPT_'+$key)}}
  if($errors.Count -gt 0){return $errors.ToArray()}
  if($R.Status -cne 'PASS_EPHEMERAL_HEADLESS_INSTALL_UNINSTALL' -or
     $R.PublicTag -cne $ExpectedTag -or $R.EventCommit -cne $Commit -or
     $R.InstalledMainSHA256 -cne $ExpectedMainSha -or
     $R.InstalledNativeFiveStatus -cne 'PASS_INSTALLED_MAIN_NATIVE_PORTABLE_FIVE' -or
     $R.InstalledNativeFiveCases -ne 5 -or
     $R.InstalledNativeFiveSummarySHA256 -cnotmatch '^[0-9A-F]{64}$' -or
     $R.GuiSessionCapabilityReport -cne 'R90_GUI_SESSION_READINESS.json' -or
     $R.InstallExitCode -ne 0 -or $R.UninstallExitCode -ne 0 -or
     $R.HeadlessSubsetOnly -ne $true -or $R.FullSignedStableAccepted -ne $false -or
     $R.RealInteractiveG14EightProbes -cne 'NOT_TESTED'){$errors.Add('RECEIPT_NOT_LIMITED_INSTALLED5')}
  if($null -eq $S.PSObject.Properties['Results'] -or
     $S.Status -cne 'PASS' -or $S.Mode -cne 'CI_PORTABLE_5' -or
     $S.ExecutableSHA256 -cne $ExpectedMainSha){$errors.Add('SUMMARY_NOT_TRUE_INSTALLED5')}
  else {
    $names=@($S.Results|ForEach-Object {[string]$_.Test})
    if($names.Count -ne 5 -or @($names|Select-Object -Unique).Count -ne 5 -or
       @($names|Where-Object {$_ -notin $ExpectedNames}).Count -ne 0){$errors.Add('CASE_NAMES_COUNT')}
    foreach($c in $S.Results){
      if($c.Status -cne 'PASS' -or $c.ExitCode -ne 0 -or
         $c.StdoutSHA256 -cnotmatch '^[0-9A-F]{64}$' -or
         $c.StderrSHA256 -cnotmatch '^[0-9A-F]{64}$'){$errors.Add('CASE_NOT_VERIFIED_'+$c.Test)}
    }
  }
  if($G.Schema -ne 1 -or $G.Revision -cne 'R90' -or
     $G.HostRole -cne 'GITHUB_HOSTED_EPHEMERAL_WINDOWS' -or $G.EventCommit -cne $Commit -or
     $G.ProductWallpaperApplyInvoked -ne $false -or $G.WallpaperMutation -ne $false -or
     $G.ApprovedForG13Positive -ne $false -or
     $G.G13ReadinessVerdict -cne 'READ_ONLY_PROBE_NOT_G13_POSITIVE_ACCEPTANCE'){$errors.Add('GUI_READINESS_FALSE_ACCEPTANCE')}
  return $errors.ToArray()
}
$issues=@(Validate-Controls $receipt $summary $gui $ExpectedTestCommit)
if($issues.Count -ne 0){throw ('R90 INDEPENDENT CONTROL REJECTED: '+($issues -join ','))}
$sumSHA=(Get-FileHash -LiteralPath $SummaryPath).Hash
if($receipt.InstalledNativeFiveSummarySHA256 -cne $sumSHA){throw 'R90 ACTUAL SUMMARY FILE HASH DIFFERENCE'}
$folder=Split-Path -Parent $SummaryPath
foreach($case in $summary.Results){
  foreach($suffix in @('out','err')){
     $file=Join-Path $folder ($case.Test+'.'+$suffix)
     $digest=if($suffix -ceq 'out'){$case.StdoutSHA256}else{$case.StderrSHA256}
     if(!(Test-Path -LiteralPath $file -PathType Leaf) -or
        (Get-FileHash -LiteralPath $file).Hash -cne [string]$digest){throw ('R90 RAW HOST CASE HASH MISMATCH: '+$case.Test+$suffix)}
  }
}
if($SelfTest){
  $fixtureReceipt=Get-Content -LiteralPath $ReceiptPath -Raw
  $fixtureSummary=Get-Content -LiteralPath $SummaryPath -Raw
  $fixtureGui=Get-Content -LiteralPath $GuiCapabilityPath -Raw
  $scenarios=@(
      @{Name='WRONG_INSTALLED_SHA';Object='receipt';Field='InstalledMainSHA256';Value=('0'*64)},
      @{Name='CLAIM_FULL_G14';Object='receipt';Field='RealInteractiveG14EightProbes';Value='PASS'},
      @{Name='FALSE_NATIVE_FIVE';Object='receipt';Field='InstalledNativeFiveStatus';Value='NOT_RUN'},
      @{Name='FALSE_NATIVE_COUNT';Object='receipt';Field='InstalledNativeFiveCases';Value=8},
      @{Name='FAKE_SUMMARY_PASS';Object='summary';Field='Status';Value='FAIL'},
      @{Name='WRONG_CASE_COUNT';Object='summary';Field='Results';Value=@()},
      @{Name='GUI_FALSE_G13';Object='gui';Field='ApprovedForG13Positive';Value=$true},
      @{Name='WRONG_TEST_COMMIT';Object='gui';Field='EventCommit';Value=('0'*40)}
  )
  foreach($scenario in $scenarios){
     $r=$fixtureReceipt|ConvertFrom-Json
     $s=$fixtureSummary|ConvertFrom-Json
     $g=$fixtureGui|ConvertFrom-Json
     switch($scenario.Object){
       'receipt' {$r.($scenario.Field)=$scenario.Value}
       'summary' {$s.($scenario.Field)=$scenario.Value}
       'gui' {$g.($scenario.Field)=$scenario.Value}
     }
     $rejected=@(Validate-Controls $r $s $g $ExpectedTestCommit)
     if($rejected.Count -eq 0){throw ('R90 NEGATIVE FIXTURE FALSELY ACCEPTED '+$scenario.Name)}
  }
  Write-Output 'R90_INDEPENDENT_NATIVE_FIVE_EIGHT_NEGATIVES_PASS'
}
Write-Output ('R90_ACTUAL_INSTALLED_NATIVE_FIVE_VERIFIED_PASS COUNT=5 SUMMARY_SHA256='+$sumSHA+
    ' HOST_READINESS_ONLY_NO_G13_ACCEPTANCE=TRUE')
exit 0
