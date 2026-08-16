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

function Get-PawnIOVersion {
    foreach($key in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\PawnIO','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\PawnIO')){
        try{if(Test-Path -LiteralPath $key){$value=(Get-ItemProperty -LiteralPath $key -ErrorAction Stop).DisplayVersion;if($value){return [string]$value}}}catch{}
    }
    return ''
}

if($Mode -eq 'Uninstall'){
    Get-Process TaskbarMonitorSensorSupervisor,TaskbarMonitorSensorBroker -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $BrokerRoot -Recurse -Force -ErrorAction SilentlyContinue
    exit 0
}

$BrokerPayload=Join-Path $PayloadDir 'TaskbarMonitorSensorBroker.exe'
$SupervisorPayload=Join-Path $PayloadDir 'TaskbarMonitorSensorSupervisor.exe'
$PawnPayload=Join-Path $PayloadDir 'PawnIO_setup.exe'
$BackendRoot=Join-Path $AppRoot 'SensorBackend\LibreHardwareMonitor-0.9.6'
$LiveJson=Join-Path $AppRoot 'cpu_temp_broker.json'
foreach($required in @($BrokerPayload,$SupervisorPayload,$PawnPayload,(Join-Path $BackendRoot 'LibreHardwareMonitorLib.dll'))){if(-not(Test-Path -LiteralPath $required)){throw "PROTECTED_PAYLOAD_GATE $required"}}

$installedPawn=Get-PawnIOVersion
$needPawn=$true
if($installedPawn){try{if([version]$installedPawn -ge [version]'2.2.0'){$needPawn=$false}}catch{}}
if($needPawn){$pawnProcess=Start-Process -FilePath $PawnPayload -ArgumentList '-install -silent' -Wait -PassThru;if($pawnProcess.ExitCode -ne 0 -and $pawnProcess.ExitCode -ne 3010){throw "PAWNIO_INSTALL_GATE exit=$($pawnProcess.ExitCode)"}}

Get-Process TaskbarMonitorSensorSupervisor,TaskbarMonitorSensorBroker -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 600
New-Item -ItemType Directory -Force -Path $BrokerRoot|Out-Null
Copy-Item -LiteralPath $BrokerPayload -Destination (Join-Path $BrokerRoot 'TaskbarMonitorSensorBroker.exe') -Force
Copy-Item -LiteralPath $SupervisorPayload -Destination (Join-Path $BrokerRoot 'TaskbarMonitorSensorSupervisor.exe') -Force
Get-ChildItem -LiteralPath $BackendRoot -File -Recurse | ForEach-Object {$relative=$_.FullName.Substring($BackendRoot.Length).TrimStart('\');$destination=Join-Path $BrokerRoot $relative;$parent=Split-Path -Parent $destination;if($parent){New-Item -ItemType Directory -Force -Path $parent|Out-Null};Copy-Item -LiteralPath $_.FullName -Destination $destination -Force}

Import-Module ScheduledTasks
$SupervisorExe=Join-Path $BrokerRoot 'TaskbarMonitorSensorSupervisor.exe'
$BrokerExe=Join-Path $BrokerRoot 'TaskbarMonitorSensorBroker.exe'
$Action=New-ScheduledTaskAction -Execute $SupervisorExe -Argument ('--broker "'+$BrokerExe+'" --output "'+$LiveJson+'"')
$Trigger=New-ScheduledTaskTrigger -AtLogOn -User $UserId
$Principal=New-ScheduledTaskPrincipal -UserId $UserId -LogonType Interactive -RunLevel Highest
$Settings=New-ScheduledTaskSettingsSet -RestartCount 99 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero) -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force|Out-Null
Start-ScheduledTask -TaskName $TaskName

$healthy=$false
for($i=0;$i -lt 90;$i++){
    Start-Sleep -Milliseconds 500
    $task=Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    $supervisor=@(Get-Process TaskbarMonitorSensorSupervisor -ErrorAction SilentlyContinue)
    if($task -and [string]$task.State -eq 'Running' -and $supervisor.Count -eq 1 -and (Test-Path -LiteralPath $LiveJson)){
        try{$j=Get-Content -LiteralPath $LiveJson -Raw|ConvertFrom-Json;$ts=[datetime]::Parse([string]$j.TimestampUtc,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime();$age=([datetime]::UtcNow-$ts).TotalSeconds;if([bool]$j.Available -eq $true -and [bool]$j.Is64BitProcess -eq $true -and [bool]$j.IsElevated -eq $true -and [string]$j.Sensor -eq 'CPU Package' -and $age -lt 15){$healthy=$true;break}}catch{}
    }
}
if(-not$healthy){throw 'PROTECTED_SENSOR_STARTUP_GATE'}
exit 0
