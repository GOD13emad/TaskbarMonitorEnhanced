[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$AppPath,
    [Parameter(Mandatory=$true)][string]$SourceRoot,
    [switch]$HostedGuest
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($PSVersionTable.PSEdition -cne 'Desktop'){throw 'R400_REQUIRES_WINDOWS_POWERSHELL_51'}
if($HostedGuest -and ($env:GITHUB_ACTIONS -cne 'true' -or
    $env:RUNNER_OS -cne 'Windows' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted')){
    throw 'R400_REQUIRES_DISPOSABLE_WINDOWS_RUNNER'
}
$root=(Resolve-Path -LiteralPath $SourceRoot).Path
$app=(Resolve-Path -LiteralPath $AppPath).Path
$expectedApp=Join-Path $root 'build\_out\App\TaskbarMonitorEnhanced.exe'
if(![string]::Equals($app,$expectedApp,[StringComparison]::OrdinalIgnoreCase)){
    throw 'R400_APP_NOT_EXACT_BUILD_OUTPUT'
}
$source=[IO.File]::ReadAllText((Join-Path $root 'src\TaskbarMonitorEnhanced.cs'))
foreach($guard in @(
    'FileMode.CreateNew',
    'WriteVerifiedUpdateStaging(stream,partial,info.SetupDigest)',
    'Guid.NewGuid().ToString("N")+".download"',
    'RejectUpdateReparseAncestors(partial)'
)){
    if(!$source.Contains($guard)){throw ('R400_SOURCE_GUARD_MISSING_'+$guard)}
}
$asm=[Reflection.Assembly]::LoadFrom($app)
$type=$asm.GetType('TaskbarMonitorEnhanced.UpdateManager',$true)
$flags=[Reflection.BindingFlags]'Static,NonPublic,Public'
$method=$type.GetMethod('WriteVerifiedUpdateStaging',$flags)
if(!$method -or $method.GetParameters().Length -ne 3){
    throw 'R400_COMPILED_VERIFIED_STAGING_MISSING'
}
function Stage([byte[]]$data,[string]$dest,[string]$digest){
    $stream=[IO.MemoryStream]::new($data,$false)
    try{
        $argsToCall=New-Object 'object[]' 3
        $argsToCall[0]=$stream
        $argsToCall[1]=[string]$dest
        $argsToCall[2]=[string]$digest
        try{
            $value=[string]$method.Invoke($null,$argsToCall)
            return [pscustomobject]@{Actual=$value;Error='';Message=''}
        }catch{
            $err=$_.Exception
            while($err.InnerException){$err=$err.InnerException}
            return [pscustomobject]@{Actual='';Error=$err.GetType().Name;Message=$err.Message}
        }
    }finally{$stream.Dispose()}
}
$fixture=Join-Path $env:TEMP ('tbme-r400-native-'+[Guid]::NewGuid().ToString('N'))
if([IO.Directory]::Exists($fixture)){throw 'R400_FIXTURE_COLLISION'}
$canary=Join-Path $fixture 'OUTSIDE_CANARY.bin'
$link=Join-Path $fixture 'alias-junction'
[void][IO.Directory]::CreateDirectory($fixture)
try{
    $data=New-Object byte[] 65536
    for($i=0;$i -lt $data.Length;$i++){$data[$i]=[byte](($i*7+17)%251)}
    $sha=[Security.Cryptography.SHA256]::Create()
    try{$digest=([BitConverter]::ToString($sha.ComputeHash($data))).Replace('-','')}finally{$sha.Dispose()}
    $spec='sha256:'+$digest
    $good=Join-Path $fixture 'trusted-payload.download'
    $ok=Stage $data $good $spec
    if($ok.Error -or $ok.Actual -cne $digest -or
       (Get-FileHash -LiteralPath $good -Algorithm SHA256).Hash -cne $digest){
        throw ('R400_GOOD_VERIFIED_STAGING_FAILED_'+$ok.Error)
    }
    'R400_PASS_COMPILED_CREATE_NEW_VERIFIED_STREAM_AND_DIGEST'
    $collision=Stage $data $good $spec
    if($collision.Error -cne 'IOException' -or
       (Get-FileHash -LiteralPath $good -Algorithm SHA256).Hash -cne $digest){
        throw 'R400_EXISTING_FILE_OVERWRITTEN'
    }
    'R400_PASS_EXISTING_STAGING_NEVER_TRUNCATED'

    [IO.File]::WriteAllText($canary,'R400 OUTSIDE CANARY MUST NEVER BE WRITTEN',[Text.UTF8Encoding]::new($false))
    $canaryHash=(Get-FileHash -LiteralPath $canary -Algorithm SHA256).Hash
    $alias=Join-Path $fixture 'hardlink.download'
    New-Item -ItemType HardLink -Path $alias -Target $canary -ErrorAction Stop|Out-Null
    $hard=Stage $data $alias $spec
    if($hard.Error -cne 'IOException' -or
       (Get-FileHash -LiteralPath $canary -Algorithm SHA256).Hash -cne $canaryHash -or
       (Get-FileHash -LiteralPath $alias -Algorithm SHA256).Hash -cne $canaryHash){
        throw 'R400_HARDLINK_CANARY_ALTERED'
    }
    'R400_PASS_PREPLANTED_HARDLINK_CANARY_UNCHANGED'

    $bad=Join-Path $fixture 'bad-digest.download'
    $wrong='sha256:'+(('0'*64))
    if($wrong -ceq $spec){throw 'R400_BAD_DIGEST_TEST_COLLISION'}
    $denied=Stage $data $bad $wrong
    if($denied.Error -cne 'InvalidDataException' -or [IO.File]::Exists($bad)){
        throw ('R400_DIGEST_FAILURE_NOT_CLEAN_'+$denied.Error)
    }
    'R400_PASS_BAD_DIGEST_FAILS_CLOSED_AND_CLEANS_OWN_STAGING'

    $tiny=Join-Path $fixture 'tiny.download'
    $tinyResult=Stage ([byte[]]@(1,2,3,4)) $tiny $spec
    if($tinyResult.Error -cne 'InvalidDataException' -or [IO.File]::Exists($tiny)){
        throw 'R400_TRUNCATED_TRANSFER_ACCEPTED'
    }
    'R400_PASS_TINY_TRANSFER_REJECTED'

    $notDownload=Stage $data (Join-Path $fixture 'untrusted.exe') $spec
    if($notDownload.Error -cne 'InvalidDataException' -or
       [IO.File]::Exists((Join-Path $fixture 'untrusted.exe'))){
        throw 'R400_NON_STAGING_EXTENSION_ACCEPTED'
    }
    'R400_PASS_DISALLOWED_STAGING_PATH_REJECTED'

    $target=Join-Path $fixture 'trusted-junction-target'
    [void][IO.Directory]::CreateDirectory($target)
    $made=New-Item -ItemType Junction -Path $link -Target $target -ErrorAction Stop
    if(([IO.File]::GetAttributes($link) -band [IO.FileAttributes]::ReparsePoint) -eq 0){
        throw 'R400_JUNCTION_FIXTURE_NOT_REPARSE'
    }
    $via=Join-Path $link 'redirected.download'
    $junction=Stage $data $via $spec
    if($junction.Error -cne 'InvalidDataException' -or [IO.File]::Exists((Join-Path $target 'redirected.download'))){
        throw ('R400_PARENT_JUNCTION_NOT_REJECTED_'+$junction.Error)
    }
    'R400_PASS_PARENT_JUNCTION_REJECTED_BEFORE_WRITE'
    if((Get-FileHash -LiteralPath $canary -Algorithm SHA256).Hash -cne $canaryHash){
        throw 'R400_FOREIGN_CANARY_MUTATED'
    }
    'R400_PASS_OUTSIDE_CANARY_BYTE_IDENTICAL'
    'R400_PASS_NO_NETWORK_REQUEST_OR_INSTALLER_LAUNCH'
    'R400_RESULT=PASS_SCOPED_UNPREDICTABLE_CREATE_NEW_STAGING'
}finally{
    if([IO.Directory]::Exists($link)){
        if(([IO.File]::GetAttributes($link) -band [IO.FileAttributes]::ReparsePoint) -eq 0){
            throw 'R400_JUNCTION_CHANGED_DURING_TEST'
        }
        [IO.Directory]::Delete($link,$false)
    }
    if([IO.Directory]::Exists($fixture)){
        Remove-Item -LiteralPath $fixture -Recurse -Force
    }
}
