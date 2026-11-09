[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateSet('A','B')][string]$HostLabel,
    [Parameter(Mandatory=$true)][string]$SourceRoot
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$SourceRoot=[IO.Path]::GetFullPath($SourceRoot)
if($PSVersionTable.PSEdition -cne 'Desktop' -or
   $env:GITHUB_ACTIONS -cne 'true' -or
   $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
   $env:RUNNER_OS -cne 'Windows' -or
   $env:GITHUB_REPOSITORY -cne 'GOD13emad/TaskbarMonitorEnhanced' -or
   $env:GITHUB_REF -cne 'refs/heads/security/r347-r349-helper-hardening-v1710' -or
   $env:COMPUTERNAME -match '(?i)EMAD-PC|ALIEMAD|SAEID|LAPTOP' -or
   $env:GITHUB_RUN_ID -cnotmatch '^[0-9]{5,20}$' -or
   $env:GITHUB_SHA -cnotmatch '^[0-9a-f]{40}$' -or
   (git -C $SourceRoot rev-parse HEAD).Trim() -cne $env:GITHUB_SHA){
    throw 'R358_REFUSE_NONDISPOSABLE_OR_WRONG_GIT_SOURCE'
}
$setup=Join-Path $SourceRoot 'build\_out\Setup\TaskbarMonitorEnhanced_Setup_1.7.10.exe'
$manifestPath=Join-Path $SourceRoot 'artifacts\BUILD_MANIFEST.json'
$helperSource=Join-Path $SourceRoot 'installer\TBME_Setup_Elevated_Helper.ps1'
$native=Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe'
if(-not [IO.File]::Exists($setup) -or -not [IO.File]::Exists($manifestPath) -or -not [IO.File]::Exists($helperSource) -or -not [IO.File]::Exists($native)){
    throw 'R358_EXACT_SETUP_MANIFEST_OR_NATIVE_POWERSHELL_MISSING'
}
$manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
$manifestSetup=@($manifest.Outputs|Where-Object{$_.Name -ceq [IO.Path]::GetFileName($setup)})
if($manifestSetup.Count -ne 1){throw 'R358_SETUP_MANIFEST_ENTRY_MISSING_OR_DUPLICATE'}
$runId=$env:GITHUB_RUN_ID
$fixtureId=[guid]::NewGuid().ToString('N')
$tempRoot=[IO.Path]::GetFullPath($env:RUNNER_TEMP)
$root=Join-Path $tempRoot ('R358_'+$HostLabel+'_'+$runId+'_'+$fixtureId)
$receipt=Join-Path $tempRoot ('R358_'+$HostLabel+'_'+$runId+'.json')
if([IO.Directory]::Exists($root) -or [IO.File]::Exists($receipt)){
    throw 'R358_FIXTURE_OR_RECEIPT_COLLISION'
}
$checks=[Collections.Generic.List[string]]::new()
$failure=''
$launch=$null
$rogue=$null
$legit=$null
$createdRoot=$false
$setupHash=(Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash.ToUpperInvariant()
if(([string]$manifestSetup[0].SHA256).ToUpperInvariant() -cne $setupHash -or [long]$manifestSetup[0].Bytes -ne (Get-Item -LiteralPath $setup).Length){
    throw 'R358_SETUP_BYTES_DO_NOT_MATCH_BUILD_MANIFEST'
}
$sourceHash=(Get-FileHash -LiteralPath $helperSource -Algorithm SHA256).Hash.ToUpperInvariant()
$embeddedHash=''
$compactHash=''
$pipeHash=''
$pipeName=''
$packedBytes=0
$rogueResult=''
$legitResult=$null
function Check([string]$name){
    $script:checks.Add($name)
    Write-Output ('PASS '+$name)
}
function Start-Client([string]$Mode,[string]$ScriptPath,[string]$Pipe,[string]$Base,[string]$Delay,[string]$ExpectedPipe,[string]$ExpectedCompact){
    $psi=[Diagnostics.ProcessStartInfo]::new()
    $psi.FileName=$native
    $psi.Arguments='-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$ScriptPath+'"'
    $psi.WorkingDirectory=$Base
    $psi.UseShellExecute=$false
    $psi.CreateNoWindow=$true
    $psi.EnvironmentVariables['TBME_R358_MODE']=$Mode
    $psi.EnvironmentVariables['TBME_R358_PIPE']=$Pipe
    $psi.EnvironmentVariables['TBME_R358_BASE']=$Base
    $psi.EnvironmentVariables['TBME_R358_DELAY']=$Delay
    $psi.EnvironmentVariables['TBME_R358_EXPECTED_PIPE_SHA']=$ExpectedPipe
    $psi.EnvironmentVariables['TBME_R358_EXPECTED_COMPACT_SHA']=$ExpectedCompact
    return [Diagnostics.Process]::Start($psi)
}
try{
    [void][IO.Directory]::CreateDirectory($root);$createdRoot=$true
    $asm=[Reflection.Assembly]::LoadFrom((Resolve-Path -LiteralPath $setup).Path)
    $resource=$asm.GetManifestResourceStream('Payload.TBME_Setup_Elevated_Helper.ps1')
    if($null -eq $resource){throw 'R358_SETUP_EMBEDDED_HELPER_RESOURCE_MISSING'}
    $reader=[IO.StreamReader]::new($resource,[Text.Encoding]::UTF8)
    try{$embedded=$reader.ReadToEnd()}finally{$reader.Dispose()}
    $normalize={param([string]$v) $v.Replace(([string][char]13+[string][char]10),[string][char]10).TrimStart([char]0xFEFF).TrimEnd()}
    $source=[IO.File]::ReadAllText($helperSource)
    if((& $normalize $embedded) -cne (& $normalize $source)){
        throw 'R358_SETUP_EMBEDDED_HELPER_NOT_SOURCE_EXACT'
    }
    $embeddedSha=[Security.Cryptography.SHA256]::Create()
    try{$embeddedHash=([BitConverter]::ToString($embeddedSha.ComputeHash([Text.Encoding]::UTF8.GetBytes($embedded))).Replace('-',''))}finally{$embeddedSha.Dispose()}
    Check 'EXACT_SETUP_PE_EMBEDS_CURRENT_HELPER_SOURCE'

    $setupType=$asm.GetType('SetupProgram',$true)
    $flags=[Reflection.BindingFlags]'Static,NonPublic'
    $compactMethod=$setupType.GetMethod('CompactTrustedHelperSource',$flags)
    $buildMethod=$setupType.GetMethod('BuildElevatedSensorLaunch',$flags)
    if(!$compactMethod -or !$buildMethod){throw 'R358_REAL_SETUP_PIPE_METHODS_MISSING'}
    $compact=[string]$compactMethod.Invoke($null,[object[]]@($embedded))
    if([string]::IsNullOrWhiteSpace($compact) -or $compact.Length -ge $embedded.Length){
        throw 'R358_HELPER_COMPACTION_NOT_BOUNDED'
    }
    $tokens=$null;$parseErrors=$null
    [System.Management.Automation.Language.Parser]::ParseInput($compact,[ref]$tokens,[ref]$parseErrors)|Out-Null
    if($parseErrors.Count){throw ('R358_COMPACTED_HELPER_PARSE_FAILED_'+$parseErrors[0].Message)}
    $compactStream=[IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes($compact))
    try{$compactHash=(Get-FileHash -InputStream $compactStream -Algorithm SHA256).Hash.ToUpperInvariant()}finally{$compactStream.Dispose()}
    Check 'REAL_SETUP_COMPACTOR_OUTPUT_PARSES_AS_WINDOWS_POWERSHELL_51'

    $payload=Join-Path $root ('tbme_setup_'+$fixtureId)
    [void][IO.Directory]::CreateDirectory($payload)
    $appRoot=Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)) 'TaskbarMonitorEnhanced'
    $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $launch=$buildMethod.Invoke($null,[object[]]@('Install',$payload,$appRoot,$sid))
    if($null -eq $launch){throw 'R358_REAL_SETUP_LAUNCH_OBJECT_NULL'}
    $pipeName=[string]$launch.PipeName
    $pipeHash=[string]$launch.HelperSHA256
    $packedBytes=[int]$launch.CompressedHelperBytes
    $processInfo=$launch.ProcessInfo
    if($pipeName -cnotmatch '^TBME_SensorHelper_[0-9a-f]{32}$' -or
       $pipeHash -cnotmatch '^[0-9A-F]{64}$' -or
       $packedBytes -lt 1000 -or $packedBytes -gt 120000){
        throw 'R358_PIPE_NAME_HASH_OR_SIZE_NOT_BOUNDED'
    }
    $expectedPowerShell=[IO.Path]::GetFullPath($native)
    if(-not [string]::Equals([IO.Path]::GetFullPath($processInfo.FileName),$expectedPowerShell,[StringComparison]::OrdinalIgnoreCase) -or
       -not $processInfo.UseShellExecute -or $processInfo.Verb -cne 'runas' -or
       $processInfo.Arguments -notmatch '^-NoProfile -NonInteractive -WindowStyle Hidden -EncodedCommand [A-Za-z0-9+/=]+$'){
        throw 'R358_ELEVATED_BOOTSTRAP_PROCESS_INFO_UNEXPECTED'
    }
    Check 'REAL_SETUP_BUILD_LAUNCH_CREATES_BOUNDED_RANDOM_PIPE_AND_SYSTEM_POWERSHELL_RUNAS_BOOTSTRAP'

    $clientScript=Join-Path $root 'R358_PipeClient.ps1'
    $clientSource=@'
$ErrorActionPreference='Stop'
$mode=$env:TBME_R358_MODE
$pipeName=$env:TBME_R358_PIPE
$base=$env:TBME_R358_BASE
$delay=[int]$env:TBME_R358_DELAY
$pipe=$null
$connected=$false
try{
    if($delay -gt 0){Start-Sleep -Milliseconds $delay}
    $pipe=[IO.Pipes.NamedPipeClientStream]::new('.',$pipeName,[IO.Pipes.PipeDirection]::In)
    if($mode -ceq 'rogue'){
        [IO.File]::WriteAllText((Join-Path $base 'rogue-ready.txt'),'READY')
    }
    $pipe.Connect(15000)
    $connected=$true
    if($mode -ceq 'rogue'){
        [IO.File]::WriteAllText((Join-Path $base 'rogue-connected.txt'),'CONNECTED')
        $one=New-Object byte[] 1
        try{$n=$pipe.Read($one,0,1)}catch{$n=0}
        if($n -eq 0){
            [IO.File]::WriteAllText((Join-Path $base 'rogue-result.txt'),'NO_DATA_AFTER_PID_REJECTION')
            exit 0
        }
        [IO.File]::WriteAllText((Join-Path $base 'rogue-result.txt'),'UNEXPECTED_PIPE_DATA')
        exit 41
    }
    if($mode -cne 'legit'){throw 'R358_CLIENT_MODE_INVALID'}
    $header=New-Object byte[] 4
    $offset=0
    while($offset -lt 4){
        $n=$pipe.Read($header,$offset,4-$offset)
        if($n -le 0){throw 'R358_PIPE_HEADER_EOF'}
        $offset+=$n
    }
    $length=[BitConverter]::ToInt32($header,0)
    if($length -lt 1000 -or $length -gt 120000){throw 'R358_PIPE_LENGTH_INVALID'}
    $blob=New-Object byte[] $length
    $offset=0
    while($offset -lt $length){
        $n=$pipe.Read($blob,$offset,$length-$offset)
        if($n -le 0){throw 'R358_PIPE_BODY_EOF'}
        $offset+=$n
    }
    $sha=[Security.Cryptography.SHA256]::Create()
    try{$actual=([BitConverter]::ToString($sha.ComputeHash($blob))).Replace('-','')}finally{$sha.Dispose()}
    if($actual -cne $env:TBME_R358_EXPECTED_PIPE_SHA){throw 'R358_COMPRESSED_PIPE_SHA256_MISMATCH'}
    $memory=[IO.MemoryStream]::new($blob)
    $gzip=[IO.Compression.GZipStream]::new($memory,[IO.Compression.CompressionMode]::Decompress)
    $reader=[IO.StreamReader]::new($gzip,[Text.Encoding]::UTF8)
    try{$code=$reader.ReadToEnd()}finally{$reader.Dispose();$gzip.Dispose();$memory.Dispose()}
    $codeBytes=[Text.Encoding]::UTF8.GetBytes($code)
    $codeSha=[Security.Cryptography.SHA256]::Create()
    try{$actualCode=([BitConverter]::ToString($codeSha.ComputeHash($codeBytes))).Replace('-','')}finally{$codeSha.Dispose()}
    if($actualCode -cne $env:TBME_R358_EXPECTED_COMPACT_SHA){throw 'R358_DECOMPRESSED_HELPER_SHA256_MISMATCH'}
    $tokens=$null;$errors=$null
    [System.Management.Automation.Language.Parser]::ParseInput($code,[ref]$tokens,[ref]$errors)|Out-Null
    if($errors.Count){throw ('R358_DECOMPRESSED_HELPER_PARSE_FAILED_'+$errors[0].Message)}
    $result=[ordered]@{
        Status='PASS'
        Connected=$true
        CompressedSHA256=$actual
        DecompressedSHA256=$actualCode
        DecompressedBytes=$codeBytes.Length
        Parsed=$true
        ContainsNativeTreeLease=$code.Contains('TBMEProtectedBrokerTreeLease')
    }
    [IO.File]::WriteAllText((Join-Path $base 'legit-result.json'),($result|ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false))
    exit 0
}catch{
    $message=$_.Exception.ToString()
    try{[IO.File]::WriteAllText((Join-Path $base ($mode+'-error.txt')),$message,[Text.UTF8Encoding]::new($false))}catch{}
    exit 42
}finally{
    if($pipe){$pipe.Dispose()}
}
'@
    [IO.File]::WriteAllText($clientScript,$clientSource,[Text.UTF8Encoding]::new($false))

    $rogue=Start-Client 'rogue' $clientScript $pipeName $root '0' '' ''
    $readyDeadline=[datetime]::UtcNow.AddSeconds(8)
    while(-not [IO.File]::Exists((Join-Path $root 'rogue-ready.txt')) -and [datetime]::UtcNow -lt $readyDeadline){
        Start-Sleep -Milliseconds 25
        if($rogue.HasExited){throw 'R358_ROGUE_CLIENT_EXITED_BEFORE_READY'}
    }
    if(-not [IO.File]::Exists((Join-Path $root 'rogue-ready.txt'))){throw 'R358_ROGUE_CLIENT_READY_TIMEOUT'}
    # The rogue client is queued first. SendTo must reject its PID,
    # disconnect it without disclosing one byte, then accept the intended child.
    $legit=Start-Client 'legit' $clientScript $pipeName $root '5000' $pipeHash $compactHash
    $sendMethod=$launch.GetType().GetMethod('SendTo',[Reflection.BindingFlags]'Instance,Public')
    if(!$sendMethod){throw 'R358_REAL_SETUP_SEND_METHOD_MISSING'}
    $sendMethod.Invoke($launch,[object[]]@($legit,20000))|Out-Null
    if(-not $legit.WaitForExit(20000)){try{$legit.Kill()}catch{};throw 'R358_LEGITIMATE_PIPE_CLIENT_TIMEOUT'}
    if(-not $rogue.WaitForExit(5000)){try{$rogue.Kill()}catch{};throw 'R358_ROGUE_PIPE_CLIENT_NOT_DISCONNECTED'}
    if($legit.ExitCode -ne 0){throw ('R358_LEGITIMATE_CLIENT_EXIT_'+$legit.ExitCode)}
    if($rogue.ExitCode -ne 0){throw ('R358_ROGUE_CLIENT_EXIT_'+$rogue.ExitCode)}
    if(-not [IO.File]::Exists((Join-Path $root 'rogue-connected.txt'))){throw 'R358_ROGUE_CLIENT_NEVER_CONNECTED'}
    $rogueResult=[IO.File]::ReadAllText((Join-Path $root 'rogue-result.txt'))
    if($rogueResult -cne 'NO_DATA_AFTER_PID_REJECTION'){throw 'R358_WRONG_PID_CLIENT_RECEIVED_DATA'}
    $legitResult=Get-Content -LiteralPath (Join-Path $root 'legit-result.json') -Raw|ConvertFrom-Json
    if($legitResult.Status -cne 'PASS' -or -not $legitResult.Connected -or
       $legitResult.CompressedSHA256 -cne $pipeHash -or
       $legitResult.DecompressedSHA256 -cne $compactHash -or
       -not $legitResult.Parsed -or -not $legitResult.ContainsNativeTreeLease){
        throw 'R358_PIPE_RECEIPT_CONTENT_OR_HASH_INVALID'
    }
    Check 'WRONG_PID_PIPE_CLIENT_REJECTED_WITHOUT_RECEIVING_PAYLOAD'
    Check 'INTENDED_CHILD_RECEIVES_EXACT_SHA256_PINNED_GZIP_HELPER_AND_PARSES'
    Check 'PIPE_DELIVERY_COMPLETES_WITHOUT_ELEVATION_OR_PRODUCT_MUTATION'
}catch{
    $failure=$_.Exception.ToString()
    Write-Output ('FAIL R358 '+$failure)
}finally{
    foreach($p in @($rogue,$legit)){
        if($null -ne $p){
            try{if(-not $p.HasExited){$p.Kill();$p.WaitForExit(3000)}}catch{}
            try{$p.Dispose()}catch{}
        }
    }
    if($launch){
        try{$launch.Dispose()}catch{}
    }
    if($createdRoot -and [IO.Directory]::Exists($root)){
        try{Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction Stop}catch{if(-not $failure){$failure='R358_FIXTURE_CLEANUP_FAILED_'+$_.Exception.Message}}
    }
}
$receiptObject=[ordered]@{
    Schema=1
    Revision='R358'
    Host=$HostLabel
    Commit=$env:GITHUB_SHA
    SetupSHA256=$setupHash
    HelperSourceSHA256=$sourceHash
    EmbeddedHelperSHA256=$embeddedHash
    CompactedHelperSHA256=$compactHash
    CompressedHelperSHA256=$pipeHash
    CompressedBytes=$packedBytes
    RogueClientResult=$rogueResult
    LegitimateClientResult=$legitResult
    Checks=@($checks)
    UACActuallyInvoked=$false
    ProductInstallOrMutationPerformed=$false
    Status=if([string]::IsNullOrEmpty($failure)){'PASS'}else{'FAIL'}
    Failure=$failure
    GeneratedUtc=[datetime]::UtcNow.ToString('o')
}
[IO.File]::WriteAllText($receipt,($receiptObject|ConvertTo-Json -Depth 8)+[Environment]::NewLine,[Text.UTF8Encoding]::new($false))
if($failure){throw $failure}
Write-Output ('R358_NATIVE_STATUS=PASS CHECKS='+$checks.Count+' SETUP_SHA256='+$setupHash)
Write-Output ('R358_RECEIPT='+$receipt)
