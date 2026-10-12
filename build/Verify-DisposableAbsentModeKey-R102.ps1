# R102 independent receipt verifier. READ ONLY. No Registry access or desktop mutation.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ReceiptPath,
      [Parameter(Mandatory=$true)][string]$ExpectedCommit,
      [switch]$SelfTest)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($ExpectedCommit -cnotmatch '^[a-f0-9]{40}$'){throw 'R102 INVALID EXPECTED COMMIT'}
if(!(Test-Path -LiteralPath $ReceiptPath -PathType Leaf)){throw 'R102 RECEIPT MISSING'}
$receipt=Get-Content -LiteralPath $ReceiptPath -Raw | ConvertFrom-Json
$expectedCases=@('Absent','Empty','Dynamic','ForeignValue','ForeignChild','WrongKind','OriginallyPresent')
$negative=@('ForeignValue','ForeignChild','WrongKind','OriginallyPresent')
$reason=@{
    ForeignValue='R102 REFUSE UNOWNED REGISTRY CONTENT'
    ForeignChild='R102 REFUSE UNOWNED REGISTRY CONTENT'
    WrongKind='R102 REFUSE FOREIGN VALUE TYPE'
    OriginallyPresent='R102 REFUSE ORIGINAL EXISTED KEY'
}
$helper=Join-Path $PSScriptRoot 'Restore-DisposableModeKey-R102.ps1'
$harness=Join-Path $PSScriptRoot 'Test-WallpaperStaticDisposable-R91.ps1'
$shaHelper=if(Test-Path -LiteralPath $helper){(Get-FileHash -LiteralPath $helper -Algorithm SHA256).Hash}else{''}
$shaHarness=if(Test-Path -LiteralPath $harness){(Get-FileHash -LiteralPath $harness -Algorithm SHA256).Hash}else{''}
function Check-R102([psobject]$r) {
    $issues=[Collections.Generic.List[string]]::new()
    foreach($prop in @('Schema','Revision','EventCommit','Status','CaseCount','Cases','HostRole',
        'SourceHelperSHA256','SourceHarnessSHA256','SyntheticFixtureKeysOnly',
        'RealWallpaperKeyWasNotWritten','RealModeHashBefore','RealModeHashAfter',
        'OriginalKeyAbsentScenario','SignedIndependentLabWitness','FormalG13Accepted',
        'PersonalInstallTouched','PersonalWallpaperTouched','StartedUTC','FinishedUTC')){
         if($null -eq $r.PSObject.Properties[$prop]){$issues.Add('MISSING_'+$prop)}
    }
    if($issues.Count -ne 0){return $issues.ToArray()}
    if($r.Schema -ne 1 -or $r.Revision -cne 'R102' -or $r.EventCommit -cne $ExpectedCommit -or
       $r.Status -cne 'PASS_DISPOSABLE_SYNTHETIC_ORIGINALLY_ABSENT_KEY_GUARD' -or
       $r.HostRole -cne 'GITHUB_HOSTED_DISPOSABLE_WINDOWS'){$issues.Add('SOURCE_OR_HOST_WRONG')}
    if($shaHelper -cnotmatch '^[0-9A-Fa-f]{64}$' -or $shaHarness -cnotmatch '^[0-9A-Fa-f]{64}$' -or
       $r.SourceHelperSHA256 -cne $shaHelper -or $r.SourceHarnessSHA256 -cne $shaHarness){
       $issues.Add('HELPER_HARNESS_HASH_INVALID')
    }
    if($r.SyntheticFixtureKeysOnly -ne $true -or $r.RealWallpaperKeyWasNotWritten -ne $true -or
       $r.PersonalInstallTouched -ne $false -or $r.PersonalWallpaperTouched -ne $false){
       $issues.Add('PERSONAL_OR_REAL_WALLPAPER_CHANGE_CLAIM')
    }
    if($r.SignedIndependentLabWitness -ne $false -or $r.FormalG13Accepted -ne $false -or
       $r.OriginalKeyAbsentScenario -cne 'REPRESENTATIVE_HKCU_FIXTURE_NOT_REAL_EXPLORER_WALLPAPERS'){
        $issues.Add('FALSE_FORMAL_ACCEPTANCE')
    }
    if($r.RealModeHashBefore -cnotmatch '^[0-9A-F]{64}$' -or
       $r.RealModeHashBefore -cne $r.RealModeHashAfter){
       $issues.Add('REAL_WALLPAPER_REGISTRY_NOT_PRESERVED')
    }
    $cases=@($r.Cases)
    if($r.CaseCount -ne 7 -or $cases.Count -ne 7 -or
       @($cases|ForEach-Object Name|Select-Object -Unique).Count -ne 7){
        $issues.Add('INCOMPLETE_CASE_COUNT')
        return $issues.ToArray()
    }
    foreach($case in $cases){
       if($case.Name -cnotin $expectedCases){$issues.Add('UNKNOWN_CASE');continue}
       if($case.PreKeyExists -ne $false -or $case.FinalKeyExists -ne $false -or $case.CasePass -ne $true){
           $issues.Add('CASE_NOT_RESTORED_'+$case.Name)
       }
       if($case.Name -in $negative){
           if($case.GuardOutcome -cne 'EXPECTED_REFUSAL' -or
              $case.GuardReason -cne $reason[$case.Name] -or
              $case.PreservedUnknownContent -ne $true){$issues.Add('HOSTILE_NOT_PRESERVED_'+$case.Name)}
       }elseif($case.GuardOutcome -cne 'REMOVED' -or
               $case.GuardReason -cne 'DELETED_EXACT_INITIAL_ABSENCE'){
           $issues.Add('POSITIVE_ABSENCE_ROLLBACK_FAILED_'+$case.Name)
       }
    }
    return $issues.ToArray()
}
$bad=@(Check-R102 $receipt)
if($bad.Count -ne 0){throw ('R102 HOSTED RECEIPT INDEPENDENT REFUSED '+($bad -join ','))}
if($SelfTest){
    $raw=Get-Content -LiteralPath $ReceiptPath -Raw
    $hostile=@(
      @{Name='FAKE_FORMAL_WITNESS';Field='FormalG13Accepted';Value=$true},
      @{Name='FAKE_SIGNATURE';Field='SignedIndependentLabWitness';Value=$true},
      @{Name='HOST_CHANGED';Field='HostRole';Value='PERSONAL'},
      @{Name='CASE_COUNT_MISSING';Field='CaseCount';Value=6},
      @{Name='FALSE_REAL_WALLPAPER_UNCHANGED';Field='RealWallpaperKeyWasNotWritten';Value=$false},
      @{Name='FALSE_ORIGINALLY_ABSENT_REAL_CASE';Field='OriginalKeyAbsentScenario';Value='REAL'},
      @{Name='HASH_CHANGED';Field='RealModeHashAfter';Value=('F'*64)},
      @{Name='SOURCE_HELPER_MISMATCH';Field='SourceHelperSHA256';Value=('0'*64)},
      @{Name='INSTALL_TOUCHED';Field='PersonalInstallTouched';Value=$true},
      @{Name='STATUS_WRONG';Field='Status';Value='FAIL'}
    )
    foreach($test in $hostile){
        $r=$raw|ConvertFrom-Json
        $r.($test.Field)=$test.Value
        if(@(Check-R102 $r).Count -eq 0){throw ('R102 HOSTILE CASE FALSE PASS '+$test.Name)}
    }
    $r=$raw|ConvertFrom-Json
    $r.Cases[0].FinalKeyExists=$true
    if(@(Check-R102 $r).Count -eq 0){throw 'R102 HOSTILE CASE FINAL_KEY_EXISTS FALSE PASS'}
    $r=$raw|ConvertFrom-Json
    $r.Cases[3].PreservedUnknownContent=$false
    if(@(Check-R102 $r).Count -eq 0){throw 'R102 HOSTILE CASE UNKNOWN CONTENT FALSE PASS'}
    Write-Output 'R102_INDEPENDENT_RECEIPT_12_HOSTILE_NEGATIVES_REJECTED'
}
Write-Output ('R102_INDEPENDENT_ABSENT_KEY_7_OF_7_CASES_PASS_RECEIPT_SHA='+(Get-FileHash -LiteralPath $ReceiptPath -Algorithm SHA256).Hash+' FORMAL_G13_STILL_OPEN')
exit 0
