# R132: real taskbar glass physical ink while ordinary user-window becomes foreground.
# Disposable GitHub-hosted Windows only. Never runs on personal computer.
[CmdletBinding()]
param([switch]$StaticOnly)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($StaticOnly){
 $tokens=$null;$errors=$null
 [void][Management.Automation.Language.Parser]::ParseFile($PSCommandPath,[ref]$tokens,[ref]$errors)
 if(@($errors).Count){throw 'R132_PARSER_FAIL'}
 Write-Output 'R132_STATIC_PASS';exit 0
}
if($env:GITHUB_ACTIONS -cne 'true' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
 $env:RUNNER_OS -cne 'Windows' -or $env:GITHUB_SHA -cnotmatch '^[0-9a-f]{40}$' -or
 $env:COMPUTERNAME -match 'EMAD-PC' -or ![Environment]::UserInteractive){
 throw 'R132_PERSONAL_OR_NON_GUI_HOST_REFUSED'
}
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
$source=@'
using System;
using System.Drawing;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class R132Native
{
 [StructLayout(LayoutKind.Sequential)] public struct RECT{
  public int Left,Top,Right,Bottom;
  public int Width{get{return Right-Left;}}
  public int Height{get{return Bottom-Top;}}
 }
 [StructLayout(LayoutKind.Sequential)] public struct Mouse{
  public int dx,dy;
  public uint mouseData,flags,time;
  public UIntPtr extraInfo;
 }
 [StructLayout(LayoutKind.Explicit)] public struct Union{
  [FieldOffset(0)] public Mouse mouse;
 }
 [StructLayout(LayoutKind.Sequential)] public struct Input{
  public uint type;
  public Union data;
 }
 public delegate bool EnumProc(IntPtr hwnd,IntPtr lparam);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string cls,string name);
 [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hwnd);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hwnd);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd,out RECT rect);
 [DllImport("user32.dll")] public static extern IntPtr GetWindowLongPtr(IntPtr hwnd,int index);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
 [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc func,IntPtr p);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT point);
 [StructLayout(LayoutKind.Sequential)] public struct POINT{public int X,Y;}
 [DllImport("user32.dll",SetLastError=true)] public static extern uint SendInput(uint n,Input[] p,int size);
 [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h,uint m,IntPtr w,IntPtr l);
 public const int GWL_EXSTYLE=-20;
 public const long REQUIRED=0x08080008; // NOACTIVATE + LAYERED + TOPMOST
 public static IntPtr FindOverlay(int pid,RECT taskbar,out RECT outRect){
  var found=IntPtr.Zero;outRect=new RECT();RECT candidate=new RECT();
  EnumWindows(delegate(IntPtr h,IntPtr l){
   uint owner=0;GetWindowThreadProcessId(h,out owner);
   if(owner!=(uint)pid || !IsWindowVisible(h))return true;
   long ex=GetWindowLongPtr(h,GWL_EXSTYLE).ToInt64();
   if((ex & REQUIRED)!=REQUIRED)return true;
   RECT rc;if(!GetWindowRect(h,out rc))return true;
   if(rc.Width<180||rc.Height<25||rc.Height>90||
      rc.Left<taskbar.Left||rc.Top<taskbar.Top||
      rc.Right>taskbar.Right||rc.Bottom>taskbar.Bottom)return true;
   if(found!=IntPtr.Zero)throw new InvalidOperationException("R132_MULTIPLE_MATCHING_OVERLAYS");
   found=h;candidate=rc;return true;
  },IntPtr.Zero);
  outRect=candidate;return found;
 }
 public static int RealTitleClick(int x,int y){
  if(IntPtr.Size!=8||Marshal.SizeOf(typeof(Input))!=40)
   throw new InvalidOperationException("R132_UNEXPECTED_X64_MOUSE_LAYOUT");
  POINT saved;
  if(!GetCursorPos(out saved)||!SetCursorPos(x,y))
   throw new InvalidOperationException("R132_CURSOR_NOT_MOVED");
  try{
   Input a=new Input{type=0,data=new Union{mouse=new Mouse{flags=2}}};
   Input b=new Input{type=0,data=new Union{mouse=new Mouse{flags=4}}};
   uint n=SendInput(2,new Input[]{a,b},Marshal.SizeOf(typeof(Input)));
   if(n!=2)throw new InvalidOperationException("R132_NATIVE_MOUSE_INPUT_NOT_DELIVERED "+n);
   return (int)n;
  }finally{SetCursorPos(saved.X,saved.Y);}
 }
}
'@
Add-Type -TypeDefinition $source -Language CSharp
$app=Join-Path $env:LOCALAPPDATA 'TaskbarMonitorEnhanced'
$exe=Join-Path $app 'TaskbarMonitorEnhanced.exe'
$config=Join-Path $app 'config.json'
$state=Join-Path $app 'install_state.json'
$expected='D50A9D03190719B8385AB2F7F7DBB3129EC7EC1C77ECBD8EF7F29832AEC26420'
$out=Join-Path $env:RUNNER_TEMP 'TBME_R132_GLASS_FOCUS'
$receipt=Join-Path $out 'R132_NORMAL_WINDOW_GLASS.json'
if((Test-Path -LiteralPath $out) -or !(Test-Path -LiteralPath $config -PathType Leaf) -or
   !(Test-Path -LiteralPath $state -PathType Leaf) -or
   (Get-FileHash $exe -Algorithm SHA256).Hash -cne $expected){
 throw 'R132_INSTALLED_CANDIDATE_NOT_VERIFIED_OR_UNSAFE_RERUN'
}
$install=Get-Content -LiteralPath $state -Raw|ConvertFrom-Json
if($install.Version -cne '1.7.1' -or $install.PublicVersion -cne '1.7.1' -or
   $install.ProductIdentity -cne 'LOCKED' -or
   @(Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count -ne 0){
 throw 'R132_NOT_EXACT_INSTALLED_ONE_ROOT'
}
$oldConfig=[IO.File]::ReadAllBytes($config)
$originalConfigSha=(Get-FileHash $config -Algorithm SHA256).Hash
New-Item -ItemType Directory -Path $out -ErrorAction Stop|Out-Null
$fixture='{"Theme":"Glass Morphism","Opacity":0.0,"GlassMode":true,"OpacityWhenGlassOff":0.31,"FloatAboveStartMenu":false,"ConfigSchemaVersion":8,"StartWithWindows":false}'
$fixtureBytes=[Text.UTF8Encoding]::new($false).GetBytes($fixture)
[IO.File]::WriteAllBytes($config,$fixtureBytes)
$fixtureHash=(Get-FileHash $config -Algorithm SHA256).Hash
$phase='START';$status='FAIL';$failure='';$process=$null;$residentPid=0;$normal=@();$nativeBefore=0;$nativeAfter=0;$actualInkBefore=0;$actualInkAfter=0;$aligned=0;$alignedContrast=0
$beforeEdgeH=0;$beforeEdgeV=0;$beforeEdgeRows=0;$afterEdgeH=0;$afterEdgeV=0;$afterEdgeRows=0
$configAfterRuntimeSha=''
$monitor=0L;$taskbar=0L;$baseline=@();$screens=@()
function Snapshot([string]$path,[R132Native+RECT]$rect){
 $bmp=[Drawing.Bitmap]::new($rect.Width,$rect.Height,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
 try{
  $g=[Drawing.Graphics]::FromImage($bmp)
  try{$g.CopyFromScreen($rect.Left,$rect.Top,0,0,[Drawing.Size]::new($rect.Width,$rect.Height))}finally{$g.Dispose()}
  $bmp.Save($path,[Drawing.Imaging.ImageFormat]::Png)
 }finally{$bmp.Dispose()}
}
function Get-PhysicalInk([Drawing.Bitmap]$bmp){
 # Local high-contrast TEXT must count even when the taskbar contrast engine
 # draws genuine black/white glyphs. Zero-uniform backgrounds cannot pass.
 $colored=0;$horizontal=0;$vertical=0;$edgeRows=0
 for($y=0;$y -lt $bmp.Height;$y++){
  $rowEdges=0
  for($x=0;$x -lt $bmp.Width;$x++){
   $p=$bmp.GetPixel($x,$y)
   $hi=[Math]::Max($p.R,[Math]::Max($p.G,$p.B))
   $lo=[Math]::Min($p.R,[Math]::Min($p.G,$p.B))
   if($hi -ge 70 -and ($hi-$lo) -ge 25){$colored++}
   $lum=[int][Math]::Round(0.299*$p.R+0.587*$p.G+0.114*$p.B)
   if($x -gt 0){
    $left=$bmp.GetPixel($x-1,$y)
    $prev=[int][Math]::Round(0.299*$left.R+0.587*$left.G+0.114*$left.B)
    if([Math]::Abs($lum-$prev) -ge 60){$horizontal++;$rowEdges++}
   }
   if($y -gt 0){
    $up=$bmp.GetPixel($x,$y-1)
    $prev=[int][Math]::Round(0.299*$up.R+0.587*$up.G+0.114*$up.B)
    if([Math]::Abs($lum-$prev) -ge 60){$vertical++}
   }
  }
  if($rowEdges -ge 2){$edgeRows++}
 }
 return [pscustomobject]@{
  Colored=$colored;HorizontalEdges=$horizontal;VerticalEdges=$vertical
  EdgeRows=$edgeRows;RealInk=($colored -ge 300 -or
   ($horizontal -ge 140 -and $vertical -ge 80 -and $edgeRows -ge 10))
 }
}
try{
 $phase='LAUNCH_REAL_INSTALLED_MONITOR'
 $psi=[Diagnostics.ProcessStartInfo]::new()
 $psi.FileName=$exe;$psi.WorkingDirectory=$app;$psi.UseShellExecute=$false
 $process=[Diagnostics.Process]::Start($psi)
 if($null -eq $process){throw 'R132_PRIVATE_RESIDENT_PROCESS_FAILED'}
 $residentPid=[int]$process.Id
 $task=[R132Native]::FindWindow('Shell_TrayWnd',$null)
 $tray=[R132Native+RECT]::new()
 if($task -eq [IntPtr]::Zero -or ![R132Native]::GetWindowRect($task,[ref]$tray)){throw 'R132_PHYSICAL_TASKBAR_ABSENT'}
 $taskbar=$task.ToInt64()
 $found=[IntPtr]::Zero;$rect=[R132Native+RECT]::new()
 for($j=0;$j -lt 48;$j++){
  Start-Sleep -Milliseconds 250
  [Windows.Forms.Application]::DoEvents()
  $found=[R132Native]::FindOverlay($residentPid,$tray,[ref]$rect)
  if($found -ne [IntPtr]::Zero){break}
  $process.Refresh()
  if($process.HasExited){throw 'R132_MONITOR_EXITED_BEFORE_NATIVE_HWND'}
 }
 if($found -eq [IntPtr]::Zero){throw 'R132_REAL_TOPMOST_TASKBAR_GLASS_NOT_FOUND'}
 $monitor=$found.ToInt64()
 $baseline=@($rect.Left,$rect.Top,$rect.Width,$rect.Height)
 $phase='BASELINE_REAL_INK'
 $before=Join-Path $out 'R132_BEFORE_ORDINARY_WINDOW.png'
 $nativeBefore=[R132Native]::GetWindowLongPtr($found,[R132Native]::GWL_EXSTYLE).ToInt64()
 # The real installed app may take time to paint AFTER the HWND appears.
 # Never accept a gray/blank screenshot; only bounded real screenshot polls.
 for($attempt=0;$attempt -lt 16;$attempt++){
  Snapshot $before $rect
  $bm=[Drawing.Bitmap]::new($before)
  try{$ink=Get-PhysicalInk $bm}finally{$bm.Dispose()}
  $actualInkBefore=$ink.Colored
  $beforeEdgeH=$ink.HorizontalEdges;$beforeEdgeV=$ink.VerticalEdges
  $beforeEdgeRows=$ink.EdgeRows
  if($ink.RealInk){break}
  Start-Sleep -Milliseconds 450
 }
 if(!$ink.RealInk){throw ('R132_INITIAL_REAL_GLYPH_INK_MISSING COLOR='+$actualInkBefore+
  ' EDGE_H='+$beforeEdgeH+' EDGE_V='+$beforeEdgeV+' ROWS='+$beforeEdgeRows)}
 $phase='ACTIVATE_REAL_ORDINARY_WINDOWS'
 for($index=1;$index -le 2;$index++){
  $form=[Windows.Forms.Form]::new()
  $form.Text='R132 ordinary activated window '+$index
  $form.TopMost=$false
  $form.ShowInTaskbar=$true
  $form.FormBorderStyle=[Windows.Forms.FormBorderStyle]::FixedDialog
  $form.StartPosition=[Windows.Forms.FormStartPosition]::Manual
  $form.Bounds=[Drawing.Rectangle]::new(($tray.Left+160),([Math]::Max(50,$tray.Top-620)),650,450)
  $form.BackColor=[Drawing.Color]::FromArgb(181,33,172)
  $normal+=@($form)
  $form.Show()
  [Windows.Forms.Application]::DoEvents()
  $nativeInputCount=0;$attempts=0;$titleHitCount=0;$userForeground=$false
  for($try=0;$try -lt 4;$try++){
   $form.BringToFront();$form.Activate()
   [Windows.Forms.Application]::DoEvents()
   Start-Sleep -Milliseconds 110
   $point=[R132Native+POINT]::new()
   $point.X=$form.Left+120;$point.Y=$form.Top+15
   if([R132Native]::WindowFromPoint($point) -ne $form.Handle){continue}
   $titleHitCount++
   $nativeInputCount+=[R132Native]::RealTitleClick($point.X,$point.Y)
   $attempts++
   Start-Sleep -Milliseconds 350
   [Windows.Forms.Application]::DoEvents()
   if([R132Native]::GetForegroundWindow() -eq $form.Handle){
    $userForeground=$true;break
   }
  }
  if(!$userForeground -or $attempts -lt 1 -or
     $nativeInputCount -ne (2*$attempts) -or $titleHitCount -lt 1){
   throw ('R134_REAL_USER_TITLE_FOREGROUND_REFUSED INDEX='+$index+
    ' ATTEMPTS='+$attempts+' REAL_HITS='+$titleHitCount+
    ' NATIVE_EVENTS='+$nativeInputCount+
    ' CURRENT_FG='+([R132Native]::GetForegroundWindow().ToInt64())+
    ' TARGET='+$form.Handle.ToInt64())
  }
  Start-Sleep -Milliseconds 550
  [Windows.Forms.Application]::DoEvents()
  $nowRect=[R132Native+RECT]::new()
  $alive=[R132Native]::IsWindow($found)
  $visible=$alive -and [R132Native]::IsWindowVisible($found)
  $rectKnown=$alive -and [R132Native]::GetWindowRect($found,[ref]$nowRect)
  $exNow=if($alive){[R132Native]::GetWindowLongPtr($found,[R132Native]::GWL_EXSTYLE).ToInt64()}else{0L}
  # R133 native evidence: published taskbar anchor never moved up, while
  # bounded content width adapted from 279 to 320. Require same X/Y/height
  # and constrain both widths to real taskbar; never ignore a vertical lift.
  $sameRect=$rectKnown -and $nowRect.Left -eq $rect.Left -and
    $nowRect.Top -eq $rect.Top -and $nowRect.Height -eq $rect.Height -and
    $nowRect.Width -ge 180 -and [Math]::Abs($nowRect.Width-$rect.Width) -le 96 -and
    $nowRect.Left -ge $tray.Left -and $nowRect.Right -le $tray.Right -and
    $nowRect.Top -ge $tray.Top -and $nowRect.Bottom -le $tray.Bottom
  if(!$alive -or !$visible -or !$sameRect -or
     (($exNow -band [R132Native]::REQUIRED) -ne [R132Native]::REQUIRED)){
   # First-failure native receipt evidence. Do NOT repair/change the window
   # from inside this independent tester; surface precise class of failure.
   $image=Join-Path $out ('R133_FAILURE_FOREGROUND_'+$index+'.png')
   Snapshot $image $rect
   throw ('R133_NORMAL_FOCUS_HWND_NATIVE_STATE_REJECTED INDEX='+$index+
    ' ALIVE='+$alive+' VISIBLE='+$visible+' RECT_KNOWN='+$rectKnown+
    ' ACTUAL_RECT='+$nowRect.Left+','+$nowRect.Top+','+$nowRect.Width+','+$nowRect.Height+
    ' BASELINE='+$rect.Left+','+$rect.Top+','+$rect.Width+','+$rect.Height+
    ' EX_STYLE=0x'+$exNow.ToString('X')+' FOREGROUND='+([R132Native]::GetForegroundWindow().ToInt64()))
  }
  $path=Join-Path $out ('R132_NORMAL_FOCUS_'+$index+'.png')
  Snapshot $path $rect
  $pic=[Drawing.Bitmap]::new($path)
  try{$ink=Get-PhysicalInk $pic}finally{$pic.Dispose()}
  $afterEdgeH=$ink.HorizontalEdges;$afterEdgeV=$ink.VerticalEdges
  $afterEdgeRows=$ink.EdgeRows
  # Also inspect the COMPLETE real HWND rectangle after adaptive content width.
  $fullPath=Join-Path $out ('R134_COMPLETE_OVERLAY_'+$index+'.png')
  Snapshot $fullPath $nowRect
  $full=[Drawing.Bitmap]::new($fullPath)
  try{$fullInk=Get-PhysicalInk $full}finally{$full.Dispose()}
  if(!$fullInk.RealInk){
   throw ('R134_COMPLETE_ACTUAL_HWND_PHYSICAL_INK_MISSING '+$index)
  }
  $screens+=@([ordered]@{
   Index=$index;ForegroundHwnd=$form.Handle.ToInt64()
   ForegroundType='real ordinary WinForms form, TopMost=false'
   ColoredPixels=$ink.Colored;HorizontalEdges=$ink.HorizontalEdges
   VerticalEdges=$ink.VerticalEdges;EdgeRows=$ink.EdgeRows
   RealInk=$ink.RealInk
   NativeInputEvents=$nativeInputCount;ClickAttempts=$attempts
   ExactTitleNativeHit=($titleHitCount -ge 1)
   OverlayRectAfter=@($nowRect.Left,$nowRect.Top,$nowRect.Width,$nowRect.Height)
   NativeExStyleAfter=$exNow
   FullOverlayPng=(Split-Path $fullPath -Leaf)
   FullOverlaySha256=(Get-FileHash $fullPath -Algorithm SHA256).Hash
   FullOverlayColoredPixels=$fullInk.Colored
   FullOverlayHorizontalEdges=$fullInk.HorizontalEdges
   FullOverlayVerticalEdges=$fullInk.VerticalEdges
   FullOverlayEdgeRows=$fullInk.EdgeRows
   PhysicalPng=(Split-Path $path -Leaf)
   PngSha256=(Get-FileHash $path -Algorithm SHA256).Hash
  })
  if(!$ink.RealInk){throw ('R132_NORMAL_WINDOW_ACTUAL_METRIC_GLYPHS_MISSING '+$index+
   ' COLOR='+$ink.Colored+' EDGE_H='+$ink.HorizontalEdges+' EDGE_V='+$ink.VerticalEdges)}
 }
 $afterPath=Join-Path $out 'R132_NORMAL_FOCUS_2.png'
 $second=[Drawing.Bitmap]::new($afterPath)
 $first=[Drawing.Bitmap]::new($before)
 try{
  for($y=0;$y -lt $first.Height;$y++){
   for($x=0;$x -lt $first.Width;$x++){
    $a=$first.GetPixel($x,$y);$b=$second.GetPixel($x,$y)
    $maxA=[Math]::Max($a.R,[Math]::Max($a.G,$a.B));$minA=[Math]::Min($a.R,[Math]::Min($a.G,$a.B))
    $maxB=[Math]::Max($b.R,[Math]::Max($b.G,$b.B));$minB=[Math]::Min($b.R,[Math]::Min($b.G,$b.B))
    if($maxA -ge 70 -and $maxA-$minA -ge 25 -and $maxB -ge 70 -and $maxB-$minB -ge 25){$aligned++}
     if($x -gt 0){
      $pa=$first.GetPixel($x-1,$y);$pb=$second.GetPixel($x-1,$y)
      $aLum=[int][Math]::Round(0.299*$a.R+0.587*$a.G+0.114*$a.B)
      $bLum=[int][Math]::Round(0.299*$b.R+0.587*$b.G+0.114*$b.B)
      $paLum=[int][Math]::Round(0.299*$pa.R+0.587*$pa.G+0.114*$pa.B)
      $pbLum=[int][Math]::Round(0.299*$pb.R+0.587*$pb.G+0.114*$pb.B)
      if([Math]::Abs($aLum-$paLum) -ge 60 -and
         [Math]::Abs($bLum-$pbLum) -ge 60){$alignedContrast++}
     }
   }
  }
 }finally{$first.Dispose();$second.Dispose()}
 $actualInkAfter=$screens[-1].ColoredPixels
 if($aligned -lt 120 -and $alignedContrast -lt 120){throw ('R132_AFTER_FOREGROUND_ALIGNED_REAL_GLYPHS_MISSING SAT='+$aligned+' EDGE='+$alignedContrast)}
 $phase='PHYSICAL_ACCEPTED';$status='PASS'
}catch{$failure=$_.Exception.ToString()}
finally{
 foreach($f in $normal){try{$f.Close();$f.Dispose()}catch{}}
 if($null -ne $process){
  try{
   if(!$process.HasExited){
    if($monitor -ne 0){[void][R132Native]::SendMessage([IntPtr]$monitor,0x10,[IntPtr]::Zero,[IntPtr]::Zero)}
    if(!$process.WaitForExit(5000)){ $process.Refresh();if(!$process.HasExited -and $process.Id -eq $residentPid -and $process.MainModule.FileName -ceq $exe){$process.Kill();[void]$process.WaitForExit(5000)}}
   }
  }catch{$failure+= ' CLEANUP_WARNING='+$_.Exception.Message;$status='FAIL'}
  $process.Dispose()
 }
 try{
  $configAfterRuntimeSha=(Get-FileHash $config -Algorithm SHA256).Hash
   if($configAfterRuntimeSha -cne $fixtureHash){
    # Only in SHA-locked disposable CI: the owned app may normalize and persist
    # the known test config on exit. Archive that byte-for-byte before rollback.
    $autosave=Join-Path $out 'R132_AUTOSAVED_TEST_CONFIG.json'
    if((Get-Item $config).Length -gt 65536 -or (Test-Path -LiteralPath $autosave)){
     throw 'R132_UNRECOGNIZED_TEST_CONFIG_MUTATION'
    }
    Copy-Item -LiteralPath $config -Destination $autosave -ErrorAction Stop
   }
  [IO.File]::WriteAllBytes($config,$oldConfig)
  if((Get-FileHash $config -Algorithm SHA256).Hash -cne $originalConfigSha){throw 'R132_CONFIG_RESTORE_SHA_FAILED'}
 }catch{$failure+=' CONFIG_RESTORE_FAILURE='+$_.Exception.Message;$status='FAIL'}
 $receiptObj=[ordered]@{
  Schema=1;Revision='R132';Commit=$env:GITHUB_SHA;Status=$status;Phase=$phase;Failure=$failure
  Host='GITHUB_HOSTED_DISPOSABLE_WINDOWS';MainSHA256=$expected;MainPid=$residentPid
  TaskbarHwnd=$taskbar;TaskbarRect=if($taskbar -ne 0){@($tray.Left,$tray.Top,$tray.Width,$tray.Height)}else{@()};OverlayHwnd=$monitor;OverlayRect=$baseline
  NativeGlassBefore=$nativeBefore;BeforeColored=$actualInkBefore;AfterColored=$actualInkAfter;AlignedColoredPixels=$aligned
   BeforeHorizontalEdges=$beforeEdgeH;BeforeVerticalEdges=$beforeEdgeV;BeforeEdgeRows=$beforeEdgeRows
   AfterHorizontalEdges=$afterEdgeH;AfterVerticalEdges=$afterEdgeV;AfterEdgeRows=$afterEdgeRows
   AlignedContrastEdges=$alignedContrast;ConfigAfterRuntimeSha=$configAfterRuntimeSha
  FirstScreenshotSha256=if(Test-Path (Join-Path $out 'R132_BEFORE_ORDINARY_WINDOW.png')){(Get-FileHash (Join-Path $out 'R132_BEFORE_ORDINARY_WINDOW.png') -Algorithm SHA256).Hash}else{''}
  ForegroundWindows=@($screens);GlassModeOn=$true;SavedOpacityWhenOff=0.31;BackgroundOpacityZero=$true
  ConfigBeforeSha=$originalConfigSha;ConfigRestoredSha=if(Test-Path $config){(Get-FileHash $config -Algorithm SHA256).Hash}else{''}
  PersonalMachineTouched=$false;FormalExternalLabAccepted=$false
 }
 [IO.File]::WriteAllText($receipt,($receiptObj|ConvertTo-Json -Depth 10),[Text.UTF8Encoding]::new($false))
 Write-Output ('R132_REAL_NORMAL_FOREGROUND_GLASS='+$status+' BEFORE_COLOR='+$actualInkBefore+' BEFORE_H_EDGES='+$beforeEdgeH+' AFTER_COLOR='+$actualInkAfter+' AFTER_H_EDGES='+$afterEdgeH+' ALIGN_COLOR='+$aligned+' ALIGN_EDGES='+$alignedContrast+' RECEIPT_SHA256='+(Get-FileHash $receipt -Algorithm SHA256).Hash)
}
if($status -cne 'PASS'){throw ('R132_NATIVE_REAL_NORMAL_WINDOW_VISIBILITY_REFUSED '+$failure)}
exit 0
