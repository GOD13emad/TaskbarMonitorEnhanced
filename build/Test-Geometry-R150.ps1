[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$MainPath,[Parameter(Mandatory=$true)][string]$OutDir)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -eq 'Core'){throw 'R150_USE_FRAMEWORK_WINDOWS_POWERSHELL'}
if(Test-Path -LiteralPath $OutDir){throw 'R150_OUTPUT_EXISTS_NO_RERUN'}
Add-Type -AssemblyName System.Drawing,System.Windows.Forms
$a=[Reflection.Assembly]::LoadFrom([IO.Path]::GetFullPath($MainPath))
$configType=$a.GetType('TaskbarMonitorEnhanced.AppConfig',$true)
$overlayType=$a.GetType('TaskbarMonitorEnhanced.OverlayForm',$true)
$flags=[Reflection.BindingFlags]'Instance,Public,NonPublic'
$config=[Activator]::CreateInstance($configType,$true)
$ctor=@($overlayType.GetConstructors($flags)|Where-Object {$_.GetParameters().Count -eq 2})
if($ctor.Count -ne 1){throw 'R150_REAL_PROOF_CONSTRUCTOR_UNEXPECTED'}
$overlay=$ctor[0].Invoke([object[]]@($config,$true))
$render=$overlayType.GetMethod('RenderAppearanceForProof',$flags)
if($null -eq $render){throw 'R150_PRODUCTION_RENDER_ENTRY_MISSING'}
$cases=0;$sample=@();$status='FAIL';$failure=''
New-Item -ItemType Directory -Path $OutDir|Out-Null
try{
 foreach($width in @(180,279,319,320,640)){
  foreach($height in @(24,32,48,72)){
   foreach($percent in @(1,10,29,30,31,99,100)){
    $b=$null
    try{
     $b=$render.Invoke($overlay,[object[]]@('Retro Terminal',$width,$height,$percent,[Drawing.Color]::FromArgb(35,35,35),$false))
     if($b.Width -ne $width -or $b.Height -ne $height){throw ('R150_NATIVE_GEOMETRY_DRIFT width='+$width+' height='+$height+' got='+$b.Width+'x'+$b.Height)}
     $cases++
     if($width -eq 279 -and $height -eq 48 -and $percent -in @(1,10,30,31,100)){
      $path=Join-Path $OutDir ('COMPOSITOR_279_'+$percent+'.png')
      $b.Save($path,[Drawing.Imaging.ImageFormat]::Png)
      $sample+=@{Width=$width;Height=$height;Opacity=$percent;File=[IO.Path]::GetFileName($path);SHA256=(Get-FileHash $path -Algorithm SHA256).Hash}
     }
    }finally{if($null -ne $b){$b.Dispose()}}
   }
   $b=$null
   try{
    $b=$render.Invoke($overlay,[object[]]@('Retro Terminal',$width,$height,0,[Drawing.Color]::FromArgb(35,35,35),$true))
    if($b.Width -ne $width -or $b.Height -ne $height){throw 'R150_EXPLICIT_GLASS_SIZE_DRIFT'}
    $cases++
   }finally{if($null -ne $b){$b.Dispose()}}
  }
 }
 if($cases -ne 160){throw ('R150_WRONG_CASE_COUNT '+$cases)}
 $status='PASS_REAL_RENDERER_EXACT_GEOMETRY_160_CASES'
}catch{$failure=$_.Exception.ToString()}
finally{
 $overlay.Dispose()
 $r=[ordered]@{Revision='R150';Status=$status;Cases=$cases;MainSHA256=(Get-FileHash $MainPath -Algorithm SHA256).Hash;ProductionRenderer='RenderAppearanceForProof->RenderGlassBitmap->RenderThemeDefinition->Compose';NativeFootprints=@(180,279,319,320,640);Heights=@(24,32,48,72);PlainOpacityCases=@(1,10,29,30,31,99,100);ExplicitGlass=$true;Samples=$sample;Error=$failure;PersonalProcessStarted=$false;ActualDesktopAcceptance='SEPARATE_NATIVE_GATE'}
 [IO.File]::WriteAllText((Join-Path $OutDir 'R150_GEOMETRY.json'),($r|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
 Write-Output ($r|ConvertTo-Json -Depth 8 -Compress)
}
if($status -notlike 'PASS_*'){throw ('R150_GEOMETRY_FAIL '+$failure)}
