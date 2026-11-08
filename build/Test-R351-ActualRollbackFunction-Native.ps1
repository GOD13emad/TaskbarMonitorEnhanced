param(
    [Parameter(Mandatory=$true)][ValidateSet('A','B')][string]$HostLabel,
    [Parameter(Mandatory=$true)][string]$SourceRoot
)
$ErrorActionPreference='Stop'
$SourceRoot=[IO.Path]::GetFullPath($SourceRoot)
$runId=if($env:GITHUB_RUN_ID){$env:GITHUB_RUN_ID}else{[guid]::NewGuid().ToString('N')}
$tempBase=if(-not [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)){$env:RUNNER_TEMP}else{$env:TEMP}
$root=Join-Path $tempBase ('R351_'+$HostLabel+'_'+$runId)
$receipt=Join-Path $root 'R351_ACTUAL_ROLLBACK_FUNCTION_NATIVE.json'
$programFiles=[Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles)
$product=Join-Path $programFiles 'TaskbarMonitorEnhanced'
$broker=Join-Path $product 'SensorBroker'
$canaryDir=Join-Path $programFiles ('TBME_R351_OUTSIDE_'+$HostLabel+'_'+$runId)
$canary=Join-Path $canaryDir 'OUTSIDE_CANARY.txt'
$setup=Join-Path $SourceRoot 'build\_out\Setup\TaskbarMonitorEnhanced_Setup_1.7.10.exe'
$source=Join-Path $SourceRoot 'installer\TBME_Setup_Elevated_Helper.ps1'
$native=Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe'
$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$taskName='TaskbarMonitorEnhanced Sensor Broker'
$snapshotRoot=Join-Path $root 'previous-layer-snapshot'
$checks=[Collections.Generic.List[string]]::new()
$logs=[Collections.Generic.List[string]]::new()
$failure=''
$createdRoot=$false
$preconditionPassed=$false
$taskCreationAttempted=$false
$createdProduct=$false
$createdCanary=$false
$createdBroker=$false
$createdTask=$false
$cleanupOk=$true
$beforeCanary=''
$afterCanary=''
$rootAbsentBeforeRestore=$false
$previousExport=''
$restoredExport=''
$firstRollbackResult=$false
$secondRollbackResult=$false
$uncapturedRollbackResult=$true
function Check([string]$name){
    $script:checks.Add($name)
    Write-Output ('PASS '+$name)
}
function Hash([string]$file){
    (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
}
function HashBytes([byte[]]$bytes){
    $sha=[Security.Cryptography.SHA256]::Create()
    try{return [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-','')}
    finally{$sha.Dispose()}
}
function Normalize([string]$value){
    $value.Replace(([string][char]13+[string][char]10),[string][char]10).Trim()
}
function New-TaskXml([string]$description,[string]$arguments){
    $command=[Security.SecurityElement]::Escape($script:nativeCmd)
    $desc=[Security.SecurityElement]::Escape($description)
    $escapedArgs=[Security.SecurityElement]::Escape($arguments)
    return @"
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
<RegistrationInfo><Description>$desc</Description></RegistrationInfo>
<Triggers><LogonTrigger><Enabled>false</Enabled><UserId>$script:sid</UserId></LogonTrigger></Triggers>
<Principals><Principal id="Author"><UserId>$script:sid</UserId><LogonType>InteractiveToken</LogonType><RunLevel>HighestAvailable</RunLevel></Principal></Principals>
<Settings><Enabled>true</Enabled><AllowStartOnDemand>true</AllowStartOnDemand><DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries><StopIfGoingOnBatteries>false</StopIfGoingOnBatteries><ExecutionTimeLimit>PT1M</ExecutionTimeLimit><Priority>7</Priority></Settings>
<Actions Context="Author"><Exec><Command>$command</Command><Arguments>$escapedArgs</Arguments></Exec></Actions>
</Task>
"@
}
function New-LayerFixture([string]$tag){
    if([IO.Directory]::Exists($broker)){throw 'R351_BROKER_FIXTURE_ALREADY_EXISTS'}
    [void][IO.Directory]::CreateDirectory($broker)
    $script:createdBroker=$true
    $brokerAcl=Get-Acl -LiteralPath $broker
    $brokerAcl.SetOwner([Security.Principal.SecurityIdentifier]::new('S-1-5-32-544'))
    Set-Acl -LiteralPath $broker -AclObject $brokerAcl -ErrorAction Stop
    [IO.File]::WriteAllText((Join-Path $broker '.tbme-owner.sid'),$sid,[Text.Encoding]::ASCII)
    [IO.File]::WriteAllText((Join-Path $broker 'TaskbarMonitorSensorBroker.exe'),('R351_'+$tag+'_BROKER'),[Text.Encoding]::ASCII)
    [IO.File]::WriteAllText((Join-Path $broker 'TaskbarMonitorSensorSupervisor.exe'),('R351_'+$tag+'_SUPERVISOR'),[Text.Encoding]::ASCII)
    [void][IO.Directory]::CreateDirectory((Join-Path $broker 'backend\nested'))
    [IO.File]::WriteAllText((Join-Path $broker 'backend\nested\probe.bin'),('R351_'+$tag+'_BACKEND'),[Text.Encoding]::ASCII)
}
function Remove-OwnedBrokerFixture {
    if(-not $createdBroker){return}
    if(-not [IO.Directory]::Exists($broker)){$script:createdBroker=$false;return}
    $lease=[TBMEProtectedBrokerTreeLease]::new($broker)
    try{
        if(-not $lease.IsPinned){throw 'R351_CLEANUP_TREE_LEASE_NOT_PINNED'}
        [void]$lease.DeleteOwnedTree($sid,$false)
    }finally{$lease.Dispose()}
    if([IO.Directory]::Exists($broker)){throw 'R351_CLEANUP_BROKER_ROOT_REMAINS'}
    $script:createdBroker=$false
}
function Set-RollbackState(
    [bool]$captured,[bool]$previous,[object[]]$files,[string]$taskXml,
    [string]$live,[string]$gpu,[string]$storage,[string]$supervisorState
){
    $script:RollbackCaptured=$captured
    $script:PreviousSensorLayerPresent=$previous
    $script:RollbackFiles=$files
    $script:RollbackTaskXmlText=$taskXml
    $script:RollbackPerformed=$false
    $script:RollbackSucceeded=$false
    $script:ActiveArchitecture=''
    $script:validatedSensorSid=$script:sid
    $script:BrokerRoot=$script:broker
    $script:TaskName=$script:taskName
    $script:LiveJson=$live
    $script:GpuJson=$gpu
    $script:StorageJson=$storage
    $script:SupervisorState=$supervisorState
}
try{
    if($env:GITHUB_ACTIONS -cne 'true' -or
       $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
       $env:RUNNER_OS -cne 'Windows' -or
       $env:GITHUB_REPOSITORY -cne 'GOD13emad/TaskbarMonitorEnhanced' -or
       $env:GITHUB_REF -cne 'refs/heads/security/r347-r349-helper-hardening-v1710' -or
       $env:COMPUTERNAME -match '(?i)EMAD-PC|ALIEMAD|SAEID|LAPTOP' -or
       (git rev-parse HEAD).Trim() -cne $env:GITHUB_SHA){
        throw 'R351_REFUSE_NON_DISPOSABLE_OR_WRONG_SOURCE'
    }
    if([IO.Directory]::Exists($root) -or [IO.Directory]::Exists($product) -or
       [IO.Directory]::Exists($canaryDir) -or
       @(Get-ScheduledTask -TaskPath '\' -TaskName $taskName -ErrorAction SilentlyContinue|Where-Object {$null -ne $_}).Count -or
       @(Get-Process TaskbarMonitorEnhanced,TaskbarMonitorSensorBroker,TaskbarMonitorSensorSupervisor -ErrorAction SilentlyContinue).Count){
        throw 'R351_PREEXISTING_PRODUCT_TASK_OR_FIXTURE_COLLISION'
    }
    $principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
        throw 'R351_NO_PREEXISTING_ADMIN_TOKEN'
    }
    foreach($f in @($source,$setup,$native)){
        if(-not [IO.File]::Exists($f)){throw ('R351_REQUIRED_FILE_MISSING_'+$f)}
    }
    $preconditionPassed=$true
    [void][IO.Directory]::CreateDirectory($root)
    $createdRoot=$true
    $asm=[Reflection.Assembly]::LoadFrom((Resolve-Path $setup).Path)
    $stream=$asm.GetManifestResourceStream('Payload.TBME_Setup_Elevated_Helper.ps1')
    if(!$stream){throw 'R351_REAL_SETUP_EMBEDDED_HELPER_MISSING'}
    $reader=[IO.StreamReader]::new($stream,[Text.Encoding]::UTF8)
    try{$embedded=$reader.ReadToEnd()}finally{$reader.Dispose()}
    $helperSource=[IO.File]::ReadAllText($source)
    if((Normalize $embedded) -cne (Normalize $helperSource)){
        throw 'R351_SETUP_EMBEDDED_HELPER_SOURCE_MISMATCH'
    }
    Check 'EXACT_COMPILED_SETUP_PE_EMBEDS_CURRENT_HELPER_SOURCE'
    $classAt=$embedded.IndexOf('public sealed class TBMEProtectedBrokerTreeLease',[StringComparison]::Ordinal)
    $header=$embedded.LastIndexOf("Add-Type -TypeDefinition @'",[Math]::Max(0,$classAt),[StringComparison]::Ordinal)
    $first=$embedded.IndexOf([string][char]10,$header,[StringComparison]::Ordinal)
    $last=$embedded.IndexOf(([string][char]10+"'@"),$classAt,[StringComparison]::Ordinal)
    if($classAt -lt 0 -or $header -lt 0 -or $first -lt 0 -or $last -le $classAt -or $last-$first -gt 40000){
        throw 'R351_EXACT_EMBEDDED_NATIVE_CLASS_EXTRACTION_REFUSED'
    }
    Add-Type -TypeDefinition $embedded.Substring($first+1,$last-$first-1) -ErrorAction Stop
    if($null -eq ('TBMEProtectedBrokerTreeLease' -as [type])){
        throw 'R351_NATIVE_TREE_LEASE_CLASS_NOT_COMPILED'
    }
    Check 'EXACT_PE_EMBEDDED_NATIVE_TREE_LEASE_COMPILED'
    $tokens=$null;$parseErrors=$null
    $ast=[Management.Automation.Language.Parser]::ParseInput($embedded,[ref]$tokens,[ref]$parseErrors)
    if(@($parseErrors).Count -ne 0){throw ('R351_EMBEDDED_HELPER_PARSE_ERRORS_'+@($parseErrors).Count)}
    $required=@('Assert-SensorBoundaryNoReparse','Assert-SensorJournalTrustedAcl','Get-SensorRollbackFiles','Restore-SensorRollbackFiles','Restore-PreviousSensorLayer')
    $definitions=@{}
    foreach($name in $required){
        $nodes=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ceq $name},$true))
        if($nodes.Count -ne 1){throw ('R351_EXPECTED_ONE_EXACT_PRODUCTION_FUNCTION_'+$name)}
        $definitions[$name]=$nodes[0].Extent.Text
    }
    foreach($name in @('Assert-SensorBoundaryNoReparse','Assert-SensorJournalTrustedAcl','Get-SensorRollbackFiles','Restore-PreviousSensorLayer')){
        Invoke-Expression $definitions[$name]
    }
    $originalRestore=$definitions['Restore-SensorRollbackFiles'] -replace '^(?i)function\s+Restore-SensorRollbackFiles\b','function Restore-SensorRollbackFiles_R351Original'
    Invoke-Expression $originalRestore
    function Restore-SensorRollbackFiles([string]$Folder,[object[]]$Saved){
        if([IO.Directory]::Exists($Folder)){throw 'R351_NATIVE_TREE_NOT_DELETED_BEFORE_PRIOR_LAYER_RESTORE'}
        $script:rootAbsentBeforeRestore=$true
        Restore-SensorRollbackFiles_R351Original $Folder $Saved
    }
    function Write-Log([string]$Message){$script:logs.Add($Message)}
    Check 'EXACT_PRODUCTION_ROLLBACK_AND_SNAPSHOT_FUNCTIONS_EXTRACTED_FROM_PE'
    Import-Module ScheduledTasks -ErrorAction Stop
    $script:nativeCmd=Join-Path ([Environment]::SystemDirectory) 'cmd.exe'
    $script:sid=$sid
    $script:taskName=$taskName
    $script:broker=$broker
    $script:logs=$logs
    [void][IO.Directory]::CreateDirectory($product);$createdProduct=$true
    [void][IO.Directory]::CreateDirectory($canaryDir);$createdCanary=$true
    [IO.File]::WriteAllText($canary,'R351_OUTSIDE_CANARY',[Text.UTF8Encoding]::new($false))
    $beforeCanary=Hash $canary
    Check 'FRESH_PROGRAMFILES_ROOT_AND_OUTSIDE_CANARY_CREATED'
    [void][IO.Directory]::CreateDirectory($snapshotRoot)
    [IO.File]::WriteAllText((Join-Path $snapshotRoot '.tbme-owner.sid'),$sid,[Text.Encoding]::ASCII)
    [IO.File]::WriteAllText((Join-Path $snapshotRoot 'TaskbarMonitorSensorBroker.exe'),'R351_PRIOR_BROKER',[Text.Encoding]::ASCII)
    [IO.File]::WriteAllText((Join-Path $snapshotRoot 'TaskbarMonitorSensorSupervisor.exe'),'R351_PRIOR_SUPERVISOR',[Text.Encoding]::ASCII)
    [void][IO.Directory]::CreateDirectory((Join-Path $snapshotRoot 'backend\nested'))
    [IO.File]::WriteAllText((Join-Path $snapshotRoot 'backend\nested\prior.bin'),'R351_PRIOR_BACKEND',[Text.Encoding]::ASCII)
    $saved=Get-SensorRollbackFiles $snapshotRoot
    if(@($saved).Count -ne 4){throw ('R351_PRIOR_SNAPSHOT_FILE_COUNT_'+@($saved).Count)}
    Check 'EXACT_PRODUCTION_ROLLBACK_SNAPSHOT_CAPTURED_FROM_PRIOR_FILES'
    $previousXml=New-TaskXml 'R351_PREVIOUS_TASK_SNAPSHOT' '/c exit 0'
    $taskCreationAttempted=$true
    Register-ScheduledTask -TaskPath '\' -TaskName $taskName -Xml $previousXml -Force|Out-Null
    $createdTask=$true
    $previousExport=[string](Export-ScheduledTask -TaskPath '\' -TaskName $taskName)
    if([string]::IsNullOrWhiteSpace($previousExport) -or !$previousExport.Contains('R351_PREVIOUS_TASK_SNAPSHOT')){
        throw 'R351_PREVIOUS_TASK_EXPORT_FAILED'
    }
    $newXml=New-TaskXml 'R351_NEW_LAYER_TASK' '/c exit 97'
    $taskCreationAttempted=$true
    Register-ScheduledTask -TaskPath '\' -TaskName $taskName -Xml $newXml -Force|Out-Null
    $createdTask=$true
    $newExport=[string](Export-ScheduledTask -TaskPath '\' -TaskName $taskName)
    if(!$newExport.Contains('R351_NEW_LAYER_TASK')){throw 'R351_NEW_TASK_NOT_INSTALLED'}
    Check 'REAL_TASK_SCHEDULER_NEW_TASK_REPLACES_CAPTURED_PRIOR_TASK'
    New-LayerFixture 'NEW'
    $live=Join-Path $root 'live.json'
    $gpu=Join-Path $root 'gpu.json'
    $storage=Join-Path $root 'storage.json'
    $supervisorState=Join-Path $root 'supervisor-state.json'
    foreach($f in @($live,$gpu,$storage,$supervisorState)){
        [IO.File]::WriteAllText($f,'R351_NEW_LAYER_TELEMETRY',[Text.Encoding]::ASCII)
    }
    Set-RollbackState $true $true $saved $previousExport $live $gpu $storage $supervisorState
    $firstRollbackResult=Restore-PreviousSensorLayer 'R351_REAL_INPROCESS_ROLLBACK_PROBE'
    if(-not $firstRollbackResult -or -not $RollbackPerformed -or -not $RollbackSucceeded -or
       $ActiveArchitecture -cne 'PREVIOUS_SENSOR_LAYER_RESTORED' -or
       -not $rootAbsentBeforeRestore -or -not [IO.Directory]::Exists($broker)){
        throw 'R351_PREVIOUS_LAYER_ROLLBACK_FUNCTION_NOT_SUCCESSFUL'
    }
    Check 'EXACT_PRODUCTION_ROLLBACK_FUNCTION_DELETES_NEW_TREE_BEFORE_RESTORE'
    $expected=@{
      '.tbme-owner.sid'=$sid
      'TaskbarMonitorSensorBroker.exe'='R351_PRIOR_BROKER'
      'TaskbarMonitorSensorSupervisor.exe'='R351_PRIOR_SUPERVISOR'
      'backend\nested\prior.bin'='R351_PRIOR_BACKEND'
    }
    foreach($rel in $expected.Keys){
        $f=Join-Path $broker $rel
        if(-not [IO.File]::Exists($f) -or [IO.File]::ReadAllText($f,[Text.Encoding]::ASCII) -cne [string]$expected[$rel]){
            throw ('R351_PRIOR_FILE_NOT_BYTE_EXACT_'+$rel)
        }
    }
    if([IO.File]::Exists((Join-Path $broker 'backend\nested\probe.bin'))){
        throw 'R351_NEW_LAYER_FILE_SURVIVED_ROLLBACK'
    }
    Check 'PREVIOUS_BROKER_SUPERVISOR_BACKEND_AND_OWNER_MARKER_RESTORED_EXACT'
    Assert-SensorJournalTrustedAcl $broker $false
    Check 'RESTORED_PREVIOUS_BROKER_ROOT_RETAINS_TRUSTED_OWNER_AND_DACL'
    $restoredExport=[string](Export-ScheduledTask -TaskPath '\' -TaskName $taskName)
    if((Normalize $restoredExport) -cne (Normalize $previousExport)){
        throw 'R351_PREVIOUS_TASK_XML_NOT_RESTORED_EXACT'
    }
    $taskInfo=Get-ScheduledTaskInfo -TaskPath '\' -TaskName $taskName
    $deadline=(Get-Date).AddSeconds(10)
    while(($taskInfo.LastRunTime -le [datetime]::FromFileTimeUtc(0) -or $taskInfo.LastTaskResult -ne 0) -and (Get-Date) -lt $deadline){
        Start-Sleep -Milliseconds 200
        $taskInfo=Get-ScheduledTaskInfo -TaskPath '\' -TaskName $taskName
    }
    if($taskInfo.LastRunTime -le [datetime]::FromFileTimeUtc(0) -or $taskInfo.LastTaskResult -ne 0){throw ('R351_RESTORED_TASK_DID_NOT_RUN_SUCCESSFULLY_'+$taskInfo.LastTaskResult)}
    Check 'REAL_TASK_SCHEDULER_RESTORES_PRIOR_XML_AND_STARTS_PRIOR_TASK'
    foreach($f in @($live,$gpu,$storage,$supervisorState)){
        if([IO.File]::Exists($f)){throw ('R351_NEW_TELEMETRY_NOT_REMOVED_'+$f)}
    }
    if(@($logs|Where-Object {$_ -like 'R350_ROLLBACK_HANDLE_BOUND_TREE_DELETE_PASS entries=*'}).Count -ne 1 -or
       @($logs|Where-Object {$_ -ceq 'ROLLBACK_PASS architecture=PREVIOUS_SENSOR_LAYER_RESTORED'}).Count -ne 1){
        throw 'R351_NATIVE_DELETE_OR_ROLLBACK_SUCCESS_LOG_MISSING'
    }
    if((Hash $canary) -cne $beforeCanary){throw 'R351_OUTSIDE_CANARY_CHANGED_DURING_PREVIOUS_RESTORE'}
    Check 'ROLLBACK_CLEARS_NEW_TELEMETRY_AND_PRESERVES_OUTSIDE_CANARY'
    Remove-OwnedBrokerFixture
    Unregister-ScheduledTask -TaskPath '\' -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    $createdTask=$false
    $newXml=New-TaskXml 'R351_NEW_LAYER_TASK_NO_PRIOR' '/c exit 97'
    $taskCreationAttempted=$true
    Register-ScheduledTask -TaskPath '\' -TaskName $taskName -Xml $newXml -Force|Out-Null
    $createdTask=$true
    New-LayerFixture 'NO_PRIOR'
    Set-RollbackState $true $false @() '' $live $gpu $storage $supervisorState
    foreach($f in @($live,$gpu,$storage,$supervisorState)){
        [IO.File]::WriteAllText($f,'R351_NO_PRIOR_TELEMETRY',[Text.Encoding]::ASCII)
    }
    $secondRollbackResult=Restore-PreviousSensorLayer 'R351_NO_PREVIOUS_LAYER_PROBE'
    if(-not $secondRollbackResult -or -not $RollbackSucceeded -or
       $ActiveArchitecture -cne 'NO_PROTECTED_SENSOR_LAYER' -or
       [IO.Directory]::Exists($broker) -or
       @(Get-ScheduledTask -TaskPath '\' -TaskName $taskName -ErrorAction SilentlyContinue|Where-Object {$null -ne $_}).Count){
        throw 'R351_NO_PREVIOUS_LAYER_ROLLBACK_NOT_CLEAN'
    }
    Check 'NO_PREVIOUS_LAYER_ROLLBACK_DELETES_NEW_TREE_AND_LEAVES_TASK_ABSENT'
    foreach($f in @($live,$gpu,$storage,$supervisorState)){
        if([IO.File]::Exists($f)){throw 'R351_NO_PRIOR_TELEMETRY_NOT_REMOVED'}
    }
    if((Hash $canary) -cne $beforeCanary){throw 'R351_NO_PRIOR_ROLLBACK_CHANGED_OUTSIDE_CANARY'}
    Check 'NO_PRIOR_ROLLBACK_PRESERVES_EXTERNAL_CANARY'
    $createdTask=$false
    New-LayerFixture 'UNCAPTURED'
    Set-RollbackState $false $true $saved $previousExport $live $gpu $storage $supervisorState
    $uncapturedRollbackResult=Restore-PreviousSensorLayer 'R351_UNCAPTURED_SNAPSHOT_NEGATIVE'
    if($uncapturedRollbackResult -or $RollbackSucceeded -or
       $ActiveArchitecture -cne 'ROLLBACK_FAILED' -or
       -not [IO.Directory]::Exists($broker) -or
       [IO.File]::ReadAllText((Join-Path $broker 'TaskbarMonitorSensorBroker.exe'),[Text.Encoding]::ASCII) -cne 'R351_UNCAPTURED_BROKER'){
        throw 'R351_UNCAPTURED_SNAPSHOT_DID_NOT_FAIL_CLOSED'
    }
    Check 'UNCAPTURED_ROLLBACK_REFUSED_WITHOUT_TREE_OR_TASK_MUTATION'
    $afterCanary=Hash $canary
    if($afterCanary -cne $beforeCanary){throw 'R351_FINAL_OUTSIDE_CANARY_HASH_MISMATCH'}
    Check 'OUTSIDE_CANARY_FINAL_HASH_UNCHANGED'
}catch{
    $failure=$_.Exception.ToString()
}finally{
    try{
        if($preconditionPassed -and $taskCreationAttempted -and
           @(Get-ScheduledTask -TaskPath '\' -TaskName $taskName -ErrorAction SilentlyContinue|Where-Object {$null -ne $_}).Count){
            Unregister-ScheduledTask -TaskPath '\' -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        }
    }catch{$failure+=' R351_TASK_CLEANUP_REFUSED '+$_.Exception.ToString()}
    try{
        if($createdBroker){Remove-OwnedBrokerFixture}
        if($createdProduct -and [IO.Directory]::Exists($product)){
            if(([IO.File]::GetAttributes($product) -band [IO.FileAttributes]::ReparsePoint) -ne 0){
                throw 'R351_PRODUCT_CLEANUP_REPARSE_REFUSED'
            }
            $entries=@([IO.Directory]::GetFileSystemEntries($product))
            if($entries.Count -ne 0){throw 'R351_PRODUCT_CLEANUP_UNEXPECTED_MEMBER'}
            [IO.Directory]::Delete($product,$false)
        }
        if($createdProduct){$cleanupOk=$cleanupOk -and -not [IO.Directory]::Exists($product)}
    }catch{$failure+=' R351_PROGRAMFILES_CLEANUP_REFUSED '+$_.Exception.ToString()}
    try{
        if($createdCanary -and [IO.Directory]::Exists($canaryDir)){
            $attrs=[IO.File]::GetAttributes($canaryDir)
            if(($attrs -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'R351_CANARY_DIRECTORY_REPARSE'}
            $members=@([IO.Directory]::GetFileSystemEntries($canaryDir))
            if($members.Count -ne 1 -or $members[0] -cne $canary){throw 'R351_CANARY_DIRECTORY_UNEXPECTED_MEMBER'}
            if([IO.File]::Exists($canary)){
                if(-not $beforeCanary -or (Hash $canary) -cne $beforeCanary){throw 'R351_CANARY_CLEANUP_HASH_MISMATCH'}
                [IO.File]::Delete($canary)
            }
            [IO.Directory]::Delete($canaryDir,$false)
        }
        if($createdCanary){$cleanupOk=$cleanupOk -and -not [IO.Directory]::Exists($canaryDir)}
    }catch{$failure+=' R351_CANARY_CLEANUP_REFUSED '+$_.Exception.ToString()}
}
if($createdRoot -and [IO.Directory]::Exists($root)){
    $receiptData=[ordered]@{
        Schema=1;Revision='R351'
        Status=$(if(!$failure -and $checks.Count -eq 15 -and $cleanupOk){'PASS_R351_ACTUAL_INPROCESS_ROLLBACK_FUNCTION'}else{'FAIL_R351_ACTUAL_INPROCESS_ROLLBACK_FUNCTION'})
        Host=$HostLabel;SourceCommit=$env:GITHUB_SHA
        SetupSHA256=$(if([IO.File]::Exists($setup)){Hash $setup}else{''})
        EmbeddedHelperSHA256=$(if($embedded){HashBytes ([Text.Encoding]::UTF8.GetBytes($embedded))}else{''})
        ExactProductionRollbackFunctionsExtracted=$true
        ExactEmbeddedNativeTreeLeaseCompiled=$true
        RealProgramFilesNTFS=$true
        RealTaskSchedulerRegistrationAndStart=$true
        PreviousLayerFileSnapshotRestored=$firstRollbackResult
        NoPreviousLayerBranchTested=$secondRollbackResult
        UncapturedSnapshotFailClosed=(-not $uncapturedRollbackResult)
        PreviousTaskXmlSHA256=$(if($previousExport){HashBytes ([Text.Encoding]::UTF8.GetBytes($previousExport))}else{''})
        RestoredTaskXmlExact=([bool]$previousExport -and (Normalize $restoredExport) -ceq (Normalize $previousExport))
        OutsideCanarySHA256Before=$beforeCanary;OutsideCanarySHA256After=$afterCanary
        Checks=@($checks);CleanupOwnedProgramFilesFixture=$cleanupOk;Failure=$failure
    }
    [IO.File]::WriteAllText($receipt,($receiptData|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
    Write-Output ('R351_NATIVE_RECEIPT='+$receipt)
}
$status=if(!$failure -and $checks.Count -eq 15 -and $cleanupOk){'PASS_R351_ACTUAL_INPROCESS_ROLLBACK_FUNCTION'}else{'FAIL_R351_ACTUAL_INPROCESS_ROLLBACK_FUNCTION'}
Write-Output ('R351_NATIVE_STATUS='+$status+' CHECKS='+$checks.Count)
if($failure){throw ('R351_ACTUAL_ROLLBACK_FUNCTION_NOT_ACCEPTED '+$failure)}
