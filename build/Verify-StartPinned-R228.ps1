# R118 independent real Windows pinned glass Start acceptance, not the legacy 60px
# float acceptance. Must prove real HWND stays inside taskbar all 24 samples and
# 300+ *physical* text/graph pixels reappear after closing Start.
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$ManifestPath,
 [Parameter(Mandatory=$true)][string]$CandidateReceiptPath,
 [Parameter(Mandatory=$true)][string]$ExpectedCommit,
 [switch]$SelfTest
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($ExpectedCommit -cnotmatch '^[0-9a-f]{40}$'){throw 'R118_EXPECTED_COMMIT_WRONG'}
if(!(Test-Path $ManifestPath -PathType Leaf) -or !(Test-Path $CandidateReceiptPath -PathType Leaf)){throw 'R118_MISSING_REAL_START_OR_INSTALLED_RECEIPT'}
$trace=Get-Content -LiteralPath $ManifestPath -Raw|ConvertFrom-Json
$candidate=Get-Content -LiteralPath $CandidateReceiptPath -Raw|ConvertFrom-Json
function Check-R118($a,$receipt) {
 $bad=[Collections.Generic.List[string]]::new()
 foreach($n in @('Schema','Revision','EventCommit','Status','Test','Stimulus','MainPid','CachedOverlayHwnd',
 'BaselineRect','PinnedSamples','RequiredPinnedSamples','ShellSamples','RequiredShellSamples',
 'InvalidSamples','RealPhysicalInkAfterStart','MainProcessAlive','PixelOcclusionWhileStartOpen',
 'Samples','BeforeStartSaturatedPixels','AfterStartSaturatedPixels','FormalExternalLabAccepted')){
   if($null -eq $a.PSObject.Properties[$n]){$bad.Add('MISSING_'+$n)}
 }
 if($bad.Count){return $bad.ToArray()}
 if($a.Schema -ne 1 -or $a.Revision -cne 'R118' -or $a.EventCommit -cne $ExpectedCommit -or
    $a.Status -cne 'PASS' -or $a.Test -cne 'REAL_PINNED_START_NO_60PX_LIFT' -or
    $a.Stimulus -cnotin @('KEYBD_EVENT_WIN','KEYBD_EVENT_CTRL_ESC') -or
    $a.MainPid -le 0 -or $a.CachedOverlayHwnd -eq 0 -or
    $a.FormalExternalLabAccepted -ne $false){
    $bad.Add('SOURCE_NATIVE_START_FORMAL_CONTRACT')
 }
 if($receipt.GitHubTestCommit -cne $ExpectedCommit -or
    $receipt.CandidateMainSHA256 -cne '5A44490034EB8A8B846FB11E7BD6954EED741F92DB53FC7A568DCCA358A5BCE2' -or
    $receipt.OfficialMainSHA256 -cne '84D5DBF6F2E6D1D2E2B3E6D9C9DA523E564A7F5240C08D34A456D934026B829F' -or
    $receipt.OfficialSetupSHA256 -cne '225BCC259C392DA04F3E0157CAF22F96C4052282AAF02555E6F6E777F4CB8AF4' -or
    $receipt.ResidentProcessId -ne $a.MainPid -or
    $receipt.HostedGlassAndPinnedConfigured -ne $true -or
    $receipt.NoOwnerComputerTouched -ne $true -or
    $receipt.NativeSourceResult -cne 'PASS'){
     $bad.Add('R228_NOT_EXACT_GUEST_RESIDENT_MAIN_AND_172_SOURCE')
 }
 $rect=@($a.BaselineRect)
 if($rect.Count -ne 4 -or $rect[2] -lt 420 -or $rect[3] -ne 48){
    $bad.Add('INVALID_ORIGINAL_TASKBAR_RECT')
    return $bad.ToArray()
 }
 if($a.PinnedSamples -ne 24 -or $a.RequiredPinnedSamples -ne 24 -or
    $a.InvalidSamples -ne 0 -or $a.ShellSamples -lt 18 -or
    $a.RequiredShellSamples -ne 18 -or
    $a.RealPhysicalInkAfterStart -ne $true -or $a.BeforeStartSaturatedPixels -lt 300 -or
    $a.AfterStartSaturatedPixels -lt 300 -or $a.MainProcessAlive -ne $true -or
    $a.PixelOcclusionWhileStartOpen -cnotmatch '^ALLOWED_BY_USER_PINNED_MODE'){
    $bad.Add('FALSIFIED_START_PIN_SHELL_OR_POST_INK')
 }
 $samples=@($a.Samples)
 if($samples.Count -ne 24){$bad.Add('NATIVE_START_NOT_24_SAMPLES');return $bad.ToArray()}
 $genuineShell=0
 for($i=0;$i -lt $samples.Count;$i++){
  $s=$samples[$i]
  if($null -eq $s -or
     $s.Sample -ne ($i+1) -or $s.ElapsedMs -ne (($i+1)*250) -or
     $s.Pinned -ne $true -or $s.OverlayHwnd -ne $a.CachedOverlayHwnd -or
     $s.MainPid -ne $a.MainPid -or $s.OwnerPid -ne $a.MainPid -or
     $s.WindowVisible -ne $true -or $s.WindowAlive -ne $true -or
     $s.Cloaked -ne 0 -or @($s.ActualRect).Count -ne 4 -or
     ($s.ActualRect -join ',') -cne ($rect -join ',')){
     $bad.Add('REAL_NATIVE_RECT_MOVED_OR_FORGED_SAMPLE_'+($i+1))
  }
  if($s.StartForeground -eq $true -or $s.StartSurface -eq $true){$genuineShell++}
 }
 if($genuineShell -lt 18 -or $genuineShell -ne $a.ShellSamples){
  $bad.Add('START_SHELL_COUNT_MISMATCH')
 }
 return $bad.ToArray()
}
$reasons=@(Check-R118 $trace $candidate)
if($reasons.Count){throw ('R118_INDEPENDENT_NATIVE_PINNED_START_REFUSED '+($reasons -join ','))}
$dir=Split-Path -Parent ([IO.Path]::GetFullPath($ManifestPath))
$images=@('PINNED_BEFORE_START.png','PINNED_DURING_START_1.png',
 'PINNED_DURING_START_4.png','PINNED_DURING_START_20.png','PINNED_AFTER_START.png')
Add-Type -AssemblyName System.Drawing
foreach($name in $images){
 $path=Join-Path $dir $name
 if(!(Test-Path $path -PathType Leaf) -or (Get-Item $path).Length -lt 100){
  throw ('R118_REAL_WINDOW_CROPPED_PNG_MISSING '+$name)
 }
 $bitmap=[Drawing.Bitmap]::new($path)
 try{
  if($bitmap.Width -ne $trace.BaselineRect[2] -or $bitmap.Height -ne $trace.BaselineRect[3]){
     throw ('R118_REAL_PNG_DIMENSIONS_MISMATCH '+$name)
  }
 }finally{$bitmap.Dispose()}
}

# R119: the native HWND may be pinned but visually covered by Start. On return,
# verify real colored metric glyphs/graphs from physical PNGs, not just a bright
# solid Windows/Start/Taskbar background. The three DURING files may legitimately
# be tiny and occluded; the BEFORE and AFTER evidence may NOT.
$beforePng=[Drawing.Bitmap]::new((Join-Path $dir 'PINNED_BEFORE_START.png'))
$afterPng=[Drawing.Bitmap]::new((Join-Path $dir 'PINNED_AFTER_START.png'))
$beforeSat=0;$afterSat=0;$alignedSat=0
try {
 for($y=0;$y -lt $beforePng.Height;$y++){
  for($x=0;$x -lt $beforePng.Width;$x++){
   $a=$beforePng.GetPixel($x,$y)
   $b=$afterPng.GetPixel($x,$y)
   $aMax=[Math]::Max($a.R,[Math]::Max($a.G,$a.B))
   $aMin=[Math]::Min($a.R,[Math]::Min($a.G,$a.B))
   $bMax=[Math]::Max($b.R,[Math]::Max($b.G,$b.B))
   $bMin=[Math]::Min($b.R,[Math]::Min($b.G,$b.B))
   $aColored=($aMax -ge 70 -and ($aMax-$aMin) -ge 25)
   $bColored=($bMax -ge 70 -and ($bMax-$bMin) -ge 25)
   if($aColored){$beforeSat++}
   if($bColored){$afterSat++}
   if($aColored -and $bColored){$alignedSat++}
  }
 }
}finally{$beforePng.Dispose();$afterPng.Dispose()}
if($beforeSat -lt 300 -or $afterSat -lt 300 -or $alignedSat -lt 120 -or
   $trace.BeforeStartSaturatedPixels -ne $beforeSat -or
   $trace.AfterStartSaturatedPixels -ne $afterSat){
  throw ('R119_REAL_POST_START_PHYSICAL_METRIC_INK_MISSING BEFORE='+
   $beforeSat+' AFTER='+$afterSat+' ALIGNED='+$alignedSat)
}
Write-Output ('R119_REAL_AFTER_START_COLOR_SATURATION_PASS BEFORE='+$beforeSat+
 ' AFTER='+$afterSat+' MATCHED_POSITIONS='+$alignedSat)

if($SelfTest){
 $raw=Get-Content -LiteralPath $ManifestPath -Raw
 $hostiles=@(
  @{Field='Status';Value='FAIL'},
  @{Field='EventCommit';Value=('0'*40)},
  @{Field='MainPid';Value=0},
  @{Field='CachedOverlayHwnd';Value=0},
  @{Field='PinnedSamples';Value=23},
  @{Field='InvalidSamples';Value=1},
  @{Field='ShellSamples';Value=0},
  @{Field='RealPhysicalInkAfterStart';Value=$false},
  @{Field='MainProcessAlive';Value=$false},
  @{Field='FormalExternalLabAccepted';Value=$true}
 )
 foreach($h in $hostiles){
  $t=$raw|ConvertFrom-Json
  $t.($h.Field)=$h.Value
  if(@(Check-R118 $t $candidate).Count -eq 0){throw ('R118_HOSTILE_FALSE_ACCEPT_'+$h.Field)}
 }
 $t=$raw|ConvertFrom-Json;$t.Samples[0].Pinned=$false
 if(@(Check-R118 $t $candidate).Count -eq 0){throw 'R118_FALSE_PINNED_SAMPLE_ACCEPTED'}
 $t=$raw|ConvertFrom-Json;$t.Samples[0].ActualRect[1]-=60
 if(@(Check-R118 $t $candidate).Count -eq 0){throw 'R118_FALSE_NATIVE_60PX_LIFT_ACCEPTED'}
 $t=$raw|ConvertFrom-Json;$t.AfterStartSaturatedPixels=0
 if(@(Check-R118 $t $candidate).Count -eq 0){throw 'R119_FALSE_INK_COUNT_ACCEPTED'}
 $t=$raw|ConvertFrom-Json;$t.Samples[0].OwnerPid=0
 if(@(Check-R118 $t $candidate).Count -eq 0){throw 'R118_FORGED_MAIN_PID_ACCEPTED'}
 $t=$raw|ConvertFrom-Json;$t.Samples[0].StartForeground=$false;$t.Samples[0].StartSurface=$false
 if(@(Check-R118 $t $candidate).Count -eq 0){throw 'R118_FALSE_START_FOREGROUND_COUNT_ACCEPTED'}
 Write-Output 'R228_FOURTEEN_ADVERSARIAL_PINNED_START_MUTANTS_REJECTED'
}
Write-Output ('R118_NATIVE_TASKBAR_PINNED_START_24_OF_24_PASS HOSTED_COMMIT='+$ExpectedCommit+
 ' REAL_POST_START_SCREEN_INK=PASS SHA='+ (Get-FileHash $ManifestPath -Algorithm SHA256).Hash)
exit 0
