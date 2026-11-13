# R85 hermetic negative runtime test: missing external PawnIO must degrade before any sensor mutation.
# Uses the exact canonical LocalAppData AppRoot and exact private Setup Temp child required by the production Helper.
# It refuses to run if a real app root/task already exists; CI uses a fresh disposable Windows account.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$Root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$Helper=Join-Path $Root 'installer\TBME_Setup_Elevated_Helper.ps1'
if($env:GITHUB_ACTIONS -cne 'true' -or
   $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
   $env:RUNNER_OS -cne 'Windows' -or
   $env:GITHUB_REPOSITORY -cne 'GOD13emad/TaskbarMonitorEnhanced'){
    throw 'R85_DISPOSABLE_GITHUB_HOSTED_WINDOWS_REQUIRED'
}
# This test creates the canonical AppRoot and Setup Temp child, so it is
# restricted to a fresh GitHub-hosted Windows runner, never a developer PC.
$Fixture=Join-Path $Root 'artifacts\_r85_external_degrade_test'
$Profile=[IO.Path]::GetFullPath([Environment]::GetFolderPath('UserProfile')).TrimEnd('\')
$Local=[IO.Path]::GetFullPath([Environment]::GetFolderPath('LocalApplicationData')).TrimEnd('\')
$ExpectedLocal=[IO.Path]::GetFullPath((Join-Path $Profile 'AppData\Local')).TrimEnd('\')
if(-not [string]::Equals($Local,$ExpectedLocal,[StringComparison]::OrdinalIgnoreCase)){
    throw 'R85_TEST_REQUIRES_CANONICAL_LOCALAPPDATA'
}
$App=Join-Path $Local 'TaskbarMonitorEnhanced'
$TempRoot=Join-Path $Local 'Temp'
$Payload=Join-Path $TempRoot ('tbme_setup_'+[guid]::NewGuid().ToString('N'))
$Mock=Join-Path $Fixture 'helper_mocked_pawnio_discovery.ps1'
$Result=Join-Path $App 'Logs\sensor_install_result.json'
$Log=Join-Path $App 'Logs\sensor_install.log'
if(Test-Path -LiteralPath $Fixture){throw 'R85_UNSAFE_FIXTURE_REUSE'}
if(Test-Path -LiteralPath $App){throw 'R85_CANONICAL_APP_ROOT_ALREADY_EXISTS_REFUSE_OWNER_DATA'}
if(Test-Path -LiteralPath $Payload){throw 'R85_PRIVATE_PAYLOAD_COLLISION'}
if(!(Test-Path -LiteralPath $TempRoot -PathType Container)){throw 'R85_CANONICAL_TEMP_ROOT_MISSING'}
if(!(Test-Path -LiteralPath $Helper -PathType Leaf)){throw 'R85_HELPER_MISSING'}

$source=Get-Content -LiteralPath $Helper -Raw
# The helper has a separate Uninstall snapshot call before the Install branch.
# Scope the static ordering check to Install, avoiding a false match in Uninstall.
$installAt=$source.IndexOf('$existingPawn=Get-PawnIOVersion',[StringComparison]::Ordinal)
if($installAt -lt 0){throw 'R85_INSTALL_ENTRYPOINT_NOT_FOUND'}
$guardAt=$source.IndexOf('PAWNIO_UPSTREAM_EXTERNAL_INSTALL_REQUIRED',$installAt,[StringComparison]::Ordinal)
$captureAt=$source.IndexOf('if(-not(Capture-PreviousSensorLayer))',$installAt,[StringComparison]::Ordinal)
if($guardAt -lt $installAt -or $captureAt -le $guardAt){throw 'R85_INSTALL_GUARD_NOT_BEFORE_SENSOR_MUTATION'}

$tok=$null;$errs=$null
$ast=[Management.Automation.Language.Parser]::ParseInput($source,[ref]$tok,[ref]$errs)
if($errs.Count -ne 0){throw 'R85_HELPER_HAS_PARSER_ERRORS'}
$funcs=@($ast.FindAll({param($x) $x -is [Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -ceq 'Get-PawnIOVersion'},$true))
if($funcs.Count -ne 1){throw 'R85_EXACT_FUNCTION_REPLACEMENT_AMBIGUOUS'}
$node=$funcs[0]
$mocked=$source.Substring(0,$node.Extent.StartOffset)+"function Get-PawnIOVersion { return '' }"+$source.Substring($node.Extent.EndOffset)
$done=$false
try {
    [void][IO.Directory]::CreateDirectory($Fixture)
    [void][IO.Directory]::CreateDirectory($Payload)
    [void][IO.Directory]::CreateDirectory((Join-Path $App 'SensorBackend\LibreHardwareMonitor-0.9.6'))
    [IO.File]::WriteAllBytes((Join-Path $Payload 'TaskbarMonitorSensorBroker.exe'),[byte[]](1,2,3))
    [IO.File]::WriteAllBytes((Join-Path $Payload 'TaskbarMonitorSensorSupervisor.exe'),[byte[]](1,2,3))
    $backend=Join-Path $App 'SensorBackend\LibreHardwareMonitor-0.9.6\LibreHardwareMonitorLib.dll'
    [IO.File]::WriteAllBytes($backend,[byte[]](1,2,3))
    [IO.File]::WriteAllText($Mock,$mocked,[Text.UTF8Encoding]::new($false))
    $payloadHashes=@{}
    foreach($name in @('TaskbarMonitorSensorBroker.exe','TaskbarMonitorSensorSupervisor.exe')){
        $payloadHashes[$name]=(Get-FileHash (Join-Path $Payload $name) -Algorithm SHA256).Hash
    }
    $backendHash=(Get-FileHash $backend -Algorithm SHA256).Hash
    $exec=@(& pwsh -NoProfile -File $Mock -Mode Install -PayloadDir $Payload -AppRoot $App -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name))
    if($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $Result)){throw 'R85_MOCK_HOST_SENSOR_HELPER_FAILED'}
    $receipt=Get-Content -LiteralPath $Result -Raw|ConvertFrom-Json
    if($receipt.Status -cne 'DEGRADED' -or
       $receipt.PawnIOStatus -cne 'EXTERNAL_INSTALL_REQUIRED' -or
       $receipt.SensorHealthy -ne $false -or
       $receipt.TaskInstalled -ne $false -or
       $receipt.RebootRequired -ne $false -or
       $receipt.RollbackPerformed -ne $false -or
       $receipt.Architecture -cne 'PAWNIO_EXTERNAL_INSTALL_REQUIRED' -or
       $receipt.Message -notmatch 'https://github.com/namazso/PawnIO.Setup/releases/tag/2.2.0'){
        throw 'R85_MISSING_PAWNIO_DID_NOT_FAIL_SAFE'
    }
    $lograw=Get-Content -LiteralPath $Log -Raw
    if($lograw -match 'PAWNIO_INSTALL_START|ROLLBACK_CAPTURE|SENSOR_PROCESS_DRAIN|REGISTER_TASK'){
        throw 'R85_PROTECTED_MUTATION_WAS_ATTEMPTED'
    }
    foreach($name in $payloadHashes.Keys){
        if((Get-FileHash (Join-Path $Payload $name) -Algorithm SHA256).Hash -cne $payloadHashes[$name]){
            throw ('R85_PAYLOAD_CANARY_CHANGED_'+$name)
        }
    }
    if((Get-FileHash $backend -Algorithm SHA256).Hash -cne $backendHash){throw 'R85_BACKEND_CANARY_CHANGED'}
    $appFiles=@(Get-ChildItem -LiteralPath $App -Force -Recurse -File)
    $appAllowed=@(
      'SensorBackend\LibreHardwareMonitor-0.9.6\LibreHardwareMonitorLib.dll',
      'Logs\sensor_install_result.json','Logs\sensor_install.log'
    )
    if($appFiles.Count -ne $appAllowed.Count -or
       @($appFiles|Where-Object {$_.FullName.Substring($App.Length+1) -notin $appAllowed}).Count -ne 0){
        throw 'R85_UNKNOWN_APP_FIXTURE_FILES'
    }
    $payloadFiles=@(Get-ChildItem -LiteralPath $Payload -Force -File)
    $payloadAllowed=@('TaskbarMonitorSensorBroker.exe','TaskbarMonitorSensorSupervisor.exe')
    if($payloadFiles.Count -ne $payloadAllowed.Count -or
       @($payloadFiles|Where-Object {$_.Name -notin $payloadAllowed}).Count -ne 0){
        throw 'R85_UNKNOWN_PAYLOAD_FIXTURE_FILES'
    }
    $fixtureFiles=@(Get-ChildItem -LiteralPath $Fixture -Force -File)
    if($fixtureFiles.Count -ne 1 -or $fixtureFiles[0].Name -cne 'helper_mocked_pawnio_discovery.ps1'){
        throw 'R85_UNKNOWN_FIXTURE_FILES'
    }
    Write-Output 'R85_MISSING_PAWNIO_DEGRADED_FAIL_CLOSED_NO_DRIVER_INSTALL_NO_ROLLBACK_NO_OS_CHANGE=PASS'
    $done=$true
} finally {
    if($done){
        foreach($path in @($App,$Payload,$Fixture)){
            if(Test-Path -LiteralPath $path){
                $tree=@(Get-ChildItem -LiteralPath $path -Force -Recurse)
                foreach($entry in $tree){
                    if(($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){
                        throw 'R85_CLEANUP_REFUSED_REPARSE_CHILD'
                    }
                }
                $attributes=[IO.File]::GetAttributes($path)
                if(($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){
                    throw 'R85_CLEANUP_REFUSED_REPARSE_ROOT'
                }
                [IO.Directory]::Delete($path,$true)
                if(Test-Path -LiteralPath $path){throw 'R85_FIXTURE_CLEANUP_FAILED'}
            }
        }
    }else{
        Write-Warning ('R85 TEST FAILED; exact diagnostic fixtures preserved. App='+$App+' Payload='+$Payload+' Fixture='+$Fixture)
    }
}
exit 0
