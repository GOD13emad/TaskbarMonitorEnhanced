[CmdletBinding()]
param([Parameter(Mandatory=$true)][ValidateSet('A','B')][string]$Machine)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($env:GITHUB_ACTIONS -cne 'true' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
   $env:RUNNER_OS -cne 'Windows' -or
   $env:GITHUB_REPOSITORY -cne 'GOD13emad/TaskbarMonitorEnhanced' -or
   $env:GITHUB_REF -cne 'refs/heads/audit/r226-native-settings-foreground' -or
   [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP) -or
   $env:COMPUTERNAME -match '(?i)EMAD|ALI|LAPTOP'){
   throw 'R226_SACRIFICIAL_GITHUB_WINDOWS_ONLY'
}
$expectedMain='5A44490034EB8A8B846FB11E7BD6954EED741F92DB53FC7A568DCCA358A5BCE2'
$source='./build/_out/App/TaskbarMonitorEnhanced.exe'
$dir=Join-Path $env:RUNNER_TEMP ('TBME_R226_SETTINGS_'+$Machine)
$out=Join-Path $dir 'native'
$proof=Join-Path $out 'SETTINGS_NATIVE_FOREGROUND_R121.json'
$receipt=Join-Path $dir 'R226_NATIVE_SETTINGS_RESULT.json'
$stage='PRESTATE';$status='FAIL';$reason='';$exit=$null
$verifierStatus='UNPROVEN';$sourceProofPresent=$false
function Fail([string]$msg){throw ('R226_'+$msg)}
try{
    if(Test-Path -LiteralPath $dir){Fail 'PREVIOUS_TEST_DIR_EXISTS_NO_RERUN'}
    if((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -cne $expectedMain){
        Fail 'BUILT_R223_PRODUCT_SHA_NOT_EXACT'
    }
    if(@(Get-Process TaskbarMonitorEnhanced -ErrorAction SilentlyContinue).Count){
        Fail 'APPLICATION_ALREADY_RUNNING_IN_GUEST'
    }
    # Proof owns the child directory and explicitly refuses any pre-existing output.
    New-Item -ItemType Directory -Path $dir -ErrorAction Stop | Out-Null
    if(Test-Path -LiteralPath $out){Fail 'PROOF_OUTPUT_DIR_ALREADY_EXISTS'}
    $stage='PRODUCTION_TEST_BINARY_NATIVE_REAL_FOREGROUND'
    $si=[Diagnostics.ProcessStartInfo]::new()
    $si.FileName=(Resolve-Path $source).Path
    $si.Arguments=('--settingsforegroundproof "'+$out+'"')
    $si.UseShellExecute=$false
    $si.WorkingDirectory=(Split-Path $si.FileName -Parent)
    $si.CreateNoWindow=$true
    $proc=[Diagnostics.Process]::Start($si)
    if($null -eq $proc){Fail 'PROOF_NOT_LAUNCHED'}
    try{
        if(!$proc.WaitForExit(60000)){
            try{$proc.Kill($true)}catch{}
            Fail 'NATIVE_REAL_FOREGROUND_PROOF_TIMEOUT'
        }
        $exit=$proc.ExitCode
    }finally{$proc.Dispose()}
    $sourceProofPresent=Test-Path -LiteralPath $proof -PathType Leaf
    if($exit -ne 0){Fail ('NATIVE_PROOF_RETURNED_ERROR_'+$exit)}
    if(!$sourceProofPresent){Fail 'NATIVE_SOURCE_PROOF_RECEIPT_MISSING'}
    $stage='INDEPENDENT_NATIVE_WIN32_SCREENSHOT_PIXEL_AND_MUTANT_VV'
    $args=@{
      ManifestPath=$proof
      CandidateMainPath=$source
      ExpectedCommit=$env:GITHUB_SHA
      ExpectedMainSha256=$expectedMain
      SelfTest=$true
    }
    & ./build/Verify-SettingsForeground-R121.ps1 @args
    if($LASTEXITCODE -ne 0){Fail 'NATIVE_INDEPENDENT_VERIFIER_FAILED'}
    $v=Get-Content -LiteralPath $proof -Raw|ConvertFrom-Json
    if($v.Status -cne 'PASS' -or $v.ForegroundIsSettings -ne $true -or
       $v.SettingsTitleHit -ne $true -or
       $v.SettingsVisibleUncloaked -ne $true -or
       $v.RealMouseClickAttempts -lt 1 -or
       $v.RealMouseInputEvents -ne (2*$v.RealMouseClickAttempts)){
        Fail 'SOURCE_NATIVE_FOREGROUND_VV_FLAGS_WRONG'
    }
    $verifierStatus='PASS_INDEPENDENT_PIXELS_AND_FIFTEEN_HOSTILE_MUTANTS_REJECTED'
    $stage='ACCEPTED'
    $status='PASS_DISPOSABLE_R223_NATIVE_SETTINGS_FOREGROUND_OVER_LAYERED_TOPMOST_GLASS'
}catch{
    $reason=$_.Exception.GetType().Name+': '+$_.Exception.Message
}finally{
    if(Test-Path $dir -PathType Container){
        $manifest=$null
        if(Test-Path $proof -PathType Leaf){
           try{$manifest=Get-Content $proof -Raw|ConvertFrom-Json}catch{}
        }
        $result=[ordered]@{
            Revision='R226';Host=$Machine;Status=$status;Phase=$stage;Error=$reason
            GitHubTestCommit=$env:GITHUB_SHA;CandidateMainSHA256=$expectedMain
            CandidateExeNativeProofExitCode=$exit
            NativeProofReceiptPresent=$sourceProofPresent
            NativeProofStatus=if($null -ne $manifest){[string]$manifest.Status}else{'MISSING'}
            SourceScreenshotSHA256=if($null -ne $manifest -and
              $null -ne $manifest.PSObject.Properties['SettingsScreenshotSha256']){
              [string]$manifest.SettingsScreenshotSha256
            }else{'UNPROVEN'}
            IndependentVerifier=$verifierStatus
            NoOwnerPersonalDesktopInput=$true
            NoOwnerInstalledMainOrConfigMutation=$true
            FormalExternalPhysicalLabAccepted=$false
            TimestampUTC=[DateTime]::UtcNow.ToString('o')
        }
        [IO.File]::WriteAllText($receipt,($result|ConvertTo-Json -Depth 8),
             [Text.UTF8Encoding]::new($false))
        Write-Output ($result|ConvertTo-Json -Depth 8 -Compress)
    }
}
if($status -cne 'PASS_DISPOSABLE_R223_NATIVE_SETTINGS_FOREGROUND_OVER_LAYERED_TOPMOST_GLASS'){
    throw ('R226_NATIVE_SETTINGS_NOT_ACCEPTED_'+$stage+' '+$reason)
}
