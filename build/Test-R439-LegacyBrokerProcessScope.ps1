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
'R439_PASS_FOREIGN_SAME_NAME_DENIED_NO_PROCESS_TERMINATION'
