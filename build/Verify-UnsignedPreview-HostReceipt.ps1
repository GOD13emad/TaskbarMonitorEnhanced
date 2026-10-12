# R88-F05: independent, pure/read-only hosted installation receipt verifier.
# Prevents copy/paste hash typos, case-insensitive variable shadowing and false Stable claims.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ReceiptPath,
    [Parameter(Mandatory=$true)][string]$ExpectedTestCommit,
    [switch]$SelfTest
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$ExpectedTag='v1.7.0-unsigned-preview.1'
$ExpectedSource='eeac48c2ff201326c6a59e7ccc21c72c9a676160'
$ExpectedSetupSHA256='9A1B4F81C07CC39E3D5A329E89EFD834A9DFDC3D7BB6CF12812AC7C300E6B104'
$ExpectedMainSHA256='63A724981E949BA4C91F8BD44F2659F223BDFE0350A2E229CEE7B05535D4BA70'
$ExpectedConfigSHA256='D2E51872D93F0793C02AD07DCBF8C2802F59708C666548372A4FDDDA5C7C5E4F'
if($ExpectedTestCommit -cnotmatch '^[a-f0-9]{40}$'){throw 'R88 VALIDATOR COMMIT IS NOT EXACT 40-CHAR GIT HEX'}
foreach($digest in @($ExpectedSetupSHA256,$ExpectedMainSHA256,$ExpectedConfigSHA256)){
    if($digest -cnotmatch '^[A-F0-9]{64}$'){throw 'R88 VALIDATOR HASH CONSTANT CORRUPTED'}
}
function Validate-HostedReceipt {
    param([Parameter(Mandatory=$true)][psobject]$Record,[Parameter(Mandatory=$true)][string]$Commit)
    $issues=[Collections.Generic.List[string]]::new()
    $required=@(
        'Schema','Revision','Status','HostRole','EventCommit','PublicTag','ReleaseId',
        'ReleasedSource','ActualTagSource','PublishedSetupSHA256','InstalledMainSHA256',
        'InstalledConfigSHA256','SignatureStatus','InstallExitCode','InstallStatus',
        'UninstallExitCode','UninstallStatus','SensorStatus','WallpaperBefore',
        'RealInteractiveG13','RealInteractiveG14EightProbes','FullSignedStableAccepted',
        'HeadlessSubsetOnly','Failure','StartedUTC','FinishedUTC'
    )
    foreach($key in $required){
        if($null -eq $Record.PSObject.Properties[$key]){$issues.Add('MISSING_'+$key)}
    }
    if($issues.Count -gt 0){return $issues.ToArray()}
    if($Record.Schema -ne 1 -or $Record.Revision -cne 'R88'){$issues.Add('SCHEMA_REVISION')}
    if($Record.Status -cne 'PASS_EPHEMERAL_HEADLESS_INSTALL_UNINSTALL'){$issues.Add('NOT_SUCCESS')}
    if($Record.HostRole -cne 'GITHUB_HOSTED_EPHEMERAL_WINDOWS'){$issues.Add('UNAUTHORIZED_HOST')}
    if($Record.EventCommit -cne $Commit){$issues.Add('CI_TEST_COMMIT_DRIFT')}
    if($Record.PublicTag -isnot [string]){$issues.Add('TAG_NOT_STRING')}
    elseif($Record.PublicTag -cne $ExpectedTag){$issues.Add('TAG_VALUE')}
    if($Record.ReleaseId -ne 409785885 -or
       $Record.ReleasedSource -cne $ExpectedSource -or
       $Record.ActualTagSource -cne $ExpectedSource){$issues.Add('RELEASE_ORIGIN')}
    if($Record.PublishedSetupSHA256 -cne $ExpectedSetupSHA256){$issues.Add('SETUP_SHA')}
    if($Record.InstalledMainSHA256 -cne $ExpectedMainSHA256){$issues.Add('MAIN_SHA')}
    if($Record.InstalledConfigSHA256 -cne $ExpectedConfigSHA256){$issues.Add('CONFIG_SHA')}
    if($Record.SignatureStatus -cne 'NotSigned'){$issues.Add('MISREPRESENTED_PUBLIC_SIGNATURE')}
    if($Record.InstallExitCode -ne 0 -or
       $Record.InstallStatus -cne 'PASS_HEADLESS_INSTALLED_EXACT_SHA_STATE_AND_SHORTCUT'){$issues.Add('INSTALL_FAILURE')}
    if($Record.UninstallExitCode -ne 0 -or
       $Record.UninstallStatus -cne 'PASS_HEADLESS_UNINSTALL_PRODUCT_STATE_REMOVED'){$issues.Add('UNINSTALL_FAILURE')}
    if($Record.SensorStatus -cne 'DEGRADED'){$issues.Add('SENSOR_UNEXPECTED_CLAIM')}
    if($Record.RealInteractiveG13 -cne 'NOT_TESTED' -or
       $Record.RealInteractiveG14EightProbes -cne 'NOT_TESTED'){$issues.Add('FALSE_FULL_G13_G14')}
    if($Record.FullSignedStableAccepted -ne $false -or
       $Record.HeadlessSubsetOnly -ne $true){$issues.Add('FALSE_STABLE_ACCEPTANCE')}
    if($Record.Failure -isnot [string] -or -not [string]::IsNullOrEmpty([string]$Record.Failure)){$issues.Add('FAILED_RECEIPT')}
    $start=[datetimeoffset]::MinValue
    $finish=[datetimeoffset]::MinValue
    if(![datetimeoffset]::TryParse([string]$Record.StartedUTC,[ref]$start) -or
       ![datetimeoffset]::TryParse([string]$Record.FinishedUTC,[ref]$finish) -or
       $finish -lt $start){$issues.Add('INVALID_TIMELINE')}
    return $issues.ToArray()
}
if(!(Test-Path -LiteralPath $ReceiptPath -PathType Leaf)){throw 'R88 ACTUAL HOSTED RECEIPT NOT FOUND'}
$raw=Get-Content -LiteralPath $ReceiptPath -Raw -ErrorAction Stop
$actual=$raw|ConvertFrom-Json -ErrorAction Stop
$failures=@(Validate-HostedReceipt -Record $actual -Commit $ExpectedTestCommit)
if($failures.Count -ne 0){throw ('R88 HOSTED RECEIPT REFUSED: '+($failures -join ','))}
if($SelfTest){
    $cases=@(
        @{Name='BAD_TAG_OBJECT';Field='PublicTag';Value=[pscustomobject]@{ref='refs/tags/v1.7.0-unsigned-preview.1'}},
        @{Name='TRUNCATED_CONFIG_HASH';Field='InstalledConfigSHA256';Value='D2E51872D93F0793C02AD07DCBF8C2802F59708C666548372A4FDDDA5C7E4F'},
        @{Name='WRONG_MAIN_HASH';Field='InstalledMainSHA256';Value=('0'*64)},
        @{Name='FALSE_STABLE';Field='FullSignedStableAccepted';Value=$true},
        @{Name='FALSE_INTERACTIVE';Field='RealInteractiveG14EightProbes';Value='PASS'},
        @{Name='INSTALL_FAILED';Field='InstallExitCode';Value=1},
        @{Name='PROVENANCE_ERROR';Field='EventCommit';Value=('0'*40)},
        @{Name='WRONG_ORIGIN';Field='HostRole';Value='EMAD-PC-ULTIMAT'}
    )
    foreach($scenario in $cases){
        $fixture=$raw|ConvertFrom-Json
        $fixture.($scenario.Field)=$scenario.Value
        $rejected=@(Validate-HostedReceipt -Record $fixture -Commit $ExpectedTestCommit)
        if($rejected.Count -eq 0){throw ('R88 NEGATIVE REGRESSION FALSE PASS: '+$scenario.Name)}
    }
    Write-Output 'R88_INDEPENDENT_RECEIPT_NEGATIVE_TESTS_8_OF_8_PASS'
}
Write-Output ('R88_INDEPENDENT_ACTUAL_HOST_RECEIPT_PASS SHA256='+
    (Get-FileHash -LiteralPath $ReceiptPath).Hash+
    ' TEST_COMMIT='+$ExpectedTestCommit+
    ' INSTALL=0 UNINSTALL=0 SIG=NotSigned FULL_G14=NOT_TESTED')
exit 0
