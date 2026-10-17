# R85 disposable GitHub Windows negative runtime test: absent PawnIO must degrade
# without privileged driver/service mutation. Use a profile-canonical guest AppRoot
# because the real R291 elevated-helper boundary must not be bypassed in tests.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
# Never write even a test config to a real owner's user profile.
if($env:GITHUB_ACTIONS -cne 'true' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
   $env:RUNNER_OS -cne 'Windows' -or $env:COMPUTERNAME -match '(?i)EMAD-PC' -or
   [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)){throw 'R85_ONLY_DISPOSABLE_GITHUB_WINDOWS'}
$Root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$Helper=Join-Path $Root 'installer\TBME_Setup_Elevated_Helper.ps1'
$Base=Join-Path $Root 'artifacts\_r85_external_degrade_test'
$Payload=Join-Path ([IO.Path]::GetTempPath()) ('tbme_setup_'+[guid]::NewGuid().ToString('N'))
$App=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'TaskbarMonitorEnhanced'
$Mock=Join-Path $Base 'helper_mocked_pawnio_discovery.ps1'
$Result=Join-Path $App 'Logs\sensor_install_result.json'
$Log=Join-Path $App 'Logs\sensor_install.log'
if((Test-Path -LiteralPath $Base) -or (Test-Path -LiteralPath $Payload) -or
   (Test-Path -LiteralPath $App)){throw 'R85 GUEST_FIXTURE_COLLISION_NO_USER_DATA_TOUCH'}
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
    $exec=@(& pwsh -NoProfile -File $Mock -Mode Install -PayloadDir $Payload -AppRoot $App -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name))
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
    $files=@(Get-ChildItem -LiteralPath $Base -Recurse -File) +
           @(Get-ChildItem -LiteralPath $Payload -Recurse -File) +
           @(Get-ChildItem -LiteralPath $App -Recurse -File)
    $allowed=@(
      $Mock,
      (Join-Path $Payload 'TaskbarMonitorSensorBroker.exe'),
      (Join-Path $Payload 'TaskbarMonitorSensorSupervisor.exe'),
      (Join-Path $App 'SensorBackend\LibreHardwareMonitor-0.9.6\LibreHardwareMonitorLib.dll'),
      $Result,$Log
    )
    $observed=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($file in $files){[void]$observed.Add([IO.Path]::GetFullPath($file.FullName))}
    if($files.Count -ne 6 -or $observed.Count -ne 6 -or $allowed.Count -ne 6){
      throw 'R85 UNEXPECTED_DISPOSABLE_GUEST_FIXTURE_FILE_COUNT'
    }
    foreach($expected in $allowed){
      if(-not $observed.Contains([IO.Path]::GetFullPath($expected))){throw 'R85 UNSAFE_OR_MISSING_FIXTURE_FILE'}
    }
    Write-Output 'R85_MISSING_PAWNIO_DEGRADED_FAIL_CLOSED_NO_DRIVER_INSTALL_NO_ROLLBACK_NO_OS_CHANGE=PASS'
    $done=$true
} finally {
    if($done){
        # Three exact guest fixture roots were absent before the test.
        foreach($owned in @($Payload,$App,$Base)){
          Remove-Item -LiteralPath $owned -Recurse -Force -ErrorAction Stop
          if(Test-Path -LiteralPath $owned){throw 'R85 GUEST FIXTURE CLEANUP FAILED'}
        }
    }else{
        Write-Warning ('R85 GUEST FAILURE: fixtures preserved in '+$Base+' ; '+$Payload+' ; '+$App)
    }
}
exit 0
