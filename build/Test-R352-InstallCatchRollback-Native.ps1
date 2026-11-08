param(
    [Parameter(Mandatory=$true)][ValidateSet('A','B')][string]$HostLabel,
    [Parameter(Mandatory=$true)][string]$SourceRoot
)
$ErrorActionPreference='Stop'
$SourceRoot=[IO.Path]::GetFullPath($SourceRoot)
$runId=if($env:GITHUB_RUN_ID){$env:GITHUB_RUN_ID}else{[guid]::NewGuid().ToString('N')}
$fixtureId=[guid]::NewGuid().ToString('N')
$tempBase=if(-not [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)){$env:RUNNER_TEMP}else{$env:TEMP}
$root=Join-Path $tempBase ('R352_'+$HostLabel+'_'+$runId+'_'+$fixtureId)
$receipt=Join-Path $root 'R352_INSTALL_CATCH_ROLLBACK_NATIVE.json'
$outputPath=Join-Path $root 'R352_HELPER_OUTPUT.log'
$previousXmlPath=Join-Path $root 'R352_PREVIOUS_TASK_XML.xml'
$injectedHelperPath=Join-Path $root 'R352_Injected_Helper.ps1'
$programFiles=[Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles)
$profileSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$profileKey='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\'+$profileSid
$profileEntry=Get-ItemProperty -LiteralPath $profileKey -ErrorAction Stop
$profile=[IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables([string]$profileEntry.ProfileImagePath)).TrimEnd('\')
$appRoot=Join-Path $profile 'AppData\Local\TaskbarMonitorEnhanced'
$payloadParent=Join-Path $profile 'AppData\Local\Temp'
$payloadDir=Join-Path $payloadParent ('tbme_setup_'+$fixtureId)
$product=Join-Path $programFiles 'TaskbarMonitorEnhanced'
$broker=Join-Path $product 'SensorBroker'
$journal=Join-Path $product '.tbme-sensor-rollback'
$canaryDir=Join-Path $programFiles ('TBME_R352_OUTSIDE_'+$HostLabel+'_'+$runId+'_'+$fixtureId)
$canary=Join-Path $canaryDir 'OUTSIDE_CANARY.txt'
$pawnKey='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\PawnIO'
$pawnWowKey='HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\PawnIO'
$pawnRegistrySubKey='SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\PawnIO'
$setup=Join-Path $SourceRoot 'build\_out\Setup\TaskbarMonitorEnhanced_Setup_1.7.10.exe'
$helperSourcePath=Join-Path $SourceRoot 'installer\TBME_Setup_Elevated_Helper.ps1'
$native=Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe'
$taskName='TaskbarMonitorEnhanced Sensor Broker'
$nativeCmd=Join-Path ([Environment]::SystemDirectory) 'cmd.exe'
$checks=[Collections.Generic.List[string]]::new()
$cleanupErrors=[Collections.Generic.List[string]]::new()
$failure=''
$preconditionPassed=$false
$createdRoot=$false
$createdAppRoot=$false
$createdPayload=$false
$createdProduct=$false
$createdBroker=$false
$createdCanary=$false
$createdTask=$false
$createdPawnKey=$false
$helperExit=$null
$helperResult=$null
$previousExport=''
$restoredExport=''
$beforeCanary=''
$afterCanary=''
$embedded=''
$zipEntryCount=0
$zipExpectedNames=@()
$journalExpectedFiles=@()
$journalExpectedDirs=@()
$priorFiles=[ordered]@{
    '.tbme-owner.sid'=$profileSid
    'TaskbarMonitorSensorBroker.exe'='R352_PRIOR_BROKER_BYTES'
    'TaskbarMonitorSensorSupervisor.exe'='R352_PRIOR_SUPERVISOR_BYTES'
    'backend\nested\prior.bin'='R352_PRIOR_BACKEND_BYTES'
}
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
function Read-ResourceBytes([Reflection.Assembly]$Assembly,[string]$Name){
    $stream=$Assembly.GetManifestResourceStream($Name)
    if($null -eq $stream){throw ('R352_SETUP_RESOURCE_MISSING_'+$Name)}
    $memory=[IO.MemoryStream]::new()
    try{
        $stream.CopyTo($memory)
        return ,$memory.ToArray()
    }finally{$stream.Dispose();$memory.Dispose()}
}
function Set-TrustedDirectoryOwner([string]$Path){
    $acl=Get-Acl -LiteralPath $Path -ErrorAction Stop
    $acl.SetOwner([Security.Principal.SecurityIdentifier]::new('S-1-5-32-544'))
    Set-Acl -LiteralPath $Path -AclObject $acl -ErrorAction Stop
}
function New-TaskXml([string]$Description,[string]$Arguments){
    $command=[Security.SecurityElement]::Escape($script:nativeCmd)
    $desc=[Security.SecurityElement]::Escape($Description)
    $escapedArgs=[Security.SecurityElement]::Escape($Arguments)
    return @"
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
<RegistrationInfo><Description>$desc</Description></RegistrationInfo>
<Triggers><LogonTrigger><Enabled>false</Enabled><UserId>$script:profileSid</UserId></LogonTrigger></Triggers>
<Principals><Principal id="Author"><UserId>$script:profileSid</UserId><LogonType>InteractiveToken</LogonType><RunLevel>HighestAvailable</RunLevel></Principal></Principals>
<Settings><Enabled>true</Enabled><AllowStartOnDemand>true</AllowStartOnDemand><DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries><StopIfGoingOnBatteries>false</StopIfGoingOnBatteries><ExecutionTimeLimit>PT1M</ExecutionTimeLimit><Priority>7</Priority></Settings>
<Actions Context="Author"><Exec><Command>$command</Command><Arguments>$escapedArgs</Arguments></Exec></Actions>
</Task>
"@
}
function Assert-ExactTreeFiles([string]$Path,[string[]]$ExpectedFiles,[string[]]$ExpectedDirs=@()){
    if(-not [IO.Directory]::Exists($Path)){throw ('R352_TREE_MISSING_'+$Path)}
    $files=@(Get-ChildItem -LiteralPath $Path -Force -File -Recurse -ErrorAction Stop)
    $dirs=@(Get-ChildItem -LiteralPath $Path -Force -Directory -Recurse -ErrorAction Stop)
    foreach($item in @($files)+@($dirs)){
        if(([IO.File]::GetAttributes($item.FullName) -band [IO.FileAttributes]::ReparsePoint) -ne 0){
            throw ('R352_TREE_REPARSE_REFUSED_'+$item.FullName)
        }
    }
    $actualFiles=@($files|ForEach-Object {$_.FullName.Substring($Path.Length+1).Replace('/','\')}|Sort-Object)
    $expectedFileSet=@($ExpectedFiles|Sort-Object)
    if(($actualFiles -join '|') -cne ($expectedFileSet -join '|')){
        throw ('R352_TREE_FILESET_MISMATCH_'+$Path+' actual='+($actualFiles -join ','))
    }
    $actualDirs=@($dirs|ForEach-Object {$_.FullName.Substring($Path.Length+1).Replace('/','\')}|Sort-Object)
    $expectedDirSet=@($ExpectedDirs|Sort-Object)
    if(($actualDirs -join '|') -cne ($expectedDirSet -join '|')){
        throw ('R352_TREE_DIRSET_MISMATCH_'+$Path+' actual='+($actualDirs -join ','))
    }
    return ,$files
}
function Remove-ExactTree([string]$Path,[string[]]$ExpectedFiles,[string[]]$ExpectedDirs=@()){
    if(-not [IO.Directory]::Exists($Path)){return}
    $files=Assert-ExactTreeFiles $Path $ExpectedFiles $ExpectedDirs
    foreach($file in $files){[IO.File]::Delete($file.FullName)}
    $dirs=@(Get-ChildItem -LiteralPath $Path -Force -Directory -Recurse -ErrorAction Stop|Sort-Object {$_.FullName.Length} -Descending)
    foreach($dir in $dirs){[IO.Directory]::Delete($dir.FullName,$false)}
    [IO.Directory]::Delete($Path,$false)
}
try{
    if($env:GITHUB_ACTIONS -cne 'true' -or
       $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
       $env:RUNNER_OS -cne 'Windows' -or
       $env:GITHUB_REPOSITORY -cne 'GOD13emad/TaskbarMonitorEnhanced' -or
       $env:GITHUB_REF -cne 'refs/heads/security/r347-r349-helper-hardening-v1710' -or
       $env:COMPUTERNAME -match '(?i)EMAD-PC|ALIEMAD|SAEID|LAPTOP' -or
       (& git -C $SourceRoot rev-parse HEAD).Trim() -cne $env:GITHUB_SHA){
        throw 'R352_REFUSE_NON_DISPOSABLE_OR_WRONG_SOURCE'
    }
    if($profileSid -cnotmatch '^S-1-5-21-(?:\d+-){3}\d+$' -or
       [IO.Path]::GetFullPath($profile).TrimEnd('\') -cne [IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\') -or
       -not [IO.Directory]::Exists($payloadParent) -or
       -not [IO.Directory]::Exists($programFiles) -or
       [IO.Path]::GetFullPath($programFiles) -cne [IO.Path]::GetFullPath($env:ProgramFiles) -or
       -not [IO.File]::Exists($setup) -or
       -not [IO.File]::Exists($helperSourcePath) -or
       -not [IO.File]::Exists($native)){
        throw 'R352_HOST_PROFILE_OR_BUILD_PRECONDITION_FAILED'
    }
    $principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
        throw 'R352_NO_PREEXISTING_ADMIN_TOKEN'
    }
    Import-Module ScheduledTasks -ErrorAction Stop
    $collisions=[Collections.Generic.List[string]]::new()
    if([IO.Directory]::Exists($root)){$collisions.Add('RUNNER_TEMP_ROOT')}
    if([IO.Directory]::Exists($appRoot)){$collisions.Add('APP_ROOT')}
    if([IO.Directory]::Exists($product)){$collisions.Add('PROGRAMFILES_PRODUCT_ROOT')}
    if([IO.Directory]::Exists($payloadDir)){$collisions.Add('PAYLOAD_DIRECTORY')}
    if([IO.Directory]::Exists($canaryDir)){$collisions.Add('OUTSIDE_CANARY_DIRECTORY')}
    if(Test-Path -LiteralPath $journal){$collisions.Add('ROLLBACK_JOURNAL')}
    if(Test-Path -LiteralPath $pawnKey){$collisions.Add('PAWNIO_REGISTRY_KEY')}
    if(Test-Path -LiteralPath $pawnWowKey){$collisions.Add('PAWNIO_WOW64_REGISTRY_KEY')}
    if(@(Get-ScheduledTask -TaskPath '\' -TaskName $taskName -ErrorAction SilentlyContinue|Where-Object {$null -ne $_}).Count){$collisions.Add('SENSOR_TASK')}
    if(@(Get-Process TaskbarMonitorEnhanced,TaskbarMonitorSensorBroker,TaskbarMonitorSensorSupervisor -ErrorAction SilentlyContinue).Count){$collisions.Add('PRODUCT_PROCESS')}
    if($collisions.Count){throw ('R352_PREEXISTING_TARGET_COLLISION_'+($collisions -join ','))}
    $preconditionPassed=$true
    [void][IO.Directory]::CreateDirectory($root);$createdRoot=$true
    [void][IO.Directory]::CreateDirectory($appRoot);$createdAppRoot=$true
    [void][IO.Directory]::CreateDirectory($payloadDir);$createdPayload=$true
    [void][IO.Directory]::CreateDirectory($product);$createdProduct=$true
    Set-TrustedDirectoryOwner $product
    [void][IO.Directory]::CreateDirectory($broker);$createdBroker=$true
    Set-TrustedDirectoryOwner $broker
    foreach($entry in $priorFiles.GetEnumerator()){
        $destination=Join-Path $broker $entry.Key
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
        [IO.File]::WriteAllText($destination,[string]$entry.Value,[Text.Encoding]::ASCII)
    }
    [void][IO.Directory]::CreateDirectory($canaryDir);$createdCanary=$true
    [IO.File]::WriteAllText($canary,'R352_OUTSIDE_CANARY',[Text.UTF8Encoding]::new($false))
    $beforeCanary=Hash $canary
    Check 'FRESH_GITHUB_HOSTED_ADMIN_RUNNER_AND_EMPTY_TARGETS_CONFIRMED'
    $asm=[Reflection.Assembly]::LoadFrom((Resolve-Path $setup).Path)
    $helperBytes=Read-ResourceBytes $asm 'Payload.TBME_Setup_Elevated_Helper.ps1'
    $brokerBytes=Read-ResourceBytes $asm 'Payload.TaskbarMonitorSensorBroker.exe'
    $supervisorBytes=Read-ResourceBytes $asm 'Payload.TaskbarMonitorSensorSupervisor.exe'
    $zipBytes=Read-ResourceBytes $asm 'Payload.LibreHardwareMonitor.zip'
    $embedded=[Text.Encoding]::UTF8.GetString($helperBytes)
    $helperSource=[IO.File]::ReadAllText($helperSourcePath)
    if((Normalize $embedded) -cne (Normalize $helperSource)){
        throw 'R352_SETUP_EMBEDDED_HELPER_SOURCE_MISMATCH'
    }
    Check 'EXACT_COMPILED_SETUP_PE_EMBEDS_CURRENT_HELPER_SOURCE'
    $helperPath=Join-Path $payloadDir 'TBME_Setup_Elevated_Helper.ps1'
    $brokerPayload=Join-Path $payloadDir 'TaskbarMonitorSensorBroker.exe'
    $supervisorPayload=Join-Path $payloadDir 'TaskbarMonitorSensorSupervisor.exe'
    $zipPath=Join-Path $payloadDir 'LibreHardwareMonitor.zip'
    [IO.File]::WriteAllBytes($helperPath,$helperBytes)
    [IO.File]::WriteAllBytes($brokerPayload,$brokerBytes)
    [IO.File]::WriteAllBytes($supervisorPayload,$supervisorBytes)
    [IO.File]::WriteAllBytes($zipPath,$zipBytes)
    Add-Type -AssemblyName System.IO.Compression
    $zipStream=[IO.File]::OpenRead($zipPath)
    $archive=[IO.Compression.ZipArchive]::new($zipStream,[IO.Compression.ZipArchiveMode]::Read,$false)
    try{
        $zipEntryCount=$archive.Entries.Count
        $zipExpectedNames=@($archive.Entries|ForEach-Object {([string]$_.FullName).Replace('/','\')})
        if($zipEntryCount -ne 43){throw ('R352_BACKEND_ZIP_ENTRY_COUNT_'+$zipEntryCount)}
        $dllEntry=$archive.GetEntry('LibreHardwareMonitorLib.dll')
        if($null -eq $dllEntry -or $dllEntry.Length -le 0){throw 'R352_BACKEND_DLL_ENTRY_MISSING'}
        $backendRoot=Join-Path $appRoot 'SensorBackend\LibreHardwareMonitor-0.9.6'
        [void][IO.Directory]::CreateDirectory($backendRoot)
        $dllStream=$dllEntry.Open()
        $dllOutput=[IO.File]::Open((Join-Path $backendRoot 'LibreHardwareMonitorLib.dll'),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try{$dllStream.CopyTo($dllOutput);$dllOutput.Flush($true)}
        finally{$dllStream.Dispose();$dllOutput.Dispose()}
    }finally{$archive.Dispose();$zipStream.Dispose()}
    Check 'EXACT_SETUP_PAYLOAD_RESOURCES_EXTRACTED_AND_BACKEND_PREFLIGHT_SATISFIED'
    $registerLine='Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force|Out-Null'
    $registerFirst=$embedded.IndexOf($registerLine,[StringComparison]::Ordinal)
    $registerLast=$embedded.LastIndexOf($registerLine,[StringComparison]::Ordinal)
    if($registerFirst -lt 0 -or $registerLast -ne $registerFirst){
        throw 'R352_EXPECTED_ONE_INSTALL_TASK_REGISTRATION_INJECTION_POINT'
    }
    $injected=$embedded.Replace($registerLine,$registerLine+[Environment]::NewLine+"    throw 'R352_INJECTED_AFTER_NEW_TASK_REGISTERED'")
    if($injected -ceq $embedded){throw 'R352_FAILURE_INJECTION_NOT_APPLIED'}
    [IO.File]::WriteAllText($injectedHelperPath,$injected,[Text.UTF8Encoding]::new($false))
    Check 'SINGLE_FAILURE_INJECTION_INSERTED_AFTER_REAL_NEW_TASK_REGISTRATION'
    $previousXml=New-TaskXml 'R352_PREVIOUS_TASK_SNAPSHOT' '/c exit 0'
    Register-ScheduledTask -TaskPath '\' -TaskName $taskName -Xml $previousXml -Force -ErrorAction Stop|Out-Null
    $createdTask=$true
    $previousExport=[string](Export-ScheduledTask -TaskPath '\' -TaskName $taskName -ErrorAction Stop)
    if([string]::IsNullOrWhiteSpace($previousExport) -or !$previousExport.Contains('R352_PREVIOUS_TASK_SNAPSHOT')){
        throw 'R352_PREVIOUS_TASK_EXPORT_FAILED'
    }
    [IO.File]::WriteAllText($previousXmlPath,$previousExport,[Text.UTF8Encoding]::new($false))
    Check 'REAL_TASK_SCHEDULER_PRIOR_OWNER_TASK_AND_PROGRAMFILES_LAYER_SEEDED'
    $registry=[Microsoft.Win32.Registry]::LocalMachine.CreateSubKey($pawnRegistrySubKey)
    if($null -eq $registry){throw 'R352_PAWNIO_TEST_REGISTRY_CREATE_FAILED'}
    try{$registry.SetValue('DisplayVersion','2.2.0',[Microsoft.Win32.RegistryValueKind]::String)}
    finally{$registry.Dispose()}
    $createdPawnKey=$true
    if([string](Get-ItemProperty -LiteralPath $pawnKey -ErrorAction Stop).DisplayVersion -cne '2.2.0'){
        throw 'R352_PAWNIO_TEST_REGISTRY_READBACK_FAILED'
    }
    Check 'TEMPORARY_PAWNIO_VERSION_METADATA_FIXTURE_READY_NO_DRIVER_INSTALLED'
    $nativePowerShell=[IO.Path]::GetFullPath($native)
    $helperArgs=@(
        '-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass',
        '-File',$injectedHelperPath,
        '-Mode','Install',
        '-PayloadDir',$payloadDir,
        '-AppRoot',$appRoot,
        '-UserId',$profileSid,
        '-ExpectedBrokerSHA256',(Hash $brokerPayload),
        '-ExpectedSupervisorSHA256',(Hash $supervisorPayload),
        '-ExpectedBackendZipSHA256',(Hash $zipPath)
    )
    $helperOutput=@(& $nativePowerShell @helperArgs 2>&1)
    $helperExit=$LASTEXITCODE
    $helperOutputText=($helperOutput|ForEach-Object {[string]$_}) -join [Environment]::NewLine
    [IO.File]::WriteAllText($outputPath,$helperOutputText,[Text.UTF8Encoding]::new($false))
    if($helperExit -ne 0){throw ('R352_HELPER_PROCESS_EXIT_'+$helperExit+' '+$helperOutputText)}
    if(-not [IO.File]::Exists((Join-Path $appRoot 'Logs\sensor_install.log')) -or
       -not [IO.File]::Exists((Join-Path $appRoot 'Logs\sensor_install_result.json'))){
        throw 'R352_HELPER_DID_NOT_WRITE_LOG_AND_RESULT'
    }
    $log=[IO.File]::ReadAllText((Join-Path $appRoot 'Logs\sensor_install.log'))
    $result=[IO.File]::ReadAllText((Join-Path $appRoot 'Logs\sensor_install_result.json'))|ConvertFrom-Json
    $helperResult=$result
    if($result.Status -cne 'DEGRADED_ROLLBACK_RECOVERY_REQUIRED' -or
       -not [bool]$result.RollbackPerformed -or
       -not [bool]$result.RollbackSucceeded -or
       -not [bool]$result.PreviousSensorLayerPresent -or
       [bool]$result.TaskInstalled -or
       [bool]$result.SensorHealthy -or
       [bool]$result.SupervisorHealthy -or
       [string]$result.Architecture -cne 'PREVIOUS_SENSOR_LAYER_RESTORED' -or
       [string]$result.PawnIOStatus -cne 'ALREADY_PRESENT'){
        throw ('R352_INSTALL_CALLER_ROLLBACK_RESULT_MISMATCH '+($result|ConvertTo-Json -Depth 5 -Compress))
    }
    Check 'ACTUAL_INSTALL_MODE_CALLER_CATCH_REACHED_ROLLBACK_AND_REPORTED_SUCCESS'
    foreach($marker in @(
        'R352_INJECTED_AFTER_NEW_TASK_REGISTERED',
        'ROLLBACK_PASS architecture=PREVIOUS_SENSOR_LAYER_RESTORED',
        'R311_INPROCESS_ROLLBACK_JOURNAL_PENDING verifiedInMemory=True',
        'R350_ROLLBACK_HANDLE_BOUND_TREE_DELETE_PASS entries='
    )){
        if(-not $log.Contains($marker)){throw ('R352_REQUIRED_INSTALL_ROLLBACK_LOG_MARKER_MISSING_'+$marker)}
    }
    Check 'INJECTED_FAILURE_AFTER_REAL_TASK_REGISTERED_AND_NATIVE_ROLLBACK_LOGS_CONFIRMED'
    $actualBrokerFiles=Assert-ExactTreeFiles $broker @(
        '.tbme-owner.sid','TaskbarMonitorSensorBroker.exe',
        'TaskbarMonitorSensorSupervisor.exe','backend\nested\prior.bin'
    ) @('backend','backend\nested')
    foreach($entry in $priorFiles.GetEnumerator()){
        $file=Join-Path $broker $entry.Key
        if([IO.File]::ReadAllText($file,[Text.Encoding]::ASCII) -cne [string]$entry.Value){
            throw ('R352_PRIOR_LAYER_FILE_NOT_RESTORED_EXACT_'+$entry.Key)
        }
    }
    $brokerAcl=Get-Acl -LiteralPath $broker -ErrorAction Stop
    $brokerOwner=([Security.Principal.NTAccount]::new([string]$brokerAcl.Owner)).Translate([Security.Principal.SecurityIdentifier]).Value
    if($brokerOwner -cne 'S-1-5-32-544'){throw 'R352_RESTORED_BROKER_OWNER_NOT_ADMINISTRATORS'}
    Check 'PRIOR_BROKER_SUPERVISOR_BACKEND_AND_OWNER_MARKER_BYTES_RESTORED_EXACT'
    $restoredExport=[string](Export-ScheduledTask -TaskPath '\' -TaskName $taskName -ErrorAction Stop)
    if((Normalize $restoredExport) -cne (Normalize $previousExport)){
        throw 'R352_PRIOR_TASK_XML_NOT_RESTORED_EXACT'
    }
    $taskInfo=Get-ScheduledTaskInfo -TaskPath '\' -TaskName $taskName -ErrorAction Stop
    $deadline=(Get-Date).AddSeconds(10)
    while(($taskInfo.LastRunTime -le [datetime]::FromFileTimeUtc(0) -or $taskInfo.LastTaskResult -ne 0) -and (Get-Date) -lt $deadline){
        Start-Sleep -Milliseconds 200
        $taskInfo=Get-ScheduledTaskInfo -TaskPath '\' -TaskName $taskName -ErrorAction Stop
    }
    if($taskInfo.LastRunTime -le [datetime]::FromFileTimeUtc(0) -or $taskInfo.LastTaskResult -ne 0){
        throw ('R352_RESTORED_PRIOR_TASK_DID_NOT_RUN_SUCCESSFULLY_'+$taskInfo.LastTaskResult)
    }
    Check 'REAL_TASK_SCHEDULER_PRIOR_XML_RESTORED_AND_PRIOR_TASK_EXECUTED'
    foreach($pathToCheck in @(
        (Join-Path $appRoot 'cpu_temp_broker.json'),
        (Join-Path $appRoot 'gpu_temp_broker.json'),
        (Join-Path $appRoot 'storage_temp_broker.json'),
        (Join-Path $appRoot 'sensor_supervisor_state.json')
    )){
        if([IO.File]::Exists($pathToCheck)){throw ('R352_NEW_SENSOR_TELEMETRY_SURVIVED_ROLLBACK_'+$pathToCheck)}
    }
    Check 'NEW_SENSOR_TELEMETRY_REMOVED_DURING_ROLLBACK'
    if((Hash $canary) -cne $beforeCanary){throw 'R352_OUTSIDE_CANARY_CHANGED'}
    Check 'OUTSIDE_PROGRAMFILES_CANARY_UNCHANGED'
    if(-not [IO.Directory]::Exists($journal)){throw 'R352_DURABLE_PREPARED_JOURNAL_MISSING_AFTER_INPROCESS_ROLLBACK'}
    $ready=Join-Path $journal 'READY'
    $manifestPath=Join-Path $journal 'manifest.json'
    $taskSnapshot=Join-Path $journal 'task.xml'
    if([IO.File]::ReadAllText($ready,[Text.Encoding]::ASCII) -cne 'TBME_SENSOR_READY_V1'){
        throw 'R352_JOURNAL_READY_MARKER_INVALID'
    }
    $manifest=[IO.File]::ReadAllText($manifestPath,[Text.Encoding]::UTF8)|ConvertFrom-Json
    if($manifest.Schema -ne 1 -or $manifest.Phase -cne 'PREPARED' -or
       $manifest.Sid -cne $profileSid -or -not [bool]$manifest.OldRootPresent -or
       -not [bool]$manifest.TaskPresent -or @($manifest.Files).Count -ne 4){
        throw 'R352_JOURNAL_PREPARED_MANIFEST_INVALID'
    }
    $manifestPriorNames=@($manifest.Files|ForEach-Object {[string]$_.Rel}|Sort-Object)
    $expectedPriorNames=@($priorFiles.Keys|Sort-Object)
    if(($manifestPriorNames -join '|') -cne ($expectedPriorNames -join '|')){
        throw 'R352_JOURNAL_PRIOR_FILE_INVENTORY_MISMATCH'
    }
    $taskBytes=[IO.File]::ReadAllBytes($taskSnapshot)
    if((HashBytes $taskBytes) -cne [string]$manifest.TaskHash -or
       (Normalize ([Text.Encoding]::UTF8.GetString($taskBytes))) -cne (Normalize $previousExport)){
        throw 'R352_JOURNAL_TASK_SNAPSHOT_NOT_BYTE_EXACT'
    }
    $journalExpectedFiles=@('READY','manifest.json','task.xml')
    $journalExpectedDirs=@('files')
    foreach($row in @($manifest.Files)){
        $relative=[string]$row.Rel
        $snapshot=Join-Path (Join-Path $journal 'files') $relative
        if(-not [IO.File]::Exists($snapshot)){throw ('R352_JOURNAL_SNAPSHOT_MISSING_'+$relative)}
        $bytes=[IO.File]::ReadAllBytes($snapshot)
        if($bytes.Length -ne [long]$row.Length -or (HashBytes $bytes) -cne [string]$row.Hash){
            throw ('R352_JOURNAL_SNAPSHOT_HASH_MISMATCH_'+$relative)
        }
        $journalExpectedFiles+=('files\'+$relative)
        $parent=[IO.Path]::GetDirectoryName($relative)
        while($parent){
            $journalExpectedDirs+=('files\'+$parent.Replace('/','\'))
            $parent=[IO.Path]::GetDirectoryName($parent)
        }
    }
    $journalExpectedDirs=@($journalExpectedDirs|Select-Object -Unique)
    if([IO.File]::Exists((Join-Path $journal 'COMMITTED.terminal')) -or
       [IO.File]::Exists((Join-Path $journal 'ROLLED_BACK.terminal'))){
        throw 'R352_INPROCESS_ROLLBACK_MUST_RETAIN_PREPARED_WITHOUT_TERMINAL'
    }
    [void](Assert-ExactTreeFiles $journal $journalExpectedFiles $journalExpectedDirs)
    $journalAcl=Get-Acl -LiteralPath $journal -ErrorAction Stop
    $journalOwner=([Security.Principal.NTAccount]::new([string]$journalAcl.Owner)).Translate([Security.Principal.SecurityIdentifier]).Value
    if($journalOwner -cne 'S-1-5-32-544' -or -not $journalAcl.AreAccessRulesProtected){
        throw 'R352_JOURNAL_OWNER_OR_PROTECTED_DACL_INVALID'
    }
    $expectedNewNames=@('TaskbarMonitorSensorBroker.exe','TaskbarMonitorSensorSupervisor.exe','.tbme-owner.sid')+$zipExpectedNames
    $manifestNewNames=@($manifest.ExpectedNewFiles|ForEach-Object {[string]$_}|Sort-Object)
    $expectedNewNames=@($expectedNewNames|Sort-Object)
    if(($manifestNewNames -join '|') -cne ($expectedNewNames -join '|')){
        throw 'R352_JOURNAL_EXPECTED_NEW_FILE_INVENTORY_INVALID'
    }
    Check 'DURABLE_JOURNAL_REMAINS_AUTHENTICATED_PREPARED_WITH_BYTE_EXACT_SNAPSHOTS'
    $sensorProcesses=@(Get-Process TaskbarMonitorSensorBroker,TaskbarMonitorSensorSupervisor -ErrorAction SilentlyContinue)
    if($sensorProcesses.Count){throw 'R352_SENSOR_PROCESS_STARTED_DURING_INJECTED_ROLLBACK'}
    Check 'NO_NEW_PROTECTED_SENSOR_PROCESS_LEFT_RUNNING'
}catch{
    $failure=$_.Exception.ToString()
}finally{
    if($preconditionPassed){
        try{
            if($createdTask){
                $current=@(Get-ScheduledTask -TaskPath '\' -TaskName $taskName -ErrorAction SilentlyContinue|Where-Object {$null -ne $_})
                if($current.Count -eq 1 -and $previousExport){
                    $currentXml=[string](Export-ScheduledTask -TaskPath '\' -TaskName $taskName -ErrorAction Stop)
                    if((Normalize $currentXml) -cne (Normalize $previousExport)){
                        throw 'R352_TASK_CLEANUP_REFUSED_UNEXPECTED_TASK_XML'
                    }
                    Unregister-ScheduledTask -TaskPath '\' -TaskName $taskName -Confirm:$false -ErrorAction Stop
                }elseif($current.Count -gt 0){
                    throw 'R352_TASK_CLEANUP_REFUSED_UNEXPECTED_TASK_COUNT'
                }
            }
        }catch{$cleanupErrors.Add('TASK '+$_.Exception.ToString())}
        try{
            if($createdBroker -and [IO.Directory]::Exists($broker)){
                Remove-ExactTree $broker @(
                    '.tbme-owner.sid','TaskbarMonitorSensorBroker.exe',
                    'TaskbarMonitorSensorSupervisor.exe','backend\nested\prior.bin'
                ) @('backend','backend\nested')
            }
            if([IO.Directory]::Exists($journal)){
                if(-not $journalExpectedFiles.Count){throw 'R352_JOURNAL_CLEANUP_REFUSED_UNVERIFIED_JOURNAL'}
                Remove-ExactTree $journal $journalExpectedFiles $journalExpectedDirs
            }
            if($createdProduct -and [IO.Directory]::Exists($product)){
                Remove-ExactTree $product @() @()
            }
        }catch{$cleanupErrors.Add('PROGRAMFILES '+$_.Exception.ToString())}
        try{
            if($createdCanary -and [IO.Directory]::Exists($canaryDir)){
                if((Hash $canary) -cne $beforeCanary){throw 'R352_CANARY_CLEANUP_HASH_MISMATCH'}
                Remove-ExactTree $canaryDir @('OUTSIDE_CANARY.txt') @()
            }
        }catch{$cleanupErrors.Add('CANARY '+$_.Exception.ToString())}
        try{
            if($createdAppRoot -and [IO.Directory]::Exists($appRoot)){
                Remove-ExactTree $appRoot @(
                    'Logs\sensor_install.log',
                    'Logs\sensor_install_result.json',
                    'SensorBackend\LibreHardwareMonitor-0.9.6\LibreHardwareMonitorLib.dll'
                ) @('Logs','SensorBackend','SensorBackend\LibreHardwareMonitor-0.9.6')
            }
        }catch{$cleanupErrors.Add('APPROOT '+$_.Exception.ToString())}
        try{
            if($createdPayload -and [IO.Directory]::Exists($payloadDir)){
                Remove-ExactTree $payloadDir @(
                    'TBME_Setup_Elevated_Helper.ps1',
                    'TaskbarMonitorSensorBroker.exe',
                    'TaskbarMonitorSensorSupervisor.exe',
                    'LibreHardwareMonitor.zip'
                ) @()
            }
        }catch{$cleanupErrors.Add('PAYLOAD '+$_.Exception.ToString())}
        try{
            if($createdPawnKey -and (Test-Path -LiteralPath $pawnKey)){
                $key=Get-Item -LiteralPath $pawnKey -ErrorAction Stop
                $valueNames=@($key.GetValueNames())
                $subKeys=@($key.GetSubKeyNames())
                if($valueNames.Count -ne 1 -or $valueNames[0] -cne 'DisplayVersion' -or
                   $subKeys.Count -ne 0 -or [string]$key.GetValue('DisplayVersion') -cne '2.2.0'){
                    throw 'R352_PAWNIO_REGISTRY_CLEANUP_REFUSED_UNEXPECTED_CONTENT'
                }
                Remove-Item -LiteralPath $pawnKey -Force -ErrorAction Stop
            }
        }catch{$cleanupErrors.Add('PAWNIO_REGISTRY '+$_.Exception.ToString())}
    }
}
if($createdRoot -and [IO.Directory]::Exists($root)){
    if($cleanupErrors.Count -eq 0){
        foreach($left in @($product,$appRoot,$payloadDir,$canaryDir)){
            if([IO.Directory]::Exists($left)){$cleanupErrors.Add('OWNED_FIXTURE_REMAINS '+$left)}
        }
        if(Test-Path -LiteralPath $pawnKey){$cleanupErrors.Add('PAWNIO_REGISTRY_FIXTURE_REMAINS')}
        if(Test-Path -LiteralPath $pawnWowKey){$cleanupErrors.Add('UNEXPECTED_WOW64_PAWNIO_REGISTRY_KEY_REMAINS')}
        if(@(Get-ScheduledTask -TaskPath '\' -TaskName $taskName -ErrorAction SilentlyContinue|Where-Object {$null -ne $_}).Count){
            $cleanupErrors.Add('OWNED_TASK_REMAINS')
        }
    }
    if($cleanupErrors.Count){$failure+=' R352_CLEANUP_FAILURE '+($cleanupErrors -join ' | ')}
    $status=if(!$failure -and $checks.Count -eq 14 -and $cleanupErrors.Count -eq 0){
        'PASS_R352_ACTUAL_INSTALL_CATCH_ROLLBACK'
    }else{
        'FAIL_R352_ACTUAL_INSTALL_CATCH_ROLLBACK'
    }
    $receiptData=[ordered]@{
        Schema=1;Revision='R352';Status=$status;Host=$HostLabel;SourceCommit=$env:GITHUB_SHA
        SetupSHA256=$(if([IO.File]::Exists($setup)){Hash $setup}else{''})
        EmbeddedHelperSHA256=$(if($embedded){HashBytes ([Text.Encoding]::UTF8.GetBytes($embedded))}else{''})
        InjectedHelperSHA256=$(if([IO.File]::Exists($injectedHelperPath)){Hash $injectedHelperPath}else{''})
        FailureInjection='THROW_IMMEDIATELY_AFTER_REAL_NEW_TASK_REGISTRATION'
        PawnIOFixture='TEMPORARY_HKLM_UNINSTALL_DISPLAYVERSION_2_2_0'
        PawnIODriverInstalled=$false
        RealProgramFilesNTFS=($checks -contains 'INJECTED_FAILURE_AFTER_REAL_TASK_REGISTERED_AND_NATIVE_ROLLBACK_LOGS_CONFIRMED')
        RealTaskSchedulerRegistrationExportAndStart=($checks -contains 'REAL_TASK_SCHEDULER_PRIOR_XML_RESTORED_AND_PRIOR_TASK_EXECUTED')
        PawnIORegistryFixtureRemoved=(-not (Test-Path -LiteralPath $pawnKey))
        OwnerDeviceMutation=$false
        HelperProcessExitCode=$helperExit
        HelperResultStatus=$(if($helperResult){[string]$helperResult.Status}else{''})
        RollbackPerformed=$(if($helperResult){[bool]$helperResult.RollbackPerformed}else{$false})
        RollbackSucceeded=$(if($helperResult){[bool]$helperResult.RollbackSucceeded}else{$false})
        PriorLayerFileBytesRestored=($checks -contains 'PRIOR_BROKER_SUPERVISOR_BACKEND_AND_OWNER_MARKER_BYTES_RESTORED_EXACT')
        PriorTaskXmlRestored=($checks -contains 'REAL_TASK_SCHEDULER_PRIOR_XML_RESTORED_AND_PRIOR_TASK_EXECUTED')
        PreparedJournalRetained=($checks -contains 'DURABLE_JOURNAL_REMAINS_AUTHENTICATED_PREPARED_WITH_BYTE_EXACT_SNAPSHOTS')
        OutsideCanarySHA256Before=$beforeCanary;OutsideCanarySHA256After=$afterCanary
        Checks=@($checks);CleanupErrors=@($cleanupErrors);Failure=$failure
    }
    [IO.File]::WriteAllText($receipt,($receiptData|ConvertTo-Json -Depth 7),[Text.UTF8Encoding]::new($false))
    Write-Output ('R352_NATIVE_RECEIPT='+$receipt)
}
$status=if(!$failure -and $checks.Count -eq 14 -and $cleanupErrors.Count -eq 0){
    'PASS_R352_ACTUAL_INSTALL_CATCH_ROLLBACK'
}else{
    'FAIL_R352_ACTUAL_INSTALL_CATCH_ROLLBACK'
}
Write-Output ('R352_NATIVE_STATUS='+$status+' CHECKS='+$checks.Count)
if($failure){throw ('R352_ACTUAL_INSTALL_CATCH_ROLLBACK_NOT_ACCEPTED '+$failure)}
