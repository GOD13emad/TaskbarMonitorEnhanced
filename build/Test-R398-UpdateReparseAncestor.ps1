[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$AppPath,
    [Parameter(Mandatory=$true)][string]$SourceRoot,
    [switch]$HostedGuest
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($PSVersionTable.PSEdition -cne 'Desktop'){throw 'R398_REQUIRES_WINDOWS_POWERSHELL_51'}
if($HostedGuest -and ($env:GITHUB_ACTIONS -cne 'true' -or
    $env:RUNNER_OS -cne 'Windows' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted')){
    throw 'R398_NOT_DISPOSABLE_HOST'
}
$source=(Resolve-Path -LiteralPath $SourceRoot).Path
$app=(Resolve-Path -LiteralPath $AppPath).Path
$expected=Join-Path $source 'build\_out\App\TaskbarMonitorEnhanced.exe'
if(![string]::Equals($app,$expected,[StringComparison]::OrdinalIgnoreCase)){
    throw 'R398_APP_NOT_EXACT_BUILD_OUTPUT'
}
$text=[IO.File]::ReadAllText((Join-Path $source 'src\TaskbarMonitorEnhanced.cs'))
if(!$text.Contains('RejectUpdateReparseAncestors(path)') -or
   !$text.Contains('RejectUpdateReparseAncestors(partial)')){
    throw 'R398_CANDIDATE_SOURCE_GUARD_MISSING'
}
$asm=[Reflection.Assembly]::LoadFrom($app)
$type=$asm.GetType('TaskbarMonitorEnhanced.UpdateManager',$true)
$flags=[Reflection.BindingFlags]'Static,Public,NonPublic'
$verify=$type.GetMethod('VerifyInstallerBeforeLaunch',$flags)
$reject=$type.GetMethod('RejectUpdateReparseAncestors',$flags)
if(!$verify -or !$reject -or $verify.GetParameters().Length -ne 2){
    throw 'R398_COMPILED_GUARD_METHOD_MISSING'
}
function Invoke-Checked([Reflection.MethodInfo]$Method,[object[]]$Arguments){
    try{
        $value=$Method.Invoke($null,$Arguments)
        return [pscustomobject]@{Value=$value;Exception='';Message=''}
    }catch{
        $e=$_.Exception
        while($e.InnerException){$e=$e.InnerException}
        return [pscustomobject]@{Value=$null;Exception=$e.GetType().Name;Message=$e.Message}
    }
}
$root=Join-Path $env:TEMP ('tbme-r398-verified-update-path-'+[Guid]::NewGuid().ToString('N'))
if(Test-Path -LiteralPath $root){throw 'R398_ROOT_ALREADY_EXISTS'}
$real=Join-Path $root 'target'
$link=Join-Path $root 'junction'
[void][IO.Directory]::CreateDirectory($real)
try{
    $file=Join-Path $real 'harmless-fixture.txt'
    [IO.File]::WriteAllText($file,'R398 harmless non-executable fixture')
    $digest=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
    $metadata='sha256:'+$digest.ToLowerInvariant()
    $normal=Invoke-Checked $verify ([object[]]@([string]$file,[string]$metadata))
    if($normal.Exception -or $normal.Value -cne $digest){
        throw 'R398_NORMAL_FILE_VERIFIER_MUST_ACCEPT'
    }
    'R398_PASS_REAL_COMPILED_VERIFIER_ACCEPTS_UNLINKED_FIXTURE'

    $created=New-Item -ItemType Junction -Path $link -Target $real -ErrorAction Stop
    if(!(Test-Path -LiteralPath $link) -or
       (([IO.File]::GetAttributes($link) -band [IO.FileAttributes]::ReparsePoint) -eq 0)){
        throw 'R398_JUNCTION_NOT_CREATED_AS_REPARSE_POINT'
    }
    $through=Join-Path $link 'harmless-fixture.txt'
    if((([IO.File]::GetAttributes($through) -band [IO.FileAttributes]::ReparsePoint) -ne 0)){
        throw 'R398_EXPECT_REGULAR_FILE_LEAF'
    }
    $blocked=Invoke-Checked $verify ([object[]]@([string]$through,[string]$metadata))
    if($blocked.Exception -cne 'InvalidDataException' -or
       $blocked.Message -notmatch '(?i)reparse'){
        throw ('R398_JUNCTION_ANCESTOR_NOT_REJECTED_'+$blocked.Exception)
    }
    'R398_PASS_COMPILED_VERIFIER_REJECTS_PARENT_JUNCTION'

    $notYet=Join-Path $link 'not-yet-created.download'
    $blockedBeforeWrite=Invoke-Checked $reject ([object[]]@([string]$notYet))
    if($blockedBeforeWrite.Exception -cne 'InvalidDataException' -or
       $blockedBeforeWrite.Message -notmatch '(?i)reparse'){
        throw 'R398_PREWRITE_JUNCTION_NOT_REJECTED'
    }
    'R398_PASS_COMPILED_PREWRITE_GUARD_REJECTS_JUNCTION'

    $normalMissing=Join-Path $real 'not-yet-created.download'
    $allowedBeforeWrite=Invoke-Checked $reject ([object[]]@([string]$normalMissing))
    if($allowedBeforeWrite.Exception){throw 'R398_PREWRITE_NORMAL_PATH_REJECTED'}
    'R398_PASS_COMPILED_PREWRITE_GUARD_ACCEPTS_NORMAL_PATH'

    if((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -cne $digest){
        throw 'R398_FIXTURE_CONTENT_CHANGED'
    }
    'R398_PASS_FIXTURE_CONTENT_UNCHANGED'
    'R398_PASS_NO_INSTALLER_LAUNCHED'
    'R398_RESULT=PASS_SCOPED_UPDATER_PARENT_JUNCTION_BLOCKED'
}finally{
    if(Test-Path -LiteralPath $link){[IO.Directory]::Delete($link)}
    if(Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Recurse -Force}
}
