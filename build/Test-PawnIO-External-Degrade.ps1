# R85 hermetic negative runtime test: a missing proprietary PawnIO binary cannot install
# driver/services or mutate the real host. An isolated copy only mocks the read-only
# PawnIO version discovery function so installed PawnIO on the developer PC is untouched.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$Root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$Helper=Join-Path $Root 'installer\TBME_Setup_Elevated_Helper.ps1'
$Base=Join-Path $Root 'artifacts\_r85_external_degrade_test'
$Payload=Join-Path $Base 'payload'
$App=Join-Path $Base 'local_app'
$Mock=Join-Path $Base 'helper_mocked_pawnio_discovery.ps1'
$Result=Join-Path $App 'Logs\sensor_install_result.json'
$Log=Join-Path $App 'Logs\sensor_install.log'
if(Test-Path -LiteralPath $Base){throw 'R85 UNSAFE FIXTURE REUSE'}
if(!(Test-Path -LiteralPath $Helper -PathType Leaf)){throw 'R85 HELPER MISSING'}
$source=Get-Content -LiteralPath $Helper -Raw
$guardAt=$source.IndexOf('PAWNIO_UPSTREAM_EXTERNAL_INSTALL_REQUIRED',[StringComparison]::Ordinal)
$captureAt=$source.IndexOf('if(-not(Capture-PreviousSensorLayer))',[StringComparison]::Ordinal)
if($guardAt -lt 0 -or $captureAt -le $guardAt){throw 'R85 EARLY DEGRADED GUARD NOT BEFORE SENSOR MUTATION'}
$tok=$null;$errs=$null
$ast=[Management.Automation.Language.Parser]::ParseInput($source,[ref]$tok,[ref]$errs)
if($errs.Count -ne 0){throw 'R85 HELPER HAS PARSER ERRORS'}
$funcs=@($ast.FindAll({param($x) $x -is [Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -ceq 'Get-PawnIOVersion'},$true))
if($funcs.Count -ne 1){throw 'R85 EXACT FUNCTION REPLACEMENT AMBIGUOUS'}
$node=$funcs[0]
$mocked=$source.Substring(0,$node.Extent.StartOffset)+"function Get-PawnIOVersion { return '' }"+$source.Substring($node.Extent.EndOffset)
$done=$false
try {
    New-Item -ItemType Directory -Path $Payload -Force -ErrorAction Stop|Out-Null
    New-Item -ItemType Directory -Path (Join-Path $App 'SensorBackend\LibreHardwareMonitor-0.9.6') -Force -ErrorAction Stop|Out-Null
    [IO.File]::WriteAllBytes((Join-Path $Payload 'TaskbarMonitorSensorBroker.exe'),[byte[]](1,2,3))
    [IO.File]::WriteAllBytes((Join-Path $Payload 'TaskbarMonitorSensorSupervisor.exe'),[byte[]](1,2,3))
    [IO.File]::WriteAllBytes((Join-Path $App 'SensorBackend\LibreHardwareMonitor-0.9.6\LibreHardwareMonitorLib.dll'),[byte[]](1,2,3))
    [IO.File]::WriteAllText($Mock,$mocked,[Text.UTF8Encoding]::new($false))
    $exec=@(& pwsh -NoProfile -File $Mock -Mode Install -PayloadDir $Payload -AppRoot $App -UserId 'R85_TEST_FIXTURE_NO_DRIVER')
    if($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $Result)){throw 'R85 MOCK HOST SENSOR HELPER FAILED'}
    $receipt=Get-Content -LiteralPath $Result -Raw|ConvertFrom-Json
    if($receipt.Status -cne 'DEGRADED' -or
       $receipt.PawnIOStatus -cne 'EXTERNAL_INSTALL_REQUIRED' -or
       $receipt.SensorHealthy -ne $false -or
       $receipt.TaskInstalled -ne $false -or
       $receipt.RebootRequired -ne $false -or
       $receipt.RollbackPerformed -ne $false -or
       $receipt.Architecture -cne 'PAWNIO_EXTERNAL_INSTALL_REQUIRED' -or
       $receipt.Message -notmatch 'https://github.com/namazso/PawnIO.Setup/releases/tag/2.2.0'){
       throw 'R85 MISSING PAWNIO DID NOT FAIL SAFE'
    }
    $lograw=Get-Content -LiteralPath $Log -Raw
    if($lograw -match 'PAWNIO_INSTALL_START|ROLLBACK_CAPTURE|SENSOR_PROCESS_DRAIN|REGISTER_TASK'){throw 'R85 PROTECTED MUTATION WAS ATTEMPTED'}
    $files=@(Get-ChildItem -LiteralPath $Base -Recurse -File)
    $allowed=@(
      'payload\TaskbarMonitorSensorBroker.exe','payload\TaskbarMonitorSensorSupervisor.exe',
      'local_app\SensorBackend\LibreHardwareMonitor-0.9.6\LibreHardwareMonitorLib.dll',
      'local_app\Logs\sensor_install_result.json','local_app\Logs\sensor_install.log',
      'helper_mocked_pawnio_discovery.ps1')
    if($files.Count -ne $allowed.Count -or @($files|Where-Object {$_.FullName.Substring($Base.Length+1) -notin $allowed}).Count -ne 0){throw 'R85 UNKNOWN FIXTURE FILES'}
    Write-Output 'R85_MISSING_PAWNIO_DEGRADED_FAIL_CLOSED_NO_DRIVER_INSTALL_NO_ROLLBACK_NO_OS_CHANGE=PASS'
    $done=$true
} finally {
    if($done){
        # Only this preflight-owned, exact-path fixture tree is removed.
        Remove-Item -LiteralPath $Base -Recurse -Force -ErrorAction Stop
        if(Test-Path -LiteralPath $Base){throw 'R85 FIXTURE CLEANUP FAILED'}
    }else{
        Write-Warning ('R85 TEST FAILED; exact diagnostic fixture preserved at '+$Base)
    }
}
exit 0
