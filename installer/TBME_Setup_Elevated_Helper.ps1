param(
    [Parameter(Mandatory=$true)][ValidateSet('Install','Uninstall')][string]$Mode,
    [Parameter(Mandatory=$true)][string]$PayloadDir,
    [Parameter(Mandatory=$true)][string]$AppRoot,
    [Parameter(Mandatory=$true)][string]$UserId
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

$TaskName='TaskbarMonitorEnhanced Sensor Broker'
$BrokerRoot=Join-Path $env:ProgramFiles 'TaskbarMonitorEnhanced\SensorBroker'
$LogsRoot=Join-Path $AppRoot 'Logs'
$ResultPath=Join-Path $LogsRoot 'sensor_install_result.json'
$LogPath=Join-Path $LogsRoot 'sensor_install.log'
New-Item -ItemType Directory -Force -Path $LogsRoot | Out-Null

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

Write-Log "BEGIN mode=$Mode user=$UserId"

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

$BrokerPayload=Join-Path $PayloadDir 'TaskbarMonitorSensorBroker.exe'
$SupervisorPayload=Join-Path $PayloadDir 'TaskbarMonitorSensorSupervisor.exe'
$PawnPayload=Join-Path $PayloadDir 'PawnIO_setup.exe'
$BackendRoot=Join-Path $AppRoot 'SensorBackend\LibreHardwareMonitor-0.9.6'
$LiveJson=Join-Path $AppRoot 'cpu_temp_broker.json'

$requiredOk=$true
foreach($required in @(
    $BrokerPayload,$SupervisorPayload,$PawnPayload,
    (Join-Path $BackendRoot 'LibreHardwareMonitorLib.dll')
)){
    if(-not(Test-Path -LiteralPath $required)){
        Write-Log "MISSING_PAYLOAD $required"
        $requiredOk=$false
    }
}
if(-not$requiredOk){
    Write-Result 'DEGRADED' 'Hardware sensor payload is incomplete. The main application can still run; CPU temperature will show N/A.' 'NOT_STARTED' $null $false $false $false
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
    Start-Sleep -Milliseconds 600

    New-Item -ItemType Directory -Force -Path $BrokerRoot|Out-Null
    Copy-Item -LiteralPath $BrokerPayload -Destination (Join-Path $BrokerRoot 'TaskbarMonitorSensorBroker.exe') -Force
    Copy-Item -LiteralPath $SupervisorPayload -Destination (Join-Path $BrokerRoot 'TaskbarMonitorSensorSupervisor.exe') -Force

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
    $Settings=New-ScheduledTaskSettingsSet -RestartCount 99 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero) -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force|Out-Null
    Start-ScheduledTask -TaskName $TaskName
    $taskInstalled=$true
    Write-Log 'SUPERVISOR_TASK_INSTALLED_AND_STARTED'
}catch{
    Write-Log ('SUPERVISOR_TASK_SETUP_WARNING '+$_.Exception.ToString())
}

$healthy=$false
$currentC=$null
if($taskInstalled -and -not$rebootRequired){
    for($i=0;$i -lt 60;$i++){
        Start-Sleep -Milliseconds 500
        $task=Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        $supervisor=@(Get-Process TaskbarMonitorSensorSupervisor -ErrorAction SilentlyContinue)
        if($task -and [string]$task.State -eq 'Running' -and $supervisor.Count -eq 1 -and (Test-Path -LiteralPath $LiveJson)){
            try{
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
                    $currentC=$current
                    Write-Log ("SENSOR_READY_MATCH sensor='"+$sensorName+"' cpu="+$current+" ageSec="+[math]::Round($age,2))
                    break
                }
            }catch{}
        }
    }
}

if($healthy){
    Write-Log "SENSOR_READY cpu=$currentC"
    Write-Result 'READY' 'CPU temperature sensor is active and reporting fresh data.' $pawnStatus $pawnExit $false $taskInstalled $true
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
    Write-Log 'SENSOR_UNAVAILABLE_AFTER_STARTUP_WINDOW'
    Write-Result 'UNAVAILABLE' 'The application installed successfully. The CPU sensor did not become ready in time and will show N/A for now.' $pawnStatus $pawnExit $false $taskInstalled $false
}
exit 0
