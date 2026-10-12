# R102: Representative originally-absent HKCU KEY recovery using exact shared R91 restore function.
# Does NOT remove or change the real Explorer\Wallpapers key, personal Wallpaper, or install.
# All Registry writes confined to six exact, initially absent disposable GitHub VM-owned fixtures.
[CmdletBinding()]
param([switch]$StaticOnly,[string]$EvidenceDir='')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$helper=Join-Path $PSScriptRoot 'Restore-DisposableModeKey-R102.ps1'
if(!(Test-Path -LiteralPath $helper -PathType Leaf)){throw 'R102 SHARED HELPER MISSING'}
. $helper
if($StaticOnly){
    $t=$null;$e=$null
    foreach($f in @($PSCommandPath,$helper)){
        [void][Management.Automation.Language.Parser]::ParseFile($f,[ref]$t,[ref]$e)
        if(@($e).Count -ne 0){throw ('R102 STATIC PARSER FAILED '+$f)}
    }
    if((Get-Command Invoke-R102RestoreOriginallyAbsentModeKey -CommandType Function -ErrorAction Stop).Name -cne 'Invoke-R102RestoreOriginallyAbsentModeKey'){
        throw 'R102 SHARED FUNCTION NOT LOADED'
    }
    Write-Output 'R102_STATIC_PARSER_AND_SHARED_GUARD_PASS_NO_REGISTRY_MUTATION'
    exit 0
}
if($env:GITHUB_ACTIONS -cne 'true' -or
   $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
   $env:RUNNER_OS -cne 'Windows' -or
   $env:COMPUTERNAME -ceq 'EMAD-PC-ULTIMAT' -or
   [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP) -or
   $env:GITHUB_SHA -cnotmatch '^[0-9a-f]{40}$'){
    throw 'R102 REFUSE NONDISPOSABLE HOST'
}
$expectedRoot=[IO.Path]::GetFullPath((Join-Path $env:RUNNER_TEMP 'TBME_R88_UnsignedPreview_Smoke'))
$area=[IO.Path]::GetFullPath($EvidenceDir)
if($area -cne $expectedRoot){throw 'R102 RECEIPT PATH NOT EXPECTED OWNED HOST AREA'}
$receiptPath=Join-Path $area 'R102_ABSENT_MODE_KEY_RECEIPT.json'
if(Test-Path -LiteralPath $receiptPath){throw 'R102 UNSAFE RECEIPT RERUN'}
$fixtureNames=@('Absent','Empty','Dynamic','ForeignValue','ForeignChild','WrongKind','OriginallyPresent')
$parent='Software\TaskbarMonitorEnhanced_R102_Canary_'
$real='Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers'
function Test-R102KeyExists([string]$sub){
    $key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($sub,$false)
    if($key){$key.Dispose();return $true}
    return $false
}
function Get-R102RealModeHash {
    # Read-only digest of hosted-runner real mode registry, to prove fixture operations did not alter it.
    $key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($real,$false)
    if(!$key){$raw='MODE_KEY_ABSENT'}
    else{
        try{
            $v=@()
            foreach($name in @($key.GetValueNames()|Sort-Object)){
                $kind=[string]$key.GetValueKind($name)
                $value=$key.GetValue($name)
                if($value -is [array]){$value=($value -join ',')}
                $v+=([string]$name+'|'+$kind+'|'+[string]$value)
            }
            $raw='PRESENT|'+(@($key.GetSubKeyNames()|Sort-Object) -join ',')+'|'+($v -join ';')
        }finally{$key.Dispose()}
    }
    $sha=[Security.Cryptography.SHA256]::Create()
    try {return [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($raw))).Replace('-','')}
    finally{$sha.Dispose()}
}
function Clear-R102KnownFixture([string]$native){
    # Negative test fixture cleanup only. Exact owned names and no unknown values/subkeys.
    $key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($native,$true)
    if(!$key){return}
    try{
        $names=@($key.GetValueNames())
        $children=@($key.GetSubKeyNames())
        if(@($names | Where-Object {$_ -cnotin @('BackgroundType','R102OwnedForeign')}).Count -gt 0 -or
           @($children | Where-Object {$_ -cne 'TestOwnedChild'}).Count -gt 0){
            throw 'R102 REFUSE CLEANUP OF UNOWNED FIXTURE CONTENT'
        }
        if($children -contains 'TestOwnedChild'){
            $child=$key.OpenSubKey('TestOwnedChild',$false)
            if(!$child){throw 'R102 OWNED CHILD INACCESSIBLE'}
            try{if($child.ValueCount -ne 0 -or $child.SubKeyCount -ne 0){throw 'R102 OWNED CHILD HAS UNKNOWN CONTENT'}}
            finally{$child.Dispose()}
            $key.DeleteSubKey('TestOwnedChild',$false)
        }
        foreach($name in @('BackgroundType','R102OwnedForeign')){$key.DeleteValue($name,$false)}
        if($key.ValueCount -ne 0 -or $key.SubKeyCount -ne 0){throw 'R102 CLEANUP NOT EMPTY'}
    }finally{$key.Dispose()}
    [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKey($native,$false)
    if(Test-R102KeyExists $native){throw 'R102 TEST FIXTURE STILL PRESENT'}
}
$realBefore=Get-R102RealModeHash
$results=@()
$errors=@()
$start=(Get-Date).ToUniversalTime().ToString('o')
foreach($name in $fixtureNames){
    $native=$parent+$name
    if(Test-R102KeyExists $native){throw ('R102 REFUSE PREEXISTING REGISTRY FIXTURE '+$native)}
    $created=$false
    try{
        $key=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($native)
        if($null -eq $key){throw 'R102 TEST FIXTURE CREATE FAILED'}
        $created=$true
        try{
            switch($name){
               'Absent' {$key.SetValue('BackgroundType',0,[Microsoft.Win32.RegistryValueKind]::DWord)}
               'Dynamic' {$key.SetValue('BackgroundType',2,[Microsoft.Win32.RegistryValueKind]::DWord)}
               'ForeignValue' {
                   $key.SetValue('BackgroundType',0,[Microsoft.Win32.RegistryValueKind]::DWord)
                   $key.SetValue('R102OwnedForeign','sentinel',[Microsoft.Win32.RegistryValueKind]::String)
               }
               'ForeignChild' {
                   $key.SetValue('BackgroundType',0,[Microsoft.Win32.RegistryValueKind]::DWord)
                   $child=$key.CreateSubKey('TestOwnedChild')
                   $child.Dispose()
               }
               'WrongKind' {$key.SetValue('BackgroundType','0',[Microsoft.Win32.RegistryValueKind]::String)}
               'OriginallyPresent' {$key.SetValue('BackgroundType',0,[Microsoft.Win32.RegistryValueKind]::DWord)}
               'Empty' { }
            }
        }finally{$key.Dispose()}
        $shouldRefuse=$name -in @('ForeignValue','ForeignChild','WrongKind','OriginallyPresent')
        $reason=''
        try{
            $actual=Invoke-R102RestoreOriginallyAbsentModeKey -NativeSubKey $native -OriginalKeyExists ($name -ceq 'OriginallyPresent')
            if($shouldRefuse){throw ('R102 REFUSAL NOT RAISED '+$name)}
            if($actual -cne 'REMOVED_EXACT_OWNED_EMPTY_KEY'){throw ('R102 UNEXPECTED CLEANUP RETURN '+$name)}
            if(Test-R102KeyExists $native){throw ('R102 POSITIVE KEY STILL EXISTS '+$name)}
            $reason='DELETED_EXACT_INITIAL_ABSENCE'
        }catch{
            if(!$shouldRefuse){throw}
            $reason=$_.Exception.Message
            $expected= switch($name){
               'ForeignValue' {'R102 REFUSE UNOWNED REGISTRY CONTENT'}
               'ForeignChild' {'R102 REFUSE UNOWNED REGISTRY CONTENT'}
               'WrongKind' {'R102 REFUSE FOREIGN VALUE TYPE'}
               'OriginallyPresent' {'R102 REFUSE ORIGINAL EXISTED KEY'}
            }
            if($reason -cne $expected){throw ('R102 WRONG NEGATIVE REASON '+$name+': '+$reason)}
            if(!(Test-R102KeyExists $native)){throw ('R102 FOREIGN CONTENT KEY REMOVED '+$name)}
            $peek=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($native,$false)
            try{
                if($name -ceq 'ForeignValue' -and $peek.GetValue('R102OwnedForeign') -cne 'sentinel'){throw 'R102 FOREIGN VALUE MUTATED'}
                if($name -ceq 'ForeignChild' -and @($peek.GetSubKeyNames()) -cnotcontains 'TestOwnedChild'){throw 'R102 FOREIGN SUBKEY MUTATED'}
                if($name -ceq 'WrongKind' -and $peek.GetValueKind('BackgroundType') -ne [Microsoft.Win32.RegistryValueKind]::String){throw 'R102 FOREIGN VALUE KIND MUTATED'}
                if($name -ceq 'OriginallyPresent' -and $peek.GetValue('BackgroundType') -ne 0){throw 'R102 ORIGINAL-EXISTS STATE MUTATED'}
            }finally{$peek.Dispose()}
        }
        $results+= [ordered]@{Name=$name;PreKeyExists=$false;GuardOutcome=if($shouldRefuse){'EXPECTED_REFUSAL'}else{'REMOVED'};GuardReason=$reason;PreservedUnknownContent=if($shouldRefuse){$true}else{$null};FinalKeyExists=$false;CasePass=$true}
    }catch{
        $errors+=($name+': '+$_.Exception.ToString())
        throw
    }finally{
        if($created){
            Clear-R102KnownFixture $native
        }
    }
}
$realAfter=Get-R102RealModeHash
if($realAfter -cne $realBefore){throw 'R102 HOSTED REAL WALLPAPER KEY CHANGED BY SYNTHETIC TEST'}
if(@($results).Count -ne 7 -or @($results|Where-Object {!$_.CasePass}).Count -ne 0){throw 'R102 TEST CASE COUNT/STATUS INVALID'}
$receipt=[ordered]@{
 Schema=1;Revision='R102';EventCommit=$env:GITHUB_SHA
 Status='PASS_DISPOSABLE_SYNTHETIC_ORIGINALLY_ABSENT_KEY_GUARD'
 CaseCount=7;Cases=$results
 HostRole='GITHUB_HOSTED_DISPOSABLE_WINDOWS'
 SourceHelperSHA256=(Get-FileHash -LiteralPath $helper -Algorithm SHA256).Hash
 SourceHarnessSHA256=(Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'Test-WallpaperStaticDisposable-R91.ps1') -Algorithm SHA256).Hash
 SyntheticFixtureKeysOnly=$true;RealWallpaperKeyWasNotWritten=$true
 RealModeHashBefore=$realBefore;RealModeHashAfter=$realAfter
 OriginalKeyAbsentScenario='REPRESENTATIVE_HKCU_FIXTURE_NOT_REAL_EXPLORER_WALLPAPERS'
 SignedIndependentLabWitness=$false;FormalG13Accepted=$false
 PersonalInstallTouched=$false;PersonalWallpaperTouched=$false
 StartedUTC=$start;FinishedUTC=(Get-Date).ToUniversalTime().ToString('o')
}
$bytes=$receipt|ConvertTo-Json -Depth 8
[IO.File]::WriteAllText($receiptPath,$bytes,[Text.UTF8Encoding]::new($false))
Write-Output ('R102_SYNTHETIC_ABSENT_MODE_KEY_GUARD_7_OF_7_PASS SHA256='+(Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash+' FORMAL_G13_OPEN_REAL_MODE_UNCHANGED')
exit 0
