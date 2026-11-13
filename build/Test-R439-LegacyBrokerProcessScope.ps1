[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$SupervisorPath)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -cne 'Desktop'){throw 'R439_REQUIRES_WINPS51'}
$compiled=(Resolve-Path -LiteralPath $SupervisorPath).Path
$assembly=[Reflection.Assembly]::LoadFrom($compiled)
$type=$assembly.GetType('TaskbarMonitorSensorSupervisor',$true)
$flags=[Reflection.BindingFlags]'NonPublic,Static'
$test=$type.GetMethod('IsManagedLegacyBrokerIdentity',$flags)
if(!$test){throw 'R439_COMPILED_LEGACY_BROKER_IDENTITY_GUARD_MISSING'}
$trusted='C:\Program Files\TaskbarMonitorEnhanced\SensorBroker\TaskbarMonitorSensorBroker.exe'
$foreign='C:\Other\TaskbarMonitorSensorBroker.exe'
$cases=@(
    @{Label='exact same-session';Path=$trusted;Session=4;Expected=$true},
    @{Label='case-insensitive same-session';Path=$trusted.ToUpperInvariant();Session=4;Expected=$true},
    @{Label='normalized same-session';Path='C:\Program Files\TaskbarMonitorEnhanced\SensorBroker\..\SensorBroker\TaskbarMonitorSensorBroker.exe';Session=4;Expected=$true},
    @{Label='other session same protected exe';Path=$trusted;Session=5;Expected=$false},
    @{Label='different same-named executable';Path=$foreign;Session=4;Expected=$false},
    @{Label='different executable basename';Path='C:\Program Files\TaskbarMonitorEnhanced\SensorBroker\Other.exe';Session=4;Expected=$false},
    @{Label='different protected subtree';Path='C:\Program Files\Other\SensorBroker\TaskbarMonitorSensorBroker.exe';Session=4;Expected=$false},
    @{Label='empty path';Path='';Session=4;Expected=$false},
    @{Label='UNC origin';Path='\\server\share\TaskbarMonitorSensorBroker.exe';Session=4;Expected=$false},
    @{Label='invalid quoted path';Path='"C:\Program Files\TaskbarMonitorEnhanced\SensorBroker\TaskbarMonitorSensorBroker.exe"';Session=4;Expected=$false}
)
foreach($c in $cases){
    $result=[bool]$test.Invoke($null,[object[]]@([string]$c.Path,[int]$c.Session,[string]$trusted,[int]4))
    if($result -ne [bool]$c.Expected){throw ('R439_IDENTITY_WRONG_'+$c.Label)}
}
# An unavailable image path must not become a match even when session matches.
if([bool]$test.Invoke($null,[object[]]@($null,[int]4,[string]$trusted,[int]4))){
    throw 'R439_NULL_IMAGE_ACCEPTED'
}
'R439_PASS_COMPILED_EXACT_IMAGE_AND_SESSION_SCOPE_11_CASES'
# Exercise the real stop loop against two harmless, same-named processes.
# Redirect the compiled Supervisor's static BrokerPath only inside this WinPS test process;
# the user's installed Supervisor and its running Brokers are not modified.
$managed=$type.GetMethod('IsManagedLegacyBroker',$flags)
$stop=$type.GetMethod('StopExistingBrokers',$flags)
$remain=$type.GetMethod('LegacyBrokerProcessesRemain',$flags)
$brokerField=$type.GetField('BrokerPath',$flags)
if(!$managed -or !$stop -or !$remain -or !$brokerField){
    throw 'R439_LIVE_COMPILED_GUARDS_MISSING'
}
$liveRoot=Join-Path ([IO.Path]::GetTempPath()) ('tbme-r439-'+[Guid]::NewGuid().ToString('N'))
$trustedProcess=$null
$foreignProcess=$null
$originalBrokerPath=[string]$brokerField.GetValue($null)
try {
    $trustedDir=Join-Path $liveRoot 'trusted'
    $foreignDir=Join-Path $liveRoot 'foreign'
    New-Item -ItemType Directory -Path $trustedDir,$foreignDir -Force | Out-Null
    $trustedExe=Join-Path $trustedDir 'TaskbarMonitorSensorBroker.exe'
    $foreignExe=Join-Path $foreignDir 'TaskbarMonitorSensorBroker.exe'
    $fixtureSource=@'
using System;
using System.Threading;
public static class R439BrokerFixture {
    public static int Main(string[] args) {
        Thread.Sleep(30000);
        return 0;
    }
}
'@
    Add-Type -TypeDefinition $fixtureSource -OutputAssembly $trustedExe -OutputType ConsoleApplication -ErrorAction Stop
    Copy-Item -LiteralPath $trustedExe -Destination $foreignExe -ErrorAction Stop
    $trustedProcess=Start-Process -FilePath $trustedExe -PassThru -WindowStyle Hidden
    $foreignProcess=Start-Process -FilePath $foreignExe -PassThru -WindowStyle Hidden
    for($attempt=0;$attempt -lt 40;$attempt++){
        $trustedProcess.Refresh()
        $foreignProcess.Refresh()
        if($trustedProcess.HasExited -or $foreignProcess.HasExited){
            throw 'R439_LIVE_FIXTURE_EXITED_PREMATURELY'
        }
        $seen=Get-Process -Name 'TaskbarMonitorSensorBroker' -ErrorAction SilentlyContinue |
            Where-Object {$_.Id -eq $trustedProcess.Id -or $_.Id -eq $foreignProcess.Id}
        if(@($seen).Count -eq 2){break}
        Start-Sleep -Milliseconds 100
    }
    $brokerField.SetValue($null,$trustedExe)
    if(-not [bool]$managed.Invoke($null,[object[]]@([System.Diagnostics.Process]$trustedProcess))){
        throw 'R439_TRUSTED_LIVE_PROCESS_REJECTED'
    }
    if([bool]$managed.Invoke($null,[object[]]@([System.Diagnostics.Process]$foreignProcess))){
        throw 'R439_FOREIGN_LIVE_PROCESS_ACCEPTED'
    }
    $drained=[bool]$stop.Invoke($null,[object[]]@())
    if(!$drained){throw 'R439_TRUSTED_LIVE_DRAIN_FAILED'}
    if(!$trustedProcess.WaitForExit(3000)){throw 'R439_TRUSTED_LIVE_PROCESS_SURVIVED'}
    $foreignProcess.Refresh()
    if($foreignProcess.HasExited){throw 'R439_FOREIGN_LIVE_PROCESS_KILLED'}
    if([bool]$remain.Invoke($null,[object[]]@())){
        throw 'R439_FOREIGN_LIVE_PROCESS_BLOCKED_REMAINING_CHECK'
    }
    'R439_PASS_LIVE_TRUSTED_DRAIN_FOREIGN_SAME_NAME_SURVIVES'
}
finally {
    $brokerField.SetValue($null,$originalBrokerPath)
    foreach($p in @($trustedProcess,$foreignProcess)){
        if($null -eq $p){continue}
        try {if(!$p.HasExited){$p.Kill();$null=$p.WaitForExit(3000)}}catch{}
        try {$p.Dispose()}catch{}
    }
    if(Test-Path -LiteralPath $liveRoot){
        Remove-Item -LiteralPath $liveRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
