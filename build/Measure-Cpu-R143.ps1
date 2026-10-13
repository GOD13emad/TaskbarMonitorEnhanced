# R143: ONE objective — gather sampled CPU stack evidence from exact official
# v1.7.1 binary on disposable GitHub Windows, never mutate personal PC.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][ValidateSet('glass31','glass0','opaque100')][string]$Mode)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($env:GITHUB_ACTIONS -cne 'true' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
   $env:RUNNER_OS -cne 'Windows' -or $env:COMPUTERNAME -match 'EMAD-PC' -or
   $env:GITHUB_SHA -cnotmatch '^[a-f0-9]{40}$' -or ![Environment]::UserInteractive){
 throw 'R143_REFUSED_NON_DISPOSABLE_OR_NON_INTERACTIVE_HOST'
}
$mainSHA='D50A9D03190719B8385AB2F7F7DBB3129EC7EC1C77ECBD8EF7F29832AEC26420'
$setupSHA='ABD106630F7BAB3471CAF3F5BD4313DFCF2D61DDE1DF79E72EFE91933C8F2F89'
$app=Join-Path $env:LOCALAPPDATA 'TaskbarMonitorEnhanced'
$reg='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TaskbarMonitorEnhanced'
$dir=Join-Path $env:RUNNER_TEMP ('TBME_R143_CPU_'+$Mode)
if((Test-Path $dir) -or (Test-Path $app) -or (Test-Path $reg) -or
  @(Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count -gt 0){
 throw 'R143_FRESH_HOST_OR_OUTPUT_PRESTATE_FAILED'
}
New-Item -ItemType Directory -Path $dir -ErrorAction Stop|Out-Null
$receipt=Join-Path $dir 'R143_CPU.json'
$trace=Join-Path $dir ('R143_CPU_'+$Mode+'.etl')
$phase='PRECHECK';$status='FAIL';$errorText='';$proc=$null;$traceStarted=$false
$wprSession='TBME_R143_CPU_'+$Mode
$cpu=0;$kernel=0;$user=0;$mainTid=0;$elapsed=0
$traceSha='';$traceSize=0;$startWpr='';$stopWpr=''
$modeMeta=([ordered]@{
 glass31=@{GlassMode=$false;Opacity=0.31}
 glass0=@{GlassMode=$true;Opacity=0.0}
 opaque100=@{GlassMode=$false;Opacity=1.0}
})[$Mode]
try{
 $phase='OFFICIAL_IMMUTABLE_SETUP_SOURCE'
 if(!(Get-Command gh -ErrorAction SilentlyContinue)){throw 'R143_GH_CLI_UNAVAILABLE'}
 $setup=Join-Path $dir 'TaskbarMonitorEnhanced_Setup_1.7.1.exe'
 & gh release download v1.7.1 --repo GOD13emad/TaskbarMonitorEnhanced --pattern 'TaskbarMonitorEnhanced_Setup_1.7.1.exe' --dir $dir
 if($LASTEXITCODE -ne 0 -or !(Test-Path $setup -PathType Leaf) -or
   (Get-FileHash $setup -Algorithm SHA256).Hash -cne $setupSHA){throw 'R143_NOT_OFFICIAL_RELEASE_SETUP_BYTES'}
 $phase='INSTALL_ONLY_DISPOSABLE_WINDOWS'
 # R144 FIRST CAUSE: GUI-subsystem Setup launched via & returned to pwsh
 # before installer completion; LASTEXITCODE carried previous gh=0.
 # Historical R126 native test already uses Process.WaitForExit.
 # Wait for EXACT launched Setup PID (not descendants) with a 190s cap;
 # only then validate actual root, state, registry and immutable Main SHA.
 $setupProcess=Start-Process -FilePath $setup -ArgumentList @(
  '/install','/quiet','/desktop=0','/startup=0') -PassThru -ErrorAction Stop
 if($null -eq $setupProcess -or $setupProcess.Id -le 0){throw 'R144_GUI_SETUP_PROCESS_NOT_OBSERVED'}
 if(!$setupProcess.WaitForExit(190000)){throw ('R144_GUI_SETUP_EXIT_TIMEOUT PID='+$setupProcess.Id)}
 $setupProcess.Refresh()
 if($setupProcess.ExitCode -ne 0){
  throw ('R144_OFFICIAL_SETUP_PROCESS_EXIT_NONZERO CODE='+$setupProcess.ExitCode+
   ' PID='+$setupProcess.Id)
 }
 Write-Output ('R144_GUI_SETUP_BOUND_TO_EXIT PID='+$setupProcess.Id+' CODE='+$setupProcess.ExitCode)
 $exe=Join-Path $app 'TaskbarMonitorEnhanced.exe'
 $state=Join-Path $app 'install_state.json'
 $config=Join-Path $app 'config.json'
 # Second identical hosted failure: diagnose before any more fixture changes.
 # Display exact state identity, even when it is absent; never guess another root.
 $existsMain=Test-Path -LiteralPath $exe -PathType Leaf
 $existsState=Test-Path -LiteralPath $state -PathType Leaf
 $installedSHA=if($existsMain){(Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash}else{'MISSING'}
 $knownRoot=[IO.Path]::Combine(
   [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData),
   'TaskbarMonitorEnhanced')
 $installedRegistry=Get-ItemProperty $reg -ErrorAction SilentlyContinue
 $regVersion=if($null -ne $installedRegistry){[string]$installedRegistry.DisplayVersion}else{'MISSING'}
 $regRoot=if($null -ne $installedRegistry){[string]$installedRegistry.InstallLocation}else{'MISSING'}
 Write-Output ('R143_HOST_INSTALL_FORENSICS MAIN_EXISTS='+$existsMain+
   ' MAIN_SHA='+$installedSHA+' STATE_EXISTS='+$existsState+
   ' SCRIPT_ROOT='+$app+' SETUP_SPECIAL_FOLDER_ROOT='+$knownRoot+
   ' REG_VERSION='+$regVersion+
   ' REG_INSTALL_PATH='+$regRoot+
   ' MAIN_SIZE='+$(if($existsMain){(Get-Item $exe).Length}else{0}))
 if(!$existsMain -or !$existsState -or $installedSHA -cne $mainSHA){
   throw ('R143_HOSTED_INSTALL_UNRECOGNIZED_MAIN_OR_STATE MAIN_EXISTS='+$existsMain+
    ' MAIN_SHA='+$installedSHA+' STATE_EXISTS='+$existsState+
    ' REG_VERSION='+$regVersion+
    ' ROOTS_EQUAL='+($knownRoot -ceq $app))
 }
 $s=Get-Content $state -Raw|ConvertFrom-Json
 if($s.Version -cne '1.7.1' -or $s.ProductIdentity -cne 'LOCKED'){throw 'R143_WRONG_INSTALLED_VERSION'}
 # Fresh official Setup intentionally does not create config until Main starts.
 # The hosted stable in-place contract creates an owner fixture after Setup.
 # On THIS disposable Windows only, create the exact same minimal settings.
 $resident=@(Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue)
 if($resident.Count -ne 0){throw 'R143_INSTALLER_AUTOLAUNCHED_UNEXPECTED_RUNTIME'}
 if(!(Test-Path $config -PathType Leaf)){
  $initial='{"Theme":"Retro Terminal","Opacity":0.31,"GlassMode":false,"OpacityWhenGlassOff":0.31,"ConfigSchemaVersion":8,"StartWithWindows":false,"UpdateIntervalMs":1000,"ShowSparklines":true}'
  [IO.File]::WriteAllText($config,$initial,[Text.UTF8Encoding]::new($false))
 }
 $phase='KNOWN_FIXTURE_ONLY_DISPOSABLE'
 $cfg=Get-Content $config -Raw|ConvertFrom-Json
 $cfg.Theme='Retro Terminal'
 $cfg.GlassMode=[bool]$modeMeta.GlassMode
 $cfg.Opacity=[double]$modeMeta.Opacity
 $cfg.OpacityWhenGlassOff=0.31
 $cfg.ConfigSchemaVersion=8
 $cfg.UpdateIntervalMs=1000
 $cfg.StartWithWindows=$false
 $cfg.ShowSparklines=$true
 $cfg|ConvertTo-Json -Depth 40|Set-Content -LiteralPath $config -Encoding utf8
 $fixtureSha=(Get-FileHash $config -Algorithm SHA256).Hash
 $phase='RUN_EXACT_PUBLIC_MAIN'
 $proc=Start-Process -FilePath $exe -WorkingDirectory $app -PassThru
 Start-Sleep -Seconds 6
 $processes=@(Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue)
 if($processes.Count -ne 1 -or $processes[0].Id -ne $proc.Id -or $proc.HasExited){
  throw 'R143_REAL_APPLICATION_DID_NOT_RUN'
 }
 $proc=$processes[0]
 $threads=@($proc.Threads|Sort-Object StartTime)
 if($threads.Count -lt 1){throw 'R143_NO_PROCESS_THREADS'}
 $mainTid=[int]$threads[0].Id
 $t=$threads[0]
 $priorKernel=$t.PrivilegedProcessorTime.TotalSeconds
 $priorUser=$t.UserProcessorTime.TotalSeconds
 $priorCpu=$proc.CPU
 $watch=[Diagnostics.Stopwatch]::StartNew()
 $phase='NATIVE_SAMPLED_CPU_WPR'
 $wprStatus=(& wpr -status 2>&1|Out-String)
 if($LASTEXITCODE -ne 0 -or $wprStatus -notmatch 'WPR is not recording'){
  throw 'R143_UNKNOWN_ETW_TRACE_ALREADY_RUNNING'
 }
 $startWpr=(& wpr -start CPU -instancename $wprSession 2>&1|Out-String)
 if($LASTEXITCODE -ne 0){throw ('R143_WPR_NOT_AUTHORIZED_OR_NOT_AVAILABLE '+$startWpr.Trim())}
 $traceStarted=$true
 Start-Sleep -Seconds 6
 $stopWpr=(& wpr -stop $trace -instancename $wprSession 2>&1|Out-String)
 if($LASTEXITCODE -ne 0){throw ('R143_STOP_ETW_TRACE_FAILED '+$stopWpr.Trim())}
 $traceStarted=$false
 $watch.Stop()
 $elapsed=[Math]::Round($watch.Elapsed.TotalSeconds,3)
 $proc.Refresh()
 $target=@($proc.Threads|Where-Object Id -eq $mainTid)
 if($target.Count -ne 1){throw 'R143_HOT_THREAD_DISAPPEARED'}
 $cpu=[Math]::Round($proc.CPU-$priorCpu,3)
 $kernel=[Math]::Round($target[0].PrivilegedProcessorTime.TotalSeconds-$priorKernel,3)
 $user=[Math]::Round($target[0].UserProcessorTime.TotalSeconds-$priorUser,3)
 if(!(Test-Path $trace -PathType Leaf) -or (Get-Item $trace).Length -lt 16384){throw 'R143_ETL_TRACE_TOO_SMALL'}
 $traceSha=(Get-FileHash $trace -Algorithm SHA256).Hash
 $traceSize=(Get-Item $trace).Length
 $phase='CAPTURED_NATIVE_CPU_STACK_ETL'
 $status='PASS_TRACE_CAPTURE_NOT_PRODUCT_PERFORMANCE_ACCEPTANCE'
} catch{
 $errorText=$_.Exception.ToString().Substring(0,[Math]::Min(2800,$_.Exception.ToString().Length))
} finally {
 if($traceStarted){
  $rescue=(& wpr -stop $trace -instancename $wprSession 2>&1|Out-String)
  if($LASTEXITCODE -eq 0){$traceStarted=$false}
  else{$errorText+=' R143_WPR_SESSION_UNRESOLVED='+$rescue}
 }
 if($null -ne $proc){
  try{
   if(!$proc.HasExited){Stop-Process -Id $proc.Id -Force -ErrorAction Stop}
  }catch{$errorText+=' R143_DISPOSABLE_PROCESS_CLEANUP='+$_.Exception.Message}
 }
 $report=[ordered]@{
  Revision='R143';Objective='Independently sample exact official v1.7.1 product CPU stack on disposable Windows'
  SourceCommit=$env:GITHUB_SHA;Host='GITHUB_HOSTED_DISPOSABLE_WINDOWS';Mode=$Mode
  Phase=$phase;Status=$status;Error=$errorText;OfficialSetupSHA256=$setupSHA
  OfficialMainSHA256=$mainSHA;ProductPid=if($null -eq $proc){0}else{$proc.Id}
  InitialThreadId=$mainTid;WallTraceSeconds=$elapsed;AppTotalCpuSeconds=$cpu
  MainThreadKernelCpuSeconds=$kernel;MainThreadUserCpuSeconds=$user
  TraceSha256=$traceSha;TraceBytes=$traceSize
  EtwSessionClosed=(-not $traceStarted);PersonalPcTouched=$false
  PerformancePassClaimed=$false;ExternalPhysicalLabAccepted=$false
 }
 [IO.File]::WriteAllText($receipt,($report|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
 Write-Output ('R143_DISPOSABLE_CPU_TRACE='+$status+' MODE='+$Mode+
  ' KERNEL='+$kernel+' USER='+$user+' CPU='+$cpu+
  ' ETL='+$traceSha+' RECEIPT_SHA='+ (Get-FileHash $receipt -Algorithm SHA256).Hash)
}
if($status -cne 'PASS_TRACE_CAPTURE_NOT_PRODUCT_PERFORMANCE_ACCEPTANCE' -or $traceStarted){
 throw ('R143_HOSTED_CPU_TRACE_FAIL_CLOSED '+$errorText)
}
