[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateSet('A','B')][string]$HostLabel,
    [Parameter(Mandatory=$true)][string]$CandidateDir,
    [ValidateRange(2,5)][int]$Iterations=3
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$sourceRoot=(Resolve-Path -LiteralPath '.').Path
$CandidateDir=(Resolve-Path -LiteralPath $CandidateDir).Path
if($env:GITHUB_ACTIONS -cne 'true' -or
   $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
   $env:RUNNER_OS -cne 'Windows' -or
   $env:GITHUB_REPOSITORY -cne 'GOD13emad/TaskbarMonitorEnhanced' -or
   $env:GITHUB_REF -cne 'refs/heads/security/r347-r349-helper-hardening-v1710' -or
   $env:COMPUTERNAME -match '(?i)EMAD-PC|ALIEMAD|SAEID|LAPTOP' -or
   ![Environment]::UserInteractive -or
   (git -C $sourceRoot rev-parse HEAD).Trim() -cne $env:GITHUB_SHA){
    throw 'R360_REFUSE_NONDISPOSABLE_OR_WRONG_GIT_SOURCE'
}
$native=Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe'
$test=Join-Path $sourceRoot 'build\Test-R291-ExplorerStart-Settings-Glass.ps1'
$manifestPath=Join-Path $CandidateDir 'CANDIDATE.json'
$setup=Join-Path $CandidateDir 'Setup\TaskbarMonitorEnhanced_Setup_1.7.10.exe'
$main=Join-Path $CandidateDir 'App\TaskbarMonitorEnhanced.exe'
if(!(Test-Path -LiteralPath $native) -or
   !(Test-Path -LiteralPath $test) -or
   !(Test-Path -LiteralPath $manifestPath) -or
   !(Test-Path -LiteralPath $setup) -or
   !(Test-Path -LiteralPath $main)){
    throw 'R360_EXACT_NATIVE_HOST_TEST_OR_CANDIDATE_MISSING'
}
$manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
$setupHash=(Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash.ToUpperInvariant()
$mainHash=(Get-FileHash -LiteralPath $main -Algorithm SHA256).Hash.ToUpperInvariant()
if($manifest.Commit -cne $env:GITHUB_SHA -or
   $manifest.Version -cne '1.7.10' -or
   $manifest.Private -ne $true -or
   $manifest.NotForPublicInstallation -ne $true -or
   $manifest.SetupSHA256 -cne $setupHash -or
   $manifest.MainSHA256 -cne $mainHash){
    throw 'R360_CANDIDATE_COMMIT_OR_HASH_MISMATCH'
}
$appRoot=Join-Path $env:LOCALAPPDATA 'TaskbarMonitorEnhanced'
$uninstallKey='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TaskbarMonitorEnhanced'
if((Test-Path -LiteralPath $appRoot) -or
   (Test-Path -LiteralPath $uninstallKey) -or
   @(Get-Process -Name TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count -ne 0){
    throw 'R360_FRESH_HOST_PRECONDITION_FAILED'
}
$originalRunnerTemp=$env:RUNNER_TEMP
if([string]::IsNullOrWhiteSpace($originalRunnerTemp) -or !(Test-Path -LiteralPath $originalRunnerTemp)){
    throw 'R360_RUNNER_TEMP_INVALID'
}
$outRoot=Join-Path $originalRunnerTemp ('R360_'+$HostLabel)
if(Test-Path -LiteralPath $outRoot){throw 'R360_OUTPUT_COLLISION'}
[void][IO.Directory]::CreateDirectory($outRoot)
$results=[Collections.Generic.List[object]]::new()
$installAttempted=$false
$blockedAfter=$null
$fatal=''
try{
    for($iteration=1;$iteration -le $Iterations;$iteration++){
        $cycleRoot=Join-Path $outRoot ('Cycle'+$iteration)
        [void][IO.Directory]::CreateDirectory($cycleRoot)
        $env:RUNNER_TEMP=$cycleRoot
        $exitCode=900
        $launchFailure=''
        try{
            if($iteration -eq 1){$installAttempted=$true}
            $nativeArgs=@('-NoLogo','-NoProfile','-NonInteractive','-STA','-ExecutionPolicy','Bypass',
                '-File',$test,'-HostLabel',$HostLabel,'-CandidateDir',$CandidateDir)
            if($iteration -gt 1){$nativeArgs+= '-UseInstalledCandidate'}
            & $native @nativeArgs
            $exitCode=$LASTEXITCODE
        }catch{
            $launchFailure=$_.Exception.ToString()
        }finally{
            $env:RUNNER_TEMP=$originalRunnerTemp
        }
        $cycleOut=Join-Path $cycleRoot ('TBME_R291_'+$HostLabel)
        $receiptPath=Join-Path $cycleOut 'R291_NATIVE.json'
        $status='MISSING'
        $phase=''
        $failure=$launchFailure
        $receiptHash=''
        if(Test-Path -LiteralPath $receiptPath){
            $receipt=Get-Content -LiteralPath $receiptPath -Raw|ConvertFrom-Json
            $status=[string]$receipt.Status
            $phase=[string]$receipt.Phase
            if([string]::IsNullOrWhiteSpace($failure)){$failure=[string]$receipt.Failure}
            $receiptHash=(Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash.ToUpperInvariant()
        }
        $diagnostics=[Collections.Generic.List[object]]::new()
        if(Test-Path -LiteralPath $cycleOut){
            foreach($file in @(Get-ChildItem -LiteralPath $cycleOut -Filter '*_SETTINGS_NATIVE_FAILURE.json' -File -ErrorAction SilentlyContinue)){
                $d=Get-Content -LiteralPath $file.FullName -Raw|ConvertFrom-Json
                $settingWindows=@($d.Windows|Where-Object{$_.Title -like '* - Settings'}|ForEach-Object{[ordered]@{
                    Hwnd=$_.Hwnd;Visible=$_.Visible;WSVisible=$_.WSVisible
                    Parent=$_.Parent;ParentVisible=$_.ParentVisible
                    Owner=$_.Owner;OwnerVisible=$_.OwnerVisible
                    Style=$_.Style;Rect=$_.Rect
                }})
                $diagnostics.Add([ordered]@{
                    File=$file.Name;Mode=$d.Mode;WaitMs=$d.WaitMs
                    ForegroundHWND=$d.ForegroundHWND;ForegroundPID=$d.ForegroundPID
                    ForegroundTitle=$d.ForegroundTitle;CandidateHWND=$d.CandidateHWND
                    SettingsWindows=$settingWindows
                })
            }
        }
        $passed=($exitCode -eq 0 -and $status -ceq 'PASS_REAL_MENU_SETTINGS_START_FULLSCREEN_TASKBAR_VISIBILITY_FOUR_MODES')
        $results.Add([ordered]@{
            Iteration=$iteration;Mode=if($iteration -eq 1){'FRESH_INSTALL'}else{'REUSE_EXACT_INSTALLED_CANDIDATE'}
            ExitCode=$exitCode;Status=$status;Phase=$phase;Passed=$passed
            ReceiptPath=$(if(Test-Path -LiteralPath $receiptPath){$receiptPath}else{''})
            ReceiptSHA256=$receiptHash;Failure=$failure
            SettingsFailureDiagnostics=@($diagnostics.ToArray())
        })
        Write-Output ('R360_CYCLE_'+$iteration+' STATUS='+$status+' EXIT='+$exitCode+' DIAGNOSTICS='+$diagnostics.Count)
        if($iteration -lt $Iterations){
            $processWait=0
            while(@(Get-Process -Name TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count -gt 0 -and $processWait -lt 50){
                Start-Sleep -Milliseconds 100;$processWait++
            }
            $installedMain=Join-Path $appRoot 'TaskbarMonitorEnhanced.exe'
            $installedOk=(Test-Path -LiteralPath $installedMain) -and
                (Test-Path -LiteralPath $uninstallKey) -and
                ((Get-FileHash -LiteralPath $installedMain -Algorithm SHA256).Hash.ToUpperInvariant() -ceq $mainHash)
            if(!$installedOk -or @(Get-Process -Name TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count -gt 0){
                $blockedAfter=$iteration
                Write-Output ('R360_REUSE_BLOCKED_AFTER_CYCLE_'+$iteration)
                break
            }
        }
    }
}catch{
    $fatal=$_.Exception.ToString()
}finally{
    $env:RUNNER_TEMP=$originalRunnerTemp
    $passedCount=@($results|Where-Object{$_.Passed}).Count
    $summary=[ordered]@{
        Schema=1;Revision='R360';Host=$HostLabel;RunId=$env:GITHUB_RUN_ID
        Commit=$env:GITHUB_SHA;IterationsRequested=$Iterations
        IterationsCompleted=$results.Count;Passed=$passedCount
        Failed=($results.Count-$passedCount);BlockedAfterIteration=$blockedAfter
        OSVersion=[Environment]::OSVersion.Version.ToString()
        SetupSHA256=$setupHash;MainSHA256=$mainHash
        Results=@($results.ToArray())
        PersonalComputerTouched=$false;ProductSourceChanged=$false
        UACActuallyInvoked=$false;ProductInstallAttemptedOnDisposableRunner=$installAttempted
        ProductInstallScope='Disposable GitHub-hosted runner only; first iteration installs, subsequent iterations reuse exact candidate'
        Failure=$fatal
    }
    [IO.File]::WriteAllText((Join-Path $outRoot ('R360_'+$HostLabel+'.json')),
        ($summary|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
}
if($fatal -or $results.Count -ne $Iterations -or @($results|Where-Object{-not $_.Passed}).Count -gt 0){
    throw ('R360_SETTINGS_VISIBILITY_STRESS_FAILED '+$fatal)
}
Write-Output ('R360_NATIVE_STATUS=PASS HOST='+$HostLabel+' ITERATIONS='+$passedCount+'/'+$Iterations+' SETUP_SHA256='+$setupHash)
