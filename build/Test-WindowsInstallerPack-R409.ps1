[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$PackageZip,[switch]$ExpectUnsupportedServer,[switch]$ExpectOfflineRuntime)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -cne 'Desktop'){throw 'R409_TEST_REQUIRES_WINDOWS_POWERSHELL_51'}
$zip=(Resolve-Path -LiteralPath $PackageZip).Path
$expected=@('Install.cmd','Install-TaskbarMonitorEnhanced.ps1','README.md',
  'TaskbarMonitorEnhanced_Setup_1.7.10.exe','package-manifest.json')
$runtimeName='NDP48-x86-x64-AllOS-ENU.exe'
$runtimeExpectedSHA='68C9986A8DCC0214D909AA1F31BEE9FB5461BB839EDCA996A75B08DDFFC1483F'
if($ExpectOfflineRuntime){$expected+= $runtimeName}
# R437: exercise every native fixture case in a genuine Unicode path with
# whitespace and CMD metacharacters, without relying on PS5 source encoding.
$testRoot=Join-Path $env:TEMP ('tbme-r409-test Space & ! '+[char]0x06CC+'-'+[guid]::NewGuid().ToString('N'))
if(!$testRoot.Contains([char]0x06CC)){throw 'R437_TEST_FIXTURE_UNICODE_LOST'}
if(Test-Path $testRoot){throw 'R409_TEST_ROOT_ALREADY_EXISTS'}
[void][IO.Directory]::CreateDirectory($testRoot)
$owner=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'TaskbarMonitorEnhanced'
$config=Join-Path $owner 'config.json'
$app=Join-Path $owner 'TaskbarMonitorEnhanced.exe'
$beforeConfig=if(Test-Path $config){(Get-FileHash $config -Algorithm SHA256).Hash}else{'ABSENT'}
$beforeApp=if(Test-Path $app){(Get-FileHash $app -Algorithm SHA256).Hash}else{'ABSENT'}
function Invoke-Preflight([string]$folder,[string]$mode='-CheckOnly') {
  $stdout=Join-Path $testRoot ([guid]::NewGuid().ToString('N')+'.out')
  $stderr=Join-Path $testRoot ([guid]::NewGuid().ToString('N')+'.err')
  $ps=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
  $file=Join-Path $folder 'Install-TaskbarMonitorEnhanced.ps1'
  # R428: native ProcessStartInfo gives the real exit code even on an enforced
  # Windows11 Sandbox where Start-Process -PassThru reported 0 for exit 17/23.
  # Read both pipes concurrently to prevent child stdout/stderr deadlocks.
  $cliArgs='-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$file+'" '+$mode
  $info=New-Object System.Diagnostics.ProcessStartInfo
  $info.FileName=$ps
  $info.Arguments=$cliArgs
  $info.UseShellExecute=$false
  $info.CreateNoWindow=$true
  $info.RedirectStandardOutput=$true
  $info.RedirectStandardError=$true
  $p=[Diagnostics.Process]::Start($info)
  if(!$p){throw 'R409_TEST_CANNOT_START_PREFLIGHT'}
  try {
    $readOut=$p.StandardOutput.ReadToEndAsync()
    $readErr=$p.StandardError.ReadToEndAsync()
    if(!$p.WaitForExit(45000)){
      try{$p.Kill();[void]$p.WaitForExit(3000)}catch{}
      throw 'R428_PREFLIGHT_CHILD_TIMEOUT'
    }
    $result=[pscustomobject]@{
      Exit=[int]$p.ExitCode
      Stdout=$readOut.GetAwaiter().GetResult()
      Stderr=$readErr.GetAwaiter().GetResult()
    }
    return $result
  }finally{$p.Dispose()}
}
# R414: simulate PowerShell 7 -> cmd.exe -> Windows PowerShell 5.1.
# Microsoft documents that the intermediate CMD inherits PS7's module paths,
# which makes WinPS 5.1 autoload an incompatible Microsoft.PowerShell.Utility.
# A correct launcher clears only the child CMD's inherited PSModulePath.
function Invoke-CmdFromPollutedPs7Environment([string]$folder,[string]$mode) {
  $pwsh=Get-Command pwsh.exe -ErrorAction Stop
  $ps7Modules=Join-Path (Split-Path -Parent $pwsh.Source) 'Modules'
  if(!(Test-Path -LiteralPath $ps7Modules -PathType Container)){
    throw 'R414_TEST_POWERSHELL7_MODULE_ROOT_MISSING'
  }
  $prior=$env:PSModulePath
  try {
    $env:PSModulePath=$ps7Modules+';'+$prior
    $output=(& (Join-Path $folder 'Install.cmd') $mode |Out-String)
    $exit=$LASTEXITCODE
  }finally{$env:PSModulePath=$prior}
  if($exit -ne 0){
    throw ('R414_CMD_POLLUTED_PS7_ENV_FAILED_'+$exit+'_'+$output)
  }
  return $output
}
try{
  $stage=Join-Path $testRoot 'extracted'
  [void][IO.Directory]::CreateDirectory($stage)
  Expand-Archive -LiteralPath $zip -DestinationPath $stage -ErrorAction Stop
  $all=@(Get-ChildItem -LiteralPath $stage -File |Select-Object -ExpandProperty Name)
  if($all.Count -ne $expected.Count -or @($all|Where-Object {$_ -cnotin $expected}).Count -gt 0){
    throw 'R409_TEST_UNEXPECTED_ZIP_CONTENT'
  }
  $manifest=Get-Content (Join-Path $stage 'package-manifest.json') -Raw|ConvertFrom-Json
  if([bool]$manifest.OfficialRuntimeBundled -ne [bool]$ExpectOfflineRuntime){throw 'R410_PACKAGE_OFFLINE_MANIFEST_FLAG_MISMATCH'}
  if($manifest.SetupSHA256 -cne (Get-FileHash (Join-Path $stage $manifest.SetupFile) -Algorithm SHA256).Hash){
    throw 'R409_TEST_MANIFEST_SETUP_HASH_INVALID'
  }
  # R424: a missing-package failure from the real CMD launcher must finish
  # noninteractively with the original error code, not wait for "pause".
  # Use the package-first verification path on both Windows Server and Client.
  # Keep stdin open deliberately; a bare CMD pause hangs this regression.
  $badRoot=Join-Path $testRoot 'missing-package'
  [void][IO.Directory]::CreateDirectory($badRoot)
  Copy-Item -LiteralPath (Join-Path $stage 'Install.cmd') -Destination (Join-Path $badRoot 'Install.cmd')
  Copy-Item -LiteralPath (Join-Path $stage 'Install-TaskbarMonitorEnhanced.ps1') -Destination (Join-Path $badRoot 'Install-TaskbarMonitorEnhanced.ps1')
  $badInfo=New-Object System.Diagnostics.ProcessStartInfo
  $badInfo.FileName=$env:ComSpec
  $badInfo.Arguments='/d /s /c ""'+(Join-Path $badRoot 'Install.cmd')+'" -VerifyOfflineRuntime"'
  $badInfo.UseShellExecute=$false
  $badInfo.CreateNoWindow=$true
  $badInfo.RedirectStandardInput=$true
  $badInfo.RedirectStandardOutput=$true
  $badInfo.RedirectStandardError=$true
  $badInfo.EnvironmentVariables['TBME_PAUSE_ON_ERROR']='0'
  $badProcess=[Diagnostics.Process]::Start($badInfo)
  if(!$badProcess){throw 'R424_MISSING_PACKAGE_CMD_FAILED_TO_START'}
  try {
    if(!$badProcess.WaitForExit(5000)){
      try{$badProcess.Kill();$badProcess.WaitForExit(3000)|Out-Null}catch{}
      throw 'R424_MISSING_PACKAGE_CMD_BLOCKED_FOR_INTERACTIVE_INPUT'
    }
    $badStdout=$badProcess.StandardOutput.ReadToEnd()
    $badStderr=$badProcess.StandardError.ReadToEnd()
    if($badProcess.ExitCode -ne 1 -or
       $badStdout -notmatch 'R409_PACKAGE_FILES_MISSING' -or
       $badStdout -notmatch 'installation did not complete'){
      throw ('R424_MISSING_PACKAGE_WRONG_FAILURE_SEMANTICS_exit_'+$badProcess.ExitCode+'_'+$badStdout+'_'+$badStderr)
    }
    'R424_PASS_MISSING_PACKAGE_CMD_FAILS_WITHOUT_INTERACTIVE_PAUSE'
  }finally {
    $badProcess.StandardInput.Close()
    $badProcess.Dispose()
  }
  # R428 - inspect only the standalone production error-classifier function.
  # No actual Setup installation is performed. Input remains the exact
  # staged packaged PowerShell launcher.
  $tokens=$null;$errors=$null
  $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $stage 'Install-TaskbarMonitorEnhanced.ps1'),[ref]$tokens,[ref]$errors)
  if(@($errors).Count){throw 'R428_PACKAGE_BOOTSTRAP_PARSE_FAILED'}
  $functions=@($ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -ceq 'Test-AppControlLaunchDenial'
  },$true))
  if($functions.Count -ne 1){throw 'R428_ERROR_CLASSIFIER_MISSING_OR_DUPLICATE'}
  Invoke-Expression $functions[0].Extent.Text
  $wrapped=[Exception]::new('outer', [ComponentModel.Win32Exception]::new(4551))
  $localized=[ComponentModel.Win32Exception]::new(4551)
  $message=[Exception]::new('This command cannot be run due to the error: An Application Control policy has blocked this file.')
  $unrelated=[ComponentModel.Win32Exception]::new(5)
  $generic=[Exception]::new('The system cannot find the file specified.')
  if(!(Test-AppControlLaunchDenial -Failure $wrapped) -or
     !(Test-AppControlLaunchDenial -Failure $localized) -or
     !(Test-AppControlLaunchDenial -Failure $message) -or
     (Test-AppControlLaunchDenial -Failure $unrelated) -or
     (Test-AppControlLaunchDenial -Failure $generic)){
    throw 'R428_APP_CONTROL_ERROR_CLASSIFICATION_FALSE_POSITIVE_OR_NEGATIVE'
  }
  Remove-Item -LiteralPath 'Function:\Test-AppControlLaunchDenial' -ErrorAction Stop
  'R428_PASS_APP_CONTROL_4551_WRAPPED_TEXT_AND_OTHER_ERRORS_NOT_RECLASSIFIED'
  # A native PE can be executed from a read-only file handle which denies
  # write/delete sharing; use Setup /verify (no install) as the harmless proof.
  $setupFixture=Join-Path $stage $manifest.SetupFile
  $pin=[IO.FileStream]::new($setupFixture,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
  try{
    $denied=$false
    try{$writer=[IO.FileStream]::new($setupFixture,[IO.FileMode]::Open,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite);$writer.Dispose()}
    catch [IO.IOException]{$denied=$true}
    if(!$denied){throw 'R410_PINNED_SETUP_STILL_WRITABLE'}
    $verifiedProcess=Start-Process -FilePath $setupFixture -ArgumentList '/verify' -PassThru -Wait -ErrorAction Stop
    if(!$verifiedProcess -or $verifiedProcess.ExitCode -ne 0){throw 'R410_PINNED_SETUP_VERIFY_PROCESS_FAILED'}
  }finally{$pin.Dispose()}
  'R410_PASS_NATIVE_PINNED_EXE_READONLY_VERIFY_AND_DENIED_WRITER'
  # R426: execute the production Setup lease with harmless /verify,
  # enforcing real native Windows sharing denial and no installation.
  $leaseProof=Invoke-Preflight $stage '-VerifyPinnedSetup'
  if($leaseProof.Exit -ne 0){
    throw ('R426_PINNED_SETUP_NATIVE_VERIFY_FAILED_'+$leaseProof.Stdout+'_'+$leaseProof.Stderr)
  }
  $leaseResult=$leaseProof.Stdout|ConvertFrom-Json
  if($leaseResult.Status -cne 'SETUP_VERIFIED_PINNED_NO_INSTALL' -or
     $leaseResult.SetupSHA256 -cne $manifest.SetupSHA256 -or
     !$leaseResult.DeniedWriteWhilePinned -or
     !$leaseResult.SetupExecutedForVerification -or
     $leaseResult.ProductInstalled){
    throw 'R426_PINNED_SETUP_NATIVE_VERIFY_SEMANTICS_CHANGED'
  }
  'R426_PASS_BOOTSTRAP_PINNED_SETUP_VERIFY_NO_INSTALL'
  if($ExpectOfflineRuntime){
    $proof=Invoke-Preflight $stage '-VerifyOfflineRuntime'
    if($proof.Exit -ne 0){throw ('R410_REAL_MICROSOFT_OFFLINE_SIGNATURE_VERIFICATION_FAILED_'+$proof.Stdout+'_'+$proof.Stderr)}
    $verified=$proof.Stdout|ConvertFrom-Json
    if($verified.Status -cne 'OFFLINE_RUNTIME_VERIFIED_NO_EXECUTION' -or $verified.RuntimeExecuted -or $verified.ProductInstalled -or $verified.SHA256 -cne $runtimeExpectedSHA){throw 'R410_OFFLINE_RUNTIME_VERIFICATION_SEMANTIC_FAILED'}
    'R410_PASS_REAL_OFFLINE_MICROSOFT_EXE_SHA256_AND_AUTHENTICODE'
  }
  if($ExpectUnsupportedServer){
    $kind=[string](Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\ProductOptions' -Name ProductType).ProductType
    if($kind -ceq 'WinNT'){throw 'R409_HOSTED_TEST_REQUIRES_WINDOWS_SERVER'}
    $server=Invoke-Preflight $stage
    if($server.Exit -eq 0 -or $server.Stdout -notmatch 'R409_WINDOWS_SERVER_NOT_SUPPORTED'){
      throw ('R409_WINDOWS_SERVER_WAS_NOT_REFUSED_'+$server.Stdout)
    }
    if($ExpectOfflineRuntime){
      $cmdResult=Invoke-CmdFromPollutedPs7Environment $stage '-VerifyOfflineRuntime'
      $checked=$cmdResult|ConvertFrom-Json
      if($checked.Status -cne 'OFFLINE_RUNTIME_VERIFIED_NO_EXECUTION' -or
         $checked.SHA256 -cne $runtimeExpectedSHA -or $checked.RuntimeExecuted -or $checked.ProductInstalled){
        throw 'R414_HOSTED_POLLUTED_CMD_VERIFICATION_SEMANTICS_CHANGED'
      }
      'R414_PASS_HOSTED_WINPS51_CMD_CLEARS_INHERITED_PS7_MODULE_PATH'
    }
    'R409_PASS_HOSTED_SERVER_OS_UNSUPPORTED_FAIL_CLOSED'
    if($ExpectOfflineRuntime){'R410_PASS_HOSTED_OFFLINE_FRAMEWORK_VERIFIED_BUT_SERVER_NOT_INSTALLED'}
    'R409_RESULT=PASS_HOSTED_ARCHIVE_MANIFEST_AND_UNSUPPORTED_OS_BOUNDARY'
    return
  }
  $good=Invoke-Preflight $stage
  if($good.Exit -ne 0){throw ('R409_CHECK_ONLY_FAILED_'+$good.Stdout+'_'+$good.Stderr)}
  $check=$good.Stdout|ConvertFrom-Json
  if($check.Status -cne 'CHECK_ONLY' -or !$check.Framework48OrNewer -or
     $check.OfficialRuntimeBundled -ne [bool]$ExpectOfflineRuntime -or
     $check.ExecutedSetup -or $check.ModifiedOwnerSettings){
    throw 'R409_CHECK_ONLY_SEMANTIC_MISMATCH'
  }
  $launcher=Join-Path $stage 'Install.cmd'
  $cmdProof=(& $launcher -CheckOnly | Out-String)
  if($LASTEXITCODE -ne 0 -or $cmdProof -notmatch '"Status"\s*:\s*"CHECK_ONLY"'){
    throw ('R409_CMD_ENTRYPOINT_READONLY_FAILED_'+$cmdProof)
  }
  $cmdResult=Invoke-CmdFromPollutedPs7Environment $stage '-CheckOnly'
  $cmdChecked=$cmdResult|ConvertFrom-Json
  if($cmdChecked.Status -cne 'CHECK_ONLY' -or
     $cmdChecked.ExecutedSetup -or $cmdChecked.ModifiedOwnerSettings -or
     $cmdChecked.SetupSHA256 -cne $manifest.SetupSHA256){
    throw 'R414_LOCAL_POLLUTED_CMD_CHECKONLY_SEMANTICS_CHANGED'
  }
  'R414_PASS_CLIENT_WINPS51_CMD_CLEARS_INHERITED_PS7_MODULE_PATH'
  'R409_PASS_REAL_WINDOWS_CMD_ENTRYPOINT_READONLY_CHECK_ONLY'
  'R409_PASS_REAL_WINDOWS_CHECK_ONLY_NO_INSTALL_NO_ELEVATION'
  $savedSetup=(Join-Path $stage $manifest.SetupFile)
  $touched=[IO.File]::ReadAllBytes($savedSetup)
  try{
    # Mutation of one byte in the private temporary copy only.
    $touched[0]=$touched[0] -bxor 1
    [IO.File]::WriteAllBytes($savedSetup,$touched)
    $bad=Invoke-Preflight $stage
    if($bad.Exit -eq 0 -or $bad.Stdout -notmatch 'R409_SETUP_HASH_MISMATCH'){
      throw ('R409_TAMPERED_SETUP_ACCEPTED_'+$bad.Stdout)
    }
    'R409_PASS_MODIFIED_SETUP_SHA256_REFUSED'
    $badLease=Invoke-Preflight $stage '-VerifyPinnedSetup'
    if($badLease.Exit -eq 0 -or $badLease.Stdout -notmatch 'R409_SETUP_HASH_MISMATCH'){
      throw ('R426_PINNED_SETUP_ACCEPTED_MODIFIED_BINARY_'+$badLease.Stdout)
    }
    'R426_PASS_MODIFIED_SETUP_REJECTED_BEFORE_PINNED_LAUNCH'
  }finally{
    # Restore from the unmodified archive, never attempt repair of user installation.
    Remove-Item -LiteralPath $savedSetup -Force
    Expand-Archive -LiteralPath $zip -DestinationPath $stage -Force
  }
  $manifestPath=Join-Path $stage 'package-manifest.json'
  $m=Get-Content $manifestPath -Raw|ConvertFrom-Json
  $m.SetupSHA256='0'*64
  [IO.File]::WriteAllText($manifestPath,($m|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
  $tampered=Invoke-Preflight $stage
  if($tampered.Exit -eq 0 -or $tampered.Stdout -notmatch 'R409_SETUP_HASH_MISMATCH'){
    throw ('R409_TAMPERED_MANIFEST_ACCEPTED_'+$tampered.Stdout)
  }
  'R409_PASS_TAMPERED_MANIFEST_REFUSED'
  if($ExpectOfflineRuntime){
    # Restore only the test fixture manifest before the independent runtime-
    # tampering trial; otherwise an earlier Setup check would mask the finding.
    $m.SetupSHA256=$manifest.SetupSHA256
    [IO.File]::WriteAllText($manifestPath,($m|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
    # All mutation is confined to an extracted temporary fixture. Never touch
    # the pristine downloaded Microsoft runtime or the owner's installation.
    $off=Join-Path $stage $runtimeName
    [IO.File]::WriteAllBytes($off,[byte[]]@(0x4d,0x5a,0,0))
    $fake=Invoke-Preflight $stage '-VerifyOfflineRuntime'
    if($fake.Exit -eq 0 -or $fake.Stdout -notmatch 'R409_RUNTIME_HASH_MISMATCH'){
      throw ('R410_OFFLINE_TAMPERED_RUNTIME_NOT_REJECTED_'+$fake.Stdout)
    }
    'R410_PASS_TAMPERED_OFFLINE_RUNTIME_SHA256_REFUSED'
  }
  $afterConfig=if(Test-Path $config){(Get-FileHash $config -Algorithm SHA256).Hash}else{'ABSENT'}
  $afterApp=if(Test-Path $app){(Get-FileHash $app -Algorithm SHA256).Hash}else{'ABSENT'}
  if($beforeConfig -cne $afterConfig -or $beforeApp -cne $afterApp){
    throw 'R409_TEST_OWNER_MAIN_OR_CONFIG_CHANGED'
  }
  'R409_PASS_OWNER_INSTALLATION_AND_CONFIG_SHA_UNCHANGED'
  'R409_RESULT=PASS_WINDOWS_BOOTSTRAP_ARCHIVE_READONLY_AND_TAMPER_SCOPE'
}finally{
  if(Test-Path -LiteralPath $testRoot){Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction Stop}
}
