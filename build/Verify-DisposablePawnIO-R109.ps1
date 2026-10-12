# R109 independent read-only exact signer/driver and real HealthProbe raw verification.
# No self-issued witness, no fake broker timestamp, no product acceptance promotion.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ReceiptPath,
      [Parameter(Mandatory=$true)][string]$HealthPath,
      [Parameter(Mandatory=$true)][string]$ExpectedCommit,
      [switch]$SelfTest)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($ExpectedCommit -cnotmatch '^[0-9a-f]{40}$'){throw 'R109_BAD_EXPECTED_COMMIT'}
if(!(Test-Path -LiteralPath $ReceiptPath -PathType Leaf) -or
   !(Test-Path -LiteralPath $HealthPath -PathType Leaf)){
    throw 'R109_INDEPENDENT_RAW_FILES_MISSING'
}
$r=Get-Content -LiteralPath $ReceiptPath -Raw|ConvertFrom-Json
$h=Get-Content -LiteralPath $HealthPath -Raw|ConvertFrom-Json
$expected='1F519A22E47187F70A1379A48CA604981C4FCF694F4E65B734AAA74A9FBA3032'
function Reject-R109([psobject]$a,[psobject]$health){
 $errors=[Collections.Generic.List[string]]::new()
 foreach($n in @('Schema','Revision','EventCommit','HostRole','Status','OfficialUrl','Version',
     'PinnedSHA256','DownloadedSHA256','AuthenticodeStatus','SignerSubject',
     'InstallerExit','InstalledRegistryVersion','DriverInstalledOnDisposable',
     'OriginalDriverAbsent','RebootRequired','RebootPerformed','PersonalMachineTouched',
     'ProtectedUserSetupChanged','PublicReleaseModified','Error','StartedUTC','FinishedUTC')){
    if($null -eq $a.PSObject.Properties[$n]){$errors.Add('MISSING_'+$n)}
 }
 if($errors.Count){return $errors.ToArray()}
 if($a.Schema -ne 1 -or $a.Revision -cne 'R109' -or
    $a.EventCommit -cne $ExpectedCommit -or
    $a.HostRole -cne 'GITHUB_HOSTED_DISPOSABLE_WINDOWS' -or
    $a.Status -cne 'PASS_VALID_SIGNED_OFFICIAL_DRIVER_ON_DISPOSABLE_VM_ONLY'){
    $errors.Add('DRIVER_SOURCE_IDENTITY_FALSE')
 }
 if($a.OfficialUrl -cne 'https://github.com/namazso/PawnIO.Setup/releases/download/2.2.0/PawnIO_setup.exe' -or
    $a.Version -cne '2.2.0' -or $a.InstalledRegistryVersion -cne '2.2.0' -or
    $a.PinnedSHA256 -cne $expected -or $a.DownloadedSHA256 -cne $expected -or
    $a.AuthenticodeStatus -cne 'Valid' -or
    $a.SignerSubject -cnotmatch 'CN=namazso\.eu' -or
    $a.SignerSubject -cnotmatch 'O=namazso' -or
    $a.InstallerExit -ne 0 -or $a.OriginalDriverAbsent -ne $true -or
    $a.DriverInstalledOnDisposable -ne $true){
    $errors.Add('OFFICIAL_DRIVER_PROVENANCE_OR_AUTHENTICODE_UNPROVEN')
 }
 if($a.RebootRequired -ne $false -or $a.RebootPerformed -ne $false -or
    $a.PersonalMachineTouched -ne $false -or
    $a.ProtectedUserSetupChanged -ne $false -or
    $a.PublicReleaseModified -ne $false -or $a.Error -cne ''){
    $errors.Add('DRIVER_UNAPPROVED_REBOOT_OR_PERSONAL_MUTATION')
 }
 if($health.Status -cne 'PASS' -or
    $health.ArchitectureR21 -ne $true -or
    $health.SupervisorR33 -ne $true -or
    $health.ProcessContainment -ne $true -or
    $health.SupervisorVersion -cne '1.3.0+r33' -or
    $health.BrokerProtocolVersion -cne '1.1.2+r21'){
    $errors.Add('HEALTH_TRUE_SUPERVISOR_BROKER_NOT_READY')
 }
 foreach($n in @('Supervisor','Cpu','Gpu','Storage')){
    $block=$health.($n)
    if($null -eq $block -or $block.Exists -ne $true -or
       $block.Fresh -ne $true){
        $errors.Add('REAL_'+$n+'_DATAFILE_MISSING_OR_STALE')
    }
 }
 foreach($n in @('Cpu','Gpu','Storage')){
    $property=$n+'TransportHealthy'
    if($health.Supervisor.($property) -ne $true){
        $errors.Add('HEALTH_'+$n+'_TRANSPORT_UNAVAILABLE')
    }
 }
 return $errors.ToArray()
}
$issues=@(Reject-R109 $r $h)
if($issues.Count){throw ('R109_TRUE_SENSOR_HEALTH_NOT_ACCEPTED '+($issues -join ','))}
if($SelfTest){
 $original=Get-Content -LiteralPath $ReceiptPath -Raw
 $mutations=@(
  @{Field='Status';Value='STABLE_SIGNED'},
  @{Field='HostRole';Value='PERSONAL'},
  @{Field='Version';Value='2.1.0'},
  @{Field='InstalledRegistryVersion';Value='2.1.0'},
  @{Field='PinnedSHA256';Value=('0'*64)},
  @{Field='DownloadedSHA256';Value=('0'*64)},
  @{Field='AuthenticodeStatus';Value='NotSigned'},
  @{Field='SignerSubject';Value='Unknown Fake'},
  @{Field='RebootPerformed';Value=$true},
  @{Field='RebootRequired';Value=$true},
  @{Field='PersonalMachineTouched';Value=$true},
  @{Field='DriverInstalledOnDisposable';Value=$false},
  @{Field='InstallerExit';Value=3010},
  @{Field='PublicReleaseModified';Value=$true},
  @{Field='OriginalDriverAbsent';Value=$false}
 )
 foreach($m in $mutations){
   $candidate=$original|ConvertFrom-Json
   $candidate.($m.Field)=$m.Value
   if(@(Reject-R109 $candidate $h).Count -eq 0){
      throw ('R109_HOSTILE_DRIVER_FALSE_ACCEPT_'+$m.Field)
   }
 }
 $v=$original|ConvertFrom-Json
 $falseHealth=Get-Content -LiteralPath $HealthPath -Raw|ConvertFrom-Json
 $falseHealth.Status='DEGRADED'
 if(@(Reject-R109 $v $falseHealth).Count -eq 0){throw 'R109_FALSE_HEALTH_STATUS_ACCEPTED'}
 Write-Output 'R109_INDEPENDENT_SIXTEEN_HOSTILE_NEGATIVES_REJECTED'
}
Write-Output ('R109_OFFICIAL_SIGNED_PAWNIO_AND_REAL_SUPERVISOR_HEALTH_PASS DRIVER_RECEIPT_SHA='+
 (Get-FileHash -LiteralPath $ReceiptPath -Algorithm SHA256).Hash+
 ' HEALTH_SHA='+(Get-FileHash -LiteralPath $HealthPath -Algorithm SHA256).Hash+
 ' FORMAL_G14_STILL_REQUIRES_EXTERNAL_LAB_WITNESS')
exit 0
