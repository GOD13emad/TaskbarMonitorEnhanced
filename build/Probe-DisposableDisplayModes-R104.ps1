# R104: read-only Win32 EnumDisplaySettingsW / CDS_TEST only on disposable GitHub Windows.
# No CDS_UPDATEREGISTRY, no actual display change, reboot, product install or personal desktop mutation.
[CmdletBinding()]
param([switch]$StaticOnly)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($StaticOnly){
  $t=$null;$e=$null
  [void][Management.Automation.Language.Parser]::ParseFile($PSCommandPath,[ref]$t,[ref]$e)
  if(@($e).Count -ne 0){throw 'R104_STATIC_SOURCE_PARSER_FAILED'}
  Write-Output 'R104_ENUM_DISPLAY_STATIC_PASS_NO_WIN32_CALL_OR_DESKTOP_MUTATION'
  exit 0
}
if($env:GITHUB_ACTIONS -cne 'true' -or
   $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
   $env:RUNNER_OS -cne 'Windows' -or
   $env:GITHUB_SHA -cnotmatch '^[0-9a-f]{40}$' -or
   $env:COMPUTERNAME -ceq 'EMAD-PC-ULTIMAT' -or
   [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)){
    throw 'R104_REFUSE_NONDISPOSABLE_HOST'
}
$dir=[IO.Path]::GetFullPath((Join-Path $env:RUNNER_TEMP 'TBME_R104_DisplayModes'))
if(Test-Path -LiteralPath $dir){throw 'R104_UNSAFE_RERUN'}
New-Item -ItemType Directory -Path $dir -ErrorAction Stop|Out-Null
$receipt=Join-Path $dir 'R104_DISPLAY_CAPABILITY.json'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class R104Win32Display {
 [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
 public struct DEVMODE {
  [MarshalAs(UnmanagedType.ByValTStr,SizeConst=32)]
  public string dmDeviceName;
  public ushort dmSpecVersion,dmDriverVersion,dmSize,dmDriverExtra;
  public uint dmFields;
  public int dmPositionX,dmPositionY;
  public uint dmDisplayOrientation,dmDisplayFixedOutput;
  public short dmColor,dmDuplex,dmYResolution,dmTTOption,dmCollate;
  [MarshalAs(UnmanagedType.ByValTStr,SizeConst=32)]
  public string dmFormName;
  public ushort dmLogPixels;
  public uint dmBitsPerPel,dmPelsWidth,dmPelsHeight,dmDisplayFlags,dmDisplayFrequency;
  public uint dmICMMethod,dmICMIntent,dmMediaType,dmDitherType,dmReserved1,dmReserved2;
  public uint dmPanningWidth,dmPanningHeight;
 }
 [DllImport("user32.dll",CharSet=CharSet.Unicode,EntryPoint="EnumDisplaySettingsW")]
 [return: MarshalAs(UnmanagedType.Bool)]
 public static extern bool EnumDisplaySettings(string device,int index,ref DEVMODE mode);
 [DllImport("user32.dll",CharSet=CharSet.Unicode,EntryPoint="ChangeDisplaySettingsExW")]
 public static extern int ChangeDisplaySettingsEx(string device,ref DEVMODE mode,IntPtr hwnd,uint flags,IntPtr lParam);
 public static DEVMODE NewMode(){
  DEVMODE mode=new DEVMODE();
  mode.dmSize=(ushort)Marshal.SizeOf(typeof(DEVMODE));
  return mode;
 }
}
'@
Add-Type -AssemblyName System.Windows.Forms
$primaryScreen=[Windows.Forms.Screen]::PrimaryScreen
if($null -eq $primaryScreen){throw 'R104_NO_PRIMARY_SCREEN'}
$deviceName=[string]$primaryScreen.DeviceName
if($deviceName -cnotmatch '^\\\\\.\\DISPLAY[1-9][0-9]*$'){
    throw ('R104_PRIMARY_DEVICE_NAME_INVALID '+$deviceName)
}
# R104-F01: hosted Windows rejected NULL default-device query; exact \.DISPLAY1
# read-only query is supported. Do not enumerate an unspecified device.
$current=[R104Win32Display]::NewMode()
if(![R104Win32Display]::EnumDisplaySettings($deviceName,-1,[ref]$current)){
  throw 'R104_ENUM_CURRENT_DISPLAY_MODE_FAILED'
}
$primary=$primaryScreen.Bounds
$before=[ordered]@{Width=[int]$current.dmPelsWidth;Height=[int]$current.dmPelsHeight;
 BitsPerPixel=[int]$current.dmBitsPerPel;Frequency=[int]$current.dmDisplayFrequency;DEVMODEBytes=[int]$current.dmSize}
if($before.Width -ne $primary.Width -or $before.Height -ne $primary.Height){
 throw 'R104_DEVMODE_SCREEN_SIZE_CONTRADICTION'
}
$rows=@();$tests=@()
for($i=0;$i -lt 256;$i++){
 $mode=[R104Win32Display]::NewMode()
 if(![R104Win32Display]::EnumDisplaySettings($deviceName,$i,[ref]$mode)){break}
 $record=[ordered]@{Index=$i;Width=[int]$mode.dmPelsWidth;Height=[int]$mode.dmPelsHeight;
 BitsPerPixel=[int]$mode.dmBitsPerPel;Frequency=[int]$mode.dmDisplayFrequency}
 $rows+=$record
 if($record.Width -ge 1100 -and $record.Height -ge 800 -and
    $record.BitsPerPixel -ge 32 -and $tests.Count -lt 20){
   # 0x00000002: CDS_TEST only; does not change the graphics mode.
   $result=[R104Win32Display]::ChangeDisplaySettingsEx(
      $deviceName,[ref]$mode,[IntPtr]::Zero,[uint32]2,[IntPtr]::Zero)
   $tests+=[ordered]@{Index=$i;Width=$record.Width;Height=$record.Height;
      BitDepth=$record.BitsPerPixel;Frequency=$record.Frequency;
      Win32Flag='CDS_TEST_ONLY';ReturnCode=$result;Supported=($result -eq 0)}
 }
}
$finalMode=[R104Win32Display]::NewMode()
if(![R104Win32Display]::EnumDisplaySettings($deviceName,-1,[ref]$finalMode)){
 throw 'R104_ENUM_FINAL_DISPLAY_FAILED'
}
$after=[ordered]@{Width=[int]$finalMode.dmPelsWidth;Height=[int]$finalMode.dmPelsHeight;
 BitsPerPixel=[int]$finalMode.dmBitsPerPel;Frequency=[int]$finalMode.dmDisplayFrequency;DEVMODEBytes=[int]$finalMode.dmSize}
$finalScreen=[Windows.Forms.Screen]::PrimaryScreen.Bounds
if($rows.Count -lt 1 -or $before.Width -ne $after.Width -or $before.Height -ne $after.Height -or
 $before.BitsPerPixel -ne $after.BitsPerPixel -or $before.Frequency -ne $after.Frequency -or
 $primary.Width -ne $finalScreen.Width -or $primary.Height -ne $finalScreen.Height){
 throw 'R104_DISPLAY_READONLY_POSTSTATE_INVALID'
}
$good=@($tests|Where-Object {$_.Supported})
$report=[ordered]@{
 Schema=1;Revision='R104';EventCommit=$env:GITHUB_SHA;HostRole='GITHUB_HOSTED_DISPOSABLE_WINDOWS'
 Status='PASS_READONLY_DISPLAY_MODE_ENUMERATION';DisplayDeviceName=$deviceName;OriginalMode=$before;FinalMode=$after
 ScreenBefore=@($primary.X,$primary.Y,$primary.Width,$primary.Height)
 ScreenAfter=@($finalScreen.X,$finalScreen.Y,$finalScreen.Width,$finalScreen.Height)
 ModeCount=$rows.Count;EnumeratedModes=$rows
 CDSTestModes=$tests;WiderSupportedCount=$good.Count
 RequiredNativeOverlayWidth=1100
 SupportedWiderModeExists=($good.Count -gt 0)
 MutationFlagOnly='CDS_TEST';RegistryUpdated=$false;GraphicsModeChanged=$false
 NoRebootOrLogoff=$true;NoInstall=$true;PersonalWallpaperTouched=$false
 FormalG14Accepted=$false;IndependentLabWitnessSignature='MISSING'
 Verdict=if($good.Count -gt 0){'WIDER_MODE_SUPPORTED_FOR_LATER_TRANSACTIONAL_VM_TEST'}else{'NO_WIDER_SUPPORTED_VM_MODE_ESCALATE_INDEPENDENT_LAB'}
 Utc=(Get-Date).ToUniversalTime().ToString('o')
}
[IO.File]::WriteAllText($receipt,($report|ConvertTo-Json -Depth 10),[Text.UTF8Encoding]::new($false))
Write-Output ('R104_DISPLAY_CAPABILITY_READONLY_PASS MODES='+$rows.Count+
 ' TESTED_WIDE='+$tests.Count+' SUPPORTED_WIDE='+$good.Count+
 ' SCREEN='+$before.Width+'x'+$before.Height+' SHA256='+
 (Get-FileHash $receipt -Algorithm SHA256).Hash+' G14_STABLE_OPEN')
exit 0
