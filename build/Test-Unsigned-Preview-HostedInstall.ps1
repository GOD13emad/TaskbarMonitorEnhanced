# R88: exact IMMUTABLE PUBLIC UNSIGNED PREVIEW install/uninstall on EPHEMERAL GitHub-hosted Windows runner ONLY.
# This is a narrow, bounded headless smoke test, NOT G13 Wallpaper or G14 interactive 8/8 approval.
# Never execute on a personal machine, never disable security, reboot, or touch Windows Wallpaper.
[CmdletBinding()]
param([switch]$StaticOnly)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$Tag='v1.7.0-unsigned-preview.1'
$Source='eeac48c2ff201326c6a59e7ccc21c72c9a676160'
$Repo='GOD13emad/TaskbarMonitorEnhanced'
$ReleaseId=409785885
$SetupSHA='9A1B4F81C07CC39E3D5A329E89EFD834A9DFDC3D7BB6CF12812AC7C300E6B104'
$MainSHA='63A724981E949BA4C91F8BD44F2659F223BDFE0350A2E229CEE7B05535D4BA70'
$ConfigSHA='D2E51872D93F0793C02AD07DCBF8C2802F59708C666548372A4FDDDA5C7C5E4F'
$Asset='TaskbarMonitorEnhanced_Setup_1.7.0_UNSIGNED_PREVIEW.exe'
if($StaticOnly){
  $t=$null;$e=$null
  $ast=[Management.Automation.Language.Parser]::ParseFile($PSCommandPath,[ref]$t,[ref]$e)
  if($e.Count -ne 0){throw 'R88 SCRIPT PARSER'}
  $f=@($ast.FindAll({param($x) $x -is [Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -ceq 'Execute-Bounded'},$true))
  if($f.Count -ne 1){throw 'R88 BOUNDED PROCESS FUNCTION MISSING'}
  $names=@($f[0].Parameters | ForEach-Object {$_.Name.VariablePath.UserPath})
  if($names -contains 'Args' -or $names -notcontains 'ChildArguments'){
     throw 'R88 AUTOMATIC_ARGS_VARIABLE_COLLISION R88-F03'
  }
  # R88-F04: detect collisions with the release Tag string before CI touches a VM.
  $badTagAssignments=@($ast.FindAll({param($x)
     $x -is [Management.Automation.Language.AssignmentStatementAst] -and
     $x.Left.Extent.Text -ceq '$tag'
  },$true))
  if($badTagAssignments.Count -ne 0){throw 'R88 F04 AUTOMATIC-CASE-SHADOWED_TAG_VARIABLE'}
  # ArgumentList contract, no child process created; PowerShell 7.6.6/hosted runner safety.
  $probe=[Diagnostics.ProcessStartInfo]::new()
  foreach($argName in @('/verify','/verifyfile=C:\safe-test\receipt.json')){[void]$probe.ArgumentList.Add($argName)}
  if($probe.ArgumentList.Count -ne 2 -or $probe.ArgumentList[0] -cne '/verify' -or
     $probe.ArgumentList[1] -cne '/verifyfile=C:\safe-test\receipt.json'){throw 'R88 ARGUMENTLIST_STATIC_CONTRACT'}
  Write-Output 'R88_STATIC_PREFLIGHT_ARGUMENT_BINDING_PASS_NO_INSTALL'
  exit 0
}
if($env:GITHUB_ACTIONS -cne 'true' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
   $env:RUNNER_OS -cne 'Windows' -or $env:COMPUTERNAME -ceq 'EMAD-PC-ULTIMAT' -or
   [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)){throw 'R88 REFUSE: NOT DISPOSABLE GITHUB HOSTED WINDOWS'}
if(!(Get-Command gh -ErrorAction SilentlyContinue)){throw 'R88 GitHub CLI absent'}
$AppRoot=Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)) 'TaskbarMonitorEnhanced'
$UninstallReg='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TaskbarMonitorEnhanced'
$RunReg='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$RunName='TaskbarMonitorEnhanced'
$StartDir=[Environment]::GetFolderPath([Environment+SpecialFolder]::Programs)
$StartLink=Join-Path $StartDir 'Taskbar Monitor Enhanced.lnk'
$RepairLink=Join-Path $StartDir 'Taskbar Monitor Enhanced - Repair Hardware Sensors.lnk'
$DesktopLink=Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory)) 'Taskbar Monitor Enhanced.lnk'
$LaunchMode='UNKNOWN'
$InitialBg=Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers' -ErrorAction SilentlyContinue
$InitialType=if($InitialBg -and $InitialBg.PSObject.Properties.Name -contains 'BackgroundType'){[string]$InitialBg.BackgroundType}else{'ABSENT'}
$InitialExePaths=@($AppRoot,$StartLink,$RepairLink,$DesktopLink)
# R88-F01: strict PowerShell throws for an absent HKCU Run property on clean CI.
# Examine the existing property bag without requiring the value or creating it.
function Read-ExistingProductRunValue {
  $bag=Get-ItemProperty -Path $RunReg -ErrorAction SilentlyContinue
  if($null -eq $bag){return $null}
  $prop=$bag.PSObject.Properties[$RunName]
  if($null -eq $prop){return $null}
  return [string]$prop.Value
}
$Output=Join-Path $env:RUNNER_TEMP 'TBME_R88_UnsignedPreview_Smoke'
if(Test-Path -LiteralPath $Output){throw 'R88 OUTPUT ALREADY EXISTS/NO RERUN'}
New-Item -ItemType Directory -Path $Output -ErrorAction Stop|Out-Null
$Setup=Join-Path $Output $Asset
$SelfCheck=Join-Path $Output 'public-setup-verify.json'
$ReceiptFile=Join-Path $Output 'R88_HOSTED_INSTALL_RECEIPT.json'
$StartUtc=(Get-Date).ToUniversalTime().ToString('o')
$InstallStatus='NOT_RUN';$UninstallStatus='NOT_RUN'
$InstalledSHA='';$InstalledConfigSHA='';$SensorStatus='UNVERIFIED';$SensorMode='UNVERIFIED'
$ActualSource='';$Failure='';$InstallExit=-999;$UninstallExit=-999
$NativeFiveStatus='NOT_RUN';$NativeFiveCases=0;$NativeFiveSHA=''
$NativeFolder=Join-Path $Output 'R90_INSTALLED_NATIVE_5'
$GuiSessionPath=Join-Path $Output 'R90_GUI_SESSION_READINESS.json'
function Execute-Bounded([string]$File,[string[]]$ChildArguments,[int]$TimeoutMs){
  # R88-F03 root cause: '$Args' is PowerShell's automatic unbound-arguments variable.
  # Never reuse it as the parameter name: the old function launched GUI with zero args.
  if($null -eq $ChildArguments -or $ChildArguments.Count -lt 1){throw 'R88 F03 REFUSE GUI EXECUTION WITH ZERO ARGUMENTS'}
  $p=$null
  try{
    $psi=[Diagnostics.ProcessStartInfo]::new()
    $psi.FileName=$File
    $psi.UseShellExecute=$false
    $psi.CreateNoWindow=$true
    foreach($argument in $ChildArguments){[void]$psi.ArgumentList.Add($argument)}
    if($psi.ArgumentList.Count -ne $ChildArguments.Count){throw 'R88 F03 CHILD ARGS NOT FORWARDED'}
    $p=[Diagnostics.Process]::Start($psi)
    if($null -eq $p){throw 'CHILD PROCESS DID NOT START'}
    if(!$p.WaitForExit($TimeoutMs)){
        try{$p.Kill()}catch{}
        throw ('R88 BOUNDED CHILD TIMEOUT '+$File+' LIMIT_MS='+$TimeoutMs)
    }
    return [int]$p.ExitCode
  }finally{if($p){$p.Dispose()}}
}
try{
  # Failures in this clean-host guard are recorded in the CI artifact receipt.
  if(@($InitialExePaths | Where-Object {Test-Path -LiteralPath $_}).Count -gt 0 -or
     (Test-Path $UninstallReg) -or
     $null -ne (Read-ExistingProductRunValue) -or
     @(Get-Process -Name TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count -gt 0){
     throw 'R88 REFUSE: EPHEMERAL RUNNER NOT CLEAN BEFORE TEST'
  }
  $r=(& gh api ('repos/'+$Repo+'/releases/'+$ReleaseId) | Out-String | ConvertFrom-Json)
  if($LASTEXITCODE -ne 0 -or $r.id -ne $ReleaseId -or $r.tag_name -cne $Tag -or
     $r.target_commitish -cne $Source -or $r.draft -ne $false -or
     $r.prerelease -ne $true -or $r.immutable -ne $true){throw 'R88 IMMUTABLE RELEASE CONTRACT'}
  # R88-F04: PowerShell variable names are case-insensitive; '$tag' overwrote '$Tag'
  # (string) with a JSON object, corrupting PublicTag in an otherwise accepted receipt.
  $tagReference=( & gh api ('repos/'+$Repo+'/git/ref/tags/'+$Tag) | Out-String | ConvertFrom-Json)
  if($LASTEXITCODE -ne 0 -or $tagReference.object.sha -cne $Source -or $tagReference.object.type -cne 'commit'){throw 'R88 TAG SHA DRIFT'}
  $actualSource=$tagReference.object.sha
  if($Tag -isnot [string] -or $Tag -cne 'v1.7.0-unsigned-preview.1'){throw 'R88 F04 TAG VARIABLE TYPE OR VALUE CORRUPTED'}
  $assetRows=@($r.assets|Where-Object {$_.name -ceq $Asset})
  if($assetRows.Count -ne 1 -or $assetRows[0].digest -cne ('sha256:'+$SetupSHA.ToLowerInvariant()) -or
     $assetRows[0].state -cne 'uploaded'){throw 'R88 RELEASE ASSET NOT EXACT'}
  # R88-F02: GH CLI tag lookup returned "release not found" on a hosted runner despite
  # successful GET-by-release-ID and correct digest. Fetch exactly the pinned public
  # asset browser URL over HTTPS and verify bytes *before* executing any child process.
  $expectedURL='https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/download/v1.7.0-unsigned-preview.1/TaskbarMonitorEnhanced_Setup_1.7.0_UNSIGNED_PREVIEW.exe'
  $downloadURL=[string]$assetRows[0].browser_download_url
  if($downloadURL -cne $expectedURL){throw 'R88 PUBLIC ASSET URI SOURCE NOT EXACT'}
  Invoke-WebRequest -Uri $downloadURL -OutFile $Setup -MaximumRedirection 5 -TimeoutSec 120 -ErrorAction Stop
  if(!(Test-Path -LiteralPath $Setup -PathType Leaf)){throw 'R88 PUBLIC DIRECT HTTPS DOWNLOAD FAILED'}
  if((Get-FileHash $Setup).Hash -cne $SetupSHA -or (Get-AuthenticodeSignature $Setup).Status -ne 'NotSigned'){throw 'R88 DOWNLOADED SETUP NOT EXACT UNSIGNED'}
  $VerifyExit=Execute-Bounded $Setup @('/verify',('/verifyfile='+$SelfCheck)) 30000
  if($VerifyExit -ne 0 -or !(Test-Path $SelfCheck -PathType Leaf)){throw 'R88 PUBLIC SETUP SELFTEST FAILED'}
  $self=Get-Content $SelfCheck -Raw|ConvertFrom-Json
  if($self.Status -cne 'PASS' -or $self.Resources -ne 25 -or $self.PawnIOBundled -ne $false -or
     $self.EmbeddedMainSHA256 -cne $MainSHA){throw 'R88 UNSIGNED MAIN RESOURCE CONTRACT'}
  # This modifies only the disposable GitHub-hosted Windows VM. Disable Desktop and Startup.
  $InstallExit=Execute-Bounded $Setup @('/install','/quiet','/desktop=0','/startup=0') 210000
  if($InstallExit -ne 0){throw ('R88 PUBLIC SETUP QUIET INSTALL RETURNED '+$InstallExit)}
  $InstallStatus='PROCESS_EXIT_ZERO'
  $main=Join-Path $AppRoot 'TaskbarMonitorEnhanced.exe'
  $config=Join-Path $AppRoot 'TaskbarMonitorEnhanced.exe.config'
  $state=Join-Path $AppRoot 'install_state.json'
  if(!(Test-Path -LiteralPath $main -PathType Leaf) -or !(Test-Path -LiteralPath $config -PathType Leaf) -or
     !(Test-Path -LiteralPath $state -PathType Leaf)){throw 'R88 REAL INSTALLED APP/CONFIG/STATE NOT FOUND'}
  $InstalledSHA=(Get-FileHash $main).Hash
  $InstalledConfigSHA=(Get-FileHash $config).Hash
  if($InstalledSHA -cne $MainSHA -or $InstalledConfigSHA -cne $ConfigSHA){throw 'R88 INSTALLED MAIN/CONFIG SHA WRONG'}
  $installState=Get-Content $state -Raw|ConvertFrom-Json
  if($installState.Version -cne '1.7.0' -or $installState.ProductIdentity -cne 'LOCKED'){throw 'R88 REAL INSTALL STATE UNKNOWN'}
  $SensorStatus=[string]$installState.SensorLayerStatus
  $SensorMode=[string]$installState.SensorLayerMode
  $LaunchMode=[string]$installState.MainLaunchMode
  if([string]::IsNullOrWhiteSpace($SensorStatus)){throw 'R88 SENSOR STATE NOT DECLARED'}
  if(!(Test-Path $UninstallReg) -or !(Test-Path $StartLink)){throw 'R88 INSTALLED UNINSTALL OR START MENU LINK MISSING'}
  if(Test-Path -LiteralPath $DesktopLink){throw 'R88 DESKTOP=0 NOT HONORED'}
  if($null -ne (Read-ExistingProductRunValue)){throw 'R88 STARTUP=0 NOT HONORED'}
  $InstallStatus='PASS_HEADLESS_INSTALLED_EXACT_SHA_STATE_AND_SHORTCUT'
  # R90: run native portable cases from the genuine installed Main, not build/_out.
  # Do not equate these five automated cases with full interactive G14 8/8.
  $nativeHarness=Join-Path $PSScriptRoot 'Test-Runtime.ps1'
  if(!(Test-Path -LiteralPath $nativeHarness -PathType Leaf) -or (Test-Path -LiteralPath $NativeFolder)){
     throw 'R90 NATIVE HARNESS MISSING OR EVIDENCE PATH ALREADY EXISTS'
  }
  $nativeExit=Execute-Bounded 'pwsh.exe' @(
    '-NoProfile','-NonInteractive','-File',$nativeHarness,
    '-Executable',$main,'-OutputDirectory',$NativeFolder,'-CiContract'
  ) 300000
  if($nativeExit -ne 0){throw ('R90 INSTALLED NATIVE FIVE EXIT='+$nativeExit)}
  $summaryPath=Join-Path $NativeFolder 'SUMMARY.json'
  if(!(Test-Path -LiteralPath $summaryPath -PathType Leaf)){throw 'R90 NATIVE SUMMARY MISSING'}
  $native=Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
  $expectedNativeNames=@('startup','hover','hardware','temperature','support')
  $namesNative=@($native.Results|ForEach-Object {[string]$_.Test})
  if($native.Status -cne 'PASS' -or $native.Mode -cne 'CI_PORTABLE_5' -or
     $native.ExecutableSHA256 -cne $MainSHA -or
     @($native.Results).Count -ne 5 -or
     @($namesNative | Where-Object {$_ -notin $expectedNativeNames}).Count -ne 0 -or
     @($namesNative|Select-Object -Unique).Count -ne 5){
     throw 'R90 INSTALLED NATIVE SUITE CONTRACT INVALID'
  }
  foreach($case in $native.Results){
    if($case.Status -cne 'PASS' -or $case.ExitCode -ne 0){throw ('R90 INSTALLED NATIVE CASE FAILED '+$case.Test)}
    foreach($kind in @('out','err')){
      $name=Join-Path $NativeFolder ($case.Test+'.'+$kind)
      if(!(Test-Path -LiteralPath $name -PathType Leaf)){throw ('R90 NATIVE CASE RAW MISSING '+$case.Test+'/'+$kind)}
      $expectedHash=if($kind -ceq 'out'){$case.StdoutSHA256}else{$case.StderrSHA256}
      if((Get-FileHash -LiteralPath $name).Hash -cne [string]$expectedHash){throw ('R90 CASE OUTPUT HASH '+$case.Test+'/'+$kind)}
    }
  }
  $NativeFiveCases=5
  $NativeFiveSHA=(Get-FileHash -LiteralPath $summaryPath).Hash
  $NativeFiveStatus='PASS_INSTALLED_MAIN_NATIVE_PORTABLE_FIVE'
  # Read-only desktop capability record. No wallpaper changes, and no false G13 claim.
  $r90HostSession=(Get-Process -Id $PID).SessionId
  $r90ShellPeers=@(Get-Process explorer -ErrorAction SilentlyContinue|Where-Object {$_.SessionId -eq $r90HostSession})
  $r90GuiReadiness=[ordered]@{
     Schema=1;Revision='R90';HostRole='GITHUB_HOSTED_EPHEMERAL_WINDOWS'
     EventCommit=$env:GITHUB_SHA;ObservedUtc=(Get-Date).ToUniversalTime().ToString('o')
     RunnerSessionId=$r90HostSession;UserInteractive=[Environment]::UserInteractive
     ExplorerInSameSessionCount=$r90ShellPeers.Count
     WallpaperBackgroundTypeBefore=$InitialType
     ProductWallpaperApplyInvoked=$false;WallpaperMutation=$false
     ApprovedForG13Positive=$false
     G13ReadinessVerdict='READ_ONLY_PROBE_NOT_G13_POSITIVE_ACCEPTANCE'
  }
  $r90GuiReadiness|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $GuiSessionPath -Encoding utf8
  if((Get-FileHash -LiteralPath $main).Hash -cne $MainSHA){throw 'R90 INSTALLED MAIN MUTATED DURING PORTABLE RUNTIME SUITE'}
  # Prepare clean unload of launched main before invoking public Setup uninstaller.
  Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue | ForEach-Object {
    try{$_.Kill()}catch{}
  }
  $UninstallExe=Join-Path $AppRoot 'Uninstall.exe'
  if(!(Test-Path -LiteralPath $UninstallExe -PathType Leaf) -or
     (Get-FileHash $UninstallExe).Hash -cne $SetupSHA){throw 'R88 EXACT UNINSTALLER SHA MISMATCH'}
  $UninstallExit=Execute-Bounded $UninstallExe @('/uninstall','/quiet') 180000
  if($UninstallExit -ne 0){throw ('R88 PUBLIC QUIET UNINSTALL FAILED CODE '+$UninstallExit)}
  $UninstallStatus='PROCESS_EXIT_ZERO'
  for($i=0;$i -lt 25 -and (Test-Path -LiteralPath $AppRoot);$i++){Start-Sleep -Milliseconds 500}
  if((Test-Path $UninstallReg) -or (Test-Path $AppRoot) -or
     (Test-Path -LiteralPath $StartLink) -or (Test-Path -LiteralPath $RepairLink) -or
     (Test-Path -LiteralPath $DesktopLink) -or
     $null -ne (Read-ExistingProductRunValue)){
     throw 'R88 QUIET UNINSTALL LEFT PRODUCT REGISTRATION/FILES'
  }
  $UninstallStatus='PASS_HEADLESS_UNINSTALL_PRODUCT_STATE_REMOVED'
  $bg=Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers' -ErrorAction SilentlyContinue
  $afterbg=if($bg -and $bg.PSObject.Properties.Name -contains 'BackgroundType'){[string]$bg.BackgroundType}else{'ABSENT'}
  if($afterbg -cne $InitialType){throw 'R88 UNEXPECTED WALLPAPER REGISTRY MUTATION'}
} catch {
  $Failure=$_.Exception.Message
} finally {
  # Evidence-only; the VM is ephemeral and cannot be confused with any personal host.
  $receipt=[ordered]@{
    Schema=1;Revision='R88'
    Status=if(!$Failure -and $InstallStatus -like 'PASS*' -and $UninstallStatus -like 'PASS*'){'PASS_EPHEMERAL_HEADLESS_INSTALL_UNINSTALL'}else{'FAIL_CLOSED_EPHEMERAL_INSTALL_CHECK'}
    HostRole='GITHUB_HOSTED_EPHEMERAL_WINDOWS';EventCommit=$env:GITHUB_SHA
    PublicTag=$Tag;ReleaseId=$ReleaseId;ReleasedSource=$Source;ActualTagSource=$ActualSource
    PublishedSetupSHA256=$SetupSHA;InstalledMainSHA256=$InstalledSHA
    InstalledConfigSHA256=$InstalledConfigSHA;SignatureStatus='NotSigned'
    InstallExitCode=$InstallExit;InstallStatus=$InstallStatus
    UninstallExitCode=$UninstallExit;UninstallStatus=$UninstallStatus
    SensorStatus=$SensorStatus;SensorLayerMode=$SensorMode;MainLaunchMode=$LaunchMode
    InstalledNativeFiveStatus=$NativeFiveStatus
    InstalledNativeFiveCases=$NativeFiveCases
    InstalledNativeFiveSummarySHA256=$NativeFiveSHA
    GuiSessionCapabilityReport=if(Test-Path -LiteralPath $GuiSessionPath){'R90_GUI_SESSION_READINESS.json'}else{''}
    WallpaperBefore=$InitialType;RealInteractiveG13='NOT_TESTED'
    RealInteractiveG14EightProbes='NOT_TESTED'
    FullSignedStableAccepted=$false;HeadlessSubsetOnly=$true
    StartedUTC=$StartUtc;FinishedUTC=(Get-Date).ToUniversalTime().ToString('o')
    Failure=$Failure
  }
  $receipt|ConvertTo-Json -Depth 7|Set-Content -LiteralPath $ReceiptFile -Encoding utf8
  Write-Output ('R88_SMOKE_RECEIPT='+$ReceiptFile)
  Write-Output ('R88_SMOKE_STATUS='+$receipt.Status+' SENSOR='+$SensorStatus+' INSTALL='+$InstallStatus+' UNINSTALL='+$UninstallStatus)
}
if($Failure){throw ('R88 SMOKE FAILED: '+$Failure)}
Write-Output 'R88_GITHUB_HOSTED_UNSIGNED_PREVIEW_HEADLESS_INSTALL_AND_UNINSTALL_PASS'
exit 0
