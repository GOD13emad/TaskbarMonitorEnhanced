[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$CandidateDir,[Parameter(Mandatory=$true)][ValidateSet('A','B')][string]$HostLabel)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -eq 'Core' -or $env:GITHUB_ACTIONS -cne 'true' -or
 $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or $env:RUNNER_OS -cne 'Windows' -or
 $env:COMPUTERNAME -match 'EMAD-PC' -or ![Environment]::UserInteractive){throw 'R146_REAL_TEST_ONLY_FRESH_HOSTED_WINDOWS_FRAMEWORK'}
Add-Type -AssemblyName System.Drawing,System.Windows.Forms,UIAutomationClient,UIAutomationTypes
$native=@'
using System;using System.Text;using System.Collections.Generic;using System.Runtime.InteropServices;
public static class R146Native {
 [StructLayout(LayoutKind.Sequential)] public struct Rect {public int L,T,R,B;}
 [StructLayout(LayoutKind.Sequential)] public struct Point {public int X,Y;}
 [StructLayout(LayoutKind.Sequential)] public struct Mouse {public int x,y;public uint data,flags,time;public UIntPtr extra;}
 [StructLayout(LayoutKind.Explicit)] public struct Union {[FieldOffset(0)] public Mouse m;}
 [StructLayout(LayoutKind.Sequential)] public struct Input {public uint type;public Union u;}
 public delegate bool EnumFn(IntPtr h,IntPtr data);
 [DllImport("user32.dll")] public static extern bool EnumWindows(EnumFn f,IntPtr d);
 [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p,EnumFn f,IntPtr d);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h,out uint p);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h,out Rect r);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] public static extern IntPtr GetWindowLongPtr(IntPtr h,int n);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr h,uint n);
 [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h,StringBuilder s,int n);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string c,string t);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int s);
 [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h,uint m,IntPtr w,IntPtr l);
 [DllImport("user32.dll")] public static extern void keybd_event(byte k,byte s,uint f,UIntPtr extra);
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] public static extern bool GetCursorPos(out Point p);
 [DllImport("user32.dll",SetLastError=true)] public static extern uint SendInput(uint n,Input[] p,int size);
 public static void Key(byte code){keybd_event(code,0,0,UIntPtr.Zero);keybd_event(code,0,2,UIntPtr.Zero);}
 public static void Click(int x,int y,bool right){Point old;GetCursorPos(out old);SetCursorPos(x,y);try{
  Input down=new Input{u=new Union{m=new Mouse{flags=right?8u:2u}}};
  Input up=new Input{u=new Union{m=new Mouse{flags=right?16u:4u}}};
  if(Marshal.SizeOf(typeof(Input))!=40||SendInput(2,new[]{down,up},40)!=2)throw new Exception("Input not delivered");
 }finally{SetCursorPos(old.X,old.Y);}}
 public static IntPtr[] Owned(uint pid,IntPtr tray){var list=new List<IntPtr>();EnumFn f=(h,d)=>{uint p;GetWindowThreadProcessId(h,out p);if(p==pid&&!list.Contains(h))list.Add(h);return true;};EnumWindows(f,IntPtr.Zero);EnumChildWindows(tray,f,IntPtr.Zero);return list.ToArray();}
 public static bool Above(IntPtr a,IntPtr b){for(int i=0;i<512;i++){b=GetWindow(b,3);if(b==IntPtr.Zero)return false;if(a==b)return true;}return false;}
 public static string Title(IntPtr h){var s=new StringBuilder(256);GetWindowText(h,s,s.Capacity);return s.ToString();}
}
'@
Add-Type -TypeDefinition $native -Language CSharp
$manifest=Get-Content (Join-Path $CandidateDir 'CANDIDATE.json') -Raw|ConvertFrom-Json
if($manifest.Commit -cne $env:GITHUB_SHA -or $manifest.Private -ne $true){throw 'R146_NOT_EXACT_PRIVATE_BUILD_ARTIFACT'}
$setup=Join-Path $CandidateDir 'Setup\TaskbarMonitorEnhanced_Setup_1.7.1.exe'
if((Get-FileHash $setup -Algorithm SHA256).Hash -cne $manifest.SetupSHA256){throw 'R146_SETUP_SHA'}
$app=Join-Path $env:LOCALAPPDATA 'TaskbarMonitorEnhanced'
$reg='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TaskbarMonitorEnhanced'
$out=Join-Path $env:RUNNER_TEMP ('TBME_R146_'+$HostLabel)
if((Test-Path $out) -or (Test-Path $app) -or (Test-Path $reg) -or @(Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count){throw 'R146_FRESH_HOST_REQUIRED'}
New-Item -ItemType Directory -Path $out|Out-Null
$visualFailures=New-Object 'Collections.Generic.List[string]'
$phase='INSTALL';$status='FAIL';$failure='';$process=$null;$full=$null;$taskbar=[IntPtr]::Zero;$hidTaskbar=$false;$evidence=@()
function Box([IntPtr]$h){$r=New-Object R146Native+Rect;if(![R146Native]::GetWindowRect($h,[ref]$r)){throw 'R146_RECT_FAILED'};return New-Object Drawing.Rectangle($r.L,$r.T,($r.R-$r.L),($r.B-$r.T))}
function Pump([int]$ms){$stop=[Diagnostics.Stopwatch]::StartNew();while($stop.ElapsedMilliseconds -lt $ms){[Windows.Forms.Application]::DoEvents();Start-Sleep -Milliseconds 25}}
function Capture([IntPtr]$h,[string]$label){
 $r=Box $h;$file=$label+'.png';$b=New-Object Drawing.Bitmap($r.Width,$r.Height)
 try{
  $g=[Drawing.Graphics]::FromImage($b);try{$g.CopyFromScreen($r.Location,[Drawing.Point]::Empty,$r.Size)}finally{$g.Dispose()}
  $edges=0;for($y=0;$y -lt $b.Height;$y++){for($x=1;$x -lt $b.Width;$x++){
   $a=$b.GetPixel($x,$y);$z=$b.GetPixel(($x-1),$y)
   if([Math]::Abs(([int]$a.R+$a.G+$a.B)-([int]$z.R+$z.G+$z.B)) -ge 120){$edges++}
  }}
  $b.Save((Join-Path $out $file),[Drawing.Imaging.ImageFormat]::Png)
  if($edges -lt 60){$visualFailures.Add(('R146_PHYSICAL_GLYPHS_MISSING '+$label+' EDGES='+$edges))}
  return @{State=$label;File=$file;SHA256=(Get-FileHash (Join-Path $out $file) -Algorithm SHA256).Hash;Edges=$edges;Rect=@($r.X,$r.Y,$r.Width,$r.Height);Parent=[R146Native]::GetParent($h).ToInt64();Owner=[R146Native]::GetWindow($h,4).ToInt64();PreviousSibling=[R146Native]::GetWindow($h,3).ToInt64();ExStyle=[R146Native]::GetWindowLongPtr($h,-20).ToInt64();Style=[R146Native]::GetWindowLongPtr($h,-16).ToInt64();Foreground=[R146Native]::GetForegroundWindow().ToInt64()}
 }finally{$b.Dispose()}
}
function Assert-Visible([IntPtr]$h,[Drawing.Rectangle]$original,[string]$label,[bool]$top){
 if(![R146Native]::IsWindowVisible($h)){throw ('R146_MONITOR_HIDDEN '+$label)}
 $r=Box $h
 if($r.X -ne $original.X -or $r.Y -ne $original.Y -or $r.Height -ne $original.Height -or [Math]::Abs($r.Width-$original.Width) -gt 96){throw ('R146_UNEXPECTED_MOVEMENT '+$label)}
 if([R146Native]::GetWindow($h,4) -ne $taskbar){
  $nativeOwner=[R146Native]::GetWindow($h,4)
  $directTray=[R146Native]::FindWindow('Shell_TrayWnd',$null)
  $frame=Capture $h ($label+'_OWNER_FAILURE')
  [IO.File]::WriteAllText((Join-Path $out ($label+'_NATIVE_FAILURE.json')),(@{ExpectedOwner=$taskbar.ToInt64();ActualOwner=$nativeOwner.ToInt64();DirectTaskbar=$directTray.ToInt64();Frame=$frame}|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
  throw ('R152_TASKBAR_OWNER_DRIFT '+$label+' EXPECTED='+$taskbar.ToInt64()+' ACTUAL='+$nativeOwner.ToInt64()+' DIRECT='+$directTray.ToInt64())
 }
 if(([R146Native]::GetWindowLongPtr($h,-16).ToInt64() -band 0x40000000) -ne 0){throw ('R151_MONITOR_BECAME_CHILD '+$label)}
 if($top -and [R146Native]::Above($taskbar,$h)){throw ('R146_MONITOR_UNDER_TASKBAR '+$label)}
}
try{
 $install=Start-Process -FilePath $setup -ArgumentList @('/install','/quiet','/desktop=0','/startup=0') -PassThru
 if(!$install.WaitForExit(190000) -or $install.ExitCode -ne 0){throw 'R146_SETUP_DID_NOT_FINISH'}
 $main=Join-Path $app 'TaskbarMonitorEnhanced.exe';$config=Join-Path $app 'config.json'
 if((Get-FileHash $main -Algorithm SHA256).Hash -cne $manifest.MainSHA256){throw 'R146_INSTALLED_MAIN_SHA'}
 $taskbar=[R146Native]::FindWindow('Shell_TrayWnd',$null)
 if($taskbar -eq [IntPtr]::Zero -or ![R146Native]::IsWindowVisible($taskbar)){throw 'R146_REAL_TASKBAR_MISSING'}
 $assembly=[Reflection.Assembly]::LoadFrom($main)
 $shell=$assembly.GetType('TaskbarMonitorEnhanced.ShellUi',$true)
 $shellMethod=$shell.GetMethod('IsStartShellForeground',[Reflection.BindingFlags]'Static,Public,NonPublic')
 foreach($mode in @('plain1','plain10','glass0','opaque100')){
  $phase=$mode
  $pct=if($mode -ceq 'plain1'){0.01}elseif($mode -ceq 'plain10'){0.10}elseif($mode -ceq 'glass0'){0.0}else{1.0}
  $fixture=@{Theme='Retro Terminal';Opacity=$pct;GlassMode=($mode -ceq 'glass0');OpacityWhenGlassOff=0.10;ConfigSchemaVersion=8;StartWithWindows=$false;ShowSparklines=$true;UpdateIntervalMs=1000}
  [IO.File]::WriteAllText($config,($fixture|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
  $process=Start-Process -FilePath $main -WorkingDirectory $app -PassThru;Pump 5000
  $monitor=[IntPtr]::Zero
  foreach($h in [R146Native]::Owned([uint32]$process.Id,$taskbar)){
   if(![R146Native]::IsWindowVisible($h)){continue};$r=Box $h
   if($r.Width -ge 80 -and $r.Height -ge 16 -and $r.Height -lt 100 -and (Box $taskbar).Contains($r)){$monitor=$h;break}
  }
  if($monitor -eq [IntPtr]::Zero){throw ('R146_NATIVE_MONITOR_NOT_FOUND '+$mode)}
  $original=Box $monitor;$top=$true
  $evidence+=Capture $monitor ($mode+'_NORMAL')
  # Real right-click and invoke the actual installed product's Settings menu item.
  [R146Native]::Click(($original.X+40),($original.Y+($original.Height/2)),$true);Pump 650
  Assert-Visible $monitor $original ($mode+'_MENU') $top
  $evidence+=Capture $monitor ($mode+'_MENU')
  $menuItem=$null
  $condition=New-Object Windows.Automation.AndCondition([Windows.Automation.Condition[]]@(
   (New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ProcessIdProperty,[int]$process.Id)),
   (New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::NameProperty,'Settings...'))))
  $menuItem=[Windows.Automation.AutomationElement]::RootElement.FindFirst([Windows.Automation.TreeScope]::Descendants,$condition)
  if($null -eq $menuItem){throw 'R146_REAL_SETTINGS_MENU_ITEM_NOT_FOUND'}
  $invoke=$menuItem.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern);$invoke.Invoke();Pump 1500
  $settings=[IntPtr]::Zero
  foreach($h in [R146Native]::Owned([uint32]$process.Id,$taskbar)){if([R146Native]::Title($h) -like '* - Settings' -and [R146Native]::IsWindowVisible($h)){$settings=$h;break}}
  if($settings -eq [IntPtr]::Zero -or [R146Native]::GetForegroundWindow() -ne $settings){throw 'R146_SETTINGS_NOT_REAL_FOREGROUND'}
  $work=[Windows.Forms.Screen]::FromHandle($settings).WorkingArea
  if(!$work.Contains((Box $settings))){throw 'R146_SETTINGS_EXTENDS_BEHIND_TASKBAR'}
  Assert-Visible $monitor $original ($mode+'_SETTINGS') $top
  $evidence+=Capture $monitor ($mode+'_SETTINGS')
  [void][R146Native]::SendMessage($settings,0x0010,[IntPtr]::Zero,[IntPtr]::Zero);Pump 500
  [R146Native]::Key(0x5B);Pump 1200
  $args=[object[]]@('','',[IntPtr]::Zero)
  if(!$shellMethod.Invoke($null,$args)){throw 'R146_GENUINE_START_FOREGROUND_NOT_VERIFIED'}
  Assert-Visible $monitor $original ($mode+'_START') $top
  $evidence+=Capture $monitor ($mode+'_START')
  [R146Native]::Key(0x1B);Pump 900
  Assert-Visible $monitor $original ($mode+'_AFTER_START') $top
  # A real foreground fullscreen window covering this monitor and its taskbar.
  $full=New-Object Windows.Forms.Form
  $full.FormBorderStyle='None';$full.StartPosition='Manual';$full.Bounds=[Windows.Forms.Screen]::FromHandle($taskbar).Bounds
  $full.TopMost=$true;$full.BackColor=[Drawing.Color]::FromArgb(24,40,56);$full.Text='R146 disposable fullscreen witness';$full.Show();Pump 300
  [R146Native]::Click(($full.Left+100),($full.Top+100),$false);Pump 1500
  if([R146Native]::GetForegroundWindow() -ne $full.Handle){throw 'R146_FULLSCREEN_NOT_FOREGROUND'}
  if([R146Native]::IsWindowVisible($monitor)){throw 'R146_MONITOR_VISIBLE_WITHOUT_TASKBAR_IN_FULLSCREEN'}
  $evidence+=@{State=$mode+'_FULLSCREEN';Hidden=$true;Foreground=$full.Handle.ToInt64()}
  $full.Close();$full.Dispose();$full=$null;Pump 1500
  Assert-Visible $monitor $original ($mode+'_RETURN_FULLSCREEN') $top
  $evidence+=Capture $monitor ($mode+'_RETURN_FULLSCREEN')
  # Simulate taskbar visibility notification, only on disposable runner; always restore.
  [void][R146Native]::ShowWindow($taskbar,0);$hidTaskbar=$true;Pump 1100
  if([R146Native]::IsWindowVisible($monitor)){throw 'R146_MONITOR_IGNORES_TASKBAR_HIDE'}
  [void][R146Native]::ShowWindow($taskbar,4);$hidTaskbar=$false;Pump 1100
  Assert-Visible $monitor $original ($mode+'_TASKBAR_REAPPEARS') $top
  $process.Refresh();$cpu0=$process.CPU;$clock=[Diagnostics.Stopwatch]::StartNew();Pump 5000;$clock.Stop();$process.Refresh()
  $evidence+=@{State=$mode+'_CPU';Seconds=$clock.Elapsed.TotalSeconds;CpuSeconds=$process.CPU-$cpu0;PercentOfOneCore=100*($process.CPU-$cpu0)/$clock.Elapsed.TotalSeconds;Status='MEASURED_NOT_USER_PC_ACCEPTANCE'}
  [void][R146Native]::SendMessage($monitor,0x0010,[IntPtr]::Zero,[IntPtr]::Zero)
  if(!$process.WaitForExit(10000)){throw 'R146_OWN_TEST_PROCESS_DID_NOT_EXIT'};$process.Dispose();$process=$null
 }
 if($visualFailures.Count){throw ($visualFailures -join ';')}
 $status='PASS_REAL_MENU_SETTINGS_START_FULLSCREEN_TASKBAR_VISIBILITY_THREE_MODES'
}catch{$failure=$_.Exception.ToString().Substring(0,[Math]::Min(3500,$_.Exception.ToString().Length))}
finally{
 if($hidTaskbar -and $taskbar -ne [IntPtr]::Zero){[void][R146Native]::ShowWindow($taskbar,4)}
 [R146Native]::Key(0x1B)
 if($null -ne $full){$full.Close();$full.Dispose()}
 if($null -ne $process){try{if(!$process.HasExited){$process.Kill()}}catch{}}
 try{
  $logs=@(Get-ChildItem (Join-Path $app 'Logs') -Filter 'tbme_csharp_*.log' -File -ErrorAction Stop)
  foreach($log in $logs){
   Get-Content -LiteralPath $log.FullName -Tail 1600 | Select-String -Pattern 'PRESENTATION|GLASS_NATIVE|GLASS_COMPOSITION|TASKBAR_|VISIBILITY_WATCHDOG|LOW_PRESSURE|CONTEXT_MENU|SETTINGS|START_|RECOVERY' | ForEach-Object Line | Set-Content -LiteralPath (Join-Path $out ('DIAG_'+$log.Name)) -Encoding UTF8
  }
 }catch{Write-Output ('R148_LOG_COLLECTION_WARNING '+$_.Exception.Message)}
 $r=[ordered]@{Revision='R146';Status=$status;Phase=$phase;Failure=$failure;Host=$HostLabel;EventCommit=$env:GITHUB_SHA;MainSHA256=$manifest.MainSHA256;SetupSHA256=$manifest.SetupSHA256;Evidence=$evidence;TestedModes=@('plain1','plain10','glass0','opaque100');ExpectedTaskbarOwner=$taskbar.ToInt64();PersonalComputerTouched=$false;Proof='Installed candidate + native HWND + real screenshots + real input; not synthetic taskbar paint'}
 [IO.File]::WriteAllText((Join-Path $out 'R146_NATIVE.json'),($r|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
 Write-Output ($r|ConvertTo-Json -Depth 12 -Compress)
}
if($status -notlike 'PASS_*'){throw ('R146_NATIVE_FAIL '+$failure)}
