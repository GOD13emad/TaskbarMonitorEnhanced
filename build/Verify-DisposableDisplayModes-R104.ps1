# R104 read-only independent verifier of Win32 display mode capability. No desktop changes.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ReceiptPath,
      [Parameter(Mandatory=$true)][string]$ExpectedCommit,
      [switch]$SelfTest)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($ExpectedCommit -cnotmatch '^[0-9a-f]{40}$'){throw 'R104 EXPECTED COMMIT SHA INVALID'}
if(!(Test-Path -LiteralPath $ReceiptPath -PathType Leaf)){throw 'R104 DISPLAY RAW RECEIPT MISSING'}
$receipt=Get-Content -LiteralPath $ReceiptPath -Raw | ConvertFrom-Json
function Assert-R104Receipt([psobject]$r){
    $errors=[Collections.Generic.List[string]]::new()
    foreach($name in @('Schema','Revision','EventCommit','HostRole','Status','DisplayDeviceName',
       'OriginalMode','FinalMode','ScreenBefore','ScreenAfter','ModeCount','EnumeratedModes',
       'CDSTestModes','WiderSupportedCount','RequiredNativeOverlayWidth','SupportedWiderModeExists',
       'MutationFlagOnly','RegistryUpdated','GraphicsModeChanged','NoRebootOrLogoff',
       'NoInstall','PersonalWallpaperTouched','FormalG14Accepted',
       'IndependentLabWitnessSignature','Verdict','Utc')){
       if($null -eq $r.PSObject.Properties[$name]){$errors.Add('MISSING_'+$name)}
    }
    if($errors.Count -ne 0){return $errors.ToArray()}
    if($r.Schema -ne 1 -or $r.Revision -cne 'R104' -or
       $r.EventCommit -cne $ExpectedCommit -or
       $r.HostRole -cne 'GITHUB_HOSTED_DISPOSABLE_WINDOWS' -or
       $r.Status -cne 'PASS_READONLY_DISPLAY_MODE_ENUMERATION'){
        $errors.Add('IDENTITY_OR_STATUS_INVALID')
    }
    if($r.DisplayDeviceName -cnotmatch '^\\\\\.\\DISPLAY[1-9][0-9]*$'){
        $errors.Add('PRIMARY_DISPLAY_IDENTITY_NOT_PINNED')
    }
    if($r.MutationFlagOnly -cne 'CDS_TEST' -or $r.RegistryUpdated -ne $false -or
       $r.GraphicsModeChanged -ne $false -or $r.NoRebootOrLogoff -ne $true -or
       $r.NoInstall -ne $true -or $r.PersonalWallpaperTouched -ne $false -or
       $r.FormalG14Accepted -ne $false -or
       $r.IndependentLabWitnessSignature -cne 'MISSING'){
         $errors.Add('FORBIDDEN_DISPLAY_OR_FORMAL_MUTATION')
    }
    foreach($name in @('Width','Height','BitsPerPixel','Frequency','DEVMODEBytes')){
        if($null -eq $r.OriginalMode.PSObject.Properties[$name] -or
           $null -eq $r.FinalMode.PSObject.Properties[$name]){
            $errors.Add('MODE_FIELD_MISSING_'+$name)
            continue
        }
        if($r.OriginalMode.($name) -ne $r.FinalMode.($name)){
            $errors.Add('DISPLAY_MODE_CHANGED_'+$name)
        }
    }
    if($r.OriginalMode.Width -lt 320 -or $r.OriginalMode.Height -lt 200 -or
       $r.OriginalMode.BitsPerPixel -lt 24 -or
       $r.OriginalMode.DEVMODEBytes -lt 180 -or
       $r.RequiredNativeOverlayWidth -ne 1100){
         $errors.Add('MODE_OR_TARGET_GEOMETRY_INVALID')
    }
    $screen1=@($r.ScreenBefore)
    $screen2=@($r.ScreenAfter)
    if($screen1.Count -ne 4 -or $screen2.Count -ne 4 -or
       ($screen1 -join ',') -cne ($screen2 -join ',') -or
       $screen1[2] -ne $r.OriginalMode.Width -or
       $screen1[3] -ne $r.OriginalMode.Height){
        $errors.Add('SCREEN_BOUNDS_NOT_PRESERVED')
    }
    $all=@($r.EnumeratedModes)
    $tested=@($r.CDSTestModes)
    if($r.ModeCount -ne $all.Count -or $all.Count -lt 1 -or
       $all.Count -gt 256 -or $tested.Count -gt 20){
         $errors.Add('ENUMERATION_COUNT_OR_BOUND_MISMATCH')
         return $errors.ToArray()
    }
    $indexes=@($all|ForEach-Object Index)
    if(@($indexes|Select-Object -Unique).Count -ne $all.Count){
        $errors.Add('DUPLICATE_MODE_INDEX')
    }
    for($i=0;$i -lt $all.Count;$i++){
        $m=$all[$i]
        if($m.Index -ne $i -or $m.Width -lt 320 -or $m.Height -lt 200 -or
           $m.BitsPerPixel -lt 24){
             $errors.Add('INVALID_ENUMERATED_MODE_'+$i)
        }
    }
    $wide=0
    foreach($t in $tested){
       $idx=[int]$t.Index
       if($idx -lt 0 -or $idx -ge $all.Count){
           $errors.Add('BAD_TEST_MODE_INDEX')
           continue
       }
       $m=$all[$idx]
       if($t.Win32Flag -cne 'CDS_TEST_ONLY' -or
          $t.Width -ne $m.Width -or $t.Height -ne $m.Height -or
          $t.BitDepth -ne $m.BitsPerPixel -or $t.Frequency -ne $m.Frequency -or
          $t.Width -lt 1100 -or $t.Height -lt 800 -or $t.BitDepth -lt 32){
          $errors.Add('UNSAFE_OR_WRONG_CDS_TEST_'+$idx)
       }
       if([bool]$t.Supported -ne ($t.ReturnCode -eq 0)){
          $errors.Add('INCORRECT_CDS_TEST_RESULT_'+$idx)
       }
       if($t.ReturnCode -eq 0){$wide++}
    }
    $eligible=@($all|Where-Object {$_.Width -ge 1100 -and $_.Height -ge 800 -and $_.BitsPerPixel -ge 32})
    if($tested.Count -ne [Math]::Min(20,$eligible.Count)){
        $errors.Add('ELIGIBLE_WIDE_MODES_NOT_TESTED')
    }
    if($r.WiderSupportedCount -ne $wide -or
       $r.SupportedWiderModeExists -ne ($wide -gt 0)){
        $errors.Add('FALSE_WIDE_MODE_CLAIM')
    }
    $expectedVerdict=if($wide -gt 0){
        'WIDER_MODE_SUPPORTED_FOR_LATER_TRANSACTIONAL_VM_TEST'
    }else{
        'NO_WIDER_SUPPORTED_VM_MODE_ESCALATE_INDEPENDENT_LAB'
    }
    if($r.Verdict -cne $expectedVerdict){$errors.Add('FALSE_VERDICT')}
    return $errors.ToArray()
}
$violations=@(Assert-R104Receipt $receipt)
if($violations.Count -gt 0){
 throw ('R104_INDEPENDENT_DISPLAY_RECEIPT_REFUSED '+($violations -join ','))
}
if($SelfTest){
 $baseline=Get-Content -LiteralPath $ReceiptPath -Raw
 $mutations=@(
   @{Name='FALSE_G14_ACCEPTANCE';Location='top';Field='FormalG14Accepted';Value=$true},
   @{Name='FORGED_WITNESS';Location='top';Field='IndependentLabWitnessSignature';Value='SELF_SIGNED'},
   @{Name='DISPOSABLE_FALSE';Location='top';Field='HostRole';Value='PERSONAL'},
   @{Name='FALSE_CDS_FLAG';Location='top';Field='MutationFlagOnly';Value='CDS_UPDATEREGISTRY'},
   @{Name='FALSE_DEVICE_NAME';Location='top';Field='DisplayDeviceName';Value='unknown-display'},
   @{Name='REGISTRY_WRITE';Location='top';Field='RegistryUpdated';Value=$true},
   @{Name='ACTUAL_MODE_CHANGED';Location='top';Field='GraphicsModeChanged';Value=$true},
   @{Name='UNEXPECTED_REBOOT';Location='top';Field='NoRebootOrLogoff';Value=$false},
   @{Name='FALSE_OVERLAY_WIDTH';Location='top';Field='RequiredNativeOverlayWidth';Value=1},
   @{Name='FALSE_MODE_COUNT';Location='top';Field='ModeCount';Value=999},
   @{Name='BAD_SOURCE_COMMIT';Location='top';Field='EventCommit';Value=('0'*40)},
   @{Name='PRESERVATION_FAIL';Location='final';Field='Width';Value=12345},
   @{Name='SCREEN_CHANGED';Location='screen';Field='ScreenAfter';Value=@(0,0,99,99)},
   @{Name='FALSE_SUPPORTED_COUNT';Location='top';Field='WiderSupportedCount';Value=999},
   @{Name='BAD_VERDICT';Location='top';Field='Verdict';Value='STABLE_G14_COMPLETE'}
 )
 foreach($q in $mutations){
    $candidate=$baseline|ConvertFrom-Json
    switch($q.Location){
       'top' {$candidate.($q.Field)=$q.Value}
       'final' {$candidate.FinalMode.($q.Field)=$q.Value}
       'screen' {$candidate.($q.Field)=$q.Value}
    }
    if(@(Assert-R104Receipt $candidate).Count -eq 0){
        throw ('R104_HOSTILE_RECEIPT_FALSE_ACCEPT '+$q.Name)
    }
 }
 Write-Output ('R104_INDEPENDENT_RECEIPT_HOSTILE_NEGATIVES_PASS='+$mutations.Count)
}
Write-Output ('R104_READONLY_DISPLAY_RECEIPT_PASS MODE_COUNT='+$receipt.ModeCount+
  ' WIDER_SUPPORTED='+$receipt.WiderSupportedCount+
  ' FORMAL_G14=OPEN SHA256='+(Get-FileHash -LiteralPath $ReceiptPath -Algorithm SHA256).Hash)
exit 0
