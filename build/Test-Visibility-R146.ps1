[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$MainPath,[Parameter(Mandatory=$true)][string]$OutDir)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -eq 'Core'){throw 'R146_FRAMEWORK_REQUIRES_WINDOWS_POWERSHELL'}
if(Test-Path $OutDir){throw 'R146_OUTPUT_ALREADY_EXISTS'}
Add-Type -AssemblyName System.Drawing
$a=[Reflection.Assembly]::LoadFrom([IO.Path]::GetFullPath($MainPath))
$type=$a.GetType('TaskbarMonitorEnhanced.TaskbarPresentationPolicy',$true)
$flags=[Reflection.BindingFlags]'Static,Public,NonPublic'
$decide=$type.GetMethod('Decide',$flags);$cover=$type.GetMethod('CoversMonitor',$flags)
$tests=0
foreach($left in @(0,-1920,2560)){
 $screen=New-Object Drawing.Rectangle($left,0,1920,1080)
 $bar=New-Object Drawing.Rectangle($left,1032,1920,48)
 foreach($exists in @($false,$true)){foreach($visible in @($false,$true)){foreach($cloaked in @($false,$true)){foreach($full in @($false,$true)){foreach($reveal in @($false,$true)){
  $expected=if(!$exists){'Missing'}elseif(!$visible -or $cloaked){'Hidden'}elseif($full -and !$reveal){'Fullscreen'}else{'Visible'}
  $actual=$decide.Invoke($null,[object[]]@($exists,$visible,$cloaked,$bar.PSObject.BaseObject,$screen.PSObject.BaseObject,$full,$reveal)).ToString()
  if($actual -cne $expected){throw ('R146_PRESENTATION_STATE '+$actual+' != '+$expected)}
  $tests++
 }}}}}
 foreach($partial in @((New-Object Drawing.Rectangle($left,1078,1920,48)),(New-Object Drawing.Rectangle($left,1080,1920,48)))){
  $actual=$decide.Invoke($null,[object[]]@($true,$true,$false,$partial.PSObject.BaseObject,$screen.PSObject.BaseObject,$false,$false)).ToString()
  if($actual -cne 'AutoHidden'){throw 'R146_AUTOHIDE_EDGE_RENDERED'};$tests++
 }
 $maximized=New-Object Drawing.Rectangle($left,0,1920,1032)
 if($cover.Invoke($null,[object[]]@($maximized.PSObject.BaseObject,$screen.PSObject.BaseObject))){throw 'R146_MAXIMIZED_MISTAKEN_FOR_FULLSCREEN'};$tests++
 if(!$cover.Invoke($null,[object[]]@($screen.PSObject.BaseObject,$screen.PSObject.BaseObject))){throw 'R146_FULLSCREEN_NOT_DETECTED'};$tests++
 $other=New-Object Drawing.Rectangle(($left+1920),0,1920,1080)
 if($cover.Invoke($null,[object[]]@($other.PSObject.BaseObject,$screen.PSObject.BaseObject))){throw 'R146_OTHER_MONITOR_FULLSCREEN_HIDES_THIS_MONITOR'};$tests++
}
New-Item -ItemType Directory -Path $OutDir|Out-Null
$r=[ordered]@{Revision='R146';Status='PASS_PRESENTATION_DECISION_CONTRACT';Cases=$tests;Monitors=3;NegativeCoordinates=$true;MaximizedNotFullscreen=$true;TaskbarAutoHideEdgeSuppressed=$true;FullscreenWithTaskbarRevealedVisible=$true;MainSHA256=(Get-FileHash $MainPath -Algorithm SHA256).Hash;NativeDesktopValidation='SEPARATE_GATE';UserDesktopChanged=$false}
[IO.File]::WriteAllText((Join-Path $OutDir 'R146_POLICY.json'),($r|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
Write-Output ($r|ConvertTo-Json -Compress)
