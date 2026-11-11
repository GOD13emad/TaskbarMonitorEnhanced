[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$AppPath,
    [Parameter(Mandatory=$true)][string]$SourceRoot,
    [switch]$HostedGuest
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($PSVersionTable.PSEdition -cne 'Desktop'){throw 'R401_REQUIRES_WINDOWS_POWERSHELL_51'}
if($HostedGuest -and ($env:GITHUB_ACTIONS -cne 'true' -or
    $env:RUNNER_OS -cne 'Windows' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted')){
    throw 'R401_REQUIRES_DISPOSABLE_WINDOWS_RUNNER'
}
$root=(Resolve-Path -LiteralPath $SourceRoot).Path
$app=(Resolve-Path -LiteralPath $AppPath).Path
$expected=Join-Path $root 'build\_out\App\TaskbarMonitorEnhanced.exe'
if(![string]::Equals($app,$expected,[StringComparison]::OrdinalIgnoreCase)){
    throw 'R401_NOT_EXACT_BUILD_OUTPUT'
}
$source=[IO.File]::ReadAllText((Join-Path $root 'src\TaskbarGlass.cs'))
foreach($needle in @(
    'ShouldRepairMissingTopmost(',
    'EnsureTopLevelGlassStyles("VISIBLE_TOPMOST_LOSS",true)',
    'presentationLastOcclusionRepairUtc=now',
    'TASKBAR_VISIBLE_TOPMOST_DRIFT_REPAIRED',
    'if(!recoveryPending)ScheduleRecovery("VISIBLE_TOPMOST_REPAIR_FAILED",250)'
)){
    if(!$source.Contains($needle)){throw ('R401_SOURCE_REPAIR_GUARD_MISSING_'+$needle)}
}
$asm=[Reflection.Assembly]::LoadFrom($app)
$type=$asm.GetType('TaskbarMonitorEnhanced.TaskbarPresentationPolicy',$true)
$method=$type.GetMethod('ShouldRepairMissingTopmost',[Reflection.BindingFlags]'Static,NonPublic,Public')
if(!$method -or $method.GetParameters().Length -ne 5){
    throw 'R401_COMPILED_NATIVE_POLICY_NOT_PRESENT'
}
function Invoke-Decision([bool]$glass,[bool]$visible,[bool]$shell,[bool]$dialog,[long]$style){
    $argsToInvoke=New-Object 'object[]' 5
    $argsToInvoke[0]=$glass;$argsToInvoke[1]=$visible
    $argsToInvoke[2]=$shell;$argsToInvoke[3]=$dialog
    $argsToInvoke[4]=$style
    return [bool]$method.Invoke($null,$argsToInvoke)
}
$ordinary=([long]0x08090080)
$topmost=$ordinary -bor 8L
if(!(Invoke-Decision $true $true $false $false $ordinary)){
    throw 'R401_NATIVE_DRIFT_MUST_REQUEST_REPAIR'
}
'R401_PASS_MISSING_TOPMOST_REQUIRES_REPAIR_AFTER_VISIBLE'
if(Invoke-Decision $true $true $false $false $topmost){
    throw 'R401_NATIVE_ALREADY_TOPMOST_MUST_NOT_RESTACK'
}
'R401_PASS_HEALTHY_TOPMOST_NO_PERPETUAL_RESTACK'
if(Invoke-Decision $true $false $false $false $ordinary){
    throw 'R401_MUST_NOT_RESTACK_FULLSCREEN_OR_HIDDEN'
}
'R401_PASS_FULLSCREEN_AND_HIDDEN_DO_NOT_RESTACK'
if(Invoke-Decision $true $true $true $false $ordinary){
    throw 'R401_MUST_NOT_RESTACK_WHILE_START_OPEN'
}
'R401_PASS_START_SHELL_NOT_RESTACKED'
if(Invoke-Decision $true $true $false $true $ordinary){
    throw 'R401_MUST_NOT_RESTACK_SETTINGS_DIALOG'
}
'R401_PASS_SETTINGS_AND_MENU_NOT_RESTACKED'
if(Invoke-Decision $false $true $false $false $ordinary){
    throw 'R401_MUST_NOT_RESTACK_CHILD_WINDOW'
}
'R401_PASS_CHILD_MODE_NOT_RESTACKED'
if(Invoke-Decision $false $false $true $true $topmost){
    throw 'R401_ALL_GUARDS_FALSE_EXPECTED'
}
'R401_PASS_BOUNDARY_MATRIX_NO_UNCONDITIONAL_TOPMOST_TIMER'
'R401_PASS_NO_REAL_TASKBAR_OR_OWNER_PROCESS_TOUCHED'
'R401_RESULT=PASS_COMPILED_VISIBLE_TOPMOST_DRIFT_POLICY_ONLY'
