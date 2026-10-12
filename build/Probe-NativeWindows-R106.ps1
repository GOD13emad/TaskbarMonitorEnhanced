# R106 test-only Win32 native overlay discovery on a disposable GitHub-hosted Windows.
# Read-only EnumWindows + EnumChildWindows + GetWindowRect/GetWindowLongPtr/GetClassName;
# NO SendMessage, input simulation, wallpaper, taskbar, registry, driver or install mutation.
[CmdletBinding()]
param([switch]$StaticOnly,[int]$ExpectedPid=0,[string]$ExpectedMain='',[string]$OutputDirectory='')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$PinnedMainSHA='63A724981E949BA4C91F8BD44F2659F223BDFE0350A2E229CEE7B05535D4BA70'
if($StaticOnly){
    $token=$null;$errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($PSCommandPath,[ref]$token,[ref]$errors)
    if(@($errors).Count){throw 'R106 PARSER ERROR'}
    Write-Output 'R106_STATIC_NATIVE_PID_WINDOW_PROBE_PARSER_PASS_NO_WIN32_CALL'
    exit 0
}
if($env:GITHUB_ACTIONS -cne 'true' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
   $env:RUNNER_OS -cne 'Windows' -or $env:GITHUB_SHA -cnotmatch '^[0-9a-f]{40}$' -or
   $env:COMPUTERNAME -ceq 'EMAD-PC-ULTIMAT' -or
   [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP) -or
   $ExpectedPid -le 0 -or ![Environment]::UserInteractive){
    throw 'R106 REFUSE NONDISPOSABLE OR NONINTERACTIVE OR UNBOUND PID'
}
$actualMain=[IO.Path]::GetFullPath($ExpectedMain)
$expectedMain=[IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'TaskbarMonitorEnhanced\TaskbarMonitorEnhanced.exe'))
$actualDir=[IO.Path]::GetFullPath($OutputDirectory)
$expectedDir=[IO.Path]::GetFullPath((Join-Path $env:RUNNER_TEMP 'TBME_R88_UnsignedPreview_Smoke\R103_INSTALLED_8'))
if($actualMain -cne $expectedMain -or $actualDir -cne $expectedDir -or
   !(Test-Path -LiteralPath $actualMain -PathType Leaf) -or
   !(Test-Path -LiteralPath $actualDir -PathType Container) -or
   (Get-FileHash -LiteralPath $actualMain -Algorithm SHA256).Hash -cne $PinnedMainSHA){
   throw 'R106 REFUSE UNPINNED MAIN / UNOWNED EVIDENCE ROOT'
}
$path=Join-Path $actualDir 'R106_NATIVE_WINDOWS.json'
if(Test-Path -LiteralPath $path){throw 'R106 NO RAW_RECEIPT_OVERWRITE'}
$proc=Get-Process -Id $ExpectedPid -ErrorAction Stop
if($proc.ProcessName -cne 'TaskbarMonitorEnhanced' -or
   $proc.SessionId -ne (Get-Process -Id $PID).SessionId -or
   $proc.HasExited){throw 'R106 PID PROCESS IDENTITY OR SESSION WRONG'}
$bound=''
try{$bound=[IO.Path]::GetFullPath($proc.MainModule.FileName)}catch{throw 'R106 CANNOT VERIFY NATIVE MAINMODULE PATH'}
if($bound -cne $expectedMain){throw 'R106 PINNED EXE PID PATH DOES NOT MATCH'}
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class R106NativeWindows {
 public delegate bool EnumDelegate(IntPtr h, IntPtr state);
 [StructLayout(LayoutKind.Sequential)]
 public struct RECT {public int Left,Top,Right,Bottom;}
 [DllImport("user32.dll")]
 [return: MarshalAs(UnmanagedType.Bool)]
 public static extern bool EnumWindows(EnumDelegate cb,IntPtr arg);
 [DllImport("user32.dll")]
 [return: MarshalAs(UnmanagedType.Bool)]
 public static extern bool EnumChildWindows(IntPtr parent, EnumDelegate cb, IntPtr arg);
 [DllImport("user32.dll")]
 public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
 [DllImport("user32.dll")]
 [return: MarshalAs(UnmanagedType.Bool)]
 public static extern bool IsWindowVisible(IntPtr hwnd);
 [DllImport("user32.dll")]
 [return: MarshalAs(UnmanagedType.Bool)]
 public static extern bool GetWindowRect(IntPtr hwnd,out RECT rect);
 [DllImport("user32.dll",EntryPoint="GetWindowLongPtrW")]
 public static extern IntPtr GetWindowLongPtr(IntPtr hwnd,int index);
 [DllImport("user32.dll")]
 public static extern IntPtr GetParent(IntPtr hwnd);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]
 public static extern IntPtr FindWindow(string name,string title);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]
 public static extern int GetClassName(IntPtr hwnd,StringBuilder cls,int max);
 [DllImport("dwmapi.dll")]
 public static extern int DwmGetWindowAttribute(IntPtr hwnd,uint attrib,out int value,int size);
}
'@
$windows=[Collections.Generic.List[object]]::new()
$dedupe=[Collections.Generic.HashSet[long]]::new()
$tray=[R106NativeWindows]::FindWindow('Shell_TrayWnd',$null)
$trayRect=@()
if($tray -ne [IntPtr]::Zero){
 $rc=New-Object R106NativeWindows+RECT
 if([R106NativeWindows]::GetWindowRect($tray,[ref]$rc)){
     $trayRect=@($rc.Left,$rc.Top,$rc.Right,$rc.Bottom)
 }
}
function Record-R106([IntPtr]$h,[string]$source){
 [uint32]$pidOf=0
 [void][R106NativeWindows]::GetWindowThreadProcessId($h,[ref]$pidOf)
 if([int]$pidOf -ne $ExpectedPid){return}
 if(!$dedupe.Add($h.ToInt64())){return}
 $rc=New-Object R106NativeWindows+RECT
 $hasRect=[R106NativeWindows]::GetWindowRect($h,[ref]$rc)
 $cls=[Text.StringBuilder]::new(256)
 [void][R106NativeWindows]::GetClassName($h,$cls,$cls.Capacity)
 $style=[R106NativeWindows]::GetWindowLongPtr($h,-16).ToInt64()
 $ex=[R106NativeWindows]::GetWindowLongPtr($h,-20).ToInt64()
 $parent=[R106NativeWindows]::GetParent($h)
 $cloaked=-1
 try{
   [int]$out=0
   $result=[R106NativeWindows]::DwmGetWindowAttribute($h,[uint32]14,[ref]$out,4)
   if($result -eq 0){$cloaked=$out}
 }catch{}
 $width=if($hasRect){$rc.Right-$rc.Left}else{0}
 $height=if($hasRect){$rc.Bottom-$rc.Top}else{0}
 $isLayered=(($ex -band 0x80000) -ne 0)
 $isNoActivate=(($ex -band 0x8000000) -ne 0)
 $isChild=(($style -band 0x40000000) -ne 0)
 $isPopup=(($style -band -2147483648) -ne 0)
 $matches=($hasRect -and $width -eq 1100 -and $height -eq 48 -and
   [R106NativeWindows]::IsWindowVisible($h) -and $isLayered -and
   $isNoActivate -and $isPopup -and !$isChild)
 $windows.Add([ordered]@{
   From=$source;HWND=$h.ToInt64();PID=$ExpectedPid;Class=$cls.ToString()
   Visible=[R106NativeWindows]::IsWindowVisible($h)
   ParentHandle=$parent.ToInt64();ParentIsTaskbar=($parent -eq $tray)
   RectKnown=$hasRect;Rect=if($hasRect){@($rc.Left,$rc.Top,$rc.Right,$rc.Bottom)}else{@()}
   Width=$width;Height=$height;Style=[string]$style;ExStyle=[string]$ex
   IsLayered=$isLayered;IsNoActivate=$isNoActivate;IsPopup=$isPopup;IsChild=$isChild
   DwmCloaked=$cloaked;MatchesNative1100x48Signature=$matches
 })
}
$callback=[R106NativeWindows+EnumDelegate]{
 param([IntPtr]$handle,[IntPtr]$data)
 Record-R106 $handle 'top_level'
 return $true
}
[void][R106NativeWindows]::EnumWindows($callback,[IntPtr]::Zero)
if($tray -ne [IntPtr]::Zero){
 $cb=[R106NativeWindows+EnumDelegate]{
  param([IntPtr]$handle,[IntPtr]$data)
  Record-R106 $handle 'taskbar_descendant'
  return $true
 }
 [void][R106NativeWindows]::EnumChildWindows($tray,$cb,[IntPtr]::Zero)
}
$screen=[ordered]@{Width=0;Height=0}
try{
 Add-Type -AssemblyName System.Windows.Forms
 $b=[Windows.Forms.Screen]::PrimaryScreen.Bounds
 $screen.Width=$b.Width;$screen.Height=$b.Height
}catch{throw 'R106 CANNOT VERIFY READONLY SCREEN'}
if($screen.Width -lt 1100 -or $screen.Height -lt 800){
 throw 'R106 RUNNER_SCREEN_INVALID_G14'
}
$match=@($windows|Where-Object {$_.MatchesNative1100x48Signature})
$report=[ordered]@{
 Schema=1;Revision='R106';EventCommit=$env:GITHUB_SHA
 HostRole='GITHUB_HOSTED_DISPOSABLE_WINDOWS'
 Status='PASS_READONLY_PID_WINDOW_ENUMERATION'
 ExactSourceExeSHA256=$PinnedMainSHA
 ExactProductPid=$ExpectedPid;ExactProductPath=$bound
 ExactSessionId=$proc.SessionId;ProbeSessionId=(Get-Process -Id $PID).SessionId
 MainProcessAlive=(!$proc.HasExited);MainWindowHandle=$proc.MainWindowHandle.ToInt64()
 TaskbarPresent=($tray -ne [IntPtr]::Zero);TaskbarRect=$trayRect
 Screen=$screen
 WindowsCount=$windows.Count;VisibleWindowsCount=@($windows|Where-Object {$_.Visible}).Count
 CandidateNativePopupCount=$match.Count
 EnumeratedProductWindows=@($windows)
 Meaning='READONLY_NATIVE_WINDOW_DIAGNOSTIC_NOT_FORMAL_G14_ACCEPTANCE'
 FormalG14Accepted=$false;SignedIndependentLabWitness='MISSING'
 RegistryMutated=$false;WindowMutated=$false;PersonalHostTouched=$false
 Utc=(Get-Date).ToUniversalTime().ToString('o')
}
[IO.File]::WriteAllText($path,($report|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
Write-Output ('R106_WIN32_PID_WINDOW_DIAGNOSTIC_PASS PRODUCT_WINDOWS='+$report.WindowsCount+
 ' VISIBLE='+$report.VisibleWindowsCount+' MATCHING_NATIVE='+$report.CandidateNativePopupCount+
 ' SCREEN='+$screen.Width+'x'+$screen.Height+' SHA256='+
 (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash+' G14_FORMAL_OPEN')
exit 0
