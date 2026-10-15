[CmdletBinding()]
param([Parameter(Mandatory=$true)][ValidateSet('A','B')][string]$HostLabel)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

# R193 is a GitHub disposable Windows-only test. Never run on the owner's computer.
if($PSVersionTable.PSEdition -eq 'Core' -or $env:GITHUB_ACTIONS -cne 'true' -or
   $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or $env:RUNNER_OS -cne 'Windows' -or
   $env:GITHUB_REPOSITORY -cne 'GOD13emad/TaskbarMonitorEnhanced' -or
   ![Environment]::UserInteractive -or $env:COMPUTERNAME -match 'EMAD|ALI'){
    throw 'R193_REFUSE_NON_DISPOSABLE_PERSONAL_OR_NONINTERACTIVE_HOST'
}
$trialSource='1b2bf5b6b58313706556d10efd242270583b5f0d'
$expectedBase='84D5DBF6F2E6D1D2E2B3E6D9C9DA523E564A7F5240C08D34A456D934026B829F'
$expectedTrial='5A44490034EB8A8B846FB11E7BD6954EED741F92DB53FC7A568DCCA358A5BCE2'
$expectedSetup='225BCC259C392DA04F3E0157CAF22F96C4052282AAF02555E6F6E777F4CB8AF4'
$expectedPriorSetup='ABD106630F7BAB3471CAF3F5BD4313DFCF2D61DDE1DF79E72EFE91933C8F2F89'
$expectedPriorMain='D50A9D03190719B8385AB2F7F7DBB3129EC7EC1C77ECBD8EF7F29832AEC26420'
if($expectedPriorMain -cnotmatch '^[A-F0-9]{64}$'){throw 'R213_OFFICIAL_171_MAIN_EXPECTED_SHA_MALFORMED'}
$repo='GOD13emad/TaskbarMonitorEnhanced'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$out=Join-Path $env:RUNNER_TEMP ('TBME_R193_CPU_'+$HostLabel)
$app=Join-Path $env:LOCALAPPDATA 'TaskbarMonitorEnhanced'
$unreg='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TaskbarMonitorEnhanced'
$reg=Join-Path $env:LOCALAPPDATA 'TaskbarMonitorEnhanced\install_state.json'
$main=Join-Path $app 'TaskbarMonitorEnhanced.exe'
$candidate=Join-Path $env:RUNNER_TEMP 'TBME_R201_CANDIDATE\TaskbarMonitorEnhanced.exe'
$source=Join-Path $out 'VERIFIED_BASELINE_MAIN.exe'
$trial=Join-Path $out 'VERIFIED_TRIAL_MAIN.exe'
$installer=Join-Path $out 'TaskbarMonitorEnhanced_Setup_1.7.2.exe'
$priorSetup=Join-Path $out 'TaskbarMonitorEnhanced_Setup_1.7.1.exe'
$config=Join-Path $app 'config.json'
$backup=Join-Path $app 'config.json.bak'
$sentinel=Join-Path $app 'R201_DISPOSABLE_ONLY.txt'
$receipt=Join-Path $out 'R201_CPU_AB.json'
$started=[DateTime]::UtcNow.ToString('o')
$phase='PRECONDITION'
$status='FAIL'
$failure=''
$results=@()
$proc=$null
$expectedConfigSha=$null
$normalizedSavedConfigSHA=$null
$postRunFixtureHashes=@()
$testFixture='{"Theme":"Retro Terminal","Opacity":0.10,"GlassMode":false,"OpacityWhenGlassOff":0.10,"ConfigSchemaVersion":8,"StartWithWindows":false,"UpdateIntervalMs":1000,"ShowSparklines":true,"AutoCheckUpdates":false}'
$proof=Join-Path $env:RUNNER_TEMP ('R201_PREINSTALL_'+$HostLabel+'.json')
if(!(Test-Path $proof -PathType Leaf)){throw 'R201_FRESH_HOST_PREINSTALL_PROOF_MISSING'}
$pre=Get-Content -LiteralPath $proof -Raw|ConvertFrom-Json
if($pre.Revision -cne 'R201' -or $pre.Host -cne $HostLabel -or
   $pre.GitCommit -cne $env:GITHUB_SHA -or
   $pre.OutputExists -ne $false -or $pre.AppRootExists -ne $false -or
   $pre.UninstallKeyExists -ne $false -or $pre.ProcessCount -ne 0){
    throw 'R201_PREINSTALL_RECEIPT_INCONSISTENT'
}
if((Test-Path $out) -or (Test-Path $app) -or (Test-Path $unreg) -or
   @((Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue)).Count){
    throw 'R201_NOT_TRULY_FRESH_BEFORE_OFFICIAL_INSTALL'
}
New-Item -ItemType Directory -Path $out -ErrorAction Stop|Out-Null
function Hash([string]$path) {
    if(!(Test-Path $path -PathType Leaf)){return 'MISSING'}
    return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
function ExactProcess([string]$exe,[string]$cliArgs,[int]$timeoutMs) {
    $info=New-Object Diagnostics.ProcessStartInfo
    $info.FileName=$exe
    $info.Arguments=$cliArgs
    $info.UseShellExecute=$false
    $info.WorkingDirectory=(Split-Path $exe -Parent)
    $p=[Diagnostics.Process]::Start($info)
    if($null -eq $p){throw 'R193_INSTALLER_PROCESS_FAILED_TO_START'}
    try {
        if(!$p.WaitForExit($timeoutMs)){throw 'R193_INSTALLER_TIMEOUT'}
        if($p.ExitCode -ne 0){throw ('R193_INSTALLER_EXIT_'+$p.ExitCode)}
    }finally{$p.Dispose()}
}
$native=@'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class R193Win {
    [StructLayout(LayoutKind.Sequential)]public struct Rect {public int L,T,R,B;}
    public delegate bool EnumFn(IntPtr h,IntPtr d);
    [DllImport("user32.dll",CharSet=CharSet.Unicode)]public static extern IntPtr FindWindow(string c,string n);
    [DllImport("user32.dll")]public static extern uint GetWindowThreadProcessId(IntPtr h,out uint pid);
    [DllImport("user32.dll")]public static extern bool EnumWindows(EnumFn f,IntPtr d);
    [DllImport("user32.dll")]public static extern bool EnumChildWindows(IntPtr p,EnumFn f,IntPtr d);
    [DllImport("user32.dll")]public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")]public static extern bool GetWindowRect(IntPtr h,out Rect r);
    [DllImport("user32.dll")]public static extern IntPtr SendMessage(IntPtr h,uint msg,IntPtr w,IntPtr l);
    public static IntPtr[] Owned(uint process,IntPtr tray){
        var list=new List<IntPtr>();
        EnumFn f=(h,d)=>{uint p;GetWindowThreadProcessId(h,out p);
          if(p==process&&!list.Contains(h))list.Add(h);return true;};
        EnumWindows(f,IntPtr.Zero);
        EnumChildWindows(tray,f,IntPtr.Zero);
        return list.ToArray();
    }
}
'@
Add-Type -TypeDefinition $native -Language CSharp
Add-Type -AssemblyName System.Drawing,System.Windows.Forms

function RequireFixture(){
    if((Hash $config) -cne $script:expectedConfigSha -or
       (Hash $backup) -cne $script:expectedConfigSha -or
       !(Test-Path $sentinel -PathType Leaf) -or
       [IO.File]::ReadAllText($sentinel) -cne 'R201 sacrificial Windows only'){
        throw 'R193_CONFIG_OR_PROTECTED_FIXTURE_CHANGED'
    }
}
# R216: only on disposable GitHub Windows. Real app normally persists its normalized
# config on WM_CLOSE via CleanupRuntime -> AppConfig.Save. This is not a user-file mutation.
# Require matching core preferences, intact immutable canary and stable normalized bytes;
# then reset exact comparable fixture before the next real CPU block.
function ReconcileAndResetDisposableFixture([int]$block){
    if(@(Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count){
        throw 'R216_PROCESS_STILL_RUNNING_BEFORE_FIXTURE_RESET'
    }
    if(!(Test-Path $sentinel -PathType Leaf) -or
       [IO.File]::ReadAllText($sentinel) -cne 'R201 sacrificial Windows only'){
        throw 'R216_USER_OWNED_CANARY_CHANGED_FAIL_CLOSED'
    }
    $actualConfig=Hash $config
    $actualBackup=Hash $backup
    if($actualConfig -ceq 'MISSING' -or $actualBackup -ceq 'MISSING' -or
       $actualConfig -cne $actualBackup){
        throw 'R216_NORMALIZED_CONFIG_BACKUP_NOT_BYTE_IDENTICAL'
    }
    $cfgBytes=[IO.File]::ReadAllBytes($config)
    $bakBytes=[IO.File]::ReadAllBytes($backup)
    if($cfgBytes.Length -gt 65536 -or $bakBytes.Length -gt 65536){
        throw 'R216_CONFIG_SIZE_BUDGET_EXCEEDED'
    }
    try{$saved=[IO.File]::ReadAllText($config,[Text.Encoding]::UTF8)|ConvertFrom-Json}
    catch{throw 'R216_NORMALIZED_CONFIG_JSON_INVALID'}
    if($saved.Theme -cne 'Retro Terminal' -or [bool]$saved.GlassMode -or
       [math]::Abs([double]$saved.Opacity-0.10) -gt 0.00001 -or
       [math]::Abs([double]$saved.OpacityWhenGlassOff-0.10) -gt 0.00001 -or
       [int]$saved.ConfigSchemaVersion -ne 8 -or [bool]$saved.StartWithWindows -or
       [int]$saved.UpdateIntervalMs -ne 1000 -or
       ![bool]$saved.ShowSparklines -or [bool]$saved.AutoCheckUpdates){
        throw 'R216_CONFIG_PROTECTED_PUBLIC_PREFERENCES_CHANGED'
    }
    if($null -eq $script:normalizedSavedConfigSHA){
        $script:normalizedSavedConfigSHA=$actualConfig
    }elseif($script:normalizedSavedConfigSHA -cne $actualConfig){
        throw 'R216_NORMALIZED_CONFIG_SHA_NOT_STABLE_ACROSS_ABBA'
    }
    $script:postRunFixtureHashes+=([ordered]@{
        Block=$block;ConfigSHA256=$actualConfig;BackupSHA256=$actualBackup
        OriginalInputConfigSHA256=$script:expectedConfigSha
        NormalizedKeyCount=@($saved.PSObject.Properties.Name).Count
        ProtectedPreferencesUnchanged=$true;DisposableCanaryUnchanged=$true
    })
    # Exact same canary-free, deterministic prestate for each ABBA block.
    # If either write fails, restore the captured normalized bytes and fail closed.
    try{
        if((Hash $config) -cne $actualConfig -or (Hash $backup) -cne $actualBackup){
            throw 'R216_CONCURRENT_FIXTURE_EDIT_BEFORE_RESET'
        }
        [IO.File]::WriteAllText($config,$testFixture,[Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText($backup,$testFixture,[Text.UTF8Encoding]::new($false))
        RequireFixture
    }catch{
        try{
            [IO.File]::WriteAllBytes($config,$cfgBytes)
            [IO.File]::WriteAllBytes($backup,$bakBytes)
            if((Hash $config) -cne $actualConfig -or (Hash $backup) -cne $actualBackup){
                throw 'R216_ROLLBACK_HASH_MISMATCH'
            }
        }catch{
            throw 'R216_FIXTURE_RESET_FAILED_ROLLBACK_UNRESOLVED'
        }
        throw 'R216_FIXTURE_RESET_FAILED_RESTORED_NORMALIZED_INPUT'
    }
}
function MonitorWindow([uint32]$targetPid) {
    $tray=[R193Win]::FindWindow('Shell_TrayWnd',$null)
    if($tray -eq [IntPtr]::Zero){return [IntPtr]::Zero}
    $trayRect=New-Object R193Win+Rect
    if(![R193Win]::GetWindowRect($tray,[ref]$trayRect)){return [IntPtr]::Zero}
    foreach($hwnd in [R193Win]::Owned($targetPid,$tray)) {
        if(![R193Win]::IsWindowVisible($hwnd)){continue}
        $r=New-Object R193Win+Rect
        if(![R193Win]::GetWindowRect($hwnd,[ref]$r)){continue}
        $width=$r.R-$r.L
        $height=$r.B-$r.T
        if($width -ge 80 -and $width -le 500 -and $height -ge 16 -and $height -lt 100 -and
           $r.L -ge $trayRect.L -and $r.R -le $trayRect.R -and
           $r.T -ge $trayRect.T -and $r.B -le $trayRect.B){
            return $hwnd
        }
    }
    return [IntPtr]::Zero
}
function StopExactOwnedProcess([Diagnostics.Process]$p,[IntPtr]$hwnd) {
    $p.Refresh()
    if($p.HasExited){return}
    if($hwnd -ne [IntPtr]::Zero) {
        [void][R193Win]::SendMessage($hwnd,0x10,[IntPtr]::Zero,[IntPtr]::Zero)
    }
    if(!$p.WaitForExit(12000)) {
        # Only our own sacrificial test process on verified ephemeral GitHub Windows.
        if([IO.Path]::GetFullPath($p.MainModule.FileName) -cne [IO.Path]::GetFullPath($main)){
            throw 'R193_REFUSE_TERMINATE_OTHER_PROCESS'
        }
        $p.Kill()
        if(!$p.WaitForExit(12000)){throw 'R193_TEST_PROCESS_STILL_RUNNING'}
    }
}
function RunBlock([string]$kind,[int]$block){
    if(@(Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count){
        throw 'R193_DUPLICATE_PROCESS_BEFORE_BLOCK'
    }
    $want=if($kind -ceq 'BASE'){$expectedBase}else{$expectedTrial}
    if((Hash $main) -cne $want){throw ('R193_WRONG_BINARY_BEFORE_BLOCK_'+$kind)}
    RequireFixture
    $process=Start-Process -FilePath $main -WorkingDirectory $app -PassThru -ErrorAction Stop
    $script:proc=$process
    $handle=[IntPtr]::Zero
    try {
        $clock=[Diagnostics.Stopwatch]::StartNew()
        do{
            $process.Refresh()
            if($process.HasExited){throw ('R193_APP_EXITED_EARLY_'+$kind)}
            $handle=MonitorWindow ([uint32]$process.Id)
            if($handle -ne [IntPtr]::Zero){break}
            Start-Sleep -Milliseconds 400
        }while($clock.Elapsed.TotalSeconds -lt 28)
        if($handle -eq [IntPtr]::Zero){throw ('R193_NO_GENUINE_VISIBLE_TASKBAR_MONITOR_'+$kind)}
        Start-Sleep -Seconds 7
        $process.Refresh()
        if($process.HasExited){throw 'R193_PRE_MEASUREMENT_APP_EXIT'}
        $before=$process.TotalProcessorTime.TotalSeconds
        $watch=[Diagnostics.Stopwatch]::StartNew()
        $ticks=0
        while($watch.Elapsed.TotalSeconds -lt 60){
            Start-Sleep -Seconds 1
            $ticks++
            $process.Refresh()
            if($process.HasExited){throw ('R193_APP_EXITED_IN_MEASUREMENT_'+$kind)}
        }
        $watch.Stop()
        $after=$process.TotalProcessorTime.TotalSeconds
        $cpu=$after-$before
        $duration=$watch.Elapsed.TotalSeconds
        if($duration -lt 60 -or $duration -gt 67 -or $cpu -lt 0){
            throw 'R193_INVALID_SUSTAINED_CPU_TIMING'
        }
        $bar=MonitorWindow ([uint32]$process.Id)
        if($bar -eq [IntPtr]::Zero){throw 'R193_MONITOR_NOT_VISIBLE_AFTER_60S'}
        $rec=[ordered]@{
            Kind=$kind
            Block=$block
            DurationSeconds=[math]::Round($duration,4)
            CpuSeconds=[math]::Round($cpu,5)
            CpuPercentOfOneCore=[math]::Round(100*$cpu/$duration,5)
            WarmupSeconds=7
            MonitoringTicks=$ticks
            NativeMonitorVisibleAtStartAndEnd=$true
            SingleProcess=$true
            BinarySHA256=$want
            ConfigSHA256=$expectedConfigSha
            TestMode='real full application running taskbar monitor; no method reflection'
        }
        return $rec
    }finally {
        try {StopExactOwnedProcess $process $handle}
        finally {
            $process.Dispose()
            $script:proc=$null
        }
    }
}
try {
    $phase='VERIFY_GITHUB_CANDIDATE'
    # R202: R201-F01 inherited stale HEAD^ from historical R193 script.
    # The real R190 product commit is an ANCESTOR, not the latest test commit parent.
    # Prove actual candidate SHA, exact CI commit, full ancestry, unchanged source.
    if((Hash $candidate) -cne $expectedTrial){
        throw 'R202_CANDIDATE_BINARY_SHA_DRIFT'
    }
    $head=(& git -C $root rev-parse HEAD).Trim()
    if($LASTEXITCODE -ne 0 -or $head -cne $env:GITHUB_SHA){
        throw 'R202_CHECKED_OUT_TEST_COMMIT_DRIFT'
    }
    & git -C $root cat-file -e ($trialSource+'^{commit}')
    if($LASTEXITCODE -ne 0){throw 'R202_ACCEPTED_PRODUCT_COMMIT_NOT_FETCHED'}
    & git -C $root merge-base --is-ancestor $trialSource HEAD
    if($LASTEXITCODE -ne 0){throw 'R202_PRODUCT_COMMIT_NOT_ANCESTOR'}
    # R223 only, exact 16-line stable-taskbar early return on frozen R202/R190 source.
    $sourceBase='8f8514189ab966138d13260e5590c5df104634b4'
    & git -C $root merge-base --is-ancestor $sourceBase HEAD
    if($LASTEXITCODE -ne 0){throw 'R223_EXPECTED_R190_TEST_BASE_NOT_ANCESTOR'}
    $changedSource=@(& git -C $root diff --name-only $sourceBase HEAD -- src)
    if($LASTEXITCODE -ne 0 -or $changedSource.Count -ne 1 -or
       $changedSource[0] -cne 'src/TaskbarMonitorEnhanced.cs'){
        throw 'R223_SOURCE_NOT_EXACT_ONE_OPTIMIZATION_FILE'
    }
    if((Hash (Join-Path $root 'src\TaskbarMonitorEnhanced.cs')) -cne
       '4AF4A6C05AFC18E6390D918A10B3CE35A4AF948C7451EF9604311A816C313E3F'){
        throw 'R223_OPTIMIZATION_SOURCE_SHA_DRIFT'
    }
    $phase='FETCH_EXACT_TWO_OFFICIAL_IMMUTABLE_SETUPS'
    & gh release download v1.7.1 --repo $repo --pattern 'TaskbarMonitorEnhanced_Setup_1.7.1.exe' --dir $out --clobber
    if($LASTEXITCODE -ne 0 -or (Hash $priorSetup) -cne $expectedPriorSetup){
        throw 'R201_OFFICIAL_171_SETUP_SHA_DRIFT'
    }
    & gh release download v1.7.2 --repo $repo --pattern 'TaskbarMonitorEnhanced_Setup_1.7.2.exe' --dir $out --clobber
    if($LASTEXITCODE -ne 0 -or (Hash $installer) -cne $expectedSetup){
        throw 'R201_OFFICIAL_172_SETUP_SHA_DRIFT'
    }
    # Exact accepted R191 native upgrade route: fresh v1.7.1 install then official
    # 1.7.2 in-place update, both into ONE sacrificial per-user canonical root.
    $phase='OFFICIAL_V171_FRESH_INSTALL_BEFORE_ANY_BUILD'
    ExactProcess $priorSetup '/install /quiet /desktop=0 /startup=0' 195000
    if((Hash $main) -cne $expectedPriorMain -or !(Test-Path $unreg)){
        throw 'R201_OFFICIAL_171_FRESH_INSTALL_IDENTITY_FAILED'
    }
    $phase='OFFICIAL_V171_TO_172_INPLACE_UPDATE'
    ExactProcess $installer '/update /quiet' 195000
    if((Hash $main) -cne $expectedBase -or !(Test-Path $unreg) -or !(Test-Path $reg)){
        throw 'R201_OFFICIAL_172_INPLACE_BASELINE_IDENTITY_FAILED'
    }
    $appLocation=[string](Get-ItemProperty $unreg).InstallLocation
    if($appLocation -cne $app -or (Get-ItemProperty $unreg).DisplayVersion -cne '1.7.2'){
        throw 'R193_CANONICAL_ONE_ROOT_OR_VERSION'
    }
    Copy-Item -LiteralPath $main -Destination $source -ErrorAction Stop
    Copy-Item -LiteralPath $candidate -Destination $trial -ErrorAction Stop
    if((Hash $source) -cne $expectedBase -or (Hash $trial) -cne $expectedTrial){
        throw 'R193_STAGED_BYTES_NOT_PINNED'
    }
    [IO.File]::WriteAllText($config,$testFixture,[Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($backup,$testFixture,[Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($sentinel,'R201 sacrificial Windows only',[Text.UTF8Encoding]::new($false))
    $expectedConfigSha=Hash $config
    RequireFixture
    $phase='SUSTAINED_ABBA_CPU_60_SECONDS_EACH'
    $modes=@('BASE','TRIAL','TRIAL','BASE')
    for($i=0;$i -lt $modes.Count;$i++){
        $mode=$modes[$i]
        $want=$source
        if($mode -ceq 'TRIAL'){$want=$trial}
        if(@(Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count){
            throw 'R193_DUPLICATE_PROCESS_ON_TRANSITION'
        }
        Copy-Item -LiteralPath $want -Destination $main -Force -ErrorAction Stop
        $wantSHA=if($mode -ceq 'BASE'){$expectedBase}else{$expectedTrial}
        if((Hash $main) -cne $wantSHA){throw 'R193_TRANSITION_BINARY_SHA_MISMATCH'}
        $results+=RunBlock $mode ($i+1)
        ReconcileAndResetDisposableFixture ($i+1)
    }
    $phase='REAL_FULL_APP_ABBA_ACCEPTANCE'
    if($results.Count -ne 4 -or @($results|Where-Object Kind -eq BASE).Count -ne 2 -or
       @($results|Where-Object Kind -eq TRIAL).Count -ne 2){
        throw 'R193_NOT_EXACT_FOUR_60S_BLOCKS'
    }
    $status='PASS_4_SUSTAINED_FULL_APP_BLOCKS_TWO_VERSIONS_SAME_HOST'
}catch {
    $failure=$_.Exception.GetType().Name+': '+$_.Exception.Message
}finally {
    if($null -ne $proc) {
        try {StopExactOwnedProcess $proc [IntPtr]::Zero}catch {}
    }
    # Restore the immutable baseline bytes in sacrificial test install root if safe.
    $restored=$false
    try {
        if((Hash $source) -ceq $expectedBase -and
           @((Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue)).Count -eq 0) {
            Copy-Item -LiteralPath $source -Destination $main -Force -ErrorAction Stop
            $restored=((Hash $main) -ceq $expectedBase)
        }
    }catch {}
    $baseValues=@($results|Where-Object Kind -eq BASE|ForEach-Object {$_.CpuPercentOfOneCore})
    $trialValues=@($results|Where-Object Kind -eq TRIAL|ForEach-Object {$_.CpuPercentOfOneCore})
    $meanBase=if($baseValues.Count){[math]::Round(($baseValues|Measure-Object -Average).Average,5)}else{$null}
    $meanTrial=if($trialValues.Count){[math]::Round(($trialValues|Measure-Object -Average).Average,5)}else{$null}
    $effect=if($meanBase -gt 0 -and $null -ne $meanTrial){[math]::Round(100*(1-$meanTrial/$meanBase),3)}else{$null}
    $evidence=[ordered]@{
        Revision='R201'
        Objective='Actual full program ABBA 4x60s on fresh GitHub-hosted CPU VM; official 171->172 single-root baseline; build in separate VM'
        Status=$status
        Phase=$phase
        Failure=$failure
        Host=$HostLabel
        ExactTrialSourceParentSHA256=$trialSource
        GithubTestCommit=$env:GITHUB_SHA
        BaselineMainSHA256=$expectedBase
        TrialMainSHA256=$expectedTrial
        OfficialSetupSHA256=$expectedSetup
        PriorOfficialSetupSHA256=$expectedPriorSetup
        Fresh171ThenUpgraded172InPlace=$true
        EntireMeasuredProgram='TaskbarMonitorEnhanced.exe'
        CanonicalSingleInstallRoot=$app
        ActualBlocks=@($results)
        BaselineMeanOneCorePercent=$meanBase
        TrialMeanOneCorePercent=$meanTrial
        ObservedReductionPercent=$effect
        AllBlocksCompleted=($results.Count -eq 4)
        DeterministicFixtureResetAfterEveryBlock=($postRunFixtureHashes.Count -eq 4)
        NormalizedConfigSHA256=$normalizedSavedConfigSHA
        PostBlockFixtureSHAEvidence=@($postRunFixtureHashes)
        RestoredBaselineExeOnSacrificialHost=$restored
        OwnerPersonalComputerTouched=$false
        NoPublicReleaseMutation=$true
        NoPhysicalPowerInterruptionClaimed=$true
        DoesNotProvePersonalOwnersCpuAfterUpgrade=$true
        StartedUTC=$started
        FinishedUTC=[DateTime]::UtcNow.ToString('o')
    }
    [IO.File]::WriteAllText($receipt,($evidence|ConvertTo-Json -Depth 10),[Text.UTF8Encoding]::new($false))
    Write-Output ($evidence|ConvertTo-Json -Depth 10 -Compress)
}
if($status -cne 'PASS_4_SUSTAINED_FULL_APP_BLOCKS_TWO_VERSIONS_SAME_HOST' -or !$restored) {
    throw ('R193_FAIL_CLOSED_'+$phase+' '+$failure+' RestoreBaseline='+$restored)
}
