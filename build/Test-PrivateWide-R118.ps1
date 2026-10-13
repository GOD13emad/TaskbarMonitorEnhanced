# R108: ONE disposable GitHub-hosted Windows VM session: reversible temporary Win32 display
# mode (flags=0 only, NO registry changes) + exact public Preview1 installed G14 diagnostic.
# No reboot/logoff, driver/security adjustments or mutation on a personal machine.
[CmdletBinding()]
param([switch]$StaticOnly)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$Source='R108'
$TargetWidth=1600;$TargetHeight=900;$TargetBpp=32
$AllowedModeFlags=[uint32]0
$DisplayTestFlags=[uint32]2
$ExpectedPrivateMainSHA='FB77754C337441F1A87CD38DCEF45FE8C4DC66A2ACAC3E27CFE388417549CFD9'
if($StaticOnly){
    $tokens=$null;$problems=$null
    [void][Management.Automation.Language.Parser]::ParseFile($PSCommandPath,[ref]$tokens,[ref]$problems)
    if(@($problems).Count -ne 0){throw 'R108 PARSER ERROR'}
    if($AllowedModeFlags -ne 0 -or $DisplayTestFlags -ne 2 -or
       $TargetWidth -ne 1600 -or $TargetHeight -ne 900){
        throw 'R108 DISPLAY SWITCH GUARDS DISABLED'
    }
    Write-Output 'R108_STATIC_EXACT_TEMP_DISPLAY_FLAGS_0_TEST_FLAGS_2_PASS_NO_MUTATION'
    exit 0
}
if($env:GITHUB_ACTIONS -cne 'true' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
   $env:RUNNER_OS -cne 'Windows' -or $env:GITHUB_SHA -cnotmatch '^[0-9a-f]{40}$' -or
   [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP) -or
   $env:COMPUTERNAME -ceq 'EMAD-PC-ULTIMAT' -or
   ![Environment]::UserInteractive){
    throw 'R108 REFUSE ANY NONDISPOSABLE / NONINTERACTIVE MACHINE'
}
$dir=[IO.Path]::GetFullPath((Join-Path $env:RUNNER_TEMP 'TBME_R108_PrivateWide'))
$smokeRoot=[IO.Path]::GetFullPath((Join-Path $env:RUNNER_TEMP 'TBME_R107_PRIVATE_CANDIDATE'))
$smokeHarness=Join-Path $PSScriptRoot 'Test-G14-PrivateCandidate-R118.ps1'
if((Test-Path -LiteralPath $dir) -or (Test-Path -LiteralPath $smokeRoot) -or
   !(Test-Path -LiteralPath $smokeHarness -PathType Leaf)){
    throw 'R108 MISSING OWNED HARNESS OR UNSAFE RERUN OUTPUT'
}
New-Item -ItemType Directory -Path $dir -ErrorAction Stop|Out-Null
$receiptPath=Join-Path $dir 'R108_WIDESCREEN_TRANSACTION_RECEIPT.json'
$stdoutPath=Join-Path $dir 'R108_INSTALL_SMOKE_STDOUT.txt'
$stderrPath=Join-Path $dir 'R108_INSTALL_SMOKE_STDERR.txt'
$start=(Get-Date).ToUniversalTime().ToString('o')
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class R108WideNative {
 [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)]
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
 [StructLayout(LayoutKind.Sequential)]
 public struct RECT {public int Left,Top,Right,Bottom;}
 [DllImport("user32.dll",CharSet=CharSet.Unicode,EntryPoint="EnumDisplaySettingsW")]
 [return: MarshalAs(UnmanagedType.Bool)]
 public static extern bool EnumDisplaySettings(string device,int index,ref DEVMODE mode);
 [DllImport("user32.dll",CharSet=CharSet.Unicode,EntryPoint="ChangeDisplaySettingsExW")]
 public static extern int ChangeDisplaySettingsEx(string device,ref DEVMODE mode,IntPtr hwnd,uint flags,IntPtr lParam);
 [DllImport("user32.dll")]
 public static extern int GetSystemMetrics(int i);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]
 public static extern IntPtr FindWindow(string cls,string title);
 [DllImport("user32.dll")]
 [return: MarshalAs(UnmanagedType.Bool)]
 public static extern bool GetWindowRect(IntPtr hwnd,out RECT rect);
 public static DEVMODE NewMode(){
  DEVMODE m=new DEVMODE();
  m.dmSize=(ushort)Marshal.SizeOf(typeof(DEVMODE));
  return m;
 }
}
'@
Add-Type -AssemblyName System.Windows.Forms
function Current-R108Mode([string]$name){
    $m=[R108WideNative]::NewMode()
    if(![R108WideNative]::EnumDisplaySettings($name,-1,[ref]$m)){
        throw 'R108 CANNOT READ CURRENT DISPLAY MODE'
    }
    return $m
}
function Snapshot-R108Display([string]$name){
    $mode=Current-R108Mode $name
    $bounds=[Windows.Forms.Screen]::PrimaryScreen.Bounds
    return [ordered]@{
      Device=$name;Width=[int]$mode.dmPelsWidth;Height=[int]$mode.dmPelsHeight
      Bpp=[int]$mode.dmBitsPerPel;Hz=[int]$mode.dmDisplayFrequency
      NativeScreen=@([R108WideNative]::GetSystemMetrics(0),[R108WideNative]::GetSystemMetrics(1))
      WinFormsScreen=@($bounds.X,$bounds.Y,$bounds.Width,$bounds.Height)
      TaskbarRect=Get-R108TaskbarRect
    }
}
function Get-R108TaskbarRect {
    $taskbar=[R108WideNative]::FindWindow('Shell_TrayWnd',$null)
    if($taskbar -eq [IntPtr]::Zero){return @()}
    $rect=New-Object R108WideNative+RECT
    if(![R108WideNative]::GetWindowRect($taskbar,[ref]$rect)){return @()}
    return @($rect.Left,$rect.Top,$rect.Right,$rect.Bottom)
}
function Same-R108Mode($a,$b){
    if(!$a -or !$b){return $false}
    return ($a.Device -ceq $b.Device -and $a.Width -eq $b.Width -and
       $a.Height -eq $b.Height -and $a.Bpp -eq $b.Bpp -and
       $a.Hz -eq $b.Hz -and
       ($a.NativeScreen -join ',') -ceq ($b.NativeScreen -join ',') -and
       ($a.WinFormsScreen -join ',') -ceq ($b.WinFormsScreen -join ',') -and
       @($a.TaskbarRect).Count -eq 4 -and
       ($a.TaskbarRect -join ',') -ceq ($b.TaskbarRect -join ','))
}
$screen=[Windows.Forms.Screen]::PrimaryScreen
if($null -eq $screen){throw 'R108 NO PRIMARY SCREEN'}
$device=[string]$screen.DeviceName
if($device -cnotmatch '^\\\\\.\\DISPLAY[1-9][0-9]*$'){
    throw 'R108 PRIMARY DISPLAY DEVICE NOT VALIDATED'
}
$original=Current-R108Mode $device
$before=Snapshot-R108Display $device
$targetMode=$null
$targetInfo=[ordered]@{Width=$TargetWidth;Height=$TargetHeight;Bpp=$TargetBpp;Hz=0;Index=-1}
$pretestOriginal=-999
$pretestTarget=-999
$setResult=-999
$restoreResult=-999
$setAttempted=$false
$modeApplied=$false
$modeRestored=$false
$changeObserved=$false
$childExit=-999
$childError=''
$stdout='';$stderr=''
$middle=$null;$after=$null
$failure=''
$phase='PREFLIGHT'
$g14Path=''
$g14Status='NOT_RUN'
$g14Attempts=0;$g14Passes=0
$g14FailureNames=@()
$g14ReceiptSHA=''
$underlyingSmokeStatus='NOT_RUN'
$earlyError=''
try{
    if($before.Width -ge $TargetWidth -or $before.Height -ge $TargetHeight){
        throw 'R108 BASELINE NOT EXPECTED NARROW VM; REFUSE UNNECESSARY MODE SWITCH'
    }
    if($before.Width -ne $before.NativeScreen[0] -or
       $before.Height -ne $before.NativeScreen[1]){
        throw 'R108 NATIVE CURRENT MODE AND SCREEN METRICS CONTRADICT'
    }
    $pretestOriginal=[R108WideNative]::ChangeDisplaySettingsEx(
        $device,[ref]$original,[IntPtr]::Zero,$DisplayTestFlags,[IntPtr]::Zero)
    if($pretestOriginal -ne 0){throw 'R108 ORIGINAL DISPLAY MODE FAILS CDS_TEST'}
    for($i=0;$i -lt 256;$i++){
        $mode=[R108WideNative]::NewMode()
        if(![R108WideNative]::EnumDisplaySettings($device,$i,[ref]$mode)){break}
        if([int]$mode.dmPelsWidth -ne $TargetWidth -or [int]$mode.dmPelsHeight -ne $TargetHeight -or
           [int]$mode.dmBitsPerPel -ne $TargetBpp){continue}
        # Deterministic requested virtual display 1600x900, 32bpp, exact enumerated mode.
        $tested=[R108WideNative]::ChangeDisplaySettingsEx(
            $device,[ref]$mode,[IntPtr]::Zero,$DisplayTestFlags,[IntPtr]::Zero)
        if($tested -eq 0){
           $targetMode=$mode
           $targetInfo.Hz=[int]$mode.dmDisplayFrequency
           $targetInfo.Index=$i
           $pretestTarget=$tested
           break
        }
    }
    if($null -eq $targetMode){throw 'R108 NO EXACT SUPPORTED 1600x900 32BPP MODE'}
    $phase='TEMP_MODE_SWITCH'
    $setAttempted=$true
    # Zero flags means transient graphics-mode change only. Never CDS_UPDATEREGISTRY.
    $setResult=[R108WideNative]::ChangeDisplaySettingsEx(
        $device,[ref]$targetMode,[IntPtr]::Zero,$AllowedModeFlags,[IntPtr]::Zero)
    if($setResult -ne 0){throw ('R108 TEMP MODE CHANGE REFUSED CODE '+$setResult)}
    $modeApplied=$true
    $deadline=(Get-Date).AddSeconds(14)
    while((Get-Date) -lt $deadline){
        Start-Sleep -Milliseconds 600
        $middle=Snapshot-R108Display $device
        if($middle.Width -eq $TargetWidth -and $middle.Height -eq $TargetHeight -and
           $middle.NativeScreen[0] -eq $TargetWidth -and $middle.NativeScreen[1] -eq $TargetHeight -and
           $middle.WinFormsScreen[2] -eq $TargetWidth -and $middle.WinFormsScreen[3] -eq $TargetHeight){
            $changeObserved=$true
            break
        }
    }
    if(!$changeObserved){throw 'R108 DISPLAY MODE CHANGE NOT OBSERVED BY BOTH INDEPENDENT SCREEN APIs'}
    $phase='ACTUAL_INSTALLED_G14_HOSTED'
    $psi=[Diagnostics.ProcessStartInfo]::new()
    $psi.FileName='pwsh.exe'
    $psi.UseShellExecute=$false
    $psi.WorkingDirectory=$PSScriptRoot
    $psi.CreateNoWindow=$true
    $psi.RedirectStandardOutput=$true
    $psi.RedirectStandardError=$true
    foreach($arg in @('-NoProfile','-NonInteractive','-File',$smokeHarness)){
        [void]$psi.ArgumentList.Add([string]$arg)
    }
    $proc=$null
    try{
        $proc=[Diagnostics.Process]::Start($psi)
        if($null -eq $proc){throw 'R108 INSTALLED DIAGNOSTIC CHILD DID NOT START'}
        $outTask=$proc.StandardOutput.ReadToEndAsync()
        $errTask=$proc.StandardError.ReadToEndAsync()
        if(!$proc.WaitForExit(810000)){
            try{$proc.Kill();$proc.WaitForExit(7000)}catch{}
            throw 'R108 INSTALLED DIAGNOSTIC CHILD TIMED OUT'
        }
        $childExit=[int]$proc.ExitCode
        $stdout=$outTask.GetAwaiter().GetResult()
        $stderr=$errTask.GetAwaiter().GetResult()
    }catch{
        $childError=$_.Exception.ToString()
        if($null -ne $proc){
            try{$stdout=$outTask.GetAwaiter().GetResult()}catch{}
            try{$stderr=$errTask.GetAwaiter().GetResult()}catch{}
        }
    }finally{
        if($proc){$proc.Dispose()}
        [IO.File]::WriteAllText($stdoutPath,[string]$stdout,[Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText($stderrPath,[string]$stderr,[Text.UTF8Encoding]::new($false))
    }
    $g14Path=Join-Path $smokeRoot 'R107_PRIVATE_CANDIDATE_RECEIPT.json'
    $smokeReceipt=Join-Path $smokeRoot 'R107_PRIVATE_CANDIDATE_RECEIPT.json'
    if(Test-Path -LiteralPath $g14Path -PathType Leaf){
        $g14=Get-Content -LiteralPath $g14Path -Raw|ConvertFrom-Json
        $g14Status=[string]$g14.Status
        $g14Attempts=[int]$g14.DiagnosticAttempts
        $g14Passes=[int]$g14.DiagnosticPasses
        $g14FailureNames=@($g14.DiagnosticResults|Where-Object {$_.Status -ceq 'FAIL_DIAGNOSTIC'}|ForEach-Object Test)
        $g14ReceiptSHA=(Get-FileHash -LiteralPath $g14Path -Algorithm SHA256).Hash
    }
    if(Test-Path -LiteralPath $smokeReceipt -PathType Leaf){
        $smoke=Get-Content -LiteralPath $smokeReceipt -Raw|ConvertFrom-Json
        $underlyingSmokeStatus=[string]$smoke.Status
    }
    if($childExit -ne 0 -or $childError){
        throw ('R108 EXACT PRIVATE CANDIDATE INSTALLED SMOKE FAILED EXIT='+$childExit+' '+$childError)
    }
    if($g14Attempts -ne 8 -or $g14Status -cne 'PASS_PRIVATE_CANDIDATE_INSTALLED_EIGHT_DIAGNOSTICS_CAPTURED'){
        throw 'R108 EIGHT DIAGNOSTIC RECEIPT NOT PRODUCED'
    }
}catch{
    $failure=$_.Exception.ToString()
}finally{
    $phase='RESTORE_EXACT_ORIGINAL_DISPLAY'
    if($setAttempted){
        # Always attempt to restore the exact snapshotted native DEVMODE, with
        # flags=0. Never reboot, logout, write display registry or hide rollback failure.
        try{
            $restoreResult=[R108WideNative]::ChangeDisplaySettingsEx(
                $device,[ref]$original,[IntPtr]::Zero,$AllowedModeFlags,[IntPtr]::Zero)
            if($restoreResult -eq 0){
                $restoreDeadline=(Get-Date).AddSeconds(14)
                while((Get-Date) -lt $restoreDeadline){
                    Start-Sleep -Milliseconds 600
                    $after=Snapshot-R108Display $device
                    if(Same-R108Mode $before $after){
                        $modeRestored=$true;break
                    }
                }
            }
        }catch{$failure+=(' ; RESTORE_THROW '+$_.Exception.ToString())}
    }else{
        try{$after=Snapshot-R108Display $device;$modeRestored=Same-R108Mode $before $after}
        catch{$failure+=(' ; ORIGINAL_READ_ERROR '+$_.Exception.ToString())}
    }
    if(-not $modeRestored){$failure+=' ; CRITICAL_UNRESOLVED_EXACT_DISPLAY_ROLLBACK'}
    $after=if($null -ne $after){$after}else{[ordered]@{Width=-1;Height=-1;Bpp=-1;Hz=-1}}
    $summary=[ordered]@{
        Schema=1;Revision='R108';EventCommit=$env:GITHUB_SHA
        HostRole='GITHUB_HOSTED_DISPOSABLE_WINDOWS'
        Status=if($modeApplied -and $changeObserved -and $modeRestored -and $childExit -eq 0 -and !$failure){
           'PASS_PRIVATE_CANDIDATE_1600_AND_EXACT_RESTORE'
        }else{'FAIL_CLOSED_OR_INCOMPLETE_DISPLAY_TRANSACTION'}
        DeviceName=$device
        OriginalMode=$before;RequestedMode=$targetInfo;ObservedWideMode=$middle;FinalMode=$after
        OriginalCDSTestCode=$pretestOriginal;TargetCDSTestCode=$pretestTarget
        DisplayChangeFlags=0;CDSTestFlags=2;RegistryModePersistence=$false
        DisplayChangeAttempted=$setAttempted
        DisplayChangeReturnCode=$setResult;DisplayModeApplied=$modeApplied
        WideModeIndependentlyObserved=$changeObserved;RestoreReturnCode=$restoreResult
        OriginalModeExactRestored=$modeRestored
        SmokeChildExitCode=$childExit;SmokeChildError=$childError
        SmokeChildStdoutSHA256=if(Test-Path $stdoutPath){(Get-FileHash $stdoutPath -Algorithm SHA256).Hash}else{''}
        SmokeChildStderrSHA256=if(Test-Path $stderrPath){(Get-FileHash $stderrPath -Algorithm SHA256).Hash}else{''}
        PrivateCandidateInstallStatus=$underlyingSmokeStatus
        G14DiagnosticStatus=$g14Status;G14Completed=$g14Attempts;G14Passed=$g14Passes
        G14FailedCases=@($g14FailureNames);G14ReceiptSHA256=$g14ReceiptSHA
        G13FormalAccepted=$false;G14FormalAccepted=$false
        TrustedIndependentLabWitness='MISSING'
        PersonalDesktopTouched=$false;DriverInstalled=$false;SystemRebooted=$false
        StartedUTC=$start;FinishedUTC=(Get-Date).ToUniversalTime().ToString('o')
        Failure=$failure
    }
    [IO.File]::WriteAllText($receiptPath,($summary|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
    Write-Output ('R108_WIDE_MODE_G14_STATUS='+$summary.Status+' CHANGE='+$setResult+
        ' RESTORE='+$restoreResult+' ORIGINAL_EXACT_RESTORED='+$modeRestored+
        ' G14_PASS='+$g14Passes+' G14_ATTEMPTED='+$g14Attempts+
        ' SHA256='+(Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash+
        ' FORMAL_G14_OPEN')
}
if($summary.Status -cne 'PASS_PRIVATE_CANDIDATE_1600_AND_EXACT_RESTORE'){
    throw ('R108_FAIL_CLOSED '+$summary.Failure)
}
exit 0
