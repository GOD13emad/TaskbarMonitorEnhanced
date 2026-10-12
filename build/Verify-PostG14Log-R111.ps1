# R111 independent read-only log snapshot SHA and PID binding verifier.
# Does not change main product, sensor or release, nor sign G14.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ReceiptPath,
      [Parameter(Mandatory=$true)][string]$ExpectedCommit,
      [switch]$SelfTest)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($ExpectedCommit -cnotmatch '^[0-9a-f]{40}$'){throw 'R111 EXPECTED COMMIT NOT HEX'}
if(!(Test-Path -LiteralPath $ReceiptPath -PathType Leaf)){throw 'R111 RAW RECEIPT MISSING'}
$r=Get-Content -LiteralPath $ReceiptPath -Raw|ConvertFrom-Json
$root=[IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($ReceiptPath))
function Validate-R111($item){
  $reasons=[Collections.Generic.List[string]]::new()
  foreach($field in @('EventCommit','HostRole','Status','MainProcessPid',
   'CanonicalSingleRoot','CandidateMainSHA256','FormalG14Accepted',
   'R111MainLogCaptureStatus','R111CapturedMainLogs')){
    if($null -eq $item.PSObject.Properties[$field]){$reasons.Add('MISSING_'+$field)}
  }
  if($reasons.Count){return $reasons.ToArray()}
  if($item.EventCommit -cne $ExpectedCommit -or
     $item.HostRole -cne 'GITHUB_HOSTED_DISPOSABLE_WINDOWS' -or
     $item.Status -cne 'PASS_PRIVATE_CANDIDATE_INSTALLED_EIGHT_DIAGNOSTICS_CAPTURED' -or
     $item.CandidateMainSHA256 -cne '9401E54D4A35DDA98CDCECA967683639CF59B940F67E724CDA9B980D8859E8EC' -or
     $item.FormalG14Accepted -ne $false -or
     $item.MainProcessPid -le 0 -or
     $item.CanonicalSingleRoot -cnotmatch '\\TaskbarMonitorEnhanced$'){
     $reasons.Add('SOURCE_HOST_PRODUCT_OR_FORMAL_ACCEPTANCE_INVALID')
  }
  if($item.R111MainLogCaptureStatus -cne 'PASS_READONLY_EXACT_TEMP_INSTALLED_MAIN_LOG'){
    $reasons.Add('REAL_POST_G14_RUNTIME_LOG_NOT_CAPTURED')
  }
  $logs=@($item.R111CapturedMainLogs)
  if($logs.Count -lt 1 -or $logs.Count -gt 3){
    $reasons.Add('ACTUAL_MAIN_LOG_FILE_COUNT_INVALID')
    return $reasons.ToArray()
  }
  $seen=@{}
  $residentLocated=$false
  foreach($log in $logs){
    if($null -eq $log.Name -or
       $log.Name -cnotmatch '^R111_POST_G14_tbme_csharp_[0-9]{8}[.]log$' -or
       $log.SourceName -cnotmatch '^tbme_csharp_[0-9]{8}[.]log$' -or
       $log.Name -cne ('R111_POST_G14_'+$log.SourceName) -or
       $log.Bytes -lt 64 -or $log.Bytes -gt 2097152 -or
       $log.SHA256 -cnotmatch '^[0-9A-F]{64}$'){
       $reasons.Add('LOG_NAME_LENGTH_OR_SHA_FORMAT_NOT_BOUND')
       continue
    }
    if($seen.ContainsKey([string]$log.Name)){
       $reasons.Add('DUPLICATE_LOG_NAMES')
       continue
    }
    $seen[[string]$log.Name]=$true
    $p=Join-Path $root $log.Name
    if(!(Test-Path -LiteralPath $p -PathType Leaf)){
       $reasons.Add('EXACT_LOG_NOT_IN_DISPOSABLE_ARTIFACT')
       continue
    }
    if((Get-Item -LiteralPath $p).Length -ne [long]$log.Bytes -or
       (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash -cne $log.SHA256){
       $reasons.Add('MAIN_LOG_RAW_SHA_OR_LENGTH_TAMPERED')
       continue
    }
    $contents=Get-Content -LiteralPath $p -Raw
    if($contents.Contains('HOST_CONTEXT_START') -and
       $contents.Contains(('pid='+[string]$item.MainProcessPid))){
       $residentLocated=$true
    }
  }
  if(!$residentLocated){$reasons.Add('MAIN_LOG_NOT_PROVEN_MATCHING_EXACT_RESIDENT_PID')}
  return $reasons.ToArray()
}
$issues=@(Validate-R111 $r)
if($issues.Count){throw ('R111_MAIN_POST_START_RUNTIME_LOG_REFUSED '+($issues -join ','))}
if($SelfTest){
  $original=Get-Content -LiteralPath $ReceiptPath -Raw
  $tamper=@(
    @{Key='HostRole';Value='PERSONAL'},
    @{Key='EventCommit';Value=('0'*40)},
    @{Key='Status';Value='STABLE_RELEASE'},
    @{Key='MainProcessPid';Value=0},
    @{Key='CandidateMainSHA256';Value=('0'*64)},
    @{Key='FormalG14Accepted';Value=$true},
    @{Key='R111MainLogCaptureStatus';Value='UNVERIFIED'},
    @{Key='CanonicalSingleRoot';Value='C:\PersonalFolder'}
  )
  foreach($case in $tamper){
    $item=$original|ConvertFrom-Json
    $item.($case.Key)=$case.Value
    if(@(Validate-R111 $item).Count -eq 0){throw ('R111_HOSTILE_LOG_RECEIPT_FALSE_ACCEPT '+$case.Key)}
  }
  $item=$original|ConvertFrom-Json
  $item.R111CapturedMainLogs[0].SHA256=('0'*64)
  if(@(Validate-R111 $item).Count -eq 0){throw 'R111_LOG_SHA_FORGERY_ACCEPTED'}
  $item=$original|ConvertFrom-Json
  $item.R111CapturedMainLogs[0].Bytes=10
  if(@(Validate-R111 $item).Count -eq 0){throw 'R111_LOG_SIZE_FORGERY_ACCEPTED'}
  $item=$original|ConvertFrom-Json
  $item.R111CapturedMainLogs[0].Name='../outside.log'
  if(@(Validate-R111 $item).Count -eq 0){throw 'R111_LOG_PATH_TRAVERSAL_ACCEPTED'}
  Write-Output 'R111_INDEPENDENT_ELEVEN_HOSTILE_NEGATIVE_LOG_CASES_REJECTED'
}
$files=@($r.R111CapturedMainLogs)
$logSamples=0;$surfaceSamples=0;$liftSamples=0;$returnSamples=0
foreach($x in $files){
 $txt=Get-Content -LiteralPath (Join-Path $root $x.Name) -Raw
 $logSamples+=@($txt -split '\r?\n').Count
 $surfaceSamples+=([regex]::Matches($txt,'START_GUARD_VERIFIED_SURFACE')).Count
 $liftSamples+=([regex]::Matches($txt,'START_GLASS_LIFT_NATIVE_PASS')).Count
 $returnSamples+=([regex]::Matches($txt,'START_GLASS_RETURN')).Count
}
Write-Output ('R111_ACTUAL_INSTALLED_POST_G14_LOG_SHA_VERIFIED COUNT='+$files.Count+
 ' LOG_LINES='+$logSamples+' SURFACE_RECOGNIZED='+$surfaceSamples+
 ' LIFT_SUCCESS='+$liftSamples+' RETURN_EVENTS='+$returnSamples+
 ' G14_FORMAL_OPEN RECEIPT_SHA256='+(Get-FileHash $ReceiptPath -Algorithm SHA256).Hash)
exit 0
