[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$AssemblyPath,
 [switch]$LocalFixture
)
Set-StrictMode -Version Latest
if($PSVersionTable.PSEdition -cne 'Desktop'){throw 'R080_ONLY_NATIVE_WINDOWS_PS51'}
if(-not $LocalFixture){
 if($env:GITHUB_ACTIONS -cne 'true' -or $env:RUNNER_OS -cne 'Windows' -or
    $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
    [string]::IsNullOrWhiteSpace($env:GITHUB_SHA) -or
    $env:COMPUTERNAME -match '(?i)EMAD-PC'){
    throw 'R080_NEEDS_DISPOSABLE_GITHUB_WINDOWS_RUNNER'
 }
 if((git rev-parse HEAD).Trim() -cne $env:GITHUB_SHA){
    throw 'R080_BUILD_SHA_MISMATCH'
 }
 if(-not $AssemblyPath.EndsWith('TaskbarMonitorEnhanced_Setup_1.7.8.exe',
                          [StringComparison]::OrdinalIgnoreCase)){
    throw 'R080_EXPECTED_REAL_INSTALLER_BUILD_MISSING'
 }
}else{
 if(-not $AssemblyPath.EndsWith('_r080_safe_v3.dll',
                          [StringComparison]::OrdinalIgnoreCase) -or
    -not ([IO.Path]::GetFullPath($AssemblyPath)).StartsWith(
              [IO.Path]::GetFullPath([IO.Path]::GetTempPath()),
              [StringComparison]::OrdinalIgnoreCase)){
    throw 'R080_LOCAL_FIXTURE_OUTSIDE_BOUNDED_TEMP'
 }
}
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$dll=[IO.Path]::GetFullPath($AssemblyPath)
$helper=Join-Path $root 'installer/TBME_Setup_Elevated_Helper.ps1'
if(-not [IO.File]::Exists($dll)){throw 'TEST_DLL_MISSING'}
$asm=[Reflection.Assembly]::LoadFile($dll)
$receiverType=$asm.GetType('SetupProgram+SensorStatusReceiver',$true)
$flags=[Reflection.BindingFlags]'Public,Instance'
$receiverName=$receiverType.GetField('Name',$flags)
$receiverNonce=$receiverType.GetProperty('Nonce',$flags)
$receiverPoll=$receiverType.GetMethod('Poll',$flags)
$receiverHasResult=$receiverType.GetProperty('HasResult',$flags)
$messageField=$receiverType.GetField('message',[Reflection.BindingFlags]'NonPublic,Instance')
if(!$receiverName -or !$receiverNonce -or !$receiverPoll -or !$receiverHasResult -or !$messageField){throw 'ACTUAL_RECEIVER_METHODS_MISSING'}
# Verify that the actual PE resource and checkout source compact identically.
$t=$asm.GetType('SetupProgram',$true)
$compact=$t.GetMethod('CompactTrustedHelperSource',[Reflection.BindingFlags]'NonPublic,Static')
if(!$compact){throw 'R080_COMPACTOR_MISSING'}
$stream=$asm.GetManifestResourceStream('Payload.TBME_Setup_Elevated_Helper.ps1')
if(!$stream){throw 'R080_EMBEDDED_HELPER_MISSING'}
try{
 $reader=[IO.StreamReader]::new($stream,[Text.Encoding]::UTF8,$true)
 $embedded=$reader.ReadToEnd()
}finally{$stream.Dispose()}
$packaged=[string]$compact.Invoke($null,([object[]]@([string]$embedded)))
$fromSource=[string]$compact.Invoke($null,([object[]]@([IO.File]::ReadAllText($helper))))
if($packaged -cne $fromSource){throw 'R080_EMBEDDED_AND_SOURCE_HELPER_DO_NOT_MATCH'}
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput($packaged,[ref]$tokens,[ref]$errors)
if(@($errors).Count){throw 'REAL_EMBEDDED_COMPACTED_HELPER_PARSE_INVALID'}
$functions=@($ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst]},$true))
$need=@('Write-Log','Write-Result')
$bodyFunctions=''
foreach($n in $need){
 $f=@($functions|Where-Object{$_.Name -ceq $n})
 if($f.Count -ne 1){throw ('HELPER_REAL_FUNCTION_MISSING_'+$n)}
 $bodyFunctions+=[string]$f[0].Extent.Text+[char]10
}
$raw=$packaged
$start=$raw.IndexOf('if($StatusPipe -cnotmatch',[StringComparison]::Ordinal)
$end=$raw.IndexOf('$TaskName=',[StringComparison]::Ordinal)
if($start -lt 0 -or $end -le $start -or $raw.IndexOf('if($StatusPipe -cnotmatch',$start+1,[StringComparison]::Ordinal) -ge 0){throw 'HELPER_HANDSHAKE_NOT_UNIQUE'}
$handshake=$raw.Substring($start,$end-$start)
$winps=Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe'
function Verify-One([string]$kind) {
 $receiver=[Activator]::CreateInstance($receiverType,$true)
 $client=$null
 try{
  $name=[string]$receiverName.GetValue($receiver)
  $nonce=[string]$receiverNonce.GetValue($receiver,$null)
  $sentNonce=if($kind -eq 'wrong_nonce'){'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee'}else{$nonce}
  $code='$ErrorActionPreference="Stop"'+[char]10+
    '$StatusPipe="'+$name+'";$StatusNonce="'+$sentNonce+'";'+[char]10+
    $handshake+[char]10+
    '$SupervisorHealthy=$false;$CpuTransportHealthy=$false;$GpuTransportHealthy=$false;'+
    '$StorageTransportHealthy=$false;$CpuDataAvailable=$false;'+
    '$RollbackPerformed=$false;$RollbackSucceeded=$false;$PreviousSensorLayerPresent=$false;'+
    '$ActiveArchitecture="R080_TEST_ONLY";$LogPath="R080_TEST_NO_DISK_PATH";'+[char]10+
    $bodyFunctions+[char]10+
    'Write-Log "R080_TEST_ONLY";'+[char]10+
    'Write-Result "DEGRADED" "R080_HARMLESS_NONADMIN" "SKIPPED" $null $false $false $false;'+[char]10+
    '[Threading.Thread]::Sleep(1000)'+[char]10
  $cmd=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code))
  $psi=[Diagnostics.ProcessStartInfo]::new()
  $psi.FileName=$winps
  $psi.Arguments='-NoProfile -NonInteractive -EncodedCommand '+$cmd
  $psi.UseShellExecute=$false
  $psi.CreateNoWindow=$true
  $psi.RedirectStandardError=$true
  $client=[Diagnostics.Process]::Start($psi)
  if(!$client){throw 'CLIENT_NOT_STARTED'}
  $success=$false;$rejected=$false;$deadline=[DateTime]::UtcNow.AddSeconds(12)
  while([DateTime]::UtcNow -lt $deadline){
   $expected=if($kind -eq 'wrong_expected_pid'){[Diagnostics.Process]::GetCurrentProcess()}else{$client}
   try{[void]$receiverPoll.Invoke($receiver,([object[]]@($expected)))}
   catch{
    $e=$_.Exception
    while($e.InnerException){$e=$e.InnerException}
     if($kind -eq 'wrong_nonce' -and $e -is [IO.InvalidDataException] -and $e.Message.Contains('HELLO nonce')){$rejected=$true;break}
     if($kind -eq 'wrong_expected_pid' -and $e -is [IO.InvalidDataException] -and $e.Message.Contains('identity mismatch')){$rejected=$true;break}
    throw ('R080_RECEIVER_ERROR_'+$kind+': '+$e.GetType().Name+' '+$e.Message)
   }
   if([bool]$receiverHasResult.GetValue($receiver,$null)){$success=$true;break}
   Start-Sleep -Milliseconds 40
  }
   if($kind -eq 'wrong_nonce' -or $kind -eq 'wrong_expected_pid'){
    if(!$rejected){throw ('R080_EXPECTED_NEGATIVE_REJECTION_'+$kind)}
    'R080_ACTUAL_RECEIVER_'+$kind.ToUpperInvariant()+'=REJECTED'
   }else{
   if(!$success){throw ('R080_REAL_HELPER_FUNCTION_RESULT_NOT_RECEIVED;clientExited='+$client.HasExited)}
   $frame=[string]$messageField.GetValue($receiver)
   $parts=$frame.Split('|')
   if($parts.Length -ne 4 -or $parts[0] -ne 'TBME80' -or $parts[1] -cne $nonce){throw 'R080_FRAME_BOUNDARY_INVALID'}
   $json=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($parts[2]))|ConvertFrom-Json
   $logs=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($parts[3]))
   if($json.Status -cne 'DEGRADED' -or $json.Message -cne 'R080_HARMLESS_NONADMIN' -or !$logs.Contains('R080_TEST_ONLY')){throw 'R080_STATUS_CONTENT_NOT_PRESERVED'}
   'R080_REAL_HELPER_FUNCTION_STATUS_FRAME=PASS'
   'R080_POLL_WITH_OS_PID_NONCE_SESSION=PASS'
   'R080_NO_PRIVILEGED_PERUSER_WRITES=TRUE'
   if(-not $LocalFixture){
     # The Windows-latest user is disposable. Refuse any existing installation
     # rather than deleting or overwriting a pre-existing AppRoot.
     $appRoot=[string]$t.GetProperty('AppRoot',[Reflection.BindingFlags]'NonPublic,Static').GetValue($null,$null)
     if(Test-Path -LiteralPath $appRoot){throw 'R080_RUNNER_APP_ALREADY_EXISTS'}
     try{
       $persist=$receiverType.GetMethod('PersistAsInvoker',$flags)
       [void]$persist.Invoke($receiver,[object[]]::new(0))
       $resultFile=Join-Path $appRoot 'Logs/sensor_install_result.json'
       $logFile=Join-Path $appRoot 'Logs/sensor_install.log'
       if(-not(Test-Path -LiteralPath $resultFile -PathType Leaf) -or
          -not(Test-Path -LiteralPath $logFile -PathType Leaf)){
          throw 'R080_USER_LEVEL_STATUS_PERSIST_MISSING'
       }
       $saved=Get-Content -LiteralPath $resultFile -Raw|ConvertFrom-Json
       if($saved.Status -cne 'DEGRADED' -or
          $saved.Message -cne 'R080_HARMLESS_NONADMIN' -or
          -not ([IO.File]::ReadAllText($logFile).Contains('R080_TEST_ONLY'))){
          throw 'R080_USER_LEVEL_STATUS_CONTENT_WRONG'
       }
       'R080_HOSTED_NORMAL_USER_STATUS_LOG_AND_JSON_PERSIST=PASS'
     }finally{
       if(Test-Path -LiteralPath $appRoot){
          # Only delete the fixture created under this runner when this test
          # previously proved it was not present.
          [IO.Directory]::Delete($appRoot,$true)
       }
     }
   }
   }
  }finally{
  if($client){
   if(!$client.HasExited){try{$client.Kill();$client.WaitForExit(3000)|Out-Null}catch{}}
   $client.Dispose()
  }
  $receiver.Dispose()
 }
}
Verify-One 'valid'
Verify-One 'wrong_nonce'
Verify-One 'wrong_expected_pid'
if($LocalFixture){'R080_NO_PERSIST_ASINVOKER_METHOD_CALLED=TRUE'}
'R080_OS_UAC_OR_SETUP_INSTALL_RUN=FALSE'
'R080_REAL_HELPER_SOURCE_SHA256='+((Get-FileHash $helper -Algorithm SHA256).Hash)