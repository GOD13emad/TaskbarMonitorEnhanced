# R122: independent physical screenshot / Win32 foreground witness acceptance, exact real OS process wait-bound PID.
# Never synthesizes missing images, revises passing criteria or touches installed app.
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$ManifestPath,
 [Parameter(Mandatory=$true)][string]$CandidateMainPath,
 [Parameter(Mandatory=$true)][string]$ExpectedCommit,
 [Parameter(Mandatory=$true)][string]$ExpectedMainSha256,
 [Parameter(Mandatory=$true)][int]$ExpectedProbePid,
 [switch]$SelfTest
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($ExpectedCommit -cnotmatch '^[0-9a-f]{40}$' -or
   $ExpectedMainSha256 -cnotmatch '^[0-9A-F]{64}$'){
 throw 'R121_EXPECTED_SHA_OR_COMMIT_INVALID'
}
foreach($f in @($ManifestPath,$CandidateMainPath)){
 if(!(Test-Path -LiteralPath $f -PathType Leaf)){throw ('R121_MISSING_FILE '+$f)}
}
if($ExpectedProbePid -le 0){throw 'R122_PROBE_PID_MISSING'}
if((Get-FileHash -LiteralPath $CandidateMainPath -Algorithm SHA256).Hash -cne $ExpectedMainSha256){
 throw 'R121_MAIN_EXACT_SHA_MISMATCH'
}
$t=Get-Content -LiteralPath $ManifestPath -Raw|ConvertFrom-Json
function Verify-Native-R121($p){
 $bad=[Collections.Generic.List[string]]::new()
 foreach($key in @('Schema','Revision','EventCommit','Status','Test',
   'MainPid','SettingsPid','ObstaclePid','SettingsHwnd','ForegroundHwnd',
   'ForegroundBeforeClick','ClickPoint','SettingsTitleHit','RealMouseInputEvents','RealMouseClickAttempts',
   'ObstacleHwnd','SettingsNativeExStyle','ObstacleNativeExStyle',
   'ForegroundIsSettings','SettingsVisibleUncloaked','SettingsHasNoOwner',
   'SettingsTopMostAndActivatable','SettingsBounds','ObstacleBounds',
   'ObstaclePhysicalPinkBefore','ObstaclePhysicalPinkLeakingAfter',
   'SettingsPhysicalSaturatedPixels','SettingsPhysicalDistinctColors',
   'SettingsScreenshotSha256','ObstacleScreenshotSha256','FormalExternalLabAccepted')){
    if($null -eq $p.PSObject.Properties[$key]){$bad.Add('MISSING_'+$key)}
 }
 if($bad.Count){return $bad.ToArray()}
 if($p.Schema -ne 1 -or $p.Revision -cne 'R121' -or
    $p.EventCommit -cne $ExpectedCommit -or $p.Status -cne 'PASS' -or
    $p.Test -cne 'R121_USER_CLICK_SETTINGS_NATIVE_FOREGROUND_OVER_GLASS' -or
    $p.MainPid -ne $ExpectedProbePid -or $p.SettingsPid -ne $p.MainPid -or
    $p.ObstaclePid -ne $p.MainPid -or
    $p.SettingsHwnd -eq 0 -or $p.ForegroundHwnd -ne $p.SettingsHwnd -or
    $p.ObstacleHwnd -eq 0 -or $p.ObstacleHwnd -eq $p.SettingsHwnd -or
    $p.ForegroundIsSettings -ne $true -or $p.SettingsTitleHit -ne $true -or
    $p.RealMouseClickAttempts -lt 1 -or $p.RealMouseClickAttempts -gt 3 -or
    $p.RealMouseInputEvents -ne (2*$p.RealMouseClickAttempts) -or
    $p.SettingsVisibleUncloaked -ne $true -or
    $p.SettingsHasNoOwner -ne $true -or $p.SettingsTopMostAndActivatable -ne $true -or
    $p.FormalExternalLabAccepted -ne $false){
    $bad.Add('REAL_NATIVE_FOREGROUND_OR_PROCESS_WRONG')
 }
 $noactivate=[long]0x08000000;$layered=[long]0x00080000;$toolwindow=[long]0x80;$topmost=[long]8
 if((([long]$p.SettingsNativeExStyle -band $topmost) -eq 0) -or
    (([long]$p.SettingsNativeExStyle -band ($noactivate -bor $toolwindow)) -ne 0) -or
    (([long]$p.ObstacleNativeExStyle -band ($topmost -bor $noactivate -bor $layered)) -ne
      ($topmost -bor $noactivate -bor $layered))){
    $bad.Add('R121_NATIVE_ZBAND_OR_GLASS_STYLES_INVALID')
 }
 $r=@($p.SettingsBounds)
 $o=@($p.ObstacleBounds)
 $click=@($p.ClickPoint)
 if($click.Count -ne 2){$bad.Add('R121_MISSING_NATIVE_PHYSICAL_CLICK');return $bad.ToArray()}
 if($r.Count -eq 4 -and ($click[0] -ne ($r[0]+120) -or $click[1] -ne ($r[1]+15))){
   $bad.Add('R121_CLICK_WRONG_LOCATION')
 }
 if($r.Count -ne 4 -or $o.Count -ne 4){$bad.Add('R121_RECT_MISSING');return $bad.ToArray()}
 if($r[2] -ne 900 -or $r[3] -ne 650 -or $o[2] -ne 440 -or $o[3] -ne 220 -or
    $o[0] -lt $r[0] -or $o[1] -lt $r[1] -or $o[0]+$o[2] -gt $r[0]+$r[2] -or
    $o[1]+$o[3] -gt $r[1]+$r[3]){
    $bad.Add('R121_EXPECTED_REAL_ONSCREEN_OVERLAP_INVALID')
 }
 if($p.ObstaclePhysicalPinkBefore -lt 2000 -or
    $p.ObstaclePhysicalPinkLeakingAfter -ge 100 -or
    $p.SettingsPhysicalSaturatedPixels -lt 150 -or
    $p.SettingsPhysicalDistinctColors -lt 24){
    $bad.Add('R121_PHYSICAL_SCREEN_FAILURE')
 }
 if($p.SettingsScreenshotSha256 -cnotmatch '^[0-9A-F]{64}$' -or
    $p.ObstacleScreenshotSha256 -cnotmatch '^[0-9A-F]{64}$'){
    $bad.Add('R121_SCREENSHOT_SHA_MISSING')
 }
 return $bad.ToArray()
}
$reasons=@(Verify-Native-R121 $t)
if($reasons.Count){throw ('R121_NATIVE_SETTINGS_PROOF_REJECTED '+($reasons -join ','))}
$dir=Split-Path -Parent ([IO.Path]::GetFullPath($ManifestPath))
Add-Type -AssemblyName System.Drawing
$files=@(
 @{Name='SETTINGS_REAL_FOREGROUND.png';Width=900;Height=650;Hash=$t.SettingsScreenshotSha256},
 @{Name='TOPMOST_GLASS_OBSTRUCTION_BEFORE.png';Width=440;Height=220;Hash=$t.ObstacleScreenshotSha256}
)
$realSat=0;$realPink=0;$realColors=0;$witnessPink=0
foreach($f in $files){
 $path=Join-Path $dir $f.Name
 if(!(Test-Path -LiteralPath $path -PathType Leaf) -or
    (Get-Item -LiteralPath $path).Length -lt 5000 -or
    (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $f.Hash){
    throw ('R121_SCREENSHOT_MISSING_TOO_SMALL_OR_SHA_DRIFT '+$f.Name)
 }
 $bmp=[Drawing.Bitmap]::new($path)
 try{
  if($bmp.Width -ne $f.Width -or $bmp.Height -ne $f.Height){
   throw ('R121_SCREENSHOT_GEOMETRY '+$f.Name)
  }
  $sat=0;$pink=0;$colors=[Collections.Generic.HashSet[int]]::new()
  for($y=0;$y -lt $bmp.Height;$y+=2){
   for($x=0;$x -lt $bmp.Width;$x+=2){
    $v=$bmp.GetPixel($x,$y)
    $max=[Math]::Max($v.R,[Math]::Max($v.G,$v.B))
    $min=[Math]::Min($v.R,[Math]::Min($v.G,$v.B))
    if($max -ge 80 -and ($max-$min) -ge 24){$sat++}
    if($v.R -gt 170 -and $v.B -gt 100 -and $v.G -lt 65){$pink++}
    [void]$colors.Add($v.ToArgb())
   }
  }
  if($f.Name -eq 'SETTINGS_REAL_FOREGROUND.png'){
   $realSat=$sat;$realPink=$pink;$realColors=$colors.Count
  }else{$witnessPink=$pink}
 }finally{$bmp.Dispose()}
}
if($realSat -ne $t.SettingsPhysicalSaturatedPixels -or
   $realColors -ne $t.SettingsPhysicalDistinctColors -or
   $realSat -lt 150 -or $realColors -lt 24 -or
   $realPink -ge 100 -or $witnessPink -ne $t.ObstaclePhysicalPinkBefore -or
   $witnessPink -lt 2000){
 throw ('R121_INDEPENDENT_REAL_SCREEN_PIXELS_REFUSED SAT='+$realSat+
   ' COLORS='+$realColors+' MAGENTA_LEAK='+$realPink+
   ' WITNESS='+$witnessPink)
}
if($SelfTest){
 $mutants=@(
   @{K='Status';V='FAIL'},
   @{K='EventCommit';V=('0'*40)},
   @{K='MainPid';V=0},
   @{K='ForegroundHwnd';V=0},
   @{K='ForegroundIsSettings';V=$false},
   @{K='SettingsVisibleUncloaked';V=$false},
   @{K='SettingsHasNoOwner';V=$false},
   @{K='SettingsTopMostAndActivatable';V=$false},
   @{K='ObstaclePhysicalPinkBefore';V=0},
   @{K='ObstaclePhysicalPinkLeakingAfter';V=3000},
   @{K='SettingsPhysicalSaturatedPixels';V=0},
   @{K='FormalExternalLabAccepted';V=$true},
   @{K='SettingsTitleHit';V=$false},
   @{K='RealMouseInputEvents';V=0},
   @{K='RealMouseClickAttempts';V=0}
 )
 foreach($m in $mutants){
  $mutated=(Get-Content -LiteralPath $ManifestPath -Raw|ConvertFrom-Json)
  $mutated.($m.K)=$m.V
  if(@(Verify-Native-R121 $mutated).Count -eq 0){
   throw ('R121_HOSTILE_MUTANT_ACCEPTED '+$m.K)
  }
 }
 Write-Output 'R121_FIFTEEN_HOSTILE_FOREGROUND_RECEIPT_MUTANTS_REJECTED'
}
Write-Output ('R122_INDEPENDENT_PID_BOUND_SETTINGS_FOREGROUND=PASS COMMIT='+$ExpectedCommit+
 ' PROBE_PID='+$ExpectedProbePid+' SETTINGS_SAT='+$realSat+' COLORS='+$realColors+
 ' FOREGROUND_OBSTACLE_PINK_BEFORE='+$witnessPink+
 ' LEAK_AFTER='+$realPink+' RECEIPT_SHA256='+
 (Get-FileHash -LiteralPath $ManifestPath -Algorithm SHA256).Hash)
exit 0
