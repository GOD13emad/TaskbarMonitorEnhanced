# R103 G14 actual installed Main eight-case diagnostic on disposable GitHub-hosted Windows.
# Real user GUI/Start/Explorer/sensor G14 independent signed acceptance is NOT implied.
# Product remains exactly immutable unsigned public Preview1; no driver, Startup, Wallpaper
# or personal install mutations. This is NOT an upgrade/uninstall/reinstall workflow.
[CmdletBinding()]
param(
 [switch]$StaticOnly,
 [string]$MainExe='',
 [string]$EvidenceDir=''
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$ExpectedMainSHA='63A724981E949BA4C91F8BD44F2659F223BDFE0350A2E229CEE7B05535D4BA70'
$ExpectedConfigSHA='D2E51872D93F0793C02AD07DCBF8C2802F59708C666548372A4FDDDA5C7C5E4F'
$CaseSpecs=@(
 [ordered]@{Test='startup';Switch='--startup-contract-selftest';Output='';TimeoutMs=30000},
 [ordered]@{Test='hover';Switch='--hoverguardproof';Output='';TimeoutMs=30000},
 [ordered]@{Test='hardware';Switch='--hardwareprobe';Output='hardware.json';TimeoutMs=45000},
 [ordered]@{Test='temperature';Switch='--tempprobe';Output='temperature.json';TimeoutMs=45000},
 [ordered]@{Test='health';Switch='--healthprobe';Output='health.json';TimeoutMs=45000},
 [ordered]@{Test='support';Switch='--supportbundleproof';Output='support.zip';TimeoutMs=45000},
 [ordered]@{Test='start';Switch='--startprobe';Output='start';TimeoutMs=90000},
 [ordered]@{Test='shell';Switch='--shellstate';Output='shell.json';TimeoutMs=45000}
)
if($StaticOnly){
  $tokens=$null;$errs=$null
  [void][Management.Automation.Language.Parser]::ParseFile($PSCommandPath,[ref]$tokens,[ref]$errs)
  if(@($errs).Count -ne 0){throw 'R103 G14 SCRIPT PARSER FAIL'}
  $actual=@($CaseSpecs|ForEach-Object Test)
  if($actual.Count -ne 8 -or @($actual|Select-Object -Unique).Count -ne 8 -or
     @($actual|Where-Object {$_ -notin @('startup','hover','hardware','temperature','health','support','start','shell')}).Count -ne 0){
     throw 'R103 G14 EIGHT NAME INVENTORY INVALID'
  }
  Write-Output 'R103_G14_STATIC_EIGHT_CASE_PRECHECK_PASS_NO_DESKTOP_OR_INSTALL_MUTATION'
  exit 0
}
if($env:GITHUB_ACTIONS -cne 'true' -or
   $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
   $env:RUNNER_OS -cne 'Windows' -or
   $env:COMPUTERNAME -ceq 'EMAD-PC-ULTIMAT' -or
   $env:GITHUB_SHA -cnotmatch '^[a-f0-9]{40}$' -or
   [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP) -or
   ![Environment]::UserInteractive){throw 'R103 REFUSE NONDISPOSABLE OR NONINTERACTIVE HOST'}
$expectedMain=[IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'TaskbarMonitorEnhanced\TaskbarMonitorEnhanced.exe'))
$main=[IO.Path]::GetFullPath($MainExe)
$folder=[IO.Path]::GetFullPath($EvidenceDir)
$expectedFolder=[IO.Path]::GetFullPath((Join-Path $env:RUNNER_TEMP 'TBME_R88_UnsignedPreview_Smoke\R103_INSTALLED_8'))
if($main -cne $expectedMain -or $folder -cne $expectedFolder -or
   !(Test-Path -LiteralPath $main -PathType Leaf) -or
   (Test-Path -LiteralPath $folder)){throw 'R103 INPUTS NOT EXACT HOST OWNED OR UNSAFE RERUN'}
$mainSHA=(Get-FileHash -LiteralPath $main -Algorithm SHA256).Hash
$config=Join-Path (Split-Path $main -Parent) 'TaskbarMonitorEnhanced.exe.config'
if($mainSHA -cne $ExpectedMainSHA -or
   !(Test-Path -LiteralPath $config -PathType Leaf) -or
   (Get-FileHash -LiteralPath $config -Algorithm SHA256).Hash -cne $ExpectedConfigSHA){
     throw 'R103 NOT EXACT IMMUTABLE PUBLIC INSTALLED MAIN/CONFIG'
}
$stateFile=Join-Path (Split-Path $main -Parent) 'install_state.json'
if(!(Test-Path -LiteralPath $stateFile -PathType Leaf)){throw 'R103 NO INSTALLED IDENTITY'}
$state=Get-Content -LiteralPath $stateFile -Raw|ConvertFrom-Json
if($state.Version -cne '1.7.0' -or $state.ProductIdentity -cne 'LOCKED'){throw 'R103 INSTALL IDENTITY NOT LOCKED'}
$installReg='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TaskbarMonitorEnhanced'
if(!(Test-Path $installReg)){throw 'R103 INSTALLED UNINSTALL REG MISSING'}
$initial=@(Get-Process -Name TaskbarMonitorEnhanced -ErrorAction SilentlyContinue)
if($initial.Count -ne 0){throw 'R103 MULTIPLE OR PREEXISTING MAIN PROCESSES'}
$session=(Get-Process -Id $PID).SessionId
$explorers=@(Get-Process -Name explorer -ErrorAction SilentlyContinue|Where-Object {$_.SessionId -eq $session})
if($session -lt 1 -or $explorers.Count -lt 1){throw 'R103 REAL SAME SESSION EXPLORER NOT AVAILABLE'}
# Exact test-owned evidence directory, nothing else gets cleaned.
New-Item -ItemType Directory -Path $folder -ErrorAction Stop|Out-Null
$startUtc=(Get-Date).ToUniversalTime().ToString('o')
$summaryPath=Join-Path $folder 'R103_INSTALLED_EIGHT_DIAGNOSTIC.json'
$resident=$null
$residentStarted=$false
$residentId=0
$results=@()
$failure=''
$cleanup='NOT_STARTED'
$lastResidentPath=''
$lastResidentSHA=''
function Run-R103Probe([string]$switch,[string]$target,[string]$testName,[int]$timeout){
    $info=[Diagnostics.ProcessStartInfo]::new()
    $info.FileName=$main
    $info.WorkingDirectory=Split-Path $main -Parent
    $info.UseShellExecute=$false
    $info.CreateNoWindow=$true
    $info.RedirectStandardOutput=$true
    $info.RedirectStandardError=$true
    [void]$info.ArgumentList.Add($switch)
    if($target){[void]$info.ArgumentList.Add((Join-Path $folder $target))}
    $proc=$null;$stdout='';$stderr='';$code=-100; $problem=''
    try{
        $proc=[Diagnostics.Process]::Start($info)
        if(!$proc){throw 'G14 diagnostic probe failed to spawn'}
        $stdoutTask=$proc.StandardOutput.ReadToEndAsync()
        $stderrTask=$proc.StandardError.ReadToEndAsync()
        if(!$proc.WaitForExit($timeout)){
            try{$proc.Kill();$proc.WaitForExit(7000)}catch{}
            throw ('R103 TIMEOUT '+$testName)
        }
        $code=[int]$proc.ExitCode
        $stdout=$stdoutTask.GetAwaiter().GetResult()
        $stderr=$stderrTask.GetAwaiter().GetResult()
    }catch{
        $problem=$_.Exception.Message
        if($proc){
            try{$stdout=$stdoutTask.GetAwaiter().GetResult()}catch{}
            try{$stderr=$stderrTask.GetAwaiter().GetResult()}catch{}
        }
    }finally{if($proc){$proc.Dispose()}}
    $outPath=Join-Path $folder ($testName+'.out')
    $errPath=Join-Path $folder ($testName+'.err')
    [IO.File]::WriteAllText($outPath,[string]$stdout,[Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($errPath,[string]$stderr,[Text.UTF8Encoding]::new($false))
    $targetExists=(!$target) -or (Test-Path -LiteralPath (Join-Path $folder $target))
    $pass=($code -eq 0 -and $stdout.Contains('=PASS') -and
       !$stdout.Contains('=FAIL') -and !$stderr.Contains('=FAIL') -and
       !$problem -and $targetExists)
    return [ordered]@{
        Test=$testName;Switch=$switch;TimeoutMs=$timeout
        Status=if($pass){'PASS_DIAGNOSTIC'}else{'FAIL_DIAGNOSTIC'}
        ExitCode=$code;Error=$problem;Target=$target;TargetExists=[bool]$targetExists
        StdoutSHA256=(Get-FileHash -LiteralPath $outPath -Algorithm SHA256).Hash
        StderrSHA256=(Get-FileHash -LiteralPath $errPath -Algorithm SHA256).Hash
    }
}
try{
    $info=[Diagnostics.ProcessStartInfo]::new()
    $info.FileName=$main
    $info.WorkingDirectory=Split-Path $main -Parent
    $info.UseShellExecute=$false
    $info.CreateNoWindow=$false
    $resident=[Diagnostics.Process]::Start($info)
    if($null -eq $resident){throw 'R103 INSTALLED REAL GUI PROCESS NOT SPAWNED'}
    $residentId=[int]$resident.Id;$residentStarted=$true
    $ready=$false
    $deadline=(Get-Date).AddSeconds(19)
    while((Get-Date) -lt $deadline){
        $resident.Refresh()
        if($resident.HasExited){throw ('R103 REAL INSTALLED RESIDENT EXITED '+$resident.ExitCode)}
        $same=@(Get-Process -Name TaskbarMonitorEnhanced -ErrorAction SilentlyContinue|Where-Object {$_.Id -eq $residentId -and $_.SessionId -eq $session})
        if($same.Count -eq 1){
            $mainModule=''
            try{$mainModule=[IO.Path]::GetFullPath($same[0].MainModule.FileName)}catch{}
            if($mainModule -cne $main){throw 'R103 RESIDENT MAIN PATH DOES NOT MATCH EXACT PUBLIC APP'}
            $ready=$true;break
        }
        Start-Sleep -Milliseconds 600
    }
    if(!$ready){throw 'R103 INSTALLED MAIN DID NOT BECOME VALID RESIDENT'}
    $lastResidentPath=$main
    $lastResidentSHA=(Get-FileHash -LiteralPath $main -Algorithm SHA256).Hash
    # Give actual overlay time to initialize before Start and Shell-dependent probes.
    Start-Sleep -Seconds 5
    # Read-only desktop capability observation. This is not proof of a
    # visible 1100x48 native overlay or signed G14 acceptance.
    $desktopReadiness=[ordered]@{
        Revision='R103';EventCommit=$env:GITHUB_SHA
        HostRole='GITHUB_HOSTED_DISPOSABLE_WINDOWS'
        RealInstalledMainPid=$residentId
        RealInstalledMainProcessAlive=(!$resident.HasExited)
        SameSessionExplorerCount=$explorers.Count
        SameSessionId=$session
        MainWindowHandle=[long]$resident.MainWindowHandle.ToInt64()
        MainResponding=[bool]$resident.Responding
        UserInteractive=[Environment]::UserInteractive
        TaskbarFound=$false
        TaskbarRect=@()
        PrimaryScreenBounds=@()
        ReadinessOnlyNotG14Acceptance=$true
        Error=''
    }
    try{
        Add-Type -AssemblyName System.Windows.Forms
        $screen=[Windows.Forms.Screen]::PrimaryScreen.Bounds
        $desktopReadiness.PrimaryScreenBounds=@($screen.Left,$screen.Top,$screen.Width,$screen.Height)
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class R103ReadOnlyTaskbar {
 [StructLayout(LayoutKind.Sequential)]
 public struct RECT { public int Left,Top,Right,Bottom; }
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]
 public static extern IntPtr FindWindow(string name,string title);
 [DllImport("user32.dll")]
 public static extern bool GetWindowRect(IntPtr h,out RECT rect);
}
'@
        $tray=[R103ReadOnlyTaskbar]::FindWindow('Shell_TrayWnd',$null)
        $desktopReadiness.TaskbarFound=($tray -ne [IntPtr]::Zero)
        if($desktopReadiness.TaskbarFound){
            $rect=New-Object R103ReadOnlyTaskbar+RECT
            if([R103ReadOnlyTaskbar]::GetWindowRect($tray,[ref]$rect)){
                $desktopReadiness.TaskbarRect=@($rect.Left,$rect.Top,$rect.Right,$rect.Bottom)
            }
        }
    }catch{$desktopReadiness.Error=$_.Exception.Message}
    [IO.File]::WriteAllText((Join-Path $folder 'R103_GUI_READINESS.json'),
        ($desktopReadiness|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
    # R106 read-only Win32 HWND/PID/Explorer topology of the exact hosted installed Main.
    # No window/desktop mutation and never treat this evidence as formal G14 acceptance.
    $nativeProbe=Join-Path $PSScriptRoot 'Probe-NativeWindows-R106.ps1'
    if(!(Test-Path -LiteralPath $nativeProbe -PathType Leaf)){throw 'R106 native probe missing'}
    & $nativeProbe -ExpectedPid $residentId -ExpectedMain $main -OutputDirectory $folder
    if($LASTEXITCODE -ne 0){throw 'R106 native HWND diagnostic failed'}
    if(!(Test-Path -LiteralPath (Join-Path $folder 'R106_NATIVE_WINDOWS.json') -PathType Leaf)){
        throw 'R106 native raw receipt missing'
    }
    foreach($spec in $CaseSpecs){
        $result=Run-R103Probe -switch $spec.Switch -target $spec.Output -testName $spec.Test -timeout $spec.TimeoutMs
        $results+= $result
        Write-Output ('R103_G14_CASE='+$spec.Test+' '+$result.Status+' EXIT='+$result.ExitCode)
        if($resident.HasExited){
            $failure='RESIDENT_EXITED_DURING_EIGHT_DIAGNOSTIC'
            break
        }
    }
}catch{$failure=$_.Exception.ToString()}
finally{
    if($resident){
        try{
            $resident.Refresh()
            if(!$resident.HasExited){
                try{[void]$resident.CloseMainWindow();$resident.WaitForExit(3000)|Out-Null}catch{}
                $resident.Refresh()
                if(!$resident.HasExited){
                    # Terminate only this exact disposable VM-owned process started by us.
                    # Exact Process object and PID were captured at spawn; only terminate
                    # this disposable test-owned child, never a process searched by name.
                    if($resident.Id -ne $residentId -or !$residentStarted -or $lastResidentPath -cne $main){
                        throw 'R103 REFUSE TERMINATE UNKNOWN RESIDENT'
                    }
                    $resident.Kill()
                    $resident.WaitForExit(8000)|Out-Null
                }
            }
            $cleanup=if($resident.HasExited){'PASS_EXACT_STARTED_RESIDENT_EXITED'}else{'FAIL_STARTED_RESIDENT_UNRESOLVED'}
        }catch{$cleanup='FAIL_CLOSED_CLEANUP '+$_.Exception.Message}
        $resident.Dispose()
    }else{$cleanup='NO_RESIDENT_CREATED'}
    $changedMain=(Get-FileHash -LiteralPath $main -Algorithm SHA256).Hash
    $changedConfig=(Get-FileHash -LiteralPath $config -Algorithm SHA256).Hash
    $eight=@($results|ForEach-Object Test)
    $allEight=($results.Count -eq 8 -and @($eight|Select-Object -Unique).Count -eq 8)
    $passes=@($results|Where-Object {$_.Status -eq 'PASS_DIAGNOSTIC'}).Count
    $summary=[ordered]@{
       Schema=1;Revision='R103';EventCommit=$env:GITHUB_SHA
       Purpose='DISPOSABLE_INSTALLED_G14_EIGHT_DIAGNOSTIC_NO_FORMAL_ACCEPTANCE'
       Status=if($allEight -and !$failure -and $cleanup -eq 'PASS_EXACT_STARTED_RESIDENT_EXITED' -and
            $changedMain -ceq $ExpectedMainSHA -and
            $changedConfig -ceq $ExpectedConfigSHA){
              'EIGHT_RESULTS_CAPTURED_DIAGNOSTIC_ONLY'
            }else{'FAIL_CLOSED_OR_INCOMPLETE_DIAGNOSTIC'}
       ExactInstalledMainSHA256=$changedMain;InstalledConfigSHA256=$changedConfig
       HostRole='GITHUB_HOSTED_DISPOSABLE_WINDOWS';ExplorerSameSession=$explorers.Count
       UserInteractive=[Environment]::UserInteractive;HostSessionId=$session
       OriginalPublicTag='v1.7.0-unsigned-preview.1'
       ResidentStarted=$residentStarted;ResidentProcessId=$residentId;ResidentPath=$lastResidentPath
       ResidentMainSHA256=$lastResidentSHA
       GuiReadinessReport='R103_GUI_READINESS.json'
       GuiReadinessSHA256=if(Test-Path -LiteralPath (Join-Path $folder 'R103_GUI_READINESS.json')){
           (Get-FileHash -LiteralPath (Join-Path $folder 'R103_GUI_READINESS.json') -Algorithm SHA256).Hash
       }else{''}
       R106NativeWindowReport='R106_NATIVE_WINDOWS.json'
       R106NativeWindowSHA256=if(Test-Path -LiteralPath (Join-Path $folder 'R106_NATIVE_WINDOWS.json')){
           (Get-FileHash -LiteralPath (Join-Path $folder 'R106_NATIVE_WINDOWS.json') -Algorithm SHA256).Hash
       }else{''}
       EighthCaseNames=@('startup','hover','hardware','temperature','health','support','start','shell')
       Results=$results;CompletedCases=$results.Count;PassedCases=$passes
       FullInteractiveG14SignedAccepted=$false
       TrustedIndependentLabWitness='MISSING'
       SensorLayerStatus=[string]$state.SensorLayerStatus
       SystemRestarted=$false;DriverInstallPerformed=$false
       PersonalInstallTouched=$false;PersonalWallpaperTouched=$false
       Cleanup=$cleanup;Failure=$failure
       StartedUTC=$startUtc;FinishedUTC=(Get-Date).ToUniversalTime().ToString('o')
    }
    [IO.File]::WriteAllText($summaryPath,($summary|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
    Write-Output ('R103_G14_DIAGNOSTIC_RESULTS='+$summary.CompletedCases+' PASS='+$summary.PassedCases+
      ' STATUS='+$summary.Status+' SHA256='+(Get-FileHash -LiteralPath $summaryPath -Algorithm SHA256).Hash+
      ' FORMAL_G14=UNPROVEN')
}
if($summary.Status -cne 'EIGHT_RESULTS_CAPTURED_DIAGNOSTIC_ONLY'){
    throw ('R103 G14 EIGHT CASE DIAGNOSTIC NOT COMPLETE '+$summary.Failure+' CLEANUP='+$cleanup)
}
exit 0
