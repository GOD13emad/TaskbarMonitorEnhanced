[CmdletBinding()]
param([Parameter(Mandatory=$true)][ValidateSet('A','B')][string]$Machine)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# Destructive HKCU fault injection only on a fresh GitHub-hosted disposable Windows VM.
if($env:GITHUB_ACTIONS -cne 'true' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
   $env:RUNNER_OS -cne 'Windows' -or $env:GITHUB_REPOSITORY -cne 'GOD13emad/TaskbarMonitorEnhanced' -or
   $env:GITHUB_REF -cne 'refs/heads/audit/r225-disposable-registry-rollback' -or
   [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP) -or
   $env:COMPUTERNAME -match '(?i)EMAD|ALI|LAPTOP'){
    throw 'R225_DISPOSABLE_HOST_ONLY_REFUSAL'
}
$repo='GOD13emad/TaskbarMonitorEnhanced'
$app=Join-Path $env:LOCALAPPDATA 'TaskbarMonitorEnhanced'
$main=Join-Path $app 'TaskbarMonitorEnhanced.exe'
$uninstallPath='Software\Microsoft\Windows\CurrentVersion\Uninstall\TaskbarMonitorEnhanced'
$runPath='Software\Microsoft\Windows\CurrentVersion\Run'
$runName='TaskbarMonitorEnhanced'
$root=[Microsoft.Win32.Registry]::CurrentUser
$expectedSetupSHA='225BCC259C392DA04F3E0157CAF22F96C4052282AAF02555E6F6E777F4CB8AF4'
$expectedMainSHA='84D5DBF6F2E6D1D2E2B3E6D9C9DA523E564A7F5240C08D34A456D934026B829F'
$work=Join-Path $env:RUNNER_TEMP ('TBME_R225_REGISTRY_'+$Machine)
$receipt=Join-Path $work 'R225_REAL_HKCU_REGISTRY_RESTORE.json'
$backup=Join-Path $work 'R225_EXACT_HKCU_REGISTRY_BACKUP.json'
$status='FAIL';$phase='HOST_PREFLIGHT';$why=''
$before=$null;$registered=$false;$fault=$false;$restored=$false;$same=$false
$originalRegistrySHA='';$restoredRegistrySHA=''
$originalInstallVersion='';$originalRunPresent=$false;$valueCount=0
function Fail([string]$reason){throw ('R225_'+$reason)}
function SHA([string]$path){
  if(!(Test-Path -LiteralPath $path -PathType Leaf)){return 'MISSING'}
  return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
function HashUtf8([string]$value){
  return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($value)))
}
function ProcessCount{
  return @((Get-Process -ErrorAction SilentlyContinue|Where-Object {
    $_.ProcessName -in @('TaskbarMonitorEnhanced','TaskbarMonitorSensorBroker',
                        'TaskbarMonitorSensorSupervisor')
  })).Count
}
function ValueEntry([Microsoft.Win32.RegistryKey]$key,[string]$name){
  $kind=$key.GetValueKind($name)
  if($kind -notin @([Microsoft.Win32.RegistryValueKind]::String,
                   [Microsoft.Win32.RegistryValueKind]::ExpandString,
                   [Microsoft.Win32.RegistryValueKind]::DWord,
                   [Microsoft.Win32.RegistryValueKind]::QWord,
                   [Microsoft.Win32.RegistryValueKind]::Binary,
                   [Microsoft.Win32.RegistryValueKind]::MultiString)){
    Fail ('UNSUPPORTED_REGISTRY_KIND_'+[string]$kind)
  }
  $raw=$key.GetValue($name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
  if($null -eq $raw){Fail 'REGISTRY_VALUE_NULL'}
  $v=if($kind -eq [Microsoft.Win32.RegistryValueKind]::Binary){
    [Convert]::ToBase64String([byte[]]$raw)
  }elseif($kind -eq [Microsoft.Win32.RegistryValueKind]::MultiString){
    @([string[]]$raw)
  }elseif($kind -eq [Microsoft.Win32.RegistryValueKind]::DWord){
    [int]$raw
  }elseif($kind -eq [Microsoft.Win32.RegistryValueKind]::QWord){
    [long]$raw
  }else{[string]$raw}
  return [ordered]@{Kind=[string]$kind;Value=$v}
}
function RegistryState {
  $u=$root.OpenSubKey($uninstallPath,$false)
  if($null -eq $u){Fail 'UNINSTALL_HKCU_REGISTRY_NOT_FOUND'}
  try{
    if($u.SubKeyCount -ne 0){Fail 'UNEXPECTED_REGISTRY_SUBKEYS'}
    $names=@($u.GetValueNames()|Sort-Object -CaseSensitive)
    if($names.Count -lt 4 -or $names.Count -gt 100){Fail 'HKCU_UNINSTALL_VALUES_COUNT_OUT_OF_BOUND'}
    $values=[ordered]@{}
    foreach($n in $names){$values[$n]=ValueEntry $u $n}
  }finally{$u.Dispose()}
  $r=$root.OpenSubKey($runPath,$false)
  $runRecord=[ordered]@{Present=$false;Name=$runName;Entry=$null}
  if($null -ne $r){
    try{
      if($r.GetValueNames() -contains $runName){
        $runRecord['Present']=$true
        $runRecord['Entry']=ValueEntry $r $runName
      }
    }finally{$r.Dispose()}
  }
  return [ordered]@{Schema=1;UninstallHKCU=$values;StartupHKCU=$runRecord}
}
function EncodeState($state){
  return ($state|ConvertTo-Json -Depth 15 -Compress)
}
function RestoreValues($original){
  $snap=$original.UninstallHKCU
  $u=$root.CreateSubKey($uninstallPath,$true)
  if($null -eq $u){Fail 'CANNOT_CREATE_HKCU_UNINSTALL_KEY'}
  try{
    foreach($name in @($u.GetValueNames())){
      if(!$snap.Contains($name)){$u.DeleteValue($name,$false)}
    }
    foreach($name in @($snap.Keys)){
      $record=$snap[$name]
      $kind=[Enum]::Parse([Microsoft.Win32.RegistryValueKind],[string]$record.Kind)
      $value=if($kind -eq [Microsoft.Win32.RegistryValueKind]::Binary){
        [Convert]::FromBase64String([string]$record.Value)
      }elseif($kind -eq [Microsoft.Win32.RegistryValueKind]::MultiString){
        [string[]]@($record.Value)
      }elseif($kind -eq [Microsoft.Win32.RegistryValueKind]::DWord){
        [int]$record.Value
      }elseif($kind -eq [Microsoft.Win32.RegistryValueKind]::QWord){
        [long]$record.Value
      }else{[string]$record.Value}
      $u.SetValue($name,$value,$kind)
    }
    $u.Flush()
  }finally{$u.Dispose()}
  $r=$root.CreateSubKey($runPath,$true)
  if($null -eq $r){Fail 'CANNOT_OPEN_HKCU_RUN_KEY'}
  try{
    if($original.StartupHKCU.Present){
      $record=$original.StartupHKCU.Entry
      $kind=[Enum]::Parse([Microsoft.Win32.RegistryValueKind],[string]$record.Kind)
      if($kind -notin @([Microsoft.Win32.RegistryValueKind]::String,
                        [Microsoft.Win32.RegistryValueKind]::ExpandString)){
        Fail 'UNSUPPORTED_AUTOSTART_VALUE_TYPE'
      }
      $r.SetValue($runName,[string]$record.Value,$kind)
    }else{
      $r.DeleteValue($runName,$false)
    }
    $r.Flush()
  }finally{$r.Dispose()}
}
function Install([string]$setup,[string]$installerArguments){
  # Reject GUI defaults: PowerShell's built-in $args is always empty here if
  # it is incorrectly used as a declared named function parameter.
  if($installerArguments -cnotmatch '^/install /quiet /desktop=0 /startup=[01]$'){
    Fail 'SILENT_INSTALL_ARGS_NOT_BOUND_EXACTLY'
  }
  $si=[Diagnostics.ProcessStartInfo]::new()
  $si.FileName=$setup;$si.Arguments=$installerArguments;$si.UseShellExecute=$false;$si.CreateNoWindow=$true
  $si.WorkingDirectory=Split-Path $setup -Parent
  $proc=[Diagnostics.Process]::Start($si)
  if($null -eq $proc){Fail 'NO_SETUP_CHILD'}
  try{
    if(!$proc.WaitForExit(190000)){Fail 'SETUP_TIMEOUT'}
    if($proc.ExitCode -ne 0){Fail ('SETUP_FAILED_'+$proc.ExitCode)}
  }finally{$proc.Dispose()}
}
try{
  if(Test-Path $work -PathType Container){Fail 'WORKDIR_PREEXISTS'}
  if((Test-Path $app) -or ($null -ne $root.OpenSubKey($uninstallPath,$false)) -or
     (ProcessCount) -ne 0){Fail 'GUEST_NOT_PRISTINE'}
  New-Item -ItemType Directory $work -ErrorAction Stop|Out-Null
  $phase='DOWNLOAD_OFFICIAL_IMMUTABLE_V172'
  & gh release download v1.7.2 --repo $repo --pattern TaskbarMonitorEnhanced_Setup_1.7.2.exe --dir $work
  if($LASTEXITCODE -ne 0){Fail 'IMMUTABLE_SETUP_DOWNLOAD_FAILED'}
  $setup=Join-Path $work 'TaskbarMonitorEnhanced_Setup_1.7.2.exe'
  if((SHA $setup) -cne $expectedSetupSHA){Fail 'PUBLIC_SETUP_SHA_MISMATCH'}
  $phase='INSTALL_REAL_GUEST_'+$Machine
  $startup=if($Machine -ceq 'A'){'0'}else{'1'}
  Install $setup ('/install /quiet /desktop=0 /startup='+$startup)
  if((SHA $main) -cne $expectedMainSHA -or (ProcessCount) -ne 0){Fail 'GUEST_NOT_OFFICIAL_AND_QUIESCENT'}
  $phase='BACKUP_COMPLETE_HKCU_INSTALLER_KEYS'
  $before=RegistryState
  $originalInstallVersion=[string]$before.UninstallHKCU['DisplayVersion'].Value
  if($originalInstallVersion -cne '1.7.2' -or
     [string]$before.UninstallHKCU['InstallLocation'].Value -cne $app){
    Fail 'HKCU_172_INSTALL_IDENTITY_WRONG'
  }
  if(($Machine -ceq 'A' -and $before.StartupHKCU.Present) -or
     ($Machine -ceq 'B' -and !$before.StartupHKCU.Present)){
    Fail 'OFFICIAL_INSTALLER_STARTUP_OPTION_IGNORED'
  }
  $originalRunPresent=[bool]$before.StartupHKCU.Present
  $valueCount=@($before.UninstallHKCU.Keys).Count
  [IO.File]::WriteAllText($backup,(EncodeState $before),[Text.UTF8Encoding]::new($false))
  $originalRegistrySHA=SHA $backup
  if(!(Test-Path $backup -PathType Leaf) -or !$originalRegistrySHA -or
     ((Get-Content $backup -Raw|ConvertFrom-Json).UninstallHKCU.DisplayVersion.Value) -cne '1.7.2'){
    Fail 'HKCU_BACKUP_FILE_NOT_READABLE_AND_VALID'
  }
  $phase='INJECT_CONTROLLED_GUEST_HKCU_FAULT'
  $u=$root.OpenSubKey($uninstallPath,$true)
  if($null -eq $u){Fail 'HKCU_UNINSTALL_NOT_WRITABLE_ON_GUEST'}
  try{
    $u.SetValue('DisplayName','R225-FAULT-INJECTION',[Microsoft.Win32.RegistryValueKind]::String)
    $u.SetValue('DisplayVersion','9.9.9',[Microsoft.Win32.RegistryValueKind]::String)
    $u.SetValue('R225TempFault','REMOVE_THIS_FAULT_ENTRY',[Microsoft.Win32.RegistryValueKind]::String)
    $u.Flush()
  }finally{$u.Dispose()}
  $run=$root.CreateSubKey($runPath,$true)
  try{
    $run.SetValue($runName,'R225-FAULT-INJECTION-NO-RUN',[Microsoft.Win32.RegistryValueKind]::String)
    $run.Flush()
  }finally{$run.Dispose()}
  $fault=$true
  if((RegistryState).UninstallHKCU.DisplayVersion.Value -cne '9.9.9'){
    Fail 'CONTROLLED_MUTATION_DID_NOT_APPLY'
  }
  $phase='RESTORE_EXACT_BACKUP_HKCU_VALUE_TYPES'
  $copied=Get-Content $backup -Raw|ConvertFrom-Json -AsHashtable
  if([int]$copied.Schema -ne 1 -or $copied.UninstallHKCU.Count -ne $valueCount){
    Fail 'RESTORE_FILE_SCHEMA_WRONG'
  }
  RestoreValues $copied
  $restored=$true
  $observed=RegistryState
  $same=((EncodeState $observed) -ceq (EncodeState $before))
  if(!$same -or (SHA $main) -cne $expectedMainSHA -or (ProcessCount) -ne 0){
    Fail 'REGISTRY_CONTENT_KINDS_OR_GUEST_APP_CHANGED_AFTER_RESTORE'
  }
  $restoredRegistrySHA=HashUtf8 (EncodeState $observed)
  if($restoredRegistrySHA -cne $originalRegistrySHA){Fail 'REGISTRY_SERIALIZED_HASH_DIFF'}
  $status='PASS_REAL_GUEST_EXACT_HKCU_INSTALL_STARTUP_REGISTRY_BACKUP_FAULT_RESTORE'
  $phase='ACCEPTED'
}catch{
  $why=$_.Exception.GetType().Name+': '+$_.Exception.Message
}finally{
  if($fault -and $null -ne $before -and !$same){
    try{
      RestoreValues $before
      $same=((EncodeState (RegistryState)) -ceq (EncodeState $before))
      if($same){$restored=$true}
    }catch{$why+='; CLEANUP='+$_.Exception.Message}
  }
  if(Test-Path $work -PathType Container){
    $obj=[ordered]@{
      Revision='R225';Host=$Machine;Status=$status;Phase=$phase;Failure=$why
      GitHubTestCommit=$env:GITHUB_SHA
      OfficialMainSHA256=$expectedMainSHA
      OfficialSetupSHA256=$expectedSetupSHA
      OriginalInstallVersion=$originalInstallVersion
      OriginalStartupValuePresent=$originalRunPresent
      UninstallRegistryValueCount=$valueCount
      OriginalHKCURegistryBackupSHA256=$originalRegistrySHA
      RestoredHKCURegistrySHA256=$restoredRegistrySHA
      FaultInjected=$fault
      RegistryRestoreFunctionExecuted=$restored
      RestoredByteAndTypeExact=$same
      GuestMainStillOfficial=(SHA $main) -ceq $expectedMainSHA
      GuestProcessCount=(ProcessCount)
      UserPersonalComputerTouched=$false
      NoPublicReleaseMutation=$true
      NoNonProductRegistryKeyModified=$true
      FullActualOwnerColdBackupAccepted=$false
      TimestampUTC=[DateTime]::UtcNow.ToString('o')
    }
    [IO.File]::WriteAllText($receipt,($obj|ConvertTo-Json -Depth 10),
                          [Text.UTF8Encoding]::new($false))
    Write-Output ($obj|ConvertTo-Json -Depth 10 -Compress)
  }
}
if($status -cne 'PASS_REAL_GUEST_EXACT_HKCU_INSTALL_STARTUP_REGISTRY_BACKUP_FAULT_RESTORE'){
    throw ('R225_REGISTRY_ROLLBACK_UNACCEPTED_'+$phase+' '+$why)
}
