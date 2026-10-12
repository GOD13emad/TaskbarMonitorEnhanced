# R112 independent raw 3.2sec read-only Start activation trace validator.
# No forged green status; only Start real native rect+actual source receives evidence.
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$TracePath,
  [Parameter(Mandatory=$true)][string]$CandidateReceiptPath,
  [Parameter(Mandatory=$true)][string]$ExpectedCommit,
  [switch]$SelfTest
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($ExpectedCommit -cnotmatch '^[a-f0-9]{40}$'){throw 'R112_BAD_COMMIT'}
if(!(Test-Path -LiteralPath $TracePath -PathType Leaf) -or
   !(Test-Path -LiteralPath $CandidateReceiptPath -PathType Leaf)){
  throw 'R112_RAW_START_TIMELINE_OR_INSTALLED_RECEIPT_MISSING'
}
$trace=Get-Content -LiteralPath $TracePath -Raw|ConvertFrom-Json
$installed=Get-Content -LiteralPath $CandidateReceiptPath -Raw|ConvertFrom-Json
function Check-R112($t,$i){
  $errors=[Collections.Generic.List[string]]::new()
  foreach($name in @('Schema','Revision','EventCommit','MainPid','CachedOverlayHwnd',
    'OriginalTaskbarHwnd','StimulusMethod','ExpectedRect','BaselineRect',
    'FloatingReached','Samples','FormalG14Accepted')){
    if($null -eq $t.PSObject.Properties[$name]){$errors.Add('MISSING_'+$name)}
  }
  if($errors.Count){return $errors.ToArray()}
  if($t.Schema -ne 1 -or $t.Revision -cne 'R112' -or
     $t.EventCommit -cne $ExpectedCommit -or
     $t.MainPid -lt 1 -or $t.CachedOverlayHwnd -eq 0 -or
     $t.OriginalTaskbarHwnd -eq 0 -or
     $t.FormalG14Accepted -ne $false -or
     $t.StimulusMethod -cnotin @('KEYBD_EVENT_WIN','KEYBD_EVENT_CTRL_ESC')){
    $errors.Add('START_REAL_PROCESS_SOURCE_OR_STIMULUS_INVALID')
  }
  if($i.EventCommit -cne $ExpectedCommit -or
     $i.CandidateMainSHA256 -cne 'C417E9F7FF7D9B6D945387CA257BBC8A50627C3FDAC5431D18F7505A92D32FE2' -or
     $i.MainProcessPid -ne $t.MainPid -or
     $i.DiagnosticAttempts -ne 8 -or $i.FormalG14Accepted -ne $false){
    $errors.Add('HOSTED_REAL_INSTALLED_MAIN_NOT_BOUND')
  }
  $expected=@($t.ExpectedRect);$base=@($t.BaselineRect)
  if($expected.Count -ne 4 -or $base.Count -ne 4 -or
     $expected[2] -ne $base[2] -or $expected[3] -ne 48 -or
     $expected[1] -ne ($base[1]-60) -or $base[3] -ne 48 -or
     $expected[2] -lt 420 -or $expected[2] -gt 1100){
    $errors.Add('START_EXPECTED_RECT_NOT_60PX_SAFE')
  }
  $samples=@($t.Samples)
  if($samples.Count -lt 1 -or $samples.Count -gt 55){
     $errors.Add('R112_SAMPLING_COUNT_INVALID');return $errors.ToArray()
  }
  $lastTime=-1;$atLeastOneMatch=$false
  foreach($v in $samples){
    foreach($f in @('ElapsedMs','WindowId','WindowAlive','WindowVisible',
       'WindowRectKnown','WindowRect','MatchesExpectedFloating','ForegroundStart',
       'ForegroundProcess','ForegroundClass','ForegroundWindow',
       'StartSurfacePresent','StartSurfaceProcess','StartSurfaceClass','StartSurfaceHwnd',
       'StartSurfaceRect','TaskbarHwnd','TaskbarAlive','TaskbarRect')){
       if($null -eq $v.PSObject.Properties[$f]){$errors.Add('MISSING_SAMPLE_'+$f)}
    }
    if($v.ElapsedMs -lt 0 -or $v.ElapsedMs -lt $lastTime -or
       $v.ElapsedMs -gt 7000 -or $v.WindowId -ne $t.CachedOverlayHwnd -or
       $v.WindowAlive -notin @($true,$false) -or
       $v.WindowVisible -notin @($true,$false) -or
       $v.WindowRectKnown -notin @($true,$false) -or
       $v.ForegroundStart -notin @($true,$false) -or
       $v.StartSurfacePresent -notin @($true,$false) -or
       @($v.WindowRect).Count -ne 4 -or
       @($v.StartSurfaceRect).Count -ne 4 -or
       @($v.TaskbarRect).Count -ne 4){
       $errors.Add('R112_SAMPLE_DATA_FALSE')
    }
    $lastTime=[int]$v.ElapsedMs
    $actual=@($v.WindowRect)
    $match=($v.WindowRectKnown -eq $true -and
       $actual[0] -eq $expected[0] -and $actual[1] -eq $expected[1] -and
       $actual[2] -eq $expected[2] -and $actual[3] -eq $expected[3])
    if($v.MatchesExpectedFloating -ne $match){
       $errors.Add('R112_FALSE_NATIVE_RECT_CLAIM')
    }
    if($match){$atLeastOneMatch=$true}
  }
  if($t.FloatingReached -ne $atLeastOneMatch){
     $errors.Add('R112_FLOAT_CLAIM_CONTRADICTORY')
  }
  $start=@($i.DiagnosticResults|Where-Object {$_.Test -ceq 'start'})
  if($start.Count -ne 1){$errors.Add('REAL_START_PROBE_RESULT_NOT_UNIQUE')}
  return $errors.ToArray()
}
$errors=@(Check-R112 $trace $installed)
if($errors.Count){throw ('R112_STRICT_START_TIMELINE_REFUSED '+($errors -join ','))}
if($SelfTest){
 $raw=Get-Content -LiteralPath $TracePath -Raw
 $hostiles=@(
    @{Field='Revision';Value='R110'},
    @{Field='EventCommit';Value=('0'*40)},
    @{Field='MainPid';Value=-1},
    @{Field='CachedOverlayHwnd';Value=0},
    @{Field='OriginalTaskbarHwnd';Value=0},
    @{Field='StimulusMethod';Value='INJECTED_START'},
    @{Field='FloatingReached';Value=(!$trace.FloatingReached)},
    @{Field='FormalG14Accepted';Value=$true}
 )
 foreach($x in $hostiles){
    $candidate=$raw|ConvertFrom-Json
    $candidate.($x.Field)=$x.Value
    if(@(Check-R112 $candidate $installed).Count -eq 0){
       throw ('R112_HOSTILE_FALSE_ACCEPT_'+$x.Field)
    }
 }
 $a=$raw|ConvertFrom-Json
 $a.ExpectedRect[1]=0
 if(@(Check-R112 $a $installed).Count -eq 0){throw 'R112_FALSE_60PX_RECT_ACCEPT'}
 $a=$raw|ConvertFrom-Json;$a.Samples[0].WindowId=0
 if(@(Check-R112 $a $installed).Count -eq 0){throw 'R112_FORGED_HWND_ACCEPT'}
 $a=$raw|ConvertFrom-Json;$a.Samples[0].ElapsedMs=-1
 if(@(Check-R112 $a $installed).Count -eq 0){throw 'R112_NEGATIVE_TIME_ACCEPT'}
 $a=$raw|ConvertFrom-Json;$a.Samples[0].MatchesExpectedFloating=(!$a.Samples[0].MatchesExpectedFloating)
 if(@(Check-R112 $a $installed).Count -eq 0){throw 'R112_FAKE_NATIVE_GUARD_ACCEPT'}
 Write-Output 'R112_INDEPENDENT_TWELVE_HOSTILE_START_TIMELINE_CASES_REJECTED'
}
$samples=@($trace.Samples)
$fg=@($samples|Where-Object{$_.ForegroundStart -eq $true}).Count
$surface=@($samples|Where-Object{$_.StartSurfacePresent -eq $true}).Count
$alive=@($samples|Where-Object{$_.WindowAlive -eq $true}).Count
$visible=@($samples|Where-Object{$_.WindowVisible -eq $true}).Count
$tray=@($samples|Where-Object{$_.TaskbarAlive -eq $true}).Count
Write-Output ('R112_REAL_START_TIMELINE_VERIFIED SAMPLES='+$samples.Count+
 ' FG_START='+$fg+' REAL_START_SURFACE='+$surface+
 ' OVERLAY_ALIVE='+$alive+' OVERLAY_VISIBLE='+$visible+
 ' TRAY_ALIVE='+$tray+' FLOAT='+$trace.FloatingReached+
 ' G14_FORMAL_OPEN SHA256='+(Get-FileHash -LiteralPath $TracePath -Algorithm SHA256).Hash)
exit 0
