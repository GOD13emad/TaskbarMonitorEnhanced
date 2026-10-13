# R132 INDEPENDENT verifier of real physical screen pixels after normal-window
# activation, and exact source/installed Main identity. No synthetic images accepted.
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$ReceiptPath,
 [Parameter(Mandatory=$true)][string]$ExpectedCommit,
 [Parameter(Mandatory=$true)][string]$ExpectedMainSha256,
 [Parameter(Mandatory=$true)][ValidateSet('A','B')][string]$ExpectedHost,
 [switch]$SelfTest
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($ExpectedCommit -cnotmatch '^[0-9a-f]{40}$' -or
   $ExpectedMainSha256 -cnotmatch '^[0-9A-F]{64}$'){
 throw 'R132_INVALID_PINNED_COMMIT_OR_MAIN_SHA'
}
if(!(Test-Path -LiteralPath $ReceiptPath -PathType Leaf)){
 throw 'R132_MISSING_RAW_PHYSICAL_RECEIPT'
}
$r=Get-Content -LiteralPath $ReceiptPath -Raw | ConvertFrom-Json
function Check-R132Receipt($item){
 $reasons=[Collections.Generic.List[string]]::new()
 foreach($key in @('Schema','Revision','Commit','Status','Phase','Host','MainSHA256',
  'MainPid','TaskbarHwnd','TaskbarRect','OverlayHwnd','OverlayRect',
  'NativeGlassBefore','BeforeColored','AfterColored','AlignedColoredPixels',
  'FirstScreenshotSha256','ForegroundWindows','GlassModeOn','SavedOpacityWhenOff',
  'BackgroundOpacityZero','ConfigBeforeSha','ConfigRestoredSha',
  'PersonalMachineTouched','FormalExternalLabAccepted')){
  if($null -eq $item.PSObject.Properties[$key]){$reasons.Add('MISSING_'+$key)}
 }
 if($reasons.Count -gt 0){return $reasons.ToArray()}
 if($item.Schema -ne 1 -or $item.Revision -cne 'R132' -or
    $item.Commit -cne $ExpectedCommit -or $item.Status -cne 'PASS' -or
    $item.Phase -cne 'PHYSICAL_ACCEPTED' -or
    $item.MainSHA256 -cne $ExpectedMainSha256 -or
    $item.Host -cne 'GITHUB_HOSTED_DISPOSABLE_WINDOWS' -or
    $item.MainPid -le 0 -or $item.TaskbarHwnd -eq 0 -or
    $item.OverlayHwnd -eq 0 -or $item.OverlayHwnd -eq $item.TaskbarHwnd){
  $reasons.Add('R132_WRONG_SIGNED_SOURCE_PID_HWND_OR_STATUS')
 }
 $style=[long]0x08080008
 if((([long]$item.NativeGlassBefore -band $style) -ne $style)){
  $reasons.Add('R132_MISSING_LAYERED_NOACTIVATE_TOPMOST_STYLE')
 }
 $task=@($item.TaskbarRect)
 $overlay=@($item.OverlayRect)
 if($task.Count -ne 4 -or $overlay.Count -ne 4){$reasons.Add('R132_RECT_FIELD_MISSING');return $reasons.ToArray()}
 if($task[2] -lt 650 -or $task[3] -lt 25 -or
    $overlay[2] -lt 180 -or $overlay[3] -lt 25 -or $overlay[3] -gt 90 -or
    $overlay[0] -lt $task[0] -or $overlay[1] -lt $task[1] -or
    ($overlay[0]+$overlay[2]) -gt ($task[0]+$task[2]) -or
    ($overlay[1]+$overlay[3]) -gt ($task[1]+$task[3])){
  $reasons.Add('R132_MOVED_OUTSIDE_OR_RESIZED_FROM_TASKBAR')
 }
 if($item.GlassModeOn -ne $true -or $item.BackgroundOpacityZero -ne $true -or
    [Math]::Abs([double]$item.SavedOpacityWhenOff-0.31) -gt 0.0001 -or
    $item.PersonalMachineTouched -ne $false -or
    $item.FormalExternalLabAccepted -ne $false -or
    $item.ConfigBeforeSha -cnotmatch '^[A-F0-9]{64}$' -or
    $item.ConfigBeforeSha -cne $item.ConfigRestoredSha){
  $reasons.Add('R132_GLASS_FIXTURE_OR_CONFIG_NOT_RESTORED')
 }
 if($item.BeforeColored -lt 300 -or $item.AfterColored -lt 300 -or
    $item.AlignedColoredPixels -lt 120 -or
    $item.FirstScreenshotSha256 -cnotmatch '^[A-F0-9]{64}$'){
  $reasons.Add('R132_MISSING_GENUINE_ONSCREEN_COLORED_METRICS')
 }
 $samples=@($item.ForegroundWindows)
 if($samples.Count -ne 2){$reasons.Add('R132_TWO_REAL_WINDOWS_NOT_FOUND');return $reasons.ToArray()}
 $handles=@()
 for($i=0;$i -lt 2;$i++){
  $s=$samples[$i]
  if($s.Index -ne ($i+1) -or
     $s.ForegroundHwnd -eq 0 -or $s.ForegroundHwnd -eq $item.OverlayHwnd -or
     $s.ForegroundType -cne 'real ordinary WinForms form, TopMost=false' -or
     $s.ColoredPixels -lt 300 -or
     $s.PhysicalPng -cne ('R132_NORMAL_FOCUS_'+($i+1)+'.png') -or
     $s.PngSha256 -cnotmatch '^[0-9A-F]{64}$'){
    $reasons.Add('R132_REAL_USER_FOREGROUND_OR_PHYSICAL_PNG_'+($i+1))
  }
  $handles+=@($s.ForegroundHwnd)
 }
 if($handles[0] -eq $handles[1]){
  $reasons.Add('R132_NO_TWO_INDEPENDENT_ORDINARY_WINDOWS')
 }
 return $reasons.ToArray()
}
$failure=@(Check-R132Receipt $r)
if($failure.Count){throw ('R132_RECEIPT_FAIL_CLOSED '+($failure -join '; '))}
if($SelfTest){
 $mutants=@(
  @{Property='Status';Val='FAIL'},
  @{Property='Commit';Val=('0'*40)},
  @{Property='MainPid';Val=0},
  @{Property='NativeGlassBefore';Val=0},
  @{Property='OverlayHwnd';Val=0},
  @{Property='BeforeColored';Val=0},
  @{Property='AfterColored';Val=0},
  @{Property='AlignedColoredPixels';Val=0},
  @{Property='GlassModeOn';Val=$false},
  @{Property='BackgroundOpacityZero';Val=$false},
  @{Property='SavedOpacityWhenOff';Val=0.97},
  @{Property='ConfigRestoredSha';Val=('0'*64)},
  @{Property='PersonalMachineTouched';Val=$true}
 )
 foreach($m in $mutants){
  $modified=($r|ConvertTo-Json -Depth 12|ConvertFrom-Json)
  $modified.($m.Property)=$m.Val
  if(@(Check-R132Receipt $modified).Count -eq 0){
   throw ('R132_HOSTILE_RECEIPT_ACCEPTED '+$m.Property)
  }
 }
 Write-Output 'R132_THIRTEEN_HOSTILE_FOREGROUND_AND_GLASS_RECEIPT_MUTANTS_REJECTED'
}
$dir=Split-Path -Parent ([IO.Path]::GetFullPath($ReceiptPath))
Add-Type -AssemblyName System.Drawing
function Saturation([Drawing.Bitmap]$bitmap){
 $n=0
 for($yy=0;$yy -lt $bitmap.Height;$yy++){
  for($xx=0;$xx -lt $bitmap.Width;$xx++){
   $p=$bitmap.GetPixel($xx,$yy)
   $high=[Math]::Max($p.R,[Math]::Max($p.G,$p.B))
   $low=[Math]::Min($p.R,[Math]::Min($p.G,$p.B))
   if($high -ge 70 -and ($high-$low) -ge 25){$n++}
  }
 }
 return $n
}
$paths=@(
 @{Name='R132_BEFORE_ORDINARY_WINDOW.png';Sha=$r.FirstScreenshotSha256;Count=$r.BeforeColored},
 @{Name='R132_NORMAL_FOCUS_1.png';Sha=$r.ForegroundWindows[0].PngSha256;Count=$r.ForegroundWindows[0].ColoredPixels},
 @{Name='R132_NORMAL_FOCUS_2.png';Sha=$r.ForegroundWindows[1].PngSha256;Count=$r.ForegroundWindows[1].ColoredPixels}
)
$bitmaps=@()
try{
 foreach($entry in $paths){
  $f=Join-Path $dir $entry.Name
  if(!(Test-Path -LiteralPath $f -PathType Leaf) -or (Get-Item $f).Length -lt 250){
   throw ('R132_RAW_PNG_NOT_ON_DISK '+$entry.Name)
  }
  if((Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash -cne $entry.Sha){
   throw ('R132_SCREENSHOT_SHA_MISMATCH '+$entry.Name)
  }
  $b=[Drawing.Bitmap]::new($f)
  $bitmaps+=@($b)
  if($b.Width -ne $r.OverlayRect[2] -or $b.Height -ne $r.OverlayRect[3]){
   throw ('R132_PHYSICAL_SCREENSHOT_NOT_REAL_NATIVE_RECT '+$entry.Name)
  }
  $physical= Saturation $b
  if($physical -ne $entry.Count -or $physical -lt 300){
   throw ('R132_INDEPENDENT_SATURATION_REFUSED '+$entry.Name+' COUNT='+$physical)
  }
 }
 $aligned=0
 for($yy=0;$yy -lt $bitmaps[0].Height;$yy++){
  for($xx=0;$xx -lt $bitmaps[0].Width;$xx++){
   $a=$bitmaps[0].GetPixel($xx,$yy)
   $b=$bitmaps[2].GetPixel($xx,$yy)
   $aMax=[Math]::Max($a.R,[Math]::Max($a.G,$a.B))
   $aMin=[Math]::Min($a.R,[Math]::Min($a.G,$a.B))
   $bMax=[Math]::Max($b.R,[Math]::Max($b.G,$b.B))
   $bMin=[Math]::Min($b.R,[Math]::Min($b.G,$b.B))
   if($aMax -ge 70 -and ($aMax-$aMin) -ge 25 -and
      $bMax -ge 70 -and ($bMax-$bMin) -ge 25){$aligned++}
  }
 }
 if($aligned -ne $r.AlignedColoredPixels -or $aligned -lt 120){
  throw ('R132_INDEPENDENT_ALIGNED_GLASS_INK_REJECTED '+$aligned)
 }
}finally{foreach($b in $bitmaps){$b.Dispose()}}
Write-Output ('R132_REAL_ORDINARY_WINDOW_FOREGROUND_GLASS_PHYSICAL_PASS HOST='+$ExpectedHost+
 ' SAT_BEFORE='+$r.BeforeColored+' SAT_AFTER='+$r.AfterColored+
 ' ALIGNED='+$aligned+' MANIFEST_SHA256='+(Get-FileHash $ReceiptPath -Algorithm SHA256).Hash)
exit 0
