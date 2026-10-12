# R107 ONLY disposable hosted Windows: exact built private candidate Setup install
# + actual installed eight G14 diagnostic probes + exact cleanup. No public release.
# This cannot stand in for independent signed G14 acceptance and never touches user PC.
[CmdletBinding()]
param([switch]$StaticOnly)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$caseSpecs=@(
 [ordered]@{Name='startup';Switch='--startup-contract-selftest';Target='';Timeout=30000},
 [ordered]@{Name='hover';Switch='--hoverguardproof';Target='';Timeout=30000},
 [ordered]@{Name='hardware';Switch='--hardwareprobe';Target='hardware.json';Timeout=45000},
 [ordered]@{Name='temperature';Switch='--tempprobe';Target='temperature.json';Timeout=45000},
 [ordered]@{Name='health';Switch='--healthprobe';Target='health.json';Timeout=45000},
 [ordered]@{Name='support';Switch='--supportbundleproof';Target='support.zip';Timeout=45000},
 [ordered]@{Name='start';Switch='--startprobe';Target='start';Timeout=90000},
 [ordered]@{Name='shell';Switch='--shellstate';Target='shell.json';Timeout=45000}
)
if($StaticOnly){
  $tokens=$null;$errors=$null
  [void][Management.Automation.Language.Parser]::ParseFile($PSCommandPath,[ref]$tokens,[ref]$errors)
  if(@($errors).Count){throw 'R107 CANDIDATE HARNESS PARSER FAILURE'}
  if(@($caseSpecs).Count -ne 8 -or @($caseSpecs|ForEach-Object Name|Select-Object -Unique).Count -ne 8){
      throw 'R107 G14 CASE INVENTORY NOT 8 DISTINCT'
  }
  Write-Output 'R107_CANDIDATE_STATIC_EIGHT_CASES_AND_NO_PERSONAL_MUTATION_PASS'
  exit 0
}
if($env:GITHUB_ACTIONS -cne 'true' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
   $env:RUNNER_OS -cne 'Windows' -or [string]::IsNullOrEmpty($env:RUNNER_TEMP) -or
   $env:GITHUB_SHA -cnotmatch '^[0-9a-f]{40}$' -or $env:COMPUTERNAME -ceq 'EMAD-PC-ULTIMAT' -or
   ![Environment]::UserInteractive){throw 'R107 REFUSE NONDISPOSABLE HOST'}
$candidateLocalAppData=[Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
$app=Join-Path $candidateLocalAppData 'TaskbarMonitorEnhanced'
$reg='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TaskbarMonitorEnhanced'
$run='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$link=Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::Programs)) 'Taskbar Monitor Enhanced.lnk'
$desktop=Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory)) 'Taskbar Monitor Enhanced.lnk'
$out=Join-Path $env:RUNNER_TEMP 'TBME_R107_PRIVATE_CANDIDATE'
$setup=Join-Path $PSScriptRoot '_out\Setup\TaskbarMonitorEnhanced_Setup_1.7.0.exe'
$builtMain=Join-Path $PSScriptRoot '_out\App\TaskbarMonitorEnhanced.exe'
$builtConfig=Join-Path $PSScriptRoot '_out\App\TaskbarMonitorEnhanced.exe.config'
if((Test-Path -LiteralPath $out) -or (Test-Path -LiteralPath $app) -or
   (Test-Path -LiteralPath $reg) -or (Test-Path -LiteralPath $link) -or (Test-Path -LiteralPath $desktop) -or
   @(Get-Process -Name TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count -ne 0){
   throw 'R107 PRE-EXISTING INSTALL/DATA/PROCESS: REFUSE'
}
foreach($file in @($setup,$builtMain,$builtConfig)){
  if(!(Test-Path -LiteralPath $file -PathType Leaf)){throw ('R107 BUILT FILE MISSING '+$file)}
}
$mainSHA=(Get-FileHash -LiteralPath $builtMain -Algorithm SHA256).Hash
$configSHA=(Get-FileHash -LiteralPath $builtConfig -Algorithm SHA256).Hash
$setupSHA=(Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash
if((Get-AuthenticodeSignature -LiteralPath $setup).Status -ne 'NotSigned'){
    throw 'R107 CANDIDATE MUST NOT CLAIM TRUSTED SIGNED STABLE'
}
$initialRun=Get-ItemProperty -LiteralPath $run -Name 'TaskbarMonitorEnhanced' -ErrorAction SilentlyContinue
if($null -ne $initialRun){throw 'R107 STARTUP REG PREEXISTS'}
$wallKey=Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers' -ErrorAction SilentlyContinue
$wallMode=if($wallKey -and $null -ne $wallKey.PSObject.Properties['BackgroundType']){
 [string]$wallKey.BackgroundType
}else{'ABSENT'}
New-Item -ItemType Directory -Path $out -ErrorAction Stop|Out-Null
$receipt=Join-Path $out 'R107_PRIVATE_CANDIDATE_RECEIPT.json'
$testDir=Join-Path $out 'G14_8'
$start=(Get-Date).ToUniversalTime().ToString('o')
$installed=$false;$installedMain=''
$installCode=-999;$verifyCode=-999;$uninstallCode=-999
$results=@();$failure='';$cleanup='NOT_DONE';$residentProcessId=0;$resident=$null
$hardwareHealth='NOT_OBSERVED'
function Run-Bounded([string]$exe,[string[]]$childArgs,[int]$max,[string]$label){
   $info=[Diagnostics.ProcessStartInfo]::new()
   $info.FileName=$exe
   $info.UseShellExecute=$false
   $info.CreateNoWindow=$true
   $info.WorkingDirectory=Split-Path $exe -Parent
   $info.RedirectStandardOutput=$true
   $info.RedirectStandardError=$true
   foreach($arg in $childArgs){[void]$info.ArgumentList.Add([string]$arg)}
   $p=[Diagnostics.Process]::Start($info)
   if(!$p){throw ('R107 CHILD DID NOT START '+$label)}
   try{
      $stdoutTask=$p.StandardOutput.ReadToEndAsync()
      $stderrTask=$p.StandardError.ReadToEndAsync()
      if(!$p.WaitForExit($max)){
         try{$p.Kill();$p.WaitForExit(6000)|Out-Null}catch{}
         throw ('R107 CHILD TIMEOUT '+$label)
      }
      $stdout=$stdoutTask.GetAwaiter().GetResult()
      $stderr=$stderrTask.GetAwaiter().GetResult()
      $o=Join-Path $out ($label+'.out')
      $e=Join-Path $out ($label+'.err')
      [IO.File]::WriteAllText($o,[string]$stdout,[Text.UTF8Encoding]::new($false))
      [IO.File]::WriteAllText($e,[string]$stderr,[Text.UTF8Encoding]::new($false))
      return [ordered]@{
         Exit=[int]$p.ExitCode
         Stdout=$stdout;Stderr=$stderr
         StdoutSHA256=(Get-FileHash $o -Algorithm SHA256).Hash
         StderrSHA256=(Get-FileHash $e -Algorithm SHA256).Hash
      }
   }finally{$p.Dispose()}
}
try{
 $checkFile=Join-Path $out 'candidate-setup-verify.json'
 $x=Run-Bounded -exe $setup -childArgs @('/verify',('/verifyfile='+$checkFile)) -max 45000 -label 'setup-verify'
 $verifyCode=$x.Exit
 if($verifyCode -ne 0 -or !(Test-Path -LiteralPath $checkFile)){throw 'R107 SETUP VERIFY FAILED'}
 $check=Get-Content -LiteralPath $checkFile -Raw|ConvertFrom-Json
 if($check.Status -cne 'PASS' -or $check.EmbeddedMainSHA256 -cne $mainSHA -or
    $check.Resources -ne 25 -or $check.PawnIOBundled -ne $false){
    throw 'R107 SETUP EMBEDDED SOURCE/MAIN NOT MATCHING BUILT APP'
 }
 $x=Run-Bounded -exe $setup -childArgs @('/install','/quiet','/desktop=0','/startup=0') -max 210000 -label 'setup-install'
 $installCode=$x.Exit
 if($installCode -ne 0){throw ('R107 CANDIDATE INSTALL RETURNED '+$installCode)}
 $installedMain=Join-Path $app 'TaskbarMonitorEnhanced.exe'
 $installedConfig=Join-Path $app 'TaskbarMonitorEnhanced.exe.config'
 $state=Join-Path $app 'install_state.json'
 if(!(Test-Path -LiteralPath $installedMain) -or
    !(Test-Path -LiteralPath $installedConfig) -or !(Test-Path -LiteralPath $state)){
    throw 'R107 CANDIDATE INSTALLED FILE MISSING'
 }
 if((Get-FileHash -LiteralPath $installedMain -Algorithm SHA256).Hash -cne $mainSHA -or
    (Get-FileHash -LiteralPath $installedConfig -Algorithm SHA256).Hash -cne $configSHA){
    throw 'R107 INSTALLED BINARY OR CONFIG NOT EXACT'
 }
 $s=Get-Content -LiteralPath $state -Raw|ConvertFrom-Json
 if($s.Version -cne '1.7.0' -or $s.ProductIdentity -cne 'LOCKED' -or
    !(Test-Path $reg) -or !(Test-Path $link) -or (Test-Path $desktop) -or
    $null -ne (Get-ItemProperty -LiteralPath $run -Name 'TaskbarMonitorEnhanced' -ErrorAction SilentlyContinue)){
    throw 'R107 SINGLE CANONICAL INSTALL OR STARTUP PROTECTION FAIL'
 }
 $installed=$true
 $hardwareHealth=[string]$s.SensorLayerStatus
 if(@(Get-Process -Name TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count -gt 0){
    throw 'R107 UNEXPECTED SETUP AUTOSTART'
 }
 $session=(Get-Process -Id $PID).SessionId
 $explorers=@(Get-Process -Name explorer -ErrorAction SilentlyContinue|Where-Object {$_.SessionId -eq $session})
 if($session -lt 1 -or $explorers.Count -lt 1){throw 'R107 NOT REAL INTERACTIVE EXPLORER SESSION'}
 $psi=[Diagnostics.ProcessStartInfo]::new()
 $psi.FileName=$installedMain
 $psi.WorkingDirectory=$app
 $psi.UseShellExecute=$false
 $resident=[Diagnostics.Process]::Start($psi)
 if(!$resident){throw 'R107 MAIN RESIDENT NOT SPAWNED'}
 $residentProcessId=[int]$resident.Id
 Start-Sleep -Seconds 7
 $resident.Refresh()
 if($resident.HasExited){throw ('R107 INSTALLED REAL MAIN EXITED EARLY '+$resident.ExitCode)}
 if((Get-Process -Id $residentProcessId).SessionId -ne $session){throw 'R107 MAIN NOT SAME EXPLORER SESSION'}
 New-Item -ItemType Directory -Path $testDir -ErrorAction Stop|Out-Null
 foreach($spec in $caseSpecs){
   $target=if($spec.Target){Join-Path $testDir $spec.Target}else{''}
   $probeArgs=@([string]$spec.Switch)
   if($target){$probeArgs+= $target}
   $x=Run-Bounded -exe $installedMain -childArgs $probeArgs -max $spec.Timeout -label ('G14-'+$spec.Name)
   $pass=($x.Exit -eq 0 -and $x.Stdout.Contains('=PASS') -and
     !$x.Stderr.Contains('=FAIL') -and (!$target -or (Test-Path $target)))
   $results+= [ordered]@{
      Test=$spec.Name;ExitCode=$x.Exit;Status=if($pass){'PASS_DIAGNOSTIC'}else{'FAIL_DIAGNOSTIC'}
      StdoutSHA256=$x.StdoutSHA256;StderrSHA256=$x.StderrSHA256
      ErrorLine=if($x.Stderr){($x.Stderr -split '[\r\n]+' |Select-Object -First 1)}else{''}
   }
   Write-Output ('R107_INSTALLED_G14 '+$spec.Name+' '+$results[-1].Status+' EXIT='+$x.Exit)
   $resident.Refresh()
   if($resident.HasExited){throw 'R107 RESIDENT DIED WHILE DIAGNOSTIC RUNNING'}
 }
}catch{$failure=$_.Exception.ToString()}
finally{
 try{
    if($null -ne $resident){
       $resident.Refresh()
       if(!$resident.HasExited){
          if($resident.Id -ne $residentProcessId -or
             (Get-Process -Id $residentProcessId -ErrorAction SilentlyContinue).Path -cne $installedMain){
             throw 'R107 REFUSE KILL UNKNOWN PROCESS'
          }
          $resident.Kill()
          $resident.WaitForExit(7000)|Out-Null
       }
       $resident.Dispose()
    }
    if($installed){
       $uninstaller=Join-Path $app 'Uninstall.exe'
       if(!(Test-Path $uninstaller) -or
          (Get-FileHash -LiteralPath $uninstaller -Algorithm SHA256).Hash -cne $setupSHA){
           throw 'R107 EXACT OWNED UNINSTALLER HASH MISMATCH'
       }
       $x=Run-Bounded -exe $uninstaller -childArgs @('/uninstall','/quiet') -max 180000 -label 'setup-uninstall'
       $uninstallCode=$x.Exit
       if($uninstallCode -ne 0){throw ('R107 OWNED UNINSTALL FAILED '+$uninstallCode)}
       for($i=0;$i -lt 25 -and (Test-Path $app);$i++){Start-Sleep -Milliseconds 500}
    }
    if((Test-Path -LiteralPath $app) -or (Test-Path $reg) -or
       (Test-Path -LiteralPath $link) -or (Test-Path -LiteralPath $desktop) -or
       $null -ne (Get-ItemProperty -LiteralPath $run -Name 'TaskbarMonitorEnhanced' -ErrorAction SilentlyContinue)){
       throw 'R107 SETUP LEFT EXTRA INSTALL OR STARTUP REGISTRATION'
    }
    $modePost=Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers' -ErrorAction SilentlyContinue
    $wallAfter=if($modePost -and $null -ne $modePost.PSObject.Properties['BackgroundType']){
       [string]$modePost.BackgroundType
    }else{'ABSENT'}
    if($wallAfter -cne $wallMode){throw 'R107 WALLPAPER MODE WAS MUTATED'}
    $cleanup='PASS_EXACT_OWNED_DISPOSABLE_INSTALL_AND_UNINSTALL'
 }catch{
    $cleanup='FAIL_CLOSED_UNRESOLVED_CLEANUP'
    $failure+=(' ; '+$_.Exception.ToString())
 }
 $passed=@($results|Where-Object {$_.Status -ceq 'PASS_DIAGNOSTIC'}).Count
 $receiptData=[ordered]@{
    Schema=1;Revision='R107';EventCommit=$env:GITHUB_SHA
    HostRole='GITHUB_HOSTED_DISPOSABLE_WINDOWS'
    Status=if(!$failure -and $installed -and $verifyCode -eq 0 -and $installCode -eq 0 -and
       $uninstallCode -eq 0 -and $cleanup -ceq 'PASS_EXACT_OWNED_DISPOSABLE_INSTALL_AND_UNINSTALL' -and
       $results.Count -eq 8){'PASS_PRIVATE_CANDIDATE_INSTALLED_EIGHT_DIAGNOSTICS_CAPTURED'}else{'FAIL_CLOSED_CANDIDATE_INSTALL_OR_DIAGNOSTICS'}
    CandidateMainSHA256=$mainSHA;CandidateSetupSHA256=$setupSHA
    CandidateConfigSHA256=$configSHA;CandidateIsPublicRelease=$false
    CandidateAuthenticodeSigned=$false;CanonicalSingleRoot=$app
    MainProcessPid=$residentProcessId;InstalledSensorStatus=$hardwareHealth
    StartupRegistryInitiallyAbsent=($null -eq $initialRun);WallpaperModeBefore=$wallMode
    OwnedSetupVerifyExit=$verifyCode;OwnedSetupInstallExit=$installCode;OwnedSetupUninstallExit=$uninstallCode
    DiagnosticAttempts=$results.Count;DiagnosticPasses=$passed;DiagnosticResults=$results
    Cleanup=$cleanup;Failure=$failure;FormalG14Accepted=$false
    TrustedIndependentLabWitness='MISSING'
    PersonalInstallTouched=$false;PublicReleaseModified=$false;SystemRestarted=$false
    StartedUTC=$start;FinishedUTC=(Get-Date).ToUniversalTime().ToString('o')
 }
 [IO.File]::WriteAllText($receipt,($receiptData|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
 Write-Output ('R107_CANDIDATE_DIAGNOSTIC='+ $receiptData.DiagnosticPasses+'/'+$receiptData.DiagnosticAttempts+
   ' STATUS='+$receiptData.Status+' MAIN_SHA='+$mainSHA+' SETUP_SHA='+$setupSHA+
   ' RECEIPT_SHA='+(Get-FileHash -LiteralPath $receipt -Algorithm SHA256).Hash+
   ' FORMAL_G14=OPEN')
}
if($receiptData.Status -cne 'PASS_PRIVATE_CANDIDATE_INSTALLED_EIGHT_DIAGNOSTICS_CAPTURED'){
 throw ('R107 CANDIDATE INCOMPLETE '+$receiptData.Failure)
}
exit 0
