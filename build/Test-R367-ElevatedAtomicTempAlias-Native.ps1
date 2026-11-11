[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateSet('baseline','candidate')][string]$Variant,
    [Parameter(Mandatory=$true)][string]$SupervisorPath,
    [Parameter(Mandatory=$true)][string]$BrokerPath,
    [Parameter(Mandatory=$true)][string]$SourceRoot,
    [Parameter(Mandatory=$true)][string]$HostLabel,
    [switch]$HostedGuest
)
$ErrorActionPreference='Stop'
if($PSEdition -ne 'Desktop'){throw 'R367_REQUIRES_WINDOWS_POWERSHELL_51'}
$source=(Resolve-Path -LiteralPath $SourceRoot).Path
$sup=(Resolve-Path -LiteralPath $SupervisorPath).Path
$broker=(Resolve-Path -LiteralPath $BrokerPath).Path
$expectedSup=Join-Path $source 'build\_out\Supervisor\TaskbarMonitorSensorSupervisor.exe'
$expectedBroker=Join-Path $source 'build\_out\Broker\TaskbarMonitorSensorBroker.exe'
if(-not [string]::Equals($sup,$expectedSup,[StringComparison]::OrdinalIgnoreCase)){throw 'R367_SUPERVISOR_PATH_OUTSIDE_BUILD_OUTPUT'}
if(-not [string]::Equals($broker,$expectedBroker,[StringComparison]::OrdinalIgnoreCase)){throw 'R367_BROKER_PATH_OUTSIDE_BUILD_OUTPUT'}
if(!(Test-Path -LiteralPath $sup) -or !(Test-Path -LiteralPath $broker)){throw 'R367_COMPILED_SENSOR_EXE_MISSING'}
if($HostedGuest -and $env:GITHUB_ACTIONS -ne 'true'){throw 'R367_HOSTED_GUEST_FLAG_WITHOUT_GITHUB_ACTIONS'}
$commit=(git -C $source rev-parse HEAD).Trim()
if($Variant -eq 'baseline' -and $commit -ne '035e8fc5db2fc020e539ec930a10770b9807d318'){throw "R367_BASELINE_COMMIT_MISMATCH_$commit"}
if($Variant -eq 'candidate'){
    $supSource=Get-Content (Join-Path $source 'src\sensors\TaskbarMonitorSensorSupervisor.cs') -Raw
    $brokerSource=Get-Content (Join-Path $source 'src\sensors\TaskbarMonitorSensorBroker.cs') -Raw
    if(!$supSource.Contains('FileMode.CreateNew,FileAccess.Write,FileShare.None') -or !$supSource.Contains('Guid.NewGuid().ToString("N")')){throw 'R367_CANDIDATE_SUPERVISOR_SOURCE_NOT_HARDENED'}
    if(!$brokerSource.Contains('FileMode.CreateNew,FileAccess.Write,FileShare.None') -or !$brokerSource.Contains('Guid.NewGuid().ToString("N")')){throw 'R367_CANDIDATE_BROKER_SOURCE_NOT_HARDENED'}
    if(!$supSource.Contains('File.Replace(tmp,StatePath,null,true)') -or !$supSource.Contains('File.Move(tmp,StatePath)') -or $supSource -match 'File\.WriteAllText\s*\(\s*tmp'){throw 'R367_CANDIDATE_SUPERVISOR_ATOMIC_REPLACE_REQUIRED'}
    if(!$brokerSource.Contains('File.Replace(tmp,path,null,true)') -or !$brokerSource.Contains('File.Move(tmp,path)') -or $brokerSource -match 'File\.WriteAllText\s*\(\s*tmp'){throw 'R367_CANDIDATE_BROKER_ATOMIC_REPLACE_REQUIRED'}
    if($brokerSource -match 'File\.Copy\s*\(\s*tmp\s*,\s*path\s*,\s*true\s*\)'){throw 'R367_CANDIDATE_BROKER_UNSAFE_COPY_FALLBACK_REMAINS'}
}
$checks=New-Object 'System.Collections.Generic.List[string]'
function Pass([string]$name){$checks.Add($name);Write-Output "PASS $name"}
function Sha([string]$path){(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash}
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class R367HardLinkNative {
    [DllImport("kernel32.dll", EntryPoint="CreateHardLinkW", CharSet=CharSet.Unicode, SetLastError=true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool CreateHardLink(string link, string target, IntPtr securityAttributes);
}
"@
function New-R367HardLink([string]$link,[string]$target){
    if(-not [R367HardLinkNative]::CreateHardLink($link,$target,[IntPtr]::Zero)){
        $code=[Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw "R367_CREATE_HARDLINK_FAILED_$code"
    }
}
$testRoot=[IO.Path]::GetFullPath((Join-Path $env:TEMP ('tbme-r367-atomic-alias-'+[Guid]::NewGuid().ToString('N'))))
$syntheticProfile=Join-Path $testRoot 'Profile With Spaces'
$syntheticLocal=Join-Path $syntheticProfile 'AppData\Local'
$appRoot=if($Variant -eq 'candidate'){Join-Path $syntheticLocal 'TaskbarMonitorEnhanced'}else{Join-Path $testRoot 'app'}
$canaryRoot=Join-Path $testRoot 'canaries'
[void][IO.Directory]::CreateDirectory($appRoot)
[void][IO.Directory]::CreateDirectory($canaryRoot)
$statePath=Join-Path $appRoot 'sensor_supervisor_state.json'
$stateTmp=$statePath+'.tmp'
$supCanary=Join-Path $canaryRoot 'supervisor-canary.txt'
$brokerOutput=Join-Path $appRoot 'cpu_temp_broker.json'
$brokerCanary=Join-Path $canaryRoot 'broker-canary.txt'
$brokerLinks=New-Object 'System.Collections.Generic.List[string]'
$brokerLease=$null
try{
    [IO.File]::WriteAllText($supCanary,'R367_SUPERVISOR_CANARY_ORIGINAL')
    $supBefore=Sha $supCanary
    New-R367HardLink $stateTmp $supCanary
    $supAsm=[Reflection.Assembly]::LoadFrom($sup)
    $supType=$supAsm.GetType('TaskbarMonitorSensorSupervisor',$true)
    $flags=[Reflection.BindingFlags]'Static,NonPublic'
    $stateField=$supType.GetField('StatePath',$flags)
    $writeState=$supType.GetMethod('WriteState',$flags)
    if(!$stateField -or !$writeState){throw 'R367_SUPERVISOR_WRITE_STATE_REFLECTION_MISSING'}
    $stateField.SetValue($null,$statePath)
    $supArgs=New-Object 'object[]' 1
    $supArgs[0]='R367_ATOMIC_TEMP_ALIAS_TEST'
    $writeState.Invoke($null,$supArgs)|Out-Null
    $supAfter=Sha $supCanary
    if($Variant -eq 'baseline'){
        if($supAfter -eq $supBefore){throw 'R367_BASELINE_SUPERVISOR_ALIAS_NOT_REPRODUCED'}
        Pass 'BASELINE_SUPERVISOR_PRECREATED_TEMP_HARDLINK_WRITE_THROUGH_REPRODUCED'
    }else{
        if($supAfter -ne $supBefore){throw 'R367_CANDIDATE_SUPERVISOR_TEMP_HARDLINK_WRITE_THROUGH_NOT_BLOCKED'}
        if(!(Test-Path -LiteralPath $statePath)){throw 'R367_CANDIDATE_SUPERVISOR_STATE_NOT_WRITTEN'}
        if(!(Test-Path -LiteralPath $stateTmp)){throw 'R367_CANDIDATE_SUPERVISOR_PRECREATED_ALIAS_SHOULD_REMAIN_UNTOUCHED'}
        $stateAttributes=[IO.File]::GetAttributes($statePath)
        if(($stateAttributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'R367_CANDIDATE_SUPERVISOR_STATE_IS_REPARSE'}
        $null=([IO.File]::ReadAllText($statePath)|ConvertFrom-Json -ErrorAction Stop)
        Pass 'CANDIDATE_SUPERVISOR_CREATE_NEW_TEMP_BLOCKS_PRECREATED_HARDLINK_AND_STATE_UPDATES'
    }
    $stateHardlinkPath=Join-Path $appRoot 'sensor_supervisor_hardlink_state.json'
    $stateHardlinkCanary=Join-Path $canaryRoot 'supervisor-destination-canary.txt'
    [IO.File]::WriteAllText($stateHardlinkCanary,'R367_SUPERVISOR_DESTINATION_CANARY_ORIGINAL')
    $stateHardlinkBefore=Sha $stateHardlinkCanary
    New-R367HardLink $stateHardlinkPath $stateHardlinkCanary
    $stateField.SetValue($null,$stateHardlinkPath)
    $writeState.Invoke($null,$supArgs)|Out-Null
    $stateHardlinkAfter=Sha $stateHardlinkCanary
    if($stateHardlinkAfter -ne $stateHardlinkBefore){throw 'R367_SUPERVISOR_DESTINATION_HARDLINK_WRITE_THROUGH'}
    if(!(Test-Path -LiteralPath $stateHardlinkPath)){throw 'R367_SUPERVISOR_DESTINATION_HARDLINK_NOT_REPLACED'}
    $null=([IO.File]::ReadAllText($stateHardlinkPath)|ConvertFrom-Json -ErrorAction Stop)
    Pass 'SUPERVISOR_DESTINATION_HARDLINK_REPLACED_WITHOUT_WRITE_THROUGH'

    [IO.File]::WriteAllText($brokerCanary,'R367_BROKER_CANARY_ORIGINAL')
    $brokerBefore=Sha $brokerCanary
    $brokerAsm=[Reflection.Assembly]::LoadFrom($broker)
    $brokerType=$brokerAsm.GetType('TaskbarMonitorSensorBroker.Program',$true)
    $atomicWrite=if($Variant -eq 'candidate'){
      $brokerType.GetMethod('AtomicWriteUnderLease',$flags)
    }else{$brokerType.GetMethod('AtomicWrite',$flags)}
    if(!$atomicWrite){throw 'R367_BROKER_ATOMIC_WRITE_REFLECTION_MISSING'}
    if($Variant -eq 'candidate'){
      $boundary=$brokerAsm.GetType('TaskbarMonitorSensorBroker.BrokerOutputBoundary',$true)
      $acquire=$boundary.GetMethod('Acquire',$flags)
      if(!$acquire){throw 'R367_CANDIDATE_BROKER_OWNER_OUTPUT_LEASE_API_MISSING'}
      $expectedBrokerOutput=[IO.Path]::Combine([IO.Path]::GetFullPath($syntheticLocal),'TaskbarMonitorEnhanced','cpu_temp_broker.json')
      $actualOutput=[IO.Path]::GetFullPath($brokerOutput)
      if(![string]::Equals($brokerOutput,$expectedBrokerOutput,[StringComparison]::OrdinalIgnoreCase) -or
         ![string]::Equals($actualOutput,$expectedBrokerOutput,[StringComparison]::OrdinalIgnoreCase)){
        throw ('R367_CANDIDATE_SYNTHETIC_OUTPUT_MISMATCH expected='+$expectedBrokerOutput+' actual='+$brokerOutput+' canonical='+$actualOutput+
               ' profile='+$syntheticProfile+' local='+$syntheticLocal+' appRoot='+$appRoot)
      }
      'R367_CANDIDATE_SYNTHETIC_MODE_OUTPUT_MATCH=PASS'
      $brokerLease=$acquire.Invoke($null,[object[]]@([string]'--run-cpu',[string]$brokerOutput,[string]$syntheticProfile,[string]$syntheticLocal))
      if(!$brokerLease){throw 'R367_CANDIDATE_TEST_ONLY_SYNTHETIC_OWNER_LEASE_REFUSED'}
    }
    $processId=[Diagnostics.Process]::GetCurrentProcess().Id
    $tickStart=[Environment]::TickCount
    $brokerArgs=if($Variant -eq 'candidate'){
      [object[]]@([string]$brokerOutput,[string]'{"R367":"ATOMIC_TEMP_ALIAS_TEST"}',$brokerLease)
    }else{[object[]]@([string]$brokerOutput,[string]'{"R367":"ATOMIC_TEMP_ALIAS_TEST"}')}
    $brokerAliasAttempts=0
    $brokerAliasHit=$false
    for($i=0;$i -lt 100;$i++){
        $tick=[Environment]::TickCount
        $alias=$brokerOutput+'.'+$processId+'.'+$tick+'.tmp'
        if(!(Test-Path -LiteralPath $alias)){
            New-R367HardLink $alias $brokerCanary
            $brokerLinks.Add($alias)
        }
        $atomicWrite.Invoke($null,$brokerArgs)|Out-Null
        $brokerAliasAttempts++
        $brokerAfter=Sha $brokerCanary
        if($brokerAfter -ne $brokerBefore){$brokerAliasHit=$true;break}
    }
    $tickEnd=[Environment]::TickCount
    if($Variant -eq 'baseline'){
        if(!$brokerAliasHit){throw 'R367_BASELINE_BROKER_ALIAS_NOT_REPRODUCED'}
        Pass 'BASELINE_BROKER_PID_TICK_TEMP_HARDLINK_WRITE_THROUGH_REPRODUCED'
    }else{
        if($brokerAliasHit){throw 'R367_CANDIDATE_BROKER_TEMP_HARDLINK_WRITE_THROUGH_NOT_BLOCKED'}
        if(!(Test-Path -LiteralPath $brokerOutput)){throw 'R367_CANDIDATE_BROKER_OUTPUT_NOT_WRITTEN'}
        $null=([IO.File]::ReadAllText($brokerOutput)|ConvertFrom-Json -ErrorAction Stop)
        Pass 'CANDIDATE_BROKER_RANDOM_CREATE_NEW_TEMP_BLOCKS_PRECREATED_HARDLINK_AND_OUTPUT_UPDATES'
    }
    $brokerHardlinkOutput=Join-Path $appRoot 'cpu_temp_broker_hardlink.json'
    $brokerHardlinkCanary=Join-Path $canaryRoot 'broker-destination-canary.txt'
    [IO.File]::WriteAllText($brokerHardlinkCanary,'R367_BROKER_DESTINATION_CANARY_ORIGINAL')
    $brokerHardlinkBefore=Sha $brokerHardlinkCanary
    New-R367HardLink $brokerHardlinkOutput $brokerHardlinkCanary
    $brokerHardlinkArgs=if($Variant -eq 'candidate'){
      [object[]]@([string]$brokerHardlinkOutput,[string]'{"R367":"DESTINATION_HARDLINK_TEST"}',$brokerLease)
    }else{[object[]]@([string]$brokerHardlinkOutput,[string]'{"R367":"DESTINATION_HARDLINK_TEST"}')}
    $atomicWrite.Invoke($null,$brokerHardlinkArgs)|Out-Null
    $brokerHardlinkAfter=Sha $brokerHardlinkCanary
    if($brokerHardlinkAfter -ne $brokerHardlinkBefore){throw 'R367_BROKER_DESTINATION_HARDLINK_WRITE_THROUGH'}
    if(!(Test-Path -LiteralPath $brokerHardlinkOutput)){throw 'R367_BROKER_DESTINATION_HARDLINK_NOT_REPLACED'}
    $null=([IO.File]::ReadAllText($brokerHardlinkOutput)|ConvertFrom-Json -ErrorAction Stop)
    Pass 'BROKER_DESTINATION_HARDLINK_REPLACED_WITHOUT_WRITE_THROUGH'
    $result=if($Variant -eq 'baseline'){'PASS_BASELINE_VULNERABILITY_REPRODUCED'}else{'PASS_CANDIDATE_TEMP_ALIAS_BLOCKED_DESTINATION_HARDLINK_SAFE'}
    $receipt=[ordered]@{
        Schema=1
        Revision='R367'
        Variant=$Variant
        HostLabel=$HostLabel
        SourceCommit=$commit
        SupervisorSHA256=(Sha $sup)
        BrokerSHA256=(Sha $broker)
        SupervisorCanaryBefore=$supBefore
        SupervisorCanaryAfter=$supAfter
        BrokerCanaryBefore=$brokerBefore
        BrokerCanaryAfter=$brokerAfter
        SupervisorDestinationCanaryBefore=$stateHardlinkBefore
        SupervisorDestinationCanaryAfter=$stateHardlinkAfter
        BrokerDestinationCanaryBefore=$brokerHardlinkBefore
        BrokerDestinationCanaryAfter=$brokerHardlinkAfter
        BrokerAliasNamesPrecreated=$brokerLinks.Count
        BrokerAliasAttempts=$brokerAliasAttempts
        BrokerAliasTestDurationMilliseconds=($tickEnd-$tickStart)
        Checks=@($checks.ToArray())
        Result=$result
        ActualSupervisorStarted=$false
        ActualBrokerStarted=$false
        InstalledFilesChanged=$false
        ScheduledTasksChanged=$false
        UACRequested=$false
    }
    if($HostedGuest){
        $receiptDir=Join-Path $env:RUNNER_TEMP ("R367_"+$Variant+"_"+$HostLabel)
        [void][IO.Directory]::CreateDirectory($receiptDir)
        $receiptPath=Join-Path $receiptDir 'R367_ELEVATED_TEMP_ALIAS.json'
        [IO.File]::WriteAllText($receiptPath,($receipt|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
        Write-Output "R367_RECEIPT=$receiptPath"
    }
    Write-Output "R367_STATUS=$result CHECKS=$($checks.Count)"
}finally{
    if($brokerLease){$brokerLease.Dispose()}
    foreach($alias in $brokerLinks){if(![String]::IsNullOrWhiteSpace([string]$alias)){Remove-Item -LiteralPath $alias -Force -ErrorAction SilentlyContinue}}
    foreach($path in @($stateTmp,$statePath,$stateHardlinkPath,$stateHardlinkCanary,$supCanary,$brokerOutput,$brokerCanary,$brokerHardlinkOutput,$brokerHardlinkCanary)){
        if(![String]::IsNullOrWhiteSpace([string]$path)){Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue}
    }
    if(Test-Path -LiteralPath $testRoot){Remove-Item -LiteralPath $testRoot -Force -Recurse -ErrorAction SilentlyContinue}
}