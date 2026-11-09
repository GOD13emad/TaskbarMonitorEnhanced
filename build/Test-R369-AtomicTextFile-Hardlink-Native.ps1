[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][ValidateSet('baseline','candidate')][string]$Variant,
 [Parameter(Mandatory=$true)][string]$AppPath,
 [Parameter(Mandatory=$true)][string]$SourceRoot,
 [ValidateSet('LOCAL','A','B')][string]$HostLabel='LOCAL',
 [switch]$HostedGuest
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($PSVersionTable.PSEdition -cne 'Desktop'){throw 'R369_NATIVE_WINDOWS_POWERSHELL_51_REQUIRED'}
if($HostedGuest -and ($env:GITHUB_ACTIONS -cne 'true' -or
 $env:RUNNER_OS -cne 'Windows' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted')){
 throw 'R369_REFUSE_NON_DISPOSABLE_HOST'
}
$source=(Resolve-Path -LiteralPath $SourceRoot).Path
$app=(Resolve-Path -LiteralPath $AppPath).Path
$expected=Join-Path $source 'build\_out\App\TaskbarMonitorEnhanced.exe'
if(![string]::Equals($app,$expected,[StringComparison]::OrdinalIgnoreCase)){throw 'R369_APP_NOT_EXACT_BUILD_OUTPUT'}
$sourcePath=Join-Path $source 'src\TaskbarMonitorEnhanced.cs'
if(!(Test-Path -LiteralPath $sourcePath)){throw 'R369_APP_SOURCE_MISSING'}
$sourceText=[IO.File]::ReadAllText($sourcePath)
$sourceCommit=(git -C $source rev-parse HEAD).Trim()
if($Variant -eq 'baseline'){
 if($sourceCommit -cne 'e6d3405c116e6dd5b52a018dc46dc7beb86a8562' -or
  !$sourceText.Contains('Environment.TickCount.ToString(CultureInfo.InvariantCulture)+".tmp"')){
  throw 'R369_BASELINE_EXACT_SOURCE_NOT_MATCHED'
 }
}else{
 if(!$sourceText.Contains('Guid.NewGuid().ToString("N")+".tmp"') -or
  !$sourceText.Contains('FileMode.CreateNew,FileAccess.Write,FileShare.None') -or
  !$sourceText.Contains('File.Copy(path,backupPath,false)') -or
  $sourceText.Contains('Environment.TickCount.ToString(CultureInfo.InvariantCulture)+".tmp"')){
  throw 'R369_CANDIDATE_SOURCE_ATOMIC_GUARD_FAILED'
 }
}
# The earlier workflow step proves there is no installed product before Build.
# Build's own selftests may legitimately create the AppData folder; it is not an installation.
if($HostedGuest){
 $installedExe=Join-Path (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'TaskbarMonitorEnhanced') 'TaskbarMonitorEnhanced.exe'
 if(Test-Path -LiteralPath $installedExe -PathType Leaf){throw 'R369_HOSTED_INSTALLED_APP_BINARY_PREEXISTS'}
}
$checks=[Collections.Generic.List[string]]::new()
function Pass([string]$name){$checks.Add($name);Write-Output ('R369_PASS '+$name)}
function Sha([string]$path){(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash}
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class R369HardLinkNative {
 [DllImport("kernel32.dll", EntryPoint="CreateHardLinkW",CharSet=CharSet.Unicode,SetLastError=true)]
 [return: MarshalAs(UnmanagedType.Bool)]
 public static extern bool Link(string path,string existing,IntPtr security);
}
'@
function New-HardLink([string]$link,[string]$target){
 if(![R369HardLinkNative]::Link($link,$target,[IntPtr]::Zero)){
  throw ('R369_HARDLINK_CREATE_FAILED_'+[Runtime.InteropServices.Marshal]::GetLastWin32Error())
 }
}
$asm=[Reflection.Assembly]::LoadFrom($app)
$typ=$asm.GetType('TaskbarMonitorEnhanced.AtomicTextFile',$true)
$m=$typ.GetMethod('Write',[Reflection.BindingFlags]'Static,Public,NonPublic')
if(!$m -or $m.GetParameters().Length -ne 4){throw 'R369_COMPILED_WRITE_METHOD_MISSING'}
Pass 'COMPILED_APP_ATOMIC_WRITER_METHOD_BOUND'
$root=Join-Path $env:TEMP ('tbme-r369-atomic-write-'+[Guid]::NewGuid().ToString('N'))
if(Test-Path -LiteralPath $root){throw 'R369_FIXTURE_ROOT_EXISTS'}
[void][IO.Directory]::CreateDirectory($root)
$dest=Join-Path $root 'config.json'
$canary=Join-Path $root 'outside-canary.txt'
$canaryMarker='R369_OUTSIDE_CANARY_UNCHANGED'
[IO.File]::WriteAllText($canary,$canaryMarker)
$canaryBefore=Sha $canary
$aliasCount=0
$aliasHit=$false
$alignedCalls=0
$preseedMisses=0
# R376: NTFS hardlink setup can exceed the old 850-ms future window.
# Both variants must exercise the real compiled writer inside a seeded window.
$futureLeadMs=8000
function Invoke-Write([string]$path,[string]$value,[string]$backup=''){
 $argsToInvoke=[object[]]@([string]$path,[string]$value,[Text.Encoding]::UTF8,[string]$backup)
 $m.Invoke($null,$argsToInvoke)|Out-Null
}
try {
 for($attempt=0;$attempt -lt 3 -and !$aliasHit -and $alignedCalls -eq 0;$attempt++){
  $pidInt=[Diagnostics.Process]::GetCurrentProcess().Id
  $tickStart=[long][Environment]::TickCount+$futureLeadMs
  if($tickStart+350 -ge [int]::MaxValue){throw 'R369_TEST_TICKCOUNT_SIGNED_WRAP'}
  for($i=0;$i -lt 350;$i++){
   $tick=$tickStart+$i
   $alias=$dest+'.'+$pidInt+'.'+$tick+'.tmp'
   if(!(Test-Path -LiteralPath $alias)){
    New-HardLink $alias $canary
    $aliasCount++
   }
  }
  if([Environment]::TickCount -ge ($tickStart-300)){$preseedMisses++;continue}
  $watch=[Diagnostics.Stopwatch]::StartNew()
  while([Environment]::TickCount -lt $tickStart -and $watch.ElapsedMilliseconds -lt ($futureLeadMs+1500)){
   Start-Sleep -Milliseconds 10
  }
  if([Environment]::TickCount -lt $tickStart){throw 'R369_TEST_TICKCOUNT_WAIT_TIMEOUT'}
  for($n=0;$n -lt 10;$n++){
   $beforeTick=[Environment]::TickCount
   Invoke-Write $dest 'R369_ALIAS_WRITE'
   $afterTick=[Environment]::TickCount
   if($beforeTick -ge $tickStart -and $afterTick -lt ($tickStart+350)){$alignedCalls++}
   if((Sha $canary) -cne $canaryBefore){$aliasHit=$true;break}
  }
 }
 if(!$aliasHit -and $alignedCalls -eq 0){
  throw ('R369_FIXTURE_NO_ALIGNED_WRITE preseedMisses='+$preseedMisses)
 }
 $canaryAfter=Sha $canary
 if($Variant -eq 'baseline'){
  if(!$aliasHit){throw 'R369_BASELINE_PREDICTABLE_TEMP_ALIAS_NOT_REPRODUCED'}
  Pass 'BASELINE_PREDICTABLE_TEMP_HARDLINK_WRITE_THROUGH_REPRODUCED'
 }else{
  if($aliasHit -or $canaryAfter -cne $canaryBefore){throw 'R369_CANDIDATE_WRITES_THROUGH_OLD_PREDICTABLE_ALIAS'}
  if([IO.File]::ReadAllText($dest) -cne 'R369_ALIAS_WRITE'){throw 'R369_CANDIDATE_OUTPUT_INVALID'}
  Pass 'CANDIDATE_RANDOM_CREATE_NEW_BLOCKS_PREDICTABLE_ALIAS_WRITE_THROUGH'
 }
 # Backup semantics must use a clean fixture: after a successful baseline attack
 # config.json still shares a file object with hundreds of NTFS aliases.
 $normal=Join-Path $root 'normal-config.json'
 [IO.File]::WriteAllText($normal,'R369_ALIAS_WRITE',[Text.Encoding]::UTF8)
 $backup=Join-Path $root 'normal-config.json.bak'
 Invoke-Write $normal 'R369_REPLACED' $backup
 if([IO.File]::ReadAllText($normal) -cne 'R369_REPLACED' -or
  [IO.File]::ReadAllText($backup) -cne 'R369_ALIAS_WRITE'){
  throw 'R369_REPLACE_BACKUP_SEMANTICS_REGRESSION'
 }
 Pass 'ATOMIC_REPLACE_PRESERVES_PREVIOUS_CONFIG_BACKUP'
 $fresh=Join-Path $root 'fresh.json'
 $freshBackup=Join-Path $root 'fresh.json.bak'
 Invoke-Write $fresh 'R369_INITIAL_CONFIG' $freshBackup
 if([IO.File]::ReadAllText($fresh) -cne 'R369_INITIAL_CONFIG' -or
    [IO.File]::ReadAllText($freshBackup) -cne 'R369_INITIAL_CONFIG'){
   throw 'R369_FIRST_WRITE_BACKUP_SEMANTICS_REGRESSION'
 }
 Pass 'INITIAL_CONFIG_CREATES_BACKUP_WITH_IDENTICAL_BYTES'
 $destLink=Join-Path $root 'destination-hardlink.json'
 $other=Join-Path $root 'destination-canary.txt'
 [IO.File]::WriteAllText($other,'R369_DESTINATION_CANARY_ORIGINAL')
 $beforeDest=Sha $other
 New-HardLink $destLink $other
 Invoke-Write $destLink 'R369_DESTINATION_REPLACEMENT'
 if((Sha $other) -cne $beforeDest -or
    [IO.File]::ReadAllText($destLink) -cne 'R369_DESTINATION_REPLACEMENT'){
   throw 'R369_DESTINATION_HARDLINK_CANARY_WRITE_THROUGH'
 }
 Pass 'DESTINATION_HARDLINK_REPLACED_WITHOUT_CANARY_WRITE_THROUGH'
 if($Variant -eq 'candidate'){
  $prefix=[IO.Path]::GetFileName($dest)
  $newTemp=@(Get-ChildItem -LiteralPath $root -File -Filter '*.tmp' |
   Where-Object {$_.Name -match ('^'+[regex]::Escape($prefix)+'\.[0-9a-f]{32}\.tmp$')})
  if($newTemp.Count -ne 0){throw 'R369_CANDIDATE_RANDOM_TEMP_NOT_CLEANED'}
  Pass 'CANDIDATE_RANDOM_TEMP_CLEANUP_NO_ORPHANS'
 }
 $state=[ordered]@{
  Schema=1
  Revision='R369'
  Variant=$Variant
  Host=$HostLabel
  SourceCommit=$sourceCommit
  SourceSHA256=(Sha $sourcePath)
  AppSHA256=(Sha $app)
  Result=if($Variant -eq 'baseline'){'PASS_BASELINE_ALIAS_REPRODUCED'}else{'PASS_CANDIDATE_ALIAS_BLOCKED'}
  Checks=@($checks)
  AliasCount=$aliasCount
  AliasWriteThrough=$aliasHit
  AlignedWriteCalls=$alignedCalls
  PreseedMisses=$preseedMisses
  FutureLeadMilliseconds=$futureLeadMs
  CanaryBeforeSHA256=$canaryBefore
  CanaryAfterSHA256=$canaryAfter
  Scope='Isolated same-user NTFS file hardlinks and exact compiled AtomicTextFile.Write. Does not prove security against post-handle-close concurrent directory writers.'
 }
 $receiptParent=if($HostedGuest){$env:RUNNER_TEMP}else{$env:TEMP}
 $receiptDir=Join-Path $receiptParent ('R369_'+$Variant+'_'+$HostLabel+'_'+[Guid]::NewGuid().ToString('N'))
 [void][IO.Directory]::CreateDirectory($receiptDir)
 $receipt=Join-Path $receiptDir 'R369_ATOMIC_TEXT_HARDLINK.json'
 [IO.File]::WriteAllText($receipt,($state|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
 $read=[IO.File]::ReadAllText($receipt)|ConvertFrom-Json -ErrorAction Stop
 if($read.Revision -cne 'R369' -or $read.Checks.Count -lt 4){throw 'R369_TYPED_RECEIPT_INVALID'}
 Write-Output "R369_RECEIPT=$receipt"
 Write-Output "R369_RESULT=$($state.Result) CHECKS=$($checks.Count) ALIASES=$aliasCount"
}finally{
 if(Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Force -Recurse -ErrorAction SilentlyContinue}
}
