param(
    [Parameter(Mandatory=$true)][ValidateSet('Install','Uninstall')][string]$Mode,
    [Parameter(Mandatory=$true)][string]$PayloadDir,
    [Parameter(Mandatory=$true)][string]$AppRoot,
    [Parameter(Mandatory=$true)][string]$UserId,
    [string]$ExpectedBrokerSHA256='',
    [string]$ExpectedSupervisorSHA256=''
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

# R291: privileged sensor preflight runs before ANY result/log creation.
# Ordinary per-user Setup stays unelevated; only optional sensors use UAC.
function Assert-SensorBoundaryNoReparse([string]$Path){
    if([string]::IsNullOrWhiteSpace($Path)){throw 'SENSOR_BOUNDARY_EMPTY_PATH'}
    $cursor=[IO.Path]::GetFullPath($Path)
    while(-not [string]::IsNullOrEmpty($cursor)){
        try{
            if(([IO.File]::GetAttributes($cursor) -band [IO.FileAttributes]::ReparsePoint) -ne 0){
                throw [IO.IOException]::new('SENSOR_BOUNDARY_REPARSE_REFUSED: '+$cursor)
            }
        }catch [IO.FileNotFoundException]{
            # Absent output may be created later; other I/O errors fail closed.
        }catch [IO.DirectoryNotFoundException]{
        }
        $parent=[IO.Path]::GetDirectoryName($cursor)
        if([string]::IsNullOrEmpty($parent) -or $parent -ceq $cursor){break}
        $cursor=$parent
    }
}
function Assert-SensorPrivilegedBoundary(
    [string]$RequestedMode,[string]$RequestedPayload,[string]$RequestedAppRoot,[string]$RequestedUser
){
    if($RequestedMode -cne 'Install' -and $RequestedMode -cne 'Uninstall'){
        throw 'SENSOR_BOUNDARY_INVALID_MODE'
    }
    if([string]::IsNullOrWhiteSpace($RequestedUser)){throw 'SENSOR_BOUNDARY_EMPTY_USER'}
    $sid=if($RequestedUser -match '^S-1-5-21-(?:\d+-){3}\d+$'){
        $RequestedUser
    }else{
        try{
            [string]([Security.Principal.NTAccount]::new($RequestedUser)).Translate(
                [Security.Principal.SecurityIdentifier]
            ).Value
        }catch{
            throw 'SENSOR_BOUNDARY_USER_ID_UNRESOLVABLE'
        }
    }
    if($sid -cnotmatch '^S-1-5-21-(?:\d+-){3}\d+$'){
        throw 'SENSOR_BOUNDARY_USER_PROFILE_NOT_INTERACTIVE'
    }
    $profileKey='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\'+$sid
    $entry=Get-ItemProperty -LiteralPath $profileKey -ErrorAction Stop
    if([string]::IsNullOrWhiteSpace([string]$entry.ProfileImagePath)){
        throw 'SENSOR_BOUNDARY_PROFILE_MISSING'
    }
    $profile=[IO.Path]::GetFullPath(
        [Environment]::ExpandEnvironmentVariables([string]$entry.ProfileImagePath)
    ).TrimEnd([IO.Path]::DirectorySeparatorChar)
    if($profile.StartsWith('\\') -or [IO.Path]::GetPathRoot($profile) -ceq $profile){
        throw 'SENSOR_BOUNDARY_PROFILE_NOT_LOCAL'
    }
    $expectedRoot=[IO.Path]::GetFullPath((Join-Path $profile 'AppData\Local\TaskbarMonitorEnhanced'))
    if(-not [IO.Path]::IsPathRooted($RequestedAppRoot) -or
       -not [string]::Equals([IO.Path]::GetFullPath($RequestedAppRoot),
               $expectedRoot,[StringComparison]::OrdinalIgnoreCase)){
        throw 'SENSOR_BOUNDARY_APP_ROOT_OUTSIDE_USER_PROFILE'
    }
    if(-not [IO.Path]::IsPathRooted($RequestedPayload)){
        throw 'SENSOR_BOUNDARY_PAYLOAD_NOT_ABSOLUTE'
    }
    $payload=[IO.Path]::GetFullPath($RequestedPayload)
    $name=[IO.Path]::GetFileName($payload.TrimEnd([IO.Path]::DirectorySeparatorChar))
    $prefix=if($RequestedMode -ceq 'Install'){'tbme_setup_'}else{'tbme_uninstall_'}
    # Only direct children of this user's default Temp root are trusted. A
    # profile-wide prefix would also accept Downloads or arbitrary subfolders.
    # Nonstandard redirected TEMP locations fail closed (optional sensors degrade).
    $expectedTempParent=[IO.Path]::GetFullPath(
        (Join-Path $profile 'AppData\Local\Temp')
    ).TrimEnd([IO.Path]::DirectorySeparatorChar)
    if(-not [string]::Equals([IO.Path]::GetDirectoryName($payload),
                             $expectedTempParent,[StringComparison]::OrdinalIgnoreCase) -or
       $name -cnotmatch ('^'+$prefix+'[0-9a-f]{32}$')){
        throw 'SENSOR_BOUNDARY_PAYLOAD_OUTSIDE_USER_TEMP'
    }
    $trustedProgramFiles=[Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles)
    if(-not [string]::Equals([IO.Path]::GetFullPath($trustedProgramFiles),
              [IO.Path]::GetFullPath($env:ProgramFiles),[StringComparison]::OrdinalIgnoreCase)){
        throw 'SENSOR_BOUNDARY_PROGRAMFILES_REDIRECT'
    }
    $brokerRoot=Join-Path $trustedProgramFiles 'TaskbarMonitorEnhanced\SensorBroker'
    $candidates=@(
       $profile,$expectedRoot,$payload,$brokerRoot,
       (Join-Path $expectedRoot 'Logs'),
       (Join-Path $expectedRoot 'Logs\sensor_install.log'),
       (Join-Path $expectedRoot 'Logs\sensor_install_result.json'),
       (Join-Path $expectedRoot 'SensorBackend\LibreHardwareMonitor-0.9.6\LibreHardwareMonitorLib.dll'),
       (Join-Path $expectedRoot 'cpu_temp_broker.json'),
       (Join-Path $expectedRoot 'gpu_temp_broker.json'),
       (Join-Path $expectedRoot 'storage_temp_broker.json'),
       (Join-Path $expectedRoot 'sensor_supervisor_state.json'),
       (Join-Path $payload 'TBME_Setup_Elevated_Helper.ps1'),
       (Join-Path $payload 'TaskbarMonitorSensorBroker.exe'),
       (Join-Path $payload 'TaskbarMonitorSensorSupervisor.exe'),
       (Join-Path $payload 'PawnIO_setup.exe'),
       (Join-Path $brokerRoot 'TaskbarMonitorSensorBroker.exe'),
       (Join-Path $brokerRoot 'TaskbarMonitorSensorSupervisor.exe')
    )
    foreach($path in $candidates){Assert-SensorBoundaryNoReparse $path}
    return $sid
}
$validatedSensorSid=Assert-SensorPrivilegedBoundary $Mode $PayloadDir $AppRoot $UserId

$TaskName='TaskbarMonitorEnhanced Sensor Broker'
$BrokerRoot=Join-Path $env:ProgramFiles 'TaskbarMonitorEnhanced\SensorBroker'
$LogsRoot=Join-Path $AppRoot 'Logs'
$ResultPath=Join-Path $LogsRoot 'sensor_install_result.json'
$LogPath=Join-Path $LogsRoot 'sensor_install.log'
New-Item -ItemType Directory -Force -Path $LogsRoot | Out-Null

# R21 health channels are initialized before any early-return/uninstall branch so
# Write-Result can always emit a stable schema under StrictMode.
$SupervisorHealthy=$false
$CpuTransportHealthy=$false
$GpuTransportHealthy=$false
$StorageTransportHealthy=$false
$CpuDataAvailable=$false
$RollbackPerformed=$false
$RollbackSucceeded=$false
$PreviousSensorLayerPresent=$false
$ActiveArchitecture='R21_PROCESS_ISOLATED'
$RollbackRoot=Join-Path $PayloadDir '_sensor_rollback'
$RollbackBrokerRoot=Join-Path $RollbackRoot 'SensorBroker'
$RollbackTaskXml=Join-Path $RollbackRoot 'task.xml'

function Write-Log([string]$Message){
    $line=(Get-Date).ToString('o')+' '+$Message
    $line | Add-Content -LiteralPath $LogPath -Encoding UTF8
}
function Write-Result(
    [string]$Status,
    [string]$Message,
    [string]$PawnStatus,
    [Nullable[int]]$PawnExitCode,
    [bool]$RebootRequired,
    [bool]$TaskInstalled,
    [bool]$SensorHealthy
){
    [ordered]@{
        Status=$Status
        Message=$Message
        PawnIOStatus=$PawnStatus
        PawnIOExitCode=$(if($null -eq $PawnExitCode){$null}else{[int]$PawnExitCode})
        RebootRequired=$RebootRequired
        TaskInstalled=$TaskInstalled
        SensorHealthy=$SensorHealthy
        SupervisorHealthy=$SupervisorHealthy
        CpuTransportHealthy=$CpuTransportHealthy
        GpuTransportHealthy=$GpuTransportHealthy
        StorageTransportHealthy=$StorageTransportHealthy
        CpuDataAvailable=$CpuDataAvailable
        Architecture=$ActiveArchitecture
        RollbackPerformed=$RollbackPerformed
        RollbackSucceeded=$RollbackSucceeded
        PreviousSensorLayerPresent=$PreviousSensorLayerPresent
        Time=(Get-Date).ToString('o')
        LogPath=$LogPath
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ResultPath -Encoding UTF8
}
function Get-PawnIOVersion {
    foreach($key in @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\PawnIO',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\PawnIO'
    )){
        try{
            if(Test-Path -LiteralPath $key){
                $value=(Get-ItemProperty -LiteralPath $key -ErrorAction Stop).DisplayVersion
                if($value){return [string]$value}
            }
        }catch{}
    }
    return ''
}

function Capture-PreviousSensorLayer {
    try{
        Remove-Item -LiteralPath $RollbackRoot -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force -Path $RollbackRoot|Out-Null

        if(Test-Path -LiteralPath $BrokerRoot){
            $script:PreviousSensorLayerPresent=$true
            Copy-Item -LiteralPath $BrokerRoot -Destination $RollbackBrokerRoot -Recurse -Force
        }

        Import-Module ScheduledTasks
        $oldTask=Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if($oldTask){
            $script:PreviousSensorLayerPresent=$true
            Export-ScheduledTask -TaskName $TaskName | Set-Content -LiteralPath $RollbackTaskXml -Encoding Unicode
        }
        Write-Log ("ROLLBACK_CAPTURE_PASS previous="+$PreviousSensorLayerPresent)
        return $true
    }catch{
        Write-Log ('ROLLBACK_CAPTURE_FAIL '+$_.Exception.ToString())
        return $false
    }
}

function Restore-PreviousSensorLayer([string]$Reason){
    $script:RollbackPerformed=$true
    $script:RollbackSucceeded=$false
    try{
        Write-Log ("ROLLBACK_BEGIN reason="+$Reason+" previous="+$PreviousSensorLayerPresent)
        Get-Process TaskbarMonitorSensorSupervisor,TaskbarMonitorSensorBroker -ErrorAction SilentlyContinue |
            Stop-Process -Force -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
        Remove-Item -LiteralPath $BrokerRoot -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $LiveJson,$GpuJson,$StorageJson,$SupervisorState -Force -ErrorAction SilentlyContinue

        if(Test-Path -LiteralPath $RollbackBrokerRoot){
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $BrokerRoot)|Out-Null
            Copy-Item -LiteralPath $RollbackBrokerRoot -Destination $BrokerRoot -Recurse -Force
        }

        if(Test-Path -LiteralPath $RollbackTaskXml){
            $xml=Get-Content -LiteralPath $RollbackTaskXml -Raw
            Register-ScheduledTask -TaskName $TaskName -Xml $xml -Force|Out-Null
            Start-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        }

        $script:ActiveArchitecture=$(if($PreviousSensorLayerPresent){'PREVIOUS_SENSOR_LAYER_RESTORED'}else{'NO_PROTECTED_SENSOR_LAYER'})
        $script:RollbackSucceeded=$true
        Write-Log ("ROLLBACK_PASS architecture="+$ActiveArchitecture)
        return $true
    }catch{
        $script:ActiveArchitecture='ROLLBACK_FAILED'
        Write-Log ('ROLLBACK_FAIL '+$_.Exception.ToString())
        return $false
    }
}

Write-Log "BEGIN mode=$Mode user=$UserId"

# R264-SENSOR-GUARD-BOUNDARY-BEGIN
# Before any shared task/process/file mutation, fail closed if a different
# Windows account owns the fixed legacy machinewide sensor task or processes.
# This is defensive per-account isolation, NOT a machinewide singleton policy.
function Resolve-SensorPrincipalSid([string]$AccountName){
    if([string]::IsNullOrWhiteSpace($AccountName)){throw 'EMPTY_SENSOR_PRINCIPAL'}
    if($AccountName -match '^S-1-5-(?:\d+-)+\d+$'){return $AccountName}
    $account=[Security.Principal.NTAccount]::new($AccountName)
    return [string]$account.Translate([Security.Principal.SecurityIdentifier]).Value
}
function Preserve-OtherUserSensorLayer([string]$Why){
    $script:ActiveArchitecture='SHARED_PROTECTED_SENSOR_LAYER_LEFT_UNTOUCHED'
    Write-Log ('CROSS_USER_SENSOR_SAFETY_REFUSAL reason='+$Why+' mode='+$Mode)
    Write-Result 'DEGRADED_OTHER_USER_SENSOR_LAYER_PRESERVED' ('Protected sensors were not changed: '+$Why+'. The per-user main app remains available with unavailable protected metrics as N/A.') 'NOT_STARTED' $null $false $false $false
    exit 0
}
try{
    $expectedUserSid=Resolve-SensorPrincipalSid $UserId
    Import-Module ScheduledTasks -ErrorAction Stop
    $lookupErrors=@()
    $existing=@(Get-ScheduledTask -TaskPath '\' -TaskName $TaskName -ErrorAction SilentlyContinue -ErrorVariable +lookupErrors |
        Where-Object {$null -ne $_})
    if(@($lookupErrors|Where-Object {$_.CategoryInfo.Category -ne [Management.Automation.ErrorCategory]::ObjectNotFound}).Count){
        throw 'TASK_SCHEDULER_LOOKUP_NOT_TRUSTED'
    }
    if($existing.Count -gt 1){throw 'MULTIPLE_GLOBAL_TASK_MATCHES'}
    if($existing.Count -eq 1){
        $oldSid=Resolve-SensorPrincipalSid ([string]$existing[0].Principal.UserId)
        if($oldSid -cne $expectedUserSid){
            Preserve-OtherUserSensorLayer 'ANOTHER_ACCOUNT_OWNS_GLOBAL_SCHEDULED_TASK'
        }
    }elseif(Test-Path -LiteralPath $BrokerRoot){
        Preserve-OtherUserSensorLayer 'UNOWNED_SHARED_PROGRAMFILES_BROKER_WITHOUT_TASK'
    }
    $sensorProcesses=@(Get-CimInstance Win32_Process -Filter "Name='TaskbarMonitorSensorBroker.exe' OR Name='TaskbarMonitorSensorSupervisor.exe'" -ErrorAction Stop |
       Where-Object {$null -ne $_})
    foreach($proc in $sensorProcesses){
        $owner=Invoke-CimMethod -InputObject $proc -MethodName GetOwnerSid -ErrorAction Stop
        if([int]$owner.ReturnValue -ne 0 -or
            [String]::IsNullOrWhiteSpace([string]$owner.Sid) -or
            [string]$owner.Sid -cne $expectedUserSid){
            Preserve-OtherUserSensorLayer 'SENSOR_PROCESS_OWNER_IS_UNKNOWN_OR_OTHER_ACCOUNT'
        }
    }
}catch{
    Preserve-OtherUserSensorLayer ('UNVERIFIED_MACHINEWIDE_SENSOR_OWNERSHIP_'+$_.Exception.GetType().Name)
}
# R264-SENSOR-GUARD-BOUNDARY-END

if($Mode -eq 'Uninstall'){
    try{
        Get-Process TaskbarMonitorSensorSupervisor,TaskbarMonitorSensorBroker -ErrorAction SilentlyContinue |
            Stop-Process -Force -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $BrokerRoot -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log 'UNINSTALL protected sensor layer removed'
        Write-Result 'UNINSTALLED' 'Protected sensor layer removed.' 'NOT_APPLICABLE' $null $false $false $false
        exit 0
    }catch{
        Write-Log ('UNINSTALL_ERROR '+$_.Exception.ToString())
        Write-Result 'UNINSTALL_WARNING' $_.Exception.Message 'NOT_APPLICABLE' $null $false $false $false
        exit 0
    }
}

# R294: one exclusive read; installed bytes are the same verified buffer.
function Get-VerifiedSensorPayloadBytes([string]$File,[string]$Expected,[long]$MaxBytes){
    if($Expected -cnotmatch '^[A-F0-9]{64}$'){throw 'SENSOR_PAYLOAD_SHA_NOT_PINNED'}
    Assert-SensorBoundaryNoReparse $File
    $stream=[IO.FileStream]::new($File,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None)
    try{
        if($stream.Length -lt 1 -or $stream.Length -gt $MaxBytes){throw 'SENSOR_PAYLOAD_SIZE_INVALID'}
        $buffer=[byte[]]::new([int]$stream.Length)
        $offset=0
        while($offset -lt $buffer.Length){
            $count=$stream.Read($buffer,$offset,$buffer.Length-$offset)
            if($count -le 0){throw 'SENSOR_PAYLOAD_SHORT_READ'}
            $offset+=$count
        }
        $sha=[Security.Cryptography.SHA256]::Create()
        try{$actual=[BitConverter]::ToString($sha.ComputeHash($buffer)).Replace('-','')}
        finally{$sha.Dispose()}
        if($actual -cne $Expected){throw 'SENSOR_PAYLOAD_EMBEDDED_SHA_MISMATCH'}
        return ,$buffer
    }finally{$stream.Dispose()}
}

$BrokerPayload=Join-Path $PayloadDir 'TaskbarMonitorSensorBroker.exe'
$SupervisorPayload=Join-Path $PayloadDir 'TaskbarMonitorSensorSupervisor.exe'
$PawnPayload=Join-Path $PayloadDir 'PawnIO_setup.exe'
$BackendRoot=Join-Path $AppRoot 'SensorBackend\LibreHardwareMonitor-0.9.6'
$LiveJson=Join-Path $AppRoot 'cpu_temp_broker.json'
$GpuJson=Join-Path $AppRoot 'gpu_temp_broker.json'
$StorageJson=Join-Path $AppRoot 'storage_temp_broker.json'
$SupervisorState=Join-Path $AppRoot 'sensor_supervisor_state.json'

$requiredOk=$true
foreach($required in @(
    $BrokerPayload,$SupervisorPayload,
    (Join-Path $BackendRoot 'LibreHardwareMonitorLib.dll')
)){
    if(-not(Test-Path -LiteralPath $required)){
        Write-Log "MISSING_PAYLOAD $required"
        $requiredOk=$false
    }
}
if(-not$requiredOk){
    Write-Result 'DEGRADED' 'Hardware sensor payload is incomplete. The main application can still run; protected temperature fields will show N/A.' 'NOT_STARTED' $null $false $false $false
    exit 0
}

# Public OSS Setup never bundles the separately licensed official PawnIO installer.
# Reuse an already installed compatible PawnIO; otherwise degrade before any service
# mutation, UAC driver installation, network request or host rollback snapshot.
$existingPawn=Get-PawnIOVersion
$pawnAlreadyCompatible=$false
if($existingPawn){
    try{if([version]$existingPawn -ge [version]'2.2.0'){$pawnAlreadyCompatible=$true}}catch{}
}
if(-not $pawnAlreadyCompatible -and !(Test-Path -LiteralPath $PawnPayload -PathType Leaf)){
    $ActiveArchitecture='PAWNIO_EXTERNAL_INSTALL_REQUIRED'
    Write-Log 'PAWNIO_UPSTREAM_EXTERNAL_INSTALL_REQUIRED no bundled proprietary binary and no silent driver download'
    Write-Result 'DEGRADED' ('Optional protected hardware sensors require the official PawnIO 2.2.0 driver, installed separately with user consent from https://github.com/namazso/PawnIO.Setup/releases/tag/2.2.0 . The main application works without it and unavailable temperatures show N/A. No driver or protected sensor service was modified.') 'EXTERNAL_INSTALL_REQUIRED' $null $false $false $false
    exit 0
}

# R294: Verify pinned embedded identity before touching protected services.
try{
    $VerifiedBrokerBytes=Get-VerifiedSensorPayloadBytes $BrokerPayload $ExpectedBrokerSHA256 16777216
    $VerifiedSupervisorBytes=Get-VerifiedSensorPayloadBytes $SupervisorPayload $ExpectedSupervisorSHA256 16777216
}catch{
    Write-Log ('SENSOR_PAYLOAD_PROVENANCE_REFUSED '+$_.Exception.Message)
    Write-Result 'DEGRADED' 'Protected sensor payload provenance not verified; prior service preserved.' 'NOT_STARTED' $null $false $false $false
    exit 0
}
if(-not(Capture-PreviousSensorLayer)){
    $ActiveArchitecture='PREVIOUS_SENSOR_LAYER_UNCHANGED'
    Write-Result 'DEGRADED' 'Setup could not capture a rollback snapshot of the existing protected sensor layer, so it did not modify that layer.' 'NOT_STARTED' $null $false $false $false
    exit 0
}

$pawnStatus='ALREADY_PRESENT'
$pawnExit=$null
$rebootRequired=$false
$installedPawn=Get-PawnIOVersion
$needPawn=$true
if($installedPawn){
    try{
        if([version]$installedPawn -ge [version]'2.2.0'){$needPawn=$false}
    }catch{}
}

if($needPawn){
    $pawnStatus='STARTING'
    Write-Log 'PAWNIO_INSTALL_START timeoutSec=60'
    try{
        $pawnProcess=Start-Process -FilePath $PawnPayload -ArgumentList '-install -silent' -PassThru
        if(-not $pawnProcess.WaitForExit(60000)){
            Write-Log "PAWNIO_TIMEOUT pid=$($pawnProcess.Id)"
            try{Stop-Process -Id $pawnProcess.Id -Force -ErrorAction SilentlyContinue}catch{}
            $pawnStatus='TIMEOUT'
        }else{
            $pawnExit=[int]$pawnProcess.ExitCode
            if($pawnExit -eq 0){
                $pawnStatus='INSTALLED'
                Write-Log 'PAWNIO_INSTALL_PASS exit=0'
            }elseif($pawnExit -eq 3010){
                $pawnStatus='REBOOT_REQUIRED'
                $rebootRequired=$true
                Write-Log 'PAWNIO_INSTALL_REBOOT_REQUIRED exit=3010'
            }else{
                $pawnStatus='FAILED'
                Write-Log "PAWNIO_INSTALL_FAILED exit=$pawnExit"
            }
        }
    }catch{
        $pawnStatus='EXCEPTION'
        Write-Log ('PAWNIO_INSTALL_EXCEPTION '+$_.Exception.ToString())
    }
}else{
    Write-Log "PAWNIO_ALREADY_PRESENT version=$installedPawn"
}

$taskInstalled=$false
try{
    Get-Process TaskbarMonitorSensorSupervisor,TaskbarMonitorSensorBroker -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    $drainDeadline=(Get-Date).AddSeconds(5)
    do{
        Start-Sleep -Milliseconds 250
        $remaining=@(Get-Process TaskbarMonitorSensorSupervisor,TaskbarMonitorSensorBroker -ErrorAction SilentlyContinue)
    }while($remaining.Count -gt 0 -and (Get-Date) -lt $drainDeadline)
    if($remaining.Count -gt 0){
        throw ('SENSOR_PROCESS_DRAIN_FAILED pids='+($remaining.Id -join ','))
    }
    Remove-Item -LiteralPath $LiveJson,$GpuJson,$StorageJson,$SupervisorState -Force -ErrorAction SilentlyContinue

    New-Item -ItemType Directory -Force -Path $BrokerRoot|Out-Null
    [IO.File]::WriteAllBytes((Join-Path $BrokerRoot 'TaskbarMonitorSensorBroker.exe'),$VerifiedBrokerBytes)
    [IO.File]::WriteAllBytes((Join-Path $BrokerRoot 'TaskbarMonitorSensorSupervisor.exe'),$VerifiedSupervisorBytes)

    Get-ChildItem -LiteralPath $BackendRoot -File -Recurse | ForEach-Object {
        $relative=$_.FullName.Substring($BackendRoot.Length).TrimStart('\')
        $destination=Join-Path $BrokerRoot $relative
        $parent=Split-Path -Parent $destination
        if($parent){New-Item -ItemType Directory -Force -Path $parent|Out-Null}
        Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
    }

    Import-Module ScheduledTasks
    $SupervisorExe=Join-Path $BrokerRoot 'TaskbarMonitorSensorSupervisor.exe'
    $BrokerExe=Join-Path $BrokerRoot 'TaskbarMonitorSensorBroker.exe'
    $Action=New-ScheduledTaskAction -Execute $SupervisorExe -Argument ('--broker "'+$BrokerExe+'" --output "'+$LiveJson+'"')
    $Trigger=New-ScheduledTaskTrigger -AtLogOn -User $UserId
    $Principal=New-ScheduledTaskPrincipal -UserId $UserId -LogonType Interactive -RunLevel Highest
    $Settings=New-ScheduledTaskSettingsSet -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force|Out-Null
    Start-ScheduledTask -TaskName $TaskName
    $taskInstalled=$true
    Write-Log 'SUPERVISOR_TASK_INSTALLED_AND_STARTED restartCount=3 restartInterval=PT1M multipleInstances=IgnoreNew'
}catch{
    Write-Log ('SUPERVISOR_TASK_SETUP_WARNING '+$_.Exception.ToString())
    Restore-PreviousSensorLayer 'TASK_SETUP_EXCEPTION'|Out-Null
    $taskInstalled=$false
}

$healthy=$false
$currentC=$null
if($taskInstalled -and -not$rebootRequired){
    for($i=0;$i -lt 90;$i++){
        Start-Sleep -Milliseconds 500
        $task=Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        $supervisor=@(Get-Process TaskbarMonitorSensorSupervisor -ErrorAction SilentlyContinue)

        if($task -and [string]$task.State -eq 'Running' -and $supervisor.Count -eq 1){
            try{
                if(Test-Path -LiteralPath $SupervisorState){
                    $state=Get-Content -LiteralPath $SupervisorState -Raw|ConvertFrom-Json
                    $stateTs=[datetime]::Parse([string]$state.TimestampUtc,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime()
                    $stateAge=([datetime]::UtcNow-$stateTs).TotalSeconds
                    $version=[string]$state.BrokerVersion
                    $supervisorVersion=[string]$state.SupervisorVersion
                    $CpuTransportHealthy=[bool]$state.CpuTransportHealthy
                    $GpuTransportHealthy=[bool]$state.GpuTransportHealthy
                    $StorageTransportHealthy=[bool]$state.StorageTransportHealthy
                    $JobContainmentHealthy=(
                        [bool]$state.ChildJobKillOnClose -and
                        [bool]$state.CpuJobContained -and
                        [bool]$state.GpuJobContained -and
                        [bool]$state.StorageJobContained
                    )
                    $SupervisorHealthy=(
                        $stateAge -ge 0 -and $stateAge -lt 15 -and
                        $version -eq '1.1.2+r21' -and
                        $supervisorVersion -eq '1.3.0+r33' -and
                        $JobContainmentHealthy -and
                        $CpuTransportHealthy -and $GpuTransportHealthy -and $StorageTransportHealthy
                    )
                }
            }catch{
                $SupervisorHealthy=$false
            }

            try{
                if(Test-Path -LiteralPath $LiveJson){
                    $j=Get-Content -LiteralPath $LiveJson -Raw|ConvertFrom-Json
                    $ts=[datetime]::Parse([string]$j.TimestampUtc,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime()
                    $age=([datetime]::UtcNow-$ts).TotalSeconds
                    $sensorName=[string]$j.Sensor
                    $current=[double]$j.CurrentC
                    if([bool]$j.Available -eq $true -and
                       [bool]$j.Is64BitProcess -eq $true -and
                       [bool]$j.IsElevated -eq $true -and
                       -not[String]::IsNullOrWhiteSpace($sensorName) -and
                       $current -gt 0 -and $current -lt 130 -and
                       $age -lt 15){
                        $healthy=$true
                        $CpuDataAvailable=$true
                        $currentC=$current
                    }
                }
            }catch{}

            if($SupervisorHealthy -and $healthy){
                Write-Log ("R33_READY_MATCH supervisor="+$supervisorVersion+" brokerProtocol="+$version+" cpu="+$currentC+" jobContainment="+$JobContainmentHealthy+" cpuTransport="+$CpuTransportHealthy+" gpuTransport="+$GpuTransportHealthy+" storageTransport="+$StorageTransportHealthy)
                break
            }
        }
    }
}

if($taskInstalled -and -not$SupervisorHealthy -and -not$rebootRequired){
    Restore-PreviousSensorLayer 'R21_HEALTH_GATE_FAILED'|Out-Null
    $taskInstalled=$false
}

if($RollbackPerformed){
    if($RollbackSucceeded){
        Write-Log 'R21_INSTALL_DEGRADED_ROLLED_BACK'
        Write-Result 'DEGRADED_ROLLED_BACK' 'R21 protected sensor validation did not pass, so the previous protected sensor layer was restored automatically. The main application remains usable; use Repair protected sensors to retry R21 later.' $pawnStatus $pawnExit $false $false $false
    }else{
        Write-Log 'R21_INSTALL_DEGRADED_ROLLBACK_FAILED'
        Write-Result 'DEGRADED_ROLLBACK_FAILED' 'R21 protected sensor validation did not pass and automatic rollback also failed. The main application remains usable, but protected telemetry requires repair.' $pawnStatus $pawnExit $false $false $false
    }
    exit 0
}

if($SupervisorHealthy -and $healthy){
    Write-Log "R21_SENSOR_READY cpu=$currentC"
    Write-Result 'READY' 'R21 protected sensor supervisor is healthy across CPU, GPU and storage lanes; CPU temperature data is active.' $pawnStatus $pawnExit $false $taskInstalled $true
}elseif($SupervisorHealthy){
    Write-Log 'R21_SENSOR_TRANSPORT_READY_DATA_DEGRADED'
    Write-Result 'DEGRADED_DATA' 'The R21 protected sensor supervisor is healthy across CPU, GPU and storage lanes, but CPU temperature data is not currently available on this machine.' $pawnStatus $pawnExit $false $taskInstalled $false
}elseif($rebootRequired){
    Write-Log 'SENSOR_REBOOT_REQUIRED'
    Write-Result 'REBOOT_REQUIRED' 'The application installed successfully. Restart Windows to finish activating CPU temperature monitoring.' $pawnStatus $pawnExit $true $taskInstalled $false
}elseif($pawnStatus -eq 'TIMEOUT'){
    Write-Log 'SENSOR_DEGRADED pawnio-timeout'
    Write-Result 'DEGRADED' 'The application installed successfully, but the PawnIO driver installer timed out. CPU temperature will show N/A until the sensor layer is repaired.' $pawnStatus $pawnExit $false $taskInstalled $false
}elseif($pawnStatus -eq 'FAILED' -or $pawnStatus -eq 'EXCEPTION'){
    Write-Log "SENSOR_DEGRADED pawnio=$pawnStatus"
    Write-Result 'DEGRADED' 'The application installed successfully, but CPU temperature could not be activated on this machine. Other monitoring features remain available.' $pawnStatus $pawnExit $false $taskInstalled $false
}elseif(-not$taskInstalled){
    Write-Log 'SENSOR_DEGRADED task-not-installed'
    Write-Result 'DEGRADED' 'The application installed successfully, but the protected sensor task could not be created. CPU temperature will show N/A.' $pawnStatus $pawnExit $false $false $false
}else{
    Write-Log ("R21_SUPERVISOR_UNAVAILABLE_AFTER_STARTUP_WINDOW cpuTransport="+$CpuTransportHealthy+" gpuTransport="+$GpuTransportHealthy+" storageTransport="+$StorageTransportHealthy)
    Write-Result 'UNAVAILABLE' 'The application installed successfully, but the R21 protected sensor supervisor did not reach a fresh healthy state across all worker lanes in time. Use Diagnostics > Repair protected sensors.' $pawnStatus $pawnExit $false $taskInstalled $false
}
exit 0
