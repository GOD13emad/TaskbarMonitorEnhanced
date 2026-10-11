# R91 read-only independent verification of actual WallpaperStudio product ApplyDesktop
# and private rollback on DISPOSABLE interactive Windows using synthetic static Picture.
# Does not confer formal G13 trusted lab witness acceptance.
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$CanaryDirectory,
 [Parameter(Mandatory=$true)][string]$ExpectedTestCommit,
 [switch]$SelfTest
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$PublicMain='63A724981E949BA4C91F8BD44F2659F223BDFE0350A2E229CEE7B05535D4BA70'
$PublicSource='eeac48c2ff201326c6a59e7ccc21c72c9a676160'
if($ExpectedTestCommit -cnotmatch '^[a-f0-9]{40}$'){throw 'R91 VALIDATOR EXPECTED COMMIT INVALID'}
$Root=[IO.Path]::GetFullPath($CanaryDirectory)
$ReceiptFile=Join-Path $Root 'R91_G13_CANARY_RECEIPT.json'
$EventsFile=Join-Path $Root 'raw\wallpaper\product-events.json'
$ManifestFile=Join-Path $Root 'R91_G13_RAW_MANIFEST.json'
$RawFiles=@('raw/wallpaper/before.bin','raw/wallpaper/applied.bin','raw/wallpaper/restored.bin','raw/wallpaper/product-events.json')
foreach($file in @($ReceiptFile,$EventsFile,$ManifestFile)){
 if(!(Test-Path -LiteralPath $file -PathType Leaf)){throw ('R91 HOST G13 PROOF MISSING '+$file)}
}
$receipt=Get-Content $ReceiptFile -Raw|ConvertFrom-Json
$events=Get-Content $EventsFile -Raw|ConvertFrom-Json
$manifest=Get-Content $ManifestFile -Raw|ConvertFrom-Json
function Validate-ActualCanary([psobject]$R,[psobject]$E,[psobject]$M,[string]$Commit){
  $errors=[Collections.Generic.List[string]]::new()
  $required=@('Schema','Revision','EventCommit','Status','SourceSHA','InstalledMainSHA256',
    'HostRole','HostSessionId','ExplorerInSameSessionCount','ProductApplyStatus',
    'ProductRestoreStatus','NegativeDynamicModeStatus','OriginalHostRestorationStatus',
    'BeforeImageSHA256','AppliedImageSHA256','RestoredImageSHA256','FormalG13Accepted',
    'IndependentLabWitnessSignature','UserPersonalWallpaperTouched','Error','RestorationError')
  foreach($key in $required){if($null -eq $R.PSObject.Properties[$key]){$errors.Add('MISSING_'+$key)}}
  if($errors.Count -gt 0){return $errors.ToArray()}
  if($R.Schema -ne 1 -or $R.Revision -cne 'R91' -or $R.EventCommit -cne $Commit -or
     $R.SourceSHA -cne $PublicSource -or $R.InstalledMainSHA256 -cne $PublicMain -or
     $R.Status -cne 'PASS_ACTUAL_WALLPAPER_APPLY_RESTORE_DISPOSABLE_INTERACTIVE' -or
     $R.HostRole -cne 'GITHUB_HOSTED_DISPOSABLE_INTERACTIVE_WINDOWS' -or
     $R.HostSessionId -lt 1 -or $R.ExplorerInSameSessionCount -lt 1){$errors.Add('HOST_OR_SOURCE_MISMATCH')}
  if($R.ProductApplyStatus -cne 'PRODUCT_APPLY_RETURNED' -or
     $R.ProductRestoreStatus -cne 'PASS_EXACT_PRODUCT_APPLY_THEN_RESTORE' -or
     $R.NegativeDynamicModeStatus -cne 'PASS_REAL_PRODUCT_REJECTED_DYNAMIC_SLIDESHOW' -or
     $R.OriginalHostRestorationStatus -cne 'PASS_ORIGINAL_HOST_REGISTRY_AND_ORIGINAL_FILE_SHA'){$errors.Add('PRODUCT_TRANSACTION_NOT_PROVEN')}
  if($R.FormalG13Accepted -ne $false -or
     $R.IndependentLabWitnessSignature -cne 'MISSING_NOT_FORMAL_G13_ACCEPTANCE' -or
     $R.UserPersonalWallpaperTouched -ne $false){$errors.Add('FALSE_SIGNED_INDEPENDENT_G13_CLAIM')}
  foreach($shaProp in @('BeforeImageSHA256','AppliedImageSHA256','RestoredImageSHA256')){
    if([string]$R.($shaProp) -cnotmatch '^[A-Fa-f0-9]{64}$'){$errors.Add('INVALID_'+$shaProp)}
  }
  if($R.BeforeImageSHA256 -cne $R.RestoredImageSHA256 -or
     $R.BeforeImageSHA256 -ceq $R.AppliedImageSHA256){$errors.Add('NO_REAL_CHANGED_IMAGE_THEN_ROLLBACK')}
  if($R.Error -ne '' -or $R.RestorationError -ne ''){$errors.Add('UNRESOLVED_ERROR')}
  if($E.ProductClass -cne 'WallpaperStudio' -or $E.SourceSHA -cne $PublicSource -or
     $E.EventCommit -cne $Commit -or
     $E.ApplyDesktopInvoked -ne $true -or
     $E.RestoreDesktopPreStateInvoked -ne $true -or
     $E.IndependentAfterStateObserved -ne $true -or
     $E.NegativeSlideshowRefusalObserved -ne $true -or
     $E.ProcessId -lt 1){$errors.Add('NO_REAL_PRODUCT_EVENT_CHAIN')}
  if($null -eq $E.PSObject.Properties['BeforeRegistry'] -or $null -eq $E.PSObject.Properties['AfterRegistry']){
      $errors.Add('REGISTRY_SNAPSHOT_MISSING')
  }else {
    foreach($field in @('WallPaper','WallpaperStyle','TileWallpaper','BackgroundType')){
      if($E.BeforeRegistry.($field) -cne $E.AfterRegistry.($field)){$errors.Add('UNRESTORED_REGISTRY_'+$field)}
    }
    if($E.BeforeRegistry.BackgroundType -ne 0 -or $E.AfterRegistry.BackgroundType -ne 0){$errors.Add('NONSTATIC_PICTURE_PRE_OR_POST')}
  }
  if($M.Schema -ne 1 -or $M.Revision -cne 'R91' -or $M.EventCommit -cne $Commit -or
     $M.Status -cne 'PASS_ACTUAL_WALLPAPER_APPLY_RESTORE_DISPOSABLE_INTERACTIVE' -or
     $M.FormalG13Accepted -ne $false -or $M.SignedIndependentWitness -ne $false -or
     @($M.Files).Count -ne 4){$errors.Add('G13_RAW_MANIFEST_WRONG')}
  return $errors.ToArray()
}
$issues=@(Validate-ActualCanary $receipt $events $manifest $ExpectedTestCommit)
if($issues.Count -ne 0){throw ('R91 PRODUCT_CANARY_REFUSED '+($issues -join ','))}
if(@($manifest.Files|ForEach-Object Path|Select-Object -Unique).Count -ne 4 -or
   @($manifest.Files|Where-Object {$_.Path -notin $RawFiles}).Count -ne 0){throw 'R91 RAW FILE INVENTORY WRONG'}
foreach($rec in $manifest.Files){
 $path=Join-Path $Root ([string]$rec.Path.Replace('/','\'))
 if(!(Test-Path -LiteralPath $path -PathType Leaf) -or
    (Get-Item -LiteralPath $path).Length -ne [long]$rec.Bytes -or
    (Get-FileHash -LiteralPath $path).Hash -cne [string]$rec.SHA256){
     throw ('R91 RAW WITNESS FILE BYTE/HASH MISMATCH '+$rec.Path)
 }
}
foreach($pair in @(@('raw/wallpaper/before.bin','BeforeImageSHA256'),
                   @('raw/wallpaper/applied.bin','AppliedImageSHA256'),
                   @('raw/wallpaper/restored.bin','RestoredImageSHA256'))){
  $file=Join-Path $Root ($pair[0].Replace('/','\'))
  if((Get-FileHash -LiteralPath $file).Hash -cne [string]$receipt.($pair[1])){throw ('R91 REAL IMAGE RECEIPT SHA MISMATCH '+$pair[1])}
}
if($SelfTest){
 $rraw=Get-Content $ReceiptFile -Raw
 $eraw=Get-Content $EventsFile -Raw
 $mraw=Get-Content $ManifestFile -Raw
 $cases=@(
   @{Name='FAKE_SIGNED_WITNESS';Obj='receipt';Field='FormalG13Accepted';Value=$true},
   @{Name='INCORRECT_RESTORED_SHA';Obj='receipt';Field='RestoredImageSHA256';Value=('0'*64)},
   @{Name='NO_REAL_APPLY';Obj='receipt';Field='ProductApplyStatus';Value='NOT_RUN'},
   @{Name='NO_RUNNER_ROLLBACK';Obj='receipt';Field='OriginalHostRestorationStatus';Value='FAIL'},
   @{Name='DYNAMIC_NOT_REJECTED';Obj='receipt';Field='NegativeDynamicModeStatus';Value='NOT_RUN'},
   @{Name='PRODUCT_EVENT_MISSING';Obj='events';Field='RestoreDesktopPreStateInvoked';Value=$false},
   @{Name='FALSE_DIFFERENT_IMAGE';Obj='receipt';Field='AppliedImageSHA256';Value=$receipt.BeforeImageSHA256},
   @{Name='NOT_STATIC_AFTER';Obj='events';Field='BeforeRegistry';Value=[pscustomobject]@{WallPaper='';WallpaperStyle='10';TileWallpaper='0';BackgroundType=2}}
 )
 foreach($case in $cases){
   $r=$rraw|ConvertFrom-Json
   $e=$eraw|ConvertFrom-Json
   $m=$mraw|ConvertFrom-Json
   switch($case.Obj){
     'receipt'{$r.($case.Field)=$case.Value}
     'events'{$e.($case.Field)=$case.Value}
     'manifest'{$m.($case.Field)=$case.Value}
   }
   $rejected=@(Validate-ActualCanary $r $e $m $ExpectedTestCommit)
   if($rejected.Count -eq 0){throw ('R91 NEGATIVE MUTATION FALSELY ACCEPTED '+$case.Name)}
 }
 Write-Output 'R91_REAL_PRODUCT_G13_CANARY_VERIFIER_EIGHT_NEGATIVES_PASS'
}
Write-Output ('R91_REAL_ACTUAL_STATIC_PICTURE_APPLY_RESTORE_SHA_PASS='+(Get-FileHash $ReceiptFile).Hash+
 ' FORMAL_INDEPENDENT_SIGNATURE=MISSING FULL_G13_ACCEPTANCE=UNPROVEN')
exit 0
